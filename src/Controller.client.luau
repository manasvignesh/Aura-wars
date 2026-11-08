-- Phase 3A: all action results are acknowledged before changing modes.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local shared=game.ReplicatedStorage:WaitForChild("PenFight")
local remotes=shared:WaitForChild("Remotes")
local player=Players.LocalPlayer
local arena=workspace:WaitForChild("PenFight")
local prefs=require(script.Parent.ClientPreferences)
local hud=require(script.Parent.HUD).new(player,prefs)
local camera=require(script.Parent.CameraController).new(arena.Pens,arena.Characters,prefs,hud)
local movement=require(script.Parent.MovementController).new(player)
local interaction=require(script.Parent.InteractionController).new(player,arena.Pens,arena.Characters,remotes,hud,camera)
local input=require(script.Parent.FlickInput).new(player,arena.Pens,arena.Characters,remotes,hud,camera,interaction)
local audio=require(script.Parent.AudioController).new(prefs,hud.Gui)
local feedback=require(script.Parent.FeedbackClient).new(arena.Pens,hud,camera,audio,prefs,remotes.Feedback)
require(script.Parent.CharacterAnimator).Start(arena.Characters,arena.Spectators,prefs,hud.Gui,arena.Pens)
local state,lastShot=nil,0
local playing=shared:GetAttribute("GameMode")=="Hotseat"
hud.Gui.Enabled=playing
camera.menuActive=not playing
if not playing then
 require(script.Parent.MenuController).new(player,arena,remotes,prefs,function(active)
  playing=active;hud.Gui.Enabled=active;camera.menuActive=not active
  if not active then input:Cancel();hud.Options.Visible=false end
 end)
end
local function receive(packet)
 if not packet or (state and packet.revision<=state.revision)then return end
 local previous=state
 state=packet
 interaction:SetState(state);input:SetState(state);camera:SetState(state)
 hud:SetState(state,player.UserId,not camera.ready)
 if previous and previous.active~=state.active and state.phase=="Aiming"then hud:Flash(state.active:upper().." TURN")end
 if packet.shotId>lastShot then
  lastShot=packet.shotId
  if packet.phase=="Moving"then feedback:Shot(packet.shotPen,packet.round,packet.turn)end
 end
 if packet.phase=="Won"then feedback:Winner(packet.winner,packet.round)end
 feedback:SetState(packet)
end
remotes.StateChanged.OnClientEvent:Connect(receive)
remotes:WaitForChild("Result").OnClientEvent:Connect(function(packet)
 receive(packet.state)
 interaction:Result(packet);input:Result(packet)
 hud.Gui:SetAttribute("LastResultId",packet.id)
 hud.Gui:SetAttribute("LastResultAccepted",packet.accepted)
 hud.Gui:SetAttribute("LastResultAction",packet.action)
 if shared:GetAttribute("DebugTrace") then print("[PF3 result]",packet.action,packet.id,packet.accepted,packet.reason or "Accepted")end
end)
local folder=shared.State
folder:GetAttributeChangedSignal("revision"):Connect(function()receive(folder:GetAttributes())end)
task.spawn(function()receive(remotes.Snapshot:InvokeServer())end)
camera:BeginIntro()
RunService.Heartbeat:Connect(function()
 local character=player.Character
 local root=character and character.PrimaryPart
 local controlled=false
 if state and state.mode=="Online" then
  local owns=state.blueUserId==player.UserId or state.redUserId==player.UserId
  controlled=owns and root~=nil and not character:GetAttribute("Aiming") and not root.Anchored
   and camera.ready and not hud.Options.Visible
 else
  controlled=state and state.controller==player.UserId and state.phase=="Aiming" and not state.aiming
   and character~=nil and character.Name==state.active and camera.ready and not hud.Options.Visible
 end
 movement:SetEnabled(playing and controlled==true)
end)
print("[PenFight] Phase 5A presentation ready")
