-- ==============================================================================
--                   XYRAX HUB UI LIBRARY - LUXE NOIR EDITION
--                 (Fixed Icon Resolution & Native Fallbacks)
-- ==============================================================================
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local UIModule = {}
UIModule.__index = UIModule

-- ==================== PALETTE CONSTANTS ====================
local THEME = {
    Background   = Color3.fromRGB(11, 11, 14),
    Header       = Color3.fromRGB(16, 16, 20),
    Sidebar      = Color3.fromRGB(14, 14, 18),
    Card         = Color3.fromRGB(20, 20, 25),
    CardHover    = Color3.fromRGB(26, 26, 33),
    Element      = Color3.fromRGB(24, 24, 30),
    ElementHover = Color3.fromRGB(32, 32, 40),
    
    Border       = Color3.fromRGB(40, 40, 50),
    BorderActive = Color3.fromRGB(220, 220, 230),
    
    TextPrimary   = Color3.fromRGB(255, 255, 255),
    TextSecondary = Color3.fromRGB(150, 150, 165),
    TextMuted     = Color3.fromRGB(90, 90, 105),
    
    Accent        = Color3.fromRGB(255, 255, 255),
    AccentMuted   = Color3.fromRGB(180, 180, 190),
}

-- ==================== VERIFIED NATIVE FALLBACK ICONS ====================
-- Pre-resolved active Roblox asset IDs (Works 100% offline & in Studio)
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
    ["user"]               = "rbxassetid://93472926933440",
    ["code"]               = "rbxassetid://107380207681249",
}

-- Common name normalizations
local IconAliases = {
    ["sliders"]   = "sliders-horizontal",
    ["sword"]     = "swords",
    ["gear"]      = "settings",
    ["setting"]   = "settings",
    ["sparkle"]   = "sparkles",
    ["bell-ring"] = "bell",
}

-- ==================== DYNAMIC WINDUI ICON ENGINE ====================
local WindUIIcons = nil
pcall(function()
    if game.HttpGet then
        WindUIIcons = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/Icons/refs/heads/main/lucide/dist/Icons.lua"))()
    end
end)

function UIModule:GetIcon(iconName)
    if not iconName or iconName == "" then return nil end
    iconName = tostring(iconName)

    -- Direct asset ID or custom URI
    if string.find(iconName, "^rbxassetid://") or string.find(iconName, "^rbxasset://") or string.find(iconName, "^http") then
        return { Asset = iconName }
    end
    if tonumber(iconName) then
        return { Asset = "rbxassetid://" .. iconName }
    end

    local clean = string.lower(iconName)
    local resolvedName = IconAliases[clean] or clean

    -- 1. Check fetched dynamic icons
    if WindUIIcons and type(WindUIIcons) == "table" then
        local raw = WindUIIcons[resolvedName] or WindUIIcons[clean]
        if raw then
            local assetId = nil
            local rectOffset = Vector2.new(0, 0)
            local rectSize = Vector2.new(0, 0)

            if type(raw) == "string" then
                assetId = raw
                if not string.find(assetId, "://") then
                    assetId = "rbxassetid://" .. assetId
                end
            elseif type(raw) == "number" then
                assetId = "rbxassetid://" .. tostring(raw)
            elseif type(raw) == "table" then
                assetId = raw.Asset or raw.Image or raw.id or raw[1]
                if type(assetId) == "number" then
                    assetId = "rbxassetid://" .. tostring(assetId)
                end
                rectOffset = raw.ImageRectOffset or raw[2] or Vector2.new(0, 0)
                rectSize = raw.ImageRectSize or raw[3] or Vector2.new(0, 0)
            end

            if assetId and assetId ~= "" then
                return {
                    Asset = assetId,
                    ImageRectOffset = rectOffset,
                    ImageRectSize = rectSize
                }
            end
        end
    end

    -- 2. Check embedded verified fallbacks
    local fallback = FallbackIcons[resolvedName] or FallbackIcons[clean]
    if fallback then
        if type(fallback) == "string" then
            return { Asset = fallback }
        elseif type(fallback) == "table" then
            return fallback
        end
    end

    return nil
end

local function applyIconToLabel(imageLabel, iconData, defaultColor)
    if not iconData or not iconData.Asset or iconData.Asset == "" then
        imageLabel.Visible = false
        return
    end
    imageLabel.Image = iconData.Asset
    if iconData.ImageRectOffset and iconData.ImageRectSize and iconData.ImageRectSize ~= Vector2.new(0,0) then
        imageLabel.ImageRectOffset = iconData.ImageRectOffset
        imageLabel.ImageRectSize = iconData.ImageRectSize
    else
        imageLabel.ImageRectOffset = Vector2.new(0, 0)
        imageLabel.ImageRectSize = Vector2.new(0, 0)
    end
    imageLabel.ImageColor3 = defaultColor or THEME.TextPrimary
    imageLabel.Visible = true
end

-- ==================== MAIN WINDOW CREATION ====================
function UIModule.new(config)
    config = config or {}
    local self = setmetatable({}, UIModule)

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "XyraxNoir_" .. tostring(math.random(1000, 9999))
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
    notifContainer.Name = "NotificationContainer"
    notifContainer.Size = UDim2.new(0, 320, 1, -40)
    notifContainer.Position = UDim2.new(1, -340, 0, 20)
    notifContainer.BackgroundTransparency = 1
    notifContainer.Parent = screenGui

    local notifLayout = Instance.new("UIListLayout")
    notifLayout.FillDirection = Enum.FillDirection.Vertical
    notifLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    notifLayout.Padding = UDim.new(0, 12)
    notifLayout.Parent = notifContainer
    self.NotifContainer = notifContainer

    -- Main Frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainWindow"
    mainFrame.Size = config.Size or UDim2.new(0, 800, 0, 500)
    mainFrame.Position = UDim2.new(0.5, -400, 0.5, -250)
    mainFrame.BackgroundColor3 = THEME.Background
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Active = true
    mainFrame.Parent = screenGui

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 14)
    mainCorner.Parent = mainFrame

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(60, 60, 75)
    mainStroke.Thickness = 1.4
    mainStroke.Parent = mainFrame

    local strokeGradient = Instance.new("UIGradient")
    strokeGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.0, Color3.fromRGB(180, 180, 195)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(45, 45, 55)),
        ColorSequenceKeypoint.new(1.0, Color3.fromRGB(140, 140, 155))
    })
    strokeGradient.Rotation = 45
    strokeGradient.Parent = mainStroke

    self.MainFrame = mainFrame

    -- Title Bar
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 52)
    titleBar.BackgroundColor3 = THEME.Header
    titleBar.BorderSizePixel = 0
    titleBar.Active = true
    titleBar.Parent = mainFrame

    local titleBarBottom = Instance.new("Frame")
    titleBarBottom.Size = UDim2.new(1, 0, 0, 1)
    titleBarBottom.Position = UDim2.new(0, 0, 1, -1)
    titleBarBottom.BackgroundColor3 = THEME.Border
    titleBarBottom.BorderSizePixel = 0
    titleBarBottom.Parent = titleBar

    -- Emblem Monogram
    local emblem = Instance.new("Frame")
    emblem.Name = "Emblem"
    emblem.Size = UDim2.new(0, 26, 0, 26)
    emblem.Position = UDim2.new(0, 16, 0.5, -13)
    emblem.BackgroundColor3 = Color3.fromRGB(245, 245, 250)
    emblem.BorderSizePixel = 0
    emblem.Parent = titleBar

    local emblemCorner = Instance.new("UICorner")
    emblemCorner.CornerRadius = UDim.new(0, 7)
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
    emblemText.TextSize = 13
    emblemText.TextColor3 = Color3.fromRGB(10, 10, 12)
    emblemText.Parent = emblem

    local titleHolder = Instance.new("Frame")
    titleHolder.Size = UDim2.new(0, 240, 1, 0)
    titleHolder.Position = UDim2.new(0, 52, 0, 0)
    titleHolder.BackgroundTransparency = 1
    titleHolder.Parent = titleBar

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(1, 0, 0, 22)
    titleLabel.Position = UDim2.new(0, 0, 0.5, (config.Subtitle and -16 or -11))
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = config.Title or "Xyrax Hub"
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 14
    titleLabel.TextColor3 = THEME.TextPrimary
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = titleHolder

    if config.Subtitle then
        local subLabel = Instance.new("TextLabel")
        subLabel.Name = "Subtitle"
        subLabel.Size = UDim2.new(1, 0, 0, 14)
        subLabel.Position = UDim2.new(0, 0, 0.5, 4)
        subLabel.BackgroundTransparency = 1
        subLabel.Text = string.upper(config.Subtitle)
        subLabel.Font = Enum.Font.GothamBold
        subLabel.TextSize = 9
        subLabel.TextColor3 = THEME.TextMuted
        subLabel.TextXAlignment = Enum.TextXAlignment.Left
        subLabel.Parent = titleHolder
    end

    -- Window Controls: Minimize & Close
    local controlsHolder = Instance.new("Frame")
    controlsHolder.Size = UDim2.new(0, 60, 1, 0)
    controlsHolder.Position = UDim2.new(1, -70, 0, 0)
    controlsHolder.BackgroundTransparency = 1
    controlsHolder.Parent = titleBar

    local minBtn = Instance.new("TextButton")
    minBtn.Name = "MinButton"
    minBtn.Size = UDim2.new(0, 22, 0, 22)
    minBtn.Position = UDim2.new(0, 6, 0.5, -11)
    minBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
    minBtn.BorderSizePixel = 0
    minBtn.Text = "—"
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 10
    minBtn.TextColor3 = THEME.TextSecondary
    minBtn.AutoButtonColor = false
    minBtn.Parent = controlsHolder

    local minCorner = Instance.new("UICorner")
    minCorner.CornerRadius = UDim.new(0, 6)
    minCorner.Parent = minBtn

    local minStroke = Instance.new("UIStroke")
    minStroke.Color = THEME.Border
    minStroke.Thickness = 1
    minStroke.Parent = minBtn

    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.new(0, 22, 0, 22)
    closeBtn.Position = UDim2.new(0, 34, 0.5, -11)
    closeBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "✕"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 10
    closeBtn.TextColor3 = THEME.TextSecondary
    closeBtn.AutoButtonColor = false
    closeBtn.Parent = controlsHolder

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeBtn

    local closeStroke = Instance.new("UIStroke")
    closeStroke.Color = THEME.Border
    closeStroke.Thickness = 1
    closeStroke.Parent = closeBtn

    local function setupHover(btn, stroke, activeColor, activeStrokeColor)
        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = activeColor }):Play()
            TweenService:Create(stroke, TweenInfo.new(0.2), { Color = activeStrokeColor }):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(24, 24, 30) }):Play()
            TweenService:Create(stroke, TweenInfo.new(0.2), { Color = THEME.Border }):Play()
        end)
    end
    setupHover(minBtn, minStroke, Color3.fromRGB(36, 36, 44), Color3.fromRGB(180, 180, 200))
    setupHover(closeBtn, closeStroke, Color3.fromRGB(50, 20, 24), Color3.fromRGB(255, 90, 100))

    local isMinimized = false
    local originalSize = mainFrame.Size
    minBtn.MouseButton1Click:Connect(function()
        isMinimized = not isMinimized
        if isMinimized then
            originalSize = mainFrame.Size
            TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quart), {
                Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset, 0, 52)
            }):Play()
        else
            TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quart), {
                Size = originalSize
            }):Play()
        end
    end)

    closeBtn.MouseButton1Click:Connect(function()
        local tw = TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 0, 0, 0),
            Position = UDim2.new(mainFrame.Position.X.Scale, mainFrame.Position.X.Offset + (mainFrame.Size.X.Offset/2), mainFrame.Position.Y.Scale, mainFrame.Position.Y.Offset + (mainFrame.Size.Y.Offset/2))
        })
        tw:Play()
        tw.Completed:Connect(function()
            screenGui:Destroy()
        end)
    end)

    -- Draggable Handling
    local dragging, dragStart, startPos
    local dragChangedConn
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
            
            if dragChangedConn then dragChangedConn:Disconnect() end
            dragChangedConn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if dragChangedConn then
                        dragChangedConn:Disconnect()
                        dragChangedConn = nil
                    end
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    -- Resizer Handle (◢)
    local resizeHandle = Instance.new("TextButton")
    resizeHandle.Name = "ResizeHandle"
    resizeHandle.Size = UDim2.new(0, 18, 0, 18)
    resizeHandle.Position = UDim2.new(1, -18, 1, -18)
    resizeHandle.BackgroundTransparency = 1
    resizeHandle.Text = "◢"
    resizeHandle.Font = Enum.Font.GothamBold
    resizeHandle.TextSize = 11
    resizeHandle.TextColor3 = THEME.TextMuted
    resizeHandle.Active = true
    resizeHandle.Parent = mainFrame

    local resizing, resizeStart, startSize
    local resizeChangedConn
    resizeHandle.InputBegan:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and not isMinimized then
            resizing = true
            resizeStart = input.Position
            startSize = mainFrame.Size

            if resizeChangedConn then resizeChangedConn:Disconnect() end
            resizeChangedConn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    resizing = false
                    if resizeChangedConn then
                        resizeChangedConn:Disconnect()
                        resizeChangedConn = nil
                    end
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - resizeStart
            local newWidth = math.max(520, startSize.X.Offset + delta.X)
            local newHeight = math.max(360, startSize.Y.Offset + delta.Y)
            mainFrame.Size = UDim2.new(0, newWidth, 0, newHeight)
        end
    end)

    -- Toggle Key (RightControl)
    local toggleKey = config.ToggleKey or Enum.KeyCode.RightControl
    UserInputService.InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode == toggleKey then
            mainFrame.Visible = not mainFrame.Visible
        end
    end)

    -- Sidebar
    local sidebar = Instance.new("ScrollingFrame")
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.new(0, 195, 1, -52)
    sidebar.Position = UDim2.new(0, 0, 0, 52)
    sidebar.BackgroundColor3 = THEME.Sidebar
    sidebar.BorderSizePixel = 0
    sidebar.ScrollBarThickness = 2
    sidebar.ScrollBarImageColor3 = Color3.fromRGB(45, 45, 55)
    sidebar.CanvasSize = UDim2.new(0, 0, 0, 0)
    sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sidebar.Parent = mainFrame

    local sideLayout = Instance.new("UIListLayout")
    sideLayout.Padding = UDim.new(0, 4)
    sideLayout.Parent = sidebar

    local sidePadding = Instance.new("UIPadding")
    sidePadding.PaddingTop = UDim.new(0, 12)
    sidePadding.PaddingLeft = UDim.new(0, 10)
    sidePadding.PaddingRight = UDim.new(0, 10)
    sidePadding.Parent = sidebar

    self.Sidebar = sidebar

    -- Content Area
    local contentArea = Instance.new("Frame")
    contentArea.Name = "ContentArea"
    contentArea.Size = UDim2.new(1, -195, 1, -52)
    contentArea.Position = UDim2.new(0, 195, 0, 52)
    contentArea.BackgroundColor3 = THEME.Background
    contentArea.BorderSizePixel = 0
    contentArea.ClipsDescendants = true
    contentArea.Parent = mainFrame
    self.ContentArea = contentArea

    self.Tabs = {}
    self.ActiveTab = nil

    return self
end

-- ==================== NOTIFICATIONS ====================
function UIModule:Notify(config)
    config = config or {}
    local duration = config.Duration or 3.5

    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 64)
    card.BackgroundColor3 = THEME.Card
    card.BorderSizePixel = 0
    card.ClipsDescendants = true
    card.Parent = self.NotifContainer

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 8)
    cardCorner.Parent = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = Color3.fromRGB(60, 60, 75)
    cardStroke.Thickness = 1
    cardStroke.Parent = card

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -24, 0, 20)
    titleLbl.Position = UDim2.new(0, 14, 0, 10)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = config.Title or "Notification"
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 13
    titleLbl.TextColor3 = THEME.TextPrimary
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = card

    local descLbl = Instance.new("TextLabel")
    descLbl.Size = UDim2.new(1, -24, 0, 20)
    descLbl.Position = UDim2.new(0, 14, 0, 30)
    descLbl.BackgroundTransparency = 1
    descLbl.Text = config.Content or ""
    descLbl.Font = Enum.Font.Gotham
    descLbl.TextSize = 11
    descLbl.TextColor3 = THEME.TextSecondary
    descLbl.TextXAlignment = Enum.TextXAlignment.Left
    descLbl.Parent = card

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, 0, 0, 2)
    bar.Position = UDim2.new(0, 0, 1, -2)
    bar.BackgroundColor3 = Color3.fromRGB(240, 240, 250)
    bar.BorderSizePixel = 0
    bar.Parent = card

    local barGrad = Instance.new("UIGradient")
    barGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 120, 130))
    })
    barGrad.Parent = bar

    TweenService:Create(bar, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
        Size = UDim2.new(0, 0, 0, 2)
    }):Play()

    task.delay(duration, function()
        local fade = TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Quart), {
            BackgroundTransparency = 1
        })
        fade:Play()
        fade.Completed:Connect(function()
            card:Destroy()
        end)
    end)
end

-- ==================== TAB SYSTEM ====================
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
    tabCorner.CornerRadius = UDim.new(0, 7)
    tabCorner.Parent = tabBtn

    local tabStroke = Instance.new("UIStroke")
    tabStroke.Color = Color3.fromRGB(25, 25, 32)
    tabStroke.Thickness = 1
    tabStroke.Parent = tabBtn

    local indicator = Instance.new("Frame")
    indicator.Name = "Indicator"
    indicator.Size = UDim2.new(0, 3, 0.55, 0)
    indicator.Position = UDim2.new(0, 0, 0.225, 0)
    indicator.BackgroundColor3 = THEME.Accent
    indicator.BorderSizePixel = 0
    indicator.Visible = false
    indicator.Parent = tabBtn

    local iconLabel = Instance.new("ImageLabel")
    iconLabel.Name = "Icon"
    iconLabel.Size = UDim2.new(0, 16, 0, 16)
    iconLabel.Position = UDim2.new(0, 12, 0.5, -8)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Parent = tabBtn

    local iconData = self:GetIcon(iconName)
    if iconData then
        applyIconToLabel(iconLabel, iconData, THEME.TextMuted)
    else
        iconLabel.Visible = false
    end

    local textOffset = (iconData and 36) or 14
    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Size = UDim2.new(1, -textOffset - 6, 1, 0)
    label.Position = UDim2.new(0, textOffset, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 12
    label.TextColor3 = THEME.TextSecondary
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = tabBtn

    local page = Instance.new("ScrollingFrame")
    page.Name = "Page_" .. name
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = Color3.fromRGB(45, 45, 60)
    page.Visible = false
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Parent = self.ContentArea

    local pageLayout = Instance.new("UIListLayout")
    pageLayout.Padding = UDim.new(0, 12)
    pageLayout.Parent = page

    local pagePadding = Instance.new("UIPadding")
    pagePadding.PaddingTop = UDim.new(0, 16)
    pagePadding.PaddingLeft = UDim.new(0, 18)
    pagePadding.PaddingRight = UDim.new(0, 18)
    pagePadding.PaddingBottom = UDim.new(0, 16)
    pagePadding.Parent = page

    local tabData = {
        Button = tabBtn,
        Stroke = tabStroke,
        Page = page,
        Label = label,
        Indicator = indicator,
        IconLabel = iconLabel
    }

    local function selectTab()
        for _, t in pairs(self.Tabs) do
            t.Page.Visible = false
            t.Indicator.Visible = false
            TweenService:Create(t.Button, TweenInfo.new(0.2), { BackgroundColor3 = THEME.Sidebar }):Play()
            TweenService:Create(t.Stroke, TweenInfo.new(0.2), { Color = Color3.fromRGB(25, 25, 32) }):Play()
            TweenService:Create(t.Label, TweenInfo.new(0.2), { TextColor3 = THEME.TextSecondary }):Play()
            if t.IconLabel.Visible then
                TweenService:Create(t.IconLabel, TweenInfo.new(0.2), { ImageColor3 = THEME.TextMuted }):Play()
            end
        end

        tabData.Page.Visible = true
        tabData.Indicator.Visible = true
        TweenService:Create(tabBtn, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(24, 24, 30) }):Play()
        TweenService:Create(tabStroke, TweenInfo.new(0.2), { Color = Color3.fromRGB(55, 55, 68) }):Play()
        TweenService:Create(label, TweenInfo.new(0.2), { TextColor3 = THEME.TextPrimary }):Play()
        if iconData then
            TweenService:Create(iconLabel, TweenInfo.new(0.2), { ImageColor3 = THEME.TextPrimary }):Play()
        end
        self.ActiveTab = tabData
    end

    tabBtn.MouseButton1Click:Connect(selectTab)
    table.insert(self.Tabs, tabData)

    if #self.Tabs == 1 then
        selectTab()
    end

    return tabData
end

-- ==================== SECTION CARD ====================
function UIModule:CreateSection(tab, config)
    config = config or {}
    local page = (type(tab) == "table" and tab.Page) or tab

    local card = Instance.new("Frame")
    card.Name = "Section_" .. (config.Title or "Card")
    card.Size = UDim2.new(1, 0, 0, 40)
    card.BackgroundColor3 = THEME.Card
    card.BorderSizePixel = 0
    card.Parent = page

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 9)
    cardCorner.Parent = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = THEME.Border
    cardStroke.Thickness = 1
    cardStroke.Parent = card

    local cardLayout = Instance.new("UIListLayout")
    cardLayout.Padding = UDim.new(0, 8)
    cardLayout.Parent = card

    local cardPadding = Instance.new("UIPadding")
    cardPadding.PaddingTop = UDim.new(0, 12)
    cardPadding.PaddingBottom = UDim.new(0, 12)
    cardPadding.PaddingLeft = UDim.new(0, 12)
    cardPadding.PaddingRight = UDim.new(0, 12)
    cardPadding.Parent = card

    if config.Title then
        local header = Instance.new("Frame")
        header.Size = UDim2.new(1, 0, 0, 22)
        header.BackgroundTransparency = 1
        header.Parent = card

        local headerIcon = Instance.new("ImageLabel")
        headerIcon.Size = UDim2.new(0, 14, 0, 14)
        headerIcon.Position = UDim2.new(0, 0, 0.5, -7)
        headerIcon.BackgroundTransparency = 1
        headerIcon.Parent = header

        local iconData = self:GetIcon(config.Icon)
        local hOffset = 0
        if iconData then
            applyIconToLabel(headerIcon, iconData, THEME.TextPrimary)
            hOffset = 20
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
        titleLbl.TextColor3 = Color3.fromRGB(200, 200, 210)
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left
        titleLbl.Parent = header
    end

    cardLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        card.Size = UDim2.new(1, 0, 0, cardLayout.AbsoluteContentSize.Y + 24)
    end)

    return card
end

-- ==================== WIDGET: BUTTON ====================
function UIModule:CreateButton(parent, config)
    config = config or {}
    local container = (type(parent) == "table" and parent.Page) or parent

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, (config.Description and 48) or 38)
    btn.BackgroundColor3 = THEME.Element
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = container

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(36, 36, 46)
    stroke.Thickness = 1
    stroke.Parent = btn

    local iconLabel = Instance.new("ImageLabel")
    iconLabel.Size = UDim2.new(0, 16, 0, 16)
    iconLabel.Position = UDim2.new(0, 12, 0.5, -8)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Parent = btn

    local iconData = self:GetIcon(config.Icon)
    local leftOffset = 12
    if iconData then
        applyIconToLabel(iconLabel, iconData, THEME.TextPrimary)
        leftOffset = 36
    else
        iconLabel.Visible = false
    end

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -leftOffset - 12, 0, 18)
    titleLbl.Position = UDim2.new(0, leftOffset, 0, (config.Description and 6) or 10)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = config.Title or "Button"
    titleLbl.Font = Enum.Font.GothamMedium
    titleLbl.TextSize = 12
    titleLbl.TextColor3 = THEME.TextPrimary
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = btn

    if config.Description then
        local descLbl = Instance.new("TextLabel")
        descLbl.Size = UDim2.new(1, -leftOffset - 12, 0, 14)
        descLbl.Position = UDim2.new(0, leftOffset, 0, 26)
        descLbl.BackgroundTransparency = 1
        descLbl.Text = config.Description
        descLbl.Font = Enum.Font.Gotham
        descLbl.TextSize = 10
        descLbl.TextColor3 = THEME.TextMuted
        descLbl.TextXAlignment = Enum.TextXAlignment.Left
        descLbl.Parent = btn
    end

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = THEME.ElementHover }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2), { Color = Color3.fromRGB(70, 70, 85) }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = THEME.Element }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2), { Color = Color3.fromRGB(36, 36, 46) }):Play()
    end)
    btn.MouseButton1Click:Connect(function()
        local orig = btn.Size
        TweenService:Create(btn, TweenInfo.new(0.08), { Size = UDim2.new(orig.X.Scale, orig.X.Offset - 2, orig.Y.Scale, orig.Y.Offset - 2) }):Play()
        task.wait(0.08)
        TweenService:Create(btn, TweenInfo.new(0.08), { Size = orig }):Play()
        if config.Callback then
            task.spawn(config.Callback)
        end
    end)

    return btn
end

-- ==================== WIDGET: TOGGLE ====================
function UIModule:CreateToggle(parent, config)
    config = config or {}
    local container = (type(parent) == "table" and parent.Page) or parent
    local state = config.Default or false

    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, 0, 0, (config.Description and 48) or 38)
    row.BackgroundColor3 = THEME.Element
    row.BorderSizePixel = 0
    row.Text = ""
    row.AutoButtonColor = false
    row.Parent = container

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = row

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(36, 36, 46)
    stroke.Thickness = 1
    stroke.Parent = row

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -70, 0, 18)
    titleLbl.Position = UDim2.new(0, 12, 0, (config.Description and 6) or 10)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = config.Title or "Toggle"
    titleLbl.Font = Enum.Font.GothamMedium
    titleLbl.TextSize = 12
    titleLbl.TextColor3 = THEME.TextPrimary
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = row

    if config.Description then
        local descLbl = Instance.new("TextLabel")
        descLbl.Size = UDim2.new(1, -70, 0, 14)
        descLbl.Position = UDim2.new(0, 12, 0, 26)
        descLbl.BackgroundTransparency = 1
        descLbl.Text = config.Description
        descLbl.Font = Enum.Font.Gotham
        descLbl.TextSize = 10
        descLbl.TextColor3 = THEME.TextMuted
        descLbl.TextXAlignment = Enum.TextXAlignment.Left
        descLbl.Parent = row
    end

    local pill = Instance.new("Frame")
    pill.Size = UDim2.new(0, 38, 0, 20)
    pill.Position = UDim2.new(1, -50, 0.5, -10)
    pill.BackgroundColor3 = state and Color3.fromRGB(245, 245, 250) or Color3.fromRGB(38, 38, 48)
    pill.BorderSizePixel = 0
    pill.Parent = row

    local pillCorner = Instance.new("UICorner")
    pillCorner.CornerRadius = UDim.new(1, 0)
    pillCorner.Parent = pill

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = state and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
    knob.BackgroundColor3 = state and Color3.fromRGB(15, 15, 20) or Color3.fromRGB(180, 180, 190)
    knob.BorderSizePixel = 0
    knob.Parent = pill

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob

    local function updateToggle(val)
        state = val
        local targetPill = state and Color3.fromRGB(245, 245, 250) or Color3.fromRGB(38, 38, 48)
        local targetKnobPos = state and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
        local targetKnobColor = state and Color3.fromRGB(15, 15, 20) or Color3.fromRGB(180, 180, 190)

        TweenService:Create(pill, TweenInfo.new(0.22, Enum.EasingStyle.Quart), { BackgroundColor3 = targetPill }):Play()
        TweenService:Create(knob, TweenInfo.new(0.22, Enum.EasingStyle.Quart), {
            Position = targetKnobPos,
            BackgroundColor3 = targetKnobColor
        }):Play()

        if config.Callback then
            task.spawn(config.Callback, state)
        end
    end

    row.MouseButton1Click:Connect(function()
        updateToggle(not state)
    end)

    return {
        Set = updateToggle,
        Get = function() return state end
    }
end

-- ==================== WIDGET: SLIDER ====================
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
    row.Size = UDim2.new(1, 0, 0, 50)
    row.BackgroundColor3 = THEME.Element
    row.BorderSizePixel = 0
    row.Parent = container

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = row

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(36, 36, 46)
    stroke.Thickness = 1
    stroke.Parent = row

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -80, 0, 18)
    titleLbl.Position = UDim2.new(0, 12, 0, 8)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = config.Title or "Slider"
    titleLbl.Font = Enum.Font.GothamMedium
    titleLbl.TextSize = 12
    titleLbl.TextColor3 = THEME.TextPrimary
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = row

    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(0, 70, 0, 18)
    valLbl.Position = UDim2.new(1, -82, 0, 8)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = tostring(val) .. suffix
    valLbl.Font = Enum.Font.GothamBold
    valLbl.TextSize = 11
    valLbl.TextColor3 = THEME.TextSecondary
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Parent = row

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -24, 0, 4)
    track.Position = UDim2.new(0, 12, 0, 34)
    track.BackgroundColor3 = Color3.fromRGB(40, 40, 52)
    track.BorderSizePixel = 0
    track.Parent = row

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = track

    local fill = Instance.new("Frame")
    local ratio = math.clamp((val - min) / (max - min), 0, 1)
    fill.Size = UDim2.new(ratio, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(245, 245, 255)
    fill.BorderSizePixel = 0
    fill.Parent = track

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill

    local dragging = false
    local function update(input)
        local posX = math.clamp(input.Position.X - track.AbsolutePosition.X, 0, track.AbsoluteSize.X)
        local pct = posX / track.AbsoluteSize.X
        local raw = min + (max - min) * pct
        local stepped = math.floor((raw / inc) + 0.5) * inc
        val = math.clamp(stepped, min, max)

        fill.Size = UDim2.new((val - min) / (max - min), 0, 1, 0)
        valLbl.Text = tostring(val) .. suffix

        if config.Callback then
            task.spawn(config.Callback, val)
        end
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

-- ==================== WIDGET: DROPDOWN ====================
function UIModule:CreateDropdown(parent, config)
    config = config or {}
    local container = (type(parent) == "table" and parent.Page) or parent
    local options = config.Options or {}
    local selected = config.Default or options[1] or ""
    local open = false

    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 38)
    holder.BackgroundColor3 = THEME.Element
    holder.BorderSizePixel = 0
    holder.ClipsDescendants = true
    holder.Parent = container

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = holder

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(36, 36, 46)
    stroke.Thickness = 1
    stroke.Parent = holder

    local header = Instance.new("TextButton")
    header.Size = UDim2.new(1, 0, 0, 38)
    header.BackgroundTransparency = 1
    header.Text = ""
    header.AutoButtonColor = false
    header.Parent = holder

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(0.5, 0, 1, 0)
    titleLbl.Position = UDim2.new(0, 12, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = config.Title or "Dropdown"
    titleLbl.Font = Enum.Font.GothamMedium
    titleLbl.TextSize = 12
    titleLbl.TextColor3 = THEME.TextPrimary
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = header

    local selLbl = Instance.new("TextLabel")
    selLbl.Size = UDim2.new(0.5, -42, 1, 0)
    selLbl.Position = UDim2.new(0.5, 0, 0, 0)
    selLbl.BackgroundTransparency = 1
    selLbl.Text = selected
    selLbl.Font = Enum.Font.Gotham
    selLbl.TextSize = 11
    selLbl.TextColor3 = THEME.AccentMuted
    selLbl.TextXAlignment = Enum.TextXAlignment.Right
    selLbl.Parent = header

    local arrow = Instance.new("TextLabel")
    arrow.Size = UDim2.new(0, 16, 0, 16)
    arrow.Position = UDim2.new(1, -26, 0.5, -8)
    arrow.BackgroundTransparency = 1
    arrow.Text = "▼"
    arrow.Font = Enum.Font.GothamBold
    arrow.TextSize = 9
    arrow.TextColor3 = THEME.TextMuted
    arrow.Parent = header

    local optList = Instance.new("Frame")
    optList.Size = UDim2.new(1, 0, 0, #options * 28)
    optList.Position = UDim2.new(0, 0, 0, 38)
    optList.BackgroundTransparency = 1
    optList.Parent = holder

    local optLayout = Instance.new("UIListLayout")
    optLayout.Parent = optList

    local function refresh()
        local targetH = open and (38 + #options * 28 + 6) or 38
        TweenService:Create(holder, TweenInfo.new(0.25, Enum.EasingStyle.Quart), { Size = UDim2.new(1, 0, 0, targetH) }):Play()
        TweenService:Create(arrow, TweenInfo.new(0.2), { Rotation = open and 180 or 0 }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2), { Color = open and Color3.fromRGB(70, 70, 90) or Color3.fromRGB(36, 36, 46) }):Play()
    end

    for _, opt in ipairs(options) do
        local obtn = Instance.new("TextButton")
        obtn.Size = UDim2.new(1, 0, 0, 28)
        obtn.BackgroundTransparency = 1
        obtn.Text = "    " .. opt
        obtn.Font = Enum.Font.Gotham
        obtn.TextSize = 11
        obtn.TextColor3 = (opt == selected) and THEME.TextPrimary or THEME.TextMuted
        obtn.TextXAlignment = Enum.TextXAlignment.Left
        obtn.Parent = optList

        obtn.MouseButton1Click:Connect(function()
            selected = opt
            selLbl.Text = selected
            open = false
            refresh()
            for _, child in ipairs(optList:GetChildren()) do
                if child:IsA("TextButton") then
                    child.TextColor3 = (child.Text == "    " .. selected) and THEME.TextPrimary or THEME.TextMuted
                end
            end
            if config.Callback then
                task.spawn(config.Callback, selected)
            end
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

-- ==================== WIDGET: TEXT INPUT ====================
function UIModule:CreateInput(parent, config)
    config = config or {}
    local container = (type(parent) == "table" and parent.Page) or parent

    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 40)
    row.BackgroundColor3 = THEME.Element
    row.BorderSizePixel = 0
    row.Parent = container

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = row

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(36, 36, 46)
    stroke.Thickness = 1
    stroke.Parent = row

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(0.45, 0, 1, 0)
    titleLbl.Position = UDim2.new(0, 12, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = config.Title or "Input"
    titleLbl.Font = Enum.Font.GothamMedium
    titleLbl.TextSize = 12
    titleLbl.TextColor3 = THEME.TextPrimary
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = row

    local tb = Instance.new("TextBox")
    tb.Size = UDim2.new(0.5, 0, 0, 26)
    tb.Position = UDim2.new(0.5, -8, 0.5, -13)
    tb.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    tb.BorderSizePixel = 0
    tb.Text = config.Default or ""
    tb.PlaceholderText = config.Placeholder or "Type here..."
    tb.PlaceholderColor3 = THEME.TextMuted
    tb.Font = Enum.Font.Gotham
    tb.TextSize = 11
    tb.TextColor3 = THEME.TextPrimary
    tb.ClearTextOnFocus = false
    tb.Parent = row

    local tbCorner = Instance.new("UICorner")
    tbCorner.CornerRadius = UDim.new(0, 5)
    tbCorner.Parent = tb

    local tbStroke = Instance.new("UIStroke")
    tbStroke.Color = Color3.fromRGB(45, 45, 58)
    tbStroke.Thickness = 1
    tbStroke.Parent = tb

    tb.Focused:Connect(function()
        TweenService:Create(tbStroke, TweenInfo.new(0.2), { Color = THEME.Accent }):Play()
    end)
    tb.FocusLost:Connect(function(enterPressed)
        TweenService:Create(tbStroke, TweenInfo.new(0.2), { Color = Color3.fromRGB(45, 45, 58) }):Play()
        if config.Callback then
            task.spawn(config.Callback, tb.Text, enterPressed)
        end
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
    row.Size = UDim2.new(1, 0, 0, 34)
    row.BackgroundColor3 = THEME.Element
    row.BorderSizePixel = 0
    row.Text = ""
    row.AutoButtonColor = false
    row.Parent = container

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = row

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(36, 36, 46)
    stroke.Thickness = 1
    stroke.Parent = row

    local box = Instance.new("Frame")
    box.Size = UDim2.new(0, 16, 0, 16)
    box.Position = UDim2.new(0, 12, 0.5, -8)
    box.BackgroundColor3 = checked and Color3.fromRGB(240, 240, 250) or Color3.fromRGB(30, 30, 38)
    box.BorderSizePixel = 0
    box.Parent = row

    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 4)
    boxCorner.Parent = box

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
    titleLbl.Size = UDim2.new(1, -40, 1, 0)
    titleLbl.Position = UDim2.new(0, 36, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = config.Title or "Checkbox"
    titleLbl.Font = Enum.Font.GothamMedium
    titleLbl.TextSize = 11
    titleLbl.TextColor3 = THEME.TextPrimary
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = row

    local function toggle(val)
        checked = val
        checkmark.Visible = checked
        TweenService:Create(box, TweenInfo.new(0.2), {
            BackgroundColor3 = checked and Color3.fromRGB(240, 240, 250) or Color3.fromRGB(30, 30, 38)
        }):Play()
        if config.Callback then
            task.spawn(config.Callback, checked)
        end
    end

    row.MouseButton1Click:Connect(function()
        toggle(not checked)
    end)

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
    btn.Size = UDim2.new(1, 0, 0, 38)
    btn.BackgroundColor3 = THEME.Element
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = container

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(36, 36, 46)
    stroke.Thickness = 1
    stroke.Parent = btn

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -40, 1, 0)
    titleLbl.Position = UDim2.new(0, 12, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = (config.Title or "Picker") .. "  ⚙"
    titleLbl.Font = Enum.Font.GothamMedium
    titleLbl.TextSize = 12
    titleLbl.TextColor3 = THEME.TextPrimary
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = btn

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = THEME.ElementHover }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2), { Color = Color3.fromRGB(70, 70, 85) }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = THEME.Element }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2), { Color = Color3.fromRGB(36, 36, 46) }):Play()
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
    overlay.BackgroundTransparency = 0.4
    overlay.Text = ""
    overlay.AutoButtonColor = false
    overlay.Parent = screenGui

    local modal = Instance.new("Frame")
    modal.Size = UDim2.new(0, 330, 0, 360)
    modal.Position = UDim2.new(0.5, -165, 0.5, -180)
    modal.BackgroundColor3 = THEME.Background
    modal.BorderSizePixel = 0
    modal.Parent = overlay

    local modalCorner = Instance.new("UICorner")
    modalCorner.CornerRadius = UDim.new(0, 12)
    modalCorner.Parent = modal

    local modalStroke = Instance.new("UIStroke")
    modalStroke.Color = Color3.fromRGB(60, 60, 75)
    modalStroke.Thickness = 1.2
    modalStroke.Parent = modal

    local mTitle = Instance.new("TextLabel")
    mTitle.Size = UDim2.new(1, -24, 0, 42)
    mTitle.Position = UDim2.new(0, 16, 0, 0)
    mTitle.BackgroundTransparency = 1
    mTitle.Text = config.Title or "Select Options"
    mTitle.Font = Enum.Font.GothamBold
    mTitle.TextSize = 13
    mTitle.TextColor3 = THEME.TextPrimary
    mTitle.TextXAlignment = Enum.TextXAlignment.Left
    mTitle.Parent = modal

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -24, 1, -100)
    scroll.Position = UDim2.new(0, 12, 0, 44)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 2
    scroll.ScrollBarImageColor3 = Color3.fromRGB(50, 50, 60)
    scroll.Parent = modal

    local sLayout = Instance.new("UIListLayout")
    sLayout.Padding = UDim.new(0, 6)
    sLayout.Parent = scroll

    local selectedMap = {}
    if config.Selected then
        for _, v in ipairs(config.Selected) do
            selectedMap[v] = true
        end
    end

    for _, opt in ipairs(config.Options or {}) do
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, -6, 0, 30)
        row.BackgroundColor3 = selectedMap[opt] and Color3.fromRGB(30, 30, 38) or Color3.fromRGB(18, 18, 22)
        row.BorderSizePixel = 0
        row.Text = ""
        row.AutoButtonColor = false
        row.Parent = scroll

        local rCorner = Instance.new("UICorner")
        rCorner.CornerRadius = UDim.new(0, 6)
        rCorner.Parent = row

        local rStroke = Instance.new("UIStroke")
        rStroke.Color = selectedMap[opt] and Color3.fromRGB(80, 80, 100) or Color3.fromRGB(30, 30, 38)
        rStroke.Thickness = 1
        rStroke.Parent = row

        local rText = Instance.new("TextLabel")
        rText.Size = UDim2.new(1, -34, 1, 0)
        rText.Position = UDim2.new(0, 12, 0, 0)
        rText.BackgroundTransparency = 1
        rText.Text = opt
        rText.Font = Enum.Font.Gotham
        rText.TextSize = 11
        rText.TextColor3 = selectedMap[opt] and THEME.TextPrimary or THEME.TextMuted
        rText.TextXAlignment = Enum.TextXAlignment.Left
        rText.Parent = row

        local ind = Instance.new("TextLabel")
        ind.Size = UDim2.new(0, 20, 1, 0)
        ind.Position = UDim2.new(1, -26, 0, 0)
        ind.BackgroundTransparency = 1
        ind.Text = selectedMap[opt] and "✓" or ""
        ind.Font = Enum.Font.GothamBold
        ind.TextSize = 12
        ind.TextColor3 = THEME.TextPrimary
        ind.Parent = row

        row.MouseButton1Click:Connect(function()
            selectedMap[opt] = not selectedMap[opt]
            ind.Text = selectedMap[opt] and "✓" or ""
            rText.TextColor3 = selectedMap[opt] and THEME.TextPrimary or THEME.TextMuted
            row.BackgroundColor3 = selectedMap[opt] and Color3.fromRGB(30, 30, 38) or Color3.fromRGB(18, 18, 22)
            rStroke.Color = selectedMap[opt] and Color3.fromRGB(80, 80, 100) or Color3.fromRGB(30, 30, 38)
        end)
    end

    scroll.CanvasSize = UDim2.new(0, 0, 0, sLayout.AbsoluteContentSize.Y + 10)

    local doneBtn = Instance.new("TextButton")
    doneBtn.Size = UDim2.new(1, -24, 0, 32)
    doneBtn.Position = UDim2.new(0, 12, 1, -44)
    doneBtn.BackgroundColor3 = Color3.fromRGB(245, 245, 250)
    doneBtn.BorderSizePixel = 0
    doneBtn.Text = "Confirm Selection"
    doneBtn.Font = Enum.Font.GothamBold
    doneBtn.TextSize = 12
    doneBtn.TextColor3 = Color3.fromRGB(15, 15, 20)
    doneBtn.AutoButtonColor = false
    doneBtn.Parent = modal

    local doneCorner = Instance.new("UICorner")
    doneCorner.CornerRadius = UDim.new(0, 7)
    doneCorner.Parent = doneBtn

    doneBtn.MouseButton1Click:Connect(function()
        local result = {}
        for k, v in pairs(selectedMap) do
            if v then table.insert(result, k) end
        end
        if config.Callback then
            task.spawn(config.Callback, result)
        end
        overlay:Destroy()
    end)
end

return UIModule
