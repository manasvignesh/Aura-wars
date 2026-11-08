local Settings = require(game.ReplicatedStorage.PenFight.Settings)
local T = require(game.ReplicatedStorage.PenFight.PhysicsTuning)
local PenFinish = require(script.Parent.PenFinish)
local Catalog = require(game.ReplicatedStorage.PenFight.PenCatalog)
local Factory = {}

function Factory.ApplyHandling(model, id)
	local item = Catalog.Get(id) or Catalog.Items[1]
	local body = model.PrimaryPart
	local properties = PhysicalProperties.new(item.density, item.friction, T.PenElasticity, 100, 100)
	body.CustomPhysicalProperties = properties
	local tip = model:FindFirstChild("Ballpoint")
	if tip and tip:IsA("BasePart") then
		tip.CustomPhysicalProperties = properties
	end
	model:SetAttribute("EquippedPen", item.id)
end

function Factory.ConfigureCollision(model)
	local body = model.PrimaryPart
	body.CollisionGroup = "Pens"
	local tip = model:FindFirstChild("Ballpoint")
	if tip and tip:IsA("BasePart") then
		tip.CollisionGroup = "PenFightTips"
		tip.CanCollide = true
		tip.CanTouch = true
	end
	Factory.ApplyHandling(model, Catalog.Default)
	body:SetNetworkOwner(nil)
end

function Factory.SpawnCFrame(id)
	local offset = if id == "Blue" then Vector3.new(-Settings.SpawnX, Settings.SpawnHeight, -Settings.SpawnZ) else Vector3.new(Settings.SpawnX, Settings.SpawnHeight, Settings.SpawnZ)
	return CFrame.new(Settings.Origin + offset) * CFrame.Angles(0, math.rad(if id == "Blue" then 25 else 205), 0)
end

function Factory.Create(parent, id)
	local model = Instance.new("Model")
	model.Name = id
	model:SetAttribute("PenId", id)
	local root = Instance.new("Part")
	root.Name = "Body"
	root.Size = Settings.PenSize
	root.Transparency = 1
	root.Anchored = false
	root.CustomPhysicalProperties = PhysicalProperties.new(T.Density, T.SurfaceFriction, T.PenElasticity, 100, 100)
	root.RootPriority = 127
	root.CFrame = Factory.SpawnCFrame(id)
	root.Parent = model
	model.PrimaryPart = root
	local color = Settings[id]
	local function visual(name, size, offset, tint, material, cylinder)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = tint
		part.Material = material or Enum.Material.SmoothPlastic
		if cylinder then part.Shape = Enum.PartType.Cylinder end
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.CFrame = root.CFrame * CFrame.new(offset)
		part.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		return part
	end
	visual("Barrel", Vector3.new(3.8, .58, .58), Vector3.new(-.1, 0, 0), Color3.fromRGB(223, 229, 218), nil, true)
	visual("InkCore", Vector3.new(3.4, .15, .15), Vector3.new(-.1, .26, 0), color, nil, true)
	visual("Grip", Vector3.new(1.15, .63, .63), Vector3.new(1.85, 0, 0), color, nil, true)
	for i = 1, 6 do
		visual("GripRing" .. i, Vector3.new(.035, .65, .65), Vector3.new(1.37 + i * .14, 0, 0), color:Lerp(Color3.new(0,0,0), .22), nil, true)
	end
	visual("NibHousing", Vector3.new(.42, .42, .42), Vector3.new(2.58, 0, 0), Color3.fromRGB(180, 188, 192), Enum.Material.Metal, true)
	visual("Ballpoint", Vector3.new(.18, .16, .16), Vector3.new(2.87, 0, 0), Color3.fromRGB(52, 58, 66), Enum.Material.Metal, true)
	visual("Cap", Vector3.new(.65, .64, .64), Vector3.new(-2.33, 0, 0), color, nil, true)
	visual("EndPlug", Vector3.new(.13, .49, .49), Vector3.new(-2.73, 0, 0), color, nil, true)
	visual("PocketClip", Vector3.new(1.15, .1, .15), Vector3.new(-1.92, .36, .12), color)
	visual("ClipMount", Vector3.new(.13, .2, .15), Vector3.new(-2.45, .29, .12), color)
	PenFinish.Apply(model, id)
	model.Parent = parent
	return model
end

return Factory
