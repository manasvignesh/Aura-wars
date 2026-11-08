-- Apply once in Studio Edit mode to the backed-up Phase 3A place.
local arena = workspace.PenFight
assert(arena:GetAttribute("Phase3AScene"), "Phase 4A requires the Phase 3A arena")
assert(not arena:GetAttribute("Phase4AArt"), "Phase 4A art is already installed")

local env = arena.Environment
local desk = arena.Desk
local top = desk.Tabletop
local materials = Enum.Material
local rgb = Color3.fromRGB
local plaster = rgb(224, 207, 173)
local cream = rgb(245, 223, 177)
local pale = rgb(211, 193, 155)
local jade = rgb(62, 112, 103)
local deepJade = rgb(32, 67, 64)
local teak = rgb(147, 94, 49)
local edge = rgb(96, 53, 30)
local iron = rgb(43, 53, 54)
local brass = rgb(191, 138, 67)
local chalk = rgb(239, 229, 194)
local ink = rgb(45, 60, 58)
local collection = game:GetService("CollectionService")
local rng = Random.new(712)

local function folder(parent, name)
	local node = Instance.new("Folder")
	node.Name = name
	node.Parent = parent
	return node
end

local function part(parent, name, size, cf, color, material)
	local node = Instance.new("Part")
	node.Name = name
	node.Size = size
	node.CFrame = cf
	node.Color = color
	node.Material = material or materials.SmoothPlastic
	node.Anchored = true
	node.CanCollide = false
	node.CanTouch = false
	node.CanQuery = false
	node.CastShadow = false
	node.Parent = parent
	return node
end

local function box(parent, name, sx, sy, sz, x, y, z, color, material)
	return part(parent, name, Vector3.new(sx, sy, sz), CFrame.new(x, y, z), color, material)
end

local function face(parent, name, normal, width, height, maxDistance)
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = normal
	gui.CanvasSize = Vector2.new(width, height)
	gui.LightInfluence = .3
	gui.MaxDistance = maxDistance or 125
	gui.Parent = parent
	return gui
end

local function text(gui, name, value, x, y, w, h, font, size, color, align)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Text = value
	label.Font = font
	label.TextSize = size
	label.TextColor3 = color
	label.TextXAlignment = align or Enum.TextXAlignment.Left
	label.Position = UDim2.fromOffset(x, y)
	label.Size = UDim2.fromOffset(w, h)
	label.Parent = gui
	return label
end

local function rule(gui, x, y, w, h, color, alpha)
	local frame = Instance.new("Frame")
	frame.Name = "Rule"
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = alpha or 0
	frame.Position = UDim2.fromOffset(x, y)
	frame.Size = UDim2.fromOffset(w, h)
	frame.Parent = gui
	return frame
end

local function hideOld(node)
	if node:IsA("BasePart") then
		node.Transparency = 1
		node.CastShadow = false
	elseif node:IsA("SurfaceGui") or node:IsA("Light") then
		node.Enabled = false
	end
end

-- Arena art. The original Tabletop, apron, steel supports, and guard remain the colliders.
local finish = folder(desk, "TeakFinish")
top.Color = rgb(179, 122, 70)
for _, node in ipairs(desk:GetChildren()) do
	if not node:IsA("BasePart") then continue end
	if node.Name == "WoodWear" then
		node.Color = rgb(112, 72, 43)
		node.Transparency = .58
		collection:AddTag(node, "PenFightFineArt")
	elseif node.Name == "FrontEdge" or node.Name == "BackEdge" or node.Name == "SideApron" then
		node.Color = edge
	elseif node.Material == materials.Metal then
		node.Color = node.Name == "RecessedScrew" and brass or deepJade
	end
end

for _, sign in ipairs({-1, 1}) do
	local z = 100 + sign * 2.905
	box(finish, "DarkEndgrain", 20, .30, .036, 0, 5.38, z, edge, materials.Wood)
	box(finish, "LaminatedLip", 19.94, .056, .042, 0, 5.53, z, rgb(218, 158, 88), materials.Wood)
	box(finish, "LowerBead", 19.91, .042, .032, 0, 5.25, z, rgb(68, 42, 31), materials.Wood)
	local badge = part(finish, "DeskNumber", Vector3.new(2.08, .27, .035),
		CFrame.lookAt(Vector3.new(0, 5.14, z + sign * .045), Vector3.new(0, 5.14, z + sign)), brass, materials.Metal)
	local plate = face(badge, "DeskPlate", Enum.NormalId.Front, 208, 27, 38)
	text(plate, "Number", "VII–B    /    07", 0, 0, 208, 27, Enum.Font.GothamBold, 17, ink, Enum.TextXAlignment.Center)
	for _, x in ipairs({-9.333, 9.333}) do
		box(finish, "FootCap", .50, .11, .255, x, .165, 100 + sign * 2.61, iron)
	end
end

for _, sign in ipairs({-1, 1}) do
	box(finish, "ShortEndBand", .037, .22, 5.77, sign * 10.01, 5.41, 100, edge, materials.Wood)
end
local tabletopArt = face(top, "DeskInkAndScuffs", Enum.NormalId.Top, 1000, 290, 56)
text(tabletopArt, "CarvedInitials", "R + P", 68, 193, 90, 37, Enum.Font.PatrickHand, 28, rgb(91, 59, 39)).Rotation = -9
text(tabletopArt, "PencilTally", "Ⅲ  /  Ⅱ", 822, 50, 100, 32, Enum.Font.PatrickHand, 27, rgb(100, 62, 40)).Rotation = 5
text(tabletopArt, "ClassMark", "7B", 480, 236, 42, 28, Enum.Font.PatrickHand, 23, rgb(112, 71, 43)).Rotation = -5
for index = 1, 12 do
	local x = rng:NextInteger(30, 940)
	local scratch = rule(tabletopArt, x, rng:NextInteger(20, 266), rng:NextInteger(15, 60), 1, index % 2 == 0 and cream or edge, .62)
	scratch.Rotation = rng:NextNumber(-8, 8)
end

local server = game.ServerScriptService.PenFight
local PenFinish = require(server.PenFinish)
for _, pen in ipairs(arena.Pens:GetChildren()) do
	PenFinish.Apply(pen, pen.Name)
end

-- Architecture. Existing wall and window collision parts are retained behind the visible shell.
local art = folder(env, "Phase4AArt")
local shell = folder(art, "Architecture")
local floorArt = folder(art, "Terrazzo")
local story = folder(art, "ClassroomStories")
local furniture = folder(art, "FurnitureFinish")
local exterior = folder(art, "Courtyard")
env.LeftWall.Transparency = 1
env.LeftWall.CastShadow = false
for _, node in ipairs(env.Windows:GetDescendants()) do hideOld(node) end

for _, wall in ipairs({env.BackWall, env.RightWall, env.FrontWall}) do
	wall.Color = plaster
end
env.WallDado.Color = jade
env.ClassroomFloor.Color = rgb(164, 151, 128)

local windowBottom, windowTop = 7.45, 19.6
local minZ, maxZ = 69.5, 137.5
local centers = {82.5, 102.5, 122.5}
local halfWindow = 6.6
local function leftSpan(name, loY, hiY, loZ, hiZ, tint)
	local node = box(shell, name, .94, hiY-loY, hiZ-loZ, -37, (loY+hiY)/2, (loZ+hiZ)/2, tint, materials.Plaster)
	node.CastShadow = true
	return node
end
leftSpan("WestWallBase", -.5, windowBottom, minZ, maxZ, plaster)
leftSpan("WestWallLintel", windowTop, 23.5, minZ, maxZ, plaster)
local previousZ = minZ
for index, z in ipairs(centers) do
	leftSpan("WestPier"..index, windowBottom, windowTop, previousZ, z-halfWindow, pale)
	previousZ = z+halfWindow
end
leftSpan("WestPierEnd", windowBottom, windowTop, previousZ, maxZ, pale)

for index, z in ipairs(centers) do
	local bay = folder(shell, "WestWindow_"..index)
	local y = (windowBottom+windowTop)/2
	local height = windowTop-windowBottom
	for _, dy in ipairs({-height/2, height/2}) do
		local casing = box(bay, "TeakCrosspiece", 1.0, .38, 13.64, -36.54, y+dy, z, teak, materials.Wood)
		casing.CastShadow = true
		box(bay, "PaintedInset", .095, .11, 13.15, -35.99, y+dy, z, jade)
	end
	for _, dz in ipairs({-halfWindow, 0, halfWindow}) do
		local mullion = box(bay, "WindowMullion", .84, height, dz == 0 and .22 or .33, -36.54, y, z+dz, edge, materials.Wood)
		mullion.CastShadow = true
	end
	box(bay, "StoneSill", 1.45, .36, 14.05, -36.25, windowBottom-.31, z, pale, materials.Marble)
	box(bay, "SillShadow", .14, .22, 13.8, -35.55, windowBottom-.51, z, rgb(158, 142, 114))
	for dz = -4.8, 4.81, 1.6 do
		local grille = box(bay, "IronGrille", .13, height-.35, .085, -36.47, y, z+dz, iron, materials.Metal)
		grille.CastShadow = true
	end
	for _, dy in ipairs({-2.8, 2.8}) do
		local grille = box(bay, "HorizontalGrille", .13, .11, 13, -36.47, y+dy, z, iron, materials.Metal)
		grille.CastShadow = true
	end
	local rim = box(bay, "GlazingGlint", .035, height-.55, .055, -36.11, y, z-6.21, cream)
	rim.Transparency = .23
	collection:AddTag(rim, "PenFightFineArt")
end

for _, x in ipairs({-36.49, 36.49}) do
	box(shell, "PaintedWainscot", .072, 4.7, 73, x, 2.45, 100, jade, materials.Plaster)
	box(shell, "DadoCap", .13, .14, 73, x, 4.88, 100, deepJade, materials.Wood)
	box(shell, "TerrazzoSkirting", .12, .43, 73, x, .31, 100, rgb(102, 101, 83), materials.Concrete)
end
for _, z in ipairs({70.64, 136.45}) do
	box(shell, "PaintedWainscot", 72.8, 4.7, .078, 0, 2.45, z, jade, materials.Plaster)
	box(shell, "DadoCap", 72.8, .14, .14, 0, 4.88, z, deepJade, materials.Wood)
	box(shell, "TerrazzoSkirting", 72.8, .43, .13, 0, .31, z, rgb(102, 101, 83), materials.Concrete)
end

for x = -32, 32, 8 do
	box(floorArt, "TerrazzoJoint", .075, .012, 65, x, .109, 103, rgb(150, 139, 118))
end
for z = 73, 133, 8 do
	box(floorArt, "TerrazzoJoint", 65, .012, .075, 0, .109, z, rgb(150, 139, 118))
end
for _, mark in ipairs(arena.WalkingLane:GetChildren()) do
	mark.Color = rgb(137, 149, 121)
	mark.Transparency = .28
end
for _, x in ipairs({-11, 11}) do
	for _, z in ipairs({95.6, 104.4}) do
		box(floorArt, "BrassCorner", .07, .008, .68, x, .11, z, brass)
		box(floorArt, "BrassCorner", .67, .008, .07, x, .11, z, brass)
	end
end

local roof = box(env.Ceiling, "LimewashCeiling", 75, .4, 75, 0, 23.71, 100, rgb(221, 206, 173), materials.Plaster)
roof.CanCollide = true
roof.CanQuery = true
roof.CastShadow = true
roof.CollisionGroup = "Environment"
for _, beam in ipairs(env.Ceiling:GetChildren()) do
	if beam.Name == "CeilingBeam" then
		beam.Color = rgb(126, 101, 74)
		beam.CastShadow = true
	end
end

local function sign(parent, name, x, y, z, width, height, direction, background)
	local pos = Vector3.new(x, y, z)
	local cf = CFrame.lookAt(pos, pos+direction)
	part(parent, name.."Frame", Vector3.new(width+.3, height+.28, .18), cf*CFrame.new(0,0,.05), edge, materials.Wood)
	local panel = part(parent, name, Vector3.new(width, height, .1), cf*CFrame.new(0,0,-.069), background)
	return panel
end

-- Visible closed door sits against the original solid front wall.
local door = folder(shell, "ClassroomDoor")
sign(door, "EnamelDoor", 25.5, 6.67, 136.35, 6.6, 13.1, -Vector3.zAxis, deepJade)
for _, y in ipairs({2.3, 6.25, 10.2}) do
	box(door, "RecessedPanel", 5.36, 3.08, .12, 25.5, y, 136.17, jade, materials.Wood)
	box(door, "PanelTopBevel", 5.3, .075, .047, 25.5, y+1.54, 136.07, rgb(96, 143, 119))
end
box(door, "BrassLatchPlate", .22, .72, .11, 28.37, 5.7, 136.03, brass, materials.Metal)
box(door, "LatchHandle", .37, .09, .12, 28.23, 5.73, 135.94, rgb(219, 171, 93), materials.Metal)
local doorSign = sign(door, "ClassSign", 25.5, 14.65, 136.25, 5.2, 1.15, -Vector3.zAxis, cream)
text(face(doorSign, "ClassLabel", Enum.NormalId.Front, 416, 92), "Class", "CLASS   VII–B", 0, 0, 416, 92, Enum.Font.GothamBlack, 45, ink, Enum.TextXAlignment.Center)

-- A light, readable classroom graph rather than an external decal.
local board = env.Blackboard
board.Color = rgb(31, 64, 55)
for _, v in ipairs(board:GetChildren()) do
	if v:IsA("SurfaceGui") then v.Enabled = false end
end
for _, v in ipairs(env:GetChildren()) do
	if v.Name == "BoardFrame" or v.Name == "ChalkTray" then v.Color = teak end
end
local writing = face(board, "RecessChalk", Enum.NormalId.Back, 1160, 360)
text(writing, "School", "GOVT. MODEL SCHOOL     •     CLASS VII–B", 35, 19, 1085, 38, Enum.Font.GothamBold, 24, chalk)
rule(writing, 38, 62, 1084, 2, chalk, .56)
text(writing, "Hindi", "अवकाश", 38, 83, 310, 47, Enum.Font.SourceSansBold, 40, chalk)
text(writing, "MainTitle", "RECESS LEAGUE", 38, 125, 790, 82, Enum.Font.PatrickHand, 81, chalk)
text(writing, "Slogan", "One desk. Two pens. Winner stays.", 42, 213, 780, 45, Enum.Font.PatrickHand, 40, chalk)
text(writing, "PhysicsDoodle", "p = mv        ↗        F = ma", 45, 278, 750, 45, Enum.Font.PatrickHand, 38, rgb(205, 196, 142)).Rotation = -3
rule(writing, 833, 93, 2, 219, chalk, .64)
text(writing, "FixtureHeading", "TODAY'S DRAW", 870, 104, 250, 33, Enum.Font.GothamBold, 23, chalk)
text(writing, "FixtureBlue", "01    BLUE", 870, 162, 240, 42, Enum.Font.PatrickHand, 41, rgb(127, 183, 222))
text(writing, "FixtureRed", "02    RED", 870, 216, 240, 42, Enum.Font.PatrickHand, 41, rgb(235, 148, 128))
text(writing, "Period", "AFTER PERIOD 05", 870, 279, 250, 35, Enum.Font.GothamBold, 22, chalk)

for _, v in ipairs(env.Posters:GetDescendants()) do hideOld(v) end
local schedule = sign(story, "Timetable", -22.4, 13.3, 70.86, 7.15, 5.85, Vector3.zAxis, cream)
local timetable = face(schedule, "Paper", Enum.NormalId.Front, 429, 351)
text(timetable, "Heading", "WEEKLY TIMETABLE", 23, 18, 383, 40, Enum.Font.GothamBlack, 30, ink)
rule(timetable, 24, 64, 381, 3, jade)
for index, row in ipairs({"01    MORNING ASSEMBLY", "02    HINDI", "03    MATHEMATICS", "04    SCIENCE", "05    RECESS   /   BREAK"}) do
	local y = 84+(index-1)*46
	text(timetable, "Lesson"..index, row, 26, y, 370, 36, Enum.Font.GothamMedium, 22, ink)
	rule(timetable, 26, y+39, 365, 1, jade, .55)
end
local bulletin = sign(story, "NoticeBoard", 22.7, 13.35, 70.86, 7.4, 5.75, Vector3.zAxis, rgb(184, 125, 76))
local bulletinGui = face(bulletin, "PinnedNotices", Enum.NormalId.Front, 444, 345)
local sheet = rule(bulletinGui, 29, 36, 224, 252, cream)
sheet.Rotation = -3
text(sheet, "Notice", "HOUSE MEET", 16, 22, 195, 34, Enum.Font.GothamBlack, 24, ink)
text(sheet, "Details", "FRIDAY\n\nBring your\nnotebook and\nteam colours.", 16, 68, 190, 157, Enum.Font.PatrickHand, 27, ink)
local card = rule(bulletinGui, 274, 68, 136, 191, rgb(150, 183, 163))
card.Rotation = 7
text(card, "Note", "LIBRARY\n\nRETURN\nBOOKS\nON MON.", 12, 15, 113, 160, Enum.Font.PatrickHand, 23, ink)
for _, x in ipairs({140, 338}) do rule(bulletinGui, x, 49, 9, 9, rgb(151, 56, 46)) end

local motto = sign(story, "SchoolMotto", 36.34, 15.25, 110, 12, 2.2, -Vector3.xAxis, deepJade)
text(face(motto, "Motto", Enum.NormalId.Front, 600, 110), "Words", "WORK HARD  •  PLAY FAIR", 0, 0, 600, 110, Enum.Font.GothamBold, 43, cream, Enum.TextXAlignment.Center)

-- Furniture embellishments stay within the silhouettes of the existing solid pieces.
for _, boardPart in ipairs(env:GetChildren()) do
	if boardPart.Name == "NeighbourDesk" or boardPart.Name == "Bench" then
		boardPart.Color = boardPart.Name == "Bench" and rgb(120, 77, 45) or teak
		local p, s = boardPart.Position, boardPart.Size
		for _, side in ipairs({-1, 1}) do
			box(furniture, "SeatEndgrain", s.X-.04, .09, .026, p.X, p.Y+.16, p.Z+side*(s.Z/2+.013), edge, materials.Wood)
		end
	elseif boardPart.Name == "NeighbourLeg" then
		boardPart.Color = iron
	end
end
for _, node in ipairs(arena.Seating:GetChildren()) do
	if node:IsA("BasePart") then
		node.Color = node.Name:find("Leg") and deepJade or teak
	end
end

local function book(name, x, y, z, yaw, color, title)
	local cf = CFrame.new(x,y,z)*CFrame.Angles(0,math.rad(yaw),0)
	part(furniture, name.."Back", Vector3.new(2.35,.065,1.72), cf, color)
	part(furniture, name.."Pages", Vector3.new(2.19,.12,1.60), cf*CFrame.new(.035,.09,0), chalk)
	local cover = part(furniture, name.."Cover", Vector3.new(2.35,.065,1.72), cf*CFrame.new(0,.18,0), color)
	part(furniture, name.."Spine", Vector3.new(.115,.23,1.72), cf*CFrame.new(-1.15,.09,0), color:Lerp(ink,.3))
	local gui = face(cover, "CoverStamp", Enum.NormalId.Top, 235, 172, 55)
	text(gui, "Subject", title, 16, 30, 204, 48, Enum.Font.GothamBold, 27, chalk, Enum.TextXAlignment.Center)
	rule(gui, 32, 89, 172, 2, chalk, .35)
	text(gui, "Class", "VII–B  /  TERM 2", 17, 100, 203, 38, Enum.Font.GothamMedium, 17, chalk, Enum.TextXAlignment.Center)
end
book("MathExercise", -25.5, 6.89, 86.7, -11, rgb(68,102,98), "MATHEMATICS")
book("HindiReader", 23.3, 6.89, 86.1, 8, rgb(142,63,55), "HINDI")
book("ScienceReader", 27.3, 6.89, 86.7, -17, rgb(61,88,132), "SCIENCE")
book("AttendanceRegister", 27.0, 8.45, 75.7, -5, rgb(105,55,42), "ATTENDANCE")
book("TeacherNotebook", 28.7, 8.45, 76.2, 8, jade, "TERM 2")
for _, bag in ipairs(env.ClassroomProps:GetChildren()) do
	local pouch = bag:FindFirstChild("MainPouch")
	if not pouch then continue end
	local dark = pouch.Color:Lerp(ink,.32)
	part(furniture, "BastaBinding", Vector3.new(1.96,.11,.08), pouch.CFrame*CFrame.new(0,-.77,1.11), dark, materials.Fabric)
	for _, dx in ipairs({-.52,.52}) do
		part(furniture, "BastaBuckle", Vector3.new(.19,.26,.075), pouch.CFrame*CFrame.new(dx,.04,1.14), brass, materials.Metal)
	end
	local tag = part(furniture, "BagNameTag", Vector3.new(.52,.22,.036), pouch.CFrame*CFrame.new(.20,-.34,1.14), cream)
	text(face(tag, "TagPrint", Enum.NormalId.Back, 104, 44, 46), "Class", "VII–B", 0, 0, 104, 44, Enum.Font.GothamBold, 25, ink, Enum.TextXAlignment.Center)
end

-- Courtyard depth through the apertures. These silhouettes sit outside the playable room.
box(exterior, "CourtyardGround", 62, .4, 103, -68, -.18, 100, rgb(160, 138, 94), materials.Ground)
box(exterior, "SchoolWing", 2.6, 15.8, 53, -86, 7.9, 93, rgb(192, 142, 91), materials.Plaster)
box(exterior, "VerandaRoof", 6.7, .65, 55, -83, 15.9, 93, rgb(117, 73, 52), materials.Wood)
for _, z in ipairs({72, 88, 104, 120}) do
	box(exterior, "VerandaColumn", .8, 15.5, .8, -80.1, 7.7, z, cream, materials.Plaster)
end
for index, z in ipairs({81, 106, 128}) do
	local x = -59-index*2
	box(exterior, "MangoTrunk", 1.05, 12.8, 1.05, x, 6.4, z, rgb(107,80,55), materials.Wood)
	for crown = 1, 3 do
		local leaf = box(exterior, "MangoCrown", 6.4, 5.6, 6.7, x+(crown-2)*2.6, 13.4+(crown%2)*2.1, z+(crown-2)*1.7,
			rgb(82+crown*13, 106+crown*10, 65+crown*5), materials.Grass)
		leaf.Shape = Enum.PartType.Ball
	end
end

-- Configure only presentation. The existing camera hides these ceiling groups from tactical view.
for _, fan in ipairs(env.CeilingFans:GetChildren()) do
	local blades = fan:FindFirstChild("Blades")
	local hub = fan:FindFirstChild("MotorHub")
	if blades and hub then
		blades.WorldPivot = CFrame.new(hub.Position)
		for _, p in ipairs(blades:GetChildren()) do
			if p:IsA("BasePart") then
				p.Color = rgb(85, 74, 60)
				p.CanCollide = false
				p.CanTouch = false
				p.CanQuery = false
				p.CastShadow = false
			end
		end
	end
end

local lighting = game.Lighting
lighting.LightingStyle = Enum.LightingStyle.Realistic
lighting.PrioritizeLightingQuality = false
lighting.GlobalShadows = true
lighting.ClockTime = 16.67
lighting.Brightness = 2.0
lighting.ExposureCompensation = .05
lighting.Ambient = rgb(121, 115, 101)
lighting.OutdoorAmbient = rgb(143, 133, 112)
lighting.EnvironmentDiffuseScale = .58
lighting.EnvironmentSpecularScale = .56
lighting.ShadowSoftness = .32
lighting.ColorShift_Top = rgb(30, 17, 6)
local atmosphere = lighting:FindFirstChildOfClass("Atmosphere")
if atmosphere then
	atmosphere.Density = .12
	atmosphere.Haze = .55
	atmosphere.Glare = 0
	atmosphere.Color = rgb(231, 219, 194)
	atmosphere.Decay = rgb(179, 146, 106)
end
local bloom = lighting:FindFirstChildOfClass("BloomEffect")
if bloom then
	bloom.Intensity = .09
	bloom.Threshold = 1.9
	bloom.Size = 18
	collection:AddTag(bloom, "PenFightRichEffect")
end
local rays = lighting:FindFirstChildOfClass("SunRaysEffect")
if rays then
	rays.Intensity = .037
	rays.Spread = .78
	collection:AddTag(rays, "PenFightRichEffect")
end
local depth = lighting:FindFirstChildOfClass("DepthOfFieldEffect")
if depth then depth.Enabled = false end
local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "ClassroomAfternoon"
grade.Contrast = .035
grade.Saturation = .015
grade.Brightness = .027
grade.TintColor = rgb(255, 246, 232)
grade.Parent = lighting

local fill = env.SoftDeskLight:FindFirstChildOfClass("PointLight")
if fill then
	fill.Brightness = .62
	fill.Color = rgb(255, 227, 185)
	fill.Range = 44
	fill.Shadows = false
end
for _, light in ipairs(env.ClassroomLights:GetDescendants()) do
	if light:IsA("PointLight") then
		light.Brightness = .16
		light.Range = 25
		light.Color = rgb(246, 234, 209)
		light.Shadows = false
	end
end

local SchoolStyle = require(server.SchoolStyle)
for _, model in ipairs(arena.Characters:GetChildren()) do
	SchoolStyle.Apply(model, model.Name, false)
	local label = model:FindFirstChild("ParticipantLabel")
	if label and label:IsA("BillboardGui") then label.Enabled = false end
end
local poses = require(game.ReplicatedStorage.PenFight.AvatarPoses)
local spectatorX = {Student_Rohan = -25.6, Student_Priya = -21.4, Student_Amit = 21.7, Student_Vikram = 26.2}
for _, model in ipairs(arena.Spectators:GetChildren()) do
	local x = spectatorX[model.Name]
	if x then
		local y = model.PrimaryPart.Position.Y
		local pos = Vector3.new(x, y, 93)
		model:PivotTo(CFrame.lookAt(pos, Vector3.new(0, y, 100)))
		poses.PlaceSeated(model)
		SchoolStyle.Apply(model, x < 0 and "Blue" or "Red", false)
	end
end

arena:SetAttribute("Phase4AArt", true)
workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(27, 14.8, 123), Vector3.new(-7, 7.4, 92))
return game.HttpService:JSONEncode({
	artParts = #art:GetDescendants(),
	desk = tostring(top.Size),
	sunDirection = tostring(lighting:GetSunDirection()),
})
