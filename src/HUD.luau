-- Responsive presentation. Authoritative names, turns, scores and outcomes arrive in the round snapshot.
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local HUD = {}
HUD.__index = HUD

local INK = Color3.fromRGB(18, 34, 35)
local PANEL = Color3.fromRGB(34, 54, 55)
local PAPER = Color3.fromRGB(248, 231, 193)
local MUTED = Color3.fromRGB(206, 209, 185)
local GOLD = Color3.fromRGB(244, 194, 99)
local BLUE = Color3.fromRGB(121, 183, 255)
local RED = Color3.fromRGB(255, 140, 132)
local TEAM = {Blue = BLUE, Red = RED}

local function style(gui, color, radius)
	gui.BackgroundColor3 = color
	gui.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = gui
end

local function frame(parent, name, color)
	local result = Instance.new("Frame")
	result.Name = name
	style(result, color)
	result.Parent = parent
	return result
end

local function label(parent, name, value, size, color, bold)
	local result = Instance.new("TextLabel")
	result.Name = name
	result.BackgroundTransparency = 1
	result.Text = value
	result.TextSize = size
	result.TextColor3 = color
	result.Font = bold and Enum.Font.GothamBold or Enum.Font.GothamMedium
	result.TextXAlignment = Enum.TextXAlignment.Left
	result.TextTruncate = Enum.TextTruncate.AtEnd
	result.ZIndex = parent:IsA("GuiObject") and parent.ZIndex + 1 or 3
	result.Parent = parent
	return result
end

local function button(parent, name, value, color)
	local result = Instance.new("TextButton")
	result.Name = name
	result.Text = value
	result.TextColor3 = color == GOLD and INK or PAPER
	result.Font = Enum.Font.GothamBold
	result.TextSize = 12
	result.ZIndex = parent:IsA("GuiObject") and parent.ZIndex + 2 or 6
	style(result, color or PANEL, 8)
	result.Parent = parent
	return result
end

local function rectangle(object, x, y, w, h)
	object.Position = UDim2.fromOffset(x, y)
	object.Size = UDim2.fromOffset(w, h)
end

local function centered(object, width, height, y)
	object.AnchorPoint = Vector2.new(.5, 0)
	object.Position = UDim2.new(.5, 0, 0, y)
	object.Size = UDim2.fromOffset(width, height)
end

function HUD.new(player, prefs)
	local self = setmetatable({prefs = prefs, toastToken = 0}, HUD)
	local gui = Instance.new("ScreenGui")
	gui.Name = "PenFightHUD"
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.ClipToDeviceSafeArea = true
	gui.DisplayOrder = 20
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	self.Gui = gui

	self.Brand = frame(gui, "Brand", INK)
	self.Brand.BackgroundTransparency = .12
	rectangle(label(self.Brand, "Title", "PEN FIGHT", 16, GOLD, true), 9, 3, 128, 20)
	rectangle(label(self.Brand, "Subtitle", "THE AURA WARS", 9, PAPER, true), 10, 21, 128, 14)

	self.Scoreboard = frame(gui, "Scoreboard", INK)
	self.Scoreboard.BackgroundTransparency = .08
	self.BlueName = label(self.Scoreboard, "BlueIdentity", "Blue", 12, BLUE, true)
	self.RedName = label(self.Scoreboard, "RedIdentity", "Practice Opponent", 12, RED, true)
	self.RedName.TextXAlignment = Enum.TextXAlignment.Right
	self.Score = label(self.Scoreboard, "MatchScore", "0 : 0", 17, PAPER, true)
	self.Score.TextXAlignment = Enum.TextXAlignment.Center
	self.Turn = label(self.Scoreboard, "Turn", "CLASS VII–B", 9, MUTED, true)
	self.Turn.TextXAlignment = Enum.TextXAlignment.Center
	self.BlueLine = frame(self.Scoreboard, "BlueUnderline", BLUE)
	self.RedLine = frame(self.Scoreboard, "RedUnderline", RED)

	self.SettingsButton = button(gui, "Settings", "OPTIONS")
	self.AudioButton = button(gui, "Audio", "SOUND")
	self.SkipButton = button(gui, "SkipIntro", "SKIP INTRO", GOLD)
	self.ViewButton = button(gui, "ViewMode", "OVERHEAD")
	self.ViewButton.Visible = false

	self.ActionPrompt = frame(gui, "ActionPrompt", INK)
	self.ActionPrompt.BackgroundTransparency = 1
	self.ActionPrompt.Visible = false
	self.ActionButton = button(self.ActionPrompt, "ActionButton", "AIM", GOLD)
	self.ActionButton.Size = UDim2.fromScale(1, 1)

	self.Panel = frame(gui, "TurnPanel", INK)
	self.Panel.BackgroundTransparency = .12
	self.Status = label(self.Panel, "Status", "RECESS LEAGUE", 11, GOLD, true)
	self.Hint = label(self.Panel, "Hint", "", 10, PAPER, false)
	self.Power = label(self.Panel, "Power", "0%", 10, GOLD, true)
	self.Bar = frame(self.Panel, "PowerTrack", PANEL)
	self.Bar.ClipsDescendants = true
	self.Fill = frame(self.Bar, "PowerFill", GOLD)
	self.Fill.Size = UDim2.fromScale(0, 1)
	self.Reset = button(self.Panel, "ResetRound", "RESET")
	self.Toast = label(gui, "Feedback", "", 13, PAPER, true)
	self.Toast.TextTruncate = Enum.TextTruncate.None
	self.Toast.TextWrapped = true
	self.Toast.TextXAlignment = Enum.TextXAlignment.Center
	self.Toast.ZIndex = 18
	self.Toast.Visible = false
	style(self.Toast, INK, 8)
	self.Toast.BackgroundTransparency = .14

	local options = Instance.new("ScrollingFrame")
	options.Name = "OptionsPanel"
	options.CanvasSize = UDim2.fromOffset(0, 306)
	options.ScrollingDirection = Enum.ScrollingDirection.Y
	options.ScrollBarThickness = 4
	options.ScrollBarImageColor3 = GOLD
	options.ZIndex = 24
	options.Active = true
	options.Visible = false
	style(options, INK, 11)
	options.Parent = gui
	self.Options = options
	rectangle(label(options, "Heading", "CLASSROOM SETTINGS", 13, GOLD, true), 14, 6, 232, 28)
	local function row(name, y)
		local item = button(options, name, "")
		rectangle(item, 12, y, 236, 39)
		return item
	end
	self.Motion = row("ReducedMotion", 37)
	self.Effects = row("Effects", 81)
	self.Ambience = row("Ambience", 125)
	self.SensBtn = row("Sensitivity", 169)
	self.Quality = row("VisualQuality", 213)
	self.Replay = row("ReplayIntro", 257)
	self.Replay.Text = "REPLAY INTRO"

	self.SettingsButton.Activated:Connect(function() options.Visible = not options.Visible end)
	self.Motion.Activated:Connect(function() prefs.Set("ReducedMotion", not prefs.ReducedMotion) end)
	self.ViewButton.Activated:Connect(function() prefs.Set("PrecisionView", not prefs.PrecisionView) end)
	self.Quality.Activated:Connect(function()
		local nextQuality = {Auto = "Rich", Rich = "Simple", Simple = "Auto"}
		prefs.Set("VisualQuality", nextQuality[prefs.VisualQuality])
	end)
	local function cycleVolume(value)
		if value > .5 then return .35 end
		if value > 0 then return 0 end
		return .65
	end
	self.Effects.Activated:Connect(function() prefs.Set("Effects", cycleVolume(prefs.Effects)) end)
	self.Ambience.Activated:Connect(function() prefs.Set("Ambience", cycleVolume(prefs.Ambience)) end)
	self.SensBtn.Activated:Connect(function()
		prefs.Set("CameraSensitivity", prefs.CameraSensitivity >= 2 and .5 or prefs.CameraSensitivity + .5)
	end)
	self.AudioButton.Activated:Connect(function()
		if prefs.Effects > 0 or prefs.Ambience > 0 then
			self.lastMix = {prefs.Effects, prefs.Ambience}
			prefs.Set("Effects", 0)
			prefs.Set("Ambience", 0)
		else
			local mix = self.lastMix or {.65, .35}
			prefs.Set("Effects", mix[1])
			prefs.Set("Ambience", mix[2])
		end
	end)
	local function refreshOptions()
		self.Motion.Text = "REDUCED MOTION   " .. (prefs.ReducedMotion and "ON" or "OFF")
		self.Effects.Text = string.format("EFFECTS   %d%%", math.round(prefs.Effects * 100))
		self.Ambience.Text = string.format("AMBIENCE   %d%%", math.round(prefs.Ambience * 100))
		self.SensBtn.Text = string.format("ORBIT SENSITIVITY   %.1fx", prefs.CameraSensitivity)
		self.Quality.Text = "VISUALS   " .. prefs.VisualQuality:upper()
		self.AudioButton.Text = (prefs.Effects == 0 and prefs.Ambience == 0) and "MUTED" or "SOUND"
		self.ViewButton.Text = prefs.PrecisionView and "TACTICAL" or "OVERHEAD"
		self.Gui:SetAttribute("PrecisionView", prefs.PrecisionView)
		self.Gui:SetAttribute("ReducedMotion", prefs.ReducedMotion)
	end
	prefs.Changed:Connect(refreshOptions)
	refreshOptions()
	return self
end

function HUD:Layout(view)
	local touch = UserInputService.TouchEnabled
	local inset, bottomInset = GuiService:GetGuiInset()
	local key = table.concat({view.X, view.Y, inset.Y, bottomInset.Y, tostring(touch)}, ":")
	if self.layoutKey == key then return end
	self.layoutKey = key
	self.mobile = touch
	local narrow = view.X < 635
	local top = math.max(12, inset.Y + 6)
	local bottom = math.max(10, bottomInset.Y + 6)
	local header = narrow and top + 45 or top
	local scoreWidth = narrow and math.min(view.X - 24, 410) or math.clamp(view.X - 330, 270, 420)
	local scoreMiddle = scoreWidth * .5
	local identityWidth = scoreMiddle - 40

	rectangle(self.Brand, 12, top, 144, 40)
	centered(self.Scoreboard, scoreWidth, 43, header)
	rectangle(self.BlueName, 11, 5, identityWidth - 10, 20)
	rectangle(self.RedName, scoreMiddle + 40, 5, identityWidth - 10, 20)
	rectangle(self.Score, scoreMiddle - 39, 3, 78, 23)
	rectangle(self.Turn, 8, 25, scoreWidth - 16, 14)
	rectangle(self.BlueLine, 11, 26, math.min(identityWidth - 13, 63), 2)
	rectangle(self.RedLine, scoreWidth - math.min(identityWidth - 13, 63) - 11, 26, math.min(identityWidth - 13, 63), 2)

	self.SettingsButton.AnchorPoint = Vector2.new(1, 0)
	self.SettingsButton.Position = UDim2.new(1, -12, 0, top)
	self.SettingsButton.Size = UDim2.fromOffset(72, 44)
	self.AudioButton.AnchorPoint = Vector2.new(1, 0)
	self.AudioButton.Position = UDim2.new(1, -89, 0, top)
	self.AudioButton.Size = UDim2.fromOffset(60, 44)
	self.SkipButton.AnchorPoint = Vector2.new(1, 1)
	self.SkipButton.Position = UDim2.new(1, -12, 1, -bottom)
	self.SkipButton.Size = UDim2.fromOffset(118, 44)

	local panelWidth = narrow and math.min(view.X - 24, 392) or math.clamp(view.X - 440, 188, 400)
	local panelHeight = 58
	if narrow then
		centered(self.Panel, panelWidth, panelHeight, header + 48)
	else
		self.Panel.AnchorPoint = Vector2.new(.5, 1)
		self.Panel.Position = UDim2.new(.5, 0, 1, -bottom)
		self.Panel.Size = UDim2.fromOffset(panelWidth, panelHeight)
	end
	rectangle(self.Status, 10, 4, panelWidth - 91, 15)
	rectangle(self.Hint, 10, 19, panelWidth - 91, 15)
	rectangle(self.Power, 10, 37, 32, 14)
	rectangle(self.Bar, 45, 41, panelWidth - 129, 6)
	rectangle(self.Reset, panelWidth - 76, 7, 68, 44)

	local actionWidth = touch and 94 or 104
	self.ActionPrompt.AnchorPoint = Vector2.new(1, 1)
	self.ActionPrompt.Position = UDim2.new(1, -12, 1, -bottom)
	self.ActionPrompt.Size = UDim2.fromOffset(actionWidth, 44)
	self.ViewButton.AnchorPoint = Vector2.new(1, 1)
	self.ViewButton.Position = UDim2.new(1, -actionWidth - 18, 1, -bottom)
	self.ViewButton.Size = UDim2.fromOffset(84, 44)

	self.Options.AnchorPoint = Vector2.new(1, 0)
	self.Options.Position = UDim2.new(1, -12, 0, top + 49)
	self.Options.Size = UDim2.fromOffset(264, math.clamp(view.Y - top - 65, 100, 306))
	self.TopReserve = header + (narrow and 108 or 46)
	self.BottomReserve = bottom + (narrow and 48 or panelHeight)
	centered(self.Toast, math.min(view.X - 30, 370), 42, self.TopReserve + 5)
end

function HUD:IsBlocked(point)
	if self.Options.Visible then return true end
	for _, node in ipairs({self.SettingsButton, self.AudioButton, self.SkipButton, self.ActionPrompt, self.ViewButton, self.Reset}) do
		if node.Visible then
			local start = node.AbsolutePosition - self.Gui.AbsolutePosition
			local size = node.AbsoluteSize
			if point.X >= start.X and point.Y >= start.Y and point.X <= start.X + size.X and point.Y <= start.Y + size.Y then
				return true
			end
		end
	end
	return false
end

function HUD:SetState(state, userId, _)
	self.state = state
	self.BlueName.Text = state.blueName or "Blue"
	self.RedName.Text = state.redName or "Practice Opponent"
	self.Score.Text = string.format("%d : %d", state.blueWins or 0, state.redWins or 0)
	self.Turn.Text = string.format("ROUND %02d    •    %s TURN %d", state.roundIndex or state.round, state.active:upper(), state.turn)
	self.BlueLine.Visible = state.active == "Blue"
	self.RedLine.Visible = state.active == "Red"
	self.Fill.BackgroundColor3 = TEAM[state.active] or GOLD
	if state.mode == "Online" then
		local participant = state.blueUserId == userId or state.redUserId == userId
		self.Reset.Visible = participant and (state.matchPhase == "MatchResult" or state.matchPhase == "Rematch")
		local voted = state.blueUserId == userId and state.blueRematch or state.redUserId == userId and state.redRematch
		self.Reset.Text = voted and "VOTED" or "REMATCH"
		if state.gameKind == "Practice" then self.Reset.Visible = participant; self.Reset.Text = "RESET" end
	else
		self.Reset.Visible = state.controller == userId
		self.Reset.Text = state.phase == "Won" and "REMATCH" or "RESET"
	end
end

function HUD:SetGuidance(state, reachable, aiming, ready, userId)
	local controlling = state.controller == userId
	local moving = state.phase == "Moving" or state.phase == "Falling" or state.phase == "Settling"
	local mobile = self.mobile
	local stage, hint
	local online = state.mode == "Online"
	if online and state.matchPhase == "WaitingForPlayers" then
		stage, hint = "WAITING FOR PLAYERS", state.message
		self.Turn.Text = "ONLINE  /  WAITING FOR TWO PLAYERS"
	elseif online and (state.matchPhase == "MatchResult" or state.matchPhase == "Rematch") then
		stage = (state.matchWinner or ""):upper() .. " WINS THE MATCH"
		hint = state.gameKind == "Hotseat" and "Start another local match" or state.blueRematch and state.redRematch and "Starting rematch…" or "Both players must accept a rematch"
	elseif state.phase == "Won" then
		stage = state.winner == "Draw" and "ROUND DRAW" or state.winner:upper() .. " WINS"
		hint = online and state.message or "Rematch to rack up the next round"
	elseif not ready then
		stage, hint = "CLASS VII–B  /  RECESS", "Blue vs Red • one desk, two pens"
	elseif moving then
		stage, hint = "PENS IN MOTION", "Wait for the turn to settle"
	elseif not controlling then
		stage, hint = "WATCH THE ROUND", online and (state.active .. " player is choosing a shot") or "Hotseat player controls the desk"
	elseif self.Gui:GetAttribute("PendingFlick") then
		stage, hint = "CHECKING SHOT", "Waiting for the server"
	elseif aiming then
		stage = "DRAG TO FLICK"
		hint = mobile and "Touch your pen, pull back, release" or "Pull back from your pen and release"
	elseif reachable then
		stage = mobile and "TAP AIM" or "E  /  AIM"
		hint = "Choose a clear approach to your pen"
	else
		stage = "WALK TO YOUR PEN"
		hint = mobile and "Joystick to walk • swipe right to orbit" or "WASD / arrows • right drag to orbit"
	end
	if online and (state.turnDeadline or 0) > 0 then
		local seconds = math.max(0, math.ceil(state.turnDeadline - workspace:GetServerTimeNow()))
		self.Turn.Text = string.format("BEST OF 3  •  %s TURN  •  %ds", state.active:upper(), seconds)
		if controlling and seconds <= (state.warningSeconds or 10) then stage = "HURRY  /  " .. seconds .. "s LEFT" end
	end
	self.Gui:SetAttribute("InteractionStage", stage)
	if self.Status.Text ~= stage then self.Status.Text = stage end
	local color = TEAM[state.winner] or TEAM[state.active] or GOLD
	self.Status.TextColor3 = color
	local aimReady = controlling and ready and state.phase == "Aiming"
	self.ActionPrompt.Visible = aimReady and (aiming or reachable)
	self.ViewButton.Visible = aimReady and aiming
	self.ActionButton.Text = aiming and (mobile and "EXIT AIM" or "Q  EXIT") or (mobile and "AIM" or "E  AIM")
	self.ActionButton.BackgroundColor3 = aiming and PANEL or GOLD
	self.ActionButton.TextColor3 = aiming and PAPER or INK
	self.Power.Visible = aiming
	self.Bar.Visible = aiming
	if not self.Gui:GetAttribute("DragActive") then self.Hint.Text = hint end
end

function HUD:SetPower(effective)
	self.Fill.Size = UDim2.fromScale(effective, 1)
	self.Power.Text = string.format("%d%%", math.round(effective * 100))
end

function HUD:Flash(value, color, duration)
	self.toastToken += 1
	local token = self.toastToken
	self.Toast.Text = value
	self.Toast.TextColor3 = color or PAPER
	self.Toast.Visible = true
	task.delay(duration or 1.15, function()
		if self.toastToken == token then self.Toast.Visible = false end
	end)
end

function HUD:SetError(reason)
	self.Gui:SetAttribute("LastRejectReason", reason)
	self:Flash(reason, RED, 2.8)
end

return HUD
