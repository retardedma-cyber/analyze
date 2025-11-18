-- Roblox GUI Debug Tool
-- Professional GUI Inspector & Debugger
-- No lag, no auto-refresh, manual control only
--
-- USAGE:
-- _G.ShowDebugTool()   - Show the debug window
-- _G.HideDebugTool()   - Hide the debug window
-- _G.ToggleDebugTool() - Toggle window visibility
--
-- Press the "X" button to hide (not destroy) the window
-- Use the global functions above to show it again

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- ========================
-- CONFIGURATION
-- ========================
local CONFIG = {
	WindowSize = Vector2.new(750, 600),
	SidebarWidth = 120,
	Colors = {
		Background = Color3.fromRGB(25, 25, 28),
		TopBar = Color3.fromRGB(35, 35, 40),
		Border = Color3.fromRGB(50, 50, 55),
		Button = Color3.fromRGB(45, 45, 50),
		ButtonHover = Color3.fromRGB(60, 60, 65),
		ButtonActive = Color3.fromRGB(70, 130, 180),
		Text = Color3.fromRGB(220, 220, 220),
		TextDim = Color3.fromRGB(150, 150, 150),
		AccentBlue = Color3.fromRGB(70, 130, 180),
		AccentGreen = Color3.fromRGB(80, 180, 100),
		AccentRed = Color3.fromRGB(180, 80, 80),
		AccentYellow = Color3.fromRGB(200, 180, 80),
		AccentPurple = Color3.fromRGB(150, 100, 200),
	},
	Font = Enum.Font.Gotham,
	FontBold = Enum.Font.GothamBold,
}

-- ========================
-- STATE MANAGEMENT
-- ========================
local State = {
	expanded = {}, -- {[instance] = true/false}
	frozen = false,
	frozenData = nil,
	hiddenGuis = {}, -- {[instance] = true}
	frozenIndividual = {}, -- {[instance] = {children snapshot}}
	searchQuery = "", -- Current search filter
	currentTab = "GUIs", -- Active tab: "GUIs", "Remotes", "Tools", "Settings"
	remoteLogs = {}, -- {timestamp, remote, args, type}
	remoteSpyEnabled = false,
	highlightedObject = nil,
}

-- ========================
-- UTILITY FUNCTIONS
-- ========================

local function isGuiRoot(obj)
	return obj:IsA("ScreenGui") or obj:IsA("SurfaceGui") or obj:IsA("BillboardGui")
end

local function copyToClipboard(text)
	if setclipboard then
		setclipboard(text)
		return true
	elseif syn and syn.write_clipboard then
		syn.write_clipboard(text)
		return true
	elseif Clipboard and Clipboard.set then
		Clipboard.set(text)
		return true
	end
	return false
end

local function getFullPath(obj)
	local path = obj.Name
	local parent = obj.Parent
	while parent and parent ~= game do
		path = parent.Name .. "." .. path
		parent = parent.Parent
	end
	return "game." .. path
end

local function formatValue(value)
	local valueType = typeof(value)
	if valueType == "string" then
		return '"' .. value .. '"'
	elseif valueType == "number" then
		return tostring(value)
	elseif valueType == "boolean" then
		return tostring(value)
	elseif valueType == "Instance" then
		return value:GetFullName()
	elseif valueType == "Vector3" then
		return string.format("Vector3.new(%.2f, %.2f, %.2f)", value.X, value.Y, value.Z)
	elseif valueType == "Vector2" then
		return string.format("Vector2.new(%.2f, %.2f)", value.X, value.Y)
	elseif valueType == "Color3" then
		return string.format("Color3.fromRGB(%d, %d, %d)", value.R * 255, value.G * 255, value.B * 255)
	elseif valueType == "UDim2" then
		return string.format("UDim2.new(%.3f, %d, %.3f, %d)", value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset)
	else
		return tostring(value)
	end
end

local function getSourceTag(obj)
	if obj:IsDescendantOf(LocalPlayer.PlayerGui) then
		return "PlayerGui"
	elseif obj:IsDescendantOf(game:GetService("StarterGui")) then
		return "StarterGui"
	else
		local success = pcall(function()
			if obj:IsDescendantOf(CoreGui) then
				return true
			end
		end)
		if success then
			return "CoreGui"
		end
	end
	return "Unknown"
end

local function createUICorner(radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	return corner
end

local function createButton(parent, text, position, size, callback)
	local button = Instance.new("TextButton")
	button.Name = text .. "Button"
	button.Parent = parent
	button.Position = position
	button.Size = size
	button.BackgroundColor3 = CONFIG.Colors.Button
	button.BorderSizePixel = 0
	button.Font = CONFIG.Font
	button.Text = text
	button.TextColor3 = CONFIG.Colors.Text
	button.TextSize = 14
	button.AutoButtonColor = false

	createUICorner(4).Parent = button

	button.MouseEnter:Connect(function()
		button.BackgroundColor3 = CONFIG.Colors.ButtonHover
	end)

	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = CONFIG.Colors.Button
	end)

	button.MouseButton1Click:Connect(callback)

	return button
end

-- ========================
-- MAIN GUI CREATION
-- ========================

local function createMainWindow()
	-- Create ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "RobloxGUIDebugTool"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 999999

	-- Protect from client scripts
	pcall(function()
		screenGui.Parent = CoreGui
	end)
	if not screenGui.Parent then
		screenGui.Parent = LocalPlayer.PlayerGui
	end

	-- Main Frame
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Parent = screenGui
	mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	mainFrame.Size = UDim2.new(0, CONFIG.WindowSize.X, 0, CONFIG.WindowSize.Y)
	mainFrame.BackgroundColor3 = CONFIG.Colors.Background
	mainFrame.BorderSizePixel = 1
	mainFrame.BorderColor3 = CONFIG.Colors.Border

	createUICorner(8).Parent = mainFrame

	-- Top Bar
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Parent = mainFrame
	topBar.Size = UDim2.new(1, 0, 0, 35)
	topBar.BackgroundColor3 = CONFIG.Colors.TopBar
	topBar.BorderSizePixel = 0

	local topCorner = createUICorner(8)
	topCorner.Parent = topBar

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Parent = topBar
	title.Position = UDim2.new(0, 12, 0, 0)
	title.Size = UDim2.new(0, 300, 1, 0)
	title.BackgroundTransparency = 1
	title.Font = CONFIG.FontBold
	title.Text = "GUI Debug Tool"
	title.TextColor3 = CONFIG.Colors.Text
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left

	-- Control Buttons (Right side)
	local btnSize = 30
	local btnPadding = 5

	-- Refresh Button
	local refreshBtn = Instance.new("TextButton")
	refreshBtn.Name = "RefreshButton"
	refreshBtn.Parent = topBar
	refreshBtn.Position = UDim2.new(1, -(btnSize + btnPadding) * 3, 0.5, -btnSize/2)
	refreshBtn.Size = UDim2.new(0, btnSize, 0, btnSize)
	refreshBtn.BackgroundColor3 = CONFIG.Colors.Button
	refreshBtn.BorderSizePixel = 0
	refreshBtn.Font = CONFIG.FontBold
	refreshBtn.Text = "R"
	refreshBtn.TextColor3 = CONFIG.Colors.AccentGreen
	refreshBtn.TextSize = 16
	refreshBtn.AutoButtonColor = false
	createUICorner(4).Parent = refreshBtn

	-- Minimize Button (−)
	local minimizeBtn = Instance.new("TextButton")
	minimizeBtn.Name = "MinimizeButton"
	minimizeBtn.Parent = topBar
	minimizeBtn.Position = UDim2.new(1, -(btnSize + btnPadding) * 2, 0.5, -btnSize/2)
	minimizeBtn.Size = UDim2.new(0, btnSize, 0, btnSize)
	minimizeBtn.BackgroundColor3 = CONFIG.Colors.Button
	minimizeBtn.BorderSizePixel = 0
	minimizeBtn.Font = CONFIG.FontBold
	minimizeBtn.Text = "−"
	minimizeBtn.TextColor3 = CONFIG.Colors.Text
	minimizeBtn.TextSize = 20
	minimizeBtn.AutoButtonColor = false
	createUICorner(4).Parent = minimizeBtn

	-- Close Button (×)
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Parent = topBar
	closeBtn.Position = UDim2.new(1, -(btnSize + btnPadding), 0.5, -btnSize/2)
	closeBtn.Size = UDim2.new(0, btnSize, 0, btnSize)
	closeBtn.BackgroundColor3 = CONFIG.Colors.Button
	closeBtn.BorderSizePixel = 0
	closeBtn.Font = CONFIG.FontBold
	closeBtn.Text = "×"
	closeBtn.TextColor3 = CONFIG.Colors.AccentRed
	closeBtn.TextSize = 22
	closeBtn.AutoButtonColor = false
	createUICorner(4).Parent = closeBtn

	-- Hover effects for control buttons
	for _, btn in ipairs({refreshBtn, minimizeBtn, closeBtn}) do
		btn.MouseEnter:Connect(function()
			btn.BackgroundColor3 = CONFIG.Colors.ButtonHover
		end)
		btn.MouseLeave:Connect(function()
			btn.BackgroundColor3 = CONFIG.Colors.Button
		end)
	end

	-- Separator
	local separator = Instance.new("Frame")
	separator.Name = "Separator"
	separator.Parent = mainFrame
	separator.Position = UDim2.new(0, 0, 0, 35)
	separator.Size = UDim2.new(1, 0, 0, 1)
	separator.BackgroundColor3 = CONFIG.Colors.Border
	separator.BorderSizePixel = 0

	-- Sidebar (Left navigation)
	local sidebar = Instance.new("Frame")
	sidebar.Name = "Sidebar"
	sidebar.Parent = mainFrame
	sidebar.Position = UDim2.new(0, 0, 0, 36)
	sidebar.Size = UDim2.new(0, CONFIG.SidebarWidth, 1, -36)
	sidebar.BackgroundColor3 = CONFIG.Colors.TopBar
	sidebar.BorderSizePixel = 0

	-- Vertical separator for sidebar
	local sidebarSeparator = Instance.new("Frame")
	sidebarSeparator.Name = "SidebarSeparator"
	sidebarSeparator.Parent = mainFrame
	sidebarSeparator.Position = UDim2.new(0, CONFIG.SidebarWidth, 0, 36)
	sidebarSeparator.Size = UDim2.new(0, 1, 1, -36)
	sidebarSeparator.BackgroundColor3 = CONFIG.Colors.Border
	sidebarSeparator.BorderSizePixel = 0

	-- Sidebar buttons
	local tabButtons = {}
	local tabs = {
		{name = "GUIs", icon = "G"},
		{name = "Remotes", icon = "R"},
		{name = "Tools", icon = "T"},
		{name = "Settings", icon = "S"}
	}

	for i, tab in ipairs(tabs) do
		local btn = Instance.new("TextButton")
		btn.Name = tab.name .. "Tab"
		btn.Parent = sidebar
		btn.Position = UDim2.new(0, 10, 0, 10 + (i - 1) * 50)
		btn.Size = UDim2.new(1, -20, 0, 40)
		btn.BackgroundColor3 = State.currentTab == tab.name and CONFIG.Colors.ButtonActive or CONFIG.Colors.Button
		btn.BorderSizePixel = 0
		btn.Font = CONFIG.FontBold
		btn.Text = tab.name
		btn.TextColor3 = CONFIG.Colors.Text
		btn.TextSize = 13
		btn.AutoButtonColor = false
		createUICorner(4).Parent = btn

		tabButtons[tab.name] = btn
	end

	-- Toolbar (Freeze toggle + Search)
	local toolbar = Instance.new("Frame")
	toolbar.Name = "Toolbar"
	toolbar.Parent = mainFrame
	toolbar.Position = UDim2.new(0, CONFIG.SidebarWidth + 1, 0, 36)
	toolbar.Size = UDim2.new(1, -(CONFIG.SidebarWidth + 1), 0, 70)
	toolbar.BackgroundColor3 = CONFIG.Colors.Background
	toolbar.BorderSizePixel = 0

	-- First row: Freeze button
	local freezeBtn = Instance.new("TextButton")
	freezeBtn.Name = "FreezeButton"
	freezeBtn.Parent = toolbar
	freezeBtn.Position = UDim2.new(0, 10, 0, 5)
	freezeBtn.Size = UDim2.new(0, 100, 0, 28)
	freezeBtn.BackgroundColor3 = CONFIG.Colors.Button
	freezeBtn.BorderSizePixel = 0
	freezeBtn.Font = CONFIG.Font
	freezeBtn.Text = "FREEZE ALL"
	freezeBtn.TextColor3 = CONFIG.Colors.Text
	freezeBtn.TextSize = 13
	freezeBtn.AutoButtonColor = false
	createUICorner(4).Parent = freezeBtn

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Parent = toolbar
	statusLabel.Position = UDim2.new(0, 120, 0, 0)
	statusLabel.Size = UDim2.new(1, -130, 0, 35)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = CONFIG.Font
	statusLabel.Text = "Ready"
	statusLabel.TextColor3 = CONFIG.Colors.TextDim
	statusLabel.TextSize = 12
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left

	-- Second row: Search box
	local searchLabel = Instance.new("TextLabel")
	searchLabel.Name = "SearchLabel"
	searchLabel.Parent = toolbar
	searchLabel.Position = UDim2.new(0, 10, 0, 38)
	searchLabel.Size = UDim2.new(0, 50, 0, 28)
	searchLabel.BackgroundTransparency = 1
	searchLabel.Font = CONFIG.Font
	searchLabel.Text = "Search:"
	searchLabel.TextColor3 = CONFIG.Colors.Text
	searchLabel.TextSize = 12
	searchLabel.TextXAlignment = Enum.TextXAlignment.Left

	local searchBox = Instance.new("TextBox")
	searchBox.Name = "SearchBox"
	searchBox.Parent = toolbar
	searchBox.Position = UDim2.new(0, 65, 0, 38)
	searchBox.Size = UDim2.new(1, -140, 0, 28)
	searchBox.BackgroundColor3 = CONFIG.Colors.Button
	searchBox.BorderSizePixel = 0
	searchBox.Font = CONFIG.Font
	searchBox.PlaceholderText = "Type to filter GUIs..."
	searchBox.Text = ""
	searchBox.TextColor3 = CONFIG.Colors.Text
	searchBox.PlaceholderColor3 = CONFIG.Colors.TextDim
	searchBox.TextSize = 12
	searchBox.TextXAlignment = Enum.TextXAlignment.Left
	searchBox.ClearTextOnFocus = false
	createUICorner(4).Parent = searchBox

	-- Clear search button
	local clearSearchBtn = Instance.new("TextButton")
	clearSearchBtn.Name = "ClearSearchButton"
	clearSearchBtn.Parent = toolbar
	clearSearchBtn.Position = UDim2.new(1, -65, 0, 38)
	clearSearchBtn.Size = UDim2.new(0, 55, 0, 28)
	clearSearchBtn.BackgroundColor3 = CONFIG.Colors.Button
	clearSearchBtn.BorderSizePixel = 0
	clearSearchBtn.Font = CONFIG.Font
	clearSearchBtn.Text = "CLEAR"
	clearSearchBtn.TextColor3 = CONFIG.Colors.TextDim
	clearSearchBtn.TextSize = 11
	clearSearchBtn.AutoButtonColor = false
	createUICorner(4).Parent = clearSearchBtn

	-- Content Frame
	local contentFrame = Instance.new("ScrollingFrame")
	contentFrame.Name = "ContentFrame"
	contentFrame.Parent = mainFrame
	contentFrame.Position = UDim2.new(0, CONFIG.SidebarWidth + 11, 0, 116)
	contentFrame.Size = UDim2.new(1, -(CONFIG.SidebarWidth + 21), 1, -126)
	contentFrame.BackgroundColor3 = CONFIG.Colors.Background
	contentFrame.BorderSizePixel = 0
	contentFrame.ScrollBarThickness = 6
	contentFrame.ScrollBarImageColor3 = CONFIG.Colors.Border
	contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	contentFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y

	local listLayout = Instance.new("UIListLayout")
	listLayout.Parent = contentFrame
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 2)

	-- Content frames for each tab
	local remotesFrame = Instance.new("ScrollingFrame")
	remotesFrame.Name = "RemotesFrame"
	remotesFrame.Parent = mainFrame
	remotesFrame.Position = UDim2.new(0, CONFIG.SidebarWidth + 11, 0, 46)
	remotesFrame.Size = UDim2.new(1, -(CONFIG.SidebarWidth + 21), 1, -56)
	remotesFrame.BackgroundColor3 = CONFIG.Colors.Background
	remotesFrame.BorderSizePixel = 0
	remotesFrame.ScrollBarThickness = 6
	remotesFrame.ScrollBarImageColor3 = CONFIG.Colors.Border
	remotesFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	remotesFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	remotesFrame.Visible = false

	local remotesLayout = Instance.new("UIListLayout")
	remotesLayout.Parent = remotesFrame
	remotesLayout.SortOrder = Enum.SortOrder.LayoutOrder
	remotesLayout.Padding = UDim.new(0, 2)

	local toolsFrame = Instance.new("ScrollingFrame")
	toolsFrame.Name = "ToolsFrame"
	toolsFrame.Parent = mainFrame
	toolsFrame.Position = UDim2.new(0, CONFIG.SidebarWidth + 11, 0, 46)
	toolsFrame.Size = UDim2.new(1, -(CONFIG.SidebarWidth + 21), 1, -56)
	toolsFrame.BackgroundColor3 = CONFIG.Colors.Background
	toolsFrame.BorderSizePixel = 0
	toolsFrame.ScrollBarThickness = 6
	toolsFrame.ScrollBarImageColor3 = CONFIG.Colors.Border
	toolsFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	toolsFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	toolsFrame.Visible = false

	local toolsLayout = Instance.new("UIListLayout")
	toolsLayout.Parent = toolsFrame
	toolsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	toolsLayout.Padding = UDim.new(0, 5)

	local settingsFrame = Instance.new("Frame")
	settingsFrame.Name = "SettingsFrame"
	settingsFrame.Parent = mainFrame
	settingsFrame.Position = UDim2.new(0, CONFIG.SidebarWidth + 11, 0, 46)
	settingsFrame.Size = UDim2.new(1, -(CONFIG.SidebarWidth + 21), 1, -56)
	settingsFrame.BackgroundColor3 = CONFIG.Colors.Background
	settingsFrame.BorderSizePixel = 0
	settingsFrame.Visible = false

	return screenGui, mainFrame, contentFrame, freezeBtn, refreshBtn, minimizeBtn, closeBtn, statusLabel, searchBox, clearSearchBtn, tabButtons, toolbar, remotesFrame, toolsFrame, settingsFrame
end

-- ========================
-- DRAG FUNCTIONALITY
-- ========================

local function makeDraggable(frame, dragHandle)
	local dragging = false
	local dragStart = nil
	local startPos = nil

	dragHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - dragStart
			frame.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
end

-- ========================
-- GUI SCANNING & DISPLAY
-- ========================

local function attachGuiObject(obj)
	print("=== ATTACH DEBUG START ===")
	print("Attaching:", obj:GetFullName())

	-- First, make the object itself visible
	if isGuiRoot(obj) then
		obj.Enabled = true
		print("✓ Enabled GuiRoot:", obj.Name)
	elseif obj:IsA("GuiObject") then
		obj.Visible = true
		print("✓ Made visible:", obj.Name)
	end

	-- Then enable entire parent chain
	local parent = obj.Parent
	local depth = 0
	while parent and depth < 20 do  -- Safety limit
		if isGuiRoot(parent) then
			parent.Enabled = true
			print("✓ Enabled parent GuiRoot:", parent.Name)
			break
		elseif parent:IsA("GuiObject") then
			parent.Visible = true
			print("✓ Made parent visible:", parent.Name)
		end
		parent = parent.Parent
		depth = depth + 1
	end

	-- Also make all descendants visible for complete visibility
	for _, descendant in ipairs(obj:GetDescendants()) do
		if descendant:IsA("GuiObject") then
			descendant.Visible = true
		elseif isGuiRoot(descendant) then
			descendant.Enabled = true
		end
	end

	print("=== ATTACH DEBUG END ===")
end

local function hideGuiObject(obj)
	if State.hiddenGuis[obj] then
		-- Unhide
		State.hiddenGuis[obj] = nil
		if isGuiRoot(obj) then
			obj.Enabled = true
		elseif obj:IsA("GuiObject") then
			obj.Visible = true
		end
	else
		-- Hide
		State.hiddenGuis[obj] = true
		if isGuiRoot(obj) then
			obj.Enabled = false
		elseif obj:IsA("GuiObject") then
			obj.Visible = false
		end
	end
end

local function createGuiEntry(parent, obj, depth, onRefresh)
	local entryHeight = 32
	local indentSize = depth * 20

	-- Create wrapper to hold both entry and its children
	local wrapper = Instance.new("Frame")
	wrapper.Name = "Wrapper_" .. obj.Name
	wrapper.Parent = parent
	wrapper.Size = UDim2.new(1, -10, 0, entryHeight)
	wrapper.BackgroundTransparency = 1
	wrapper.BorderSizePixel = 0
	wrapper.AutomaticSize = Enum.AutomaticSize.Y

	local wrapperLayout = Instance.new("UIListLayout")
	wrapperLayout.Parent = wrapper
	wrapperLayout.SortOrder = Enum.SortOrder.LayoutOrder
	wrapperLayout.Padding = UDim.new(0, 2)

	local entry = Instance.new("Frame")
	entry.Name = "Entry_" .. obj.Name
	entry.Parent = wrapper
	entry.Size = UDim2.new(1, 0, 0, entryHeight)
	entry.BackgroundColor3 = depth == 0 and CONFIG.Colors.TopBar or CONFIG.Colors.Button
	entry.BorderSizePixel = 0
	entry.LayoutOrder = 1

	createUICorner(4).Parent = entry

	-- Expand button (if has children)
	local hasChildren = #obj:GetChildren() > 0
	local expandBtn = nil

	if hasChildren then
		expandBtn = Instance.new("TextButton")
		expandBtn.Name = "ExpandButton"
		expandBtn.Parent = entry
		expandBtn.Position = UDim2.new(0, 5 + indentSize, 0, 5)
		expandBtn.Size = UDim2.new(0, 22, 0, 22)
		expandBtn.BackgroundColor3 = CONFIG.Colors.Background
		expandBtn.BorderSizePixel = 0
		expandBtn.Font = CONFIG.FontBold
		expandBtn.Text = State.expanded[obj] and "−" or "+"
		expandBtn.TextColor3 = CONFIG.Colors.Text
		expandBtn.TextSize = 14
		expandBtn.AutoButtonColor = false
		createUICorner(3).Parent = expandBtn
	end

	-- Name Label
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Parent = entry
	nameLabel.Position = UDim2.new(0, 35 + indentSize, 0, 0)
	nameLabel.Size = UDim2.new(0, 180, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = CONFIG.Font
	nameLabel.Text = obj.Name
	nameLabel.TextColor3 = CONFIG.Colors.Text
	nameLabel.TextSize = 13
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd

	-- Source Tag (for root level)
	if depth == 0 then
		local sourceLabel = Instance.new("TextLabel")
		sourceLabel.Name = "SourceLabel"
		sourceLabel.Parent = entry
		sourceLabel.Position = UDim2.new(0, 220, 0, 0)
		sourceLabel.Size = UDim2.new(0, 80, 1, 0)
		sourceLabel.BackgroundTransparency = 1
		sourceLabel.Font = CONFIG.Font
		sourceLabel.Text = getSourceTag(obj)
		sourceLabel.TextColor3 = CONFIG.Colors.TextDim
		sourceLabel.TextSize = 11
		sourceLabel.TextXAlignment = Enum.TextXAlignment.Left
	end

	-- FREEZE Button (individual)
	local freezeIndividualBtn = Instance.new("TextButton")
	freezeIndividualBtn.Name = "FreezeIndividualButton"
	freezeIndividualBtn.Parent = entry
	freezeIndividualBtn.Position = UDim2.new(1, -195, 0, 5)
	freezeIndividualBtn.Size = UDim2.new(0, 35, 0, 22)
	freezeIndividualBtn.BackgroundColor3 = State.frozenIndividual[obj] and CONFIG.Colors.AccentBlue or CONFIG.Colors.Button
	freezeIndividualBtn.BorderSizePixel = 0
	freezeIndividualBtn.Font = CONFIG.Font
	freezeIndividualBtn.Text = "FRZ"
	freezeIndividualBtn.TextColor3 = CONFIG.Colors.Text
	freezeIndividualBtn.TextSize = 10
	freezeIndividualBtn.AutoButtonColor = false
	createUICorner(3).Parent = freezeIndividualBtn

	-- ATTACH Button
	local attachBtn = Instance.new("TextButton")
	attachBtn.Name = "AttachButton"
	attachBtn.Parent = entry
	attachBtn.Position = UDim2.new(1, -155, 0, 5)
	attachBtn.Size = UDim2.new(0, 65, 0, 22)
	attachBtn.BackgroundColor3 = CONFIG.Colors.AccentGreen
	attachBtn.BorderSizePixel = 0
	attachBtn.Font = CONFIG.Font
	attachBtn.Text = "ATTACH"
	attachBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	attachBtn.TextSize = 11
	attachBtn.AutoButtonColor = false
	createUICorner(3).Parent = attachBtn

	attachBtn.MouseEnter:Connect(function()
		attachBtn.BackgroundColor3 = Color3.fromRGB(90, 200, 110)
	end)
	attachBtn.MouseLeave:Connect(function()
		attachBtn.BackgroundColor3 = CONFIG.Colors.AccentGreen
	end)

	attachBtn.MouseButton1Click:Connect(function()
		attachGuiObject(obj)

		-- Visual feedback
		local originalColor = attachBtn.BackgroundColor3
		local originalText = attachBtn.Text
		attachBtn.BackgroundColor3 = Color3.fromRGB(80, 220, 100)
		attachBtn.Text = "DONE!"

		task.wait(0.5)
		attachBtn.BackgroundColor3 = originalColor
		attachBtn.Text = originalText
	end)

	-- HIDE Button
	local hideBtn = Instance.new("TextButton")
	hideBtn.Name = "HideButton"
	hideBtn.Parent = entry
	hideBtn.Position = UDim2.new(1, -85, 0, 5)
	hideBtn.Size = UDim2.new(0, 40, 0, 22)
	hideBtn.BackgroundColor3 = State.hiddenGuis[obj] and CONFIG.Colors.AccentRed or CONFIG.Colors.Button
	hideBtn.BorderSizePixel = 0
	hideBtn.Font = CONFIG.Font
	hideBtn.Text = "HIDE"
	hideBtn.TextColor3 = CONFIG.Colors.Text
	hideBtn.TextSize = 11
	hideBtn.AutoButtonColor = false
	createUICorner(3).Parent = hideBtn

	hideBtn.MouseButton1Click:Connect(function()
		hideGuiObject(obj)
		hideBtn.BackgroundColor3 = State.hiddenGuis[obj] and CONFIG.Colors.AccentRed or CONFIG.Colors.Button
	end)

	-- MORE Button (...)
	local moreBtn = Instance.new("TextButton")
	moreBtn.Name = "MoreButton"
	moreBtn.Parent = entry
	moreBtn.Position = UDim2.new(1, -40, 0, 5)
	moreBtn.Size = UDim2.new(0, 30, 0, 22)
	moreBtn.BackgroundColor3 = CONFIG.Colors.Button
	moreBtn.BorderSizePixel = 0
	moreBtn.Font = CONFIG.FontBold
	moreBtn.Text = "..."
	moreBtn.TextColor3 = CONFIG.Colors.Text
	moreBtn.TextSize = 14
	moreBtn.AutoButtonColor = false
	createUICorner(3).Parent = moreBtn

	moreBtn.MouseEnter:Connect(function()
		moreBtn.BackgroundColor3 = CONFIG.Colors.ButtonHover
	end)
	moreBtn.MouseLeave:Connect(function()
		moreBtn.BackgroundColor3 = CONFIG.Colors.Button
	end)

	-- More menu (context menu)
	local moreMenu = nil
	moreBtn.MouseButton1Click:Connect(function()
		if moreMenu then
			moreMenu:Destroy()
			moreMenu = nil
			return
		end

		moreMenu = Instance.new("Frame")
		moreMenu.Name = "MoreMenu"
		moreMenu.Parent = entry
		moreMenu.Position = UDim2.new(1, -180, 0, 28)
		moreMenu.Size = UDim2.new(0, 170, 0, 0)
		moreMenu.BackgroundColor3 = CONFIG.Colors.TopBar
		moreMenu.BorderSizePixel = 1
		moreMenu.BorderColor3 = CONFIG.Colors.Border
		moreMenu.AutomaticSize = Enum.AutomaticSize.Y
		moreMenu.ZIndex = 100
		createUICorner(4).Parent = moreMenu

		local menuLayout = Instance.new("UIListLayout")
		menuLayout.Parent = moreMenu
		menuLayout.SortOrder = Enum.SortOrder.LayoutOrder
		menuLayout.Padding = UDim.new(0, 2)

		local menuPadding = Instance.new("UIPadding")
		menuPadding.Parent = moreMenu
		menuPadding.PaddingTop = UDim.new(0, 5)
		menuPadding.PaddingBottom = UDim.new(0, 5)
		menuPadding.PaddingLeft = UDim.new(0, 5)
		menuPadding.PaddingRight = UDim.new(0, 5)

		local menuOptions = {
			{text = "Copy Path", callback = function()
				local path = getFullPath(obj)
				if copyToClipboard(path) then
					print("Copied to clipboard:", path)
				else
					print("Path:", path)
				end
			end},
			{text = "Copy Name", callback = function()
				if copyToClipboard(obj.Name) then
					print("Copied to clipboard:", obj.Name)
				else
					print("Name:", obj.Name)
				end
			end},
			{text = "View Properties", callback = function()
				print("=== PROPERTIES:", obj:GetFullName(), "===")
				for _, prop in ipairs({"Name", "ClassName", "Parent", "Visible", "Position", "Size", "BackgroundColor3", "BackgroundTransparency"}) do
					local success, value = pcall(function() return obj[prop] end)
					if success then
						print(prop .. ":", formatValue(value))
					end
				end
				print("===========================")
			end},
			{text = "Clone Object", callback = function()
				local success, clone = pcall(function()
					return obj:Clone()
				end)
				if success then
					print("Cloned:", obj.Name, "->", clone:GetFullName())
				else
					print("Failed to clone:", obj.Name)
				end
			end},
			{text = "Destroy Object", callback = function()
				print("Destroyed:", obj:GetFullName())
				obj:Destroy()
				if onRefresh then
					onRefresh()
				end
			end},
		}

		for i, option in ipairs(menuOptions) do
			local optionBtn = Instance.new("TextButton")
			optionBtn.Name = option.text
			optionBtn.Parent = moreMenu
			optionBtn.Size = UDim2.new(1, 0, 0, 26)
			optionBtn.BackgroundColor3 = CONFIG.Colors.Button
			optionBtn.BorderSizePixel = 0
			optionBtn.Font = CONFIG.Font
			optionBtn.Text = option.text
			optionBtn.TextColor3 = CONFIG.Colors.Text
			optionBtn.TextSize = 11
			optionBtn.TextXAlignment = Enum.TextXAlignment.Left
			optionBtn.AutoButtonColor = false
			optionBtn.LayoutOrder = i
			createUICorner(3).Parent = optionBtn

			local btnPadding = Instance.new("UIPadding")
			btnPadding.Parent = optionBtn
			btnPadding.PaddingLeft = UDim.new(0, 8)

			optionBtn.MouseEnter:Connect(function()
				optionBtn.BackgroundColor3 = CONFIG.Colors.ButtonHover
			end)
			optionBtn.MouseLeave:Connect(function()
				optionBtn.BackgroundColor3 = CONFIG.Colors.Button
			end)

			optionBtn.MouseButton1Click:Connect(function()
				option.callback()
				if moreMenu then
					moreMenu:Destroy()
					moreMenu = nil
				end
			end)
		end
	end)

	-- Freeze individual button logic
	freezeIndividualBtn.MouseButton1Click:Connect(function()
		if State.frozenIndividual[obj] then
			-- Unfreeze
			State.frozenIndividual[obj] = nil
			freezeIndividualBtn.BackgroundColor3 = CONFIG.Colors.Button
			print("Unfroze:", obj.Name)
			-- Refresh to show live children
			if onRefresh then
				onRefresh()
			end
		else
			-- Freeze - capture current children
			local childrenSnapshot = {}
			for _, child in ipairs(obj:GetChildren()) do
				if child:IsA("GuiObject") or isGuiRoot(child) then
					table.insert(childrenSnapshot, child)
				end
			end
			State.frozenIndividual[obj] = childrenSnapshot
			freezeIndividualBtn.BackgroundColor3 = CONFIG.Colors.AccentBlue
			print("Frozen:", obj.Name, "with", #childrenSnapshot, "children")
		end
	end)

	-- Expand functionality
	if expandBtn then
		local childContainer = nil

		expandBtn.MouseEnter:Connect(function()
			expandBtn.BackgroundColor3 = CONFIG.Colors.ButtonHover
		end)
		expandBtn.MouseLeave:Connect(function()
			expandBtn.BackgroundColor3 = CONFIG.Colors.Background
		end)

		expandBtn.MouseButton1Click:Connect(function()
			if State.expanded[obj] then
				-- Collapse
				State.expanded[obj] = false
				expandBtn.Text = "+"
				if childContainer then
					childContainer:Destroy()
					childContainer = nil
				end
			else
				-- Expand
				State.expanded[obj] = true
				expandBtn.Text = "−"

				-- Create child container directly under this entry in wrapper
				childContainer = Instance.new("Frame")
				childContainer.Name = "ChildContainer"
				childContainer.Parent = wrapper
				childContainer.Size = UDim2.new(1, 0, 0, 0)
				childContainer.BackgroundTransparency = 1
				childContainer.BorderSizePixel = 0
				childContainer.AutomaticSize = Enum.AutomaticSize.Y
				childContainer.LayoutOrder = 2

				local childLayout = Instance.new("UIListLayout")
				childLayout.Parent = childContainer
				childLayout.SortOrder = Enum.SortOrder.LayoutOrder
				childLayout.Padding = UDim.new(0, 2)

				-- Add children (use frozen snapshot if available)
				local childrenToDisplay = State.frozenIndividual[obj] or obj:GetChildren()
				for i, child in ipairs(childrenToDisplay) do
					if child:IsA("GuiObject") or isGuiRoot(child) then
						local childEntry = createGuiEntry(childContainer, child, depth + 1, onRefresh)
						childEntry.LayoutOrder = i
					end
				end
			end
		end)
	end

	return wrapper
end

local function matchesSearch(obj, query)
	if query == "" then
		return true
	end

	-- Case-insensitive search
	local lowerQuery = string.lower(query)
	local lowerName = string.lower(obj.Name)

	return string.find(lowerName, lowerQuery, 1, true) ~= nil
end

local function scanAndDisplayGuis(contentFrame, statusLabel)
	-- Clear existing content
	for _, child in ipairs(contentFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	State.expanded = {}

	local guiList = {}

	-- Use frozen data if freeze is active
	if State.frozen and State.frozenData then
		guiList = State.frozenData
		statusLabel.Text = "Frozen | " .. #guiList .. " root GUIs"
		statusLabel.TextColor3 = CONFIG.Colors.AccentBlue
	else
		-- Scan PlayerGui
		for _, gui in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
			if isGuiRoot(gui) then
				table.insert(guiList, gui)
			end
		end

		-- Scan StarterGui
		local starterGui = game:GetService("StarterGui")
		for _, gui in ipairs(starterGui:GetChildren()) do
			if isGuiRoot(gui) then
				table.insert(guiList, gui)
			end
		end

		-- Scan CoreGui (if possible)
		pcall(function()
			for _, gui in ipairs(CoreGui:GetChildren()) do
				if isGuiRoot(gui) then
					table.insert(guiList, gui)
				end
			end
		end)

		statusLabel.Text = "Scanned | " .. #guiList .. " root GUIs found"
		statusLabel.TextColor3 = CONFIG.Colors.AccentGreen
	end

	-- Filter by search query
	local filteredList = {}
	for _, gui in ipairs(guiList) do
		if matchesSearch(gui, State.searchQuery) then
			table.insert(filteredList, gui)
		end
	end

	-- Update status with filter info
	if State.searchQuery ~= "" then
		statusLabel.Text = statusLabel.Text .. " | Filtered: " .. #filteredList .. "/" .. #guiList
	end

	-- Display filtered root GUIs
	for i, gui in ipairs(filteredList) do
		local entry = createGuiEntry(contentFrame, gui, 0, function()
			scanAndDisplayGuis(contentFrame, statusLabel)
		end)
		entry.LayoutOrder = i
	end
end

-- ========================
-- SHOW/HIDE FUNCTIONALITY
-- ========================

local debugToolInstance = nil

_G.ShowDebugTool = function()
	if debugToolInstance then
		debugToolInstance.Enabled = true

		-- Make all GuiObjects visible
		for _, v in ipairs(debugToolInstance:GetDescendants()) do
			if v:IsA("GuiObject") then
				v.Visible = true
			end
		end

		print("🟢 GUI Debug Tool Shown")
	else
		print("⚠ Debug Tool not initialized yet")
	end
end

_G.HideDebugTool = function()
	if debugToolInstance then
		debugToolInstance.Enabled = false
		print("🙈 GUI Debug Tool Hidden")
	else
		print("⚠ Debug Tool not initialized yet")
	end
end

_G.ToggleDebugTool = function()
	if debugToolInstance then
		if debugToolInstance.Enabled then
			_G.HideDebugTool()
		else
			_G.ShowDebugTool()
		end
	end
end

-- ========================
-- INITIALIZE
-- ========================

-- ========================
-- REMOTE SPY
-- ========================

local function setupRemoteSpy(remotesFrame)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	-- Hook RemoteEvent
	local oldFireServer
	oldFireServer = hookmetamethod(game, "__namecall", function(self, ...)
		local method = getnamecallmethod()
		local args = {...}

		if method == "FireServer" or method == "InvokeServer" then
			if self:IsA("RemoteEvent") or self:IsA("RemoteFunction") then
				table.insert(State.remoteLogs, {
					time = os.date("%H:%M:%S"),
					remote = self:GetFullName(),
					type = self.ClassName,
					method = method,
					args = args
				})
				print("[REMOTE]", method, "->", self:GetFullName())
			end
		end

		return oldFireServer(self, ...)
	end)
end

local function refreshRemotesList(remotesFrame)
	for _, child in ipairs(remotesFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for i, log in ipairs(State.remoteLogs) do
		if i > 50 then break end -- Limit to last 50

		local logEntry = Instance.new("Frame")
		logEntry.Name = "LogEntry_" .. i
		logEntry.Parent = remotesFrame
		logEntry.Size = UDim2.new(1, -10, 0, 60)
		logEntry.BackgroundColor3 = CONFIG.Colors.Button
		logEntry.BorderSizePixel = 0
		logEntry.LayoutOrder = #State.remoteLogs - i + 1
		createUICorner(4).Parent = logEntry

		local timeLabel = Instance.new("TextLabel")
		timeLabel.Parent = logEntry
		timeLabel.Position = UDim2.new(0, 8, 0, 5)
		timeLabel.Size = UDim2.new(0, 60, 0, 15)
		timeLabel.BackgroundTransparency = 1
		timeLabel.Font = CONFIG.Font
		timeLabel.Text = log.time
		timeLabel.TextColor3 = CONFIG.Colors.TextDim
		timeLabel.TextSize = 10
		timeLabel.TextXAlignment = Enum.TextXAlignment.Left

		local typeLabel = Instance.new("TextLabel")
		typeLabel.Parent = logEntry
		typeLabel.Position = UDim2.new(0, 75, 0, 5)
		typeLabel.Size = UDim2.new(0, 100, 0, 15)
		typeLabel.BackgroundTransparency = 1
		typeLabel.Font = CONFIG.FontBold
		typeLabel.Text = log.method
		typeLabel.TextColor3 = CONFIG.Colors.AccentBlue
		typeLabel.TextSize = 10
		typeLabel.TextXAlignment = Enum.TextXAlignment.Left

		local remoteLabel = Instance.new("TextLabel")
		remoteLabel.Parent = logEntry
		remoteLabel.Position = UDim2.new(0, 8, 0, 22)
		remoteLabel.Size = UDim2.new(1, -16, 0, 35)
		remoteLabel.BackgroundTransparency = 1
		remoteLabel.Font = CONFIG.Font
		remoteLabel.Text = log.remote
		remoteLabel.TextColor3 = CONFIG.Colors.Text
		remoteLabel.TextSize = 11
		remoteLabel.TextXAlignment = Enum.TextXAlignment.Left
		remoteLabel.TextYAlignment = Enum.TextYAlignment.Top
		remoteLabel.TextWrapped = true
	end
end

local function populateToolsTab(toolsFrame)
	local tools = {
		{
			name = "Scan All Remotes",
			desc = "Find all RemoteEvents and RemoteFunctions",
			color = CONFIG.Colors.AccentBlue,
			callback = function()
				print("=== SCANNING REMOTES ===")
				local count = 0
				for _, desc in ipairs(game:GetDescendants()) do
					if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") then
						print(desc.ClassName, "->", desc:GetFullName())
						count = count + 1
					end
				end
				print("Total found:", count)
				print("=======================")
			end
		},
		{
			name = "List All Scripts",
			desc = "Find all LocalScripts and Scripts",
			color = CONFIG.Colors.AccentYellow,
			callback = function()
				print("=== SCANNING SCRIPTS ===")
				local count = 0
				for _, desc in ipairs(game:GetDescendants()) do
					if desc:IsA("LocalScript") or desc:IsA("Script") then
						print(desc.ClassName, "->", desc:GetFullName())
						count = count + 1
					end
				end
				print("Total found:", count)
				print("========================")
			end
		},
		{
			name = "Dump Game Tree",
			desc = "Print entire game hierarchy",
			color = CONFIG.Colors.AccentPurple,
			callback = function()
				print("=== GAME TREE DUMP ===")
				local function printTree(obj, depth)
					if depth > 5 then return end
					print(string.rep("  ", depth) .. obj.ClassName .. ": " .. obj.Name)
					for _, child in ipairs(obj:GetChildren()) do
						printTree(child, depth + 1)
					end
				end
				printTree(game, 0)
				print("======================")
			end
		},
		{
			name = "Clear Console",
			desc = "Clear output console (if supported)",
			color = CONFIG.Colors.AccentRed,
			callback = function()
				if rconsoleclear then
					rconsoleclear()
				end
				print("\n\n\n\n\n\n\n\n\n\n")
				print("Console cleared")
			end
		},
	}

	for i, tool in ipairs(tools) do
		local toolCard = Instance.new("Frame")
		toolCard.Name = "Tool_" .. i
		toolCard.Parent = toolsFrame
		toolCard.Size = UDim2.new(1, -10, 0, 70)
		toolCard.BackgroundColor3 = CONFIG.Colors.Button
		toolCard.BorderSizePixel = 0
		toolCard.LayoutOrder = i
		createUICorner(6).Parent = toolCard

		local colorBar = Instance.new("Frame")
		colorBar.Parent = toolCard
		colorBar.Size = UDim2.new(0, 4, 1, 0)
		colorBar.BackgroundColor3 = tool.color
		colorBar.BorderSizePixel = 0

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Parent = toolCard
		nameLabel.Position = UDim2.new(0, 15, 0, 8)
		nameLabel.Size = UDim2.new(1, -120, 0, 20)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = CONFIG.FontBold
		nameLabel.Text = tool.name
		nameLabel.TextColor3 = CONFIG.Colors.Text
		nameLabel.TextSize = 14
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left

		local descLabel = Instance.new("TextLabel")
		descLabel.Parent = toolCard
		descLabel.Position = UDim2.new(0, 15, 0, 30)
		descLabel.Size = UDim2.new(1, -120, 0, 30)
		descLabel.BackgroundTransparency = 1
		descLabel.Font = CONFIG.Font
		descLabel.Text = tool.desc
		descLabel.TextColor3 = CONFIG.Colors.TextDim
		descLabel.TextSize = 11
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.TextWrapped = true

		local runBtn = Instance.new("TextButton")
		runBtn.Parent = toolCard
		runBtn.Position = UDim2.new(1, -95, 0.5, -15)
		runBtn.Size = UDim2.new(0, 85, 0, 30)
		runBtn.BackgroundColor3 = tool.color
		runBtn.BorderSizePixel = 0
		runBtn.Font = CONFIG.FontBold
		runBtn.Text = "RUN"
		runBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		runBtn.TextSize = 13
		runBtn.AutoButtonColor = false
		createUICorner(4).Parent = runBtn

		runBtn.MouseEnter:Connect(function()
			runBtn.BackgroundColor3 = Color3.new(
				math.min(tool.color.R + 0.1, 1),
				math.min(tool.color.G + 0.1, 1),
				math.min(tool.color.B + 0.1, 1)
			)
		end)
		runBtn.MouseLeave:Connect(function()
			runBtn.BackgroundColor3 = tool.color
		end)
		runBtn.MouseButton1Click:Connect(tool.callback)
	end
end

local function initialize()
	local screenGui, mainFrame, contentFrame, freezeBtn, refreshBtn, minimizeBtn, closeBtn, statusLabel, searchBox, clearSearchBtn, tabButtons, toolbar, remotesFrame, toolsFrame, settingsFrame = createMainWindow()

	-- Store reference for show/hide functions
	debugToolInstance = screenGui

	-- Setup Remote Spy
	pcall(function()
		if hookmetamethod then
			setupRemoteSpy(remotesFrame)
		end
	end)

	-- Populate Tools tab
	populateToolsTab(toolsFrame)

	-- Tab switching logic
	local function switchTab(tabName)
		State.currentTab = tabName

		-- Update button colors
		for name, btn in pairs(tabButtons) do
			btn.BackgroundColor3 = (name == tabName) and CONFIG.Colors.ButtonActive or CONFIG.Colors.Button
		end

		-- Show/hide content
		contentFrame.Visible = (tabName == "GUIs")
		toolbar.Visible = (tabName == "GUIs")
		remotesFrame.Visible = (tabName == "Remotes")
		toolsFrame.Visible = (tabName == "Tools")
		settingsFrame.Visible = (tabName == "Settings")

		if tabName == "Remotes" then
			refreshRemotesList(remotesFrame)
		end
	end

	-- Connect tab buttons
	for tabName, btn in pairs(tabButtons) do
		btn.MouseEnter:Connect(function()
			if State.currentTab ~= tabName then
				btn.BackgroundColor3 = CONFIG.Colors.ButtonHover
			end
		end)
		btn.MouseLeave:Connect(function()
			if State.currentTab ~= tabName then
				btn.BackgroundColor3 = CONFIG.Colors.Button
			end
		end)
		btn.MouseButton1Click:Connect(function()
			switchTab(tabName)
		end)
	end

	-- Make draggable
	local topBar = mainFrame:FindFirstChild("TopBar")
	makeDraggable(mainFrame, topBar)

	-- Search functionality
	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		State.searchQuery = searchBox.Text
		scanAndDisplayGuis(contentFrame, statusLabel)
	end)

	clearSearchBtn.MouseEnter:Connect(function()
		clearSearchBtn.BackgroundColor3 = CONFIG.Colors.ButtonHover
	end)
	clearSearchBtn.MouseLeave:Connect(function()
		clearSearchBtn.BackgroundColor3 = CONFIG.Colors.Button
	end)
	clearSearchBtn.MouseButton1Click:Connect(function()
		searchBox.Text = ""
		State.searchQuery = ""
		scanAndDisplayGuis(contentFrame, statusLabel)
	end)

	-- Close button (hides instead of destroying)
	closeBtn.MouseButton1Click:Connect(function()
		_G.HideDebugTool()
	end)

	-- Minimize button
	local isMinimized = false
	local originalSize = mainFrame.Size
	minimizeBtn.MouseButton1Click:Connect(function()
		if isMinimized then
			mainFrame.Size = originalSize
			contentFrame.Visible = true
			mainFrame:FindFirstChild("Toolbar").Visible = true
			minimizeBtn.Text = "−"
			isMinimized = false
		else
			mainFrame.Size = UDim2.new(0, CONFIG.WindowSize.X, 0, 35)
			contentFrame.Visible = false
			mainFrame:FindFirstChild("Toolbar").Visible = false
			minimizeBtn.Text = "□"
			isMinimized = true
		end
	end)

	-- Freeze button
	freezeBtn.MouseButton1Click:Connect(function()
		State.frozen = not State.frozen

		if State.frozen then
			-- Capture current state
			local guiList = {}

			for _, gui in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
				if isGuiRoot(gui) then table.insert(guiList, gui) end
			end

			local starterGui = game:GetService("StarterGui")
			for _, gui in ipairs(starterGui:GetChildren()) do
				if isGuiRoot(gui) then table.insert(guiList, gui) end
			end

			pcall(function()
				for _, gui in ipairs(CoreGui:GetChildren()) do
					if isGuiRoot(gui) then table.insert(guiList, gui) end
				end
			end)

			State.frozenData = guiList
			freezeBtn.BackgroundColor3 = CONFIG.Colors.AccentBlue
			freezeBtn.Text = "UNFREEZE ALL"
			statusLabel.Text = "Frozen | " .. #guiList .. " root GUIs"
			statusLabel.TextColor3 = CONFIG.Colors.AccentBlue
		else
			-- Unfreeze
			State.frozenData = nil
			freezeBtn.BackgroundColor3 = CONFIG.Colors.Button
			freezeBtn.Text = "FREEZE ALL"
			scanAndDisplayGuis(contentFrame, statusLabel)
		end
	end)

	freezeBtn.MouseEnter:Connect(function()
		if not State.frozen then
			freezeBtn.BackgroundColor3 = CONFIG.Colors.ButtonHover
		end
	end)

	freezeBtn.MouseLeave:Connect(function()
		if not State.frozen then
			freezeBtn.BackgroundColor3 = CONFIG.Colors.Button
		end
	end)

	-- Refresh button
	refreshBtn.MouseButton1Click:Connect(function()
		if not State.frozen then
			scanAndDisplayGuis(contentFrame, statusLabel)
		end
	end)

	-- Initial scan
	scanAndDisplayGuis(contentFrame, statusLabel)
end

-- Start the tool
initialize()
