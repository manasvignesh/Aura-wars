-- Run through Studio MCP in a Server play session. Set firstCase and lastCase in the caller.
-- Uses actual cloned assemblies/tabletop, the production flick impulse and native contact.
local RunService = game:GetService("RunService")
assert(RunService:IsRunning() and RunService:IsServer(), "Server play session required")
local arena = workspace.PenFight
local Physics = require(game.ServerScriptService.PenFight.PenPhysics)
local tabletop = arena.Desk.Tabletop
local origin = Vector3.new(128, tabletop.Position.Y + tabletop.Size.Y / 2, 128)
local powers = {.28, .58, 1}
local scenarios = {
	{name = "parallel side", z = .86},
	{name = "off-center left", x = 1.8, z = .88, offset = 1.2},
	{name = "off-center right", x = -1.8, z = .88, offset = -1.2},
	{name = "oblique approach", x = .5, z = .88, dir = Vector3.new(.4, 0, 1).Unit},
	{name = "angled target", x = -1.0, z = 1.68, targetYaw = 17},
	{name = "opposed tips end-on", x = 6.10, targetYaw = 180, dir = Vector3.xAxis},
	{name = "tips skim", x = 5.86, z = .33, targetYaw = 180, skim = true},
	{name = "tips skim wide", x = 5.89, z = .32, targetYaw = 180, skim = true},
	{name = "tips skim with yaw", x = 5.84, z = .36, targetYaw = 178, skim = true},
	{name = "near short desk edge", x = .4, z = .88, center = Vector3.new(6.6, 0, 0)},
	{name = "toward long desk edge", z = .86, center = Vector3.new(0, 0, 2.26)},
	{name = "both pens moving", z = 1.04, moving = true, offset = .75},
}

local function planar(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function placePen(pen, position, yaw, parent)
	pen:PivotTo(CFrame.new(position) * CFrame.Angles(0, math.rad(yaw), 0))
	pen.Parent = parent
	pen.PrimaryPart:SetNetworkOwner(nil)
end

local function case(number, fixture)
	local charge = powers[(number - 1) % #powers + 1]
	local setup = scenarios[math.ceil(number / #powers)]
	local attacking = if number % 2 == 1 then "Blue" else "Red"
	local defending = if attacking == "Blue" then "Red" else "Blue"
	local attacker, target = arena.Pens[attacking]:Clone(), arena.Pens[defending]:Clone()
	local center = origin + Vector3.new(0, attacker.PrimaryPart.Size.Y / 2 + .025, 0)
		+ (setup.center or Vector3.zero)
	local separation = Vector3.new(setup.x or 0, 0, setup.z or 0)
	placePen(attacker, center - separation / 2, 0, fixture)
	placePen(target, center + separation / 2, setup.targetYaw or 0, fixture)
	local a, b = attacker.PrimaryPart, target.PrimaryPart
	local touching, tipContact, started = false, false, false
	local connections = {}
	for _, part in attacker:GetChildren() do
		if part:IsA("BasePart") and part.CanCollide and part.CanTouch then
			table.insert(connections, part.Touched:Connect(function(other)
				if started and other.Parent == target and other.CanCollide then
					touching = true
					tipContact = tipContact or part.Name == "Ballpoint" or other.Name == "Ballpoint"
				end
			end))
		end
	end
	for _ = 1, 9 do RunService.Heartbeat:Wait() end
	local restingSpeed = math.max(planar(a.AssemblyLinearVelocity).Magnitude, planar(b.AssemblyLinearVelocity).Magnitude)
	local startA, startB = a.Position, b.Position
	local direction = setup.dir or Vector3.zAxis
	started = true
	if setup.moving then Physics.Flick(target, -direction, .26, 0) end
	local launchSpeed = Physics.Flick(attacker, direction, charge, setup.offset or 0)
	local maxTarget, maxTransfer, maxSpin, closest, elapsed = 0, 0, 0, math.huge, 0
	local crossed, fell, bothMoving = false, false, false
	local previousForward = planar(b.AssemblyLinearVelocity):Dot(direction)
	local largestDeflection = 0
	repeat
		elapsed += RunService.Heartbeat:Wait()
		local velocityA, velocityB = planar(a.AssemblyLinearVelocity), planar(b.AssemblyLinearVelocity)
		maxTarget = math.max(maxTarget, velocityB.Magnitude)
		local forward = velocityB:Dot(direction)
		maxTransfer = math.max(maxTransfer, forward)
		largestDeflection = math.max(largestDeflection, forward - previousForward)
		previousForward = forward
		maxSpin = math.max(maxSpin, math.abs(a.AssemblyAngularVelocity.Y), math.abs(b.AssemblyAngularVelocity.Y))
		closest = math.min(closest, (b.Position - a.Position):Dot(direction))
		crossed = crossed or (b.Position - a.Position):Dot(direction) < -.12
		fell = fell or Physics.HasFallen(attacker) or Physics.HasFallen(target)
		bothMoving = bothMoving or (touching and velocityA.Magnitude > .12 and velocityB.Magnitude > .12)
	until elapsed >= .46
	local result = {
		case = number, name = setup.name, attacker = attacking, power = charge, launchSpeed = launchSpeed,
		pass = touching and (if setup.moving then largestDeflection > 1 else maxTransfer > .15)
			and restingSpeed < .15 and (not setup.skim or tipContact),
		contact = touching, tipContact = tipContact, targetSpeed = maxTarget, transfer = maxTransfer,
		spin = maxSpin, targetTravel = planar(b.Position - startB).Magnitude,
		attackerTravel = planar(a.Position - startA).Magnitude, crossed = crossed, fell = fell,
		closestSignedGap = closest, bothMoving = bothMoving, restingSpeed = restingSpeed,
		largestDeflection = largestDeflection,
	}
	for _, connection in connections do connection:Disconnect() end
	attacker:Destroy()
	target:Destroy()
	return result
end

local fixture = Instance.new("Folder")
fixture.Name = "Phase4BCollisionQA"
fixture.Parent = workspace
local testTable = tabletop:Clone()
testTable.CFrame = CFrame.new(origin - Vector3.yAxis * tabletop.Size.Y / 2) * tabletop.CFrame.Rotation
testTable.Parent = fixture
local ok, results = pcall(function()
	local cases = {}
	for number = firstCase, lastCase do table.insert(cases, case(number, fixture)) end
	return cases
end)
fixture:Destroy()
assert(ok, results)
return game:GetService("HttpService"):JSONEncode(results)
