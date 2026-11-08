-- Presentation only. The existing body parts and rig joints retain their physics.
local Style = {}
local cream = Color3.fromRGB(233, 224, 195)
local navy = Color3.fromRGB(43, 60, 76)
local brass = Color3.fromRGB(221, 166, 77)
local blue = Color3.fromRGB(31, 93, 160)
local red = Color3.fromRGB(144, 53, 59)
local skinByStudent = {
	Student_Rohan = Color3.fromRGB(193, 141, 100),
	Student_Priya = Color3.fromRGB(179, 119, 88),
	Student_Amit = Color3.fromRGB(218, 163, 116),
	Student_Vikram = Color3.fromRGB(156, 105, 77),
}

local function clothPanel(parent, name, x, y, width, height, color, rotation)
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.Position = UDim2.fromScale(x, y)
	panel.Size = UDim2.fromScale(width, height)
	panel.BackgroundColor3 = color
	panel.BorderSizePixel = 0
	panel.Rotation = rotation or 0
	panel.Parent = parent
	return panel
end

local function uniformMark(torso, accent, personalAvatar)
	local previous = torso:FindFirstChild("SchoolUniform")
	if previous then previous:Destroy() end
	local surface = Instance.new("SurfaceGui")
	surface.Name = "SchoolUniform"
	surface.CanvasSize = Vector2.new(160, 140)
	surface.Face = Enum.NormalId.Front
	surface.LightInfluence = .55
	surface.MaxDistance = 64
	surface.Parent = torso

	if not personalAvatar then
		clothPanel(surface, "CollarLeft", .36, .07, .11, .15, navy, -28)
		clothPanel(surface, "CollarRight", .53, .07, .11, .15, navy, 28)
		clothPanel(surface, "Tie", .47, .17, .065, .56, accent)
		clothPanel(surface, "TieKnot", .47, .15, .065, .085, accent, 45)
		clothPanel(surface, "PocketSeam", .68, .31, .18, .025, navy)
		clothPanel(surface, "Hem", .04, .86, .92, .035, navy)
	end

	local crest = clothPanel(surface, "HouseCrest", .70, .35, .135, .17, accent)
	local badge = Instance.new("TextLabel")
	badge.Text = "7B"
	badge.Font = Enum.Font.GothamBlack
	badge.TextScaled = true
	badge.TextColor3 = brass
	badge.BackgroundTransparency = 1
	badge.Size = UDim2.fromScale(1, 1)
	badge.Parent = crest
end

local function hairpiece(parent, head, name, scale, offset, tint)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Ball
	part.Size = head.Size * scale
	part.CFrame = head.CFrame * CFrame.new(head.Size * offset)
	part.Color = tint
	part.Material = Enum.Material.SmoothPlastic
	part.Massless = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.CollisionGroup = "PenFightVisual"
	part.Parent = parent
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = part
	weld.Parent = part
end

function Style.Apply(model, id, personalAvatar)
	local torso = model:FindFirstChild("UpperTorso")
	if not torso then return end
	local accent = id == "Blue" and blue or red
	uniformMark(torso, accent, personalAvatar)
	if personalAvatar then return end

	local skin = skinByStudent[model.Name] or Color3.fromRGB(204, 151, 108)
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") then
			local name = part.Name
			if name == "UpperTorso" or name:find("UpperArm") then
				part.Color = cream
			elseif name == "LowerTorso" or name:find("UpperLeg") or name:find("Foot") then
				part.Color = navy
			elseif name:find("LowerLeg") then
				part.Color = Color3.fromRGB(191, 192, 179)
			elseif name == "Head" or name:find("LowerArm") or name:find("Hand") then
				part.Color = skin
			end
		end
	end

	local head = model:FindFirstChild("Head")
	if not head then return end
	local oldHair = model:FindFirstChild("SchoolHair")
	if oldHair then oldHair:Destroy() end
	local hair = Instance.new("Folder")
	hair.Name = "SchoolHair"
	hair.Parent = model
	local dark = model.Name == "Student_Amit" and Color3.fromRGB(56, 37, 28) or Color3.fromRGB(35, 29, 25)
	hairpiece(hair, head, "Crown", Vector3.new(1.02, .48, .97), Vector3.new(0, .36, .06), dark)
	hairpiece(hair, head, "Parting", Vector3.new(.68, .27, .72), Vector3.new(-.17, .45, -.09), dark:Lerp(cream, .08))
	if model.Name == "Student_Priya" then
		hairpiece(hair, head, "Braid", Vector3.new(.32, .77, .32), Vector3.new(.25, -.12, .51), dark)
	end
end

return Style
