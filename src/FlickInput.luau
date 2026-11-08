-- FlickInput.luau
-- Drag-to-aim and release-to-flick mechanics with reach angle validation and visual feedback.

local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local S = require(game.ReplicatedStorage.PenFight.Settings)
local T = require(game.ReplicatedStorage.PenFight.PhysicsTuning)

local Input = {}
Input.__index = Input

local function screenPosition(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		local inset = GuiService:GetGuiInset()
		return Vector2.new(input.Position.X, input.Position.Y) + inset
	end
	return UIS:GetMouseLocation()
end

local function plane(screen)
	local ray = workspace.CurrentCamera:ViewportPointToRay(screen.X, screen.Y)
	if math.abs(ray.Direction.Y) < 0.001 then return end
	local t = (S.Origin.Y + S.SurfaceY + 0.38 - ray.Origin.Y) / ray.Direction.Y
	if t > 0 then
		return ray.Origin + ray.Direction * t
	end
end

local function distance(p, a, b)
	local ab = b - a
	local t = math.clamp((p - a):Dot(ab) / math.max(ab:Dot(ab), 0.001), 0, 1)
	return (p - (a + ab * t)).Magnitude
end

local function line(part, a, b, color, width)
	part.Color = color
	part.Size = Vector3.new(width, 0.075, math.max(0.01, (b - a).Magnitude))
	part.CFrame = CFrame.lookAt((a + b) * 0.5, b)
	part.Transparency = 0.07
end

function Input.new(player, pens, characters, remotes, hud, camera, interaction)
	local self = setmetatable({
		player = player,
		pens = pens,
		characters = characters,
		remotes = remotes,
		hud = hud,
		camera = camera,
		interaction = interaction,
		pending = false,
	}, Input)

	self.preview = Instance.new("Folder")
	self.preview.Name = "PenFightLocalPreview"
	self.preview.Parent = workspace

	self.parts = {}
	for i = 1, 9 do
		local p = Instance.new("Part")
		p.Name = if i <= 3 then "Aim" .. i elseif i == 4 then "Contact" else "Guide" .. i
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Material = Enum.Material.Neon
		p.Transparency = 1
		p.Parent = self.preview
		self.parts[i] = p
	end

	self.highlight = Instance.new("Highlight")
	self.highlight.Name = "ActivePen"
	self.highlight.FillTransparency = 0.9
	self.highlight.OutlineTransparency = 0.05
	self.highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	self.highlight.Parent = self.preview

	UIS.InputBegan:Connect(function(i, used) self:Begin(i, used) end)
	UIS.InputChanged:Connect(function(i)
		if self.drag and (i == self.drag.input or (self.drag.input.UserInputType == Enum.UserInputType.MouseButton1 and i.UserInputType == Enum.UserInputType.MouseMovement)) then
			self.drag.screen = screenPosition(i)
		end
	end)
	UIS.InputEnded:Connect(function(i) self:Finish(i) end)
	UIS.WindowFocusReleased:Connect(function() self:Cancel() end)

	hud.SettingsButton.Activated:Connect(function() self:Cancel() end)
	hud.ViewButton.Activated:Connect(function() self:Cancel() end)
	hud.Reset.Activated:Connect(function()
		self:Cancel()
		if self.state and self.state.mode == "Online" then
			interaction:Request(self.state.gameKind == "Practice" and "PracticeReset" or "Rematch")
		elseif self.state and self.state.controller == player.UserId then
			remotes.Request:FireServer({action = "Reset"})
		end
	end)

	RunService:BindToRenderStep("PenFightAim", Enum.RenderPriority.Camera.Value + 2, function()
		self:Render()
	end)

	return self
end

function Input:Cancel()
	self.drag = nil
	self.hud.Gui:SetAttribute("DragActive",false)
	self.hud.Gui:SetAttribute("AimLoad", 0)
	for _, p in ipairs(self.parts) do
		p.Transparency = 1
	end
	self.hud:SetPower(0)
	if self.state then
		self.hud.Hint.Text = self.state.message
	end
end

function Input:SetState(s)
	self.state = s
	self.pending = false
	self.hud.Gui:SetAttribute("PendingFlick",false)
	self:Cancel()
	self.highlight.Adornee = self.pens:FindFirstChild(s.active)
	self.highlight.FillColor = S[s.active] or S.Blue
	self.highlight.OutlineColor = S[s.active] or S.Blue
	self.highlight.Enabled = (s.phase == "Aiming" and self.camera.ready and self.interaction.isAiming)
end

function Input:CanAim()
	return self.state
		and self.hud.Gui.Enabled
		and self.state.phase == "Aiming"
		and self.state.controller == self.player.UserId
		and not self.pending
		and self.camera.ready
		and not self.hud.Options.Visible
		and self.interaction.isAiming
		and self.camera.AimStable
end

function Input:Begin(input, processed)
	if processed or self.drag or not self:CanAim() then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end

	local screen = screenPosition(input)
	if self.hud:IsBlocked(screen) then return end

	local model = self.pens:FindFirstChild(self.state.active)
	if not model or not model.PrimaryPart then return end

	local body = model.PrimaryPart
	local cam = workspace.CurrentCamera
	local a = cam:WorldToViewportPoint(body.Position - body.CFrame.RightVector * 2.8)
	local b = cam:WorldToViewportPoint(body.Position + body.CFrame.RightVector * 2.8)
	local radius = if input.UserInputType == Enum.UserInputType.Touch then 45 else 28

	if distance(screen, Vector2.new(a.X, a.Y), Vector2.new(b.X, b.Y)) > radius then return end
	local world = plane(screen)
	if not world then return end

	self.drag = {
		input = input,
		screen = screen,
		startScreen = screen,
		start = world,
		body = body,
		pen = self.state.active,
		round = self.state.round,
		turn = self.state.turn,
		offset = math.clamp(body.CFrame:PointToObjectSpace(world).X, -T.MaxContactOffset, T.MaxContactOffset),
	}
	self.hud.Hint.Text = "Pull back, then release to flick"
	self.hud.Gui:SetAttribute("DragActive",true)
	self.hud.Gui:SetAttribute("SelectedPen",self.state.active)
end

function Input:Aim()
	local drag = self.drag
	if not drag then return end
	local world = plane(drag.screen)
	if not world then return end

	local d = drag.start - world
	d = Vector3.new(d.X, 0, d.Z)
	if d.Magnitude < 0.001 then
		return Vector3.xAxis, 0
	end

	return d.Unit, T.ChargeFromPixels((drag.screen - drag.startScreen).Magnitude, workspace.CurrentCamera.ViewportSize)
end

function Input:CheckReachAngle(direction)
	local char = self.characters:FindFirstChild(self.state.active)
	local pen = self.pens:FindFirstChild(self.state.active)
	if not char or not char.PrimaryPart or not pen or not pen.PrimaryPart then return true end

	local charPos = char.PrimaryPart.Position
	local penPos = pen.PrimaryPart.Position
	local horizontalReach = Vector3.new(penPos.X - charPos.X, 0, penPos.Z - charPos.Z)

	if horizontalReach.Magnitude > 0.1 then
		local reachDir = horizontalReach.Unit
		local dot = direction:Dot(reachDir)
		if dot < (T.MinReachDot or -0.40) then
			return false
		end
	end
	return true
end

function Input:Finish(input)
	local drag = self.drag
	if not drag then return end
	if input ~= drag.input and not (drag.input.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1) then
		return
	end

	drag.screen = screenPosition(input)
	local direction, charge = self:Aim()
	local allowed = input.UserInputState ~= Enum.UserInputState.Cancel and not self.hud.Options.Visible
	self:Cancel()

	if allowed and direction and charge >= T.MinPower and self:CanAim() then
		self.pending = true
		self.hud.Gui:SetAttribute("PendingFlick",true)
		self.hud.Gui:SetAttribute("LastReleaseCharge",charge)
		self.pendingId=self.interaction:Request("Flick",{
			pen = drag.pen,
			round = drag.round,
			turn = drag.turn,
			direction = direction,
			power = charge,
			offset = drag.offset,
		})

		local requestId=self.pendingId
		task.delay(2, function()
			if self.pending and self.pendingId==requestId then
				self.pending = false
				self.hud.Gui:SetAttribute("PendingFlick",false)
				self:Cancel()
				self.hud:SetError("No flick response. Aim again or reset the round.")
			end
		end)
	end
end

function Input:Result(packet)
	if packet.id==self.pendingId then
		self.pending=false
		self.hud.Gui:SetAttribute("PendingFlick",false)
	end
end

function Input:Render()
	self.highlight.Enabled = (self.state ~= nil and self.state.phase == "Aiming" and self.camera.ready and self.interaction.isAiming)
	if not self.drag then return end
	if not self:CanAim() then
		self:Cancel()
		return
	end

	local d, charge = self:Aim()
	if not d then return end

	local power = T.EffectivePower(charge)
	self.hud:SetPower(power)
	self.hud.Gui:SetAttribute("AimLoad", power)

	local isAngleValid = self:CheckReachAngle(d)
	local body = self.drag.body
	local origin = body.Position + body.CFrame.RightVector * self.drag.offset + Vector3.new(0, 0.6, 0)
	local tip = origin + d * (1.6 + power * 5.5)
	local side = Vector3.new(-d.Z, 0, d.X)

	local color = if isAngleValid then (S[self.drag.pen] or Color3.new(1, 1, 1)) else Color3.fromRGB(240, 80, 80)
	line(self.parts[1], origin, tip, color, 0.12)
	line(self.parts[2], tip, tip - d * 0.65 + side * 0.38, color, 0.15)
	line(self.parts[3], tip, tip - d * 0.65 - side * 0.38, color, 0.15)

	local contact = self.parts[4]
	contact.Shape = Enum.PartType.Ball
	contact.Size = Vector3.new(0.22, 0.22, 0.22)
	contact.Position = origin
	contact.Color = if isAngleValid then Color3.new(1, 1, 1) else Color3.fromRGB(255, 120, 120)
	contact.Transparency = 0

	for i = 5, 9 do
		local dot = self.parts[i]
		dot.Shape = Enum.PartType.Ball
		dot.Size = Vector3.new(0.11, 0.11, 0.11)
		dot.Position = tip + d * ((i - 4) * 0.55)
		dot.Color = color
		dot.Transparency = 0.35 + (i - 5) * 0.1
	end

	if not isAngleValid then
		self.hud.Hint.Text = "Exit aim and walk around for this angle"
	else
		self.hud.Hint.Text = "Pull back, then release to flick"
	end
end

return Input
