local PenFinish = {}

local finishes = {
	Blue = {
		enamel = Color3.fromRGB(19, 73, 172),
		accent = Color3.fromRGB(89, 170, 242),
		barrel = Color3.fromRGB(188, 220, 239),
		ink = Color3.fromRGB(27, 60, 114),
	},
	Red = {
		enamel = Color3.fromRGB(173, 34, 44),
		accent = Color3.fromRGB(244, 124, 110),
		barrel = Color3.fromRGB(244, 201, 188),
		ink = Color3.fromRGB(127, 30, 45),
	},
}

function PenFinish.Apply(model, id)
	local finish = assert(finishes[id], "Unknown pen finish")
	local barrel = model:FindFirstChild("Barrel")
	if not barrel then return end
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") and part ~= model.PrimaryPart then
			if part.Name == "Barrel" then
				part.Color = finish.barrel
				part.Transparency = .13
			elseif part.Name == "InkCore" then
				part.Color = finish.ink
			elseif part.Name:match("^GripRing") then
				part.Color = finish.accent:Lerp(finish.enamel, .42)
			elseif part.Name == "NibHousing" or part.Name == "EndPlug" then
				part.Color = Color3.fromRGB(204, 205, 194)
				part.Material = Enum.Material.Metal
			elseif part.Name == "Ballpoint" then
				part.Color = Color3.fromRGB(70, 75, 83)
			elseif part.Name == "PocketClip" or part.Name == "ClipMount" then
				part.Color = finish.accent
				part.Material = Enum.Material.Metal
			else
				part.Color = finish.enamel
			end
		end
	end

	local previous = barrel:FindFirstChild("RecessImprint")
	if previous then previous:Destroy() end
	local imprint = Instance.new("SurfaceGui")
	imprint.Name = "RecessImprint"
	imprint.Face = Enum.NormalId.Top
	imprint.CanvasSize = Vector2.new(380, 58)
	imprint.LightInfluence = .35
	imprint.MaxDistance = 72
	imprint.Parent = barrel
	local mark = Instance.new("TextLabel")
	mark.BackgroundTransparency = 1
	mark.Position = UDim2.fromScale(.25, .32)
	mark.Size = UDim2.fromScale(.55, .38)
	mark.Text = "RECESS   /   0.7"
	mark.TextColor3 = finish.ink
	mark.Font = Enum.Font.GothamBold
	mark.TextScaled = true
	mark.Parent = imprint
end

return PenFinish
