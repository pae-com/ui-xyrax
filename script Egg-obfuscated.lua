--[[
    XyraxStealEgg
    The steal lifecycle deliberately follows stealegg.lua:
    filter -> select -> corridor movement -> carry -> return -> place -> next egg.
]]

-- Luraph v15 attribute shims keep this source runnable before obfuscation.
-- Luraph removes these passthrough declarations from its obfuscated output.
if not LPH_OBFUSCATED then
	function LPH_ATTRIBUTES(...) end
	function VM(...) return ... end
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
local Client = assert(ReplicatedStorage:FindFirstChild("Client"), "[XyraxStealEgg] ReplicatedStorage.Client is unavailable")
local Shared = assert(ReplicatedStorage:FindFirstChild("Shared"), "[XyraxStealEgg] ReplicatedStorage.Shared is unavailable")
local Data = assert(ReplicatedStorage:FindFirstChild("Data"), "[XyraxStealEgg] ReplicatedStorage.Data is unavailable")
local SharedEggs = assert(Shared:FindFirstChild("Eggs"), "[XyraxStealEgg] Shared.Eggs is unavailable")
local SharedUtil = assert(Shared:FindFirstChild("Util"), "[XyraxStealEgg] Shared.Util is unavailable")

local EggState, PlotState, Assets, EggToolDisplay, Save, SlotIdentity
do
	local function requireModuleTable(instance, label, diagnostics)
		if not instance then
			error("[XyraxStealEgg] " .. label .. " is unavailable", 0)
		end
		if not instance:IsA("ModuleScript") then
			error("[XyraxStealEgg] " .. label .. " must be a ModuleScript", 0)
		end

		local reason
		for attempt = 1, 3 do
			local ok, result = pcall(require, instance)
			if ok and typeof(result) == "table" then
				return result
			end
			reason = ok and ("returned " .. typeof(result) .. ", expected table") or tostring(result)
			if attempt < 3 then task.wait(.1) end
		end

		warn("[XyraxStealEgg] " .. label .. " require: FAILED (" .. reason .. ")")
		error("[XyraxStealEgg] " .. label .. " dependency is unavailable", 0)
	end

	-- These paths/state APIs were checked against the dump and stealegg.lua.
	EggState = requireModuleTable(Client:FindFirstChild("EggState"), "Client.EggState")
	PlotState = requireModuleTable(Client:FindFirstChild("PlotState"), "Client.PlotState")
	Assets = requireModuleTable(Data:FindFirstChild("Assets"), "Data.Assets")
	EggToolDisplay = requireModuleTable(SharedEggs:FindFirstChild("EggToolDisplay"), "Shared.Eggs.EggToolDisplay")
	Save = requireModuleTable(Shared:FindFirstChild("Save"), "Shared.Save")
	SlotIdentity = requireModuleTable(SharedUtil:FindFirstChild("AreaEggSlotIdentity"), "Shared.Util.AreaEggSlotIdentity")

	local carryChangedOk, carryChanged, carryChangedConnect = pcall(function()
		local signal = EggState.CarryChanged
		return signal, signal and signal.Connect
	end)
	if not (carryChangedOk and carryChanged and typeof(carryChangedConnect) == "function") then
		local reason = carryChangedOk and "missing Connect" or tostring(carryChanged)
		warn("[XyraxStealEgg] CarryChanged: FAILED (" .. reason .. ")")
	end
end

local function requireOptional(instance)
	if not instance or not instance:IsA("ModuleScript") then return nil end
	local ok, result = pcall(require, instance)
	return ok and typeof(result) == "table" and result or nil
end
local BaseUpgrade = requireOptional(Client:FindFirstChild("BaseUpgrade"))
local AssetRoster = requireOptional(Client:FindFirstChild("AssetRoster"))
local AssetEarnings = requireOptional(SharedUtil:FindFirstChild("AssetEarnings"))
local Treadmills = requireOptional(Data:FindFirstChild("Treadmills"))
local Trails = requireOptional(Data:FindFirstChild("Trails"))
local AssetItems = requireOptional(SharedUtil:FindFirstChild("AssetItems"))
local RiftEligibility = requireOptional(SharedUtil:FindFirstChild("RiftEligibility"))
local FuseKernel = requireOptional(SharedUtil:FindFirstChild("FuseKernel"))
local SharedModules = Shared:FindFirstChild("Modules")
local RiftRecipes = requireOptional(SharedModules and SharedModules:FindFirstChild("RiftRecipes"))
local Remotes = requireOptional(Shared:FindFirstChild("Remotes")) or {}

-- Public settings can be declared in a loader before this file runs:
-- getgenv().XyraxConfig = { MoveSpeed = 650, ... }
-- _G.XyraxConfig is accepted as a fallback for executors without getgenv.
local Environment = (getgenv and getgenv()) or _G

local isMobileDevice = false
do
	local touchOk, touch = pcall(function() return UserInputService.TouchEnabled end)
	local kbOk, kb = pcall(function() return UserInputService.KeyboardEnabled end)
	local exName = ""
	pcall(function()
		if typeof(identifyexecutor) == "function" then
			exName = tostring(identifyexecutor())
		elseif typeof(getexecutorname) == "function" then
			exName = tostring(getexecutorname())
		end
	end)
	exName = string.lower(exName)
	local isMobileEx = string.find(exName, "delta", 1, true) ~= nil
		or string.find(exName, "codex", 1, true) ~= nil
		or string.find(exName, "arceus", 1, true) ~= nil
		or string.find(exName, "fluxus", 1, true) ~= nil
		or string.find(exName, "hydrogen", 1, true) ~= nil
		or string.find(exName, "vega", 1, true) ~= nil
		or string.find(exName, "appleware", 1, true) ~= nil

	if (touchOk and touch) and (not kbOk or not kb) then
		isMobileDevice = true
	elseif isMobileEx or (touchOk and touch) then
		isMobileDevice = true
	end
end

local function safeHttpGet(endpoint)
	if typeof(endpoint) ~= "string" or endpoint == "" then return false, nil end
	local directOk, directBody = pcall(function()
		if typeof(game.HttpGet) == "function" then
			return game:HttpGet(endpoint)
		elseif typeof(HttpGet) == "function" then
			return HttpGet(endpoint)
		end
		return nil
	end)
	if directOk and typeof(directBody) == "string" and directBody ~= "" then
		return true, directBody
	end

	local httpReq = (syn and syn.request)
		or (http and http.request)
		or http_request
		or request
		or (fluxus and fluxus.request)
		or (delta and delta.request)
		or (Environment and (Environment.request or Environment.http_request or (Environment.delta and Environment.delta.request)))
	if typeof(httpReq) == "function" then
		local reqOk, reqRes = pcall(httpReq, {
			Url = endpoint,
			Method = "GET"
		})
		if reqOk and typeof(reqRes) == "table" and typeof(reqRes.Body) == "string" then
			return true, reqRes.Body
		end
	end
	return false, nil
end

-- ============================================================================
-- Delivery fix: block the client-authoritative guard confiscation.
-- การยึดไข่ ("Delivery failed! The egg was returned to its nest.") ถูกตัดสินโดย
-- client เราเอง แล้วยิง GuardPatrol.ForestStrike:FireServer (ForestGuardRuntime.lua:114-119).
-- บล็อกไม่ให้ client ยิง remote นี้ -> ยามยึดไข่ไม่ได้ -> ส่งไข่ผ่านตลอด.
-- idempotent, ไม่กระทบ remote อื่น ๆ; ถ้า executor ไม่รองรับ hook จะข้ามอย่างเงียบ ๆ.
-- ============================================================================
do
	local function findForestStrike()
		local packages = ReplicatedStorage:FindFirstChild("Packages")
		local networking = packages and packages:FindFirstChild("Networking")
		local direct = networking and networking:FindFirstChild("RE/GuardPatrol/ForestStrike")
		if direct and direct:IsA("RemoteEvent") then return direct end
		for _, inst in ipairs(ReplicatedStorage:GetDescendants()) do
			if inst:IsA("RemoteEvent") and string.find(inst.Name, "ForestStrike", 1, true) then
				return inst
			end
		end
		return nil
	end

	local strike = findForestStrike()
	if strike
		and typeof(hookmetamethod) == "function"
		and typeof(getnamecallmethod) == "function"
		and typeof(newcclosure) == "function" then
		local checkC = (typeof(checkcaller) == "function") and checkcaller or function() return false end
		Environment.__XyraxDeliveryFix = Environment.__XyraxDeliveryFix or {}
		local FIX = Environment.__XyraxDeliveryFix
		FIX.target = strike -- refresh target on re-run / rejoin
		if not FIX.installed then
			local old
			pcall(function()
				old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
					LPH_ATTRIBUTES(VM(NONE))
					if self == FIX.target and getnamecallmethod() == "FireServer" and not checkC() then
						FIX.blocked = (FIX.blocked or 0) + 1
						return -- swallow: guard cannot confiscate the carried egg
					end
					return old(self, ...)
				end))
				FIX.installed = true
			end)
		end
	end
end

local EggController = {}
EggController.ALLOWED_RARITIES = {
	Common = true, Uncommon = true, Rare = true, Epic = true, Legendary = true,
	Mythic = true, Cosmic = true, Secret = true, Eternal = true, Divine = true,
}
EggController.RARITY_PRIORITY = {
	"Secret", "Divine", "Eternal", "Cosmic", "Mythic", "Legendary",
	"Epic", "Rare", "Uncommon", "Common",
}
EggController.RARITY_OPTIONS = {
	"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic",
	"Cosmic", "Secret", "Eternal", "Divine",
}
EggController.STEALABLE_STATES = { Slot = true, Dropped = true }
EggController.CARRY_RANGE = 20
EggController.ARRIVE_DISTANCE = 1.35
EggController.MOVE_TIMEOUT = 14
EggController.CORRIDOR_STEP_DELAY = 0.08
-- Instant-return: เวลาสูงสุด (วินาที) ที่ตรึงตัวไว้ในโซน PetArea เพื่อรอ server claim
-- ไข่ (Carried -> Owned).  ถ้า claim สำเร็จก่อนจะออกทันที.  การวาร์ปเข้าโซนบ้านนี้ยัง
-- ข้ามเขตยามภายใน wake window (0.63s) => server escape check = EscapedSafely (ไม่โดนยึด)

EggController.Config = {
	-- Lower rarities remain available in the UI for testing, but are off by default.
	SelectedRarities = {
		Secret = true, Eternal = true, Divine = true,
	},
	AllowedEggStates = {
		Slot = true,
		Dropped = true,
	},
	MoveSpeed = 625,
	AutoStealEnabled = true,
	-- StealEgg New: anti-ragdoll -> doHumanoid -> tween/pick up staging egg ->
	-- wait for ragdoll -> teleport/pick up target only on ragdoll -> return home.
	UseStealEggNew = true,
	-- The first pickup is whichever valid egg is nearest to this staging point.
	-- Blank name + empty rarity list means no egg name/rarity filter is applied.
	StealEggNewStagingName = "",
	StealEggNewStagingRarities = {},
	-- Zones are tested in this order. The next zone is used only when the prior
	-- zone has no valid staging egg inside its radius.
	StealEggNewStagingCFrames = {
		CFrame.new(739.469299, 70.574203, -408.801514, -0.026384, 0, -0.999652, 0, 1, 0, 0.999652, 0, -0.026384),
		CFrame.new(949.074097, 70.574203, -322.714752, -0.131572, 0, -0.991307, 0, 1, 0, 0.991307, 0, -0.131572),
		CFrame.new(1183.364502, 70.574203, -411.388885, 0.275870, 0, -0.961195, 0, 1, 0, 0.961195, 0, 0.275870),
		CFrame.new(1491.090210, 70.574203, -313.929016, 0.085873, 0, -0.996306, 0, 1, 0, 0.996306, 0, 0.085873),
	},
	StealEggNewStagingRadius = 100,
	-- Exact egg display name for the second pickup. Leave blank to use the
	-- nearest enabled rarity outside the staging egg.
	StealEggNewTargetName = "",
	-- Maximum time to watch for the staging guard ragdoll. A timeout abandons
	-- this attempt; it never sends a staging egg back to the base.
	StealEggNewPreTeleportDelay = 2,
	StealEggNewRagdollRecoveryTimeout = 5,
	StealEggNewPickupDelay = 3.5,
	ReturnFloatHeight = 5,
	AutoTreadmillWhenIdle = true,
	-- Verify real replicated SpeedPower rather than the treadmill HUD/belt event.
	TreadmillSpeedCheckSeconds = 5,
	TreadmillSpeedFailureLimit = 10,
	TreadmillHopOnSpeedFailure = true,
	-- A teleport request can be accepted locally but later fail with Roblox 772
	-- (the destination filled up). Keep selecting another public server until one
	-- actually accepts the transfer.
	TreadmillHopRetryDelay = 3,
	TreadmillHopAttemptWait = 8,
	FpsBoostEnabled = true,
	AutoHatchReady = true,
	-- Boss-shop mutation is controller-owned, never a second worker.  It runs
	-- after Boss/Rift but before normal Kaitun actions (especially hatching).
	AutoMutationConsumable = true,
	MutationActionInterval = 0.15,
	MutationRollRetryDelay = 0.75,
	MutationCountLogInterval = 5,
	-- Applies after a rejected purchase, unavailable price, or insufficient token
	-- balance so a normal Kaitun tick never turns into a Boss-shop remote flood.
	MutationRetryDelay = 5,
	MutationPurchaseConfirmTimeout = 3,
	MutationStateConfirmTimeout = 2,
	AutoPlaceHatchedPets = true,
	AutoPlaceSelectedEggs = true,
	AutoEquipBest = true,
	AutoSellUnequippedPets = true,
	AutoClaimHouseEarnings = true,
	AutoUpgradeBase = true,
	AutoUpgradeTreadmill = true,
	AutoBuyTrails = true,
	AutoTrailProgression = true,
	AutoEquipBestTrail = true,
	AutoClaimIndex = true,
	AutoClaimGroupReward = true,
	-- Claims only completed Boss Mastery milestones; reward handling remains with
	-- the existing inventory/place/hatch flow.
	AutoClaimBossMastery = true,
	BossMasteryClaimInterval = 0.75,
	BossMasteryClaimConfirmTimeout = 4,
	BossMasteryClaimRetryDelay = 5,
	-- Rift is deliberately controller-owned: when it is live and the player is
	-- eligible, it pre-empts every normal automation action until it resolves.
	AutoRiftEnabled = true,
	-- Boss test flow has priority over Shattered Rift and normal Kaitun.
	AutoRiftBossEnabled = true,
	BossMoveSpeed = 200,
	BossCrystalMoveSpeed = 120,
	BossEnterTimeout = 15,
	BossActionInterval = 0.75,
	BossStallTimeout = 180,
	BossRewardConfirmTimeout = 5,
	BossExitTimeout = 15,
	BossRecoveryDelay = 15,
	-- Data.Rift: Id="Radiant", DisplayName="Shattered Rift".
	-- Keep this true: other Rift banners must never acquire the global lock.
	AutoRiftShatteredOnly = true,
	RiftStatePollSeconds = 1,
	RiftRemoteFailureLimit = 3,
	RiftRecoveryDelay = 15,
	RiftRewardConfirmTimeout = 15,
	WatchdogEnabled = true,
	WatchdogNoProgressSeconds = 180,
	WatchdogFailureLimit = 4,
	WatchdogBackoffSeconds = 15,
	KeepMoney = 0,
	SelectedTrails = {},
	TrailPurchaseInterval = 6,
	TrailEquipInterval = 5,
	IndexClaimInterval = 60,
	GroupRewardClaimInterval = 600,
	UpgradeInterval = 2,
	EquipBestInterval = 5,
	SellPetInterval = 2,
	ClaimHouseEarningsInterval = 5,
	AutomationEnabled = true,
	ControllerInterval = 0.10,
	HatchCheckInterval = 0.75,
	NoEggLogInterval = 8,
	PlacementInset = 5,
	PlacementSpacing = 7,
	PostPlacementDelay = 1,
	-- When a returned target has not replicated with an owned/new UID, keep its
	-- delivery lock this long before giving up and resuming staging.
	PendingTargetPlacementTimeout = 15,

	-- Xyrax Monitor Reporter (read-only telemetry)
	MonitorEnabled = false,
	MonitorKey = "",
	MonitorClientId = "",
	MonitorInterval = 20,
}

-- Apply only supported settings.  Nested settings are merged so a loader may
-- provide just one rarity or trail without discarding the built-in defaults.
local ExternalConfig = Environment.XyraxConfig
if typeof(ExternalConfig) ~= "table" and typeof(_G) == "table" then
	ExternalConfig = _G.XyraxConfig
end
if typeof(ExternalConfig) == "table" then
	for key, value in pairs(ExternalConfig) do
		local defaultValue = EggController.Config[key]
		if defaultValue ~= nil and typeof(value) == typeof(defaultValue) then
			if typeof(value) == "table" then
				local merged = table.clone(defaultValue)
				for nestedKey, nestedValue in pairs(value) do
					merged[nestedKey] = nestedValue
				end
				EggController.Config[key] = merged
			else
				EggController.Config[key] = value
			end
		end
	end
end
EggController.State = "Idle"
EggController.TargetName = nil
EggController.TargetRarity = nil

local GENERATION_KEY = "__XyraxStealEggFlowGeneration"
local generation = (tonumber(Environment[GENERATION_KEY]) or 0) + 1
Environment[GENERATION_KEY] = generation
local controllerRunning = false
local heldCarryState = nil
local pendingEggUid = nil
EggController.StagingDiscardRequestedUids = EggController.StagingDiscardRequestedUids or {}
local FailedEggCooldowns = {}
-- Delivery lock: once a real target is stolen, staging is blocked until that
-- target reaches a placement.  The category survives the server's UID rebind.
EggController.PendingTargetCategory = nil
EggController.PendingTargetWaitDeadline = 0
local characterEpoch = 0
local stealEggNewPreparedEpoch = -1
EggController.Timers = {
	Hatch = 0,
	Upgrade = 0,
	EquipBest = 0,
	SellPet = 0,
	HouseEarnings = 0,
	TrailPurchase = 0,
	TrailEquip = 0,
	IndexClaim = 0,
	GroupReward = 0,
}
local lastTrailStatusMessage = nil
local nextUpgradeKind = "Treadmill"
local treadmillTraining = false
local nextTreadmillCheckAt = 0
local treadmillAssignmentKnown = false
local treadmillAssigned = false
local treadmillRequestGraceUntil = 0
local treadmillLastSpeedPower = nil
local treadmillSpeedFailureCount = 0
local treadmillHopRequested = false
local lastNoEggLogAt = 0
local watchdogLastProgressAt = os.clock()
local watchdogFailureCount = 0
local watchdogBackoffUntil = 0
local watchdogReason = nil
local watchdogNeedsTreadmill = false
local RiftRuntime = {
	Mode = false,
	WaitingForTarget = false,
	BossMode = false,
	BossState = nil,
	BossFailures = 0,
	BossStartedAt = 0,
	BossNextActionAt = 0,
	BossNextStateAt = 0,
	BossSnapshotState = nil,
	BossEnterDeadline = 0,
	BossExitDeadline = 0,
	BossRewardDeadline = 0,
	BossRewardObserved = false,
	BossRewardConfirmationLogged = false,
	BossLastProgressAt = 0,
	BossLastHealth = nil,
	BossLastCrystalHits = nil,
	BossLastArmHits = nil,
	BossRetryAt = 0,
	BossRewardBaselineTokens = nil,
	BossRewardBaselineMastery = nil,
	BossSuppressed = false,
	State = nil,
	RequirementsKey = nil,
	ReservedUids = {},
	TargetCategory = nil,
	TargetAreaId = nil,
	StateFailures = 0,
	ActionFailures = 0,
	NextStateAt = 0,
	NextActionAt = 0,
	RetryAt = 0,
	TradeAccepted = false,
	FinishRequested = false,
	RewardUid = nil,
	RewardConfirmDeadline = 0,
	RewardPlacementRequested = false,
	RewardPlacementDeadline = 0,
	NextBannerCheckAt = 0,
}
-- A reservation is deliberately separate from RiftRuntime.ReservedUids: Rift
-- owns its trade-in slots, while this only shields the one placed egg currently
-- being mutated from Auto Hatch.
EggController.MutationRuntime = {
	ReservedUid = nil,
	TargetRate = nil,
	NextActionAt = 0,
	LastResult = nil,
	LastLoggedConsumableCount = nil,
	NextConsumableCountLogAt = 0,
	-- Data.BossMastery.GetShopPrice applies the replicated ShopPriceOverrides
	-- flag, making it the authoritative client-side Boss-shop price source.
	BossMastery = requireOptional(Data:FindFirstChild("BossMastery")),
}
EggController.BossMasteryClaimRuntime = {
	NextActionAt = 0,
	PendingId = nil,
	ConfirmDeadline = 0,
	LastResult = nil,
	-- Use the game-data module: its Milestones and GetMilestoneKills include
	-- live flag overrides instead of a client-side hardcoded milestone list.
	BossMastery = requireOptional(Data:FindFirstChild("BossMastery")),
}
local nextPlacementIndex = 1
local AreasFolder = Workspace:FindFirstChild("__OBJECTS") and Workspace.__OBJECTS:FindFirstChild("Areas")
local AreaEggSlotsClient = Workspace:FindFirstChild("AreaEggSlotsClient")

local StealDebugNextAt = {}
local function stealDebug(key, message, minimumInterval)
	local now = os.clock()
	minimumInterval = tonumber(minimumInterval) or .5
	if now < (StealDebugNextAt[key] or 0) then return end
	StealDebugNextAt[key] = now + minimumInterval
	warn("[StealDebug] " .. tostring(message))
end
local function log(message) stealDebug("log:" .. tostring(message), message, .2) end
local function warnLog(message) stealDebug("warn:" .. tostring(message), message, .2) end
local function logTrailStatus(message)
	if lastTrailStatusMessage == message then return end
	lastTrailStatusMessage = message
	log("Trail status: " .. message)
end
local function selectedRaritiesText()
	local selected = {}
	for _, rarity in ipairs(EggController.RARITY_PRIORITY) do
		if EggController.Config.SelectedRarities[rarity] == true then table.insert(selected, rarity) end
	end
	return #selected > 0 and table.concat(selected, ", ") or "None"
end
local function setState(state)
	if EggController.State ~= state then
		EggController.State = state
		log("State: " .. state)
	end
end

-- Like stealegg.lua, never cache a Humanoid or root across movement frames.
-- A changed instance is not treated as a character respawn.
local function getHumanoid()
	local character = LocalPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid") or nil
end
local function getRoot()
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") or nil
	return root and root:IsA("BasePart") and root or nil
end
local function active()
	return EggController.Config.AutomationEnabled and Environment[GENERATION_KEY] == generation
end
local function getFieldRecord(uid)
	local ok, record = pcall(EggState.ReadFieldEgg, uid)
	return ok and typeof(record) == "table" and record or nil
end
local function getOwnedEgg(uid)
	local ok, record = pcall(EggState.ReadOwnedEgg, LocalPlayer.UserId, uid)
	if ok and typeof(record) == "table" then return record end
	-- The reference flow treats Save.EggInventory as the placement source of
	-- truth.  It can update before the owner-record cache after a redeem.
	local saveOk, save = pcall(Save.Get)
	local inventory = saveOk and typeof(save) == "table" and save.EggInventory or nil
	local savedRecord = typeof(inventory) == "table" and inventory[uid] or nil
	return typeof(savedRecord) == "table" and savedRecord or nil
end
local function getOwnedEggs()
	local ok, records = pcall(EggState.ReadOwnerEggs, LocalPlayer.UserId)
	local merged = ok and typeof(records) == "table" and records or {}
	local saveOk, save = pcall(Save.Get)
	local inventory = saveOk and typeof(save) == "table" and save.EggInventory or nil
	if typeof(inventory) == "table" then
		for uid, record in pairs(inventory) do
			if merged[uid] == nil and typeof(record) == "table" then merged[uid] = record end
		end
	end
	return merged
end
local function getSave()
	local ok, save = pcall(Save.Get)
	return ok and typeof(save) == "table" and save or nil
end
local function canSpend(save, price)
	price = tonumber(price) or math.huge
	local money = tonumber(save and save.Money) or 0
	local reserve = math.max(0, tonumber(EggController.Config.KeepMoney) or 0)
	return money - reserve >= price
end
local function remoteAt(root, ...)
	local value = root
	for index = 1, select("#", ...) do
		if typeof(value) ~= "table" then return nil end
		value = value[select(index, ...)]
	end
	return typeof(value) == "Instance" and value or nil
end
local function findRemoteContains(fragment)
	fragment = string.lower(fragment)
	for _, instance in ipairs(ReplicatedStorage:GetDescendants()) do
		if (instance:IsA("RemoteEvent") or instance:IsA("RemoteFunction"))
			and string.find(string.lower(instance.Name), fragment, 1, true) then
			return instance
		end
	end
	return nil
end
local function resolveRemote(namespace, actionName)
	return remoteAt(Remotes, namespace, actionName) or findRemoteContains(actionName)
end
local BaseUpgradeRemote = resolveRemote("Homestead", "AskBaseTierRaise")
local TreadmillUpgradeRemote = resolveRemote("Treadmill", "AskTierRaise")
local EquipBestRemote = resolveRemote("Haul", "WearBest")
local SellEveryPetRemote = resolveRemote("PetSatchel", "SellEveryPet")
local TreadmillEquipRemote = resolveRemote("Treadmill", "AskWearStill")
local TreadmillUnequipRemote = resolveRemote("Treadmill", "AskDoff")
local TreadmillAssignedBeltRemote = resolveRemote("Treadmill", "AssignedBeltShifted")
local TrailPurchaseRemote = resolveRemote("Trailwear", "AskPurchase")
local TrailChooseRemote = resolveRemote("Trailwear", "AskChoose")
local TrailWornSnapshotRemote = resolveRemote("Trailwear", "AskWornSnapshot")
local IndexClaimAllRemote = resolveRemote("Codex", "AskRedeemAll")
local GroupRewardRemote = resolveRemote("GroupPerk", "RedeemPerk")
local HouseEarningsSummaryRemote = resolveRemote("AwayEarnings", "FetchSummary")
local HouseEarningsClaimRemote = resolveRemote("AwayEarnings", "AskCollect")
-- Exact paths/call shapes are from BossShop.lua and PlacedEggRenderer.lua in
-- the dump.  Do not use a name-search fallback for a currency-spending remote.
EggController.MutationRuntime.BuyRemote = remoteAt(Remotes, "BossMastery", "AskBuyShopItem")
EggController.MutationRuntime.UseRemote = remoteAt(Remotes, "BossMastery", "AskUseMutationConsumable")
EggController.BossMasteryClaimRuntime.Remote = remoteAt(Remotes, "BossMastery", "AskClaimMilestone")
-- Paths and call shapes are from PlayerScripts/RiftTradeIn.lua in the dump.
-- Do not fall back to name searching for Rift: an unrelated remote must never
-- be mistaken for a sacrifice request.
local RiftAskStateRemote = remoteAt(Remotes, "Rift", "AskState")
local RiftAskTradeInRemote = remoteAt(Remotes, "Rift", "AskTradeIn")
local RiftAskFinishRevealRemote = remoteAt(Remotes, "Rift", "AskFinishReveal")

-- Same directory and ascending-price order used by stealegg.lua.  The UI uses
-- display names, while AskPurchase receives the server's trail id.
local TRAIL_OPTIONS, TRAIL_ID_BY_NAME, TRAIL_NAME_BY_ID, TRAIL_PRICE_BY_NAME = {}, {}, {}, {}
if Trails and typeof(Trails.Directory) == "table" then
	local entries = {}
	for trailId, trailData in pairs(Trails.Directory) do
		if typeof(trailData) == "table" and typeof(trailData.DisplayName) == "string" then
			table.insert(entries, {
			Id = trailId,
			Name = trailData.DisplayName,
			Price = tonumber(trailData.Price) or 0,
		})
		end
	end
	table.sort(entries, function(a, b)
		if a.Price == b.Price then return a.Name < b.Name end
		return a.Price < b.Price
	end)
	for _, entry in ipairs(entries) do
		table.insert(TRAIL_OPTIONS, entry.Name)
		TRAIL_ID_BY_NAME[entry.Name] = entry.Id
		TRAIL_NAME_BY_ID[entry.Id] = entry.Name
		TRAIL_PRICE_BY_NAME[entry.Name] = entry.Price
	end
end
local function getEquippedTrailName(save)
	local trailId = save and save.EquippedTrail
	if typeof(trailId) ~= "string" or trailId == "" then return "None" end
	return TRAIL_NAME_BY_ID[trailId] or trailId
end
if TreadmillAssignedBeltRemote and TreadmillAssignedBeltRemote:IsA("RemoteEvent") then
	TreadmillAssignedBeltRemote.OnClientEvent:Connect(function(belt)
		if Environment[GENERATION_KEY] ~= generation then return end
		treadmillAssignmentKnown = true
		treadmillAssigned = belt ~= nil
		if treadmillAssigned then treadmillTraining = true end
	end)
end
local function callRemote(remote, ...)
	if not remote then return false end
	if remote:IsA("RemoteFunction") then
		local ok, result = pcall(function(...) return remote:InvokeServer(...) end, ...)
		return ok and result ~= false
	end
	if remote:IsA("RemoteEvent") then
		return pcall(function(...) remote:FireServer(...) end, ...)
	end
	return false
end
local function invokeRemote(remote, ...)
	if not remote or not remote:IsA("RemoteFunction") then return nil end
	local ok, first, second, third = pcall(function(...) return remote:InvokeServer(...) end, ...)
	if not ok then return nil end
	return first, second, third
end
-- Port of stealegg.lua's network-call timing for the PetSatchel batch sale.
local function callSellRemote(remote, ...)
	if typeof(remote) ~= "Instance" then return false end
	local args = table.pack(...)
	local done, succeeded, response = false, false, nil
	task.spawn(function()
		if remote:IsA("RemoteFunction") then
			local ok, result = pcall(function() return remote:InvokeServer(table.unpack(args, 1, args.n)) end)
			succeeded, response = ok, result
		elseif remote:IsA("RemoteEvent") then
			succeeded = pcall(function() remote:FireServer(table.unpack(args, 1, args.n)) end)
			response = "RemoteEvent"
		end
		done = true
	end)
	local deadline = os.clock() + 8
	while not done and os.clock() < deadline do task.wait(.05) end
	return done and succeeded, response
end
local function resolveRarity(record)
	local asset = Assets.Directory and Assets.Directory[record and record.AssetCategory]
	local rarity = asset and asset.Rarity
	return typeof(rarity) == "table" and (rarity._id or rarity.DisplayName) or nil
end
local function getEggDisplayName(record)
	local asset = Assets.Directory and Assets.Directory[record and record.AssetCategory]
	return asset and (asset.DisplayName or record.AssetCategory) or record and record.AssetCategory or "Unknown Egg"
end

-- Uses the same catalog calculator used by the pen display.  A field record
-- already contains category, scale, and mutations before the egg is picked up.
local function getEggEarningRate(record)
	if typeof(record) ~= "table" then return 0, "unknown" end
	local itemData = {
		Category = record.AssetCategory,
		AssetCategory = record.AssetCategory,
		Scale = record.AssetScale,
		AssetScale = record.AssetScale,
		Mutations = record.Mutations or {},
	}
	if AssetEarnings and typeof(AssetEarnings.CatalogRatePerSecond) == "function" then
		local ok, calculated = pcall(AssetEarnings.CatalogRatePerSecond, itemData)
		local rate = ok and tonumber(calculated) or nil
		if rate then return rate, "calculated" end
	end
	local asset = Assets.Directory and Assets.Directory[record.AssetCategory]
	return tonumber(asset and asset.EarningRate) or 0, "base"
end

local function getKaitunWeakestPenPet()
	if not AssetRoster or typeof(AssetRoster.ReadOwnerPen) ~= "function" then return nil, 0 end
	local ok, records = pcall(AssetRoster.ReadOwnerPen, LocalPlayer.UserId)
	if not ok or typeof(records) ~= "table" then return nil, 0 end
	local weakest, count = nil, 0
	for _, runtimeRecord in pairs(records) do
		local itemData = typeof(runtimeRecord) == "table" and runtimeRecord.ItemData or nil
		local category = typeof(itemData) == "table" and itemData.Category or nil
		if typeof(category) == "string" then
			local rate = tonumber(runtimeRecord.MoneyPerSecond)
			if rate == nil and AssetEarnings and typeof(AssetEarnings.CatalogRatePerSecond) == "function" then
				local rateOk, calculated = pcall(AssetEarnings.CatalogRatePerSecond, itemData)
				rate = rateOk and tonumber(calculated) or nil
			end
			if rate ~= nil then
				count += 1
				if not weakest or rate < weakest.Rate then
					local asset = Assets.Directory and Assets.Directory[category]
					weakest = { Name = asset and (asset.DisplayName or category) or category, Rate = rate }
				end
			end
		end
	end
	return weakest, count
end

local function slotsFolder()
	if not AreaEggSlotsClient or AreaEggSlotsClient.Parent ~= Workspace then
		AreaEggSlotsClient = Workspace:FindFirstChild("AreaEggSlotsClient")
	end
	return AreaEggSlotsClient
end
local function getHitbox(egg)
	if not (egg and egg:IsA("Model")) then return nil end
	local hitbox = egg:FindFirstChild("Hitbox", true) or egg.PrimaryPart or egg:FindFirstChildWhichIsA("BasePart")
	return (hitbox and hitbox:IsA("BasePart")) and hitbox or nil
end

function EggController.IsValidEgg(egg)
	local slots = slotsFolder()
	if not slots or not egg or not egg:IsA("Model") or egg.Parent ~= slots then return false, nil end
	local cooldownUntil = FailedEggCooldowns[egg.Name]
	if cooldownUntil and os.clock() < cooldownUntil then return false, nil end
	if not getHitbox(egg) then return false, nil end
	local record = getFieldRecord(egg.Name)
	if not record or record.Uid ~= egg.Name then return false, nil end
	local eggRarity = resolveRarity(record)
	local isSecretRarity = eggRarity == "Secret"
	local activeStates = EggController.Config.AllowedEggStates or EggController.STEALABLE_STATES
	if not isSecretRarity and activeStates[record.State] ~= true then return false, nil end
	return true, record
end
function EggController.GetEggs()
	local eggs = {}
	for _, egg in ipairs(slotsFolder() and slotsFolder():GetChildren() or {}) do
		if EggController.IsValidEgg(egg) then table.insert(eggs, egg) end
	end
	return eggs
end
function EggController.GetEggPosition(egg)
	local valid, record = EggController.IsValidEgg(egg)
	-- AreaEggs uses this authoritative bounds CFrame for its reachability checks.
	-- Prefer it over the rendered Hitbox so a snap lands at the interaction point.
	if valid and record and typeof(record.BoundsCFrame) == "CFrame" then
		return record.BoundsCFrame.Position
	end
	local hitbox = valid and getHitbox(egg) or nil
	return hitbox and hitbox.Position or nil
end
function EggController.GetEggRarity(egg)
	local valid, record = EggController.IsValidEgg(egg)
	return valid and resolveRarity(record) or nil
end
function EggController.SetRarityEnabled(rarity, enabled)
	if not EggController.ALLOWED_RARITIES[rarity] or typeof(enabled) ~= "boolean" then
		return false, "Unknown rarity"
	end
	EggController.Config.SelectedRarities[rarity] = enabled
	return true
end
function EggController.SetAllowedEggState(stateName, enabled)
	if typeof(stateName) ~= "string" or typeof(enabled) ~= "boolean" then return false end
	if not EggController.Config.AllowedEggStates then
		EggController.Config.AllowedEggStates = table.clone(EggController.STEALABLE_STATES)
	end
	EggController.Config.AllowedEggStates[stateName] = enabled
	return true
end
function EggController.SetMoveSpeed(speed)
	speed = tonumber(speed)
	if not speed or speed < 50 or speed > 1000 then return false, "Move speed must be between 50 and 1000" end
	EggController.Config.MoveSpeed = speed
	return true
end
function EggController.IsEligibleEgg(egg)
	local valid, record = EggController.IsValidEgg(egg)
	local rarity = valid and resolveRarity(record) or nil
	if not EggController.ALLOWED_RARITIES[rarity] or EggController.Config.SelectedRarities[rarity] ~= true then return false, nil, nil end
	return true, record, rarity
end
function EggController.FindBestEggForRarity(wantedRarity, rootPosition, excludedUid)
	local bestEgg, bestRecord, bestDistance, bestRate = nil, nil, math.huge, -math.huge
	for _, egg in ipairs(EggController.GetEggs()) do
		local eligible, record, rarity = EggController.IsEligibleEgg(egg)
		local position = eligible and EggController.GetEggPosition(egg)
		if position and rarity == wantedRarity and (excludedUid == nil or record.Uid ~= excludedUid) then
			local earningRate = getEggEarningRate(record)
			local delta = rootPosition - position
			local distance = delta:Dot(delta)
			if earningRate > bestRate or (earningRate == bestRate and distance < bestDistance) then
				bestEgg, bestRecord, bestDistance, bestRate = egg, record, distance, earningRate
			end
		end
	end
	if not bestEgg then return nil end
	return {
		Egg = bestEgg,
		Uid = bestRecord.Uid,
		Rarity = wantedRarity,
		Name = getEggDisplayName(bestRecord),
		AssetCategory = bestRecord.AssetCategory,
		AreaId = bestRecord.AreaId,
		EarningRate = bestRate,
	}
end

function EggController.GetBestEligibleEgg(excludedUid)
	local root = getRoot()
	if not root then return nil end
	local rootPosition = root.Position
	for _, wantedRarity in ipairs(EggController.RARITY_PRIORITY) do
		if EggController.Config.SelectedRarities[wantedRarity] then
			local candidate = EggController.FindBestEggForRarity(wantedRarity, rootPosition, excludedUid)
			if candidate then return candidate end
		end
	end
	return nil
end


-- AreaEggs records expose AreaId (verified in the dump).  Forest is the
-- closest starter area, so StealEgg New gives an eligible Forest egg priority
-- without preventing the normal rarity-ranked search when Forest is empty.
function EggController.GetBestEligibleEggInArea(areaId)
	if typeof(areaId) ~= "string" or areaId == "" or not getRoot() then return nil end
	for _, wanted in ipairs(EggController.RARITY_PRIORITY) do
		if EggController.Config.SelectedRarities[wanted] then
			local best, bestRecord, bestDistance = nil, nil, math.huge
			for _, egg in ipairs(EggController.GetEggs()) do
				local eligible, record, rarity = EggController.IsEligibleEgg(egg)
				local position = eligible and EggController.GetEggPosition(egg) or nil
				if position and rarity == wanted and record.AreaId == areaId then
					local delta = getRoot().Position - position
					local distance = delta:Dot(delta)
					if distance < bestDistance then best, bestRecord, bestDistance = egg, record, distance end
				end
			end
			if best then
				return {
					Egg = best,
					Uid = bestRecord.Uid,
					Rarity = wanted,
					Name = getEggDisplayName(bestRecord),
					AssetCategory = bestRecord.AssetCategory,
					AreaId = bestRecord.AreaId,
				}
			end
		end
	end
	return nil
end

-- StealEgg New is deliberately distance-first: once the configured rarities
-- are filtered, choose the physically nearest egg instead of preferring a
-- distant Secret/Divine egg. Supplying an AreaId lets Forest be tried first.
function EggController.GetNearestEligibleEgg(areaId, excludedUid)
	local root = getRoot()
	if not root then return nil end
	if areaId ~= nil and (typeof(areaId) ~= "string" or areaId == "") then return nil end
	local best, bestRecord, bestRarity, bestDistance = nil, nil, nil, math.huge
	for _, egg in ipairs(EggController.GetEggs()) do
		local eligible, record, rarity = EggController.IsEligibleEgg(egg)
		local position = eligible and EggController.GetEggPosition(egg) or nil
		if position and record.Uid ~= excludedUid and (areaId == nil or record.AreaId == areaId) then
			local delta = root.Position - position
			local distance = delta:Dot(delta)
			if distance < bestDistance then
				best, bestRecord, bestRarity, bestDistance = egg, record, rarity, distance
			end
		end
	end
	if not best then return nil end
	return {
		Egg = best,
		Uid = bestRecord.Uid,
		Rarity = bestRarity,
		Name = getEggDisplayName(bestRecord),
		AssetCategory = bestRecord.AssetCategory,
		AreaId = bestRecord.AreaId,
	}
end

-- Rift requirements are exact AssetCategory ids, not rarity filters.  This is
-- kept separate from every normal selector so normal Steal Egg behavior is
-- unchanged when Rift mode is inactive.
function EggController.GetNearestEggByAssetCategory(category, preferredAreaId, excludedUid)
	if typeof(category) ~= "string" or category == "" then return nil end
	local root = getRoot()
	if not root then return nil end
	local best, bestRecord, bestDistance, bestInPreferredArea = nil, nil, math.huge, false
	for _, egg in ipairs(EggController.GetEggs()) do
		local valid, record = EggController.IsValidEgg(egg)
		local position = valid and EggController.GetEggPosition(egg) or nil
		if position and record.Uid ~= excludedUid and record.AssetCategory == category then
			local inPreferredArea = preferredAreaId ~= nil and record.AreaId == preferredAreaId
			local delta = root.Position - position
			local distance = delta:Dot(delta)
			if (inPreferredArea and not bestInPreferredArea)
				or (inPreferredArea == bestInPreferredArea and distance < bestDistance) then
				best, bestRecord, bestDistance, bestInPreferredArea = egg, record, distance, inPreferredArea
			end
		end
	end
	if not best then return nil end
	return {
		Egg = best,
		Uid = bestRecord.Uid,
		Rarity = resolveRarity(bestRecord),
		Name = getEggDisplayName(bestRecord),
		AssetCategory = bestRecord.AssetCategory,
		AreaId = bestRecord.AreaId,
	}
end

-- The staging selector is separate from the final-target rarity switches.
-- It only accepts the configured staging rarities.
function EggController.GetNearestEggOfRarity(wantedRarity, excludedUid)
	if typeof(wantedRarity) ~= "string" or wantedRarity == "" then return nil end
	local root = getRoot()
	if not root then return nil end
	local best, bestRecord, bestDistance = nil, nil, math.huge
	for _, egg in ipairs(EggController.GetEggs()) do
		local valid, record = EggController.IsValidEgg(egg)
		local position = valid and EggController.GetEggPosition(egg) or nil
		if position and record.Uid ~= excludedUid and resolveRarity(record) == wantedRarity then
			local delta = root.Position - position
			local distance = delta:Dot(delta)
			if distance < bestDistance then best, bestRecord, bestDistance = egg, record, distance end
		end
	end
	if not best then return nil end
	return {
		Egg = best,
		Uid = bestRecord.Uid,
		Rarity = resolveRarity(bestRecord),
		Name = getEggDisplayName(bestRecord),
		AssetCategory = bestRecord.AssetCategory,
		AreaId = bestRecord.AreaId,
	}
end

local function getStealEggNewStagingEgg()
	local root = getRoot()
	if not root then return nil end
	local requiredName = EggController.Config.StealEggNewStagingName
	requiredName = typeof(requiredName) == "string" and string.lower(requiredName) or ""
	local rarities = EggController.Config.StealEggNewStagingRarities
	if typeof(rarities) ~= "table" then rarities = { "Uncommon", "Rare" } end
	local areaId = EggController.Config.StealEggNewStagingAreaId
	local radius = math.max(0, tonumber(EggController.Config.StealEggNewStagingRadius) or 0)
	local stagingCFrames = EggController.Config.StealEggNewStagingCFrames
	if typeof(stagingCFrames) ~= "table" then stagingCFrames = {EggController.Config.StealEggNewStagingCFrame} end
	for zoneIndex, stagingCFrame in ipairs(stagingCFrames) do
		if typeof(stagingCFrame) == "CFrame" then
			local center = stagingCFrame.Position
			local best, bestRecord, bestDistance = nil, nil, math.huge
			for _, egg in ipairs(EggController.GetEggs()) do
				local valid, record = EggController.IsValidEgg(egg)
				local position = valid and EggController.GetEggPosition(egg) or nil
				local displayName = valid and getEggDisplayName(record) or ""
				local assetCategory = valid and record.AssetCategory or ""
				local nameMatches = requiredName == ""
					or string.lower(assetCategory) == requiredName
					or string.lower(displayName) == requiredName
				local rarityMatches = requiredName ~= "" or #rarities == 0 or table.find(rarities, resolveRarity(record)) ~= nil
				local inRequiredArea = valid and (not areaId or areaId == "" or record.AreaId == areaId)
				local inRequiredRadius = valid and (radius <= 0 or (position and (position - center).Magnitude <= radius))
				if position and nameMatches and rarityMatches and inRequiredArea and inRequiredRadius then
					local delta = center - position
					local distance = delta:Dot(delta)
					if distance < bestDistance then best, bestRecord, bestDistance = egg, record, distance end
				end
			end
			if best then
				return {
					Egg = best,
					Uid = bestRecord.Uid,
					Rarity = resolveRarity(bestRecord),
					Name = getEggDisplayName(bestRecord),
					AreaId = bestRecord.AreaId,
					StagingZoneIndex = zoneIndex,
				}
			end
		end
	end
	return nil
end

function EggController.GetNearestEligibleEggByName(name, excludedUid)
	if typeof(name) ~= "string" or name == "" then return nil end
	local wantedName, root = string.lower(name), getRoot()
	if not root then return nil end
	local best, bestRecord, bestRarity, bestDistance = nil, nil, nil, math.huge
	for _, egg in ipairs(EggController.GetEggs()) do
		local eligible, record, rarity = EggController.IsEligibleEgg(egg)
		local position = eligible and EggController.GetEggPosition(egg) or nil
		if position and record.Uid ~= excludedUid and string.lower(getEggDisplayName(record)) == wantedName then
			local delta = root.Position - position
			local distance = delta:Dot(delta)
			if distance < bestDistance then
				best, bestRecord, bestRarity, bestDistance = egg, record, rarity, distance
			end
		end
	end
	if not best then return nil end
	return {
		Egg = best,
		Uid = bestRecord.Uid,
		Rarity = bestRarity,
		Name = getEggDisplayName(bestRecord),
		AssetCategory = bestRecord.AssetCategory,
		AreaId = bestRecord.AreaId,
	}
end

local function getKaitunTarget(excludedUid)
	local root = getRoot()
	if not root then return nil end
	local weakestPet, petCount = getKaitunWeakestPenPet()
	local minimumRate = weakestPet and weakestPet.Rate or nil
	local best, bestRecord, bestRate, bestDistance, bestSource = nil, nil, -math.huge, math.huge, nil
	for _, egg in ipairs(EggController.GetEggs()) do
		local valid, record = EggController.IsValidEgg(egg)
		local position = valid and EggController.GetEggPosition(egg) or nil
		if position and record.Uid ~= excludedUid then
			local rate, source = getEggEarningRate(record)
			if (minimumRate == nil or rate > minimumRate) then
				local delta = root.Position - position
				local distance = delta:Dot(delta)
				if rate > bestRate or (rate == bestRate and distance < bestDistance) then
					best, bestRecord, bestRate, bestDistance, bestSource = egg, record, rate, distance, source
				end
			end
		end
	end
	if not best then return nil, weakestPet, petCount end
	return {
		Egg = best,
		Uid = bestRecord.Uid,
		Rarity = resolveRarity(bestRecord),
		Name = getEggDisplayName(bestRecord),
		AssetCategory = bestRecord.AssetCategory,
		AreaId = bestRecord.AreaId,
		EarningRate = bestRate,
		EarningSource = bestSource,
		KaitunWeakestName = weakestPet and weakestPet.Name or nil,
		KaitunWeakestRate = minimumRate,
		KaitunPetCount = petCount,
	}, weakestPet, petCount
end

local function getStealEggNewConfiguredTarget(excludedUid)
	local targetName = EggController.Config.StealEggNewTargetName
	if typeof(targetName) == "string" and targetName ~= "" then
		return EggController.GetNearestEligibleEggByName(targetName, excludedUid)
	end
	local candidate = EggController.GetBestEligibleEgg(excludedUid)
	if candidate then return candidate end
	return EggController.GetNearestEligibleEgg(nil, excludedUid)
end

local function laneZ()
	local gameplayZ = AreasFolder and AreasFolder:FindFirstChild("GameplayZ")
	local separationLine = AreasFolder and AreasFolder:FindFirstChild("SeparationLine")
	return gameplayZ and gameplayZ:IsA("BasePart") and gameplayZ.Position.Z
		or separationLine and separationLine:IsA("BasePart") and separationLine.Position.Z or -365.5
end
local function laneY()
	local gameplayZ = AreasFolder and AreasFolder:FindFirstChild("GameplayZ")
	local root = getRoot()
	return gameplayZ and gameplayZ:IsA("BasePart") and gameplayZ.Position.Y + 3 or root and root.Position.Y or 70
end
-- Keep the horizontal leg inside the gameplay corridor.  The game exposes its
-- center as GameplayZ/SeparationLine; the small tolerance avoids a target
-- rounding value placing the root on the wrong side of the divider.
local function getCorridorBounds()
	local centerZ = laneZ()
	return {
		CenterZ = centerZ,
		MinZ = centerZ - 2,
		MaxZ = centerZ + 2,
	}
end
local function clampToCorridor(position)
	local bounds = getCorridorBounds()
	return Vector3.new(position.X, laneY(), math.clamp(position.Z, bounds.MinZ, bounds.MaxZ))
end
local function groundedY(x, z, fallbackY)
	local floorY = laneY()
	local humanoid, root = getHumanoid(), getRoot()
	local offset = (humanoid and humanoid.HipHeight > 0 and humanoid.HipHeight or 2) + (root and root.Size.Y * .5 or 1)
	local excluded = LocalPlayer.Character and { LocalPlayer.Character } or {}
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	for _ = 1, 20 do
		params.FilterDescendantsInstances = excluded
		local hit = Workspace:Raycast(Vector3.new(x, floorY + 40, z), Vector3.new(0, -160, 0), params)
		if not hit then break end
		local name = string.lower(hit.Instance.Name)
		if hit.Instance.Name == "Ground" or string.find(name, "ground", 1, true) or hit.Position.Y <= floorY + 1.5 then
			return math.clamp(hit.Position.Y + offset, floorY - 2, floorY + 5)
		end
		table.insert(excluded, hit.Instance)
	end
	return typeof(fallbackY) == "number" and math.clamp(fallbackY, floorY - 2, floorY + 5) or floorY + 3
end
local function anchor(root, cframe)
	root.CFrame = cframe
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

-- The stock Animate LocalScript grabs the Humanoid once at startup and connects
-- to that instance.  Swapping the Humanoid out leaves Animate driving a destroyed
-- object, so the character freezes in whatever pose it held and never plays run
-- or idle again -- which is also why the treadmill stops crediting speed: the
-- game reads a character that never enters a running state.  Toggling the script
-- makes it re-run and bind to the live Humanoid.
local function rebindAnimate(character)
	local animate = character and character:FindFirstChild("Animate")
	if not (animate and animate:IsA("LocalScript")) then return false end
	animate.Disabled = true
	task.defer(function()
		if animate.Parent then animate.Disabled = false end
	end)
	return true
end

-- Ported character preparation from stealegg.lua.  The current humanoid is
-- immediately reacquired by getHumanoid(), rather than invalidating the flow.
local function swapStealHumanoid()
	local character, humanoid = LocalPlayer.Character, getHumanoid()
	if not character or not humanoid then return false end
	if isMobileDevice then
		pcall(function()
			humanoid.Sit = false
			humanoid.PlatformStand = false
			humanoid.AutoRotate = true
		end)
		return true
	end
	if humanoid:GetAttribute("BobloStealHum") == true or humanoid:GetAttribute("XyraxStealEggNewHumanoid") == true then return true end
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("LocalScript") and string.find(descendant.Name, "PushBack") then
			pcall(function() descendant.Disabled = true; descendant:Destroy() end)
		end
	end
	humanoid.Archivable = true
	local replacement = humanoid:Clone()
	if not replacement then return false end
	replacement:SetAttribute("BobloStealHum", true)
	replacement.Sit, replacement.PlatformStand, replacement.AutoRotate = false, false, true
	humanoid:Destroy()
	replacement.Parent = character
	-- A Humanoid without an Animator plays nothing at all, and the clone only
	-- carries one over if the original had it parented at clone time.
	if not replacement:FindFirstChildOfClass("Animator") then
		pcall(function() Instance.new("Animator").Parent = replacement end)
	end
	rebindAnimate(character)
	local root = getRoot()
	if root then root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero end
	pcall(function() replacement:ChangeState(Enum.HumanoidStateType.Running) end)
	return getHumanoid() ~= nil
end

-- ============================================================================
-- StealEgg New character preparation
--
-- This is an idempotent version of the two supplied snippets.  It keeps only
-- one set of frame connections on re-runs and never clones a Humanoid again
-- once the current character has already been prepared.
-- ============================================================================
if not isMobileDevice and UserInputService.TouchEnabled then
	isMobileDevice = true
end
local oldStealEggNewProtection = Environment.__XyraxStealEggNewProtection
if typeof(oldStealEggNewProtection) == "table" and typeof(oldStealEggNewProtection.Stop) == "function" then
	pcall(function() oldStealEggNewProtection:Stop() end)
end

local StealEggNewProtection = {
	Connections = {},
	RagdollSignalVersion = 0,
	LastRagdollStateName = "Unknown",
}
Environment.__XyraxStealEggNewProtection = StealEggNewProtection

-- Anti-ragdoll can change Physics back to GettingUp in the same frame. Keep a
-- monotonic signal so the steal watcher cannot miss that transition.
local function recordStealEggNewRagdollSignal(state)
	StealEggNewProtection.RagdollSignalVersion += 1
	StealEggNewProtection.LastRagdollStateName = state and state.Name or "PlatformStanding"
end

local function isStealEggNewRagdollState(state)
	return state == Enum.HumanoidStateType.FallingDown
		or state == Enum.HumanoidStateType.Ragdoll
		or state == Enum.HumanoidStateType.Physics
		or state == Enum.HumanoidStateType.PlatformStanding
end

local function disconnectStealEggNewProtection()
	for _, connection in ipairs(StealEggNewProtection.Connections) do
		pcall(function() connection:Disconnect() end)
	end
	StealEggNewProtection.Connections = {}
end

local function lockStealEggNewJoints(character)
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Motor6D") or descendant:IsA("BallSocketConstraint") or descendant:IsA("HingeConstraint") then
			pcall(function()
				if descendant:IsA("Motor6D") then
					descendant.Enabled = true
				else
					descendant.Enabled = false
				end
			end)
		end
	end
end

local function removeStealEggNewRagdollObjects(character)
	for _, descendant in ipairs(character:GetDescendants()) do
		local name = string.lower(descendant.Name)
		if name:find("ragdoll", 1, true) or name:find("physics", 1, true)
			or name:find("fling", 1, true) or name:find("knockback", 1, true)
			or name:find("pushback", 1, true) or name:find("stun", 1, true)
			or name:find("falling", 1, true) or name:find("fall", 1, true) then
			pcall(function() descendant:Destroy() end)
		end
	end
end

local function disableStealEggNewRagdollStates(humanoid)
	pcall(function()
		humanoid.BreakJointsOnDeath = false
		humanoid.RequiresNeck = false
		humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.StrafingNoPhysics, false)
	end)
end

local function applyStealEggNewProtection(character)
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then disableStealEggNewRagdollStates(humanoid) end
	removeStealEggNewRagdollObjects(character)
	lockStealEggNewJoints(character)

	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		table.insert(StealEggNewProtection.Connections, RunService.Heartbeat:Connect(function()
			if not root.Parent then return end
			if root.AssemblyLinearVelocity.Magnitude > 100 then
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
			end
			local parameters = RaycastParams.new()
			parameters.FilterType = Enum.RaycastFilterType.Exclude
			parameters.FilterDescendantsInstances = { character }
			local ground = Workspace:Raycast(root.Position, Vector3.new(0, -50, 0), parameters)
			if not ground and root.Position.Y > 500 then
				root.CFrame = CFrame.new(root.Position.X, 300, root.Position.Z)
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
			end
		end))
	end

	if humanoid then
		table.insert(StealEggNewProtection.Connections, humanoid.StateChanged:Connect(function(_, newState)
			if isStealEggNewRagdollState(newState) then
				recordStealEggNewRagdollSignal(newState)
			end
		end))
		table.insert(StealEggNewProtection.Connections, humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(function()
			if humanoid.PlatformStand then recordStealEggNewRagdollSignal(nil) end
		end))
		table.insert(StealEggNewProtection.Connections, RunService.Heartbeat:Connect(function()
			if not humanoid.Parent then return end
			local state = humanoid:GetState()
			if isStealEggNewRagdollState(state) or humanoid.PlatformStand then
				recordStealEggNewRagdollSignal(state)
				pcall(function()
					humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
					lockStealEggNewJoints(character)
				end)
			end
		end))
	end

	table.insert(StealEggNewProtection.Connections, character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("Motor6D") then
			task.defer(function() if descendant.Parent then descendant.Enabled = true end end)
		elseif (descendant:IsA("BallSocketConstraint") or descendant:IsA("HingeConstraint")) then
			local name = string.lower(descendant.Name)
			if name:find("ragdoll", 1, true) or name:find("physics", 1, true) then
				pcall(function() descendant:Destroy() end)
			end
		end
	end))

	table.insert(StealEggNewProtection.Connections, RunService.Stepped:Connect(function()
		if not character.Parent then return end
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.AssemblyLinearVelocity.Magnitude > 200 then
				part.AssemblyLinearVelocity = Vector3.zero
				part.AssemblyAngularVelocity = Vector3.zero
			end
		end
	end))
end

function StealEggNewProtection:Stop()
	disconnectStealEggNewProtection()
end

function StealEggNewProtection:Start()
	self:Stop()
	if LocalPlayer.Character then applyStealEggNewProtection(LocalPlayer.Character) end
	table.insert(self.Connections, LocalPlayer.CharacterAdded:Connect(function(character)
		if EggController.Config.UseStealEggNew then
			task.wait(.3)
			applyStealEggNewProtection(character)
		end
	end))
end

local function blockStealEggNewRagdollRemotes()
	if typeof(hookmetamethod) ~= "function" or typeof(getnamecallmethod) ~= "function" or typeof(newcclosure) ~= "function" then return end
	local hookState = Environment.__XyraxStealEggNewRagdollRemoteHook or {}
	Environment.__XyraxStealEggNewRagdollRemoteHook = hookState
	if hookState.Installed then return end
	local blockedNames = { ragdoll = true, fling = true, knockback = true, pushback = true, stun = true, physics = true, falling = true, launch = true, throw = true }
	local old
	pcall(function()
		old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
			LPH_ATTRIBUTES(VM(NONE))
			local method = getnamecallmethod()
			if method == "FireServer" or method == "InvokeServer" then
				local name = string.lower(tostring(self.Name))
				for keyword in pairs(blockedNames) do
					if name:find(keyword, 1, true) then return nil end
				end
			end
			return old(self, ...)
		end))
		hookState.Installed = true
	end)
end

-- Kept as doHumanoid so the preparation sequence is explicit in the flow.
local function doHumanoid()
	if isMobileDevice then
		log("StealEgg New: mobile detected; skipped Humanoid clone")
		return true
	end
	local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	local original = character and (character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10))
	if not original then return false end
	if original:GetAttribute("XyraxStealEggNewHumanoid") == true then return true end
	local cloned = nil
	local ok = pcall(function()
		original.Archivable = true
		cloned = original:Clone()
		cloned.WalkSpeed = original.WalkSpeed
		cloned.JumpPower = original.JumpPower
		cloned.MaxHealth = original.MaxHealth
		cloned.Health = original.Health
		cloned.AutoRotate = original.AutoRotate
		cloned:SetAttribute("BobloStealHum", true)
		cloned:SetAttribute("XyraxStealEggNewHumanoid", true)
		cloned.Parent = character
		task.wait(.05)
		original:Destroy()
		task.wait(.05)
		if Workspace.CurrentCamera then Workspace.CurrentCamera.CameraSubject = cloned end
	end)
	if ok and cloned and cloned.Parent then
		if not cloned:FindFirstChildOfClass("Animator") then
			pcall(function() Instance.new("Animator").Parent = cloned end)
		end
		rebindAnimate(character)
		return true
	end
	return false
end

function EggController.PrepareStealEggNew()
	if not EggController.Config.UseStealEggNew then return true end
	blockStealEggNewRagdollRemotes()
	-- Keep the requested order: anti-ragdoll first, then the Humanoid bypass.
	StealEggNewProtection:Start()
	local bypassed = doHumanoid()
	-- The clone replaces the old Humanoid in-place, so attach the state watcher
	-- to the fresh Humanoid as well.
	StealEggNewProtection:Start()
	return bypassed
end

local function prepareStealEggNewForCurrentCharacter()
	if stealEggNewPreparedEpoch == characterEpoch then return true end
	local prepared = EggController.PrepareStealEggNew()
	if prepared then stealEggNewPreparedEpoch = characterEpoch end
	return prepared
end
function EggController.NormalizeMovementCharacter(humanoid, character)
	if humanoid then
		humanoid.Sit, humanoid.PlatformStand = false, false
		local state = humanoid:GetState()
		if state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.FallingDown or state == Enum.HumanoidStateType.Physics then
			pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)
		end
	end
	if character then
		for _, descendant in ipairs(character:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant.CanCollide then
				descendant.CanCollide = false
			end
		end
	end
end

local function stealMoveTo(targetX, targetZ, heightOffset, exactY)
	local yOffset = typeof(heightOffset) == "number" and heightOffset or 0
	local deadline = tick() + EggController.MOVE_TIMEOUT
	while tick() < deadline do
		if not active() then return false end
		local root = getRoot()
		if not root then return false end
		EggController.NormalizeMovementCharacter(getHumanoid(), LocalPlayer.Character)
		local targetY = typeof(exactY) == "number" and exactY or (groundedY(targetX, targetZ, root.Position.Y) + yOffset)
		local destination = Vector3.new(targetX, targetY, targetZ)
		local offset = destination - root.Position
		local horizontalDist = Vector2.new(offset.X, offset.Z).Magnitude
		if horizontalDist <= EggController.ARRIVE_DISTANCE or offset.Magnitude <= 2.2 then
			anchor(root, CFrame.new(destination))
			return true
		end
		local dt = RunService.Heartbeat:Wait()
		if typeof(dt) ~= "number" or dt <= 0 then dt = 1 / 60 end
		root = getRoot()
		if not root then return false end
		targetY = typeof(exactY) == "number" and exactY or (groundedY(targetX, targetZ, root.Position.Y) + yOffset)
		destination = Vector3.new(targetX, targetY, targetZ)
		offset = destination - root.Position
		horizontalDist = Vector2.new(offset.X, offset.Z).Magnitude
		if horizontalDist <= EggController.ARRIVE_DISTANCE or offset.Magnitude <= 2.2 then
			anchor(root, CFrame.new(destination))
			return true
		end
		local speed = tonumber(EggController.Config.MoveSpeed) or 300
		local stepDist = math.min(offset.Magnitude, speed * dt)
		local nextPos = root.Position + offset.Unit * stepDist
		local nextGroundY = typeof(exactY) == "number" and exactY or (groundedY(nextPos.X, nextPos.Z, nextPos.Y) + yOffset)
		nextPos = Vector3.new(nextPos.X, nextGroundY, nextPos.Z)
		local horizontal = Vector3.new(offset.X, 0, offset.Z)
		anchor(root, horizontal.Magnitude > .05 and CFrame.lookAt(nextPos, nextPos + horizontal) or CFrame.new(nextPos))
	end
	local root = getRoot()
	if root then
		local flatDelta = Vector2.new(targetX - root.Position.X, targetZ - root.Position.Z).Magnitude
		if flatDelta <= 3.5 then
			anchor(root, CFrame.new(targetX, typeof(exactY) == "number" and exactY or root.Position.Y, targetZ))
			return true
		end
	end
	return false
end
local function buildStealPath(startPosition, targetPosition)
	local path = {}
	local directDelta = targetPosition - startPosition
	local directDist = Vector2.new(directDelta.X, directDelta.Z).Magnitude
	if directDist <= 60 then
		table.insert(path, Vector3.new(targetPosition.X, targetPosition.Y or laneY(), targetPosition.Z))
		return path
	end
	local corridorStart = clampToCorridor(startPosition)
	local corridorTarget = clampToCorridor(targetPosition)
	if (startPosition - corridorStart).Magnitude > 3 then table.insert(path, corridorStart) end
	if math.abs(corridorStart.X - corridorTarget.X) > 2 then table.insert(path, corridorTarget) end
	-- Leave the corridor only for the final interaction/base position.
	table.insert(path, Vector3.new(targetPosition.X, targetPosition.Y or laneY(), targetPosition.Z))
	return path
end

-- The deployed trap implementation uses a PlayerTrap object with a Hitbox.
-- Restrict scanning to Workspace objects so backpack/tool preview hitboxes are
-- not treated as hazards.
local function getActiveTrapHitboxes()
	local traps = {}
	for _, instance in ipairs(Workspace:GetDescendants()) do
		if instance.Name == "PlayerTrap" and instance:IsDescendantOf(Workspace) then
			local hitbox = instance:FindFirstChild("Hitbox")
			-- The trap module disables the deployed PlayerTrap's CanTouch after
			-- activation, so do not detour around an already-consumed trap.
			local touchable = not instance:IsA("BasePart") or instance.CanTouch ~= false
			if touchable and hitbox and hitbox:IsA("BasePart") and hitbox.Parent then
				table.insert(traps, hitbox)
			end
		end
	end
	return traps
end

local function segmentHitsTrap(fromPosition, toPosition, hitbox, padding)
	if not hitbox or not hitbox.Parent then return false end
	local a = hitbox.CFrame:PointToObjectSpace(fromPosition)
	local b = hitbox.CFrame:PointToObjectSpace(toPosition)
	local hx = math.abs(hitbox.Size.X) * .5 + padding
	local hz = math.abs(hitbox.Size.Z) * .5 + padding
	local tMin, tMax = 0, 1
	local function clip(origin, delta, extent)
		if math.abs(delta) < 1e-5 then return origin >= -extent and origin <= extent end
		local near, far = (-extent - origin) / delta, (extent - origin) / delta
		if near > far then near, far = far, near end
		tMin, tMax = math.max(tMin, near), math.min(tMax, far)
		return tMin <= tMax
	end
	return clip(a.X, b.X - a.X, hx) and clip(a.Z, b.Z - a.Z, hz)
end

local function detourAroundTrap(fromPosition, toPosition, hitbox, padding)
	local hx = math.abs(hitbox.Size.X) * .5 + padding
	local hz = math.abs(hitbox.Size.Z) * .5 + padding
	local corners = {
		Vector3.new(-hx, 0, -hz), Vector3.new(hx, 0, -hz),
		Vector3.new(hx, 0, hz), Vector3.new(-hx, 0, hz),
	}
	local candidates = {}
	for i = 1, 4 do
		local j = (i % 4) + 1
		local a = hitbox.CFrame:PointToWorldSpace(corners[i])
		local b = hitbox.CFrame:PointToWorldSpace(corners[j])
		local pa = Vector3.new(a.X, fromPosition.Y, a.Z)
		local pb = Vector3.new(b.X, fromPosition.Y, b.Z)
		table.insert(candidates, {pa, pb, (fromPosition - pa).Magnitude + (pa - pb).Magnitude + (pb - toPosition).Magnitude})
	end
	table.sort(candidates, function(left, right) return left[3] < right[3] end)
	return candidates[1][1], candidates[1][2]
end

local function avoidTrapsInPath(path)
	if typeof(path) ~= "table" or #path == 0 then return path end
	local root = getRoot()
	if not root then return path end
	local padding = math.max(math.abs(root.Size.X), math.abs(root.Size.Z)) * .5 + 2
	local traps = getActiveTrapHitboxes()
	if #traps == 0 then return path end
	local result, current = {}, root.Position
	for _, waypoint in ipairs(path) do
		local nextPoint = waypoint
		for _ = 1, 4 do
			local blocker
			for _, hitbox in ipairs(traps) do
				if segmentHitsTrap(current, nextPoint, hitbox, padding) then blocker = hitbox; break end
			end
			if not blocker then break end
			local detourA, detourB = detourAroundTrap(current, nextPoint, blocker, padding)
			table.insert(result, detourA)
			table.insert(result, detourB)
			current = detourB
			warnLog("Auto Avoid Trap: detour inserted")
		end
		table.insert(result, nextPoint)
		current = nextPoint
	end
	return result
end

local function stealAlong(path)
	for _, waypoint in ipairs(avoidTrapsInPath(path)) do
		if not stealMoveTo(waypoint.X, waypoint.Z, 0, waypoint.Y) then return false end
	end
	return true
end

local function tweenStealMoveTo(targetX, targetZ, targetY, speedOverride)
	local root = getRoot()
	if not root then return false end
	local resolvedY = typeof(targetY) == "number" and targetY or groundedY(targetX, targetZ, root.Position.Y)
	local targetPosition = Vector3.new(targetX, resolvedY, targetZ)
	local delta = targetPosition - root.Position
	local horizStartDist = Vector2.new(delta.X, delta.Z).Magnitude
	if horizStartDist <= EggController.ARRIVE_DISTANCE or delta.Magnitude <= 2.2 then
		anchor(root, CFrame.new(targetPosition))
		return true
	end
	local horizontal = Vector3.new(delta.X, 0, delta.Z)
	local targetCFrame = horizontal.Magnitude > .05
		and CFrame.lookAt(targetPosition, targetPosition + horizontal)
		or CFrame.new(targetPosition)
	local moveSpeed = tonumber(speedOverride) or tonumber(EggController.Config.MoveSpeed) or 1
	local duration = math.clamp(delta.Magnitude / math.max(1, moveSpeed), .08, EggController.MOVE_TIMEOUT)
	local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = targetCFrame })
	local completed = false
	local completionConnection = tween.Completed:Connect(function() completed = true end)
	tween:Play()
	while not completed do
		if not active() or root ~= getRoot() then
			tween:Cancel()
			completionConnection:Disconnect()
			return false
		end
		RunService.Heartbeat:Wait()
	end
	completionConnection:Disconnect()
	root = getRoot()
	if not root then return false end
	local finalDelta = root.Position - targetPosition
	local horizDelta = Vector2.new(finalDelta.X, finalDelta.Z).Magnitude
	if horizDelta > 4.5 and finalDelta.Magnitude > 6 then return false end
	anchor(root, targetCFrame)
	return true
end

local function tweenAlong(path)
	for _, waypoint in ipairs(avoidTrapsInPath(path)) do
		if not tweenStealMoveTo(waypoint.X, waypoint.Z, waypoint.Y) then return false end
	end
	return true
end
local function rawTeleport(position)
	local root = getRoot()
	if not root then return false end
	local targetPos = (typeof(position) == "CFrame" and position.Position) or (typeof(position) == "Vector3" and position)
	if not targetPos then return false end
	root.CFrame = CFrame.new(targetPos) * (root.CFrame - root.CFrame.Position)
	root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
	return true
end
local function restoreCharacterControl()
	local humanoid, root = getHumanoid(), getRoot()
	if root then
		root.Anchored = false
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
	if humanoid then
		humanoid.Sit = false
		humanoid.PlatformStand = false
		humanoid.AutoRotate = true
		humanoid:Move(Vector3.zero, false)
		pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Running) end)
		-- Handing control back has to include the animations.  Without this the
		-- character stays frozen in its steal pose on the treadmill.
		rebindAnimate(LocalPlayer.Character)
	end
end

-- The steal controller moves the root deliberately, so a character can retain
-- a Physics/FallingDown state or residual velocity after a carry finishes.
-- Before entering a treadmill, normalize only the local character rather than
-- respawning it (a respawn would discard a legitimately held egg).
local function resetCharacterForTreadmill()
	local character, humanoid, root = LocalPlayer.Character, getHumanoid(), getRoot()
	if not character or not humanoid or not root then return false end
	local state = humanoid:GetState()
	local expectedY = groundedY(root.Position.X, root.Position.Z, root.Position.Y)
	local abnormal = root.Anchored or humanoid.Sit or humanoid.PlatformStand
		or state == Enum.HumanoidStateType.Physics
		or state == Enum.HumanoidStateType.PlatformStanding
		or state == Enum.HumanoidStateType.FallingDown
		or math.abs(root.Position.Y - expectedY) > 6
	if abnormal then setState("ResettingCharacterForTreadmill") end
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
		end
	end
	humanoid.Sit = false
	humanoid.PlatformStand = false
	humanoid.AutoRotate = true
	humanoid:Move(Vector3.zero, false)
	pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)
	pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Running) end)
	return getRoot() ~= nil
end

-- Reversible client-side visual reduction.  It never touches gameplay state,
-- remotes, pets, or the user's saved settings.
local FPS_BOOST_RESTORE_KEY = "__XyraxStealEggFpsBoostRestore"
local fpsBoostRestore = typeof(Environment[FPS_BOOST_RESTORE_KEY]) == "table" and Environment[FPS_BOOST_RESTORE_KEY] or {}
Environment[FPS_BOOST_RESTORE_KEY] = fpsBoostRestore
function EggController.SetFpsBoostProperty(instance, property, value)
	if not instance then return end
	local saved = fpsBoostRestore[instance]
	if not saved then saved = {}; fpsBoostRestore[instance] = saved end
	if saved[property] == nil then
		local ok, original = pcall(function() return instance[property] end)
		if ok then saved[property] = original end
	end
	pcall(function() instance[property] = value end)
end
Environment.__XyraxFpsBoostConnections = typeof(Environment.__XyraxFpsBoostConnections) == "table" and Environment.__XyraxFpsBoostConnections or {}

function EggController.BoostVisualInstance(instance)
	if instance:IsA("ParticleEmitter") or instance:IsA("Trail") or instance:IsA("Beam")
		or instance:IsA("Smoke") or instance:IsA("Fire") or instance:IsA("Sparkles")
		or instance:IsA("Highlight") or instance:IsA("PointLight") or instance:IsA("SpotLight") or instance:IsA("SurfaceLight") then
		EggController.SetFpsBoostProperty(instance, "Enabled", false)
	elseif instance:IsA("BasePart") then
		EggController.SetFpsBoostProperty(instance, "CastShadow", false)
		if instance.Material ~= Enum.Material.SmoothPlastic and instance.Material ~= Enum.Material.Plastic then
			EggController.SetFpsBoostProperty(instance, "Material", Enum.Material.SmoothPlastic)
		end
	elseif instance:IsA("MeshPart") then
		EggController.SetFpsBoostProperty(instance, "CastShadow", false)
		if instance.Material ~= Enum.Material.SmoothPlastic and instance.Material ~= Enum.Material.Plastic then
			EggController.SetFpsBoostProperty(instance, "Material", Enum.Material.SmoothPlastic)
		end
	elseif instance:IsA("PostEffect") and instance.Name ~= "XyraxHubStatusBlur" then
		EggController.SetFpsBoostProperty(instance, "Enabled", false)
	elseif instance:IsA("Decal") or instance:IsA("Texture") then
		EggController.SetFpsBoostProperty(instance, "Transparency", 1)
	end
end

function EggController.SetFpsBoost(enabled)
	enabled = enabled == true
	EggController.Config.FpsBoostEnabled = enabled
	local activeConnections = Environment.__XyraxFpsBoostConnections
	for _, connection in ipairs(activeConnections) do
		pcall(function() connection:Disconnect() end)
	end
	table.clear(activeConnections)
	if not enabled then
		for instance, values in pairs(fpsBoostRestore) do
			if typeof(instance) == "Instance" then
				for property, original in pairs(values) do pcall(function() instance[property] = original end) end
			end
		end
		fpsBoostRestore = {}
		Environment[FPS_BOOST_RESTORE_KEY] = fpsBoostRestore
		return true
	end
	EggController.SetFpsBoostProperty(Lighting, "GlobalShadows", false)
	EggController.SetFpsBoostProperty(Lighting, "FogEnd", 100000)
	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		EggController.SetFpsBoostProperty(terrain, "WaterWaveSize", 0)
		EggController.SetFpsBoostProperty(terrain, "WaterWaveSpeed", 0)
		EggController.SetFpsBoostProperty(terrain, "WaterReflectance", 0)
	end
	for _, instance in ipairs(Workspace:GetDescendants()) do EggController.BoostVisualInstance(instance) end
	for _, instance in ipairs(Lighting:GetDescendants()) do EggController.BoostVisualInstance(instance) end

	local workspaceConn = Workspace.DescendantAdded:Connect(function(instance)
		if EggController.Config.FpsBoostEnabled then EggController.BoostVisualInstance(instance) end
	end)
	local lightingConn = Lighting.DescendantAdded:Connect(function(instance)
		if EggController.Config.FpsBoostEnabled then EggController.BoostVisualInstance(instance) end
	end)
	table.insert(activeConnections, workspaceConn)
	table.insert(activeConnections, lightingConn)
	return true
end

-- Forward declaration: treadmill code is defined before the carry-state helper.
-- Without this, Luau resolves the earlier reference as a global nil.
local isFieldCarrying
local deliverAndPlace
local function watchdogMarkProgress()
	watchdogLastProgressAt = os.clock()
	watchdogFailureCount = 0
	if os.clock() >= watchdogBackoffUntil then watchdogReason = nil end
end
local function watchdogReset()
	watchdogLastProgressAt = os.clock()
	watchdogFailureCount = 0
	watchdogBackoffUntil = 0
	watchdogReason = nil
	watchdogNeedsTreadmill = false
end
local function watchdogBeginBackoff(reason)
	if watchdogBackoffUntil > os.clock() then return end
	watchdogReason = reason
	watchdogFailureCount = 0
	watchdogBackoffUntil = os.clock() + math.max(3, tonumber(EggController.Config.WatchdogBackoffSeconds) or 15)
	watchdogNeedsTreadmill = true
	log("Watchdog: backing off for " .. math.ceil(watchdogBackoffUntil - os.clock()) .. "s (" .. reason .. ")")
	if EggController.StopTreadmillTraining then EggController.StopTreadmillTraining() end
	restoreCharacterControl()
end
local function watchdogReportFailure(reason)
	if EggController.Config.WatchdogEnabled ~= true or watchdogBackoffUntil > os.clock() then return end
	-- A held egg is more valuable than a reset attempt; its normal recovery path
	-- gets the next chance to return it before watchdog recovery is considered.
	if isFieldCarrying and isFieldCarrying() then return end
	watchdogFailureCount += 1
	watchdogReason = reason .. " (" .. watchdogFailureCount .. "/" .. (tonumber(EggController.Config.WatchdogFailureLimit) or 4) .. ")"
	if watchdogFailureCount >= math.max(1, tonumber(EggController.Config.WatchdogFailureLimit) or 4) then
		watchdogBeginBackoff(reason)
	end
end
local function watchdogTick()
	if EggController.Config.WatchdogEnabled ~= true then return false end
	local now = os.clock()
	if now < watchdogBackoffUntil then
		setState("WatchdogBackoff")
		return true
	end
	if watchdogNeedsTreadmill then
		watchdogNeedsTreadmill = false
		restoreCharacterControl()
		if EggController.Config.AutoTreadmillWhenIdle then
			setState("WatchdogRecovery")
			EggController.RunTreadmillTraining()
		end
		watchdogMarkProgress()
		return true
	end
	if EggController.Config.AutoStealEnabled and not treadmillTraining
		and EggController.State ~= "Idle" and now - watchdogLastProgressAt >= (tonumber(EggController.Config.WatchdogNoProgressSeconds) or 180) then
		watchdogLastProgressAt = now
		watchdogReportFailure("No farm progress")
	end
	return false
end
local function stageAtHomeForTreadmill()
	local root = getRoot()
	if not root then return false end
	local ok, respawn = pcall(PlotState.FindRespawnCFrame)
	local home = ok and typeof(respawn) == "CFrame" and respawn.Position or nil
	if not home then return false end
	-- Do not enter a distant treadmill directly.  The game's movement checks can
	-- pull the character back when the belt is equipped from far away.  Stage at
	-- the owner's home first, then use the regular movement routine to the belt.
	if (root.Position - home).Magnitude > 10 then
		setState("ReturningHomeForTreadmill")
		if not stealAlong(buildStealPath(root.Position, home)) then
			if not rawTeleport(Vector3.new(home.X, home.Y + 2, home.Z)) then return false end
		end
		root = getRoot()
		if root then anchor(root, CFrame.new(home.X, home.Y + 2, home.Z)) end
		task.wait(.1)
	end
	return getRoot() ~= nil
end
local function getTreadmillStandPosition()
	local plot = EggController.GetLocalPlayerPlot()
	local treadmill = plot and plot.PlotFolder and plot.PlotFolder:FindFirstChild("TreadmillBottom") or nil
	return treadmill and treadmill:IsA("BasePart") and treadmill.Position + Vector3.new(0, 4, 0) or nil
end
local function treadmillCharacterCheck(stand)
	local humanoid, root = getHumanoid(), getRoot()
	if not humanoid or not root then return false, "missing character" end
	if humanoid.Health <= 0 then return false, "humanoid has no health" end
	if root.Anchored then return false, "root is anchored" end
	if humanoid.Sit or humanoid.PlatformStand then return false, "humanoid is locked" end
	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Physics or state == Enum.HumanoidStateType.PlatformStanding
		or state == Enum.HumanoidStateType.FallingDown then
		return false, "humanoid physics state is stuck"
	end
	if typeof(stand) == "Vector3" then
		local offset = root.Position - stand
		local horizontal = Vector3.new(offset.X, 0, offset.Z).Magnitude
		if horizontal > 8 or math.abs(offset.Y) > 9 then
			return false, "character is outside treadmill stand"
		end
	end
	return true
end
local function isTreadmillHudVisible()
	local ok, visible = pcall(function()
		local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
		local elements = playerGui and playerGui:FindFirstChild("Elements")
		local left = elements and elements:FindFirstChild("Left")
		local tools = left and left:FindFirstChild("Tools")
		local doubleSpeed = tools and tools:FindFirstChild("DoubleYourSpeed")
		return doubleSpeed ~= nil and doubleSpeed.Visible == true
	end)
	return ok and visible == true
end
local function isTreadmillLikelyActive()
	-- Do not accept an early nil AssignedBeltShifted event as a rejection.  The
	-- game can send that stale clear event before the successful wear state and
	-- its treadmill HUD replicate.  The old ordering checked it first, so the
	-- controller cleared the treadmill after only a few frames.
	if os.clock() < treadmillRequestGraceUntil then return true end
	if treadmillAssignmentKnown then return treadmillAssigned end
	return isTreadmillHudVisible()
end

local function getTreadmillSpeedPower()
	local save = getSave()
	local speedPower = save and tonumber(save.SpeedPower)
	return speedPower
end

local function resetTreadmillSpeedMonitor()
	treadmillLastSpeedPower = nil
	treadmillSpeedFailureCount = 0
	treadmillHopRequested = false
end

local function hopServerForTreadmillFailure()
	if treadmillHopRequested then return true end
	treadmillHopRequested = true
	log("Treadmill SpeedPower did not increase after " .. tostring(EggController.Config.TreadmillSpeedFailureLimit or 10) .. " checks; finding a new server")

	-- TeleportToPlaceInstance only confirms that Roblox accepted the *request*.
	-- It does not mean the player joined; a full server subsequently raises 772.
	-- Stay in this worker until the process leaves for a successful destination.
	task.spawn(function()
		local triedServerIds = {}
		local retryDelay = math.max(1, tonumber(EggController.Config.TreadmillHopRetryDelay) or 3)
		local attemptWait = math.max(3, tonumber(EggController.Config.TreadmillHopAttemptWait) or 8)
		while treadmillHopRequested and EggController.Config.TreadmillHopOnSpeedFailure do
			setState("HoppingServerForTreadmill")
			local candidates = {}
			local cursor = nil
			-- Search several pages: the first page can be stale or entirely full.
			for _ = 1, 4 do
				local endpoint = "https://games.roblox.com/v1/games/" .. tostring(game.PlaceId)
					.. "/servers/Public?sortOrder=Asc&limit=100"
				if typeof(cursor) == "string" and cursor ~= "" then
					endpoint ..= "&cursor=" .. HttpService:UrlEncode(cursor)
				end
				local requestOk, body = safeHttpGet(endpoint)
				local decodedOk, payload = false, nil
				if requestOk and typeof(body) == "string" then
					decodedOk, payload = pcall(function() return HttpService:JSONDecode(body) end)
				end
				local servers = decodedOk and typeof(payload) == "table" and payload.data
				if typeof(servers) ~= "table" then break end
				for _, server in ipairs(servers) do
					local serverId = typeof(server) == "table" and server.id or nil
					local playing = tonumber(typeof(server) == "table" and server.playing) or 0
					local maxPlayers = tonumber(typeof(server) == "table" and server.maxPlayers) or 0
					if typeof(serverId) == "string" and serverId ~= game.JobId
						and not triedServerIds[serverId] and playing < maxPlayers then
						table.insert(candidates, server)
					end
				end
				cursor = payload.nextPageCursor
				if typeof(cursor) ~= "string" or cursor == "" then break end
			end
			table.sort(candidates, function(left, right)
				return (tonumber(left.playing) or math.huge) < (tonumber(right.playing) or math.huge)
			end)

			if #candidates == 0 then
				-- All cached candidates may have become full. Clear the cache and poll
				-- again instead of ending the hop after a single unsuccessful pass.
				triedServerIds = {}
				warnLog("Server hop: no open server yet; retrying in " .. tostring(retryDelay) .. "s")
				task.wait(retryDelay)
			else
				local server = candidates[1]
				triedServerIds[server.id] = true
				log("Server hop attempt: " .. tostring(server.playing) .. "/" .. tostring(server.maxPlayers))
				local dispatched, dispatchError = pcall(function()
					TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
				end)
				if not dispatched then
					warnLog("Server hop dispatch failed: " .. tostring(dispatchError))
					task.wait(retryDelay)
				else
					-- On success this script ends as the client changes instance. If it
					-- remains here (including error 772), try a different server next.
					task.wait(attemptWait)
					if treadmillHopRequested then
						warnLog("Server hop did not complete; trying another server")
						task.wait(retryDelay)
					end
				end
			end
		end
		treadmillHopRequested = false
	end)
	return true
end

local function clearTreadmillWearForRetry()
	treadmillTraining = false
	treadmillAssignmentKnown, treadmillAssigned, treadmillRequestGraceUntil = true, false, 0
	if TreadmillUnequipRemote then callRemote(TreadmillUnequipRemote) end
	local humanoid = getHumanoid()
	if humanoid then
		humanoid.Jump = true
		pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end)
	end
	restoreCharacterControl()
end

local function requestTreadmillEquip()
	if not TreadmillEquipRemote then return false end
	-- stealegg.lua deliberately treats a completed InvokeServer call as the
	-- request succeeding.  AskWearStill can reply false/nil while the belt
	-- assignment is still replicated through AssignedBeltShifted afterwards.
	if TreadmillEquipRemote:IsA("RemoteFunction") then
		return pcall(function() TreadmillEquipRemote:InvokeServer() end)
	end
	return callRemote(TreadmillEquipRemote)
end
function EggController.StopTreadmillTraining()
	clearTreadmillWearForRetry()
	resetTreadmillSpeedMonitor()
	nextTreadmillCheckAt = 0
end
local function leaveTreadmillForAction(actionName)
	-- Mirror stealegg.lua's scheduler: no unrelated remote is sent while the
	-- treadmill is worn.  The game rejects PetSatchel/other actions in that state.
	if treadmillTraining or isTreadmillHudVisible() then
		log("Stopping treadmill for " .. actionName)
		EggController.StopTreadmillTraining()
		task.wait(.2)
		-- Let AskDoff replicate before idle logic can request AskWearStill again.
		nextTreadmillCheckAt = os.clock() + 1.2
		return true
	end
	return false
end

function EggController.RunTreadmillTraining()
	if isFieldCarrying() or pendingEggUid or not TreadmillEquipRemote then return false end
	local stand = getTreadmillStandPosition()
	if not stand then return false end
	local root = getRoot()
	if not root then return false end
	-- An assigned belt alone is not enough: a carry can leave the local character
	-- floating or physics-locked while the server still reports the old belt.
	if treadmillTraining then
		local healthy, reason = treadmillCharacterCheck(stand)
		if healthy then
			treadmillTraining = true
			return true
		end
		log("Treadmill character check failed: " .. tostring(reason) .. "; re-entering belt")
		clearTreadmillWearForRetry()
		task.wait(.25)
	end
	if not resetCharacterForTreadmill() then
		warnLog("Treadmill: character reset preparation failed")
		return false
	end
	if not stageAtHomeForTreadmill() then
		warnLog("Treadmill: could not return to home before entering the belt")
		return false
	end
	-- Always finish with normal corridor movement onto the belt, even when the
	-- root appears nearby.  This clears a floating position left from stealing.
	root = getRoot()
	if not root or not stealMoveTo(stand.X, stand.Z, 0, stand.Y) then
		if root and (root.Position - stand).Magnitude <= 12 then
			anchor(root, CFrame.new(stand))
		else
			warnLog("Treadmill: could not reach the treadmill stand position")
			return false
		end
	end
	if not resetCharacterForTreadmill() then
		warnLog("Treadmill: character reset after staging failed")
		return false
	end
	setState("Treadmill")
	treadmillAssignmentKnown, treadmillAssigned = false, false
	-- Allow the server assignment and its native treadmill UI enough time to
	-- replicate, particularly after returning from a stolen-egg trip.
	treadmillRequestGraceUntil = os.clock() + 8
	treadmillTraining = requestTreadmillEquip()
	if not treadmillTraining then treadmillRequestGraceUntil = 0 end
	if treadmillTraining then
		if treadmillLastSpeedPower == nil then
			treadmillLastSpeedPower = getTreadmillSpeedPower()
			treadmillSpeedFailureCount = 0
			treadmillHopRequested = false
		end
		nextTreadmillCheckAt = os.clock() + math.max(1, tonumber(EggController.Config.TreadmillSpeedCheckSeconds) or 5)
	else
		nextTreadmillCheckAt = os.clock() + 1.2
	end
	if treadmillTraining then
		log("Treadmill equip requested")
	else
		warnLog("Treadmill equip dispatch failed")
		watchdogReportFailure("Treadmill equip request failed")
	end
	return treadmillTraining
end

function EggController.GetHeldEgg()
	if typeof(heldCarryState) == "table" and heldCarryState.IsCarrying == true and typeof(heldCarryState.Uid) == "string" then
		return { Uid = heldCarryState.Uid, Record = getOwnedEgg(heldCarryState.Uid), Source = "CarryState" }
	end
	local character = LocalPlayer.Character
	for _, child in ipairs(character and character:GetChildren() or {}) do
		if child:IsA("Tool") then
			local isEgg, eggTool = pcall(EggToolDisplay.IsEggTool, child)
			if isEgg and eggTool then
				local hasUid, uid = pcall(EggToolDisplay.GetToolUid, child)
				if hasUid and typeof(uid) == "string" and uid ~= "" then return { Uid = uid, Record = getOwnedEgg(uid), Source = "EquippedTool" } end
			end
			local toolUid = child:GetAttribute("UID")
			if typeof(toolUid) == "string" and toolUid ~= "" then
				return { Uid = toolUid, Record = getOwnedEgg(toolUid), Source = "ToolAttribute" }
			end
		end
	end
	return nil
end
function EggController.IsHoldingEgg() return EggController.GetHeldEgg() ~= nil end
isFieldCarrying = function(uid)
	if typeof(heldCarryState) == "table" and heldCarryState.IsCarrying == true and (not uid or heldCarryState.Uid == uid) then
		return true
	end
	local held = EggController.GetHeldEgg()
	if held and (not uid or held.Uid == uid) then
		local owned = getOwnedEgg(held.Uid)
		if not owned or owned.Placement == nil then
			return true
		end
	end
	return false
end

-- Zero-death policy: Suicide reset removed entirely.
-- Any carried egg (staging or target) safely returns to base without ever resetting or killing the character.
local function abandonNonTargetStagingCarry(uid)
	return false
end

local function firstAreaSlotKey(record)
	if not record then return nil end
	local isFirstAreaUid = SlotIdentity.LooksLikeFirstAreaUid or SlotIdentity.IsFirstAreaUid
	local buildSlotKey = SlotIdentity.SlotKey or SlotIdentity.BuildSlotKey
	if typeof(isFirstAreaUid) == "function" and isFirstAreaUid(record.Uid) then
		local nestIdentifier = record.NestId or record.Slot or record.NestIndex or record.Index
		if typeof(buildSlotKey) == "function" and record.AreaId and nestIdentifier then
			local okBuild, keyString = pcall(buildSlotKey, record.AreaId, nestIdentifier)
			if okBuild and typeof(keyString) == "string" and keyString ~= "" then return keyString end
		end
	end
	return nil
end
local function nativeCarrySettleDelay()
	return Workspace:GetAttribute("FastEggPickupTime") and .15 or .25
end
local function tryCarry(target)
	if not target then return false end
	local valid, record = EggController.IsValidEgg(target.Egg)
	local root, position = getRoot(), EggController.GetEggPosition(target.Egg)
	local targetUid = tostring(target and target.Uid or "nil")
	local distance = root and position and (root.Position - position).Magnitude or nil
	local maximumDistance = math.max(20, tonumber(EggController.CARRY_RANGE) or 20)
	if not valid or not root or not position or not distance or distance > maximumDistance then
		stealDebug("carry-precheck:" .. targetUid, "pickup precheck: uid=" .. targetUid .. " valid=" .. tostring(valid) .. " distance=" .. tostring(distance), 1)
		return false
	end
	if record.Uid ~= target.Uid then
		stealDebug("carry-uid:" .. targetUid, "pickup UID mismatch: expected=" .. targetUid .. " actual=" .. tostring(record.Uid), 1)
		return false
	end
	local slotKey = firstAreaSlotKey(record)
	local firstAreaSlotKey = (slotKey and slotKey ~= "") and slotKey or nil
	stealDebug("carry-attempt:" .. targetUid, "attempting pickup: uid=" .. targetUid .. " distance=" .. string.format("%.2f", distance) .. " firstAreaSlotKey=" .. tostring(firstAreaSlotKey ~= nil), .75)
	local ok, accepted, detail = pcall(EggState.CarryFieldEgg, record.Uid, firstAreaSlotKey)
	if not ok or accepted == false then
		stealDebug("carry-result:" .. targetUid, "pickup rejected: uid=" .. targetUid .. " callOk=" .. tostring(ok) .. " accepted=" .. tostring(accepted) .. " detail=" .. tostring(detail), .75)
		return false
	end
	stealDebug("carry-result:" .. targetUid, "pickup accepted: uid=" .. targetUid .. "; waiting for CarryChanged", .75)
	return true
end

-- A carry request can be accepted before CarryChanged replicates. Poll only
-- briefly and require the exact staging UID; never continue with another egg.
local function waitForExactStagingCarry(stagingTarget)
	local deadline = tick() + .75
	while tick() < deadline and active() do
		local held = EggController.GetHeldEgg()
		if held then
			local record = getFieldRecord(held.Uid) or held.Record
			local actualName = record and getEggDisplayName(record) or "Unknown"
			local actualRarity = record and resolveRarity(record) or "Unknown"
			if held.Uid == stagingTarget.Uid or actualName == stagingTarget.Name or actualRarity == stagingTarget.Rarity then
				log("Staging carry verified: " .. actualName .. " [" .. actualRarity .. "] | uid=" .. held.Uid)
				return "staging", held.Uid
			end
			if record and EggController.PendingTargetCategory == record.AssetCategory then
				log("Recovered pending target while checking staging: " .. actualName .. " [" .. actualRarity .. "] | uid=" .. held.Uid)
				return "target", held.Uid
			end
			log("Staging carry accepted with rebound uid: " .. actualName .. " [" .. actualRarity .. "] | uid=" .. tostring(held.Uid))
			return "staging", held.Uid
		end
		task.wait(.01)
	end
	if isFieldCarrying() then
		local held = EggController.GetHeldEgg()
		local heldUid = held and held.Uid or stagingTarget.Uid
		return "staging", heldUid
	end
	warnLog("Staging carry did not replicate for " .. stagingTarget.Name .. " [" .. stagingTarget.Rarity .. "] uid=" .. stagingTarget.Uid)
	return nil, nil
end
function EggController.StealEgg(target)
	if not target or isFieldCarrying() or not swapStealHumanoid() then return false, nil end
	local root, position = getRoot(), EggController.GetEggPosition(target.Egg)
	if not root or not position then return false, nil end
	if not stealAlong(buildStealPath(root.Position, position)) then
		return false, nil
	end
	root = getRoot()
	if root then
		local groundLevel = groundedY(position.X, position.Z, position.Y)
		anchor(root, CFrame.new(position.X, groundLevel, position.Z))
	end
	local settleDelay = nativeCarrySettleDelay()
	stealDebug("carry-settle:" .. target.Uid, "at egg; waiting " .. tostring(settleDelay) .. "s for native pickup/position replication", .5)
	task.wait(settleDelay)
	local carried, carriedUid, untilTime = false, nil, tick() + 2.5
	while tick() < untilTime and active() do
		tryCarry(target)
		if isFieldCarrying(target.Uid) then
			carried, carriedUid = true, target.Uid
			break
		end
		local held = EggController.GetHeldEgg()
		if held and isFieldCarrying(held.Uid) then
			carried, carriedUid = true, held.Uid
			break
		end
		task.wait(.05)
	end
	task.wait(.1)
	return carried, carried and (carriedUid or target.Uid) or nil
end

-- This is deliberately a synchronous, short-lived poll rather than a spawned
-- loop: it cannot survive into a later steal attempt or stack up over time.
local function isRagdolled(humanoid)
	if not humanoid then return false end
	local state = humanoid:GetState()
	return humanoid.PlatformStand
		or humanoid.Sit
		or state == Enum.HumanoidStateType.Ragdoll
		or state == Enum.HumanoidStateType.Physics
		or state == Enum.HumanoidStateType.FallingDown
		or state == Enum.HumanoidStateType.PlatformStanding
end

local function forceClearRagdoll(humanoid)
	if not humanoid then return end
	local character = humanoid.Parent or LocalPlayer.Character
	pcall(function()
		humanoid.PlatformStand = false
		humanoid.Sit = false
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end)
	if character then
		pcall(function()
			for attributeName, _ in pairs(character:GetAttributes()) do
				local lower = string.lower(attributeName)
				if lower:find("knock", 1, true) or lower:find("ragdoll", 1, true) or lower:find("stun", 1, true) or lower:find("fall", 1, true) or lower:find("down", 1, true) then
					character:SetAttribute(attributeName, false)
				end
			end
			for attributeName, _ in pairs(humanoid:GetAttributes()) do
				local lower = string.lower(attributeName)
				if lower:find("knock", 1, true) or lower:find("ragdoll", 1, true) or lower:find("stun", 1, true) or lower:find("fall", 1, true) or lower:find("down", 1, true) then
					humanoid:SetAttribute(attributeName, false)
				end
			end
			for attributeName, _ in pairs(LocalPlayer:GetAttributes()) do
				local lower = string.lower(attributeName)
				if lower:find("knock", 1, true) or lower:find("ragdoll", 1, true) or lower:find("stun", 1, true) or lower:find("fall", 1, true) or lower:find("down", 1, true) then
					LocalPlayer:SetAttribute(attributeName, false)
				end
			end
		end)
		removeStealEggNewRagdollObjects(character)
		lockStealEggNewJoints(character)
	end
	local root = getRoot()
	if root then
		pcall(function()
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end)
	end
end

local function startStagingRagdollWatcher(timeout)
	local watcher = {
		Cancelled = false,
		Detected = false,
		Expired = false,
		StateName = "Unknown",
		SignalVersionAtStart = StealEggNewProtection.RagdollSignalVersion or 0,
	}
	local deadline = tick() + math.max(0, tonumber(timeout) or 60)
	task.spawn(function()
		while tick() < deadline and active() and not watcher.Cancelled do
			local humanoid = getHumanoid()
			if humanoid and isRagdolled(humanoid) then
				watcher.StateName = humanoid:GetState().Name
				watcher.Detected = true
				return
			end
			if (StealEggNewProtection.RagdollSignalVersion or 0) > watcher.SignalVersionAtStart then
				watcher.StateName = StealEggNewProtection.LastRagdollStateName or "Unknown"
				watcher.Detected = true
				return
			end
			task.wait(.01)
		end
		if active() and not watcher.Cancelled then watcher.Expired = true end
	end)
	return watcher
end

local function waitForStagingRagdollWatcher(watcher)
	while active() and not watcher.Detected and not watcher.Expired do task.wait(.01) end
	watcher.Cancelled = true
	if not active() then return nil end
	if watcher.Detected then
		return true
	end
	return false
end

local function waitForRagdollRecovery(timeout)
	local deadline = tick() + math.max(1, tonumber(timeout) or 4)
	while tick() < deadline do
		if not active() then return false end
		local humanoid = getHumanoid()
		if humanoid then
			forceClearRagdoll(humanoid)
			if not isRagdolled(humanoid) then
				pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Running) end)
				return true
			end
		end
		task.wait(.05)
	end
	local hum = getHumanoid()
	if hum then forceClearRagdoll(hum) end
	return false
end

-- The requested two-egg sequence: pick up the staging egg, then poll for the
-- guard ragdoll. Ragdoll causes an immediate target teleport. A timeout ends
-- the attempt; staging eggs are never treated as successful steals.
function EggController.StealEggNewStagingThenTarget(stagingTarget, target)
	if not target or not swapStealHumanoid() then return false, nil end
	local root = getRoot()
	if not root then return false, nil end

	-- 1. Determine staging position where the guard / pet patrol is located
	local stagingPosition = stagingTarget and EggController.GetEggPosition(stagingTarget.Egg)
	if not stagingPosition then
		local cframes = EggController.Config.StealEggNewStagingCFrames
		local firstCf = (typeof(cframes) == "table" and cframes[1]) or EggController.Config.StealEggNewStagingCFrame
		stagingPosition = (typeof(firstCf) == "CFrame" and firstCf.Position) or Vector3.new(739.469, 70.574, -408.801)
	end

	-- 2. Move to staging guard area
	setState("MovingToStagingEgg")
	log("StealEgg New: moving to staging area for guard aggro")
	local pathToStaging = buildStealPath(root.Position, stagingPosition)
	if not tweenAlong(pathToStaging) then
		return false, nil
	end
	root = getRoot()
	if root then
		anchor(root, CFrame.new(stagingPosition.X, groundedY(stagingPosition.X, stagingPosition.Z, stagingPosition.Y), stagingPosition.Z))
	end

	-- 3. Trigger guard strike & watch for hit ("ให้สัตว์มันตี")
	setState("StealingStagingEgg")
	local ragdollWatcher = startStagingRagdollWatcher(EggController.Config.StealEggNewPreTeleportDelay or 3)
	if stagingTarget and stagingTarget.Uid then
		pcall(function() EggState.CarryFieldEgg(stagingTarget.Uid) end)
	end

	local hitDeadline = tick() + math.max(1.5, tonumber(EggController.Config.StealEggNewPreTeleportDelay) or 2.5)
	while tick() < hitDeadline and active() do
		local hum = getHumanoid()
		if hum and isRagdolled(hum) then
			break
		end
		if ragdollWatcher and ragdollWatcher.Detected then
			break
		end
		task.wait(0.05)
	end
	if ragdollWatcher then ragdollWatcher.Cancelled = true end

	-- 4. Warp directly to configured target egg ("แล้วเราวาปไปที่ใข่ที่เราจะเอา")
	local targetPosition = EggController.GetEggPosition(target.Egg)
	if not targetPosition then return false, nil end
	local targetGround = groundedY(targetPosition.X, targetPosition.Z, targetPosition.Y)
	local warpDestination = Vector3.new(targetPosition.X, targetGround, targetPosition.Z)

	setState("TeleportingToConfiguredEgg")
	log("StealEgg New: warped to target egg " .. target.Name)
	if not rawTeleport(warpDestination) then
		return false, nil
	end

	root = getRoot()
	if root then
		anchor(root, CFrame.new(warpDestination))
	end

	-- 5. At target egg: wait for knockdown recovery and pick up target ("แล้วหยิบใข่")
	setState("StealingConfiguredEgg")
	log("StealEgg New: picking up target egg " .. target.Name)

	local carried, carriedUid = false, nil
	local pickupDeadline = tick() + 8.0
	while tick() < pickupDeadline and active() do
		local currentHum = getHumanoid()
		if currentHum then
			forceClearRagdoll(currentHum)
		end

		tryCarry(target)

		if isFieldCarrying(target.Uid) then
			carried, carriedUid = true, target.Uid
			break
		end
		local held = EggController.GetHeldEgg()
		if held and isFieldCarrying(held.Uid) then
			carried, carriedUid = true, held.Uid
			break
		end
		task.wait(0.2)
	end

	return carried, carried and (carriedUid or target.Uid) or nil
end

function EggController.GetLocalPlayerPlot()
	local ok, plot = pcall(PlotState.ResolvePlot)
	if not ok or typeof(plot) ~= "table" or typeof(plot.Slot) ~= "number" then return nil end
	if PlotState.LookupOwner(plot.Slot) ~= LocalPlayer.UserId then return nil end
	if not (plot.PetArea and plot.PetArea:IsA("BasePart") and plot.CenterPoint and plot.CenterPoint:IsA("BasePart")) then return nil end
	return plot
end
local function getBasePosition()
	local ok, cframe = pcall(PlotState.FindRespawnCFrame)
	if ok and typeof(cframe) == "CFrame" then return cframe.Position end
	local plot = EggController.GetLocalPlayerPlot()
	return plot and (plot.CenterPoint.Position or plot.PetArea.Position) or nil
end

local function getStealEggNewReturnTarget()
	local ok, cframe = pcall(PlotState.FindRespawnCFrame)
	if ok and typeof(cframe) == "CFrame" then return cframe end
	local plot = EggController.GetLocalPlayerPlot()
	return plot and plot.PetArea and (plot.PetArea.CFrame + Vector3.new(0, 4, 0)) or nil
end

function EggController.ReturnToBaseWithEgg(uid)
	local base, root = getBasePosition(), getRoot()
	if not root or not isFieldCarrying(uid) then return false end
	local tripEpoch = characterEpoch
	if not swapStealHumanoid() then return false end
	-- Once the final target has been taken, use the same return route as the
	-- normal steal flow.  The staging/ragdoll routine must not affect delivery.
	if not base then return false end
	-- The respawn point can be outside the pen.  A carried egg is released only
	-- after entering the actual PetArea, so make that the delivery destination.
	local plot = EggController.GetLocalPlayerPlot()
	local deliveryTarget = plot and plot.PetArea and plot.PetArea.Position or base
	root = getRoot()
	if characterEpoch ~= tripEpoch or not root or not isFieldCarrying(uid) then return false end
	log("Carry confirmed; using normal steal return to base")
	local returnWaypoints = avoidTrapsInPath(buildStealPath(root.Position, deliveryTarget))
	for _, waypoint in ipairs(returnWaypoints) do
		-- Grounded movement is required here: flying above the pen does not trigger
		-- the server-side field-carry release.
		if not stealMoveTo(waypoint.X, waypoint.Z, 0) then return false end
		if not isFieldCarrying(uid) and characterEpoch == tripEpoch then
			local droppedEgg = slotsFolder() and slotsFolder():FindFirstChild(uid)
			if droppedEgg then
				tryCarry({ Egg = droppedEgg, Uid = uid })
			end
		end
	end
	task.wait(EggController.CORRIDOR_STEP_DELAY)
	return characterEpoch == tripEpoch and (isFieldCarrying(uid) or isInsidePetArea() or atOwnPlot())
end
local function atOwnPlot()
	local root = getRoot()
	if not root then return false end
	local ok, inside = pcall(PlotState.ContainsLocalPoint, root.Position)
	return ok and inside == true
end
local function ensureAtPlot()
	if atOwnPlot() then return true end
	local plot = EggController.GetLocalPlayerPlot()
	return plot and rawTeleport(plot.PetArea.Position + Vector3.new(0, 4, 0)) or false
end
local function isInsidePetArea()
	local root, plot = getRoot(), EggController.GetLocalPlayerPlot()
	local area = plot and plot.PetArea
	if not root or not area then return false end
	local localPosition = area.CFrame:PointToObjectSpace(root.Position)
	local half = area.Size * .5 + Vector3.new(4, 10, 4)
	return math.abs(localPosition.X) <= half.X and math.abs(localPosition.Z) <= half.Z
		and math.abs(localPosition.Y) <= half.Y
end
local function ensureInsidePetArea()
	if isInsidePetArea() then return true end
	local plot = EggController.GetLocalPlayerPlot()
	if not plot then return false end
	setState("MovingIntoPetArea")
	if not rawTeleport(plot.PetArea.Position + Vector3.new(0, 4, 0)) then return false end
	task.wait(.12)
	return isInsidePetArea()
end
function EggController.GetPlacementLocalCFrames()
	local plot = EggController.GetLocalPlayerPlot()
	if not plot then return {} end
	local placements, halfSize = {}, plot.PetArea.Size * .5
	for x = -halfSize.X + EggController.Config.PlacementInset, halfSize.X - EggController.Config.PlacementInset, EggController.Config.PlacementSpacing do
		for z = -halfSize.Z + EggController.Config.PlacementInset, halfSize.Z - EggController.Config.PlacementInset, EggController.Config.PlacementSpacing do
			local world = plot.PetArea.CFrame:PointToWorldSpace(Vector3.new(x, 1, z))
			table.insert(placements, plot.CenterPoint.CFrame:ToObjectSpace(CFrame.new(world)))
		end
	end
	return placements
end
function EggController.GetAvailableEggSlot()
	return EggController.GetPlacementLocalCFrames()[1]
end
function EggController.GetEggPlacementLocation() return EggController.GetAvailableEggSlot() end
local function isSelectedEggRecord(record, uid)
	-- A Rift acquisition is matched by its authoritative AssetCategory.  It is
	-- the only case allowed to bypass the user's normal rarity switches.
	if RiftRuntime.Mode and uid == RiftRuntime.RewardUid then return true end
	if RiftRuntime.Mode and typeof(record) == "table" and record.AssetCategory == RiftRuntime.TargetCategory then
		return true
	end
	local rarity = resolveRarity(record)
	return EggController.ALLOWED_RARITIES[rarity] == true and EggController.Config.SelectedRarities[rarity] == true
end
function EggController.GetSelectedUnplacedEggUids()
	local result = {}
	for uid, record in pairs(getOwnedEggs()) do
		if typeof(uid) == "string" and typeof(record) == "table" and record.Placement == nil and isSelectedEggRecord(record, uid) then
			table.insert(result, uid)
		end
	end
	table.sort(result)
	return result
end
function EggController.PlaceEgg(uid)
	leaveTreadmillForAction("PlaceEgg")
	local targetUid = uid
	local record = targetUid and getOwnedEgg(targetUid) or nil
	if not record then
		local held = EggController.GetHeldEgg()
		if held and held.Uid then
			targetUid = held.Uid
			record = getOwnedEgg(targetUid) or held.Record
		end
	end
	if not record then
		for ownedUid, ownedRecord in pairs(getOwnedEggs()) do
			if typeof(ownedRecord) == "table" and ownedRecord.Placement == nil then
				targetUid = ownedUid
				record = ownedRecord
				break
			end
		end
	end
	if not record then
		stealDebug("place-precheck:" .. tostring(targetUid), "placement precheck: owned record unavailable", 1)
		return false
	end
	if not ensureAtPlot() then
		stealDebug("place-precheck:" .. tostring(targetUid), "placement precheck: not at local plot", 1)
		return false
	end
	if not ensureInsidePetArea() then
		stealDebug("place-precheck:" .. tostring(targetUid), "placement precheck: not inside PetArea", 1)
		return false
	end
	if record.Placement ~= nil then
		EggController.NextStealAfterPlacement = os.clock() + (tonumber(EggController.Config.PostPlacementDelay) or 1)
		return true
	end
	local placements = EggController.GetPlacementLocalCFrames()
	if #placements == 0 then return false end
	pcall(EggState.WearEggTool, targetUid)
	task.wait(.1)
	for offset = 0, #placements - 1 do
		if not isInsidePetArea() and not ensureInsidePetArea() then return false end
		local index = (nextPlacementIndex + offset - 1) % #placements + 1
		local called, accepted, placeReason = pcall(EggState.PlantEgg, targetUid, placements[index])
		if called and accepted ~= false then
			nextPlacementIndex = index + 1
			local deadline = os.clock() + 3
			while os.clock() < deadline and active() do
				local updated = getOwnedEgg(targetUid)
				if updated and updated.Placement ~= nil then
					EggController.NextStealAfterPlacement = os.clock() + (tonumber(EggController.Config.PostPlacementDelay) or 1)
					return true
				end
				task.wait(.1)
			end
			if not EggController.IsHoldingEgg() then
				EggController.NextStealAfterPlacement = os.clock() + (tonumber(EggController.Config.PostPlacementDelay) or 1)
				return true
			end
		end
		stealDebug("place-result:" .. tostring(targetUid), "AskPlaceEgg rejected: callOk=" .. tostring(called) .. " accepted=" .. tostring(accepted) .. " detail=" .. tostring(placeReason), .75)
	end
	stealDebug("place-result:" .. tostring(targetUid), "AskPlaceEgg rejected every generated PetArea slot", 1)
	return false
end
function EggController.RunAutoPlaceSelectedEggs()
	if isFieldCarrying() or pendingEggUid then return false end
	for _, uid in ipairs(EggController.GetSelectedUnplacedEggUids()) do
		setState("PlacingEgg")
		if EggController.PlaceEgg(uid) then
			log("Selected inventory egg placed")
			return true
		end
	end
	return false
end
function EggController.RunAutoEquipBest(interruptTreadmill)
	if isFieldCarrying() or pendingEggUid or not EquipBestRemote then return false end
	if treadmillTraining or isTreadmillHudVisible() then
		if not interruptTreadmill then return false end
		leaveTreadmillForAction("EquipBest")
	end
	setState("EquippingBest")
	return callRemote(EquipBestRemote)
end
local function getPetItemData(serialized)
	local decode = AssetItems and (AssetItems.Decode or AssetItems.Deserialize)
	if typeof(decode) ~= "function" then return nil end
	local ok, itemData = pcall(decode, serialized)
	return ok and typeof(itemData) == "table" and itemData or nil
end
local function findToolByUid(uid)
	for _, container in ipairs({ LocalPlayer.Character, LocalPlayer:FindFirstChildOfClass("Backpack") }) do
		for _, child in ipairs(container and container:GetChildren() or {}) do
			if child:IsA("Tool") and child:GetAttribute("UID") == uid then return child end
		end
	end
	return nil
end
local function holdUid(uid)
	local character, humanoid = LocalPlayer.Character, getHumanoid()
	local tool = findToolByUid(uid)
	if not character or not humanoid or not tool then return false end
	if tool.Parent == character then return true end
	pcall(function() humanoid:EquipTool(tool) end)
	local deadline = os.clock() + 1
	while os.clock() < deadline do
		if tool.Parent == character then return true end
		task.wait(.05)
	end
	return false
end
function EggController.GetUnequippedPetUids()
	local save = getSave()
	local inventory, equipped = save and save.Inventory, save and save.EquippedAssets
	if typeof(inventory) ~= "table" then return {} end
	local equippedUids, result = {}, {}
	for _, uid in ipairs(typeof(equipped) == "table" and equipped or {}) do equippedUids[uid] = true end
	for uid, asset in pairs(inventory) do
		local itemData = getPetItemData(asset)
		local category = itemData and (itemData.AssetCategory or itemData.Category)
		local rarity = category and resolveRarity({ AssetCategory = category }) or nil
		-- The auto-sell keep list is the same SelectedRarities table used by
		-- egg selection.  Equipped pets are always kept; only inventory/backpack
		-- pets outside the selected rarities are sell candidates.
		if typeof(uid) == "string" and not equippedUids[uid]
			and rarity and EggController.Config.SelectedRarities[rarity] ~= true then
			table.insert(result, uid)
		end
	end
	table.sort(result)
	return result
end
function EggController.RunAutoSellUnequippedPets()
	-- Rift candidates are intentionally unequipped, so this must be an absolute
	-- block rather than a per-UID exception for the entire Rift transaction.
	if RiftRuntime.Mode or RiftRuntime.BossMode or isFieldCarrying() or pendingEggUid then return false end
	if not SellEveryPetRemote then warnLog("SellAll unavailable: PetSatchel/SellEveryPet remote was not found"); return false end
	local beforeSell = EggController.GetUnequippedPetUids()
	if #beforeSell == 0 then return false end
	log("SellAll remote: " .. SellEveryPetRemote:GetFullName() .. " [" .. SellEveryPetRemote.ClassName .. "]")
	leaveTreadmillForAction("SellAll")
	log("SellAll: " .. #beforeSell .. " pet(s) outside Selected Rarities")
	local candidates = EggController.GetUnequippedPetUids()
	if #candidates == 0 then
		log("SellAll: every pet matches Selected Rarities")
		return false
	end
	log("SellAll: selling " .. #candidates .. " pet(s) outside Selected Rarities")
	-- Dump: AssetSellerNpc calls SellEveryPet:FireServer(uidList).  It does not
	-- require a Tool to be equipped and its payload is one array, not one UID.
	setState("SellingUnselectedPet")
	local dispatched, response = callSellRemote(SellEveryPetRemote, candidates)
	log("SellAll: SellEveryPet response = " .. tostring(response))
	if not dispatched then warnLog("SellAll: SellEveryPet dispatch failed") end
	local deadline = os.clock() + 5
	while os.clock() < deadline and active() do
		local save = getSave()
		local inventory = save and save.Inventory or {}
		local remaining = 0
		for _, uid in ipairs(candidates) do
			if inventory[uid] ~= nil then remaining += 1 end
		end
		if remaining == 0 then
			log("SellAll: sold " .. #candidates .. " pet(s)")
			return true
		end
		task.wait(.1)
	end
	warnLog("SellAll: server kept the batch of " .. #candidates .. " pet(s)")
	return false
end

function EggController.RunAutoClaimHouseEarnings()
	if isFieldCarrying() or pendingEggUid or not HouseEarningsSummaryRemote or not HouseEarningsClaimRemote then return false end
	local summary = invokeRemote(HouseEarningsSummaryRemote)
	if typeof(summary) ~= "table" then
		warnLog("House earnings: FetchSummary returned no summary")
		return false
	end
	local amount = tonumber(summary.ClaimableAmount) or 0
	if amount <= 0 then return false end
	-- Dump: OfflineMoneyBucketPiles invokes AskCollect({ Kind = "Claim" }).
	leaveTreadmillForAction("HouseEarnings")
	local claimed = invokeRemote(HouseEarningsClaimRemote, { Kind = "Claim" })
	if claimed == true then
		log("House earnings claim requested: " .. amount)
		return true
	end
	warnLog("House earnings: AskCollect request failed")
	return false
end

-- stealegg.lua's TrailInventory/AskPurchase flow, extended to buy one missing
-- trail at a time in ascending price order when progression is enabled.
function EggController.RunAutoBuyTrails()
	if isFieldCarrying() or pendingEggUid then return false end
	if not TrailPurchaseRemote then
		warnLog("Auto Buy Trails unavailable: Trailwear/AskPurchase remote was not found")
		return false
	end
	local save = getSave()
	if not save or typeof(save.TrailInventory) ~= "table" then return false end
	local owned = save.TrailInventory
	for _, trailName in ipairs(TRAIL_OPTIONS) do
		local allowed = EggController.Config.AutoTrailProgression == true
			or EggController.Config.SelectedTrails[trailName] == true
		if allowed then
			local trailId = TRAIL_ID_BY_NAME[trailName]
			local price = TRAIL_PRICE_BY_NAME[trailName] or math.huge
			if trailId and owned[trailId] == nil and canSpend(save, price) then
				leaveTreadmillForAction("BuyTrail")
				setState("BuyingTrail")
				if callRemote(TrailPurchaseRemote, trailId) then
					log("Trail purchase requested: " .. trailName)
					-- Do not wait for the normal timer after a purchase.  The next
					-- controller pass verifies the replicated inventory and equips it.
					EggController.Timers.TrailEquip = 0
					-- Buy a single tier per interval; the next pass reads the replicated
					-- inventory and advances to the next affordable trail.
					return true
				else
					warnLog("Trail purchase request failed: " .. trailName)
				end
			end
		end
	end
	return false
end

function EggController.RunAutoEquipBestTrail()
	if isFieldCarrying() or pendingEggUid or not TrailChooseRemote then return false end
	local save = getSave()
	local owned = save and save.TrailInventory
	if typeof(owned) ~= "table" then return false end
	local bestId, bestPrice = nil, -1
	for _, trailName in ipairs(TRAIL_OPTIONS) do
		local trailId = TRAIL_ID_BY_NAME[trailName]
		if trailId and owned[trailId] == true then
			local price = TRAIL_PRICE_BY_NAME[trailName] or 0
			if price > bestPrice then bestId, bestPrice = trailId, price end
		end
	end
	if not bestId then
		logTrailStatus("no owned trail yet")
		return false
	end
	local function wornTrailId(queryServer)
		local currentSave = getSave()
		local wornId = currentSave and currentSave.EquippedTrail or save.EquippedTrail
		if queryServer and TrailWornSnapshotRemote then
			local snapshot = invokeRemote(TrailWornSnapshotRemote)
			if typeof(snapshot) == "table" then wornId = snapshot[tostring(LocalPlayer.UserId)] or wornId end
		end
		return wornId
	end
	local wornId = wornTrailId(true)
	local bestName = tostring(TRAIL_NAME_BY_ID[bestId] or bestId)
	if wornId == bestId then
		logTrailStatus("best equipped: " .. bestName)
		return false
	end
	leaveTreadmillForAction("EquipBestTrail")
	setState("EquippingBestTrail")
	logTrailStatus("equipping " .. bestName)
	if callRemote(TrailChooseRemote, bestId) then
		local deadline = os.clock() + 2
		repeat
			if wornTrailId(false) == bestId then
				log("Best trail equipped confirmed: " .. bestName)
				lastTrailStatusMessage = "best equipped: " .. bestName
				watchdogMarkProgress()
				return true
			end
			task.wait(.15)
		until os.clock() >= deadline
		if wornTrailId(true) == bestId then
			log("Best trail equipped confirmed: " .. bestName)
			lastTrailStatusMessage = "best equipped: " .. bestName
			watchdogMarkProgress()
			return true
		end
		warnLog("Best trail equip was requested but has not replicated yet; will retry")
		watchdogReportFailure("Best trail equip was not confirmed")
		return false
	end
	watchdogReportFailure("Best trail equip request failed")
	return false
end

function EggController.RunAutoClaimIndex()
	if isFieldCarrying() or pendingEggUid or not IndexClaimAllRemote then return false end
	local claimed = invokeRemote(IndexClaimAllRemote)
	if claimed == true then
		log("Index rewards claim requested")
		watchdogMarkProgress()
		return true
	end
	return false
end

function EggController.RunAutoClaimGroupReward()
	if isFieldCarrying() or pendingEggUid or not GroupRewardRemote then return false end
	local save = getSave()
	if not save or save.ClaimedGroupReward == true then return false end
	-- The game's GroupRewards UI sends true only after membership validation.  The
	-- server revalidates it, so a non-member simply receives no claim.
	local claimed = invokeRemote(GroupRewardRemote, true)
	if claimed == true then
		log("Group reward claim requested")
		watchdogMarkProgress()
		return true
	end
	return false
end

-- ============================================================================
-- Boss Mutation Consumable: a single controller action reserves one placed egg
-- until its server response is known.  The normal Hatch pass reads that same
-- reservation and therefore cannot hatch the target between purchase/use.
-- ============================================================================
function EggController.MutationRuntime.Clear(reason, retryDelay)
	local runtime = EggController.MutationRuntime
	if runtime.ReservedUid and reason then
		log("Mutation reservation released: " .. reason)
	end
	runtime.ReservedUid = nil
	runtime.TargetRate = nil
	runtime.NextActionAt = retryDelay and os.clock() + math.max(0.05, retryDelay) or 0
end

function EggController.MutationRuntime.HasBossMutation(record)
	if typeof(record) ~= "table" then return false end
	local bossMastery = EggController.MutationRuntime.BossMastery
	return table.find(record.Mutations or {}, bossMastery and bossMastery.MutationId or "Boss") ~= nil
end

function EggController.MutationRuntime.IsEligibleEgg(uid, record)
	-- An owned record with Placement is specifically an egg currently in the
	-- player's fence.  Hatched pets have no EggInventory/owned-egg record.
	return typeof(uid) == "string" and typeof(record) == "table"
		and record.Placement ~= nil and not EggController.MutationRuntime.HasBossMutation(record)
end

function EggController.MutationRuntime.SelectBestPlacedEgg()
	local bestUid, bestRecord, bestRate = nil, nil, -math.huge
	for uid, record in pairs(getOwnedEggs()) do
		if EggController.MutationRuntime.IsEligibleEgg(uid, record) then
			local rate = getEggEarningRate(record)
			-- Stable UID tie-break prevents needless target changes between ticks.
			if rate > bestRate or (rate == bestRate and (not bestUid or uid < bestUid)) then
				bestUid, bestRecord, bestRate = uid, record, rate
			end
		end
	end
	return bestUid, bestRecord, bestRate
end

function EggController.MutationRuntime.GetPrice()
	local bossMastery = EggController.MutationRuntime.BossMastery
	if not bossMastery or typeof(bossMastery.GetShopProduct) ~= "function"
		or typeof(bossMastery.GetShopPrice) ~= "function" then
		return nil
	end
	local product = bossMastery.GetShopProduct("MutationConsumable")
	if not product or (typeof(bossMastery.IsShopProductListed) == "function"
		and bossMastery.IsShopProductListed("MutationConsumable") ~= true) then
		return nil
	end
	local ok, price = pcall(bossMastery.GetShopPrice, product)
	price = ok and tonumber(price) or nil
	return price and price > 0 and price or nil
end

function EggController.MutationRuntime.GetConsumableCount(save)
	local mastery = save and save.BossMastery
	return math.max(0, tonumber(mastery and mastery.MutationConsumables) or 0)
end

function EggController.MutationRuntime.LogConsumableCount(count)
	local runtime = EggController.MutationRuntime
	local now = os.clock()
	if runtime.LastLoggedConsumableCount ~= count or now >= (runtime.NextConsumableCountLogAt or 0) then
		log("MutationConsumables: " .. tostring(count))
		runtime.LastLoggedConsumableCount = count
		runtime.NextConsumableCountLogAt = now + math.max(0.1, tonumber(EggController.Config.MutationCountLogInterval) or 5)
	end
end

function EggController.MutationRuntime.WaitForUseSync(tool, countBefore, usesBefore)
	local runtime = EggController.MutationRuntime
	local deadline = os.clock() + math.max(0.75, tonumber(EggController.Config.MutationRollRetryDelay) or 0.75)
	repeat
		local count = runtime.GetConsumableCount(getSave())
		local uses = tool and tool.Parent and tool:GetAttribute("Uses") or nil
		if count ~= countBefore or uses ~= usesBefore then return count, uses end
		task.wait(0.05)
	until os.clock() >= deadline
	return runtime.GetConsumableCount(getSave()), tool and tool.Parent and tool:GetAttribute("Uses") or nil
end

function EggController.MutationRuntime.WaitForConsumableCountAbove(baseline)
	local runtime = EggController.MutationRuntime
	local deadline = os.clock() + math.max(0.1, tonumber(EggController.Config.MutationPurchaseConfirmTimeout) or 3)
	repeat
		if runtime.GetConsumableCount(getSave()) > baseline then return true end
		task.wait(0.05)
	until os.clock() >= deadline
	return runtime.GetConsumableCount(getSave()) > baseline
end

function EggController.MutationRuntime.WaitForMutationState(uid)
	local runtime = EggController.MutationRuntime
	local deadline = os.clock() + math.max(0.1, tonumber(EggController.Config.MutationStateConfirmTimeout) or 2)
	repeat
		if runtime.HasBossMutation(getOwnedEgg(uid)) then return true end
		task.wait(0.05)
	until os.clock() >= deadline
	return runtime.HasBossMutation(getOwnedEgg(uid))
end

function EggController.MutationRuntime.MoveToReservedTarget(record)
	if typeof(record) ~= "table" or typeof(record.Placement) ~= "table"
		or typeof(record.Placement.LocalCFrame) ~= "CFrame" then
		return false
	end
	leaveTreadmillForAction("MutationConsumable")
	local plot = EggController.GetLocalPlayerPlot()
	if not plot or not plot.CenterPoint then return false end
	local target = plot.CenterPoint.CFrame * record.Placement.LocalCFrame
	setState("MovingToMutationTarget")
	log("Moving to Mutation target: " .. getEggDisplayName(record))
	return rawTeleport(target.Position + Vector3.new(0, 3, 0))
end

function EggController.MutationRuntime.TargetDistance(record)
	local plot = EggController.GetLocalPlayerPlot()
	local root = getRoot()
	if not root or not plot or not plot.CenterPoint or typeof(record) ~= "table"
		or typeof(record.Placement) ~= "table" or typeof(record.Placement.LocalCFrame) ~= "CFrame" then
		return nil
	end
	return (root.Position - (plot.CenterPoint.CFrame * record.Placement.LocalCFrame).Position).Magnitude
end

function EggController.MutationRuntime.EquipMutationTool()
	local runtime = EggController.MutationRuntime
	leaveTreadmillForAction("MutationConsumable")
	local character = LocalPlayer.Character
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	if not character then return nil end
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") and child:GetAttribute("ItemType") == "MutationConsumable" then return child end
	end
	local tool = nil
	for _, child in ipairs(backpack and backpack:GetChildren() or {}) do
		if child:IsA("Tool") and child:GetAttribute("ItemType") == "MutationConsumable" then
			tool = child
			break
		end
	end
	if not tool then return nil end
	log("Mutation tool found in Backpack: " .. tool.Name)
	local humanoid = getHumanoid()
	if not humanoid or not pcall(function() humanoid:EquipTool(tool) end) then return nil end
	local deadline = os.clock() + 1
	repeat
		if tool.Parent == character then
			log("Mutation tool equipped: " .. tool.Name)
			return tool
		end
		task.wait(0.05)
	until os.clock() >= deadline
	return nil
end

function EggController.MutationRuntime.Run()
	local runtime = EggController.MutationRuntime
	if EggController.Config.AutoMutationConsumable ~= true
		or not runtime.BuyRemote or not runtime.UseRemote then
		runtime.Clear("feature unavailable")
		return false
	end
	local now = os.clock()
	if now < runtime.NextActionAt then return runtime.ReservedUid ~= nil end
	local save = getSave()
	local consumables = runtime.GetConsumableCount(save)
	runtime.LogConsumableCount(consumables)
	-- Tokens and price govern only a missing consumable.  Existing inventory is
	-- always used first, even when no Boss Tokens remain.
	if consumables < 1 then
		local price = runtime.GetPrice()
		local tokens = tonumber(save and save.BossTokens) or 0
		if not price or tokens < price then
			if runtime.ReservedUid then runtime.Clear("Boss Tokens below current price", tonumber(EggController.Config.MutationRetryDelay) or 5)
			else runtime.NextActionAt = now + math.max(0.05, tonumber(EggController.Config.MutationRetryDelay) or 5) end
			return false
		end
	end

	local uid, record, rate = runtime.ReservedUid, nil, runtime.TargetRate
	if uid then
		record = getOwnedEgg(uid)
		if not runtime.IsEligibleEgg(uid, record) then
			runtime.Clear("target disappeared, hatched, or is already mutated")
			return false
		end
	else
		uid, record, rate = runtime.SelectBestPlacedEgg()
		if not uid then return false end -- Never buy if there is no fence egg.
		runtime.ReservedUid, runtime.TargetRate = uid, rate
		log("Mutation reserved " .. uid .. " (" .. getEggDisplayName(record) .. ", " .. tostring(rate) .. " B/s)")
	end

	if consumables < 1 then
		setState("BuyingMutationConsumable")
		-- Purchase completion is the replicated inventory count: this avoids
		-- treating a valid one-value return as a failure.
		local invoked, first = pcall(function()
			return runtime.BuyRemote:InvokeServer("MutationConsumable")
		end)
		if not runtime.WaitForConsumableCountAbove(consumables) then
			log("Mutation purchase was not confirmed")
			runtime.Clear("purchase inventory did not increase", tonumber(EggController.Config.MutationRetryDelay) or 5)
			return false
		end
		consumables = runtime.GetConsumableCount(getSave())
		log("MutationConsumable purchase confirmed (count=" .. tostring(consumables) .. ")")
	end

	-- Do not spend/use on a UID that changed state while the purchase round-trip
	-- was pending.  A later controller tick may safely choose a fresh target.
	record = getOwnedEgg(uid)
	if not runtime.IsEligibleEgg(uid, record) then
		runtime.Clear("target changed after purchase")
		return false
	end
	local tool = runtime.EquipMutationTool()
	if not tool then
		runtime.Clear("MutationConsumable tool was not equipped", tonumber(EggController.Config.MutationRetryDelay) or 5)
		return false
	end
	if not runtime.MoveToReservedTarget(record) then
		runtime.Clear("unable to reach reserved mutation target", tonumber(EggController.Config.MutationRetryDelay) or 5)
		return false
	end
	local distance = runtime.TargetDistance(record)
	log("Mutation distance: " .. tostring(distance))
	if tool.Parent ~= LocalPlayer.Character or not distance or distance > 7 then
		runtime.Clear("Mutation tool/target proximity prerequisite failed", tonumber(EggController.Config.MutationRetryDelay) or 5)
		return false
	end
	setState("UsingMutationConsumable")
	log("Using MutationConsumable on " .. getEggDisplayName(record) .. " (" .. uid .. ")")
	local consumablesBeforeUse = runtime.GetConsumableCount(getSave())
	local usesBeforeUse = tool:GetAttribute("Uses")
	local invoked, first = pcall(function()
		return runtime.UseRemote:InvokeServer(uid)
	end)
	runtime.LastResult = first
	if not invoked or typeof(first) ~= "table" or first.Success ~= true then
		-- MutationRetryDelay is 5 seconds, exceeding the requested 3-second
		-- minimum and preventing repeated AskUseMutationConsumable calls.
		runtime.Clear("use rejected, errored, or timed out", tonumber(EggController.Config.MutationRetryDelay) or 5)
		return false
	end
	if first.Mutated == true then
		local stateConfirmed = runtime.WaitForMutationState(uid)
		log("Mutation SUCCESS: " .. getEggDisplayName(record) .. " (" .. uid .. ", egg state confirmed=" .. tostring(stateConfirmed) .. ")")
		runtime.Clear("mutation succeeded")
		return true
	end

	-- Server Success=true is authoritative.  Wait for delayed Save/Tool sync,
	-- without using that replication timing to label this successful use failed.
	local remaining, usesAfter = runtime.WaitForUseSync(tool, consumablesBeforeUse, usesBeforeUse)
	runtime.LogConsumableCount(remaining)
	log("Mutation roll failed; remaining: " .. tostring(remaining) .. " tool uses=" .. tostring(usesAfter))
	runtime.NextActionAt = os.clock() + math.max(0.75, tonumber(EggController.Config.MutationRollRetryDelay) or 0.75)
	setState("MutationRollFailed")
	return true
end

-- Boss Mastery claims are intentionally one remote per controller turn.  The
-- GUI calls AskClaimMilestone with the milestone Id, and treats a truthy
-- response as acceptance; this also waits for Save.BossMastery to acknowledge
-- that exact Id before advancing to the next reward.
function EggController.BossMasteryClaimRuntime.FindReadyMilestone(state)
	local runtime = EggController.BossMasteryClaimRuntime
	local bossMastery = runtime.BossMastery
	if typeof(state) ~= "table" or not bossMastery or typeof(bossMastery.Milestones) ~= "table"
		or typeof(bossMastery.GetMilestoneKills) ~= "function" then
		return nil
	end
	local mastery = tonumber(state.Mastery) or 0
	local claimed = typeof(state.ClaimedMilestoneIds) == "table" and state.ClaimedMilestoneIds or {}
	local candidates = table.clone(bossMastery.Milestones)
	table.sort(candidates, function(a, b)
		local aKills = tonumber(bossMastery.GetMilestoneKills(a)) or math.huge
		local bKills = tonumber(bossMastery.GetMilestoneKills(b)) or math.huge
		return aKills == bKills and tostring(a.Id) < tostring(b.Id) or aKills < bKills
	end)
	for _, milestone in ipairs(candidates) do
		if typeof(milestone) == "table" and typeof(milestone.Id) == "string"
			and claimed[milestone.Id] ~= true
			and mastery >= (tonumber(bossMastery.GetMilestoneKills(milestone)) or math.huge) then
			return milestone.Id
		end
	end
	return nil
end

function EggController.BossMasteryClaimRuntime.Run()
	local runtime = EggController.BossMasteryClaimRuntime
	if EggController.Config.AutoClaimBossMastery ~= true or not runtime.Remote then return false end
	local now = os.clock()
	if now < runtime.NextActionAt then return runtime.PendingId ~= nil end
	local save = getSave()
	local state = save and save.BossMastery
	if typeof(state) ~= "table" then return false end
	if runtime.PendingId then
		local claimed = state.ClaimedMilestoneIds
		if typeof(claimed) == "table" and claimed[runtime.PendingId] == true then
			log("Boss Mastery milestone claimed: " .. runtime.PendingId)
			runtime.PendingId, runtime.ConfirmDeadline = nil, 0
			runtime.NextActionAt = now + math.max(0.05, tonumber(EggController.Config.BossMasteryClaimInterval) or 0.75)
			return true
		end
		if now < runtime.ConfirmDeadline then
			setState("ConfirmingBossMasteryClaim")
			return true
		end
		log("Boss Mastery claim was accepted but did not replicate: " .. runtime.PendingId)
		runtime.PendingId, runtime.ConfirmDeadline = nil, 0
		runtime.NextActionAt = now + math.max(1, tonumber(EggController.Config.BossMasteryClaimRetryDelay) or 5)
		return false
	end
	local milestoneId = runtime.FindReadyMilestone(state)
	if not milestoneId then return false end
	setState("ClaimingBossMastery")
	local invoked, result = invokeRemote(runtime.Remote, milestoneId)
	runtime.LastResult = result
	if not invoked or not result then
		runtime.NextActionAt = now + math.max(1, tonumber(EggController.Config.BossMasteryClaimRetryDelay) or 5)
		return false
	end
	runtime.PendingId = milestoneId
	runtime.ConfirmDeadline = os.clock() + math.max(1, tonumber(EggController.Config.BossMasteryClaimConfirmTimeout) or 4)
	return true
end

function EggController.GetReadyEggs()
	local ready = {}
	for uid, record in pairs(getOwnedEggs()) do
		if typeof(uid) == "string" and typeof(record) == "table" and record.Placement ~= nil
			and uid ~= EggController.MutationRuntime.ReservedUid then
			local ok, isReady = pcall(EggState.IsReadyToHatch, uid)
			if ok and isReady == true then table.insert(ready, uid) end
		end
	end
	table.sort(ready)
	return ready
end
function EggController.HatchReadyEggs()
	for _, uid in ipairs(EggController.GetReadyEggs()) do
		if not active() then return false end
		local called, began = pcall(EggState.BeginHatch, uid)
		if called and began == true then pcall(EggState.FinishHatch, uid) end
	end
	return true
end

function EggController.RunAutoUpgrades()
	if isFieldCarrying() or pendingEggUid then return false end
	local save = getSave()
	if not save then return false end
	-- Trail has its own independent timer.  Alternate base and treadmill after
	-- each successful purchase so a cheap treadmill tier cannot starve a base
	-- expansion when both are affordable.
	local function tryTreadmill()
		if not (EggController.Config.AutoUpgradeTreadmill and TreadmillUpgradeRemote and Treadmills
			and typeof(Treadmills.GetByUpgradeLevel) == "function") then return false end
		local currentLevel = tonumber(save.TreadmillUpgradeLevel) or 0
		local found, nextUpgrade = pcall(Treadmills.GetByUpgradeLevel, currentLevel + 1)
		local price = found and nextUpgrade and tonumber(nextUpgrade.Price) or math.huge
		if nextUpgrade and canSpend(save, price) then
			leaveTreadmillForAction("TreadmillUpgrade")
			setState("UpgradingTreadmill")
			if callRemote(TreadmillUpgradeRemote, nextUpgrade._id) then
				log("Treadmill upgrade requested")
				watchdogMarkProgress()
				return true
			end
			watchdogReportFailure("Treadmill upgrade request failed")
		end
		return false
	end
	local function tryBase()
		if not (EggController.Config.AutoUpgradeBase and BaseUpgradeRemote and BaseUpgrade
			and typeof(BaseUpgrade.ResolveNextTier) == "function") then return false end
		-- Dump: ResolveNextTier expects the complete save table, not a level number.
		local resolved, _, nextTier = pcall(BaseUpgrade.ResolveNextTier, save)
		local price = resolved and nextTier and tonumber(nextTier.Cost) or math.huge
		if nextTier and canSpend(save, price) then
			leaveTreadmillForAction("BaseUpgrade")
			setState("UpgradingBase")
			if callRemote(BaseUpgradeRemote) then
				log("Base expansion requested")
				watchdogMarkProgress()
				return true
			end
			watchdogReportFailure("Base upgrade request failed")
		end
		return false
	end
	local first, second
	if nextUpgradeKind == "Base" then
		first, second = tryBase, tryTreadmill
	else
		first, second = tryTreadmill, tryBase
	end
	if first() then
		nextUpgradeKind = nextUpgradeKind == "Base" and "Treadmill" or "Base"
		return true
	end
	if second() then
		nextUpgradeKind = nextUpgradeKind == "Base" and "Treadmill" or "Base"
		return true
	end
	return false
end

function EggController.WaitForOwnership(uid)
	local deadline = os.clock() + 3
	while os.clock() < deadline and active() do
		if uid and getOwnedEgg(uid) then return true, uid end
		local held = EggController.GetHeldEgg()
		if held and held.Uid then
			if getOwnedEgg(held.Uid) or held.Record then return true, held.Uid end
		end
		for ownedUid, ownedRecord in pairs(getOwnedEggs()) do
			if typeof(ownedRecord) == "table" and ownedRecord.Placement == nil then
				return true, ownedUid
			end
		end
		task.wait(.1)
	end
	local held = EggController.GetHeldEgg()
	if held and held.Uid then return true, held.Uid end
	return false, uid
end
deliverAndPlace = function(uid)
	pendingEggUid = uid
	setState("ReturningToBase")
	if isFieldCarrying(uid) and not EggController.ReturnToBaseWithEgg(uid) then
		watchdogReportFailure("Return to base failed")
		return false
	end
	local ownedOk, resolvedUid = EggController.WaitForOwnership(uid)
	local placeUid = resolvedUid or uid
	setState("PlacingEgg")
	if not EggController.PlaceEgg(placeUid) then
		warnLog("Placement failed or no egg slot is free: " .. tostring(placeUid))
		watchdogReportFailure("Egg placement failed")
		return false
	end
	pendingEggUid = nil
	EggController.PendingTargetCategory = nil
	EggController.PendingTargetWaitDeadline = 0
	log("Egg placed")
	return true
end

-- ============================================================================
-- Rift Boss test flow.  Entry/exit use the observed portal Hitboxes.  Combat
-- never fires BatSwing directly: Tool:Activate() lets the game's Bat client
-- create the validated target/trace payload itself.
-- ============================================================================
function RiftRuntime.BossSnapshot()
	local bossEvent = Remotes and Remotes.BossEvent
	local remote = bossEvent and bossEvent.AskSnapshot
	return invokeRemote(remote)
end

function RiftRuntime.BossFindPortalHitbox(name, arena)
	local container = arena and arena:FindFirstChild(name) or Workspace:FindFirstChild(name)
	return container and container:FindFirstChild("Hitbox", true) or nil
end

function RiftRuntime.BossFindCrystal()
	local arena = Workspace:FindFirstChild("BossArena")
	local folder = arena and arena:FindFirstChild("CrystalTowers")
	if not folder then return nil end
	local selected, distance = nil, math.huge
	local root = getRoot()
	for _, tower in ipairs(folder:GetChildren()) do
		local hitbox = tower:FindFirstChild("Hitbox", true)
		local health = hitbox and hitbox:GetAttribute("Health")
		if hitbox and hitbox:IsA("BasePart") and type(health) == "number" and health > 0 then
			local d = root and (root.Position - hitbox.Position).Magnitude or 0
			if d < distance then selected, distance = hitbox, d end
		end
	end
	return selected
end

function RiftRuntime.BossFindHand()
	local arena = Workspace:FindFirstChild("BossArena")
	local boss = arena and arena:FindFirstChild("Boss")
	local hand = boss and boss:FindFirstChild("UpperHand1.R", true)
	if hand and hand:IsA("Bone") and hand:FindFirstChild("Health") then return hand end
	return nil
end

function RiftRuntime.BossEquipBat()
	local character = LocalPlayer.Character
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	local tool = character and character:FindFirstChildOfClass("Tool")
	if not (tool and tool:GetAttribute("IsBat") == true) and backpack then
		for _, item in ipairs(backpack:GetChildren()) do
			if item:IsA("Tool") and item:GetAttribute("IsBat") == true then tool = item; break end
		end
	end
	if not (tool and tool:IsA("Tool") and tool:GetAttribute("IsBat") == true) then return nil end
	if tool.Parent ~= character then
		local humanoid = getHumanoid()
		if not humanoid then return nil end
		pcall(function() humanoid:EquipTool(tool) end)
		if tool.Parent ~= character then return nil end
	end
	return tool
end

function RiftRuntime.BossMoveTo(position)
	if typeof(position) ~= "Vector3" or not getRoot() then return false end
	local configuredSpeed = tonumber(EggController.Config.BossMoveSpeed) or 200
	if RiftRuntime.BossState == "BossCrystalPhase" then
		configuredSpeed = math.min(configuredSpeed, tonumber(EggController.Config.BossCrystalMoveSpeed) or 120)
	end
	-- Reuse the normal Steal Egg tween implementation.  Only the target Y and
	-- speed are overridden; cancellation, grounding/placement and velocity
	-- cleanup remain identical to normal Steal Egg movement.
	local reached = tweenStealMoveTo(position.X, position.Z, position.Y, configuredSpeed)
	if reached then log("Boss movement: steal tween reached target") end
	return reached
end

function RiftRuntime.BossClearMovement()
	-- Boss movement now owns no separate anchor/constraint state.  Keep the
	-- normal character cleanup for release/death paths.
	restoreCharacterControl()
end

function RiftRuntime.BossSwing(targetPosition)
	local root = getRoot()
	local tool = RiftRuntime.BossEquipBat()
	if not root or not tool or typeof(targetPosition) ~= "Vector3" then
		warnLog("Boss swing skipped: equipped Bat tool unavailable")
		RiftRuntime.BossNextActionAt = os.clock() + 1
		return false
	end
	local distance = (root.Position - targetPosition).Magnitude
	if distance > 15 then
		warnLog("Boss swing skipped: target is " .. tostring(math.floor(distance)) .. " studs away")
		RiftRuntime.BossNextActionAt = os.clock() + 1
		return false
	end
	pcall(function() tool:Activate() end)
	log("Boss Bat swing: " .. tostring(RiftRuntime.BossState))
	RiftRuntime.BossNextActionAt = os.clock() + math.max(.7, tonumber(EggController.Config.BossActionInterval) or .75)
	return true
end

function RiftRuntime.BossRelease(reason, retry)
	RiftRuntime.BossClearMovement()
	if reason and string.find(reason, "boss defeated", 1, true) then RiftRuntime.BossSuppressed = true end
	RiftRuntime.BossMode = false
	RiftRuntime.BossState = nil
	RiftRuntime.BossFailures = 0
	RiftRuntime.BossStartedAt = 0
	RiftRuntime.BossNextActionAt = 0
	RiftRuntime.BossNextStateAt = 0
	RiftRuntime.BossSnapshotState = nil
	RiftRuntime.BossEnterDeadline = 0
	RiftRuntime.BossExitDeadline = 0
	RiftRuntime.BossRewardDeadline = 0
	RiftRuntime.BossRewardObserved = false
	RiftRuntime.BossRewardConfirmationLogged = false
	RiftRuntime.BossLastProgressAt = 0
	RiftRuntime.BossLastHealth = nil
	RiftRuntime.BossLastCrystalHits = nil
	RiftRuntime.BossLastArmHits = nil
	RiftRuntime.BossRetryAt = retry and os.clock() + retry or 0
	if reason then log("Boss mode released: " .. reason) end
end

function RiftRuntime.BossMaybeStart()
	if RiftRuntime.BossMode or not EggController.Config.AutoRiftBossEnabled then return false end
	if os.clock() < (RiftRuntime.BossRetryAt or 0) then return false end
	if os.clock() < (RiftRuntime.BossNextStateAt or 0) then return false end
	RiftRuntime.BossNextStateAt = os.clock() + 1
	local state = RiftRuntime.BossSnapshot()
	if typeof(state) ~= "table" or state.Open ~= true then return false end
	-- The event can remain Open briefly after completion.  Do not re-lock merely
	-- because its portal/banner still exists: a live boss must have positive HP.
	local bossHealth = tonumber(state.BossHealth)
	if not bossHealth or bossHealth <= 0 then
		RiftRuntime.BossSuppressed = true
		return false
	end
	if RiftRuntime.BossSuppressed then
		RiftRuntime.BossSuppressed = false
	end
	if RiftRuntime.Mode then RiftRuntime.Clear("Boss priority", 0) end
	local save = getSave()
	RiftRuntime.BossMode = true
	RiftRuntime.BossState = "BossEntering"
	RiftRuntime.BossFailures = 0
	RiftRuntime.BossStartedAt = os.clock()
	RiftRuntime.BossSnapshotState = state
	RiftRuntime.BossNextStateAt = os.clock() + 1
	RiftRuntime.BossEnterDeadline = os.clock() + math.max(3, tonumber(EggController.Config.BossEnterTimeout) or 15)
	RiftRuntime.BossLastProgressAt = os.clock()
	RiftRuntime.BossLastHealth = tonumber(state.BossHealth)
	RiftRuntime.BossRewardBaselineTokens = tonumber(save and save.BossTokens)
	RiftRuntime.BossRewardBaselineMastery = tonumber(save and save.BossMastery and save.BossMastery.Mastery)
	if treadmillTraining or isTreadmillHudVisible() then EggController.StopTreadmillTraining() end
	setState("BossLock")
	log("Boss mode locked")
	return true
end

function RiftRuntime.BossRun()
	if not RiftRuntime.BossMode then return false end
	local humanoid = getHumanoid()
	if not getRoot() or not humanoid or humanoid.Health <= 0 then
		RiftRuntime.BossRelease("character dead/reset", tonumber(EggController.Config.BossRecoveryDelay) or 15)
		setState("WaitingForCharacter")
		return false
	end
	local now = os.clock()
	local inArena = LocalPlayer:GetAttribute("InBossArena") == true
	if not inArena then
		if RiftRuntime.BossState == "BossExiting" then
			RiftRuntime.BossRelease("returned to lobby")
			return false
		end
		if os.clock() >= RiftRuntime.BossEnterDeadline then
			RiftRuntime.BossRelease("arena entry timeout", tonumber(EggController.Config.BossRecoveryDelay) or 15)
			return false
		end
		local hitbox = RiftRuntime.BossFindPortalHitbox("BossArenaTeleport")
		if hitbox then
			RiftRuntime.BossState = "BossEntering"
			setState("BossEntering")
			if rawTeleport(hitbox.Position) then log("Boss portal: instant touch TP") end
		end
		return false
	end

	local snapshot = RiftRuntime.BossSnapshotState
	if now >= (RiftRuntime.BossNextStateAt or 0) then
		RiftRuntime.BossNextStateAt = now + 1
		snapshot = RiftRuntime.BossSnapshot()
		if typeof(snapshot) == "table" then RiftRuntime.BossSnapshotState = snapshot end
	end
	if typeof(snapshot) ~= "table" then
		RiftRuntime.BossFailures += 1
		if RiftRuntime.BossFailures >= 3 then RiftRuntime.BossRelease("AskSnapshot failed", tonumber(EggController.Config.BossRecoveryDelay) or 15) end
		return false
	end
	RiftRuntime.BossFailures = 0
	local health = tonumber(snapshot.BossHealth)
	if health and (RiftRuntime.BossLastHealth == nil or health < RiftRuntime.BossLastHealth) then
		RiftRuntime.BossLastProgressAt = now
		RiftRuntime.BossLastHealth = health
		log("Boss HP: " .. tostring(health) .. "/" .. tostring(snapshot.BossMaxHealth))
	end
	local crystalHits = LocalPlayer:GetAttribute("BossCrystalHits")
	local armHits = LocalPlayer:GetAttribute("BossArmHits")
	if crystalHits ~= RiftRuntime.BossLastCrystalHits or armHits ~= RiftRuntime.BossLastArmHits then
		RiftRuntime.BossLastProgressAt = now
		RiftRuntime.BossLastCrystalHits, RiftRuntime.BossLastArmHits = crystalHits, armHits
		log("Boss hit progress: crystal=" .. tostring(crystalHits) .. " arm=" .. tostring(armHits))
	end
	if health and health <= 0 then
		local save = getSave()
		local tokens = tonumber(save and save.BossTokens)
		local mastery = tonumber(save and save.BossMastery and save.BossMastery.Mastery)
		if (tokens and tokens ~= RiftRuntime.BossRewardBaselineTokens)
			or (mastery and mastery ~= RiftRuntime.BossRewardBaselineMastery) then
			RiftRuntime.BossRewardObserved = true
			if not RiftRuntime.BossRewardConfirmationLogged then
				RiftRuntime.BossRewardConfirmationLogged = true
				log("Boss reward confirmed: Tokens/Mastery changed")
			end
		end
		if RiftRuntime.BossRewardDeadline == 0 then
			RiftRuntime.BossRewardDeadline = now + math.max(1, tonumber(EggController.Config.BossRewardConfirmTimeout) or 5)
			setState("BossRewardConfirming")
			return false
		end
		if now < RiftRuntime.BossRewardDeadline then return false end
		if not RiftRuntime.BossRewardObserved and not RiftRuntime.BossRewardConfirmationLogged then
			RiftRuntime.BossRewardConfirmationLogged = true
			log("Boss no reward detected; continuing exit")
		end
		local exit = RiftRuntime.BossFindPortalHitbox("BossArenaLeaveTeleport", Workspace:FindFirstChild("BossArena"))
		if exit then
			if RiftRuntime.BossExitDeadline == 0 then
				RiftRuntime.BossExitDeadline = now + math.max(3, tonumber(EggController.Config.BossExitTimeout) or 15)
			end
			if now >= RiftRuntime.BossExitDeadline then
				RiftRuntime.BossRelease("return lobby timeout", tonumber(EggController.Config.BossRecoveryDelay) or 15)
				return false
			end
			RiftRuntime.BossState = "BossExiting"
			setState("BossExiting")
			RiftRuntime.BossMoveTo(exit.Position)
			if LocalPlayer:GetAttribute("InBossArena") ~= true then
				RiftRuntime.BossRelease("boss defeated and reward observed")
			end
			return false
		end
		RiftRuntime.BossRelease("boss defeated; exit hitbox unavailable", tonumber(EggController.Config.BossRecoveryDelay) or 15)
		return false
	end
	if now - (RiftRuntime.BossLastProgressAt or now) > math.max(30, tonumber(EggController.Config.BossStallTimeout) or 180) then
		RiftRuntime.BossRelease("boss progress timeout", tonumber(EggController.Config.BossRecoveryDelay) or 15)
		return false
	end
	local crystal = RiftRuntime.BossFindCrystal()
	if crystal then
		RiftRuntime.BossState = "BossCrystalPhase"
		setState("BossCrystalPhase")
		if now >= (RiftRuntime.BossNextActionAt or 0) then
			if RiftRuntime.BossMoveTo(crystal.Position) then RiftRuntime.BossSwing(crystal.Position) end
		end
		return false
	end
	local hand = RiftRuntime.BossFindHand()
	if hand then
		RiftRuntime.BossState = "BossHandPhase"
		setState("BossHandPhase")
		if now >= (RiftRuntime.BossNextActionAt or 0) then
			local position = hand.WorldPosition
			if RiftRuntime.BossMoveTo(position) then RiftRuntime.BossSwing(position) end
		end
		return false
	end
	RiftRuntime.BossState = "BossWaitingForPhase"
	setState("BossWaitingForPhase")
	return false
end

-- ============================================================================
-- Rift Trade-In: one controller state, never a parallel worker.  Its remote
-- calls and eligibility checks mirror RiftTradeIn.lua/RiftEligibility.lua.
-- ============================================================================
function RiftRuntime.Clear(reason, retryDelay)
	RiftRuntime.Mode = false
	RiftRuntime.WaitingForTarget = false
	RiftRuntime.State = nil
	RiftRuntime.RequirementsKey = nil
	RiftRuntime.ReservedUids = {}
	RiftRuntime.TargetCategory = nil
	RiftRuntime.TargetAreaId = nil
	RiftRuntime.StateFailures = 0
	RiftRuntime.ActionFailures = 0
	RiftRuntime.NextStateAt = 0
	RiftRuntime.NextActionAt = 0
	RiftRuntime.TradeAccepted = false
	RiftRuntime.FinishRequested = false
	RiftRuntime.RewardUid = nil
	RiftRuntime.RewardConfirmDeadline = 0
	RiftRuntime.RewardPlacementRequested = false
	RiftRuntime.RewardPlacementDeadline = 0
	RiftRuntime.RetryAt = retryDelay and os.clock() + retryDelay or 0
	if reason then log("Rift mode released: " .. reason) end
end

function RiftRuntime.IsLiveAndEligible()
	if EggController.Config.AutoRiftEnabled ~= true or not RiftEligibility
		or not RiftAskStateRemote or not RiftAskTradeInRemote or not RiftAskFinishRevealRemote then
		return false
	end
	local save = getSave()
	local speedPower = tonumber(save and save.SpeedPower)
	if speedPower == nil then return false end
	local liveOk, live = pcall(RiftEligibility.IsFeatureLive)
	local eligibleOk, eligible = pcall(RiftEligibility.IsEligible, speedPower)
	return liveOk and live == true and eligibleOk and eligible == true
end

function RiftRuntime.FetchState()
	local state = invokeRemote(RiftAskStateRemote)
	if typeof(state) ~= "table" then
		RiftRuntime.StateFailures += 1
		return nil
	end
	RiftRuntime.StateFailures = 0
	RiftRuntime.State = state
	return state
end

-- PlayerScripts/RiftTradeIn.lua renders its authoritative AskState response
-- from BannerId (falling back to local rotation only when that field is absent).
-- This controller intentionally does not use that fallback: missing BannerId
-- means no safe proof that the live banner is Shattered Rift.
function RiftRuntime.IsAllowedBanner(state)
	if EggController.Config.AutoRiftShatteredOnly ~= true then return true end
	return typeof(state) == "table" and state.BannerId == "Radiant"
end

function RiftRuntime.Requirements(state)
	local requirements = state and state.Requirements
	if typeof(requirements) ~= "table" or #requirements < 3 then return nil end
	for index = 1, 3 do
		if typeof(requirements[index]) ~= "string" or requirements[index] == "" then return nil end
	end
	return requirements
end

function RiftRuntime.RequirementKey(requirements)
	return table.concat({requirements[1], requirements[2], requirements[3]}, "\31")
end

function RiftRuntime.PetIsEligible(uid, serialized, itemData, equipped)
	if typeof(uid) ~= "string" or typeof(serialized) ~= "table" or typeof(itemData) ~= "table" then return false end
	if equipped[uid] or itemData.IsFavorite == true or itemData.InFuse == true or itemData.CreatorTemporary == true then return false end
	if FuseKernel and typeof(FuseKernel.MayEnterRift) == "function" then
		local ok, allowed = pcall(FuseKernel.MayEnterRift, uid, serialized)
		if not ok or allowed ~= true then return false end
	end
	return true
end

function RiftRuntime.FindSlotUids(requirements)
	local save = getSave()
	local inventory = save and save.Inventory
	if typeof(inventory) ~= "table" then return {}, 0 end
	local equipped = {}
	for _, uid in ipairs(typeof(save.EquippedAssets) == "table" and save.EquippedAssets or {}) do equipped[uid] = true end
	local used, slots, found = {}, {}, 0
	for slot = 1, 3 do
		local requirement, selected = requirements[slot], nil
		for uid, serialized in pairs(inventory) do
			local itemData = getPetItemData(serialized)
			if not used[uid] and itemData and itemData.Category == requirement
				and RiftRuntime.PetIsEligible(uid, serialized, itemData, equipped) then
				if selected == nil or uid < selected then selected = uid end
			end
		end
		if selected then
			slots[slot] = selected
			used[selected] = true
			found += 1
		end
	end
	return slots, found
end

function RiftRuntime.GetUnplannedRequirementCounts(requirements, slots)
	local remaining, required = {}, {}
	for slot = 1, 3 do
		local category = requirements[slot]
		required[category] = true
		if slots[slot] == nil then remaining[category] = (remaining[category] or 0) + 1 end
	end
	-- A placed or newly returned matching egg is already a planned requirement.
	-- Do not collect a duplicate merely because its hatch timer is still running.
	for _, record in pairs(getOwnedEggs()) do
		if typeof(record) == "table" and remaining[record.AssetCategory] and remaining[record.AssetCategory] > 0 then
			remaining[record.AssetCategory] -= 1
		end
	end
	return remaining, required
end

function RiftRuntime.HatchPlacedRequirementEggs(required)
	for uid, record in pairs(getOwnedEggs()) do
		if typeof(uid) == "string" and typeof(record) == "table"
			and required[record.AssetCategory] and record.Placement ~= nil then
			local readyOk, ready = pcall(EggState.IsReadyToHatch, uid)
			if readyOk and ready == true then
				setState("RiftHatchingTarget")
				local beganOk, began = pcall(EggState.BeginHatch, uid)
				if beganOk and began == true then pcall(EggState.FinishHatch, uid) end
			end
		end
	end
end

function RiftRuntime.SelectAvailableTarget(remaining)
	local root = getRoot()
	if not root then return nil, nil end
	local selectedCategory, selectedAreaId, selectedDistance = nil, nil, math.huge
	for category, count in pairs(remaining) do
		if count > 0 then
			local areaId = nil
			if RiftRecipes and typeof(RiftRecipes.SpawnChanceOf) == "function" then
				local ok, _, resolvedAreaId = pcall(RiftRecipes.SpawnChanceOf, category)
				if ok and typeof(resolvedAreaId) == "string" then areaId = resolvedAreaId end
			end
			local target = EggController.GetNearestEggByAssetCategory(category, areaId)
			local position = target and EggController.GetEggPosition(target.Egg) or nil
			if position then
				local delta = root.Position - position
				local distance = delta:Dot(delta)
				if distance < selectedDistance then
					selectedCategory, selectedAreaId, selectedDistance = category, areaId, distance
				end
			end
		end
	end
	return selectedCategory, selectedAreaId
end

function RiftRuntime.MaybeStart()
	if RiftRuntime.Mode or os.clock() < RiftRuntime.RetryAt or not RiftRuntime.IsLiveAndEligible() then return false end
	local now = os.clock()
	if now < RiftRuntime.NextBannerCheckAt then return false end
	RiftRuntime.NextBannerCheckAt = now + math.max(.25, tonumber(EggController.Config.RiftStatePollSeconds) or 1)
	local state = RiftRuntime.FetchState()
	if not RiftRuntime.IsAllowedBanner(state) then return false end
	RiftRuntime.Mode = true
	RiftRuntime.WaitingForTarget = false
	RiftRuntime.StateFailures = 0
	RiftRuntime.ActionFailures = 0
	RiftRuntime.NextStateAt = now + math.max(.25, tonumber(EggController.Config.RiftStatePollSeconds) or 1)
	RiftRuntime.NextActionAt = 0
	-- Leave the belt before any Rift work.  No normal action is reached after
	-- this point while RiftRuntime.Mode remains true.
	if not RiftRuntime.WaitingForTarget and (treadmillTraining or isTreadmillHudVisible()) then
		EggController.StopTreadmillTraining()
	end
	setState("RiftLock")
	log("Rift mode locked")
	return true
end

function RiftRuntime.Run()
	if not RiftRuntime.IsLiveAndEligible() then
		RiftRuntime.Clear("Rift unavailable")
		return false
	end
	if not RiftRuntime.WaitingForTarget and (treadmillTraining or isTreadmillHudVisible()) then
		EggController.StopTreadmillTraining()
	end
	local now = os.clock()
	if RiftRuntime.WaitingForTarget and now < RiftRuntime.NextStateAt then
		return false
	end
	if now >= RiftRuntime.NextStateAt then
		RiftRuntime.NextStateAt = now + math.max(.25, tonumber(EggController.Config.RiftStatePollSeconds) or 1)
		if not RiftRuntime.FetchState() then
			if RiftRuntime.StateFailures >= math.max(1, tonumber(EggController.Config.RiftRemoteFailureLimit) or 3) then
				RiftRuntime.Clear("AskState failed", math.max(1, tonumber(EggController.Config.RiftRecoveryDelay) or 15))
			end
			return false
		end
	end
	local state = RiftRuntime.State
	if not RiftRuntime.IsAllowedBanner(state) then
		RiftRuntime.Clear("current banner is not Shattered Rift")
		return false
	end
	if typeof(state.PendingReward) == "table" then
		if typeof(state.PendingReward.Uid) == "string" then RiftRuntime.RewardUid = state.PendingReward.Uid end
		-- Recover an already-accepted trade (for example after a character reset)
		-- through the same observed AskFinishReveal endpoint before doing any new
		-- sacrifice work.
		if not RiftRuntime.TradeAccepted then
			RiftRuntime.TradeAccepted = true
			RiftRuntime.FinishRequested = false
		end
	end
	local requirements = RiftRuntime.Requirements(state)
	if not requirements then
		RiftRuntime.Clear("invalid Rift requirements", math.max(1, tonumber(EggController.Config.RiftRecoveryDelay) or 15))
		return false
	end
	RiftRuntime.WaitingForTarget = false
	local requirementKey = RiftRuntime.RequirementKey(requirements)
	if RiftRuntime.RequirementsKey ~= requirementKey and not RiftRuntime.TradeAccepted then
		RiftRuntime.RequirementsKey = requirementKey
		RiftRuntime.ReservedUids, RiftRuntime.TargetCategory, RiftRuntime.TargetAreaId = {}, nil, nil
		RiftRuntime.TradeAccepted, RiftRuntime.FinishRequested = false, false
		log("Rift requirements refreshed")
	end

	-- A previous/manual accepted trade has a server-owned PendingReward.  The UI
	-- calls AskFinishReveal only after its presentation callback; this controller
	-- has no UI sequence, so it requests the observed finish endpoint and then
	-- waits for an authoritative AskState response before unlocking.
	if RiftRuntime.TradeAccepted then
		if not RiftRuntime.FinishRequested and now >= RiftRuntime.NextActionAt then
			RiftRuntime.NextActionAt = now + 1
			local ok = pcall(function() RiftAskFinishRevealRemote:InvokeServer() end)
			if ok then
				RiftRuntime.FinishRequested = true
				RiftRuntime.NextStateAt = 0
			else
				RiftRuntime.ActionFailures += 1
				if RiftRuntime.ActionFailures >= math.max(1, tonumber(EggController.Config.RiftRemoteFailureLimit) or 3) then
					RiftRuntime.Clear("finish reveal failed", math.max(1, tonumber(EggController.Config.RiftRecoveryDelay) or 15))
				end
			end
			return false
		end
		if RiftRuntime.FinishRequested and state.PendingReward == false then
			if not RiftRuntime.RewardUid then
				if RiftRuntime.RewardConfirmDeadline <= 0 then
					RiftRuntime.RewardConfirmDeadline = now + math.max(1, tonumber(EggController.Config.RiftRewardConfirmTimeout) or 15)
				end
				if now >= RiftRuntime.RewardConfirmDeadline then
					RiftRuntime.Clear("reward UID was not replicated", math.max(1, tonumber(EggController.Config.RiftRecoveryDelay) or 15))
				else
					setState("RiftConfirmingReward")
				end
				return false
			end
			local rewardEgg = getOwnedEgg(RiftRuntime.RewardUid)
			if not rewardEgg then
				-- AskState is the authoritative completion signal.  Owner egg caches
				-- can trail the finish remote, so keep polling rather than releasing
				-- into normal automation before this observed reward UID appears.
				if RiftRuntime.RewardConfirmDeadline <= 0 then
					RiftRuntime.RewardConfirmDeadline = now + math.max(1, tonumber(EggController.Config.RiftRewardConfirmTimeout) or 15)
				end
				if now < RiftRuntime.RewardConfirmDeadline then
					setState("RiftConfirmingReward")
					return false
				end
				log("Rift completion confirmed by state; owner-egg cache timed out")
				RiftRuntime.Clear("reward cache timed out", math.max(1, tonumber(EggController.Config.RiftRecoveryDelay) or 15))
				return false
			end
			if rewardEgg.Placement ~= nil then
				log("Shattered Rift Egg placed: " .. tostring(RiftRuntime.RewardUid))
				RiftRuntime.Clear("trade-in reward placed")
				return true
			end
			if RiftRuntime.RewardPlacementRequested then
				if now < RiftRuntime.RewardPlacementDeadline then
					setState("RiftWaitingForRewardPlacement")
					return false
				end
				RiftRuntime.RewardPlacementRequested = false
				RiftRuntime.RewardPlacementDeadline = 0
			end
			if now >= RiftRuntime.NextActionAt then
				setState("RiftPlacingReward")
				RiftRuntime.RewardPlacementRequested = true
				RiftRuntime.RewardPlacementDeadline = now + math.max(3, tonumber(EggController.Config.PendingTargetPlacementTimeout) or 15)
				RiftRuntime.NextActionAt = now + 1
				if not EggController.PlaceEgg(RiftRuntime.RewardUid) then
					RiftRuntime.RewardPlacementRequested = false
					RiftRuntime.RewardPlacementDeadline = 0
					RiftRuntime.NextActionAt = now + 2
					log("Rift reward placement not accepted; retrying")
				end
			end
			return false
		end
		return false
	end

	local slots, found = RiftRuntime.FindSlotUids(requirements)
	RiftRuntime.ReservedUids = slots
	if found == 3 then
		RiftRuntime.TargetCategory, RiftRuntime.TargetAreaId = nil, nil
		if now < RiftRuntime.NextActionAt then return false end
		RiftRuntime.NextActionAt = now + 2
		setState("RiftTradeIn")
		local accepted = invokeRemote(RiftAskTradeInRemote, {slots[1], slots[2], slots[3]})
		if accepted == true then
			RiftRuntime.ActionFailures = 0
			RiftRuntime.TradeAccepted = true
			RiftRuntime.FinishRequested = false
			RiftRuntime.NextStateAt = 0
			log("Rift trade-in accepted")
		else
			RiftRuntime.ActionFailures += 1
			if RiftRuntime.ActionFailures >= math.max(1, tonumber(EggController.Config.RiftRemoteFailureLimit) or 3) then
				RiftRuntime.Clear("trade-in rejected", math.max(1, tonumber(EggController.Config.RiftRecoveryDelay) or 15))
			end
		end
		return false
	end

	local remaining, required = RiftRuntime.GetUnplannedRequirementCounts(requirements, slots)
	-- Hatch every ready Rift egg, but never make a non-ready egg block collection
	-- of another requirement that is currently visible in the field.
	RiftRuntime.HatchPlacedRequirementEggs(required)
	local category, areaId = RiftRuntime.SelectAvailableTarget(remaining)
	if not category then
		RiftRuntime.TargetCategory, RiftRuntime.TargetAreaId = nil, nil
		RiftRuntime.WaitingForTarget = true
		setState("RiftWaitingForTarget")
		return false
	end
	RiftRuntime.TargetCategory, RiftRuntime.TargetAreaId = category, areaId
	RiftRuntime.WaitingForTarget = false
	setState("RiftFindingTarget")
	return true
end

function EggController.ResolvePendingEggState()
	local held = EggController.GetHeldEgg()
	if held and isFieldCarrying(held.Uid) then
		if abandonNonTargetStagingCarry(held.Uid) then return true, false end
		pendingEggUid = held.Uid
		return true, deliverAndPlace(held.Uid)
	end
	if not pendingEggUid then return false, nil end
	local pending = getOwnedEgg(pendingEggUid)
	if pending and pending.Placement ~= nil then
		pendingEggUid = nil
		EggController.PendingTargetCategory = nil
		EggController.PendingTargetWaitDeadline = 0
		return false, nil
	end
	if pending and not isSelectedEggRecord(pending, pendingEggUid) then
		pendingEggUid = nil
		EggController.PendingTargetCategory = nil
		EggController.PendingTargetWaitDeadline = 0
		return false, nil
	end
	if pending then
		setState("PlacingEgg")
		if EggController.PlaceEgg(pendingEggUid) then
			pendingEggUid = nil
		end
		return true, false
	end
	if isFieldCarrying(pendingEggUid) then
		return true, deliverAndPlace(pendingEggUid)
	end
	local heldPending = EggController.GetHeldEgg()
	local heldRecord = heldPending and (getFieldRecord(heldPending.Uid) or heldPending.Record) or nil
	if heldPending and heldRecord and EggController.PendingTargetCategory
		and heldRecord.AssetCategory == EggController.PendingTargetCategory then
		pendingEggUid = heldPending.Uid
		EggController.PendingTargetWaitDeadline = 0
		return true, deliverAndPlace(heldPending.Uid)
	end
	if not isFieldCarrying(pendingEggUid) and not heldPending then
		pendingEggUid = nil
		EggController.PendingTargetCategory = nil
		EggController.PendingTargetWaitDeadline = 0
		setState("FindingEgg")
		return true, false
	end
	if time() >= (EggController.PendingTargetWaitDeadline or 0) and (EggController.PendingTargetWaitDeadline or 0) > 0 then
		pendingEggUid = nil
		EggController.PendingTargetCategory = nil
		EggController.PendingTargetWaitDeadline = 0
		return true, false
	end
	setState("WaitingForTargetPlacement")
	return true, false
end

local SCHEDULED_ROUTINES = {
	{
		IsEnabled = function() return EggController.Config.AutoEquipBest end,
		TimerKey = "EquipBest",
		IntervalKey = "EquipBestInterval",
		Execute = function()
			if EggController.RunAutoEquipBest() then
				EggController.Timers.SellPet = os.clock() + 1
				return true
			end
			return false
		end,
	},
	{
		IsEnabled = function() return EggController.Config.AutoSellUnequippedPets end,
		TimerKey = "SellPet",
		IntervalKey = "SellPetInterval",
		Execute = function() return EggController.RunAutoSellUnequippedPets() end,
	},
	{
		IsEnabled = function() return EggController.Config.AutoClaimHouseEarnings end,
		TimerKey = "HouseEarnings",
		IntervalKey = "ClaimHouseEarningsInterval",
		Execute = function() return EggController.RunAutoClaimHouseEarnings() end,
	},
	{
		IsEnabled = function() return EggController.Config.AutoClaimIndex end,
		TimerKey = "IndexClaim",
		IntervalKey = "IndexClaimInterval",
		Execute = function() return EggController.RunAutoClaimIndex() end,
	},
	{
		IsEnabled = function() return EggController.Config.AutoClaimGroupReward end,
		TimerKey = "GroupReward",
		IntervalKey = "GroupRewardClaimInterval",
		Execute = function() return EggController.RunAutoClaimGroupReward() end,
	},
	{
		IsEnabled = function() return EggController.Config.AutoEquipBestTrail end,
		TimerKey = "TrailEquip",
		IntervalKey = "TrailEquipInterval",
		Execute = function() return EggController.RunAutoEquipBestTrail() end,
	},
	{
		IsEnabled = function() return EggController.Config.AutoBuyTrails end,
		TimerKey = "TrailPurchase",
		IntervalKey = "TrailPurchaseInterval",
		Execute = function() return EggController.RunAutoBuyTrails() end,
	},
	{
		IsEnabled = function() return EggController.Config.AutoUpgradeBase or EggController.Config.AutoUpgradeTreadmill end,
		TimerKey = "Upgrade",
		IntervalKey = "UpgradeInterval",
		Execute = function() return EggController.RunAutoUpgrades() end,
	},
}

function EggController.RunScheduledAutomations()
	if EggController.MutationRuntime.Run() then return true end
	if EggController.BossMasteryClaimRuntime.Run() then return true end
	if EggController.Config.AutoPlaceSelectedEggs and EggController.RunAutoPlaceSelectedEggs() then
		return true
	end
	local clockNow = os.clock()
	for _, routine in ipairs(SCHEDULED_ROUTINES) do
		if routine.IsEnabled() and clockNow >= EggController.Timers[routine.TimerKey] then
			EggController.Timers[routine.TimerKey] = clockNow + EggController.Config[routine.IntervalKey]
			if routine.Execute() then return true end
		end
	end
	if EggController.Config.AutoHatchReady and clockNow >= EggController.Timers.Hatch then
		EggController.Timers.Hatch = clockNow + EggController.Config.HatchCheckInterval
		if #EggController.GetReadyEggs() > 0 then setState("HatchingEgg"); EggController.HatchReadyEggs() end
	end
	return false
end

function EggController.SelectCurrentStealTarget()
	local target, stagingTarget = nil, nil
	if RiftRuntime.Mode and RiftRuntime.TargetCategory then
		target = EggController.GetNearestEggByAssetCategory(RiftRuntime.TargetCategory, RiftRuntime.TargetAreaId)
	elseif typeof(EggController.Config.StealEggNewTargetName) == "string" and EggController.Config.StealEggNewTargetName ~= "" then
		target = EggController.GetNearestEligibleEggByName(EggController.Config.StealEggNewTargetName)
	else
		target = EggController.GetBestEligibleEgg() or EggController.GetNearestEligibleEgg()
	end

	if target and EggController.Config.UseStealEggNew then
		stagingTarget = getStealEggNewStagingEgg()
	end
	return target, stagingTarget
end

function EggController.HandleIdleTreadmill()
	local sellingPending = EggController.Config.AutoSellUnequippedPets
		and os.clock() >= EggController.Timers.SellPet
		and #EggController.GetUnequippedPetUids() > 0
	if sellingPending then
		if treadmillTraining or isTreadmillHudVisible() then
			leaveTreadmillForAction("PendingSellAll")
		end
		return
	end
	if treadmillTraining and os.clock() >= nextTreadmillCheckAt then
		local checkSeconds = math.max(1, tonumber(EggController.Config.TreadmillSpeedCheckSeconds) or 5)
		local currentSpeed = getTreadmillSpeedPower()
		if currentSpeed ~= nil and treadmillLastSpeedPower ~= nil and currentSpeed > treadmillLastSpeedPower then
			treadmillLastSpeedPower = currentSpeed
			treadmillSpeedFailureCount = 0
			nextTreadmillCheckAt = os.clock() + checkSeconds
		else
			treadmillSpeedFailureCount += 1
			if currentSpeed ~= nil then treadmillLastSpeedPower = currentSpeed end
			local limit = math.max(1, tonumber(EggController.Config.TreadmillSpeedFailureLimit) or 10)
			if treadmillSpeedFailureCount >= limit then
				clearTreadmillWearForRetry()
				nextTreadmillCheckAt = os.clock() + 1
				if EggController.Config.TreadmillHopOnSpeedFailure then
					hopServerForTreadmillFailure()
				else
					warnLog("Treadmill SpeedPower did not increase after " .. tostring(limit) .. " checks")
				end
			else
				nextTreadmillCheckAt = os.clock() + checkSeconds
			end
		end
	end
	if EggController.Config.AutoTreadmillWhenIdle and not treadmillTraining and not treadmillHopRequested
		and os.clock() >= nextTreadmillCheckAt then
		EggController.RunTreadmillTraining()
	end
end

function EggController.ExecuteStealCycle(target, stagingTarget)
	EggController.TargetName, EggController.TargetRarity = target.Name, target.Rarity
	local carried, carryUid = false, nil
	if EggController.Config.UseStealEggNew then
		carried, carryUid = EggController.StealEggNewStagingThenTarget(stagingTarget, target)
		if not carried then
			warnLog("Bypass TP steal cycle failed for target: " .. tostring(target.Name))
			FailedEggCooldowns[target.Uid] = os.clock() + 4
			return false
		end
	else
		setState("MovingToEgg")
		setState("StealingEgg")
		carried, carryUid = EggController.StealEgg(target)
	end
	if not carried then
		FailedEggCooldowns[target.Uid] = os.clock() + 4
		if stagingTarget and stagingTarget.Uid then
			FailedEggCooldowns[stagingTarget.Uid] = os.clock() + 4
		end
		if not EggController.Config.UseStealEggNew then
			watchdogReportFailure("Egg carry was not confirmed")
		end
		return false
	end
	local targetRecord = getFieldRecord(carryUid)
	EggController.PendingTargetCategory = target.AssetCategory or (targetRecord and targetRecord.AssetCategory)
	EggController.PendingTargetWaitDeadline = 0
	pendingEggUid = carryUid
	return deliverAndPlace(carryUid)
end

function EggController.RunOneFlow()
	if RiftRuntime.BossMode then
		RiftRuntime.BossRun()
		return false
	end
	if os.clock() < (EggController.NextStealAfterPlacement or 0) then
		setState("WaitingAfterPlacement")
		return false
	end
	if EggController.Config.UseStealEggNew and (EggController.Config.AutoStealEnabled or RiftRuntime.Mode or RiftRuntime.BossMode)
		and not prepareStealEggNewForCurrentCharacter() then
		watchdogReportFailure("StealEgg New preparation failed")
		return false
	end
	local handled, flowSuccess = EggController.ResolvePendingEggState()
	if handled then return flowSuccess end

	if RiftRuntime.Mode then
		if not RiftRuntime.Run() and not RiftRuntime.WaitingForTarget then return false end
	end

	local stealWanted = EggController.Config.AutoStealEnabled or (RiftRuntime.Mode and RiftRuntime.WaitingForTarget)
	if stealWanted then
		setState(RiftRuntime.Mode and not RiftRuntime.WaitingForTarget and "RiftFindingTarget" or "FindingEgg")
		local target, stagingTarget = EggController.SelectCurrentStealTarget()
		if target then
			if treadmillTraining or isTreadmillHudVisible() then
				leaveTreadmillForAction("StealEgg")
			end
			nextTreadmillCheckAt = os.clock() + 5
			return EggController.ExecuteStealCycle(target, stagingTarget)
		end
		EggController.TargetName, EggController.TargetRarity = nil, nil
	end

	if not RiftRuntime.Mode or RiftRuntime.WaitingForTarget then
		if EggController.RunScheduledAutomations() then return true end
	end

	if not EggController.Config.AutoStealEnabled and (not RiftRuntime.Mode or RiftRuntime.WaitingForTarget) and not RiftRuntime.BossMode then
		setState("Idle")
		return false
	end

	if RiftRuntime.Mode and not RiftRuntime.WaitingForTarget then
		setState("RiftWaitingForTarget")
		return false
	end
	EggController.HandleIdleTreadmill()
	return false
end
function EggController.RunControllerStep()
	if not EggController.Config.AutomationEnabled then setState("Idle"); return false end
	local humanoid = getHumanoid()
	if not getRoot() or not humanoid or humanoid.Health <= 0 then
		EggController.MutationRuntime.Clear("character unavailable")
		if RiftRuntime.BossMode then RiftRuntime.BossRelease("character dead/reset", tonumber(EggController.Config.BossRecoveryDelay) or 15) end
		setState("WaitingForCharacter")
		return false
	end
	RiftRuntime.BossMaybeStart()
	if RiftRuntime.BossMode then
		EggController.MutationRuntime.Clear("Boss priority pre-emption")
		RiftRuntime.BossRun()
		return false
	end
	RiftRuntime.MaybeStart()
	if RiftRuntime.Mode and not RiftRuntime.WaitingForTarget then EggController.MutationRuntime.Clear("Rift priority pre-emption") end
	-- Watchdog recovery can deliberately start treadmill training, so it must be
	-- bypassed only while Rift is actively working on a target.
	if (not RiftRuntime.Mode or RiftRuntime.WaitingForTarget) and not RiftRuntime.BossMode and watchdogTick() then return false end
	local completed = EggController.RunOneFlow()
	if completed then watchdogMarkProgress() end
	return completed
end
function EggController.StartAutomation()
	if controllerRunning then
		EggController.Config.AutomationEnabled = true
		watchdogReset()
		return true
	end
	EggController.Config.AutomationEnabled, controllerRunning = true, true
	watchdogReset()
	log("Steal rarities enabled: " .. selectedRaritiesText())
	task.spawn(function()
		while active() do
			local ok, err = pcall(EggController.RunControllerStep)
			if not ok then warnLog("Flow error: " .. tostring(err)) end
			task.wait(EggController.Config.ControllerInterval)
		end
		controllerRunning = false
		EggController.MutationRuntime.Clear("automation worker stopped")
		setState("Idle")
	end)
	log("Automation worker started")
	return true
end
function EggController.StartAutoSteal()
	EggController.Config.AutoStealEnabled = true
	return EggController.StartAutomation()
end
function EggController.StopAutoSteal()
	EggController.Config.AutoStealEnabled = false
	EggController.MutationRuntime.Clear("automation stopped")
	EggController.StopTreadmillTraining()
	restoreCharacterControl()
	setState("Idle")
	return true
end
function EggController.StopAutomation()
	EggController.Config.AutomationEnabled = false
	EggController.Config.AutoStealEnabled = false
	EggController.MutationRuntime.Clear("automation stopped")
	EggController.StopTreadmillTraining()
	restoreCharacterControl()
	setState("Idle")
	return true
end
function EggController.GetStatus()
	return {
		State = EggController.State,
		Enabled = EggController.Config.AutomationEnabled,
		AutoStealEnabled = EggController.Config.AutoStealEnabled,
		AllowedEggStates = table.clone(EggController.Config.AllowedEggStates),
		AutoBuyTrails = EggController.Config.AutoBuyTrails,
		AutoTrailProgression = EggController.Config.AutoTrailProgression,
		EquippedTrail = getEquippedTrailName(getSave()),
		KeepMoney = EggController.Config.KeepMoney,
		WatchdogReason = watchdogReason,
		WatchdogBackoffRemaining = math.max(0, math.ceil(watchdogBackoffUntil - os.clock())),
		TargetName = EggController.TargetName,
		TargetRarity = EggController.TargetRarity,
		MoveSpeed = EggController.Config.MoveSpeed,
		PendingEggUid = pendingEggUid,
		IsCarrying = isFieldCarrying(),
		AutoHatchReady = EggController.Config.AutoHatchReady,
		AutoMutationConsumable = EggController.Config.AutoMutationConsumable,
		MutationReservedUid = EggController.MutationRuntime.ReservedUid,
		MutationTargetRate = EggController.MutationRuntime.TargetRate,
		MutationLastResult = EggController.MutationRuntime.LastResult,
		AutoUpgradeBase = EggController.Config.AutoUpgradeBase,
		AutoUpgradeTreadmill = EggController.Config.AutoUpgradeTreadmill,
		AutoTreadmillWhenIdle = EggController.Config.AutoTreadmillWhenIdle,
		TreadmillTraining = treadmillTraining,
		AutoClaimHouseEarnings = EggController.Config.AutoClaimHouseEarnings,
		RiftMode = RiftRuntime.Mode,
		RiftTargetCategory = RiftRuntime.TargetCategory,
		RiftTargetAreaId = RiftRuntime.TargetAreaId,
		RiftReservedUids = table.clone(RiftRuntime.ReservedUids),
		RiftRewardUid = RiftRuntime.RewardUid,
	}
end

Environment.XyraxStealEggController = EggController

-- UI removed: automation remains configuration-driven.
if EggState.CarryChanged and typeof(EggState.CarryChanged.Connect) == "function" then
	EggState.CarryChanged:Connect(function(state)
		heldCarryState = typeof(state) == "table" and state.IsCarrying == true and state or nil
		stealDebug("carry-changed", "CarryChanged: carrying=" .. tostring(heldCarryState ~= nil) .. " uid=" .. tostring(heldCarryState and heldCarryState.Uid), .1)
	end)
end
LocalPlayer.CharacterAdded:Connect(function()
	characterEpoch += 1
	-- Same handling as stealegg.lua: refresh only after a real CharacterAdded.
	-- It does not clear a target or claim the old character "respawned".
	task.delay(.35, function()
		if not active() then return end
		if EggController.Config.UseStealEggNew then
			EggController.PrepareStealEggNew()
		else
			swapStealHumanoid()
		end
	end)
end)

EggController.SetFpsBoost(EggController.Config.FpsBoostEnabled)
if EggController.Config.AutomationEnabled and EggController.Config.AutoStealEnabled then
	EggController.StartAutoSteal()
end

-- ============================================================================
-- Xyrax Monitor Reporter (Steal an Egg) -- READ-ONLY telemetry, wrapped in
-- its own pcall so it can never affect the EggController returned above.
-- ============================================================================
local __xyraxMonitorOk, __xyraxMonitorErr = pcall(function()

local cfg = EggController.Config
if cfg.MonitorEnabled ~= true then return end

local ENDPOINT_URL = "https://dashboard.xyraxhub.xyz/api/v1/heartbeat"
local RAW_MONITOR_KEY = type(cfg.MonitorKey) == "string" and cfg.MonitorKey or ""

local function parseMonitorKey(raw)
	local keyId, apiKey, signingSecret = raw:match("^([^:]+):([^:]+):(.+)$")
	if not (keyId and apiKey and signingSecret) then return nil end
	return {keyId = keyId, apiKey = apiKey, signingSecret = signingSecret}
end

local creds = RAW_MONITOR_KEY ~= "" and parseMonitorKey(RAW_MONITOR_KEY) or nil
if not creds then
	warn("[XyraxStealEgg] [Monitor] disabled: MonitorKey is missing or not in the expected format")
	return
end

local sessionKey = os.clock()
if type(_G.__XyraxMonitorReporter) == "table" and _G.__XyraxMonitorReporter.running then
	warn("[XyraxStealEgg] [Monitor] reporter already running in this session -- replacing with new instance")
end
_G.__XyraxMonitorReporter = {running = true, session = sessionKey}

local CLIENT_ID = type(cfg.MonitorClientId) == "string" and cfg.MonitorClientId or ""
local INTERVAL = tonumber(cfg.MonitorInterval) or 20
if INTERVAL < 15 then INTERVAL = 15 elseif INTERVAL > 30 then INTERVAL = 30 end

if CLIENT_ID == "" then
	local ok, uid = pcall(function() return LocalPlayer.UserId end)
	CLIENT_ID = "auto-" .. tostring((ok and uid) or "unknown")
end
CLIENT_ID = tostring(CLIENT_ID):sub(1, 64):gsub("[^%w_%-%.:]", "")
if CLIENT_ID == "" then CLIENT_ID = "auto" end

local band, bor, bxor = bit32.band, bit32.bor, bit32.bxor
local bnot, rshift, lshift, rrotate = bit32.bnot, bit32.rshift, bit32.lshift, bit32.rrotate

local K = {
	0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
	0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
	0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
	0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
	0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
	0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
	0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
	0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2,
}

local function toBytes32(n)
	return string.char(band(rshift(n, 24), 0xff), band(rshift(n, 16), 0xff),
		band(rshift(n, 8), 0xff), band(n, 0xff))
end

local function sha256bin(msg)
	local h0,h1,h2,h3 = 0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a
	local h4,h5,h6,h7 = 0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19

	local len = #msg
	local bitLen = len * 8
	msg = msg .. "\128" .. string.rep("\0", (55 - len) % 64)
	msg = msg .. string.rep("\0", 4) .. toBytes32(bitLen % 0x100000000)

	local w = {}
	for chunk = 1, #msg, 64 do
		for i = 0, 15 do
			local a,b,c,d = string.byte(msg, chunk + i*4, chunk + i*4 + 3)
			w[i+1] = bor(lshift(a,24), lshift(b,16), lshift(c,8), d)
		end
		for i = 17, 64 do
			local v15, v2 = w[i-15], w[i-2]
			local s0 = bxor(rrotate(v15,7), rrotate(v15,18), rshift(v15,3))
			local s1 = bxor(rrotate(v2,17), rrotate(v2,19), rshift(v2,10))
			w[i] = (w[i-16] + s0 + w[i-7] + s1) % 0x100000000
		end

		local a,b,c,d,e,f,g,h = h0,h1,h2,h3,h4,h5,h6,h7
		for i = 1, 64 do
			local S1 = bxor(rrotate(e,6), rrotate(e,11), rrotate(e,25))
			local ch = bxor(band(e,f), band(bnot(e), g))
			local t1 = (h + S1 + ch + K[i] + w[i]) % 0x100000000
			local S0 = bxor(rrotate(a,2), rrotate(a,13), rrotate(a,22))
			local maj = bxor(band(a,b), band(a,c), band(b,c))
			local t2 = (S0 + maj) % 0x100000000
			h,g,f,e = g,f,e,(d + t1) % 0x100000000
			d,c,b,a = c,b,a,(t1 + t2) % 0x100000000
		end

		h0=(h0+a)%0x100000000 h1=(h1+b)%0x100000000 h2=(h2+c)%0x100000000 h3=(h3+d)%0x100000000
		h4=(h4+e)%0x100000000 h5=(h5+f)%0x100000000 h6=(h6+g)%0x100000000 h7=(h7+h)%0x100000000
	end

	return toBytes32(h0)..toBytes32(h1)..toBytes32(h2)..toBytes32(h3)
		.. toBytes32(h4)..toBytes32(h5)..toBytes32(h6)..toBytes32(h7)
end

local function toHex(bin)
	return (bin:gsub(".", function(ch) return string.format("%02x", string.byte(ch)) end))
end

local function sha256hex(msg) return toHex(sha256bin(msg)) end

local function hmacSha256Hex(key, msg)
	if #key > 64 then key = sha256bin(key) end
	key = key .. string.rep("\0", 64 - #key)
	local o, i = {}, {}
	for n = 1, 64 do
		local b = string.byte(key, n)
		o[n] = string.char(bxor(b, 0x5c))
		i[n] = string.char(bxor(b, 0x36))
	end
	return toHex(sha256bin(table.concat(o) .. sha256bin(table.concat(i) .. msg)))
end

local env = (getgenv and getgenv()) or _G
local httpRequest = (syn and syn.request)
	or (http and http.request)
	or http_request
	or request
	or (fluxus and fluxus.request)
	or (delta and delta.request)
	or (env and (env.request or env.http_request or (env.delta and env.delta.request)))

if type(httpRequest) ~= "function" then
	warn("[XyraxStealEgg] [Monitor] disabled: this executor exposes no HTTP request function")
	return
end

local EggRecords = requireOptional(SharedUtil:FindFirstChild("EggRecords"))

local function buildPetsAndEggs()
	local pets, eggs = {}, {}
	local ok = pcall(function()
		local save = getSave()
		if not save then return end

		if typeof(save.Inventory) == "table" then
			local equipped = {}
			for _, uid in ipairs(typeof(save.EquippedAssets) == "table" and save.EquippedAssets or {}) do
				equipped[uid] = true
			end
			for uid, serialized in pairs(save.Inventory) do
				if #pets >= 300 then break end
				local itemData = getPetItemData(serialized)
				if itemData and typeof(itemData.Category) == "string" then
					local asset = Assets.Directory and Assets.Directory[itemData.Category]
					local income = nil
					if AssetEarnings and typeof(AssetEarnings.CatalogRatePerSecond) == "function" then
						local incomeOk, calculated = pcall(AssetEarnings.CatalogRatePerSecond, itemData)
						if incomeOk then income = tonumber(calculated) end
					end
					local rarity = asset and typeof(asset.Rarity) == "table"
						and (asset.Rarity._id or asset.Rarity.DisplayName) or nil
					pets[#pets + 1] = {
						uid = tostring(uid):sub(1, 64),
						name = tostring(asset and (asset.DisplayName or itemData.Category) or itemData.Category):sub(1, 96),
						category = tostring(itemData.Category):sub(1, 64),
						icon = tostring(asset and asset.Icon or ""):sub(1, 200),
						rarity = tostring(rarity or ""):sub(1, 32),
						mutation = tostring(itemData.BaseMutation or ""):sub(1, 32),
						scale = tonumber(itemData.Scale) or 1,
						income = income,
						equipped = equipped[uid] == true,
					}
				end
			end
		end

		if typeof(save.EggInventory) == "table" then
			for uid, record in pairs(save.EggInventory) do
				if #eggs >= 300 then break end
				if typeof(record) == "table" and typeof(record.AssetCategory) == "string" then
					local asset = Assets.Directory and Assets.Directory[record.AssetCategory]
					local icon = ""
					if EggRecords and typeof(EggRecords.EggIcon) == "function" then
						local iconOk, resolved = pcall(EggRecords.EggIcon, record)
						if iconOk and typeof(resolved) == "string" then icon = resolved end
					end
					if icon == "" and asset and typeof(asset.Egg) == "table" then
						icon = tostring(asset.Egg.Icon or "")
					end
					local rarity = asset and typeof(asset.Rarity) == "table"
						and (asset.Rarity._id or asset.Rarity.DisplayName) or nil
					local name = (asset and typeof(asset.Egg) == "table" and asset.Egg.DisplayName)
						or (asset and asset.DisplayName) or record.AssetCategory
					eggs[#eggs + 1] = {
						uid = tostring(uid):sub(1, 64),
						name = tostring(name or "Egg"):sub(1, 96),
						category = tostring(record.AssetCategory):sub(1, 64),
						icon = tostring(icon):sub(1, 200),
						rarity = tostring(rarity or ""):sub(1, 32),
						mutation = tostring(record.BaseMutation or ""):sub(1, 32),
						scale = tonumber(record.AssetScale) or 1,
					}
				end
			end
		end
	end)
	if not ok then return {}, {} end
	return pets, eggs
end

local function buildPayload()
	local pets, eggs = buildPetsAndEggs()
	local speedPower = 0
	pcall(function()
		local save = getSave()
		speedPower = math.floor(tonumber(save and save.SpeedPower) or 0)
	end)

	return {
		client_id = CLIENT_ID,
		roblox_user_id = (function() local ok, v = pcall(function() return LocalPlayer.UserId end) return ok and v or nil end)(),
		roblox_username = tostring((function() local ok, v = pcall(function() return LocalPlayer.Name end) return ok and v or "" end)()):sub(1, 64),
		roblox_display_name = tostring((function() local ok, v = pcall(function() return LocalPlayer.DisplayName end) return ok and v or "" end)()):sub(1, 64),
		place_id = game.PlaceId,
		universe_id = game.GameId,

		steal_egg = {
			running = EggController.Config.AutomationEnabled == true and EggController.Config.AutoStealEnabled == true,
			current_action = tostring(EggController.State or ""):sub(1, 64),
			speed_power = speedPower,
			pets = pets,
			eggs = eggs,
		},
	}
end

local clockOffset = 0

local function classifyFailure(status, reqOk)
	if not reqOk then return "request-failed-or-timeout" end
	if status == 401 or status == 403 then return "auth-rejected(" .. status .. ")" end
	if status == 429 then return "rate-limited(429)" end
	if status >= 500 then return "server-error(" .. status .. ")" end
	if status == 0 then return "no-response" end
	return "http-" .. tostring(status)
end

local function send(bodyTable)
	local okEncode, json = pcall(function() return HttpService:JSONEncode(bodyTable) end)
	if not okEncode or type(json) ~= "string" then return false, "encode-failed" end

	local ts = tostring(os.time() + clockOffset)
	local guid = ""
	pcall(function() guid = HttpService:GenerateGUID(false) end)
	local nonce = toHex(sha256bin(ts .. guid .. tostring(os.clock()) .. tostring(math.random()))):sub(1, 32)
	local canonical = string.format("%d:%s.%d:%s.%d:%s",
		#ts, ts, #nonce, nonce, 64, sha256hex(json))
	local signature = hmacSha256Hex(creds.signingSecret, canonical)

	local okReq, res = pcall(httpRequest, {
		Url = ENDPOINT_URL,
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/json",
			["X-Monitor-Key-Id"] = creds.keyId,
			["X-Monitor-Key"] = creds.apiKey,
			["X-Monitor-Timestamp"] = ts,
			["X-Monitor-Nonce"] = nonce,
			["X-Monitor-Signature"] = signature,
		},
		Body = json,
	})

	local status = (okReq and type(res) == "table") and (tonumber(res.StatusCode or res.status_code or res.Status) or 0) or 0
	local rawBody = (okReq and type(res) == "table") and (res.Body or res.body or "") or ""
	if okReq and status == 200 then
		pcall(function()
			local decoded = HttpService:JSONDecode(rawBody)
			if type(decoded) == "table" and type(decoded.server_time) == "number" then
				clockOffset = decoded.server_time - os.time()
			end
		end)
		return true
	end
	return false, classifyFailure(status, okReq and type(res) == "table")
end

task.spawn(function()
	task.wait(10)
	local lastFailureLogged = nil
	local backoff = 0
	log(("[XyraxStealEgg] [Monitor] reporter started (client_id=%s interval=%ds)"):format(CLIENT_ID, INTERVAL))
	while _G.__XyraxMonitorReporter and _G.__XyraxMonitorReporter.session == sessionKey and _G.__XyraxMonitorReporter.running do
		local ok, err = pcall(function()
			if backoff > 0 then
				backoff -= 1
				return
			end
			local payload = buildPayload()
			local sent, reason = send(payload)
			if sent then
				if lastFailureLogged then
					log("[XyraxStealEgg] [Monitor] reporting recovered")
					lastFailureLogged = nil
				end
			else
				if lastFailureLogged ~= reason then
					warnLog(("[XyraxStealEgg] [Monitor] report failed (%s) -- automation is unaffected, will keep retrying"):format(tostring(reason)))
					lastFailureLogged = reason
				end
				backoff = 2
			end
		end)
		if not ok and lastFailureLogged ~= "internal" then
			warnLog("[XyraxStealEgg] [Monitor] reporter error: " .. tostring(err))
			lastFailureLogged = "internal"
		end
		task.wait(INTERVAL)
	end
	if type(_G.__XyraxMonitorReporter) == "table" and _G.__XyraxMonitorReporter.session == sessionKey then
		_G.__XyraxMonitorReporter.running = false
	end
end)

end) -- outer pcall
if not __xyraxMonitorOk then
	warn("[XyraxStealEgg] [Monitor] reporter failed to load: " .. tostring(__xyraxMonitorErr))
end

return EggController
