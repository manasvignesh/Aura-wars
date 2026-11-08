-- BuildPhase2BScene.studio.luau
-- Builds the stylized Indian classroom environment, props, lighting, and spectator seating for Phase 2B.
-- Run in Studio Edit mode.

local S = require(game.ReplicatedStorage.PenFight.Settings)
local arena = workspace:WaitForChild("PenFight")
local env = arena:WaitForChild("Environment")
local desk = arena:WaitForChild("Desk")

local function part(parent, name, size, cf, color, material, canCollide)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = canCollide == true
	p.CanTouch = canCollide == true
	p.CanQuery = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CollisionGroup = "Environment"
	p.Parent = parent
	return p
end

-- 1. CEILING & BEAMS
local ceilingFolder = env:FindFirstChild("Ceiling") or Instance.new("Folder")
ceilingFolder.Name = "Ceiling"
ceilingFolder.Parent = env

-- Main ceiling
part(ceilingFolder, "CeilingPlaster", Vector3.new(75, 1, 75), CFrame.new(S.Origin + Vector3.new(0, 24, 0)), Color3.fromRGB(242, 238, 228), Enum.Material.Concrete, true)

-- Wooden support beams across ceiling
for _, z in ipairs({-25, 0, 25}) do
	part(ceilingFolder, "CeilingBeam", Vector3.new(75, 1.2, 1.2), CFrame.new(S.Origin + Vector3.new(0, 23.4, z)), Color3.fromRGB(78, 48, 28), Enum.Material.Wood, false)
end

-- 2. CEILING FANS (Classic Indian 3-blade hanging fans)
local fansFolder = env:FindFirstChild("CeilingFans") or Instance.new("Folder")
fansFolder.Name = "CeilingFans"
fansFolder.Parent = env

local function createCeilingFan(position)
	local fanModel = Instance.new("Model")
	fanModel.Name = "CeilingFan"
	
	-- Downrod
	local rod = part(fanModel, "Downrod", Vector3.new(0.3, 4.5, 0.3), CFrame.new(position + Vector3.new(0, 2, 0)), Color3.fromRGB(72, 68, 62), Enum.Material.Metal, false)
	-- Canopy
	part(fanModel, "Canopy", Vector3.new(1.2, 0.6, 1.2), CFrame.new(position + Vector3.new(0, 4, 0)), Color3.fromRGB(85, 80, 72), Enum.Material.Metal, false).Shape = Enum.PartType.Cylinder
	-- Motor hub
	local hub = part(fanModel, "MotorHub", Vector3.new(2.2, 0.8, 2.2), CFrame.new(position), Color3.fromRGB(92, 86, 78), Enum.Material.Metal, false)
	hub.Shape = Enum.PartType.Cylinder
	
	-- 3 Blades
	local blades = Instance.new("Model")
	blades.Name = "Blades"
	blades.Parent = fanModel
	
	for i = 1, 3 do
		local angle = math.rad((i - 1) * 120)
		local blade = part(blades, "Blade" .. i, Vector3.new(4.8, 0.08, 0.9), CFrame.new(position) * CFrame.Angles(0, angle, math.rad(4)) * CFrame.new(3.2, 0, 0), Color3.fromRGB(75, 70, 64), Enum.Material.Metal, false)
		blade.CastShadow = true
	end
	
	fanModel.PrimaryPart = hub
	fanModel.Parent = fansFolder
	return fanModel
end

createCeilingFan(S.Origin + Vector3.new(-12, 18.5, -8))
createCeilingFan(S.Origin + Vector3.new(12, 18.5, 12))

-- 3. WINDOWS ON LEFT WALL (Indian classroom iron grills & wooden frame)
local windowsFolder = env:FindFirstChild("Windows") or Instance.new("Folder")
windowsFolder.Name = "Windows"
windowsFolder.Parent = env

local function createWindow(centerZ)
	local winCf = CFrame.new(S.Origin + Vector3.new(-36.8, 12, centerZ))
	-- Outer Frame
	part(windowsFolder, "WindowFrame", Vector3.new(0.6, 10, 12), winCf, Color3.fromRGB(105, 68, 42), Enum.Material.Wood, true)
	-- Glass Pane (translucent warm daylight)
	local glass = part(windowsFolder, "WindowGlass", Vector3.new(0.2, 8.8, 10.8), winCf, Color3.fromRGB(210, 235, 245), Enum.Material.Glass, false)
	glass.Transparency = 0.55
	
	-- Vertical Iron Grills
	for dz = -4.5, 4.5, 1.5 do
		part(windowsFolder, "WindowBar", Vector3.new(0.25, 8.8, 0.25), winCf * CFrame.new(0.2, 0, dz), Color3.fromRGB(48, 52, 54), Enum.Material.Metal, false)
	end
	-- Horizontal Iron Bars
	for dy = -3.2, 3.2, 2.1 do
		part(windowsFolder, "WindowBarH", Vector3.new(0.25, 0.25, 10.8), winCf * CFrame.new(0.2, dy, 0), Color3.fromRGB(48, 52, 54), Enum.Material.Metal, false)
	end
	
	-- Sunlight Point Light from window
	local sunLight = Instance.new("PointLight")
	sunLight.Name = "SunBeam"
	sunLight.Color = Color3.fromRGB(255, 242, 210)
	sunLight.Brightness = 1.6
	sunLight.Range = 38
	sunLight.Shadows = true
	sunLight.Parent = glass
end

createWindow(-15)
createWindow(15)

-- 4. CLASSROOM POSTERS (Periodic Table & Solar System charts)
local postersFolder = env:FindFirstChild("Posters") or Instance.new("Folder")
postersFolder.Name = "Posters"
postersFolder.Parent = env

local function createPoster(cf, size, title, subtitle, bgColor)
	local p = part(postersFolder, "PosterBoard", size, cf, bgColor, Enum.Material.SmoothPlastic, false)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "PosterGui"
	sg.Face = Enum.NormalId.Back
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 50
	sg.Parent = p
	
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = bgColor
	bg.BorderSizePixel = 0
	bg.Parent = sg
	
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -20, 0, 32)
	t.Position = UDim2.fromOffset(10, 10)
	t.BackgroundTransparency = 1
	t.Text = title
	t.Font = Enum.Font.GothamBold
	t.TextSize = 16
	t.TextColor3 = Color3.fromRGB(24, 30, 38)
	t.TextXAlignment = Enum.TextXAlignment.Center
	t.Parent = bg
	
	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, -20, 1, -45)
	sub.Position = UDim2.fromOffset(10, 42)
	sub.BackgroundTransparency = 1
	sub.Text = subtitle
	sub.Font = Enum.Font.GothamMedium
	sub.TextSize = 11
	sub.TextColor3 = Color3.fromRGB(60, 70, 80)
	sub.TextWrapped = true
	sub.TextYAlignment = Enum.TextYAlignment.Top
	sub.Parent = bg
end

createPoster(CFrame.new(S.Origin + Vector3.new(-22, 14, -29.2)), Vector3.new(8, 6, 0.1), "PERIODIC TABLE OF ELEMENTS", "H  He  Li  Be  B  C  N  O  F  Ne\nNa Mg Al Si  P  S  Cl Ar  K  Ca\nStandard Atomic Weights 2026\nClassroom Chart No. 4", Color3.fromRGB(248, 245, 235))
createPoster(CFrame.new(S.Origin + Vector3.new(22, 14, -29.2)), Vector3.new(8, 6, 0.1), "THE SOLAR SYSTEM", "Sun • Mercury • Venus • Earth • Mars • Jupiter • Saturn • Uranus • Neptune\nOrbital Mechanics & Physics\nCentral Board of Secondary Education", Color3.fromRGB(240, 244, 250))

-- 5. STATIONERY & PROPS (School bags, notebooks, pencils)
local propsFolder = env:FindFirstChild("ClassroomProps") or Instance.new("Folder")
propsFolder.Name = "ClassroomProps"
propsFolder.Parent = env

-- Helper: School Bag (Basta)
local function createSchoolBag(pos, rotationY, color)
	local bag = Instance.new("Model")
	bag.Name = "SchoolBag"
	local main = part(bag, "MainPouch", Vector3.new(2.2, 2.8, 1.4), CFrame.new(pos) * CFrame.Angles(0, math.rad(rotationY), math.rad(4)), color, Enum.Material.Fabric, false)
	part(bag, "FrontPocket", Vector3.new(1.8, 1.5, 0.5), main.CFrame * CFrame.new(0, -0.4, 0.85), color:Lerp(Color3.new(0,0,0), 0.2), Enum.Material.Fabric, false)
	part(bag, "Zipper", Vector3.new(1.6, 0.08, 0.52), main.CFrame * CFrame.new(0, 0.35, 0.85), Color3.fromRGB(210, 210, 210), Enum.Material.Metal, false)
	part(bag, "Handle", Vector3.new(0.8, 0.35, 0.15), main.CFrame * CFrame.new(0, 1.5, 0), Color3.fromRGB(30, 30, 30), Enum.Material.Fabric, false)
	bag.PrimaryPart = main
	bag:SetAttribute("DecorativeProp", true)
	bag.Parent = propsFolder
	return bag
end

-- Place school bags leaning near neighbor desks
createSchoolBag(S.Origin + Vector3.new(-24, 1.4, -18), 35, Color3.fromRGB(42, 85, 148))
createSchoolBag(S.Origin + Vector3.new(24, 1.4, -18), -25, Color3.fromRGB(152, 48, 54))
createSchoolBag(S.Origin + Vector3.new(-24, 1.4, 22), 70, Color3.fromRGB(48, 92, 58))

-- Helper: Ruled Notebook
local function createNotebook(cf, coverColor)
	local nb = Instance.new("Model")
	nb.Name = "Notebook"
	local cover = part(nb, "Cover", Vector3.new(1.8, 0.08, 2.4), cf, coverColor, Enum.Material.SmoothPlastic, false)
	local pages = part(nb, "Pages", Vector3.new(1.7, 0.06, 2.3), cf * CFrame.new(0.04, 0.04, 0), Color3.fromRGB(250, 248, 242), Enum.Material.SmoothPlastic, false)
	
	-- Open page surface with red margin
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Top
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 60
	sg.Parent = pages
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = Color3.fromRGB(250, 248, 242)
	f.BorderSizePixel = 0
	f.Parent = sg
	
	-- Red margin line
	local margin = Instance.new("Frame")
	margin.Size = UDim2.new(0, 2, 1, 0)
	margin.Position = UDim2.fromScale(0.18, 0)
	margin.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
	margin.BorderSizePixel = 0
	margin.Parent = f
	
	-- Subtle blue ruled lines
	for i = 1, 8 do
		local line = Instance.new("Frame")
		line.Size = UDim2.new(1, 0, 0, 1)
		line.Position = UDim2.fromScale(0, i / 9)
		line.BackgroundColor3 = Color3.fromRGB(180, 205, 230)
		line.BorderSizePixel = 0
		line.Parent = f
	end
	
	-- Pencil next to notebook
	part(nb, "Pencil", Vector3.new(0.12, 0.12, 1.6), cf * CFrame.new(1.2, 0.06, 0.2) * CFrame.Angles(0, math.rad(15), 0), Color3.fromRGB(235, 175, 45), Enum.Material.Wood, false)
	
	nb.PrimaryPart = cover
	nb:SetAttribute("DecorativeProp", true)
	nb.Parent = propsFolder
	return nb
end

-- Place notebooks on neighbor desks
createNotebook(CFrame.new(S.Origin + Vector3.new(-22, 6.9, -14)) * CFrame.Angles(0, math.rad(12), 0), Color3.fromRGB(185, 45, 45))
createNotebook(CFrame.new(S.Origin + Vector3.new(22, 6.9, -14)) * CFrame.Angles(0, math.rad(-8), 0), Color3.fromRGB(45, 95, 165))

-- Chalk Eraser (Duster) on chalkboard tray
local duster = part(propsFolder, "ChalkEraser", Vector3.new(2.2, 0.5, 0.8), CFrame.new(S.Origin + Vector3.new(4, 8.35, -28.1)), Color3.fromRGB(115, 75, 45), Enum.Material.Wood, false)
part(propsFolder, "EraserFelt", Vector3.new(2.1, 0.15, 0.75), duster.CFrame * CFrame.new(0, -0.3, 0), Color3.fromRGB(185, 180, 170), Enum.Material.Fabric, false)

-- 6. TEACHER'S PODIUM TABLE in front corner
local podium = Instance.new("Model")
podium.Name = "TeacherDesk"
part(podium, "PodiumTop", Vector3.new(7, 0.8, 5), CFrame.new(S.Origin + Vector3.new(28, 8, -24)), Color3.fromRGB(112, 70, 38), Enum.Material.Wood, true)
for _, dx in ipairs({-3, 3}) do for _, dz in ipairs({-2, 2}) do
	part(podium, "PodiumLeg", Vector3.new(0.55, 7.6, 0.55), CFrame.new(S.Origin + Vector3.new(28 + dx, 3.8, -24 + dz)), Color3.fromRGB(42, 52, 50), Enum.Material.Metal, true)
end end
podium.Parent = propsFolder

-- 7. RIGHT WALL (Enclosing classroom symmetrically)
local rightWall = env:FindFirstChild("RightWall") or part(env, "RightWall", Vector3.new(1, 24, 75), CFrame.new(S.Origin + Vector3.new(37, 11.5, 0)), Color3.fromRGB(230, 225, 215), Enum.Material.Concrete, true)
local frontWall = env:FindFirstChild("FrontWall") or part(env, "FrontWall", Vector3.new(75, 24, 1), CFrame.new(S.Origin + Vector3.new(0, 11.5, 37)), Color3.fromRGB(230, 225, 215), Enum.Material.Concrete, true)

-- Adjust Blackboard Chalk Text for Phase 2B
local blackboard = env:FindFirstChild("Blackboard")
if blackboard and blackboard:FindFirstChild("ChalkWriting") then
	local tl = blackboard.ChalkWriting:FindFirstChild("TextLabel")
	if tl then
		tl.Text = "PEN FIGHT: THE AURA WARS\nPeriod 5: Physics & Spirit\nAfter class. On the desk. Winner stays."
	end
end

-- 8. LIGHTING SETTINGS
local lighting = game:GetService("Lighting")
lighting.Brightness = 2.4
lighting.ClockTime = 16.2 -- 4:12 PM warm afternoon sun
lighting.GeographicLatitude = 20.59 -- India latitude (subtropical warm sunlight)
lighting.Ambient = Color3.fromRGB(115, 110, 105)
lighting.OutdoorAmbient = Color3.fromRGB(140, 130, 118)
lighting.ColorShift_Top = Color3.fromRGB(255, 240, 215)
lighting.ShadowSoftness = 0.35

return "Phase 2B Classroom Visual Overhaul built successfully!"
