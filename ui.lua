-- ==============================================================================
--              XYRAX HUB - EXECUTIVE DUAL-COLUMN EDITION
--     (Dual-Column Grid, Master Section Toggles, Step Sliders & Categories)
-- ==============================================================================
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local UIModule = {}
UIModule.__index = UIModule

-- ==================== THEME SYSTEM ====================
local THEME = {
    Canvas       = Color3.fromRGB(13, 13, 16),      -- Main dark background
    Header       = Color3.fromRGB(15, 15, 19),      -- Titlebar
    Sidebar      = Color3.fromRGB(15, 15, 19),      -- Sidebar
    CardBg       = Color3.fromRGB(20, 20, 26),      -- Section card background
    CardInner    = Color3.fromRGB(25, 25, 33),      -- Inner control tray
    Recessed     = Color3.fromRGB(15, 15, 20),      -- Input/Slider trough
    
    -- Accent: High-End Velvet Crimson (Matches reference image)
    Accent       = Color3.fromRGB(225, 35, 55),
    AccentGlow   = Color3.fromRGB(255, 60, 80),
    AccentDark   = Color3.fromRGB(140, 20, 35),
    
    Border       = Color3.fromRGB(35, 35, 45),
    BorderLight  = Color3.fromRGB(50, 50, 65),
    
    TextHero     = Color3.fromRGB(255, 255, 255),
    TextBody     = Color3.fromRGB(215, 215, 225),
    TextMuted    = Color3.fromRGB(135, 135, 150),
    TextDim      = Color3.fromRGB(80, 80, 95),
}

-- ==================== VERIFIED ICON MATRIX ====================
local FallbackIcons = {
    ["swords"]             = "rbxassetid://81872698913435",
    ["sword"]              = "rbxassetid://124448418211665",
    ["crosshair"]          = "rbxassetid://134242818164054",
    ["sparkles"]           = "rbxassetid://138635884129147",
    ["sparkle"]            = "rbxassetid://138635884129147",
    ["settings"]           = "rbxassetid://80758916183665",
    ["shield"]             = "rbxassetid://110987169760162",
    ["zap"]                = "rbxassetid://130551565616516",
    ["flame"]              = "rbxassetid://98218034436456",
    ["target"]             = "rbxassetid://87563802520297",
    ["eye"]                = "rbxassetid://100033680381365",
    ["sliders"]            = "rbxassetid://85538382643347",
    ["sliders-horizontal"] = "rbxassetid://85538382643347",
    ["bell"]               = "rbxassetid://97392696311902",
    ["check"]              = "rbxassetid://93898873302694",
    ["x"]                  = "rbxassetid://110786993356448",
    ["chevron-down"]       = "rbxassetid://134243273101015",
    ["play"]               = "rbxassetid://115020759309179",
    ["refresh-cw"]         = "rbxassetid://78956681942188",
    ["star"]               = "rbxassetid://138635884129147",
    ["clock"]              = "rbxassetid://126259032907535",
    ["shopping-cart"]      = "rbxassetid://140420225386018",
    ["gift"]               = "rbxassetid://132740088158419",
    ["users"]              = "rbxassetid://71907624112229",
    ["skull"]              = "rbxassetid://74237056000103",
    ["globe"]              = "rbxassetid://115123411028382",
    ["server"]             = "rbxassetid://77480056459407",
}

local IconAliases = {
    ["sliders"]   = "sliders-horizontal",
    ["sword"]     = "swords",
    ["gear"]      = "settings",
    ["setting"]   = "settings",
    ["sparkle"]   = "sparkles",
    ["bell-ring"] = "bell",
    ["loop"]      = "refresh-cw",
    ["cart"]      = "shopping-cart",
}

local WindUIIcons = nil
pcall(function()
    if game.HttpGet then
        WindUIIcons = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/Icons/refs/heads/main/lucide/dist/Icons.lua"))()
    end
end)

function UIModule:GetIcon(name)
    if not name or name == "" then return nil end
    name = tostring(name)
    if string.find(name, "^rbxassetid://") or string.find(name, "^rbxasset://") or string.find(name, "^http") then
        return { Asset = name }
    end
    if tonumber(name) then
        return { Asset = "rbxassetid://" .. name }
    end

    local clean = string.lower(name)
    local resolved = IconAliases[clean] or clean

    if WindUIIcons and type(WindUIIcons) == "table" then
        local raw = WindUIIcons[resolved] or WindUIIcons[clean]
        if raw then
            local assetId = (type(raw) == "string" and raw) or (type(raw) == "number" and "rbxassetid://" .. raw) or (type(raw) == "table" and (raw.Asset or raw.Image or raw.id or raw[1]))
            if assetId then
                if type(assetId) == "number" then assetId = "rbxassetid://" .. assetId end
                if not string.find(assetId, "://") then assetId = "rbxassetid://" .. assetId end
                return {
                    Asset = assetId,
                    ImageRectOffset = (type(raw) == "table" and (raw.ImageRectOffset or raw[2])) or Vector2.new(0, 0),
                    ImageRectSize = (type(raw) == "table" and (raw.ImageRectSize or raw[3])) or Vector2.new(0, 0)
                }
            end
        end
    end

    local fb = FallbackIcons[resolved] or FallbackIcons[clean]
    if fb then
        return { Asset = type(fb) == "table" and fb.Asset or fb }
    end
    return nil
end

local function applyIcon(img, iconData, color)
    if not iconData or not iconData.Asset or iconData.Asset == "" then
        img.Visible = false
        return
    end
    img.Image = iconData.Asset
    if iconData.ImageRectOffset and iconData.ImageRectSize and iconData.ImageRectSize ~= Vector2.new(0,0) then
        img.ImageRectOffset = iconData.ImageRectOffset
        img.ImageRectSize = iconData.ImageRectSize
    else
        img.ImageRectOffset = Vector2.new(0, 0)
        img.ImageRectSize = Vector2.new(0, 0)
    end
    img.ImageColor3 = color or THEME.TextHero
    img.Visible = true
end

-- ==================== MAIN WINDOW CREATION ====================
function UIModule.new(config)
    config = config or {}
    local self = setmetatable({}, UIModule)

    if config.AccentColor then
        THEME.Accent = config.AccentColor
        THEME.AccentGlow = config.AccentColor
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "XyraxExec_" .. tostring(math.random(1000, 9999))
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    pcall(function()
        if syn and syn.protect_gui then
            syn.protect_gui(screenGui)
            screenGui.Parent = game:GetService("CoreGui")
        elseif gethui then
            screenGui.Parent = gethui()
        else
            screenGui.Parent = game:GetService("CoreGui")
        end
    end)
    if not screenGui.Parent then
        screenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
    end
    self.ScreenGui = screenGui

    -- Ambient Notifications
    local notifContainer = Instance.new("Frame")
    notifContainer.Name = "Notifs"
    notifContainer.Size = UDim2.new(0, 310, 1, -40)
    notifContainer.Position = UDim2.new(1, -330, 0, 20)
    notifContainer.BackgroundTransparency = 1
    notifContainer.Parent = screenGui

    local notifLayout = Instance.new("UIListLayout")
    notifLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    notifLayout.Padding = UDim.new(0, 10)
    notifLayout.Parent = notifContainer
    self.NotifContainer = notifContainer

    -- Main Frame
    local main = Instance.new("Frame")
    main.Name = "MainWindow"
    main.Size = config.Size or UDim2.new(0, 840, 0, 560)
    main.Position = UDim2.new(0.5, -420, 0.5, -280)
    main.BackgroundColor3 = THEME.Canvas
    main.BorderSizePixel = 0
    main.ClipsDescendants = true
    main.Active = true
    main.Parent = screenGui
    self.MainFrame = main

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 12)
    mainCorner.Parent = main

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = THEME.Border
    mainStroke.Thickness = 1.2
    mainStroke.Parent = main

    -- Top Border Accent Light
    local topAccentLine = Instance.new("Frame")
    topAccentLine.Size = UDim2.new(1, 0, 0, 2)
    topAccentLine.Position = UDim2.new(0, 0, 0, 0)
    topAccentLine.BackgroundColor3 = THEME.Accent
    topAccentLine.BorderSizePixel = 0
    topAccentLine.Parent = main

    local taGrad = Instance.new("UIGradient")
    taGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, THEME.AccentGlow),
        ColorSequenceKeypoint.new(0.5, THEME.Accent),
        ColorSequenceKeypoint.new(1, THEME.AccentDark)
    })
    taGrad.Parent = topAccentLine

    -- ==================== TITLE BAR ====================
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 50)
    titleBar.BackgroundColor3 = THEME.Header
    titleBar.BorderSizePixel = 0
    titleBar.Active = true
    titleBar.Parent = main

    local tbDivider = Instance.new("Frame")
    tbDivider.Size = UDim2.new(1, 0, 0, 1)
    tbDivider.Position = UDim2.new(0, 0, 1, -1)
    tbDivider.BackgroundColor3 = THEME.Border
    tbDivider.BorderSizePixel = 0
    tbDivider.Parent = titleBar

    -- Stylized Monogram
    local emblem = Instance.new("Frame")
    emblem.Size = UDim2.new(0, 26, 0, 26)
    emblem.Position = UDim2.new(0, 18, 0.5, -13)
    emblem.BackgroundColor3 = THEME.Accent
    emblem.BorderSizePixel = 0
    emblem.Parent = titleBar

    local emCorner = Instance.new("UICorner")
    emCorner.CornerRadius = UDim.new(0, 6)
    emCorner.Parent = emblem

    local emGrad = Instance.new("UIGradient")
    emGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, THEME.AccentGlow),
        ColorSequenceKeypoint.new(1, THEME.AccentDark)
    })
    emGrad.Rotation = 45
    emGrad.Parent = emblem

    local emText = Instance.new("TextLabel")
    emText.Size = UDim2.new(1, 0, 1, 0)
    emText.BackgroundTransparency = 1
    emText.Text = string.sub(config.Title or "X", 1, 1)
    emText.Font = Enum.Font.GothamBold
    emText.TextSize = 13
    emText.TextColor3 = Color3.fromRGB(255, 255, 255)
    emText.Parent = emblem

    local titleHolder = Instance.new("Frame")
    titleHolder.Size = UDim2.new(0, 320, 1, 0)
    titleHolder.Position = UDim2.new(0, 54, 0, 0)
    titleHolder.BackgroundTransparency = 1
    titleHolder.Parent = titleBar

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, 0, 0, 20)
    titleLbl.Position = UDim2.new(0, 0, 0.5, config.Subtitle and -15 or -10)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = config.Title or "ReaperX"
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 13
    titleLbl.TextColor3 = THEME.TextHero
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = titleHolder

    if config.Subtitle then
        local subLbl = Instance.new("TextLabel")
        subLbl.Size = UDim2.new(1, 0, 0, 14)
        subLbl.Position = UDim2.new(0, 0, 0.5, 3)
        subLbl.BackgroundTransparency = 1
        subLbl.Text = config.Subtitle
        subLbl.Font = Enum.Font.Gotham
        subLbl.TextSize = 11
        subLbl.TextColor3 = THEME.TextMuted
        subLbl.TextXAlignment = Enum.TextXAlignment.Left
        subLbl.Parent = titleHolder
    end

    -- Window Controls
    local controls = Instance.new("Frame")
    controls.Size = UDim2.new(0, 100, 1, 0)
    controls.Position = UDim2.new(1, -110, 0, 0)
    controls.BackgroundTransparency = 1
    controls.Parent = titleBar

    local ctrlLayout = Instance.new("UIListLayout")
    ctrlLayout.FillDirection = Enum.FillDirection.Horizontal
    ctrlLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    ctrlLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    ctrlLayout.Padding = UDim.new(0, 8)
    ctrlLayout.Parent = controls

    -- Minimize Button
    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 26, 0, 26)
    minBtn.BackgroundTransparency = 1
    minBtn.Text = "—"
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 11
    minBtn.TextColor3 = THEME.TextMuted
    minBtn.AutoButtonColor = false
    minBtn.Parent = controls

    -- Close Button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 26, 0, 26)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Text = ""
    closeBtn.AutoButtonColor = false
    closeBtn.Parent = controls

    local closeIcon = Instance.new("ImageLabel")
    closeIcon.Size = UDim2.new(0, 13, 0, 13)
    closeIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    closeIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
    closeIcon.BackgroundTransparency = 1
    closeIcon.Image = "rbxassetid://110786993356448"
    closeIcon.ImageColor3 = THEME.TextMuted
    closeIcon.Parent = closeBtn

    closeBtn.MouseEnter:Connect(function()
        TweenService:Create(closeIcon, TweenInfo.new(0.2), { ImageColor3 = THEME.Accent }):Play()
    end)
    closeBtn.MouseLeave:Connect(function()
        TweenService:Create(closeIcon, TweenInfo.new(0.2), { ImageColor3 = THEME.TextMuted }):Play()
    end)

    local isMin, origSize = false, main.Size
    minBtn.MouseButton1Click:Connect(function()
        isMin = not isMin
        if isMin then
            origSize = main.Size
            TweenService:Create(main, TweenInfo.new(0.3, Enum.EasingStyle.Quart), { Size = UDim2.new(origSize.X.Scale, origSize.X.Offset, 0, 50) }):Play()
        else
            TweenService:Create(main, TweenInfo.new(0.3, Enum.EasingStyle.Quart), { Size = origSize }):Play()
        end
    end)

    closeBtn.MouseButton1Click:Connect(function()
        local tw = TweenService:Create(main, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 0, 0, 0),
            Position = UDim2.new(main.Position.X.Scale, main.Position.X.Offset + (main.Size.X.Offset/2), main.Position.Y.Scale, main.Position.Y.Offset + (main.Size.Y.Offset/2))
        })
        tw:Play()
        tw.Completed:Connect(function() screenGui:Destroy() end)
    end)

    -- Draggable Handling
    local dragging, dragStart, startPos, dragConn
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
            if dragConn then dragConn:Disconnect() end
            dragConn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if dragConn then dragConn:Disconnect() dragConn = nil end
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    -- Resizer Handle (◢)
    local resizeHandle = Instance.new("TextButton")
    resizeHandle.Size = UDim2.new(0, 18, 0, 18)
    resizeHandle.Position = UDim2.new(1, -18, 1, -18)
    resizeHandle.BackgroundTransparency = 1
    resizeHandle.Text = "◢"
    resizeHandle.Font = Enum.Font.GothamBold
    resizeHandle.TextSize = 11
    resizeHandle.TextColor3 = THEME.TextDim
    resizeHandle.ZIndex = 5
    resizeHandle.Parent = main

    local resizing, resizeStart, startSize, resizeConn
    resizeHandle.InputBegan:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and not isMin then
            resizing = true
            resizeStart = input.Position
            startSize = main.Size
            if resizeConn then resizeConn:Disconnect() end
            resizeConn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    resizing = false
                    if resizeConn then resizeConn:Disconnect() resizeConn = nil end
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - resizeStart
            main.Size = UDim2.new(0, math.max(680, startSize.X.Offset + delta.X), 0, math.max(450, startSize.Y.Offset + delta.Y))
        end
    end)

    -- Toggle Hotkey
    local toggleKey = config.ToggleKey or Enum.KeyCode.RightControl
    UserInputService.InputBegan:Connect(function(input, gpe)
        if not gpe and input.KeyCode == toggleKey then
            main.Visible = not main.Visible
        end
    end)

    -- ==================== SIDEBAR WITH CATEGORIES ====================
    local sidebar = Instance.new("ScrollingFrame")
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.new(0, 180, 1, -50)
    sidebar.Position = UDim2.new(0, 0, 0, 50)
    sidebar.BackgroundColor3 = THEME.Sidebar
    sidebar.BorderSizePixel = 0
    sidebar.ScrollBarThickness = 2
    sidebar.ScrollBarImageColor3 = THEME.Border
    sidebar.CanvasSize = UDim2.new(0, 0, 0, 0)
    sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sidebar.Parent = main

    local sideLayout = Instance.new("UIListLayout")
    sideLayout.Padding = UDim.new(0, 4)
    sideLayout.Parent = sidebar

    local sidePad = Instance.new("UIPadding")
    sidePad.PaddingTop = UDim.new(0, 12)
    sidePad.PaddingLeft = UDim.new(0, 10)
    sidePad.PaddingRight = UDim.new(0, 10)
    sidePad.Parent = sidebar

    local sideDivider = Instance.new("Frame")
    sideDivider.Size = UDim2.new(0, 1, 1, -50)
    sideDivider.Position = UDim2.new(0, 180, 0, 50)
    sideDivider.BackgroundColor3 = THEME.Border
    sideDivider.BorderSizePixel = 0
    sideDivider.Parent = main

    self.Sidebar = sidebar

    -- ==================== DUAL-COLUMN CONTENT AREA ====================
    local contentArea = Instance.new("Frame")
    contentArea.Name = "ContentArea"
    contentArea.Size = UDim2.new(1, -181, 1, -50)
    contentArea.Position = UDim2.new(0, 181, 0, 50)
    contentArea.BackgroundTransparency = 1
    contentArea.ClipsDescendants = true
    contentArea.Parent = main
    self.ContentArea = contentArea

    self.Tabs = {}
    self.ActiveTab = nil

    return self
end

-- ==================== SIDEBAR CATEGORY HEADER ====================
function UIModule:CreateCategory(name)
    local header = Instance.new("TextLabel")
    header.Name = "Category_" .. name
    header.Size = UDim2.new(1, 0, 0, 22)
    header.BackgroundTransparency = 1
    header.Text = name
    header.Font = Enum.Font.GothamBold
    header.TextSize = 11
    header.TextColor3 = THEME.TextMuted
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Parent = self.Sidebar

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingTop = UDim.new(0, 4)
    pad.Parent = header
end

-- ==================== TAB SYSTEM (EXECUTIVE CAPSULE) ====================
function UIModule:CreateTab(name, iconName)
    local tabBtn = Instance.new("TextButton")
    tabBtn.Name = "Tab_" .. name
    tabBtn.Size = UDim2.new(1, 0, 0, 36)
    tabBtn.BackgroundColor3 = THEME.Sidebar
    tabBtn.BorderSizePixel = 0
    tabBtn.Text = ""
    tabBtn.AutoButtonColor = false
    tabBtn.Parent = self.Sidebar

    local tabCorner = Instance.new("UICorner")
    tabCorner.CornerRadius = UDim.new(0, 6)
    tabCorner.Parent = tabBtn

    local tabGrad = Instance.new("UIGradient")
    tabGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, THEME.Accent),
        ColorSequenceKeypoint.new(1, THEME.AccentDark)
    })
    tabGrad.Enabled = false
    tabGrad.Parent = tabBtn

    -- Left Accent Pip
    local pip = Instance.new("Frame")
    pip.Size = UDim2.new(0, 3, 0.6, 0)
    pip.Position = UDim2.new(0, 0, 0.2, 0)
    pip.BackgroundColor3 = THEME.Accent
    pip.BorderSizePixel = 0
    pip.Visible = false
    pip.Parent = tabBtn

    local icon = Instance.new("ImageLabel")
    icon.Size = UDim2.new(0, 16, 0, 16)
    icon.Position = UDim2.new(0, 12, 0.5, -8)
    icon.BackgroundTransparency = 1
    icon.Parent = tabBtn

    local iconData = self:GetIcon(iconName)
    if iconData then
        applyIcon(icon, iconData, THEME.TextMuted)
    else
        icon.Visible = false
    end

    local textOffset = (iconData and 36) or 12
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -textOffset - 6, 1, 0)
    label.Position = UDim2.new(0, textOffset, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 12
    label.TextColor3 = THEME.TextMuted
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = tabBtn

    -- Dual-Column Scroll Page
    local page = Instance.new("ScrollingFrame")
    page.Name = "Page_" .. name
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = THEME.Border
    page.Visible = false
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Parent = self.ContentArea

    -- Dual-Column Sub-Containers (Left & Right)
    local dualContainer = Instance.new("Frame")
    dualContainer.Size = UDim2.new(1, 0, 0, 0)
    dualContainer.AutomaticSize = Enum.AutomaticSize.Y
    dualContainer.BackgroundTransparency = 1
    dualContainer.Parent = page

    local pagePad = Instance.new("UIPadding")
    pagePad.PaddingTop = UDim.new(0, 14)
    pagePad.PaddingLeft = UDim.new(0, 16)
    pagePad.PaddingRight = UDim.new(0, 16)
    pagePad.PaddingBottom = UDim.new(0, 20)
    pagePad.Parent = dualContainer

    local colLeft = Instance.new("Frame")
    colLeft.Name = "ColLeft"
    colLeft.Size = UDim2.new(0.5, -7, 0, 0)
    colLeft.Position = UDim2.new(0, 0, 0, 0)
    colLeft.AutomaticSize = Enum.AutomaticSize.Y
    colLeft.BackgroundTransparency = 1
    colLeft.Parent = dualContainer

    local colLeftLayout = Instance.new("UIListLayout")
    colLeftLayout.Padding = UDim.new(0, 12)
    colLeftLayout.Parent = colLeft

    local colRight = Instance.new("Frame")
    colRight.Name = "ColRight"
    colRight.Size = UDim2.new(0.5, -7, 0, 0)
    colRight.Position = UDim2.new(0.5, 7, 0, 0)
    colRight.AutomaticSize = Enum.AutomaticSize.Y
    colRight.BackgroundTransparency = 1
    colRight.Parent = dualContainer

    local colRightLayout = Instance.new("UIListLayout")
    colRightLayout.Padding = UDim.new(0, 12)
    colRightLayout.Parent = colRight

    local tabData = {
        Button = tabBtn,
        Page = page,
        ColLeft = colLeft,
        ColRight = colRight,
        Label = label,
        Icon = icon,
        Pip = pip,
        Grad = tabGrad
    }

    local function selectTab()
        for _, t in pairs(self.Tabs) do
            t.Page.Visible = false
            t.Pip.Visible = false
            t.Grad.Enabled = false
            TweenService:Create(t.Button, TweenInfo.new(0.2), { BackgroundColor3 = THEME.Sidebar }):Play()
            TweenService:Create(t.Label, TweenInfo.new(0.2), { TextColor3 = THEME.TextMuted }):Play()
            if t.Icon.Visible then
                TweenService:Create(t.Icon, TweenInfo.new(0.2), { ImageColor3 = THEME.TextMuted }):Play()
            end
        end

        tabData.Page.Visible = true
        tabData.Pip.Visible = true
        tabData.Grad.Enabled = true
        TweenService:Create(tabBtn, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(255, 255, 255) }):Play()
        TweenService:Create(label, TweenInfo.new(0.2), { TextColor3 = THEME.TextHero }):Play()
        if iconData then
            TweenService:Create(icon, TweenInfo.new(0.2), { ImageColor3 = THEME.TextHero }):Play()
        end
        self.ActiveTab = tabData
    end

    tabBtn.MouseButton1Click:Connect(selectTab)
    table.insert(self.Tabs, tabData)

    if #self.Tabs == 1 then
        task.defer(selectTab)
    end

    return tabData
end

-- ==================== MASTER SECTION (WITH EMBEDDED TOGGLE) ====================
function UIModule:CreateSection(tab, config)
    config = config or {}
    local side = config.Side or "Left"
    local parentCol = (side == "Right" and tab.ColRight) or tab.ColLeft or tab.Page or tab

    local card = Instance.new("Frame")
    card.Name = "Card_" .. (config.Title or "Section")
    card.Size = UDim2.new(1, 0, 0, 44)
    card.BackgroundColor3 = THEME.CardBg
    card.BorderSizePixel = 0
    card.Parent = parentCol

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 8)
    cardCorner.Parent = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = THEME.Border
    cardStroke.Thickness = 1
    cardStroke.Parent = card

    local cardLayout = Instance.new("UIListLayout")
    cardLayout.Padding = UDim.new(0, 8)
    cardLayout.Parent = card

    local cardPad = Instance.new("UIPadding")
    cardPad.PaddingTop = UDim.new(0, 12)
    cardPad.PaddingBottom = UDim.new(0, 12)
    cardPad.PaddingLeft = UDim.new(0, 12)
    cardPad.PaddingRight = UDim.new(0, 12)
    cardPad.Parent = card

    -- Header with Title, Subtitle, Icon & Optional Master Toggle
    if config.Title then
        local hdr = Instance.new("Frame")
        hdr.Name = "Header"
        hdr.Size = UDim2.new(1, 0, 0, config.Subtitle and 36 or 24)
        hdr.BackgroundTransparency = 1
        hdr.Parent = card

        local icon = Instance.new("ImageLabel")
        icon.Size = UDim2.new(0, 18, 0, 18)
        icon.Position = UDim2.new(0, 0, 0.5, -9)
        icon.BackgroundTransparency = 1
        icon.Parent = hdr

        local iconData = self:GetIcon(config.Icon)
        local hOffset = 0
        if iconData then
            applyIcon(icon, iconData, THEME.Accent)
            hOffset = 26
        else
            icon.Visible = false
        end

        local titleHolder = Instance.new("Frame")
        titleHolder.Size = UDim2.new(1, -hOffset - (config.Toggle and 50 or 0), 1, 0)
        titleHolder.Position = UDim2.new(0, hOffset, 0, 0)
        titleHolder.BackgroundTransparency = 1
        titleHolder.Parent = hdr

        local titleLbl = Instance.new("TextLabel")
        titleLbl.Size = UDim2.new(1, 0, 0, 18)
        titleLbl.Position = UDim2.new(0, 0, 0.5, config.Subtitle and -16 or -9)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Text = config.Title
        titleLbl.Font = Enum.Font.GothamBold
        titleLbl.TextSize = 13
        titleLbl.TextColor3 = THEME.TextHero
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left
        titleLbl.Parent = titleHolder

        if config.Subtitle then
            local subLbl = Instance.new("TextLabel")
            subLbl.Size = UDim2.new(1, 0, 0, 14)
            subLbl.Position = UDim2.new(0, 0, 0.5, 2)
            subLbl.BackgroundTransparency = 1
            subLbl.Text = config.Subtitle
            subLbl.Font = Enum.Font.Gotham
            subLbl.TextSize = 10
            subLbl.TextColor3 = THEME.TextMuted
            subLbl.TextXAlignment = Enum.TextXAlignment.Left
            subLbl.Parent = titleHolder
        end

        -- Optional Master Toggle Switch in Section Header
        if config.Toggle ~= nil then
            local tState = config.ToggleDefault or false
            local tBtn = Instance.new("TextButton")
            tBtn.Size = UDim2.new(0, 38, 0, 20)
            tBtn.Position = UDim2.new(1, -38, 0.5, -10)
            tBtn.BackgroundColor3 = tState and THEME.Accent or THEME.Recessed
            tBtn.BorderSizePixel = 0
            tBtn.Text = ""
            tBtn.AutoButtonColor = false
            tBtn.Parent = hdr

            local tCorner = Instance.new("UICorner")
            tCorner.CornerRadius = UDim.new(1, 0)
            tCorner.Parent = tBtn

            local tKnob = Instance.new("Frame")
            tKnob.Size = UDim2.new(0, 14, 0, 14)
            tKnob.Position = tState and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
            tKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            tKnob.BorderSizePixel = 0
            tKnob.Parent = tBtn

            local tkCorner = Instance.new("UICorner")
            tkCorner.CornerRadius = UDim.new(1, 0)
            tkCorner.Parent = tKnob

            tBtn.MouseButton1Click:Connect(function()
                tState = not tState
                TweenService:Create(tBtn, TweenInfo.new(0.2), { BackgroundColor3 = tState and THEME.Accent or THEME.Recessed }):Play()
                TweenService:Create(tKnob, TweenInfo.new(0.2), { Position = tState and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 3, 0.5, -7) }):Play()
                if config.ToggleCallback then task.spawn(config.ToggleCallback, tState) end
            end)
        end
    end

    cardLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        card.Size = UDim2.new(1, 0, 0, cardLayout.AbsoluteContentSize.Y + 24)
    end)

    return card
end

-- ==================== WIDGET: STEP SLIDER (- / + BUTTONS) ====================
function UIModule:CreateSlider(parent, config)
    config = config or {}
    local container = (type(parent) == "table" and parent.Page) or parent

    local min = config.Min or 0
    local max = config.Max or 100
    local default = config.Default or min
    local inc = config.Increment or 1
    local suffix = config.Suffix or ""
    local val = math.clamp(default, min, max)

    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 48)
    row.BackgroundTransparency = 1
    row.Parent = container

    -- Top Label Row: Title on Left, Value on Right
    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(0.6, 0, 0, 18)
    titleLbl.Position = UDim2.new(0, 0, 0, 2)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = config.Title or "Slider"
    titleLbl.Font = Enum.Font.GothamMedium
    titleLbl.TextSize = 12
    titleLbl.TextColor3 = THEME.TextHero
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = row

    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(0.4, 0, 0, 18)
    valLbl.Position = UDim2.new(0.6, 0, 0, 2)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = tostring(val) .. suffix
    valLbl.Font = Enum.Font.Gotham
    valLbl.TextSize = 11
    valLbl.TextColor3 = THEME.TextHero
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Parent = row

    -- Slider Row: [ - ] [=========TRACK=========] [ + ]
    local minusBtn = Instance.new("TextButton")
    minusBtn.Size = UDim2.new(0, 16, 0, 16)
    minusBtn.Position = UDim2.new(0, 0, 0, 26)
    minusBtn.BackgroundTransparency = 1
    minusBtn.Text = "-"
    minusBtn.Font = Enum.Font.GothamBold
    minusBtn.TextSize = 14
    minusBtn.TextColor3 = THEME.TextMuted
    minusBtn.Parent = row

    local plusBtn = Instance.new("TextButton")
    plusBtn.Size = UDim2.new(0, 16, 0, 16)
    plusBtn.Position = UDim2.new(1, -16, 0, 26)
    plusBtn.BackgroundTransparency = 1
    plusBtn.Text = "+"
    plusBtn.Font = Enum.Font.GothamBold
    plusBtn.TextSize = 14
    plusBtn.TextColor3 = THEME.TextMuted
    plusBtn.Parent = row

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -44, 0, 4)
    track.Position = UDim2.new(0, 22, 0, 32)
    track.BackgroundColor3 = THEME.Recessed
    track.BorderSizePixel = 0
    track.Parent = row

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = track

    local fill = Instance.new("Frame")
    local ratio = math.clamp((val - min) / (max - min), 0, 1)
    fill.Size = UDim2.new(ratio, 0, 1, 0)
    fill.BackgroundColor3 = THEME.Accent
    fill.BorderSizePixel = 0
    fill.Parent = track

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill

    local thumb = Instance.new("Frame")
    thumb.Size = UDim2.new(0, 14, 0, 14)
    thumb.AnchorPoint = Vector2.new(0.5, 0.5)
    thumb.Position = UDim2.new(ratio, 0, 0.5, 0)
    thumb.BackgroundColor3 = Color3.fromRGB(220, 220, 225)
    thumb.BorderSizePixel = 0
    thumb.Parent = track

    local thCorner = Instance.new("UICorner")
    thCorner.CornerRadius = UDim.new(0, 4)
    thCorner.Parent = thumb

    local function applyValue(newVal)
        val = math.clamp(math.floor((newVal / inc) + 0.5) * inc, min, max)
        local curRatio = (val - min) / (max - min)
        fill.Size = UDim2.new(curRatio, 0, 1, 0)
        thumb.Position = UDim2.new(curRatio, 0, 0.5, 0)
        valLbl.Text = tostring(val) .. suffix
        if config.Callback then task.spawn(config.Callback, val) end
    end

    minusBtn.MouseButton1Click:Connect(function() applyValue(val - inc) end)
    plusBtn.MouseButton1Click:Connect(function() applyValue(val + inc) end)

    local dragging = false
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            local posX = math.clamp(input.Position.X - track.AbsolutePosition.X, 0, track.AbsoluteSize.X)
            applyValue(min + (max - min) * (posX / track.AbsoluteSize.X))
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local posX = math.clamp(input.Position.X - track.AbsolutePosition.X, 0, track.AbsoluteSize.X)
            applyValue(min + (max - min) * (posX / track.AbsoluteSize.X))
        end
    end)

    return {
        Set = applyValue,
        Get = function() return val end
    }
end

-- ==================== WIDGET: COMPACT DROPDOWN ====================
function UIModule:CreateDropdown(parent, config)
    config = config or {}
    local container = (type(parent) == "table" and parent.Page) or parent
    local options = config.Options or {}
    local selected = config.Default or options[1] or ""
    local open = false

    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 32)
    holder.BackgroundTransparency = 1
    holder.ClipsDescendants = true
    holder.Parent = container

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(0.45, 0, 0, 30)
    titleLbl.Position = UDim2.new(0, 0, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = config.Title or "Dropdown"
    titleLbl.Font = Enum.Font.GothamMedium
    titleLbl.TextSize = 12
    titleLbl.TextColor3 = THEME.TextHero
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = holder

    local dropBtn = Instance.new("TextButton")
    dropBtn.Size = UDim2.new(0.55, 0, 0, 28)
    dropBtn.Position = UDim2.new(0.45, 0, 0, 1)
    dropBtn.BackgroundColor3 = THEME.Recessed
    dropBtn.BorderSizePixel = 0
    dropBtn.Text = ""
    dropBtn.AutoButtonColor = false
    dropBtn.Parent = holder

    local dbCorner = Instance.new("UICorner")
    dbCorner.CornerRadius = UDim.new(0, 6)
    dbCorner.Parent = dropBtn

    local dbStroke = Instance.new("UIStroke")
    dbStroke.Color = THEME.Border
    dbStroke.Parent = dropBtn

    local selLbl = Instance.new("TextLabel")
    selLbl.Size = UDim2.new(1, -26, 1, 0)
    selLbl.Position = UDim2.new(0, 8, 0, 0)
    selLbl.BackgroundTransparency = 1
    selLbl.Text = selected
    selLbl.Font = Enum.Font.Gotham
    selLbl.TextSize = 11
    selLbl.TextColor3 = THEME.TextBody
    selLbl.TextXAlignment = Enum.TextXAlignment.Left
    selLbl.Parent = dropBtn

    local arrow = Instance.new("TextLabel")
    arrow.Size = UDim2.new(0, 16, 1, 0)
    arrow.Position = UDim2.new(1, -20, 0, 0)
    arrow.BackgroundTransparency = 1
    arrow.Text = "▼"
    arrow.Font = Enum.Font.GothamBold
    arrow.TextSize = 8
    arrow.TextColor3 = THEME.TextMuted
    arrow.Parent = dropBtn

    local optList = Instance.new("Frame")
    optList.Size = UDim2.new(0.55, 0, 0, #options * 26)
    optList.Position = UDim2.new(0.45, 0, 0, 32)
    optList.BackgroundColor3 = THEME.Recessed
    optList.BorderSizePixel = 0
    optList.Parent = holder

    local optCorner = Instance.new("UICorner")
    optCorner.CornerRadius = UDim.new(0, 6)
    optCorner.Parent = optList

    local optLayout = Instance.new("UIListLayout")
    optLayout.Parent = optList

    local function refresh()
        local targetH = open and (34 + #options * 26 + 4) or 32
        TweenService:Create(holder, TweenInfo.new(0.2), { Size = UDim2.new(1, 0, 0, targetH) }):Play()
        TweenService:Create(arrow, TweenInfo.new(0.2), { Rotation = open and 180 or 0 }):Play()
    end

    for _, opt in ipairs(options) do
        local obtn = Instance.new("TextButton")
        obtn.Size = UDim2.new(1, 0, 0, 26)
        obtn.BackgroundTransparency = 1
        obtn.Text = "  " .. opt
        obtn.Font = Enum.Font.Gotham
        obtn.TextSize = 10
        obtn.TextColor3 = (opt == selected) and THEME.Accent or THEME.TextMuted
        obtn.TextXAlignment = Enum.TextXAlignment.Left
        obtn.Parent = optList

        obtn.MouseButton1Click:Connect(function()
            selected = opt
            selLbl.Text = selected
            open = false
            refresh()
            for _, child in ipairs(optList:GetChildren()) do
                if child:IsA("TextButton") then
                    child.TextColor3 = (child.Text == "  " .. selected) and THEME.Accent or THEME.TextMuted
                end
            end
            if config.Callback then task.spawn(config.Callback, selected) end
        end)
    end

    dropBtn.MouseButton1Click:Connect(function()
        open = not open
        refresh()
    end)

    return {
        Set = function(newOpt)
            selected = newOpt
            selLbl.Text = selected
            if config.Callback then config.Callback(selected) end
        end,
        Get = function() return selected end
    }
end

-- ==================== WIDGET: RIGHT-ALIGNED CHECKBOX ====================
function UIModule:CreateCheckbox(parent, config)
    config = config or {}
    local container = (type(parent) == "table" and parent.Page) or parent
    local checked = config.Default or false

    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, 0, 0, 28)
    row.BackgroundTransparency = 1
    row.Text = ""
    row.AutoButtonColor = false
    row.Parent = container

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -30, 1, 0)
    titleLbl.Position = UDim2.new(0, 0, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = config.Title or "Checkbox"
    titleLbl.Font = Enum.Font.GothamMedium
    titleLbl.TextSize = 12
    titleLbl.TextColor3 = THEME.TextHero
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = row

    local box = Instance.new("Frame")
    box.Size = UDim2.new(0, 18, 0, 18)
    box.Position = UDim2.new(1, -18, 0.5, -9)
    box.BackgroundColor3 = checked and THEME.Accent or THEME.Recessed
    box.BorderSizePixel = 0
    box.Parent = row

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 4)
    bCorner.Parent = box

    local bStroke = Instance.new("UIStroke")
    bStroke.Color = checked and THEME.Accent or THEME.Border
    bStroke.Parent = box

    local checkmark = Instance.new("TextLabel")
    checkmark.Size = UDim2.new(1, 0, 1, 0)
    checkmark.BackgroundTransparency = 1
    checkmark.Text = "✓"
    checkmark.Font = Enum.Font.GothamBold
    checkmark.TextSize = 11
    checkmark.TextColor3 = Color3.fromRGB(255, 255, 255)
    checkmark.Visible = checked
    checkmark.Parent = box

    local function toggle(val)
        checked = val
        checkmark.Visible = checked
        TweenService:Create(box, TweenInfo.new(0.2), {
            BackgroundColor3 = checked and THEME.Accent or THEME.Recessed
        }):Play()
        TweenService:Create(bStroke, TweenInfo.new(0.2), {
            Color = checked and THEME.Accent or THEME.Border
        }):Play()
        if config.Callback then task.spawn(config.Callback, checked) end
    end

    row.MouseButton1Click:Connect(function() toggle(not checked) end)

    return {
        Set = toggle,
        Get = function() return checked end
    }
end

-- ==================== WIDGET: STATUS INFO ROW ====================
function UIModule:CreateInfoLabel(parent, config)
    config = config or {}
    local container = (type(parent) == "table" and parent.Page) or parent

    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 24)
    row.BackgroundTransparency = 1
    row.Parent = container

    local icon = Instance.new("ImageLabel")
    icon.Size = UDim2.new(0, 14, 0, 14)
    icon.Position = UDim2.new(0, 0, 0.5, -7)
    icon.BackgroundTransparency = 1
    icon.Parent = row

    local iconData = self:GetIcon(config.Icon or "refresh-cw")
    local offset = 0
    if iconData then
        applyIcon(icon, iconData, THEME.TextMuted)
        offset = 20
    else
        icon.Visible = false
    end

    local textLbl = Instance.new("TextLabel")
    textLbl.Size = UDim2.new(1, -offset, 1, 0)
    textLbl.Position = UDim2.new(0, offset, 0, 0)
    textLbl.BackgroundTransparency = 1
    textLbl.Text = config.Text or "Status info"
    textLbl.Font = Enum.Font.Gotham
    textLbl.TextSize = 11
    textLbl.TextColor3 = THEME.TextMuted
    textLbl.TextXAlignment = Enum.TextXAlignment.Left
    textLbl.Parent = row

    return {
        Set = function(newText) textLbl.Text = newText end
    }
end

-- ==================== WIDGET: STANDARD BUTTON ====================
function UIModule:CreateButton(parent, config)
    config = config or {}
    local container = (type(parent) == "table" and parent.Page) or parent

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = THEME.CardInner
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = container

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Color = THEME.Border
    stroke.Parent = btn

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -20, 1, 0)
    titleLbl.Position = UDim2.new(0, 10, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = config.Title or "Button"
    titleLbl.Font = Enum.Font.GothamMedium
    titleLbl.TextSize = 12
    titleLbl.TextColor3 = THEME.TextHero
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = btn

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(32, 32, 42) }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = THEME.CardInner }):Play()
    end)
    btn.MouseButton1Click:Connect(function()
        if config.Callback then task.spawn(config.Callback) end
    end)

    return btn
end

-- ==================== WIDGET: TEXT INPUT ====================
function UIModule:CreateInput(parent, config)
    config = config or {}
    local container = (type(parent) == "table" and parent.Page) or parent

    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 32)
    row.BackgroundTransparency = 1
    row.Parent = container

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(0.45, 0, 1, 0)
    titleLbl.Position = UDim2.new(0, 0, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = config.Title or "Input"
    titleLbl.Font = Enum.Font.GothamMedium
    titleLbl.TextSize = 12
    titleLbl.TextColor3 = THEME.TextHero
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = row

    local tb = Instance.new("TextBox")
    tb.Size = UDim2.new(0.55, 0, 0, 26)
    tb.Position = UDim2.new(0.45, 0, 0.5, -13)
    tb.BackgroundColor3 = THEME.Recessed
    tb.BorderSizePixel = 0
    tb.Text = config.Default or ""
    tb.PlaceholderText = config.Placeholder or "Type here..."
    tb.PlaceholderColor3 = THEME.TextDim
    tb.Font = Enum.Font.Gotham
    tb.TextSize = 11
    tb.TextColor3 = THEME.TextHero
    tb.ClearTextOnFocus = false
    tb.Parent = row

    local tbCorner = Instance.new("UICorner")
    tbCorner.CornerRadius = UDim.new(0, 6)
    tbCorner.Parent = tb

    local tbStroke = Instance.new("UIStroke")
    tbStroke.Color = THEME.Border
    tbStroke.Parent = tb

    tb.Focused:Connect(function()
        TweenService:Create(tbStroke, TweenInfo.new(0.2), { Color = THEME.Accent }):Play()
    end)
    tb.FocusLost:Connect(function(enter)
        TweenService:Create(tbStroke, TweenInfo.new(0.2), { Color = THEME.Border }):Play()
        if config.Callback then task.spawn(config.Callback, tb.Text, enter) end
    end)

    return {
        Set = function(t) tb.Text = t end,
        Get = function() return tb.Text end
    }
end

-- ==================== NOTIFICATIONS ====================
function UIModule:Notify(config)
    config = config or {}
    local duration = config.Duration or 3.5

    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 60)
    card.BackgroundColor3 = THEME.CardBg
    card.BorderSizePixel = 0
    card.Parent = self.NotifContainer

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 8)
    cardCorner.Parent = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = THEME.Border
    cardStroke.Parent = card

    local tLbl = Instance.new("TextLabel")
    tLbl.Size = UDim2.new(1, -20, 0, 18)
    tLbl.Position = UDim2.new(0, 12, 0, 10)
    tLbl.BackgroundTransparency = 1
    tLbl.Text = config.Title or "Notification"
    tLbl.Font = Enum.Font.GothamBold
    tLbl.TextSize = 12
    tLbl.TextColor3 = THEME.TextHero
    tLbl.TextXAlignment = Enum.TextXAlignment.Left
    tLbl.Parent = card

    local dLbl = Instance.new("TextLabel")
    dLbl.Size = UDim2.new(1, -20, 0, 18)
    dLbl.Position = UDim2.new(0, 12, 0, 28)
    dLbl.BackgroundTransparency = 1
    dLbl.Text = config.Content or ""
    dLbl.Font = Enum.Font.Gotham
    dLbl.TextSize = 11
    dLbl.TextColor3 = THEME.TextMuted
    dLbl.TextXAlignment = Enum.TextXAlignment.Left
    dLbl.Parent = card

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, 0, 0, 2)
    bar.Position = UDim2.new(0, 0, 1, -2)
    bar.BackgroundColor3 = THEME.Accent
    bar.BorderSizePixel = 0
    bar.Parent = card

    TweenService:Create(bar, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) }):Play()
    task.delay(duration, function()
        local tw = TweenService:Create(card, TweenInfo.new(0.3), { BackgroundTransparency = 1 })
        tw:Play()
        tw.Completed:Connect(function() card:Destroy() end)
    end)
end

return UIModule
