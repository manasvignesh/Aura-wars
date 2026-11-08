local tests = game:GetService("StudioTestService")
local mode = tests:GetTestArgs()
if not string.find(tostring(mode), "^PenFight6") then return end
local players = game:GetService("Players")
local shared = game.ReplicatedStorage.PenFight
local bridge = Instance.new("RemoteEvent")
bridge.Name = "Phase5B1Test"
bridge.Parent = shared
local ready, replies, results, errors = {}, {}, {}, {}
local seq = 0
game:GetService("LogService").MessageOut:Connect(function(message, kind)
	if kind == Enum.MessageType.MessageError and #errors < 30 then table.insert(errors, message) end
end)
bridge.OnServerEvent:Connect(function(player, id, ok, data)
	if id == 0 then ready[player] = true else replies[id] = {player = player, ok = ok, data = data} end
end)
local function waitFor(predicate, label, limit)
	local start = os.clock()
	repeat
		if predicate() then return end
		task.wait(.08)
	until os.clock() - start > (limit or 14)
	error("Timeout: " .. label, 2)
end
local function send(player, action, payload)
	seq += 1
	local id = seq
	bridge:FireClient(player, id, action, payload or {})
	waitFor(function() return replies[id] ~= nil end, action, 23)
	local response = replies[id]
	assert(response.ok and response.player == player, tostring(response.data))
	return response.data
end
local function check(label, passed, evidence)
	table.insert(results, {name = label, status = passed and "PASS" or "FAIL", evidence = evidence})
	shared:SetAttribute("QA5B1Progress", label .. (passed and " PASS" or " FAIL"))
	assert(passed, label)
end
local matchModule = require(game.ServerScriptService.PenFight.OnlineMatchService)
local lobbyModule = require(game.ServerScriptService.PenFight.LobbyService)
local ok, failure = pcall(function()
	waitFor(function() return matchModule.Current and lobbyModule.Current and #players:GetPlayers() == 2 end, "server start", 80)
	local match, lobby = matchModule.Current, lobbyModule.Current
	local a,b = table.unpack(players:GetPlayers())
	waitFor(function() return ready[a] and ready[b] end, "two clients", 35)
	local awards = {}
	local completed = match.onCompleted
	match.onCompleted = function(blue, red, matchId, winner)
		table.insert(awards, {id = matchId, winner = winner})
		completed(blue, red, matchId, winner)
	end
	local function request(player, action, payload)
		local reply = send(player, action, payload)
		assert(reply.accepted, tostring(reply.reason))
		return reply
	end
	local function pair()
		request(a, "Queue")
		request(b, "Queue")
		local room = assert(lobby.reservation.id)
		request(a, "Ready", {token = room, ready = true})
		request(b, "Ready", {token = room, ready = true})
		waitFor(function() return match.stage == "Positioning" end, "intro", 20)
		return room
	end
	local room = pair()
	local previousRound = match.round
	match:Resolve("Draw")
	check("Draw changes no wins and dispatches no progression", match.blueWins == 0 and match.redWins == 0 and #awards == 0)
	waitFor(function() return match.round > previousRound and match.stage == "Positioning" end, "draw replay", 12)
	for round = 1, 2 do
		for _, side in {"Blue", "Red"} do
			waitFor(function() return match.stage == "Positioning" and match.active == side end, "turn " .. side, 22)
			local previous = match.shotId
			local evidence = send(match.slots[side], "Shot", {side = side, pixels = side == "Blue" and 23 or 155})
			check("Round " .. round .. " " .. side .. " physical drag", evidence.held and match.shotId == previous + 1 and match.shotPen == side, evidence)
		end
		waitFor(function() return match.blueWins == round end, "physical fall", 13)
	end
	waitFor(function() return match.stage == "MatchResult" end, "best of three")
	local left, right = send(a, "Report"), send(b, "Report")
	check("Both clients receive identical best-of-three score", left.match.matchWinner == "Blue" and right.match.matchWinner == "Blue"
		and left.match.blueWins == 2 and right.match.blueWins == 2, {left,right})
	check("Legitimate physical match dispatches once", #awards == 1 and awards[1].id == match.matchId)
	check("Studio unavailable storage does not mint rewards", lobby.progress:View(a).status == "Unavailable"
		and lobby.progress:View(a).aura == nil and lobby.progress:View(b).aura == nil)
	send(a, "Vote")
	waitFor(function() return match.votes.Blue end, "first rematch vote")
	send(b, "Vote")
	waitFor(function() return match.stage == "Positioning" and match.matchId ~= awards[1].id end, "rematch")
	check("Rematch resets match reward eligibility", not next(match.matchShots) and not match.hadTimeout and not match.completionSent)
	for _ = 1, 2 do
		match.deadline = workspace:GetServerTimeNow() - 1
		waitFor(function() return match.stage == "RoundResult" end, "timeout")
		waitFor(function() return match.stage == "Positioning" or match.stage == "MatchResult" end, "timeout result")
	end
	check("Timeout result dispatches no progression", match.matchWinner == "Red" and #awards == 1)
	request(a, "Leave", {token = room})
	-- Studio-only seeded record for the real LobbyRequest and loadout paths.
	local profile = lobby.progress.profiles[a]
	local record = {version = 1, aura = 100, completed = 0, wins = 0, recent = {},
		equipped = "recess", owned = {recess = true},
		lease = {id = profile.id, untilTime = os.time() + 120}}
	profile.data, profile.status = record, "Ready"
	lobby.progress.store = {UpdateAsync = function(_, key, transform)
		assert(key == profile.key)
		local updated = transform(game.HttpService:JSONDecode(game.HttpService:JSONEncode(record)))
		if updated then record = updated end
		return updated
	end}
	request(a, "Unlock", {pen = "gripper"})
	request(a, "Equip", {pen = "gripper"})
	check("Client unlock and equip persist to the isolated store", record.aura == 0 and record.owned.gripper and record.equipped == "gripper")
	room = pair()
	local pen = workspace.PenFight.Pens.Blue
	check("Saved loadout applies appearance and physical friction at match start",
		pen:GetAttribute("EquippedPen") == "gripper" and math.abs(pen.PrimaryPart.CustomPhysicalProperties.Friction - .18) < .001
		and pen.Barrel.Color.R < .3)
	request(a, "Leave", {token = room})
	check("Cancellation and menu cleanup", not lobby.reservation and not next(match.slots) and #awards == 1)
	pair()
	b:Kick("Phase 6 controlled disconnect")
	waitFor(function() return not lobby.reservation end, "disconnect cleanup")
	check("Disconnect does not dispatch progression", not next(match.slots) and #awards == 1)
end)
tests:EndTest({complete = ok, error = ok and "" or tostring(failure), results = results, errors = errors})
