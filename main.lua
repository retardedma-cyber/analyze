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

-- ========================
-- RESULTS WINDOW SYSTEM
-- ========================

local function createUICorner(radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	return corner
end

local function createResultsWindow(title, content, parentGui)
	-- Create overlay
	local overlay = Instance.new("Frame")
	overlay.Name = "ResultsOverlay"
	overlay.Parent = parentGui
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.5
	overlay.BorderSizePixel = 0
	overlay.ZIndex = 5000

	-- Results window
	local resultsWindow = Instance.new("Frame")
	resultsWindow.Name = "ResultsWindow"
	resultsWindow.Parent = overlay
	resultsWindow.Position = UDim2.new(0.5, -300, 0.5, -250)
	resultsWindow.Size = UDim2.new(0, 600, 0, 500)
	resultsWindow.BackgroundColor3 = CONFIG.Colors.Background
	resultsWindow.BorderSizePixel = 1
	resultsWindow.BorderColor3 = CONFIG.Colors.Border
	resultsWindow.ZIndex = 5001
	createUICorner(8).Parent = resultsWindow

	-- Title bar
	local titleBar = Instance.new("Frame")
	titleBar.Parent = resultsWindow
	titleBar.Size = UDim2.new(1, 0, 0, 35)
	titleBar.BackgroundColor3 = CONFIG.Colors.TopBar
	titleBar.BorderSizePixel = 0
	titleBar.ZIndex = 5002
	createUICorner(8).Parent = titleBar

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Parent = titleBar
	titleLabel.Position = UDim2.new(0, 12, 0, 0)
	titleLabel.Size = UDim2.new(1, -50, 1, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = CONFIG.FontBold
	titleLabel.Text = title
	titleLabel.TextColor3 = CONFIG.Colors.Text
	titleLabel.TextSize = 15
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.ZIndex = 5003

	-- Close button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Parent = titleBar
	closeBtn.Position = UDim2.new(1, -30, 0.5, -13)
	closeBtn.Size = UDim2.new(0, 26, 0, 26)
	closeBtn.BackgroundColor3 = CONFIG.Colors.AccentRed
	closeBtn.BorderSizePixel = 0
	closeBtn.Font = CONFIG.FontBold
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextSize = 14
	closeBtn.AutoButtonColor = false
	closeBtn.ZIndex = 5003
	createUICorner(4).Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		overlay:Destroy()
	end)

	-- Content scroll
	local contentScroll = Instance.new("ScrollingFrame")
	contentScroll.Parent = resultsWindow
	contentScroll.Position = UDim2.new(0, 8, 0, 43)
	contentScroll.Size = UDim2.new(1, -16, 1, -51)
	contentScroll.BackgroundColor3 = CONFIG.Colors.Button
	contentScroll.BorderSizePixel = 0
	contentScroll.ScrollBarThickness = 6
	contentScroll.ScrollBarImageColor3 = CONFIG.Colors.Border
	contentScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	contentScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	contentScroll.ZIndex = 5002
	createUICorner(6).Parent = contentScroll

	local contentText = Instance.new("TextLabel")
	contentText.Parent = contentScroll
	contentText.Position = UDim2.new(0, 10, 0, 10)
	contentText.Size = UDim2.new(1, -20, 0, 0)
	contentText.BackgroundTransparency = 1
	contentText.Font = Enum.Font.Code
	contentText.Text = content
	contentText.TextColor3 = CONFIG.Colors.Text
	contentText.TextSize = 12
	contentText.TextXAlignment = Enum.TextXAlignment.Left
	contentText.TextYAlignment = Enum.TextYAlignment.Top
	contentText.TextWrapped = true
	contentText.AutomaticSize = Enum.AutomaticSize.Y
	contentText.RichText = true
	contentText.ZIndex = 5003

	-- Copy button
	local copyBtn = Instance.new("TextButton")
	copyBtn.Parent = resultsWindow
	copyBtn.Position = UDim2.new(1, -110, 0, 5)
	copyBtn.Size = UDim2.new(0, 75, 0, 25)
	copyBtn.BackgroundColor3 = CONFIG.Colors.AccentGreen
	copyBtn.BorderSizePixel = 0
	copyBtn.Font = CONFIG.FontBold
	copyBtn.Text = "COPY"
	copyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	copyBtn.TextSize = 11
	copyBtn.AutoButtonColor = false
	copyBtn.ZIndex = 5003
	createUICorner(4).Parent = copyBtn

	copyBtn.MouseButton1Click:Connect(function()
		local plainText = content:gsub("<[^>]+>", "") -- Remove rich text tags
		if copyToClipboard(plainText) then
			copyBtn.Text = "COPIED!"
			copyBtn.BackgroundColor3 = CONFIG.Colors.AccentBlue
			task.wait(1)
			copyBtn.Text = "COPY"
			copyBtn.BackgroundColor3 = CONFIG.Colors.AccentGreen
		end
	end)

	return overlay
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
		{name = "Chat", icon = "C"},
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
	-- Remotes tab header
	local remotesHeader = Instance.new("Frame")
	remotesHeader.Name = "RemotesHeader"
	remotesHeader.Parent = mainFrame
	remotesHeader.Position = UDim2.new(0, CONFIG.SidebarWidth + 11, 0, 46)
	remotesHeader.Size = UDim2.new(1, -(CONFIG.SidebarWidth + 21), 0, 40)
	remotesHeader.BackgroundColor3 = CONFIG.Colors.TopBar
	remotesHeader.BorderSizePixel = 0
	remotesHeader.Visible = false
	createUICorner(4).Parent = remotesHeader

	local remotesTitle = Instance.new("TextLabel")
	remotesTitle.Parent = remotesHeader
	remotesTitle.Position = UDim2.new(0, 10, 0, 0)
	remotesTitle.Size = UDim2.new(0, 300, 1, 0)
	remotesTitle.BackgroundTransparency = 1
	remotesTitle.Font = CONFIG.FontBold
	remotesTitle.Text = "Remote Spy"
	remotesTitle.TextColor3 = CONFIG.Colors.Text
	remotesTitle.TextSize = 14
	remotesTitle.TextXAlignment = Enum.TextXAlignment.Left

	local remotesStatus = Instance.new("TextLabel")
	remotesStatus.Name = "RemotesStatus"
	remotesStatus.Parent = remotesHeader
	remotesStatus.Position = UDim2.new(0, 120, 0, 0)
	remotesStatus.Size = UDim2.new(1, -250, 1, 0)
	remotesStatus.BackgroundTransparency = 1
	remotesStatus.Font = CONFIG.Font
	remotesStatus.Text = "Initializing..."
	remotesStatus.TextColor3 = CONFIG.Colors.TextDim
	remotesStatus.TextSize = 11
	remotesStatus.TextXAlignment = Enum.TextXAlignment.Left

	local refreshRemotesBtn = Instance.new("TextButton")
	refreshRemotesBtn.Name = "RefreshRemotesBtn"
	refreshRemotesBtn.Parent = remotesHeader
	refreshRemotesBtn.Position = UDim2.new(1, -110, 0.5, -15)
	refreshRemotesBtn.Size = UDim2.new(0, 100, 0, 30)
	refreshRemotesBtn.BackgroundColor3 = CONFIG.Colors.AccentBlue
	refreshRemotesBtn.BorderSizePixel = 0
	refreshRemotesBtn.Font = CONFIG.FontBold
	refreshRemotesBtn.Text = "REFRESH"
	refreshRemotesBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	refreshRemotesBtn.TextSize = 12
	refreshRemotesBtn.AutoButtonColor = false
	createUICorner(4).Parent = refreshRemotesBtn

	local remotesFrame = Instance.new("ScrollingFrame")
	remotesFrame.Name = "RemotesFrame"
	remotesFrame.Parent = mainFrame
	remotesFrame.Position = UDim2.new(0, CONFIG.SidebarWidth + 11, 0, 96)
	remotesFrame.Size = UDim2.new(1, -(CONFIG.SidebarWidth + 21), 1, -106)
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

	-- Chat Frame
	local chatFrame = Instance.new("Frame")
	chatFrame.Name = "ChatFrame"
	chatFrame.Parent = mainFrame
	chatFrame.Position = UDim2.new(0, CONFIG.SidebarWidth + 11, 0, 46)
	chatFrame.Size = UDim2.new(1, -(CONFIG.SidebarWidth + 21), 1, -56)
	chatFrame.BackgroundColor3 = CONFIG.Colors.Background
	chatFrame.BorderSizePixel = 0
	chatFrame.Visible = false

	-- Chat messages scroll
	local chatScroll = Instance.new("ScrollingFrame")
	chatScroll.Name = "ChatScroll"
	chatScroll.Parent = chatFrame
	chatScroll.Position = UDim2.new(0, 5, 0, 5)
	chatScroll.Size = UDim2.new(1, -10, 1, -50)
	chatScroll.BackgroundColor3 = CONFIG.Colors.Button
	chatScroll.BorderSizePixel = 0
	chatScroll.ScrollBarThickness = 6
	chatScroll.ScrollBarImageColor3 = CONFIG.Colors.Border
	chatScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	chatScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	createUICorner(6).Parent = chatScroll

	local chatLayout = Instance.new("UIListLayout")
	chatLayout.Parent = chatScroll
	chatLayout.SortOrder = Enum.SortOrder.LayoutOrder
	chatLayout.Padding = UDim.new(0, 3)

	-- Chat input box
	local chatInputBox = Instance.new("TextBox")
	chatInputBox.Name = "ChatInputBox"
	chatInputBox.Parent = chatFrame
	chatInputBox.Position = UDim2.new(0, 5, 1, -40)
	chatInputBox.Size = UDim2.new(1, -95, 0, 35)
	chatInputBox.BackgroundColor3 = CONFIG.Colors.Button
	chatInputBox.BorderSizePixel = 0
	chatInputBox.Font = CONFIG.Font
	chatInputBox.PlaceholderText = "Type message... (Enter to send)"
	chatInputBox.Text = ""
	chatInputBox.TextColor3 = CONFIG.Colors.Text
	chatInputBox.PlaceholderColor3 = CONFIG.Colors.TextDim
	chatInputBox.TextSize = 13
	chatInputBox.TextXAlignment = Enum.TextXAlignment.Left
	chatInputBox.ClearTextOnFocus = false
	createUICorner(4).Parent = chatInputBox

	local chatPadding = Instance.new("UIPadding")
	chatPadding.Parent = chatInputBox
	chatPadding.PaddingLeft = UDim.new(0, 8)

	-- Send button
	local sendBtn = Instance.new("TextButton")
	sendBtn.Name = "SendButton"
	sendBtn.Parent = chatFrame
	sendBtn.Position = UDim2.new(1, -85, 1, -40)
	sendBtn.Size = UDim2.new(0, 80, 0, 35)
	sendBtn.BackgroundColor3 = CONFIG.Colors.AccentGreen
	sendBtn.BorderSizePixel = 0
	sendBtn.Font = CONFIG.FontBold
	sendBtn.Text = "SEND"
	sendBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	sendBtn.TextSize = 13
	sendBtn.AutoButtonColor = false
	createUICorner(4).Parent = sendBtn

	return screenGui, mainFrame, contentFrame, freezeBtn, refreshBtn, minimizeBtn, closeBtn, statusLabel, searchBox, clearSearchBtn, tabButtons, toolbar, remotesFrame, toolsFrame, settingsFrame, remotesHeader, remotesStatus, refreshRemotesBtn, chatFrame, chatScroll, chatInputBox, sendBtn
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

local function createGuiEntry(parent, obj, depth, onRefresh, screenGui)
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

		-- Create GUI preview window instead of just a menu
		local previewWindow = Instance.new("Frame")
		previewWindow.Name = "PreviewWindow"
		previewWindow.Parent = screenGui
		previewWindow.Position = UDim2.new(0.5, -200, 0.5, -250)
		previewWindow.Size = UDim2.new(0, 400, 0, 500)
		previewWindow.BackgroundColor3 = CONFIG.Colors.Background
		previewWindow.BorderSizePixel = 1
		previewWindow.BorderColor3 = CONFIG.Colors.Border
		previewWindow.ZIndex = 10000
		createUICorner(8).Parent = previewWindow

		-- Store reference to preview window
		moreMenu = previewWindow

		-- Preview window title bar
		local previewTitleBar = Instance.new("Frame")
		previewTitleBar.Parent = previewWindow
		previewTitleBar.Size = UDim2.new(1, 0, 0, 30)
		previewTitleBar.BackgroundColor3 = CONFIG.Colors.TopBar
		previewTitleBar.BorderSizePixel = 0
		previewTitleBar.ZIndex = 10001
		createUICorner(8).Parent = previewTitleBar

		local previewTitle = Instance.new("TextLabel")
		previewTitle.Parent = previewTitleBar
		previewTitle.Position = UDim2.new(0, 10, 0, 0)
		previewTitle.Size = UDim2.new(1, -40, 1, 0)
		previewTitle.BackgroundTransparency = 1
		previewTitle.Font = CONFIG.FontBold
		previewTitle.Text = "GUI Preview: " .. obj.Name
		previewTitle.TextColor3 = CONFIG.Colors.Text
		previewTitle.TextSize = 13
		previewTitle.TextXAlignment = Enum.TextXAlignment.Left
		previewTitle.TextTruncate = Enum.TextTruncate.AtEnd
		previewTitle.ZIndex = 10002

		-- Close button for preview
		local previewCloseBtn = Instance.new("TextButton")
		previewCloseBtn.Parent = previewTitleBar
		previewCloseBtn.Position = UDim2.new(1, -25, 0.5, -12)
		previewCloseBtn.Size = UDim2.new(0, 24, 0, 24)
		previewCloseBtn.BackgroundColor3 = CONFIG.Colors.AccentRed
		previewCloseBtn.BorderSizePixel = 0
		previewCloseBtn.Font = CONFIG.FontBold
		previewCloseBtn.Text = "X"
		previewCloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		previewCloseBtn.TextSize = 14
		previewCloseBtn.AutoButtonColor = false
		previewCloseBtn.ZIndex = 10003
		createUICorner(3).Parent = previewCloseBtn

		previewCloseBtn.MouseEnter:Connect(function()
			previewCloseBtn.BackgroundColor3 = Color3.fromRGB(200, 80, 80)
		end)
		previewCloseBtn.MouseLeave:Connect(function()
			previewCloseBtn.BackgroundColor3 = CONFIG.Colors.AccentRed
		end)

		previewCloseBtn.MouseButton1Click:Connect(function()
			if moreMenu then
				moreMenu:Destroy()
				moreMenu = nil
			end
		end)

		-- Preview content scroll
		local previewScroll = Instance.new("ScrollingFrame")
		previewScroll.Parent = previewWindow
		previewScroll.Position = UDim2.new(0, 5, 0, 35)
		previewScroll.Size = UDim2.new(1, -10, 1, -40)
		previewScroll.BackgroundColor3 = CONFIG.Colors.Button
		previewScroll.BorderSizePixel = 0
		previewScroll.ScrollBarThickness = 6
		previewScroll.ScrollBarImageColor3 = CONFIG.Colors.Border
		previewScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		previewScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		previewScroll.ZIndex = 10001
		createUICorner(6).Parent = previewScroll

		local previewLayout = Instance.new("UIListLayout")
		previewLayout.Parent = previewScroll
		previewLayout.SortOrder = Enum.SortOrder.LayoutOrder
		previewLayout.Padding = UDim.new(0, 5)

		local previewPadding = Instance.new("UIPadding")
		previewPadding.Parent = previewScroll
		previewPadding.PaddingTop = UDim.new(0, 8)
		previewPadding.PaddingBottom = UDim.new(0, 8)
		previewPadding.PaddingLeft = UDim.new(0, 8)
		previewPadding.PaddingRight = UDim.new(0, 8)

		-- Add GUI properties to preview
		local propertiesToShow = {"Name", "ClassName", "Visible", "Position", "Size", "BackgroundColor3", "BackgroundTransparency", "ZIndex", "Parent"}

		for i, propName in ipairs(propertiesToShow) do
			local success, value = pcall(function() return obj[propName] end)
			if success then
				local propFrame = Instance.new("Frame")
				propFrame.Parent = previewScroll
				propFrame.Size = UDim2.new(1, -5, 0, 40)
				propFrame.BackgroundColor3 = CONFIG.Colors.Background
				propFrame.BorderSizePixel = 0
				propFrame.LayoutOrder = i
				propFrame.ZIndex = 10002
				createUICorner(4).Parent = propFrame

				local propLabel = Instance.new("TextLabel")
				propLabel.Parent = propFrame
				propLabel.Position = UDim2.new(0, 8, 0, 5)
				propLabel.Size = UDim2.new(1, -16, 0, 15)
				propLabel.BackgroundTransparency = 1
				propLabel.Font = CONFIG.FontBold
				propLabel.Text = propName
				propLabel.TextColor3 = CONFIG.Colors.AccentBlue
				propLabel.TextSize = 11
				propLabel.TextXAlignment = Enum.TextXAlignment.Left
				propLabel.ZIndex = 10003

				local valueLabel = Instance.new("TextLabel")
				valueLabel.Parent = propFrame
				valueLabel.Position = UDim2.new(0, 8, 0, 20)
				valueLabel.Size = UDim2.new(1, -16, 0, 15)
				valueLabel.BackgroundTransparency = 1
				valueLabel.Font = CONFIG.Font
				valueLabel.Text = formatValue(value)
				valueLabel.TextColor3 = CONFIG.Colors.Text
				valueLabel.TextSize = 10
				valueLabel.TextXAlignment = Enum.TextXAlignment.Left
				valueLabel.TextTruncate = Enum.TextTruncate.AtEnd
				valueLabel.ZIndex = 10003
			end
		end

		-- Action buttons section
		local actionsFrame = Instance.new("Frame")
		actionsFrame.Parent = previewScroll
		actionsFrame.Size = UDim2.new(1, -5, 0, 0)
		actionsFrame.BackgroundColor3 = CONFIG.Colors.TopBar
		actionsFrame.BorderSizePixel = 0
		actionsFrame.AutomaticSize = Enum.AutomaticSize.Y
		actionsFrame.LayoutOrder = 1000
		actionsFrame.ZIndex = 10002
		createUICorner(4).Parent = actionsFrame

		local menuLayout = Instance.new("UIListLayout")
		menuLayout.Parent = actionsFrame
		menuLayout.SortOrder = Enum.SortOrder.LayoutOrder
		menuLayout.Padding = UDim.new(0, 2)

		local menuPadding = Instance.new("UIPadding")
		menuPadding.Parent = actionsFrame
		menuPadding.PaddingTop = UDim.new(0, 5)
		menuPadding.PaddingBottom = UDim.new(0, 5)
		menuPadding.PaddingLeft = UDim.new(0, 5)
		menuPadding.PaddingRight = UDim.new(0, 5)

		local menuOptions = {
			{text = "📋 Copy Path", callback = function()
				local path = getFullPath(obj)
				if copyToClipboard(path) then
					createResultsWindow("Copied!", "Path copied to clipboard:\n\n" .. path, screenGui)
				end
			end},
			{text = "📄 Copy Name", callback = function()
				if copyToClipboard(obj.Name) then
					createResultsWindow("Copied!", "Name copied to clipboard:\n\n" .. obj.Name, screenGui)
				end
			end},
			{text = "🔍 All Properties", callback = function()
				local results = "<b>ALL PROPERTIES</b>\n\n<b>" .. obj:GetFullName() .. "</b>\n\n"
				local props = {}
				for _, prop in ipairs({"Name", "ClassName", "Parent", "Visible", "Position", "Size", "AnchorPoint", "BackgroundColor3", "BackgroundTransparency", "BorderColor3", "BorderSizePixel", "LayoutOrder", "ZIndex", "Rotation", "Transparency", "TextColor3", "TextSize", "Font", "Text", "Image", "ImageColor3"}) do
					local success, value = pcall(function() return obj[prop] end)
					if success then
						results = results .. string.format('<font color="#5AA3E0">%s:</font> %s\n', prop, formatValue(value))
					end
				end
				createResultsWindow("Object Properties", results, screenGui)
			end},
			{text = "👥 Get Children", callback = function()
				local children = obj:GetChildren()
				local results = "<b>CHILDREN</b>\n\n<b>" .. obj:GetFullName() .. "</b>\n\n"
				results = results .. string.format('<b>Total: %d children</b>\n\n', #children)
				for i, child in ipairs(children) do
					if i <= 100 then
						results = results .. string.format('<font color="#5AA3E0">%s</font>: %s\n', child.ClassName, child.Name)
					end
				end
				if #children > 100 then
					results = results .. string.format('\n... and %d more', #children - 100)
				end
				createResultsWindow("Children List", results, screenGui)
			end},
			{text = "🌳 Get Descendants", callback = function()
				local descendants = obj:GetDescendants()
				local results = "<b>DESCENDANTS</b>\n\n<b>" .. obj:GetFullName() .. "</b>\n\n"
				results = results .. string.format('<b>Total: %d descendants</b>\n\n', #descendants)

				local byClass = {}
				for _, desc in ipairs(descendants) do
					byClass[desc.ClassName] = (byClass[desc.ClassName] or 0) + 1
				end

				results = results .. '<b>By Type:</b>\n'
				for className, count in pairs(byClass) do
					results = results .. string.format('<font color="#50B464">%s:</font> %d\n', className, count)
				end
				createResultsWindow("Descendants Tree", results, screenGui)
			end},
			{text = "🔗 Find Scripts", callback = function()
				local scripts = {}
				for _, desc in ipairs(obj:GetDescendants()) do
					if desc:IsA("LocalScript") or desc:IsA("Script") or desc:IsA("ModuleScript") then
						table.insert(scripts, desc)
					end
				end
				local results = "<b>SCRIPTS IN OBJECT</b>\n\n<b>" .. obj:GetFullName() .. "</b>\n\n"
				results = results .. string.format('<b>Found: %d scripts</b>\n\n', #scripts)
				for i, script in ipairs(scripts) do
					if i <= 50 then
						results = results .. string.format('<font color="#C8B450">%s:</font> %s\n', script.ClassName, script:GetFullName())
					end
				end
				if #scripts > 50 then
					results = results .. string.format('\n... and %d more', #scripts - 50)
				end
				createResultsWindow("Scripts Found", results, screenGui)
			end},
			{text = "📦 Clone Object", callback = function()
				local success, clone = pcall(function()
					return obj:Clone()
				end)
				if success and clone then
					clone.Parent = obj.Parent
					createResultsWindow("Cloned!", string.format("Successfully cloned:\n\n<b>%s</b>\n\nClone placed in same parent", obj.Name), screenGui)
					if onRefresh then onRefresh() end
				else
					createResultsWindow("Clone Failed", string.format("Failed to clone:\n\n<b>%s</b>", obj.Name), screenGui)
				end
			end},
			{text = "🗑️ Destroy Object", callback = function()
				local name = obj:GetFullName()
				obj:Destroy()
				createResultsWindow("Destroyed", string.format("Object destroyed:\n\n<b>%s</b>", name), screenGui)
				if onRefresh then onRefresh() end
				if moreMenu then
					moreMenu:Destroy()
					moreMenu = nil
				end
			end},
		}

		for i, option in ipairs(menuOptions) do
			local optionBtn = Instance.new("TextButton")
			optionBtn.Name = option.text
			optionBtn.Parent = actionsFrame
			optionBtn.Size = UDim2.new(1, 0, 0, 30)
			optionBtn.BackgroundColor3 = CONFIG.Colors.Button
			optionBtn.BorderSizePixel = 0
			optionBtn.Font = CONFIG.Font
			optionBtn.Text = option.text
			optionBtn.TextColor3 = CONFIG.Colors.Text
			optionBtn.TextSize = 12
			optionBtn.TextXAlignment = Enum.TextXAlignment.Left
			optionBtn.AutoButtonColor = false
			optionBtn.LayoutOrder = i
			optionBtn.ZIndex = 10003
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
						local childEntry = createGuiEntry(childContainer, child, depth + 1, onRefresh, screenGui)
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

local function scanAndDisplayGuis(contentFrame, statusLabel, screenGui)
	-- Clear existing content
	for _, child in ipairs(contentFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	State.expanded = {}

	local guiList = {}
	screenGui = screenGui or contentFrame:FindFirstAncestorOfClass("ScreenGui")

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
			scanAndDisplayGuis(contentFrame, statusLabel, screenGui)
		end, screenGui)
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

	-- Try to hook RemoteEvent/RemoteFunction calls
	local hookSuccess = false
	local hookError = nil

	-- Method 1: Try hookmetamethod
	if hookmetamethod and getnamecallmethod then
		local success, err = pcall(function()
			local oldNamecall
			oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
				local method = getnamecallmethod()
				local args = {...}

				if method == "FireServer" or method == "InvokeServer" then
					if self:IsA("RemoteEvent") or self:IsA("RemoteFunction") then
						local logEntry = {
							time = os.date("%H:%M:%S"),
							remote = self:GetFullName(),
							type = self.ClassName,
							method = method,
							args = args
						}
						table.insert(State.remoteLogs, 1, logEntry) -- Insert at beginning for newest first

						-- Only print if debug output is enabled
						if State.debugOutput then
							print("[REMOTE SPY]", method, "->", self:GetFullName())
						end
					end
				end

				return oldNamecall(self, ...)
			end)
		end)

		if success then
			hookSuccess = true
			print("[REMOTE SPY] Successfully hooked via hookmetamethod")
		else
			hookError = tostring(err)
			print("[REMOTE SPY] hookmetamethod failed:", err)
		end
	end

	-- Method 2: Fallback - scan for existing remotes
	if not hookSuccess then
		print("[REMOTE SPY] Using passive scanning mode")
		-- Add a note that we're in passive mode
		table.insert(State.remoteLogs, {
			time = os.date("%H:%M:%S"),
			remote = "SYSTEM",
			type = "INFO",
			method = "Passive Mode",
			args = {"Remote spy is in passive mode - use 'Scan All Remotes' in Tools tab"}
		})
	end

	return hookSuccess, hookError
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

local function populateToolsTab(toolsFrame, screenGui)
	local tools = {
		{
			name = "Scan All Remotes",
			desc = "Find all RemoteEvents and RemoteFunctions",
			color = CONFIG.Colors.AccentBlue,
			callback = function()
				local results = "<b>SCANNING REMOTES</b>\n\n"
				local count = 0
				for _, desc in ipairs(game:GetDescendants()) do
					if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") then
						results = results .. string.format('<font color="#5AA3E0">%s</font> → %s\n', desc.ClassName, desc:GetFullName())
						count = count + 1
					end
				end
				results = results .. string.format('\n<b><font color="#50B464">Total found: %d</font></b>', count)
				createResultsWindow("Remote Scanner Results", results, screenGui)
			end
		},
		{
			name = "List All Scripts",
			desc = "Find all LocalScripts and Scripts",
			color = CONFIG.Colors.AccentYellow,
			callback = function()
				local results = "<b>SCANNING SCRIPTS</b>\n\n"
				local locals = {}
				local servers = {}
				local modules = {}
				for _, desc in ipairs(game:GetDescendants()) do
					if desc:IsA("LocalScript") then
						table.insert(locals, desc)
					elseif desc:IsA("Script") then
						table.insert(servers, desc)
					elseif desc:IsA("ModuleScript") then
						table.insert(modules, desc)
					end
				end
				results = results .. string.format('<b><font color="#C8B450">LocalScripts: %d</font></b>\n', #locals)
				for i, script in ipairs(locals) do
					if i <= 50 then
						results = results .. string.format('  → %s\n', script:GetFullName())
					end
				end
				if #locals > 50 then results = results .. string.format('  ... and %d more\n', #locals - 50) end

				results = results .. string.format('\n<b><font color="#5AA3E0">Scripts: %d</font></b>\n', #servers)
				for i, script in ipairs(servers) do
					if i <= 50 then
						results = results .. string.format('  → %s\n', script:GetFullName())
					end
				end
				if #servers > 50 then results = results .. string.format('  ... and %d more\n', #servers - 50) end

				results = results .. string.format('\n<b><font color="#9664C8">ModuleScripts: %d</font></b>\n', #modules)
				for i, script in ipairs(modules) do
					if i <= 50 then
						results = results .. string.format('  → %s\n', script:GetFullName())
					end
				end
				if #modules > 50 then results = results .. string.format('  ... and %d more\n', #modules - 50) end

				results = results .. string.format('\n<b>Total: %d scripts</b>', #locals + #servers + #modules)
				createResultsWindow("Script Scanner Results", results, screenGui)
			end
		},
		{
			name = "Dump Game Tree",
			desc = "Show game hierarchy tree structure",
			color = CONFIG.Colors.AccentPurple,
			callback = function()
				local results = "<b>GAME TREE HIERARCHY</b>\n\n"
				local function buildTree(obj, depth)
					if depth > 6 then return "" end
					local tree = string.rep("  ", depth) .. obj.ClassName .. ": <b>" .. obj.Name .. "</b>\n"
					for i, child in ipairs(obj:GetChildren()) do
						if i <= 20 or depth < 2 then
							tree = tree .. buildTree(child, depth + 1)
						elseif i == 21 then
							tree = tree .. string.rep("  ", depth + 1) .. "... and " .. (#obj:GetChildren() - 20) .. " more children\n"
							break
						end
					end
					return tree
				end
				results = results .. buildTree(game, 0)
				createResultsWindow("Game Tree Structure", results, screenGui)
			end
		},
		{
			name = "Memory Stats",
			desc = "Show detailed memory and performance statistics",
			color = CONFIG.Colors.AccentRed,
			callback = function()
				local stats = game:GetService("Stats")
				local results = "<b>MEMORY & PERFORMANCE STATS</b>\n\n"

				results = results .. "<b><font color=\"#50B464\">Memory:</font></b>\n"
				pcall(function()
					results = results .. string.format("  Total Memory: %.2f MB\n", stats:GetTotalMemoryUsageMb())
				end)

				results = results .. "\n<b><font color=\"#5AA3E0\">Performance:</font></b>\n"
				results = results .. string.format("  FPS: %.1f\n", 1 / game:GetService("RunService").RenderStepped:Wait())
				results = results .. string.format("  Ping: %d ms\n", game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())

				results = results .. "\n<b><font color=\"#C8B450\">Instances:</font></b>\n"
				results = results .. string.format("  Total in game: %d\n", #game:GetDescendants())
				results = results .. string.format("  In Workspace: %d\n", #game:GetService("Workspace"):GetDescendants())
				results = results .. string.format("  In PlayerGui: %d\n", #LocalPlayer.PlayerGui:GetDescendants())

				createResultsWindow("Memory & Performance Stats", results, screenGui)
			end
		},
		{
			name = "Explore Services",
			desc = "Browse all game services and their contents",
			color = CONFIG.Colors.AccentGreen,
			callback = function()
				local results = "<b>GAME SERVICES EXPLORER</b>\n\n"
				local services = {
					"Workspace", "Players", "Lighting", "ReplicatedStorage", "ReplicatedFirst",
					"ServerStorage", "ServerScriptService", "StarterGui", "StarterPack", "StarterPlayer",
					"Teams", "SoundService", "Chat", "LocalizationService", "TestService"
				}
				for _, serviceName in ipairs(services) do
					local success, service = pcall(function() return game:GetService(serviceName) end)
					if success and service then
						results = results .. string.format('<b><font color="#5AA3E0">%s</font></b> (%d children)\n', serviceName, #service:GetChildren())
						for i, child in ipairs(service:GetChildren()) do
							if i <= 15 then
								results = results .. string.format('  • %s: <i>%s</i>\n', child.ClassName, child.Name)
							end
						end
						if #service:GetChildren() > 15 then
							results = results .. string.format('  ... and %d more\n', #service:GetChildren() - 15)
						end
						results = results .. '\n'
					end
				end
				createResultsWindow("Services Explorer", results, screenGui)
			end
		},
		{
			name = "Find BindableEvents",
			desc = "Locate all BindableEvents and BindableFunctions",
			color = CONFIG.Colors.AccentPurple,
			callback = function()
				local results = "<b>BINDABLE EVENTS SCAN</b>\n\n"
				local events = {}
				local functions = {}
				for _, desc in ipairs(game:GetDescendants()) do
					if desc:IsA("BindableEvent") then
						table.insert(events, desc)
					elseif desc:IsA("BindableFunction") then
						table.insert(functions, desc)
					end
				end
				results = results .. string.format('<b><font color="#50B464">BindableEvents: %d</font></b>\n', #events)
				for i, event in ipairs(events) do
					if i <= 50 then
						results = results .. string.format('  → %s\n', event:GetFullName())
					end
				end
				if #events > 50 then results = results .. string.format('  ... and %d more\n', #events - 50) end

				results = results .. string.format('\n<b><font color="#5AA3E0">BindableFunctions: %d</font></b>\n', #functions)
				for i, func in ipairs(functions) do
					if i <= 50 then
						results = results .. string.format('  → %s\n', func:GetFullName())
					end
				end
				if #functions > 50 then results = results .. string.format('  ... and %d more\n', #functions - 50) end

				results = results .. string.format('\n<b>Total: %d bindables</b>', #events + #functions)
				createResultsWindow("Bindable Events Results", results, screenGui)
			end
		},
		{
			name = "Workspace Inspector",
			desc = "Analyze workspace models and parts",
			color = CONFIG.Colors.AccentYellow,
			callback = function()
				local workspace = game:GetService("Workspace")
				local results = "<b>WORKSPACE INSPECTOR</b>\n\n"

				results = results .. string.format('<b><font color="#50B464">General Info:</font></b>\n')
				results = results .. string.format('  Camera: %s\n', tostring(workspace.CurrentCamera))
				results = results .. string.format('  Gravity: %.1f\n', workspace.Gravity)
				results = results .. string.format('  Total Descendants: %d\n', #workspace:GetDescendants())

				local models = {}
				local parts = 0
				local meshes = 0
				for _, obj in ipairs(workspace:GetDescendants()) do
					if obj:IsA("Model") and obj.Parent == workspace then
						table.insert(models, obj)
					elseif obj:IsA("BasePart") then
						parts = parts + 1
					elseif obj:IsA("MeshPart") or obj:IsA("SpecialMesh") then
						meshes = meshes + 1
					end
				end

				results = results .. string.format('\n<b><font color="#5AA3E0">Content:</font></b>\n')
				results = results .. string.format('  Parts: %d\n', parts)
				results = results .. string.format('  Meshes: %d\n', meshes)
				results = results .. string.format('  Top-level Models: %d\n\n', #models)

				results = results .. '<b><font color="#C8B450">Models:</font></b>\n'
				for i, model in ipairs(models) do
					if i <= 30 then
						local primary = model.PrimaryPart and model.PrimaryPart.Name or "none"
						results = results .. string.format('  • %s (Primary: %s, Children: %d)\n', model.Name, primary, #model:GetChildren())
					end
				end
				if #models > 30 then results = results .. string.format('  ... and %d more models\n', #models - 30) end

				createResultsWindow("Workspace Inspector", results, screenGui)
			end
		},
		{
			name = "Decompile Scripts",
			desc = "Attempt to decompile all scripts (requires decompile)",
			color = CONFIG.Colors.AccentPurple,
			callback = function()
				local results = "<b>SCRIPT DECOMPILER</b>\n\n"
				if decompile then
					local success_count = 0
					local failed_count = 0
					local scripts = {}

					for _, desc in ipairs(game:GetDescendants()) do
						if desc:IsA("LocalScript") or desc:IsA("Script") or desc:IsA("ModuleScript") then
							table.insert(scripts, desc)
						end
					end

					results = results .. string.format('Found %d scripts to decompile...\n\n', #scripts)

					for i, desc in ipairs(scripts) do
						if i <= 20 then
							local success, source = pcall(function()
								return decompile(desc)
							end)
							if success and source then
								results = results .. string.format('<font color="#50B464">✓</font> %s\n  <i>Size: %d chars</i>\n', desc:GetFullName(), #source)
								success_count = success_count + 1
							else
								results = results .. string.format('<font color="#B45050">✗</font> %s\n  <i>Failed to decompile</i>\n', desc:GetFullName())
								failed_count = failed_count + 1
							end
						else
							local success, source = pcall(function()
								return decompile(desc)
							end)
							if success and source then
								success_count = success_count + 1
							else
								failed_count = failed_count + 1
							end
						end
					end

					if #scripts > 20 then
						results = results .. string.format('\n... and %d more scripts\n', #scripts - 20)
					end

					results = results .. string.format('\n<b>Results:</b>\n')
					results = results .. string.format('<font color="#50B464">  Success: %d</font>\n', success_count)
					results = results .. string.format('<font color="#B45050">  Failed: %d</font>\n', failed_count)
				else
					results = results .. '<font color="#B45050">decompile() function not available</font>\n\n'
					results = results .. 'This feature requires an executor with decompile() support.'
				end
				createResultsWindow("Decompiler Results", results, screenGui)
			end
		},
		{
			name = "Find Hidden GUIs",
			desc = "Locate all invisible or hidden GUI elements",
			color = CONFIG.Colors.AccentRed,
			callback = function()
				local results = "<b>HIDDEN GUI SCANNER</b>\n\n"
				local hidden = {}
				for _, desc in ipairs(game:GetDescendants()) do
					if desc:IsA("GuiObject") then
						local isHidden = false
						if not desc.Visible then
							isHidden = true
						end
						local parent = desc.Parent
						while parent and parent ~= game do
							if parent:IsA("ScreenGui") and not parent.Enabled then
								isHidden = true
								break
							end
							if parent:IsA("GuiObject") and not parent.Visible then
								isHidden = true
								break
							end
							parent = parent.Parent
						end
						if isHidden then
							table.insert(hidden, desc)
						end
					end
				end

				results = results .. string.format('<b><font color="#C8B450">Found %d hidden GUIs</font></b>\n\n', #hidden)
				for i, obj in ipairs(hidden) do
					if i <= 100 then
						local reason = not obj.Visible and "Visible=false" or "Parent hidden"
						results = results .. string.format('%s → %s\n  <i>(%s)</i>\n', obj.ClassName, obj:GetFullName(), reason)
					end
				end
				if #hidden > 100 then
					results = results .. string.format('\n... and %d more hidden GUIs', #hidden - 100)
				end

				createResultsWindow("Hidden GUIs", results, screenGui)
			end
		},
		{
			name = "Scan ValueBase Objects",
			desc = "Find all Value objects (StringValue, IntValue, etc.)",
			color = CONFIG.Colors.AccentGreen,
			callback = function()
				local results = "<b>VALUE OBJECTS SCANNER</b>\n\n"
				local values = {}
				local total = 0
				for _, desc in ipairs(game:GetDescendants()) do
					if desc:IsA("ValueBase") then
						local valType = desc.ClassName
						values[valType] = values[valType] or {}
						table.insert(values[valType], desc)
						total = total + 1
					end
				end

				results = results .. string.format('<b>Total Value Objects: %d</b>\n\n', total)

				for valType, list in pairs(values) do
					results = results .. string.format('<b><font color="#5AA3E0">%s</font></b> (%d)\n', valType, #list)
					for i, obj in ipairs(list) do
						if i <= 15 then
							local success, val = pcall(function() return obj.Value end)
							if success then
								results = results .. string.format('  → %s = <font color="#50B464">%s</font>\n', obj:GetFullName(), tostring(val))
							else
								results = results .. string.format('  → %s\n', obj:GetFullName())
							end
						end
					end
					if #list > 15 then
						results = results .. string.format('  ... and %d more\n', #list - 15)
					end
					results = results .. '\n'
				end
				createResultsWindow("Value Objects", results, screenGui)
			end
		},
		{
			name = "Get Game Stats",
			desc = "Show detailed game statistics and info",
			color = CONFIG.Colors.AccentBlue,
			callback = function()
				local results = "<b>GAME STATISTICS</b>\n\n"

				results = results .. '<b><font color="#5AA3E0">Game Info:</font></b>\n'
				results = results .. string.format('  Game ID: %d\n', game.GameId)
				results = results .. string.format('  Place ID: %d\n', game.PlaceId)
				results = results .. string.format('  Creator: %s (ID: %d)\n', game.CreatorType, game.CreatorId)
				results = results .. string.format('  Job ID: %s\n', game.JobId)

				local players = game:GetService("Players"):GetPlayers()
				results = results .. string.format('\n<b><font color="#50B464">Players:</font></b> %d\n', #players)
				for i, player in ipairs(players) do
					if i <= 20 then
						results = results .. string.format('  • %s (ID: %d)\n', player.Name, player.UserId)
					end
				end
				if #players > 20 then
					results = results .. string.format('  ... and %d more\n', #players - 20)
				end

				results = results .. string.format('\n<b><font color="#C8B450">Instance Count:</font></b>\n')
				results = results .. string.format('  Total in game: %d\n', #game:GetDescendants())
				results = results .. string.format('  Workspace: %d\n', #game:GetService("Workspace"):GetChildren())

				local services = {"ReplicatedStorage", "ReplicatedFirst", "ServerScriptService", "StarterPlayer", "StarterPack", "StarterGui", "Lighting"}
				results = results .. '\n<b>Services:</b>\n'
				for _, serviceName in ipairs(services) do
					local success, service = pcall(function() return game:GetService(serviceName) end)
					if success then
						results = results .. string.format('  %s: %d children\n', serviceName, #service:GetChildren())
					end
				end
				createResultsWindow("Game Statistics", results, screenGui)
			end
		},
		{
			name = "Find All Assets",
			desc = "Scan for all asset references (Images, Sounds, etc.)",
			color = CONFIG.Colors.AccentYellow,
			callback = function()
				local results = "<b>ASSET SCANNER</b>\n\n"
				local assets = {}
				for _, desc in ipairs(game:GetDescendants()) do
					for _, prop in ipairs({"Image", "Texture", "SoundId", "MeshId", "VideoId"}) do
						local success, value = pcall(function() return desc[prop] end)
						if success and type(value) == "string" and value ~= "" then
							if not assets[value] then
								assets[value] = {count = 0, instances = {}}
							end
							assets[value].count = assets[value].count + 1
							table.insert(assets[value].instances, desc:GetFullName())
						end
					end
				end

				local sorted = {}
				for asset, data in pairs(assets) do
					table.insert(sorted, {asset = asset, count = data.count, instances = data.instances})
				end
				table.sort(sorted, function(a, b) return a.count > b.count end)

				results = results .. string.format('<b>Unique assets found: %d</b>\n\n', #sorted)
				results = results .. '<b><font color="#5AA3E0">Most Used Assets:</font></b>\n'
				for i = 1, math.min(30, #sorted) do
					results = results .. string.format('<font color="#C8B450">%dx</font> %s\n', sorted[i].count, sorted[i].asset)
					if i <= 10 then
						results = results .. string.format('  <i>Used by: %s</i>\n', sorted[i].instances[1])
					end
				end
				if #sorted > 30 then
					results = results .. string.format('\n... and %d more unique assets', #sorted - 30)
				end

				createResultsWindow("Asset Scanner", results, screenGui)
			end
		},
		{
			name = "Character Inspector",
			desc = "Inspect local player character and humanoid",
			color = CONFIG.Colors.AccentPurple,
			callback = function()
				local results = "<b>CHARACTER INSPECTOR</b>\n\n"
				local player = game:GetService("Players").LocalPlayer
				local char = player.Character

				if char then
					results = results .. string.format('<b><font color="#5AA3E0">Character:</font></b> %s\n\n', char.Name)

					local humanoid = char:FindFirstChildOfClass("Humanoid")
					if humanoid then
						results = results .. '<b><font color="#50B464">Humanoid:</font></b>\n'
						results = results .. string.format('  Health: %.1f / %.1f\n', humanoid.Health, humanoid.MaxHealth)
						results = results .. string.format('  WalkSpeed: %.1f\n', humanoid.WalkSpeed)
						results = results .. string.format('  JumpPower: %.1f\n', humanoid.JumpPower)
						results = results .. string.format('  State: %s\n', tostring(humanoid:GetState()))
						results = results .. string.format('  DisplayName: %s\n', humanoid.DisplayName)
					end

					local root = char:FindFirstChild("HumanoidRootPart")
					if root then
						results = results .. '\n<b><font color="#C8B450">Position:</font></b>\n'
						results = results .. string.format('  Position: %s\n', tostring(root.Position))
						results = results .. string.format('  CFrame: %s\n', tostring(root.CFrame))
					end

					results = results .. '\n<b>Parts:</b>\n'
					for _, part in ipairs(char:GetChildren()) do
						if part:IsA("BasePart") then
							results = results .. string.format('  • %s (Size: %s)\n', part.Name, tostring(part.Size))
						end
					end

					local accessories = char:GetChildren()
					local accCount = 0
					for _, obj in ipairs(accessories) do
						if obj:IsA("Accessory") then
							accCount = accCount + 1
						end
					end
					if accCount > 0 then
						results = results .. string.format('\n<b>Accessories:</b> %d equipped\n', accCount)
					end
				else
					results = results .. '<font color="#B45050">Character not loaded</font>'
				end

				createResultsWindow("Character Inspector", results, screenGui)
			end
		},
		{
			name = "Dump All Attributes",
			desc = "Find all instances with custom attributes",
			color = CONFIG.Colors.AccentGreen,
			callback = function()
				local results = "<b>ATTRIBUTES DUMP</b>\n\n"
				local found = {}
				for _, desc in ipairs(game:GetDescendants()) do
					local attrs = desc:GetAttributes()
					local hasAttrs = false
					for k, v in pairs(attrs) do
						hasAttrs = true
						break
					end
					if hasAttrs then
						table.insert(found, {obj = desc, attrs = attrs})
					end
				end

				results = results .. string.format('<b>Total instances with attributes: %d</b>\n\n', #found)

				for i, data in ipairs(found) do
					if i <= 50 then
						results = results .. string.format('<b><font color="#5AA3E0">%s</font></b>\n', data.obj:GetFullName())
						for k, v in pairs(data.attrs) do
							results = results .. string.format('  [%s] = <font color="#50B464">%s</font>\n', k, formatValue(v))
						end
						results = results .. '\n'
					end
				end
				if #found > 50 then
					results = results .. string.format('... and %d more instances with attributes', #found - 50)
				end

				createResultsWindow("Attributes Dump", results, screenGui)
			end
		},
		{
			name = "🔍 Find Require() Calls",
			desc = "Scan all scripts for require() calls to ModuleScripts",
			color = CONFIG.Colors.AccentBlue,
			callback = function()
				local results = "<b>REQUIRE() CALLS SCANNER</b>\n\n"
				local requires = {}

				for _, script in ipairs(game:GetDescendants()) do
					if script:IsA("LocalScript") or script:IsA("Script") then
						pcall(function()
							if getsenv then
								local env = getsenv(script)
								if env then
									results = results .. string.format('<font color="#5AA3E0">%s</font>\n  Environment accessible\n', script:GetFullName())
								end
							end
						end)
					end
				end

				results = results .. '\n<b>Note:</b> Full require() scanning requires script source access'
				createResultsWindow("Require() Scanner", results, screenGui)
			end
		},
		{
			name = "🎯 Find GetService Calls",
			desc = "Identify all services being accessed",
			color = CONFIG.Colors.AccentYellow,
			callback = function()
				local results = "<b>GETSERVICE() USAGE</b>\n\n"
				local services = {}

				-- Scan for common service patterns
				local commonServices = {
					"Workspace", "Players", "ReplicatedStorage", "ReplicatedFirst",
					"StarterGui", "StarterPack", "UserInputService", "RunService",
					"TweenService", "HttpService", "DataStoreService", "MarketplaceService",
					"TextChatService", "SoundService", "Lighting"
				}

				results = results .. '<b>Services Available:</b>\n'
				for _, serviceName in ipairs(commonServices) do
					local success, service = pcall(function()
						return game:GetService(serviceName)
					end)
					if success then
						results = results .. string.format('<font color="#50B464">✓</font> %s\n', serviceName)
					else
						results = results .. string.format('<font color="#B45050">✗</font> %s\n', serviceName)
					end
				end

				createResultsWindow("GetService Scanner", results, screenGui)
			end
		},
		{
			name = "🧩 Extract Constants",
			desc = "Find common constants and configuration values",
			color = CONFIG.Colors.AccentPurple,
			callback = function()
				local results = "<b>CONSTANTS & CONFIGS</b>\n\n"

				-- Scan StringValues, NumberValues, etc for configs
				local configs = {}
				for _, obj in ipairs(game:GetDescendants()) do
					if obj:IsA("Configuration") then
						results = results .. string.format('<b><font color="#5AA3E0">%s</font></b>\n', obj:GetFullName())
						for _, child in ipairs(obj:GetChildren()) do
							if child:IsA("ValueBase") then
								local success, val = pcall(function() return child.Value end)
								if success then
									results = results .. string.format('  %s = %s\n', child.Name, tostring(val))
								end
							end
						end
						results = results .. '\n'
					end
				end

				createResultsWindow("Constants Extractor", results, screenGui)
			end
		},
		{
			name = "📡 Network Analyzer",
			desc = "Analyze RemoteEvents/Functions by parent location",
			color = CONFIG.Colors.AccentGreen,
			callback = function()
				local results = "<b>NETWORK STRUCTURE</b>\n\n"
				local byParent = {}

				for _, obj in ipairs(game:GetDescendants()) do
					if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
						local parentPath = obj.Parent and obj.Parent:GetFullName() or "nil"
						byParent[parentPath] = byParent[parentPath] or {}
						table.insert(byParent[parentPath], obj)
					end
				end

				results = results .. '<b>Remotes by Location:</b>\n\n'
				for parentPath, remotes in pairs(byParent) do
					results = results .. string.format('<font color="#5AA3E0">%s</font> (%d)\n', parentPath, #remotes)
					for i, remote in ipairs(remotes) do
						if i <= 10 then
							results = results .. string.format('  • %s: %s\n', remote.ClassName, remote.Name)
						end
					end
					if #remotes > 10 then
						results = results .. string.format('  ... and %d more\n', #remotes - 10)
					end
					results = results .. '\n'
				end

				createResultsWindow("Network Analyzer", results, screenGui)
			end
		},
		{
			name = "🎨 UI Theme Extractor",
			desc = "Extract colors and styling from GUIs",
			color = CONFIG.Colors.AccentRed,
			callback = function()
				local results = "<b>UI THEME EXTRACTION</b>\n\n"
				local colors = {}
				local fonts = {}

				for _, obj in ipairs(game:GetDescendants()) do
					if obj:IsA("GuiObject") then
						-- Extract colors
						local success, bgColor = pcall(function() return obj.BackgroundColor3 end)
						if success and bgColor then
							local colorKey = string.format("#%02X%02X%02X", bgColor.R * 255, bgColor.G * 255, bgColor.B * 255)
							colors[colorKey] = (colors[colorKey] or 0) + 1
						end

						-- Extract fonts
						local fontSuccess, font = pcall(function() return obj.Font end)
						if fontSuccess and font then
							fonts[tostring(font)] = (fonts[tostring(font)] or 0) + 1
						end
					end
				end

				results = results .. '<b>Most Used Colors:</b>\n'
				local sortedColors = {}
				for color, count in pairs(colors) do
					table.insert(sortedColors, {color = color, count = count})
				end
				table.sort(sortedColors, function(a, b) return a.count > b.count end)

				for i, data in ipairs(sortedColors) do
					if i <= 15 then
						results = results .. string.format('%dx <font color="%s">█████</font> %s\n', data.count, data.color, data.color)
					end
				end

				results = results .. '\n<b>Most Used Fonts:</b>\n'
				for font, count in pairs(fonts) do
					results = results .. string.format('%dx %s\n', count, font)
				end

				createResultsWindow("UI Theme", results, screenGui)
			end
		},
		{
			name = "⚡ Find Connections",
			desc = "Scan for .Changed, .Touched and other event connections",
			color = CONFIG.Colors.AccentBlue,
			callback = function()
				local results = "<b>EVENT CONNECTIONS</b>\n\n"

				if getconnections then
					results = results .. '<font color="#50B464">✓ getconnections() available</font>\n\n'
					results = results .. 'Feature: Can inspect connections on any GUI or object\n'
					results = results .. 'Use the "..." menu on a GUI to view its connections'
				else
					results = results .. '<font color="#B45050">✗ getconnections() not available</font>\n\n'
					results = results .. 'This executor does not support getconnections()\n'
					results = results .. 'Try using a different executor with this feature'
				end

				-- Still show some basic info
				results = results .. '\n<b>Common Events to Monitor:</b>\n'
				local events = {
					"MouseButton1Click", "MouseButton2Click",
					"Changed", "ChildAdded", "DescendantAdded",
					"Touched", "TouchEnded",
					"Chatted", "Died", "HealthChanged"
				}
				for _, event in ipairs(events) do
					results = results .. '  • ' .. event .. '\n'
				end

				createResultsWindow("Connections Info", results, screenGui)
			end
		},
		{
			name = "📊 Instance Statistics",
			desc = "Statistical analysis of all instances in game",
			color = CONFIG.Colors.AccentYellow,
			callback = function()
				local results = "<b>INSTANCE STATISTICS</b>\n\n"
				local byClass = {}
				local total = 0

				for _, obj in ipairs(game:GetDescendants()) do
					total = total + 1
					byClass[obj.ClassName] = (byClass[obj.ClassName] or 0) + 1
				end

				results = results .. string.format('<b>Total Instances: %d</b>\n\n', total)

				local sorted = {}
				for className, count in pairs(byClass) do
					table.insert(sorted, {className = className, count = count})
				end
				table.sort(sorted, function(a, b) return a.count > b.count end)

				results = results .. '<b>Top Classes:</b>\n'
				for i, data in ipairs(sorted) do
					if i <= 30 then
						local percentage = (data.count / total) * 100
						results = results .. string.format('%d. <font color="#5AA3E0">%s</font>: %d (%.1f%%)\n', i, data.className, data.count, percentage)
					end
				end

				if #sorted > 30 then
					results = results .. string.format('\n... and %d more classes', #sorted - 30)
				end

				createResultsWindow("Instance Statistics", results, screenGui)
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

local function populateSettingsTab(settingsFrame)
	local settingsList = Instance.new("ScrollingFrame")
	settingsList.Parent = settingsFrame
	settingsList.Size = UDim2.new(1, 0, 1, 0)
	settingsList.BackgroundTransparency = 1
	settingsList.BorderSizePixel = 0
	settingsList.ScrollBarThickness = 6
	settingsList.ScrollBarImageColor3 = CONFIG.Colors.Border
	settingsList.CanvasSize = UDim2.new(0, 0, 0, 0)
	settingsList.AutomaticCanvasSize = Enum.AutomaticSize.Y

	local settingsLayout = Instance.new("UIListLayout")
	settingsLayout.Parent = settingsList
	settingsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	settingsLayout.Padding = UDim.new(0, 10)

	local settingsOptions = {
		{
			name = "Remote Spy",
			desc = "Monitor RemoteEvent and RemoteFunction calls",
			type = "toggle",
			default = true,
			key = "remoteSpyEnabled"
		},
		{
			name = "Show Clipboard Notifications",
			desc = "Show notifications when copying to clipboard",
			type = "toggle",
			default = true,
			key = "showClipboardNotif"
		},
		{
			name = "Debug Output",
			desc = "Print debug information to console",
			type = "toggle",
			default = true,
			key = "debugOutput"
		}
	}

	for i, setting in ipairs(settingsOptions) do
		local settingCard = Instance.new("Frame")
		settingCard.Name = "Setting_" .. i
		settingCard.Parent = settingsList
		settingCard.Size = UDim2.new(1, -20, 0, 60)
		settingCard.BackgroundColor3 = CONFIG.Colors.Button
		settingCard.BorderSizePixel = 0
		settingCard.LayoutOrder = i
		createUICorner(6).Parent = settingCard

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Parent = settingCard
		nameLabel.Position = UDim2.new(0, 15, 0, 8)
		nameLabel.Size = UDim2.new(1, -120, 0, 20)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = CONFIG.FontBold
		nameLabel.Text = setting.name
		nameLabel.TextColor3 = CONFIG.Colors.Text
		nameLabel.TextSize = 14
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left

		local descLabel = Instance.new("TextLabel")
		descLabel.Parent = settingCard
		descLabel.Position = UDim2.new(0, 15, 0, 30)
		descLabel.Size = UDim2.new(1, -120, 0, 20)
		descLabel.BackgroundTransparency = 1
		descLabel.Font = CONFIG.Font
		descLabel.Text = setting.desc
		descLabel.TextColor3 = CONFIG.Colors.TextDim
		descLabel.TextSize = 11
		descLabel.TextXAlignment = Enum.TextXAlignment.Left

		-- Toggle button
		local toggleBtn = Instance.new("TextButton")
		toggleBtn.Parent = settingCard
		toggleBtn.Position = UDim2.new(1, -90, 0.5, -15)
		toggleBtn.Size = UDim2.new(0, 80, 0, 30)
		toggleBtn.BackgroundColor3 = setting.default and CONFIG.Colors.AccentGreen or CONFIG.Colors.AccentRed
		toggleBtn.BorderSizePixel = 0
		toggleBtn.Font = CONFIG.FontBold
		toggleBtn.Text = setting.default and "ON" or "OFF"
		toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		toggleBtn.TextSize = 13
		toggleBtn.AutoButtonColor = false
		createUICorner(4).Parent = toggleBtn

		State[setting.key] = setting.default

		toggleBtn.MouseButton1Click:Connect(function()
			State[setting.key] = not State[setting.key]
			toggleBtn.BackgroundColor3 = State[setting.key] and CONFIG.Colors.AccentGreen or CONFIG.Colors.AccentRed
			toggleBtn.Text = State[setting.key] and "ON" or "OFF"
			print("Setting changed:", setting.name, "=", State[setting.key])
		end)
	end

	-- Info section
	local infoCard = Instance.new("Frame")
	infoCard.Name = "Info"
	infoCard.Parent = settingsList
	infoCard.Size = UDim2.new(1, -20, 0, 120)
	infoCard.BackgroundColor3 = CONFIG.Colors.TopBar
	infoCard.BorderSizePixel = 0
	infoCard.LayoutOrder = 100
	createUICorner(6).Parent = infoCard

	local infoTitle = Instance.new("TextLabel")
	infoTitle.Parent = infoCard
	infoTitle.Position = UDim2.new(0, 15, 0, 10)
	infoTitle.Size = UDim2.new(1, -30, 0, 20)
	infoTitle.BackgroundTransparency = 1
	infoTitle.Font = CONFIG.FontBold
	infoTitle.Text = "GUI Debug Tool v1.0"
	infoTitle.TextColor3 = CONFIG.Colors.AccentBlue
	infoTitle.TextSize = 16
	infoTitle.TextXAlignment = Enum.TextXAlignment.Left

	local infoText = Instance.new("TextLabel")
	infoText.Parent = infoCard
	infoText.Position = UDim2.new(0, 15, 0, 35)
	infoText.Size = UDim2.new(1, -30, 0, 75)
	infoText.BackgroundTransparency = 1
	infoText.Font = CONFIG.Font
	infoText.Text = "Professional GUI Inspector & Debugger\nReverse Engineering Tools\nRemote Spy • Script Scanner • Chat Monitor"
	infoText.TextColor3 = CONFIG.Colors.TextDim
	infoText.TextSize = 12
	infoText.TextXAlignment = Enum.TextXAlignment.Left
	infoText.TextYAlignment = Enum.TextYAlignment.Top
	infoText.TextWrapped = true
end

-- ========================
-- CHAT SPY
-- ========================

local function setupChatSpy(chatScroll)
	local StarterGui = game:GetService("StarterGui")
	local Players = game:GetService("Players")
	local player = Players.LocalPlayer

	-- Try new TextChatService first
	local TextChatService = game:GetService("TextChatService")
	local useNewChat = false
	local chatEvents = nil
	local saymsg, getmsg = nil, nil

	-- Check if TextChatService is enabled
	pcall(function()
		if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
			useNewChat = true
		end
	end)

	if not useNewChat then
		-- Try legacy chat system
		local success, err = pcall(function()
			chatEvents = game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
		end)

		if success and chatEvents then
			saymsg = chatEvents:FindFirstChild("SayMessageRequest")
			getmsg = chatEvents:FindFirstChild("OnMessageDoneFiltering")

			if not saymsg or not getmsg then
				-- Try TextChatService as fallback
				useNewChat = true
			end
		else
			-- Try TextChatService as fallback
			useNewChat = true
		end
	end

	-- Show error only if both systems fail
	if not useNewChat and (not chatEvents or not saymsg or not getmsg) then
		local errorMsg = Instance.new("TextLabel")
		errorMsg.Parent = chatScroll
		errorMsg.Size = UDim2.new(1, -10, 0, 60)
		errorMsg.BackgroundColor3 = CONFIG.Colors.AccentRed
		errorMsg.BorderSizePixel = 0
		errorMsg.Font = CONFIG.Font
		errorMsg.Text = "⚠ Chat Spy Not Available\n\nNo chat system detected (tried both Legacy and TextChatService)"
		errorMsg.TextColor3 = Color3.fromRGB(255, 255, 255)
		errorMsg.TextSize = 12
		errorMsg.TextWrapped = true
		errorMsg.TextYAlignment = Enum.TextYAlignment.Top
		createUICorner(6).Parent = errorMsg

		local msgPadding = Instance.new("UIPadding")
		msgPadding.Parent = errorMsg
		msgPadding.PaddingTop = UDim.new(0, 8)
		msgPadding.PaddingLeft = UDim.new(0, 8)
		msgPadding.PaddingRight = UDim.new(0, 8)

		print("[CHAT SPY] No chat system available")
		return false
	end

	-- Color function for players
	local function getPlayerColor(playerName)
		local hash = 0
		for i = 1, #playerName do
			hash = hash + string.byte(playerName, i)
		end
		local colors = {
			Color3.fromRGB(255, 85, 85),   -- Red
			Color3.fromRGB(85, 170, 255),  -- Blue
			Color3.fromRGB(85, 255, 85),   -- Green
			Color3.fromRGB(255, 170, 0),   -- Orange
			Color3.fromRGB(170, 85, 255),  -- Purple
			Color3.fromRGB(255, 255, 85),  -- Yellow
			Color3.fromRGB(85, 255, 255),  -- Cyan
			Color3.fromRGB(255, 85, 255),  -- Magenta
		}
		return colors[(hash % #colors) + 1]
	end

	-- Add message to chat
	local function addChatMessage(playerName, message, isPrivate)
		local msgFrame = Instance.new("Frame")
		msgFrame.Name = "ChatMessage"
		msgFrame.Parent = chatScroll
		msgFrame.Size = UDim2.new(1, -10, 0, 0)
		msgFrame.BackgroundTransparency = 1
		msgFrame.AutomaticSize = Enum.AutomaticSize.Y
		msgFrame.LayoutOrder = #chatScroll:GetChildren()

		local msgText = Instance.new("TextLabel")
		msgText.Parent = msgFrame
		msgText.Size = UDim2.new(1, 0, 0, 0)
		msgText.BackgroundTransparency = 1
		msgText.Font = CONFIG.Font
		msgText.TextColor3 = CONFIG.Colors.Text
		msgText.TextSize = 13
		msgText.TextXAlignment = Enum.TextXAlignment.Left
		msgText.TextYAlignment = Enum.TextYAlignment.Top
		msgText.TextWrapped = true
		msgText.AutomaticSize = Enum.AutomaticSize.Y
		msgText.RichText = true

		local playerColor = getPlayerColor(playerName)
		local prefix = isPrivate and "[SPY] " or ""
		local colorHex = string.format("#%02X%02X%02X", playerColor.R * 255, playerColor.G * 255, playerColor.B * 255)

		msgText.Text = string.format('%s<font color="%s"><b>%s</b></font>: %s', prefix, colorHex, playerName, message)

		-- Auto scroll to bottom
		chatScroll.CanvasPosition = Vector2.new(0, chatScroll.AbsoluteCanvasSize.Y)
	end

	-- Monitor chat
	local function onChatted(p, msg)
		msg = msg:gsub("[\n\r]",''):gsub("\t",' '):gsub("[ ]+",' ')
		local hidden = true

		local conn = getmsg.OnClientEvent:Connect(function(packet, channel)
			if packet.SpeakerUserId == p.UserId and packet.Message == msg:sub(#msg-#packet.Message+1) then
				if channel == "All" or (channel == "Team" and Players[packet.FromSpeaker].Team == player.Team) then
					hidden = false
				end
			end
		end)

		wait(1)
		conn:Disconnect()

		if hidden then
			-- This is a private message
			addChatMessage(p.Name, msg, true)
		end
	end

	-- Setup monitoring based on chat system
	local connectSuccess = false

	if useNewChat then
		-- NEW: TextChatService monitoring
		print("[CHAT SPY] Using TextChatService")
		connectSuccess = pcall(function()
			-- Monitor incoming messages
			TextChatService.MessageReceived:Connect(function(message)
				local sourcePlayer = Players:GetPlayerByUserId(message.TextSource.UserId)
				if sourcePlayer and sourcePlayer ~= player then
					addChatMessage(sourcePlayer.Name, message.Text, false)
				end
			end)

			-- Monitor all text channels for messages
			for _, textChannel in ipairs(TextChatService:GetChildren()) do
				if textChannel:IsA("TextChannel") then
					textChannel.MessageReceived:Connect(function(message)
						if message.TextSource then
							local sourcePlayer = Players:GetPlayerByUserId(message.TextSource.UserId)
							if sourcePlayer and sourcePlayer ~= player then
								-- Check if it's a whisper/private message
								local isPrivate = message.Metadata and message.Metadata:find("Whisper") or false
								addChatMessage(sourcePlayer.Name, message.Text, isPrivate)
							end
						end
					end)
				end
			end

			-- Monitor player joins/leaves
			Players.PlayerAdded:Connect(function(p)
				addChatMessage("SYSTEM", p.Name .. " joined the game", false)
			end)

			Players.PlayerRemoving:Connect(function(p)
				addChatMessage("SYSTEM", p.Name .. " left the game", false)
			end)
		end)
	else
		-- LEGACY: DefaultChatSystemChatEvents monitoring
		print("[CHAT SPY] Using Legacy Chat System")
		connectSuccess = pcall(function()
			-- Monitor chat
			local function onChatted(p, msg)
				msg = msg:gsub("[\n\r]",''):gsub("\t",' '):gsub("[ ]+",' ')
				local hidden = true

				local conn = getmsg.OnClientEvent:Connect(function(packet, channel)
					if packet.SpeakerUserId == p.UserId and packet.Message == msg:sub(#msg-#packet.Message+1) then
						if channel == "All" or (channel == "Team" and Players[packet.FromSpeaker].Team == player.Team) then
							hidden = false
						end
					end
				end)

				wait(1)
				conn:Disconnect()

				if hidden then
					-- This is a private message
					addChatMessage(p.Name, msg, true)
				end
			end

			-- Connect to all players
			for _, p in ipairs(Players:GetPlayers()) do
				p.Chatted:Connect(function(msg) onChatted(p, msg) end)
			end

			Players.PlayerAdded:Connect(function(p)
				p.Chatted:Connect(function(msg) onChatted(p, msg) end)
				addChatMessage("SYSTEM", p.Name .. " joined the game", false)
			end)

			Players.PlayerRemoving:Connect(function(p)
				addChatMessage("SYSTEM", p.Name .. " left the game", false)
			end)

			-- Monitor public messages too
			getmsg.OnClientEvent:Connect(function(packet, channel)
				if packet.SpeakerUserId ~= player.UserId then
					local senderPlayer = Players:GetPlayerByUserId(packet.SpeakerUserId)
					if senderPlayer then
						addChatMessage(senderPlayer.Name, packet.Message, false)
					end
				end
			end)
		end)
	end

	if connectSuccess then
		-- Add success message to chat
		local successMsg = Instance.new("TextLabel")
		successMsg.Parent = chatScroll
		successMsg.Size = UDim2.new(1, -10, 0, 55)
		successMsg.BackgroundColor3 = CONFIG.Colors.AccentGreen
		successMsg.BorderSizePixel = 0
		successMsg.Font = CONFIG.FontBold
		local chatType = useNewChat and "TextChatService" or "Legacy Chat"
		successMsg.Text = string.format("✓ Chat Spy Active (%s)\n\nMonitoring all chat messages", chatType)
		successMsg.TextColor3 = Color3.fromRGB(255, 255, 255)
		successMsg.TextSize = 11
		successMsg.TextWrapped = true
		successMsg.TextYAlignment = Enum.TextYAlignment.Top
		createUICorner(6).Parent = successMsg

		local successPadding = Instance.new("UIPadding")
		successPadding.Parent = successMsg
		successPadding.PaddingTop = UDim.new(0, 8)
		successPadding.PaddingLeft = UDim.new(0, 8)
		successPadding.PaddingRight = UDim.new(0, 8)

		print("[CHAT SPY] Enabled successfully using " .. chatType)
		return true
	else
		local errorMsg = Instance.new("TextLabel")
		errorMsg.Parent = chatScroll
		errorMsg.Size = UDim2.new(1, -10, 0, 50)
		errorMsg.BackgroundColor3 = CONFIG.Colors.AccentRed
		errorMsg.BorderSizePixel = 0
		errorMsg.Font = CONFIG.Font
		errorMsg.Text = "⚠ Chat Spy Failed\n\nFailed to connect to chat events"
		errorMsg.TextColor3 = Color3.fromRGB(255, 255, 255)
		errorMsg.TextSize = 12
		errorMsg.TextWrapped = true
		errorMsg.TextYAlignment = Enum.TextYAlignment.Top
		createUICorner(6).Parent = errorMsg

		local msgPadding = Instance.new("UIPadding")
		msgPadding.Parent = errorMsg
		msgPadding.PaddingTop = UDim.new(0, 8)
		msgPadding.PaddingLeft = UDim.new(0, 8)
		msgPadding.PaddingRight = UDim.new(0, 8)

		print("[CHAT SPY] Failed to connect events")
		return false
	end
end

local function initialize()
	local screenGui, mainFrame, contentFrame, freezeBtn, refreshBtn, minimizeBtn, closeBtn, statusLabel, searchBox, clearSearchBtn, tabButtons, toolbar, remotesFrame, toolsFrame, settingsFrame, remotesHeader, remotesStatus, refreshRemotesBtn, chatFrame, chatScroll, chatInputBox, sendBtn = createMainWindow()

	-- Store reference for show/hide functions
	debugToolInstance = screenGui

	-- Setup Remote Spy
	local remoteSpyActive, spyError = setupRemoteSpy(remotesFrame)

	if remoteSpyActive then
		remotesStatus.Text = "Active (Hooked) | " .. #State.remoteLogs .. " logs"
		remotesStatus.TextColor3 = CONFIG.Colors.AccentGreen
	else
		if spyError then
			remotesStatus.Text = "Passive Mode | Error: " .. (spyError or "Unknown")
			remotesStatus.TextColor3 = CONFIG.Colors.AccentYellow
		elseif not hookmetamethod or not getnamecallmethod then
			remotesStatus.Text = "Passive Mode | hookmetamethod not available"
			remotesStatus.TextColor3 = CONFIG.Colors.AccentYellow
		else
			remotesStatus.Text = "Passive Mode | Use Tools tab to scan"
			remotesStatus.TextColor3 = CONFIG.Colors.AccentYellow
		end
	end

	-- Refresh remotes button
	refreshRemotesBtn.MouseEnter:Connect(function()
		refreshRemotesBtn.BackgroundColor3 = Color3.fromRGB(90, 150, 200)
	end)
	refreshRemotesBtn.MouseLeave:Connect(function()
		refreshRemotesBtn.BackgroundColor3 = CONFIG.Colors.AccentBlue
	end)
	refreshRemotesBtn.MouseButton1Click:Connect(function()
		refreshRemotesList(remotesFrame)
		remotesStatus.Text = "Active | " .. #State.remoteLogs .. " logs"
	end)

	-- Populate Tools tab
	populateToolsTab(toolsFrame, screenGui)

	-- Populate Settings tab
	populateSettingsTab(settingsFrame)

	-- Setup Chat Spy
	local chatSpyActive = pcall(function()
		return setupChatSpy(chatScroll)
	end)

	-- Chat send functionality
	-- Store chat system type
	local chatSystemType = "unknown"
	local TextChatService = game:GetService("TextChatService")

	-- Detect chat system
	local useTextChatService = false
	pcall(function()
		if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
			useTextChatService = true
			chatSystemType = "TextChatService"
		end
	end)

	if not useTextChatService then
		local chatEvents = game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
		if chatEvents then
			chatSystemType = "Legacy"
		end
	end

	local function sendChatMessage()
		local message = chatInputBox.Text
		if message and message ~= "" then
			if chatSystemType == "TextChatService" then
				-- NEW: Use TextChatService
				local success = pcall(function()
					-- Get the local player's text channel
					local textChannel = TextChatService:FindFirstChild("TextChannels")
					if textChannel then
						textChannel = textChannel:FindFirstChild("RBXGeneral")
					end

					-- Alternative: try to get from player's chat
					if not textChannel then
						local channels = TextChatService:GetDescendants()
						for _, channel in ipairs(channels) do
							if channel:IsA("TextChannel") and (channel.Name == "RBXGeneral" or channel.Name == "RBXTeam") then
								textChannel = channel
								break
							end
						end
					end

					if textChannel and textChannel:IsA("TextChannel") then
						textChannel:SendAsync(message)
						chatInputBox.Text = ""
						return
					end

					-- Last resort: use Players.LocalPlayer.Chatted
					LocalPlayer.Chatted:Fire(message)
					chatInputBox.Text = ""
				end)

				if not success then
					-- If TextChatService failed, try legacy as fallback
					chatSystemType = "Legacy"
					sendChatMessage()
				end
			elseif chatSystemType == "Legacy" then
				-- LEGACY: Use DefaultChatSystemChatEvents
				local success = pcall(function()
					local chatEvents = game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
					if chatEvents then
						local saymsg = chatEvents:FindFirstChild("SayMessageRequest")
						if saymsg then
							saymsg:FireServer(message, "All")
							chatInputBox.Text = ""
						end
					else
						-- Try alternative: direct Player.Chatted
						LocalPlayer.Chatted:Fire(message)
						chatInputBox.Text = ""
					end
				end)

				if not success then
					chatInputBox.PlaceholderText = "Failed to send message!"
					task.wait(2)
					chatInputBox.PlaceholderText = "Type message... (Enter to send)"
				end
			else
				-- Unknown chat system - show error
				chatInputBox.PlaceholderText = "Chat system not detected!"
				task.wait(2)
				chatInputBox.PlaceholderText = "Type message... (Enter to send)"
			end
		end
	end

	sendBtn.MouseEnter:Connect(function()
		sendBtn.BackgroundColor3 = Color3.fromRGB(100, 200, 120)
	end)
	sendBtn.MouseLeave:Connect(function()
		sendBtn.BackgroundColor3 = CONFIG.Colors.AccentGreen
	end)
	sendBtn.MouseButton1Click:Connect(sendChatMessage)

	chatInputBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			sendChatMessage()
		end
	end)

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
		remotesHeader.Visible = (tabName == "Remotes")
		toolsFrame.Visible = (tabName == "Tools")
		chatFrame.Visible = (tabName == "Chat")
		settingsFrame.Visible = (tabName == "Settings")

		if tabName == "Remotes" then
			refreshRemotesList(remotesFrame)
			remotesStatus.Text = "Active | " .. #State.remoteLogs .. " logs"
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
		scanAndDisplayGuis(contentFrame, statusLabel, screenGui)
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
		scanAndDisplayGuis(contentFrame, statusLabel, screenGui)
	end)

	-- Close button (hides instead of destroying)
	closeBtn.MouseButton1Click:Connect(function()
		_G.HideDebugTool()
	end)

	-- Minimize button
	local isMinimized = false
	local originalSize = mainFrame.Size
	local sidebar = mainFrame:FindFirstChild("Sidebar")
	local sidebarSeparator = mainFrame:FindFirstChild("SidebarSeparator")

	minimizeBtn.MouseButton1Click:Connect(function()
		if isMinimized then
			mainFrame.Size = originalSize
			if sidebar then sidebar.Visible = true end
			if sidebarSeparator then sidebarSeparator.Visible = true end

			-- Show current tab content
			if State.currentTab == "GUIs" then
				contentFrame.Visible = true
				toolbar.Visible = true
			elseif State.currentTab == "Remotes" then
				remotesFrame.Visible = true
				remotesHeader.Visible = true
			elseif State.currentTab == "Tools" then
				toolsFrame.Visible = true
			elseif State.currentTab == "Chat" then
				chatFrame.Visible = true
			elseif State.currentTab == "Settings" then
				settingsFrame.Visible = true
			end

			minimizeBtn.Text = "−"
			isMinimized = false
		else
			mainFrame.Size = UDim2.new(0, CONFIG.WindowSize.X, 0, 35)
			if sidebar then sidebar.Visible = false end
			if sidebarSeparator then sidebarSeparator.Visible = false end
			contentFrame.Visible = false
			toolbar.Visible = false
			remotesFrame.Visible = false
			remotesHeader.Visible = false
			toolsFrame.Visible = false
			chatFrame.Visible = false
			settingsFrame.Visible = false
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
			scanAndDisplayGuis(contentFrame, statusLabel, screenGui)
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
			scanAndDisplayGuis(contentFrame, statusLabel, screenGui)
		end
	end)

	-- Initial scan
	scanAndDisplayGuis(contentFrame, statusLabel, screenGui)
end

-- Start the tool
initialize()
