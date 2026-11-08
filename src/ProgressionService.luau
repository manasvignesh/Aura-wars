local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Catalog = require(game.ReplicatedStorage.PenFight.PenCatalog)

local Progression = {}
Progression.__index = Progression
local VERSION = 1
local LEASE_SECONDS = 120
local RENEW_SECONDS = 40
local PAIR_COOLDOWN = 180
local COMPLETION_REWARD, WIN_REWARD = 20, 30

local function fresh()
	return {version = VERSION, aura = 0, owned = {[Catalog.Default] = true},
		equipped = Catalog.Default, completed = 0, wins = 0, recent = {}}
end

local function validCount(n)
	return type(n) == "number" and n >= 0 and n < 2^53 and n % 1 == 0
end

local function valid(data)
	return type(data) == "table" and data.version == VERSION and validCount(data.aura)
		and validCount(data.completed) and validCount(data.wins) and data.wins <= data.completed
		and type(data.owned) == "table" and data.owned[Catalog.Default] == true
		and Catalog.Get(data.equipped) ~= nil and data.owned[data.equipped] == true
		and type(data.recent) == "table"
end

function Progression.new(store, changed)
	return setmetatable({store = store, changed = changed, profiles = {}}, Progression)
end

function Progression:IsLoading(player)
	local profile = self.profiles[player]
	return not profile or profile.status == "Loading"
end

function Progression:View(player)
	local profile = self.profiles[player]
	local data = profile and profile.data
	return {
		status = profile and profile.status or "Loading",
		aura = data and data.aura, completed = data and data.completed, wins = data and data.wins,
		owned = data and table.clone(data.owned) or {[Catalog.Default] = true},
		equipped = data and data.equipped or Catalog.Default,
	}
end

function Progression:Equipped(player)
	local profile = self.profiles[player]
	local data = profile and profile.data
	return data and data.owned[data.equipped] == true and Catalog.Get(data.equipped) and data.equipped or Catalog.Default
end

function Progression:Write(profile, transform)
	local reason
	for attempt = 1, 3 do
		local ok, data = pcall(function()
			return self.store:UpdateAsync(profile.key, function(old)
				reason = nil
				local result, rejected = transform(old)
				reason = rejected
				return result
			end)
		end)
		if ok then return data, reason end
		if attempt < 3 then task.wait(.65 * 2^(attempt - 1) + math.random() * .25) end
	end
	return nil, "Progress could not be verified. Try again after reconnecting."
end

function Progression:Load(player)
	local profile = {key = "player:" .. player.UserId, id = HttpService:GenerateGUID(false),
		status = "Loading", busy = true}
	self.profiles[player] = profile
	if not self.store or player.UserId <= 0 then
		profile.status, profile.busy = "Unavailable", false
		self.changed(player)
		return
	end
	local data
	for attempt = 1, 3 do
		data = self:Write(profile, function(old)
			if old == nil then old = fresh() end
			if not valid(old) then return nil, "Unsupported profile" end
			local lease = old.lease
			if lease and lease.id ~= profile.id and lease.untilTime > os.time() then return nil, "Locked" end
			old.lease = {id = profile.id, untilTime = os.time() + LEASE_SECONDS}
			return old
		end)
		if data or profile.closing then break end
		if attempt < 3 then task.wait(1.5 * attempt) end
	end
	profile.data, profile.status, profile.busy = data, data and "Ready" or "Unavailable", false
	self.changed(player)
end

function Progression:Commit(player, mutate, release, earned)
	local profile = self.profiles[player]
	if not profile or not profile.data or (not release and (profile.status ~= "Ready" or (profile.closing and not earned))) then
		return false, "Progress saving is unavailable."
	end
	if profile.busy then return false, "Progress is saving. Try again shortly." end
	profile.busy = true
	local operation = HttpService:GenerateGUID(false)
	local data, reason = self:Write(profile, function(old)
		if not valid(old) then return nil, "Profile ownership lost" end
		if old.operation == operation then return old end
		if not old.lease or old.lease.id ~= profile.id or (not release and old.lease.untilTime <= os.time()) then
			return nil, "Profile ownership lost"
		end
		local rejected = mutate and mutate(old)
		if rejected then return nil, rejected end
		old.operation = operation
		old.lease = not release and {id = profile.id, untilTime = os.time() + LEASE_SECONDS} or nil
		return old
	end)
	profile.busy = false
	if data then
		profile.data = data
	elseif not reason or reason == "Profile ownership lost" or reason:find("could not be verified", 1, true) then
		profile.data, profile.status = nil, "Unavailable"
	end
	self.changed(player)
	return data ~= nil, reason
end

function Progression:Select(player, action, penId)
	local item = Catalog.Get(penId)
	if not item then return false, "Unknown pen." end
	return self:Commit(player, function(data)
		if action == "Unlock" then
			if data.owned[item.id] then return "You already own this pen." end
			if data.aura < item.cost then return "You need " .. item.cost .. " Aura Points to unlock this pen." end
			data.aura -= item.cost
			data.owned[item.id] = true
		else
			if not data.owned[item.id] then return "Unlock this pen first." end
			if data.equipped == item.id then return "This pen is already equipped." end
			data.equipped = item.id
		end
	end)
end

function Progression:Award(player, opponent, matchId, won)
	local profile = self.profiles[player]
	if not profile or profile.status ~= "Ready" or profile.closing then return end
	profile.pendingAwards = (profile.pendingAwards or 0) + 1
	task.spawn(function()
		while profile.busy do task.wait(.1) end
		self:Commit(player, function(data)
			local stamp = os.time()
			local opponentKey = tostring(opponent.UserId)
			local previous = data.recent[opponentKey]
			if previous and (previous.match == matchId or stamp - previous.at < PAIR_COOLDOWN) then
				return "Recent match with the same opponent."
			end
			for key, receipt in pairs(data.recent) do
				if stamp - receipt.at >= PAIR_COOLDOWN then data.recent[key] = nil end
			end
			data.recent[opponentKey] = {match = matchId, at = stamp}
			data.aura += COMPLETION_REWARD + (won and WIN_REWARD or 0)
			data.completed += 1
			if won then data.wins += 1 end
		end, false, true)
		profile.pendingAwards -= 1
	end)
end

function Progression:Close(player)
	local profile = self.profiles[player]
	if not profile or profile.closing then return end
	profile.closing = true
	while profile.busy or (profile.pendingAwards or 0) > 0 do task.wait(.1) end
	self:Commit(player, nil, true)
	self.profiles[player] = nil
end

function Progression.Start(changed)
	-- Studio play never touches live player records.
	local store = not RunService:IsStudio() and DataStoreService:GetDataStore("PenFightProgress_v1") or nil
	local service = Progression.new(store, changed)
	Players.PlayerRemoving:Connect(function(player) service:Close(player) end)
	task.spawn(function()
		while true do
			task.wait(RENEW_SECONDS)
			for player, profile in pairs(service.profiles) do
				if profile.status == "Ready" and not profile.busy and not profile.closing then
					task.spawn(function() service:Commit(player) end)
				end
			end
		end
	end)
	game:BindToClose(function()
		for player in pairs(service.profiles) do task.spawn(function() service:Close(player) end) end
		local deadline = os.clock() + 25
		while next(service.profiles) and os.clock() < deadline do task.wait(.1) end
	end)
	return service
end

return Progression
