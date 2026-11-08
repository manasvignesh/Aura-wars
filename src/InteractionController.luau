local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local Reach=require(game.ReplicatedStorage.PenFight.ReachRules)
local Interaction={}
Interaction.__index=Interaction
function Interaction.new(player,pens,characters,remotes,hud,camera)
 local self=setmetatable({player=player,pens=pens,characters=characters,remotes=remotes,hud=hud,camera=camera,isAiming=false,canReach=false,sequence=0},Interaction)
 UIS.InputBegan:Connect(function(i,used)
  if used then return end
  if i.KeyCode==Enum.KeyCode.E then self:ToggleAim()
  elseif i.KeyCode==Enum.KeyCode.Q and self.isAiming then self:ExitAim() end
 end)
 hud.ActionButton.Activated:Connect(function()self:ToggleAim()end)
 RunService.Heartbeat:Connect(function()self:Step()end)
 return self
end
function Interaction:Request(action,payload)
 self.sequence+=1
 payload=payload or {}
 payload.action=action;payload.id=self.sequence
 if self.state then
  payload.pen=payload.pen or self.state.active;payload.round=self.state.round;payload.turn=self.state.turn
  payload.matchId=self.state.matchId;payload.turnToken=self.state.turnToken
 end
 self.hud.Gui:SetAttribute("LastSubmittedAction",action);self.hud.Gui:SetAttribute("LastSubmittedId",self.sequence)
 if game.ReplicatedStorage.PenFight:GetAttribute("DebugTrace") then print("[PF3 submit]",action,self.sequence) end
 self.remotes.Request:FireServer(payload)
 return self.sequence
end
function Interaction:SetState(s)
 self.state=s
 self.isAiming=s.phase=="Aiming" and s.aiming==true and s.controller==self.player.UserId
 if s.phase~="Aiming" then self.pendingAim=false end
end
function Interaction:GetActiveCharacter()return self.state and self.characters:FindFirstChild(self.state.active)end
function Interaction:GetActivePen()return self.state and self.pens:FindFirstChild(self.state.active)end
function Interaction:CheckReach()
 if not self.state or self.state.phase~="Aiming" then return false,"Wait for both pens to settle." end
 return Reach.Check(self:GetActiveCharacter(),self:GetActivePen(),nil,false)
end
function Interaction:Result(packet)
 if packet.action=="Aim" then self.pendingAim=false end
 if not packet.accepted then self.hud:SetError(packet.reason or "Action rejected. Try again.") end
end
function Interaction:EnterAim()
 if not self.hud.Gui.Enabled then return end
 if not self.state or self.state.controller~=self.player.UserId or self.pendingAim or not self.camera.ready or self.hud.Options.Visible then return end
 local ok,reason=self:CheckReach()
 if not ok then self.hud:SetError(reason);return end
 self.pendingAim=true
 self:Request("Aim",{aiming=true})
 task.delay(2,function() if self.pendingAim then self.pendingAim=false;self.hud:SetError("No aim response. Try again.") end end)
end
function Interaction:ExitAim()
 if not self.isAiming or self.pendingAim then return end
 self.pendingAim=true;self:Request("Aim",{aiming=false})
end
function Interaction:ToggleAim()if self.isAiming then self:ExitAim() else self:EnterAim() end end
function Interaction:Step()
 self.canReach=self:CheckReach()
 if self.state then self.hud:SetGuidance(self.state,self.canReach,self.isAiming,self.camera.ready,self.player.UserId) end
end
return Interaction
