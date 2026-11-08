-- Keep Roblox PlayerModule WASD and touch joystick. Add camera-relative arrow movement.
local CAS=game:GetService("ContextActionService")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local Movement={}
Movement.__index=Movement
function Movement.new(player)
	local self=setmetatable({player=player,enabled=false,keys={}},Movement)
	task.spawn(function()
		local scripts=player:WaitForChild("PlayerScripts")
		local module=scripts:WaitForChild("PlayerModule",10)
		if module then self.controls=require(module):GetControls() end
	end)
	CAS:BindActionAtPriority("PenFightArrowMove",function(_,state,input)
		if UIS:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
		self.keys[input.KeyCode]=state==Enum.UserInputState.Begin
		return Enum.ContextActionResult.Sink
	end,false,3001,Enum.KeyCode.Up,Enum.KeyCode.Down,Enum.KeyCode.Left,Enum.KeyCode.Right)
	UIS.WindowFocusReleased:Connect(function() self.keys={} end)
	RunService:BindToRenderStep("PenFightArrowMovement",Enum.RenderPriority.Input.Value+1,function()
		if not self.enabled then return end
		local k=self.keys
		local x=(k[Enum.KeyCode.Right] and 1 or 0)-(k[Enum.KeyCode.Left] and 1 or 0)
		local z=(k[Enum.KeyCode.Down] and 1 or 0)-(k[Enum.KeyCode.Up] and 1 or 0)
		if x~=0 or z~=0 then
			local h=self.player.Character and self.player.Character:FindFirstChildOfClass("Humanoid")
			if h then h:Move(Vector3.new(x,0,z).Unit,true) end
		end
	end)
	return self
end
function Movement:SetEnabled(enabled)
	if self.enabled==enabled and self.appliedControls==self.controls then return end
	self.enabled=enabled;self.appliedControls=self.controls
	if not enabled then self.keys={} end
	if self.controls then if enabled then self.controls:Enable() else self.controls:Disable() end end
end
return Movement
