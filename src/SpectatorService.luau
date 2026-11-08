-- SpectatorService.luau
-- Manages background student classmates seated at neighbouring benches.
-- Spectators watch the match, react to strong pen collisions, and applaud victories.

local S = require(game.ReplicatedStorage.PenFight.Settings)
local Poses = require(game.ReplicatedStorage.PenFight.AvatarPoses)
local SchoolStyle = require(script.Parent.SchoolStyle)

local Spectator = {}
Spectator.__index = Spectator

local function createSpectatorRig(name, position, facingPoint, shirtColor, pantsColor)
	local template = game.ServerStorage.PenFightAssets:WaitForChild("RigTemplate"):Clone()
	template.Name = name
	
	-- Disable humanoid physics
	local h = template:FindFirstChildOfClass("Humanoid")
	if h then
		h.EvaluateStateMachine = false
		h.RequiresNeck = false
		h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	
	Poses.NormalizeVisualRig(template)
	
	for _, v in ipairs(template:GetDescendants()) do
		if v:IsA("LuaSourceContainer") then
			v:Destroy()
		elseif v:IsA("BasePart") then
			v.CanCollide = false
			v.CanTouch = false
			v.CanQuery = false
			v.Massless = true
			v.Anchored = true
			v.CollisionGroup = "Environment"
		end
	end
	
	-- Uniform colors
	local torso = template:FindFirstChild("UpperTorso")
	local lTorso = template:FindFirstChild("LowerTorso")
	if torso then torso.Color = shirtColor end
	if lTorso then lTorso.Color = shirtColor end
	
	for _, legName in ipairs({"LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg"}) do
		local part = template:FindFirstChild(legName)
		if part then part.Color = pantsColor end
	end
	
	template:ScaleTo(1.45)
	local root = template:FindFirstChild("HumanoidRootPart")
	template.PrimaryPart = root
	
	local cf = CFrame.lookAt(position, facingPoint)
	template:PivotTo(cf)
	Poses.PlaceSeated(template)
	
	template:SetAttribute("SpectatorName", name)
	template:SetAttribute("CheerAt", 0)
	template:SetAttribute("ReactAt", 0)
	
	return template
end

function Spectator.Start()
	local self = setmetatable({}, Spectator)
	local arena = workspace:WaitForChild("PenFight")
	local folder = arena:FindFirstChild("Spectators") or Instance.new("Folder")
	folder.Name = "Spectators"
	folder.Parent = arena
	self.folder = folder
	
	-- Populate spectators if empty
	if #folder:GetChildren() == 0 then
		local deskCenter = S.Origin + Vector3.new(0, S.SurfaceY, 0)
		
		-- Student 1: Rohan (left bench)
		local s1 = createSpectatorRig("Student_Rohan", S.Origin + Vector3.new(-22, 5.2, -7), deskCenter, Color3.fromRGB(240, 242, 245), Color3.fromRGB(32, 42, 68))
		s1.Parent = folder
		
		-- Student 2: Priya (left bench)
		local s2 = createSpectatorRig("Student_Priya", S.Origin + Vector3.new(-26, 5.2, -7), deskCenter, Color3.fromRGB(220, 235, 248), Color3.fromRGB(32, 42, 68))
		s2.Parent = folder
		
		-- Student 3: Amit (right bench)
		local s3 = createSpectatorRig("Student_Amit", S.Origin + Vector3.new(24, 5.2, -7), deskCenter, Color3.fromRGB(240, 242, 245), Color3.fromRGB(48, 55, 62))
		s3.Parent = folder
		
		-- Student 4: Vikram (right bench)
		local s4 = createSpectatorRig("Student_Vikram", S.Origin + Vector3.new(28, 5.2, -7), deskCenter, Color3.fromRGB(235, 238, 240), Color3.fromRGB(48, 55, 62))
		s4.Parent = folder
	end
	
	for index,model in ipairs(folder:GetChildren()) do
		local root=model:FindFirstChild("HumanoidRootPart")
		local h=model:FindFirstChildOfClass("Humanoid")
		if root and h then
			h.EvaluateStateMachine=false
			for _,v in ipairs(model:GetDescendants()) do if v:IsA("BasePart") then
				v.Anchored=v==root;v.CanCollide=false;v.CanTouch=false;v.CanQuery=false;v.Massless=true;v.CollisionGroup="PenFightVisual"
			end end
			SchoolStyle.Apply(model, index <= 2 and "Blue" or "Red", false)
		end
	end
	return self
end

function Spectator:Impact(intensity)
	if intensity < 0.4 then return end
	local now = workspace:GetServerTimeNow()
	for _, spec in ipairs(self.folder:GetChildren()) do
		spec:SetAttribute("ImpactLevel", intensity)
		spec:SetAttribute("ReactAt", now)
	end
end

function Spectator:Winner(winner)
	local now = workspace:GetServerTimeNow()
	for _, spec in ipairs(self.folder:GetChildren()) do
		spec:SetAttribute("CheerAt", now)
	end
end

return Spectator
