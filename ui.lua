--[[
	ReaperX Style UI Library (Pure Vector / No External Logo Required)
	- Branding: Native Red Gradient Monogram Emblem [R] & PRO Badge
	- Top-Right: Clean Transparent Close Button (✕)
	- Bottom-Right: Corner Drag Resizer (◢)
	- Settings: Multi-Select Popup Window (No dropdown / No icons)
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local UIModule = {}
UIModule.__index = UIModule

local Theme = {
	Background  = Color3.fromRGB(15, 15, 17),
	Sidebar     = Color3.fromRGB(20, 20, 23),
	Content     = Color3.fromRGB(15, 15, 17),
	Section     = Color3.fromRGB(24, 24, 28),
	ModalBg     = Color3.fromRGB(18, 18, 22),
	Border      = Color3.fromRGB(42, 42, 48),

	Text        = Color3.fromRGB(255, 255, 255),
	TextDim     = Color3.fromRGB(160, 160, 170),

	Accent      = Color3.fromRGB(255, 50, 50),
	AccentDark  = Color3.fromRGB(180, 20, 20),

	ToggleOff   = Color3.fromRGB(45, 45, 50),
	SliderTrack = Color3.fromRGB(35, 35, 40),
	Dropdown    = Color3.fromRGB(28, 28, 33),
}

UIModule.Icons = {
	Swords   = "rbxassetid://10747377716",
	Skull    = "rbxassetid://10747384022",
	Cart     = "rbxassetid://10747381958",
	Globe    = "rbxassetid://10747378330",
	Settings = "rbxassetid://10747383136",
	Check    = "rbxassetid://10747376789",
}
local Icons = UIModule.Icons

local function Create(class, props)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then inst[k] = v end
	end
	if props and props.Parent then inst.Parent = props.Parent end
	return inst
end

local function Tween(obj, props, time)
	local t = TweenService:Create(obj, TweenInfo.new(time or 0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), props)
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

	-- ========== TITLE BAR ==========
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

	-- 1. Native Emblem Badge [R] (ไม่ต้องใช้ไฟล์รูป ไม่พังแน่นอน)
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

	-- Title + PRO Tag
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

	-- 2. Minimal Transparent Close Button (ไม่มีกล่องทึบ ชี้แล้วเรืองแสงสีแดง)
	local closeBtn = Create("TextButton", {
		Size = UDim2.new(0, 26, 0, 26),
		Position = UDim2.new(1, -14, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Text = "✕",
		TextColor3 = Theme.TextDim,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		AutoButtonColor = false,
		Parent = titleBar,
	})

	closeBtn.MouseEnter:Connect(function()
		Tween(closeBtn, { TextColor3 = Theme.Accent, TextSize = 16 }, 0.15)
	end)
	closeBtn.MouseLeave:Connect(function()
		Tween(closeBtn, { TextColor3 = Theme.TextDim, TextSize = 14 }, 0.15)
	end)
	closeBtn.MouseButton1Click:Connect(function()
		gui:Destroy()
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

	Create("UIListLayout", {
		Padding = UDim.new(0, 14),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = contentScroll,
	})
	Create("UIPadding", {
		PaddingTop = UDim.new(0, 16),
		PaddingBottom = UDim.new(0, 24),
		PaddingLeft = UDim.new(0, 18),
		PaddingRight = UDim.new(0, 18),
		Parent = contentScroll,
	})

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
			main.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
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

	resizeHandle.MouseEnter:Connect(function() Tween(resizeHandle, { TextColor3 = Theme.Accent }) end)
	resizeHandle.MouseLeave:Connect(function() Tween(resizeHandle, { TextColor3 = Theme.TextDim }) end)

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

	local modalCloseBtn = Create("TextButton", {
		Size = UDim2.new(0, 24, 0, 24),
		Position = UDim2.new(1, -14, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Text = "✕",
		TextColor3 = Theme.TextDim,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		ZIndex = 53,
		Parent = modalHeader,
	})

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
	Create("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = scrollList,
	})
	Create("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
		Parent = scrollList,
	})

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
			AnchorPoint = Vector2.new(0, 0.5),
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
			Image = Icons.Check,
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
			Tween(box, { BackgroundColor3 = isSel and Theme.Accent or Theme.ToggleOff }, 0.15)
			Tween(check, { ImageTransparency = isSel and 0 or 1 }, 0.15)
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
	modalCloseBtn.MouseButton1Click:Connect(CloseModal)
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

	row.MouseEnter:Connect(function() Tween(row, { BackgroundColor3 = Color3.fromRGB(32, 32, 38) }) end)
	row.MouseLeave:Connect(function() Tween(row, { BackgroundColor3 = Theme.Section }) end)

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

function UIModule:CreateTab(name, iconId)
	local tab = { Name = name }
	iconId = iconId or Icons.Settings

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
	if #self.Tabs == 1 then self:SelectTab(tab) end
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
			Size = UDim2.new(1, 0, 0, config.Subtitle and 36 or 20),
			BackgroundTransparency = 1,
			Parent = section,
		})
		Create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 18),
			Position = UDim2.new(0, 0, 0, 0),
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
				Size = UDim2.new(1, 0, 0, 14),
				Position = UDim2.new(0, 0, 0, 19),
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
		Tween(track, { BackgroundColor3 = state and Theme.Accent or Theme.ToggleOff })
		Tween(knob, { Position = state and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) })
		if config.Callback then config.Callback(state) end
	end

	row.MouseButton1Click:Connect(function() SetState(not self.Flags[flag]) end)
	return { Set = SetState, Get = function() return self.Flags[flag] end }
end

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
		Tween(fill, { Size = UDim2.new(percent, 0, 1, 0) }, 0.08)
		Tween(knob, { Position = UDim2.new(percent, 0, 0.5, 0) }, 0.08)
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

function UIModule:CreateButton(section, config)
	config = config or {}
	local btn = Create("TextButton", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Theme.Dropdown,
		Text = config.Name or "Button",
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		AutoButtonColor = false,
		Parent = section,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = btn })
	Create("UIStroke", { Color = Theme.Border, Thickness = 1, Parent = btn })

	btn.MouseEnter:Connect(function() Tween(btn, { BackgroundColor3 = Theme.AccentDark }) end)
	btn.MouseLeave:Connect(function() Tween(btn, { BackgroundColor3 = Theme.Dropdown }) end)
	btn.MouseButton1Click:Connect(function()
		Tween(btn, { TextSize = 12 }, 0.05).Completed:Connect(function()
			Tween(btn, { TextSize = 13 }, 0.05)
		end)
		if config.Callback then config.Callback() end
	end)
	return btn
end

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
		Image = Icons.Check,
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
		Tween(box, { BackgroundColor3 = state and Theme.Accent or Theme.ToggleOff })
		Tween(checkIcon, { ImageTransparency = state and 0 or 1 })
		if config.Callback then config.Callback(state) end
	end

	row.MouseButton1Click:Connect(function() SetState(not self.Flags[flag]) end)
	return { Set = SetState, Get = function() return self.Flags[flag] end }
end

return UIModule
