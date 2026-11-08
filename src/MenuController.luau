local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local Catalog = require(game.ReplicatedStorage.PenFight.PenCatalog)

local Menu = {}
Menu.__index = Menu
local gold = Color3.fromRGB(231, 188, 111)
local paper = Color3.fromRGB(250, 239, 213)
local muted = Color3.fromRGB(192, 197, 176)
local ink = Color3.fromRGB(16, 27, 27)
local teal = Color3.fromRGB(37, 60, 57)

local function create(class, parent, properties)
	local node = Instance.new(class)
	for key, value in pairs(properties) do node[key] = value end
	node.Parent = parent
	return node
end

local function corner(node, radius)
	create("UICorner", node, {CornerRadius = UDim.new(0, radius or 10)})
end

function Menu.new(player, arena, remotes, prefs, onPlaying)
	local self = setmetatable({player = player, arena = arena, remotes = remotes, prefs = prefs,
		onPlaying = onPlaying, page = "Home", sequence = 0, selected = 1}, Menu)
	self.gui = create("ScreenGui", player:WaitForChild("PlayerGui"), {
		Name = "PenFightMenu", ResetOnSpawn = false, DisplayOrder = 30,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets, ClipToDeviceSafeArea = true,
	})
	local shade = create("Frame", self.gui, {Name = "ClassroomShade", Size = UDim2.fromScale(1,1), BackgroundColor3 = ink, BorderSizePixel = 0})
	create("UIGradient", shade, {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,.08), NumberSequenceKeypoint.new(.5,.28), NumberSequenceKeypoint.new(1,.90)})})
	self.shade = shade
	self.panel = create("Frame", shade, {Name = "MenuPanel", BackgroundColor3 = ink, BackgroundTransparency = .11, BorderSizePixel = 0})
	corner(self.panel, 15)
	create("UIStroke", self.panel, {Color = gold, Transparency = .77})
	self.scroll = create("ScrollingFrame", self.panel, {Name = "MenuContent", Size = UDim2.fromScale(1,1),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = gold,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y})
	create("UIPadding", self.scroll, {PaddingLeft = UDim.new(0,20), PaddingRight = UDim.new(0,20), PaddingTop = UDim.new(0,16), PaddingBottom = UDim.new(0,16)})
	self.list = create("UIListLayout", self.scroll, {Padding = UDim.new(0,8), SortOrder = Enum.SortOrder.LayoutOrder})
	self.caption = create("TextLabel", shade, {AnchorPoint = Vector2.new(1,1), Position = UDim2.new(1,-24,1,-18), Size = UDim2.fromOffset(260,24), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium,
		Text = "CLASS VII–B   /   AFTER THE BELL", TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = paper})
	self.exit = create("TextButton", self.gui, {Name = "ReturnToMenu", AnchorPoint = Vector2.new(1,0), Position = UDim2.new(1,-12,0,8), Size = UDim2.fromOffset(92,44),
		Text = "MENU", TextSize = 12, Font = Enum.Font.GothamBold, BackgroundColor3 = teal, TextColor3 = paper, Visible = false})
	corner(self.exit)
	self.exit.Activated:Connect(function() self:Send("Leave", {token = self.state and self.state.room and self.state.room.id}) end)
	self.gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:Layout() end)
	remotes.LobbyState.OnClientEvent:Connect(function(packet) self:Receive(packet) end)
	self:Layout()
	self:Render()
	task.spawn(function()
		for _ = 1, 4 do
			local ok, packet = pcall(function() return remotes.LobbySnapshot:InvokeServer() end)
			if ok and packet then self:Receive(packet); return end
			task.wait(.5)
		end
		self.error = "Menu connection unavailable. Rejoin to retry."
		self:Render()
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		if self.preview and self.shade.Visible and not prefs.ReducedMotion then
			elapsed += dt
			self.preview:PivotTo(CFrame.Angles(.12, elapsed * .65, .08))
		end
		if self.clockLabel and self.state then
			local stamp = workspace:GetServerTimeNow()
			local state = self.state
			local label = state.room and state.room.countdown > 0 and ("STARTING IN  " .. math.max(0, math.ceil(state.room.countdown - stamp)))
				or state.invite and ("EXPIRES IN  " .. math.max(0, math.ceil(state.invite.expires - stamp)) .. "s")
				or state.queueSince > 0 and ("SEARCHING  •  " .. math.max(0, math.floor(stamp - state.queueSince)) .. "s") or ""
			if self.clockLabel.Text ~= label then self.clockLabel.Text = label end
		end
	end)
	return self
end

function Menu:Layout()
	local view = self.gui.AbsoluteSize
	local topInset = GuiService:GetGuiInset()
	local top = math.max(58, topInset.Y + 8)
	local width = math.min(430, math.max(200, view.X - 24))
	local narrow = view.X < 610
	self.exit.AnchorPoint = narrow and Vector2.new(1,1) or Vector2.new(1,0)
	self.exit.Position = narrow and UDim2.new(1,-12,1,-65) or UDim2.new(1,-12,0,top+48)
	self.panel.Position = UDim2.fromOffset(narrow and (view.X-width)/2 or 24, top)
	self.panel.Size = UDim2.fromOffset(width, math.max(100, view.Y-top-14))
	self.caption.Visible = not narrow
	self.shade.BackgroundTransparency = narrow and .10 or 0
	local compact = view.Y < 470
	self.list.Padding = UDim.new(0, compact and 5 or 8)
	if self.compact ~= compact then self.compact = compact; self:Render() end
end

function Menu:Receive(packet)
	if not packet or (self.state and packet.revision < self.state.revision) then return end
	local previous = self.state
	self.state = packet
	local playing = packet.status == "Playing"
	if not previous or previous.status ~= packet.status then
		if packet.status == "Menu" and previous then self.page = "Home" end
		self.onPlaying(playing)
	end
	self.shade.Visible = not playing
	self.exit.Visible = playing
	if playing then self.gui:SetAttribute("Page", "Playing") end
	self:Render()
end

function Menu:Send(action, packet)
	if self.pending or not self.state then return end
	self.pending = true
	self.sequence += 1
	packet = packet or {}
	packet.id, packet.action = self.sequence, action
	self.error = nil
	self:Render()
	task.spawn(function()
		local transport, accepted, reason, state = pcall(function() return self.remotes.LobbyRequest:InvokeServer(packet) end)
		self.pending = false
		if not transport then self.error = "Connection interrupted. Try again."
		elseif not accepted then self.error = reason end
		if transport and state then self:Receive(state) else self:Render() end
		if self.error and self.shade.Visible == false then
			self.exit.Text = "RETRY MENU"
		else self.exit.Text = "MENU" end
	end)
end

function Menu:Label(value, size, color, height, font)
	self.order += 1
	return create("TextLabel", self.scroll, {LayoutOrder = self.order, Size = UDim2.new(1,0,0,height or 24),
		BackgroundTransparency = 1, Text = value, TextSize = size or 15, TextColor3 = color or paper,
		Font = font or Enum.Font.GothamMedium, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left})
end

function Menu:Button(name, value, callback, primary)
	self.order += 1
	local button = create("TextButton", self.scroll, {Name = name, LayoutOrder = self.order, Size = UDim2.new(1,0,0,44),
		Text = value, TextSize = 14, Font = Enum.Font.GothamBold, BackgroundColor3 = primary and gold or teal,
		TextColor3 = primary and ink or paper, AutoButtonColor = true})
	corner(button)
	button.Activated:Connect(callback)
	return button
end

function Menu:Go(page)
	self.page, self.error = page, nil
	self.scroll.CanvasPosition = Vector2.zero
	self:Render()
	if not self.prefs.ReducedMotion then
		self.panel.BackgroundTransparency = .25
		TweenService:Create(self.panel, TweenInfo.new(.18), {BackgroundTransparency = .11}):Play()
	end
end

function Menu:Person(person, detail, color)
	self.order += 1
	local row = create("Frame", self.scroll, {LayoutOrder = self.order, Size = UDim2.new(1,0,0,50), BackgroundColor3 = teal, BorderSizePixel = 0})
	corner(row)
	local image = create("ImageLabel", row, {Position = UDim2.fromOffset(6,5), Size = UDim2.fromOffset(40,40), BackgroundColor3 = ink,
		Image = person.userId > 0 and ("rbxthumb://type=AvatarHeadShot&id=" .. person.userId .. "&w=150&h=150") or ""})
	corner(image, 7)
	if person.userId <= 0 then
		create("TextLabel", image, {Size = UDim2.fromScale(1,1), BackgroundTransparency = 1, Text = person.displayName:sub(1,1), TextColor3 = gold, Font = Enum.Font.GothamBold, TextSize = 18})
	end
	create("TextLabel", row, {Position = UDim2.fromOffset(54,4), Size = UDim2.new(1,-62,0,22), BackgroundTransparency = 1,
		Text = person.displayName, TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = paper, TextSize = 15, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left})
	create("TextLabel", row, {Position = UDim2.fromOffset(54,26), Size = UDim2.new(1,-62,0,17), BackgroundTransparency = 1,
		Text = detail, TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = color or muted, TextSize = 12, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left})
end

function Menu:Showcase(item)
	self.order += 1
	local frame = create("ViewportFrame", self.scroll, {Name = "PenPreview", LayoutOrder = self.order, Size = UDim2.new(1,0,0,124),
		BackgroundColor3 = teal, Ambient = Color3.fromRGB(150,157,155), LightColor = paper, LightDirection = Vector3.new(-1,-1,-1)})
	corner(frame)
	local model = self.arena.Pens:FindFirstChild("Blue")
	if not model or not model.PrimaryPart then return end
	local world = create("WorldModel", frame, {})
	local copy = model:Clone()
	Catalog.Paint(copy, "Blue", item.id)
	copy.Parent = world
	copy:PivotTo(CFrame.Angles(.12,.30,.08))
	self.preview = copy
	frame.CurrentCamera = create("Camera", frame, {CFrame = CFrame.lookAt(Vector3.new(1,3.7,7.8),Vector3.zero), FieldOfView = 38})
end

function Menu:Render()
	if not self.shade.Visible then return end
	local scrollAt = self.scroll.CanvasPosition
	for _, node in ipairs(self.scroll:GetChildren()) do if node:IsA("GuiObject") then node:Destroy() end end
	self.order, self.preview, self.clockLabel = 0, nil, nil
	local state, page = self.state, self.page
	local player = self.player
	local person = {userId = player.UserId, displayName = player.DisplayName}
	self:Label("CLASSROOM LEAGUE    /    PHASE 6 BETA", 11, gold, 22, Enum.Font.GothamBold)
	if self.pending then self:Label("Working…", 13, gold, 18) end
	if self.error then self:Label(self.error, 13, Color3.fromRGB(255,164,151), 36) end
	if not state then self:Label("Opening the classroom…", 22, paper, 54); return end
	local progress = state.progress
	local aura = progress.aura and (tostring(progress.aura) .. " AURA POINTS")
		or (progress.status == "Loading" and "LOADING PROGRESS…" or "AURA POINTS UNAVAILABLE")
	if state.message ~= "" then self:Label(state.message, 12, muted, 30) end
	if state.invite then
		local invite = state.invite
		self:Label(invite.incoming and "DESK CHALLENGE" or "CHALLENGE SENT", 23, paper, 32, Enum.Font.GothamBold)
		self:Person(invite.peer, "Same-server challenge", gold)
		self.clockLabel = self:Label("", 14, gold)
		if invite.incoming then
			self:Button("Accept", "ACCEPT CHALLENGE", function() self:Send("Accept", {token = invite.id}) end, true)
			self:Button("Decline", "DECLINE", function() self:Send("Decline", {token = invite.id}) end)
		else self:Button("CancelInvite", "CANCEL CHALLENGE", function() self:Send("CancelInvite", {token = invite.id}) end) end
	elseif state.status == "Queued" then
		self:Label("Finding a desk rival", 25, paper, 36, Enum.Font.GothamBold)
		self:Label(state.busy and "The desk is occupied. You can stay in this server’s queue." or "Waiting for another player in this server.", 14, muted, 44)
		self.clockLabel = self:Label("", 14, gold)
		self:Button("LeaveQueue", "CANCEL SEARCH", function() self:Send("Leave") end)
	elseif state.status == "Lobby" and state.room then
		local room = state.room
		self:Label("The battle desk", 28, paper, 38, Enum.Font.GothamBold)
		self:Label(room.mode == "Practice" and "SOLO PRACTICE" or room.mode == "Hotseat" and "ONE DEVICE  /  TWO PLAYERS" or "PRE-MATCH LOBBY  /  BEST OF THREE", 12, gold)
		self:Person(room.blue, "BLUE  /  " .. (room.blueReady and "READY" or "NOT READY"), Color3.fromRGB(137,190,252))
		if room.red then self:Person(room.red, "RED  /  " .. (room.redReady and "READY" or "NOT READY"), Color3.fromRGB(255,158,141)) end
		if room.loadingProfiles then self:Label("Loading player loadouts…", 13, muted, 24) end
		self.clockLabel = self:Label("", 15, gold)
		local ready = room.blue.userId == player.UserId and room.blueReady or room.red and room.red.userId == player.UserId and room.redReady
		self:Button("Ready", ready and "NOT READY" or "READY", function() self:Send("Ready", {token = room.id, ready = not ready}) end, true)
		self:Button("LeaveLobby", "LEAVE LOBBY", function() self:Send("Leave", {token = room.id}) end)
	elseif page == "Home" then
		self:Label("PEN FIGHT", self.compact and 35 or 43, paper, self.compact and 41 or 53, Enum.Font.GothamBlack)
		self:Label("T H E   A U R A   W A R S", 16, gold, self.compact and 20 or 27, Enum.Font.GothamBold)
		if not self.compact then self:Label("The bell rings. The desk is yours.", 14, muted, 28) end
		self:Person(person, "@" .. player.Name)
		self:Button("Play", "PLAY   ›", function() self:Go("Modes") end, true)
		self:Label(aura, 12, gold, 22, Enum.Font.GothamBold)
		for _, route in ipairs({{"Pens","MY PENS"},{"Profile","PROFILE"},{"Settings","SETTINGS"},{"Help","HOW TO PLAY"}}) do
			self:Button(route[1], route[2], function() self:Go(route[1]) end)
		end
	elseif page == "Modes" then
		self:Label("Choose your game", 27, paper, 39, Enum.Font.GothamBold)
		self:Button("Quick", "QUICK MATCH   /   SAME SERVER", function() self:Send("Queue") end, true)
		self:Button("Friends", "PLAY WITH FRIENDS", function() self:Go("Friends") end)
		self:Button("Hotseat", "LOCAL HOTSEAT", function() self:Send("Solo", {mode = "Hotseat"}) end)
		self:Label("Two people share one device. A Roblox server connection is required.", 12, muted, 34)
		self:Button("Practice", "PRACTICE   /   SOLO TARGET", function() self:Send("Solo", {mode = "Practice"}) end)
	elseif page == "Friends" then
		self:Label("Challenge a classmate", 24, paper, 36, Enum.Font.GothamBold)
		self:Label("Available players in this server", 14, muted)
		if #state.eligible == 0 then self:Label("Nobody is available right now.", 14, muted, 36) end
		for _, other in ipairs(state.eligible) do
			self:Person(other, "@" .. other.name)
			self:Button("Challenge" .. other.userId, "CHALLENGE", function() self:Send("Challenge", {target = other.userId}) end)
		end
	elseif page == "Pens" then
		local item = Catalog.Items[self.selected]
		self:Label("The pen case", 26, paper, 34, Enum.Font.GothamBold)
		self:Label(aura, 12, gold, 20, Enum.Font.GothamBold)
		self:Showcase(item)
		self:Label(("LEVEL %d  /  %s"):format(self.selected, item.name), 19, gold, 32, Enum.Font.GothamBold)
		self:Label(item.tier .. " classroom style   •   " .. item.description, 13, muted, 45)
		self:Button("NextPen", "NEXT PEN   ›", function() self.selected = self.selected % #Catalog.Items + 1; self:Render() end)
		if item.id == state.equipped then
			self:Label("EQUIPPED", 14, gold)
		elseif progress.status ~= "Ready" then
			self:Label(("LOCKED  /  %d AURA  •  SAVING UNAVAILABLE"):format(item.cost), 12, muted, 36)
		elseif progress.owned[item.id] then
			self:Button("Equip", "EQUIP", function() self:Send("Equip", {pen = item.id}) end, true)
		else
			self:Button("Unlock", ("UNLOCK   /   %d AURA"):format(item.cost), function() self:Send("Unlock", {pen = item.id}) end, true)
		end
	elseif page == "Profile" then
		self:Label("Your student card", 26, paper, 38, Enum.Font.GothamBold)
		self:Person(person, "@" .. player.Name)
		self:Label(aura, 15, gold, 25, Enum.Font.GothamBold)
		self:Label("Equipped  /  " .. Catalog.Get(state.equipped).name, 14, gold, 32)
		self:Label(progress.completed and ("%d eligible matches   /   %d wins"):format(progress.completed, progress.wins)
			or "Saved match history is unavailable.", 14, muted, 36)
	elseif page == "Settings" then
		self:Label("Classroom settings", 25, paper, 38, Enum.Font.GothamBold)
		for _, setting in ipairs({{"Ambience","CLASSROOM AMBIENCE"},{"Effects","SOUND EFFECTS"},{"CameraSensitivity","CAMERA SENSITIVITY"},{"ReducedMotion","REDUCED MOTION"}}) do
			local key, title = setting[1], setting[2]
			local value = self.prefs[key]
			local display = type(value) == "boolean" and (value and "ON" or "OFF") or key == "CameraSensitivity" and (value .. "×") or (math.round(value*100) .. "%")
			self:Button(key, title .. "   /   " .. display, function()
				self.prefs.Set(key, key == "ReducedMotion" and not value or key == "CameraSensitivity" and (value >= 2 and .5 or value + .5) or type(value) == "number" and (value >= 1 and 0 or math.min(1,value+.25)))
				self:Render()
			end)
		end
		self:Label("Music and HUD scaling are unavailable in this beta.", 12, muted, 34)
	elseif page == "Help" then
		self:Label("How to play", 27, paper, 38, Enum.Font.GothamBold)
		self:Label("01   Walk around the desk and approach your pen.\n02   Enter aim and pull back to choose direction and power.\n03   Release to flick. Knock the opposing pen off the desk.\n04   First to two round wins takes the match. Draws replay.", 14, paper, 122)
		self:Label("DESKTOP   WASD or arrows to move. E to aim, Q to exit. Mouse drag to flick. Right drag to orbit.", 13, muted, 56)
		self:Label("TOUCH   Use the joystick to move. Tap Aim, then drag the pen and release. Drag on the right to orbit.", 13, muted, 56)
	end
	if state.status == "Menu" and not state.invite and page ~= "Home" then
		self:Button("Back", "‹   BACK", function() self:Go(page == "Friends" and "Modes" or "Home") end)
	end
	self.scroll.CanvasPosition = scrollAt
	self.gui:SetAttribute("Page", state.invite and "Invitation" or state.status == "Menu" and page or state.status)
end

return Menu
