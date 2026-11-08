-- Local effects and fan rotors share the existing options and camera stage.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local preferences = require(script.Parent.ClientPreferences)
local settings = UserSettings():GetService("UserGameSettings")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local hud = playerGui:WaitForChild("PenFightHUD")
local fans = workspace:WaitForChild("PenFight"):WaitForChild("Environment"):WaitForChild("CeilingFans")

local rotors = {}
for _, fan in ipairs(fans:GetChildren()) do
	local blades = fan:FindFirstChild("Blades")
	if blades and blades:IsA("Model") then
		table.insert(rotors, {model = blades, rest = blades:GetPivot()})
	end
end

local heartbeat
local frameBudget = 0
local spinClock = 0
local rich = false

local function setFanAnimation(active)
	if active and not heartbeat then
		heartbeat = RunService.Heartbeat:Connect(function(dt)
			frameBudget += dt
			spinClock += dt
			if frameBudget < 1/24 then return end
			frameBudget %= 1/24
			for i, rotor in ipairs(rotors) do
				local angle = (spinClock * (2.2 + i * .21)) % (2 * math.pi)
				rotor.model:PivotTo(rotor.rest * CFrame.Angles(0, angle, 0))
			end
		end)
	elseif not active and heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
end

local function refreshMotion()
	setFanAnimation(rich and not preferences.ReducedMotion and hud:GetAttribute("CameraStage") == "FreeWalk")
end

local function refreshQuality()
	local quality = settings.SavedQualityLevel.Value
	local autoRich = not UserInputService.TouchEnabled and (quality == 0 or quality >= 5)
	rich = preferences.VisualQuality == "Rich" or (preferences.VisualQuality == "Auto" and autoRich)
	for _, effect in ipairs(CollectionService:GetTagged("PenFightRichEffect")) do
		if effect:IsA("PostEffect") then effect.Enabled = rich end
	end
	for _, detail in ipairs(CollectionService:GetTagged("PenFightFineArt")) do
		if detail:IsA("BasePart") then detail.LocalTransparencyModifier = rich and 0 or 1 end
	end
	hud:SetAttribute("ArtQuality", rich and "Rich" or "Simple")
	refreshMotion()
end

preferences.Changed:Connect(function(key)
	if key == "VisualQuality" then refreshQuality() end
	if key == "ReducedMotion" then refreshMotion() end
end)
settings:GetPropertyChangedSignal("SavedQualityLevel"):Connect(refreshQuality)
hud:GetAttributeChangedSignal("CameraStage"):Connect(refreshMotion)
refreshQuality()
