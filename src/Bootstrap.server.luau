-- Bootstrap.server.luau
-- Phase 2B Server Composition Root

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local Factory = require(script.Parent.PenFactory)
local RoundService = require(script.Parent.RoundService)
local AvatarService = require(script.Parent.AvatarService)
local SpectatorService = require(script.Parent.SpectatorService)
local FeedbackService = require(script.Parent.FeedbackService)
local T = require(game.ReplicatedStorage.PenFight.PhysicsTuning)

-- Disable default automatic spawning so players directly control their PenFight avatar
Players.CharacterAutoLoads = false

-- Collision Groups Setup
local function registerGroup(name)
	if not PhysicsService:IsCollisionGroupRegistered(name) then
		PhysicsService:RegisterCollisionGroup(name)
	end
end

registerGroup("Characters")
registerGroup("Pens")
registerGroup("PenFightTips")
registerGroup("Environment")
registerGroup("PenFightVisual")
registerGroup("PenFightNav")
PhysicsService:CollisionGroupSetCollidable("Pens", "Pens", true)
-- The ballpoint protrudes beyond Body. It can contact pens, but cannot snag the desk.
for _, group in ipairs(PhysicsService:GetRegisteredCollisionGroups()) do
	PhysicsService:CollisionGroupSetCollidable("PenFightTips", group.name, group.name == "Pens" or group.name == "PenFightTips")
end
PhysicsService:CollisionGroupSetCollidable("Characters","PenFightVisual",false)
PhysicsService:CollisionGroupSetCollidable("Pens","PenFightVisual",false)
PhysicsService:CollisionGroupSetCollidable("PenFightNav","Default",false)
PhysicsService:CollisionGroupSetCollidable("PenFightNav","Environment",false)
PhysicsService:CollisionGroupSetCollidable("PenFightNav","Pens",false)
PhysicsService:CollisionGroupSetCollidable("PenFightNav","Characters",true)

-- Characters cannot push pens; characters pass through each other; collide with environment
PhysicsService:CollisionGroupSetCollidable("Characters", "Pens", false)
PhysicsService:CollisionGroupSetCollidable("Characters", "Characters", false)
PhysicsService:CollisionGroupSetCollidable("Characters", "Default", true)
PhysicsService:CollisionGroupSetCollidable("Characters", "Environment", true)
PhysicsService:CollisionGroupSetCollidable("Pens", "Default", true)
PhysicsService:CollisionGroupSetCollidable("Pens", "Environment", true)

local arena = workspace:WaitForChild("PenFight")

-- Initialize Pens
local pens = {}
for _, id in ipairs({"Blue", "Red"}) do
	local model = arena.Pens:FindFirstChild(id)
	if not model then
		model = Factory.Create(arena.Pens, id)
	end
	Factory.ConfigureCollision(model)
	pens[id] = model
end

arena.Desk.Tabletop.CustomPhysicalProperties = PhysicalProperties.new(1, T.SurfaceFriction, T.DeskElasticity, 100, 100)

-- Clean up any residual default player characters
local function onPlayerAdded(player)
	if player.Character and player.Character.Parent ~= arena.Characters then
		player.Character:Destroy()
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

-- Initialize Services
local hotseat = game:GetService("RunService"):IsStudio() and game.ReplicatedStorage.PenFight:GetAttribute("GameMode") == "Hotseat"
if not hotseat then
	RoundService = require(script.Parent.OnlineMatchService)
	AvatarService = require(script.Parent.OnlineAvatarService)
end
local spectators = SpectatorService.Start()
local avatars = AvatarService.Start()
local feedback = FeedbackService.Start(pens,function(intensity) spectators:Impact(intensity) end)

-- Connect feedback and spectators
local remotes = game.ReplicatedStorage.PenFight.Remotes
remotes.Feedback.OnServerEvent:Connect(function(player, packet) end) -- remote is server-to-client

local round = RoundService.Start(pens, {
	ControllerChanged = function(player)
		avatars:ControllerChanged(player)
	end,
	Reset = function(roundNum)
		feedback:Reset(roundNum)
	end,
	Shot = function(id, roundNum, turnNum, power, speed, position, direction)
		feedback:Shot(id, roundNum, turnNum, power, speed, position, direction)
	end,
	Winner = function(winner, roundNum)
		feedback:Winner(winner, roundNum)
		spectators:Winner(winner)
	end,
}, avatars, not hotseat)

if not hotseat then require(script.Parent.LobbyService).Start(round) end

print("[PenFight] Phase 5A server ready", hotseat and "Hotseat" or "Online")
