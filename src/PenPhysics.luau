local Settings = require(game.ReplicatedStorage.PenFight.Settings)
local T = require(game.ReplicatedStorage.PenFight.PhysicsTuning)
local Factory = require(script.Parent.PenFactory)
local Catalog = require(game.ReplicatedStorage.PenFight.PenCatalog)
local Physics = {}
function Physics.CanFlick(model)
	local body=model and model.PrimaryPart
	if not body or body.Anchored or not body.AssemblyRootPart or body.AssemblyRootPart.Anchored then return false,"Pen assembly is anchored. Reset the round." end
	if body.AssemblyMass<=0 or body.AssemblyMass==math.huge then return false,"Pen mass is invalid. Reset the round." end
	for _,part in ipairs(body:GetConnectedParts(true)) do if part.Anchored then return false,"A pen part is anchored. Reset the round." end end
	return true
end

function Physics.Reset(pens)
	for id, model in pairs(pens) do
		local body = model.PrimaryPart
		body.AssemblyLinearVelocity = Vector3.zero
		body.AssemblyAngularVelocity = Vector3.zero
		model:PivotTo(Factory.SpawnCFrame(id))
		body:SetNetworkOwner(nil)
	end
end

function Physics.Flick(model, direction, power, offset)
	local body = model.PrimaryPart
	local item = Catalog.Get(model:GetAttribute("EquippedPen")) or Catalog.Items[1]
	local speed = math.min(T.MaxSpeed, T.Speed(power) * item.speed)
	body:SetNetworkOwner(nil)
	-- Mass-normalised impulse keeps future pen construction independent of input.
	local point = body.AssemblyCenterOfMass + body.CFrame.RightVector * offset * T.SpinTransfer * item.spin
	body:ApplyImpulseAtPosition(direction * speed * body.AssemblyMass, point)
	return speed
end

function Physics.HasFallen(model)
	return model.PrimaryPart.Position.Y < Settings.SurfaceY + Settings.Origin.Y - Settings.FallDepth
end

function Physics.IsResting(pens)
	for _, model in pairs(pens) do
		local body = model.PrimaryPart
		if body.AssemblyLinearVelocity.Magnitude > Settings.RestLinear or body.AssemblyAngularVelocity.Magnitude > Settings.RestAngular then return false end
	end
	return true
end

function Physics.Stop(pens)
	for _, model in pairs(pens) do
		model.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
		model.PrimaryPart.AssemblyAngularVelocity = Vector3.zero
	end
end

function Physics.Step(pens, dt)
	for _, model in pairs(pens) do
		local body = model.PrimaryPart
		local p = body.Position - Settings.Origin
		-- Small extra drag only while supported by the desk. Falling remains free 3D physics.
		if math.abs(p.X) < Settings.DeskSize.X/2 and math.abs(p.Z) < Settings.DeskSize.Z/2 and math.abs(p.Y - (Settings.SurfaceY + Settings.PenSize.Y/2)) < .18 then
			local v = body.AssemblyLinearVelocity
			local a = math.exp(-Settings.LinearDamping * dt)
			body.AssemblyLinearVelocity = Vector3.new(v.X*a, v.Y, v.Z*a)
			body.AssemblyAngularVelocity *= math.exp(-Settings.SpinDamping * dt)
		end
	end
end

return Physics
