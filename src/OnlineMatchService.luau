local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Shared = game.ReplicatedStorage.PenFight
local Settings = require(Shared.Settings)
local Rules = require(Shared.OnlineRules)
local Physics = require(script.Parent.PenPhysics)
local Catalog = require(Shared.PenCatalog)
local Factory = require(script.Parent.PenFactory)

local Match = {}
Match.__index = Match
local PHASE = {
	WaitingForPlayers = "Waiting", Introduction = "Introduction", Positioning = "Aiming",
	Aiming = "Aiming", ShotInProgress = "Moving", RoundResult = "Won",
	MatchResult = "Won", Rematch = "Won",
}
local function other(id) return id == "Blue" and "Red" or "Blue" end
local function finite(n) return type(n) == "number" and n == n and math.abs(n) < math.huge end
local function guid() return HttpService:GenerateGUID(false) end

function Match:Snapshot()
	local blue, red = self.slots.Blue, self.slots.Red
	local owner = self.slots[self.active]
	local character = self.avatars:GetCharacter(self.active)
	return {
		mode = "Online", gameKind = self.kind or "Online", revision = self.revision, matchId = self.matchId, turnToken = self.turnToken,
		matchPhase = self.stage, phase = self.phase, round = self.round, turn = self.turn,
		roundIndex = self.roundIndex, active = self.active,
		controller = owner and owner.UserId or 0,
		blueUserId = blue and blue.UserId or 0, redUserId = red and red.UserId or 0,
		blueName = self.kind == "Hotseat" and "Local Player 1" or blue and blue.Name or "Waiting for Blue",
		redName = self.kind == "Practice" and "Target pen" or self.kind == "Hotseat" and "Local Player 2" or red and red.Name or "Waiting for Red",
		blueWins = self.blueWins, redWins = self.redWins, draws = self.draws,
		winner = self.winner, matchWinner = self.matchWinner, message = self.message,
		blueRematch = self.votes.Blue == true, redRematch = self.votes.Red == true,
		aiming = character ~= nil and character:GetAttribute("Aiming") == true,
		turnDeadline = self.deadline, warningSeconds = Rules.WarningSeconds,
		shotId = self.shotId, shotPen = self.shotPen, shotCharge = self.shotCharge,
	}
end

function Match:Publish()
	self.revision += 1
	local packet = self:Snapshot()
	for key, value in pairs(packet) do
		if key ~= "revision" then self.state:SetAttribute(key, value) end
	end
	self.state:SetAttribute("revision", self.revision)
	self.remotes.StateChanged:FireAllClients(packet)
end

function Match:SetStage(stage, message)
	self.stage, self.phase = stage, PHASE[stage]
	self.message = message
end

function Match:Slot(player)
	if self.kind == "Hotseat" and self.slots.Blue == player then return self.active ~= "" and self.active or "Blue" end
	for id, owner in pairs(self.slots) do if player == owner then return id end end
	return nil
end

function Match:BeginRound()
	self.round += 1
	self.roundIndex = self.blueWins + self.redWins + 1
	self.turn, self.active, self.winner = 1, "Blue", ""
	self.turnToken, self.deadline = guid(), 0
	self.elapsed, self.restTime, self.fallTime = 0, 0, 0
	Physics.Reset(self.pens)
	self.avatars:Reset()
	if self.hooks.Reset then self.hooks.Reset(self.round) end
	self:SetStage("Introduction", self.kind == "Practice" and "Practice • aim at the target pen" or "Blue versus Red • best of three")
	self.due = workspace:GetServerTimeNow() + Rules.IntroductionSeconds
	self:Publish()
end

function Match:BeginMatch()
	self.matchId = guid()
	self.blueWins, self.redWins, self.draws = 0, 0, 0
	self.matchWinner, self.votes = "", {}
	self.matchShots, self.hadTimeout, self.completionSent = {}, false, false
	self:BeginRound()
end

function Match:BeginTurn(id, message)
	self.active, self.turnToken = id, guid()
	self.deadline = self.kind == "Practice" and 0 or workspace:GetServerTimeNow() + self.turnSeconds
	self.elapsed, self.restTime, self.fallTime = 0, 0, 0
	self.avatars:SetActiveCharacter(id)
	self:SetStage("Positioning", message or (self.slots[id].Name .. " • approach your " .. id .. " pen"))
	self:Publish()
end

function Match:Resolve(winner, reason)
	if self.kind == "Practice" then self:BeginRound(); return end
	self.winner, self.deadline, self.turnToken = winner, 0, guid()
	if winner == "Blue" then self.blueWins += 1
	elseif winner == "Red" then self.redWins += 1
	else self.draws += 1 end
	self.avatars:Winner(winner)
	if self.hooks.Winner then self.hooks.Winner(winner, self.round) end
	self:SetStage("RoundResult", reason or (winner == "Draw" and "Draw • replaying this round" or winner .. " wins the round"))
	self.due = workspace:GetServerTimeNow() + (winner == "Draw" and Rules.DrawReplaySeconds or Rules.ResultSeconds)
	self:Publish()
	if self.onCompleted and self.kind == "Online" and not self.hadTimeout and not self.completionSent
		and self.matchShots.Blue and self.matchShots.Red and winner ~= "Draw"
		and math.max(self.blueWins, self.redWins) >= Rules.WinsRequired then
		self.completionSent = true
		self.onCompleted(self.slots.Blue, self.slots.Red, self.matchId, winner)
	end
end

function Match:Cancel(message)
	self.matchId, self.turnToken = guid(), guid()
	self.deadline, self.due = 0, 0
	self.blueWins, self.redWins, self.draws = 0, 0, 0
	self.winner, self.matchWinner, self.votes, self.active = "", "", {}, ""
	Physics.Reset(self.pens)
	self.avatars:Waiting()
	self:SetStage("WaitingForPlayers", message or "Waiting for two players")
	self:Publish()
end

function Match:MaybeStart()
	if self.stage ~= "WaitingForPlayers" then return end
	for _, id in ipairs({"Blue", "Red"}) do
		if self.kind == "Practice" and id == "Red" then continue end
		local player, model = self.slots[id], self.avatars:GetCharacter(id)
		if not player or player.Parent ~= Players or not model or model.Humanoid.Health <= 0 then return end
	end
	self:BeginMatch()
end

function Match:StartSession(kind, blue, red, finishes, ended)
	if self.sessionEnded then return false end
	self.kind, self.sessionEnded = kind, ended
	self.slots = {Blue = blue, Red = kind == "Hotseat" and blue or red}
	for id, pen in pairs(self.pens) do
		Catalog.Paint(pen, id, finishes[id])
		Factory.ApplyHandling(pen, finishes[id])
	end
	self:Publish()
	local function ready()
		if self.sessionEnded == ended then self:MaybeStart() end
	end
	if kind == "Hotseat" then self.avatars:StartHotseat(blue, ready)
	else
		self.avatars:Assign("Blue", blue, ready)
		if red then self.avatars:Assign("Red", red, ready) end
	end
	return true
end

function Match:EndSession(message)
	local ended = self.sessionEnded
	if not ended then return end
	self.sessionEnded = nil
	self.avatars:Remove("Blue")
	self.avatars:Remove("Red")
	self.avatars.controller = nil
	self.slots, self.kind = {}, nil
	for id, pen in pairs(self.pens) do
		Catalog.Paint(pen, id, Catalog.Default)
		Factory.ApplyHandling(pen, Catalog.Default)
	end
	self:Cancel(message)
	ended(message)
end

function Match:FillSlots(exclude)
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= exclude and not self:Slot(player) then
			local id = not self.slots.Blue and "Blue" or not self.slots.Red and "Red" or nil
			if id then
				self.slots[id] = player
				player:SetAttribute("PenFightSlot", id)
				self.avatars:Assign(id, player, function() self:MaybeStart() end)
			else player:SetAttribute("PenFightSlot", "Spectator") end
		end
	end
	self:Publish()
	self:MaybeStart()
end

function Match:PlayerLeft(player)
	self.requests[player] = nil
	local id = self:Slot(player)
	if not id then return end
	self.slots[id] = nil
	self.avatars:Remove(id)
	self:Cancel(player.Name .. " disconnected • match cancelled")
	self:FillSlots(player)
end

function Match:Handle(player, request)
	if type(request) ~= "table" then return false, "Malformed request" end
	local id = self:Slot(player)
	if not id then return false, "You are observing this desk." end
	local bucket = self.requests[player]
	if not bucket then bucket = {last = 0, credit = 8, at = os.clock()}; self.requests[player] = bucket end
	local now = os.clock()
	bucket.credit = math.min(8, bucket.credit + (now - bucket.at) * 10)
	bucket.at = now
	if bucket.credit < 1 then return false, "Too many requests. Release and try again." end
	bucket.credit -= 1
	if not finite(request.id) or request.id % 1 ~= 0 or request.id <= bucket.last or request.id > 1e9 then
		return false, "Duplicate or invalid request sequence"
	end
	bucket.last = request.id
	if request.matchId ~= self.matchId or request.turnToken ~= self.turnToken
		or request.round ~= self.round or request.turn ~= self.turn then return false, "Match or turn changed. Try again." end
	if request.action == "Rematch" then
		if self.stage ~= "MatchResult" and self.stage ~= "Rematch" then return false, "Finish the match first." end
		self.votes[id] = true
		if self.kind == "Hotseat" then self.votes.Blue, self.votes.Red = true, true end
		self:SetStage("Rematch", "Rematch • waiting for both players")
		if self.votes.Blue and self.votes.Red then
			self.message = "Both players accepted • starting rematch"
			self.due = workspace:GetServerTimeNow() + Rules.RematchSeconds
		end
		self:Publish()
		return true
	end
	if request.action == "PracticeReset" and self.kind == "Practice" then self:BeginRound(); return true end
	if request.action ~= "Aim" and request.action ~= "Flick" then return false, "Action unavailable in online matches" end
	if id ~= self.active or request.pen ~= id then return false, "Only the active player can use their own pen." end
	if self.stage ~= "Positioning" and self.stage ~= "Aiming" then return false, "Wait for your turn." end
	if Physics.HasFallen(self.pens.Blue) or Physics.HasFallen(self.pens.Red) then return false, "A pen is falling. Wait for the result." end
	if self.deadline > 0 and workspace:GetServerTimeNow() >= self.deadline then return false, "Turn time expired" end
	if request.action == "Aim" then
		if type(request.aiming) ~= "boolean" then return false, "Invalid aim state" end
		if request.aiming then
			local ok, reason = self.avatars:ValidateReach(player, id, nil)
			if not ok then return false, reason end
		end
		self.avatars:SetAiming(id, request.aiming)
		self:SetStage(request.aiming and "Aiming" or "Positioning", request.aiming and "Pull back and release" or "Choose your approach")
		self:Publish()
		return true
	end
	if self.stage ~= "Aiming" or not self.avatars:GetCharacter(id):GetAttribute("Aiming") then return false, "Approach your pen and enter aim first." end
	if not Physics.IsResting(self.pens) then return false, "Pens are still moving" end
	local direction, power, offset = request.direction, request.power, request.offset
	if typeof(direction) ~= "Vector3" or not finite(direction.X) or not finite(direction.Y) or not finite(direction.Z)
		or math.abs(direction.Y) > .001 or math.abs(direction.Magnitude - 1) > .02 then return false, "Invalid planar direction" end
	if not finite(power) or power < Settings.MinPower or power > 1 then return false, "Invalid power" end
	if not finite(offset) or math.abs(offset) > Settings.MaxContactOffset then return false, "Invalid contact offset" end
	local ok, reason = Physics.CanFlick(self.pens[id])
	if not ok then return false, reason end
	direction = Vector3.new(direction.X, 0, direction.Z).Unit
	ok, reason = self.avatars:ValidateReach(player, id, direction)
	if not ok then return false, reason end
	if Physics.HasFallen(self.pens[id]) then return false, "Pen has fallen" end
	-- Commit before impulse and without yielding. Further requests cannot reuse this turn.
	self:SetStage("ShotInProgress", id .. " flicked • pens in motion")
	self.deadline, self.elapsed, self.restTime, self.fallTime = 0, 0, 0, 0
	self.shotId += 1
	self.matchShots[id] = true
	self.shotPen, self.shotCharge = id, power
	local speed = Physics.Flick(self.pens[id], direction, power, offset)
	self.avatars:Shot(id, power, offset, direction)
	if self.hooks.Shot then self.hooks.Shot(id, self.round, self.turn, power, speed, self.pens[id].PrimaryPart.Position, direction) end
	self:Publish()
	return true
end

function Match:Step(dt)
	Physics.Step(self.pens, dt)
	local now = workspace:GetServerTimeNow()
	if self.stage == "Positioning" or self.stage == "Aiming" or self.stage == "ShotInProgress" then
		local blueDown, redDown = Physics.HasFallen(self.pens.Blue), Physics.HasFallen(self.pens.Red)
		if blueDown or redDown then
			self.fallTime += dt
			if self.phase ~= "Falling" then self.phase = "Falling"; self:Publish() end
			if self.fallTime >= Settings.FallGrace then
				self:Resolve(blueDown and redDown and "Draw" or blueDown and "Red" or "Blue")
			end
			return
		end
		self.fallTime = 0
	end
	if self.stage == "Introduction" then
		if now >= self.due then
			Physics.Stop(self.pens)
			self:BeginTurn("Blue")
		end
	elseif self.stage == "Positioning" or self.stage == "Aiming" then
		if self.deadline > 0 and now >= self.deadline then
			self.hadTimeout = true
			self:Resolve(other(self.active), self.active .. " timed out • round lost")
		end
	elseif self.stage == "ShotInProgress" then
		self.elapsed += dt
		self.restTime = Physics.IsResting(self.pens) and self.restTime + dt or 0
		if (self.elapsed > Settings.MinShotTime and self.restTime >= Settings.RestDuration) or self.elapsed > Settings.MaxShotTime then
			Physics.Stop(self.pens)
			self.turn += 1
			self:BeginTurn(self.kind == "Practice" and "Blue" or other(self.active))
		end
	elseif self.stage == "RoundResult" and now >= self.due then
		if math.max(self.blueWins, self.redWins) >= Rules.WinsRequired then
			self.matchWinner = self.blueWins >= Rules.WinsRequired and "Blue" or "Red"
			self:SetStage("MatchResult", self.matchWinner .. " wins the match • both players can vote for a rematch")
			self:Publish()
		else self:BeginRound() end
	elseif self.stage == "Rematch" and self.votes.Blue and self.votes.Red and now >= self.due then
		self:BeginMatch()
	end
end

function Match.Start(pens, hooks, avatars, managed)
	local self = setmetatable({pens = pens, hooks = hooks, avatars = avatars, slots = {}, requests = {},
		votes = {}, revision = 0, round = 0, roundIndex = 0, turn = 0, active = "", winner = "", matchWinner = "",
		blueWins = 0, redWins = 0, draws = 0, shotId = 0, shotPen = "", shotCharge = 0,
		deadline = 0, matchId = guid(), turnToken = guid(), turnSeconds = Rules.TurnSeconds}, Match)
	self.state, self.remotes = Shared.State, Shared.Remotes
	-- Studio-only timer override makes timeout QA practical without changing shipped rules.
	if RunService:IsStudio() then
		local seconds = Shared:GetAttribute("StudioTurnSeconds")
		if finite(seconds) and seconds >= 3 and seconds <= 180 then self.turnSeconds = seconds end
	end
	self:Cancel()
	avatars.onDeath = function(player)
		local id = self:Slot(player)
		if not id then return end
		if managed then self:EndSession(player.Name .. " respawned • session ended"); return end
		self:Cancel(player.Name .. " is respawning • match cancelled")
		avatars:Assign(id, player, function() self:MaybeStart() end)
	end
	self.remotes.Snapshot.OnServerInvoke = function() return self:Snapshot() end
	self.remotes.Request.OnServerEvent:Connect(function(player, request)
		local ok, reason = self:Handle(player, request)
		local requestId = type(request) == "table" and request.id or 0
		if not finite(requestId) or math.abs(requestId) > 1e9 then requestId = 0 end
		local action = type(request) == "table" and request.action or "Malformed"
		self.state:SetAttribute("LastRequestAction", type(action) == "string" and action:sub(1,20) or "Malformed")
		self.state:SetAttribute("LastRequestAccepted", ok == true)
		self.state:SetAttribute("LastRequestReason", reason or "Accepted")
		if action == "Flick" then
			local key = ok and "AcceptedShots" or "RejectedShots"
			self.state:SetAttribute(key, (self.state:GetAttribute(key) or 0) + 1)
		end
		self.remotes.Result:FireClient(player, {id = requestId, action = type(action) == "string" and action:sub(1,20) or "Malformed",
			accepted = ok == true, reason = reason, state = self:Snapshot()})
	end)
	if not managed then
		Players.PlayerAdded:Connect(function() self:FillSlots() end)
		Players.PlayerRemoving:Connect(function(player) self:PlayerLeft(player) end)
		self:FillSlots()
	else Players.PlayerRemoving:Connect(function(player) self.requests[player] = nil end) end
	RunService.Heartbeat:Connect(function(dt) self:Step(dt) end)
	Match.Current = self
	return self
end

return Match
