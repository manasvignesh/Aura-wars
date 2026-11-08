-- Phase 3A: authoritative aim locks; normal Roblox locomotion outside aim.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local S=require(game.ReplicatedStorage.PenFight.Settings)
local T=require(game.ReplicatedStorage.PenFight.PhysicsTuning)
local Poses=require(game.ReplicatedStorage.PenFight.AvatarPoses)
local Reach=require(game.ReplicatedStorage.PenFight.ReachRules)
local SchoolStyle=require(script.Parent.SchoolStyle)
local Avatar={}
Avatar.__index=Avatar

local function reachTarget(model, desired)
 local upper=model:FindFirstChild("RightUpperArm")
 local lower=model:FindFirstChild("RightLowerArm")
 local hand=model:FindFirstChild("RightHand")
 local torso=model:FindFirstChild("UpperTorso")
 local shoulder=torso and torso:FindFirstChild("RightShoulderRigAttachment")
 if not (shoulder and upper and lower and hand) then return desired end
 local delta=desired-shoulder.WorldPosition
 local length=upper.Size.Y+lower.Size.Y+hand.Size.Y*.60
 if delta.Magnitude>length then return shoulder.WorldPosition+delta.Unit*length end
 return desired
end

local function spawnCF(model,id)
 local h=model:FindFirstChildOfClass("Humanoid")
 local root=model.PrimaryPart
 local y=S.FloorY+h.HipHeight+root.Size.Y/2+.08
 local p=S.Origin+Vector3.new(id=="Blue" and -S.SpawnX or S.SpawnX,y,id=="Blue" and -S.CharacterSpawnZ or S.CharacterSpawnZ)
 return CFrame.lookAt(p,Vector3.new(p.X,p.Y,S.Origin.Z))
end

local function prepare(model,id,display,userId)
 local h=model:FindFirstChildOfClass("Humanoid")
 h.RequiresNeck=false
 Poses.NormalizeVisualRig(model)
 for _,v in ipairs(model:GetDescendants()) do
  if v:IsA("LuaSourceContainer") then v:Destroy()
  elseif v:IsA("BasePart") then
   v.CollisionGroup="Characters";v.Massless=false;v.Anchored=false
   v.CanCollide=v.Name=="HumanoidRootPart" or v.Name=="UpperTorso" or v.Name=="LowerTorso"
   v.CanTouch=true;v.CanQuery=true
  end
 end
 model.Name=id;model:ScaleTo(T.CharacterScale)
 h.AutomaticScalingEnabled=false
 model.PrimaryPart=model:FindFirstChild("HumanoidRootPart")
 model.PrimaryPart.RootPriority=127
 h.RequiresNeck=true;h.EvaluateStateMachine=true;h.WalkSpeed=0
 h.JumpPower=0;h.JumpHeight=0;h.AutoRotate=true;h.Sit=false
 h.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
 model:SetAttribute("PenId",id);model:SetAttribute("ParticipantName",display)
 model:SetAttribute("ParticipantUserId",userId or 0);model:SetAttribute("ShotAt",0)
 model:SetAttribute("Outcome","");model:SetAttribute("Aiming",false);model:SetAttribute("ActiveTurn",false)
 model:PivotTo(spawnCF(model,id));Poses.PlaceStanding(model)
 local previousHull=model:FindFirstChild("WalkCollider");if previousHull then previousHull:Destroy() end
 local below=h.HipHeight+model.PrimaryPart.Size.Y/2-.35
 local head=model:FindFirstChild("Head")
 local above=math.max(1.3,head and head.Position.Y+head.Size.Y/2-model.PrimaryPart.Position.Y-.2 or 1.3)
 local hull=Instance.new("Part");hull.Name="WalkCollider"
 hull.Size=Vector3.new(model.PrimaryPart.Size.X*.68,below+above,model.PrimaryPart.Size.Z*.9)
 hull.CFrame=model.PrimaryPart.CFrame*CFrame.new(0,(above-below)/2,0)
 hull.Transparency=1;hull.Massless=true;hull.CanCollide=true;hull.CanTouch=false;hull.CanQuery=false;hull.CollisionGroup="Characters"
 hull.Parent=model
 local weld=Instance.new("WeldConstraint");weld.Part0=model.PrimaryPart;weld.Part1=hull;weld.Parent=hull
 local old=model:FindFirstChild("ParticipantLabel")
 if old then old:Destroy() end
 local tag=Instance.new("BillboardGui");tag.Name="ParticipantLabel";tag.Size=UDim2.fromOffset(140,23)
 tag.StudsOffsetWorldSpace=Vector3.new(0,2.0,0);tag.MaxDistance=62;tag.Adornee=model.Head;tag.Parent=model
 local text=Instance.new("TextLabel");text.Size=UDim2.fromScale(1,1);text.BackgroundTransparency=.38
 text.BackgroundColor3=Color3.fromRGB(21,36,40);text.TextColor3=S[id]:Lerp(Color3.fromRGB(238,229,200),.32);text.Font=Enum.Font.GothamBold;text.TextSize=10
 text.Text=id:upper().." • "..display;text.TextTruncate=Enum.TextTruncate.AtEnd;text.Parent=tag
 local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,5);corner.Parent=text
end

function Avatar.Start()
 local self=setmetatable({tokens={},characters={},activeId="Blue"},Avatar)
 self.folder=workspace.PenFight.Characters
 self.template=game.ServerStorage.PenFightAssets.RigTemplate
 for _,id in ipairs({"Blue","Red"})do self.characters[id]=self.folder:FindFirstChild(id)end
 local f=workspace.PenFight:FindFirstChild("InteractionTargets") or Instance.new("Folder")
 f.Name="InteractionTargets";f.Parent=workspace.PenFight;self.targets=f
 RunService.Heartbeat:Connect(function()
  for id,model in pairs(self.characters) do
   local aiming=model:GetAttribute("Aiming")
   local age=workspace:GetServerTimeNow()-(model:GetAttribute("ShotAt") or 0)
   local ik=model:FindFirstChild("FlickReachIK",true)
   local target=self.targets:FindFirstChild(id)
   if ik then
    ik.Enabled=aiming or (age>=0 and age<.19)
    ik.Weight=if aiming then .96 else math.clamp(1-math.max(0,age-.06)/.13,0,1)
   end
   if aiming and target then
    local b=workspace.PenFight.Pens[id].PrimaryPart
    target.Position=reachTarget(model,b.Position+Vector3.new(0,.15,0))
   end
  end
 end)
 return self
end

function Avatar:GetCharacter(id) return self.characters[id] end

function Avatar:InstallIK(model,id)
 local oldIK=model:FindFirstChild("FlickReachIK",true);if oldIK then oldIK:Destroy()end
 local previous=self.targets:FindFirstChild(id);if previous then previous:Destroy() end
 local target=Instance.new("Part");target.Name=id;target.Size=Vector3.new(.1,.1,.1)
 target.Anchored=true;target.Transparency=1;target.CanCollide=false;target.CanTouch=false;target.CanQuery=false
 target.Position=workspace.PenFight.Pens[id].PrimaryPart.Position;target.Parent=self.targets
 local attachment=Instance.new("Attachment");attachment.Parent=target
 local upper=model:FindFirstChild("RightUpperArm")
 local hand=model:FindFirstChild("RightHand")
 if not upper or not hand then return end
 if not model.Humanoid:FindFirstChildOfClass("Animator") then
  local animator=Instance.new("Animator");animator.Parent=model.Humanoid
 end
 local ik=Instance.new("IKControl");ik.Name="FlickReachIK";ik.Type=Enum.IKControlType.Position
 ik.ChainRoot=upper;ik.EndEffector=hand
 local grip=hand:FindFirstChild("RightGripAttachment")
 if grip then ik.EndEffectorOffset=grip.CFrame end
 ik.Target=attachment;ik.SmoothTime=.07;ik.Weight=0;ik.Enabled=false;ik.Parent=model.Humanoid
end

function Avatar:SetParticipant(id,player)
 local token=(self.tokens[id] or 0)+1;self.tokens[id]=token
 local function install(model,actual)
  if self.tokens[id]~=token then model:Destroy();return end
  local old=self.characters[id]
  local oldCF=old and old.PrimaryPart.CFrame
  local attrs=old and old:GetAttributes()
  prepare(model,id,player and player.DisplayName or "Practice Opponent",player and player.UserId or 0)
  model:SetAttribute("AppearanceStatus",actual and "PlayerAvatar" or (player and "Fallback" or "Practice"))
  if oldCF then model:PivotTo(oldCF) end
  if attrs then for _,k in ipairs({"Aiming","ShotAt","ShotPower","ShotDirection","Outcome","ReactionAt"}) do
   if attrs[k]~=nil then model:SetAttribute(k,attrs[k]) end
  end end
  SchoolStyle.Apply(model,id,actual)
  model.Parent=self.folder;self.characters[id]=model
  self:InstallIK(model,id)
  if old then old:Destroy() end
  self:SetActiveCharacter(self.activeId)
 end
 install(self.template:Clone(),false)
 if player then task.spawn(function()
  local ok,model=pcall(function()
   local d=Players:GetHumanoidDescriptionFromUserIdAsync(player.UserId)
   return Players:CreateHumanoidModelFromDescriptionAsync(d,Enum.HumanoidRigType.R15)
  end)
  if ok then install(model,true) else warn("[PenFight] Avatar appearance unavailable; fallback retained") end
 end) end
end

function Avatar:ControllerChanged(player)
 self.controller=player;self.activeId="Blue"
 self:SetParticipant("Blue",player);self:SetParticipant("Red",nil)
 self:SetActiveCharacter("Blue")
end

function Avatar:SetActiveCharacter(id)
 self.activeId=id
 local outgoing=self.controller and self.controller.Character
 if outgoing and outgoing.Parent and outgoing:GetAttribute("PenId")~=id then
  local oldId=outgoing:GetAttribute("PenId")
  if oldId=="Blue" or oldId=="Red" then
   -- Roblox removes the outgoing Character after reassignment. Preserve its inactive NPC copy first.
   local archive=outgoing.Archivable;outgoing.Archivable=true
   local preserved=outgoing:Clone();outgoing.Archivable=archive
   preserved.Name=oldId;preserved:SetAttribute("ActiveTurn",false);preserved:SetAttribute("Aiming",false)
   preserved.PrimaryPart.Anchored=true;preserved.Humanoid.WalkSpeed=0
   outgoing.Name="Retiring_"..oldId
   preserved.Parent=self.folder;self.characters[oldId]=preserved
   self:InstallIK(preserved,oldId)
  end
 end
 for color,char in pairs(self.characters) do
  if not char.Parent or not char:FindFirstChildOfClass("Humanoid") or not char.PrimaryPart then continue end
  local active=color==id
  char:SetAttribute("ActiveTurn",active)
  if not active then char:SetAttribute("Aiming",false) end
  local aim=char:GetAttribute("Aiming")==true
  local h=char.Humanoid;local root=char.PrimaryPart
  root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero
  root.Anchored=not active or aim
  h.AutoRotate=active and not aim;h.WalkSpeed=active and not aim and T.WalkSpeed or 0
  if not root.Anchored then pcall(function()root:SetNetworkOwner(self.controller)end) end
 end
 local char=self:GetCharacter(id)
 if self.controller and char and self.controller.Character~=char then self.controller.Character=char end
end

function Avatar:ValidateReach(player,id,direction)
 if player~=self.controller or id~=self.activeId then return false,"Only the active player can aim." end
 local model=self:GetCharacter(id)
 if player.Character~=model then return false,"Character control is changing. Try again." end
 return Reach.Check(model,workspace.PenFight.Pens:FindFirstChild(id),direction,true)
end

function Avatar:SetAiming(id,aiming)
 local model=self:GetCharacter(id);if not model then return end
 local root=model.PrimaryPart;local h=model.Humanoid
 model:SetAttribute("Aiming",aiming)
 root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero
 h.WalkSpeed=aiming and 0 or T.WalkSpeed;h.AutoRotate=not aiming
 if aiming then
  if not root.Anchored then root:SetNetworkOwner(nil) end
  local p=root.Position;local pen=workspace.PenFight.Pens[id].PrimaryPart.Position
  root.CFrame=CFrame.lookAt(p,Vector3.new(pen.X,p.Y,pen.Z))
  root.Anchored=true
 else
  root.Anchored=id~=self.activeId
  if not root.Anchored then root:SetNetworkOwner(self.controller) end
 end
end

function Avatar:Shot(id,power,offset,direction)
 local model=self:GetCharacter(id);if not model then return end
 local body=workspace.PenFight.Pens[id].PrimaryPart
 local target=self.targets:FindFirstChild(id)
 if target then
  local contact=body.Position+body.CFrame.RightVector*(offset or 0)+Vector3.new(0,.15,0)+(direction or Vector3.zero)*.16
  target.Position=reachTarget(model,contact)
 end
 model:SetAttribute("Aiming",false);model:SetAttribute("ShotPower",power)
 model:SetAttribute("ShotDirection",direction or Vector3.zero)
 model:SetAttribute("ShotAt",workspace:GetServerTimeNow())
 model.Humanoid.WalkSpeed=0;model.Humanoid.AutoRotate=false;model.PrimaryPart.Anchored=true
end

function Avatar:Reset()
 for id,model in pairs(self.characters) do
  model:SetAttribute("Outcome","");model:SetAttribute("ShotAt",0);model:SetAttribute("Aiming",false)
  model.PrimaryPart.AssemblyLinearVelocity=Vector3.zero;model.PrimaryPart.AssemblyAngularVelocity=Vector3.zero
  model:PivotTo(spawnCF(model,id))
 end
 self:SetActiveCharacter("Blue")
end
function Avatar:Winner(winner)
 for id,model in pairs(self.characters) do
  model:SetAttribute("Aiming",false);model:SetAttribute("ReactionAt",workspace:GetServerTimeNow())
  model:SetAttribute("Outcome",winner=="Draw" and "Draw" or (winner==id and "Won" or "Lost"))
  model.Humanoid.WalkSpeed=0;model.PrimaryPart.Anchored=true
 end
end
Avatar.Prepare=prepare
return Avatar
