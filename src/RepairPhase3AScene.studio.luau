-- One-time migration of existing Phase 2B geometry. No unrelated Workspace objects touched.
local arena=workspace.PenFight
assert(arena:GetAttribute("Phase3AScene")~=true,"Phase 3A scene already migrated")
local physics=game:GetService("PhysicsService")
for _,name in ipairs({"Characters","Pens","Environment","PenFightNav","PenFightVisual"})do if not physics:IsCollisionGroupRegistered(name)then physics:RegisterCollisionGroup(name)end end
physics:CollisionGroupSetCollidable("PenFightNav","Default",false)
physics:CollisionGroupSetCollidable("PenFightNav","Environment",false)
physics:CollisionGroupSetCollidable("PenFightNav","Pens",false)
physics:CollisionGroupSetCollidable("PenFightNav","Characters",true)
physics:CollisionGroupSetCollidable("Characters","PenFightVisual",false)
physics:CollisionGroupSetCollidable("Pens","PenFightVisual",false)
local origin=Vector3.new(0,0,100)
local surface=5.6
for _,part in ipairs(arena.Desk:GetDescendants())do if part:IsA("BasePart")then
	local p=part.Position-origin
	part.Position=origin+Vector3.new(p.X*2/3,.1+p.Y*(surface-.1)/8.6,p.Z*5.8/20)
	part.Size=Vector3.new(part.Size.X*2/3,math.max(.006,part.Size.Y*(surface-.1)/8.6),math.max(.016,part.Size.Z*5.8/20))
	part.Anchored=true
end end
local top=arena.Desk.Tabletop
top.Size=Vector3.new(20,.7,5.8);top.Position=origin+Vector3.new(0,5.25,0)
top:SetAttribute("SurfaceY",surface);top:SetAttribute("PlayableWidth",20);top:SetAttribute("PlayableDepth",5.8)
local guard=Instance.new("Part");guard.Name="CharacterOnlyDeskGuard";guard.Size=Vector3.new(20.3,16,6.1)
guard.Position=origin+Vector3.new(0,8,0);guard.Anchored=true;guard.Transparency=1
guard.CanCollide=true;guard.CanTouch=false;guard.CanQuery=true;guard.CollisionGroup="PenFightNav";guard.Parent=arena.Desk
local env=arena.Environment
env.ClassroomFloor.Position=origin+Vector3.new(0,-.15,0)
env.ClassroomFloor.CanCollide=true
-- Restore collision on solid furniture; light stationery stays decorative.
for _,part in ipairs(env:GetDescendants())do if part:IsA("BasePart")then
	part.Anchored=true
	if part.Name:find("Wall") or part.Name=="NeighbourDesk" or part.Name=="NeighbourLeg" or part.Name=="Bench" or part.Name=="PodiumTop" or part.Name=="PodiumLeg" then
		part.CanCollide=true;part.CanQuery=true
	end
end end
-- Move both optional chairs to the side display area, clear of the continuous central lane.
for _,part in ipairs(arena.Seating:GetChildren())do if part:IsA("BasePart")then
	local sign=part.Name:sub(1,4)=="Blue" and -1 or 1
	local old=origin+Vector3.new(sign*7,0,sign*14)
	local target=origin+Vector3.new(sign*27,0,14)
	part.Position+=target-old
	part.Anchored=true;part.CanCollide=true;part.CanQuery=true;part.CollisionGroup="Environment"
end end
local props=env:FindFirstChild("ClassroomProps")
if props then for _,model in ipairs(props:GetChildren())do if model:IsA("Model")and model.Name=="SchoolBag"then
	local cf,size=model:GetBoundingBox()
	local block=Instance.new("Part");block.Name="BagCollider";block.Size=size;block.CFrame=cf
	block.Transparency=1;block.Anchored=true;block.CanCollide=true;block.CanQuery=true;block.CollisionGroup="Environment";block.Parent=model
end end end
-- Ensure there is no wall gap at the two rear corners.
env.LeftWall.Size=Vector3.new(1,24,75)
for _,entry in ipairs({{"RightWall",Vector3.new(1,24,75),Vector3.new(37,11.5,0)},{"FrontWall",Vector3.new(75,24,1),Vector3.new(0,11.5,37)}})do
	if not env:FindFirstChild(entry[1])then local wall=Instance.new("Part");wall.Name=entry[1];wall.Size=entry[2];wall.Position=origin+entry[3]
		wall.Anchored=true;wall.CanCollide=true;wall.Color=Color3.fromRGB(225,216,186);wall.Material=Enum.Material.Plaster;wall.CollisionGroup="Environment";wall.Parent=env
	end
end
local lanes=Instance.new("Folder");lanes.Name="WalkingLane";lanes.Parent=arena
for _,side in ipairs({-1,1})do
	for axis=1,2 do
		local p=Instance.new("Part");p.Name="LaneBoundary";p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
		p.Color=Color3.fromRGB(226,214,169);p.Material=Enum.Material.SmoothPlastic
		p.Size=axis==1 and Vector3.new(.06,.012,19)or Vector3.new(32,.012,.06)
		p.Position=origin+(axis==1 and Vector3.new(side*16,.107,0)or Vector3.new(0,.107,side*9.5));p.Parent=lanes
	end
end
for _,id in ipairs({"Blue","Red"})do
	local m=arena.Pens[id];local sign=id=="Blue"and -1 or 1
	m:PivotTo(CFrame.new(origin+Vector3.new(sign*5,5.98,sign*.65))*CFrame.Angles(0,math.rad(id=="Blue" and 25 or 205),0))
end
arena:SetAttribute("Phase3AScene",true)
-- Restore readable colours: Phase 2B stacked several strong fill lights over the desk.
game.Lighting.Brightness=1.5
game.Lighting.Ambient=Color3.fromRGB(90,88,82)
game.Lighting.OutdoorAmbient=Color3.fromRGB(110,108,100)
for _,light in env:GetDescendants()do if light:IsA("PointLight")then
 light.Brightness=light.Name=="FluorescentGlow" and .3 or (light.Name=="SunBeam" and .35 or .25)
end end
local bloom=game.Lighting:FindFirstChildOfClass("BloomEffect")
if bloom then bloom.Intensity=.05;bloom.Threshold=2;bloom.Size=16 end
local dof=game.Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
if dof then dof.Enabled=false end
return {surface=surface,size=tostring(top.Size),spectators=#arena.Spectators:GetChildren(),solidGuard=guard.CollisionGroup}
