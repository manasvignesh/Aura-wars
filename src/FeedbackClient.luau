-- Local-only effects driven by the accepted shot and server impact events.
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local Settings = require(game.ReplicatedStorage.PenFight.Settings)

local Feedback = {}
Feedback.__index = Feedback
local TABLE = Settings.Origin + Vector3.new(0, Settings.SurfaceY, 0)
local CHALK = Color3.fromRGB(246, 225, 166)

function Feedback.new(pens, hud, camera, audio, prefs, remote)
	local self = setmetatable({pens = pens, hud = hud, camera = camera, audio = audio, prefs = prefs, sample = 0}, Feedback)
	self.folder = Instance.new("Folder")
	self.folder.Name = "PenFightFeedback"
	self.folder.Parent = workspace
	remote.OnClientEvent:Connect(function(packet)
		if packet.kind == "Shot" then
			self:Shot(packet.pen, packet.round, packet.turn)
		elseif packet.kind == "Impact" then
			if hud.state and packet.round ~= hud.state.round then return end
			self:Pulse(packet.position, CHALK, packet.intensity)
			if packet.intensity >= .68 then self:Chalk(packet.position) end
			camera:Impact(packet.position, packet.intensity)
			audio:Impact(packet.intensity)
		elseif packet.kind == "Winner" then
			self:Winner(packet.winner, packet.round)
		elseif packet.kind == "Reset" then
			self.edge = nil
			self.folder:ClearAllChildren()
		end
	end)
	RunService.Heartbeat:Connect(function(dt) self:SampleEdge(dt) end)
	return self
end

function Feedback:EffectPart(name, position, color)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Position = position
	return part
end

function Feedback:Pulse(position, color, intensity)
	local part = self:EffectPart("ContactGlint", position, color)
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(.015, .32, .32)
	part.CFrame = CFrame.new(position.X, math.max(position.Y - .20, TABLE.Y + .06), position.Z) * CFrame.Angles(0, 0, math.pi / 2)
	part.Transparency = .63
	part.Parent = self.folder
	Debris:AddItem(part, .27)
	if not self.prefs.ReducedMotion then
		TweenService:Create(part, TweenInfo.new(.24), {
			Size = Vector3.new(.015, .5 + intensity, .5 + intensity),
			Transparency = 1,
		}):Play()
	end
end

function Feedback:Chalk(position)
	if self.prefs.ReducedMotion or self.hud.Gui:GetAttribute("ArtQuality") == "Simple" then return end
	for i = 1, 4 do
		local dot = self:EffectPart("ChalkFleck", position, CHALK)
		dot.Shape = Enum.PartType.Ball
		dot.Size = Vector3.one * .08
		dot.Parent = self.folder
		local angle = i * math.pi / 2 + .55
		local delta = Vector3.new(math.cos(angle) * .7, .23 + i * .03, math.sin(angle) * .7)
		TweenService:Create(dot, TweenInfo.new(.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = position + delta, Transparency = 1,
		}):Play()
		Debris:AddItem(dot, .24)
	end
end

function Feedback:Shot(id, round, turn)
	local key = round .. ":" .. turn
	if self.lastShot == key then return end
	self.lastShot = key
	local model = self.pens:FindFirstChild(id)
	if model and model.PrimaryPart then self:Pulse(model.PrimaryPart.Position, Settings[id], .20) end
	self.hud:Flash(id:upper() .. " FLICK", Color3.fromRGB(244, 226, 184), .55)
	self.audio:Play("Impact", .13, 1.62)
end

function Feedback:Winner(winner, round)
	if self.lastWinner == round then return end
	self.lastWinner = round
	self.hud:Flash(winner == "Draw" and "BOTH PENS DOWN  /  DRAW" or winner:upper() .. " WINS THE ROUND", CHALK, 1.35)
	self.audio:Winner()
end

function Feedback:SampleEdge(dt)
	if not self.edge then return end
	self.sample += dt
	if self.sample < .075 then return end
	self.sample = 0
	for _, model in ipairs(self.pens:GetChildren()) do
		local body = model:IsA("Model") and model.PrimaryPart
		if body then
			local offset = body.Position - TABLE
			local margin = math.min(Settings.DeskSize.X / 2 - math.abs(offset.X), Settings.DeskSize.Z / 2 - math.abs(offset.Z))
			if margin <= .55 and margin >= -.12 and offset.Y > .18 then self.edge.near[model.Name] = true end
		end
	end
end

function Feedback:SetState(state)
	if state.phase == "Moving" or state.phase == "Falling" then
		if not self.edge or self.edge.shot ~= state.shotId then
			self.edge = {shot = state.shotId, round = state.round, near = {}}
		end
		return
	end
	local watch = self.edge
	self.edge = nil
	if not watch or watch.round ~= state.round or state.phase ~= "Aiming" then return end
	for id in pairs(watch.near) do
		local model = self.pens:FindFirstChild(id)
		local body = model and model.PrimaryPart
		if body and body.Position.Y > TABLE.Y + .12 then
			self:Pulse(body.Position, CHALK, .25)
			self.hud:Flash(id:upper() .. " STAYS ON", CHALK, .75)
			return
		end
	end
end

return Feedback
