local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Base = require(script.Parent.AvatarService)
local S = require(game.ReplicatedStorage.PenFight.Settings)
local T = require(game.ReplicatedStorage.PenFight.PhysicsTuning)
local Reach = require(game.ReplicatedStorage.PenFight.ReachRules)
local SchoolStyle = require(script.Parent.SchoolStyle)

local Avatar = {}
Avatar.__index = Avatar
setmetatable(Avatar, {__index = Base})

local function spawnFrame(model, id)
	local root, humanoid = model.PrimaryPart, model.Humanoid
	local y = S.FloorY + humanoid.HipHeight + root.Size.Y / 2 + .08
	local p = S.Origin + Vector3.new(id == "Blue" and -S.SpawnX or S.SpawnX, y,
		id == "Blue" and -S.CharacterSpawnZ or S.CharacterSpawnZ)
	return CFrame.lookAt(p, Vector3.new(p.X, p.Y, S.Origin.Z))
end

function Avatar.Start()
	local self = Base.Start()
	setmetatable(self, Avatar)
	for _, model in pairs(self.characters) do model:Destroy() end
	self.characters = {}
	self.owners, self.guards, self.deaths = {}, {}, {}
	self.activeId = ""
	self.guardRay = RaycastParams.new()
	self.guardRay.FilterType = Enum.RaycastFilterType.Exclude
	local arena = workspace.PenFight
	self.guardRay.FilterDescendantsInstances = {arena.Characters, arena.Pens, arena.Spectators, self.targets}
	self.guardRay.RespectCanCollide = true
	self.guardRay.CollisionGroup = "Characters"
	self.guardClock = 0
	RunService.Heartbeat:Connect(function(dt)
		self.guardClock += dt
		if self.guardClock < .10 then return end
		local elapsed = self.guardClock
		self.guardClock = 0
		for id in pairs(self.characters) do self:ValidatePosition(id, elapsed) end
	end)
	return self
end

function Avatar:Remember(id)
	local model = self.characters[id]
	if model and model.PrimaryPart then
		self.guards[id] = {frame = model.PrimaryPart.CFrame, credit = 4, at = os.clock()}
	end
end

function Avatar:ValidatePosition(id)
	local model, guard = self.characters[id], self.guards[id]
	if not model or not model.PrimaryPart or not guard then return false end
	local root = model.PrimaryPart
	local now = os.clock()
	guard.credit = math.min(4, guard.credit + T.WalkSpeed * 1.35 * math.max(0, now - guard.at))
	guard.at = now
	local delta = root.Position - guard.frame.Position
	local invalid = delta.Magnitude ~= delta.Magnitude or delta.Magnitude > guard.credit
	if not invalid and delta.Magnitude > .08 then
		local hit = workspace:Spherecast(guard.frame.Position, .42, delta, self.guardRay)
		invalid = hit ~= nil and hit.Distance + .20 < delta.Magnitude
	end
	if root.Position.Y < S.FloorY or root.Position.Y > S.SurfaceY + 1 then invalid = true end
	if invalid then
		root.CFrame = guard.frame
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		model:SetAttribute("MovementCorrections", (model:GetAttribute("MovementCorrections") or 0) + 1)
		return false
	end
	guard.credit = math.max(0, guard.credit - delta.Magnitude)
	guard.frame = root.CFrame
	return true
end

function Avatar:Assign(id, player, ready)
	self:Remove(id)
	self.owners[id] = player
	local token = (self.tokens[id] or 0) + 1
	self.tokens[id] = token
	local installed = false
	local function install(model, actual)
		if installed or self.tokens[id] ~= token or player.Parent ~= Players then model:Destroy(); return end
		installed = true
		Base.Prepare(model, id, player.Name, player.UserId)
		model:SetAttribute("AppearanceStatus", actual and "PlayerAvatar" or "Fallback")
		SchoolStyle.Apply(model, id, actual)
		model.Parent = self.folder
		self.characters[id] = model
		self:InstallIK(model, id)
		player.Character = model
		self:Remember(id)
		self:SetAiming(id, false)
		self.deaths[id] = model.Humanoid.Died:Connect(function()
			if self.owners[id] == player and self.onDeath then self.onDeath(player) end
		end)
		ready()
	end
	-- Appearance requests can yield. A late response cannot replace a playing character.
	task.delay(6, function()
		if not installed and self.tokens[id] == token then install(self.template:Clone(), false) end
	end)
	task.spawn(function()
		local ok, model = pcall(function()
			local description = Players:GetHumanoidDescriptionFromUserIdAsync(player.UserId)
			return Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15)
		end)
		if ok then install(model, true)
		elseif not installed and self.tokens[id] == token then install(self.template:Clone(), false) end
	end)
end

function Avatar:Remove(id)
	self.tokens[id] = (self.tokens[id] or 0) + 1
	if self.deaths[id] then self.deaths[id]:Disconnect(); self.deaths[id] = nil end
	local model = self.characters[id]
	if model then
		local owner = self.owners and self.owners[id] or self.controller
		if owner and owner.Character == model then owner.Character = nil end
		model:Destroy()
	end
	self.characters[id] = nil
	if self.owners then self.owners[id] = nil end
	if self.guards then self.guards[id] = nil end
	local target = self.targets:FindFirstChild(id)
	if target then target:Destroy() end
end

function Avatar:StartHotseat(player, ready)
	self.controller = player
	Base.SetParticipant(self, "Red", nil)
	local red = self.characters.Red
	red:SetAttribute("ParticipantName", "Local Player 2")
	red.ParticipantLabel.TextLabel.Text = "RED • LOCAL PLAYER 2"
	self:Assign("Blue", player, ready)
end

function Avatar:SetActiveCharacter(id)
	if self.controller then
		Base.SetActiveCharacter(self, id)
		for color in pairs(self.characters) do self:Remember(color) end
		if self.deaths.Hotseat then self.deaths.Hotseat:Disconnect(); self.deaths.Hotseat = nil end
		local model, player = self.characters[id], self.controller
		if model then self.deaths.Hotseat = model.Humanoid.Died:Connect(function()
			if self.controller == player and self.onDeath then self.onDeath(player) end
		end) end
		return
	end
	self.activeId = id
	for color, model in pairs(self.characters) do
		model:SetAttribute("ActiveTurn", color == id)
		self:SetAiming(color, false)
	end
end

function Avatar:SetAiming(id, aiming)
	if self.controller then Base.SetAiming(self, id, aiming); self:Remember(id); return end
	local model = self.characters[id]
	if not model or not model.PrimaryPart then return end
	local root, humanoid = model.PrimaryPart, model.Humanoid
	model:SetAttribute("Aiming", aiming)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	humanoid.WalkSpeed = aiming and 0 or T.WalkSpeed
	humanoid.AutoRotate = not aiming
	if aiming then
		if not root.Anchored then root:SetNetworkOwner(nil) end
		local p = root.Position
		local pen = workspace.PenFight.Pens[id].PrimaryPart.Position
		root.CFrame = CFrame.lookAt(p, Vector3.new(pen.X, p.Y, pen.Z))
		root.Anchored = true
	else
		root.Anchored = false
		root:SetNetworkOwner(self.owners[id])
	end
	self:Remember(id)
end

function Avatar:ValidateReach(player, id, direction)
	if self.controller then
		if not self:ValidatePosition(id) then return false, "Movement corrected" end
		return Base.ValidateReach(self, player, id, direction)
	end
	if self.owners[id] ~= player or id ~= self.activeId then return false, "Only your active pen can be flicked." end
	local model = self.characters[id]
	if not model or player.Character ~= model then return false, "Your character is loading." end
	if not self:ValidatePosition(id) then return false, "Movement corrected. Walk to your pen again." end
	return Reach.Check(model, workspace.PenFight.Pens[id], direction, true)
end

function Avatar:Shot(id, power, offset, direction)
	Base.Shot(self, id, power, offset, direction)
	if self.controller then return end
	local model = self.characters[id]
	-- Brief arm follow-through. Ownership always stays with the assigned player.
	task.delay(.24, function()
		if self.characters[id] == model and model and model:GetAttribute("Outcome") == "" then
			self:SetAiming(id, false)
		end
	end)
end

function Avatar:Reset()
	for id, model in pairs(self.characters) do
		model:SetAttribute("Outcome", "")
		model:SetAttribute("ShotAt", 0)
		model:PivotTo(spawnFrame(model, id))
		self:Remember(id)
	end
	self:SetActiveCharacter("Blue")
end

function Avatar:Waiting()
	self.activeId = ""
	for id, model in pairs(self.characters) do
		model:SetAttribute("Outcome", "")
		model:SetAttribute("ActiveTurn", false)
		self:SetAiming(id, false)
	end
end

return Avatar
