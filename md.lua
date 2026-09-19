local Players = game:GetService("Players")
local Rep = game:GetService("ReplicatedStorage")
local Run = game:GetService("RunService")

local ThirdPerson = require(Rep.Shared.ThirdPerson)
local RevolverTiming = require(Rep.Shared.RevolverTiming)
local InputMap = require(Rep.Extensions.InputMap)
local Rarity = require(Rep.Shared.Rarity)
local RapClient = require(Rep.Shared.RapClient)

local lp = Players.LocalPlayer
local Inventory = Rep.Remotes:WaitForChild("Inventory")
local OpenCrate = Rep.Bindables:WaitForChild("OpenCrate")
local playerGui = lp:WaitForChild("PlayerGui")
local spinner = playerGui:WaitForChild("Spinner")
local wheel = spinner:WaitForChild("Content"):WaitForChild("MainSpinWheel")
local skip = wheel:WaitForChild("Skip")
local gotContent = playerGui:WaitForChild("GotItem"):WaitForChild("Content")

local Config = getgenv().XyraxConfig or {}
local function setting(name, default)
    local value = Config[name]
    return value == nil and default or value
end

local catalog = {}
local crateBusy = false
local THRESHOLD = tonumber(setting("CashThreshold", 40000)) or 40000
local KEEP_CASH = tonumber(setting("KeepCash", 0)) or 0
local CaseBuyPlan = setting("CaseBuyPlan", {SpaceCase = 8, RecruitCase = 6})
local BuyPlan = {"SpaceCase", "RecruitCase"}
local MaxCount = {
    SpaceCase = tonumber(CaseBuyPlan.SpaceCase) or 8,
    RecruitCase = tonumber(CaseBuyPlan.RecruitCase) or 6,
}

Run:UnbindFromRenderStep("MurderDuelLock")

local function cash()
    return tonumber(lp:GetAttribute("Cash")) or 0
end

local function refreshCatalog()
    local a, b = Inventory:InvokeServer("GetCrateCatalog")
    local raw = typeof(b) == "table" and b or typeof(a) == "table" and a or {}

    table.clear(catalog)

    for key, crate in pairs(raw) do
        if typeof(crate) == "table" then
            local crateId = crate.CrateId or crate.Id or key

            if typeof(crateId) == "string" then
                catalog[crateId] = crate
            end
        end
    end
end

local function getSnapshot()
    local a, b = Inventory:InvokeServer("GetSnapshot", {Filter = "All"})

    if typeof(a) == "table" and typeof(a.Items) == "table" then
        return a
    end

    if typeof(b) == "table" and typeof(b.Items) == "table" then
        return b
    end
end

local function findOwnedCrate()
    local snapshot = getSnapshot()

    for _, item in ipairs(snapshot and snapshot.Items or {}) do
        if item.Kind == "Crate" and typeof(item.CrateId) == "string" and (item.Stack or 0) > 0 then
            return item.CrateId
        end
    end
end

local function instanceIdOf(item)
    if typeof(item.InstanceId) == "string" then
        return item.InstanceId
    end

    if typeof(item.InstanceIds) == "table" and typeof(item.InstanceIds[1]) == "string" then
        return item.InstanceIds[1]
    end
end

local function getRapByItemId(kind, items)
    local rap = {}
    local pending = 0
    local requested = {}

    RapClient.Prime()

    for _, item in ipairs(items) do
        if not requested[item.ItemId] then
            requested[item.ItemId] = true
            pending = pending + 1

            RapClient.Request(kind, item.ItemId, function(meta)
                if typeof(meta) == "table" then
                    rap[item.ItemId] = meta
                end

                pending = pending - 1
            end)
        end
    end

    local deadline = os.clock() + 5

    while pending > 0 and os.clock() < deadline do
        task.wait(0.05)
    end

    return rap
end

local function equipBestKind(kind)
    local snapshot = getSnapshot()
    local items = {}

    for _, item in ipairs(snapshot and snapshot.Items or {}) do
        if item.Kind == kind and typeof(item.ItemId) == "string" and instanceIdOf(item) then
            table.insert(items, item)
        end
    end

    if #items == 0 then
        return
    end

    local rapByItemId = getRapByItemId(kind, items)
    local best
    local bestRarity = -1
    local bestRap = -1

    for _, item in ipairs(items) do
        local rarityScore = Rarity.Order[item.Rarity] or 0
        local meta = rapByItemId[item.ItemId]
        local projected = meta and (meta.Projected == true or meta.RapProjected == true)
        local rap = if meta and not projected then tonumber(meta.RAP) or tonumber(meta.RapEstimate) or -1 else -1

        if rarityScore > bestRarity or (rarityScore == bestRarity and setting("UseRAPTieBreaker", true) and rap > bestRap) then
            best = item
            bestRarity = rarityScore
            bestRap = rap
        end
    end

    if best and best.IsEquipped ~= true then
        local ok, success, reason = pcall(function()
            return Inventory:InvokeServer("Equip", {
                Kind = kind,
                InstanceId = instanceIdOf(best),
            })
        end)

        if not ok or success ~= true then
            print("Equip ไม่สำเร็จ", kind, reason or tostring(success))
        end
    end
end

local function equipBestWeapons()
    if not setting("AutoEquipBestWeapons", true) then
        return
    end

    equipBestKind("Knife")
    equipBestKind("Revolver")
end

local function skipAndClose()
    if typeof(firesignal) ~= "function" then
        return false
    end

    local deadline = os.clock() + 20

    repeat
        task.wait(0.05)
    until spinner.Enabled or os.clock() >= deadline

    while spinner.Enabled and os.clock() < deadline do
        if skip.Visible then
            firesignal(skip.MouseButton1Click)
        end

        local tapToClose = gotContent:FindFirstChild("TapToClose")

        if tapToClose and tapToClose.Visible then
            firesignal(tapToClose.MouseButton1Click)
        end

        task.wait(0.1)
    end

    return not spinner.Enabled
end

local function openOne(crateId)
    local ok, success, reason, reward = pcall(function()
        return Inventory:InvokeServer("OpenCrate", {CrateId = crateId})
    end)

    if not ok or success ~= true or typeof(reward) ~= "table" then
        return false, reason or tostring(success)
    end

    local crate = catalog[crateId] or {}

    OpenCrate:Fire({
        CrateId = crateId,
        CrateName = crate.Name or crateId,
        RarityOdds = crate.RarityOdds or {},
        PublicPools = crate.PublicPools or {},
        Reward = reward,
        AutoCloseAfterReveal = true,
        GetRemaining = function()
            return 0
        end,
        RequestRoll = function()
            return false, "NoRequestRoll"
        end,
    })

    if not skipAndClose() then
        return false, "Spinner did not close"
    end

    return true
end

local function openAllOwnedCrates()
    if not setting("AutoOpenCases", true) then
        return false
    end

    if crateBusy or typeof(firesignal) ~= "function" then
        return false
    end

    crateBusy = true
    local openedAny = false

    while true do
        local crateId = findOwnedCrate()

        if not crateId then
            break
        end

        local ok, reason = openOne(crateId)

        if not ok then
            print("เปิดกล่องไม่สำเร็จ", crateId, reason)
            break
        end

        openedAny = true
        task.wait(0.2)
    end

    crateBusy = false

    if openedAny then
        equipBestWeapons()
    end

    return openedAny
end

local function priceOf(crateId)
    return tonumber(catalog[crateId] and catalog[crateId].Price) or 0
end

local function buyOne(crateId)
    local ok, success, reason = pcall(function()
        return Inventory:InvokeServer("PurchaseCrate", {Count = 1, CrateId = crateId})
    end)

    if not ok or success ~= true then
        return false, reason or tostring(success)
    end

    return true
end

local function buyPlannedCrates()
    if not setting("AutoBuyCases", true) then
        return
    end

    for _, crateId in ipairs(BuyPlan) do
        local price = priceOf(crateId)
        local maximum = MaxCount[crateId] or 1

        for _ = 1, maximum do
            if price <= 0 or cash() - price < KEEP_CASH then
                break
            end

            local before = cash()
            local ok, reason = buyOne(crateId)

            if not ok then
                print("ซื้อไม่สำเร็จ", crateId, reason)
                break
            end

            local deadline = os.clock() + 5

            repeat
                task.wait(0.1)
            until cash() ~= before or os.clock() >= deadline
        end
    end
end

local function startSeasonPass()
    if not setting("AutoClaimSeasonPass", true) then
        return
    end

    task.spawn(function()
        local SeasonPass = Rep.Remotes:WaitForChild("SeasonPass", 8)

        if not SeasonPass then
            return
        end

        while true do
            local ok, state = pcall(function()
                return SeasonPass:InvokeServer("GetState")
            end)

            if ok and typeof(state) == "table" then
                local claimed = {}
                local claimedPremium = {}

                for _, tier in ipairs(state.Claimed or {}) do
                    claimed[tier] = true
                end

                for _, tier in ipairs(state.ClaimedPremium or {}) do
                    claimedPremium[tier] = true
                end

                for tier = 1, state.Tier or 0 do
                    if not claimed[tier] then
                        SeasonPass:InvokeServer("Claim", "Free", tier)
                        task.wait(0.1)
                    end

                    if state.Premium == true and not claimedPremium[tier] then
                        SeasonPass:InvokeServer("Claim", "Premium", tier)
                        task.wait(0.1)
                    end
                end
            end

            task.wait(5)
        end
    end)
end

local function matchIdOf()
    return lp:GetAttribute("MatchId")
end

local function queueIfNeeded()
    if not setting("AutoMatchmaking", true) then
        return
    end

    local current = matchIdOf()

    if typeof(current) == "string" and current ~= "" then
        return
    end

    if setting("OpenCasesBeforeQueue", true) and (crateBusy or findOwnedCrate()) then
        openAllOwnedCrates()
        return
    end

    if setting("AutoBuyCases", true) and cash() >= THRESHOLD then
        buyPlannedCrates()

        if findOwnedCrate() then
            openAllOwnedCrates()
        end

        return
    end

    local matchmakingRoot = Rep:FindFirstChild("MatchmakingShared")
    local remotes = matchmakingRoot and matchmakingRoot:FindFirstChild("Remotes")
    local GetMyState = remotes and remotes:FindFirstChild("GetMyState")
    local SetModes = remotes and remotes:FindFirstChild("SetModes")
    local QueueModes = remotes and remotes:FindFirstChild("QueueModes")

    if not GetMyState or not QueueModes then
        return
    end

    local ok, state = pcall(function()
        return GetMyState:InvokeServer()
    end)

    if not ok or typeof(state) ~= "table" then
        return
    end

    if state.leaderUserId and state.leaderUserId ~= lp.UserId then
        return
    end

    if state.activeTickets and next(state.activeTickets) then
        return
    end

    local partySize = typeof(state.members) == "table" and #state.members or 1
    local modes = {}
    local allowedModes = setting("MatchModes", { ["2v2"] = true, ["3v3"] = true, ["4v4"] = true })

    if partySize <= 2 and allowedModes["2v2"] then
        table.insert(modes, "2v2")
    end

    if partySize <= 3 and allowedModes["3v3"] then
        table.insert(modes, "3v3")
    end

    if partySize <= 4 and allowedModes["4v4"] then
        table.insert(modes, "4v4")
    end

    if #modes == 0 then
        return
    end

    if SetModes then
        SetModes:FireServer(modes)
        task.wait(0.15)
    end

    QueueModes:InvokeServer(modes)
end

local function isRoundLive(matchId)
    local activeMatches = Rep:FindFirstChild("ActiveMatches")
    local match = activeMatches and activeMatches:FindFirstChild(matchId)
    local roundEndTime = match and match:GetAttribute("RoundEndTime")

    return typeof(roundEndTime) == "number" and workspace:GetServerTimeNow() < roundEndTime
end

local function getTarget(matchId, matchSide, usedTargets)
    local enemies = {}

    for _, player in ipairs(Players:GetPlayers()) do
        local targetCharacter = player.Character
        local humanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")

        if player ~= lp
            and not usedTargets[player.UserId]
            and player:GetAttribute("MatchId") == matchId
            and player:GetAttribute("MatchSide") ~= matchSide
            and humanoid
            and humanoid.Health > 0 then
            table.insert(enemies, player)
        end
    end

    if #enemies == 0 then
        return nil
    end

    return enemies[math.random(#enemies)]
end

local function fireAt(target, matchId)
    if not isRoundLive(matchId) then
        return
    end

    local character = lp.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local targetCharacter = target.Character
    local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
    local targetHumanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")

    if not root or not targetRoot or not targetHumanoid or targetHumanoid.Health <= 0 then
        return
    end

    local homeCFrame = character:GetPivot()
    local spawnPosition = (targetRoot.CFrame * CFrame.new(0, 0, 4)).Position
    character:PivotTo(CFrame.lookAt(spawnPosition, targetRoot.Position))

    Run:UnbindFromRenderStep("MurderDuelLock")

    Run:BindToRenderStep("MurderDuelLock", Enum.RenderPriority.Camera.Value + 1, function()
        if root.Parent and targetRoot.Parent and targetHumanoid.Parent and targetHumanoid.Health > 0 then
            local targetPoint = targetRoot.Position + Vector3.new(0, 1.5, 0)
            local eye = CFrame.lookAt(root.Position + Vector3.new(0, 1.5, 0), targetPoint)
            local camera = workspace.CurrentCamera

            ThirdPerson.PublishEye(eye)

            if camera then
                camera.CFrame = CFrame.lookAt(camera.CFrame.Position, targetPoint)
            end
        else
            Run:UnbindFromRenderStep("MurderDuelLock")
        end
    end)

    task.wait(0.15)
    Run.RenderStepped:Wait()

    local tool = character:FindFirstChildWhichIsA("Tool")

    if isRoundLive(matchId) and tool and tool.Parent and tool:FindFirstChild("RevolverClient") then
        InputMap.tap("Attack")
    end

    Run:UnbindFromRenderStep("MurderDuelLock")

    if setting("ReturnToBaseAfterShot", true) and character.Parent then
        character:PivotTo(homeCFrame)
    end
end

refreshCatalog()
openAllOwnedCrates()
equipBestWeapons()
startSeasonPass()

local usedTargets = {}

while true do
    if not lp.Character then
        task.wait(0.25)
    else
        local matchId = matchIdOf()

        if typeof(matchId) ~= "string" or matchId == "" then
            queueIfNeeded()
            task.wait(0.5)
        elseif setting("AutoDuel", true) and isRoundLive(matchId) then
            local target = getTarget(matchId, lp:GetAttribute("MatchSide"), usedTargets)

            if target then
                usedTargets[target.UserId] = true
                fireAt(target, matchId)
                task.wait(RevolverTiming.SHOT_COOLDOWN)
            else
                table.clear(usedTargets)
                task.wait(0.25)
            end
        else
            task.wait(0.25)
        end
    end
end
