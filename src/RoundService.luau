local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game.ReplicatedStorage.PenFight
local Settings = require(Shared.Settings)
local Physics = require(script.Parent.PenPhysics)
local Round = {}
Round.__index = Round

local function finite(n)
	return type(n) == "number" and n == n and math.abs(n) < math.huge
end

function Round:Snapshot()
	return {
		revision = self.revision,
		phase = self.phase,
		active = self.active,
		turn = self.turn,
		round = self.round,
		winner = self.winner,
		blueWins = self.blueWins,
		redWins = self.redWins,
		draws = self.draws,
		controller = self.controller and self.controller.UserId or 0,
		message = self.message,
		blueName = self.controller and self.controller.DisplayName or "Waiting for player",
		redName = "Practice Opponent",
		shotId = self.shotId or 0,
		shotPen = self.shotPen or "",
		shotCharge = self.shotCharge or 0,
		aiming = self.avatars and self.avatars:GetCharacter(self.active) and self.avatars:GetCharacter(self.active):GetAttribute("Aiming")==true or false,
	}
end

function Round:Publish()
	self.revision = (self.revision or 0) + 1
	local state = self:Snapshot()
	for k, v in pairs(state) do
		if k ~= "revision" then
			self.stateFolder:SetAttribute(k, v)
		end
	end
	self.stateFolder:SetAttribute("revision", self.revision)
	self.changed:FireAllClients(state)
end

function Round:Reset()
	Physics.Reset(self.pens)
	self.round += 1
	self.turn = 1
	self.active = "Blue"
	self.phase = "Settling"
	self.winner = ""
	self.message = "Pens settling onto the desk…"
	self.elapsed, self.restTime, self.fallTime = 0, 0, 0
	if self.avatars then
		self.avatars:Reset()
	end
	if self.hooks.Reset then
		self.hooks.Reset(self.round)
	end
	self:Publish()
end

function Round:Handle(player, request)
	if type(request) ~= "table" then return false, "Malformed request" end
	if player ~= self.controller then return false, "Spectator" end
	local now = os.clock()
	local action=request.action
	if type(action)~="string" then return false,"Unknown action. Try again." end
	if action~="Aim" and action~="Flick" and action~="Reset" then return false,"Unknown action. Try again." end
	local clocks=self.lastRequest[player] or {};self.lastRequest[player]=clocks
	if now-(clocks[action] or -math.huge)<.08 then return false,"Please release once, then wait for the server." end
	clocks[action]=now

	if request.action == "Reset" then
		if now - self.lastReset < 1 then return false, "Reset cooldown" end
		self.lastReset = now
		self:Reset()
		return true
	end

	if request.action == "Aim" then
		if self.phase~="Aiming" then return false,"Wait for both pens to settle." end
		if request.round~=self.round or request.turn~=self.turn or request.pen~=self.active then return false,"Turn changed. Approach the active pen." end
		if request.aiming==true then
			local ok,reason=self.avatars:ValidateReach(player,self.active,nil)
			if not ok then return false,reason end
		end
		self.avatars:SetAiming(self.active,request.aiming==true)
		self:Publish()
		return true
	end

	if request.action ~= "Flick" or self.phase ~= "Aiming" then return false, "Not aiming" end
	if request.round ~= self.round or request.turn ~= self.turn or request.pen ~= self.active then
		return false, "Stale or wrong turn"
	end
	if not Physics.IsResting(self.pens) then return false, "Pens moving" end
	if self.avatars and not self.avatars:GetCharacter(self.active):GetAttribute("Aiming") then return false,"Press E or tap AIM before dragging your pen." end

	local d, power, offset = request.direction, request.power, request.offset
	if typeof(d) ~= "Vector3" or not finite(d.X) or not finite(d.Y) or not finite(d.Z) then
		return false, "Invalid direction"
	end
	if math.abs(d.Y) > 0.001 or d.Magnitude < 0.98 or d.Magnitude > 1.02 then
		return false, "Direction must be planar and unit length"
	end
	if not finite(power) or power < Settings.MinPower or power > 1 then return false, "Invalid power" end
	if not finite(offset) or math.abs(offset) > Settings.MaxContactOffset + 0.01 then return false, "Invalid contact" end
	if Physics.HasFallen(self.pens[self.active]) then return false, "Pen has fallen" end
	local physical,physicalReason=Physics.CanFlick(self.pens[self.active])
	if not physical then return false,physicalReason end

	-- Server-authoritative position and reach validation
	local direction = Vector3.new(d.X, 0, d.Z).Unit
	if self.avatars then
		local ok, reason = self.avatars:ValidateReach(player, self.active, direction)
		if not ok then
			return false, reason
		end
	end

	-- Lock the turn before applying physics; repeated events cannot shoot twice.
	self.phase = "Moving"
	self.message = self.active .. " flicked • tracking pen movement"
	self.elapsed, self.restTime = 0, 0
	local speed = Physics.Flick(self.pens[self.active], direction, power, offset)
	self.shotId = (self.shotId or 0) + 1
	self.shotPen = self.active
	self.shotCharge = power

	if self.avatars then
		self.avatars:Shot(self.active, power, offset, direction)
	end
	if self.hooks.Shot then
		self.hooks.Shot(self.active, self.round, self.turn, power, speed, self.pens[self.active].PrimaryPart.Position, direction)
	end
	self:Publish()
	return true
end

function Round:Step(dt)
	Physics.Step(self.pens, dt)
	if self.phase == "Won" then return end

	local blueDown, redDown = Physics.HasFallen(self.pens.Blue), Physics.HasFallen(self.pens.Red)
	if blueDown or redDown then
		self.fallTime += dt
		if self.phase ~= "Falling" then
			self.phase = "Falling"
			self.message = "Pen off the desk…"
			self:Publish()
		end
		if self.fallTime >= Settings.FallGrace then
			self.phase = "Won"
			self.winner = if blueDown and redDown then "Draw" elseif blueDown then "Red" else "Blue"
			if self.winner == "Blue" then
				self.blueWins += 1
			elseif self.winner == "Red" then
				self.redWins += 1
			else
				self.draws += 1
			end
			self.message = if self.winner == "Draw" then "Both pens fell • draw!" else self.winner .. " wins the round!"
			if self.avatars then
				self.avatars:Winner(self.winner)
			end
			if self.hooks.Winner then
				self.hooks.Winner(self.winner, self.round)
			end
			self:Publish()
		end
		return
	end

	self.fallTime = 0
	if self.phase == "Moving" or self.phase == "Settling" then
		self.elapsed += dt
		self.restTime = if Physics.IsResting(self.pens) then self.restTime + dt else 0
		if (self.elapsed > Settings.MinShotTime and self.restTime > Settings.RestDuration) or self.elapsed > Settings.MaxShotTime then
			Physics.Stop(self.pens)
			if self.phase == "Moving" then
				self.active = if self.active == "Blue" then "Red" else "Blue"
				self.turn += 1
				if self.avatars then
					self.avatars:SetActiveCharacter(self.active)
				end
			end
			self.phase = "Aiming"
			self.message = self.active .. "'s Turn • Walk to your pen and flick!"
			self:Publish()
		end
	end
end

function Round.Start(pens, hooks, avatars)
	local self = setmetatable({
		pens = pens,
		hooks = hooks or {},
		avatars = avatars,
		round = 0,
		turn = 0,
		phase = "Settling",
		active = "Blue",
		winner = "",
		blueWins = 0,
		redWins = 0,
		draws = 0,
		message = "",
		lastRequest = {},
		lastReset = -math.huge,
	}, Round)

	self.stateFolder = Shared.State
	self.changed = Shared.Remotes.StateChanged
	self.controller = Players:GetPlayers()[1]

	if self.hooks.ControllerChanged then
		self.hooks.ControllerChanged(self.controller)
	end

	Players.PlayerAdded:Connect(function(player)
		if not self.controller then
			self.controller = player
			if self.hooks.ControllerChanged then
				self.hooks.ControllerChanged(player)
			end
		end
		self:Publish()
	end)

	Players.PlayerRemoving:Connect(function(player)
		self.lastRequest[player] = nil
		if self.controller == player then
			self.controller = nil
			self.blueWins, self.redWins, self.draws = 0, 0, 0
			for _, other in ipairs(Players:GetPlayers()) do
				if other ~= player then
					self.controller = other
					break
				end
			end
			if self.hooks.ControllerChanged then
				self.hooks.ControllerChanged(self.controller)
			end
			self:Reset()
		end
	end)

	Shared.Remotes.Snapshot.OnServerInvoke = function()
		return self:Snapshot()
	end

	Shared.Remotes.Request.OnServerEvent:Connect(function(player, request)
		local ok,reason=self:Handle(player,request)
		local action=type(request)=="table" and request.action or "Malformed"
		local id=type(request)=="table" and request.id or 0
		if type(id)~="number" or id~=id or math.abs(id)>1e9 then id=0 end
		self.stateFolder:SetAttribute("LastRequestAction",tostring(action))
		self.stateFolder:SetAttribute("LastRequestAccepted",ok==true)
		self.stateFolder:SetAttribute("LastRequestReason",reason or "Accepted")
		if action=="Flick" then
			local key=ok and "AcceptedShots" or "RejectedShots"
			self.stateFolder:SetAttribute(key,(self.stateFolder:GetAttribute(key) or 0)+1)
		end
		if Shared:GetAttribute("DebugTrace") then print("[PF3 request]",action,id,ok,reason or "Accepted") end
		Shared.Remotes.Result:FireClient(player,{id=id,action=action,accepted=ok==true,reason=reason,state=self:Snapshot()})
	end)

	self:Reset()
	RunService.Heartbeat:Connect(function(dt)
		self:Step(dt)
	end)

	Round.Current = self
	return self
end

return Round
