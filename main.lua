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
	frozenIndividual = {}, -- {[instance] = {children snapshot}}
	searchQuery = "", -- Current search filter
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

	-- Toolbar (Freeze toggle + Search)
	local toolbar = Instance.new("Frame")
	toolbar.Name = "Toolbar"
	toolbar.Parent = mainFrame
	toolbar.Position = UDim2.new(0, 0, 0, 36)
	toolbar.Size = UDim2.new(1, 0, 0, 70)
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
	contentFrame.Position = UDim2.new(0, 10, 0, 116)
	contentFrame.Size = UDim2.new(1, -20, 1, -126)
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

	return screenGui, mainFrame, contentFrame, freezeBtn, refreshBtn, minimizeBtn, closeBtn, statusLabel, searchBox, clearSearchBtn
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

local function initialize()
	local screenGui, mainFrame, contentFrame, freezeBtn, refreshBtn, minimizeBtn, closeBtn, statusLabel, searchBox, clearSearchBtn = createMainWindow()

	-- Store reference for show/hide functions
	debugToolInstance = screenGui

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
