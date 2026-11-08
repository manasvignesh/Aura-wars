-- Run once through Studio MCP in Edit mode; never runs in a live server.
local arena = workspace.PenFight
local desk, env = arena.Desk, arena.Environment
local origin = Vector3.new(0,0,100)
local function part(parent,name,size,position,color,material)
	local p=Instance.new("Part")
	p.Name=name; p.Size=size; p.CFrame=CFrame.new(origin+position)
	p.Color=color; p.Material=material or Enum.Material.SmoothPlastic
	p.Anchored=true; p.TopSurface=Enum.SurfaceType.Smooth; p.BottomSurface=Enum.SurfaceType.Smooth
	p.Parent=parent
	return p
end
local wood=Color3.fromRGB(166,112,60)
local darkWood=Color3.fromRGB(89,53,32)
local top=part(desk,"Tabletop",Vector3.new(30,1.2,20),Vector3.new(0,8,0),wood,Enum.Material.Wood)
top.CustomPhysicalProperties=PhysicalProperties.new(1,.12,.18,100,100)
top:SetAttribute("SurfaceY",8.6)
top:SetAttribute("PlayableWidth",30)
top:SetAttribute("PlayableDepth",20)
part(desk,"FrontEdge",Vector3.new(30,.55,.16),Vector3.new(0,7.9,10.05),darkWood,Enum.Material.Wood)
part(desk,"BackEdge",Vector3.new(30,.55,.16),Vector3.new(0,7.9,-10.05),darkWood,Enum.Material.Wood)
for _,x in ipairs({-14,14}) do
	for _,z in ipairs({-9,9}) do
		part(desk,"SteelLeg",Vector3.new(.7,7.3,.7),Vector3.new(x,3.7,z),Color3.fromRGB(46,57,57),Enum.Material.Metal)
		local screw=part(desk,"RecessedScrew",Vector3.new(.018,.17,.17),Vector3.new(x,8.603,z),Color3.fromRGB(71,64,50),Enum.Material.Metal)
		screw.Shape=Enum.PartType.Cylinder
		screw.CFrame*=CFrame.Angles(0,0,math.pi/2)
		screw.CanCollide=false; screw.CanQuery=false
	end
	part(desk,"SideApron",Vector3.new(.6,1.5,18),Vector3.new(x,6.65,0),darkWood,Enum.Material.Wood)
end
part(desk,"CrossBrace",Vector3.new(28,.5,.6),Vector3.new(0,2.5,-8),Color3.fromRGB(46,57,57),Enum.Material.Metal)
-- Subtle wear marks are decorative and cannot impede a flick.
local rng=Random.new(17)
for i=1,18 do
	local scratch=part(desk,"WoodWear",Vector3.new(rng:NextNumber(.3,2),.006,.018),Vector3.new(rng:NextNumber(-13,13),8.603,rng:NextNumber(-8,8)),wood:Lerp(darkWood,.18))
	scratch.CanCollide=false; scratch.CanTouch=false; scratch.CanQuery=false
end
part(env,"ClassroomFloor",Vector3.new(75,.5,75),Vector3.new(0,-.3,0),Color3.fromRGB(164,157,133),Enum.Material.Concrete)
part(env,"BackWall",Vector3.new(75,24,1),Vector3.new(0,11.5,-30),Color3.fromRGB(225,216,186),Enum.Material.Plaster)
part(env,"WallDado",Vector3.new(75,5,.15),Vector3.new(0,2,-29.4),Color3.fromRGB(113,145,134),Enum.Material.Plaster)
part(env,"LeftWall",Vector3.new(1,24,60),Vector3.new(-37,11.5,0),Color3.fromRGB(225,216,186),Enum.Material.Plaster)
local board=part(env,"Blackboard",Vector3.new(29,9,.45),Vector3.new(0,13,-29),Color3.fromRGB(31,65,57),Enum.Material.Slate)
for _,y in ipairs({8.35,17.65}) do part(env,"BoardFrame",Vector3.new(30,.35,.7),Vector3.new(0,y,-28.8),darkWood,Enum.Material.Wood) end
for _,x in ipairs({-14.8,14.8}) do part(env,"BoardFrame",Vector3.new(.35,9.3,.7),Vector3.new(x,13,-28.8),darkWood,Enum.Material.Wood) end
local sign=Instance.new("SurfaceGui"); sign.Name="ChalkWriting"; sign.Face=Enum.NormalId.Back; sign.CanvasSize=Vector2.new(1160,360); sign.Parent=board
local text=Instance.new("TextLabel"); text.Size=UDim2.fromScale(1,1); text.BackgroundTransparency=1; text.Text="PEN FIGHT\nTHE AURA WARS\n________________________________\nAfter class. On the desk. Winner stays."; text.Font=Enum.Font.GothamMedium; text.TextSize=43; text.TextColor3=Color3.fromRGB(224,230,206); text.Parent=sign
part(env,"ChalkTray",Vector3.new(30,.2,1),Vector3.new(0,8,-28.3),darkWood,Enum.Material.Wood)
for i=1,3 do part(env,"Chalk",Vector3.new(.7,.15,.15),Vector3.new(i-2,8.2,-28.1),Color3.fromRGB(232,231,207)) end
-- Empty neighbouring desks establish a classroom without obstructing the arena.
for _,x in ipairs({-24,24}) do
	local t=part(env,"NeighbourDesk",Vector3.new(12,.7,8),Vector3.new(x,6.5,-14),wood,Enum.Material.Wood)
	for _,dx in ipairs({-5,5}) do for _,dz in ipairs({-3,3}) do part(env,"NeighbourLeg",Vector3.new(.45,6,.45),Vector3.new(x+dx,3.1,-14+dz),darkWood,Enum.Material.Wood) end end
	part(env,"Bench",Vector3.new(12,.5,2.8),Vector3.new(x,3.7,-7),darkWood,Enum.Material.Wood)
end
local lamp=part(env,"SoftDeskLight",Vector3.new(1,1,1),Vector3.new(-8,25,4),Color3.new(1,1,1))
lamp.Transparency=1; lamp.CanCollide=false; lamp.CanQuery=false
local light=Instance.new("PointLight"); light.Name="WarmFill"; light.Color=Color3.fromRGB(255,229,188); light.Brightness=1.1; light.Range=45; light.Shadows=true; light.Parent=lamp
local lighting=game.Lighting
arena:SetAttribute("OriginalClockTime",lighting.ClockTime)
arena:SetAttribute("OriginalBrightness",lighting.Brightness)
arena:SetAttribute("OriginalAmbient",lighting.Ambient)
arena:SetAttribute("OriginalOutdoorAmbient",lighting.OutdoorAmbient)
lighting.ClockTime=14.5; lighting.Brightness=2.5
lighting.Ambient=Color3.fromRGB(121,124,127)
lighting.OutdoorAmbient=Color3.fromRGB(152,151,139)
local factory=require(game.ServerScriptService.PenFight.PenFactory)
factory.Create(arena.Pens,"Blue"); factory.Create(arena.Pens,"Red")
local focus=origin+Vector3.new(0,8.6,0)
workspace.CurrentCamera.CFrame=CFrame.lookAt(focus+Vector3.new(0,39,29),focus)
workspace.CurrentCamera.FieldOfView=44
return {sceneDescendants=#arena:GetDescendants(),pens=#arena.Pens:GetChildren(),surfaceY=top.Position.Y+top.Size.Y/2}
