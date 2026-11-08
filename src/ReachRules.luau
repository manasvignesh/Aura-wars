-- Identical geometry checks for the prompt and the authoritative server.
local S=require(script.Parent.Settings)
local T=require(script.Parent.PhysicsTuning)
local Reach={}
function Reach.Check(character,pen,direction,server)
	local root=character and character.PrimaryPart
	local body=pen and pen.PrimaryPart
	local humanoid=character and character:FindFirstChildOfClass("Humanoid")
	if not root or not body or not humanoid or humanoid.Health<=0 then return false,"Character or pen is unavailable. Reset the round." end
	local position=root.Position-S.Origin
	if math.abs(position.X)<S.DeskSize.X/2+.1 and math.abs(position.Z)<S.DeskSize.Z/2+.1 then
		return false,"Step off the desk and stand in the walking lane."
	end
	if position.Y>S.SurfaceY+1 or position.Y<S.FloorY then return false,"Stand on the classroom floor to aim." end
	local distance=(body.Position-root.Position).Magnitude
	local limit=if server then T.MaxServerReachTolerance else T.MaxReachDistance
	if distance>limit then return false,string.format("Walk closer to your pen (%.1f / %.1f studs).",distance,limit) end
	local chest=character:FindFirstChild("UpperTorso")
	local origin=chest and chest.Position or root.Position+Vector3.new(0,1,0)
	local params=RaycastParams.new()
	params.FilterType=Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances={workspace.PenFight.Characters,workspace.PenFight.Pens,workspace.PenFight.Spectators,workspace.PenFight.Desk}
	params.RespectCanCollide=true
	params.CollisionGroup="Pens"
	local hit=workspace:Raycast(origin,body.Position-origin,params)
	if hit then return false,"Reach blocked by "..hit.Instance.Name..". Walk to a clear side." end
	if direction then
		local delta=body.Position-root.Position
		local flat=Vector3.new(delta.X,0,delta.Z)
		if flat.Magnitude>.1 and direction:Dot(flat.Unit)<T.MinReachDot then
			return false,"Flick away from your body. Exit aim and walk around the pen for this angle."
		end
	end
	return true
end
return Reach
