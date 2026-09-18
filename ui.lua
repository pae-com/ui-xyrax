--[[
	MacUI Library - Dark macOS Style
	ใช้งาน: local UI = require(path.to.MacUI)
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local MacUI = {}
MacUI.__index = MacUI

-- Theme
local Theme = {
	Background = Color3.fromRGB(18, 18, 20),
	Sidebar = Color3.fromRGB(22, 22, 25),
	Content = Color3.fromRGB(25, 25, 28),
	Section = Color3.fromRGB(32, 32, 36),
	Border = Color3.fromRGB(45, 45, 50),
	Text = Color3.fromRGB(240, 240, 245),
	TextDim = Color3.fromRGB(160, 160, 170),
	Accent = Color3.fromRGB(220, 50, 50),       -- แดงหลัก
	AccentHover = Color3.fromRGB(255, 70, 70),
	ToggleOn = Color3.fromRGB(220, 50, 50),
	ToggleOff = Color3.fromRGB(60, 60, 65),
	SliderTrack = Color3.fromRGB(50, 50, 55),
	SliderFill = Color3.fromRGB(220, 50, 50),
	Dropdown = Color3.fromRGB(35, 35, 40),
}

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

local function Tween(obj, props, time, style, dir)
	local t = TweenService:Create(obj, TweenInfo.new(time or 0.2, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

-- ====================== WINDOW ======================
function MacUI.new(config)
	config = config or {}
	local self = setmetatable({}, MacUI)

	self.Title = config.Title or "MacUI Window"
	self.Subtitle = config.Subtitle or ""
	self.Size = config.Size or UDim2.new(0, 780, 0, 480)
	self.Tabs = {}
	self.CurrentTab = nil
	self.Flags = {} -- เก็บค่า toggle/slider ฯลฯ

	-- ScreenGui
	local gui = Create("ScreenGui", {
		Name = "MacUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	self.Gui = gui

	-- Main Frame (เหลี่ยม)
	local main = Create("Frame", {
		Name = "Main",
		Size = self.Size,
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		Parent = gui,
	})
	self.Main = main

	-- ขอบบาง ๆ
	Create("UIStroke", {
		Color = Theme.Border,
		Thickness = 1,
		Parent = main,
	})

	-- ========== TITLE BAR ==========
	local titleBar = Create("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundColor3 = Theme.Sidebar,
		BorderSizePixel = 0,
		Parent = main,
	})

	-- เส้นล่าง title bar
	Create("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, -1),
		BackgroundColor3 = Theme.Border,
		BorderSizePixel = 0,
		Parent = titleBar,
	})

	-- 3 จุด macOS
	local dots = Create("Frame", {
		Size = UDim2.new(0, 60, 0, 14),
		Position = UDim2.new(0, 14, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Parent = titleBar,
	})

	local colors = {
		Color3.fromRGB(255, 95, 87),   -- แดง
		Color3.fromRGB(255, 189, 46),  -- เหลือง
		Color3.fromRGB(40, 200, 64),   -- เขียว
	}
	for i, c in ipairs(colors) do
		local dot = Create("Frame", {
			Size = UDim2.new(0, 12, 0, 12),
			Position = UDim2.new(0, (i-1)*20, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = c,
			BorderSizePixel = 0,
			Parent = dots,
		})
		Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = dot })
	end

	-- Title
	local titleLabel = Create("TextLabel", {
		Size = UDim2.new(1, -200, 1, 0),
		Position = UDim2.new(0, 80, 0, 0),
		BackgroundTransparency = 1,
		Text = self.Title,
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = titleBar,
	})
	self.TitleLabel = titleLabel

	-- Subtitle (เล็กกว่า)
	if self.Subtitle ~= "" then
		Create("TextLabel", {
			Size = UDim2.new(0, 200, 0, 14),
			Position = UDim2.new(0, 80, 0, 22),
			BackgroundTransparency = 1,
			Text = self.Subtitle,
			TextColor3 = Theme.TextDim,
			Font = Enum.Font.Gotham,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = titleBar,
		})
	end

	-- ปุ่มขวาบน (ปิด)
	local closeBtn = Create("TextButton", {
		Size = UDim2.new(0, 32, 0, 32),
		Position = UDim2.new(1, -38, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Text = "✕",
		TextColor3 = Theme.TextDim,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		Parent = titleBar,
	})
	closeBtn.MouseEnter:Connect(function()
		Tween(closeBtn, { TextColor3 = Theme.Accent })
	end)
	closeBtn.MouseLeave:Connect(function()
		Tween(closeBtn, { TextColor3 = Theme.TextDim })
	end)
	closeBtn.MouseButton1Click:Connect(function()
		gui:Destroy()
	end)

	-- ========== SIDEBAR ==========
	local sidebar = Create("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, 180, 1, -38),
		Position = UDim2.new(0, 0, 0, 38),
		BackgroundColor3 = Theme.Sidebar,
		BorderSizePixel = 0,
		Parent = main,
	})
	self.Sidebar = sidebar

	-- เส้นขวา sidebar
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
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Border,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = sidebar,
	})
	Create("UIListLayout", {
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = sidebarList,
	})
	Create("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = sidebarList,
	})
	self.SidebarList = sidebarList

	-- ========== CONTENT ==========
	local content = Create("Frame", {
		Name = "Content",
		Size = UDim2.new(1, -180, 1, -38),
		Position = UDim2.new(0, 180, 0, 38),
		BackgroundColor3 = Theme.Content,
		BorderSizePixel = 0,
		Parent = main,
	})
	self.Content = content

	local contentScroll = Create("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.Border,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = content,
	})
	Create("UIListLayout", {
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = contentScroll,
	})
	Create("UIPadding", {
		PaddingTop = UDim.new(0, 16),
		PaddingBottom = UDim.new(0, 16),
		PaddingLeft = UDim.new(0, 18),
		PaddingRight = UDim.new(0, 18),
		Parent = contentScroll,
	})
	self.ContentScroll = contentScroll

	-- Drag Window
	local dragging, dragStart, startPos
	titleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			startPos = main.Position
		end
	end)
	titleBar.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - dragStart
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)

	return self
end

-- ====================== TAB ======================
function MacUI:CreateTab(name, icon)
	local tab = {
		Name = name,
		Icon = icon or "●",
		Sections = {},
		Container = nil,
	}

	-- Sidebar Button
	local btn = Create("TextButton", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Theme.Sidebar,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = self.SidebarList,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = btn })

	local iconLabel = Create("TextLabel", {
		Size = UDim2.new(0, 28, 1, 0),
		Position = UDim2.new(0, 6, 0, 0),
		BackgroundTransparency = 1,
		Text = tab.Icon,
		TextColor3 = Theme.TextDim,
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		Parent = btn,
	})

	local nameLabel = Create("TextLabel", {
		Size = UDim2.new(1, -40, 1, 0),
		Position = UDim2.new(0, 34, 0, 0),
		BackgroundTransparency = 1,
		Text = name,
		TextColor3 = Theme.TextDim,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = btn,
	})

	-- Highlight bar ซ้าย
	local highlight = Create("Frame", {
		Size = UDim2.new(0, 3, 0.6, 0),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Visible = false,
		Parent = btn,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = highlight })

	-- Container ของ tab นี้
	local container = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = false,
		Parent = self.ContentScroll,
	})
	Create("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = container,
	})
	tab.Container = container

	btn.MouseButton1Click:Connect(function()
		self:SelectTab(tab)
	end)

	btn.MouseEnter:Connect(function()
		if self.CurrentTab ~= tab then
			Tween(btn, { BackgroundTransparency = 0.7 })
			Tween(nameLabel, { TextColor3 = Theme.Text })
		end
	end)
	btn.MouseLeave:Connect(function()
		if self.CurrentTab ~= tab then
			Tween(btn, { BackgroundTransparency = 1 })
			Tween(nameLabel, { TextColor3 = Theme.TextDim })
		end
	end)

	tab.Button = btn
	tab.Highlight = highlight
	tab.NameLabel = nameLabel
	tab.IconLabel = iconLabel

	table.insert(self.Tabs, tab)

	-- เลือกแท็บแรกอัตโนมัติ
	if #self.Tabs == 1 then
		self:SelectTab(tab)
	end

	return tab
end

function MacUI:SelectTab(tab)
	for _, t in ipairs(self.Tabs) do
		t.Container.Visible = false
		t.Highlight.Visible = false
		t.Button.BackgroundTransparency = 1
		t.NameLabel.TextColor3 = Theme.TextDim
		t.IconLabel.TextColor3 = Theme.TextDim
	end

	tab.Container.Visible = true
	tab.Highlight.Visible = true
	tab.Button.BackgroundTransparency = 0.85
	tab.Button.BackgroundColor3 = Theme.Accent
	tab.NameLabel.TextColor3 = Theme.Text
	tab.IconLabel.TextColor3 = Theme.Accent

	self.CurrentTab = tab
end

-- ====================== SECTION ======================
function MacUI:CreateSection(tab, title)
	local section = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Section,
		BorderSizePixel = 0,
		Parent = tab.Container,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = section })
	Create("UIStroke", {
		Color = Theme.Border,
		Thickness = 1,
		Parent = section,
	})
	Create("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
		Parent = section,
	})
	Create("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = section,
	})

	if title and title ~= "" then
		Create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
			Text = title,
			TextColor3 = Theme.Text,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = section,
		})
	end

	return section
end

-- ====================== TOGGLE ======================
function MacUI:CreateToggle(section, config)
	config = config or {}
	local flag = config.Flag or config.Name or "Toggle"
	local default = config.Default or false
	self.Flags[flag] = default

	local row = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		Parent = section,
	})

	Create("TextLabel", {
		Size = UDim2.new(1, -60, 1, 0),
		BackgroundTransparency = 1,
		Text = config.Name or "Toggle",
		TextColor3 = Theme.Text,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})

	if config.Description then
		Create("TextLabel", {
			Size = UDim2.new(1, -60, 0, 14),
			Position = UDim2.new(0, 0, 0, 16),
			BackgroundTransparency = 1,
			Text = config.Description,
			TextColor3 = Theme.TextDim,
			Font = Enum.Font.Gotham,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		row.Size = UDim2.new(1, 0, 0, 40)
	end

	-- Toggle switch
	local track = Create("Frame", {
		Size = UDim2.new(0, 42, 0, 24),
		Position = UDim2.new(1, -42, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = default and Theme.ToggleOn or Theme.ToggleOff,
		BorderSizePixel = 0,
		Parent = row,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })

	local knob = Create("Frame", {
		Size = UDim2.new(0, 18, 0, 18),
		Position = default and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = track,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })

	local function SetState(state)
		self.Flags[flag] = state
		Tween(track, { BackgroundColor3 = state and Theme.ToggleOn or Theme.ToggleOff })
		Tween(knob, { Position = state and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) })
		if config.Callback then
			config.Callback(state)
		end
	end

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			SetState(not self.Flags[flag])
		end
	end)

	return {
		Set = SetState,
		Get = function() return self.Flags[flag] end,
	}
end

-- ====================== SLIDER ======================
function MacUI:CreateSlider(section, config)
	config = config or {}
	local flag = config.Flag or config.Name or "Slider"
	local min, max = config.Min or 0, config.Max or 100
	local default = config.Default or min
	self.Flags[flag] = default

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
		Font = Enum.Font.Gotham,
		TextSize = 13,
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
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row,
	})

	local track = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 6),
		Position = UDim2.new(0, 0, 0, 28),
		BackgroundColor3 = Theme.SliderTrack,
		BorderSizePixel = 0,
		Parent = row,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })

	local fill = Create("Frame", {
		Size = UDim2.new((default - min) / (max - min), 0, 1, 0),
		BackgroundColor3 = Theme.SliderFill,
		BorderSizePixel = 0,
		Parent = track,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })

	local knob = Create("Frame", {
		Size = UDim2.new(0, 14, 0, 14),
		Position = UDim2.new((default - min) / (max - min), 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = track,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })

	local dragging = false
	local function Update(val)
		val = math.clamp(val, min, max)
		if config.Increment then
			val = math.floor(val / config.Increment + 0.5) * config.Increment
		end
		self.Flags[flag] = val
		local pct = (val - min) / (max - min)
		fill.Size = UDim2.new(pct, 0, 1, 0)
		knob.Position = UDim2.new(pct, 0, 0.5, 0)
		valueLabel.Text = tostring(val) .. (config.Suffix or "")
		if config.Callback then
			config.Callback(val)
		end
	end

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local rel = (input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X
			Update(min + rel * (max - min))
		end
	end)

	return {
		Set = Update,
		Get = function() return self.Flags[flag] end,
	}
end

-- ====================== DROPDOWN ======================
function MacUI:CreateDropdown(section, config)
	config = config or {}
	local flag = config.Flag or config.Name or "Dropdown"
	local options = config.Options or { "Option 1", "Option 2" }
	local default = config.Default or options[1]
	self.Flags[flag] = default

	local row = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		Parent = section,
	})

	Create("TextLabel", {
		Size = UDim2.new(0.4, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = config.Name or "Dropdown",
		TextColor3 = Theme.Text,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})

	local box = Create("TextButton", {
		Size = UDim2.new(0.55, 0, 0, 28),
		Position = UDim2.new(0.45, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.Dropdown,
		Text = default .. "  ▼",
		TextColor3 = Theme.Text,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		AutoButtonColor = false,
		Parent = row,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = box })
	Create("UIStroke", { Color = Theme.Border, Thickness = 1, Parent = box })

	-- (Dropdown list แบบง่าย — กดแล้วสลับค่าไปเรื่อย ๆ)
	local idx = table.find(options, default) or 1
	box.MouseButton1Click:Connect(function()
		idx = idx % #options + 1
		local val = options[idx]
		self.Flags[flag] = val
		box.Text = val .. "  ▼"
		if config.Callback then
			config.Callback(val)
		end
	end)

	return {
		Set = function(v)
			self.Flags[flag] = v
			box.Text = v .. "  ▼"
		end,
		Get = function() return self.Flags[flag] end,
	}
end

-- ====================== CHECKBOX ======================
function MacUI:CreateCheckbox(section, config)
	config = config or {}
	local flag = config.Flag or config.Name or "Checkbox"
	local default = config.Default or false
	self.Flags[flag] = default

	local row = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		Parent = section,
	})

	local box = Create("Frame", {
		Size = UDim2.new(0, 18, 0, 18),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = default and Theme.Accent or Theme.ToggleOff,
		BorderSizePixel = 0,
		Parent = row,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = box })

	local check = Create("TextLabel", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = default and "✓" or "",
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		Parent = box,
	})

	Create("TextLabel", {
		Size = UDim2.new(1, -28, 1, 0),
		Position = UDim2.new(0, 26, 0, 0),
		BackgroundTransparency = 1,
		Text = config.Name or "Checkbox",
		TextColor3 = Theme.Text,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})

	local function SetState(state)
		self.Flags[flag] = state
		box.BackgroundColor3 = state and Theme.Accent or Theme.ToggleOff
		check.Text = state and "✓" or ""
		if config.Callback then
			config.Callback(state)
		end
	end

	box.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			SetState(not self.Flags[flag])
		end
	end)

	return { Set = SetState, Get = function() return self.Flags[flag] end }
end

-- ====================== LABEL ======================
function MacUI:CreateLabel(section, text)
	return Create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Text = text or "",
		TextColor3 = Theme.TextDim,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Parent = section,
	})
end

return MacUI