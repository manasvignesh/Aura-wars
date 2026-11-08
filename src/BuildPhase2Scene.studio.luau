-- Additions only. Run once on the backed-up Phase 1 arena, in Studio Edit mode.
local arena=workspace.PenFight
assert(#arena.Seating:GetChildren()==0,"Phase 2 seating already built")
local S=require(game.ReplicatedStorage.PenFight.Settings)
local T=require(game.ReplicatedStorage.PenFight.PhysicsTuning)
local Avatar=require(game.ServerScriptService.PenFight.AvatarService)
local function part(name,size,position,color,material)
	local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=CFrame.new(S.Origin+position)
	p.Color=color;p.Material=material or Enum.Material.Wood;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
	p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=arena.Seating;return p
end
for _,id in ipairs({"Blue","Red"}) do
	local x=if id=="Blue" then -7 else 7
	local sign=if id=="Blue" then -1 else 1
	part(id.."Seat",Vector3.new(4.4,.4,4),Vector3.new(x,6.1,sign*14),Color3.fromRGB(116,73,39))
	part(id.."Backrest",Vector3.new(4.4,2.8,.35),Vector3.new(x,8,sign*15.8),Color3.fromRGB(116,73,39))
	for _,dx in ipairs({-1.7,1.7}) do for _,dz in ipairs({-1.4,1.4}) do
		part(id.."ChairLeg",Vector3.new(.28,5.9,.28),Vector3.new(x+dx,3.05,sign*14+dz),Color3.fromRGB(45,55,54),Enum.Material.Metal)
	end end
end
local description=Instance.new("HumanoidDescription")
description.HeadColor=Color3.fromRGB(214,175,135)
description.LeftArmColor=description.HeadColor;description.RightArmColor=description.HeadColor
description.TorsoColor=Color3.fromRGB(171,52,60)
description.LeftLegColor=Color3.fromRGB(38,45,62);description.RightLegColor=description.LeftLegColor
local template=game.Players:CreateHumanoidModelFromDescriptionAsync(description,Enum.HumanoidRigType.R15)
template.Name="RigTemplate"
for _,v in ipairs(template:GetDescendants()) do if v:IsA("LuaSourceContainer") then v:Destroy() end end
template.Parent=game.ServerStorage.PenFightAssets
description:Destroy()
local red=template:Clone();Avatar.Prepare(red,"Red","Practice Opponent",0);red.Parent=arena.Characters
local blue=template:Clone();Avatar.Prepare(blue,"Blue","Player avatar loads in Play",0)
for _,name in ipairs({"UpperTorso","LowerTorso"}) do local p=blue:FindFirstChild(name);if p then p.Color=S.Blue end end
blue.Parent=arena.Characters
arena.Desk.Tabletop.CustomPhysicalProperties=PhysicalProperties.new(1,T.SurfaceFriction,T.DeskElasticity,100,100)
for _,model in ipairs(arena.Pens:GetChildren()) do
	model.PrimaryPart.CustomPhysicalProperties=PhysicalProperties.new(T.Density,T.SurfaceFriction,T.PenElasticity,100,100)
end
arena:SetAttribute("Phase","2A")
return {characters=#arena.Characters:GetChildren(),seatingParts=#arena.Seating:GetChildren(),templateParts=#template:GetDescendants()}
