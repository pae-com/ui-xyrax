--[[
	ReaperX Style UI Library (Enhanced Full Version)
	รูปแบบ: Dark / Red Accent / Custom Logo & Icons
	Features: Corner Resizing, Element Typography/Importance, Real Dropdowns
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local UIModule = {}
UIModule.__index = UIModule

-- ====================== THEME & ICONS ======================
local Theme = {
	Background = Color3.fromRGB(15, 15, 17),
	Sidebar    = Color3.fromRGB(20, 20, 23),
	Content    = Color3.fromRGB(15, 15, 17),
	Section    = Color3.fromRGB(25, 25, 28),
	Border     = Color3.fromRGB(38, 38, 44),

	Text       = Color3.fromRGB(255, 255, 255),
	TextDim    = Color3.fromRGB(160, 160, 170),

	-- สีหลัก (แดง)
	Accent     = Color3.fromRGB(255, 50, 50),
	AccentDark = Color3.fromRGB(180, 20, 20),

	-- สีของ Widget ต่างๆ
	ToggleOff   = Color3.fromRGB(45, 45, 50),
	SliderTrack = Color3.fromRGB(35, 35, 40),
	Dropdown    = Color3.fromRGB(30, 30, 35),
}

-- Typography / Importance Scale
local Typography = {
	Title     = 15,
	Primary   = 13,
	Secondary = 12,
	Compact   = 11,
}

local function ResolveFontSize(config, fallback)
	if config then
		if type(config.TextSize) == "number" then
			return config.TextSize
		end
		if config.Importance and Typography[config.Importance] then
			return Typography[config.Importance]
		end
	end
	return fallback
end

-- Assets & Icons
UIModule.Icons = {
	Logo     = "rbxassetid://137660498980177", -- Custom Logo
	Close    = "rbxassetid://87463403317153",  -- Custom Close Button

	-- เมนูซ้าย (Sidebar)
	Swords   = "rbxassetid://10747377716",
	Skull    = "rbxassetid://10747384022",
	Users    = "rbxassetid://10747383281",
	Cart     = "rbxassetid://10747381958",
	Gift     = "rbxassetid://10747378401",
	Bell     = "rbxassetid://10747377045",
	Globe    = "rbxassetid://10747378330",
	Servers  = "rbxassetid://10747381285",
	Settings = "rbxassetid://10747383136",

	-- UI ทั่วไป
	Star     = "rbxassetid://10747383049",
	Play     = "rbxassetid://10747381395",
	Loop     = "rbxassetid://10747381023",
	Search   = "rbxassetid://10747381118",
	Dropdown = "rbxassetid://10747384978",
	Check    = "rbxassetid://10747376789",
	Resize   = "rbxassetid://10747384394",
}
local Icons = UIModule.Icons

-- ====================== UTILITIES ======================
local function Create(class, props)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function Tween(obj, props, time)
	local t = TweenService:Create(
		obj,
		TweenInfo.new(time or 0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

local function ApplyGradient(parent, color1, color2)
	return Create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, color1),
			ColorSequenceKeypoint.new(1, color2 or color1)
		}),
		Rotation = 45,
		Parent = parent
	})
end

-- ====================== WINDOW ======================
function UIModule.new(config)
	config = config or {}
	local self = setmetatable({}, UIModule)

	self.Title = config.Title or "ReaperX"
	self.Subtitle = config.Subtitle or "Premium Script Hub"
	self.Size = config.Size or UDim2.new(0, 800, 0, 500)
	self.MinSize = config.MinSize or Vector2.new(540, 360)
	self.MaxSize = config.MaxSize or Vector2.new(1200, 850)
	self.ToggleKey = config.ToggleKey or Enum.KeyCode.RightControl
	self.Tabs = {}
	self.CurrentTab = nil
	self.Flags = {}

	-- ScreenGui
	local gui = Create("ScreenGui", {
		Name = "ReaperX_UI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	self.Gui = gui

	-- Main Frame
	local main = Create("Frame", {
		Name = "Main",
		Size = self.Size,
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = gui,
	})
	self.Main = main

	Create("UICorner", { CornerRadius = UDim.new(0, 9), Parent = main })
	Create("UIStroke", { Color = Theme.Border, Thickness = 1.2, Parent = main })

	-- Keybind to Show/Hide GUI
	UserInputService.InputBegan:Connect(function(input, gpe)
		if not gpe and input.KeyCode == self.ToggleKey then
			main.Visible = not main.Visible
		end
	end)

	-- ========== TITLE BAR ==========
	local titleBar = Create("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = Theme.Sidebar,
		BorderSizePixel = 0,
		Parent = main,
	})

	Create("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, -1),
		BackgroundColor3 = Theme.Border,
		BorderSizePixel = 0,
		Parent = titleBar,
	})

	-- Logo
	local logoImg = Create("ImageLabel", {
		Name = "Logo",
		Size = UDim2.new(0, 32, 0, 32),
		Position = UDim2.new(0, 14, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Image = Icons.Logo,
		Parent = titleBar,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = logoImg })

	-- Title & Subtitle Labels
	local textStartX = 54
	local titleSize = ResolveFontSize({ Importance = config.TitleImportance or "Title" }, 15)
	local subSize = ResolveFontSize({ Importance = config.SubtitleImportance or "Compact" }, 11)

	Create("TextLabel", {
		Size = UDim2.new(1, -(textStartX + 120), 0, 20),
		Position = UDim2.new(0, textStartX, 0, 8),
		BackgroundTransparency = 1,
		Text = self.Title,
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamBold,
		TextSize = titleSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = titleBar,
	})

	if self.Subtitle ~= "" then
		Create("TextLabel", {
			Size = UDim2.new(1, -(textStartX + 120), 0, 16),
			Position = UDim2.new(0, textStartX, 0, 28),
			BackgroundTransparency = 1,
			Text = self.Subtitle,
			TextColor3 = Theme.TextDim,
			Font = Enum.Font.Gotham,
			TextSize = subSize,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = titleBar,
		})
	end

	-- Top Right Controls (Search, Settings, Close)
	local btnList = Create("Frame", {
		Size = UDim2.new(0, 95, 1, 0),
		Position = UDim2.new(1, -105, 0, 0),
		BackgroundTransparency = 1,
		Parent = titleBar,
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 12),
		Parent = btnList,
	})

	local function CreateTopBtn(iconId, callback)
		local btn = Create("ImageButton", {
			Size = UDim2.new(0, 18, 0, 18),
			BackgroundTransparency = 1,
			Image = iconId,
			ImageColor3 = Theme.TextDim,
			Parent = btnList,
		})
		btn.MouseEnter:Connect(function() Tween(btn, { ImageColor3 = Theme.Accent }) end)
		btn.MouseLeave:Connect(function() Tween(btn, { ImageColor3 = Theme.TextDim }) end)
		if callback then
			btn.MouseButton1Click:Connect(callback)
		end
		return btn
	end

	CreateTopBtn(Icons.Search)
	CreateTopBtn(Icons.Settings)
	CreateTopBtn(Icons.Close, function() gui:Destroy() end)

	-- ========== SIDEBAR ==========
	local sidebar = Create("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, 190, 1, -52),
		Position = UDim2.new(0, 0, 0, 52),
		BackgroundColor3 = Theme.Sidebar,
		BorderSizePixel = 0,
		Parent = main,
	})

	Create("Frame", {
		Size = UDim2.new(0, 1, 1, 0),
		Position = UDim2.new(1, -1, 0, 0),
		BackgroundColor3 = Theme.Border,
		BorderSizePixel = 0,
		Parent = sidebar,
	})

	local sidebarList = Create("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = Theme.Accent,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = sidebar,
	})
	self.SidebarList = sidebarList

	Create("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = sidebarList,
	})
	Create("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		Parent = sidebarList,
	})

	-- ========== CONTENT ==========
	local content = Create("Frame", {
		Name = "Content",
		Size = UDim2.new(1, -190, 1, -52),
		Position = UDim2.new(0, 190, 0, 52),
		BackgroundColor3 = Theme.Content,
		BorderSizePixel = 0,
		Parent = main,
	})
	self.Content = content

	local contentScroll = Create("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Border,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = content,
	})
	self.ContentScroll = contentScroll

	Create("UIListLayout", {
		Padding = UDim.new(0, 14),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = contentScroll,
	})
	Create("UIPadding", {
		PaddingTop = UDim.new(0, 16),
		PaddingBottom = UDim.new(0, 24),
		PaddingLeft = UDim.new(0, 20),
		PaddingRight = UDim.new(0, 20),
		Parent = contentScroll,
	})

	-- ========== WINDOW DRAGGING LOGIC (Fixed) ==========
	local dragging, dragStart, startPos = false, nil, nil
	titleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = main.Position
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			main.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
	end)

	-- ========== CORNER RESIZE LOGIC (Bottom-Right Handle) ==========
	local resizeHandle = Create("ImageButton", {
		Name = "ResizeHandle",
		Size = UDim2.new(0, 18, 0, 18),
		Position = UDim2.new(1, -2, 1, -2),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		Image = "rbxassetid://10747384394", -- Grip corner icon
		ImageColor3 = Theme.TextDim,
		ZIndex = 10,
		Parent = main,
	})

	resizeHandle.MouseEnter:Connect(function() Tween(resizeHandle, { ImageColor3 = Theme.Accent }) end)
	resizeHandle.MouseLeave:Connect(function() Tween(resizeHandle, { ImageColor3 = Theme.TextDim }) end)

	local resizing = false
	local resizeStartPos, resizeStartSize, resizeMainCenter

	resizeHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			resizing = true
			resizeStartPos = input.Position
			resizeStartSize = main.AbsoluteSize
			resizeMainCenter = main.Position
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			resizing = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - resizeStartPos
			local newW = math.clamp(resizeStartSize.X + delta.X, self.MinSize.X, self.MaxSize.X)
			local newH = math.clamp(resizeStartSize.Y + delta.Y, self.MinSize.Y, self.MaxSize.Y)

			-- Keep Top-Left pinned while AnchorPoint is (0.5, 0.5)
			local actualDeltaW = newW - resizeStartSize.X
			local actualDeltaH = newH - resizeStartSize.Y

			main.Size = UDim2.new(0, newW, 0, newH)
			main.Position = UDim2.new(
				resizeMainCenter.X.Scale,
				resizeMainCenter.X.Offset + (actualDeltaW / 2),
				resizeMainCenter.Y.Scale,
				resizeMainCenter.Y.Offset + (actualDeltaH / 2)
			)
		end
	end)

	return self
end

-- ====================== TABS ======================
function UIModule:CreateTabLabel(text, config)
	local fontSize = ResolveFontSize(config, Typography.Compact)
	Create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Text = "  " .. text:upper(),
		TextColor3 = Theme.TextDim,
		Font = Enum.Font.GothamBold,
		TextSize = fontSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = self.SidebarList,
	})
end

function UIModule:CreateTab(name, iconId, config)
	local tab = { Name = name, Sections = {} }
	iconId = iconId or Icons.Settings
	local textSize = ResolveFontSize(config, Typography.Primary)

	local btn = Create("TextButton", {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = Theme.Accent,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = self.SidebarList,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = btn })

	local btnGradient = ApplyGradient(btn, Theme.Accent, Theme.AccentDark)
	btnGradient.Enabled = false

	local iconLabel = Create("ImageLabel", {
		Size = UDim2.new(0, 18, 0, 18),
		Position = UDim2.new(0, 10, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Image = iconId,
		ImageColor3 = Theme.TextDim,
		Parent = btn,
	})

	local nameLabel = Create("TextLabel", {
		Size = UDim2.new(1, -38, 1, 0),
		Position = UDim2.new(0, 36, 0, 0),
		BackgroundTransparency = 1,
		Text = name,
		TextColor3 = Theme.TextDim,
		Font = Enum.Font.GothamMedium,
		TextSize = textSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = btn,
	})

	local container = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = false,
		Parent = self.ContentScroll,
	})
	Create("UIListLayout", {
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = container,
	})
	tab.Container = container

	btn.MouseButton1Click:Connect(function() self:SelectTab(tab) end)

	btn.MouseEnter:Connect(function()
		if self.CurrentTab ~= tab then
			Tween(btn, { BackgroundTransparency = 0.9 })
			Tween(nameLabel, { TextColor3 = Theme.Text })
			Tween(iconLabel, { ImageColor3 = Theme.Text })
		end
	end)

	btn.MouseLeave:Connect(function()
		if self.CurrentTab ~= tab then
			Tween(btn, { BackgroundTransparency = 1 })
			Tween(nameLabel, { TextColor3 = Theme.TextDim })
			Tween(iconLabel, { ImageColor3 = Theme.TextDim })
		end
	end)

	tab.Button = btn
	tab.Gradient = btnGradient
	tab.NameLabel = nameLabel
	tab.IconLabel = iconLabel

	table.insert(self.Tabs, tab)
	if #self.Tabs == 1 then
		self:SelectTab(tab)
	end
	return tab
end

function UIModule:SelectTab(tab)
	for _, t in ipairs(self.Tabs) do
		t.Container.Visible = false
		t.Gradient.Enabled = false
		t.Button.BackgroundTransparency = 1
		t.NameLabel.TextColor3 = Theme.TextDim
		t.IconLabel.ImageColor3 = Theme.TextDim
	end

	tab.Container.Visible = true
	tab.Gradient.Enabled = true
	tab.Button.BackgroundTransparency = 0.85
	tab.NameLabel.TextColor3 = Theme.Text
	tab.IconLabel.ImageColor3 = Theme.Accent
	self.CurrentTab = tab
end

-- ====================== SECTION ======================
function UIModule:CreateSection(tab, config)
	config = config or {}
	local titleSize = ResolveFontSize({ TextSize = config.TitleSize, Importance = config.Importance }, Typography.Title)
	local subSize = ResolveFontSize({ TextSize = config.SubtitleSize, Importance = config.SubtitleImportance }, Typography.Compact)

	local section = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Section,
		BorderSizePixel = 0,
		Parent = tab.Container,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = section })
	Create("UIStroke", { Color = Theme.Border, Thickness = 1, Parent = section })
	Create("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 14),
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
		Parent = section,
	})
	Create("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = section,
	})

	if config.Title then
		local header = Create("Frame", {
			Size = UDim2.new(1, 0, 0, config.Subtitle and 36 or 22),
			BackgroundTransparency = 1,
			Parent = section,
		})

		if config.Icon then
			Create("ImageLabel", {
				Size = UDim2.new(0, 18, 0, 18),
				Position = UDim2.new(0, 0, 0, 2),
				BackgroundTransparency = 1,
				Image = config.Icon,
				ImageColor3 = Theme.Accent,
				Parent = header,
			})
		end

		local textOffset = config.Icon and 26 or 0
		Create("TextLabel", {
			Size = UDim2.new(1, -textOffset, 0, 18),
			Position = UDim2.new(0, textOffset, 0, 0),
			BackgroundTransparency = 1,
			Text = config.Title,
			TextColor3 = Theme.Text,
			Font = Enum.Font.GothamBold,
			TextSize = titleSize,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = header,
		})

		if config.Subtitle then
			Create("TextLabel", {
				Size = UDim2.new(1, -textOffset, 0, 14),
				Position = UDim2.new(0, textOffset, 0, 19),
				BackgroundTransparency = 1,
				Text = config.Subtitle,
				TextColor3 = Theme.TextDim,
				Font = Enum.Font.Gotham,
				TextSize = subSize,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = header,
			})
		end
	end

	return section
end

-- ====================== BUTTON ======================
function UIModule:CreateButton(section, config)
	config = config or {}
	local textSize = ResolveFontSize(config, Typography.Primary)

	local btn = Create("TextButton", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Theme.Dropdown,
		Text = config.Name or "Button",
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamMedium,
		TextSize = textSize,
		AutoButtonColor = false,
		Parent = section,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = btn })
	Create("UIStroke", { Color = Theme.Border, Thickness = 1, Parent = btn })

	btn.MouseEnter:Connect(function() Tween(btn, { BackgroundColor3 = Theme.AccentDark }) end)
	btn.MouseLeave:Connect(function() Tween(btn, { BackgroundColor3 = Theme.Dropdown }) end)
	btn.MouseButton1Click:Connect(function()
		Tween(btn, { TextSize = textSize - 1 }, 0.05).Completed:Connect(function()
			Tween(btn, { TextSize = textSize }, 0.05)
		end)
		if config.Callback then
			config.Callback()
		end
	end)
	return btn
end

-- ====================== TOGGLE ======================
function UIModule:CreateToggle(section, config)
	config = config or {}
	local flag = config.Flag or config.Name or "Toggle"
	local default = config.Default or false
	self.Flags[flag] = default

	local titleSize = ResolveFontSize(config, Typography.Primary)
	local subSize = ResolveFontSize({ TextSize = config.DescSize, Importance = config.DescImportance }, Typography.Compact)
	local hasDesc = config.Description ~= nil

	local row = Create("TextButton", {
		Size = UDim2.new(1, 0, 0, hasDesc and 44 or 32),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = section,
	})

	Create("TextLabel", {
		Size = UDim2.new(1, -55, 0, hasDesc and 18 or 32),
		Position = UDim2.new(0, 0, 0, hasDesc and 2 or 0),
		BackgroundTransparency = 1,
		Text = config.Name or "Toggle",
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamMedium,
		TextSize = titleSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})

	if hasDesc then
		Create("TextLabel", {
			Size = UDim2.new(1, -55, 0, 16),
			Position = UDim2.new(0, 0, 0, 22),
			BackgroundTransparency = 1,
			Text = config.Description,
			TextColor3 = Theme.TextDim,
			Font = Enum.Font.Gotham,
			TextSize = subSize,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
	end

	local track = Create("Frame", {
		Size = UDim2.new(0, 42, 0, 22),
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = default and Theme.Accent or Theme.ToggleOff,
		Parent = row,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })
	local trackGradient = ApplyGradient(track, Theme.Accent, Theme.AccentDark)
	trackGradient.Enabled = default

	local knob = Create("Frame", {
		Size = UDim2.new(0, 16, 0, 16),
		Position = default and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = track,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })

	local function SetState(state)
		self.Flags[flag] = state
		trackGradient.Enabled = state
		Tween(track, { BackgroundColor3 = state and Theme.Accent or Theme.ToggleOff })
		Tween(knob, { Position = state and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) })
		if config.Callback then
			config.Callback(state)
		end
	end

	row.MouseButton1Click:Connect(function()
		SetState(not self.Flags[flag])
	end)

	return { Set = SetState, Get = function() return self.Flags[flag] end }
end

-- ====================== SLIDER ======================
function UIModule:CreateSlider(section, config)
	config = config or {}
	local flag = config.Flag or config.Name or "Slider"
	local min = config.Min or 0
	local max = config.Max or 100
	if max <= min then max = min + 1 end
	local default = math.clamp(config.Default or min, min, max)
	self.Flags[flag] = default

	local titleSize = ResolveFontSize(config, Typography.Primary)
	local valSize = ResolveFontSize({ TextSize = config.ValueSize, Importance = config.ValueImportance }, Typography.Secondary)

	local row = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundTransparency = 1,
		Parent = section,
	})

	Create("TextLabel", {
		Size = UDim2.new(0.7, 0, 0, 18),
		BackgroundTransparency = 1,
		Text = config.Name or "Slider",
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamMedium,
		TextSize = titleSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})

	local valueLabel = Create("TextLabel", {
		Size = UDim2.new(0.3, 0, 0, 18),
		Position = UDim2.new(0.7, 0, 0, 0),
		BackgroundTransparency = 1,
		Text = tostring(default) .. (config.Suffix or ""),
		TextColor3 = Theme.TextDim,
		Font = Enum.Font.Gotham,
		TextSize = valSize,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row,
	})

	local track = Create("TextButton", {
		Size = UDim2.new(1, 0, 0, 8),
		Position = UDim2.new(0, 0, 1, -12),
		BackgroundColor3 = Theme.SliderTrack,
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Parent = row,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })

	local pct = (default - min) / (max - min)

	local fill = Create("Frame", {
		Size = UDim2.new(pct, 0, 1, 0),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Parent = track,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })
	ApplyGradient(fill, Theme.Accent, Theme.AccentDark)

	local knob = Create("Frame", {
		Size = UDim2.new(0, 14, 0, 14),
		Position = UDim2.new(pct, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = track,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })

	local function UpdateFromX(posX)
		local rel = math.clamp((posX - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		local val = min + rel * (max - min)
		if config.Increment then
			val = math.floor((val / config.Increment) + 0.5) * config.Increment
		else
			val = math.floor(val * 10) / 10
		end
		val = math.clamp(val, min, max)
		self.Flags[flag] = val

		local percent = (val - min) / (max - min)
		Tween(fill, { Size = UDim2.new(percent, 0, 1, 0) }, 0.08)
		Tween(knob, { Position = UDim2.new(percent, 0, 0.5, 0) }, 0.08)

		valueLabel.Text = tostring(val) .. (config.Suffix or "")
		if config.Callback then
			config.Callback(val)
		end
	end

	local dragging = false
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			UpdateFromX(input.Position.X)
		end
	end)

	local moveConn = UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			UpdateFromX(input.Position.X)
		end
	end)

	local endConn = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	row.Destroying:Connect(function()
		moveConn:Disconnect()
		endConn:Disconnect()
	end)

	return {
		Set = function(v)
			v = math.clamp(v, min, max)
			self.Flags[flag] = v
			local percent = (v - min) / (max - min)
			fill.Size = UDim2.new(percent, 0, 1, 0)
			knob.Position = UDim2.new(percent, 0, 0.5, 0)
			valueLabel.Text = tostring(v) .. (config.Suffix or "")
			if config.Callback then config.Callback(v) end
		end,
		Get = function() return self.Flags[flag] end,
	}
end

-- ====================== REAL EXPANDING DROPDOWN ======================
function UIModule:CreateDropdown(section, config)
	config = config or {}
	local flag = config.Flag or config.Name or "Dropdown"
	local options = config.Options or { "Option 1", "Option 2" }
	local default = config.Default or options[1]
	self.Flags[flag] = default

	local titleSize = ResolveFontSize(config, Typography.Primary)
	local itemSize = ResolveFontSize({ TextSize = config.ItemSize, Importance = config.ItemImportance }, Typography.Secondary)

	local container = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 36),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = section,
	})

	local header = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		Parent = container,
	})

	Create("TextLabel", {
		Size = UDim2.new(0.4, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = config.Name or "Dropdown",
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamMedium,
		TextSize = titleSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	})

	local box = Create("TextButton", {
		Size = UDim2.new(0.58, 0, 0, 30),
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Theme.Dropdown,
		Text = "   " .. default,
		TextColor3 = Theme.Text,
		Font = Enum.Font.Gotham,
		TextSize = itemSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutoButtonColor = false,
		Parent = header,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = box })
	Create("UIStroke", { Color = Theme.Border, Thickness = 1, Parent = box })

	local arrow = Create("ImageLabel", {
		Size = UDim2.new(0, 16, 0, 16),
		Position = UDim2.new(1, -22, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Image = Icons.Dropdown,
		ImageColor3 = Theme.TextDim,
		Parent = box,
	})

	local listFrame = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		Position = UDim2.new(0, 0, 0, 40),
		BackgroundColor3 = Theme.Dropdown,
		BorderSizePixel = 0,
		Visible = false,
		ClipsDescendants = true,
		Parent = container,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = listFrame })
	Create("UIStroke", { Color = Theme.Border, Thickness = 1, Parent = listFrame })

	local listLayout = Create("UIListLayout", {
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = listFrame,
	})
	Create("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 4),
		Parent = listFrame,
	})

	local isOpen = false
	local function Populate()
		for _, child in ipairs(listFrame:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end

		for _, opt in ipairs(options) do
			local itemBtn = Create("TextButton", {
				Size = UDim2.new(1, 0, 0, 26),
				BackgroundColor3 = (opt == self.Flags[flag]) and Theme.AccentDark or Theme.Dropdown,
				BackgroundTransparency = (opt == self.Flags[flag]) and 0.4 or 1,
				Text = "   " .. tostring(opt),
				TextColor3 = (opt == self.Flags[flag]) and Theme.Text or Theme.TextDim,
				Font = Enum.Font.Gotham,
				TextSize = itemSize,
				TextXAlignment = Enum.TextXAlignment.Left,
				AutoButtonColor = false,
				Parent = listFrame,
			})
			Create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = itemBtn })

			itemBtn.MouseEnter:Connect(function()
				if opt ~= self.Flags[flag] then
					Tween(itemBtn, { BackgroundTransparency = 0.8, TextColor3 = Theme.Text })
				end
			end)
			itemBtn.MouseLeave:Connect(function()
				if opt ~= self.Flags[flag] then
					Tween(itemBtn, { BackgroundTransparency = 1, TextColor3 = Theme.TextDim })
				end
			end)
			itemBtn.MouseButton1Click:Connect(function()
				self.Flags[flag] = opt
				box.Text = "   " .. tostring(opt)
				isOpen = false
				Tween(arrow, { Rotation = 0 }, 0.15)
				listFrame.Visible = false
				Populate()
				if config.Callback then
					config.Callback(opt)
				end
			end)
		end
		listFrame.Size = UDim2.new(1, 0, 0, #options * 28 + 8)
	end

	Populate()

	box.MouseButton1Click:Connect(function()
		isOpen = not isOpen
		listFrame.Visible = isOpen
		Tween(arrow, { Rotation = isOpen and 180 or 0 }, 0.2)
	end)

	return {
		Set = function(v)
			self.Flags[flag] = v
			box.Text = "   " .. tostring(v)
			Populate()
			if config.Callback then config.Callback(v) end
		end,
		Get = function() return self.Flags[flag] end,
		Refresh = function(newOpts)
			options = newOpts or options
			Populate()
		end,
	}
end

-- ====================== CHECKBOX ======================
function UIModule:CreateCheckbox(section, config)
	config = config or {}
	local flag = config.Flag or config.Name or "Checkbox"
	local default = config.Default or false
	self.Flags[flag] = default

	local textSize = ResolveFontSize(config, Typography.Primary)

	local row = Create("TextButton", {
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = section,
	})

	local box = Create("Frame", {
		Size = UDim2.new(0, 20, 0, 20),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = default and Theme.Accent or Theme.ToggleOff,
		BorderSizePixel = 0,
		Parent = row,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = box })
	local boxGradient = ApplyGradient(box, Theme.Accent, Theme.AccentDark)
	boxGradient.Enabled = default

	local checkIcon = Create("ImageLabel", {
		Size = UDim2.new(0, 14, 0, 14),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = Icons.Check,
		ImageColor3 = Color3.new(1, 1, 1),
		ImageTransparency = default and 0 or 1,
		Parent = box,
	})

	Create("TextLabel", {
		Size = UDim2.new(1, -30, 1, 0),
		Position = UDim2.new(0, 30, 0, 0),
		BackgroundTransparency = 1,
		Text = config.Name or "Checkbox",
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamMedium,
		TextSize = textSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})

	local function SetState(state)
		self.Flags[flag] = state
		boxGradient.Enabled = state
		Tween(box, { BackgroundColor3 = state and Theme.Accent or Theme.ToggleOff })
		Tween(checkIcon, { ImageTransparency = state and 0 or 1 })
		if config.Callback then
			config.Callback(state)
		end
	end

	row.MouseButton1Click:Connect(function()
		SetState(not self.Flags[flag])
	end)

	return { Set = SetState, Get = function() return self.Flags[flag] end }
end

-- ====================== LABEL ======================
function UIModule:CreateLabel(section, text, config)
	config = config or {}
	local fontSize = ResolveFontSize(config, Typography.Secondary)

	return Create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Text = text or "",
		TextColor3 = config.Color or Theme.TextDim,
		Font = config.Font or Enum.Font.Gotham,
		TextSize = fontSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Parent = section,
	})
end

return UIModule
