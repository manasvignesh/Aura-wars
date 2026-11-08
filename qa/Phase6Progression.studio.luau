-- Run in Studio server play. Storage here is an isolated UpdateAsync test double.
local Http = game:GetService("HttpService")
local Progression = require(game.ServerScriptService.PenFight.ProgressionService)
local records, results = {}, {}
local lostResponse = false
local function copy(value)
	return value and Http:JSONDecode(Http:JSONEncode(value))
end
local store = {}
function store:UpdateAsync(key, transform)
	local nextValue = transform(copy(records[key]))
	if nextValue then
		records[key] = copy(nextValue)
		if lostResponse then lostResponse = false; error("Simulated lost response after commit") end
	end
	return copy(nextValue)
end
local function check(name, ok)
	table.insert(results, {name = name, pass = ok == true})
end
local function waitAwards(service, player)
	local deadline = os.clock() + 4
	repeat task.wait() until service.profiles[player].pendingAwards == 0 or os.clock() > deadline
end
local a,b,c,d = {UserId = 61001}, {UserId = 61002}, {UserId = 61003}, {UserId = 61004}
local progress = Progression.new(store, function() end)
progress:Load(a)
progress:Load(b)
check("Fresh profile has Classic and zero Aura", progress:View(a).aura == 0 and progress:Equipped(a) == "recess")
check("Reject insufficient balance, unknown pen and unowned equip",
	not progress:Select(a, "Unlock", "gripper") and not progress:Select(a, "Unlock", "invalid")
	and not progress:Select(a, "Equip", "gripper"))
lostResponse = true
progress:Award(a, b, "match1", true)
waitAwards(progress, a)
progress:Award(b, a, "match1", false)
waitAwards(progress, b)
check("Winner receives 50 once after lost response, loser receives 20",
	progress:View(a).aura == 50 and progress:View(b).aura == 20 and progress:View(a).wins == 1)
progress:Award(a, b, "match1", true)
progress:Award(a, b, "rematch", true)
waitAwards(progress, a)
check("Duplicate match and same-opponent cooldown block payout", progress:View(a).aura == 50)
progress:Award(a, c, "match2", true)
waitAwards(progress, a)
check("Correct deduction and duplicate unlock rejection", progress:Select(a, "Unlock", "gripper")
	and progress:View(a).aura == 0 and not progress:Select(a, "Unlock", "gripper"))
check("Owned pen equips", progress:Select(a, "Equip", "gripper") and progress:Equipped(a) == "gripper")
local contender = Progression.new(store, function() end)
contender:Load(a)
check("Second session cannot overwrite active lease", contender:View(a).status == "Unavailable"
	and progress:Equipped(a) == "gripper")
progress:Close(a)
contender:Load(a)
local saved = contender:View(a)
check("Reconnect restores ownership, equipped pen, balance and stats",
	saved.owned.gripper and saved.equipped == "gripper" and saved.aura == 0 and saved.completed == 2 and saved.wins == 2)
records["player:" .. d.UserId] = {version = 99, aura = 500}
contender:Load(d)
check("Unknown schema is preserved and blocked", contender:View(d).status == "Unavailable"
	and records["player:" .. d.UserId].aura == 500)
local unavailable = Progression.new(nil, function() end)
unavailable:Load(c)
unavailable:Award(c, a, "unsaved", true)
check("Unavailable store disables purchases and awards", not unavailable:Select(c, "Unlock", "gripper")
	and unavailable:View(c).aura == nil and unavailable:Equipped(c) == "recess")
return Http:JSONEncode(results)
