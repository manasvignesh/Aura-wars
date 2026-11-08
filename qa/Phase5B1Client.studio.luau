local players = game:GetService("Players")
local input = game:GetService("UserInputService")
local shared = game.ReplicatedStorage:WaitForChild("PenFight")
local bridge = shared:WaitForChild("Phase5B1Test", 20)
if not bridge then return end
local player = players.LocalPlayer
local reach = require(shared.ReachRules)
local virtual = input:CreateVirtualInput()
local sequence = 0
local state = shared:WaitForChild("State")
local errors = {}
game:GetService("LogService").MessageOut:Connect(function(message, kind)
	if kind == Enum.MessageType.MessageError and #errors < 30 then table.insert(errors, message) end
end)

local function tap(key, seconds)
	virtual:SendKey(true, key, false)
	task.wait(seconds or .07)
	virtual:SendKey(false, key, false)
	task.wait(.1)
end

local function approach(side)
	local model = player.Character
	local pen = workspace.PenFight.Pens[side]
	local root = model.PrimaryPart
	local first = root.Position
	local sign = side == "Blue" and -1 or 1
	local x = math.clamp(pen.PrimaryPart.Position.X, -9, 9)
	local goal = Vector3.new(x, first.Y, 100 + sign * 4.35)
	local keys = {Enum.KeyCode.Up, Enum.KeyCode.Right, Enum.KeyCode.Down, Enum.KeyCode.Left}
	for _ = 1, 18 do
		if reach.Check(model, pen, nil, false) and math.abs(goal.X - root.Position.X) < 1.5 then break end
		local delta = goal - root.Position
		local frame = workspace.CurrentCamera.CFrame
		local flat = Vector3.new(frame.LookVector.X, 0, frame.LookVector.Z).Unit
		local right = Vector3.new(-flat.Z, 0, flat.X)
		local components = {delta:Dot(flat), delta:Dot(right), -delta:Dot(flat), -delta:Dot(right)}
		local best = 1
		for j = 2, 4 do if components[j] > components[best] then best = j end end
		tap(keys[best], math.clamp(components[best] / 16, .04, .22))
	end
	local valid, reason = reach.Check(model, pen, nil, false)
	return {valid = valid, reason = reason, distance = (root.Position - first).Magnitude, position = tostring(root.Position)}
end

local function shot(payload)
	local evidence = approach(payload.side)
	if not evidence.valid then return evidence end
	local gui = player.PlayerGui.PenFightHUD
	for _ = 1, 3 do
		if state:GetAttribute("aiming") then break end
		tap(Enum.KeyCode.E)
		task.wait(.7)
	end
	task.wait(.5)
	evidence.aiming = state:GetAttribute("aiming")
	evidence.input = gui:GetAttribute("LastSubmittedAction")
	evidence.rejection = gui:GetAttribute("LastRejectReason")
	if not evidence.aiming then return evidence end
	local body = workspace.PenFight.Pens[payload.side].PrimaryPart
	local camera = workspace.CurrentCamera
	local world = Vector3.new(body.Position.X, 5.98, body.Position.Z)
	local a = camera:WorldToViewportPoint(world)
	local b = camera:WorldToViewportPoint(world + Vector3.xAxis)
	local p = Vector2.new(a.X, a.Y)
	local q = p - (Vector2.new(b.X, b.Y) - p).Unit * payload.pixels
	virtual:SendMousePosition(p)
	task.wait(.08)
	virtual:SendMouseButton(p, Enum.UserInputType.MouseButton1, true, 0)
	for i = 1, 9 do
		virtual:SendMousePosition(p:Lerp(q, i / 9))
		task.wait(.035)
	end
	evidence.held = gui:GetAttribute("DragActive")
	virtual:SendMouseButton(q, Enum.UserInputType.MouseButton1, false, 0)
	task.wait(.65)
	evidence.shot = state:GetAttribute("shotId")
	evidence.pen = state:GetAttribute("shotPen")
	evidence.reason = state:GetAttribute("LastRequestReason")
	evidence.charge = gui:GetAttribute("LastReleaseCharge")
	evidence.p, evidence.q = tostring(p), tostring(q)
	return evidence
end

bridge.OnClientEvent:Connect(function(id, action, payload)
	local ok, result = pcall(function()
		if action == "Shot" then return shot(payload) end
		local gui = player.PlayerGui.PenFightHUD
		if action == "Report" then
			return {page = player.PlayerGui.PenFightMenu:GetAttribute("Page"), hud = gui.Enabled,
				avatar = player.Character and player.Character.Name, touch = input.TouchEnabled,
				viewport = tostring(workspace.CurrentCamera.ViewportSize), match = state:GetAttributes(), errors = errors}
		end
		if action == "Vote" then
			local b = assert(gui:FindFirstChild("ResetRound", true))
			assert(b.Visible, "Rematch button is hidden")
			local p = b.AbsolutePosition + b.AbsoluteSize / 2 + game.GuiService:GetGuiInset()
			virtual:SendMousePosition(p)
			task.wait(.1)
			virtual:SendMouseButton(p, Enum.UserInputType.MouseButton1, true, 0)
			task.wait(.08)
			virtual:SendMouseButton(p, Enum.UserInputType.MouseButton1, false, 0)
			return true
		end
		if action == "Forbidden" then
			payload.action, payload.id = "Flick", (gui:GetAttribute("LastSubmittedId") or 0) + 1
			for _, k in {"matchId", "turnToken", "round", "turn"} do payload[k] = state:GetAttribute(k) end
			local rejected
			local c = shared.Remotes.Result.OnClientEvent:Connect(function(packet)
				if packet.id == payload.id then rejected = packet end
			end)
			shared.Remotes.Request:FireServer(payload)
			task.wait(.4)
			c:Disconnect()
			return rejected and {accepted = rejected.accepted, reason = rejected.reason}
		end
		sequence += 1
		payload.action, payload.id = action, sequence
		local accepted, reason, snapshot = shared.Remotes.LobbyRequest:InvokeServer(payload)
		return {accepted = accepted, reason = reason, snapshot = snapshot}
	end)
	bridge:FireServer(id, ok, result)
end)
bridge:FireServer(0, true)
