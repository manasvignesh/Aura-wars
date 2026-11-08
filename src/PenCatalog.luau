-- Display tiers describe familiar classroom pens. Only cost is an Aura price.
local Catalog = {Version = 2, Default = "recess"}
local T = require(script.Parent.PhysicsTuning)
local function pen(id, name, tier, cost, description, density, friction, speed, spin, tint, rings)
	return table.freeze({id = id, name = name, tier = tier, cost = cost, description = description,
		density = density, friction = friction, speed = speed, spin = spin, tint = tint, rings = rings})
end
Catalog.Items = table.freeze({
	pen("recess", "Classic", "₹5", 0, "Balanced travel and spin.", T.Density, T.SurfaceFriction, 1, 1, Color3.fromRGB(188,220,239), 0),
	pen("gripper", "Gripper", "₹10", 100, "High grip stops sooner. Stronger launches compensate on short shots.", 1.4, .18, 1.04, .85, Color3.fromRGB(44,60,64), 2),
	pen("swift", "Swift", "₹20", 250, "Light and fast, with less mass to transfer on impact.", 1.20, .08, 1.07, 1, Color3.fromRGB(227,224,205), 3),
	pen("spinner", "Spinner", "₹30", 500, "More spin on off-centre flicks, with a slower straight launch.", 1.4, .105, .92, 1.28, Color3.fromRGB(100,88,123), 4),
	pen("heavyweight", "Heavyweight", "₹50", 850, "More mass at contact, with a slower launch and less spin.", 1.63, .105, .88, .84, Color3.fromRGB(87,104,112), 5),
	pen("precision", "Precision", "₹100", 1300, "Low spin and a slower launch. Lower grip rewards careful alignment.", 1.4, .075, .94, .60, Color3.fromRGB(179,149,90), 1),
})

function Catalog.Get(id)
	for _, item in ipairs(Catalog.Items) do
		if item.id == id then return item end
	end
end

function Catalog.Paint(model, team, id)
	local item = Catalog.Get(id) or Catalog.Items[1]
	local red = team == "Red"
	local enamel = red and Color3.fromRGB(173,34,44) or Color3.fromRGB(19,73,172)
	local accent = red and Color3.fromRGB(244,124,110) or Color3.fromRGB(89,170,242)
	local barrel = model:FindFirstChild("Barrel")
	if barrel then
		barrel.Color = item.cost == 0 and (red and Color3.fromRGB(244,201,188) or item.tint) or item.tint:Lerp(accent, .22)
		barrel.Transparency = item.cost == 0 and .13 or .04
		local imprint = barrel:FindFirstChild("RecessImprint")
		local label = imprint and imprint:FindFirstChildOfClass("TextLabel")
		if label then label.Text = item.name:upper() .. "   /   0.7" end
	end
	for _, part in ipairs(model:GetChildren()) do
		local ring = tonumber(part.Name:match("^GripRing(%d+)$"))
		if ring and part:IsA("BasePart") then part.Color = ring <= item.rings and accent or accent:Lerp(enamel, .42) end
	end
end

return table.freeze(Catalog)
