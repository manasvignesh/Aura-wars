-- The presentation camera is the only writer of CurrentCamera.
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Settings = require(game.ReplicatedStorage.PenFight.Settings)

local Camera = {}
Camera.__index = Camera

local FOV = 48
local TAN_Y = math.tan(math.rad(FOV / 2))
local TABLE = Settings.Origin + Vector3.new(0, Settings.SurfaceY, 0)
local OVERHEAD = Vector3.new(0, 3.8, 1).Unit
local OVERHEAD_GROUPS = {Ceiling = true, CeilingFans = true, ClassroomLights = true}

local function pointer(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		local inset = GuiService:GetGuiInset()
		return Vector2.new(input.Position.X, input.Position.Y) + inset
	end
	return Input:GetMouseLocation()
end

local function approach(dt, speed)
	return 1 - math.exp(-math.max(dt, 0) * speed)
end

function Camera.new(pens, characters, prefs, hud)
	local self = setmetatable({
		pens = pens, characters = characters, prefs = prefs, hud = hud,
		mode = "Intro", ready = false, yaw = math.pi, pitch = .30, distance = 12,
		roof = {}, faded = {}, fadeClock = 0, impactAt = -math.huge, impactStrength = 0,
	}, Camera)
	local arena = pens.Parent
	self.environment = arena:WaitForChild("Environment")

	self.collision = RaycastParams.new()
	self.collision.FilterType = Enum.RaycastFilterType.Exclude
	self.collision.FilterDescendantsInstances = {characters, pens, arena:WaitForChild("Spectators")}
	self.collision.RespectCanCollide = true
	self.collision.CollisionGroup = "Pens"

	self.actorRay = RaycastParams.new()
	self.actorRay.FilterType = Enum.RaycastFilterType.Include
	self.actorRay.FilterDescendantsInstances = {characters}

	-- The folders or their contents can arrive after the client camera starts.
	self.environment.DescendantAdded:Connect(function(node) self:RegisterOverhead(node) end)
	self.environment.DescendantRemoving:Connect(function(node)
		local original = self.roof[node]
		if original ~= nil then
			node.LocalTransparencyModifier = original
			self.roof[node] = nil
		end
	end)
	for _, node in ipairs(self.environment:GetDescendants()) do self:RegisterOverhead(node) end

	hud.SkipButton.Activated:Connect(function() self:Skip() end)
	hud.Replay.Activated:Connect(function()
		hud.Options.Visible = false
		if self.prefs.ReducedMotion or (self.state and (self.state.phase ~= "Aiming" or self.state.aiming)) then
			hud:Flash("Exit aim to replay the intro.")
			return
		end
		self.ready = false
		self.started = os.clock()
	end)
	prefs.Changed:Connect(function(key, value)
		if key == "ReducedMotion" and value then self:Skip() end
		if key == "PrecisionView" then
			self.aimFrame = nil
			self.aimEntered = os.clock()
		end
	end)

	Input.InputBegan:Connect(function(input, processed)
		if processed or not self.ready or self.mode ~= "FreeWalk" or hud.Options.Visible then return end
		local touch = input.UserInputType == Enum.UserInputType.Touch
		if not touch and input.UserInputType ~= Enum.UserInputType.MouseButton2 then return end
		local pos = pointer(input)
		if hud:IsBlocked(pos) or (touch and pos.X < workspace.CurrentCamera.ViewportSize.X * .62) then return end
		self.orbit = input
		self.lastPointer = pos
	end)
	Input.InputChanged:Connect(function(input)
		if not self.orbit or self.mode ~= "FreeWalk" then return end
		local mouseMove = self.orbit.UserInputType == Enum.UserInputType.MouseButton2
			and input.UserInputType == Enum.UserInputType.MouseMovement
		if input ~= self.orbit and not mouseMove then return end
		local pos = pointer(input)
		local delta = pos - self.lastPointer
		self.lastPointer = pos
		local sensitivity = .004 * self.prefs.CameraSensitivity
		self.yaw -= delta.X * sensitivity
		self.pitch = math.clamp(self.pitch + delta.Y * sensitivity, .08, 1.05)
	end)
	Input.InputEnded:Connect(function(input)
		if input == self.orbit or input.UserInputType == Enum.UserInputType.MouseButton2 then self.orbit = nil end
	end)
	Input.WindowFocusReleased:Connect(function() self.orbit = nil end)
	RunService:BindToRenderStep("PenFightCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		self:Step(dt)
	end)
	return self
end

function Camera:RegisterOverhead(node)
	if not node:IsA("BasePart") or self.roof[node] ~= nil then return end
	local group = node.Parent
	while group and group.Parent ~= self.environment do group = group.Parent end
	if not group or not OVERHEAD_GROUPS[group.Name] then return end
	self.roof[node] = node.LocalTransparencyModifier
	if self.mode ~= "FreeWalk" then node.LocalTransparencyModifier = 1 end
end

function Camera:SetMode(mode)
	if mode == self.mode then return end
	self.mode = mode
	self.orbit = nil
	local hide = mode ~= "FreeWalk"
	for part, original in pairs(self.roof) do
		part.LocalTransparencyModifier = hide and 1 or original
	end
	if mode ~= "Aiming" then self:RestoreActors() end
end

function Camera:BeginIntro()
	self.started = self.started or os.clock()
end

function Camera:Skip()
	self.ready = true
	self.started = nil
end

function Camera:SetState(state)
	local previous = self.state
	local online = state.mode == "Online"
	local character = online and game.Players.LocalPlayer.Character
	if not previous or (not online and previous.active ~= state.active) or (online and self.walkCharacter ~= character) then
		self.newTarget = true
		self.orbit = nil
	end
	self.walkCharacter = character
	if online and state.matchPhase == "Introduction" and (not previous or previous.matchPhase ~= "Introduction") then
		self.aimFrame = nil
		self.ready = false
		self.started = os.clock()
	end
	if state.aiming and (not previous or not previous.aiming) then
		self.aimEntered = os.clock()
		self.aimFrame = nil
		local model = self.characters:FindFirstChild(state.active)
		local root = model and model.PrimaryPart
		local side = root and (root.Position.Z > TABLE.Z and -1 or 1) or 1
		self.tacticalAxis = Vector3.new(.26, 2.65, side).Unit
	end
	if state.phase == "Won" and (not previous or previous.phase ~= "Won") then
		self.victoryAt = os.clock()
	end
	self.state = state
end

function Camera:Impact(_, intensity)
	if self.mode == "Tracking" and not self.prefs.ReducedMotion and intensity >= .65 then
		self.impactAt = os.clock()
		self.impactStrength = math.min(intensity, 1)
	end
end

function Camera:ScenePoints(includeActors, includeFallen)
	local points = {}
	local halfX = Settings.DeskSize.X / 2 + .45
	local halfZ = Settings.DeskSize.Z / 2 + .45
	for _, x in ipairs({-halfX, halfX}) do
		for _, z in ipairs({-halfZ, halfZ}) do
			table.insert(points, TABLE + Vector3.new(x, .2, z))
		end
	end
	for _, pen in ipairs(self.pens:GetChildren()) do
		local body = pen:IsA("Model") and pen.PrimaryPart
		if body and ((body.Position - TABLE).Magnitude < 26 or not includeFallen) then
			local half = body.CFrame.RightVector * 3.0
			table.insert(points, body.Position + half)
			table.insert(points, body.Position - half)
		end
	end
	if includeActors then
		for _, model in ipairs(self.characters:GetChildren()) do
			local root = model:IsA("Model") and model.PrimaryPart
			if root and (root.Position - TABLE).Magnitude < 21 then
				table.insert(points, root.Position + Vector3.new(0, 4, 0))
				table.insert(points, root.Position - Vector3.new(0, 4, 0))
			end
		end
	end
	return points
end

function Camera:Fit(view, focus, axis, points, minimum)
	local basis = CFrame.lookAt(axis, Vector3.zero)
	local height = math.max(view.Y, 1)
	local width = math.max(view.X, 1)
	local top = (self.hud.TopReserve or 84) + 8
	local bottom = (self.hud.BottomReserve or 70) + 9
	local usable = math.clamp((height - top - bottom) / height, .25, .83)
	local yCenter = (top - bottom) / height * TAN_Y
	local horizontal = TAN_Y * width / height * .86
	local vertical = TAN_Y * usable * .92
	local distance = minimum
	for _, point in ipairs(points) do
		local p = basis:VectorToObjectSpace(point - focus)
		distance = math.max(distance, math.abs(p.X) / horizontal + p.Z,
			math.abs(p.Y - yCenter * p.Z) / vertical + p.Z)
	end
	return CFrame.lookAt(focus + axis * distance, focus) * CFrame.new(0, yCenter * distance, 0)
end

function Camera:WalkFrame(dt, model)
	local root = model and model.PrimaryPart
	if not root then return self:Fit(workspace.CurrentCamera.ViewportSize, TABLE, OVERHEAD, self:ScenePoints(false, false), 18) end
	if self.newTarget then
		local backwards = -root.CFrame.LookVector
		self.yaw = math.atan2(backwards.X, backwards.Z)
		self.newTarget = false
	end
	local goal = root.Position + Vector3.new(0, 1.65, 0)
	self.focus = self.focus and self.focus:Lerp(goal, approach(dt, 14)) or goal
	local view = workspace.CurrentCamera.ViewportSize
	local requested = math.clamp(9.6 / math.max(view.X / math.max(view.Y, 1), .1), 12, 19)
	local horizontal = math.cos(self.pitch)
	local offset = Vector3.new(math.sin(self.yaw) * horizontal, math.sin(self.pitch), math.cos(self.yaw) * horizontal) * requested
	local hit = workspace:Spherecast(self.focus, .55, offset, self.collision)
	local allowed = hit and math.max(.5, hit.Distance - .30) or requested
	if allowed < self.distance then
		self.distance = allowed
		self.clearAt = os.clock()
	elseif os.clock() - (self.clearAt or 0) > .15 then
		self.distance += (allowed - self.distance) * approach(dt, 5)
	end
	return CFrame.lookAt(self.focus + offset.Unit * self.distance, self.focus), self.focus
end

function Camera:RestoreActors()
	for part, original in pairs(self.faded) do part.LocalTransparencyModifier = original end
	table.clear(self.faded)
end

function Camera:ClearAimSight(dt, frame)
	self.fadeClock += dt
	if self.fadeClock < .08 then return end
	self.fadeClock = 0
	local blockers = {}
	local cameraPosition = frame.Position
	local function check(point)
		local hit = workspace:Raycast(cameraPosition, point - cameraPosition, self.actorRay)
		if not hit then return end
		local part = hit.Instance
		while part and part.Parent ~= self.characters do part = part.Parent end
		if part then blockers[part] = true end
	end
	check(TABLE + Vector3.new(0, .35, 0))
	for _, pen in ipairs(self.pens:GetChildren()) do
		local body = pen:IsA("Model") and pen.PrimaryPart
		if body then
			local side = body.CFrame.RightVector * 2.2
			check(body.Position)
			check(body.Position + side)
			check(body.Position - side)
		end
	end
	for part, original in pairs(self.faded) do
		local model = part
		while model and model.Parent ~= self.characters do model = model.Parent end
		if not blockers[model] then
			part.LocalTransparencyModifier = original
			self.faded[part] = nil
		end
	end
	for model in pairs(blockers) do
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") and part.Transparency < 1 and self.faded[part] == nil then
				self.faded[part] = part.LocalTransparencyModifier
				part.LocalTransparencyModifier = math.max(part.LocalTransparencyModifier, .78)
			end
		end
	end
end

function Camera:Target(dt, view, mode, now)
	local state = self.state
	if mode == "Menu" then
		local drift = self.prefs.ReducedMotion and 0 or math.sin(now * .22) * 1.6
		return CFrame.lookAt(Vector3.new(14 + drift, 11, 116), Vector3.new(-2, 6, 100))
	elseif mode == "FreeWalk" then
		local model = state and (state.mode == "Online" and game.Players.LocalPlayer.Character or self.characters:FindFirstChild(state.active))
		return self:WalkFrame(dt, model)
	elseif mode == "Intro" then
		local progress = math.clamp((now - (self.started or now)) / 2.1, 0, 1)
		local axis = Vector3.new(.82 - progress * .55, 1.38 + progress * .20, 1).Unit
		return self:Fit(view, TABLE, axis, self:ScenePoints(true, false), 24)
	elseif mode == "Victory" then
		local model = state and self.characters:FindFirstChild(state.winner)
		local root = model and model.PrimaryPart
		if root and (root.Position - TABLE).Magnitude < 23 then
			local focus = root.Position + Vector3.new(0, 1.6, 0)
			local side = root.Position.Z > TABLE.Z and -1 or 1
			local pos = focus + Vector3.new(10, 5.7, side * 12)
			local hit = workspace:Spherecast(focus, .55, pos - focus, self.collision)
			if not hit then return CFrame.lookAt(pos, focus) end
		end
	end

	local axis = self.prefs.PrecisionView and OVERHEAD or self.tacticalAxis or OVERHEAD
	if mode == "Aiming" then
		if not self.aimFrame or self.aimViewport ~= view then
			self.aimFrame = self:Fit(view, TABLE, axis, self:ScenePoints(false, false), 18)
			self.aimViewport = view
			self.aimEntered = now
		end
		return self.aimFrame
	end
	local focus = TABLE
	if mode == "Tracking" and not self.prefs.ReducedMotion then
		local pen = state and self.pens:FindFirstChild(state.shotPen)
		local body = pen and pen.PrimaryPart
		if body then
			local offset = body.Position - TABLE
			focus += Vector3.new(math.clamp(offset.X * .22, -3, 3), 0, math.clamp(offset.Z * .22, -2.4, 2.4))
		end
	end
	return self:Fit(view, focus, axis, self:ScenePoints(false, true), 18)
end

function Camera:Step(dt)
	local camera = workspace.CurrentCamera
	if not camera then return end
	local view = camera.ViewportSize
	if view.X < 100 or view.Y < 100 then return end
	local now = os.clock()
	local state = self.state
	local mode = "FreeWalk"
	if self.menuActive then
		mode = "Menu"
	elseif not self.ready then
		mode = "Intro"
	elseif state and (state.phase == "Moving" or state.phase == "Falling") then
		mode = "Tracking"
	elseif state and state.phase == "Won" then
		mode = not self.prefs.ReducedMotion and now - (self.victoryAt or 0) < 1.25 and "Victory" or "Won"
	elseif state and state.aiming then
		mode = "Aiming"
	end
	self:SetMode(mode)
	self.hud:Layout(view)
	local target, focus = self:Target(dt, view, mode, now)
	self.frame = self.frame and self.frame:Lerp(target, approach(dt, mode == "Tracking" and 8 or 15)) or target
	if focus then
		local delta = self.frame.Position - focus
		if delta.Magnitude > 60 then
			self.frame = target
		elseif delta.Magnitude > .01 then
			local hit = workspace:Spherecast(focus, .5, delta, self.collision)
			if hit then self.frame = CFrame.lookAt(focus + delta.Unit * math.max(.45, hit.Distance - .25), focus) end
		end
	end
	local frame = self.frame
	if mode == "Aiming" then self:ClearAimSight(dt, frame) end
	local impactAge = now - self.impactAt
	if mode == "Tracking" and not self.prefs.ReducedMotion and impactAge < .18 then
		local nudge = math.sin(impactAge * 34) * (1 - impactAge / .18) * self.impactStrength
		frame *= CFrame.new(.12 * nudge, .045 * nudge, 0)
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = FOV
	camera.CFrame = frame
	self.AimStable = mode == "Aiming" and now - (self.aimEntered or now) > .28
	self.hud.SkipButton.Visible = not self.ready
	self.hud.Gui:SetAttribute("CameraStage", mode)
	self.hud.Gui:SetAttribute("IntroPlaying", not self.ready)
	if not self.ready and (self.prefs.ReducedMotion or now - (self.started or now) > 2.1) then self:Skip() end
end

return Camera
