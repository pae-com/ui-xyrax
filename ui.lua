-- ==============================================================================
--              XYRAX HUB - ETHEREAL AURORA EDITION (NEXT-GEN UI)
--                 (Modern Glassmorphism, Floating Dock & Gradients)
-- ==============================================================================
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local UIModule = {}
UIModule.__index = UIModule

-- ==================== COLOR PALETTE & LUXURY STYLING ====================
local THEME = {
    Canvas       = Color3.fromRGB(13, 12, 19),      -- Deep midnight obsidian
    CardBg       = Color3.fromRGB(20, 18, 29),      -- Soft glass velvet
    CardElevated = Color3.fromRGB(26, 23, 38),      -- Elevated component surface
    InputBg      = Color3.fromRGB(16, 14, 24),      -- Recessed field backdrop
    
    -- Twilight Aurora Gradients
    GradientA    = Color3.fromRGB(255, 94, 126),    -- Sunset Coral
    GradientB    = Color3.fromRGB(158, 70, 255),    -- Electric Orchid
    GradientC    = Color3.fromRGB(64, 196, 255),    -- Cyan Spark
    
    BorderLight  = Color3.fromRGB(60, 52, 80),      -- Specular edge highlight
    BorderMuted  = Color3.fromRGB(36, 32, 50),      -- Subtle perimeter stroke
    
    TextHero     = Color3.fromRGB(255, 255, 255),
    TextBody     = Color3.fromRGB(220, 215, 235),
    TextMuted    = Color3.fromRGB(140, 134, 160),
    TextDim      = Color3.fromRGB(95, 90, 115),
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
    screenGui.Name = "XyraxAurora_" .. tostring(math.random(1000, 9999))
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

    -- Ambient Floating Notifications
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

    -- Main Floating Window Shell
    local main = Instance.new("Frame")
    main.Name = "AuroraWindow"
    main.Size = config.Size or UDim2.new(0, 780, 0, 520)
    main.Position = UDim2.new(0.5, -390, 0.5, -260)
    main.BackgroundColor3 = THEME.Canvas
    main.BorderSizePixel = 0
    main.ClipsDescendants = true
    main.Active = true
    main.Parent = screenGui
    self.MainFrame = main

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 20)
    mainCorner.Parent = main

    -- Edge Catch-Light Stroke
    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = THEME.BorderLight
    mainStroke.Thickness = 1.4
    mainStroke.Parent = main

    local strokeGrad = Instance.new("UIGradient")
    strokeGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.0, THEME.GradientA),
        ColorSequenceKeypoint.new(0.5, THEME.GradientB),
        ColorSequenceKeypoint.new(1.0, THEME.GradientC)
    })
    strokeGrad.Rotation = 45
    strokeGrad.Parent = mainStroke

    -- Ambient Interior Glow Spot
    local glowSpot = Instance.new("Frame")
    glowSpot.Name = "GlowAmbient"
    glowSpot.Size = UDim2.new(0, 450, 0, 250)
    glowSpot.Position = UDim2.new(0.5, -225, 0, -120)
    glowSpot.BackgroundColor3 = THEME.GradientB
    glowSpot.BackgroundTransparency = 0.88
    glowSpot.BorderSizePixel = 0
    glowSpot.ZIndex = 1
    glowSpot.Parent = main

    local glowCorner = Instance.new("UICorner")
    glowCorner.CornerRadius = UDim.new(1, 0)
    glowCorner.Parent = glowSpot

    -- ==================== MODERN HEADER ISLAND ====================
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 56)
    header.BackgroundTransparency = 1
    header.Active = true
    header.ZIndex = 2
    header.Parent = main

    -- Monogram Brand Chip
    local brandChip = Instance.new("Frame")
    brandChip.Size = UDim2.new(0, 32, 0, 32)
    brandChip.Position = UDim2.new(0, 20, 0.5, -16)
    brandChip.BackgroundColor3 = THEME.CardElevated
    brandChip.BorderSizePixel = 0
    brandChip.Parent = header

    local chipCorner = Instance.new("UICorner")
    chipCorner.CornerRadius = UDim.new(0, 10)
    chipCorner.Parent = brandChip

    local chipStroke = Instance.new("UIStroke")
    chipStroke.Color = THEME.BorderLight
    chipStroke.Thickness = 1
    chipStroke.Parent = brandChip

    local chipGrad = Instance.new("UIGradient")
    chipGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, THEME.GradientA),
        ColorSequenceKeypoint.new(1, THEME.GradientB)
    })
    chipGrad.Rotation = 45
    chipGrad.Parent = brandChip

    local chipText = Instance.new("TextLabel")
    chipText.Size = UDim2.new(1, 0, 1, 0)
    chipText.BackgroundTransparency = 1
    chipText.Text = string.sub(config.Title or "X", 1, 1)
    chipText.Font = Enum.Font.GothamBold
    chipText.TextSize = 15
    chipText.TextColor3 = THEME.TextHero
    chipText.Parent = brandChip

    -- Brand Titles
    local brandTextHolder = Instance.new("Frame")
    brandTextHolder.Size = UDim2.new(0, 180, 1, 0)
    brandTextHolder.Position = UDim2.new(0, 60, 0, 0)
    brandTextHolder.BackgroundTransparency = 1
    brandTextHolder.Parent = header

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, 0, 0, 20)
    titleLbl.Position = UDim2.new(0, 0, 0.5, config.Subtitle and -15 or -10)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = config.Title or "Xyrax Hub"
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 14
    titleLbl.TextColor3 = THEME.TextHero
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = brandTextHolder

    if config.Subtitle then
        local subLbl = Instance.new("TextLabel")
        subLbl.Size = UDim2.new(1, 0, 0, 14)
        subLbl.Position = UDim2.new(0, 0, 0.5, 4)
        subLbl.BackgroundTransparency = 1
        subLbl.Text = string.upper(config.Subtitle)
        subLbl.Font = Enum.Font.GothamBold
        subLbl.TextSize = 9
        subLbl.TextColor3 = THEME.GradientA
        subLbl.TextXAlignment = Enum.TextXAlignment.Left
        subLbl.Parent = brandTextHolder
    end

    -- Header Controls: Status Chip, Minimize, Close
    local controls = Instance.new("Frame")
    controls.Size = UDim2.new(0, 220, 1, 0)
    controls.Position = UDim2.new(1, -230, 0, 0)
    controls.BackgroundTransparency = 1
    controls.Parent = header

    -- Live Pulse Status Chip (FPS / Studio Health)
    local statusPill = Instance.new("Frame")
    statusPill.Size = UDim2.new(0, 95, 0, 26)
    statusPill.Position = UDim2.new(0, 20, 0.5, -13)
    statusPill.BackgroundColor3 = THEME.CardBg
    statusPill.BorderSizePixel = 0
    statusPill.Parent = controls

    local spCorner = Instance.new("UICorner")
    spCorner.CornerRadius = UDim.new(1, 0)
    spCorner.Parent = statusPill

    local spStroke = Instance.new("UIStroke")
    spStroke.Color = THEME.BorderMuted
    spStroke.Parent = statusPill

    local pulseDot = Instance.new("Frame")
    pulseDot.Size = UDim2.new(0, 7, 0, 7)
    pulseDot.Position = UDim2.new(0, 10, 0.5, -3)
    pulseDot.BackgroundColor3 = Color3.fromRGB(52, 211, 153)
    pulseDot.BorderSizePixel = 0
    pulseDot.Parent = statusPill

    local pdCorner = Instance.new("UICorner")
    pdCorner.CornerRadius = UDim.new(1, 0)
    pdCorner.Parent = pulseDot

    local fpsLbl = Instance.new("TextLabel")
    fpsLbl.Size = UDim2.new(1, -25, 1, 0)
    fpsLbl.Position = UDim2.new(0, 22, 0, 0)
    fpsLbl.BackgroundTransparency = 1
    fpsLbl.Text = "60 FPS"
    fpsLbl.Font = Enum.Font.GothamBold
    fpsLbl.TextSize = 10
    fpsLbl.TextColor3 = THEME.TextMuted
    fpsLbl.TextXAlignment = Enum.TextXAlignment.Left
    fpsLbl.Parent = statusPill

    -- FPS Counter Heartbeat
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
    minBtn.Position = UDim2.new(1, -72, 0.5, -13)
    minBtn.BackgroundColor3 = THEME.CardBg
    minBtn.BorderSizePixel = 0
    minBtn.Text = "—"
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 11
    minBtn.TextColor3 = THEME.TextMuted
    minBtn.AutoButtonColor = false
    minBtn.Parent = controls

    local minCorner = Instance.new("UICorner")
    minCorner.CornerRadius = UDim.new(0, 8)
    minCorner.Parent = minBtn

    local minStroke = Instance.new("UIStroke")
    minStroke.Color = THEME.BorderMuted
    minStroke.Parent = minBtn

    -- Window Close Button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 26, 0, 26)
    closeBtn.Position = UDim2.new(1, -38, 0.5, -13)
    closeBtn.BackgroundColor3 = THEME.CardBg
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "✕"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 11
    closeBtn.TextColor3 = THEME.TextMuted
    closeBtn.AutoButtonColor = false
    closeBtn.Parent = controls

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 8)
    closeCorner.Parent = closeBtn

    local closeStroke = Instance.new("UIStroke")
    closeStroke.Color = THEME.BorderMuted
    closeStroke.Parent = closeBtn

    -- Control Button Hover Animations
    minBtn.MouseEnter:Connect(function()
        TweenService:Create(minBtn, TweenInfo.new(0.2), { BackgroundColor3 = THEME.CardElevated, TextColor3 = THEME.TextHero }):Play()
    end)
    minBtn.MouseLeave:Connect(function()
        TweenService:Create(minBtn, TweenInfo.new(0.2), { BackgroundColor3 = THEME.CardBg, TextColor3 = THEME.TextMuted }):Play()
    end)
    closeBtn.MouseEnter:Connect(function()
        TweenService:Create(closeBtn, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(80, 25, 35), TextColor3 = Color3.fromRGB(255, 100, 120) }):Play()
        TweenService:Create(closeStroke, TweenInfo.new(0.2), { Color = Color3.fromRGB(180, 40, 60) }):Play()
    end)
    closeBtn.MouseLeave:Connect(function()
        TweenService:Create(closeBtn, TweenInfo.new(0.2), { BackgroundColor3 = THEME.CardBg, TextColor3 = THEME.TextMuted }):Play()
        TweenService:Create(closeStroke, TweenInfo.new(0.2), { Color = THEME.BorderMuted }):Play()
    end)

    -- Minimize Action
    local isMin, origSize = false, main.Size
    minBtn.MouseButton1Click:Connect(function()
        isMin = not isMin
        if isMin then
            origSize = main.Size
            TweenService:Create(main, TweenInfo.new(0.35, Enum.EasingStyle.Quart), { Size = UDim2.new(origSize.X.Scale, origSize.X.Offset, 0, 56) }):Play()
        else
            TweenService:Create(main, TweenInfo.new(0.35, Enum.EasingStyle.Quart), { Size = origSize }):Play()
        end
    end)

    -- Close Action
    closeBtn.MouseButton1Click:Connect(function()
        local tw = TweenService:Create(main, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 0, 0, 0),
            Position = UDim2.new(main.Position.X.Scale, main.Position.X.Offset + (main.Size.X.Offset/2), main.Position.Y.Scale, main.Position.Y.Offset + (main.Size.Y.Offset/2))
        })
        tw:Play()
        tw.Completed:Connect(function()
            screenGui:Destroy()
        end)
    end)

    -- Dragging Logic
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

    -- Resizer Handle (◢)
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

    -- ==================== FLOATING DOCK NAVIGATION (HORIZONTAL) ====================
    local navRibbon = Instance.new("Frame")
    navRibbon.Name = "NavRibbon"
    navRibbon.Size = UDim2.new(1, -40, 0, 42)
    navRibbon.Position = UDim2.new(0, 20, 0, 62)
    navRibbon.BackgroundColor3 = THEME.CardBg
    navRibbon.BorderSizePixel = 0
    navRibbon.ZIndex = 3
    navRibbon.Parent = main

    local navCorner = Instance.new("UICorner")
    navCorner.CornerRadius = UDim.new(0, 14)
    navCorner.Parent = navRibbon

    local navStroke = Instance.new("UIStroke")
    navStroke.Color = THEME.BorderMuted
    navStroke.Thickness = 1
    navStroke.Parent = navRibbon

    -- Active Gliding Pill (Slides smoothly beneath the active tab)
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
    gpCorner.CornerRadius = UDim.new(0, 10)
    gpCorner.Parent = glidePill

    local gpStroke = Instance.new("UIStroke")
    gpStroke.Color = THEME.BorderLight
    gpStroke.Thickness = 1
    gpStroke.Parent = glidePill

    local gpGrad = Instance.new("UIGradient")
    gpGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, THEME.GradientA),
        ColorSequenceKeypoint.new(1, THEME.GradientB)
    })
    gpGrad.Rotation = 45
    gpGrad.Parent = gpStroke

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

    -- ==================== CONTENT CANVAS ====================
    local contentArea = Instance.new("Frame")
    contentArea.Name = "ContentArea"
    contentArea.Size = UDim2.new(1, -40, 1, -120)
    contentArea.Position = UDim2.new(0, 20, 0, 114)
    contentArea.BackgroundTransparency = 1
    contentArea.ClipsDescendants = true
    contentArea.ZIndex = 2
    contentArea.Parent = main
    self.ContentArea = contentArea

    self.Tabs = {}
    self.ActiveTab = nil

    return self
end

-- ==================== NOTIFICATIONS (GLASS CAPSULE) ====================
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
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = pill

    local stroke = Instance.new("UIStroke")
    stroke.Color = THEME.BorderLight
    stroke.Thickness = 1.2
    stroke.Parent = pill

    local strokeGrad = Instance.new("UIGradient")
    strokeGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, THEME.GradientA),
        ColorSequenceKeypoint.new(1, THEME.GradientB)
    })
    strokeGrad.Rotation = 45
    strokeGrad.Parent = stroke

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
    bar.BackgroundColor3 = THEME.GradientA
    bar.BorderSizePixel = 0
    bar.Parent = pill

    local bGrad = Instance.new("UIGradient")
    bGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, THEME.GradientA),
        ColorSequenceKeypoint.new(1, THEME.GradientB)
    })
    bGrad.Parent = bar

    TweenService:Create(bar, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) }):Play()
    task.delay(duration, function()
        local tw = TweenService:Create(pill, TweenInfo.new(0.3, Enum.EasingStyle.Quart), { BackgroundTransparency = 1 })
        tw:Play()
        tw.Completed:Connect(function() pill:Destroy() end)
    end)
end

-- ==================== TAB SYSTEM (TOP PILL DOCK) ====================
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

    -- 2-Column Responsive Page Frame
    local page = Instance.new("ScrollingFrame")
    page.Name = "Page_" .. name
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = THEME.BorderLight
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

        -- Animate Gliding Pill
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
            TweenService:Create(icon, TweenInfo.new(0.25), { ImageColor3 = THEME.GradientA }):Play()
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

-- ==================== GLAMOROUS SECTION CARD ====================
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
    cardStroke.Color = THEME.BorderMuted
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
        local header = Instance.new("Frame")
        header.Size = UDim2.new(1, 0, 0, 24)
        header.BackgroundTransparency = 1
        header.Parent = card

        local headerIcon = Instance.new("ImageLabel")
        headerIcon.Size = UDim2.new(0, 16, 0, 16)
        headerIcon.Position = UDim2.new(0, 0, 0.5, -8)
        headerIcon.BackgroundTransparency = 1
        headerIcon.Parent = header

        local iconData = self:GetIcon(config.Icon)
        local hOffset = 0
        if iconData then
            applyIcon(headerIcon, iconData, THEME.GradientA)
            hOffset = 24
        else
            headerIcon.Visible = false
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
        titleLbl.Parent = header
    end

    cardLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        card.Size = UDim2.new(1, 0, 0, cardLayout.AbsoluteContentSize.Y + 28)
    end)

    return card
end

-- ==================== WIDGET: MODERN BUTTON ====================
function UIModule:CreateButton(parent, config)
    config = config or {}
    local container = (type(parent) == "table" and parent.Page) or parent

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, config.Description and 50 or 40)
    btn.BackgroundColor3 = THEME.CardElevated
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = container

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Color = THEME.BorderMuted
    stroke.Thickness = 1
    stroke.Parent = btn

    local icon = Instance.new("ImageLabel")
    icon.Size = UDim2.new(0, 16, 0, 16)
    icon.Position = UDim2.new(0, 14, 0.5, -8)
    icon.BackgroundTransparency = 1
    icon.Parent = btn

    local iconData = self:GetIcon(config.Icon)
    local offset = 14
    if iconData then
        applyIcon(icon, iconData, THEME.GradientA)
        offset = 40
    else
        icon.Visible = false
    end

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -offset - 14, 0, 18)
    titleLbl.Position = UDim2.new(0, offset, 0, config.Description and 8 or 11)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = config.Title or "Button"
    titleLbl.Font = Enum.Font.GothamMedium
    titleLbl.TextSize = 12
    titleLbl.TextColor3 = THEME.TextHero
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = btn

    if config.Description then
        local descLbl = Instance.new("TextLabel")
        descLbl.Size = UDim2.new(1, -offset - 14, 0, 14)
        descLbl.Position = UDim2.new(0, offset, 0, 27)
        descLbl.BackgroundTransparency = 1
        descLbl.Text = config.Description
        descLbl.Font = Enum.Font.Gotham
        descLbl.TextSize = 10
        descLbl.TextColor3 = THEME.TextMuted
        descLbl.TextXAlignment = Enum.TextXAlignment.Left
        descLbl.Parent = btn
    end

    -- Interactive Gradient Sweep on Hover
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(34, 30, 48) }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2), { Color = THEME.BorderLight }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = THEME.CardElevated }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2), { Color = THEME.BorderMuted }):Play()
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

-- ==================== WIDGET: AURORA TOGGLE ====================
function UIModule:CreateToggle(parent, config)
    config = config or {}
    local container = (type(parent) == "table" and parent.Page) or parent
    local state = config.Default or false

    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, 0, 0, config.Description and 50 or 40)
    row.BackgroundColor3 = THEME.CardElevated
    row.BorderSizePixel = 0
    row.Text = ""
    row.AutoButtonColor = false
    row.Parent = container

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = row

    local stroke = Instance.new("UIStroke")
    stroke.Color = THEME.BorderMuted
    stroke.Thickness = 1
    stroke.Parent = row

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -75, 0, 18)
    titleLbl.Position = UDim2.new(0, 14, 0, config.Description and 8 or 11)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = config.Title or "Toggle"
    titleLbl.Font = Enum.Font.GothamMedium
    titleLbl.TextSize = 12
    titleLbl.TextColor3 = THEME.TextHero
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = row

    if config.Description then
        local descLbl = Instance.new("TextLabel")
        descLbl.Size = UDim2.new(1, -75, 0, 14)
        descLbl.Position = UDim2.new(0, 14, 0, 27)
        descLbl.BackgroundTransparency = 1
        descLbl.Text = config.Description
        descLbl.Font = Enum.Font.Gotham
        descLbl.TextSize = 10
        descLbl.TextColor3 = THEME.TextMuted
        descLbl.TextXAlignment = Enum.TextXAlignment.Left
        descLbl.Parent = row
    end

    -- Modern Switch Pill
    local pill = Instance.new("Frame")
    pill.Size = UDim2.new(0, 42, 0, 22)
    pill.Position = UDim2.new(1, -56, 0.5, -11)
    pill.BackgroundColor3 = state and THEME.GradientB or Color3.fromRGB(35, 30, 46)
    pill.BorderSizePixel = 0
    pill.Parent = row

    local pillCorner = Instance.new("UICorner")
    pillCorner.CornerRadius = UDim.new(1, 0)
    pillCorner.Parent = pill

    local pillGrad = Instance.new("UIGradient")
    pillGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, THEME.GradientA),
        ColorSequenceKeypoint.new(1, THEME.GradientB)
    })
    pillGrad.Enabled = state
    pillGrad.Parent = pill

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = pill

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob

    local function update(val)
        state = val
        pillGrad.Enabled = state
        local targetColor = state and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(35, 30, 46)
        local targetPos = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)

        TweenService:Create(pill, TweenInfo.new(0.24, Enum.EasingStyle.Quart), { BackgroundColor3 = targetColor }):Play()
        TweenService:Create(knob, TweenInfo.new(0.24, Enum.EasingStyle.Quart), { Position = targetPos }):Play()

        if config.Callback then task.spawn(config.Callback, state) end
    end

    row.MouseButton1Click:Connect(function() update(not state) end)

    return {
        Set = update,
        Get = function() return state end
    }
end

-- ==================== WIDGET: SLIDER WITH LIVE GLOW ====================
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
    row.Size = UDim2.new(1, 0, 0, 52)
    row.BackgroundColor3 = THEME.CardElevated
    row.BorderSizePixel = 0
    row.Parent = container

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = row

    local stroke = Instance.new("UIStroke")
    stroke.Color = THEME.BorderMuted
    stroke.Thickness = 1
    stroke.Parent = row

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -80, 0, 18)
    titleLbl.Position = UDim2.new(0, 14, 0, 8)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = config.Title or "Slider"
    titleLbl.Font = Enum.Font.GothamMedium
    titleLbl.TextSize = 12
    titleLbl.TextColor3 = THEME.TextHero
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = row

    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(0, 70, 0, 18)
    valLbl.Position = UDim2.new(1, -84, 0, 8)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = tostring(val) .. suffix
    valLbl.Font = Enum.Font.GothamBold
    valLbl.TextSize = 11
    valLbl.TextColor3 = THEME.GradientA
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Parent = row

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -28, 0, 5)
    track.Position = UDim2.new(0, 14, 0, 35)
    track.BackgroundColor3 = Color3.fromRGB(36, 31, 48)
    track.BorderSizePixel = 0
    track.Parent = row

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = track

    local fill = Instance.new("Frame")
    local ratio = math.clamp((val - min) / (max - min), 0, 1)
    fill.Size = UDim2.new(ratio, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    fill.BorderSizePixel = 0
    fill.Parent = track

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill

    local fillGrad = Instance.new("UIGradient")
    fillGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, THEME.GradientA),
        ColorSequenceKeypoint.new(1, THEME.GradientB)
    })
    fillGrad.Parent = fill

    local dragging = false
    local function update(input)
        local posX = math.clamp(input.Position.X - track.AbsolutePosition.X, 0, track.AbsoluteSize.X)
        local pct = posX / track.AbsoluteSize.X
        local raw = min + (max - min) * pct
        local stepped = math.floor((raw / inc) + 0.5) * inc
        val = math.clamp(stepped, min, max)

        fill.Size = UDim2.new((val - min) / (max - min), 0, 1, 0)
        valLbl.Text = tostring(val) .. suffix

        if config.Callback then task.spawn(config.Callback, val) end
    end

    row.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            update(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
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
            fill.Size = UDim2.new((val - min) / (max - min), 0, 1, 0)
            valLbl.Text = tostring(val) .. suffix
            if config.Callback then config.Callback(val) end
        end,
        Get = function() return val end
    }
end

-- ==================== WIDGET: MODERN DROPDOWN ====================
function UIModule:CreateDropdown(parent, config)
    config = config or {}
    local container = (type(parent) == "table" and parent.Page) or parent
    local options = config.Options or {}
    local selected = config.Default or options[1] or ""
    local open = false

    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 42)
    holder.BackgroundColor3 = THEME.CardElevated
    holder.BorderSizePixel = 0
    holder.ClipsDescendants = true
    holder.Parent = container

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = holder

    local stroke = Instance.new("UIStroke")
    stroke.Color = THEME.BorderMuted
    stroke.Thickness = 1
    stroke.Parent = holder

    local header = Instance.new("TextButton")
    header.Size = UDim2.new(1, 0, 0, 42)
    header.BackgroundTransparency = 1
    header.Text = ""
    header.AutoButtonColor = false
    header.Parent = holder

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(0.5, 0, 1, 0)
    titleLbl.Position = UDim2.new(0, 14, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = config.Title or "Dropdown"
    titleLbl.Font = Enum.Font.GothamMedium
    titleLbl.TextSize = 12
    titleLbl.TextColor3 = THEME.TextHero
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = header

    local selLbl = Instance.new("TextLabel")
    selLbl.Size = UDim2.new(0.5, -44, 1, 0)
    selLbl.Position = UDim2.new(0.5, 0, 0, 0)
    selLbl.BackgroundTransparency = 1
    selLbl.Text = selected
    selLbl.Font = Enum.Font.Gotham
    selLbl.TextSize = 11
    selLbl.TextColor3 = THEME.GradientA
    selLbl.TextXAlignment = Enum.TextXAlignment.Right
    selLbl.Parent = header

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
    optList.Size = UDim2.new(1, 0, 0, #options * 30)
    optList.Position = UDim2.new(0, 0, 0, 42)
    optList.BackgroundTransparency = 1
    optList.Parent = holder

    local optLayout = Instance.new("UIListLayout")
    optLayout.Parent = optList

    local function refresh()
        local targetH = open and (42 + #options * 30 + 6) or 42
        TweenService:Create(holder, TweenInfo.new(0.26, Enum.EasingStyle.Quart), { Size = UDim2.new(1, 0, 0, targetH) }):Play()
        TweenService:Create(arrow, TweenInfo.new(0.26), { Rotation = open and 180 or 0 }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2), { Color = open and THEME.BorderLight or THEME.BorderMuted }):Play()
    end

    for _, opt in ipairs(options) do
        local obtn = Instance.new("TextButton")
        obtn.Size = UDim2.new(1, 0, 0, 30)
        obtn.BackgroundTransparency = 1
        obtn.Text = "     " .. opt
        obtn.Font = Enum.Font.Gotham
        obtn.TextSize = 11
        obtn.TextColor3 = (opt == selected) and THEME.GradientA or THEME.TextMuted
        obtn.TextXAlignment = Enum.TextXAlignment.Left
        obtn.Parent = optList

        obtn.MouseButton1Click:Connect(function()
            selected = opt
            selLbl.Text = selected
            open = false
            refresh()
            for _, child in ipairs(optList:GetChildren()) do
                if child:IsA("TextButton") then
                    child.TextColor3 = (child.Text == "     " .. selected) and THEME.GradientA or THEME.TextMuted
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

-- ==================== WIDGET: MODERN TEXT INPUT ====================
function UIModule:CreateInput(parent, config)
    config = config or {}
    local container = (type(parent) == "table" and parent.Page) or parent

    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 42)
    row.BackgroundColor3 = THEME.CardElevated
    row.BorderSizePixel = 0
    row.Parent = container

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = row

    local stroke = Instance.new("UIStroke")
    stroke.Color = THEME.BorderMuted
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

    local tb = Instance.new("TextBox")
    tb.Size = UDim2.new(0.5, 0, 0, 28)
    tb.Position = UDim2.new(0.5, -10, 0.5, -14)
    tb.BackgroundColor3 = THEME.InputBg
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
    tbCorner.CornerRadius = UDim.new(0, 8)
    tbCorner.Parent = tb

    local tbStroke = Instance.new("UIStroke")
    tbStroke.Color = THEME.BorderMuted
    tbStroke.Thickness = 1
    tbStroke.Parent = tb

    tb.Focused:Connect(function()
        TweenService:Create(tbStroke, TweenInfo.new(0.2), { Color = THEME.GradientB }):Play()
    end)
    tb.FocusLost:Connect(function(enter)
        TweenService:Create(tbStroke, TweenInfo.new(0.2), { Color = THEME.BorderMuted }):Play()
        if config.Callback then task.spawn(config.Callback, tb.Text, enter) end
    end)

    return {
        Set = function(t) tb.Text = t end,
        Get = function() return tb.Text end
    }
end

-- ==================== WIDGET: CHECKBOX ====================
function UIModule:CreateCheckbox(parent, config)
    config = config or {}
    local container = (type(parent) == "table" and parent.Page) or parent
    local checked = config.Default or false

    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, 0, 0, 36)
    row.BackgroundColor3 = THEME.CardElevated
    row.BorderSizePixel = 0
    row.Text = ""
    row.AutoButtonColor = false
    row.Parent = container

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = row

    local stroke = Instance.new("UIStroke")
    stroke.Color = THEME.BorderMuted
    stroke.Thickness = 1
    stroke.Parent = row

    local box = Instance.new("Frame")
    box.Size = UDim2.new(0, 18, 0, 18)
    box.Position = UDim2.new(0, 14, 0.5, -9)
    box.BackgroundColor3 = checked and THEME.GradientA or Color3.fromRGB(36, 31, 48)
    box.BorderSizePixel = 0
    box.Parent = row

    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 6)
    boxCorner.Parent = box

    local checkmark = Instance.new("TextLabel")
    checkmark.Size = UDim2.new(1, 0, 1, 0)
    checkmark.BackgroundTransparency = 1
    checkmark.Text = "✓"
    checkmark.Font = Enum.Font.GothamBold
    checkmark.TextSize = 11
    checkmark.TextColor3 = Color3.fromRGB(255, 255, 255)
    checkmark.Visible = checked
    checkmark.Parent = box

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -44, 1, 0)
    titleLbl.Position = UDim2.new(0, 42, 0, 0)
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
            BackgroundColor3 = checked and THEME.GradientA or Color3.fromRGB(36, 31, 48)
        }):Play()
        if config.Callback then task.spawn(config.Callback, checked) end
    end

    row.MouseButton1Click:Connect(function() toggle(not checked) end)

    return {
        Set = toggle,
        Get = function() return checked end
    }
end

-- ==================== WIDGET: MULTI-SELECT PICKER ====================
function UIModule:CreateAdjustmentPicker(parent, config)
    config = config or {}
    local container = (type(parent) == "table" and parent.Page) or parent

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 40)
    btn.BackgroundColor3 = THEME.CardElevated
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = container

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Color = THEME.BorderMuted
    stroke.Thickness = 1
    stroke.Parent = btn

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -40, 1, 0)
    titleLbl.Position = UDim2.new(0, 14, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = (config.Title or "Picker") .. "  ⚙"
    titleLbl.Font = Enum.Font.GothamMedium
    titleLbl.TextSize = 12
    titleLbl.TextColor3 = THEME.TextHero
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = btn

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(34, 30, 48) }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2), { Color = THEME.BorderLight }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = THEME.CardElevated }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2), { Color = THEME.BorderMuted }):Play()
    end)

    btn.MouseButton1Click:Connect(function()
        UIModule:OpenMultiSelectWindow({
            Title = config.Title or "Select Options",
            Options = config.Options or {},
            Selected = config.Selected or {},
            Callback = config.Callback
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
    overlay.BackgroundTransparency = 0.5
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
    modalStroke.Color = THEME.BorderLight
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
    scroll.ScrollBarImageColor3 = THEME.BorderLight
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
        rCorner.CornerRadius = UDim.new(0, 8)
        rCorner.Parent = row

        local rStroke = Instance.new("UIStroke")
        rStroke.Color = selectedMap[opt] and THEME.BorderLight or THEME.BorderMuted
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
        ind.TextColor3 = THEME.GradientA
        ind.Parent = row

        row.MouseButton1Click:Connect(function()
            selectedMap[opt] = not selectedMap[opt]
            ind.Text = selectedMap[opt] and "✓" or ""
            rText.TextColor3 = selectedMap[opt] and THEME.TextHero or THEME.TextMuted
            row.BackgroundColor3 = selectedMap[opt] and THEME.CardElevated or THEME.CardBg
            rStroke.Color = selectedMap[opt] and THEME.BorderLight or THEME.BorderMuted
        end)
    end

    scroll.CanvasSize = UDim2.new(0, 0, 0, sLayout.AbsoluteContentSize.Y + 10)

    local doneBtn = Instance.new("TextButton")
    doneBtn.Size = UDim2.new(1, -28, 0, 36)
    doneBtn.Position = UDim2.new(0, 14, 1, -48)
    doneBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    doneBtn.BorderSizePixel = 0
    doneBtn.Text = "Confirm Selection"
    doneBtn.Font = Enum.Font.GothamBold
    doneBtn.TextSize = 12
    doneBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    doneBtn.AutoButtonColor = false
    doneBtn.Parent = modal

    local doneCorner = Instance.new("UICorner")
    doneCorner.CornerRadius = UDim.new(0, 10)
    doneCorner.Parent = doneBtn

    local doneGrad = Instance.new("UIGradient")
    doneGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, THEME.GradientA),
        ColorSequenceKeypoint.new(1, THEME.GradientB)
    })
    doneGrad.Parent = doneBtn

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
