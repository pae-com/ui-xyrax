-- ==============================================================================
--           XYRAX HUB - BESPOKE ARCHITECTURE (MONOCHROME EDITION)
--          (Custom Micro-Geometry, Precision Gauges & Tactile Depth)
-- ==============================================================================
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local UIModule = {}
UIModule.__index = UIModule

-- ==================== NOIR SPECULAR PALETTE ====================
local THEME = {
    Canvas       = Color3.fromRGB(11, 11, 13),      -- Deepest Obsidian
    CardBg       = Color3.fromRGB(16, 16, 20),      -- Dark Matte Glass
    CardElevated = Color3.fromRGB(22, 22, 28),      -- Component Surface
    RecessedTray = Color3.fromRGB(13, 13, 16),      -- Sunken Depth Chamber
    
    -- Metallic Sheen & Specular Keypoints
    Platinum     = Color3.fromRGB(255, 255, 255),    -- Pure Highlight
    SilverLight  = Color3.fromRGB(210, 210, 220),    -- Active Light
    SilverMid    = Color3.fromRGB(140, 140, 155),    -- Neutral Brushed Steel
    SilverDark   = Color3.fromRGB(75, 75, 90),       -- Shadow Stroke
    BorderStroke = Color3.fromRGB(38, 38, 48),       -- Subtle Perimeter
    
    TextHero     = Color3.fromRGB(255, 255, 255),
    TextBody     = Color3.fromRGB(210, 210, 225),
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
    ["layers"]             = "rbxassetid://115223357399375",
    ["activity"]           = "rbxassetid://94212016861936",
    ["arrow-right"]        = "rbxassetid://113692007244654"
}

local IconAliases = {
    ["sliders"]   = "sliders-horizontal",
    ["sword"]     = "swords",
    ["gear"]      = "settings",
    ["setting"]   = "settings",
    ["sparkle"]   = "sparkles",
    ["bell-ring"] = "bell",
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

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "XyraxBespoke_" .. tostring(math.random(1000, 9999))
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

    -- Notification Container
    local notifContainer = Instance.new("Frame")
    notifContainer.Name = "Notifs"
    notifContainer.Size = UDim2.new(0, 320, 1, -50)
    notifContainer.Position = UDim2.new(1, -340, 0, 25)
    notifContainer.BackgroundTransparency = 1
    notifContainer.Parent = screenGui

    local notifLayout = Instance.new("UIListLayout")
    notifLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    notifLayout.Padding = UDim.new(0, 10)
    notifLayout.Parent = notifContainer
    self.NotifContainer = notifContainer

    -- Main Shell
    local main = Instance.new("Frame")
    main.Name = "MainWindow"
    main.Size = config.Size or UDim2.new(0, 800, 0, 530)
    main.Position = UDim2.new(0.5, -400, 0.5, -265)
    main.BackgroundColor3 = THEME.Canvas
    main.BorderSizePixel = 0
    main.ClipsDescendants = true
    main.Active = true
    main.Parent = screenGui
    self.MainFrame = main

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 18)
    mainCorner.Parent = main

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = THEME.SilverDark
    mainStroke.Thickness = 1.2
    mainStroke.Parent = main

    local strokeGrad = Instance.new("UIGradient")
    strokeGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.0, Color3.fromRGB(240, 240, 255)),
        ColorSequenceKeypoint.new(0.4, Color3.fromRGB(50, 50, 60)),
        ColorSequenceKeypoint.new(1.0, Color3.fromRGB(160, 160, 180))
    })
    strokeGrad.Rotation = 45
    strokeGrad.Parent = mainStroke

    -- Header Island
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 56)
    header.BackgroundTransparency = 1
    header.Active = true
    header.ZIndex = 2
    header.Parent = main

    -- Monogram Chamber
    local emblem = Instance.new("Frame")
    emblem.Size = UDim2.new(0, 32, 0, 32)
    emblem.Position = UDim2.new(0, 22, 0.5, -16)
    emblem.BackgroundColor3 = Color3.fromRGB(245, 245, 250)
    emblem.BorderSizePixel = 0
    emblem.Parent = header

    local emblemCorner = Instance.new("UICorner")
    emblemCorner.CornerRadius = UDim.new(0, 8)
    emblemCorner.Parent = emblem

    local emblemGrad = Instance.new("UIGradient")
    emblemGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 150, 165))
    })
    emblemGrad.Rotation = 45
    emblemGrad.Parent = emblem

    local emblemText = Instance.new("TextLabel")
    emblemText.Size = UDim2.new(1, 0, 1, 0)
    emblemText.BackgroundTransparency = 1
    emblemText.Text = string.sub(config.Title or "X", 1, 1)
    emblemText.Font = Enum.Font.GothamBold
    emblemText.TextSize = 14
    emblemText.TextColor3 = Color3.fromRGB(14, 14, 18)
    emblemText.Parent = emblem

    local titleHolder = Instance.new("Frame")
    titleHolder.Size = UDim2.new(0, 200, 1, 0)
    titleHolder.Position = UDim2.new(0, 64, 0, 0)
    titleHolder.BackgroundTransparency = 1
    titleHolder.Parent = header

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, 0, 0, 20)
    titleLbl.Position = UDim2.new(0, 0, 0.5, config.Subtitle and -15 or -10)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = config.Title or "Xyrax Hub"
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 14
    titleLbl.TextColor3 = THEME.TextHero
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = titleHolder

    if config.Subtitle then
        local subLbl = Instance.new("TextLabel")
        subLbl.Size = UDim2.new(1, 0, 0, 14)
        subLbl.Position = UDim2.new(0, 0, 0.5, 4)
        subLbl.BackgroundTransparency = 1
        subLbl.Text = string.upper(config.Subtitle)
        subLbl.Font = Enum.Font.GothamBold
        subLbl.TextSize = 9
        subLbl.TextColor3 = THEME.SilverMid
        subLbl.TextXAlignment = Enum.TextXAlignment.Left
        subLbl.Parent = titleHolder
    end

    -- Header Controls & Aligned Status Pill
    local controls = Instance.new("Frame")
    controls.Size = UDim2.new(0, 220, 1, 0)
    controls.Position = UDim2.new(1, -235, 0, 0)
    controls.BackgroundTransparency = 1
    controls.Parent = header

    -- True Centered FPS Pill
    local statusPill = Instance.new("Frame")
    statusPill.Name = "StatusPill"
    statusPill.AnchorPoint = Vector2.new(0, 0.5)
    statusPill.Position = UDim2.new(0, 26, 0.5, 0)
    statusPill.Size = UDim2.new(0, 0, 0, 26)
    statusPill.AutomaticSize = Enum.AutomaticSize.X
    statusPill.BackgroundColor3 = THEME.CardBg
    statusPill.BorderSizePixel = 0
    statusPill.Parent = controls

    local spCorner = Instance.new("UICorner")
    spCorner.CornerRadius = UDim.new(1, 0)
    spCorner.Parent = statusPill

    local spStroke = Instance.new("UIStroke")
    spStroke.Color = THEME.BorderStroke
    spStroke.Thickness = 1
    spStroke.Parent = statusPill

    local spLayout = Instance.new("UIListLayout")
    spLayout.FillDirection = Enum.FillDirection.Horizontal
    spLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    spLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    spLayout.Padding = UDim.new(0, 6)
    spLayout.Parent = statusPill

    local spPad = Instance.new("UIPadding")
    spPad.PaddingLeft = UDim.new(0, 10)
    spPad.PaddingRight = UDim.new(0, 12)
    spPad.Parent = statusPill

    local pulseDot = Instance.new("Frame")
    pulseDot.Size = UDim2.new(0, 6, 0, 6)
    pulseDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    pulseDot.BorderSizePixel = 0
    pulseDot.Parent = statusPill

    local pdCorner = Instance.new("UICorner")
    pdCorner.CornerRadius = UDim.new(1, 0)
    pdCorner.Parent = pulseDot

    local fpsLbl = Instance.new("TextLabel")
    fpsLbl.Size = UDim2.new(0, 0, 1, 0)
    fpsLbl.AutomaticSize = Enum.AutomaticSize.X
    fpsLbl.BackgroundTransparency = 1
    fpsLbl.Text = "60 FPS"
    fpsLbl.Font = Enum.Font.GothamBold
    fpsLbl.TextSize = 10
    fpsLbl.TextColor3 = THEME.TextBody
    fpsLbl.TextYAlignment = Enum.TextYAlignment.Center
    fpsLbl.Parent = statusPill

    local lastUpdate, frames = tick(), 0
    RunService.RenderStepped:Connect(function()
        frames = frames + 1
        if tick() - lastUpdate >= 1 then
            fpsLbl.Text = tostring(frames) .. " FPS"
            frames = 0
            lastUpdate = tick()
        end
    end)

    -- Window Minimize Button
    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 26, 0, 26)
    minBtn.Position = UDim2.new(1, -66, 0.5, -13)
    minBtn.BackgroundColor3 = THEME.CardBg
    minBtn.BorderSizePixel = 0
    minBtn.Text = "—"
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 11
    minBtn.TextColor3 = THEME.TextMuted
    minBtn.AutoButtonColor = false
    minBtn.Parent = controls

    local minCorner = Instance.new("UICorner")
    minCorner.CornerRadius = UDim.new(0, 7)
    minCorner.Parent = minBtn

    local minStroke = Instance.new("UIStroke")
    minStroke.Color = THEME.BorderStroke
    minStroke.Parent = minBtn

    -- True Pixel-Crisp "X" Button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 26, 0, 26)
    closeBtn.Position = UDim2.new(1, -32, 0.5, -13)
    closeBtn.BackgroundColor3 = THEME.CardBg
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = ""
    closeBtn.AutoButtonColor = false
    closeBtn.Parent = controls

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 7)
    closeCorner.Parent = closeBtn

    local closeStroke = Instance.new("UIStroke")
    closeStroke.Color = THEME.BorderStroke
    closeStroke.Parent = closeBtn

    local closeIcon = Instance.new("ImageLabel")
    closeIcon.Size = UDim2.new(0, 13, 0, 13)
    closeIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    closeIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
    closeIcon.BackgroundTransparency = 1
    closeIcon.Image = "rbxassetid://110786993356448"
    closeIcon.ImageColor3 = THEME.TextMuted
    closeIcon.Parent = closeBtn

    -- Hover animations
    minBtn.MouseEnter:Connect(function()
        TweenService:Create(minBtn, TweenInfo.new(0.2), { BackgroundColor3 = THEME.CardElevated, TextColor3 = THEME.TextHero }):Play()
        TweenService:Create(minStroke, TweenInfo.new(0.2), { Color = THEME.SilverMid }):Play()
    end)
    minBtn.MouseLeave:Connect(function()
        TweenService:Create(minBtn, TweenInfo.new(0.2), { BackgroundColor3 = THEME.CardBg, TextColor3 = THEME.TextMuted }):Play()
        TweenService:Create(minStroke, TweenInfo.new(0.2), { Color = THEME.BorderStroke }):Play()
    end)

    closeBtn.MouseEnter:Connect(function()
        TweenService:Create(closeBtn, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(38, 38, 46) }):Play()
        TweenService:Create(closeStroke, TweenInfo.new(0.2), { Color = Color3.fromRGB(150, 150, 165) }):Play()
        TweenService:Create(closeIcon, TweenInfo.new(0.2), { ImageColor3 = Color3.fromRGB(255, 255, 255) }):Play()
    end)
    closeBtn.MouseLeave:Connect(function()
        TweenService:Create(closeBtn, TweenInfo.new(0.2), { BackgroundColor3 = THEME.CardBg }):Play()
        TweenService:Create(closeStroke, TweenInfo.new(0.2), { Color = THEME.BorderStroke }):Play()
        TweenService:Create(closeIcon, TweenInfo.new(0.2), { ImageColor3 = THEME.TextMuted }):Play()
    end)

    local isMin, origSize = false, main.Size
    minBtn.MouseButton1Click:Connect(function()
        isMin = not isMin
        if isMin then
            origSize = main.Size
            TweenService:Create(main, TweenInfo.new(0.32, Enum.EasingStyle.Quart), { Size = UDim2.new(origSize.X.Scale, origSize.X.Offset, 0, 56) }):Play()
        else
            TweenService:Create(main, TweenInfo.new(0.32, Enum.EasingStyle.Quart), { Size = origSize }):Play()
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
    header.InputBegan:Connect(function(input)
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

    -- Resizer Handle
    local resizeHandle = Instance.new("TextButton")
    resizeHandle.Size = UDim2.new(0, 20, 0, 20)
    resizeHandle.Position = UDim2.new(1, -20, 1, -20)
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
            main.Size = UDim2.new(0, math.max(620, startSize.X.Offset + delta.X), 0, math.max(400, startSize.Y.Offset + delta.Y))
        end
    end)

    -- Toggle Hotkey
    local toggleKey = config.ToggleKey or Enum.KeyCode.RightControl
    UserInputService.InputBegan:Connect(function(input, gpe)
        if not gpe and input.KeyCode == toggleKey then
            main.Visible = not main.Visible
        end
    end)

    -- Horizontal Floating Capsule Dock
    local navRibbon = Instance.new("Frame")
    navRibbon.Name = "NavRibbon"
    navRibbon.Size = UDim2.new(1, -44, 0, 42)
    navRibbon.Position = UDim2.new(0, 22, 0, 62)
    navRibbon.BackgroundColor3 = THEME.CardBg
    navRibbon.BorderSizePixel = 0
    navRibbon.ZIndex = 3
    navRibbon.Parent = main

    local navCorner = Instance.new("UICorner")
    navCorner.CornerRadius = UDim.new(0, 12)
    navCorner.Parent = navRibbon

    local navStroke = Instance.new("UIStroke")
    navStroke.Color = THEME.BorderStroke
    navStroke.Thickness = 1
    navStroke.Parent = navRibbon

    local glidePill = Instance.new("Frame")
    glidePill.Name = "GlideIndicator"
    glidePill.Size = UDim2.new(0, 100, 0, 32)
    glidePill.Position = UDim2.new(0, 5, 0.5, -16)
    glidePill.BackgroundColor3 = THEME.CardElevated
    glidePill.BorderSizePixel = 0
    glidePill.ZIndex = 3
    glidePill.Visible = false
    glidePill.Parent = navRibbon

    local gpCorner = Instance.new("UICorner")
    gpCorner.CornerRadius = UDim.new(0, 9)
    gpCorner.Parent = glidePill

    local gpStroke = Instance.new("UIStroke")
    gpStroke.Color = THEME.SilverMid
    gpStroke.Thickness = 1
    gpStroke.Parent = glidePill

    local navScroll = Instance.new("ScrollingFrame")
    navScroll.Name = "NavItems"
    navScroll.Size = UDim2.new(1, -10, 1, 0)
    navScroll.Position = UDim2.new(0, 5, 0, 0)
    navScroll.BackgroundTransparency = 1
    navScroll.BorderSizePixel = 0
    navScroll.ScrollBarThickness = 0
    navScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    navScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
    navScroll.ZIndex = 4
    navScroll.Parent = navRibbon

    local navLayout = Instance.new("UIListLayout")
    navLayout.FillDirection = Enum.FillDirection.Horizontal
    navLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    navLayout.Padding = UDim.new(0, 6)
    navLayout.Parent = navScroll

    self.NavScroll = navScroll
    self.GlidePill = glidePill

    -- Content Area
    local contentArea = Instance.new("Frame")
    contentArea.Name = "ContentArea"
    contentArea.Size = UDim2.new(1, -44, 1, -122)
    contentArea.Position = UDim2.new(0, 22, 0, 114)
    contentArea.BackgroundTransparency = 1
    contentArea.ClipsDescendants = true
    contentArea.ZIndex = 2
    contentArea.Parent = main
    self.ContentArea = contentArea

    self.Tabs = {}
    self.ActiveTab = nil

    return self
end

-- ==================== NOTIFICATIONS ====================
function UIModule:Notify(config)
    config = config or {}
    local duration = config.Duration or 3.5

    local pill = Instance.new("Frame")
    pill.Size = UDim2.new(1, 0, 0, 62)
    pill.BackgroundColor3 = THEME.CardBg
    pill.BorderSizePixel = 0
    pill.ClipsDescendants = true
    pill.Parent = self.NotifContainer

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = pill

    local stroke = Instance.new("UIStroke")
    stroke.Color = THEME.SilverDark
    stroke.Thickness = 1
    stroke.Parent = pill

    local tLbl = Instance.new("TextLabel")
    tLbl.Size = UDim2.new(1, -28, 0, 18)
    tLbl.Position = UDim2.new(0, 14, 0, 10)
    tLbl.BackgroundTransparency = 1
    tLbl.Text = config.Title or "Notification"
    tLbl.Font = Enum.Font.GothamBold
    tLbl.TextSize = 12
    tLbl.TextColor3 = THEME.TextHero
    tLbl.TextXAlignment = Enum.TextXAlignment.Left
    tLbl.Parent = pill

    local dLbl = Instance.new("TextLabel")
    dLbl.Size = UDim2.new(1, -28, 0, 18)
    dLbl.Position = UDim2.new(0, 14, 0, 28)
    dLbl.BackgroundTransparency = 1
    dLbl.Text = config.Content or ""
    dLbl.Font = Enum.Font.Gotham
    dLbl.TextSize = 11
    dLbl.TextColor3 = THEME.TextMuted
    dLbl.TextXAlignment = Enum.TextXAlignment.Left
    dLbl.Parent = pill

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, 0, 0, 2)
    bar.Position = UDim2.new(0, 0, 1, -2)
    bar.BackgroundColor3 = Color3.fromRGB(240, 240, 250)
    bar.BorderSizePixel = 0
    bar.Parent = pill

    TweenService:Create(bar, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) }):Play()
    task.delay(duration, function()
        local tw = TweenService:Create(pill, TweenInfo.new(0.3, Enum.EasingStyle.Quart), { BackgroundTransparency = 1 })
        tw:Play()
        tw.Completed:Connect(function() pill:Destroy() end)
    end)
end

-- ==================== TAB SYSTEM ====================
function UIModule:CreateTab(name, iconName)
    local tabBtn = Instance.new("TextButton")
    tabBtn.Name = "Nav_" .. name
    tabBtn.Size = UDim2.new(0, 0, 0, 32)
    tabBtn.AutomaticSize = Enum.AutomaticSize.X
    tabBtn.BackgroundTransparency = 1
    tabBtn.Text = ""
    tabBtn.AutoButtonColor = false
    tabBtn.Parent = self.NavScroll

    local tabPad = Instance.new("UIPadding")
    tabPad.PaddingLeft = UDim.new(0, 14)
    tabPad.PaddingRight = UDim.new(0, 14)
    tabPad.Parent = tabBtn

    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    tabLayout.Padding = UDim.new(0, 8)
    tabLayout.Parent = tabBtn

    local icon = Instance.new("ImageLabel")
    icon.Size = UDim2.new(0, 15, 0, 15)
    icon.BackgroundTransparency = 1
    icon.Parent = tabBtn

    local iconData = self:GetIcon(iconName)
    if iconData then
        applyIcon(icon, iconData, THEME.TextMuted)
    else
        icon.Visible = false
    end

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 0, 1, 0)
    label.AutomaticSize = Enum.AutomaticSize.X
    label.BackgroundTransparency = 1
    label.Text = name
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 12
    label.TextColor3 = THEME.TextMuted
    label.Parent = tabBtn

    local page = Instance.new("ScrollingFrame")
    page.Name = "Page_" .. name
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = THEME.SilverDark
    page.Visible = false
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Parent = self.ContentArea

    local pageLayout = Instance.new("UIListLayout")
    pageLayout.Padding = UDim.new(0, 14)
    pageLayout.Parent = page

    local pagePadding = Instance.new("UIPadding")
    pagePadding.PaddingTop = UDim.new(0, 6)
    pagePadding.PaddingBottom = UDim.new(0, 16)
    pagePadding.PaddingRight = UDim.new(0, 6)
    pagePadding.Parent = page

    local tabData = {
        Button = tabBtn,
        Page = page,
        Label = label,
        Icon = icon,
        IconData = iconData
    }

    local function selectTab()
        for _, t in pairs(self.Tabs) do
            t.Page.Visible = false
            TweenService:Create(t.Label, TweenInfo.new(0.2), { TextColor3 = THEME.TextMuted }):Play()
            if t.Icon.Visible then
                TweenService:Create(t.Icon, TweenInfo.new(0.2), { ImageColor3 = THEME.TextMuted }):Play()
            end
        end

        tabData.Page.Visible = true
        self.GlidePill.Visible = true

        task.defer(function()
            local targetX = tabBtn.AbsolutePosition.X - self.NavScroll.AbsolutePosition.X + self.NavScroll.CanvasPosition.X
            local targetW = tabBtn.AbsoluteSize.X
            TweenService:Create(self.GlidePill, TweenInfo.new(0.3, Enum.EasingStyle.Quart), {
                Position = UDim2.new(0, targetX + 5, 0.5, -16),
                Size = UDim2.new(0, targetW, 0, 32)
            }):Play()
        end)

        TweenService:Create(label, TweenInfo.new(0.25), { TextColor3 = THEME.TextHero }):Play()
        if iconData then
            TweenService:Create(icon, TweenInfo.new(0.25), { ImageColor3 = THEME.TextHero }):Play()
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

-- ==================== ARCHITECTURAL SECTION CARD ====================
function UIModule:CreateSection(tab, config)
    config = config or {}
    local page = (type(tab) == "table" and tab.Page) or tab

    local card = Instance.new("Frame")
    card.Name = "Card_" .. (config.Title or "Section")
    card.Size = UDim2.new(1, 0, 0, 40)
    card.BackgroundColor3 = THEME.CardBg
    card.BorderSizePixel = 0
    card.Parent = page

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 14)
    cardCorner.Parent = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = THEME.BorderStroke
    cardStroke.Thickness = 1
    cardStroke.Parent = card

    local cardLayout = Instance.new("UIListLayout")
    cardLayout.Padding = UDim.new(0, 8)
    cardLayout.Parent = card

    local cardPad = Instance.new("UIPadding")
    cardPad.PaddingTop = UDim.new(0, 14)
    cardPad.PaddingBottom = UDim.new(0, 14)
    cardPad.PaddingLeft = UDim.new(0, 16)
    cardPad.PaddingRight = UDim.new(0, 16)
    cardPad.Parent = card

    if config.Title then
        local hdr = Instance.new("Frame")
        hdr.Size = UDim2.new(1, 0, 0, 26)
        hdr.BackgroundTransparency = 1
        hdr.Parent = card

        -- Frosted Icon Chip for Section
        local chip = Instance.new("Frame")
        chip.Size = UDim2.new(0, 22, 0, 22)
        chip.Position = UDim2.new(0, 0, 0.5, -11)
        chip.BackgroundColor3 = THEME.CardElevated
        chip.BorderSizePixel = 0
        chip.Parent = hdr

        local chipCorner = Instance.new("UICorner")
        chipCorner.CornerRadius = UDim.new(0, 6)
        chipCorner.Parent = chip

        local chipStroke = Instance.new("UIStroke")
        chipStroke.Color = THEME.BorderStroke
        chipStroke.Parent = chip

        local headerIcon = Instance.new("ImageLabel")
        headerIcon.Size = UDim2.new(0, 13, 0, 13)
        headerIcon.AnchorPoint = Vector2.new(0.5, 0.5)
        headerIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
        headerIcon.BackgroundTransparency = 1
        headerIcon.Parent = chip

        local iconData = self:GetIcon(config.Icon)
        local hOffset = 0
        if iconData then
            applyIcon(headerIcon, iconData, THEME.TextHero)
            hOffset = 30
        else
            chip.Visible = false
        end

        local titleLbl = Instance.new("TextLabel")
        titleLbl.Size = UDim2.new(1, -hOffset, 1, 0)
        titleLbl.Position = UDim2.new(0, hOffset, 0, 0)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Text = string.upper(config.Title)
        titleLbl.Font = Enum.Font.GothamBold
        titleLbl.TextSize = 11
        titleLbl.TextColor3 = THEME.TextHero
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left
        titleLbl.Parent = hdr
    end

    cardLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        card.Size = UDim2.new(1, 0, 0, cardLayout.AbsoluteContentSize.Y + 28)
    end)

    return card
end

-- ==================== BESPOKE WIDGET 1: ACTION CELL (BUTTON) ====================
function UIModule:CreateButton(parent, config)
    config = config or {}
    local container = (type(parent) == "table" and parent.Page) or parent

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, config.Description and 54 or 44)
    btn.BackgroundColor3 = THEME.CardElevated
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = container

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Color = THEME.BorderStroke
    stroke.Thickness = 1
    stroke.Parent = btn

    -- Left Machined Icon Chamber
    local chamber = Instance.new("Frame")
    chamber.Size = UDim2.new(0, 30, 0, 30)
    chamber.Position = UDim2.new(0, 10, 0.5, -15)
    chamber.BackgroundColor3 = THEME.RecessedTray
    chamber.BorderSizePixel = 0
    chamber.Parent = btn

    local chCorner = Instance.new("UICorner")
    chCorner.CornerRadius = UDim.new(0, 7)
    chCorner.Parent = chamber

    local chStroke = Instance.new("UIStroke")
    chStroke.Color = THEME.BorderStroke
    chStroke.Parent = chamber

    local icon = Instance.new("ImageLabel")
    icon.Size = UDim2.new(0, 15, 0, 15)
    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.Position = UDim2.new(0.5, 0, 0.5, 0)
    icon.BackgroundTransparency = 1
    icon.Parent = chamber

    local iconData = self:GetIcon(config.Icon)
    local offset = 14
    if iconData then
        applyIcon(icon, iconData, THEME.TextHero)
        offset = 48
    else
        chamber.Visible = false
    end

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -offset - 35, 0, 18)
    titleLbl.Position = UDim2.new(0, offset, 0, config.Description and 10 or 13)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = config.Title or "Action"
    titleLbl.Font = Enum.Font.GothamMedium
    titleLbl.TextSize = 12
    titleLbl.TextColor3 = THEME.TextHero
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = btn

    if config.Description then
        local descLbl = Instance.new("TextLabel")
        descLbl.Size = UDim2.new(1, -offset - 35, 0, 14)
        descLbl.Position = UDim2.new(0, offset, 0, 29)
        descLbl.BackgroundTransparency = 1
        descLbl.Text = config.Description
        descLbl.Font = Enum.Font.Gotham
        descLbl.TextSize = 10
        descLbl.TextColor3 = THEME.TextMuted
        descLbl.TextXAlignment = Enum.TextXAlignment.Left
        descLbl.Parent = btn
    end

    -- Interactive Action Arrow Glyph (Slides on Hover)
    local arrow = Instance.new("ImageLabel")
    arrow.Size = UDim2.new(0, 14, 0, 14)
    arrow.Position = UDim2.new(1, -26, 0.5, -7)
    arrow.BackgroundTransparency = 1
    arrow.Image = "rbxassetid://113692007244654"
    arrow.ImageColor3 = THEME.TextDim
    arrow.Parent = btn

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(28, 28, 36) }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2), { Color = THEME.SilverMid }):Play()
        TweenService:Create(arrow, TweenInfo.new(0.2), { Position = UDim2.new(1, -22, 0.5, -7), ImageColor3 = THEME.TextHero }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = THEME.CardElevated }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2), { Color = THEME.BorderStroke }):Play()
        TweenService:Create(arrow, TweenInfo.new(0.2), { Position = UDim2.new(1, -26, 0.5, -7), ImageColor3 = THEME.TextDim }):Play()
    end)
    btn.MouseButton1Click:Connect(function()
        local orig = btn.Size
        TweenService:Create(btn, TweenInfo.new(0.08), { Size = UDim2.new(orig.X.Scale, orig.X.Offset - 2, orig.Y.Scale, orig.Y.Offset - 2) }):Play()
        task.wait(0.08)
        TweenService:Create(btn, TweenInfo.new(0.08), { Size = orig }):Play()
        if config.Callback then task.spawn(config.Callback) end
    end)

    return btn
end

-- ==================== BESPOKE WIDGET 2: SUNKEN TACTILE TOGGLE ====================
function UIModule:CreateToggle(parent, config)
    config = config or {}
    local container = (type(parent) == "table" and parent.Page) or parent
    local state = config.Default or false

    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, 0, 0, config.Description and 54 or 44)
    row.BackgroundColor3 = THEME.CardElevated
    row.BorderSizePixel = 0
    row.Text = ""
    row.AutoButtonColor = false
    row.Parent = container

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = row

    local stroke = Instance.new("UIStroke")
    stroke.Color = THEME.BorderStroke
    stroke.Thickness = 1
    stroke.Parent = row

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -115, 0, 18)
    titleLbl.Position = UDim2.new(0, 14, 0, config.Description and 10 or 13)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = config.Title or "Toggle"
    titleLbl.Font = Enum.Font.GothamMedium
    titleLbl.TextSize = 12
    titleLbl.TextColor3 = THEME.TextHero
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = row

    if config.Description then
        local descLbl = Instance.new("TextLabel")
        descLbl.Size = UDim2.new(1, -115, 0, 14)
        descLbl.Position = UDim2.new(0, 14, 0, 29)
        descLbl.BackgroundTransparency = 1
        descLbl.Text = config.Description
        descLbl.Font = Enum.Font.Gotham
        descLbl.TextSize = 10
        descLbl.TextColor3 = THEME.TextMuted
        descLbl.TextXAlignment = Enum.TextXAlignment.Left
        descLbl.Parent = row
    end

    -- State Capsule Badge (ON / OFF)
    local stateBadge = Instance.new("TextLabel")
    stateBadge.Size = UDim2.new(0, 28, 0, 16)
    stateBadge.Position = UDim2.new(1, -84, 0.5, -8)
    stateBadge.BackgroundTransparency = 1
    stateBadge.Text = state and "ON" or "OFF"
    stateBadge.Font = Enum.Font.GothamBold
    stateBadge.TextSize = 9
    stateBadge.TextColor3 = state and THEME.Platinum or THEME.TextDim
    stateBadge.Parent = row

    -- Sunken Recessed Groove
    local groove = Instance.new("Frame")
    groove.Size = UDim2.new(0, 44, 0, 22)
    groove.Position = UDim2.new(1, -54, 0.5, -11)
    groove.BackgroundColor3 = state and Color3.fromRGB(245, 245, 255) or THEME.RecessedTray
    groove.BorderSizePixel = 0
    groove.Parent = row

    local gCorner = Instance.new("UICorner")
    gCorner.CornerRadius = UDim.new(1, 0)
    gCorner.Parent = groove

    local gStroke = Instance.new("UIStroke")
    gStroke.Color = state and THEME.SilverLight or THEME.BorderStroke
    gStroke.Thickness = 1
    gStroke.Parent = groove

    -- Embossed Switch Knob with Center Core
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    knob.BackgroundColor3 = state and Color3.fromRGB(16, 16, 20) or Color3.fromRGB(160, 160, 175)
    knob.BorderSizePixel = 0
    knob.Parent = groove

    local kCorner = Instance.new("UICorner")
    kCorner.CornerRadius = UDim.new(1, 0)
    kCorner.Parent = knob

    local kCore = Instance.new("Frame")
    kCore.Size = UDim2.new(0, 6, 0, 6)
    kCore.AnchorPoint = Vector2.new(0.5, 0.5)
    kCore.Position = UDim2.new(0.5, 0, 0.5, 0)
    kCore.BackgroundColor3 = state and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(70, 70, 80)
    kCore.BorderSizePixel = 0
    kCore.Parent = knob

    local kcCorner = Instance.new("UICorner")
    kcCorner.CornerRadius = UDim.new(1, 0)
    kcCorner.Parent = kCore

    local function update(val)
        state = val
        stateBadge.Text = state and "ON" or "OFF"
        TweenService:Create(stateBadge, TweenInfo.new(0.2), { TextColor3 = state and THEME.Platinum or THEME.TextDim }):Play()

        local targetGroove = state and Color3.fromRGB(245, 245, 255) or THEME.RecessedTray
        local targetGStroke = state and THEME.SilverLight or THEME.BorderStroke
        local targetKnobPos = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        local targetKnobColor = state and Color3.fromRGB(16, 16, 20) or Color3.fromRGB(160, 160, 175)
        local targetCoreColor = state and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(70, 70, 80)

        TweenService:Create(groove, TweenInfo.new(0.24, Enum.EasingStyle.Quart), { BackgroundColor3 = targetGroove }):Play()
        TweenService:Create(gStroke, TweenInfo.new(0.24), { Color = targetGStroke }):Play()
        TweenService:Create(knob, TweenInfo.new(0.24, Enum.EasingStyle.Quart), { Position = targetKnobPos, BackgroundColor3 = targetKnobColor }):Play()
        TweenService:Create(kCore, TweenInfo.new(0.24), { BackgroundColor3 = targetCoreColor }):Play()

        if config.Callback then task.spawn(config.Callback, state) end
    end

    row.MouseButton1Click:Connect(function() update(not state) end)

    return {
        Set = update,
        Get = function() return state end
    }
end

-- ==================== BESPOKE WIDGET 3: ACOUSTIC GAUGE (SLIDER) ====================
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
    row.Size = UDim2.new(1, 0, 0, 56)
    row.BackgroundColor3 = THEME.CardElevated
    row.BorderSizePixel = 0
    row.Parent = container

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = row

    local stroke = Instance.new("UIStroke")
    stroke.Color = THEME.BorderStroke
    stroke.Thickness = 1
    stroke.Parent = row

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -95, 0, 18)
    titleLbl.Position = UDim2.new(0, 14, 0, 10)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = config.Title or "Precision Gauge"
    titleLbl.Font = Enum.Font.GothamMedium
    titleLbl.TextSize = 12
    titleLbl.TextColor3 = THEME.TextHero
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = row

    -- Value Capsule Pill
    local valPill = Instance.new("Frame")
    valPill.Size = UDim2.new(0, 68, 0, 20)
    valPill.Position = UDim2.new(1, -82, 0, 9)
    valPill.BackgroundColor3 = THEME.RecessedTray
    valPill.BorderSizePixel = 0
    valPill.Parent = row

    local vpCorner = Instance.new("UICorner")
    vpCorner.CornerRadius = UDim.new(0, 6)
    vpCorner.Parent = valPill

    local vpStroke = Instance.new("UIStroke")
    vpStroke.Color = THEME.BorderStroke
    vpStroke.Parent = valPill

    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(1, 0, 1, 0)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = tostring(val) .. suffix
    valLbl.Font = Enum.Font.GothamBold
    valLbl.TextSize = 10
    valLbl.TextColor3 = THEME.Platinum
    valLbl.Parent = valPill

    -- Recessed Slider Chamber
    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -28, 0, 6)
    track.Position = UDim2.new(0, 14, 0, 38)
    track.BackgroundColor3 = THEME.RecessedTray
    track.BorderSizePixel = 0
    track.Parent = row

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = track

    local trackStroke = Instance.new("UIStroke")
    trackStroke.Color = THEME.BorderStroke
    trackStroke.Parent = track

    local fill = Instance.new("Frame")
    local ratio = math.clamp((val - min) / (max - min), 0, 1)
    fill.Size = UDim2.new(ratio, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(240, 240, 250)
    fill.BorderSizePixel = 0
    fill.Parent = track

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill

    -- Floating Metallic Thumb Handle
    local thumb = Instance.new("Frame")
    thumb.Size = UDim2.new(0, 14, 0, 14)
    thumb.AnchorPoint = Vector2.new(0.5, 0.5)
    thumb.Position = UDim2.new(ratio, 0, 0.5, 0)
    thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    thumb.BorderSizePixel = 0
    thumb.Parent = track

    local thCorner = Instance.new("UICorner")
    thCorner.CornerRadius = UDim.new(0, 4)
    thCorner.Parent = thumb

    local thStroke = Instance.new("UIStroke")
    thStroke.Color = Color3.fromRGB(15, 15, 20)
    thStroke.Thickness = 1.2
    thStroke.Parent = thumb

    local dragging = false
    local function update(input)
        local posX = math.clamp(input.Position.X - track.AbsolutePosition.X, 0, track.AbsoluteSize.X)
        local pct = posX / track.AbsoluteSize.X
        local raw = min + (max - min) * pct
        local stepped = math.floor((raw / inc) + 0.5) * inc
        val = math.clamp(stepped, min, max)

        local currentRatio = (val - min) / (max - min)
        fill.Size = UDim2.new(currentRatio, 0, 1, 0)
        thumb.Position = UDim2.new(currentRatio, 0, 0.5, 0)
        valLbl.Text = tostring(val) .. suffix

        if config.Callback then task.spawn(config.Callback, val) end
    end

    row.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            TweenService:Create(vpStroke, TweenInfo.new(0.2), { Color = THEME.SilverMid }):Play()
            update(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            TweenService:Create(vpStroke, TweenInfo.new(0.2), { Color = THEME.BorderStroke }):Play()
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            update(input)
        end
    end)

    return {
        Set = function(v)
            val = math.clamp(v, min, max)
            local currentRatio = (val - min) / (max - min)
            fill.Size = UDim2.new(currentRatio, 0, 1, 0)
            thumb.Position = UDim2.new(currentRatio, 0, 0.5, 0)
            valLbl.Text = tostring(val) .. suffix
            if config.Callback then config.Callback(val) end
        end,
        Get = function() return val end
    }
end

-- ==================== BESPOKE WIDGET 4: DIAL SELECTOR (DROPDOWN) ====================
function UIModule:CreateDropdown(parent, config)
    config = config or {}
    local container = (type(parent) == "table" and parent.Page) or parent
    local options = config.Options or {}
    local selected = config.Default or options[1] or ""
    local open = false

    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 44)
    holder.BackgroundColor3 = THEME.CardElevated
    holder.BorderSizePixel = 0
    holder.ClipsDescendants = true
    holder.Parent = container

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = holder

    local stroke = Instance.new("UIStroke")
    stroke.Color = THEME.BorderStroke
    stroke.Thickness = 1
    stroke.Parent = holder

    local header = Instance.new("TextButton")
    header.Size = UDim2.new(1, 0, 0, 44)
    header.BackgroundTransparency = 1
    header.Text = ""
    header.AutoButtonColor = false
    header.Parent = holder

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(0.45, 0, 1, 0)
    titleLbl.Position = UDim2.new(0, 14, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = config.Title or "Dropdown"
    titleLbl.Font = Enum.Font.GothamMedium
    titleLbl.TextSize = 12
    titleLbl.TextColor3 = THEME.TextHero
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = header

    -- Selection Capsule Chip
    local selChip = Instance.new("Frame")
    selChip.Size = UDim2.new(0.5, -45, 0, 24)
    selChip.Position = UDim2.new(0.5, -5, 0.5, -12)
    selChip.BackgroundColor3 = THEME.RecessedTray
    selChip.BorderSizePixel = 0
    selChip.Parent = header

    local scCorner = Instance.new("UICorner")
    scCorner.CornerRadius = UDim.new(0, 6)
    scCorner.Parent = selChip

    local scStroke = Instance.new("UIStroke")
    scStroke.Color = THEME.BorderStroke
    scStroke.Parent = selChip

    local selLbl = Instance.new("TextLabel")
    selLbl.Size = UDim2.new(1, -16, 1, 0)
    selLbl.Position = UDim2.new(0, 8, 0, 0)
    selLbl.BackgroundTransparency = 1
    selLbl.Text = selected
    selLbl.Font = Enum.Font.Gotham
    selLbl.TextSize = 11
    selLbl.TextColor3 = THEME.Platinum
    selLbl.TextXAlignment = Enum.TextXAlignment.Right
    selLbl.Parent = selChip

    local arrow = Instance.new("TextLabel")
    arrow.Size = UDim2.new(0, 16, 0, 16)
    arrow.Position = UDim2.new(1, -28, 0.5, -8)
    arrow.BackgroundTransparency = 1
    arrow.Text = "▼"
    arrow.Font = Enum.Font.GothamBold
    arrow.TextSize = 9
    arrow.TextColor3 = THEME.TextMuted
    arrow.Parent = header

    local optList = Instance.new("Frame")
    optList.Size = UDim2.new(1, 0, 0, #options * 32)
    optList.Position = UDim2.new(0, 0, 0, 44)
    optList.BackgroundTransparency = 1
    optList.Parent = holder

    local optLayout = Instance.new("UIListLayout")
    optLayout.Parent = optList

    local function refresh()
        local targetH = open and (44 + #options * 32 + 6) or 44
        TweenService:Create(holder, TweenInfo.new(0.24, Enum.EasingStyle.Quart), { Size = UDim2.new(1, 0, 0, targetH) }):Play()
        TweenService:Create(arrow, TweenInfo.new(0.24), { Rotation = open and 180 or 0 }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2), { Color = open and THEME.SilverMid or THEME.BorderStroke }):Play()
    end

    for _, opt in ipairs(options) do
        local obtn = Instance.new("TextButton")
        obtn.Size = UDim2.new(1, 0, 0, 32)
        obtn.BackgroundTransparency = 1
        obtn.Text = "      " .. opt
        obtn.Font = Enum.Font.Gotham
        obtn.TextSize = 11
        obtn.TextColor3 = (opt == selected) and THEME.Platinum or THEME.TextMuted
        obtn.TextXAlignment = Enum.TextXAlignment.Left
        obtn.Parent = optList

        obtn.MouseButton1Click:Connect(function()
            selected = opt
            selLbl.Text = selected
            open = false
            refresh()
            for _, child in ipairs(optList:GetChildren()) do
                if child:IsA("TextButton") then
                    child.TextColor3 = (child.Text == "      " .. selected) and THEME.Platinum or THEME.TextMuted
                end
            end
            if config.Callback then task.spawn(config.Callback, selected) end
        end)
    end

    header.MouseButton1Click:Connect(function()
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

-- ==================== BESPOKE WIDGET 5: CONSOLE TRAY (INPUT) ====================
function UIModule:CreateInput(parent, config)
    config = config or {}
    local container = (type(parent) == "table" and parent.Page) or parent

    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 44)
    row.BackgroundColor3 = THEME.CardElevated
    row.BorderSizePixel = 0
    row.Parent = container

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = row

    local stroke = Instance.new("UIStroke")
    stroke.Color = THEME.BorderStroke
    stroke.Thickness = 1
    stroke.Parent = row

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(0.45, 0, 1, 0)
    titleLbl.Position = UDim2.new(0, 14, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = config.Title or "Input"
    titleLbl.Font = Enum.Font.GothamMedium
    titleLbl.TextSize = 12
    titleLbl.TextColor3 = THEME.TextHero
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = row

    local tray = Instance.new("Frame")
    tray.Size = UDim2.new(0.5, 0, 0, 28)
    tray.Position = UDim2.new(0.5, -10, 0.5, -14)
    tray.BackgroundColor3 = THEME.RecessedTray
    tray.BorderSizePixel = 0
    tray.Parent = row

    local trCorner = Instance.new("UICorner")
    trCorner.CornerRadius = UDim.new(0, 7)
    trCorner.Parent = tray

    local trStroke = Instance.new("UIStroke")
    trStroke.Color = THEME.BorderStroke
    trStroke.Thickness = 1
    trStroke.Parent = tray

    local tb = Instance.new("TextBox")
    tb.Size = UDim2.new(1, -26, 1, 0)
    tb.Position = UDim2.new(0, 8, 0, 0)
    tb.BackgroundTransparency = 1
    tb.Text = config.Default or ""
    tb.PlaceholderText = config.Placeholder or "Type here..."
    tb.PlaceholderColor3 = THEME.TextDim
    tb.Font = Enum.Font.Gotham
    tb.TextSize = 11
    tb.TextColor3 = THEME.TextHero
    tb.ClearTextOnFocus = false
    tb.Parent = tray

    -- Return Keycap Glyph
    local returnGlyph = Instance.new("TextLabel")
    returnGlyph.Size = UDim2.new(0, 16, 1, 0)
    returnGlyph.Position = UDim2.new(1, -20, 0, 0)
    returnGlyph.BackgroundTransparency = 1
    returnGlyph.Text = "↵"
    returnGlyph.Font = Enum.Font.GothamBold
    returnGlyph.TextSize = 12
    returnGlyph.TextColor3 = THEME.TextDim
    returnGlyph.Parent = tray

    tb.Focused:Connect(function()
        TweenService:Create(trStroke, TweenInfo.new(0.2), { Color = THEME.Platinum }):Play()
        TweenService:Create(returnGlyph, TweenInfo.new(0.2), { TextColor3 = THEME.Platinum }):Play()
    end)
    tb.FocusLost:Connect(function(enter)
        TweenService:Create(trStroke, TweenInfo.new(0.2), { Color = THEME.BorderStroke }):Play()
        TweenService:Create(returnGlyph, TweenInfo.new(0.2), { TextColor3 = THEME.TextDim }):Play()
        if config.Callback then task.spawn(config.Callback, tb.Text, enter) end
    end)

    return {
        Set = function(t) tb.Text = t end,
        Get = function() return tb.Text end
    }
end

-- ==================== BESPOKE WIDGET 6: MACHINED TILE (CHECKBOX) ====================
function UIModule:CreateCheckbox(parent, config)
    config = config or {}
    local container = (type(parent) == "table" and parent.Page) or parent
    local checked = config.Default or false

    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, 0, 0, 40)
    row.BackgroundColor3 = THEME.CardElevated
    row.BorderSizePixel = 0
    row.Text = ""
    row.AutoButtonColor = false
    row.Parent = container

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = row

    local stroke = Instance.new("UIStroke")
    stroke.Color = THEME.BorderStroke
    stroke.Thickness = 1
    stroke.Parent = row

    -- Precision Cavity
    local box = Instance.new("Frame")
    box.Size = UDim2.new(0, 20, 0, 20)
    box.Position = UDim2.new(0, 12, 0.5, -10)
    box.BackgroundColor3 = checked and Color3.fromRGB(245, 245, 255) or THEME.RecessedTray
    box.BorderSizePixel = 0
    box.Parent = row

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 6)
    bCorner.Parent = box

    local bStroke = Instance.new("UIStroke")
    bStroke.Color = checked and THEME.SilverLight or THEME.BorderStroke
    bStroke.Thickness = 1
    bStroke.Parent = box

    local checkmark = Instance.new("TextLabel")
    checkmark.Size = UDim2.new(1, 0, 1, 0)
    checkmark.BackgroundTransparency = 1
    checkmark.Text = "✓"
    checkmark.Font = Enum.Font.GothamBold
    checkmark.TextSize = 11
    checkmark.TextColor3 = Color3.fromRGB(15, 15, 20)
    checkmark.Visible = checked
    checkmark.Parent = box

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -48, 1, 0)
    titleLbl.Position = UDim2.new(0, 44, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = config.Title or "Checkbox"
    titleLbl.Font = Enum.Font.GothamMedium
    titleLbl.TextSize = 12
    titleLbl.TextColor3 = THEME.TextHero
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = row

    local function toggle(val)
        checked = val
        checkmark.Visible = checked
        TweenService:Create(box, TweenInfo.new(0.2), {
            BackgroundColor3 = checked and Color3.fromRGB(245, 245, 255) or THEME.RecessedTray
        }):Play()
        TweenService:Create(bStroke, TweenInfo.new(0.2), {
            Color = checked and THEME.SilverLight or THEME.BorderStroke
        }):Play()
        if config.Callback then task.spawn(config.Callback, checked) end
    end

    row.MouseButton1Click:Connect(function() toggle(not checked) end)

    return {
        Set = toggle,
        Get = function() return checked end
    }
end

-- ==================== BESPOKE WIDGET 7: CAPSULE PICKER ====================
function UIModule:CreateAdjustmentPicker(parent, config)
    config = config or {}
    local container = (type(parent) == "table" and parent.Page) or parent

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 44)
    btn.BackgroundColor3 = THEME.CardElevated
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = container

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Color = THEME.BorderStroke
    stroke.Thickness = 1
    stroke.Parent = btn

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -110, 1, 0)
    titleLbl.Position = UDim2.new(0, 14, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = config.Title or "Multi-Select"
    titleLbl.Font = Enum.Font.GothamMedium
    titleLbl.TextSize = 12
    titleLbl.TextColor3 = THEME.TextHero
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = btn

    -- Badge Indicator Pill
    local countPill = Instance.new("Frame")
    countPill.Size = UDim2.new(0, 80, 0, 22)
    countPill.Position = UDim2.new(1, -94, 0.5, -11)
    countPill.BackgroundColor3 = THEME.RecessedTray
    countPill.BorderSizePixel = 0
    countPill.Parent = btn

    local cpCorner = Instance.new("UICorner")
    cpCorner.CornerRadius = UDim.new(0, 6)
    cpCorner.Parent = countPill

    local cpStroke = Instance.new("UIStroke")
    cpStroke.Color = THEME.BorderStroke
    cpStroke.Parent = countPill

    local countLbl = Instance.new("TextLabel")
    countLbl.Size = UDim2.new(1, 0, 1, 0)
    countLbl.BackgroundTransparency = 1
    local currentCount = config.Selected and #config.Selected or 0
    countLbl.Text = tostring(currentCount) .. " Active ⚙"
    countLbl.Font = Enum.Font.GothamBold
    countLbl.TextSize = 10
    countLbl.TextColor3 = THEME.SilverLight
    countLbl.Parent = countPill

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(28, 28, 36) }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2), { Color = THEME.SilverMid }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = THEME.CardElevated }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2), { Color = THEME.BorderStroke }):Play()
    end)

    btn.MouseButton1Click:Connect(function()
        UIModule:OpenMultiSelectWindow({
            Title = config.Title or "Select Options",
            Options = config.Options or {},
            Selected = config.Selected or {},
            Callback = function(newList)
                countLbl.Text = tostring(#newList) .. " Active ⚙"
                if config.Callback then config.Callback(newList) end
            end
        })
    end)

    return btn
end

-- ==================== MODAL: MULTI-SELECT WINDOW ====================
function UIModule:OpenMultiSelectWindow(config)
    config = config or {}
    local screenGui = self.ScreenGui or game.CoreGui:FindFirstChildWhichIsA("ScreenGui")
    if not screenGui then return end

    local overlay = Instance.new("TextButton")
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.55
    overlay.Text = ""
    overlay.AutoButtonColor = false
    overlay.Parent = screenGui

    local modal = Instance.new("Frame")
    modal.Size = UDim2.new(0, 340, 0, 380)
    modal.Position = UDim2.new(0.5, -170, 0.5, -190)
    modal.BackgroundColor3 = THEME.Canvas
    modal.BorderSizePixel = 0
    modal.Parent = overlay

    local modalCorner = Instance.new("UICorner")
    modalCorner.CornerRadius = UDim.new(0, 16)
    modalCorner.Parent = modal

    local modalStroke = Instance.new("UIStroke")
    modalStroke.Color = THEME.SilverDark
    modalStroke.Thickness = 1.2
    modalStroke.Parent = modal

    local mTitle = Instance.new("TextLabel")
    mTitle.Size = UDim2.new(1, -28, 0, 44)
    mTitle.Position = UDim2.new(0, 16, 0, 0)
    mTitle.BackgroundTransparency = 1
    mTitle.Text = config.Title or "Select Options"
    mTitle.Font = Enum.Font.GothamBold
    mTitle.TextSize = 13
    mTitle.TextColor3 = THEME.TextHero
    mTitle.TextXAlignment = Enum.TextXAlignment.Left
    mTitle.Parent = modal

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -28, 1, -110)
    scroll.Position = UDim2.new(0, 14, 0, 46)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 2
    scroll.ScrollBarImageColor3 = THEME.SilverDark
    scroll.Parent = modal

    local sLayout = Instance.new("UIListLayout")
    sLayout.Padding = UDim.new(0, 6)
    sLayout.Parent = scroll

    local selectedMap = {}
    if config.Selected then
        for _, v in ipairs(config.Selected) do selectedMap[v] = true end
    end

    for _, opt in ipairs(config.Options or {}) do
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, -6, 0, 32)
        row.BackgroundColor3 = selectedMap[opt] and THEME.CardElevated or THEME.CardBg
        row.BorderSizePixel = 0
        row.Text = ""
        row.AutoButtonColor = false
        row.Parent = scroll

        local rCorner = Instance.new("UICorner")
        rCorner.CornerRadius = UDim.new(0, 7)
        rCorner.Parent = row

        local rStroke = Instance.new("UIStroke")
        rStroke.Color = selectedMap[opt] and THEME.SilverMid or THEME.BorderStroke
        rStroke.Thickness = 1
        rStroke.Parent = row

        local rText = Instance.new("TextLabel")
        rText.Size = UDim2.new(1, -34, 1, 0)
        rText.Position = UDim2.new(0, 12, 0, 0)
        rText.BackgroundTransparency = 1
        rText.Text = opt
        rText.Font = Enum.Font.Gotham
        rText.TextSize = 11
        rText.TextColor3 = selectedMap[opt] and THEME.TextHero or THEME.TextMuted
        rText.TextXAlignment = Enum.TextXAlignment.Left
        rText.Parent = row

        local ind = Instance.new("TextLabel")
        ind.Size = UDim2.new(0, 20, 1, 0)
        ind.Position = UDim2.new(1, -26, 0, 0)
        ind.BackgroundTransparency = 1
        ind.Text = selectedMap[opt] and "✓" or ""
        ind.Font = Enum.Font.GothamBold
        ind.TextSize = 12
        ind.TextColor3 = THEME.Platinum
        ind.Parent = row

        row.MouseButton1Click:Connect(function()
            selectedMap[opt] = not selectedMap[opt]
            ind.Text = selectedMap[opt] and "✓" or ""
            rText.TextColor3 = selectedMap[opt] and THEME.TextHero or THEME.TextMuted
            row.BackgroundColor3 = selectedMap[opt] and THEME.CardElevated or THEME.CardBg
            rStroke.Color = selectedMap[opt] and THEME.SilverMid or THEME.BorderStroke
        end)
    end

    scroll.CanvasSize = UDim2.new(0, 0, 0, sLayout.AbsoluteContentSize.Y + 10)

    local doneBtn = Instance.new("TextButton")
    doneBtn.Size = UDim2.new(1, -28, 0, 36)
    doneBtn.Position = UDim2.new(0, 14, 1, -48)
    doneBtn.BackgroundColor3 = Color3.fromRGB(245, 245, 250)
    doneBtn.BorderSizePixel = 0
    doneBtn.Text = "Confirm Selection"
    doneBtn.Font = Enum.Font.GothamBold
    doneBtn.TextSize = 12
    doneBtn.TextColor3 = Color3.fromRGB(15, 15, 20)
    doneBtn.AutoButtonColor = false
    doneBtn.Parent = modal

    local doneCorner = Instance.new("UICorner")
    doneCorner.CornerRadius = UDim.new(0, 8)
    doneCorner.Parent = doneBtn

    doneBtn.MouseButton1Click:Connect(function()
        local result = {}
        for k, v in pairs(selectedMap) do
            if v then table.insert(result, k) end
        end
        if config.Callback then task.spawn(config.Callback, result) end
        overlay:Destroy()
    end)
end

return UIModule
