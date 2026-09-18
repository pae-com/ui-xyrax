-- ==============================================================================
--              XYRAX NEXUS - SPATIAL BENTO WORKSTATION
--         (Next-Gen Holographic HUD, Command Orb & Kinetic Bento)
-- ==============================================================================
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local UIModule = {}
UIModule.__index = UIModule

-- ==================== MONOCHROME TITANIUM PALETTE ====================
local THEME = {
    Void         = Color3.fromRGB(8, 8, 10),        -- Deepest Abyss
    GlassBase    = Color3.fromRGB(14, 14, 18),      -- Smoked Titanium Glass
    ModuleBg     = Color3.fromRGB(18, 18, 23),      -- Bento Tile Surface
    Recessed     = Color3.fromRGB(11, 11, 14),      -- Recessed Mechanism Well
    
    SpecularHigh = Color3.fromRGB(255, 255, 255),    -- Diamond White Light
    Platinum     = Color3.fromRGB(225, 225, 235),    -- Crisp Titanium
    SteelMid     = Color3.fromRGB(140, 140, 155),    -- Neutral Brushed Steel
    SteelDark    = Color3.fromRGB(60, 60, 72),       -- Structural Rim
    Perimeter    = Color3.fromRGB(32, 32, 40),       -- Outer Seam
    
    TextHero     = Color3.fromRGB(255, 255, 255),
    TextBody     = Color3.fromRGB(205, 205, 218),
    TextMuted    = Color3.fromRGB(130, 130, 145),
    TextDim      = Color3.fromRGB(75, 75, 88),
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
    ["search"]             = "rbxassetid://98285514601449",
    ["chevron-down"]       = "rbxassetid://134243273101015",
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

-- ==================== WORKSTATION SHELL ====================
function UIModule.new(config)
    config = config or {}
    local self = setmetatable({}, UIModule)

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "XyraxNexus_" .. tostring(math.random(1000, 9999))
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

    -- ==================== HOLOGRAPHIC COMMAND ORB (MINIMIZED STATE) ====================
    local commandOrb = Instance.new("TextButton")
    commandOrb.Name = "NexusCommandOrb"
    commandOrb.Size = UDim2.new(0, 48, 0, 48)
    commandOrb.Position = UDim2.new(0, 30, 0.5, -24)
    commandOrb.BackgroundColor3 = THEME.GlassBase
    commandOrb.BorderSizePixel = 0
    commandOrb.Text = ""
    commandOrb.AutoButtonColor = false
    commandOrb.Visible = false
    commandOrb.Parent = screenGui
    self.CommandOrb = commandOrb

    local orbCorner = Instance.new("UICorner")
    orbCorner.CornerRadius = UDim.new(1, 0)
    orbCorner.Parent = commandOrb

    local orbStroke = Instance.new("UIStroke")
    orbStroke.Color = THEME.Platinum
    orbStroke.Thickness = 1.4
    orbStroke.Parent = commandOrb

    local orbCore = Instance.new("Frame")
    orbCore.Size = UDim2.new(0, 14, 0, 14)
    orbCore.AnchorPoint = Vector2.new(0.5, 0.5)
    orbCore.Position = UDim2.new(0.5, 0, 0.5, 0)
    orbCore.BackgroundColor3 = THEME.Platinum
    orbCore.BorderSizePixel = 0
    orbCore.Parent = commandOrb

    local orbCoreCorner = Instance.new("UICorner")
    orbCoreCorner.CornerRadius = UDim.new(1, 0)
    orbCoreCorner.Parent = orbCore

    -- ==================== MAIN WORKSTATION SLATE ====================
    local main = Instance.new("Frame")
    main.Name = "WorkstationSlate"
    main.Size = config.Size or UDim2.new(0, 840, 0, 560)
    main.Position = UDim2.new(0.5, -420, 0.5, -280)
    main.BackgroundColor3 = THEME.Void
    main.BorderSizePixel = 0
    main.ClipsDescendants = true
    main.Active = true
    main.Parent = screenGui
    self.MainFrame = main

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 20)
    mainCorner.Parent = main

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = THEME.SteelDark
    mainStroke.Thickness = 1.4
    mainStroke.Parent = main

    local strokeGrad = Instance.new("UIGradient")
    strokeGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.0, Color3.fromRGB(240, 240, 255)),
        ColorSequenceKeypoint.new(0.3, Color3.fromRGB(45, 45, 55)),
        ColorSequenceKeypoint.new(0.7, Color3.fromRGB(180, 180, 195)),
        ColorSequenceKeypoint.new(1.0, Color3.fromRGB(40, 40, 50))
    })
    strokeGrad.Rotation = 65
    strokeGrad.Parent = mainStroke

    -- Ambient Specular Highlight
    local topGlow = Instance.new("Frame")
    topGlow.Size = UDim2.new(0, 400, 0, 2)
    topGlow.Position = UDim2.new(0.5, -200, 0, 0)
    topGlow.BackgroundColor3 = THEME.Platinum
    topGlow.BorderSizePixel = 0
    topGlow.Parent = main

    local tgGrad = Instance.new("UIGradient")
    tgGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 0.2),
        NumberSequenceKeypoint.new(1, 1)
    })
    tgGrad.Parent = topGlow

    -- ==================== TELEMETRY HEADER BRIDGE ====================
    local header = Instance.new("Frame")
    header.Name = "HeaderBridge"
    header.Size = UDim2.new(1, 0, 0, 60)
    header.BackgroundTransparency = 1
    header.Active = true
    header.ZIndex = 3
    header.Parent = main

    -- Monogram Emblem Box
    local emblem = Instance.new("Frame")
    emblem.Size = UDim2.new(0, 36, 0, 36)
    emblem.Position = UDim2.new(0, 24, 0.5, -18)
    emblem.BackgroundColor3 = THEME.GlassBase
    emblem.BorderSizePixel = 0
    emblem.Parent = header

    local emCorner = Instance.new("UICorner")
    emCorner.CornerRadius = UDim.new(0, 9)
    emCorner.Parent = emblem

    local emStroke = Instance.new("UIStroke")
    emStroke.Color = THEME.SteelDark
    emStroke.Thickness = 1
    emStroke.Parent = emblem

    local emText = Instance.new("TextLabel")
    emText.Size = UDim2.new(1, 0, 1, 0)
    emText.BackgroundTransparency = 1
    emText.Text = string.sub(config.Title or "X", 1, 1)
    emText.Font = Enum.Font.GothamBold
    emText.TextSize = 16
    emText.TextColor3 = THEME.Platinum
    emText.Parent = emblem

    local titleHolder = Instance.new("Frame")
    titleHolder.Size = UDim2.new(0, 190, 1, 0)
    titleHolder.Position = UDim2.new(0, 70, 0, 0)
    titleHolder.BackgroundTransparency = 1
    titleHolder.Parent = header

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, 0, 0, 20)
    titleLbl.Position = UDim2.new(0, 0, 0.5, config.Subtitle and -15 or -10)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = config.Title or "Xyrax Nexus"
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
        subLbl.TextColor3 = THEME.SteelMid
        subLbl.TextXAlignment = Enum.TextXAlignment.Left
        subLbl.Parent = titleHolder
    end

    -- ==================== LIVE SEARCH BAR (DYNAMIC FILTER) ====================
    local searchTray = Instance.new("Frame")
    searchTray.Name = "LiveSearch"
    searchTray.Size = UDim2.new(0, 200, 0, 32)
    searchTray.Position = UDim2.new(0, 270, 0.5, -16)
    searchTray.BackgroundColor3 = THEME.GlassBase
    searchTray.BorderSizePixel = 0
    searchTray.Parent = header

    local stCorner = Instance.new("UICorner")
    stCorner.CornerRadius = UDim.new(0, 8)
    stCorner.Parent = searchTray

    local stStroke = Instance.new("UIStroke")
    stStroke.Color = THEME.Perimeter
    stStroke.Thickness = 1
    stStroke.Parent = searchTray

    local searchIcon = Instance.new("ImageLabel")
    searchIcon.Size = UDim2.new(0, 14, 0, 14)
    searchIcon.Position = UDim2.new(0, 10, 0.5, -7)
    searchIcon.BackgroundTransparency = 1
    searchIcon.Image = "rbxassetid://98285514601449"
    searchIcon.ImageColor3 = THEME.TextDim
    searchIcon.Parent = searchTray

    local searchBox = Instance.new("TextBox")
    searchBox.Size = UDim2.new(1, -34, 1, 0)
    searchBox.Position = UDim2.new(0, 30, 0, 0)
    searchBox.BackgroundTransparency = 1
    searchBox.Text = ""
    searchBox.PlaceholderText = "Search controls..."
    searchBox.PlaceholderColor3 = THEME.TextDim
    searchBox.Font = Enum.Font.Gotham
    searchBox.TextSize = 11
    searchBox.TextColor3 = THEME.TextHero
    searchBox.ClearTextOnFocus = false
    searchBox.Parent = searchTray

    searchBox.Focused:Connect(function()
        TweenService:Create(stStroke, TweenInfo.new(0.2), { Color = THEME.Platinum }):Play()
        TweenService:Create(searchIcon, TweenInfo.new(0.2), { ImageColor3 = THEME.TextHero }):Play()
    end)
    searchBox.FocusLost:Connect(function()
        TweenService:Create(stStroke, TweenInfo.new(0.2), { Color = THEME.Perimeter }):Play()
        TweenService:Create(searchIcon, TweenInfo.new(0.2), { ImageColor3 = THEME.TextDim }):Play()
    end)

    -- Live Search Filter Event
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        local query = string.lower(searchBox.Text)
        if self.ActiveTab and self.ActiveTab.Page then
            for _, section in ipairs(self.ActiveTab.Page:GetChildren()) do
                if section:IsA("Frame") and string.find(section.Name, "^Bento_") then
                    local sectionMatch = false
                    for _, widget in ipairs(section:GetChildren()) do
                        if widget:IsA("GuiObject") and widget.Name ~= "Header" and widget.Name ~= "UIPadding" and widget.Name ~= "UIListLayout" and widget.Name ~= "UICorner" and widget.Name ~= "UIStroke" then
                            local label = widget:FindFirstChild("TitleLbl") or widget:FindFirstChildWhichIsA("TextLabel")
                            local text = label and string.lower(label.Text) or ""
                            if query == "" or string.find(text, query, 1, true) then
                                widget.Visible = true
                                sectionMatch = true
                            else
                                widget.Visible = false
                            end
                        end
                    end
                    section.Visible = (query == "") or sectionMatch
                end
            end
        end
    end)

    -- ==================== TELEMETRY & CONTROLS ====================
    local controls = Instance.new("Frame")
    controls.Size = UDim2.new(0, 240, 1, 0)
    controls.Position = UDim2.new(1, -250, 0, 0)
    controls.BackgroundTransparency = 1
    controls.Parent = header

    -- Centered FPS Telemetry Chip
    local telemetryPill = Instance.new("Frame")
    telemetryPill.Name = "TelemetryPill"
    telemetryPill.AnchorPoint = Vector2.new(0, 0.5)
    telemetryPill.Position = UDim2.new(0, 20, 0.5, 0)
    telemetryPill.Size = UDim2.new(0, 0, 0, 28)
    telemetryPill.AutomaticSize = Enum.AutomaticSize.X
    telemetryPill.BackgroundColor3 = THEME.GlassBase
    telemetryPill.BorderSizePixel = 0
    telemetryPill.Parent = controls

    local tpCorner = Instance.new("UICorner")
    tpCorner.CornerRadius = UDim.new(1, 0)
    tpCorner.Parent = telemetryPill

    local tpStroke = Instance.new("UIStroke")
    tpStroke.Color = THEME.Perimeter
    tpStroke.Parent = telemetryPill

    local tpLayout = Instance.new("UIListLayout")
    tpLayout.FillDirection = Enum.FillDirection.Horizontal
    tpLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    tpLayout.Padding = UDim.new(0, 8)
    tpLayout.Parent = telemetryPill

    local tpPad = Instance.new("UIPadding")
    tpPad.PaddingLeft = UDim.new(0, 12)
    tpPad.PaddingRight = UDim.new(0, 14)
    tpPad.Parent = telemetryPill

    local pulseBeacon = Instance.new("Frame")
    pulseBeacon.Size = UDim2.new(0, 6, 0, 6)
    pulseBeacon.BackgroundColor3 = THEME.Platinum
    pulseBeacon.BorderSizePixel = 0
    pulseBeacon.Parent = telemetryPill

    local pbCorner = Instance.new("UICorner")
    pbCorner.CornerRadius = UDim.new(1, 0)
    pbCorner.Parent = pulseBeacon

    local fpsLbl = Instance.new("TextLabel")
    fpsLbl.Size = UDim2.new(0, 0, 1, 0)
    fpsLbl.AutomaticSize = Enum.AutomaticSize.X
    fpsLbl.BackgroundTransparency = 1
    fpsLbl.Text = "60 FPS"
    fpsLbl.Font = Enum.Font.GothamBold
    fpsLbl.TextSize = 10
    fpsLbl.TextColor3 = THEME.TextBody
    fpsLbl.Parent = telemetryPill

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
    minBtn.Size = UDim2.new(0, 28, 0, 28)
    minBtn.Position = UDim2.new(1, -66, 0.5, -14)
    minBtn.BackgroundColor3 = THEME.GlassBase
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
    minStroke.Color = THEME.Perimeter
    minStroke.Parent = minBtn

    -- True Lucide "X" Close Button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -30, 0.5, -14)
    closeBtn.BackgroundColor3 = THEME.GlassBase
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = ""
    closeBtn.AutoButtonColor = false
    closeBtn.Parent = controls

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 8)
    closeCorner.Parent = closeBtn

    local closeStroke = Instance.new("UIStroke")
    closeStroke.Color = THEME.Perimeter
    closeStroke.Parent = closeBtn

    local closeIcon = Instance.new("ImageLabel")
    closeIcon.Size = UDim2.new(0, 13, 0, 13)
    closeIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    closeIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
    closeIcon.BackgroundTransparency = 1
    closeIcon.Image = "rbxassetid://110786993356448"
    closeIcon.ImageColor3 = THEME.TextMuted
    closeIcon.Parent = closeBtn

    -- Micro-Interactions
    minBtn.MouseEnter:Connect(function()
        TweenService:Create(minBtn, TweenInfo.new(0.2), { BackgroundColor3 = THEME.ModuleBg, TextColor3 = THEME.TextHero }):Play()
        TweenService:Create(minStroke, TweenInfo.new(0.2), { Color = THEME.SteelMid }):Play()
    end)
    minBtn.MouseLeave:Connect(function()
        TweenService:Create(minBtn, TweenInfo.new(0.2), { BackgroundColor3 = THEME.GlassBase, TextColor3 = THEME.TextMuted }):Play()
        TweenService:Create(minStroke, TweenInfo.new(0.2), { Color = THEME.Perimeter }):Play()
    end)

    closeBtn.MouseEnter:Connect(function()
        TweenService:Create(closeBtn, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(36, 36, 44) }):Play()
        TweenService:Create(closeStroke, TweenInfo.new(0.2), { Color = THEME.Platinum }):Play()
        TweenService:Create(closeIcon, TweenInfo.new(0.2), { ImageColor3 = THEME.Platinum }):Play()
    end)
    closeBtn.MouseLeave:Connect(function()
        TweenService:Create(closeBtn, TweenInfo.new(0.2), { BackgroundColor3 = THEME.GlassBase }):Play()
        TweenService:Create(closeStroke, TweenInfo.new(0.2), { Color = THEME.Perimeter }):Play()
        TweenService:Create(closeIcon, TweenInfo.new(0.2), { ImageColor3 = THEME.TextMuted }):Play()
    end)

    -- Kinetic Minimization to Floating Command Orb
    local isMin = false
    local function setMinimized(val)
        isMin = val
        if isMin then
            local tw = TweenService:Create(main, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                Size = UDim2.new(0, 48, 0, 48),
                Position = UDim2.new(0, 30, 0.5, -24)
            })
            tw:Play()
            tw.Completed:Connect(function()
                main.Visible = false
                commandOrb.Visible = true
            end)
        else
            commandOrb.Visible = false
            main.Visible = true
            main.Size = UDim2.new(0, 48, 0, 48)
            main.Position = UDim2.new(0, 30, 0.5, -24)
            TweenService:Create(main, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Size = config.Size or UDim2.new(0, 840, 0, 560),
                Position = UDim2.new(0.5, -420, 0.5, -280)
            }):Play()
        end
    end

    minBtn.MouseButton1Click:Connect(function() setMinimized(true) end)
    commandOrb.MouseButton1Click:Connect(function() setMinimized(false) end)

    -- Window Close
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

    -- Toggle Hotkey
    local toggleKey = config.ToggleKey or Enum.KeyCode.RightControl
    UserInputService.InputBegan:Connect(function(input, gpe)
        if not gpe and input.KeyCode == toggleKey then
            main.Visible = not main.Visible
        end
    end)

    -- ==================== SPATIAL SEGMENT DOCK ====================
    local navRibbon = Instance.new("Frame")
    navRibbon.Name = "SpatialDock"
    navRibbon.Size = UDim2.new(1, -48, 0, 44)
    navRibbon.Position = UDim2.new(0, 24, 0, 68)
    navRibbon.BackgroundColor3 = THEME.GlassBase
    navRibbon.BorderSizePixel = 0
    navRibbon.ZIndex = 3
    navRibbon.Parent = main

    local navCorner = Instance.new("UICorner")
    navCorner.CornerRadius = UDim.new(0, 12)
    navCorner.Parent = navRibbon

    local navStroke = Instance.new("UIStroke")
    navStroke.Color = THEME.Perimeter
    navStroke.Thickness = 1
    navStroke.Parent = navRibbon

    local glidePill = Instance.new("Frame")
    glidePill.Name = "GlidePill"
    glidePill.Size = UDim2.new(0, 110, 0, 32)
    glidePill.Position = UDim2.new(0, 6, 0.5, -16)
    glidePill.BackgroundColor3 = THEME.ModuleBg
    glidePill.BorderSizePixel = 0
    glidePill.ZIndex = 3
    glidePill.Visible = false
    glidePill.Parent = navRibbon

    local gpCorner = Instance.new("UICorner")
    gpCorner.CornerRadius = UDim.new(0, 8)
    gpCorner.Parent = glidePill

    local gpStroke = Instance.new("UIStroke")
    gpStroke.Color = THEME.SteelMid
    gpStroke.Thickness = 1
    gpStroke.Parent = glidePill

    local navScroll = Instance.new("ScrollingFrame")
    navScroll.Name = "DockItems"
    navScroll.Size = UDim2.new(1, -12, 1, 0)
    navScroll.Position = UDim2.new(0, 6, 0, 0)
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
    navLayout.Padding = UDim.new(0, 8)
    navLayout.Parent = navScroll

    self.NavScroll = navScroll
    self.GlidePill = glidePill

    -- ==================== BENTO CANVAS ====================
    local contentArea = Instance.new("Frame")
    contentArea.Name = "BentoCanvas"
    contentArea.Size = UDim2.new(1, -48, 1, -132)
    contentArea.Position = UDim2.new(0, 24, 0, 122)
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
    pill.Size = UDim2.new(1, 0, 0, 64)
    pill.BackgroundColor3 = THEME.GlassBase
    pill.BorderSizePixel = 0
    pill.ClipsDescendants = true
    pill.Parent = self.NotifContainer

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = pill

    local stroke = Instance.new("UIStroke")
    stroke.Color = THEME.SteelDark
    stroke.Thickness = 1
    stroke.Parent = pill

    local tLbl = Instance.new("TextLabel")
    tLbl.Size = UDim2.new(1, -28, 0, 18)
    tLbl.Position = UDim2.new(0, 14, 0, 12)
    tLbl.BackgroundTransparency = 1
    tLbl.Text = config.Title or "Notification"
    tLbl.Font = Enum.Font.GothamBold
    tLbl.TextSize = 12
    tLbl.TextColor3 = THEME.TextHero
    tLbl.TextXAlignment = Enum.TextXAlignment.Left
    tLbl.Parent = pill

    local dLbl = Instance.new("TextLabel")
    dLbl.Size = UDim2.new(1, -28, 0, 18)
    dLbl.Position = UDim2.new(0, 14, 0, 30)
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
    bar.BackgroundColor3 = THEME.Platinum
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
    tabBtn.Name = "Tab_" .. name
    tabBtn.Size = UDim2.new(0, 0, 0, 32)
    tabBtn.AutomaticSize = Enum.AutomaticSize.X
    tabBtn.BackgroundTransparency = 1
    tabBtn.Text = ""
    tabBtn.AutoButtonColor = false
    tabBtn.Parent = self.NavScroll

    local tabPad = Instance.new("UIPadding")
    tabPad.PaddingLeft = UDim.new(0, 16)
    tabPad.PaddingRight = UDim.new(0, 16)
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

    -- Bento Tile Scrolling Frame
    local page = Instance.new("ScrollingFrame")
    page.Name = "Page_" .. name
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = THEME.SteelDark
    page.Visible = false
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Parent = self.ContentArea

    local pageLayout = Instance.new("UIListLayout")
    pageLayout.Padding = UDim.new(0, 14)
    pageLayout.Parent = page

    local pagePadding = Instance.new("UIPadding")
    pagePadding.PaddingTop = UDim.new(0, 6)
    pagePadding.PaddingBottom = UDim.new(0, 18)
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
                Position = UDim2.new(0, targetX + 6, 0.5, -16),
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

-- ==================== BENTO SECTION MODULE ====================
function UIModule:CreateSection(tab, config)
    config = config or {}
    local page = (type(tab) == "table" and tab.Page) or tab

    local module = Instance.new("Frame")
    module.Name = "Bento_" .. (config.Title or "Section")
    module.Size = UDim2.new(1, 0, 0, 44)
    module.BackgroundColor3 = THEME.GlassBase
    module.BorderSizePixel = 0
    module.Parent = page

    local modCorner = Instance.new("UICorner")
    modCorner.CornerRadius = UDim.new(0, 14)
    modCorner.Parent = module

    local modStroke = Instance.new("UIStroke")
    modStroke.Color = THEME.Perimeter
    modStroke.Thickness = 1
    modStroke.Parent = module

    local modLayout = Instance.new("UIListLayout")
    modLayout.Padding = UDim.new(0, 10)
    modLayout.Parent = module

    local modPad = Instance.new("UIPadding")
    modPad.PaddingTop = UDim.new(0, 14)
    modPad.PaddingBottom = UDim.new(0, 14)
    modPad.PaddingLeft = UDim.new(0, 16)
    modPad.PaddingRight = UDim.new(0, 16)
    modPad.Parent = module

    if config.Title then
        local hdr = Instance.new("Frame")
        hdr.Name = "Header"
        hdr.Size = UDim2.new(1, 0, 0, 26)
        hdr.BackgroundTransparency = 1
        hdr.Parent = module

        local icon = Instance.new("ImageLabel")
        icon.Size = UDim2.new(0, 15, 0, 15)
        icon.Position = UDim2.new(0, 0, 0.5, -7)
        icon.BackgroundTransparency = 1
        icon.Parent = hdr

        local iconData = self:GetIcon(config.Icon)
        local hOffset = 0
        if iconData then
            applyIcon(icon, iconData, THEME.Platinum)
            hOffset = 24
        else
            icon.Visible = false
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

    modLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        module.Size = UDim2.new(1, 0, 0, modLayout.AbsoluteContentSize.Y + 28)
    end)

    return module
end

-- ==================== BENTO COMPONENT 1: KINETIC KEYSTONE (BUTTON) ====================
function UIModule:CreateButton(parent, config)
    config = config or {}
    local container = (type(parent) == "table" and parent.Page) or parent

    local cell = Instance.new("TextButton")
    cell.Name = "Cell_" .. (config.Title or "Button")
    cell.Size = UDim2.new(1, 0, 0, config.Description and 54 or 44)
    cell.BackgroundColor3 = THEME.ModuleBg
    cell.BorderSizePixel = 0
    cell.Text = ""
    cell.AutoButtonColor = false
    cell.Parent = container

    local cCorner = Instance.new("UICorner")
    cCorner.CornerRadius = UDim.new(0, 10)
    cCorner.Parent = cell

    local cStroke = Instance.new("UIStroke")
    cStroke.Color = THEME.Perimeter
    cStroke.Thickness = 1
    cStroke.Parent = cell

    -- Recessed Chamber
    local chamber = Instance.new("Frame")
    chamber.Size = UDim2.new(0, 30, 0, 30)
    chamber.Position = UDim2.new(0, 10, 0.5, -15)
    chamber.BackgroundColor3 = THEME.Recessed
    chamber.BorderSizePixel = 0
    chamber.Parent = cell

    local chCorner = Instance.new("UICorner")
    chCorner.CornerRadius = UDim.new(0, 8)
    chCorner.Parent = chamber

    local chStroke = Instance.new("UIStroke")
    chStroke.Color = THEME.Perimeter
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
        offset = 50
    else
        chamber.Visible = false
    end

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Name = "TitleLbl"
    titleLbl.Size = UDim2.new(1, -offset - 35, 0, 18)
    titleLbl.Position = UDim2.new(0, offset, 0, config.Description and 10 or 13)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = config.Title or "Button"
    titleLbl.Font = Enum.Font.GothamMedium
    titleLbl.TextSize = 12
    titleLbl.TextColor3 = THEME.TextHero
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = cell

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
        descLbl.Parent = cell
    end

    local arrow = Instance.new("ImageLabel")
    arrow.Size = UDim2.new(0, 14, 0, 14)
    arrow.Position = UDim2.new(1, -26, 0.5, -7)
    arrow.BackgroundTransparency = 1
    arrow.Image = "rbxassetid://113692007244654"
    arrow.ImageColor3 = THEME.TextDim
    arrow.Parent = cell

    cell.MouseEnter:Connect(function()
        TweenService:Create(cell, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(24, 24, 30) }):Play()
        TweenService:Create(cStroke, TweenInfo.new(0.2), { Color = THEME.SteelMid }):Play()
        TweenService:Create(arrow, TweenInfo.new(0.2), { Position = UDim2.new(1, -22, 0.5, -7), ImageColor3 = THEME.Platinum }):Play()
    end)
    cell.MouseLeave:Connect(function()
        TweenService:Create(cell, TweenInfo.new(0.2), { BackgroundColor3 = THEME.ModuleBg }):Play()
        TweenService:Create(cStroke, TweenInfo.new(0.2), { Color = THEME.Perimeter }):Play()
        TweenService:Create(arrow, TweenInfo.new(0.2), { Position = UDim2.new(1, -26, 0.5, -7), ImageColor3 = THEME.TextDim }):Play()
    end)
    cell.MouseButton1Click:Connect(function()
        local orig = cell.Size
        TweenService:Create(cell, TweenInfo.new(0.08), { Size = UDim2.new(orig.X.Scale, orig.X.Offset - 2, orig.Y.Scale, orig.Y.Offset - 2) }):Play()
        task.wait(0.08)
        TweenService:Create(cell, TweenInfo.new(0.08), { Size = orig }):Play()
        if config.Callback then task.spawn(config.Callback) end
    end)

    return cell
end

-- ==================== BENTO COMPONENT 2: BIOLUMINESCENT ROCKER (TOGGLE) ====================
function UIModule:CreateToggle(parent, config)
    config = config or {}
    local container = (type(parent) == "table" and parent.Page) or parent
    local state = config.Default or false

    local cell = Instance.new("TextButton")
    cell.Name = "Toggle_" .. (config.Title or "Toggle")
    cell.Size = UDim2.new(1, 0, 0, config.Description and 54 or 44)
    cell.BackgroundColor3 = THEME.ModuleBg
    cell.BorderSizePixel = 0
    cell.Text = ""
    cell.AutoButtonColor = false
    cell.Parent = container

    local cCorner = Instance.new("UICorner")
    cCorner.CornerRadius = UDim.new(0, 10)
    cCorner.Parent = cell

    local cStroke = Instance.new("UIStroke")
    cStroke.Color = THEME.Perimeter
    cStroke.Thickness = 1
    cStroke.Parent = cell

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Name = "TitleLbl"
    titleLbl.Size = UDim2.new(1, -120, 0, 18)
    titleLbl.Position = UDim2.new(0, 14, 0, config.Description and 10 or 13)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = config.Title or "Toggle"
    titleLbl.Font = Enum.Font.GothamMedium
    titleLbl.TextSize = 12
    titleLbl.TextColor3 = THEME.TextHero
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = cell

    if config.Description then
        local descLbl = Instance.new("TextLabel")
        descLbl.Size = UDim2.new(1, -120, 0, 14)
        descLbl.Position = UDim2.new(0, 14, 0, 29)
        descLbl.BackgroundTransparency = 1
        descLbl.Text = config.Description
        descLbl.Font = Enum.Font.Gotham
        descLbl.TextSize = 10
        descLbl.TextColor3 = THEME.TextMuted
        descLbl.TextXAlignment = Enum.TextXAlignment.Left
        descLbl.Parent = cell
    end

    local statusTag = Instance.new("TextLabel")
    statusTag.Size = UDim2.new(0, 32, 0, 16)
    statusTag.Position = UDim2.new(1, -90, 0.5, -8)
    statusTag.BackgroundTransparency = 1
    statusTag.Text = state and "ACTIVE" or "IDLE"
    statusTag.Font = Enum.Font.GothamBold
    statusTag.TextSize = 8
    statusTag.TextColor3 = state and THEME.Platinum or THEME.TextDim
    statusTag.Parent = cell

    -- Recessed Rocker Track
    local rocker = Instance.new("Frame")
    rocker.Size = UDim2.new(0, 46, 0, 22)
    rocker.Position = UDim2.new(1, -54, 0.5, -11)
    rocker.BackgroundColor3 = state and Color3.fromRGB(245, 245, 255) or THEME.Recessed
    rocker.BorderSizePixel = 0
    rocker.Parent = cell

    local rkCorner = Instance.new("UICorner")
    rkCorner.CornerRadius = UDim.new(1, 0)
    rkCorner.Parent = rocker

    local rkStroke = Instance.new("UIStroke")
    rkStroke.Color = state and THEME.Platinum or THEME.Perimeter
    rkStroke.Thickness = 1
    rkStroke.Parent = rocker

    local head = Instance.new("Frame")
    head.Size = UDim2.new(0, 16, 0, 16)
    head.Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    head.BackgroundColor3 = state and Color3.fromRGB(12, 12, 16) or Color3.fromRGB(150, 150, 165)
    head.BorderSizePixel = 0
    head.Parent = rocker

    local hCorner = Instance.new("UICorner")
    hCorner.CornerRadius = UDim.new(1, 0)
    hCorner.Parent = head

    local hCore = Instance.new("Frame")
    hCore.Size = UDim2.new(0, 6, 0, 6)
    hCore.AnchorPoint = Vector2.new(0.5, 0.5)
    hCore.Position = UDim2.new(0.5, 0, 0.5, 0)
    hCore.BackgroundColor3 = state and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(60, 60, 70)
    hCore.BorderSizePixel = 0
    hCore.Parent = head

    local hcCorner = Instance.new("UICorner")
    hcCorner.CornerRadius = UDim.new(1, 0)
    hcCorner.Parent = hCore

    local function update(val)
        state = val
        statusTag.Text = state and "ACTIVE" or "IDLE"
        TweenService:Create(statusTag, TweenInfo.new(0.2), { TextColor3 = state and THEME.Platinum or THEME.TextDim }):Play()

        local targetRocker = state and Color3.fromRGB(245, 245, 255) or THEME.Recessed
        local targetRkStroke = state and THEME.Platinum or THEME.Perimeter
        local targetHeadPos = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        local targetHeadColor = state and Color3.fromRGB(12, 12, 16) or Color3.fromRGB(150, 150, 165)
        local targetCoreColor = state and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(60, 60, 70)

        TweenService:Create(rocker, TweenInfo.new(0.22, Enum.EasingStyle.Quart), { BackgroundColor3 = targetRocker }):Play()
        TweenService:Create(rkStroke, TweenInfo.new(0.22), { Color = targetRkStroke }):Play()
        TweenService:Create(head, TweenInfo.new(0.22, Enum.EasingStyle.Quart), { Position = targetHeadPos, BackgroundColor3 = targetHeadColor }):Play()
        TweenService:Create(hCore, TweenInfo.new(0.22), { BackgroundColor3 = targetCoreColor }):Play()

        if config.Callback then task.spawn(config.Callback, state) end
    end

    cell.MouseButton1Click:Connect(function() update(not state) end)

    return {
        Set = update,
        Get = function() return state end
    }
end

-- ==================== BENTO COMPONENT 3: MICROMETER GAUGE (SLIDER) ====================
function UIModule:CreateSlider(parent, config)
    config = config or {}
    local container = (type(parent) == "table" and parent.Page) or parent

    local min = config.Min or 0
    local max = config.Max or 100
    local default = config.Default or min
    local inc = config.Increment or 1
    local suffix = config.Suffix or ""
    local val = math.clamp(default, min, max)

    local cell = Instance.new("Frame")
    cell.Name = "Slider_" .. (config.Title or "Slider")
    cell.Size = UDim2.new(1, 0, 0, 58)
    cell.BackgroundColor3 = THEME.ModuleBg
    cell.BorderSizePixel = 0
    cell.Parent = container

    local cCorner = Instance.new("UICorner")
    cCorner.CornerRadius = UDim.new(0, 10)
    cCorner.Parent = cell

    local cStroke = Instance.new("UIStroke")
    cStroke.Color = THEME.Perimeter
    cStroke.Thickness = 1
    cStroke.Parent = cell

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Name = "TitleLbl"
    titleLbl.Size = UDim2.new(1, -95, 0, 18)
    titleLbl.Position = UDim2.new(0, 14, 0, 10)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = config.Title or "Micrometer Gauge"
    titleLbl.Font = Enum.Font.GothamMedium
    titleLbl.TextSize = 12
    titleLbl.TextColor3 = THEME.TextHero
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = cell

    -- Numeric Capsule
    local numCapsule = Instance.new("Frame")
    numCapsule.Size = UDim2.new(0, 72, 0, 20)
    numCapsule.Position = UDim2.new(1, -86, 0, 9)
    numCapsule.BackgroundColor3 = THEME.Recessed
    numCapsule.BorderSizePixel = 0
    numCapsule.Parent = cell

    local ncCorner = Instance.new("UICorner")
    ncCorner.CornerRadius = UDim.new(0, 6)
    ncCorner.Parent = numCapsule

    local ncStroke = Instance.new("UIStroke")
    ncStroke.Color = THEME.Perimeter
    ncStroke.Parent = numCapsule

    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(1, 0, 1, 0)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = tostring(val) .. suffix
    valLbl.Font = Enum.Font.GothamBold
    valLbl.TextSize = 10
    valLbl.TextColor3 = THEME.Platinum
    valLbl.Parent = numCapsule

    -- Recessed Gauge Channel
    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -28, 0, 8)
    track.Position = UDim2.new(0, 14, 0, 38)
    track.BackgroundColor3 = THEME.Recessed
    track.BorderSizePixel = 0
    track.Parent = cell

    local trkCorner = Instance.new("UICorner")
    trkCorner.CornerRadius = UDim.new(1, 0)
    trkCorner.Parent = track

    local trkStroke = Instance.new("UIStroke")
    trkStroke.Color = THEME.Perimeter
    trkStroke.Parent = track

    local fill = Instance.new("Frame")
    local ratio = math.clamp((val - min) / (max - min), 0, 1)
    fill.Size = UDim2.new(ratio, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(240, 240, 250)
    fill.BorderSizePixel = 0
    fill.Parent = track

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill

    -- Chamfered Diamond Handle
    local thumb = Instance.new("Frame")
    thumb.Size = UDim2.new(0, 16, 0, 16)
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

        local curRatio = (val - min) / (max - min)
        fill.Size = UDim2.new(curRatio, 0, 1, 0)
        thumb.Position = UDim2.new(curRatio, 0, 0.5, 0)
        valLbl.Text = tostring(val) .. suffix

        if config.Callback then task.spawn(config.Callback, val) end
    end

    cell.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            TweenService:Create(ncStroke, TweenInfo.new(0.2), { Color = THEME.Platinum }):Play()
            update(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            TweenService:Create(ncStroke, TweenInfo.new(0.2), { Color = THEME.Perimeter }):Play()
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
            local curRatio = (val - min) / (max - min)
            fill.Size = UDim2.new(curRatio, 0, 1, 0)
            thumb.Position = UDim2.new(curRatio, 0, 0.5, 0)
            valLbl.Text = tostring(val) .. suffix
            if config.Callback then config.Callback(val) end
        end,
        Get = function() return val end
    }
end

-- ==================== BENTO COMPONENT 4: SPATIAL DRAWER (DROPDOWN) ====================
function UIModule:CreateDropdown(parent, config)
    config = config or {}
    local container = (type(parent) == "table" and parent.Page) or parent
    local options = config.Options or {}
    local selected = config.Default or options[1] or ""
    local open = false

    local holder = Instance.new("Frame")
    holder.Name = "Dropdown_" .. (config.Title or "Dropdown")
    holder.Size = UDim2.new(1, 0, 0, 44)
    holder.BackgroundColor3 = THEME.ModuleBg
    holder.BorderSizePixel = 0
    holder.ClipsDescendants = true
    holder.Parent = container

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = holder

    local stroke = Instance.new("UIStroke")
    stroke.Color = THEME.Perimeter
    stroke.Thickness = 1
    stroke.Parent = holder

    local header = Instance.new("TextButton")
    header.Size = UDim2.new(1, 0, 0, 44)
    header.BackgroundTransparency = 1
    header.Text = ""
    header.AutoButtonColor = false
    header.Parent = holder

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Name = "TitleLbl"
    titleLbl.Size = UDim2.new(0.45, 0, 1, 0)
    titleLbl.Position = UDim2.new(0, 14, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = config.Title or "Dropdown"
    titleLbl.Font = Enum.Font.GothamMedium
    titleLbl.TextSize = 12
    titleLbl.TextColor3 = THEME.TextHero
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = header

    local selChip = Instance.new("Frame")
    selChip.Size = UDim2.new(0.5, -45, 0, 24)
    selChip.Position = UDim2.new(0.5, -5, 0.5, -12)
    selChip.BackgroundColor3 = THEME.Recessed
    selChip.BorderSizePixel = 0
    selChip.Parent = header

    local scCorner = Instance.new("UICorner")
    scCorner.CornerRadius = UDim.new(0, 6)
    scCorner.Parent = selChip

    local scStroke = Instance.new("UIStroke")
    scStroke.Color = THEME.Perimeter
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
        TweenService:Create(stroke, TweenInfo.new(0.2), { Color = open and THEME.SteelMid or THEME.Perimeter }):Play()
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

-- ==================== BENTO COMPONENT 5: CONSOLE TRAY (INPUT) ====================
function UIModule:CreateInput(parent, config)
    config = config or {}
    local container = (type(parent) == "table" and parent.Page) or parent

    local cell = Instance.new("Frame")
    cell.Name = "Input_" .. (config.Title or "Input")
    cell.Size = UDim2.new(1, 0, 0, 44)
    cell.BackgroundColor3 = THEME.ModuleBg
    cell.BorderSizePixel = 0
    cell.Parent = container

    local cCorner = Instance.new("UICorner")
    cCorner.CornerRadius = UDim.new(0, 10)
    cCorner.Parent = cell

    local cStroke = Instance.new("UIStroke")
    cStroke.Color = THEME.Perimeter
    cStroke.Thickness = 1
    cStroke.Parent = cell

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Name = "TitleLbl"
    titleLbl.Size = UDim2.new(0.45, 0, 1, 0)
    titleLbl.Position = UDim2.new(0, 14, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = config.Title or "Input"
    titleLbl.Font = Enum.Font.GothamMedium
    titleLbl.TextSize = 12
    titleLbl.TextColor3 = THEME.TextHero
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = cell

    local tray = Instance.new("Frame")
    tray.Size = UDim2.new(0.5, 0, 0, 28)
    tray.Position = UDim2.new(0.5, -10, 0.5, -14)
    tray.BackgroundColor3 = THEME.Recessed
    tray.BorderSizePixel = 0
    tray.Parent = cell

    local trCorner = Instance.new("UICorner")
    trCorner.CornerRadius = UDim.new(0, 7)
    trCorner.Parent = tray

    local trStroke = Instance.new("UIStroke")
    trStroke.Color = THEME.Perimeter
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
        TweenService:Create(trStroke, TweenInfo.new(0.2), { Color = THEME.Perimeter }):Play()
        TweenService:Create(returnGlyph, TweenInfo.new(0.2), { TextColor3 = THEME.TextDim }):Play()
        if config.Callback then task.spawn(config.Callback, tb.Text, enter) end
    end)

    return {
        Set = function(t) tb.Text = t end,
        Get = function() return tb.Text end
    }
end

-- ==================== BENTO COMPONENT 6: MACHINED TILE (CHECKBOX) ====================
function UIModule:CreateCheckbox(parent, config)
    config = config or {}
    local container = (type(parent) == "table" and parent.Page) or parent
    local checked = config.Default or false

    local cell = Instance.new("TextButton")
    cell.Name = "Check_" .. (config.Title or "Checkbox")
    cell.Size = UDim2.new(1, 0, 0, 42)
    cell.BackgroundColor3 = THEME.ModuleBg
    cell.BorderSizePixel = 0
    cell.Text = ""
    cell.AutoButtonColor = false
    cell.Parent = container

    local cCorner = Instance.new("UICorner")
    cCorner.CornerRadius = UDim.new(0, 10)
    cCorner.Parent = cell

    local cStroke = Instance.new("UIStroke")
    cStroke.Color = THEME.Perimeter
    cStroke.Thickness = 1
    cStroke.Parent = cell

    local box = Instance.new("Frame")
    box.Size = UDim2.new(0, 20, 0, 20)
    box.Position = UDim2.new(0, 12, 0.5, -10)
    box.BackgroundColor3 = checked and Color3.fromRGB(245, 245, 255) or THEME.Recessed
    box.BorderSizePixel = 0
    box.Parent = cell

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 6)
    bCorner.Parent = box

    local bStroke = Instance.new("UIStroke")
    bStroke.Color = checked and THEME.Platinum or THEME.Perimeter
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
    titleLbl.Name = "TitleLbl"
    titleLbl.Size = UDim2.new(1, -48, 1, 0)
    titleLbl.Position = UDim2.new(0, 44, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = config.Title or "Checkbox"
    titleLbl.Font = Enum.Font.GothamMedium
    titleLbl.TextSize = 12
    titleLbl.TextColor3 = THEME.TextHero
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = cell

    local function toggle(val)
        checked = val
        checkmark.Visible = checked
        TweenService:Create(box, TweenInfo.new(0.2), {
            BackgroundColor3 = checked and Color3.fromRGB(245, 245, 255) or THEME.Recessed
        }):Play()
        TweenService:Create(bStroke, TweenInfo.new(0.2), {
            Color = checked and THEME.Platinum or THEME.Perimeter
        }):Play()
        if config.Callback then task.spawn(config.Callback, checked) end
    end

    cell.MouseButton1Click:Connect(function() toggle(not checked) end)

    return {
        Set = toggle,
        Get = function() return checked end
    }
end

-- ==================== BENTO COMPONENT 7: CAPSULE MATRIX (PICKER) ====================
function UIModule:CreateAdjustmentPicker(parent, config)
    config = config or {}
    local container = (type(parent) == "table" and parent.Page) or parent

    local cell = Instance.new("TextButton")
    cell.Name = "Picker_" .. (config.Title or "Picker")
    cell.Size = UDim2.new(1, 0, 0, 44)
    cell.BackgroundColor3 = THEME.ModuleBg
    cell.BorderSizePixel = 0
    cell.Text = ""
    cell.AutoButtonColor = false
    cell.Parent = container

    local cCorner = Instance.new("UICorner")
    cCorner.CornerRadius = UDim.new(0, 10)
    cCorner.Parent = cell

    local cStroke = Instance.new("UIStroke")
    cStroke.Color = THEME.Perimeter
    cStroke.Thickness = 1
    cStroke.Parent = cell

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Name = "TitleLbl"
    titleLbl.Size = UDim2.new(1, -110, 1, 0)
    titleLbl.Position = UDim2.new(0, 14, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = config.Title or "Filter Options"
    titleLbl.Font = Enum.Font.GothamMedium
    titleLbl.TextSize = 12
    titleLbl.TextColor3 = THEME.TextHero
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = cell

    local countPill = Instance.new("Frame")
    countPill.Size = UDim2.new(0, 84, 0, 22)
    countPill.Position = UDim2.new(1, -98, 0.5, -11)
    countPill.BackgroundColor3 = THEME.Recessed
    countPill.BorderSizePixel = 0
    countPill.Parent = cell

    local cpCorner = Instance.new("UICorner")
    cpCorner.CornerRadius = UDim.new(0, 6)
    cpCorner.Parent = countPill

    local cpStroke = Instance.new("UIStroke")
    cpStroke.Color = THEME.Perimeter
    cpStroke.Parent = countPill

    local countLbl = Instance.new("TextLabel")
    countLbl.Size = UDim2.new(1, 0, 1, 0)
    countLbl.BackgroundTransparency = 1
    local curCount = config.Selected and #config.Selected or 0
    countLbl.Text = tostring(curCount) .. " Active ⚙"
    countLbl.Font = Enum.Font.GothamBold
    countLbl.TextSize = 10
    countLbl.TextColor3 = THEME.Platinum
    countLbl.Parent = countPill

    cell.MouseEnter:Connect(function()
        TweenService:Create(cell, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(24, 24, 30) }):Play()
        TweenService:Create(cStroke, TweenInfo.new(0.2), { Color = THEME.SteelMid }):Play()
    end)
    cell.MouseLeave:Connect(function()
        TweenService:Create(cell, TweenInfo.new(0.2), { BackgroundColor3 = THEME.ModuleBg }):Play()
        TweenService:Create(cStroke, TweenInfo.new(0.2), { Color = THEME.Perimeter }):Play()
    end)

    cell.MouseButton1Click:Connect(function()
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

    return cell
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
    modal.BackgroundColor3 = THEME.Void
    modal.BorderSizePixel = 0
    modal.Parent = overlay

    local modalCorner = Instance.new("UICorner")
    modalCorner.CornerRadius = UDim.new(0, 16)
    modalCorner.Parent = modal

    local modalStroke = Instance.new("UIStroke")
    modalStroke.Color = THEME.SteelDark
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
    scroll.ScrollBarImageColor3 = THEME.SteelDark
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
        row.BackgroundColor3 = selectedMap[opt] and THEME.ModuleBg or THEME.GlassBase
        row.BorderSizePixel = 0
        row.Text = ""
        row.AutoButtonColor = false
        row.Parent = scroll

        local rCorner = Instance.new("UICorner")
        rCorner.CornerRadius = UDim.new(0, 7)
        rCorner.Parent = row

        local rStroke = Instance.new("UIStroke")
        rStroke.Color = selectedMap[opt] and THEME.Platinum or THEME.Perimeter
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
            row.BackgroundColor3 = selectedMap[opt] and THEME.ModuleBg or THEME.GlassBase
            rStroke.Color = selectedMap[opt] and THEME.Platinum or THEME.Perimeter
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
