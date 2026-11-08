-- Server Play. Uses isolated clones, real assembly properties and production flicks.
local arena = workspace.PenFight
local Catalog = require(game.ReplicatedStorage.PenFight.PenCatalog)
local modules = game.ServerScriptService.PenFight
local Factory, Physics = require(modules.PenFactory), require(modules.PenPhysics)
local run = game:GetService("RunService")
local fixture = Instance.new("Folder")
fixture.Name = "Phase6HandlingQA"
fixture.Parent = workspace
local desk = arena.Desk.Tabletop:Clone()
desk.CFrame = CFrame.new(170, 5.25, 130)
desk.Parent = fixture
local rows = {}
for _, item in Catalog.Items do
	local pen = arena.Pens.Blue:Clone()
	pen:PivotTo(CFrame.new(170, 5.96, 130))
	pen.Parent = fixture
	Factory.ApplyHandling(pen, item.id)
	Catalog.Paint(pen, "Blue", item.id)
	local root = pen.PrimaryPart
	root:SetNetworkOwner(nil)
	task.wait(.15)
	local mass, before = root.AssemblyMass, root.Position
	local speed = Physics.Flick(pen, Vector3.zAxis, .55, .85)
	local launch, spin = 0, 0
	local seconds = 0
	repeat
		seconds += run.Heartbeat:Wait()
		launch = math.max(launch, root.AssemblyLinearVelocity.Magnitude)
		spin = math.max(spin, root.AssemblyAngularVelocity.Magnitude)
	until seconds >= .15
	local distance = Vector3.new(root.Position.X-before.X, 0, root.Position.Z-before.Z).Magnitude
	table.insert(rows, {pen = item.name, mass = mass, friction = root.CustomPhysicalProperties.Friction,
		speed = speed, measuredLaunch = launch, angularSpeed = spin, travel = distance,
		barrel = tostring(pen.Barrel.Color), geometry = tostring(root.Size)})
	pen:Destroy()
end
fixture:Destroy()
return game:GetService("HttpService"):JSONEncode(rows)
