local RunService=game:GetService("RunService")
local T=require(game.ReplicatedStorage.PenFight.PhysicsTuning)
local Feedback={}
Feedback.__index=Feedback
function Feedback.Start(pens,onImpact)
	local self=setmetatable({pens=pens,previous={},lastImpact=-math.huge,round=0},Feedback)
	self.remote=game.ReplicatedStorage.PenFight.Remotes.Feedback
	RunService.PreSimulation:Connect(function()
		for id,model in pairs(pens) do self.previous[id]=model.PrimaryPart.AssemblyLinearVelocity end
	end)
	local colliders={}
	for id,model in pairs(pens) do
		colliders[model.PrimaryPart]=id
		local tip=model:FindFirstChild("Ballpoint")
		if tip and tip:IsA("BasePart") and tip.CanCollide then colliders[tip]=id end
	end
	for collider,id in pairs(colliders) do
		collider.Touched:Connect(function(other)
			local otherId=colliders[other]
			if not otherId or otherId==id then return end
			local now=os.clock()
			local relative=(self.previous[id] or Vector3.zero)-(self.previous[otherId] or Vector3.zero)
			local speed=relative.Magnitude
			if speed<T.ImpactMinSpeed or now-self.lastImpact<T.ImpactCooldown then return end
			self.lastImpact=now
			local point=(collider.Position+other.Position)*.5
			if onImpact then onImpact(math.clamp(speed/T.ImpactFullSpeed,0,1)) end
			self.remote:FireAllClients({kind="Impact",position=point,intensity=math.clamp(speed/T.ImpactFullSpeed,0,1),speed=speed,round=self.round})
			local state=game.ReplicatedStorage.PenFight.State
			state:SetAttribute("LastImpactSpeed",speed)
			state:SetAttribute("ImpactCount",(state:GetAttribute("ImpactCount") or 0)+1)
		end)
	end
	return self
end
function Feedback:Shot(id,round,turn,power,speed,position,direction)
	self.round=round
	self.remote:FireAllClients({kind="Shot",pen=id,round=round,turn=turn,power=power,speed=speed,position=position,direction=direction})
end
function Feedback:Reset(round)
	self.round=round
	self.remote:FireAllClients({kind="Reset",round=round})
end
function Feedback:Winner(winner,round)
	self.remote:FireAllClients({kind="Winner",winner=winner,round=round})
end
return Feedback
