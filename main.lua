-- Roblox GUI Debug Tool
-- Professional GUI Inspector & Debugger
-- No lag, no auto-refresh, manual control only

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- ========================
-- CONFIGURATION
-- ========================
local CONFIG = {
	WindowSize = Vector2.new(500, 550),
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
}

-- ========================
-- UTILITY FUNCTIONS
-- ========================

local function isGuiRoot(obj)
	return obj:IsA("ScreenGui") or obj:IsA("SurfaceGui") or obj:IsA("BillboardGui")
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

	-- Refresh Button (⟳)
	local refreshBtn = Instance.new("TextButton")
	refreshBtn.Name = "RefreshButton"
	refreshBtn.Parent = topBar
	refreshBtn.Position = UDim2.new(1, -(btnSize + btnPadding) * 3, 0.5, -btnSize/2)
	refreshBtn.Size = UDim2.new(0, btnSize, 0, btnSize)
	refreshBtn.BackgroundColor3 = CONFIG.Colors.Button
	refreshBtn.BorderSizePixel = 0
	refreshBtn.Font = CONFIG.FontBold
	refreshBtn.Text = "⟳"
	refreshBtn.TextColor3 = CONFIG.Colors.AccentGreen
	refreshBtn.TextSize = 18
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

	-- Toolbar (Freeze toggle)
	local toolbar = Instance.new("Frame")
	toolbar.Name = "Toolbar"
	toolbar.Parent = mainFrame
	toolbar.Position = UDim2.new(0, 0, 0, 36)
	toolbar.Size = UDim2.new(1, 0, 0, 40)
	toolbar.BackgroundColor3 = CONFIG.Colors.Background
	toolbar.BorderSizePixel = 0

	local freezeBtn = Instance.new("TextButton")
	freezeBtn.Name = "FreezeButton"
	freezeBtn.Parent = toolbar
	freezeBtn.Position = UDim2.new(0, 10, 0.5, -15)
	freezeBtn.Size = UDim2.new(0, 100, 0, 30)
	freezeBtn.BackgroundColor3 = CONFIG.Colors.Button
	freezeBtn.BorderSizePixel = 0
	freezeBtn.Font = CONFIG.Font
	freezeBtn.Text = "FREEZE"
	freezeBtn.TextColor3 = CONFIG.Colors.Text
	freezeBtn.TextSize = 14
	freezeBtn.AutoButtonColor = false
	createUICorner(4).Parent = freezeBtn

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Parent = toolbar
	statusLabel.Position = UDim2.new(0, 120, 0, 0)
	statusLabel.Size = UDim2.new(1, -130, 1, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = CONFIG.Font
	statusLabel.Text = "Ready"
	statusLabel.TextColor3 = CONFIG.Colors.TextDim
	statusLabel.TextSize = 12
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left

	-- Content Frame
	local contentFrame = Instance.new("ScrollingFrame")
	contentFrame.Name = "ContentFrame"
	contentFrame.Parent = mainFrame
	contentFrame.Position = UDim2.new(0, 10, 0, 86)
	contentFrame.Size = UDim2.new(1, -20, 1, -96)
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

	return screenGui, mainFrame, contentFrame, freezeBtn, refreshBtn, minimizeBtn, closeBtn, statusLabel
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
	if isGuiRoot(obj) then
		obj.Enabled = true
	end

	if obj:IsA("GuiObject") then
		obj.Visible = true
	end

	-- Also enable parent chain if needed
	local parent = obj.Parent
	while parent do
		if isGuiRoot(parent) then
			parent.Enabled = true
			break
		elseif parent:IsA("GuiObject") then
			parent.Visible = true
		end
		parent = parent.Parent
	end
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

	local entry = Instance.new("Frame")
	entry.Name = "Entry_" .. obj.Name
	entry.Parent = parent
	entry.Size = UDim2.new(1, -10, 0, entryHeight)
	entry.BackgroundColor3 = depth == 0 and CONFIG.Colors.TopBar or CONFIG.Colors.Button
	entry.BorderSizePixel = 0

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

				-- Create child container
				childContainer = Instance.new("Frame")
				childContainer.Name = "ChildContainer"
				childContainer.Parent = parent
				childContainer.Size = UDim2.new(1, -10, 0, 0)
				childContainer.BackgroundTransparency = 1
				childContainer.BorderSizePixel = 0
				childContainer.AutomaticSize = Enum.AutomaticSize.Y
				childContainer.LayoutOrder = entry.LayoutOrder + 1

				local childLayout = Instance.new("UIListLayout")
				childLayout.Parent = childContainer
				childLayout.SortOrder = Enum.SortOrder.LayoutOrder
				childLayout.Padding = UDim.new(0, 2)

				-- Add children (only 1 level deep)
				for _, child in ipairs(obj:GetChildren()) do
					if child:IsA("GuiObject") or isGuiRoot(child) then
						createGuiEntry(childContainer, child, depth + 1, onRefresh)
					end
				end
			end
		end)
	end

	return entry
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

	-- Display all root GUIs
	for i, gui in ipairs(guiList) do
		local entry = createGuiEntry(contentFrame, gui, 0, function()
			scanAndDisplayGuis(contentFrame, statusLabel)
		end)
		entry.LayoutOrder = i
	end
end

-- ========================
-- INITIALIZE
-- ========================

local function initialize()
	local screenGui, mainFrame, contentFrame, freezeBtn, refreshBtn, minimizeBtn, closeBtn, statusLabel = createMainWindow()

	-- Make draggable
	local topBar = mainFrame:FindFirstChild("TopBar")
	makeDraggable(mainFrame, topBar)

	-- Close button
	closeBtn.MouseButton1Click:Connect(function()
		screenGui:Destroy()
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
			freezeBtn.Text = "UNFREEZE"
			statusLabel.Text = "Frozen | " .. #guiList .. " root GUIs"
			statusLabel.TextColor3 = CONFIG.Colors.AccentBlue
		else
			-- Unfreeze
			State.frozenData = nil
			freezeBtn.BackgroundColor3 = CONFIG.Colors.Button
			freezeBtn.Text = "FREEZE"
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
