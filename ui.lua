--[[
	ReaperX UI Library (Complete All-in-One Edition)
	- Widgets: Toggles, Sliders, Dropdowns, Text Inputs, Buttons, Checkboxes
	- WindUI 1,500+ Lucide Icons Integration (Footagesus/WindUI)
	- Toast Notifications (Window:Notify)
	- Ambient Crimson Dot Close Button (No 'X')
	- Spring/Exponential Transitions & Corner Resizing (◢)
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local UIModule = {}
UIModule.__index = UIModule

local Theme = {
	Background  = Color3.fromRGB(14, 14, 17),
	Sidebar     = Color3.fromRGB(19, 19, 23),
	Content     = Color3.fromRGB(14, 14, 17),
	Section     = Color3.fromRGB(22, 22, 27),
	ModalBg     = Color3.fromRGB(18, 18, 22),
	Border      = Color3.fromRGB(38, 38, 44),

	Text        = Color3.fromRGB(255, 255, 255),
	TextDim     = Color3.fromRGB(150, 150, 160),

	Accent      = Color3.fromRGB(255, 50, 50),
	AccentDark  = Color3.fromRGB(180, 20, 20),

	ToggleOff   = Color3.fromRGB(42, 42, 48),
	SliderTrack = Color3.fromRGB(32, 32, 38),
	Dropdown    = Color3.fromRGB(28, 28, 34),
	CloseDot    = Color3.fromRGB(80, 25, 25),
}

-- ====================== WINDUI ICON SYSTEM ======================
local WindUIIcons = {}
pcall(function()
	local raw = game:HttpGet("https://raw.githubusercontent.com/Footagesus/Icons/refs/heads/main/lucide/dist/Icons.lua")
	WindUIIcons = loadstring(raw)()
end)

local FallbackIcons = {
	["swords"]    = "rbxassetid://10747377716",
	["skull"]     = "rbxassetid://10747384022",
	["cart"]      = "rbxassetid://10747381958",
	["globe"]     = "rbxassetid://10747378330",
	["settings"]  = "rbxassetid://10747383136",
	["shield"]    = "rbxassetid://10747382404",
	["bell"]      = "rbxassetid://10747377045",
	["star"]      = "rbxassetid://10747383049",
	["play"]      = "rbxassetid://10747381395",
	["check"]     = "rbxassetid://10747376789",
	["zap"]       = "rbxassetid://10747384501",
	["flame"]     = "rbxassetid://10747378135",
	["copy"]      = "rbxassetid://10747377488",
	["trash"]     = "rbxassetid://10747383471",
	["dropdown"]  = "rbxassetid://10747384978",
}

function UIModule:GetIcon(iconName)
	if not iconName or iconName == "" then return nil end
	local str = tostring(iconName)
	if string.find(str, "rbxassetid://") or string.find(str, "rbxthumb://") then return str end
	local num = str:match("^%d+$")
	if num then return "rbxthumb://type=Asset&id=" .. num .. "&w=150&h=150" end
	local cleanName = string.lower(str):gsub("%s+", "-")
	if WindUIIcons and WindUIIcons[cleanName] then return WindUIIcons[cleanName] end
	return FallbackIcons[cleanName] or FallbackIcons[cleanName:gsub("-", "")] or nil
end

local function Create(class, props)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then inst[k] = v end
	end
	if props and props.Parent then inst.Parent = props.Parent end
	return inst
end

local function TweenExp(obj, props, duration)
	local t = TweenService:Create(obj, TweenInfo.new(duration or 0.25, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), props)
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

function UIModule.new(config)
	config = config or {}
	local self = setmetatable({}, UIModule)

	self.Title = config.Title or "ReaperX"
	self.Subtitle = config.Subtitle or "Premium Script Hub"
	self.Size = config.Size or UDim2.new(0, 800, 0, 500)
	self.MinSize = config.MinSize or Vector2.new(520, 340)
	self.MaxSize = config.MaxSize or Vector2.new(1200, 850)
	self.Tabs = {}
	self.CurrentTab = nil
	self.Flags = {}

	local gui = Create("ScreenGui", {
		Name = "ReaperX_Hub",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	self.Gui = gui

	-- Notification Toast Container
	local notifContainer = Create("Frame", {
		Name = "Notifications",
		Size = UDim2.new(0, 300, 1, -20),
		Position = UDim2.new(1, -310, 0, 10),
		BackgroundTransparency = 1,
		ZIndex = 100,
		Parent = gui,
	})
	Create("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 8), Parent = notifContainer })
	self.NotifContainer = notifContainer

	-- Main Window Frame
	local main = Create("Frame", {
		Name = "Main",
		Size = self.Size,
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Active = true,
		Parent = gui,
	})
	self.Main = main

	Create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = main })
	Create("UIStroke", { Color = Theme.Border, Thickness = 1.2, Parent = main })

	UserInputService.InputBegan:Connect(function(input, gpe)
		if not gpe and input.KeyCode == (config.ToggleKey or Enum.KeyCode.RightControl) then
			main.Visible = not main.Visible
		end
	end)

	-- Title Bar
	local titleBar = Create("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = Theme.Sidebar,
		BorderSizePixel = 0,
		Active = true,
		Parent = main,
	})
	Create("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, -1),
		BackgroundColor3 = Theme.Border,
		BorderSizePixel = 0,
		Parent = titleBar,
	})

	-- Emblem [R]
	local emblem = Create("Frame", {
		Size = UDim2.new(0, 30, 0, 30),
		Position = UDim2.new(0, 14, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Parent = titleBar,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 7), Parent = emblem })
	ApplyGradient(emblem, Theme.Accent, Theme.AccentDark)

	Create("TextLabel", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = "R",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		Parent = emblem,
	})

	local titleRow = Create("Frame", {
		Size = UDim2.new(1, -150, 0, 20),
		Position = UDim2.new(0, 52, 0, 8),
		BackgroundTransparency = 1,
		Parent = titleBar,
	})

	local titleLbl = Create("TextLabel", {
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Text = self.Title,
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = titleRow,
	})

	local proBadge = Create("Frame", {
		Size = UDim2.new(0, 34, 0, 16),
		Position = UDim2.new(1, 8, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.AccentDark,
		BackgroundTransparency = 0.3,
		Parent = titleLbl,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = proBadge })
	Create("UIStroke", { Color = Theme.Accent, Thickness = 0.8, Parent = proBadge })

	Create("TextLabel", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = "PRO",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Font = Enum.Font.GothamBold,
		TextSize = 9,
		Parent = proBadge,
	})

	Create("TextLabel", {
		Size = UDim2.new(1, -150, 0, 16),
		Position = UDim2.new(0, 52, 0, 28),
		BackgroundTransparency = 1,
		Text = self.Subtitle,
		TextColor3 = Theme.TextDim,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = titleBar,
	})

	-- Ambient Crimson Dot (Close Button)
	local closeBtn = Create("TextButton", {
		Size = UDim2.new(0, 24, 0, 24),
		Position = UDim2.new(1, -14, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = titleBar,
	})

	local closeDot = Create("Frame", {
		Size = UDim2.new(0, 12, 0, 12),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.CloseDot,
		BorderSizePixel = 0,
		Parent = closeBtn,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = closeDot })
	local dotStroke = Create("UIStroke", { Color = Theme.Accent, Thickness = 1, Transparency = 0.4, Parent = closeDot })

	closeBtn.MouseEnter:Connect(function()
		TweenExp(closeDot, { Size = UDim2.new(0, 14, 0, 14), BackgroundColor3 = Theme.Accent }, 0.2)
		TweenExp(dotStroke, { Transparency = 0 }, 0.2)
	end)
	closeBtn.MouseLeave:Connect(function()
		TweenExp(closeDot, { Size = UDim2.new(0, 12, 0, 12), BackgroundColor3 = Theme.CloseDot }, 0.2)
		TweenExp(dotStroke, { Transparency = 0.4 }, 0.2)
	end)
	closeBtn.MouseButton1Click:Connect(function()
		TweenExp(closeDot, { Size = UDim2.new(0, 4, 0, 4) }, 0.1).Completed:Connect(function()
			gui:Destroy()
		end)
	end)

	-- Sidebar
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

	Create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = sidebarList })
	Create("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = sidebarList })

	-- Content
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

	Create("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder, Parent = contentScroll })
	Create("UIPadding", { PaddingTop = UDim.new(0, 16), PaddingBottom = UDim.new(0, 24), PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18), Parent = contentScroll })

	-- Window Dragging Logic
	local dragging, dragInput, dragStart, startPos
	titleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = main.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)

	titleBar.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			local delta = input.Position - dragStart
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	-- Corner Resize Handle (Bottom-Right)
	local resizeHandle = Create("TextButton", {
		Name = "ResizeCorner",
		Size = UDim2.new(0, 20, 0, 20),
		Position = UDim2.new(1, 0, 1, 0),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		Text = "◢",
		TextColor3 = Theme.TextDim,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		ZIndex = 20,
		Active = true,
		Parent = main,
	})

	local resizing = false
	local rStartPos, rStartSize, rCenterPos

	resizeHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			resizing = true
			rStartPos = input.Position
			rStartSize = main.AbsoluteSize
			rCenterPos = main.Position
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			resizing = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - rStartPos
			local newW = math.clamp(rStartSize.X + delta.X, self.MinSize.X, self.MaxSize.X)
			local newH = math.clamp(rStartSize.Y + delta.Y, self.MinSize.Y, self.MaxSize.Y)

			main.Size = UDim2.new(0, newW, 0, newH)
			main.Position = UDim2.new(
				rCenterPos.X.Scale,
				rCenterPos.X.Offset + ((newW - rStartSize.X) / 2),
				rCenterPos.Y.Scale,
				rCenterPos.Y.Offset + ((newH - rStartSize.Y) / 2)
			)
		end
	end)

	return self
end

-- ====================== TOAST NOTIFICATIONS ======================
function UIModule:Notify(config)
	config = config or {}
	local title = config.Title or "Notification"
	local content = config.Content or ""
	local duration = config.Duration or 3

	local toast = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 60),
		Position = UDim2.new(1, 40, 0, 0),
		BackgroundColor3 = Theme.ModalBg,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = self.NotifContainer,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = toast })
	Create("UIStroke", { Color = Theme.Border, Thickness = 1.2, Parent = toast })

	Create("TextLabel", {
		Size = UDim2.new(1, -20, 0, 18),
		Position = UDim2.new(0, 12, 0, 10),
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = toast,
	})

	Create("TextLabel", {
		Size = UDim2.new(1, -20, 0, 16),
		Position = UDim2.new(0, 12, 0, 30),
		BackgroundTransparency = 1,
		Text = content,
		TextColor3 = Theme.TextDim,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = toast,
	})

	local timerBar = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 2),
		Position = UDim2.new(0, 0, 1, -2),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Parent = toast,
	})

	TweenExp(toast, { Position = UDim2.new(0, 0, 0, 0) }, 0.3)
	TweenService:Create(timerBar, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) }):Play()

	task.delay(duration, function()
		TweenExp(toast, { Position = UDim2.new(1, 40, 0, 0) }, 0.25).Completed:Connect(function()
			toast:Destroy()
		end)
	end)
end

-- ====================== TABS ======================
function UIModule:CreateTabLabel(text)
	Create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Text = "  " .. text:upper(),
		TextColor3 = Theme.TextDim,
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = self.SidebarList,
	})
end

function UIModule:CreateTab(name, icon)
	local tab = { Name = name }
	local resolvedIcon = self:GetIcon(icon)

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

	local indicator = Create("Frame", {
		Size = UDim2.new(0, 3, 0, 0),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Parent = btn,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = indicator })

	local iconImg
	local textStart = 14
	if resolvedIcon then
		textStart = 36
		iconImg = Create("ImageLabel", {
			Size = UDim2.new(0, 16, 0, 16),
			Position = UDim2.new(0, 12, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			Image = resolvedIcon,
			ImageColor3 = Theme.TextDim,
			Parent = btn,
		})
	end

	local nameLabel = Create("TextLabel", {
		Size = UDim2.new(1, -(textStart + 8), 1, 0),
		Position = UDim2.new(0, textStart, 0, 0),
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
	Create("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = container })

	tab.Container = container
	tab.Button = btn
	tab.Gradient = btnGradient
	tab.NameLabel = nameLabel
	tab.Indicator = indicator
	tab.IconImg = iconImg

	btn.MouseButton1Click:Connect(function()
		TweenExp(btn, { Size = UDim2.new(1, -4, 0, 34) }, 0.08).Completed:Connect(function()
			TweenExp(btn, { Size = UDim2.new(1, 0, 0, 36) }, 0.12)
		end)
		self:SelectTab(tab)
	end)

	btn.MouseEnter:Connect(function()
		if self.CurrentTab ~= tab then
			TweenExp(btn, { BackgroundTransparency = 0.92 }, 0.15)
			TweenExp(nameLabel, { TextColor3 = Theme.Text }, 0.15)
			if iconImg then TweenExp(iconImg, { ImageColor3 = Theme.Text }, 0.15) end
			TweenExp(indicator, { Size = UDim2.new(0, 3, 0, 12) }, 0.15)
		end
	end)

	btn.MouseLeave:Connect(function()
		if self.CurrentTab ~= tab then
			TweenExp(btn, { BackgroundTransparency = 1 }, 0.15)
			TweenExp(nameLabel, { TextColor3 = Theme.TextDim }, 0.15)
			if iconImg then TweenExp(iconImg, { ImageColor3 = Theme.TextDim }, 0.15) end
			TweenExp(indicator, { Size = UDim2.new(0, 3, 0, 0) }, 0.15)
		end
	end)

	table.insert(self.Tabs, tab)
	if #self.Tabs == 1 then self:SelectTab(tab) end
	return tab
end

function UIModule:SelectTab(tab)
	for _, t in ipairs(self.Tabs) do
		t.Container.Visible = false
		t.Gradient.Enabled = false
		t.Button.BackgroundTransparency = 1
		t.NameLabel.TextColor3 = Theme.TextDim
		t.NameLabel.Font = Enum.Font.GothamMedium
		if t.IconImg then TweenExp(t.IconImg, { ImageColor3 = Theme.TextDim }, 0.15) end
		TweenExp(t.Indicator, { Size = UDim2.new(0, 3, 0, 0) }, 0.15)
	end

	tab.Gradient.Enabled = true
	tab.Button.BackgroundTransparency = 0.85
	tab.NameLabel.TextColor3 = Theme.Text
	tab.NameLabel.Font = Enum.Font.GothamBold
	if tab.IconImg then TweenExp(tab.IconImg, { ImageColor3 = Theme.Accent }, 0.2) end
	TweenExp(tab.Indicator, { Size = UDim2.new(0, 3, 0, 22) }, 0.2)

	tab.Container.Position = UDim2.new(0, 0, 0, 10)
	tab.Container.Visible = true
	TweenExp(tab.Container, { Position = UDim2.new(0, 0, 0, 0) }, 0.25)

	self.CurrentTab = tab
end

-- ====================== SECTIONS ======================
function UIModule:CreateSection(tab, config)
	config = config or {}
	local section = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Section,
		BorderSizePixel = 0,
		Parent = tab.Container,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = section })
	Create("UIStroke", { Color = Theme.Border, Thickness = 1, Parent = section })
	Create("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 14), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = section })
	Create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = section })

	if config.Title then
		local header = Create("Frame", {
			Size = UDim2.new(1, 0, 0, config.Subtitle and 36 or 20),
			BackgroundTransparency = 1,
			Parent = section,
		})

		local textOffset = 0
		if config.Icon or config.Logo then
			local resolvedIcon = self:GetIcon(config.Icon or config.Logo)
			if resolvedIcon then
				Create("ImageLabel", {
					Size = UDim2.new(0, 18, 0, 18),
					Position = UDim2.new(0, 0, 0, 2),
					BackgroundTransparency = 1,
					Image = resolvedIcon,
					ImageColor3 = Theme.Accent,
					Parent = header,
				})
				textOffset = 24
			end
		end

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
				Position = UDim2.new(0, textOffset, 0, 19),
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

-- ====================== 1. BUTTONS ======================
function UIModule:CreateButton(section, config)
	config = config or {}
	local resolvedIcon = self:GetIcon(config.Icon or config.Logo)

	local btn = Create("TextButton", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Theme.ModalBg,
		Text = "",
		AutoButtonColor = false,
		Parent = section,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = btn })
	Create("UIStroke", { Color = Theme.Border, Thickness = 1, Parent = btn })

	local textStart = 0
	local textAlignment = Enum.TextXAlignment.Center

	if resolvedIcon then
		textStart = 34
		textAlignment = Enum.TextXAlignment.Left
		Create("ImageLabel", {
			Size = UDim2.new(0, 16, 0, 16),
			Position = UDim2.new(0, 12, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			Image = resolvedIcon,
			ImageColor3 = Theme.Accent,
			Parent = btn,
		})
	end

	Create("TextLabel", {
		Size = UDim2.new(1, -(textStart + 8), 1, 0),
		Position = UDim2.new(0, textStart, 0, 0),
		BackgroundTransparency = 1,
		Text = config.Name or "Button",
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextXAlignment = textAlignment,
		Parent = btn,
	})

	btn.MouseEnter:Connect(function() TweenExp(btn, { BackgroundColor3 = Theme.AccentDark }, 0.15) end)
	btn.MouseLeave:Connect(function() TweenExp(btn, { BackgroundColor3 = Theme.ModalBg }, 0.15) end)
	btn.MouseButton1Click:Connect(function()
		TweenExp(btn, { Size = UDim2.new(1, -4, 0, 32) }, 0.05).Completed:Connect(function()
			TweenExp(btn, { Size = UDim2.new(1, 0, 0, 34) }, 0.08)
		end)
		if config.Callback then config.Callback() end
	end)
	return btn
end

-- ====================== 2. TOGGLES ======================
function UIModule:CreateToggle(section, config)
	config = config or {}
	local flag = config.Flag or config.Name or "Toggle"
	local default = config.Default or false
	self.Flags[flag] = default

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
		TextSize = 13,
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
			TextSize = 11,
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
		TweenExp(track, { BackgroundColor3 = state and Theme.Accent or Theme.ToggleOff }, 0.2)
		TweenExp(knob, { Position = state and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) }, 0.2)
		if config.Callback then config.Callback(state) end
	end

	row.MouseButton1Click:Connect(function() SetState(not self.Flags[flag]) end)
	return { Set = SetState, Get = function() return self.Flags[flag] end }
end

-- ====================== 3. SLIDERS ======================
function UIModule:CreateSlider(section, config)
	config = config or {}
	local flag = config.Flag or config.Name or "Slider"
	local min = config.Min or 0
	local max = config.Max or 100
	if max <= min then max = min + 1 end
	local default = math.clamp(config.Default or min, min, max)
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
		TweenExp(fill, { Size = UDim2.new(percent, 0, 1, 0) }, 0.1)
		TweenExp(knob, { Position = UDim2.new(percent, 0, 0.5, 0) }, 0.1)
		valueLabel.Text = tostring(val) .. (config.Suffix or "")
		if config.Callback then config.Callback(val) end
	end

	local draggingSlider = false
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingSlider = true
			UpdateFromX(input.Position.X)
		end
	end)

	local moveConn = UserInputService.InputChanged:Connect(function(input)
		if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			UpdateFromX(input.Position.X)
		end
	end)

	local endConn = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingSlider = false
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
		end,
		Get = function() return self.Flags[flag] end
	}
end

-- ====================== 4. DROPDOWNS ======================
function UIModule:CreateDropdown(section, config)
	config = config or {}
	local flag = config.Flag or config.Name or "Dropdown"
	local options = config.Options or { "Option 1", "Option 2" }
	local default = config.Default or options[1]
	self.Flags[flag] = default

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
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	})

	local box = Create("TextButton", {
		Size = UDim2.new(0.58, 0, 0, 30),
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Theme.Dropdown,
		Text = "   " .. tostring(default),
		TextColor3 = Theme.Text,
		Font = Enum.Font.Gotham,
		TextSize = 12,
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
		Image = self:GetIcon("dropdown") or "rbxassetid://10747384978",
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

	local listLayout = Create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = listFrame })
	Create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), Parent = listFrame })

	local isOpen = false
	local function Populate()
		for _, child in ipairs(listFrame:GetChildren()) do
			if child:IsA("TextButton") then child:Destroy() end
		end

		for _, opt in ipairs(options) do
			local itemBtn = Create("TextButton", {
				Size = UDim2.new(1, 0, 0, 26),
				BackgroundColor3 = (opt == self.Flags[flag]) and Theme.AccentDark or Theme.Dropdown,
				BackgroundTransparency = (opt == self.Flags[flag]) and 0.4 or 1,
				Text = "   " .. tostring(opt),
				TextColor3 = (opt == self.Flags[flag]) and Theme.Text or Theme.TextDim,
				Font = Enum.Font.Gotham,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				AutoButtonColor = false,
				Parent = listFrame,
			})
			Create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = itemBtn })

			itemBtn.MouseButton1Click:Connect(function()
				self.Flags[flag] = opt
				box.Text = "   " .. tostring(opt)
				isOpen = false
				TweenExp(arrow, { Rotation = 0 }, 0.15)
				listFrame.Visible = false
				Populate()
				if config.Callback then config.Callback(opt) end
			end)
		end
		listFrame.Size = UDim2.new(1, 0, 0, #options * 28 + 8)
	end

	Populate()

	box.MouseButton1Click:Connect(function()
		isOpen = not isOpen
		listFrame.Visible = isOpen
		TweenExp(arrow, { Rotation = isOpen and 180 or 0 }, 0.2)
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

-- ====================== 5. TEXT INPUTS ======================
function UIModule:CreateInput(section, config)
	config = config or {}
	local flag = config.Flag or config.Name or "Input"
	local default = config.Default or ""
	self.Flags[flag] = default

	local row = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		Parent = section,
	})

	Create("TextLabel", {
		Size = UDim2.new(0.4, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = config.Name or "Input",
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})

	local box = Create("TextBox", {
		Size = UDim2.new(0.58, 0, 0, 30),
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Theme.Dropdown,
		Text = default,
		PlaceholderText = config.Placeholder or "Enter text...",
		PlaceholderColor3 = Theme.TextDim,
		TextColor3 = Theme.Text,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		ClearTextOnFocus = false,
		Parent = row,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = box })
	local boxStroke = Create("UIStroke", { Color = Theme.Border, Thickness = 1, Parent = box })

	box.Focused:Connect(function()
		TweenExp(boxStroke, { Color = Theme.Accent }, 0.15)
	end)
	box.FocusLost:Connect(function(enterPressed)
		TweenExp(boxStroke, { Color = Theme.Border }, 0.15)
		self.Flags[flag] = box.Text
		if config.Callback then config.Callback(box.Text, enterPressed) end
	end)

	return {
		Set = function(text)
			self.Flags[flag] = text
			box.Text = text
			if config.Callback then config.Callback(text) end
		end,
		Get = function() return self.Flags[flag] end
	}
end

-- ====================== 6. CHECKBOXES ======================
function UIModule:CreateCheckbox(section, config)
	config = config or {}
	local flag = config.Flag or config.Name or "Checkbox"
	local default = config.Default or false
	self.Flags[flag] = default

	local row = Create("TextButton", {
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
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
	local boxGrad = ApplyGradient(box, Theme.Accent, Theme.AccentDark)
	boxGrad.Enabled = default

	local checkIcon = Create("ImageLabel", {
		Size = UDim2.new(0, 12, 0, 12),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = self:GetIcon("check") or "rbxassetid://10747376789",
		ImageColor3 = Color3.fromRGB(255, 255, 255),
		ImageTransparency = default and 0 or 1,
		Parent = box,
	})

	Create("TextLabel", {
		Size = UDim2.new(1, -28, 1, 0),
		Position = UDim2.new(0, 28, 0, 0),
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
		boxGrad.Enabled = state
		TweenExp(box, { BackgroundColor3 = state and Theme.Accent or Theme.ToggleOff }, 0.15)
		TweenExp(checkIcon, { ImageTransparency = state and 0 or 1 }, 0.15)
		if config.Callback then config.Callback(state) end
	end

	row.MouseButton1Click:Connect(function() SetState(not self.Flags[flag]) end)
	return { Set = SetState, Get = function() return self.Flags[flag] end }
end

-- ====================== 7. MULTI-SELECT ADJUSTMENT MODAL ======================
function UIModule:OpenMultiSelectWindow(config)
	config = config or {}
	local title = config.Title or "Adjustments"
	local subtitle = config.Subtitle or "Select your desired options below"
	local options = config.Options or {}
	local selected = config.Selected or {}
	local onApply = config.OnApply

	local existing = self.Gui:FindFirstChild("MultiSelectModal")
	if existing then existing:Destroy() end

	local modalContainer = Create("Frame", {
		Name = "MultiSelectModal",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 0.45,
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		ZIndex = 50,
		Active = true,
		Parent = self.Gui,
	})

	local modalFrame = Create("Frame", {
		Size = UDim2.new(0, 390, 0, 430),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.ModalBg,
		BorderSizePixel = 0,
		ZIndex = 51,
		ClipsDescendants = true,
		Parent = modalContainer,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = modalFrame })
	Create("UIStroke", { Color = Theme.Border, Thickness = 1.2, Parent = modalFrame })

	local modalHeader = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundColor3 = Theme.Sidebar,
		BorderSizePixel = 0,
		ZIndex = 52,
		Parent = modalFrame,
	})
	Create("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, -1),
		BackgroundColor3 = Theme.Border,
		BorderSizePixel = 0,
		ZIndex = 52,
		Parent = modalHeader,
	})

	Create("TextLabel", {
		Size = UDim2.new(1, -60, 0, 20),
		Position = UDim2.new(0, 16, 0, 7),
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 53,
		Parent = modalHeader,
	})

	Create("TextLabel", {
		Size = UDim2.new(1, -60, 0, 16),
		Position = UDim2.new(0, 16, 0, 27),
		BackgroundTransparency = 1,
		Text = subtitle,
		TextColor3 = Theme.TextDim,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 53,
		Parent = modalHeader,
	})

	local mCloseBtn = Create("TextButton", {
		Size = UDim2.new(0, 24, 0, 24),
		Position = UDim2.new(1, -14, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 53,
		Parent = modalHeader,
	})
	local mCloseDot = Create("Frame", {
		Size = UDim2.new(0, 10, 0, 10),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.CloseDot,
		ZIndex = 54,
		Parent = mCloseBtn,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = mCloseDot })

	local scrollList = Create("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -104),
		Position = UDim2.new(0, 0, 0, 50),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Border,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 52,
		Parent = modalFrame,
	})
	Create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scrollList })
	Create("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = scrollList })

	local currentSelected = {}
	for _, v in ipairs(selected) do currentSelected[v] = true end

	for _, opt in ipairs(options) do
		local optName = type(opt) == "table" and opt.Name or tostring(opt)
		local optDesc = type(opt) == "table" and opt.Description or nil

		local row = Create("TextButton", {
			Size = UDim2.new(1, 0, 0, optDesc and 42 or 32),
			BackgroundColor3 = Theme.Section,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			Text = "",
			ZIndex = 53,
			Parent = scrollList,
		})
		Create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = row })
		Create("UIStroke", { Color = Theme.Border, Thickness = 1, Parent = row })

		local box = Create("Frame", {
			Size = UDim2.new(0, 18, 0, 18),
			Position = UDim2.new(0, 10, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = currentSelected[optName] and Theme.Accent or Theme.ToggleOff,
			BorderSizePixel = 0,
			ZIndex = 54,
			Parent = row,
		})
		Create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = box })
		local boxGrad = ApplyGradient(box, Theme.Accent, Theme.AccentDark)
		boxGrad.Enabled = currentSelected[optName] == true

		local check = Create("ImageLabel", {
			Size = UDim2.new(0, 12, 0, 12),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = self:GetIcon("check") or "rbxassetid://10747376789",
			ImageColor3 = Color3.fromRGB(255, 255, 255),
			ImageTransparency = currentSelected[optName] and 0 or 1,
			ZIndex = 55,
			Parent = box,
		})

		Create("TextLabel", {
			Size = UDim2.new(1, -38, 0, optDesc and 18 or 32),
			Position = UDim2.new(0, 36, 0, optDesc and 4 or 0),
			BackgroundTransparency = 1,
			Text = optName,
			TextColor3 = Theme.Text,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 54,
			Parent = row,
		})

		if optDesc then
			Create("TextLabel", {
				Size = UDim2.new(1, -38, 0, 14),
				Position = UDim2.new(0, 36, 0, 22),
				BackgroundTransparency = 1,
				Text = optDesc,
				TextColor3 = Theme.TextDim,
				Font = Enum.Font.Gotham,
				TextSize = 10,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 54,
				Parent = row,
			})
		end

		row.MouseButton1Click:Connect(function()
			currentSelected[optName] = not currentSelected[optName]
			local isSel = currentSelected[optName]
			boxGrad.Enabled = isSel
			TweenExp(box, { BackgroundColor3 = isSel and Theme.Accent or Theme.ToggleOff }, 0.15)
			TweenExp(check, { ImageTransparency = isSel and 0 or 1 }, 0.15)
		end)
	end

	local bottomBar = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 52),
		Position = UDim2.new(0, 0, 1, -52),
		BackgroundColor3 = Theme.Sidebar,
		BorderSizePixel = 0,
		ZIndex = 52,
		Parent = modalFrame,
	})
	Create("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = Theme.Border,
		BorderSizePixel = 0,
		ZIndex = 52,
		Parent = bottomBar,
	})

	local applyBtn = Create("TextButton", {
		Size = UDim2.new(1, -24, 0, 34),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Accent,
		Text = "Confirm & Apply",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		AutoButtonColor = false,
		ZIndex = 53,
		Parent = bottomBar,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = applyBtn })
	ApplyGradient(applyBtn, Theme.Accent, Theme.AccentDark)

	local function CloseModal()
		local res = {}
		for k, v in pairs(currentSelected) do
			if v then table.insert(res, k) end
		end
		if onApply then onApply(res) end
		modalContainer:Destroy()
	end

	applyBtn.MouseButton1Click:Connect(CloseModal)
	mCloseBtn.MouseButton1Click:Connect(CloseModal)
end

function UIModule:CreateAdjustmentPicker(section, config)
	config = config or {}
	local flag = config.Flag or "Adjustments"
	local options = config.Options or {}
	local defaultSelected = config.Default or {}
	self.Flags[flag] = defaultSelected

	local row = Create("TextButton", {
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundColor3 = Theme.Section,
		Text = "",
		AutoButtonColor = false,
		Parent = section,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = row })
	Create("UIStroke", { Color = Theme.Border, Thickness = 1, Parent = row })

	Create("TextLabel", {
		Size = UDim2.new(0.65, 0, 1, 0),
		Position = UDim2.new(0, 14, 0, 0),
		BackgroundTransparency = 1,
		Text = config.Name or "UI Adjustments",
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})

	local statusBadge = Create("TextLabel", {
		Size = UDim2.new(0.3, 0, 1, 0),
		Position = UDim2.new(1, -14, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Text = #self.Flags[flag] .. " Selected",
		TextColor3 = Theme.Accent,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row,
	})

	row.MouseEnter:Connect(function() TweenExp(row, { BackgroundColor3 = Color3.fromRGB(32, 32, 38) }, 0.15) end)
	row.MouseLeave:Connect(function() TweenExp(row, { BackgroundColor3 = Theme.Section }, 0.15) end)

	row.MouseButton1Click:Connect(function()
		self:OpenMultiSelectWindow({
			Title = config.Name or "UI Adjustments",
			Subtitle = config.Subtitle or "Select options to apply to your interface",
			Options = options,
			Selected = self.Flags[flag],
			OnApply = function(newSelection)
				self.Flags[flag] = newSelection
				statusBadge.Text = #newSelection .. " Selected"
				if config.Callback then config.Callback(newSelection) end
			end
		})
	end)

	return {
		Get = function() return self.Flags[flag] end,
		Set = function(newSel)
			self.Flags[flag] = newSel
			statusBadge.Text = #newSel .. " Selected"
		end
	}
end

return UIModule
