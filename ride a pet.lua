local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local VirtualUser = game:GetService("VirtualUser")

local player = Players.LocalPlayer
local shared = getgenv and getgenv() or _G
if not shared.RideAPetAntiAfkConnection or not shared.RideAPetAntiAfkConnection.Connected then
    shared.RideAPetAntiAfkConnection = player.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
    print("[RideAPet] Anti-AFK enabled")
end
local gameData = RS:WaitForChild("GameData")
local Eggs = require(gameData:WaitForChild("Eggs"))
local General = require(gameData:WaitForChild("General"))
local Rebirths = require(gameData:WaitForChild("Rebirths"))
local Pets = require(gameData:WaitForChild("Pets"))
local Mutations = require(gameData:WaitForChild("Mutations"))
local PetAging = require(RS:WaitForChild("GameServices"):WaitForChild("PetAging"))
local activeEggs = RS:WaitForChild("ServerData"):WaitForChild("ActiveEggs")
local savedData = player:WaitForChild("SavedData")
local cashValue = savedData:WaitForChild("Cash")
local rebirthValue = savedData:WaitForChild("Rebirths")
local tutorialFinished = savedData:WaitForChild("HasFinishedTutorial")

local remotesGame = RS:WaitForChild("Remotes"):WaitForChild("Game")
local eggPickupRemote = remotesGame:WaitForChild("EggPickup")
local eggPlacedRemote = remotesGame:WaitForChild("EggPlaced")
local hatchRemote = remotesGame:WaitForChild("Hatch")
local rebirthRemote = remotesGame:WaitForChild("Rebirth")
local pickupPetRemote = remotesGame:WaitForChild("PickupPet")
local placePetRemote = remotesGame:WaitForChild("PlacePet")
local upgradeRemote = remotesGame:WaitForChild("Plot"):WaitForChild("Upgrades")
local tutorialStepRemote = RS:WaitForChild("Remotes"):WaitForChild("Tutorial"):WaitForChild("Step")

-- ตั้งค่า
local POST_PICKUP_DELAY = 4 
local PICKUP_TIMEOUT = 3 
local FLY_SPEED = 450  
local LOOP_INTERVAL = 1 
local PLOT_EGG_CAPACITY = 10
local FALLBACK_CFARM_POS = Vector3.new(260.6596374511719, 40313.2421875, 830.9907836914062)

local REBIRTH_TARGETS = {
    Horse = "Asteroid Egg",
    Fox = "Soul Egg",
    Unicorn = "Cherub Egg",
    Phoenix = "Cherub Egg",
    Kitsune = "Cherub Egg",
    Dragon = "Cherub Egg"
}
-- ====================================================================

local currentTween = nil
local noclipConnection = nil
local kaitun = {
    status = "Starting",
    carriedEgg = nil,
    targetEgg = nil,
    targetLuck = 0,
    petPlacementPending = true,
    nextLuckUpgrade = 0
}
local setUI = function() end

local function formatLuck(num)
    if not num or num == 0 then return "0" end
    if num >= 1e12 then return string.format("%.1fT", num / 1e12) end
    if num >= 1e9  then return string.format("%.1fB", num / 1e9) end
    if num >= 1e6  then return string.format("%.1fM", num / 1e6) end
    if num >= 1e3  then return string.format("%.1fK", num / 1e3) end
    return tostring(num)
end

local function getCharacterParts()
    local char = player.Character
    if not char then return nil, nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    return char, root
end

local function stopMovement()
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end
end

local function isAlive()
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function warpTo(targetCFrame)
    local char, root = getCharacterParts()
    if not root then return false end

    local destination = targetCFrame + Vector3.new(0, 3.5, 0)
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero

    char:PivotTo(destination)
    task.wait()
    root.CFrame = destination
    return true
end

local function flyTo(targetCFrame, speed)
    local char, root = getCharacterParts()
    if not root then return false end

    stopMovement()

    local destination = targetCFrame + Vector3.new(0, 3, 0)
    local distance = (destination.Position - root.Position).Magnitude
    local travelTime = math.max(distance / math.max(speed, 50), 0.2)

    noclipConnection = RunService.Stepped:Connect(function()
        if char and char.Parent then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end)

    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero

    local tweenInfo = TweenInfo.new(travelTime, Enum.EasingStyle.Linear)
    currentTween = TweenService:Create(root, tweenInfo, {CFrame = destination})

    currentTween:Play()
    currentTween.Completed:Wait()

    stopMovement()

    if root and root.Parent then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
    return true
end

-- Locate egg coordinates
local function locateEggCFrame(eggData)
    local v = eggData.instance
    local uuid = eggData.uuid
    local eggName = eggData.name

    -- Attributes on ServerData
    for _, attr in ipairs({"Position", "Pos", "CFrame", "Location", "Origin"}) do
        local val = v:GetAttribute(attr)
        if typeof(val) == "Vector3" then return CFrame.new(val) end
        if typeof(val) == "CFrame" then return val end
    end

    -- ValueObject children
    for _, child in ipairs(v:GetChildren()) do
        if child:IsA("Vector3Value") then return CFrame.new(child.Value) end
        if child:IsA("CFrameValue") then return child.Value end
    end

    -- Workspace search by UUID
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if (obj.Name == uuid or obj:GetAttribute("UUID") == uuid) and (obj:IsA("BasePart") or obj:IsA("Model")) then
            return obj:IsA("Model") and obj:GetPivot() or obj.CFrame
        end
    end

    -- Workspace search by Egg Name
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if (obj.Name == eggName or obj:GetAttribute("Egg") == eggName) and (obj:IsA("BasePart") or obj:IsA("Model")) then
            if not obj:IsDescendantOf(player.Character) and not obj:FindFirstAncestorWhichIsA("ScreenGui") then
                return obj:IsA("Model") and obj:GetPivot() or obj.CFrame
            end
        end
    end

    return nil
end

local function getPlayerPlot()
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then return nil end

    for _, plot in ipairs(plots:GetChildren()) do
        local data = plot:FindFirstChild("Data")
        if data then
            local owner = data:FindFirstChild("Owner")
            if owner then
                local ownerVal = tostring(owner.Value)
                if ownerVal == player.Name or ownerVal == tostring(player.UserId) then
                    return plot
                end
            end
        end
    end
    return nil
end

local function getPlayerCFarmInfo()
    local plot = getPlayerPlot()
    if plot then
        for _, name in ipairs({"Cfarm", "CFarm", "C-Farm", "CandyFarm", "Farm", "PlantArea", "Plants"}) do
            local found = plot:FindFirstChild(name, true)
            if found then
                if found:IsA("BasePart") then
                    return found.CFrame, found.Position
                elseif found:IsA("Model") then
                    return found:GetPivot(), found:GetPivot().Position
                end
            end
        end

        if plot:IsA("Model") then
            return plot:GetPivot(), plot:GetPivot().Position
        elseif plot:IsA("BasePart") then
            return plot.CFrame, plot.Position
        end
    end

    return CFrame.new(FALLBACK_CFARM_POS), FALLBACK_CFARM_POS
end

local function isEggCollected(eggName)
    local collected = player:GetAttribute("CollectedEggs") or ""
    local formatted = "," .. collected .. ","
    return string.find(formatted, "," .. eggName .. ",", 1, true) ~= nil
end

local function getRequiredPet()
    local rebirthCount = math.max(tonumber(rebirthValue.Value) or 0, 0)
    if rebirthCount >= (tonumber(Rebirths.Cap) or 0) then
        return nil, rebirthCount
    end
    return General.RebirthRequirements[rebirthCount + 1], rebirthCount
end

local function ownsRequiredPet(requiredPet)
    if not requiredPet then
        return false
    end

    local function scan(container)
        if not container then
            return false
        end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") and item:GetAttribute("PetKey") then
                local petName = string.match(item.Name, "^(.-) %[") or item.Name
                if petName == requiredPet then
                    return true
                end
            end
        end
        return false
    end

    if scan(player:FindFirstChildOfClass("Backpack")) or scan(player.Character) then
        return true
    end

    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local mountJoint = root and root:FindFirstChild("PetMountJoint")
    local mountedPet = mountJoint and mountJoint.Part1 and mountJoint.Part1.Parent
    return mountedPet and mountedPet:GetAttribute("PetName") == requiredPet or false
end

local function getRebirthState()
    local requiredPet, rebirthCount = getRequiredPet()
    local cost = requiredPet and Rebirths.GetCost(rebirthCount) or 0
    local owned = ownsRequiredPet(requiredPet)
    local targetEgg = requiredPet and REBIRTH_TARGETS[requiredPet] or nil
    return requiredPet, targetEgg, cost, owned, rebirthCount
end

local function findTargetEgg(requiredEgg)
    local collected = player:GetAttribute("CollectedEggs") or ""
    local formattedCollected = "," .. collected .. ","
    local availableList = {}

    for _, v in ipairs(activeEggs:GetChildren()) do
        local name = v:GetAttribute("Egg")
        local luck = (name and Eggs[name] and Eggs[name].Luck) or 0
        local privateTo = v:GetAttribute("PrivateTo")
        local reason = "ok"

        if privateTo and privateTo ~= player.UserId then
            reason = "private"
        elseif name and string.find(formattedCollected, "," .. name .. ",", 1, true) then
            reason = "collected"
        end

        if reason == "ok" and name then
            table.insert(availableList, {
                name = name,
                luck = luck,
                uuid = v.Name,
                instance = v
            })
        end
    end

    if requiredEgg then
        for _, egg in ipairs(availableList) do
            if egg.name == requiredEgg then
                return egg
            end
        end
        return nil
    end

    table.sort(availableList, function(a, b) return a.luck > b.luck end)
    return availableList[1]
end

local ui = {}

do
    local playerGui = player:WaitForChild("PlayerGui")
    local existing = playerGui:FindFirstChild("XyraxPanel")
    if existing then
        existing:Destroy()
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "XyraxPanel"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = playerGui

    local dim = Instance.new("Frame")
    dim.Name = "Dim"
    dim.Size = UDim2.new(1, 0, 1, 0)
    dim.BackgroundColor3 = Color3.new(0, 0, 0)
    dim.BackgroundTransparency = 1
    dim.BorderSizePixel = 0
    dim.ZIndex = 1
    dim.Parent = gui

    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = UDim2.new(0, 480, 0, 210)
    main.Position = UDim2.new(0.5, -240, 0.5, -105)
    main.BackgroundColor3 = Color3.fromRGB(16, 17, 22)
    main.BackgroundTransparency = 0.08
    main.BorderSizePixel = 0
    main.ClipsDescendants = true
    main.ZIndex = 2
    main.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 26)
    corner.Parent = main

    local mainScale = Instance.new("UIScale")
    mainScale.Scale = 0.85
    mainScale.Parent = main

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.new(1, 1, 1)
    stroke.Transparency = 0.85
    stroke.Thickness = 1.6
    stroke.Parent = main

    local strokeGrad = Instance.new("UIGradient")
    strokeGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 180)),
        ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 200, 80)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 255, 200)),
        ColorSequenceKeypoint.new(0.75, Color3.fromRGB(140, 120, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 90, 180))
    })
    strokeGrad.Parent = stroke

    RunService.Heartbeat:Connect(function(dt)
        if gui.Parent then
            strokeGrad.Rotation = (strokeGrad.Rotation + dt * 40) % 360
        end
    end)

    local grad = Instance.new("UIGradient")
    grad.Rotation = 90
    grad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(38, 40, 52)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 13, 18))
    }
    grad.Parent = main

    local shimmer = Instance.new("Frame")
    shimmer.Name = "Shimmer"
    shimmer.Size = UDim2.new(0, 70, 0, 150)
    shimmer.Position = UDim2.new(0, -90, 0, 30)
    shimmer.Rotation = 0
    shimmer.BackgroundColor3 = Color3.new(1, 1, 1)
    shimmer.BorderSizePixel = 0
    shimmer.ZIndex = 6
    shimmer.Parent = main

    local shimmerGrad = Instance.new("UIGradient")
    shimmerGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 0.6),
        NumberSequenceKeypoint.new(1, 1)
    })
    shimmerGrad.Parent = shimmer

    task.spawn(function()
        while gui.Parent do
            shimmer.Position = UDim2.new(0, -90, 0, 30)
            local tween = TweenService:Create(shimmer, TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Position = UDim2.new(0, 500, 0, 30)})
            tween:Play()
            tween.Completed:Wait()
            task.wait(2.6)
        end
    end)

    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 44)
    topBar.BackgroundTransparency = 1
    topBar.ZIndex = 2
    topBar.Parent = main

    local dotColors = {Color3.fromRGB(255, 95, 87), Color3.fromRGB(255, 189, 46), Color3.fromRGB(39, 201, 63)}
    for i = 1, 3 do
        local dot = Instance.new("Frame")
        dot.Size = UDim2.new(0, 11, 0, 11)
        dot.Position = UDim2.new(0, 18 + (i - 1) * 20, 0.5, -5.5)
        dot.BackgroundColor3 = dotColors[i]
        dot.BorderSizePixel = 0
        dot.ZIndex = 2
        dot.Parent = topBar
        local dotCorner = Instance.new("UICorner")
        dotCorner.CornerRadius = UDim.new(1, 0)
        dotCorner.Parent = dot
        task.spawn(function()
            task.wait(i * 0.2)
            TweenService:Create(dot, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {BackgroundTransparency = 0.45}):Play()
        end)
    end

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 1, 0)
    title.BackgroundTransparency = 1
    title.Text = "Xyrax Kaitun"
    title.TextColor3 = Color3.fromRGB(240, 240, 245)
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 22
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.TextYAlignment = Enum.TextYAlignment.Center
    title.ZIndex = 2
    title.Parent = topBar

    local line1 = Instance.new("Frame")
    line1.Size = UDim2.new(1, -40, 0, 1)
    line1.Position = UDim2.new(0, 20, 0, 44)
    line1.BackgroundColor3 = Color3.new(1, 1, 1)
    line1.BackgroundTransparency = 0.9
    line1.BorderSizePixel = 0
    line1.ZIndex = 2
    line1.Parent = main

    local profileRow = Instance.new("Frame")
    profileRow.Size = UDim2.new(1, -40, 0, 46)
    profileRow.Position = UDim2.new(0, 20, 0, 54)
    profileRow.BackgroundTransparency = 1
    profileRow.ZIndex = 2
    profileRow.Parent = main

    local avatarGlow = Instance.new("Frame")
    avatarGlow.Size = UDim2.new(0, 54, 0, 54)
    avatarGlow.Position = UDim2.new(0, -5, 0.5, -27)
    avatarGlow.BackgroundColor3 = Color3.fromRGB(130, 150, 255)
    avatarGlow.BackgroundTransparency = 0.55
    avatarGlow.BorderSizePixel = 0
    avatarGlow.ZIndex = 1
    avatarGlow.Parent = profileRow
    local avatarGlowCorner = Instance.new("UICorner")
    avatarGlowCorner.CornerRadius = UDim.new(1, 0)
    avatarGlowCorner.Parent = avatarGlow
    TweenService:Create(avatarGlow, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Size = UDim2.new(0, 62, 0, 62), Position = UDim2.new(0, -9, 0.5, -31), BackgroundTransparency = 0.85}):Play()

    local avatar = Instance.new("ImageLabel")
    avatar.Size = UDim2.new(0, 44, 0, 44)
    avatar.Position = UDim2.new(0, 0, 0.5, -22)
    avatar.BackgroundColor3 = Color3.fromRGB(40, 42, 54)
    avatar.BorderSizePixel = 0
    avatar.Image = ""
    avatar.ZIndex = 2
    avatar.Parent = profileRow
    local avatarCorner = Instance.new("UICorner")
    avatarCorner.CornerRadius = UDim.new(1, 0)
    avatarCorner.Parent = avatar
    local avatarStroke = Instance.new("UIStroke")
    avatarStroke.Color = Color3.new(1, 1, 1)
    avatarStroke.Transparency = 0.75
    avatarStroke.Parent = avatar
    task.spawn(function()
        local ok, image = pcall(function()
            return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
        end)
        if ok then
            avatar.Image = image
        end
    end)

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(0, 180, 0, 20)
    nameLabel.Position = UDim2.new(0, 54, 0, 3)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = player.DisplayName
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 16
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.ZIndex = 2
    nameLabel.Parent = profileRow

    local handleLabel = Instance.new("TextLabel")
    handleLabel.Size = UDim2.new(0, 180, 0, 16)
    handleLabel.Position = UDim2.new(0, 54, 0, 23)
    handleLabel.BackgroundTransparency = 1
    handleLabel.Text = "@" .. player.Name
    handleLabel.TextColor3 = Color3.fromRGB(150, 155, 168)
    handleLabel.Font = Enum.Font.Gotham
    handleLabel.TextSize = 12
    handleLabel.TextXAlignment = Enum.TextXAlignment.Left
    handleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    handleLabel.ZIndex = 2
    handleLabel.Parent = profileRow
    local costCaption = Instance.new("TextLabel")
    costCaption.Size = UDim2.new(0, 140, 0, 16)
    costCaption.Position = UDim2.new(1, -140, 0, 3)
    costCaption.BackgroundTransparency = 1
    costCaption.Text = "REBIRTH COST"
    costCaption.TextColor3 = Color3.fromRGB(150, 155, 168)
    costCaption.Font = Enum.Font.GothamMedium
    costCaption.TextSize = 11
    costCaption.TextXAlignment = Enum.TextXAlignment.Right
    costCaption.ZIndex = 2
    costCaption.Parent = profileRow

    local costValue = Instance.new("TextLabel")
    costValue.Size = UDim2.new(0, 140, 0, 22)
    costValue.Position = UDim2.new(1, -140, 0, 21)
    costValue.BackgroundTransparency = 1
    costValue.Text = "0"
    costValue.TextColor3 = Color3.new(1, 1, 1)
    costValue.Font = Enum.Font.GothamBold
    costValue.TextSize = 16
    costValue.TextXAlignment = Enum.TextXAlignment.Right
    costValue.ZIndex = 2
    costValue.Parent = profileRow

    local line2 = Instance.new("Frame")
    line2.Size = UDim2.new(1, -40, 0, 1)
    line2.Position = UDim2.new(0, 20, 0, 108)
    line2.BackgroundColor3 = Color3.new(1, 1, 1)
    line2.BackgroundTransparency = 0.9
    line2.BorderSizePixel = 0
    line2.ZIndex = 2
    line2.Parent = main

    local catRig = Instance.new("Frame")
    catRig.Name = "CatRig"
    catRig.Size = UDim2.new(0, 30, 0, 16)
    catRig.Position = UDim2.new(0, 20, 0, 100)
    catRig.BackgroundTransparency = 1
    catRig.ZIndex = 5
    catRig.Parent = main
    local catBody = Instance.new("Frame")
    catBody.Size = UDim2.new(0, 22, 0, 11)
    catBody.Position = UDim2.new(0, 4, 0, 4)
    catBody.BackgroundColor3 = Color3.fromRGB(250, 250, 252)
    catBody.BorderSizePixel = 0
    catBody.ZIndex = 5
    catBody.Parent = catRig
    local catBodyCorner = Instance.new("UICorner")
    catBodyCorner.CornerRadius = UDim.new(0, 6)
    catBodyCorner.Parent = catBody
    local catHead = Instance.new("Frame")
    catHead.Size = UDim2.new(0, 12, 0, 12)
    catHead.Position = UDim2.new(0, 19, 0, -1)
    catHead.BackgroundColor3 = Color3.fromRGB(250, 250, 252)
    catHead.BorderSizePixel = 0
    catHead.ZIndex = 5
    catHead.Parent = catRig
    local catHeadCorner = Instance.new("UICorner")
    catHeadCorner.CornerRadius = UDim.new(1, 0)
    catHeadCorner.Parent = catHead
    for _, x in ipairs({20, 27}) do
        local ear = Instance.new("Frame")
        ear.Size = UDim2.new(0, 5, 0, 5)
        ear.Position = UDim2.new(0, x, 0, -3)
        ear.Rotation = 45
        ear.BackgroundColor3 = Color3.fromRGB(250, 250, 252)
        ear.BorderSizePixel = 0
        ear.ZIndex = 5
        ear.Parent = catRig
    end
    local eye = Instance.new("Frame")
    eye.Size = UDim2.new(0, 2, 0, 2)
    eye.Position = UDim2.new(0, 26, 0, 4)
    eye.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    eye.BorderSizePixel = 0
    eye.ZIndex = 5
    eye.Parent = catRig
    local eyeCorner = Instance.new("UICorner")
    eyeCorner.CornerRadius = UDim.new(1, 0)
    eyeCorner.Parent = eye
    local catTail = Instance.new("Frame")
    catTail.Size = UDim2.new(0, 9, 0, 3)
    catTail.AnchorPoint = Vector2.new(1, 0.5)
    catTail.Position = UDim2.new(0, 4, 0, 7)
    catTail.BackgroundColor3 = Color3.fromRGB(250, 250, 252)
    catTail.BorderSizePixel = 0
    catTail.ZIndex = 5
    catTail.Parent = catRig
    local catTailCorner = Instance.new("UICorner")
    catTailCorner.CornerRadius = UDim.new(1, 0)
    catTailCorner.Parent = catTail
    TweenService:Create(catTail, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Rotation = 25}):Play()
    task.spawn(function()
        while gui.Parent do
            local right = TweenService:Create(catRig, TweenInfo.new(3.5, Enum.EasingStyle.Linear), {Position = UDim2.new(0, 430, 0, 100)})
            right:Play()
            right.Completed:Wait()
            local left = TweenService:Create(catRig, TweenInfo.new(3.5, Enum.EasingStyle.Linear), {Position = UDim2.new(0, 20, 0, 100)})
            left:Play()
            left.Completed:Wait()
        end
    end)
    task.spawn(function()
        while gui.Parent do
            TweenService:Create(catBody, TweenInfo.new(0.18, Enum.EasingStyle.Sine), {Position = UDim2.new(0, 4, 0, 2)}):Play()
            task.wait(0.18)
            TweenService:Create(catBody, TweenInfo.new(0.18, Enum.EasingStyle.Sine), {Position = UDim2.new(0, 4, 0, 4)}):Play()
            task.wait(0.18)
        end
    end)

    local list = Instance.new("Frame")
    list.Size = UDim2.new(1, -56, 1, -126)
    list.Position = UDim2.new(0, 28, 0, 118)
    list.BackgroundTransparency = 1
    list.ZIndex = 2
    list.Parent = main
    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.new(0.5, -8, 0, 32)
    grid.CellPadding = UDim2.new(0, 10, 0, 8)
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    grid.Parent = list
    local function addStatus(text, value, order)
        local row = Instance.new("Frame")
        row.BackgroundTransparency = 1
        row.LayoutOrder = order
        row.ZIndex = 2
        row.Parent = list
        local key = Instance.new("TextLabel")
        key.Size = UDim2.new(0.55, 0, 1, 0)
        key.BackgroundTransparency = 1
        key.Text = text
        key.TextColor3 = Color3.fromRGB(160, 165, 178)
        key.Font = Enum.Font.GothamMedium
        key.TextSize = 15
        key.TextXAlignment = Enum.TextXAlignment.Left
        key.TextYAlignment = Enum.TextYAlignment.Center
        key.ZIndex = 2
        key.Parent = row
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.45, 0, 1, 0)
        label.Position = UDim2.new(0.55, 0, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = value
        label.TextColor3 = Color3.new(1, 1, 1)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 15
        label.TextXAlignment = Enum.TextXAlignment.Right
        label.TextYAlignment = Enum.TextYAlignment.Center
        label.ZIndex = 2
        label.Parent = row
        return label
    end
    local rebirthLabel = addStatus("Rebirth", "0", 1)
    local cashLabel = addStatus("Cash", "0", 2)
    local goalLabel = addStatus("Target", "None", 3)
    local statusLabel = addStatus("Status", "Starting", 4)
    local function setLabel(label, value)
        value = tostring(value)
        if label.Text ~= value then
            label.Text = value
            local original = label.TextColor3
            label.TextColor3 = Color3.fromRGB(255, 215, 90)
            TweenService:Create(label, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {TextColor3 = original}):Play()
        end
    end
    function ui.Update(data)
        setLabel(rebirthLabel, data.rebirth)
        setLabel(cashLabel, formatLuck(data.cash))
        setLabel(goalLabel, data.targetEgg and (string.gsub(data.targetEgg, " Egg$", "") .. " " .. formatLuck(data.targetLuck)) or "None")
        setLabel(statusLabel, data.status)
        setLabel(costValue, data.requiredPet and formatLuck(data.cost) or "Complete")
        handleLabel.Text = "@" .. player.Name .. (data.requiredPet and (" • " .. data.requiredPet .. " " .. (data.owned and "Yes" or "No")) or " • Complete")
    end

    main.BackgroundTransparency = 1
    stroke.Transparency = 1
    TweenService:Create(main, TweenInfo.new(0.4, Enum.EasingStyle.Quart), {BackgroundTransparency = 0.08}):Play()
    TweenService:Create(stroke, TweenInfo.new(0.4), {Transparency = 0.85}):Play()
    TweenService:Create(dim, TweenInfo.new(0.4, Enum.EasingStyle.Quart), {BackgroundTransparency = 0.55}):Play()
    TweenService:Create(mainScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
    task.spawn(function()
        task.wait(0.6)
        local basePosition = main.Position
        TweenService:Create(main, TweenInfo.new(2.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Position = basePosition + UDim2.new(0, 0, 0, 7)}):Play()
    end)
end

local function refreshUI()
    local requiredPet, targetEgg, cost, owned, rebirthCount = getRebirthState()
    setUI({
        rebirth = string.format("%d/%d", rebirthCount, Rebirths.Cap),
        cash = cashValue.Value,
        requiredPet = requiredPet,
        owned = owned,
        cost = cost,
        targetEgg = targetEgg,
        targetLuck = targetEgg and Eggs[targetEgg] and Eggs[targetEgg].Luck or 0,
        carriedEgg = kaitun.carriedEgg and kaitun.carriedEgg.name or nil,
        status = kaitun.status
    })
end

setUI = function(data)
    ui.Update(data)
end

local function setStatus(status)
    kaitun.status = status
    refreshUI()
end

task.spawn(function()
    if tutorialFinished.Value == true then
        return
    end
    for _, step in ipairs({1, 5, 6, 7, 8, 9, 10, 11, 11.5, 12, 13, 14, 15, 16, 17, 18}) do
        if tutorialFinished.Value == true then
            return
        end
        tutorialStepRemote:FireServer(step)
        task.wait(0.5)
    end
end)

local function getPlacedEgg()
    local plot = getPlayerPlot()
    if not plot then
        return nil
    end
    local waitingEgg = nil
    local waitingKey = nil
    for _, instance in ipairs(plot:GetDescendants()) do
        local eggKey = instance:GetAttribute("EggKey")
        if eggKey then
            local model = instance:IsA("Model") and instance or instance:FindFirstAncestorOfClass("Model")
            if model and model:IsDescendantOf(plot) then
                if CollectionService:HasTag(model, "Hatching") then
                    return model, eggKey
                end
                for _, child in ipairs(model:GetDescendants()) do
                    if child:IsA("ProximityPrompt") and child.Name == "Hatch" and child.Enabled then
                        return model, eggKey
                    end
                end
                if not waitingEgg then
                    waitingEgg = model
                    waitingKey = eggKey
                end
            end
        end
    end
    return waitingEgg, waitingKey
end

local function getHatchPrompt(eggModel)
    for _, instance in ipairs(eggModel:GetDescendants()) do
        if instance:IsA("ProximityPrompt") and instance.Name == "Hatch" then
            return instance
        end
    end
    return nil
end

local function hatchPlacedEgg(eggModel, eggKey)
    if CollectionService:HasTag(eggModel, "Hatching") then
        setStatus("Hatching")
        return true
    end
    local prompt = getHatchPrompt(eggModel)
    if not prompt or not prompt.Enabled then
        return false
    end
    setStatus("Hatching")
    CollectionService:AddTag(eggModel, "Hatching")
    prompt.Enabled = false
    hatchRemote:FireServer({EggKey = eggKey})
    task.wait(0.5)
    return true
end

local function getPlacedEggCount()
    local plot = getPlayerPlot()
    local eggs = plot and plot:FindFirstChild("Eggs")
    return eggs and #eggs:GetChildren() or 0
end

local function getEggPlacementState()
    local plot = getPlayerPlot()
    if not plot then
        return false, "unknown"
    end
    local placed = getPlacedEggCount()
    if placed >= PLOT_EGG_CAPACITY then
        return false, "capacity", placed, PLOT_EGG_CAPACITY
    end
    if plot:GetAttribute("NoNest") == true then
        return true, "nonest", placed, PLOT_EGG_CAPACITY
    end
    local nests = plot:FindFirstChild("Nests")
    local free = 0
    if nests then
        for _, nest in ipairs(nests:GetChildren()) do
            if nest:GetAttribute("Unlocked") == true and nest:GetAttribute("Occupied") ~= true then
                free += 1
            end
        end
    end
    return free > 0, "nest", placed, free
end

local function canStartEggTransaction()
    local canPlace, mode = getEggPlacementState()
    if canPlace then
        return true
    end
    setStatus(mode == "nest" and "Waiting For Nest" or "Waiting For Slot")
    return false
end

local function finishCarriedEgg()
    local egg = kaitun.carriedEgg
    if not egg or not isAlive() then
        kaitun.carriedEgg = nil
        return
    end
    if not egg.returned then
        setStatus("Carrying Egg")
        if POST_PICKUP_DELAY > 0 then
            local started = os.clock()
            while isAlive() and os.clock() - started < POST_PICKUP_DELAY do
                task.wait(0.2)
            end
        end
        if not isAlive() then
            return
        end
        setStatus("Returning To Farm")
        local cfarmCFrame = getPlayerCFarmInfo()
        flyTo(cfarmCFrame, FLY_SPEED)
        if not isAlive() then
            return
        end
        egg.returned = true
    end
    local canPlace, placementMode = getEggPlacementState()
    if not canPlace then
        setStatus(placementMode == "nest" and "Waiting For Nest" or "Waiting For Slot")
        return
    end
    if os.clock() < (egg.nextPlacementAttempt or 0) then
        setStatus(placementMode == "nest" and "Waiting For Nest" or "Waiting For Slot")
        return
    end
    local _, cfarmPosition = getPlayerCFarmInfo()
    setStatus("Placing Egg")
    local placedBefore = getPlacedEggCount()
    eggPlacedRemote:FireServer({PlantPosition = cfarmPosition})
    local deadline = os.clock() + 2
    while isAlive() and os.clock() < deadline do
        if getPlacedEggCount() > placedBefore then
            kaitun.carriedEgg = nil
            kaitun.targetEgg = nil
            kaitun.targetLuck = 0
            return
        end
        task.wait(0.1)
    end
    local _, mode = getEggPlacementState()
    egg.nextPlacementAttempt = os.clock() + 2
    setStatus(mode == "nest" and "Waiting For Nest" or "Waiting For Slot")
end

local function collectEgg(egg, rebirthTarget)
    kaitun.targetEgg = egg.name
    kaitun.targetLuck = egg.luck
    setStatus(rebirthTarget and "Rebirth Egg Available" or "Finding Best Egg")
    local eggCFrame = locateEggCFrame(egg)
    if not eggCFrame then
        warn("[-] Failed to find coordinates for " .. egg.name)
        return
    end
    if not isAlive() then
        return
    end
    setStatus(rebirthTarget and "Collecting Rebirth Egg" or "Farming Best Egg")
    warpTo(eggCFrame)
    local started = os.clock()
    while isAlive() and os.clock() - started < PICKUP_TIMEOUT do
        eggPickupRemote:FireServer(egg.uuid)
        if isEggCollected(egg.name) or not activeEggs:FindFirstChild(egg.uuid) then
            kaitun.carriedEgg = egg
            setStatus("Carrying Egg")
            return
        end
        task.wait(0.1)
    end
    warn("[-] Pick-up timed out on " .. egg.name)
end

local function upgradeHatchLuck()
    if os.clock() < kaitun.nextLuckUpgrade then
        return
    end
    kaitun.nextLuckUpgrade = os.clock() + 5
    setStatus("Upgrading Luck")
    upgradeRemote:FireServer("Max")
end

local function petIncome(instance)
    local petName = instance:GetAttribute("PetName") or instance.Name
    local petData = Pets[petName]
    local income = petData and tonumber(petData.Income) or 0
    if income <= 0 then
        return 0
    end
    local weight = tonumber(instance:GetAttribute("Weight")) or 1
    local mutation = Mutations.CombinedFactor(instance:GetAttribute("Mutation"), instance:GetAttribute("SpawnMutation"))
    return math.floor(math.floor(income * (weight / PetAging.WeightStandardKG)) * mutation)
end

local function findPetTool(petKey)
    for _, container in ipairs({player.Character, player:FindFirstChildOfClass("Backpack")}) do
        if container then
            for _, item in ipairs(container:GetChildren()) do
                if item:IsA("Tool") and item:GetAttribute("PetKey") == petKey then
                    return item
                end
            end
        end
    end
    return nil
end

local function getOwnedPets(requiredPet)
    local pets = {}
    local plot = getPlayerPlot()
    local plotPets = plot and plot:FindFirstChild("Pets")
    if plotPets then
        for _, model in ipairs(plotPets:GetChildren()) do
            local petKey = model:GetAttribute("PetKey")
            if petKey and model:GetAttribute("PetName") ~= requiredPet then
                table.insert(pets, {key = petKey, income = petIncome(model), placed = true, position = model:GetPivot().Position})
            end
        end
    end
    for _, container in ipairs({player.Character, player:FindFirstChildOfClass("Backpack")}) do
        if container then
            for _, tool in ipairs(container:GetChildren()) do
                local petKey = tool:IsA("Tool") and tool:GetAttribute("PetKey")
                if petKey and tool:HasTag("Pet") and tool:GetAttribute("PetName") ~= requiredPet then
                    table.insert(pets, {key = petKey, income = petIncome(tool), placed = false, tool = tool})
                end
            end
        end
    end
    table.sort(pets, function(a, b)
        return a.income > b.income
    end)
    return pets
end

local function petPlacementPosition(index)
    local _, root = getCharacterParts()
    if not root then
        return nil
    end
    local x = ((index - 1) % 3 - 1) * 4
    local z = math.floor((index - 1) / 3) * 4 + 8
    local position = (root.CFrame * CFrame.new(x, 0, -z)).Position
    local plot = getPlayerPlot()
    local baseplate = plot and plot:FindFirstChild("Baseplate")
    if not baseplate then
        return position
    end
    local localPosition = baseplate.CFrame:PointToObjectSpace(position)
    local xLimit = baseplate.Size.X / 2 - 2
    local zLimit = baseplate.Size.Z / 2 - 2
    return baseplate.CFrame:PointToWorldSpace(Vector3.new(math.clamp(localPosition.X, -xLimit, xLimit), localPosition.Y, math.clamp(localPosition.Z, -zLimit, zLimit)))
end

local function placeBestPets()
    local requiredPet = getRequiredPet()
    local ownedPets = getOwnedPets(requiredPet)
    local capacity = tonumber(player:GetAttribute("MaxPets")) or 5
    local desired = {}
    for index = 1, math.min(capacity, #ownedPets) do
        desired[ownedPets[index].key] = true
    end
    for _, pet in ipairs(ownedPets) do
        if pet.placed and not desired[pet.key] then
            pickupPetRemote:FireServer(pet.key)
            task.wait(0.2)
        end
    end
    for index = 1, math.min(capacity, #ownedPets) do
        local pet = ownedPets[index]
        if not pet.placed then
            local tool = pet.tool or findPetTool(pet.key)
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local position = petPlacementPosition(index)
            if tool and humanoid and position then
                humanoid:EquipTool(tool)
                local deadline = os.clock() + 2
                while tool.Parent ~= character and os.clock() < deadline do
                    task.wait()
                end
                if tool.Parent == character then
                    placePetRemote:FireServer(pet.key, position)
                    task.wait(0.2)
                end
            end
        end
    end
end

local function attemptRebirth(rebirthCount)
    setStatus("Rebirthing")
    rebirthRemote:FireServer()
    local started = os.clock()
    while isAlive() and os.clock() - started < 5 do
        if rebirthValue.Value ~= rebirthCount then
            setStatus("Checking Rebirth")
            return
        end
        task.wait(0.1)
    end
end

hatchRemote.OnClientEvent:Connect(function()
    kaitun.petPlacementPending = true
end)

print("[*] Xyrax Kaitun started. Reset character to stop.")

task.spawn(function()
    while isAlive() do
        refreshUI()

        if kaitun.carriedEgg then
            finishCarriedEgg()
            task.wait(LOOP_INTERVAL)
            continue
        end

        local placedEgg, eggKey = getPlacedEgg()
        if placedEgg and eggKey then
            if hatchPlacedEgg(placedEgg, eggKey) then
                task.wait(LOOP_INTERVAL)
                continue
            end
        end

        if kaitun.petPlacementPending then
            setStatus("Placing Best Pet")
            placeBestPets()
            kaitun.petPlacementPending = false
            task.wait(LOOP_INTERVAL)
            continue
        end

        local requiredPet, targetEgg, cost, owned, rebirthCount = getRebirthState()
        if requiredPet then
            if not owned then
                kaitun.targetEgg = targetEgg
                kaitun.targetLuck = targetEgg and Eggs[targetEgg] and Eggs[targetEgg].Luck or 0
                local egg = findTargetEgg(targetEgg)
                if egg then
                    if canStartEggTransaction() then
                        collectEgg(egg, true)
                    end
                else
                    upgradeHatchLuck()
                    if canStartEggTransaction() then
                        local bestEgg = findTargetEgg()
                        if bestEgg then
                            collectEgg(bestEgg, false)
                        else
                            setStatus("Waiting For Egg")
                        end
                    else
                        kaitun.targetEgg = targetEgg
                        kaitun.targetLuck = targetEgg and Eggs[targetEgg] and Eggs[targetEgg].Luck or 0
                    end
                end
                task.wait(LOOP_INTERVAL)
                continue
            end

            if cashValue.Value < cost then
                setStatus("Saving For Rebirth")
                task.wait(LOOP_INTERVAL)
                continue
            end

            setStatus("Ready To Rebirth")
            attemptRebirth(rebirthCount)
            task.wait(LOOP_INTERVAL)
            continue
        end

        if canStartEggTransaction() then
            local bestEgg = findTargetEgg()
            if bestEgg then
                collectEgg(bestEgg, false)
            else
                setStatus("Waiting For Egg")
            end
        else
            kaitun.targetEgg = nil
            kaitun.targetLuck = 0
        end
        task.wait(LOOP_INTERVAL)
    end
    stopMovement()
    setStatus("Idle")
    print("[!] Character reset or died. Kaitun stopped.")
end)
