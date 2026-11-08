-- Procedural presentation. Physics ownership and reach stay in AvatarService.
local RunService = game:GetService("RunService")
local Poses = require(game.ReplicatedStorage.PenFight.AvatarPoses)

local Animator = {}
local TAU = 2 * math.pi
local identity = CFrame.identity
local shoulderChain = {RightShoulder = true, RightElbow = true, RightWrist = true}
local aliases = {
	["Right Shoulder"] = "RightShoulder", ["Left Shoulder"] = "LeftShoulder",
	["Right Hip"] = "RightHip", ["Left Hip"] = "LeftHip", RootJoint = "Waist",
}

local function seed(name)
	local value = 0
	for i = 1, #name do value = (value * 31 + string.byte(name, i)) % 997 end
	return value
end

local function pulse(age, length)
	if age < 0 or age >= length then return 0 end
	return math.sin(math.pi * age / length)
end

local function pose(rig, base, changes, dt, speed, locked)
	local alpha = 1 - math.exp(-dt * speed)
	for name, motor in pairs(rig.motors) do
		if not (locked and shoulderChain[name]) then
			motor.Transform = motor.Transform:Lerp(base(name) * (changes[name] or identity), alpha)
		end
	end
end

local function animatePlayer(model, rig, now, dt, prefs, hud)
	local root = model.PrimaryPart
	if not root then return end
	local aim = model:GetAttribute("Aiming") == true
	local age = now - (model:GetAttribute("ShotAt") or 0)
	local reacting = now - (model:GetAttribute("ReactionAt") or 0)
	local outcome = model:GetAttribute("Outcome")
	local power = model:GetAttribute("ShotPower") or 0
	local scale = prefs.ReducedMotion and .42 or 1
	local ik = rig.ik
	local locked = ik and ik.Enabled
	local velocity = root.AssemblyLinearVelocity
	local pace = math.clamp(Vector3.new(velocity.X, 0, velocity.Z).Magnitude / 16, 0, 1)
	local change = {}
	local base = Poses.Standing

	if aim then
		local load = model:GetAttribute("ActiveTurn") and (hud:GetAttribute("AimLoad") or 0) or 0
		base = Poses.Leaning
		change.Waist = CFrame.Angles(-.14 + load * .06, -load * .13, .035)
		change.Neck = CFrame.Angles(-.06, load * .08, -.035)
		change.LeftShoulder = CFrame.Angles(.10, 0, -.14)
		change.LeftElbow = CFrame.Angles(.17 + load * .10, 0, 0)
		change.LeftHip = CFrame.Angles(-.08, 0, -.035)
		change.RightHip = CFrame.Angles(.10, 0, .035)
	elseif age >= 0 and age < .64 then
		local recoil = pulse(age - .055, .46) * (.55 + power * .45) * scale
		local follow = pulse(age, .31) * scale
		local direction = model:GetAttribute("ShotDirection") or Vector3.zero
		local side = math.clamp(direction:Dot(root.CFrame.RightVector), -1, 1)
		change.Waist = CFrame.Angles(.18 * follow, recoil * side * .25, -.04 * recoil)
		change.Neck = CFrame.Angles(-.08 * follow, side * .12 * recoil, 0)
		change.RightShoulder = CFrame.Angles(.62 * follow + .24 * recoil, -.29 * side * recoil, .11 * recoil)
		change.RightElbow = CFrame.Angles(.43 * recoil, 0, 0)
		change.RightWrist = CFrame.Angles(-.65 * recoil, 0, .10 * side * recoil)
		change.LeftShoulder = CFrame.Angles(.14 * follow, 0, -.07 * recoil)
	elseif pace > .045 and model:GetAttribute("ActiveTurn") then
		rig.step = (rig.step + dt * (4 + pace * 7)) % TAU
		local stride = math.sin(rig.step)
		local lift = math.cos(rig.step)
		local swing = stride * pace * .48 * scale
		change.Waist = CFrame.new(0, math.abs(lift) * .055 * pace * scale, 0) * CFrame.Angles(.08 * pace, swing * .12, .04 * lift)
		change.Neck = CFrame.Angles(-.055 * pace, -swing * .10, -.026 * lift)
		change.LeftHip = CFrame.Angles(swing, 0, 0)
		change.RightHip = CFrame.Angles(-swing, 0, 0)
		change.LeftKnee = CFrame.Angles(-math.max(0, lift) * .42 * pace * scale, 0, 0)
		change.RightKnee = CFrame.Angles(-math.max(0, -lift) * .42 * pace * scale, 0, 0)
		change.LeftShoulder = CFrame.Angles(-swing * .8, 0, -.055)
		change.RightShoulder = CFrame.Angles(swing * .8, 0, .055)
	else
		local breath = math.sin(now * 1.55 + rig.seed) * .023 * scale
		local reaction = pulse(reacting, 1.7) * scale
		local win = outcome == "Won" and reaction or 0
		local lose = outcome == "Lost" and reaction or 0
		local cheerBeat = 1 + math.sin(reacting * 14) * .10
		change.Waist = CFrame.Angles(.26 * lose, -.07 * win, breath)
		change.Neck = CFrame.Angles(.40 * lose - .13 * win, breath * 2, -.05 * lose)
		change.RightShoulder = CFrame.Angles(2.00 * win * cheerBeat - .19 * lose + breath, 0, .22 * win + breath)
		change.LeftShoulder = CFrame.Angles(.85 * win - .15 * lose - breath, 0, -.14 * win - breath)
		change.RightElbow = CFrame.Angles(.48 * win, 0, 0)
	end
	pose(rig, base, change, dt, aim and 17 or 13, locked)
end

local function animateSpectator(model, rig, focus, now, dt, prefs)
	local root = model.PrimaryPart
	if not root then return end
	local scale = prefs.ReducedMotion and .30 or 1
	local offset = rig.seed % 5
	local reactAge = now - (model:GetAttribute("ReactAt") or 0) - offset * .043
	local cheerAge = now - (model:GetAttribute("CheerAt") or 0) - offset * .081
	local react = pulse(reactAge, .68) * math.clamp(model:GetAttribute("ImpactLevel") or .55, .4, 1) * scale
	local cheer = pulse(cheerAge, 1.38) * scale
	local idle = math.sin(now * (.75 + offset * .09) + rig.seed) * scale
	local gaze = root.CFrame:PointToObjectSpace(focus)
	local yaw = math.clamp(math.atan2(-gaze.X, -gaze.Z), -.55, .55)
	local lift = math.sin(cheerAge * (10 + offset)) * .12
	local leadRight = offset % 2 == 0
	local change = {
		Neck = CFrame.Angles(.16 * react - .10 * cheer + idle * .065, yaw + idle * .075, idle * .035),
		Waist = CFrame.Angles(.15 * react - .05 * cheer, idle * .04, .05 * idle),
		RightShoulder = CFrame.Angles(react * .30 + cheer * (leadRight and 1.55 or .88) + lift * cheer, 0, .16 * cheer),
		LeftShoulder = CFrame.Angles(react * .24 + cheer * (leadRight and .91 or 1.55) - lift * cheer, 0, -.16 * cheer),
		RightElbow = CFrame.Angles(.37 * cheer + .06 * idle, 0, 0),
		LeftElbow = CFrame.Angles(.29 * cheer - .05 * idle, 0, 0),
	}
	pose(rig, Poses.Sitting, change, dt, 9, false)
end

local function track(folder)
	local rigs = {}
	local function add(model)
		if not model:IsA("Model") then return end
		local rig = {motors = {}, seed = seed(model.Name), step = 0}
		local function register(node)
			if Poses.IsJoint(node) then
				rig.motors[aliases[node.Name] or node.Name] = node
			elseif node:IsA("IKControl") and node.Name == "FlickReachIK" then
				rig.ik = node
			end
		end
		rig.added = model.DescendantAdded:Connect(register)
		rig.removed = model.DescendantRemoving:Connect(function(node)
			local key = aliases[node.Name] or node.Name
			if rig.motors[key] == node then rig.motors[key] = nil end
			if rig.ik == node then rig.ik = nil end
		end)
		for _, node in ipairs(model:GetDescendants()) do register(node) end
		rigs[model] = rig
	end
	folder.ChildAdded:Connect(add)
	folder.ChildRemoved:Connect(function(model)
		local rig = rigs[model]
		if not rig then return end
		rig.added:Disconnect()
		rig.removed:Disconnect()
		rigs[model] = nil
	end)
	for _, model in ipairs(folder:GetChildren()) do add(model) end
	return rigs
end

function Animator.Start(characters, spectators, prefs, hud, pens)
	local actors = track(characters)
	local audience = track(spectators)
	local spectatorTime = 0
	RunService.PreSimulation:Connect(function(dt)
		local now = workspace:GetServerTimeNow()
		for model, rig in pairs(actors) do
			animatePlayer(model, rig, now, dt, prefs, hud)
		end

		spectatorTime += dt
		local simple = hud:GetAttribute("ArtQuality") == "Simple"
		if spectatorTime < (simple and 1/12 or 1/24) then return end
		local elapsed = spectatorTime
		spectatorTime = 0
		local camera = workspace.CurrentCamera
		if not camera then return end
		local state = game.ReplicatedStorage.PenFight.State
		local tracking = state:GetAttribute("phase") == "Moving"
		local id = state:GetAttribute(tracking and "shotPen" or "active")
		local pen = id and pens:FindFirstChild(id)
		local focus = pen and pen.PrimaryPart and pen.PrimaryPart.Position or Vector3.new(0, 5.6, 100)
		for model, rig in pairs(audience) do
			local root = model.PrimaryPart
			if root and (root.Position - camera.CFrame.Position).Magnitude <= (simple and 75 or 110) then
				animateSpectator(model, rig, focus, now, elapsed, prefs)
			end
		end
	end)
end

return Animator
