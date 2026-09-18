local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local shared = getgenv and getgenv() or _G
if not shared.RideAPetAntiAfkConnection or not shared.RideAPetAntiAfkConnection.Connected then
    shared.RideAPetAntiAfkConnection = player.Idled:Connect(function()
        if shared.RideAPetAntiAfkEnabled ~= false then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end
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
local PET_CHECK_INTERVAL = 8
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
    nextLuckUpgrade = 0,
    enabled = true,
    eggFarmEnabled = true,
    upgradeLuckEnabled = true,
    rebirthEnabled = true,
    placePetsEnabled = true,
    nextPetCheck = 0
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

-- ==============================================================================
--                       XYRAX HUB - EXECUTIVE macOS EDITION (V3.4.1)
--    Full Library Engine + Complete Component Test Suite (All-In-One Script)
-- ==============================================================================

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local UIModule = {}
UIModule.__index = UIModule

-- // DESIGN SYSTEM & PALETTE //
local THEME = {
    WindowBg      = Color3.fromRGB(13, 13, 16),
    SidebarBg     = Color3.fromRGB(18, 18, 23),
    HeaderBg      = Color3.fromRGB(18, 18, 23),
    CardBg        = Color3.fromRGB(22, 22, 28),
    CardHoverBg   = Color3.fromRGB(26, 26, 34),
    ItemBg        = Color3.fromRGB(28, 28, 36),
    ItemHoverBg   = Color3.fromRGB(35, 35, 46),
    ItemPressBg   = Color3.fromRGB(42, 42, 56),
    BorderSubtle  = Color3.fromRGB(40, 40, 52),
    BorderFocus   = Color3.fromRGB(75, 75, 96),
    Accent        = Color3.fromRGB(255, 255, 255),
    AccentMuted   = Color3.fromRGB(180, 180, 195),
    
    -- Premium Gold Theme for Subtitle
    Gold          = Color3.fromRGB(255, 204, 50),
    GoldBg        = Color3.fromRGB(36, 30, 16),
    GoldBorder    = Color3.fromRGB(120, 95, 30),
    
    TextPrimary   = Color3.fromRGB(245, 245, 250),
    TextSecondary = Color3.fromRGB(145, 145, 160),
    TextMuted     = Color3.fromRGB(95, 95, 110),
    
    -- Traffic Light Buttons (macOS)
    CloseRed      = Color3.fromRGB(255, 95, 87),
    MinYellow     = Color3.fromRGB(254, 188, 46),
    MaxGreen      = Color3.fromRGB(40, 200, 64),
    
    -- Rounded Radius Guidelines
    RadiusWindow  = UDim.new(0, 16),
    RadiusCard    = UDim.new(0, 12),
    RadiusItem    = UDim.new(0, 9),
    RadiusPill    = UDim.new(1, 0),
    RadiusSmall   = UDim.new(0, 7),
}

-- Fallback high-res Lucide icons
local FallbackIcons = {
    swords    = "rbxassetid://81872698913435",
    shield    = "rbxassetid://110786993356448",
    zap       = "rbxassetid://10709791437",
    crosshair = "rbxassetid://10709789810",
    flame     = "rbxassetid://10709790202",
    target    = "rbxassetid://10709791130",
    sparkles  = "rbxassetid://10709790832",
    skull     = "rbxassetid://10709790697",
    eye       = "rbxassetid://10709790100",
    info      = "rbxassetid://10709790369",
    search    = "rbxassetid://10709790948",
    settings  = "rbxassetid://10709791053",
    sliders   = "rbxassetid://10709791053",
    bell      = "rbxassetid://10709789960",
    check     = "rbxassetid://93898873302694",
    x         = "rbxassetid://110786993356448",
    chevron   = "rbxassetid://10709790184",
    code      = "rbxassetid://10709789908",
    layers    = "rbxassetid://10709790462",
    maximize  = "rbxassetid://10709790558",
}

local function GetIcon(name)
    if not name or name == "" then return "" end
    if type(name) == "number" or tonumber(name) then
        return "rbxassetid://" .. tostring(name)
    end
    if string.sub(name, 1, 13) == "rbxassetid://" then
        return name
    end

    local cleanName = string.lower(tostring(name)):gsub("^lucide%-", "")
    
    if FallbackIcons[cleanName] then
        return FallbackIcons[cleanName]
    end

    local success, icons = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/Icons/main/WindUI/Icons.luau"))()
    end)
    
    if success and type(icons) == "table" and icons[cleanName] then
        local val = icons[cleanName]
        if type(val) == "string" then
            if string.sub(val, 1, 13) == "rbxassetid://" then
                return val
            elseif tonumber(val) then
                return "rbxassetid://" .. val
            end
        elseif type(val) == "number" then
            return "rbxassetid://" .. tostring(val)
        elseif type(val) == "table" and val.id then
            return "rbxassetid://" .. tostring(val.id)
        end
    end
    
    return FallbackIcons["layers"]
end

local function Tween(instance, info, properties)
    local tw = TweenService:Create(instance, info, properties)
    tw:Play()
    return tw
end

local function ResolveParent(parent)
    if typeof(parent) == "Instance" then
        return parent
    elseif type(parent) == "table" then
        return parent.Container or parent.Instance or parent[1] or parent
    end
    return parent
end

-- ==============================================================================
--                               MAIN WINDOW
-- ==============================================================================
function UIModule.new(cfg)
    cfg = cfg or {}
    local self = setmetatable({}, UIModule)

    self.TitleText    = cfg.Title or "Xyrax Hub"
    self.SubtitleText = cfg.Subtitle or "Premium Script"
    self.WindowSize   = cfg.Size or UDim2.new(0, 800, 0, 500)
    self.ToggleKey    = cfg.ToggleKey or Enum.KeyCode.RightControl
    self.Accent       = cfg.AccentColor or THEME.Accent
    self.Tabs         = {}
    self.CurrentTab   = nil

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "XyraxHub_" .. tostring(math.random(1000, 9999))
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    pcall(function()
        screenGui.Parent = CoreGui
    end)
    if not screenGui.Parent then
        screenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    end
    self.ScreenGui = screenGui

    local shadowFrame = Instance.new("Frame")
    shadowFrame.Name = "ShadowFrame"
    shadowFrame.Size = self.WindowSize + UDim2.new(0, 16, 0, 16)
    shadowFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    shadowFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    shadowFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shadowFrame.BackgroundTransparency = 0.65
    shadowFrame.BorderSizePixel = 0
    shadowFrame.Parent = screenGui

    local shadowCorner = Instance.new("UICorner")
    shadowCorner.CornerRadius = UDim.new(0, 20)
    shadowCorner.Parent = shadowFrame

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = self.WindowSize
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.BackgroundColor3 = THEME.WindowBg
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = screenGui
    self.MainFrame = mainFrame

    mainFrame:GetPropertyChangedSignal("Position"):Connect(function()
        shadowFrame.Position = mainFrame.Position
    end)

    local windowCorner = Instance.new("UICorner")
    windowCorner.CornerRadius = THEME.RadiusWindow
    windowCorner.Parent = mainFrame

    local windowStroke = Instance.new("UIStroke")
    windowStroke.Color = THEME.BorderSubtle
    windowStroke.Thickness = 1
    windowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    windowStroke.Parent = mainFrame

    local header = Instance.new("Frame")
    header.Name = "HeaderBar"
    header.Size = UDim2.new(1, 0, 0, 48)
    header.BackgroundColor3 = THEME.HeaderBg
    header.BorderSizePixel = 0
    header.Parent = mainFrame

    local headerBorder = Instance.new("Frame")
    headerBorder.Name = "HeaderBorder"
    headerBorder.Size = UDim2.new(1, 0, 0, 1)
    headerBorder.Position = UDim2.new(0, 0, 1, -1)
    headerBorder.BackgroundColor3 = THEME.BorderSubtle
    headerBorder.BorderSizePixel = 0
    headerBorder.Parent = header

    local trafficContainer = Instance.new("Frame")
    trafficContainer.Name = "TrafficLights"
    trafficContainer.Size = UDim2.new(0, 70, 1, 0)
    trafficContainer.Position = UDim2.new(0, 16, 0, 0)
    trafficContainer.BackgroundTransparency = 1
    trafficContainer.Parent = header

    local trafficLayout = Instance.new("UIListLayout")
    trafficLayout.FillDirection = Enum.FillDirection.Horizontal
    trafficLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    trafficLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    trafficLayout.Padding = UDim.new(0, 8)
    trafficLayout.Parent = trafficContainer

    local function CreateTrafficButton(name, color, callback)
        local btn = Instance.new("TextButton")
        btn.Name = name
        btn.Size = UDim2.new(0, 12, 0, 12)
        btn.BackgroundColor3 = color
        btn.Text = ""
        btn.AutoButtonColor = false
        btn.BorderSizePixel = 0
        btn.Parent = trafficContainer

        local corner = Instance.new("UICorner")
        corner.CornerRadius = THEME.RadiusPill
        corner.Parent = btn

        local stroke = Instance.new("UIStroke")
        stroke.Color = color:Lerp(Color3.fromRGB(0, 0, 0), 0.2)
        stroke.Thickness = 1
        stroke.Parent = btn

        btn.MouseEnter:Connect(function()
            Tween(btn, TweenInfo.new(0.15), { BackgroundColor3 = color:Lerp(Color3.fromRGB(255, 255, 255), 0.25) })
        end)
        btn.MouseLeave:Connect(function()
            Tween(btn, TweenInfo.new(0.15), { BackgroundColor3 = color })
        end)
        btn.MouseButton1Click:Connect(callback)
        return btn
    end

    CreateTrafficButton("CloseBtn", THEME.CloseRed, function()
        self:Destroy()
    end)

    local isMinimized = false
    CreateTrafficButton("MinBtn", THEME.MinYellow, function()
        isMinimized = not isMinimized
        if isMinimized then
            Tween(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Size = UDim2.new(self.WindowSize.X.Scale, self.WindowSize.X.Offset, 0, 48)
            })
            Tween(shadowFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Size = UDim2.new(self.WindowSize.X.Scale, self.WindowSize.X.Offset + 16, 0, 48 + 16)
            })
        else
            Tween(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Size = self.WindowSize
            })
            Tween(shadowFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Size = self.WindowSize + UDim2.new(0, 16, 0, 16)
            })
        end
    end)

    CreateTrafficButton("MaxBtn", THEME.MaxGreen, function()
        task.spawn(function()
            Tween(mainFrame, TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
                Position = mainFrame.Position + UDim2.new(0, 0, 0, -4)
            })
            task.wait(0.1)
            Tween(mainFrame, TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
                Position = mainFrame.Position
            })
        end)
    end)

    local titleContainer = Instance.new("Frame")
    titleContainer.Name = "TitleContainer"
    titleContainer.Size = UDim2.new(0, 320, 1, 0)
    titleContainer.Position = UDim2.new(0, 95, 0, 0)
    titleContainer.BackgroundTransparency = 1
    titleContainer.Parent = header

    local titleList = Instance.new("UIListLayout")
    titleList.FillDirection = Enum.FillDirection.Horizontal
    titleList.VerticalAlignment = Enum.VerticalAlignment.Center
    titleList.Padding = UDim.new(0, 9)
    titleList.Parent = titleContainer

    local mainTitle = Instance.new("TextLabel")
    mainTitle.Name = "MainTitle"
    mainTitle.Size = UDim2.new(0, 0, 1, 0)
    mainTitle.AutomaticSize = Enum.AutomaticSize.X
    mainTitle.BackgroundTransparency = 1
    mainTitle.Text = self.TitleText
    mainTitle.Font = Enum.Font.GothamBold
    mainTitle.TextSize = 14
    mainTitle.TextColor3 = THEME.TextPrimary
    mainTitle.TextXAlignment = Enum.TextXAlignment.Left
    mainTitle.Parent = titleContainer

    local subPill = Instance.new("Frame")
    subPill.Name = "SubPill"
    subPill.Size = UDim2.new(0, 0, 0, 22)
    subPill.AutomaticSize = Enum.AutomaticSize.X
    subPill.BackgroundColor3 = THEME.GoldBg
    subPill.BorderSizePixel = 0
    subPill.Parent = titleContainer

    local subPillCorner = Instance.new("UICorner")
    subPillCorner.CornerRadius = THEME.RadiusPill
    subPillCorner.Parent = subPill

    local subPillStroke = Instance.new("UIStroke")
    subPillStroke.Color = THEME.GoldBorder
    subPillStroke.Thickness = 1
    subPillStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    subPillStroke.Parent = subPill

    local subPillPad = Instance.new("UIPadding")
    subPillPad.PaddingLeft = UDim.new(0, 9)
    subPillPad.PaddingRight = UDim.new(0, 9)
    subPillPad.Parent = subPill

    local subTitle = Instance.new("TextLabel")
    subTitle.Name = "SubTitle"
    subTitle.Size = UDim2.new(0, 0, 1, 0)
    subTitle.AutomaticSize = Enum.AutomaticSize.X
    subTitle.BackgroundTransparency = 1
    subTitle.Text = self.SubtitleText
    subTitle.Font = Enum.Font.GothamBold
    subTitle.TextSize = 11
    subTitle.TextColor3 = THEME.Gold
    subTitle.Parent = subPill

    local statusPill = Instance.new("Frame")
    statusPill.Name = "StatusPill"
    statusPill.Size = UDim2.new(0, 150, 0, 26)
    statusPill.Position = UDim2.new(1, -16, 0.5, 0)
    statusPill.AnchorPoint = Vector2.new(1, 0.5)
    statusPill.BackgroundColor3 = THEME.ItemBg
    statusPill.BorderSizePixel = 0
    statusPill.Parent = header

    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = THEME.RadiusPill
    statusCorner.Parent = statusPill

    local statusStroke = Instance.new("UIStroke")
    statusStroke.Color = THEME.BorderSubtle
    statusStroke.Thickness = 1
    statusStroke.Parent = statusPill

    local statusText = Instance.new("TextLabel")
    statusText.Name = "StatusLabel"
    statusText.Size = UDim2.new(1, 0, 1, 0)
    statusText.BackgroundTransparency = 1
    statusText.Text = "60 FPS | 45ms"
    statusText.Font = Enum.Font.GothamMedium
    statusText.TextSize = 11
    statusText.TextColor3 = THEME.TextSecondary
    statusText.Parent = statusPill

    task.spawn(function()
        local lastTime = tick()
        local frames = 0
        local conn
        conn = RunService.RenderStepped:Connect(function()
            frames = frames + 1
            local now = tick()
            if now - lastTime >= 1 then
                local fps = math.floor(frames / (now - lastTime))
                frames = 0
                lastTime = now
                local ping = 50
                pcall(function()
                    ping = math.floor(game:GetService("Players").LocalPlayer:GetNetworkPing() * 1000)
                end)
                if statusText and statusText.Parent then
                    statusText.Text = string.format("%d FPS | %dms", fps, ping)
                else
                    conn:Disconnect()
                end
            end
        end)
    end)

    local dragging, dragStart, startPos
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and not self.DisableToggleKey and input.KeyCode == self.ToggleKey then
            mainFrame.Visible = not mainFrame.Visible
            shadowFrame.Visible = mainFrame.Visible
        end
    end)

    local sidebar = Instance.new("Frame")
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.new(0, 190, 1, -48)
    sidebar.Position = UDim2.new(0, 0, 0, 48)
    sidebar.BackgroundColor3 = THEME.SidebarBg
    sidebar.BorderSizePixel = 0
    sidebar.Parent = mainFrame

    local sidebarBorder = Instance.new("Frame")
    sidebarBorder.Name = "SidebarBorder"
    sidebarBorder.Size = UDim2.new(0, 1, 1, 0)
    sidebarBorder.Position = UDim2.new(1, -1, 0, 0)
    sidebarBorder.BackgroundColor3 = THEME.BorderSubtle
    sidebarBorder.BorderSizePixel = 0
    sidebarBorder.Parent = sidebar

    local tabList = Instance.new("ScrollingFrame")
    tabList.Name = "TabList"
    tabList.Size = UDim2.new(1, 0, 1, -16)
    tabList.Position = UDim2.new(0, 0, 0, 8)
    tabList.BackgroundTransparency = 1
    tabList.ScrollBarThickness = 2
    tabList.ScrollBarImageColor3 = THEME.BorderSubtle
    tabList.CanvasSize = UDim2.new(0, 0, 0, 0)
    tabList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    tabList.Parent = sidebar

    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Vertical
    tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabLayout.Padding = UDim.new(0, 4)
    tabLayout.Parent = tabList

    local tabPad = Instance.new("UIPadding")
    tabPad.PaddingLeft = UDim.new(0, 10)
    tabPad.PaddingRight = UDim.new(0, 10)
    tabPad.PaddingTop = UDim.new(0, 6)
    tabPad.PaddingBottom = UDim.new(0, 6)
    tabPad.Parent = tabList
    self.TabList = tabList

    local contentArea = Instance.new("Frame")
    contentArea.Name = "ContentArea"
    contentArea.Size = UDim2.new(1, -190, 1, -48)
    contentArea.Position = UDim2.new(0, 190, 0, 48)
    contentArea.BackgroundTransparency = 1
    contentArea.Parent = mainFrame
    self.ContentArea = contentArea

    return self
end

-- ==============================================================================
--                               NOTIFICATIONS
-- ==============================================================================
function UIModule:Notify(opts)
    opts = opts or {}
    local title = opts.Title or "Notification"
    local desc = opts.Content or opts.Description or ""
    local dur = opts.Duration or 3.5

    local notifContainer = self.ScreenGui:FindFirstChild("NotificationContainer")
    if not notifContainer then
        notifContainer = Instance.new("Frame")
        notifContainer.Name = "NotificationContainer"
        notifContainer.Size = UDim2.new(0, 300, 1, -30)
        notifContainer.Position = UDim2.new(1, -20, 0, 15)
        notifContainer.AnchorPoint = Vector2.new(1, 0)
        notifContainer.BackgroundTransparency = 1
        notifContainer.ZIndex = 1000
        notifContainer.Parent = self.ScreenGui

        local nl = Instance.new("UIListLayout")
        nl.FillDirection = Enum.FillDirection.Vertical
        nl.VerticalAlignment = Enum.VerticalAlignment.Bottom
        nl.HorizontalAlignment = Enum.HorizontalAlignment.Right
        nl.Padding = UDim.new(0, 10)
        nl.Parent = notifContainer
    end

    local notifCard = Instance.new("Frame")
    notifCard.Name = "NotifCard"
    notifCard.Size = UDim2.new(1, 0, 0, 64)
    notifCard.BackgroundColor3 = THEME.CardBg
    notifCard.BorderSizePixel = 0
    notifCard.Position = UDim2.new(1, 40, 0, 0)
    notifCard.ZIndex = 1001
    notifCard.Parent = notifContainer

    local notifCorner = Instance.new("UICorner")
    notifCorner.CornerRadius = THEME.RadiusCard
    notifCorner.Parent = notifCard

    local notifStroke = Instance.new("UIStroke")
    notifStroke.Color = THEME.BorderFocus
    notifStroke.Thickness = 1
    notifStroke.Parent = notifCard

    local notifPad = Instance.new("UIPadding")
    notifPad.PaddingLeft = UDim.new(0, 14)
    notifPad.PaddingRight = UDim.new(0, 14)
    notifPad.PaddingTop = UDim.new(0, 10)
    notifPad.PaddingBottom = UDim.new(0, 10)
    notifPad.Parent = notifCard

    local nLayout = Instance.new("UIListLayout")
    nLayout.FillDirection = Enum.FillDirection.Vertical
    nLayout.Padding = UDim.new(0, 3)
    nLayout.Parent = notifCard

    local nTitle = Instance.new("TextLabel")
    nTitle.Name = "Title"
    nTitle.Size = UDim2.new(1, 0, 0, 18)
    nTitle.BackgroundTransparency = 1
    nTitle.Text = title
    nTitle.Font = Enum.Font.GothamBold
    nTitle.TextSize = 13
    nTitle.TextColor3 = THEME.TextPrimary
    nTitle.TextXAlignment = Enum.TextXAlignment.Left
    nTitle.Parent = notifCard

    local nDesc = Instance.new("TextLabel")
    nDesc.Name = "Desc"
    nDesc.Size = UDim2.new(1, 0, 0, 24)
    nDesc.BackgroundTransparency = 1
    nDesc.Text = desc
    nDesc.Font = Enum.Font.GothamMedium
    nDesc.TextSize = 11
    nDesc.TextColor3 = THEME.TextSecondary
    nDesc.TextWrapped = true
    nDesc.TextXAlignment = Enum.TextXAlignment.Left
    nDesc.Parent = notifCard

    notifCard.Position = UDim2.new(0, 100, 0, 0)
    notifCard.BackgroundTransparency = 1
    nTitle.TextTransparency = 1
    nDesc.TextTransparency = 1
    Tween(notifCard, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0,
        Position = UDim2.new(0, 0, 0, 0)
    })
    Tween(nTitle, TweenInfo.new(0.3), { TextTransparency = 0 })
    Tween(nDesc, TweenInfo.new(0.3), { TextTransparency = 0 })

    task.delay(dur, function()
        Tween(notifCard, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
            Position = UDim2.new(1, 40, 0, 0),
            BackgroundTransparency = 1
        })
        Tween(nTitle, TweenInfo.new(0.2), { TextTransparency = 1 })
        Tween(nDesc, TweenInfo.new(0.2), { TextTransparency = 1 })
        task.wait(0.25)
        notifCard:Destroy()
    end)
end

-- ==============================================================================
--                               CATEGORIES & TABS
-- ==============================================================================
function UIModule:CreateCategory(name)
    local header = Instance.new("Frame")
    header.Name = "Cat_" .. tostring(name)
    header.Size = UDim2.new(1, 0, 0, 24)
    header.BackgroundTransparency = 1
    header.Parent = self.TabList

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -8, 1, 0)
    label.Position = UDim2.new(0, 6, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = string.upper(tostring(name))
    label.Font = Enum.Font.GothamBold
    label.TextSize = 10
    label.TextColor3 = THEME.TextMuted
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = header

    return header
end

function UIModule:CreateTab(name, iconName)
    local tab = {
        Window = self,
        Name = name,
        Icon = iconName,
        Sections = {},
        LeftCount = 0,
        RightCount = 0,
    }

    local page = Instance.new("ScrollingFrame")
    page.Name = "Page_" .. tostring(name)
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.ScrollBarThickness = 4
    page.ScrollBarImageColor3 = THEME.BorderSubtle
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.ClipsDescendants = false
    page.Visible = false
    page.Parent = self.ContentArea
    tab.Page = page

    local pagePad = Instance.new("UIPadding")
    pagePad.PaddingLeft = UDim.new(0, 14)
    pagePad.PaddingRight = UDim.new(0, 14)
    pagePad.PaddingTop = UDim.new(0, 14)
    pagePad.PaddingBottom = UDim.new(0, 14)
    pagePad.Parent = page

    local colContainer = Instance.new("Frame")
    colContainer.Name = "Columns"
    colContainer.Size = UDim2.new(1, 0, 0, 0)
    colContainer.AutomaticSize = Enum.AutomaticSize.Y
    colContainer.BackgroundTransparency = 1
    colContainer.ClipsDescendants = false
    colContainer.Parent = page

    local leftCol = Instance.new("Frame")
    leftCol.Name = "LeftColumn"
    leftCol.Size = UDim2.new(0.5, -7, 0, 0)
    leftCol.Position = UDim2.new(0, 0, 0, 0)
    leftCol.AutomaticSize = Enum.AutomaticSize.Y
    leftCol.BackgroundTransparency = 1
    leftCol.ClipsDescendants = false
    leftCol.Parent = colContainer

    local leftLayout = Instance.new("UIListLayout")
    leftLayout.FillDirection = Enum.FillDirection.Vertical
    leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
    leftLayout.Padding = UDim.new(0, 12)
    leftLayout.Parent = leftCol

    local rightCol = Instance.new("Frame")
    rightCol.Name = "RightColumn"
    rightCol.Size = UDim2.new(0.5, -7, 0, 0)
    rightCol.Position = UDim2.new(0.5, 7, 0, 0)
    rightCol.AutomaticSize = Enum.AutomaticSize.Y
    rightCol.BackgroundTransparency = 1
    rightCol.ClipsDescendants = false
    rightCol.Parent = colContainer

    local rightLayout = Instance.new("UIListLayout")
    rightLayout.FillDirection = Enum.FillDirection.Vertical
    rightLayout.SortOrder = Enum.SortOrder.LayoutOrder
    rightLayout.Padding = UDim.new(0, 12)
    rightLayout.Parent = rightCol

    tab.LeftColumn = leftCol
    tab.RightColumn = rightCol

    local tabBtn = Instance.new("TextButton")
    tabBtn.Name = "TabBtn_" .. tostring(name)
    tabBtn.Size = UDim2.new(1, 0, 0, 36)
    tabBtn.BackgroundColor3 = THEME.SidebarBg
    tabBtn.BorderSizePixel = 0
    tabBtn.Text = ""
    tabBtn.AutoButtonColor = false
    tabBtn.Parent = self.TabList

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = THEME.RadiusItem
    btnCorner.Parent = tabBtn

    local btnPad = Instance.new("UIPadding")
    btnPad.PaddingLeft = UDim.new(0, 12)
    btnPad.PaddingRight = UDim.new(0, 12)
    btnPad.Parent = tabBtn

    local btnLayout = Instance.new("UIListLayout")
    btnLayout.FillDirection = Enum.FillDirection.Horizontal
    btnLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    btnLayout.Padding = UDim.new(0, 10)
    btnLayout.Parent = tabBtn

    local iconImg = Instance.new("ImageLabel")
    iconImg.Name = "TabIcon"
    iconImg.Size = UDim2.new(0, 18, 0, 18)
    iconImg.BackgroundTransparency = 1
    iconImg.Image = GetIcon(iconName)
    iconImg.ImageColor3 = THEME.TextSecondary
    iconImg.Parent = tabBtn

    local tabTitle = Instance.new("TextLabel")
    tabTitle.Name = "TabTitle"
    tabTitle.Size = UDim2.new(1, -30, 1, 0)
    tabTitle.BackgroundTransparency = 1
    tabTitle.Text = name
    tabTitle.Font = Enum.Font.GothamMedium
    tabTitle.TextSize = 13
    tabTitle.TextColor3 = THEME.TextSecondary
    tabTitle.TextXAlignment = Enum.TextXAlignment.Left
    tabTitle.TextTruncate = Enum.TextTruncate.AtEnd
    tabTitle.Parent = tabBtn

    local activePill = Instance.new("Frame")
    activePill.Name = "ActivePill"
    activePill.Size = UDim2.new(0, 3, 0, 16)
    activePill.Position = UDim2.new(0, 2, 0.5, 0)
    activePill.AnchorPoint = Vector2.new(0, 0.5)
    activePill.BackgroundColor3 = THEME.Accent
    activePill.BorderSizePixel = 0
    activePill.Visible = false
    activePill.Parent = tabBtn

    local pillCorner = Instance.new("UICorner")
    pillCorner.CornerRadius = THEME.RadiusPill
    pillCorner.Parent = activePill

    local function SetActive(isActive)
        if isActive then
            Tween(tabBtn, TweenInfo.new(0.18), { BackgroundColor3 = THEME.ItemBg })
            Tween(iconImg, TweenInfo.new(0.18), { ImageColor3 = THEME.TextPrimary })
            Tween(tabTitle, TweenInfo.new(0.18), { TextColor3 = THEME.TextPrimary })
            tabTitle.Font = Enum.Font.GothamBold
            activePill.Visible = true
            page.Visible = true
        else
            Tween(tabBtn, TweenInfo.new(0.18), { BackgroundColor3 = THEME.SidebarBg })
            Tween(iconImg, TweenInfo.new(0.18), { ImageColor3 = THEME.TextSecondary })
            Tween(tabTitle, TweenInfo.new(0.18), { TextColor3 = THEME.TextSecondary })
            tabTitle.Font = Enum.Font.GothamMedium
            activePill.Visible = false
            page.Visible = false
        end
    end

    tabBtn.MouseButton1Click:Connect(function()
        if self.CurrentTab == tab then return end
        if self.CurrentTab then
            self.CurrentTab.SetActive(false)
        end
        self.CurrentTab = tab
        tab.SetActive(true)
    end)

    tabBtn.MouseEnter:Connect(function()
        if self.CurrentTab ~= tab then
            Tween(tabBtn, TweenInfo.new(0.15), { BackgroundColor3 = THEME.CardBg })
            Tween(tabTitle, TweenInfo.new(0.15), { TextColor3 = THEME.TextPrimary })
        end
    end)

    tabBtn.MouseLeave:Connect(function()
        if self.CurrentTab ~= tab then
            Tween(tabBtn, TweenInfo.new(0.15), { BackgroundColor3 = THEME.SidebarBg })
            Tween(tabTitle, TweenInfo.new(0.15), { TextColor3 = THEME.TextSecondary })
        end
    end)

    tab.SetActive = SetActive
    table.insert(self.Tabs, tab)

    if #self.Tabs == 1 then
        self.CurrentTab = tab
        tab.SetActive(true)
    end

    function tab:CreateSection(opts)
        return self.Window:CreateSection(self, opts)
    end

    return tab
end

-- ==============================================================================
--                               SECTIONS (BENTO CARDS)
-- ==============================================================================
function UIModule:CreateSection(tab, opts)
    opts = opts or {}
    local title = opts.Title or "Section"
    local subtitle = opts.Subtitle or ""
    local icon = opts.Icon
    local side = opts.Side

    local targetCol = tab.LeftColumn
    if side == "Right" then
        targetCol = tab.RightColumn
    elseif side == "Left" then
        targetCol = tab.LeftColumn
    else
        if tab.LeftCount > tab.RightCount then
            targetCol = tab.RightColumn
            tab.RightCount = tab.RightCount + 1
        else
            targetCol = tab.LeftColumn
            tab.LeftCount = tab.LeftCount + 1
        end
    end

    local card = Instance.new("Frame")
    card.Name = "Section_" .. title
    card.Size = UDim2.new(1, 0, 0, 0)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.BackgroundColor3 = THEME.CardBg
    card.BorderSizePixel = 0
    card.ClipsDescendants = false
    card.Parent = targetCol

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = THEME.RadiusCard
    cardCorner.Parent = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = THEME.BorderSubtle
    cardStroke.Thickness = 1
    cardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    cardStroke.Parent = card

    local cardPad = Instance.new("UIPadding")
    cardPad.PaddingLeft = UDim.new(0, 14)
    cardPad.PaddingRight = UDim.new(0, 14)
    cardPad.PaddingTop = UDim.new(0, 14)
    cardPad.PaddingBottom = UDim.new(0, 14)
    cardPad.Parent = card

    local cardLayout = Instance.new("UIListLayout")
    cardLayout.FillDirection = Enum.FillDirection.Vertical
    cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
    cardLayout.Padding = UDim.new(0, 10)
    cardLayout.Parent = card

    local headerFrame = Instance.new("Frame")
    headerFrame.Name = "Header"
    headerFrame.Size = UDim2.new(1, 0, 0, 0)
    headerFrame.AutomaticSize = Enum.AutomaticSize.Y
    headerFrame.BackgroundTransparency = 1
    headerFrame.Parent = card

    local titleStack = Instance.new("Frame")
    titleStack.Name = "TitleStack"
    titleStack.Size = UDim2.new(1, opts.Toggle and -54 or 0, 0, 0)
    titleStack.Position = UDim2.new(0, 0, 0, 0)
    titleStack.AutomaticSize = Enum.AutomaticSize.Y
    titleStack.BackgroundTransparency = 1
    titleStack.Parent = headerFrame

    local stackLayout = Instance.new("UIListLayout")
    stackLayout.FillDirection = Enum.FillDirection.Vertical
    stackLayout.SortOrder = Enum.SortOrder.LayoutOrder
    stackLayout.Padding = UDim.new(0, 2)
    stackLayout.Parent = titleStack

    local titleRow = Instance.new("Frame")
    titleRow.Name = "TitleRow"
    titleRow.Size = UDim2.new(1, 0, 0, 18)
    titleRow.BackgroundTransparency = 1
    titleRow.Parent = titleStack

    local trLayout = Instance.new("UIListLayout")
    trLayout.FillDirection = Enum.FillDirection.Horizontal
    trLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    trLayout.Padding = UDim.new(0, 6)
    trLayout.Parent = titleRow

    if icon then
        local secIcon = Instance.new("ImageLabel")
        secIcon.Name = "SecIcon"
        secIcon.Size = UDim2.new(0, 15, 0, 15)
        secIcon.BackgroundTransparency = 1
        secIcon.Image = GetIcon(icon)
        secIcon.ImageColor3 = THEME.TextSecondary
        secIcon.Parent = titleRow
    end

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Size = UDim2.new(1, icon and -21 or 0, 1, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 13
    titleLabel.TextColor3 = THEME.TextPrimary
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    titleLabel.Parent = titleRow

    if subtitle and subtitle ~= "" then
        local subLabel = Instance.new("TextLabel")
        subLabel.Name = "SubLabel"
        subLabel.Size = UDim2.new(1, 0, 0, 14)
        subLabel.BackgroundTransparency = 1
        subLabel.Text = subtitle
        subLabel.Font = Enum.Font.GothamMedium
        subLabel.TextSize = 11
        subLabel.TextColor3 = THEME.TextSecondary
        subLabel.TextXAlignment = Enum.TextXAlignment.Left
        subLabel.TextTruncate = Enum.TextTruncate.AtEnd
        subLabel.Parent = titleStack
    end

    if opts.Toggle then
        local isToggled = opts.ToggleDefault or false
        local callback = opts.ToggleCallback or function() end

        local togglePill = Instance.new("TextButton")
        togglePill.Name = "SectionToggle"
        togglePill.Size = UDim2.new(0, 44, 0, 22)
        togglePill.Position = UDim2.new(1, 0, 0.5, 0)
        togglePill.AnchorPoint = Vector2.new(1, 0.5)
        togglePill.BackgroundColor3 = isToggled and THEME.Accent or THEME.ItemBg
        togglePill.BorderSizePixel = 0
        togglePill.Text = ""
        togglePill.AutoButtonColor = false
        togglePill.Parent = headerFrame

        local tpCorner = Instance.new("UICorner")
        tpCorner.CornerRadius = THEME.RadiusPill
        tpCorner.Parent = togglePill

        local tpStroke = Instance.new("UIStroke")
        tpStroke.Color = THEME.BorderSubtle
        tpStroke.Thickness = 1
        tpStroke.Parent = togglePill

        local knob = Instance.new("Frame")
        knob.Name = "Knob"
        knob.Size = UDim2.new(0, 16, 0, 16)
        knob.Position = isToggled and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
        knob.AnchorPoint = Vector2.new(0, 0.5)
        knob.BackgroundColor3 = isToggled and Color3.fromRGB(15, 15, 20) or THEME.TextSecondary
        knob.BorderSizePixel = 0
        knob.Parent = togglePill

        local knobCorner = Instance.new("UICorner")
        knobCorner.CornerRadius = THEME.RadiusPill
        knobCorner.Parent = knob

        togglePill.MouseButton1Click:Connect(function()
            isToggled = not isToggled
            local targetPos = isToggled and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
            local targetBg = isToggled and THEME.Accent or THEME.ItemBg
            local targetKnobBg = isToggled and Color3.fromRGB(15, 15, 20) or THEME.TextSecondary

            Tween(knob, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Position = targetPos,
                BackgroundColor3 = targetKnobBg
            })
            Tween(togglePill, TweenInfo.new(0.2), { BackgroundColor3 = targetBg })
            pcall(callback, isToggled)
        end)
    end

    local sep = Instance.new("Frame")
    sep.Name = "Separator"
    sep.Size = UDim2.new(1, 0, 0, 1)
    sep.BackgroundColor3 = THEME.BorderSubtle
    sep.BorderSizePixel = 0
    sep.Parent = card

    local container = Instance.new("Frame")
    container.Name = "ItemContainer"
    container.Size = UDim2.new(1, 0, 0, 0)
    container.AutomaticSize = Enum.AutomaticSize.Y
    container.BackgroundTransparency = 1
    container.ClipsDescendants = false
    container.Parent = card

    local itemLayout = Instance.new("UIListLayout")
    itemLayout.FillDirection = Enum.FillDirection.Vertical
    itemLayout.SortOrder = Enum.SortOrder.LayoutOrder
    itemLayout.Padding = UDim.new(0, 8)
    itemLayout.Parent = container

    local window = self
    local sectionObj = {
        Card = card,
        Container = container,
        Window = window,
    }
    
    setmetatable(sectionObj, {
        __index = function(t, k)
            if UIModule[k] then
                return function(_, ...)
                    return UIModule[k](window, container, ...)
                end
            end
            return container[k]
        end
    })

    return sectionObj
end

-- ==============================================================================
--                               WIDGET: BUTTON
-- ==============================================================================
function UIModule:CreateButton(parent, opts)
    parent = ResolveParent(parent)
    opts = opts or {}
    local title = opts.Title or "Button"
    local desc = opts.Description
    local iconName = opts.Icon
    local callback = opts.Callback or function() end

    local hasDesc = desc and desc ~= ""
    local btnHeight = hasDesc and 50 or 38

    local btn = Instance.new("TextButton")
    btn.Name = "Button_" .. title
    btn.Size = UDim2.new(1, 0, 0, btnHeight)
    btn.BackgroundColor3 = THEME.ItemBg
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.ClipsDescendants = true
    btn.Parent = parent

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = THEME.RadiusItem
    btnCorner.Parent = btn

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color = THEME.BorderSubtle
    btnStroke.Thickness = 1
    btnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    btnStroke.Parent = btn

    local btnPad = Instance.new("UIPadding")
    btnPad.PaddingLeft = UDim.new(0, 12)
    btnPad.PaddingRight = UDim.new(0, 12)
    btnPad.Parent = btn

    local leftOffset = 0
    if iconName then
        leftOffset = 26
        local icon = Instance.new("ImageLabel")
        icon.Name = "BtnIcon"
        icon.Size = UDim2.new(0, 16, 0, 16)
        icon.Position = UDim2.new(0, 0, 0.5, 0)
        icon.AnchorPoint = Vector2.new(0, 0.5)
        icon.BackgroundTransparency = 1
        icon.Image = GetIcon(iconName)
        icon.ImageColor3 = THEME.TextPrimary
        icon.Parent = btn
    end

    local textContainer = Instance.new("Frame")
    textContainer.Name = "TextContainer"
    textContainer.Size = UDim2.new(1, -leftOffset - 24, 1, 0)
    textContainer.Position = UDim2.new(0, leftOffset, 0, 0)
    textContainer.BackgroundTransparency = 1
    textContainer.ClipsDescendants = true
    textContainer.Parent = btn

    local textLayout = Instance.new("UIListLayout")
    textLayout.FillDirection = Enum.FillDirection.Vertical
    textLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    textLayout.SortOrder = Enum.SortOrder.LayoutOrder
    textLayout.Padding = UDim.new(0, 2)
    textLayout.Parent = textContainer

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Size = UDim2.new(1, 0, 0, 16)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 12
    titleLabel.TextColor3 = THEME.TextPrimary
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    titleLabel.Parent = textContainer

    if hasDesc then
        local descLabel = Instance.new("TextLabel")
        descLabel.Name = "DescLabel"
        descLabel.Size = UDim2.new(1, 0, 0, 14)
        descLabel.BackgroundTransparency = 1
        descLabel.Text = desc
        descLabel.Font = Enum.Font.GothamMedium
        descLabel.TextSize = 10
        descLabel.TextColor3 = THEME.TextSecondary
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.TextTruncate = Enum.TextTruncate.AtEnd
        descLabel.Parent = textContainer
    end

    local rightArrow = Instance.new("ImageLabel")
    rightArrow.Name = "RightArrow"
    rightArrow.Size = UDim2.new(0, 14, 0, 14)
    rightArrow.Position = UDim2.new(1, 0, 0.5, 0)
    rightArrow.AnchorPoint = Vector2.new(1, 0.5)
    rightArrow.BackgroundTransparency = 1
    rightArrow.Image = FallbackIcons["chevron"]
    rightArrow.ImageColor3 = THEME.TextMuted
    rightArrow.Rotation = -90
    rightArrow.Parent = btn

    btn.MouseEnter:Connect(function()
        Tween(btn, TweenInfo.new(0.15), { BackgroundColor3 = THEME.ItemHoverBg })
        Tween(btnStroke, TweenInfo.new(0.15), { Color = THEME.BorderFocus })
        Tween(rightArrow, TweenInfo.new(0.15), { ImageColor3 = THEME.TextPrimary })
    end)

    btn.MouseLeave:Connect(function()
        Tween(btn, TweenInfo.new(0.15), { BackgroundColor3 = THEME.ItemBg })
        Tween(btnStroke, TweenInfo.new(0.15), { Color = THEME.BorderSubtle })
        Tween(rightArrow, TweenInfo.new(0.15), { ImageColor3 = THEME.TextMuted })
    end)

    btn.MouseButton1Down:Connect(function()
        Tween(btn, TweenInfo.new(0.08), { BackgroundColor3 = THEME.ItemPressBg })
    end)

    btn.MouseButton1Up:Connect(function()
        Tween(btn, TweenInfo.new(0.12), { BackgroundColor3 = THEME.ItemHoverBg })
    end)

    btn.MouseButton1Click:Connect(function()
        pcall(callback)
    end)

    return btn
end

-- ==============================================================================
--                               WIDGET: TOGGLE
-- ==============================================================================
function UIModule:CreateToggle(parent, opts)
    parent = ResolveParent(parent)
    opts = opts or {}
    local title = opts.Title or "Toggle"
    local desc = opts.Description
    local state = opts.Default or false
    local callback = opts.Callback or function() end

    local hasDesc = desc and desc ~= ""
    local toggleHeight = hasDesc and 48 or 38

    local row = Instance.new("TextButton")
    row.Name = "Toggle_" .. title
    row.Size = UDim2.new(1, 0, 0, toggleHeight)
    row.BackgroundColor3 = THEME.ItemBg
    row.BorderSizePixel = 0
    row.Text = ""
    row.AutoButtonColor = false
    row.ClipsDescendants = true
    row.Parent = parent

    local rowCorner = Instance.new("UICorner")
    rowCorner.CornerRadius = THEME.RadiusItem
    rowCorner.Parent = row

    local rowStroke = Instance.new("UIStroke")
    rowStroke.Color = THEME.BorderSubtle
    rowStroke.Thickness = 1
    rowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    rowStroke.Parent = row

    local rowPad = Instance.new("UIPadding")
    rowPad.PaddingLeft = UDim.new(0, 12)
    rowPad.PaddingRight = UDim.new(0, 12)
    rowPad.Parent = row

    local textContainer = Instance.new("Frame")
    textContainer.Name = "TextContainer"
    textContainer.Size = UDim2.new(1, -60, 1, 0)
    textContainer.Position = UDim2.new(0, 0, 0, 0)
    textContainer.BackgroundTransparency = 1
    textContainer.ClipsDescendants = true
    textContainer.Parent = row

    local textLayout = Instance.new("UIListLayout")
    textLayout.FillDirection = Enum.FillDirection.Vertical
    textLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    textLayout.SortOrder = Enum.SortOrder.LayoutOrder
    textLayout.Padding = UDim.new(0, 2)
    textLayout.Parent = textContainer

    local label = Instance.new("TextLabel")
    label.Name = "TitleLabel"
    label.Size = UDim2.new(1, 0, 0, 16)
    label.BackgroundTransparency = 1
    label.Text = title
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 12
    label.TextColor3 = THEME.TextPrimary
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.Parent = textContainer

    if hasDesc then
        local descLabel = Instance.new("TextLabel")
        descLabel.Name = "DescLabel"
        descLabel.Size = UDim2.new(1, 0, 0, 14)
        descLabel.BackgroundTransparency = 1
        descLabel.Text = desc
        descLabel.Font = Enum.Font.GothamMedium
        descLabel.TextSize = 10
        descLabel.TextColor3 = THEME.TextSecondary
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.TextTruncate = Enum.TextTruncate.AtEnd
        descLabel.Parent = textContainer
    end

    local pill = Instance.new("Frame")
    pill.Name = "SwitchPill"
    pill.Size = UDim2.new(0, 42, 0, 22)
    pill.Position = UDim2.new(1, 0, 0.5, 0)
    pill.AnchorPoint = Vector2.new(1, 0.5)
    pill.BackgroundColor3 = state and THEME.Accent or THEME.CardBg
    pill.BorderSizePixel = 0
    pill.Parent = row

    local pillCorner = Instance.new("UICorner")
    pillCorner.CornerRadius = THEME.RadiusPill
    pillCorner.Parent = pill

    local pillStroke = Instance.new("UIStroke")
    pillStroke.Color = THEME.BorderSubtle
    pillStroke.Thickness = 1
    pillStroke.Parent = pill

    local knob = Instance.new("Frame")
    knob.Name = "Knob"
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = state and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
    knob.AnchorPoint = Vector2.new(0, 0.5)
    knob.BackgroundColor3 = state and Color3.fromRGB(15, 15, 20) or THEME.TextSecondary
    knob.BorderSizePixel = 0
    knob.Parent = pill

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = THEME.RadiusPill
    knobCorner.Parent = knob

    local function UpdateState(val)
        state = val
        local targetPos = state and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
        local targetBg = state and THEME.Accent or THEME.CardBg
        local targetKnob = state and Color3.fromRGB(15, 15, 20) or THEME.TextSecondary

        Tween(knob, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Position = targetPos,
            BackgroundColor3 = targetKnob
        })
        Tween(pill, TweenInfo.new(0.2), { BackgroundColor3 = targetBg })
        pcall(callback, state)
    end

    row.MouseEnter:Connect(function()
        Tween(row, TweenInfo.new(0.15), { BackgroundColor3 = THEME.ItemHoverBg })
    end)
    row.MouseLeave:Connect(function()
        Tween(row, TweenInfo.new(0.15), { BackgroundColor3 = THEME.ItemBg })
    end)
    row.MouseButton1Click:Connect(function()
        UpdateState(not state)
    end)

    return {
        Set = function(_, val) UpdateState(val) end,
        Get = function(_) return state end,
    }
end

-- ==============================================================================
--                               WIDGET: SLIDER
-- ==============================================================================
function UIModule:CreateSlider(parent, opts)
    parent = ResolveParent(parent)
    opts = opts or {}
    local title = opts.Title or "Slider"
    local min = opts.Min or 0
    local max = opts.Max or 100
    local def = opts.Default or min
    local inc = opts.Increment or 1
    local suffix = opts.Suffix or ""
    local callback = opts.Callback or function() end

    local curVal = math.clamp(def, min, max)

    local card = Instance.new("Frame")
    card.Name = "Slider_" .. title
    card.Size = UDim2.new(1, 0, 0, 56)
    card.BackgroundColor3 = THEME.ItemBg
    card.BorderSizePixel = 0
    card.ClipsDescendants = true
    card.Parent = parent

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = THEME.RadiusItem
    cardCorner.Parent = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = THEME.BorderSubtle
    cardStroke.Thickness = 1
    cardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    cardStroke.Parent = card

    local cardPad = Instance.new("UIPadding")
    cardPad.PaddingLeft = UDim.new(0, 12)
    cardPad.PaddingRight = UDim.new(0, 12)
    cardPad.PaddingTop = UDim.new(0, 9)
    cardPad.PaddingBottom = UDim.new(0, 9)
    cardPad.Parent = card

    local topRow = Instance.new("Frame")
    topRow.Name = "TopRow"
    topRow.Size = UDim2.new(1, 0, 0, 20)
    topRow.BackgroundTransparency = 1
    topRow.ClipsDescendants = true
    topRow.Parent = card

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Size = UDim2.new(1, -65, 1, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.Font = Enum.Font.GothamMedium
    titleLabel.TextSize = 12
    titleLabel.TextColor3 = THEME.TextPrimary
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    titleLabel.Parent = topRow

    local valPill = Instance.new("Frame")
    valPill.Name = "ValuePill"
    valPill.Size = UDim2.new(0, 58, 1, 0)
    valPill.Position = UDim2.new(1, 0, 0, 0)
    valPill.AnchorPoint = Vector2.new(1, 0)
    valPill.BackgroundColor3 = THEME.CardBg
    valPill.BorderSizePixel = 0
    valPill.Parent = topRow

    local vpCorner = Instance.new("UICorner")
    vpCorner.CornerRadius = THEME.RadiusSmall
    vpCorner.Parent = valPill

    local vpStroke = Instance.new("UIStroke")
    vpStroke.Color = THEME.BorderSubtle
    vpStroke.Thickness = 1
    vpStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    vpStroke.Parent = valPill

    local valLabel = Instance.new("TextLabel")
    valLabel.Name = "ValueLabel"
    valLabel.Size = UDim2.new(1, 0, 1, 0)
    valLabel.BackgroundTransparency = 1
    valLabel.Text = tostring(curVal) .. suffix
    valLabel.Font = Enum.Font.GothamBold
    valLabel.TextSize = 11
    valLabel.TextColor3 = THEME.TextPrimary
    valLabel.TextTruncate = Enum.TextTruncate.AtEnd
    valLabel.Parent = valPill

    local track = Instance.new("Frame")
    track.Name = "Track"
    track.Size = UDim2.new(1, 0, 0, 6)
    track.Position = UDim2.new(0, 0, 1, -6)
    track.BackgroundColor3 = THEME.CardBg
    track.BorderSizePixel = 0
    track.Parent = card

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = THEME.RadiusPill
    trackCorner.Parent = track

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new((curVal - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = THEME.Accent
    fill.BorderSizePixel = 0
    fill.Parent = track

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = THEME.RadiusPill
    fillCorner.Parent = fill

    local knob = Instance.new("Frame")
    knob.Name = "Knob"
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new(1, 0, 0.5, 0)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = fill

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = THEME.RadiusPill
    knobCorner.Parent = knob

    local knobStroke = Instance.new("UIStroke")
    knobStroke.Color = THEME.BorderFocus
    knobStroke.Thickness = 1
    knobStroke.Parent = knob

    local isDragging = false

    local function UpdateFromInput(inputX)
        local rel = math.clamp((inputX - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local raw = min + ((max - min) * rel)
        local stepped = math.floor((raw / inc) + 0.5) * inc
        stepped = math.clamp(stepped, min, max)
        
        curVal = stepped
        valLabel.Text = tostring(curVal) .. suffix
        fill.Size = UDim2.new((curVal - min) / (max - min), 0, 1, 0)
        pcall(callback, curVal)
    end

    card.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            Tween(knob, TweenInfo.new(0.1), { Size = UDim2.new(0, 16, 0, 16) })
            UpdateFromInput(input.Position.X)
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    isDragging = false
                    Tween(knob, TweenInfo.new(0.1), { Size = UDim2.new(0, 14, 0, 14) })
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            UpdateFromInput(input.Position.X)
        end
    end)

    return {
        Set = function(_, val)
            curVal = math.clamp(val, min, max)
            valLabel.Text = tostring(curVal) .. suffix
            fill.Size = UDim2.new((curVal - min) / (max - min), 0, 1, 0)
            pcall(callback, curVal)
        end,
        Get = function(_) return curVal end,
    }
end

-- ==============================================================================
--                               WIDGET: DROPDOWN
-- ==============================================================================
function UIModule:CreateDropdown(parent, opts)
    parent = ResolveParent(parent)
    opts = opts or {}
    local title = opts.Title or "Dropdown"
    local options = opts.Options or {}
    local selected = opts.Default or options[1] or ""
    local callback = opts.Callback or function() end
    local isOpen = false

    local row = Instance.new("Frame")
    row.Name = "Dropdown_" .. title
    row.Size = UDim2.new(1, 0, 0, 38)
    row.BackgroundColor3 = THEME.ItemBg
    row.BorderSizePixel = 0
    row.ClipsDescendants = false
    row.ZIndex = 1
    row.Parent = parent

    local rowCorner = Instance.new("UICorner")
    rowCorner.CornerRadius = THEME.RadiusItem
    rowCorner.Parent = row

    local rowStroke = Instance.new("UIStroke")
    rowStroke.Color = THEME.BorderSubtle
    rowStroke.Thickness = 1
    rowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    rowStroke.Parent = row

    local rowPad = Instance.new("UIPadding")
    rowPad.PaddingLeft = UDim.new(0, 12)
    rowPad.PaddingRight = UDim.new(0, 12)
    rowPad.Parent = row

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Size = UDim2.new(0.45, -6, 1, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.Font = Enum.Font.GothamMedium
    titleLabel.TextSize = 12
    titleLabel.TextColor3 = THEME.TextPrimary
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    titleLabel.Parent = row

    local dropBtn = Instance.new("TextButton")
    dropBtn.Name = "DropButton"
    dropBtn.Size = UDim2.new(0.55, 0, 0, 26)
    dropBtn.Position = UDim2.new(1, 0, 0.5, 0)
    dropBtn.AnchorPoint = Vector2.new(1, 0.5)
    dropBtn.BackgroundColor3 = THEME.CardBg
    dropBtn.BorderSizePixel = 0
    dropBtn.Text = ""
    dropBtn.AutoButtonColor = false
    dropBtn.ClipsDescendants = false
    dropBtn.ZIndex = 2
    dropBtn.Parent = row

    local dbCorner = Instance.new("UICorner")
    dbCorner.CornerRadius = THEME.RadiusSmall
    dbCorner.Parent = dropBtn

    local dbStroke = Instance.new("UIStroke")
    dbStroke.Color = THEME.BorderSubtle
    dbStroke.Thickness = 1
    dbStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    dbStroke.Parent = dropBtn

    local selLabel = Instance.new("TextLabel")
    selLabel.Name = "SelectedLabel"
    selLabel.Size = UDim2.new(1, -26, 1, 0)
    selLabel.Position = UDim2.new(0, 8, 0, 0)
    selLabel.BackgroundTransparency = 1
    selLabel.Text = tostring(selected)
    selLabel.Font = Enum.Font.GothamMedium
    selLabel.TextSize = 11
    selLabel.TextColor3 = THEME.TextPrimary
    selLabel.TextXAlignment = Enum.TextXAlignment.Left
    selLabel.TextTruncate = Enum.TextTruncate.AtEnd
    selLabel.Parent = dropBtn

    local arrowIcon = Instance.new("ImageLabel")
    arrowIcon.Name = "Arrow"
    arrowIcon.Size = UDim2.new(0, 12, 0, 12)
    arrowIcon.Position = UDim2.new(1, -8, 0.5, 0)
    arrowIcon.AnchorPoint = Vector2.new(1, 0.5)
    arrowIcon.BackgroundTransparency = 1
    arrowIcon.Image = FallbackIcons["chevron"]
    arrowIcon.ImageColor3 = THEME.TextSecondary
    arrowIcon.Parent = dropBtn

    local flyout = Instance.new("Frame")
    flyout.Name = "FlyoutList"
    flyout.Size = UDim2.new(1, 0, 0, 0)
    flyout.Position = UDim2.new(0, 0, 1, 4)
    flyout.BackgroundColor3 = THEME.CardBg
    flyout.BorderSizePixel = 0
    flyout.ClipsDescendants = true
    flyout.Visible = false
    flyout.ZIndex = 120
    flyout.Parent = dropBtn

    local fCorner = Instance.new("UICorner")
    fCorner.CornerRadius = THEME.RadiusItem
    fCorner.Parent = flyout

    local fStroke = Instance.new("UIStroke")
    fStroke.Color = THEME.BorderFocus
    fStroke.Thickness = 1
    fStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    fStroke.Parent = flyout

    local fLayout = Instance.new("UIListLayout")
    fLayout.FillDirection = Enum.FillDirection.Vertical
    fLayout.Padding = UDim.new(0, 2)
    fLayout.Parent = flyout

    local fPad = Instance.new("UIPadding")
    fPad.PaddingLeft = UDim.new(0, 4)
    fPad.PaddingRight = UDim.new(0, 4)
    fPad.PaddingTop = UDim.new(0, 4)
    fPad.PaddingBottom = UDim.new(0, 4)
    fPad.Parent = flyout

    local function SetElevation(elevate)
        local z = elevate and 100 or 1
        row.ZIndex = z
        dropBtn.ZIndex = z + 1
        flyout.ZIndex = z + 10

        local cur = row.Parent
        while cur and cur ~= self.ScreenGui do
            if cur:IsA("Frame") and string.find(cur.Name, "Section_") then
                cur.ZIndex = elevate and 90 or 1
                break
            end
            cur = cur.Parent
        end
    end

    local function ToggleFlyout(open)
        isOpen = open
        if isOpen then
            SetElevation(true)
            flyout.Visible = true
            local targetH = math.min(#options * 26 + 8, 140)
            Tween(arrowIcon, TweenInfo.new(0.2), { Rotation = 180 })
            Tween(flyout, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Size = UDim2.new(1, 0, 0, targetH)
            })
        else
            Tween(arrowIcon, TweenInfo.new(0.2), { Rotation = 0 })
            local tw = Tween(flyout, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                Size = UDim2.new(1, 0, 0, 0)
            })
            tw.Completed:Connect(function()
                if not isOpen then
                    flyout.Visible = false
                    SetElevation(false)
                end
            end)
        end
    end

    local function PopulateOptions()
        for _, ch in ipairs(flyout:GetChildren()) do
            if ch:IsA("TextButton") then ch:Destroy() end
        end

        for _, opt in ipairs(options) do
            local optBtn = Instance.new("TextButton")
            optBtn.Name = "Opt_" .. tostring(opt)
            optBtn.Size = UDim2.new(1, 0, 0, 24)
            optBtn.BackgroundColor3 = (opt == selected) and THEME.ItemBg or THEME.CardBg
            optBtn.BorderSizePixel = 0
            optBtn.Text = tostring(opt)
            optBtn.Font = Enum.Font.GothamMedium
            optBtn.TextSize = 11
            optBtn.TextColor3 = (opt == selected) and THEME.TextPrimary or THEME.TextSecondary
            optBtn.TextXAlignment = Enum.TextXAlignment.Left
            optBtn.AutoButtonColor = false
            optBtn.ZIndex = 125
            optBtn.Parent = flyout

            local oCorner = Instance.new("UICorner")
            oCorner.CornerRadius = THEME.RadiusSmall
            oCorner.Parent = optBtn

            local oPad = Instance.new("UIPadding")
            oPad.PaddingLeft = UDim.new(0, 8)
            oPad.Parent = optBtn

            optBtn.MouseEnter:Connect(function()
                Tween(optBtn, TweenInfo.new(0.1), { BackgroundColor3 = THEME.ItemHoverBg, TextColor3 = THEME.TextPrimary })
            end)
            optBtn.MouseLeave:Connect(function()
                local isCurrent = (opt == selected)
                Tween(optBtn, TweenInfo.new(0.1), {
                    BackgroundColor3 = isCurrent and THEME.ItemBg or THEME.CardBg,
                    TextColor3 = isCurrent and THEME.TextPrimary or THEME.TextSecondary
                })
            end)
            optBtn.MouseButton1Click:Connect(function()
                selected = opt
                selLabel.Text = tostring(selected)
                ToggleFlyout(false)
                pcall(callback, selected)
            end)
        end
    end

    PopulateOptions()
    dropBtn.MouseButton1Click:Connect(function()
        ToggleFlyout(not isOpen)
    end)

    return {
        Set = function(_, val)
            selected = val
            selLabel.Text = tostring(selected)
            PopulateOptions()
            pcall(callback, selected)
        end,
        Get = function(_) return selected end,
    }
end

-- ==============================================================================
--                               WIDGET: INPUT
-- ==============================================================================
function UIModule:CreateInput(parent, opts)
    parent = ResolveParent(parent)
    opts = opts or {}
    local title = opts.Title or "Input"
    local placeholder = opts.Placeholder or "Type here..."
    local def = opts.Default or ""
    local callback = opts.Callback or function() end

    local row = Instance.new("Frame")
    row.Name = "Input_" .. title
    row.Size = UDim2.new(1, 0, 0, 38)
    row.BackgroundColor3 = THEME.ItemBg
    row.BorderSizePixel = 0
    row.ClipsDescendants = true
    row.Parent = parent

    local rowCorner = Instance.new("UICorner")
    rowCorner.CornerRadius = THEME.RadiusItem
    rowCorner.Parent = row

    local rowStroke = Instance.new("UIStroke")
    rowStroke.Color = THEME.BorderSubtle
    rowStroke.Thickness = 1
    rowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    rowStroke.Parent = row

    local rowPad = Instance.new("UIPadding")
    rowPad.PaddingLeft = UDim.new(0, 12)
    rowPad.PaddingRight = UDim.new(0, 12)
    rowPad.Parent = row

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Size = UDim2.new(0.45, -6, 1, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.Font = Enum.Font.GothamMedium
    titleLabel.TextSize = 12
    titleLabel.TextColor3 = THEME.TextPrimary
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    titleLabel.ClipsDescendants = true
    titleLabel.Parent = row

    local boxFrame = Instance.new("Frame")
    boxFrame.Name = "BoxContainer"
    boxFrame.Size = UDim2.new(0.55, 0, 0, 26)
    boxFrame.Position = UDim2.new(1, 0, 0.5, 0)
    boxFrame.AnchorPoint = Vector2.new(1, 0.5)
    boxFrame.BackgroundColor3 = THEME.CardBg
    boxFrame.BorderSizePixel = 0
    boxFrame.ClipsDescendants = true
    boxFrame.Parent = row

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = THEME.RadiusSmall
    bCorner.Parent = boxFrame

    local bStroke = Instance.new("UIStroke")
    bStroke.Color = THEME.BorderSubtle
    bStroke.Thickness = 1
    bStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    bStroke.Parent = boxFrame

    local bPad = Instance.new("UIPadding")
    bPad.PaddingLeft = UDim.new(0, 8)
    bPad.PaddingRight = UDim.new(0, 8)
    bPad.Parent = boxFrame

    local textBox = Instance.new("TextBox")
    textBox.Name = "InputBox"
    textBox.Size = UDim2.new(1, 0, 1, 0)
    textBox.BackgroundTransparency = 1
    textBox.Text = def
    textBox.PlaceholderText = placeholder
    textBox.PlaceholderColor3 = THEME.TextMuted
    textBox.Font = Enum.Font.GothamMedium
    textBox.TextSize = 11
    textBox.TextColor3 = THEME.TextPrimary
    textBox.TextXAlignment = Enum.TextXAlignment.Left
    textBox.ClearTextOnFocus = false
    textBox.ClipsDescendants = true
    textBox.Parent = boxFrame

    textBox.Focused:Connect(function()
        Tween(bStroke, TweenInfo.new(0.15), { Color = THEME.BorderFocus })
    end)

    textBox.FocusLost:Connect(function(enterPressed)
        Tween(bStroke, TweenInfo.new(0.15), { Color = THEME.BorderSubtle })
        pcall(callback, textBox.Text, enterPressed)
    end)

    return {
        Set = function(_, val) textBox.Text = tostring(val) end,
        Get = function(_) return textBox.Text end,
    }
end

-- ==============================================================================
--                               WIDGET: CHECKBOX
-- ==============================================================================
function UIModule:CreateCheckbox(parent, opts)
    parent = ResolveParent(parent)
    opts = opts or {}
    local title = opts.Title or "Checkbox"
    local state = opts.Default or false
    local callback = opts.Callback or function() end

    local row = Instance.new("TextButton")
    row.Name = "Checkbox_" .. title
    row.Size = UDim2.new(1, 0, 0, 36)
    row.BackgroundColor3 = THEME.ItemBg
    row.BorderSizePixel = 0
    row.Text = ""
    row.AutoButtonColor = false
    row.ClipsDescendants = true
    row.Parent = parent

    local rowCorner = Instance.new("UICorner")
    rowCorner.CornerRadius = THEME.RadiusItem
    rowCorner.Parent = row

    local rowStroke = Instance.new("UIStroke")
    rowStroke.Color = THEME.BorderSubtle
    rowStroke.Thickness = 1
    rowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    rowStroke.Parent = row

    local rowPad = Instance.new("UIPadding")
    rowPad.PaddingLeft = UDim.new(0, 12)
    rowPad.PaddingRight = UDim.new(0, 12)
    rowPad.Parent = row

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Size = UDim2.new(1, -36, 1, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.Font = Enum.Font.GothamMedium
    titleLabel.TextSize = 12
    titleLabel.TextColor3 = THEME.TextPrimary
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    titleLabel.Parent = row

    local box = Instance.new("Frame")
    box.Name = "CheckFrame"
    box.Size = UDim2.new(0, 20, 0, 20)
    box.Position = UDim2.new(1, 0, 0.5, 0)
    box.AnchorPoint = Vector2.new(1, 0.5)
    box.BackgroundColor3 = state and THEME.Accent or THEME.CardBg
    box.BorderSizePixel = 0
    box.Parent = row

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = THEME.RadiusSmall
    bCorner.Parent = box

    local bStroke = Instance.new("UIStroke")
    bStroke.Color = THEME.BorderSubtle
    bStroke.Thickness = 1
    bStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    bStroke.Parent = box

    local checkIcon = Instance.new("ImageLabel")
    checkIcon.Name = "CheckIcon"
    checkIcon.Size = UDim2.new(0, 13, 0, 13)
    checkIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
    checkIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    checkIcon.BackgroundTransparency = 1
    checkIcon.Image = FallbackIcons["check"]
    checkIcon.ImageColor3 = Color3.fromRGB(15, 15, 20)
    checkIcon.ImageTransparency = state and 0 or 1
    checkIcon.Parent = box

    local function ToggleCheck(val)
        state = val
        Tween(box, TweenInfo.new(0.15), { BackgroundColor3 = state and THEME.Accent or THEME.CardBg })
        Tween(checkIcon, TweenInfo.new(0.15), { ImageTransparency = state and 0 or 1 })
        pcall(callback, state)
    end

    row.MouseEnter:Connect(function()
        Tween(row, TweenInfo.new(0.12), { BackgroundColor3 = THEME.ItemHoverBg })
    end)
    row.MouseLeave:Connect(function()
        Tween(row, TweenInfo.new(0.12), { BackgroundColor3 = THEME.ItemBg })
    end)
    row.MouseButton1Click:Connect(function()
        ToggleCheck(not state)
    end)

    return {
        Set = function(_, val) ToggleCheck(val) end,
        Get = function(_) return state end,
    }
end

-- ==============================================================================
--                               WIDGET: ADJUSTMENT PICKER
-- ==============================================================================
function UIModule:CreateAdjustmentPicker(parent, opts)
    parent = ResolveParent(parent)
    opts = opts or {}
    local title = opts.Title or "Adjustment"
    local options = opts.Options or { "Option 1", "Option 2", "Option 3" }
    local callback = opts.Callback or function() end

    local isMulti = type(opts.Selected) == "table"
    local selectedList = {}
    if isMulti then
        for _, v in ipairs(opts.Selected) do
            table.insert(selectedList, v)
        end
    end

    local selIndex = 1
    if not isMulti and opts.Selected then
        for i, opt in ipairs(options) do
            if opt == opts.Selected then selIndex = i break end
        end
    end

    local row = Instance.new("Frame")
    row.Name = "Adjustment_" .. title
    row.Size = UDim2.new(1, 0, 0, 38)
    row.BackgroundColor3 = THEME.ItemBg
    row.BorderSizePixel = 0
    row.ClipsDescendants = false
    row.ZIndex = 1
    row.Parent = parent

    local rowCorner = Instance.new("UICorner")
    rowCorner.CornerRadius = THEME.RadiusItem
    rowCorner.Parent = row

    local rowStroke = Instance.new("UIStroke")
    rowStroke.Color = THEME.BorderSubtle
    rowStroke.Thickness = 1
    rowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    rowStroke.Parent = row

    local rowPad = Instance.new("UIPadding")
    rowPad.PaddingLeft = UDim.new(0, 12)
    rowPad.PaddingRight = UDim.new(0, 12)
    rowPad.Parent = row

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Size = UDim2.new(0.45, -6, 1, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.Font = Enum.Font.GothamMedium
    titleLabel.TextSize = 12
    titleLabel.TextColor3 = THEME.TextPrimary
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    titleLabel.Parent = row

    local controlBox = Instance.new("Frame")
    controlBox.Name = "ControlBox"
    controlBox.Size = UDim2.new(0.55, 0, 0, 26)
    controlBox.Position = UDim2.new(1, 0, 0.5, 0)
    controlBox.AnchorPoint = Vector2.new(1, 0.5)
    controlBox.BackgroundColor3 = THEME.CardBg
    controlBox.BorderSizePixel = 0
    controlBox.ClipsDescendants = false
    controlBox.ZIndex = 2
    controlBox.Parent = row

    local cbCorner = Instance.new("UICorner")
    cbCorner.CornerRadius = THEME.RadiusSmall
    cbCorner.Parent = controlBox

    local cbStroke = Instance.new("UIStroke")
    cbStroke.Color = THEME.BorderSubtle
    cbStroke.Thickness = 1
    cbStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    cbStroke.Parent = controlBox

    if isMulti then
        local curLabel = Instance.new("TextLabel")
        curLabel.Name = "CurrentLabel"
        curLabel.Size = UDim2.new(1, -24, 1, 0)
        curLabel.Position = UDim2.new(0, 8, 0, 0)
        curLabel.BackgroundTransparency = 1
        curLabel.Text = string.format("%d selected", #selectedList)
        curLabel.Font = Enum.Font.GothamMedium
        curLabel.TextSize = 11
        curLabel.TextColor3 = THEME.TextPrimary
        curLabel.TextXAlignment = Enum.TextXAlignment.Left
        curLabel.TextTruncate = Enum.TextTruncate.AtEnd
        curLabel.Parent = controlBox

        local chevron = Instance.new("ImageLabel")
        chevron.Name = "Chevron"
        chevron.Size = UDim2.new(0, 12, 0, 12)
        chevron.Position = UDim2.new(1, -8, 0.5, 0)
        chevron.AnchorPoint = Vector2.new(1, 0.5)
        chevron.BackgroundTransparency = 1
        chevron.Image = FallbackIcons["chevron"]
        chevron.ImageColor3 = THEME.TextSecondary
        chevron.Parent = controlBox

        local triggerBtn = Instance.new("TextButton")
        triggerBtn.Name = "Trigger"
        triggerBtn.Size = UDim2.new(1, 0, 1, 0)
        triggerBtn.BackgroundTransparency = 1
        triggerBtn.Text = ""
        triggerBtn.Parent = controlBox

        local flyout = Instance.new("Frame")
        flyout.Name = "MultiFlyout"
        flyout.Size = UDim2.new(1, 0, 0, 0)
        flyout.Position = UDim2.new(0, 0, 1, 4)
        flyout.BackgroundColor3 = THEME.CardBg
        flyout.BorderSizePixel = 0
        flyout.ClipsDescendants = true
        flyout.Visible = false
        flyout.ZIndex = 120
        flyout.Parent = controlBox

        local mfc = Instance.new("UICorner")
        mfc.CornerRadius = THEME.RadiusItem
        mfc.Parent = flyout

        local mfs = Instance.new("UIStroke")
        mfs.Color = THEME.BorderFocus
        mfs.Thickness = 1
        mfs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        mfs.Parent = flyout

        local mfl = Instance.new("UIListLayout")
        mfl.FillDirection = Enum.FillDirection.Vertical
        mfl.Padding = UDim.new(0, 2)
        mfl.Parent = flyout

        local mfp = Instance.new("UIPadding")
        mfp.PaddingLeft = UDim.new(0, 4)
        mfp.PaddingRight = UDim.new(0, 4)
        mfp.PaddingTop = UDim.new(0, 4)
        mfp.PaddingBottom = UDim.new(0, 4)
        mfp.Parent = flyout

        local isOpen = false

        local function SetElevation(elevate)
            local z = elevate and 100 or 1
            row.ZIndex = z
            controlBox.ZIndex = z + 1
            flyout.ZIndex = z + 10

            local cur = row.Parent
            while cur and cur ~= self.ScreenGui do
                if cur:IsA("Frame") and string.find(cur.Name, "Section_") then
                    cur.ZIndex = elevate and 90 or 1
                    break
                end
                cur = cur.Parent
            end
        end

        local function HasSelected(item)
            for _, v in ipairs(selectedList) do
                if v == item then return true end
            end
            return false
        end

        local function RefreshFlyout()
            for _, ch in ipairs(flyout:GetChildren()) do
                if ch:IsA("TextButton") then ch:Destroy() end
            end

            for _, opt in ipairs(options) do
                local isChecked = HasSelected(opt)
                local optBtn = Instance.new("TextButton")
                optBtn.Name = "Opt_" .. tostring(opt)
                optBtn.Size = UDim2.new(1, 0, 0, 24)
                optBtn.BackgroundColor3 = isChecked and THEME.ItemBg or THEME.CardBg
                optBtn.BorderSizePixel = 0
                optBtn.Text = (isChecked and "[x] " or "[ ] ") .. tostring(opt)
                optBtn.Font = Enum.Font.GothamMedium
                optBtn.TextSize = 11
                optBtn.TextColor3 = isChecked and THEME.TextPrimary or THEME.TextSecondary
                optBtn.TextXAlignment = Enum.TextXAlignment.Left
                optBtn.AutoButtonColor = false
                optBtn.ZIndex = 125
                optBtn.Parent = flyout

                local opc = Instance.new("UICorner")
                opc.CornerRadius = THEME.RadiusSmall
                opc.Parent = optBtn

                local opp = Instance.new("UIPadding")
                opp.PaddingLeft = UDim.new(0, 8)
                opp.Parent = optBtn

                optBtn.MouseButton1Click:Connect(function()
                    if HasSelected(opt) then
                        for idx, v in ipairs(selectedList) do
                            if v == opt then table.remove(selectedList, idx) break end
                        end
                    else
                        table.insert(selectedList, opt)
                    end
                    curLabel.Text = string.format("%d selected", #selectedList)
                    RefreshFlyout()
                    pcall(callback, selectedList)
                end)
            end
        end

        local function ToggleFlyout(open)
            isOpen = open
            if isOpen then
                SetElevation(true)
                RefreshFlyout()
                flyout.Visible = true
                local targetH = math.min(#options * 26 + 8, 140)
                Tween(chevron, TweenInfo.new(0.2), { Rotation = 180 })
                Tween(flyout, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    Size = UDim2.new(1, 0, 0, targetH)
                })
            else
                Tween(chevron, TweenInfo.new(0.2), { Rotation = 0 })
                local tw = Tween(flyout, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                    Size = UDim2.new(1, 0, 0, 0)
                })
                tw.Completed:Connect(function()
                    if not isOpen then
                        flyout.Visible = false
                        SetElevation(false)
                    end
                end)
            end
        end

        triggerBtn.MouseButton1Click:Connect(function()
            ToggleFlyout(not isOpen)
        end)
    else
        local prevBtn = Instance.new("TextButton")
        prevBtn.Name = "PrevBtn"
        prevBtn.Size = UDim2.new(0, 24, 1, 0)
        prevBtn.Position = UDim2.new(0, 0, 0, 0)
        prevBtn.BackgroundTransparency = 1
        prevBtn.Text = "<"
        prevBtn.Font = Enum.Font.GothamBold
        prevBtn.TextSize = 14
        prevBtn.TextColor3 = THEME.TextSecondary
        prevBtn.Parent = controlBox

        local nextBtn = Instance.new("TextButton")
        nextBtn.Name = "NextBtn"
        nextBtn.Size = UDim2.new(0, 24, 1, 0)
        nextBtn.Position = UDim2.new(1, -24, 0, 0)
        nextBtn.BackgroundTransparency = 1
        nextBtn.Text = ">"
        nextBtn.Font = Enum.Font.GothamBold
        nextBtn.TextSize = 14
        nextBtn.TextColor3 = THEME.TextSecondary
        nextBtn.Parent = controlBox

        local curLabel = Instance.new("TextLabel")
        curLabel.Name = "CurrentLabel"
        curLabel.Size = UDim2.new(1, -52, 1, 0)
        curLabel.Position = UDim2.new(0, 26, 0, 0)
        curLabel.BackgroundTransparency = 1
        curLabel.Text = tostring(options[selIndex] or "")
        curLabel.Font = Enum.Font.GothamMedium
        curLabel.TextSize = 11
        curLabel.TextColor3 = THEME.TextPrimary
        curLabel.TextTruncate = Enum.TextTruncate.AtEnd
        curLabel.Parent = controlBox

        local function Step(dir)
            selIndex = selIndex + dir
            if selIndex < 1 then selIndex = #options end
            if selIndex > #options then selIndex = 1 end
            curLabel.Text = tostring(options[selIndex])
            pcall(callback, options[selIndex], selIndex)
        end

        prevBtn.MouseButton1Click:Connect(function() Step(-1) end)
        nextBtn.MouseButton1Click:Connect(function() Step(1) end)
    end

    return {
        Get = function(_) return isMulti and selectedList or options[selIndex] end,
    }
end

-- ==============================================================================
--                               WIDGET: INFO LABEL
-- ==============================================================================
function UIModule:CreateInfoLabel(parent, opts)
    parent = ResolveParent(parent)
    opts = opts or {}
    local text = opts.Text or ""
    local icon = opts.Icon or "info"

    local card = Instance.new("Frame")
    card.Name = "InfoCard"
    card.Size = UDim2.new(1, 0, 0, 0)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.BackgroundColor3 = THEME.CardBg
    card.BorderSizePixel = 0
    card.Parent = parent

    local cCorner = Instance.new("UICorner")
    cCorner.CornerRadius = THEME.RadiusItem
    cCorner.Parent = card

    local cStroke = Instance.new("UIStroke")
    cStroke.Color = THEME.BorderSubtle
    cStroke.Thickness = 1
    cStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    cStroke.Parent = card

    local cPad = Instance.new("UIPadding")
    cPad.PaddingLeft = UDim.new(0, 10)
    cPad.PaddingRight = UDim.new(0, 10)
    cPad.PaddingTop = UDim.new(0, 8)
    cPad.PaddingBottom = UDim.new(0, 8)
    cPad.Parent = card

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0, 8)
    layout.Parent = card

    local iconImg = Instance.new("ImageLabel")
    iconImg.Name = "InfoIcon"
    iconImg.Size = UDim2.new(0, 14, 0, 14)
    iconImg.BackgroundTransparency = 1
    iconImg.Image = GetIcon(icon)
    iconImg.ImageColor3 = THEME.TextSecondary
    iconImg.Parent = card

    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "InfoText"
    infoLabel.Size = UDim2.new(1, -24, 0, 0)
    infoLabel.AutomaticSize = Enum.AutomaticSize.Y
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = text
    infoLabel.Font = Enum.Font.GothamMedium
    infoLabel.TextSize = 11
    infoLabel.TextColor3 = THEME.TextSecondary
    infoLabel.TextWrapped = true
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.Parent = card

    return card
end

-- ==============================================================================
--                               DESTROY
-- ==============================================================================
function UIModule:Destroy()
    if self.ScreenGui then
        self.ScreenGui:Destroy()
    end
end

-- ==============================================================================
--             IMPLEMENTASI PENGUJIAN: SELURUH FITUR & TOMBOL
-- ==============================================================================


local function createMainUI()
    if shared.RideAPetMainWindow then
        shared.RideAPetMainWindow:Destroy()
    end
    local window = UIModule.new({
        Title = "Xyrax Kaitun",
        Subtitle = "Ride A Pet",
        Size = UDim2.new(0, 800, 0, 520),
        ToggleKey = Enum.KeyCode.RightAlt
    })
    shared.RideAPetMainWindow = window
    window.DisableToggleKey = true
    window.MainFrame.Visible = false
    local shadow = window.ScreenGui:FindFirstChild("ShadowFrame")
    if shadow then
        shadow.Visible = false
    end
    if shared.RideAPetMainUIConnection then
        shared.RideAPetMainUIConnection:Disconnect()
    end
    shared.RideAPetMainUIConnection = UserInputService.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.LeftControl then
            local visible = not window.MainFrame.Visible
            window.MainFrame.Visible = visible
            if shadow then
                shadow.Visible = visible
            end
        end
    end)

    window:CreateCategory("KAITUN")
    local kaitunTab = window:CreateTab("Kaitun", "zap")
    local automation = kaitunTab:CreateSection({
        Title = "Automation",
        Subtitle = "Ride A Pet controller",
        Icon = "settings",
        Side = "Left"
    })
    automation:CreateToggle({
        Title = "Kaitun",
        Description = "Enable the main controller",
        Default = kaitun.enabled,
        Callback = function(value)
            kaitun.enabled = value
        end
    })
    automation:CreateToggle({
        Title = "Egg Farm",
        Description = "Collect and place eggs",
        Default = kaitun.eggFarmEnabled,
        Callback = function(value)
            kaitun.eggFarmEnabled = value
        end
    })
    automation:CreateToggle({
        Title = "Hatch Luck",
        Description = "Upgrade Hatch Luck while farming",
        Default = kaitun.upgradeLuckEnabled,
        Callback = function(value)
            kaitun.upgradeLuckEnabled = value
        end
    })
    automation:CreateToggle({
        Title = "Auto Rebirth",
        Description = "Rebirth when requirements are ready",
        Default = kaitun.rebirthEnabled,
        Callback = function(value)
            kaitun.rebirthEnabled = value
        end
    })
    automation:CreateToggle({
        Title = "Place Best Pet",
        Description = "Place the highest income pets",
        Default = kaitun.placePetsEnabled,
        Callback = function(value)
            kaitun.placePetsEnabled = value
        end
    })

    window:CreateCategory("SETTINGS")
    local settingsTab = window:CreateTab("Settings", "settings")
    local settings = settingsTab:CreateSection({
        Title = "Session",
        Subtitle = "Always-on helpers",
        Icon = "shield",
        Side = "Left"
    })
    settings:CreateToggle({
        Title = "Anti-AFK",
        Description = "Prevent idle disconnects",
        Default = shared.RideAPetAntiAfkEnabled ~= false,
        Callback = function(value)
            shared.RideAPetAntiAfkEnabled = value
        end
    })
    settings:CreateInfoLabel({
        Text = "Press LeftControl to open or close this menu.",
        Icon = "info"
    })
end

createMainUI()

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
    if not kaitun.upgradeLuckEnabled or os.clock() < kaitun.nextLuckUpgrade then
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

        if not kaitun.enabled then
            stopMovement()
            setStatus("Paused")
            task.wait(LOOP_INTERVAL)
            continue
        end

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

        if kaitun.placePetsEnabled and os.clock() >= kaitun.nextPetCheck then
            kaitun.petPlacementPending = true
            kaitun.nextPetCheck = os.clock() + PET_CHECK_INTERVAL
        end

        if kaitun.petPlacementPending and kaitun.placePetsEnabled then
            setStatus("Equipping Best")
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
                    if kaitun.eggFarmEnabled and canStartEggTransaction() then
                        collectEgg(egg, true)
                    elseif not kaitun.eggFarmEnabled then
                        setStatus("Egg Farm Paused")
                    end
                else
                    upgradeHatchLuck()
                    if kaitun.eggFarmEnabled and canStartEggTransaction() then
                        local bestEgg = findTargetEgg()
                        if bestEgg then
                            collectEgg(bestEgg, false)
                        else
                            setStatus("Waiting For Egg")
                        end
                    else
                        kaitun.targetEgg = targetEgg
                        kaitun.targetLuck = targetEgg and Eggs[targetEgg] and Eggs[targetEgg].Luck or 0
                        if not kaitun.eggFarmEnabled then
                            setStatus("Egg Farm Paused")
                        end
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

            if kaitun.rebirthEnabled then
                setStatus("Ready To Rebirth")
                attemptRebirth(rebirthCount)
            else
                setStatus("Rebirth Paused")
            end
            task.wait(LOOP_INTERVAL)
            continue
        end

        if kaitun.eggFarmEnabled and canStartEggTransaction() then
            local bestEgg = findTargetEgg()
            if bestEgg then
                collectEgg(bestEgg, false)
            else
                setStatus("Waiting For Egg")
            end
        else
            kaitun.targetEgg = nil
            kaitun.targetLuck = 0
            if not kaitun.eggFarmEnabled then
                setStatus("Egg Farm Paused")
            end
        end
        task.wait(LOOP_INTERVAL)
    end
    stopMovement()
    setStatus("Idle")
    print("[!] Character reset or died. Kaitun stopped.")
end)
