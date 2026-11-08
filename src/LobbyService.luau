local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Shared = game.ReplicatedStorage.PenFight
local Catalog = require(Shared.PenCatalog)
local Progression = require(script.Parent.ProgressionService)
local Lobby = {}
Lobby.__index = Lobby
local INVITE_SECONDS = 25
local COUNTDOWN_SECONDS = 3

local function now() return workspace:GetServerTimeNow() end
local function identity(player)
	return {userId = player.UserId, name = player.Name, displayName = player.DisplayName}
end

function Lobby:State(player)
	local entry = self.entries[player]
	if not entry then return nil end
	local progress = self.progress:View(player)
	local state = {revision = self.revision, status = entry.status, equipped = progress.equipped, progress = progress,
		message = entry.message, queueSince = entry.queueSince or 0, busy = self.reservation ~= nil}
	local invite = self.invites[player]
	if invite then
		state.invite = {id = invite.id, incoming = invite.to == player, expires = invite.expires,
			peer = identity(invite.to == player and invite.from or invite.to)}
	end
	local room = self.reservation
	if room and (room.blue == player or room.red == player) then
		state.room = {id = room.id, mode = room.mode, countdown = room.countdown or 0,
			blue = identity(room.blue), red = room.red and identity(room.red) or nil,
			loadingProfiles = self.progress:IsLoading(room.blue) or (room.red ~= nil and self.progress:IsLoading(room.red)),
			blueReady = room.ready[room.blue] == true, redReady = room.red ~= nil and room.ready[room.red] == true}
	end
	state.eligible = {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and self:IsAvailable(other) then table.insert(state.eligible, identity(other)) end
	end
	return state
end

function Lobby:Publish()
	self.revision += 1
	for player in pairs(self.entries) do
		if player.Parent == Players then self.push:FireClient(player, self:State(player)) end
	end
end

function Lobby:IsAvailable(player)
	local entry = self.entries[player]
	return entry ~= nil and player.Parent == Players and entry.status == "Menu"
		and not entry.mutating and self.invites[player] == nil
end

function Lobby:ClearInvite(invite, message)
	for _, player in ipairs({invite.from, invite.to}) do
		if self.invites[player] == invite then self.invites[player] = nil end
		if self.entries[player] then self.entries[player].message = message or "" end
	end
end

function Lobby:Reserve(mode, blue, red)
	assert(not self.reservation, "Desk already reserved")
	local room = {mode = mode, blue = blue, red = red, id = HttpService:GenerateGUID(false), ready = {}}
	self.reservation = room
	for _, player in ipairs({blue, red}) do
		local entry = self.entries[player]
		entry.status, entry.queueSince, entry.message = "Lobby", nil, ""
	end
end

function Lobby:Pair()
	if self.reservation then return end
	while #self.queue > 0 do
		local player = self.queue[1]
		if self.entries[player] and self.entries[player].status == "Queued" and player.Parent == Players then break end
		table.remove(self.queue, 1)
	end
	if #self.queue < 2 then return end
	local blue, red = table.remove(self.queue, 1), table.remove(self.queue, 1)
	self:Reserve("Quick", blue, red)
end

function Lobby:Release(room, message)
	if self.reservation ~= room then return end
	self.reservation = nil
	for _, player in ipairs({room.blue, room.red}) do
		local entry = self.entries[player]
		if entry then entry.status, entry.message, entry.queueSince = "Menu", message, nil end
	end
	self:Pair()
	self:Publish()
end

function Lobby:Leave(player, message)
	local entry = self.entries[player]
	if not entry then return end
	local index = table.find(self.queue, player)
	if index then table.remove(self.queue, index) end
	local invite = self.invites[player]
	if invite then self:ClearInvite(invite, message) end
	local room = self.reservation
	if room and (room.blue == player or room.red == player) then
		if room.started then self.match:EndSession(message) else self:Release(room, message) end
	else
		entry.status, entry.message, entry.queueSince = "Menu", message, nil
	end
end

function Lobby:Request(player, packet)
	local entry = self.entries[player]
	if not entry or type(packet) ~= "table" then return false, "Invalid request" end
	local stamp = os.clock()
	entry.credit = math.min(7, entry.credit + (stamp - entry.at) * 5)
	entry.at = stamp
	if entry.credit < 1 then return false, "Wait a moment before trying again" end
	entry.credit -= 1
	local sequence = packet.id
	if type(sequence) ~= "number" or sequence % 1 ~= 0 or sequence <= entry.last or sequence > 1e9 then
		return false, "Invalid or repeated request"
	end
	entry.last = sequence
	local action = packet.action
	if action == "Equip" or action == "Unlock" then
		local item = Catalog.Get(packet.pen)
		if not self:IsAvailable(player) then return false, "Finish your current activity first" end
		if not item then return false, "Unknown pen" end
		entry.mutating = true
		local ok, reason = self.progress:Select(player, action, item.id)
		entry.mutating = false
		if not ok then return false, reason end
		entry.message = item.name .. (action == "Unlock" and " unlocked" or " equipped")
	elseif action == "Queue" then
		if not self:IsAvailable(player) then return false, "Finish or cancel your current activity first" end
		entry.status, entry.queueSince, entry.message = "Queued", now(), "Searching in this server"
		table.insert(self.queue, player)
		self:Pair()
	elseif action == "Solo" then
		if packet.mode ~= "Hotseat" and packet.mode ~= "Practice" then return false, "Unknown mode" end
		if not self:IsAvailable(player) then return false, "Finish or cancel your current activity first" end
		if self.reservation then return false, "The classroom desk is in use" end
		self:Reserve(packet.mode, player)
	elseif action == "Challenge" then
		if type(packet.target) ~= "number" or packet.target % 1 ~= 0 or math.abs(packet.target) > 2^53 then return false, "Invalid opponent" end
		local target = Players:GetPlayerByUserId(packet.target)
		if target == player or not self:IsAvailable(player) or not self:IsAvailable(target) then return false, "That player is unavailable" end
		local invite = {id = HttpService:GenerateGUID(false), from = player, to = target, expires = now() + INVITE_SECONDS}
		self.invites[player], self.invites[target] = invite, invite
	elseif action == "Accept" or action == "Decline" or action == "CancelInvite" then
		local invite = self.invites[player]
		if not invite or invite.id ~= packet.token or invite.expires <= now() then return false, "This invitation has expired" end
		if action == "CancelInvite" and invite.from ~= player then return false, "Only the sender can cancel" end
		if action ~= "CancelInvite" and invite.to ~= player then return false, "Only the recipient can respond" end
		if action == "Accept" then
			if self.reservation then return false, "The desk is in use. Try again before the invitation expires." end
			if invite.from.Parent ~= Players or self.entries[invite.from].status ~= "Menu" or entry.status ~= "Menu" then return false, "Opponent unavailable" end
			self:ClearInvite(invite)
			self:Reserve("Friends", invite.from, invite.to)
		else self:ClearInvite(invite, action == "Decline" and "Challenge declined" or "Challenge cancelled") end
	elseif action == "Ready" then
		local room = self.reservation
		if entry.status ~= "Lobby" or not room or room.id ~= packet.token or type(packet.ready) ~= "boolean" then return false, "This lobby is no longer active" end
		room.ready[player] = packet.ready
		if not packet.ready then room.countdown = nil end
	elseif action == "Leave" then
		local room = self.reservation
		if entry.status == "Lobby" or entry.status == "Playing" then
			if not room or packet.token ~= room.id then return false, "This session has already changed" end
		elseif entry.status ~= "Queued" then return false, "No active activity" end
		self:Leave(player, player.DisplayName .. " returned to the menu")
	else return false, "Unknown menu action" end
	self:Publish()
	return true
end

function Lobby:Step()
	local stamp = now()
	local changed = false
	for player, invite in pairs(self.invites) do
		if player == invite.from and stamp >= invite.expires then
			self:ClearInvite(invite, "Challenge expired")
			changed = true
		end
	end
	local room = self.reservation
	if room and not room.started and not room.countdown and room.ready[room.blue]
		and (not room.red or room.ready[room.red]) and not self.progress:IsLoading(room.blue)
		and (not room.red or not self.progress:IsLoading(room.red)) then
		room.countdown = stamp + COUNTDOWN_SECONDS
		changed = true
	end
	if room and not room.started and room.countdown and stamp >= room.countdown then
		if room.blue.Parent ~= Players or (room.red and room.red.Parent ~= Players) then
			self:Release(room, "Opponent left before the start")
			return
		end
		room.started, room.countdown = true, nil
		for _, player in ipairs({room.blue, room.red}) do self.entries[player].status = "Playing" end
		local mode = room.mode == "Hotseat" and "Hotseat" or room.mode == "Practice" and "Practice" or "Online"
		self:Publish()
		local ok = self.match:StartSession(mode, room.blue, room.red, {
			Blue = self.progress:Equipped(room.blue),
			Red = room.red and self.progress:Equipped(room.red) or Catalog.Default,
		}, function(message) self:Release(room, message) end)
		if not ok then self:Release(room, "The desk could not start. Please try again.") end
		return
	end
	if changed then self:Publish() end
end

function Lobby.Start(match)
	local self = setmetatable({match = match, entries = {}, invites = {}, queue = {}, revision = 0}, Lobby)
	local remotes = Shared.Remotes
	self.push = remotes.LobbyState
	self.progress = Progression.Start(function(player)
		if self.entries[player] then self:Publish() end
	end)
	match.onCompleted = function(blue, red, matchId, winner)
		if blue and red and blue.Parent == Players and red.Parent == Players then
			self.progress:Award(blue, red, matchId, winner == "Blue")
			self.progress:Award(red, blue, matchId, winner == "Red")
		end
	end
	local function joined(player)
		player.ReplicationFocus = workspace.PenFight.Desk.Tabletop
		self.entries[player] = {status = "Menu", message = "", last = 0, credit = 7, at = os.clock()}
		task.defer(function() if player.Parent == Players then self.progress:Load(player) end end)
		self:Publish()
	end
	Players.PlayerAdded:Connect(joined)
	Players.PlayerRemoving:Connect(function(player)
		self:Leave(player, player.DisplayName .. " disconnected")
		self.entries[player] = nil
		self:Publish()
	end)
	for _, player in ipairs(Players:GetPlayers()) do joined(player) end
	remotes.LobbySnapshot.OnServerInvoke = function(player) return self:State(player) end
	remotes.LobbyRequest.OnServerInvoke = function(player, packet)
		local ok, reason = self:Request(player, packet)
		return ok, reason, self:State(player)
	end
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < .1 then return end
		elapsed = 0
		self:Step()
	end)
	Lobby.Current = self
	return self
end

return Lobby
