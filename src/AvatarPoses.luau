-- Native R15 procedural pose; works with both Motor6D and upgraded AnimationConstraint rigs.
local P = {}

function P.NormalizeVisualRig(model)
	for _, joint in ipairs(model:GetDescendants()) do
		if joint:IsA("AnimationConstraint") then
			local motor = Instance.new("Motor6D")
			motor.Name = joint.Name
			motor.Part0 = joint.Part0
			motor.Part1 = joint.Part1
			motor.C0 = joint.C0
			motor.C1 = joint.C1
			motor.Parent = joint.Parent
			joint:Destroy()
		elseif joint:IsA("BallSocketConstraint") or joint:IsA("NoCollisionConstraint") then
			joint:Destroy()
		end
	end
end

function P.Sitting(name)
	local degrees = 0
	if name == "LeftHip" or name == "RightHip" then degrees = 78
	elseif name == "LeftKnee" or name == "RightKnee" then degrees = -83
	elseif name == "LeftShoulder" or name == "RightShoulder" then degrees = 34
	elseif name == "LeftElbow" or name == "RightElbow" then degrees = 28 end
	return CFrame.Angles(math.rad(degrees), 0, 0)
end

function P.Standing(name)
	local rx, ry, rz = 0, 0, 0
	if name == "RightShoulder" then
		rx, rz = math.rad(6), math.rad(4)
	elseif name == "LeftShoulder" then
		rx, rz = math.rad(6), math.rad(-4)
	end
	return CFrame.Angles(rx, ry, rz)
end

function P.Leaning(name)
	if name == "Waist" then
		return CFrame.Angles(math.rad(24), 0, 0)
	elseif name == "Neck" then
		return CFrame.Angles(math.rad(-14), 0, 0)
	elseif name == "RightShoulder" then
		return CFrame.Angles(math.rad(52), math.rad(-12), math.rad(14))
	elseif name == "RightElbow" then
		return CFrame.Angles(math.rad(26), 0, 0)
	elseif name == "RightWrist" then
		return CFrame.Angles(math.rad(-12), 0, 0)
	elseif name == "LeftShoulder" then
		return CFrame.Angles(math.rad(22), 0, math.rad(-15))
	elseif name == "LeftElbow" then
		return CFrame.Angles(math.rad(30), 0, 0)
	end
	return CFrame.identity
end

function P.IsJoint(v)
	return v:IsA("AnimationConstraint") or v:IsA("Motor6D")
end

function P.PlaceStanding(model)
	local joints = {}
	for _, v in ipairs(model:GetDescendants()) do
		if P.IsJoint(v) then
			if v:IsA("AnimationConstraint") then v.IsKinematic = true end
			v.Transform = P.Standing(v.Name)
			table.insert(joints, v)
		end
	end
	local done = {[model.PrimaryPart] = true}
	for _ = 1, 8 do
		for _, joint in ipairs(joints) do
			local p0, p1 = joint.Part0, joint.Part1
			if p0 and p1 and done[p0] and not done[p1] then
				p1.CFrame = p0.CFrame * joint.C0 * P.Standing(joint.Name) * joint.C1:Inverse()
				done[p1] = true
			end
		end
	end
end

function P.PlaceSeated(model)
	local joints = {}
	for _, v in ipairs(model:GetDescendants()) do
		if P.IsJoint(v) then
			if v:IsA("AnimationConstraint") then v.IsKinematic = true end
			v.Transform = P.Sitting(v.Name)
			table.insert(joints, v)
		end
	end
	local done = {[model.PrimaryPart] = true}
	for _ = 1, 8 do
		for _, joint in ipairs(joints) do
			local p0, p1 = joint.Part0, joint.Part1
			if p0 and p1 and done[p0] and not done[p1] then
				p1.CFrame = p0.CFrame * joint.C0 * P.Sitting(joint.Name) * joint.C1:Inverse()
				done[p1] = true
			end
		end
	end
end

return P
