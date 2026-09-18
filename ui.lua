--[[
	ReaperX Style UI Library (Full Version)
	รูปแบบ: Dark / Red Accent / Icons
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local UIModule = {}
UIModule.__index = UIModule

-- ====================== THEME & ICONS ======================
local Theme = {
	Background = Color3.fromRGB(15, 15, 17),
	Sidebar = Color3.fromRGB(20, 20, 23),
	Content = Color3.fromRGB(15, 15, 17),
	Section = Color3.fromRGB(25, 25, 28),
	Border = Color3.fromRGB(35, 35, 40),
	
	Text = Color3.fromRGB(255, 255, 255),
	TextDim = Color3.fromRGB(160, 160, 170),
	
	-- สีหลัก (แดง)
	Accent = Color3.fromRGB(255, 50, 50),
	AccentDark = Color3.fromRGB(180, 20, 20),
	
	-- สีของ Widget ต่างๆ
	ToggleOff = Color3.fromRGB(45, 45, 50),
	SliderTrack = Color3.fromRGB(35, 35, 40),
	Dropdown = Color3.fromRGB(30, 30, 35),
}

-- คลังไอคอนทั้งหมด (Roblox Asset IDs)
UIModule.Icons = {
	-- เมนูซ้าย (Sidebar)
	Swords = "rbxassetid://10747377716",   -- Auto Farm
	Skull = "rbxassetid://10747384022",    -- Auto Raids
	Users = "rbxassetid://10747383281",    -- Auto Party
	Cart = "rbxassetid://10747381958",     -- Auto Sell
	Gift = "rbxassetid://10747378401",     -- Auto Crates
	Bell = "rbxassetid://10747377045",     -- Webhook
	Globe = "rbxassetid://10747378330",    -- Utilities
	Servers = "rbxassetid://10747381285",  -- Servers
	Settings = "rbxassetid://10747383136", -- Settings

	-- ไอคอนในเนื้อหา (Section)
	Star = "rbxassetid://10747383049",     -- Abilities
	Play = "rbxassetid://10747381395",     -- Launch
	Loop = "rbxassetid://10747381023",     -- Loop
	Timer = "rbxassetid://10747382902",    -- Auto Restart
	Search = "rbxassetid://10747381118",   -- Search

	-- UI ทั่วไป
	Close = "rbxassetid://10747384394",
	Dropdown = "rbxassetid://10747384978",
	Check = "rbxassetid://10747376789",
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
	self.Subtitle = config.Subtitle or "Made for Gamers"
	self.Size = config.Size or UDim2.new(0, 800, 0, 500)
	self.Tabs = {}
	self.CurrentTab = nil
	self.Flags = {} 

	-- ScreenGui
	local gui = Create("ScreenGui", {
		Name = "DarkUI",
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

	Create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = main })
	Create("UIStroke", { Color = Theme.Border, Thickness = 1, Parent = main })

	-- ========== TITLE BAR ==========
	local titleBar = Create("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, 50),
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

	-- Title Texts
	local titleLabel = Create("TextLabel", {
		Size = UDim2.new(1, -200, 0, 20),
		Position = UDim2.new(0, 24, 0, 8),
		BackgroundTransparency = 1,
		Text = self.Title,
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = titleBar,
	})
	
	if self.Subtitle ~= "" then
		Create("TextLabel", {
			Size = UDim2.new(1, -200, 0, 14),
			Position = UDim2.new(0, 24, 0, 28),
			BackgroundTransparency = 1,
			Text = self.Subtitle,
			TextColor3 = Theme.TextDim,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = titleBar,
		})
	end

	-- Top Right Icons (Search, Settings, Close)
	local btnList = Create("Frame", {
		Size = UDim2.new(0, 100, 1, 0),
		Position = UDim2.new(1, -110, 0, 0),
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

	local function CreateTopBtn(iconId)
		local btn = Create("ImageButton", {
			Size = UDim2.new(0, 16, 0, 16),
			BackgroundTransparency = 1,
			Image = iconId,
			ImageColor3 = Theme.TextDim,
			Parent = btnList,
		})
		btn.MouseEnter:Connect(function() Tween(btn, { ImageColor3 = Theme.Accent }) end)
		btn.MouseLeave:Connect(function() Tween(btn, { ImageColor3 = Theme.TextDim }) end)
		return btn
	end

	CreateTopBtn(Icons.Settings)
	CreateTopBtn(Icons.Search)
	local closeBtn = CreateTopBtn(Icons.Close)
	closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

	-- ========== SIDEBAR ==========
	local sidebar = Create("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, 200, 1, -50),
		Position = UDim2.new(0, 0, 0, 50),
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
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		Parent = sidebarList,
	})

	-- ========== CONTENT ==========
	local content = Create("Frame", {
		Name = "Content",
		Size = UDim2.new(1, -200, 1, -50),
		Position = UDim2.new(0, 200, 0, 50),
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
		PaddingTop = UDim.new(0, 18),
		PaddingBottom = UDim.new(0, 18),
		PaddingLeft = UDim.new(0, 22),
		PaddingRight = UDim.new(0, 22),
		Parent = contentScroll,
	})

	-- Drag Window Logic
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

-- ====================== TAB & LABEL ======================
-- สร้างป้ายกำกับในแถบด้านซ้าย (เช่น "General", "Utilities")
function UIModule:CreateTabLabel(text)
	Create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		Text = "  " .. text,
		TextColor3 = Theme.TextDim,
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = self.SidebarList,
	})
end

function UIModule:CreateTab(name, iconId)
	local tab = { Name = name, Sections = {} }
	iconId = iconId or Icons.Settings

	local btn = Create("TextButton", {
		Size = UDim2.new(1, 0, 0, 38),
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
		Position = UDim2.new(0, 12, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Image = iconId,
		ImageColor3 = Theme.TextDim,
		Parent = btn,
	})

	local nameLabel = Create("TextLabel", {
		Size = UDim2.new(1, -44, 1, 0),
		Position = UDim2.new(0, 40, 0, 0),
		BackgroundTransparency = 1,
		Text = name,
		TextColor3 = Theme.TextDim,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
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
		Padding = UDim.new(0, 14),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = container,
	})
	tab.Container = container

	btn.MouseButton1Click:Connect(function()
		self:SelectTab(tab)
	end)

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

	-- เลือกแท็บแรกอัตโนมัติเมื่อสร้าง
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
		PaddingTop = UDim.new(0, 14),
		PaddingBottom = UDim.new(0, 14),
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 16),
		Parent = section,
	})
	
	Create("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = section,
	})

	if config.Title then
		local header = Create("Frame", {
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundTransparency = 1,
			Parent = section,
		})
		
		-- ไอคอนหน้า Section
		if config.Icon then
			Create("ImageLabel", {
				Size = UDim2.new(0, 20, 0, 20),
				Position = UDim2.new(0, 0, 0, 8),
				BackgroundTransparency = 1,
				Image = config.Icon,
				ImageColor3 = Theme.Accent,
				Parent = header,
			})
		end
		
		local textOffset = config.Icon and 30 or 0
		
		Create("TextLabel", {
			Size = UDim2.new(1, -textOffset, 0, 18),
			Position = UDim2.new(0, textOffset, 0, 0),
			BackgroundTransparency = 1,
			Text = config.Title,
			TextColor3 = Theme.Text,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = header,
		})
		
		if config.Subtitle then
			Create("TextLabel", {
				Size = UDim2.new(1, -textOffset, 0, 14),
				Position = UDim2.new(0, textOffset, 0, 20),
				BackgroundTransparency = 1,
				Text = config.Subtitle,
				TextColor3 = Theme.TextDim,
				Font = Enum.Font.Gotham,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = header,
			})
		end
	end
	
	return section
end

-- ====================== TOGGLE ======================
function UIModule:CreateToggle(section, config)
	config = config or {}
	local flag = config.Flag or config.Name or "Toggle"
	local default = config.Default or false
	self.Flags[flag] = default

	local row = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		Parent = section,
	})

	Create("TextLabel", {
		Size = UDim2.new(1, -60, 1, 0),
		BackgroundTransparency = 1,
		Text = config.Name or "Toggle",
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})
	
	-- ถ้ารองรับคำอธิบายด้วย (เหมือนในโค้ดเก่า)
	if config.Description then
		Create("TextLabel", {
			Size = UDim2.new(1, -60, 0, 14),
			Position = UDim2.new(0, 0, 0, 18),
			BackgroundTransparency = 1,
			Text = config.Description,
			TextColor3 = Theme.TextDim,
			Font = Enum.Font.Gotham,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		row.Size = UDim2.new(1, 0, 0, 42)
	end

	local track = Create("TextButton", {
		Size = UDim2.new(0, 42, 0, 22),
		Position = UDim2.new(1, -42, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = default and Theme.Accent or Theme.ToggleOff,
		Text = "",
		AutoButtonColor = false,
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

	track.MouseButton1Click:Connect(function()
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
	local default = config.Default or min
	self.Flags[flag] = default

	local row = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 45),
		BackgroundTransparency = 1,
		Parent = section,
	})

	Create("TextLabel", {
		Size = UDim2.new(0.7, 0, 0, 18),
		BackgroundTransparency = 1,
		Text = config.Name or "Slider",
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamMedium,
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
		Position = UDim2.new(0, 0, 1, -10),
		BackgroundColor3 = Theme.SliderTrack,
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
		Size = UDim2.new(0, 12, 0, 12),
		Position = UDim2.new(pct, 0, 0.5, 0),
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
		
		local percent = (val - min) / (max - min)
		Tween(fill, { Size = UDim2.new(percent, 0, 1, 0) }, 0.1)
		Tween(knob, { Position = UDim2.new(percent, 0, 0.5, 0) }, 0.1)
		
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

	return { Set = Update, Get = function() return self.Flags[flag] end }
end

-- ====================== DROPDOWN ======================
function UIModule:CreateDropdown(section, config)
	config = config or {}
	local flag = config.Flag or config.Name or "Dropdown"
	local options = config.Options or { "Option 1" }
	local default = config.Default or options[1]
	self.Flags[flag] = default

	local row = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		Parent = section,
	})

	Create("TextLabel", {
		Size = UDim2.new(0.4, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = config.Name or "Dropdown",
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})

	local box = Create("TextButton", {
		Size = UDim2.new(0.55, 0, 0, 30),
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Theme.Dropdown,
		Text = "   " .. default,
		TextColor3 = Theme.Text,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutoButtonColor = false,
		Parent = row,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = box })
	Create("UIStroke", { Color = Theme.Border, Thickness = 1, Parent = box })
	
	local icon = Create("ImageLabel", {
		Size = UDim2.new(0, 16, 0, 16),
		Position = UDim2.new(1, -24, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Image = Icons.Dropdown,
		ImageColor3 = Theme.TextDim,
		Parent = box,
	})

	local idx = table.find(options, default) or 1
	box.MouseButton1Click:Connect(function()
		idx = idx % #options + 1
		local val = options[idx]
		self.Flags[flag] = val
		box.Text = "   " .. val
		
		-- อนิเมชั่นลูกศรตอนกด
		Tween(icon, { Position = UDim2.new(1, -24, 0.7, 0) }, 0.1).Completed:Connect(function()
			Tween(icon, { Position = UDim2.new(1, -24, 0.5, 0) }, 0.1)
		end)
		
		if config.Callback then
			config.Callback(val)
		end
	end)

	return {
		Set = function(v)
			self.Flags[flag] = v
			box.Text = "   " .. v
		end,
		Get = function() return self.Flags[flag] end
	}
end

-- ====================== CHECKBOX ======================
function UIModule:CreateCheckbox(section, config)
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

	-- เปลี่ยนจาก TextLabel "✓" เป็นไอคอน ImageLabel
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
		TextSize = 13,
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

	box.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			SetState(not self.Flags[flag])
		end
	end)

	return { Set = SetState, Get = function() return self.Flags[flag] end }
end

-- ====================== LABEL ======================
function UIModule:CreateLabel(section, text)
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

return UIModule
