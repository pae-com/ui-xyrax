-- AnimeDice_Kaitun.lua  (Part 2/3: Kaitun engine — core progression)
--
-- Every remote path/argument list below is grounded in the reviewed game's decompiled
-- Scripts/ReplicatedStorage/*.lua source (via two research passes). Anything
-- NOT confirmed there is marked "[GAP]" in a Kaitun:Log call at Init time and
-- is implemented defensively (pcall-guarded, fails closed) rather than guessed.
--============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer

local Framework = ReplicatedStorage:WaitForChild("Framework")
local Features = Framework:WaitForChild("Features")
local Network = ReplicatedStorage:WaitForChild("Network")

--============================================================
-- getgenv().AnimeDiceConfig — read once, here, before anything (including
-- Anti-AFK below) initializes, so a config set before loadstring() can gate
-- even the earliest features in this chunk. Everything it needs to affect
-- gets written onto Kaitun.Toggles/Settings/Config further down (see the
-- merge block right after Kaitun.State) — and since Part 3 (UI) fetches the
-- SAME Kaitun table via `_G.__KaitunEngine` rather than a fresh copy, it sees
-- those already-merged values directly without needing to re-read getgenv()
-- itself.
--============================================================
local function readAnimeDiceConfig()
	local ok, cfg = pcall(function()
		return (typeof(getgenv) == "function") and getgenv().AnimeDiceConfig or nil
	end)
	return (ok and type(cfg) == "table") and cfg or {}
end
local AnimeDiceConfig = readAnimeDiceConfig()

--============================================================
-- Anti-AFK (VirtualInputManager Jump + Idled Protection)
--============================================================
task.spawn(function()
    repeat task.wait() until game:IsLoaded() and game:GetService("Players").LocalPlayer

    local getEnv = (typeof(getgenv) == "function" and getgenv) or function() return _G end
    local env = getEnv()

    if env.AntiAfkJumpRunning then
        env.AntiAfkJumpRunning = false
        task.wait(0.5)
    end
    env.AntiAfkJumpRunning = true

    local PlayersService = game:GetService("Players")
    local CurrentLocalPlayer = PlayersService.LocalPlayer or PlayersService.PlayerAdded:Wait()
    local VirtualInputManager = nil
    pcall(function()
        VirtualInputManager = game:GetService("VirtualInputManager")
    end)
    local VirtualUserService = nil
    pcall(function()
        VirtualUserService = game:GetService("VirtualUser")
    end)

    local function performJump()
        local character = CurrentLocalPlayer.Character
        if not character then return end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then return end

        pcall(function()
            if VirtualInputManager then
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                task.wait(0.1)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
            end
        end)

        pcall(function()
            if VirtualUserService then
                VirtualUserService:CaptureController()
                VirtualUserService:ClickButton2(Vector2.new())
            end
        end)

        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end

    pcall(function()
        CurrentLocalPlayer.Idled:Connect(function()
            if env.AntiAfkJumpRunning then
                performJump()
            end
        end)
    end)

    local intervalSeconds = 600
    while env.AntiAfkJumpRunning do
        task.wait(intervalSeconds)
        if not env.AntiAfkJumpRunning then break end
        performJump()
    end
end)

--============================================================
-- Kaitun root table + logging
--============================================================
-- Preserve only the lock ownership ledger when this fixed version replaces a
-- running older Kaitun instance. That lets AutoLock release the old script's
-- stale bot locks (the inventory-full bug) without ever guessing that a player
-- lock belongs to the bot. Stop the older scheduler before starting this one so
-- the two versions cannot issue competing sell/lock requests.
local PreviousKaitun = _G.__KaitunEngine
local PreviousBotLockedKeys = {}
if type(PreviousKaitun) == "table" then
	PreviousKaitun.Running = false
	local previousInternal = PreviousKaitun._internal
	if type(previousInternal) == "table" then
		if previousInternal.characterConnection then
			pcall(function() previousInternal.characterConnection:Disconnect() end)
			previousInternal.characterConnection = nil
		end
		local previousUltraLite = previousInternal.UltraLite
		if type(previousUltraLite) == "table" and type(previousUltraLite.connections) == "table" then
			for _, connection in ipairs(previousUltraLite.connections) do
				pcall(function() connection:Disconnect() end)
			end
			previousUltraLite.connections = {}
			previousUltraLite.started = false
		end
		if type(previousInternal.uiState) == "table" then
			previousInternal.uiState.running = false
		end
		if type(previousInternal.Window) == "table" and type(previousInternal.Window.Unload) == "function" then
			pcall(function() previousInternal.Window:Unload() end)
		end
		local previousTowerLabel = previousInternal.towerStatusLabel
		if previousTowerLabel and previousTowerLabel.Parent then
			pcall(function() previousTowerLabel.Parent:Destroy() end)
		end
	end
	local previousState = PreviousKaitun.State
	if type(previousState) == "table" and type(previousState.BotLockedKeys) == "table" then
		for key, wasBotLocked in pairs(previousState.BotLockedKeys) do
			if wasBotLocked then PreviousBotLockedKeys[key] = true end
		end
	end
end

-- BotLockedKeys persistence across REAL rejoins (leave and join a new server),
-- not just a same-session script re-run. `_G` above only survives a hot
-- re-execute inside the SAME Lua VM — a rejoin starts a brand new one, wiping
-- it. Without this, every rejoin forgets which locks the bot itself placed, so
-- it treats all of them as player-set and never releases the ones that have
-- gone stale (a unit that was the best pick long ago, long since replaced,
-- sitting locked forever, eating an inventory slot for nothing) — confirmed
-- live: units locked in an earlier session stayed locked and un-sellable no
-- matter how far AutoLockBest's own top-N had moved on without them.
--
-- Guarded with pcall throughout: writefile/readfile/isfile are a common but
-- non-universal executor API (present on Real per this dump's own headers) —
-- if unavailable, this silently falls back to the RAM-only behavior above
-- instead of erroring. The load side runs right here (BOT_LOCKS_FILE / the
-- read into PreviousBotLockedKeys must happen before Kaitun.State is built
-- below); the save side (persistBotLockedKeys) is defined further down, after
-- the real local `Kaitun` table exists, so its closure captures the right one.
local BOT_LOCKS_FILE = "Kaitun_BotLockedKeys.json"

local function loadPersistedBotLockedKeys()
	local ok, exists = pcall(isfile, BOT_LOCKS_FILE)
	if not (ok and exists) then return end
	local ok2, contents = pcall(readfile, BOT_LOCKS_FILE)
	if not (ok2 and type(contents) == "string") then return end
	local ok3, decoded = pcall(function()
		return game:GetService("HttpService"):JSONDecode(contents)
	end)
	if ok3 and type(decoded) == "table" then
		for _, key in ipairs(decoded) do
			if type(key) == "string" then PreviousBotLockedKeys[key] = true end
		end
	end
end
pcall(loadPersistedBotLockedKeys)

local Kaitun = {}
Kaitun.Running = true
Kaitun.Busy = false
Kaitun.CurrentAction = nil
Kaitun.Notifications = {}
Kaitun.LogBuffer = {}
Kaitun.Stats = { TotalRolls = 0, TotalMoneyFromSell = 0, TotalUnitsSold = 0 }
Kaitun.Config = {
	-- [GAP] set to your own `loadstring(game:HttpGet("<raw url>"))()` source URL to
	-- enable queue_on_teleport re-injection across teleports (see setupAutoResume()).
	LoaderURL = "",
	-- Whether setupAutoResume() (queue_on_teleport re-injection) is even attempted.
	-- Defaults true, but it's already a no-op without a LoaderURL, so this only
	-- matters if you specifically want to suppress the attempt/log line too.
	AutoReconnect = true,
	-- UI-related — read (again, fresh) and applied in Part 3 below, since that's
	-- a separate loadstring chunk that builds the MacLib window.
	ShowUI = true,
	StartHidden = false,
	-- "Normal" cycles every difficulty; "Easy", "Medium", "Hard", "Extreme",
	-- or "Infinity" repeats that one difficulty forever.
	TowerMode = "Extreme",
	-- "Normal" consumes Boosts only after an Infinity run; "Instant" consumes
	-- them as soon as the scheduler sees owned Boost items.
	BoostMode = "Instant",
	-- Client-only visual reduction for low-end / multi-client use. This never
	-- deletes gameplay instances; it only disables cosmetic effect classes.
	UltraLite = true,
	FPSCap = 15,
}
Kaitun.Toggles = {
	-- MoneyEconomy is the scheduler entry point for the Collect->Rebirth-Gate->
	-- Dice->Level->Tree->Sell flow — it is not a UI toggle itself, it's the
	-- always-on wrapper; each step inside it is still gated by its own toggle
	-- below (AutoCollectBalance, AutoRebirth, AutoDice, AutoLevelUpSlots,
	-- AutoUpgradeTree, AutoSell), so disabling those has the same effect as
	-- before.
	-- All automation defaults to true (per getgenv().AnimeDiceConfig design —
	-- see the merge block after Kaitun.State below): every one of these is
	-- either fully confirmed against the dump or fails closed/self-skips on
	-- any [GAP], so none of them is unsafe to run unattended. The one
	-- deliberate exception is anything that would need externally-supplied
	-- host/trade data before it could act safely — there is no such feature
	-- implemented in this file (no trade system exists in the dump at all),
	-- so no toggle here needs a false default for that reason.
	MoneyEconomy = true,
	AutoRoll = true,
	AutoRebirth = true,
	AutoGrade = true,
	AutoTrait = true,
	AutoDice = true,
	AutoPlotBest = true,
	AutoLockBest = true,
	AutoSell = true,
	AutoUpgradeTree = true,
	AutoCollectBalance = true,
	AutoLevelUpSlots = true,
	AutoTower = true,
	AutoHideTower = true,
	AutoRedeemCodes = true,
	AutoClaimRewards = true,
	AutoQuestClaim = true,
	AutoBoost = true,
	AutoTrade = false,
	AutoFollowServer = true,
	AutoAcceptTrades = true,
}
Kaitun.Settings = {
	TargetUsername = "",
	TargetServerJobId = "",
	GemsThreshold = 20000,
	TraitThreshold = 20000,
	TransferAll = true,
	TradeCheckInterval = 5,
	-- Max Grade/Trait rolls fired at the current plot-rank active target per
	-- tick (see Ticks.AutoGrade/AutoTrait). Grade/Trait rolling always bypasses
	-- the server's "protected tag" confirmation (GradeService.lua:76 /
	-- TraitService.lua:90 skipProtectedConfirm) because reaching the Z / rainbow
	-- target requires rolling straight through the protected S/S+/Samurai/
	-- Shogun/Monarch tiers on the way up — there is no separate toggle for
	-- that anymore.
	GradeBatchLimit = 3,
	TraitBatchLimit = 3,
	RareAlertThreshold = 1e9,
	AutoSellChanceThreshold = 0,
	-- Dice priority (Dice #1, Rebirth #2, Level #3, Tree #4): buy the next dice
	-- tier immediately whenever `price / currentIncomePerSecond` (how many
	-- seconds of income it costs) is at or below this. Higher = more willing to
	-- delay Rebirth for a dice buy; 0 disables Dice entirely from cutting in
	-- front of Rebirth (every tier waits).
	DiceMaxDelaySeconds = 600,
	-- Overflow safety valve: once owned units / Unit Storage cap reaches this
	-- ratio, AutoSell is allowed to sell units it would normally protect only
	-- for their mutation or roster-rarity (top-chance) — never units that are
	-- plotted, locked, or a keeper. Selling stops once the ratio drops back
	-- below (this value - 0.10).
	OverflowSellEnterRatio = 0.95,
	-- Client-side sell floor, on top of (never instead of) SafeSellSet:
	--   0  = disabled, SafeSellSet alone decides.
	--   >0 = additionally refuse to sell any unit whose CURRENT income
	--        (UnitConfig income(attrs), the same number the game shows as "$X/s")
	--        is at or above this value.
	SellKeepIncome = 0,
	-- Logging is silenced by default (see Kaitun:Log below). true = print only
	-- Dice-related lines (the buy/wait decisions and their delaySeconds math);
	-- false = fully silent, nothing prints at all.
	LogDiceOnly = true,
}

-- Mutable runtime state that must survive across ticks (as opposed to Settings,
-- which the user sets). BotLockedKeys is the record of locks THIS script placed,
-- so reconciliation can release its own stale locks without ever touching a lock
-- the player set by hand (UnitService.lua:333-354 SetLocked accepts key->boolean,
-- so false is a real unlock — which is exactly why we must be careful with it).
Kaitun.State = {
	BotLockedKeys = PreviousBotLockedKeys,
	HeldUnitKey = nil,
	InvestmentKey = nil,
	LastInvestLog = nil,
	NextRollReady = 0,
	LastRollDuration = nil,
	TowerPhase = "Idle", -- Idle -> SelectHard -> EquipBest -> Starting -> InRun -> back to Idle
	TowerDifficultyIndex = 1, -- index into TOWER_DIFFICULTY_ORDER: cycles Easy -> Medium -> Hard -> Extreme -> Infinity -> back to Easy
	LastTowerDifficulty = nil,
}

--============================================================
-- getgenv().AnimeDiceConfig merge — applied here, AFTER every Toggles/
-- Settings/Config default above is set, but BEFORE any Tick, the UI (Part 3,
-- which reads these same tables fresh via _G.__KaitunEngine), or Kaitun.Start()
-- runs. Every key an external config supplies OVERWRITES the hardcoded
-- default; anything it omits keeps that default untouched. `AnimeDiceConfig`
-- was already read at the top of this chunk (before Anti-AFK), so this reuses
-- the same table rather than reading getgenv() twice.
--
-- Mapping covers every Toggles/Settings/Config field that actually exists in
-- this file (see the tables just above) — nothing here is a placeholder for a
-- feature that isn't real, and nothing real is left unmapped.
--============================================================
do
	local BOOL_TOGGLES = {
		AutoRoll = "AutoRoll",
		AutoEquipBest = "AutoPlotBest", -- plot placement now IS the equip-best logic (chance-ranked swap)
		AutoLock = "AutoLockBest",
		AutoSell = "AutoSell",
		AutoGrade = "AutoGrade",
		AutoTrait = "AutoTrait",
		AutoDice = "AutoDice",
		AutoRebirth = "AutoRebirth",
		AutoLevelUnit = "AutoLevelUpSlots",
		AutoUpgrade = "AutoUpgradeTree",
		AutoCollect = "AutoCollectBalance",
		AutoTower = "AutoTower",
		AutoHideTower = "AutoHideTower",
		AutoQuest = "AutoQuestClaim",
		AutoReward = "AutoClaimRewards",
		AutoRedeemCodes = "AutoRedeemCodes", -- real, distinct system; not in the requested list but exists
		AutoBoost = "AutoBoost",
		MoneyEconomyPipeline = "MoneyEconomy", -- the Collect->Rebirth->Dice->Level->Tree->Sell scheduler gate
		AutoTrade = "AutoTrade",
		AutoFollowServer = "AutoFollowServer",
		AutoAcceptTrades = "AutoAcceptTrades",
	}
	for configKey, toggleKey in pairs(BOOL_TOGGLES) do
		local v = AnimeDiceConfig[configKey]
		if type(v) == "boolean" then
			Kaitun.Toggles[toggleKey] = v
		end
	end

	local SETTINGS_FIELDS = {
		VerboseLog = {key = "LogDiceOnly", kind = "boolean"},
		GradeBatchLimit = {key = "GradeBatchLimit", kind = "number"},
		TraitBatchLimit = {key = "TraitBatchLimit", kind = "number"},
		RareAlertThreshold = {key = "RareAlertThreshold", kind = "number"},
		AutoSellChanceThreshold = {key = "AutoSellChanceThreshold", kind = "number"},
		DiceMaxDelaySeconds = {key = "DiceMaxDelaySeconds", kind = "number"},
		OverflowSellEnterRatio = {key = "OverflowSellEnterRatio", kind = "number"},
		SellKeepIncome = {key = "SellKeepIncome", kind = "number"},
		TradeTargetUsername = {key = "TargetUsername", kind = "string"},
		TargetServerJobId = {key = "TargetServerJobId", kind = "string"},
		TradeGemsThreshold = {key = "GemsThreshold", kind = "number"},
		TradeTraitThreshold = {key = "TraitThreshold", kind = "number"},
		TradeAllOnThreshold = {key = "TransferAll", kind = "boolean"},
	}
	for configKey, spec in pairs(SETTINGS_FIELDS) do
		local v = AnimeDiceConfig[configKey]
		if type(v) == spec.kind then
			Kaitun.Settings[spec.key] = v
		end
	end

	-- Top-level / Config fields, not inside Toggles or Settings.
	if type(AnimeDiceConfig.AutoStart) == "boolean" then
		Kaitun.Running = AnimeDiceConfig.AutoStart
	end
	if type(AnimeDiceConfig.LoaderURL) == "string" then
		Kaitun.Config.LoaderURL = AnimeDiceConfig.LoaderURL
	end
	if type(AnimeDiceConfig.AutoReconnect) == "boolean" then
		Kaitun.Config.AutoReconnect = AnimeDiceConfig.AutoReconnect
	end
	if type(AnimeDiceConfig.ShowUI) == "boolean" then
		Kaitun.Config.ShowUI = AnimeDiceConfig.ShowUI
	end
	if type(AnimeDiceConfig.StartHidden) == "boolean" then
		Kaitun.Config.StartHidden = AnimeDiceConfig.StartHidden
	end
	if type(AnimeDiceConfig.TowerMode) == "string" then
		local validTowerModes = {
			Normal = true, Easy = true, Medium = true, Hard = true,
			Extreme = true, Infinity = true,
		}
		-- Invalid config values fail safely to Normal rather than leaving AutoTower
		-- without a selectable difficulty.
		Kaitun.Config.TowerMode = validTowerModes[AnimeDiceConfig.TowerMode]
			and AnimeDiceConfig.TowerMode or "Normal"
	end
	if type(AnimeDiceConfig.BoostMode) == "string" then
		Kaitun.Config.BoostMode = AnimeDiceConfig.BoostMode == "Instant"
			and "Instant" or "Normal"
	end
	if type(AnimeDiceConfig.UltraLite) == "boolean" then
		Kaitun.Config.UltraLite = AnimeDiceConfig.UltraLite
	end
	if type(AnimeDiceConfig.FPSCap) == "number" then
		Kaitun.Config.FPSCap = math.clamp(math.floor(AnimeDiceConfig.FPSCap), 1, 240)
	end
end

-- Save side of BotLockedKeys persistence (see loadPersistedBotLockedKeys
-- above for why this exists). Defined here, after the real local `Kaitun`
-- table exists, so this closure captures IT — not a stray global — when it
-- reads Kaitun.State.BotLockedKeys at call time. Called from AutoLockBest
-- after every SetLocked fire that actually changes something.
local function persistBotLockedKeys()
	if not writefile then return end
	local list = {}
	for key in pairs(Kaitun.State.BotLockedKeys) do list[#list + 1] = key end
	local ok, encoded = pcall(function()
		return game:GetService("HttpService"):JSONEncode(list)
	end)
	if ok then pcall(writefile, BOT_LOCKS_FILE, encoded) end
end

-- Logging silenced by request, EXCEPT the money-spenders — Dice, Level, Tree —
-- so the priority order (Dice #1 > Rebirth #2 > Level #3 > Tree #4) can
-- actually be watched: which one is spending, and why. Filters by the TAG at
-- the very start of the line, not a substring search anywhere in it — every
-- step log's before(...)/after(...) snapshot suffix always contains the
-- substring "Dice=<name>" (it's appended to every line regardless of step),
-- so a plain substring match on "Dice" would wrongly catch Roll/Sell/Boost/
-- EquipBest too; anchoring to the leading "[Tag]" avoids that.
function Kaitun:Log(msg)
	local text = tostring(msg)
	-- [ERROR] and [Pipeline] (a Tick threw and runExclusive/Kaitun.Start caught
	-- it) ALWAYS print regardless of the Dice-only filter below. Without this,
	-- an exception in, say, AutoCollectBalance or AutoSell (which run before
	-- Dice/Level/Tree every cycle) would silently stop the whole MoneyEconomy
	-- pass from ever reaching them — total silence that looks identical to
	-- "nothing to do" instead of "something is broken".
	if text:match("^%[ERROR%]") or text:match("^%[Pipeline%]") then
		print("[Kaitun] " .. text)
		return
	end
	if not Kaitun.Settings.LogDiceOnly then return end
	local tagged = text:match("^%[Dice%]") or text:match("^%[DICE%]")
		or text:match("^%[LevelUpSlot%]") or text:match("^%[LEVEL%]")
		or text:match("^%[UpgradeTree%]") or text:match("^%[TREE%]")
		or text:match("^%[PLOT%]") or text:match("^%[TOWER%]")
		or text:match("^%[GRADE%]") or text:match("^%[TRAIT%]")
		or text:match("^%[AutoGrade%]") or text:match("^%[AutoTrait%]")
	if tagged then
		print("[Kaitun] " .. text)
	end
end

--============================================================
-- Remote cache (kept in one table to stay well clear of Luau's
-- 200-live-local-per-function limit; see memory luau-200-local-limit)
--============================================================
local Net = {}
do
	local function grab(path)
		local inst = Network
		for _, name in ipairs(path) do
			local ok, child = pcall(function() return inst:WaitForChild(name, 8) end)
			if not ok or not child then return nil end
			inst = child
		end
		return inst
	end

	Net.RollDice = grab({"RollService", "RF", "RollDice"})
	Net.SetAutoRoll = grab({"RollService", "RE", "SetAutoRoll"})
	Net.RollMessage = grab({"RollService", "RE", "RollMessage"})
	Net.GradeRoll = grab({"GradeService", "RE", "Roll"})
	Net.TraitRoll = grab({"TraitService", "RE", "Roll"})
	Net.Rebirth = grab({"RebirthService", "RE", "Rebirth"})
	Net.BuyDice = grab({"DiceShopService", "RE", "BuyDice"})
	Net.EquipDice = grab({"DiceShopService", "RE", "EquipDice"})
	Net.UnitEquip = grab({"UnitService", "RF", "Equip"})
	Net.UnitUnequip = grab({"UnitService", "RF", "Unequip"})
	Net.SetLocked = grab({"UnitService", "RE", "SetLocked"})
	Net.EquipBest = grab({"PlotService", "RE", "EquipBest"})
	Net.LevelUpSlot = grab({"PlotService", "RE", "LevelUpSlot"})
	Net.LevelUpSuccess = grab({"PlotService", "RE", "LevelUpSuccess"})
	Net.InteractSlot = grab({"PlotService", "RE", "InteractSlot"})
	Net.CollectBalance = grab({"PlotService", "RE", "CollectBalance"})
	Net.SellInventory = grab({"SellService", "RF", "SellInventory"})
	Net.SellEquipped = grab({"SellService", "RF", "SellEquipped"})
	Net.UpdateAutoSell = grab({"SellService", "RE", "UpdateAutoSell"})
	Net.RedeemCode = grab({"MonetizationService", "RE", "RedeemCode"})
	Net.QuestBuy = grab({"QuestService", "RE", "Buy"})
	Net.QuestClaim = grab({"QuestService", "RE", "Claim"})
	Net.BoostUse = grab({"BoostService", "RE", "Use"})
	-- PlayTower/CompleteTowerFloor/CancelTower are deliberately NOT grabbed here
	-- anymore: Ticks.AutoTower drives Mods.TowerController.startTower (the exact
	-- function the real Fight button calls, TowerSelectionController.lua:125-126)
	-- instead of invoking those remotes directly, so the client's own floor-loop,
	-- team snapshot and UI-visibility state stay authoritative and in sync.
	Net.EquipBestTowerTeam = grab({"Towers", "RE", "EquipBestTowerTeam"})
	Net.UpdateTowerTeam = grab({"Towers", "RE", "UpdateTowerTeam"})
	Net.OnboardingAdvance = grab({"OnboardingService", "RE", "Advance"})
	Net.DailyClaim = grab({"DailyRewardService", "RE", "Claim"})
	Net.OfflineClaim = grab({"OfflineEarningsService", "RE", "Claim"})
	Net.GroupClaim = grab({"GroupRewardService", "RE", "Claim"})
	Net.TextNotification = grab({"NotificationService", "RE", "TextNotification"})
	Net.DropNotification = grab({"NotificationService", "RE", "DropNotification"})

	-- Network.RE.BuyUpgrade lives at the Network root, not under a sub-service
	-- (ReplicatedStorage/UpgradeController.lua:55 uses Network.Client.GetSignal
	-- directly on ReplicatedStorage.Network — confirmed against Reports/02_remotes_index.txt).
	local reFolder = Network:FindFirstChild("RE")
	Net.BuyUpgrade = reFolder and reFolder:FindFirstChild("BuyUpgrade")

	Net.RequestTrade = grab({"TradeService", "RE", "RequestTrade"})
	Net.RespondToRequest = grab({"TradeService", "RE", "RespondToRequest"})
	Net.ChangeOffer = grab({"TradeService", "RE", "ChangeOffer"})
	Net.AdvanceTrade = grab({"TradeService", "RE", "AdvanceTrade"})
	Net.CancelTrade = grab({"TradeService", "RE", "CancelTrade"})
	Net.TradeEvent = grab({"TradeService", "RE", "TradeEvent"})
end

--============================================================
-- Module cache (live game modules — we read real tables/functions at
-- runtime instead of hardcoding transcribed values, so Kaitun tracks
-- game updates automatically instead of drifting from a stale copy)
--============================================================
local Mods = {}
do
	local function req(path)
		local inst = Features
		for _, name in ipairs(path) do
			inst = inst and inst:FindFirstChild(name)
		end
		if not inst then return nil end
		local ok, result = pcall(require, inst)
		if not ok then return nil end
		return result
	end

	Mods.DataController = req({"Data", "DataController"})
	Mods.Grades = req({"Grades", "Grades"})
	Mods.Traits = req({"Traits", "Traits"})
	Mods.Rebirths = req({"Rebirth", "Rebirths"})
	Mods.UnitConfig = req({"Inventory", "Kinds", "Unit", "UnitConfig"})
	Mods.UnitController = req({"Inventory", "Kinds", "Unit", "UnitController"})
	Mods.Dice = req({"Rolling", "Dice"})
	Mods.PlotConfig = req({"Plot", "PlotConfig"})
	Mods.QuestConfig = req({"Quests", "QuestConfig"})
	Mods.TreeStructure = req({"Upgrades", "TreeStructure"})
	Mods.Upgrades = req({"Upgrades", "Upgrades"})
	Mods.MonetizationConfig = req({"Monetization", "MonetizationConfig"})
	Mods.Towers = req({"Towers", "Towers"})
	Mods.TowerRefs = req({"Towers", "TowerRefs"})
	-- TowerController is the module the real Fight/Auto/Exit buttons are wired
	-- to (TowerController.lua, required by the game's own TowerSelectionController
	-- at load time) — Ticks.AutoTower calls its exported startTower(name) instead
	-- of reimplementing the floor loop. UIReferences.Root.Tower.Screen.Visible is
	-- the one real, externally-readable "a run is currently active" signal
	-- (set true in towerStarted(), false in towerEnded()).
	Mods.TowerController = req({"Towers", "TowerController"})
	Mods.UIReferences = req({"UI", "UIReferences"})
	-- HUDController.showAll/hideAll("inTower") is the exact pair TowerController's
	-- own setTowerHidden(bool) calls when the real Hide pill is pressed
	-- (TowerController.lua:79-89) — used by Ticks.AutoTower to replicate Hide
	-- without a remote (there isn't one; Hide is 100% client-only).
	Mods.HUDController = req({"UI", "HUDController"})
	Mods.BoostConfig = req({"Inventory", "Kinds", "Boost", "BoostConfig"})
	-- BuffController (Framework.Features.Buffs.BuffController) mirrors the
	-- server's fully-computed buff table to the client: BuffService.lua:44
	-- publishes it as ServerComm property "Cache" and BuffController.lua:62-76
	-- observes that property, with GetBuff(name) falling back to
	-- BuffsConfig.GetBuff(name).default. So GetBuff("Money Multiplier") /
	-- ("Roll Duration") / ("Unit Storage") / ("Luck") / ("Sell Multiplier") are
	-- the REAL numbers the server is using — no client-side re-derivation of
	-- the base*multiplier*percent aggregation, and no guessing.
	Mods.BuffController = req({"Buffs", "BuffController"})
	Mods.BuffsConfig = req({"Buffs", "BuffsConfig"})
	Mods.Mutations = req({"Inventory", "Kinds", "Unit", "Mutations"})
end

--============================================================
-- Small safe-call helpers (timeout + retry-limit + recovery)
--============================================================
-- Runs InvokeServer on its OWN thread (task.spawn) and polls for it instead of
-- yielding on it directly. If the server never responds — the exact failure
-- mode caught live right after a re-join, where every Tick, every log line,
-- went permanently silent — a bare `pcall(InvokeServer)` never returns, which
-- means the calling Tick never returns, which means runExclusive's Kaitun.Busy
-- mutex is held forever, which means every single Tick in the bot (not just
-- this one) silently no-ops as "busy" from that moment on — with no error,
-- because "busy" is explicitly not logged. Polling with a bounded wait instead
-- means THIS call gives up and returns after `timeoutSec`, releasing Busy,
-- even though the orphaned InvokeServer thread may still be hung in the
-- background forever (harmless — it holds no lock, it's just an abandoned
-- coroutine).
local function invokeWithTimeout(remoteFunction, timeoutSec, ...)
	local args = table.pack(...)
	local done, packed = false, nil
	task.spawn(function()
		packed = table.pack(pcall(function()
			return remoteFunction:InvokeServer(table.unpack(args, 1, args.n))
		end))
		done = true
	end)
	local waited = 0
	while not done and waited < timeoutSec do
		task.wait(0.05)
		waited += 0.05
	end
	if not done then return false end
	if packed[1] then
		return true, table.unpack(packed, 2, packed.n)
	end
	return false
end

local function safeInvoke(remoteFunction, retries, ...)
	if not remoteFunction then return false end
	retries = retries or 2
	local args = table.pack(...)
	for attempt = 1, retries do
		local results = table.pack(invokeWithTimeout(remoteFunction, 6, table.unpack(args, 1, args.n)))
		if results[1] then
			return true, table.unpack(results, 2, results.n)
		end
		task.wait(0.4 * attempt)
	end
	return false
end

local function safeFire(remoteEvent, ...)
	if not remoteEvent then return false end
	-- `...` cannot be referenced inside the nested anonymous function passed to
	-- pcall (Luau closures do not capture varargs as upvalues) — capture it into
	-- a table first, then unpack that table inside the closure instead.
	local args = table.pack(...)
	local ok = pcall(function()
		remoteEvent:FireServer(table.unpack(args, 1, args.n))
	end)
	return ok
end

-- Central mutex so no two systems touch the network/game state at once.
local function runExclusive(name, fn)
	if Kaitun.Busy then return false, "busy" end
	Kaitun.Busy = true
	Kaitun.CurrentAction = name
	local ok, err = pcall(fn)
	Kaitun.Busy = false
	Kaitun.CurrentAction = nil
	if not ok then
		Kaitun:Log("[ERROR] " .. name .. ": " .. tostring(err))
	end
	return ok, err
end

local function waitUntilLoaded(timeout)
	local t0 = os.clock()
	while os.clock() - t0 < timeout do
		local ok, money = pcall(function()
			return Mods.DataController and Mods.DataController.Money and Mods.DataController.Money()
		end)
		if ok and type(money) == "number" then return true end
		task.wait(0.25)
	end
	return false
end

local function waitForNotification(timeout)
	local startCount = #Kaitun.Notifications
	local t0 = os.clock()
	while os.clock() - t0 < timeout do
		if #Kaitun.Notifications > startCount then
			return Kaitun.Notifications[#Kaitun.Notifications]
		end
		task.wait(0.1)
	end
	return nil
end

if Net.TextNotification then
	Net.TextNotification.OnClientEvent:Connect(function(payload)
		if type(payload) == "table" then
			table.insert(Kaitun.Notifications, {
				message = payload.message,
				notificationType = payload.notificationType,
				time = os.clock(),
			})
			if #Kaitun.Notifications > 50 then table.remove(Kaitun.Notifications, 1) end
			Kaitun:Log(("[Notify:%s] %s"):format(tostring(payload.notificationType), tostring(payload.message)))
		end
	end)
else
	Kaitun:Log("[GAP] NotificationService.RE.TextNotification not found — insufficient-currency detection for Grade/Trait rolling will not auto-stop.")
end

if Net.DropNotification then
	Net.DropNotification.OnClientEvent:Connect(function(entryName, amount)
		Kaitun:Log(("[Drop] +%s %s"):format(tostring(amount), tostring(entryName)))
	end)
end

--============================================================
-- Evidence-grounded lookups (Grades.lua / Traits.lua may expose the tier
-- table directly OR behind Get()/GetNext() wrappers like Rebirths.lua does
-- — the research pass confirmed the data but not which shape Grades/Traits
-- itself uses, so both paths are tried defensively; see [GAP] notes.)
--============================================================
local function getGradeInfo(name)
	if not (Mods.Grades and name) then return nil end
	if Mods.Grades[name] then return Mods.Grades[name] end
	if Mods.Grades.Get then
		local ok, info = pcall(Mods.Grades.Get, name)
		if ok then return info end
	end
	return nil
end

local function getTraitInfo(name)
	if not (Mods.Traits and name) then return nil end
	if Mods.Traits[name] then return Mods.Traits[name] end
	if Mods.Traits.Get then
		local ok, info = pcall(Mods.Traits.Get, name)
		if ok then return info end
	end
	return nil
end

local function getUnitScore(entry)
	if not (Mods.UnitConfig and Mods.UnitConfig.entries) then return 0 end
	local cfg = Mods.UnitConfig.entries[entry.name]
	if not cfg or not cfg.income then return 0 end
	local ok, score = pcall(cfg.income, entry.attributes or {})
	return (ok and type(score) == "number") and score or 0
end

-- The Inventory table (DataController.Inventory) holds both Unit entries and
-- stackable currency/dice-like entries (Gems, Trait Reroll, ...) in the same
-- shape. We identify "this is a Unit" by checking membership in the confirmed
-- UnitConfig roster (UnitConfig.lua entries table) rather than guessing a
-- "kind" field we never read (EntryRegistry.lua was not opened by research).
local function getOwnedUnits()
	local list = {}
	if not (Mods.DataController and Mods.DataController.Inventory and Mods.UnitConfig and Mods.UnitConfig.entries) then
		return list
	end
	local ok, inv = pcall(Mods.DataController.Inventory)
	if not ok or type(inv) ~= "table" then return list end
	for key, entry in pairs(inv) do
		if type(entry) == "table" and Mods.UnitConfig.entries[entry.name] then
			list[#list + 1] = {
				key = key,
				name = entry.name,
				attributes = entry.attributes or {},
				score = getUnitScore({name = entry.name, attributes = entry.attributes}),
			}
		end
	end
	table.sort(list, function(a, b) return a.score > b.score end)
	return list
end

local function isPlaced(key)
	if not (Mods.DataController and Mods.DataController.Slots) then return false end
	local ok, slots = pcall(Mods.DataController.Slots)
	if not ok or type(slots) ~= "table" then return false end
	for _, slot in pairs(slots) do
		if type(slot) == "table" and slot.unitId == key then return true end
	end
	return false
end

-- [GAP] UnitController.EquippedUnit is exposed as a State-pattern node per the
-- research pass (same reactive-callable pattern as every DataController field),
-- but its exact internal shape wasn't independently re-verified — pcall-guarded,
-- fails to "not equipped" if the shape differs rather than guessing true/false.
local function isEquipped(key)
	local ok, val = pcall(function()
		return Mods.UnitController and Mods.UnitController.EquippedUnit and Mods.UnitController.EquippedUnit()
	end)
	return ok and val == key
end

local function isPlacedOrEquipped(key)
	return isPlaced(key) or isEquipped(key)
end

--============================================================
-- Live buff / inventory readers (all values below are the REAL server-side
-- numbers, read through confirmed APIs — nothing is re-derived or assumed):
--
--   getBuff(name)       BuffController.GetBuff (BuffController.lua:38-47) which
--                       reads BuffService's replicated "Cache" property
--                       (BuffService.lua:44,190) — already includes Upgrade-tree
--                       nodes (base/percentage buckets), Rebirth multipliers,
--                       active Boosts and gamepasses, i.e. exactly what
--                       BuffService.GetBuff returns server-side.
--   getEntryAmount(n)   EntryService.GetAmount == Inventory[name]().amount
--                       (EntryService.lua:97-107) — stackable entries such as
--                       "Gems" and "Trait Reroll" are keyed by their own NAME.
--   getUnitStorageCap() the exact expression RollService.lua:165 compares the
--                       owned-unit count against before refusing to roll.
--   getEffectiveLuck()  RollService.lua:191: Dice.luck * GetBuff("Luck").
--============================================================
local function getBuff(name)
	local ok, value = pcall(function()
		return Mods.BuffController and Mods.BuffController.GetBuff and Mods.BuffController.GetBuff(name)
	end)
	if ok and type(value) == "number" then return value end
	local ok2, cfg = pcall(function()
		return Mods.BuffsConfig and Mods.BuffsConfig.GetBuff and Mods.BuffsConfig.GetBuff(name)
	end)
	if ok2 and type(cfg) == "table" and type(cfg.default) == "number" then return cfg.default end
	return nil
end

local function getEntryAmount(entryName)
	local ok, entry = pcall(function()
		return Mods.DataController and Mods.DataController.Inventory
			and Mods.DataController.Inventory[entryName] and Mods.DataController.Inventory[entryName]()
	end)
	if ok and type(entry) == "table" and type(entry.amount) == "number" then return entry.amount end
	return 0
end

local function getUnitInventoryCount()
	local count = 0
	if not (Mods.DataController and Mods.DataController.Inventory and Mods.UnitConfig and Mods.UnitConfig.entries) then
		return count
	end
	local ok, inv = pcall(Mods.DataController.Inventory)
	if not ok or type(inv) ~= "table" then return count end
	for _, entry in pairs(inv) do
		if type(entry) == "table" and Mods.UnitConfig.entries[entry.name] then count += 1 end
	end
	return count
end

local function getUnitStorageCap()
	local storage = getBuff("Unit Storage")
	local rolls = getBuff("Rolls")
	if type(storage) ~= "number" then return nil end
	return storage + ((type(rolls) == "number" and rolls or 1) - 1)
end

local function getEffectiveLuck()
	local luckBuff = getBuff("Luck")
	local ok, diceName = pcall(function()
		return Mods.DataController and Mods.DataController.Dice and Mods.DataController.Dice()
	end)
	local diceLuck = nil
	if ok and diceName and Mods.Dice and Mods.Dice.Get then
		local ok2, cfg = pcall(Mods.Dice.Get, diceName)
		if ok2 and type(cfg) == "table" and type(cfg.luck) == "number" then diceLuck = cfg.luck end
	end
	if type(luckBuff) ~= "number" or not diceLuck then return nil end
	return diceLuck * luckBuff
end

-- Expected income multiplier of ONE reroll, computed live from the config's own
-- weights. Both reroll handlers pick uniformly-by-weight across the WHOLE table
-- and ignore the current value (TraitService.lua:39-62 rollTrait / GradeService's
-- identical rollGrade), so E[mult] = sum(weight*incomeMultiplier)/sum(weight).
-- Rerolling anything already above this number is a losing bet in expectation —
-- which is the evidence-based replacement for hardcoding "protect Samurai+".
local function getExpectedRerollIncomeMultiplier(configTable)
	if type(configTable) ~= "table" then return nil end
	local totalWeight, weighted = 0, 0
	for _, info in pairs(configTable) do
		if type(info) == "table" and type(info.weight) == "number" and info.weight > 0 then
			totalWeight += info.weight
			weighted += info.weight * (type(info.incomeMultiplier) == "number" and info.incomeMultiplier or 1)
		end
	end
	if totalWeight <= 0 then return nil end
	return weighted / totalWeight
end

Kaitun._internal = {
	Net = Net,
	Mods = Mods,
	safeInvoke = safeInvoke,
	safeFire = safeFire,
	runExclusive = runExclusive,
	waitUntilLoaded = waitUntilLoaded,
	waitForNotification = waitForNotification,
	getGradeInfo = getGradeInfo,
	getTraitInfo = getTraitInfo,
	getUnitScore = getUnitScore,
	getOwnedUnits = getOwnedUnits,
	isPlaced = isPlaced,
	isEquipped = isEquipped,
	isPlacedOrEquipped = isPlacedOrEquipped,
	getBuff = getBuff,
	getEntryAmount = getEntryAmount,
	getUnitInventoryCount = getUnitInventoryCount,
	getUnitStorageCap = getUnitStorageCap,
	getEffectiveLuck = getEffectiveLuck,
	getExpectedRerollIncomeMultiplier = getExpectedRerollIncomeMultiplier,
	persistBotLockedKeys = persistBotLockedKeys,
}

_G.__KaitunEngine = Kaitun
--============================================================
-- End of Part 2 (engine core). Part 3 adds the feature Ticks + UI.
--============================================================
--============================================================
-- AnimeDice_Kaitun.lua  (Part 3a/3: feature Ticks + scheduler)
--============================================================
local Kaitun = _G.__KaitunEngine
local Net = Kaitun._internal.Net
local Mods = Kaitun._internal.Mods
local safeInvoke = Kaitun._internal.safeInvoke
local safeFire = Kaitun._internal.safeFire
local waitForNotification = Kaitun._internal.waitForNotification
local getGradeInfo = Kaitun._internal.getGradeInfo
local getTraitInfo = Kaitun._internal.getTraitInfo
local getOwnedUnits = Kaitun._internal.getOwnedUnits
local isPlacedOrEquipped = Kaitun._internal.isPlacedOrEquipped
local getUnitScore = Kaitun._internal.getUnitScore
local getBuff = Kaitun._internal.getBuff
local getEntryAmount = Kaitun._internal.getEntryAmount
local getUnitInventoryCount = Kaitun._internal.getUnitInventoryCount
local getUnitStorageCap = Kaitun._internal.getUnitStorageCap
local getEffectiveLuck = Kaitun._internal.getEffectiveLuck
local getExpectedRerollIncomeMultiplier = Kaitun._internal.getExpectedRerollIncomeMultiplier
local persistBotLockedKeys = Kaitun._internal.persistBotLockedKeys

local Ticks = {}

--============================================================
-- potential(unit) / trait+grade multipliers — shared by the ROI-based
-- AutoLevelUpSlots (income-growth investment) AND the Keeper Target Selection
-- used by AutoGrade/AutoTrait below. Definition re-verified against
-- UnitConfig.lua:365-395: income({mutation=...}) with no level/trait/grade
-- passed defaults level=1 and skips the trait/grade multiplier branches
-- entirely, leaving exactly `(baseChance * mutation.chance)^0.725` — the
-- unit's permanent ceiling, independent of anything Kaitun itself invested
-- (level-ups, grade rolls, trait rerolls). Mutation is kept because no
-- reroll remote exists for it anywhere in the 52-remote index — it is a
-- permanent property of that specific rolled instance, not an investment.
--============================================================
local function getUnitPotential(entry)
	if not (Mods.UnitConfig and Mods.UnitConfig.entries) then return 0 end
	local cfg = Mods.UnitConfig.entries[entry.name]
	if not cfg or not cfg.income then return 0 end
	local ok, score = pcall(cfg.income, {mutation = entry.attributes and entry.attributes.mutation})
	return (ok and type(score) == "number") and score or 0
end

local function getUnitMultipliers(entry)
	local traitMult, gradeMult = 1, 1
	if entry.attributes and entry.attributes.trait then
		local info = getTraitInfo(entry.attributes.trait)
		if info and type(info.incomeMultiplier) == "number" then traitMult = info.incomeMultiplier end
	end
	if entry.attributes and entry.attributes.grade then
		local info = getGradeInfo(entry.attributes.grade)
		if info and type(info.incomeMultiplier) == "number" then gradeMult = info.incomeMultiplier end
	end
	return traitMult, gradeMult
end

--============================================================
-- Core-progression state tracking and bounded operational logging
-- Every step in the Roll -> EquipBest -> Lock -> Sell -> UpgradeDice -> Rebirth
-- pipeline logs: current state, the exact Remote + args it calls, a before/after
-- snapshot of the values that action is supposed to move, and success/error/skip
-- with a reason. Kaitun.CoreState always reflects "state ปัจจุบัน" for whichever
-- of the six steps last ran, so a log dump always shows where the run stalled.
--============================================================
Kaitun.CoreState = "Idle"

local function setCoreState(step)
	Kaitun.CoreState = step
end

local function snapshotCore()
	local snap = {}
	local ok1, money = pcall(function() return Mods.DataController and Mods.DataController.Money and Mods.DataController.Money() end)
	snap.Money = ok1 and money or nil
	local ok2, rebirth = pcall(function() return Mods.DataController and Mods.DataController.Rebirth and Mods.DataController.Rebirth() end)
	snap.Rebirth = ok2 and rebirth or nil
	local ok3, dice = pcall(function() return Mods.DataController and Mods.DataController.Dice and Mods.DataController.Dice() end)
	snap.Dice = ok3 and dice or nil
	local ok4, inv = pcall(function() return Mods.DataController and Mods.DataController.Inventory and Mods.DataController.Inventory() end)
	snap.InventoryCount = (ok4 and type(inv) == "table") and (function()
		local n = 0
		for _ in pairs(inv) do n += 1 end
		return n
	end)() or nil
	return snap
end

local function fmtSnapshot(s)
	return ("Money=%s Rebirth=%s Dice=%s InvCount=%s"):format(
		tostring(s.Money), tostring(s.Rebirth), tostring(s.Dice), tostring(s.InventoryCount))
end

local function fmtArgs(...)
	local n = select("#", ...)
	if n == 0 then return "()" end
	local parts = {}
	for i = 1, n do
		local v = select(i, ...)
		if type(v) == "table" then
			local count = 0
			for _ in pairs(v) do count += 1 end
			parts[i] = ("<table,#%d>"):format(count)
		else
			parts[i] = tostring(v)
		end
	end
	return "(" .. table.concat(parts, ", ") .. ")"
end

local function logStepStart(step, remoteDesc, ...)
	setCoreState(step)
	local before = snapshotCore()
	Kaitun:Log(("[%s] state=%s remote=%s args=%s before(%s)"):format(step, step, remoteDesc, fmtArgs(...), fmtSnapshot(before)))
	return before
end

-- Repeated identical status lines are logged once and then suppressed until the
-- message actually changes. Systems in the Money-Economy pipeline re-evaluate
-- every 3s, so without this a single stable condition ("cheapest node costs more
-- than you have") reprints ~1,200 times an hour and buries the events that
-- matter. The first occurrence and every change still print immediately.
local lastLineByKey = {}

-- `stamp` lets a caller dedupe on a STABLE identity while still printing a line
-- that contains live numbers (which would otherwise differ every tick and defeat
-- the comparison). Without it, the line itself is the identity.
local function logOnce(key, line, stamp)
	local id = stamp or line
	if lastLineByKey[key] == id then return false end
	lastLineByKey[key] = id
	Kaitun:Log(line)
	return true
end

local function clearLogOnce(key)
	lastLineByKey[key] = nil
end

local function logStepSkip(step, reason)
	setCoreState(step)
	logOnce("skip:" .. step, ("[%s] SKIP: %s"):format(step, reason))
end

local function logStepResult(step, ok, extra)
	-- A real result means the situation moved: allow the next identical skip
	-- message for this step to print again.
	clearLogOnce("skip:" .. step)
	local after = snapshotCore()
	if ok then
		Kaitun:Log(("[%s] OK %s after(%s)"):format(step, extra or "", fmtSnapshot(after)))
	else
		Kaitun:Log(("[%s] ERROR %s after(%s)"):format(step, extra or "(InvokeServer/FireServer failed after retries)", fmtSnapshot(after)))
	end
end

--============================================================
-- Roll  (ReplicatedStorage/RollController.lua:394,472 ; RollService.lua:139-243)
-- RF.RollDice() takes no args; returns (results[], luckUsed, rollCount, isSpin, spinName).
-- Reward is granted server-side already — the client loop is purely for the
-- roll animation, so "auto roll" here is simply calling RollDice on a timer.
--============================================================
-- cfg.chance on a UnitConfig roster entry is a FUNCTION of attrs (same pattern
-- as cfg.income/damage/health — confirmed in the research report: "chance(attrs)
-- -> number ... used as the roll weight"), not a plain number. Comparing it
-- directly to a number (as an earlier version of this file did) crashes with
-- "attempt to compare number <= function". Always call it, pcall-guarded.
local function getUnitChanceValue(unitName, attrs)
	local cfg = Mods.UnitConfig and Mods.UnitConfig.entries and Mods.UnitConfig.entries[unitName]
	if not cfg or not cfg.chance then return nil end
	local ok, value = pcall(cfg.chance, attrs or {})
	if ok and type(value) == "number" then return value end
	return nil
end

-- The roll cooldown is NOT a guess — RollService.lua:144-151 is explicit:
--
--   if u142[p1] then return end                       -- in-flight -> returns nil
--   u142[p1] = true
--   local v6 = BuffService.GetBuff(p1, "Roll Duration")
--   task.delay(v6, function() u142[p1] = nil end)     -- exactly this long
--
-- So a successful roll blocks the next one for precisely GetBuff("Roll Duration")
-- seconds, and every early attempt inside that window returns nil — which is
-- what produced the "return shape was nil ... backing off" spam in the live log.
-- BuffsConfig.lua:88 sets the default to 2.5s and each "Roll Speed" node adds
-- -0.15 to the base bucket (Upgrades.lua), and BuffController hands us the
-- already-aggregated value, so we can schedule the next roll exactly instead of
-- probing for it. Adaptive backoff is kept ONLY as a fallback for the case
-- where the buff Cache is unavailable or the server returns nil anyway.
--
-- RollService.lua:164-171 additionally refuses to roll (with a red banner) when
--   GetBuff("Unit Storage") + (GetBuff("Rolls") - 1) <= ownedUnitCount
-- so that condition is checked first: firing into it only produces an error
-- notification and wastes the tick.
local rollBackoffUntil = 0
local rollBackoffStep = 0.5
local ROLL_LATENCY_MARGIN = 0.1 -- round-trip slack only; not a game constant

function Ticks.AutoRoll()
	if not Net.RollDice then
		logStepSkip("Roll", "RollService.RF.RollDice remote missing (see [GAP] logged at startup)")
		return
	end
	if os.clock() < rollBackoffUntil then
		return -- quietly waiting out the adaptive backoff from the previous no-op roll
	end
	if os.clock() < Kaitun.State.NextRollReady then
		return -- quietly waiting out the REAL Roll Duration cooldown
	end

	local cap = getUnitStorageCap()
	if cap then
		local owned = getUnitInventoryCount()
		if owned >= cap then
			logStepSkip("Roll", ("unit inventory full: %d owned vs cap %d (Unit Storage buff + Rolls - 1, RollService.lua:165) — rolling would only raise an error banner; waiting for Sell / Unit Storage upgrade"):format(owned, cap))
			Kaitun.State.NextRollReady = os.clock() + 2
			return
		end
	end

	logStepStart("Roll", "Network.RollService.RF.RollDice")
	local ok, rolled, luckUsed, rollCount, isSpin, spinName = safeInvoke(Net.RollDice, 2)
	if not ok then
		logStepResult("Roll", false, "InvokeServer failed after 2 retries (likely server debounce: a roll is already in-flight, or unit inventory is full)")
		rollBackoffUntil = os.clock() + 1.0
		return
	end
	if type(rolled) ~= "table" then
		logStepResult("Roll", true, ("return shape was %s instead of a results table (roll still in flight) — backing off %.2fs"):format(type(rolled), rollBackoffStep))
		rollBackoffUntil = os.clock() + rollBackoffStep
		rollBackoffStep = math.min(rollBackoffStep * 1.5, 2.0)
		return
	end
	rollBackoffStep = 0.5
	rollBackoffUntil = 0

	local duration = getBuff("Roll Duration")
	if type(duration) == "number" and duration >= 0 then
		Kaitun.State.NextRollReady = os.clock() + duration + ROLL_LATENCY_MARGIN
		if Kaitun.State.LastRollDuration ~= duration then
			Kaitun.State.LastRollDuration = duration
			Kaitun:Log(("[ROLL] duration=%.2fs nextReady=+%.2fs (%.0f rolls/hour ceiling)"):format(
				duration, duration + ROLL_LATENCY_MARGIN, 3600 / math.max(duration + ROLL_LATENCY_MARGIN, 0.01)))
		end
	end
	local names = {}
	for _, r in ipairs(rolled) do
		if type(r) == "table" and r.result then
			Kaitun.Stats.TotalRolls += 1
			names[#names + 1] = r.result .. (r.mutation and (" (" .. r.mutation .. ")") or "")
			local chanceValue = getUnitChanceValue(r.result, {mutation = r.mutation})
			if chanceValue and chanceValue >= (Kaitun.Settings.RareAlertThreshold or math.huge) then
				Kaitun:Log(("[RARE] Rolled %s (chance=%s)"):format(names[#names], tostring(chanceValue)))
			end
		end
	end
	logStepResult("Roll", true, ("result=[%s] luckUsed=%s rollCount=%s isSpin=%s spinName=%s"):format(
		table.concat(names, ", "), tostring(luckUsed), tostring(rollCount), tostring(isSpin), tostring(spinName)))
end

--============================================================
-- Rebirth  (RebirthController.lua:111-114 ; RebirthService.lua:34-55 ; Rebirths.lua:28-41)
-- RE.Rebirth() — no args. Affordability = Money() >= Rebirths.GetNext(Rebirth()).cost
-- RebirthService.lua:50 confirms rebirth ONLY resets Money(0) — Inventory/Dice/
-- Upgrades/Slots all survive — which is why the hard-gate design (money economy
-- pipeline below) treats any pre-threshold spend as free and only locks down
-- once Money has actually reached the next cost.
--============================================================
local function getNextRebirthInfo()
	if not (Mods.Rebirths and Mods.Rebirths.GetNext and Mods.DataController and Mods.DataController.Rebirth) then
		return nil, nil
	end
	local ok, level = pcall(Mods.DataController.Rebirth)
	if not ok then return nil, nil end
	local ok2, info = pcall(Mods.Rebirths.GetNext, level)
	if not ok2 or type(info) ~= "table" or type(info.cost) ~= "number" then return nil, level end
	return info, level
end

-- Returns true only when the rebirth actually fired AND was confirmed (Rebirth()
-- level changed) — the Money-economy pipeline uses this to know whether to skip
-- Dice/Level/Tree/Sell for the rest of this cycle (hard gate).
function Ticks.AutoRebirth()
	setCoreState("Rebirth")
	if not Net.Rebirth then
		logStepSkip("Rebirth", "RebirthService.RE.Rebirth remote missing")
		return false
	end
	local nextInfo, level = getNextRebirthInfo()
	if not nextInfo then
		logStepSkip("Rebirth", ("Rebirths.GetNext(%s) did not return a valid {cost=...} table"):format(tostring(level)))
		return false
	end
	local ok3, money = pcall(Mods.DataController.Money)
	if not ok3 then
		logStepSkip("Rebirth", "DataController.Money() threw an error")
		return false
	end
	Kaitun:Log(("[REBIRTH] level=%s Money=%s NextRebirthCost=%s"):format(tostring(level), tostring(money), tostring(nextInfo.cost)))
	if money < nextInfo.cost then
		logStepSkip("Rebirth", ("not affordable yet: need %s for level %s -> %s"):format(
			tostring(nextInfo.cost), tostring(level), tostring(level + 1)))
		return false
	end

	logStepStart("Rebirth", "Network.RebirthService.RE.Rebirth")
	local fired = safeFire(Net.Rebirth)
	if not fired then
		logStepResult("Rebirth", false, "FireServer threw an error")
		return false
	end
	local waited = 0
	while waited < 5 do
		task.wait(0.25)
		waited += 0.25
		local ok4, newLevel = pcall(Mods.DataController.Rebirth)
		if ok4 and newLevel > level then
			logStepResult("Rebirth", true, ("level %s -> %s (waited %.2fs)"):format(tostring(level), tostring(newLevel), waited))
			Kaitun:Log(("[REBIRTH] confirmed: %s -> %s"):format(tostring(level), tostring(newLevel)))
			return true
		end
	end
	logStepResult("Rebirth", false, ("fired but Rebirth() level did not change within 5s timeout (still %s) — server may have rejected it silently"):format(tostring(level)))
	return false
end

--============================================================
-- Grade / Trait rolling — Plot Rank Order Target Selection
-- GradeService.RE.Roll(unitKey, skipProtectedConfirm?) — costs 1 Gem, server-side.
-- TraitService.RE.Roll(unitKey, skipProtectedConfirm?) — costs 1 Trait Reroll.
-- (GradeController.lua:268-289 ; GradeService.lua:54-92 ; TraitController.lua:268-283 ;
--  TraitService.lua:65-101). The currency counts ARE readable client-side after
-- all: EntryService.lua:97-107 shows GetAmount(player, name) is literally
-- Inventory[name]().amount — stackable entries are keyed by their own name — and
-- GradeService.lua:64 / TraitService.lua:74 are the exact call sites that reject
-- the roll when that count is < 1. So the batch checks "Gems" / "Trait Reroll"
-- up front instead of firing blind and reading the error banner afterwards.
--
-- Target selection is NOT potential/income based anymore. Grade and Trait
-- each walk a strict, INDEPENDENT one-at-a-time queue over PLOTTED units
-- only, ordered by real roster chance — they do not have to share a target:
--   1. Rank every unit currently on the plot by getUnitChanceValue (real
--      "1 in X", UnitConfig.entries[name].chance(attrs)), rarest first. A
--      plotted unit with no .chance function (Exclusive: Fused Zamatsu,
--      Emelia) can't be ranked by a real number, so it goes last instead of
--      being guessed at. Same ranking function backs both queues.
--   2. Grade's active target is the FIRST unit in that order whose Grade
--      hasn't reached A+ yet (Grades.lua order field, A+ = order 5; S/S+/Z/Z+
--      at orders 6-9 also pass). Trait's active target is computed the SAME
--      way but independently: the FIRST unit whose Trait isn't exactly
--      "Money III" or one of the rainbow group {Samurai, Shogun, Monarch,
--      Transcendent} yet — NOT a generic order comparison, since Traits.lua's
--      `order` is just table-declaration order (Damage/Health tiers are
--      declared after Money III purely by file layout, not because they rank
--      above it), so Damage/Health-line traits deliberately do NOT count as
--      a pass. A unit whose Grade already passed but Trait hasn't no longer
--      blocks Grade from moving on to the next unit that still needs it, and
--      vice versa — each attribute advances through the ranking at its own
--      pace.
--   3. Only the current target for THAT attribute is ever rolled, and only
--      until its own gate is met — a gate already met is never rolled again
--      (both rollGrade/rollTrait pick uniformly over the WHOLE table, so
--      rerolling an A+ or a Money III can throw it straight back down to
--      D / Money I).
--   4. There is no stored "current unit" for either queue — both rankings +
--      gate checks are recomputed fresh every tick from
--      getSlotView()/Inventory(), so a unit swapped onto or off the plot
--      re-orders both queues immediately.
-- Both Roll remotes silently no-op server-side when the current tag is
-- `protected` and skipProtectedConfirm isn't passed (GradeService.lua:76,
-- TraitService.lua:90) — S/S+/Samurai/Shogun/Monarch are all `protected`
-- (Grades.lua, Traits.lua) and sit BELOW this feature's own target, so it
-- always passes skipProtectedConfirm=true to roll straight through them.
--
-- The old potential-ranked "keeper" system right below (getUnitPotential /
-- getKeeperRanking) is untouched and still backs AutoLockBest / SafeSell —
-- this section only replaces how Grade/Trait pick a target; the plot-chance
-- ranking used by AutoGrade/AutoTrait is defined further down, right before
-- Ticks.AutoGrade.
--============================================================
local function getUnlockedSlotCount()
	if not (Mods.PlotConfig and Mods.PlotConfig.GetMaxSlots and Mods.PlotConfig.GetSlotRebirthRequirement
		and Mods.DataController and Mods.DataController.Rebirth) then
		return 0
	end
	local okMax, maxSlots = pcall(Mods.PlotConfig.GetMaxSlots)
	local okR, rebirth = pcall(Mods.DataController.Rebirth)
	if not (okMax and okR and type(maxSlots) == "number") then return 0 end
	local count = 0
	for idx = 1, maxSlots do
		local okReq, req = pcall(Mods.PlotConfig.GetSlotRebirthRequirement, idx)
		if okReq and type(req) == "number" and rebirth >= req then count += 1 end
	end
	return count
end

-- Returns (rankedAllUnits, keeperSetByKey, keeperCount). Ranked purely by
-- potential(u) descending — this is criteria 1+2 from the design (a strong
-- permanent mutation raises potential(u) directly via UnitConfig.lua:376,
-- so "good mutation" and "high potential" collapse into one score); criteria
-- 3 ("likely to stay on the long-term team") is the plot-capacity cutoff N.
local function getKeeperRanking()
	local owned = getOwnedUnits()
	local ranked = {}
	for _, u in ipairs(owned) do
		ranked[#ranked + 1] = {key = u.key, name = u.name, attributes = u.attributes, potential = getUnitPotential(u)}
	end
	table.sort(ranked, function(a, b) return a.potential > b.potential end)
	local keeperCount = getUnlockedSlotCount()
	local keeperSet = {}
	for i = 1, math.min(keeperCount, #ranked) do
		keeperSet[ranked[i].key] = true
	end
	return ranked, keeperSet, keeperCount
end

--============================================================
-- Shared slot / income / protection layer
--
-- One place that answers "what does the plot look like right now", "how much
-- money per second is actually coming in", and "which units must never be sold
-- or unlocked". AutoSell, AutoLockBest and the Investment system all read from
-- this same layer, so a unit can never be protected by one and scrapped by
-- another.
--
-- getCurrentIncomePerSecond reproduces PlotClass.lua:197 exactly:
--   balance += income(attributes) * BuffService.GetBuff(player,"Money Multiplier")
-- once per second, per unlocked slot that has a unit. The Money Multiplier is
-- read from the replicated buff Cache (see getBuff), so Upgrade-tree Money
-- nodes, the Rebirth multiplier, active Income boosts and gamepasses are all
-- already baked in — no client-side re-derivation.
--============================================================
local function getSlotView()
	local view = {slots = {}, plotted = {}, unlocked = {}, maxSlots = 0}
	if not (Mods.DataController and Mods.DataController.Slots and Mods.PlotConfig and Mods.PlotConfig.GetMaxSlots) then
		return view
	end
	local okMax, maxSlots = pcall(Mods.PlotConfig.GetMaxSlots)
	local okR, rebirth = pcall(Mods.DataController.Rebirth)
	local okS, slots = pcall(Mods.DataController.Slots)
	if not (okMax and okR and okS and type(maxSlots) == "number" and type(slots) == "table") then return view end
	view.slots = slots
	view.maxSlots = maxSlots
	for idx = 1, maxSlots do
		local okReq, req = pcall(Mods.PlotConfig.GetSlotRebirthRequirement, idx)
		if okReq and type(req) == "number" and rebirth >= req then
			local slotData = slots[tostring(idx)]
			local unitId = (type(slotData) == "table") and slotData.unitId or nil
			view.unlocked[#view.unlocked + 1] = {
				index = idx,
				unitId = unitId,
				balance = (type(slotData) == "table" and type(slotData.balance) == "number") and slotData.balance or 0,
			}
			if unitId then view.plotted[unitId] = idx end
		end
	end
	return view
end

local function getCurrentIncomePerSecond(view)
	view = view or getSlotView()
	local moneyMult = getBuff("Money Multiplier") or 1
	local total = 0
	local okI, inv = pcall(function()
		return Mods.DataController and Mods.DataController.Inventory and Mods.DataController.Inventory()
	end)
	if not okI or type(inv) ~= "table" then return 0, moneyMult end
	for _, slot in ipairs(view.unlocked) do
		if slot.unitId then
			local entry = inv[slot.unitId]
			if type(entry) == "table" then
				total += getUnitScore({name = entry.name, attributes = entry.attributes or {}})
			end
		end
	end
	return total * moneyMult, moneyMult
end

--============================================================
-- Replacement rarity — "how hard is it to roll something better than this?"
--
-- This is a direct re-implementation of RollUtil.RollUnit(luck), not an
-- approximation. That function builds its weight table like this:
--
--   for each Unit entry with a `chance` function:
--     for each mutation m:
--       eff = chance() * m.chance / luck
--       if eff >= 1 then weight = 1/eff  end        -- combo becomes rollable
--     eff = chance() / luck
--     if eff >= 1 then weight = 1/eff  end          -- the un-mutated combo
--   pick uniformly over the summed weight
--
-- Two consequences worth noting, both reproduced here: a combo is only
-- obtainable once `chance*mutation.chance <= luck` (higher luck literally unlocks
-- rarer combinations), and within the obtainable set the odds are proportional
-- to luck/chance.
--
-- With that table we can compute, exactly, the chance that ONE roll produces a
-- unit with strictly higher potential than some unit we already own, and hence
-- the expected number of rolls to beat it. That is the honest measure of "is
-- this unit a keeper or a temporary tenant", and it re-scales itself every time
-- luck changes — no maintained threshold anywhere.
--
-- The table is rebuilt only when effective luck changes (65 roster entries x 7
-- mutation states = a few hundred rows).
--============================================================
local rollDistCache = {luck = nil, combos = nil, total = 0}

local function getRollDistribution(luck)
	if not (luck and luck > 0 and Mods.UnitConfig and Mods.UnitConfig.entries and Mods.Mutations) then
		return nil
	end
	if rollDistCache.luck == luck and rollDistCache.combos then
		return rollDistCache.combos, rollDistCache.total
	end

	local combos, total = {}, 0
	local function add(weight, potential)
		total += weight
		combos[#combos + 1] = {weight = weight, potential = potential}
	end

	for name, cfg in pairs(Mods.UnitConfig.entries) do
		if type(cfg) == "table" and cfg.chance then
			local okBase, baseChance = pcall(cfg.chance)
			if okBase and type(baseChance) == "number" and baseChance > 0 then
				for mutName, mut in pairs(Mods.Mutations) do
					if type(mut) == "table" and type(mut.chance) == "number" then
						local eff = baseChance * mut.chance / luck
						if eff >= 1 then
							add(1 / eff, getUnitPotential({name = name, attributes = {mutation = mutName}}))
						end
					end
				end
				local effPlain = baseChance / luck
				if effPlain >= 1 then
					add(1 / effPlain, getUnitPotential({name = name, attributes = {}}))
				end
			end
		end
	end
	if total <= 0 then return nil end

	table.sort(combos, function(a, b) return a.potential > b.potential end)
	local cum = 0
	for _, c in ipairs(combos) do
		cum += c.weight
		c.weightAtOrAbove = cum
	end

	rollDistCache.luck, rollDistCache.combos, rollDistCache.total = luck, combos, total
	return combos, total
end

-- Expected number of rolls until a unit with potential strictly greater than
-- `potential` is produced, at the given effective luck. math.huge means nothing
-- currently rollable can beat it.
local function getRollsToBeat(potential, luck)
	local combos, total = getRollDistribution(luck)
	if not combos then return nil end
	local better = 0
	for _, c in ipairs(combos) do
		if c.potential > potential then
			better = c.weightAtOrAbove
		else
			break -- sorted descending by potential
		end
	end
	if better <= 0 then return math.huge end
	return total / better
end

-- The full protection map, keyed by unit key -> reason string.
--
-- Every reason below is either a hard game fact (plotted / locked / held) or a
-- rank-based rule sized by a real game-derived number (N = unlocked plot slots,
-- the game's own cap on how many units can earn at once — the same N the Keeper
-- system already uses), so none of it is an invented threshold.
--
--   plotted        server already refuses to sell it (SellUtil.lua:56), mirrored
--                  client-side so the decision is visible in the log
--   player-locked   a lock not created by this script — the exact field
--                   SellUtil.lua:56 checks. Bot locks are deliberately NOT a
--                   permanent SafeSell reason: they must be released as soon
--                   as the unit drops out of the small AutoLock set.
--   held           currently carried by UnitService.Equip during an investment
--                  swap (not plotted, not locked -> would otherwise be sellable)
--   top-income     top-N by CURRENT income — the units actually earning now
--   keeper         top-N by potential — the units worth levelling into earners,
--                  and the same set Grade/Trait spend their currency on (so the
--                  two can never disagree). Current income alone is NOT enough:
--                  income(attrs) scales with (1 + 0.25*(level-1))
--                  (UnitConfig.lua:96), so a Lv1 unit with a far higher permanent
--                  ceiling can rank below a levelled weak one.
--   top-chance     top-N by the roster's own chance(attrs) rarity value
--                  (UnitConfig.lua:52-64; shown in game as "1 in X")
--   keep-income    Settings.SellKeepIncome floor, when the user sets one (>0)
-- `relaxChanceProtection` lifts the top-chance (roster-rarity) soft protection
-- only — used by the overflow-sell safety valve below when the inventory is
-- nearly full, so junk units that only survived because of a decent roster
-- rarity become sellable. plotted / player-locked / held / keeper / top-income
-- are never relaxed, overflow or not.
local function buildProtectedSet(relaxChanceProtection)
	local units = getOwnedUnits() -- already sorted by current income desc
	local view = getSlotView()
	local n = getUnlockedSlotCount()
	if n < 1 then n = 1 end

	local enriched = {}
	for _, u in ipairs(units) do
		enriched[#enriched + 1] = {
			key = u.key,
			name = u.name,
			attributes = u.attributes,
			income = u.score,
			potential = getUnitPotential(u),
			chance = getUnitChanceValue(u.name, u.attributes) or 0,
			mutation = u.attributes and u.attributes.mutation or nil,
			locked = (u.attributes and u.attributes.locked) and true or false,
		}
	end

	local protected, reasons = {}, {}
	local function mark(key, reason)
		if protected[key] then return end
		protected[key] = reason
		reasons[reason] = (reasons[reason] or 0) + 1
	end

	local function markTopN(field, reason)
		local sorted = table.clone(enriched)
		table.sort(sorted, function(a, b) return a[field] > b[field] end)
		for i = 1, math.min(n, #sorted) do
			mark(sorted[i].key, reason)
		end
	end

	-- Hard facts first so they win the reason label over the rank-based rules.
	for _, u in ipairs(enriched) do
		if view.plotted[u.key] then
			mark(u.key, "plotted")
		elseif u.locked and not Kaitun.State.BotLockedKeys[u.key] then
			-- A bot lock is intentionally not a permanent sell-protection reason.
			-- If it has fallen out of AutoLock, AutoLockBest releases it on its next
			-- tick; treating it as player-locked here would make it self-perpetuate.
			mark(u.key, "player-locked")
		elseif Kaitun.State.HeldUnitKey == u.key then
			mark(u.key, "held")
		end
	end

	markTopN("income", "top-income")

	-- "keeper" and top-N-by-potential are the same rule by definition; they share
	-- one reason label so the log counts stay honest instead of showing one of
	-- them as zero.
	markTopN("potential", "keeper")

	if not relaxChanceProtection then
		markTopN("chance", "top-chance")
	end

	local floor = Kaitun.Settings.SellKeepIncome or 0
	if type(floor) == "number" and floor > 0 then
		for _, u in ipairs(enriched) do
			if u.income >= floor then mark(u.key, "keep-income") end
		end
	end

	return protected, enriched, reasons, n, view
end

-- Grade target: A+ (Grades.lua order 5) — anything ranked at or above it
-- (S, S+, Z, Z+ — orders 6-9) also passes immediately, compared live by
-- `order` from Mods.Grades so a config change (new tier, renumbered order) is
-- honored automatically.
--
-- Trait target: explicitly "Money III" OR one of the rainbow group (Samurai,
-- Shogun, Monarch, Transcendent) — NOT a generic order>=Money III comparison.
-- Traits.lua's `order` field is just the table's declaration order (Money
-- I-III, then Damage I-III, then Health I-III, then the rainbow group), so a
-- plain order>=3 check would also pass Damage/Health-line traits (orders 4-9)
-- purely because they're declared after Money III in the file — that is NOT
-- a real "better than Money III" ranking, just table position, so those are
-- deliberately excluded here per the corrected requirement.
local GRADE_TARGET_NAME = "A+"
local TRAIT_PASS_NAMES = {["Money III"] = true, Samurai = true, Shogun = true, Monarch = true, Transcendent = true}

local function gradeGateMet(gradeTag)
	local targetInfo = getGradeInfo(GRADE_TARGET_NAME)
	if not (targetInfo and type(targetInfo.order) == "number") then return false end
	local info = gradeTag and getGradeInfo(gradeTag)
	return (info and type(info.order) == "number") and info.order >= targetInfo.order or false
end

local function traitGateMet(traitTag)
	return traitTag ~= nil and TRAIT_PASS_NAMES[traitTag] == true
end

-- Every PLOTTED unit, ranked by real roster chance (UnitConfig.entries[name]
-- .chance(attrs)), rarest ("1 in X" biggest) first. A plotted unit whose
-- roster entry has no .chance function (Exclusive: Fused Zamatsu, Emelia) is
-- appended at the end, in slot-index order — there is no real number to sort
-- it by, so it is never guessed into a rank.
local function getPlotChanceRanking()
	local view = getSlotView()
	local okI, inv = pcall(Mods.DataController.Inventory)
	if not okI or type(inv) ~= "table" then return {} end

	local ranked, unranked = {}, {}
	for _, slot in ipairs(view.unlocked) do
		if slot.unitId then
			local entry = inv[slot.unitId]
			if type(entry) == "table" then
				local chance = getUnitChanceValue(entry.name, entry.attributes)
				local item = {key = slot.unitId, name = entry.name, attributes = entry.attributes or {}, chance = chance}
				if chance then
					ranked[#ranked + 1] = item
				else
					unranked[#unranked + 1] = item
				end
			end
		end
	end
	table.sort(ranked, function(a, b) return a.chance > b.chance end)
	for _, item in ipairs(unranked) do ranked[#ranked + 1] = item end
	return ranked
end

-- Grade and Trait target INDEPENDENTLY: each walks the same chance-ranked
-- plot list but only checks its own gate, so a unit whose Grade is already
-- done but Trait isn't no longer blocks Grade from moving on to the next
-- unit that still needs it (and vice versa) — the two attributes advance
-- through the ranking at their own pace instead of being forced to clear
-- together on the same unit before either can progress. Both recomputed
-- fresh on every call — no stored index — so a unit swapped onto/off the
-- plot re-ranks immediately. Returns nil once every plotted unit clears that
-- one gate (or nothing is plotted).
local function getActiveGradeTarget()
	for _, u in ipairs(getPlotChanceRanking()) do
		if not gradeGateMet(u.attributes.grade) then
			return u
		end
	end
	return nil
end

local function getActiveTraitTarget()
	for _, u in ipairs(getPlotChanceRanking()) do
		if not traitGateMet(u.attributes.trait) then
			return u
		end
	end
	return nil
end

-- Fires up to `batchLimit` rolls at `target` for whichever single gate
-- (`attrField`/`gateMetFn`) this call is responsible for, re-checking the
-- gate after every roll so it stops the instant the target is reached (never
-- rolls past the configured minimum). Always passes skipProtectedConfirm=true
-- so a unit that happens to already sit on a `protected` tier (Grades.lua/
-- Traits.lua) below the target — none do at the current A+/Money III
-- targets, but this stays correct if the targets are lowered later — is never
-- silently refused by the server's own protected-tag confirmation gate.
-- Returns true only if the very first attempt this call errored out (no
-- currency at all) — same quiet-backoff signal Ticks.AutoGrade/AutoTrait use.
local function rollTargetGate(remote, batchLimit, currencyName, attrField, gateMetFn, target, label)
	if not remote then return false end
	local available = getEntryAmount(currencyName)
	if available < 1 then
		return true -- signals the caller's quiet backoff: nothing to spend
	end

	local limit = math.min(batchLimit or 3, available)
	for attempt = 1, limit do
		local okI, inv = pcall(Mods.DataController.Inventory)
		local entry = okI and type(inv) == "table" and inv[target.key]
		local currentTag = entry and entry.attributes and entry.attributes[attrField]
		if gateMetFn(currentTag) then
			return false -- reached the target (possibly from the previous attempt)
		end

		Kaitun:Log(("[%s] target=%s (1 in %s) rank-active current_%s=%s attempt=%d/%d"):format(
			label:upper(), target.name, target.chance and tostring(target.chance) or "N/A",
			attrField, tostring(currentTag), attempt, limit))
		safeFire(remote, target.key, true) -- skipProtectedConfirm: always roll through protected tiers
		local note = waitForNotification(0.6)
		if note and note.notificationType == "error" then
			return attempt == 1
		end
		task.wait(0.3)

		if getEntryAmount(currencyName) < 1 then return true end
	end
	return false
end

-- Adaptive quiet backoff (mirrors Ticks.AutoRoll's pattern): out-of-currency
-- grows the wait instead of retrying every scheduler tick, logs ONCE per
-- backoff instead of every attempt, and never disables the toggle — it will
-- resume trying (silently) the moment currency shows up again.
local gradeBackoffUntil, gradeBackoffStep = 0, 5
local traitBackoffUntil, traitBackoffStep = 0, 5
local gradeTargetSkipLogged = nil
local traitTargetSkipLogged = nil

function Ticks.AutoGrade()
	if os.clock() < gradeBackoffUntil then return end
	local target = getActiveGradeTarget()
	local outOfCurrency
	if not target then
		local line = ("[GRADE] no active target -- nothing plotted, or every plotted unit is already Grade>=%s"):format(GRADE_TARGET_NAME)
		if gradeTargetSkipLogged ~= line then gradeTargetSkipLogged = line; Kaitun:Log(line) end
		outOfCurrency = false
	else
		gradeTargetSkipLogged = nil
		outOfCurrency = rollTargetGate(Net.GradeRoll, Kaitun.Settings.GradeBatchLimit, "Gems", "grade", gradeGateMet, target, "Grade")
	end
	if outOfCurrency then
		if gradeBackoffUntil == 0 then
			Kaitun:Log(("[AutoGrade] no Gems right now — waiting quietly, retrying every %ds until some show up"):format(gradeBackoffStep))
		end
		gradeBackoffUntil = os.clock() + gradeBackoffStep
		gradeBackoffStep = math.min(gradeBackoffStep * 1.5, 60)
	else
		gradeBackoffUntil, gradeBackoffStep = 0, 5
	end
end

function Ticks.AutoTrait()
	if os.clock() < traitBackoffUntil then return end
	local target = getActiveTraitTarget()
	local outOfCurrency
	if not target then
		local line = "[TRAIT] no active target -- nothing plotted, or every plotted unit is already Money III/rainbow"
		if traitTargetSkipLogged ~= line then traitTargetSkipLogged = line; Kaitun:Log(line) end
		outOfCurrency = false
	else
		traitTargetSkipLogged = nil
		outOfCurrency = rollTargetGate(Net.TraitRoll, Kaitun.Settings.TraitBatchLimit, "Trait Reroll", "trait", traitGateMet, target, "Trait")
	end
	if outOfCurrency then
		if traitBackoffUntil == 0 then
			Kaitun:Log(("[AutoTrait] no Trait Rerolls right now — waiting quietly, retrying every %ds until some show up"):format(traitBackoffStep))
		end
		traitBackoffUntil = os.clock() + traitBackoffStep
		traitBackoffStep = math.min(traitBackoffStep * 1.5, 60)
	else
		traitBackoffUntil, traitBackoffStep = 0, 5
	end
end

--============================================================
-- Dice shop  (DiceShopController.lua:140-147 ; DiceShopService.lua:38-73 ; Dice.lua:30-63)
-- Dice identity = string name; fields {luck, rarity, price?}. Reads Dice.GetAll()
-- live — all 24 tiers (Normal..Chrono) are covered automatically, nothing
-- hardcoded to a specific tier name.
--
-- DiceShopService.lua:38-60 confirms the ONLY purchase requirement is
-- `not owned and Money() >= price` (no Rebirth-level gate at all), and BuyDice
-- auto-equips the tier it just bought (`v1.Dice(p2)`).
--
-- TWO REAL BUGS were found in the live log and fixed here:
--
--  1. SHARED 0.5s DEBOUNCE. BuyDice AND EquipDice both call
--       DebounceUtil.Try(p1, "DiceShop", 0.5)
--     (DiceShopService.lua:40 and :61) — the SAME key. The old loop waited only
--     task.wait(0.2) between fires, so every second request in a pass was
--     silently dropped: the log showed "Fire decision=buy" while Money never
--     moved (10,000 -> 9,999 for Normal, then 9,250 went to the upgrade tree,
--     leaving 749 — the 2,500 for Fire was never taken). Every fire below is now
--     followed by a wait longer than that debounce window.
--
--  2. OWNERSHIP READ. The server checks `v1.OwnedDice[p2]()` — a per-key State
--     node, indexed by NAME first (DiceShopService.lua:44 and :66), exactly like
--     Upgrades and Inventory. The old code called `OwnedDice()` with no key, so
--     it never actually knew which tiers were owned; that is why EquipDice(Fire)
--     was re-fired every single cycle ("equipped Fire (luck 5 -> was 2)"
--     repeating forever) while the equipped dice stayed Normal — the server was
--     rejecting it at `if not v1.OwnedDice[p2]() then return end`.
--
-- PRIORITY REDESIGN (Dice #1, Rebirth #2, Level #3, Tree #4):
--
-- Every dice tier is worth buying eventually — luck survives Rebirth
-- (RebirthService.lua resets Money only) and Rebirth's own luckMultiplier
-- ladder (Rebirths.lua) multiplies it further, so buying earlier is never
-- wrong in the long run. The only real question is timing: does buying it
-- NOW delay reaching the next Rebirth by too long?
--
--   delaySeconds = dicePrice / currentTotalIncomePerSecond
--
-- currentTotalIncomePerSecond is the same real-income figure the LevelUpSlot
-- payback gate already uses (getCurrentIncomePerSecond — PlotClass.lua:197's
-- own per-second formula, Money Multiplier included). Buy the tier only if
-- money already covers it AND delaySeconds <= Settings.DiceMaxDelaySeconds;
-- otherwise stop for this tier without touching Money at all, so Rebirth's
-- hard gate (checked right after Dice in MoneyEconomy) sees the full amount
-- and can fire immediately if it qualifies. Once Rebirth fires, income goes
-- up (moneyMultiplier), so the very next MoneyEconomy cycle re-evaluates Dice
-- with a shorter delaySeconds automatically — no special "recheck" logic
-- needed, it falls out of running this every cycle.
--============================================================
-- BuyDice and EquipDice share DebounceUtil.Try(player, "DiceShop", 0.5), so
-- every fire must be followed by a wait longer than that window or the next one
-- is dropped without any error being sent back.
local DICE_DEBOUNCE = 0.6

-- OwnedDice is a per-key State node: the server reads `OwnedDice[name]()`
-- (DiceShopService.lua:44, :66), never `OwnedDice()`.
local function isDiceOwned(name)
	local ok, val = pcall(function()
		return Mods.DataController.OwnedDice and Mods.DataController.OwnedDice[name]
			and Mods.DataController.OwnedDice[name]()
	end)
	return ok and val == true
end

function Ticks.AutoDice()
	setCoreState("Dice")
	if not (Net.BuyDice and Net.EquipDice and Mods.Dice and Mods.Dice.GetAll and Mods.DataController) then
		logStepSkip("Dice", ("missing dependency (BuyDice=%s EquipDice=%s Dice module=%s DataController=%s)"):format(
			tostring(Net.BuyDice ~= nil), tostring(Net.EquipDice ~= nil), tostring(Mods.Dice ~= nil), tostring(Mods.DataController ~= nil)))
		return
	end
	local ok, all = pcall(Mods.Dice.GetAll)
	if not ok or type(all) ~= "table" then
		logStepSkip("Dice", "Dice.GetAll() did not return a table")
		return
	end

	local nextInfo = getNextRebirthInfo()
	local nextCost = nextInfo and nextInfo.cost or math.huge

	local owned = {}
	for name in pairs(all) do
		if isDiceOwned(name) then owned[name] = true end
	end
	local ok3, money = pcall(Mods.DataController.Money)
	if not ok3 then
		logStepSkip("Dice", "DataController.Money() threw an error")
		return
	end
	local ok4, currentDiceName = pcall(function() return Mods.DataController.Dice and Mods.DataController.Dice() end)
	currentDiceName = ok4 and currentDiceName or nil

	-- delaySeconds is recomputed from freshly-read Money and income before every
	-- single purchase (the loop can buy several tiers in one pass, and each buy
	-- changes Money), so nothing is bought against a stale snapshot. Cheapest
	-- first, so the wallet is never spent on a big tier while a cheap one is
	-- still unowned and un-evaluated.
	-- Best luck already owned, including the free starter tier (no price).
	local currentLuckOwned = 0
	for name, cfg in pairs(all) do
		if type(cfg) == "table" and type(cfg.luck) == "number" and (owned[name] == true or not cfg.price) then
			if cfg.luck > currentLuckOwned then currentLuckOwned = cfg.luck end
		end
	end

	-- A dice entry carries nothing but luck (Dice.lua: luck / rarity / price /
	-- image), so a tier at or below the best luck already owned is worth exactly
	-- zero — and buying it is actively harmful, because BuyDice auto-equips what
	-- it just bought (DiceShopService.lua:49, `v1.Dice(p2)`). The live log caught
	-- this: with Water (luck 10) equipped it bought Fire (luck 5) for 2,500 and
	-- dropped the equipped luck by half until the next tier landed.
	local candidates, skippedDowngrade = {}, 0
	for name, cfg in pairs(all) do
		if type(cfg) == "table" and cfg.price and owned[name] ~= true then
			if type(cfg.luck) == "number" and cfg.luck <= currentLuckOwned then
				skippedDowngrade += 1
			else
				candidates[#candidates + 1] = {name = name, price = cfg.price, luck = cfg.luck}
			end
		end
	end
	table.sort(candidates, function(a, b) return a.price < b.price end)

	-- No "is it worth the delay" gate anymore — buy any affordable, non-
	-- downgrade tier immediately, exactly like Rebirth fires the instant Money
	-- covers it. The only condition left is the hard gate below (never spend
	-- money that already qualifies for Rebirth). DiceMaxDelaySeconds is now
	-- used ONLY by AutoLevelUpSlots (to decide whether to pause and let Money
	-- climb toward an upcoming tier) — Dice's own buy decision no longer reads
	-- it at all.
	local bought, waitingLogged = {}, false
	for _, c in ipairs(candidates) do
		local gateInfo = getNextRebirthInfo()
		local okM, curMoney = pcall(Mods.DataController.Money)
		if not okM then break end
		-- Hard gate: money at/above the Rebirth threshold belongs to Rebirth,
		-- even though Dice is checked first in the pipeline — Dice only ever
		-- gets to spend money that Rebirth doesn't already qualify for.
		if gateInfo and curMoney >= gateInfo.cost then break end

		local liveNextCost = (gateInfo and gateInfo.cost) or nextCost
		local incomePerSec = getCurrentIncomePerSecond()
		local delaySeconds = (incomePerSec > 0) and (c.price / incomePerSec) or math.huge
		local rebirthShare = (liveNextCost < math.huge and liveNextCost > 0) and (c.price / liveNextCost) or 0
		local moneyShare = (curMoney > 0) and (c.price / curMoney) or math.huge
		local luckGain = (currentLuckOwned > 0 and type(c.luck) == "number") and (c.luck / currentLuckOwned) or nil

		if c.price > curMoney then
			waitingLogged = true
			logOnce("dice", ("[DICE] %s price=%s decision=wait reason=unaffordable"):format(
				c.name, tostring(c.price)))
			break -- cheapest-first: nothing after this is affordable either
		else
			clearLogOnce("dice")
			logStepStart("Dice", "Network.DiceShopService.RE.BuyDice", c.name)
			safeFire(Net.BuyDice, c.name)
			task.wait(DICE_DEBOUNCE) -- shared "DiceShop" debounce (DiceShopService.lua:40)
			-- Confirm against the server's own ownership state instead of assuming
			-- the fire landed; a dropped request must not be counted as a buy.
			local confirmed = isDiceOwned(c.name)
			Kaitun:Log(("[DICE] %s price=%s decision=%s luckGain=%s money=%s->%s delay=%.0fs ofMoney=%.1f%% ofRebirth=%.1f%%"):format(
				c.name, tostring(c.price), confirmed and "buy" or "buy-FAILED",
				luckGain and ("x%.2f"):format(luckGain) or "?",
				tostring(curMoney), tostring(curMoney - c.price), delaySeconds, moneyShare * 100, rebirthShare * 100))
			logStepResult("Dice", confirmed, confirmed and "owned confirmed via OwnedDice[name]()" or "server did not register the purchase")
			if confirmed then
				owned[c.name] = true
				bought[#bought + 1] = c.name
				if type(c.luck) == "number" and c.luck > currentLuckOwned then currentLuckOwned = c.luck end
			else
				break -- do not keep hammering a purchase the server is refusing
			end
		end
	end

	-- Whatever we now own (including anything bought above), make sure the
	-- highest-luck owned tier is the one equipped. Ownership is read per key,
	-- the same way the server validates it.
	local ok7, curDice = pcall(function() return Mods.DataController.Dice and Mods.DataController.Dice() end)
	curDice = ok7 and curDice or currentDiceName
	local currentLuck = (curDice and all[curDice] and all[curDice].luck) or 0
	local best, bestLuck = curDice, currentLuck
	for name, cfg in pairs(all) do
		if type(cfg) == "table" and cfg.luck and cfg.luck > bestLuck then
			-- `not cfg.price` = the free starter tier (Basic), always available.
			if (not cfg.price) or isDiceOwned(name) then
				best, bestLuck = name, cfg.luck
			end
		end
	end

	if best and best ~= curDice then
		logStepStart("Dice", "Network.DiceShopService.RE.EquipDice", best)
		safeFire(Net.EquipDice, best)
		task.wait(DICE_DEBOUNCE) -- same shared "DiceShop" debounce as BuyDice
		local okNow, nowDice = pcall(function() return Mods.DataController.Dice and Mods.DataController.Dice() end)
		local equipped = okNow and nowDice == best
		logStepResult("Dice", equipped, equipped
			and ("equipped %s (luck %s -> was %s)"):format(best, tostring(bestLuck), tostring(currentLuck))
			or ("EquipDice(%s) did not stick — still %s (server requires OwnedDice[%s]() to be true)"):format(
				best, tostring(okNow and nowDice or "?"), best))
	elseif #bought == 0 and not waitingLogged then
		logStepSkip("Dice", ("nothing worth buying; equipped=%s luck=%s (%d unowned tier(s) skipped as luck downgrades) nextRebirthCost=%s"):format(
			tostring(curDice), tostring(currentLuck), skippedDowngrade, tostring(nextCost)))
	end
end

--============================================================
-- Plot placement — driven purely by roster "1 in X" chance
--
-- No income/potential scoring here: the worst PLOTTED unit is simply the one
-- with the lowest real chance() value (UnitConfig.entries[name].chance(attrs),
-- UnitConfig.lua:38-47 rarity thresholds + :480-546 roster values; an empty
-- slot counts as worse than any real value), and it gets swapped for the
-- UNPLOTTED unit with the highest chance() value whenever that's actually
-- rarer. See Ticks.AutoPlotBest below.
--
-- Placing a CHOSEN unit into a CHOSEN slot uses real remotes — no guessing:
--
--   UnitService.RF.Equip(unitKey) -> bool     (UnitService.lua:149-282, bound at
--       :356) picks a specific inventory unit up into the character's hand.
--       Requires a live character (Humanoid.Health > 0) and has a 0.5s
--       "UnitAction" debounce.
--   PlotService.RE.InteractSlot(slotIndex)    (PlotService.lua:159-179) with a
--       unit in hand calls UpdateSlotUnit(slot, heldKey) and then clears the
--       hand; with an empty hand it instead picks the slot's unit up.
--       0.5s "PlotSlotInteraction" debounce.
--   UnitService.RF.Unequip() -> bool          (UnitService.lua:284-296, :358)
--       puts whatever is in hand back.
--
-- One hazard, confirmed in source: PlotClass:UpdateSlotUnit writes
-- {balance = 0, unitId = key} (PlotClass.lua:322/368), so any uncollected
-- balance in that slot is destroyed by the swap — placeUnitInSlot below
-- always calls CollectBalance first to avoid burning it.
--============================================================
local function isCharacterAlive()
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return (hum and hum.Health > 0) and true or false
end

local function releaseHeldUnit()
	if not Kaitun.State.HeldUnitKey then return end
	if Net.UnitUnequip then safeInvoke(Net.UnitUnequip, 1) end
	Kaitun.State.HeldUnitKey = nil
end

-- Puts `unitKey` into `slotIndex`, collecting that slot's balance first so the
-- swap cannot burn it. Returns true only once the slot actually reads back as
-- holding the unit.
local function placeUnitInSlot(unitKey, slotIndex)
	if not (Net.UnitEquip and Net.InteractSlot) then return false, "UnitService.RF.Equip / PlotService.RE.InteractSlot missing" end
	if not isCharacterAlive() then return false, "character is dead — UnitService.Equip requires Humanoid.Health > 0" end

	if Net.CollectBalance then
		safeFire(Net.CollectBalance, slotIndex)
		task.wait(0.15)
	end

	local ok, equipped = safeInvoke(Net.UnitEquip, 1, unitKey)
	if not ok or equipped == false then
		return false, "UnitService.Equip returned false (debounce, dead character, or unit no longer in inventory)"
	end
	Kaitun.State.HeldUnitKey = unitKey
	task.wait(0.55) -- UnitAction / PlotSlotInteraction debounces are 0.5s each

	safeFire(Net.InteractSlot, slotIndex)
	task.wait(0.4)

	local view = getSlotView()
	if view.plotted[unitKey] == slotIndex then
		Kaitun.State.HeldUnitKey = nil
		return true
	end
	releaseHeldUnit()
	return false, "slot did not read back as holding the unit after InteractSlot"
end

-- Plot placement, driven PURELY by roster "1 in X" rarity
-- (getUnitChanceValue / UnitConfig.entries[name].chance(attrs), confirmed at
-- UnitConfig.lua:38-47 rarity thresholds + :480-546 roster chance values).
-- No `potential`/income scoring is used to decide placement anymore — that
-- entire investment/EquipBest state machine (graduate/preempt/promote by
-- ceiling) is replaced by a single rule per tick:
--   1. Find the PLOTTED unit with the LOWEST real chance value (an empty
--      unlocked slot counts as worse than every real chance value, since
--      nothing should sit unfilled).
--   2. Find the UNPLOTTED (inventory) unit with the HIGHEST real chance
--      value.
--   3. If that inventory unit's chance beats the worst plot chance, evict
--      the worst plot unit and place the inventory unit in its slot.
-- Units with no .chance function (Exclusive: Fused Zamatsu, Emelia) are never
-- picked on either side — there is no real "1 in X" for them, so nothing is
-- guessed.
function Ticks.AutoPlotBest()
	setCoreState("Plot")

	-- Any hand left full by a failed swap last tick would make the unit
	-- unplotted AND unlocked, i.e. sellable — always clear it first.
	if Kaitun.State.HeldUnitKey then releaseHeldUnit() end

	local view = getSlotView()
	if #view.unlocked == 0 then
		logStepSkip("Plot", "no unlocked plot slots yet")
		return
	end

	local okI, inv = pcall(Mods.DataController.Inventory)
	if not okI or type(inv) ~= "table" then
		logStepSkip("Plot", "DataController.Inventory() unavailable")
		return
	end

	-- Repeated identical verdicts are logged once, not every tick.
	local function logPlotOnce(line)
		if Kaitun.State.LastInvestLog ~= line then
			Kaitun.State.LastInvestLog = line
			Kaitun:Log(line)
		end
	end

	-- Worst PLOTTED unit (or an empty slot) by real chance value.
	local plottedKeys, worstSlot, worstChance = {}, nil, nil
	for _, slot in ipairs(view.unlocked) do
		if not slot.unitId then
			worstSlot, worstChance = slot.index, -1
		else
			plottedKeys[slot.unitId] = true
			local entry = inv[slot.unitId]
			if type(entry) == "table" then
				local chance = getUnitChanceValue(entry.name, entry.attributes)
				if chance and (not worstChance or chance < worstChance) then
					worstSlot, worstChance = slot.index, chance
				end
			end
		end
	end

	-- Best UNPLOTTED (inventory) unit by the same real chance value.
	local bestKey, bestName, bestChance = nil, nil, nil
	for key, entry in pairs(inv) do
		if not plottedKeys[key] and type(entry) == "table" and Mods.UnitConfig.entries[entry.name] then
			local chance = getUnitChanceValue(entry.name, entry.attributes)
			if chance and (not bestChance or chance > bestChance) then
				bestKey, bestName, bestChance = key, entry.name, chance
			end
		end
	end

	if not (worstSlot and bestKey) then
		logStepSkip("Plot", "no beneficial swap available (no empty/known-chance slot, or no inventory candidate)")
		return
	end
	if worstChance >= 0 and bestChance <= worstChance then
		logPlotOnce(("[PLOT] decision=skip (best bench unit %s at 1 in %.0f does not beat the current worst plot chance 1 in %.0f)"):format(
			bestName, bestChance, worstChance))
		return
	end

	Kaitun.State.LastInvestLog = nil
	Kaitun:Log(("[PLOT] decision=swap into slot %d: %s (1 in %.0f) replacing %s"):format(
		worstSlot, bestName, bestChance, worstChance >= 0 and ("1 in " .. ("%.0f"):format(worstChance)) or "empty slot"))

	local placed, why = placeUnitInSlot(bestKey, worstSlot)
	if placed then
		Kaitun:Log(("[PLOT] unit=%s placed in slot %d (Equip -> InteractSlot confirmed)"):format(bestName, worstSlot))
	else
		Kaitun:Log(("[PLOT] unit=%s decision=failed reason=%s"):format(bestName, tostring(why)))
	end
end

--============================================================
-- AutoLock is intentionally MUCH narrower than SafeSell.
--
-- SafeSell protects the live plot, manual locks, the current income leaders,
-- potential leaders and rarity leaders. Locking every one of those units turns
-- temporary protection into a permanent inventory graveyard: a later SafeSell
-- pass then sees its own old locks and has nothing left to sell.
--
-- Therefore the bot locks only the top-N potential units (N = unlocked plot
-- slots) plus an active/held investment. On every tick it releases *only* locks
-- recorded in BotLockedKeys that no longer meet that narrow rule. A player lock
-- is never added to BotLockedKeys and is never unlocked by this code.
--============================================================
function Ticks.AutoLockBest()
	setCoreState("Lock")
	if not Net.SetLocked then
		logStepSkip("Lock", "UnitService.RE.SetLocked remote missing")
		return
	end

	local _, potentialTop = getKeeperRanking()
	local _, enriched = buildProtectedSet()
	local desired = {}
	for key in pairs(potentialTop) do desired[key] = "top-potential" end
	if Kaitun.State.InvestmentKey then
		desired[Kaitun.State.InvestmentKey] = "investment"
	end
	if Kaitun.State.HeldUnitKey then
		desired[Kaitun.State.HeldUnitKey] = "held-investment"
	end

	local lockedNow, ownedNow = {}, {}
	for _, u in ipairs(enriched) do
		ownedNow[u.key] = true
		if u.locked then lockedNow[u.key] = true end
	end

	local updates, toLock, toUnlock = {}, 0, 0
	for key in pairs(desired) do
		if not lockedNow[key] then
			updates[key] = true
			toLock += 1
		end
	end
	for key in pairs(Kaitun.State.BotLockedKeys) do
		if not ownedNow[key] or not lockedNow[key] then
			-- The unit was sold/removed or manually unlocked. It cannot be a stale
			-- bot lock anymore, so forget the bookkeeping entry without firing a
			-- meaningless false update.
			Kaitun.State.BotLockedKeys[key] = nil
		elseif not desired[key] then
			updates[key] = false
			toUnlock += 1
		end
	end

	local desiredCount = 0
	for _ in pairs(desired) do desiredCount += 1 end

	if toLock == 0 and toUnlock == 0 then
		logStepSkip("Lock", ("already in sync: %d top-potential/investment key(s) locked, nothing to release"):format(desiredCount))
		return
	end

	logStepStart("Lock", "Network.UnitService.RE.SetLocked", updates)
	local ok = safeFire(Net.SetLocked, updates)
	if ok then
		for key, value in pairs(updates) do
			if value then
				-- Claim ownership only after the remote accepted the lock. Recording it
				-- before a failed request would misclassify a later player lock.
				Kaitun.State.BotLockedKeys[key] = true
			else
				Kaitun.State.BotLockedKeys[key] = nil
			end
		end
		-- Persist to file so a full rejoin (not just a script re-run) still
		-- remembers which locks are the bot's own — otherwise every rejoin
		-- forgets, treats old bot locks as player-set, and never releases the
		-- ones that have gone stale.
		if persistBotLockedKeys then persistBotLockedKeys() end
	end
	local ownCount = 0
	for _ in pairs(Kaitun.State.BotLockedKeys) do ownCount += 1 end
	logStepResult("Lock", ok, ("+%d top-potential/investment locks / -%d stale bot locks released (bot-owned now %d; player locks untouched)"):format(
		toLock, toUnlock, ownCount))
end

-- A prior script instance may have locked hundreds of units, then been stopped
-- before its BotLockedKeys ledger could be carried into this version. Those
-- existing locks are indistinguishable from player locks, so AutoLockBest must
-- preserve them by default. This is the explicit one-time recovery action for
-- that legacy situation: it unlocks every currently locked unit OUTSIDE the
-- current top-N potential / active-investment set. The button text makes the
-- trade-off visible; it is never called automatically.
function Ticks.ReleaseLegacyLocks()
	setCoreState("ReleaseLegacyLocks")
	if not Net.SetLocked then
		logStepSkip("ReleaseLegacyLocks", "UnitService.RE.SetLocked remote missing")
		return
	end

	local _, potentialTop = getKeeperRanking()
	local desired = {}
	for key in pairs(potentialTop) do desired[key] = true end
	if Kaitun.State.InvestmentKey then desired[Kaitun.State.InvestmentKey] = true end
	if Kaitun.State.HeldUnitKey then desired[Kaitun.State.HeldUnitKey] = true end

	local _, enriched = buildProtectedSet()
	local updates, releaseCount = {}, 0
	for _, u in ipairs(enriched) do
		if u.locked and not desired[u.key] then
			updates[u.key] = false
			releaseCount += 1
		end
	end
	if releaseCount == 0 then
		logStepSkip("ReleaseLegacyLocks", "no locked unit outside top-potential/investment set")
		return
	end

	logStepStart("ReleaseLegacyLocks", "Network.UnitService.RE.SetLocked", updates)
	local ok = safeFire(Net.SetLocked, updates)
	if ok then
		for key in pairs(updates) do Kaitun.State.BotLockedKeys[key] = nil end
	end
	logStepResult("ReleaseLegacyLocks", ok, ("released %d legacy locks; the next SafeSell cycle will clear unprotected units"):format(releaseCount))
end

--============================================================
-- Safe Sell  (SellController.lua:165 ; SellService.lua:140-155 ; SellUtil.lua:34-141)
--
-- RF.SellInventory(keysArray) -> (moneyEarned, unitsSold).
--
-- The previous version handed the server EVERY owned unit key and relied on the
-- server's own filter. That filter is only two conditions — SellUtil.lua:56:
--
--   if p2 and not (p2.amount <= 0) and not p3[p1] and not p2.attributes.locked
--        -- p3 = GetPlottedUnits(Slots())     -> plotted
--        -- p2.attributes.locked              -> locked
--
-- There is NO rarity, potential, chance or mutation protection server-side at
-- all. So a unit that had just been rolled and was not yet plotted (AutoPlotBest
-- runs every 6s) or locked (AutoLockBest every 15s) was fully sellable by a Sell
-- pass running every 3s — a window the bot hit routinely, which is how good
-- units disappeared in the live test.
--
-- Now the client builds the candidate list itself from buildProtectedSet() and
-- only ever sends keys that survive every protection rule. The server filter
-- still runs afterwards as a second line of defence; it is no longer the only
-- one.
--============================================================
local SELL_LOG_CAP = 12
-- AutoSell runs every MoneyEconomy cycle, so protection lines are reported on
-- CHANGE only (a unit newly protected, or its reason changed). Candidates and
-- actual sales are always logged — those are the events worth auditing.
local sellProtectReported = {}
local sellSummaryLast = nil

-- Overflow safety valve: once owned/cap crosses Settings.OverflowSellEnterRatio
-- (default 0.95), relax the top-chance soft protection so units that only
-- survived because of roster rarity — not because they're plotted, locked,
-- a keeper, or a top earner — become sellable junk. A simple hysteresis flag
-- (enter at the ratio, exit 0.10 below it) stops it flapping on/off tick to
-- tick right at the boundary; the ratio itself is recomputed fresh every call.
local overflowSellActive = false

local function isOverflowActive()
	local cap = getUnitStorageCap()
	if not (cap and cap > 0) then return false, 0 end
	local ratio = getUnitInventoryCount() / cap
	local enter = Kaitun.Settings.OverflowSellEnterRatio or 0.95
	if not overflowSellActive and ratio >= enter then
		overflowSellActive = true
	elseif overflowSellActive and ratio < (enter - 0.10) then
		overflowSellActive = false
	end
	return overflowSellActive, ratio
end

function Ticks.AutoSell()
	setCoreState("Sell")
	if not (Net.SellInventory and Mods.DataController) then
		logStepSkip("Sell", ("missing dependency (SellInventory=%s DataController=%s)"):format(
			tostring(Net.SellInventory ~= nil), tostring(Mods.DataController ~= nil)))
		return
	end

	local overflow, storageRatio = isOverflowActive()
	if overflow then
		logOnce("sell-overflow", ("[SELL] overflow mode ON — inventory at %.0f%% of Unit Storage cap, relaxing top-chance protection until it drops back under %.0f%%"):format(
			storageRatio * 100, ((Kaitun.Settings.OverflowSellEnterRatio or 0.95) - 0.10) * 100))
	else
		clearLogOnce("sell-overflow")
	end

	local protected, enriched, reasons, n = buildProtectedSet(overflow)
	if #enriched == 0 then
		logStepSkip("Sell", "no owned Unit-kind inventory entries found")
		return
	end

	local candidates = {}
	for _, u in ipairs(enriched) do
		if not protected[u.key] then
			candidates[#candidates + 1] = u
		end
	end

	-- Per-unit detail for the non-obvious saves (everything except plain
	-- plotted/player-locked), first time that unit+reason is seen.
	local shown = 0
	for _, u in ipairs(enriched) do
		local reason = protected[u.key]
		if reason and reason ~= "plotted" and reason ~= "player-locked" and shown < SELL_LOG_CAP then
			local stamp = u.key .. "|" .. reason
			if not sellProtectReported[u.key] or sellProtectReported[u.key] ~= stamp then
				sellProtectReported[u.key] = stamp
				shown += 1
				Kaitun:Log(("[SELL-PROTECT] unit=%s reason=%s current=%.0f potential=%.0f chance=%s mutation=%s"):format(
					u.name, reason, u.income, u.potential, tostring(math.floor(u.chance)), tostring(u.mutation or "none")))
			end
		end
	end
	for key in pairs(sellProtectReported) do
		if not protected[key] then sellProtectReported[key] = nil end
	end

	if #candidates == 0 then
		logStepSkip("Sell", ("nothing to sell — all %d owned unit(s) are protected"):format(#enriched))
		return
	end

	-- A sale is actually about to happen, so print the full protection make-up
	-- next to the candidate list: that pairing is what makes the decision
	-- auditable after the fact.
	local summary = {}
	for reason, count in pairs(reasons) do
		summary[#summary + 1] = ("%s=%d"):format(reason, count)
	end
	table.sort(summary)
	sellSummaryLast = ("[SELL-PROTECT] %d/%d protected (top-N size=%d) :: %s"):format(
		#enriched - #candidates, #enriched, n, table.concat(summary, " "))
	Kaitun:Log(sellSummaryLast)

	local keys = {}
	for i, u in ipairs(candidates) do
		keys[#keys + 1] = u.key
		if i <= SELL_LOG_CAP then
			Kaitun:Log(("[SELL-CANDIDATE] unit=%s current=%.0f potential=%.0f chance=%s mutation=%s"):format(
				u.name, u.income, u.potential, tostring(math.floor(u.chance)), tostring(u.mutation or "none")))
		end
	end
	if #candidates > SELL_LOG_CAP then
		Kaitun:Log(("[SELL-CANDIDATE] ... and %d more"):format(#candidates - SELL_LOG_CAP))
	end

	logStepStart("Sell", "Network.SellService.RF.SellInventory", keys)
	local ok, earned, count = safeInvoke(Net.SellInventory, 1, keys)
	if not ok then
		logStepResult("Sell", false, "InvokeServer failed after retries")
		return
	end
	if type(count) ~= "number" or count == 0 then
		logStepResult("Sell", true, ("0 units sold out of %d candidate(s) — the server's own plotted/locked filter caught them (SellUtil.lua:56)"):format(#keys))
		return
	end

	-- Report what actually left the inventory, by diffing against the live
	-- inventory rather than assuming every candidate sold.
	local okI, invNow = pcall(Mods.DataController.Inventory)
	local sold = 0
	if okI and type(invNow) == "table" then
		for _, u in ipairs(candidates) do
			if invNow[u.key] == nil then
				sold += 1
				if sold <= SELL_LOG_CAP then
					Kaitun:Log(("[SELL-SOLD] unit=%s current=%.0f potential=%.0f"):format(u.name, u.income, u.potential))
				end
			end
		end
		if sold > SELL_LOG_CAP then
			Kaitun:Log(("[SELL-SOLD] ... and %d more"):format(sold - SELL_LOG_CAP))
		end
	end

	Kaitun.Stats.TotalMoneyFromSell += (type(earned) == "number" and earned or 0)
	Kaitun.Stats.TotalUnitsSold += count
	logStepResult("Sell", true, ("sold %d/%d candidate(s) for %s money"):format(count, #keys, tostring(earned)))
end

-- One-shot: arms the server-side auto-sell-below-chance-threshold flag used
-- during rolling itself (RollService.lua:224-234 reads DataService.AutoSell()).
function Kaitun.ApplyAutoSellThreshold()
	if Net.UpdateAutoSell then
		safeFire(Net.UpdateAutoSell, Kaitun.Settings.AutoSellChanceThreshold or 0)
	end
end

--============================================================
-- Upgrade tree — re-verified directly against Scripts/ReplicatedStorage/
-- UpgradeService.lua (server handler) on 2026-09-12:
--
--   (Network.Server.CreateSignal(ReplicatedStorage.Network, "BuyUpgrade")):Connect(function(p1, p2)
--       local u3 = Upgrades[p2]                                   -- p2 = upgrade name (string)
--       if not u3 then return end
--       local v1 = DataService[p1]
--       if v1.Upgrades[p2]() then return end                      -- <- Upgrades is a per-key State,
--                                                                  --    NOT a plain table you call once
--       local v2 = TreeStructure.GetParent(p2)                    -- <- confirmed real API: GetParent(name)
--       if v2 and v2 ~= "Start" and not v1.Upgrades[v2]() then return end
--       if v1.Money() < u3.price then ... error notify ... return end
--       v1.Money(function(p1) return p1 - u3.price end)
--       v1.Upgrades[p2](true)
--   end)
--
-- This fixes a real bug from the previous version: it was calling
-- `DataController.Upgrades()` (invoking the whole node with no key) expecting
-- a table back, when the actual API requires indexing by name FIRST —
-- `DataController.Upgrades[name]()` — exactly like `DataController.Inventory[key]()`.
-- That mismatch made the previous version silently find zero candidates every
-- time, which is why "Upgrade Tree" never visibly did anything.
--============================================================
local function isUpgradeOwned(name)
	local ok, val = pcall(function()
		return Mods.DataController.Upgrades and Mods.DataController.Upgrades[name] and Mods.DataController.Upgrades[name]()
	end)
	return ok and val == true
end

-- What each branch actually does, all confirmed in the dump:
--   Unit Storage -> +5/+10 to the "Unit Storage" base bucket (Upgrades.lua), and
--                   that buff is the cap RollService.lua:165 refuses to roll past
--   Money        -> +0.25..+1 to the "Money Multiplier" PERCENTAGE bucket, which
--                   multiplies passive plot income every second (PlotClass.lua:197)
--   Roll Speed   -> -0.15 to the "Roll Duration" base bucket, i.e. directly more
--                   rolls/hour (RollService.lua:148)
--   Luck/Fortune -> + to the "Luck" base bucket, multiplied by dice luck
--                   (RollService.lua:191)
--   Sell         -> + to the "Sell Multiplier" percentage bucket (SellService.lua:65-68)
--   Damage/Health-> Tower-only stats
--   Walkspeed    -> character movement; irrelevant to a remote-driven bot
--
-- The old version sorted by a FIXED branch rank and then stopped the whole pass
-- when the top-ranked branch's next node was unaffordable. With "Unit Storage"
-- pinned at rank 1 that meant one expensive node (Unit Storage III at 1,000,000)
-- froze every other branch indefinitely — the stall seen in the live log.
--
-- Two changes fix it:
--   1. Only AFFORDABLE nodes are candidates, so an unaffordable branch is simply
--      skipped instead of blocking the queue.
--   2. Branch priority is computed from live state rather than being a constant:
--      Unit Storage is only urgent when the inventory is actually near the cap
--      that blocks rolling, Sell only matters while AutoSell is on, Damage and
--      Health only while Tower is on.
local function getUpgradeBranch(name)
	if name == "Start" then return "Start" end
	return (name:gsub("%s+[IVXLCDM]+$", ""))
end

-- Branches that buy nothing this bot can use. Confirmed safe to skip entirely
-- against TreeStructure.lua: nothing useful hangs off any of them —
--   Damage I..IX   -> children are Damage and Health only
--   Health I..VIII -> leaf chain
--   Walkspeed I..VI-> leaf chain off Unit Storage II
-- so skipping them never makes a Money/Luck/Fortune/Roll Speed/Sell/Unit Storage
-- node unreachable. The live log spent 1,092,000 on exactly these (Walkspeed I
-- 250,000, Damage III 400,000, Health III 400,000, plus the small ones) while
-- Lightning dice sat unaffordable — that money buys real luck instead now.
local function isUselessBranch(branch)
	if branch == "Walkspeed" then
		return true, "bot is remote-driven, movement speed does nothing"
	end
	if branch == "Damage" or branch == "Health" then
		if not Kaitun.Toggles.AutoTower then
			return true, "Tower is off, so combat stats do nothing"
		end
	end
	return false
end

-- Higher score = bought first. The numbers are ordering weights, not tuned
-- magnitudes; what makes them evidence-based is the STATE each one keys off.
local function scoreUpgradeBranch(branch, ctx)
	if branch == "Unit Storage" then
		-- ctx.storagePressure = ownedUnits / (Unit Storage + Rolls - 1).
		-- At >= 1 rolling is hard-blocked (RollService.lua:165) and nothing else
		-- in the game matters until it is raised.
		if ctx.storagePressure >= 1 then return 100 end
		if ctx.storagePressure >= 0.8 then return 90 end
		return 20
	elseif branch == "Money" then
		return 80 -- compounds on every slot, every second, forever
	elseif branch == "Roll Speed" then
		return 70 -- more rolls/hour feeds every other system
	elseif branch == "Luck" or branch == "Fortune" then
		return 60 -- better units per roll
	elseif branch == "Sell" then
		return Kaitun.Toggles.AutoSell and 40 or 5
	elseif branch == "Damage" or branch == "Health" then
		return Kaitun.Toggles.AutoTower and 35 or 2
	elseif branch == "Walkspeed" then
		return 1
	end
	return 10
end

local function buildUpgradeContext()
	local cap = getUnitStorageCap()
	local owned = getUnitInventoryCount()
	return {
		storagePressure = (cap and cap > 0) and (owned / cap) or 0,
		storageCap = cap,
		ownedUnits = owned,
	}
end

-- Only nodes that are unlocked, unowned, useful AND within the spend cap.
--
-- The spend cap is the same 50%-of-current-money rule the dice shop already
-- uses, and it exists for the same reason plus one more: the tree had NO cap, so
-- whenever an expensive dice tier was waiting for the wallet to grow, the tree
-- spent that exact money first. The live log shows it three times in one minute
-- (Sell I 500,000 taken the same second Lightning 500,000 logged "wait"), which
-- is why Lightning was never bought at all. With both systems on the same rule
-- they queue behind each other instead of racing.
local UPGRADE_MONEY_SHARE = 0.5

local function buildUpgradeCandidates(money, ctx)
	local candidates = {}
	local cap = money * UPGRADE_MONEY_SHARE
	for name, cfg in pairs(Mods.Upgrades) do
		if type(cfg) == "table" and type(cfg.price) == "number" and cfg.price <= money and not isUpgradeOwned(name) then
			local okParent, parent = pcall(Mods.TreeStructure.GetParent, name)
			local parentOwned = (not okParent) or parent == nil or parent == "Start" or isUpgradeOwned(parent)
			local branch = getUpgradeBranch(name)
			local useless = isUselessBranch(branch)
			-- price 0 is the free "Start" node, which must never be capped out.
			local withinCap = cfg.price <= cap or cfg.price == 0
			if parentOwned and not useless and withinCap then
				candidates[#candidates + 1] = {
					name = name,
					price = cfg.price,
					branch = branch,
					score = scoreUpgradeBranch(branch, ctx),
				}
			end
		end
	end
	-- Best branch first; cheapest node inside that branch first.
	table.sort(candidates, function(a, b)
		if a.score ~= b.score then return a.score > b.score end
		return a.price < b.price
	end)
	return candidates
end

function Ticks.AutoUpgradeTree()
	setCoreState("UpgradeTree")
	if not (Net.BuyUpgrade and Mods.TreeStructure and Mods.TreeStructure.GetParent and Mods.Upgrades and Mods.DataController and Mods.DataController.Upgrades) then
		logStepSkip("UpgradeTree", ("missing dependency (BuyUpgrade=%s TreeStructure.GetParent=%s Upgrades module=%s DataController.Upgrades=%s)"):format(
			tostring(Net.BuyUpgrade ~= nil), tostring(Mods.TreeStructure and Mods.TreeStructure.GetParent ~= nil),
			tostring(Mods.Upgrades ~= nil), tostring(Mods.DataController and Mods.DataController.Upgrades ~= nil)))
		return
	end

	local bought = {}
	local maxBuysPerTick = 50
	for _ = 1, maxBuysPerTick do
		-- Hard gate re-check before every single node purchase, as required —
		-- Money only ever shrinks across this loop (no income step runs here),
		-- but this makes the guarantee explicit rather than implicit.
		local gateInfo = getNextRebirthInfo()
		local ok, money = pcall(Mods.DataController.Money)
		if not ok then break end
		if gateInfo and money >= gateInfo.cost then
			if #bought == 0 then
				logStepSkip("UpgradeTree", "Money already at/above Rebirth threshold — reserved, not spending")
			end
			break
		end

		local ctx = buildUpgradeContext()
		local candidates = buildUpgradeCandidates(money, ctx)
		if #candidates == 0 then
			if #bought == 0 then
				-- Distinguish "nothing left to buy" from "held back by the spend
				-- cap", otherwise the log looks identical in both cases.
				local held, heldPrice = nil, math.huge
				for name, cfg in pairs(Mods.Upgrades) do
					if type(cfg) == "table" and type(cfg.price) == "number" and cfg.price > 0
						and not isUpgradeOwned(name) and not isUselessBranch(getUpgradeBranch(name)) then
						local okParent, parent = pcall(Mods.TreeStructure.GetParent, name)
						if ((not okParent) or parent == nil or parent == "Start" or isUpgradeOwned(parent))
							and cfg.price < heldPrice then
							held, heldPrice = name, cfg.price
						end
					end
				end
				if held then
					logStepSkip("UpgradeTree", ("holding for %s (%s) — over the %d%%-of-money spend cap, letting the wallet build"):format(
						held, tostring(heldPrice), UPGRADE_MONEY_SHARE * 100))
				else
					logStepSkip("UpgradeTree", "no useful unlocked-and-unowned node left")
				end
			end
			break
		end
		local pick = candidates[1]
		local fired = safeFire(Net.BuyUpgrade, pick.name)
		if not fired then break end
		task.wait(0.2)
		-- Verify against the server's own ownership state before counting this
		-- as bought — the same fix applied to Dice. UpgradeService.lua has no
		-- debounce, but replication can still lag behind the 0.1s the old code
		-- waited: a live log caught "Roll Speed III" logged as bought TWICE in
		-- one pass while Money only dropped once — the client re-picked the
		-- same still-not-yet-replicated node and fired BuyUpgrade again; the
		-- server's own `if v1.Upgrades[p2]() then return end` silently no-opped
		-- the second fire (UpgradeService.lua), so no money was lost, but the
		-- log was wrong and the loop wasted a remote call. Confirming here
		-- makes both the log and the loop's "did this purchase land" decision
		-- match reality.
		local confirmed = isUpgradeOwned(pick.name)
		if confirmed then
			Kaitun:Log(("[TREE] %s branch=%s cost=%s score=%d storage=%d/%s money=%s"):format(
				pick.name, pick.branch, tostring(pick.price), pick.score,
				ctx.ownedUnits, tostring(ctx.storageCap or "?"), tostring(money)))
			bought[#bought + 1] = pick.name
		else
			Kaitun:Log(("[TREE] %s branch=%s cost=%s decision=buy-FAILED (not confirmed owned after fire — replication lag or server rejection)"):format(
				pick.name, pick.branch, tostring(pick.price)))
			break -- do not keep re-firing a purchase that hasn't landed
		end
	end

	if #bought > 0 then
		local ok2, money2 = pcall(Mods.DataController.Money)
		Kaitun:Log(("[UpgradeTree] bought %d node(s): %s (Money now %s)"):format(#bought, table.concat(bought, ", "), tostring(ok2 and money2 or "?")))
	end
end

--============================================================
-- Collect plot slot balances — re-verified against PlotClass.lua directly:
--   PlotClass.CollectBalance(idx): moves dataSlots[idx].balance into Money and
--   zeroes it, IF IsSlotUnlocked(idx) (no-ops harmlessly if balance<=0 or locked).
--   IsSlotUnlocked(idx) = PlotConfig.GetSlotRebirthRequirement(idx) <= Rebirth().
-- Slot balance accrues passively over time from whatever unit is placed there
-- (PlotClass.lua's balanceTask loop) — this is exactly "เดินไปเก็บเงินที่แท่น",
-- automated via the same PlotService.RE.CollectBalance the in-game walk-in-zone
-- trigger uses (PlotController.lua fires it every ~1s while standing in the zone).
--============================================================
function Ticks.AutoCollectBalance()
	setCoreState("CollectBalance")
	if not (Net.CollectBalance and Mods.DataController and Mods.DataController.Slots and Mods.PlotConfig and Mods.PlotConfig.GetMaxSlots) then
		logStepSkip("CollectBalance", "missing dependency (CollectBalance remote / DataController.Slots / PlotConfig)")
		return
	end
	local ok, maxSlots = pcall(Mods.PlotConfig.GetMaxSlots)
	local ok2, rebirth = pcall(Mods.DataController.Rebirth)
	local ok3, slots = pcall(Mods.DataController.Slots)
	if not (ok and ok2 and ok3 and type(maxSlots) == "number" and type(slots) == "table") then
		logStepSkip("CollectBalance", "could not read PlotConfig.GetMaxSlots / DataController.Rebirth / DataController.Slots")
		return
	end

	local collected = 0
	for idx = 1, maxSlots do
		local okReq, reqRebirth = pcall(Mods.PlotConfig.GetSlotRebirthRequirement, idx)
		if okReq and type(reqRebirth) == "number" and rebirth >= reqRebirth then
			local slotData = slots[tostring(idx)]
			if type(slotData) == "table" and type(slotData.balance) == "number" and slotData.balance > 0 then
				safeFire(Net.CollectBalance, idx)
				collected += 1
				task.wait(0.1)
			end
		end
	end
	if collected > 0 then
		Kaitun:Log(("[CollectBalance] collected from %d unlocked slot(s) with balance>0"):format(collected))
	end
end

--============================================================
-- Level up the unit standing on each plot slot ("อัปแท่นตัวละคร") —
-- re-verified against PlotService.lua + UnitService.lua + UnitUtil.lua directly:
--   RE.LevelUpSlot(slotIndex) requires the slot to have a unitId and be
--   unlocked, then calls UnitService.LevelUp(player, slot.unitId), which
--   charges:
--     costNext(u) = floor( UnitConfig.income({mutation=u.mutation}) * 1.6^(level-1) )
--   UnitConfig.income({mutation=...}) with no level/trait/grade passed is
--   EXACTLY "potential(u)" as defined in the FINAL PROGRESSION PRIORITY design
--   (UnitConfig.lua:365-395: level defaults to 1, trait/grade multipliers are
--   skipped when nil). Meanwhile the real income gain from one more level is
--   linear (UnitConfig.lua:393: `base * (1 + 0.25*(level-1))`), so:
--     gainPerLevel(u) = potential(u) * traitMult(u) * gradeMult(u) * 0.25
--   Dividing the two, potential(u) cancels out completely:
--     ROI(u) = gainPerLevel(u) / costNext(u) = 0.25 * traitMult(u) * gradeMult(u) / 1.6^(level-1)
-- So ROI depends only on the unit's current trait/grade multiplier and how
-- many levels it already has — NOT on how strong the unit's roster chance is.
-- A cheap, untouched unit (level=1, ROI=0.25) always beats a heavily-leveled
-- one (ROI shrinks by /1.6 per level already spent), which is the "invest in
-- whichever gives the fastest income growth per gold" rule from the design.
-- (getUnitPotential/getUnitMultipliers now live earlier in this file, right
-- after the getGradeInfo/getTraitInfo imports, because the Grade/Trait Keeper
-- Target Selection below also needs them.)
--============================================================
local function getUnitROI(entry)
	local level = (entry.attributes and entry.attributes.level) or 1
	local traitMult, gradeMult = getUnitMultipliers(entry)
	local ok, roi = pcall(function() return 0.25 * traitMult * gradeMult / (1.6 ^ (level - 1)) end)
	return ok and roi or 0
end

local function getUnitLevelCost(entry, potential)
	local level = (entry.attributes and entry.attributes.level) or 1
	local ok, cost = pcall(function() return math.floor((potential or getUnitPotential(entry)) * 1.6 ^ (level - 1)) end)
	return ok and cost or math.huge
end

--============================================================
-- Dice reservation for Level (Priority: Dice #1 > Rebirth #2 > Level #3).
--
-- Ticks.AutoDice runs earlier in the same MoneyEconomy pass and buys a tier
-- the moment Money already covers it AND it's worth the delay (price/income
-- <= DiceMaxDelaySeconds). But if Money does NOT cover it yet, AutoDice just
-- logs "unaffordable" and does nothing — it never reserves the gap. Left
-- alone, AutoLevelUpSlots (ROI-positive, far from Rebirth) immediately re-
-- spends every bit of new income, so Money never climbs the last stretch to
-- the tier's price and Dice stalls forever just short of affording it.
--
-- This closes that gap: find the cheapest unowned, non-downgrade tier that
-- would actually be worth buying (same price/income <= DiceMaxDelaySeconds
-- test AutoDice itself uses), then check how many seconds of saving are left
-- to afford it: (price - Money) / incomePerSecond. If that's also within the
-- cap, Level holds off spending so the gap actually closes instead of being
-- refilled and re-spent every cycle. A tier that's still far out (either not
-- worth its own price/income test, or the remaining gap alone exceeds the
-- cap) does not reserve anything — Level runs as normal, matching "Dice ยัง
-- ซื้อไม่ได้ หรือ delaySeconds สูงเกินกำหนด -> อย่ารอ Dice".
--============================================================
local function getDiceReserveGapSeconds(money, incomePerSec)
	if not (Mods.Dice and Mods.Dice.GetAll and incomePerSec and incomePerSec > 0) then return nil end
	local ok, all = pcall(Mods.Dice.GetAll)
	if not ok or type(all) ~= "table" then return nil end

	local currentLuckOwned = 0
	for name, cfg in pairs(all) do
		if type(cfg) == "table" and type(cfg.luck) == "number" and (isDiceOwned(name) or not cfg.price) then
			if cfg.luck > currentLuckOwned then currentLuckOwned = cfg.luck end
		end
	end

	local cheapest, cheapestPrice = nil, math.huge
	for name, cfg in pairs(all) do
		if type(cfg) == "table" and cfg.price and not isDiceOwned(name) then
			local isDowngrade = type(cfg.luck) == "number" and cfg.luck <= currentLuckOwned
			if not isDowngrade and cfg.price < cheapestPrice then
				cheapest, cheapestPrice = name, cfg.price
			end
		end
	end
	if not cheapest then return nil end

	local diceMaxDelay = Kaitun.Settings.DiceMaxDelaySeconds or 300
	local worthBuying = (cheapestPrice / incomePerSec) <= diceMaxDelay
	if not worthBuying then return nil end

	local gapSeconds = math.max(0, cheapestPrice - money) / incomePerSec
	if gapSeconds <= diceMaxDelay then
		return gapSeconds, cheapest, cheapestPrice
	end
	return nil
end

function Ticks.AutoLevelUpSlots()
	setCoreState("LevelUpSlot")
	if not (Net.LevelUpSlot and Mods.DataController and Mods.DataController.Slots and Mods.DataController.Inventory and Mods.PlotConfig and Mods.PlotConfig.GetMaxSlots) then
		logStepSkip("LevelUpSlot", "missing dependency (LevelUpSlot remote / DataController.Slots|Inventory / PlotConfig)")
		return
	end
	local okMax, maxSlots = pcall(Mods.PlotConfig.GetMaxSlots)
	if not okMax or type(maxSlots) ~= "number" then
		logStepSkip("LevelUpSlot", "PlotConfig.GetMaxSlots() failed")
		return
	end

	-- Re-reads Rebirth/Slots/Inventory/Money fresh EVERY iteration (not once
	-- before the loop) so the ROI recompute after each level-up sees the real
	-- updated level from the server, and so the Rebirth hard gate is checked
	-- live rather than against stale data.
	local leveled = 0
	local maxPerPass = 30
	for _ = 1, maxPerPass do
		local gateInfo = getNextRebirthInfo()
		local okM, money = pcall(Mods.DataController.Money)
		local okR, rebirth = pcall(Mods.DataController.Rebirth)
		local okS, slots = pcall(Mods.DataController.Slots)
		local okI, inv = pcall(Mods.DataController.Inventory)
		if not (okM and okR and okS and okI and type(slots) == "table" and type(inv) == "table") then
			if leveled == 0 then
				logStepSkip("LevelUpSlot", "could not read Money / Rebirth / Slots / Inventory")
			end
			break
		end
		if gateInfo and money >= gateInfo.cost then
			if leveled == 0 then
				logStepSkip("LevelUpSlot", ("Money already at/above NextRebirthCost=%s — reserved for Rebirth, not spending"):format(tostring(gateInfo.cost)))
			end
			break
		end

		-- Priority: Dice (#1) can still be a few seconds of income away from
		-- affordable — reserve the gap instead of Level re-spending it every
		-- cycle (see getDiceReserveGapSeconds's comment for why this exists).
		local reserveGap, reserveDiceName, reserveDicePrice = getDiceReserveGapSeconds(money, getCurrentIncomePerSecond())
		if reserveGap then
			if leveled == 0 then
				logStepSkip("LevelUpSlot", ("holding for Dice %s (%s, %.0fs away at current income) — reserving Money for it before levelling"):format(
					tostring(reserveDiceName), tostring(reserveDicePrice), reserveGap))
			end
			break
		end

		-- Rank every unlocked+occupied slot's unit by ROI (ties broken by potential).
		local best, bestROI, bestPotential, bestSlot, bestKey = nil, -1, -1, nil, nil
		for idx = 1, maxSlots do
			local okReq, reqRebirth = pcall(Mods.PlotConfig.GetSlotRebirthRequirement, idx)
			if okReq and type(reqRebirth) == "number" and rebirth >= reqRebirth then
				local slotData = slots[tostring(idx)]
				if type(slotData) == "table" and slotData.unitId then
					local unitEntry = inv[slotData.unitId]
					if type(unitEntry) == "table" then
						local u = {name = unitEntry.name, attributes = unitEntry.attributes or {}}
						local roi = getUnitROI(u)
						local potential = getUnitPotential(u)
						if roi > bestROI or (roi == bestROI and potential > bestPotential) then
							best, bestROI, bestPotential, bestSlot, bestKey = u, roi, potential, idx, slotData.unitId
						end
					end
				end
			end
		end

		if not best then
			if leveled == 0 then
				logStepSkip("LevelUpSlot", "no placed+unlocked unit instances found")
			end
			break
		end

		local cost = getUnitLevelCost(best, bestPotential)
		if money < cost then
			if leveled == 0 then
				logStepSkip("LevelUpSlot", ("best-ROI unit %s (slot %d, ROI=%.4f) needs cost=%s — waiting for income"):format(best.name, bestSlot, bestROI, tostring(cost)))
			end
			break
		end

		-- Single-purchase sanity cap, same principle as Dice/Tree's 50%-of-money
		-- rule. The payback-vs-timeToRebirth gate below only checks TIME, so
		-- when Rebirth is still far off (timeToRebirth large) it waves through
		-- almost anything — a live log caught it buying ONE level for 99.86% of
		-- total Money (3,957,565,010,198 of 3,962,995,377,561) while Dice sat
		-- unaffordable one level-up away from qualifying. Capping any single
		-- level-up at half of current Money stops one purchase from wiping out
		-- money that was otherwise about to reach the next Dice tier or Rebirth.
		if cost > money * 0.5 then
			if leveled == 0 then
				logStepSkip("LevelUpSlot", ("best-ROI unit %s (slot %d, ROI=%.4f) needs cost=%s = %.0f%% of Money=%s — over the 50%% single-purchase cap, saving the rest"):format(
					best.name, bestSlot, bestROI, tostring(cost), (cost / money) * 100, tostring(money)))
			end
			break
		end

		local traitMult, gradeMult = getUnitMultipliers(best)
		local level = (best.attributes and best.attributes.level) or 1

		-- Payback / opportunity-cost gate.
		--
		-- ROI alone ranks WHICH unit to level, but says nothing about WHETHER the
		-- money should be spent at all. In the live log that produced level-ups
		-- costing 981,136 out of 1,067,216 on hand while the next Rebirth (and
		-- its permanent x2 money/luck multiplier, Rebirths.lua) was the better
		-- use of the same money.
		--
		--   addedIncomePerSecond = potential * traitMult * gradeMult * 0.25
		--                          * MoneyMultiplier
		--       the 0.25 is the level term's slope (UnitConfig.lua:96:
		--       base * (1 + 0.25*(level-1))) and the plot pays that out once per
		--       second multiplied by the Money Multiplier (PlotClass.lua:197).
		--   upgradePayback = cost / addedIncomePerSecond
		--   timeToRebirth  = (nextRebirthCost - Money) / currentTotalIncomePerSecond
		--
		-- Buy only when upgradePayback <= timeToRebirth: the level has already
		-- paid for itself before the Rebirth would have happened anyway, so it
		-- costs nothing in Rebirth timing. Anything slower is money that should
		-- have gone toward the Rebirth instead.
		local incomePerSec, moneyMult = getCurrentIncomePerSecond()
		local addedIncomePerSec = bestPotential * traitMult * gradeMult * 0.25 * (moneyMult or 1)
		local payback = (addedIncomePerSec > 0) and (cost / addedIncomePerSec) or math.huge
		local timeToRebirth = math.huge
		if gateInfo and incomePerSec > 0 then
			timeToRebirth = math.max(0, (gateInfo.cost - money) / incomePerSec)
		end

		if payback > timeToRebirth then
			if leveled == 0 then
				logOnce("level",
					("[LEVEL] %s slot=%d level=%s cost=%s gain/s=%.2f payback=%.0fs timeToRebirth=%.0fs decision=skip (pays back slower than the Rebirth it delays)"):format(
						best.name, bestSlot, tostring(level), tostring(cost), addedIncomePerSec, payback, timeToRebirth),
					("skip|%s|%s|%s"):format(best.name, tostring(bestSlot), tostring(cost)))
			end
			break
		end
		clearLogOnce("level")

		logStepStart("LevelUpSlot", "Network.PlotService.RE.LevelUpSlot", bestSlot)
		safeFire(Net.LevelUpSlot, bestSlot)
		Kaitun:Log(("[LEVEL] %s slot=%d level=%s ROI=%.4f cost=%s gain/s=%.2f payback=%.0fs timeToRebirth=%.0fs decision=buy%s"):format(
			best.name, bestSlot, tostring(level), bestROI, tostring(cost), addedIncomePerSec,
			payback, timeToRebirth, (Kaitun.State.InvestmentKey and bestKey == Kaitun.State.InvestmentKey) and " [investment]" or ""))
		logStepResult("LevelUpSlot", true, nil)
		leveled += 1
		task.wait(0.15)
	end
	if leveled > 0 then
		Kaitun:Log(("[LevelUpSlot] leveled %d unit-level(s) this pass (ROI-ranked, payback-gated)"):format(leveled))
	end
end

--============================================================
-- Money Economy pipeline — priority order (Dice #1, Rebirth #2, Level #3,
-- Tree #4):
--   CollectBalance -> Safe Sell -> re-read Money -> Dice Decision ->
--   re-read Money -> Rebirth Hard Gate -> Unit Level (payback-gated) ->
--   Upgrade Tree -> Repeat
--
-- Dice is checked BEFORE the Rebirth gate so it can spend money Rebirth
-- hasn't qualified for yet (see Ticks.AutoDice's delaySeconds rule) — but
-- Dice's own internal hard-gate check ("if curMoney >= gateInfo.cost then
-- break") means it never touches money that ALREADY qualifies for Rebirth,
-- so "Rebirth fires the instant Money reaches the threshold" still holds:
-- Dice only ever gets to cut in front of a Rebirth that hasn't happened yet,
-- never delay one that's already affordable RIGHT NOW.
--
-- This single function REPLACES independent scheduling of AutoCollectBalance /
-- AutoRebirth / AutoDice / AutoLevelUpSlots / AutoUpgradeTree / AutoSell in the
-- scheduler (see CorePipeline below) so they run in this exact fixed order
-- every cycle instead of racing each other on separate intervals — that race
-- was the root cause of Dice/LevelUp/UpgradeTree spending money that Rebirth
-- needed. Each step is still individually gated by its own existing
-- Kaitun.Toggles.* flag, so every UI toggle keeps working exactly as before;
-- only the scheduling wiring changed, not what each toggle controls.
--
-- The hard gate itself: RebirthService.lua:34-55 confirms Rebirth() ONLY
-- resets Money(0) — Inventory/Dice/Upgrades/Slots all persist — so spending
-- below the next Rebirth cost is always "free" (it only speeds up reaching
-- that cost), while spending is completely forbidden once Money has already
-- reached the cost, because that money belongs to the imminent Rebirth.
--============================================================
function Ticks.MoneyEconomy()
	if Kaitun.Toggles.AutoCollectBalance then
		Ticks.AutoCollectBalance()
	end

	-- Sell runs BEFORE the Rebirth gate now that it is SafeSell: it only ever
	-- ADDS money (SellService.lua:78-80) and never competes for it, so running
	-- it first means a sale that crosses the Rebirth threshold triggers the
	-- Rebirth in the SAME cycle instead of one tick later. This ordering was
	-- deliberately held back until the client-side SafeSellSet existed, because
	-- selling earlier also means selling closer to a fresh roll.
	if Kaitun.Toggles.AutoSell then
		Ticks.AutoSell()
	end

	local nextInfo, level = getNextRebirthInfo()
	local okM, money = pcall(function() return Mods.DataController and Mods.DataController.Money and Mods.DataController.Money() end)
	money = okM and money or nil
	local incomePerSec = getCurrentIncomePerSecond()
	Kaitun:Log(("[PROGRESS] Money=%s NextRebirthCost=%s income=%.0f/s (Rebirth level %s)"):format(
		tostring(money), nextInfo and tostring(nextInfo.cost) or "?", incomePerSec, tostring(level)))

	-- Priority #1: Dice. Only spends money Rebirth hasn't already qualified
	-- for (its own internal check), and only when the delay it causes is
	-- short — see Ticks.AutoDice's delaySeconds rule.
	if Kaitun.Toggles.AutoDice then
		Ticks.AutoDice()
	end

	-- Priority #2: Rebirth. Re-read Money fresh — Dice may have just spent
	-- some of it, or Sell above may have pushed it over the line.
	local okM2, money2 = pcall(function() return Mods.DataController and Mods.DataController.Money and Mods.DataController.Money() end)
	if Kaitun.Toggles.AutoRebirth and nextInfo and okM2 and money2 >= nextInfo.cost then
		local rebirthed = Ticks.AutoRebirth()
		if rebirthed then
			-- Hard gate: Rebirth just claimed this money — Level/Tree do not
			-- get to touch it. Resume the full flow next cycle.
			return
		end
		-- Rebirth fired but the server didn't confirm within its own timeout
		-- (logged by AutoRebirth itself) — fall through cautiously so a wallet
		-- that's genuinely stuck above cost doesn't just sit there forever
		-- doing nothing; Level/Tree still won't spend below the line below
		-- since Money is still >= nextInfo.cost, so they'll self-skip anyway.
	end

	-- Priority #3: Level, #4: Tree.
	if Kaitun.Toggles.AutoLevelUpSlots then
		Ticks.AutoLevelUpSlots()
	end
	if Kaitun.Toggles.AutoUpgradeTree then
		Ticks.AutoUpgradeTree()
	end
end

--============================================================
-- Towers — drives the REAL client flow (Select Hard -> Equip Best -> Fight),
-- the same functions/instances the player's own UI buttons use, confirmed
-- directly against the dump instead of reimplementing the floor loop over
-- raw remotes:
--
--   Towers.lua (ReplicatedStorage.Framework.Features.Towers.Towers) — each
--     tower entry carries a `difficulty.name` field: Dragon Tower="Easy",
--     Cursed Tower="Medium", Pirate Tower="Hard", Infinity Tower="Infinity".
--     There is no separate "difficulty" argument anywhere in the remotes —
--     "select Hard mode" literally means picking the tower whose
--     difficulty.name == "Hard" (Pirate Tower).
--
--   TowerService.lua:44-84 — PlayTower(name) has no zone/position check, just
--     a 3s per-player debounce and "not already playing" guard. The
--     EquipBestTowerTeam RemoteEvent (TowerService.lua:92-128) ranks every
--     owned unit by damage(attrs) and fills DataController.TowerTeam[1..N]
--     (N = TowerRefs.MAX_TEAM_SIZE = 4) with the top N — exactly the same
--     thing the in-game "Equip Best" button fires.
--
--   TowerSelectionController.lua:56,125-126 — the real "Fight" button
--     (PlayTower.Content.Buttons.Fight) is wired to
--     `TowerController.startTower(towerName)`. That function invokes
--     PlayTower itself, snapshots DataController.TowerTeam into its own
--     internal team list, then spawns a background loop that repeatedly
--     invokes CompleteTowerFloor and plays the result out — floors clear
--     themselves with zero further input once started. It also sets
--     UIReferences.Root.Tower.Screen.Visible = true for the run's duration
--     and back to false when it ends (towerStarted/towerEnded), which is the
--     one real, externally-readable "a run is active" signal.
--
--   The in-game "Auto" button (Screen.Buttons.Auto) only toggles a PRIVATE
--     upvalue inside TowerController.lua with no exposed getter/setter — its
--     one confirmed effect (read straight out of towerStarted's post-run
--     block) is "auto-restart the same tower ~3s after this run ends"; floor
--     clearing is already fully automatic either way. There is no
--     non-guessed way to flip that private flag from outside the module, so
--     this state machine reproduces the exact same externally-visible result
--     itself: every time the run reads back ended, it re-runs
--     Select Hard -> Equip Best -> Fight from scratch, forever.
--
--   The in-game "Hide" pill (Screen.Parent.Hidden) is ALSO 100% client-only —
--     no remote at all — and its handler, setTowerHidden(bool)
--     (TowerController.lua:79-89), is itself a private local, not exposed on
--     the returned table either. Its confirmed effects when hiding (p1=true):
--       HUDController.showAll("inTower")   -- bring the normal HUD back
--       Screen.Visible = false             -- hide the big fight card UI
--       Hidden.Position = UDim2.fromScale(0.5, 0.76)
--     and when un-hiding (p1=false): HUDController.hideAll("inTower"),
--     Background.Visible = true, Screen.Visible = true,
--     Hidden.Position = UDim2.fromScale(0.5, 0.87). Ticks.AutoTower reproduces
--     exactly these confirmed, publicly-reachable steps itself (no remote to
--     fire, none exists) — it never calls the private setTowerHidden.
--     Critically: hiding sets Screen.Visible = false for the SAME reason the
--     run truly ending does (towerEnded() also sets Screen.Visible = false),
--     so Screen.Visible can no longer be used as the "run active" signal once
--     Hide is in play. Hidden.Visible is the correct one instead — it is set
--     true once at the start of towerStarted() and only back to false inside
--     towerEnded(), completely independent of whether the fight card is
--     currently shown or hidden. Auto Hide therefore cannot affect Fight,
--     Auto-repeat, or ended-detection: they all key off Hidden.Visible, which
--     Auto Hide never touches.
--============================================================
-- "Normal" cycles AutoTower through every confirmed difficulty tier forever:
-- Easy -> Medium -> Hard -> Extreme -> Infinity -> Easy. A named TowerMode
-- repeats only that difficulty. Names match the five difficulty.name values in
-- Towers.lua (Dragon="Easy", Cursed="Medium", Pirate="Hard", Hidden Leaf=
-- "Extreme", Infinity="Infinity") -- nothing guessed.
local TOWER_DIFFICULTY_ORDER = {"Easy", "Medium", "Hard", "Extreme", "Infinity"}

local function getTowerNameByDifficulty(difficultyName)
	if not (Mods.Towers and Mods.Towers.GetAll) then return nil end
	local ok, all = pcall(Mods.Towers.GetAll)
	if not ok or type(all) ~= "table" then return nil end
	for name, cfg in pairs(all) do
		if type(cfg) == "table" and type(cfg.difficulty) == "table" and cfg.difficulty.name == difficultyName then
			return name
		end
	end
	return nil
end

-- Persistent center-screen text showing exactly which difficulty AutoTower is
-- currently fighting. Always set from the SAME confirmed cfg.difficulty.name
-- just matched against Towers.lua by getTowerNameByDifficulty above (never a
-- hand-typed guess), so it can never show a difficulty that isn't the one
-- actually about to run.
local towerStatusLabel
local function getTowerStatusLabel()
	if towerStatusLabel and towerStatusLabel.Parent then return towerStatusLabel end
	local ok, label = pcall(function()
		local parent = (gethui and gethui())
			or (cloneref and cloneref(game:GetService("CoreGui")) or game:GetService("CoreGui"))
		for _, child in ipairs(parent:GetChildren()) do
			if child.Name == "KaitunTowerStatus" and child:IsA("ScreenGui") then
				child:Destroy()
			end
		end
		local screenGui = Instance.new("ScreenGui")
		screenGui.Name = "KaitunTowerStatus"
		screenGui.ResetOnSpawn = false
		screenGui.IgnoreGuiInset = true
		screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		screenGui.DisplayOrder = 2147483647
		screenGui.Parent = parent

		local newLabel = Instance.new("TextLabel")
		newLabel.Name = "DifficultyLabel"
		newLabel.AnchorPoint = Vector2.new(0.5, 0)
		newLabel.Position = UDim2.new(0.5, 0, 0, 14)
		newLabel.Size = UDim2.new(0, 460, 0, 34)
		newLabel.BackgroundTransparency = 1
		newLabel.Font = Enum.Font.GothamBold
		newLabel.TextSize = 22
		newLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		newLabel.TextStrokeTransparency = 0.4
		newLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		newLabel.TextXAlignment = Enum.TextXAlignment.Center
		newLabel.Text = ""
		newLabel.Parent = screenGui
		return newLabel
	end)
	if ok then towerStatusLabel = label end
	Kaitun._internal.towerStatusLabel = towerStatusLabel
	return towerStatusLabel
end

local function setTowerStatusText(difficultyName, towerName)
	local label = getTowerStatusLabel()
	if label then
		label.Text = ("กำลังลง: %s (%s)"):format(difficultyName, towerName)
	end
end

-- Screen/Hidden are siblings under UIReferences.Root.Tower (TowerController.lua:49-51:
-- `local Background = Screen.Parent.Background; local Hidden = Screen.Parent.Hidden`).
local function getTowerUIRefs()
	local ui = Mods.UIReferences
	local root = ui and ui.Root
	local tower = root and root.Tower
	local screen = tower and tower.Screen
	if not screen then return nil, nil end
	return screen, screen.Parent and screen.Parent:FindFirstChild("Hidden")
end

-- The one real, externally-observable "run is currently active" signal.
-- Deliberately Hidden.Visible, NOT Screen.Visible: Hidden.Visible stays true
-- for the whole run regardless of Hide state (only towerStarted/towerEnded
-- touch it), while Screen.Visible also flips false whenever the run is
-- merely hidden -- using it here would make Auto Hide look like "run ended".
local function isTowerRunActive()
	local ok, result = pcall(function()
		local _, hiddenPill = getTowerUIRefs()
		return hiddenPill ~= nil and hiddenPill.Visible == true
	end)
	return ok and result == true
end

-- Presses the REAL in-game Hide pill -- not a replication of its effects.
-- Hidden is wired through Button.init(Hidden), which returns the raw
-- Instance itself as its 2nd value (Button.lua:38-52: `return u5, p1`), and
-- TowerController.lua connects `.Activated` directly on that raw Instance
-- (TowerController.lua:216-218) -- so Hidden.Activated is a genuine native
-- RBXScriptSignal, exactly what a real click fires, with no custom
-- Signal/BindableEvent layer to invoke instead. There is no remote for Hide
-- (confirmed: setTowerHidden is 100% client-local), so the only way to
-- trigger the SAME code path a real press does is firing that signal, which
-- is an executor capability rather than a game fact -- feature-detected with
-- typeof(firesignal)=="function" exactly like queue_on_teleport/writefile
-- elsewhere in this file, never assumed present.
local function pressHideButton()
	local _, hidden = getTowerUIRefs()
	if not (hidden and typeof(firesignal) == "function") then return false end
	local ok = pcall(firesignal, hidden.Activated)
	return ok
end

-- Fallback used only when firesignal isn't available on this executor:
-- reproduces setTowerHidden(true)'s confirmed, publicly-reachable effects by
-- hand (TowerController.lua:79-89) instead of pressing the real button.
local function hideTowerUIManually()
	local screen, hidden = getTowerUIRefs()
	if not screen then return false end
	local ok = pcall(function()
		if Mods.HUDController and Mods.HUDController.showAll then Mods.HUDController.showAll("inTower") end
		screen.Visible = false
		if hidden then hidden.Position = UDim2.fromScale(0.5, 0.76) end
	end)
	return ok
end

-- Applies Auto Hide: real button press first, manual replication only as a
-- fallback. Verified against real UI state either way -- Screen.Visible must
-- read back false while Hidden.Visible (the run-active signal) stays true,
-- confirming this is "hidden mid-run", never "ended".
local function applyAutoHide()
	local pressed = pressHideButton()
	if pressed then
		task.wait(0.2)
		local screen = getTowerUIRefs()
		if screen and screen.Visible == false and isTowerRunActive() then
			return true, "pressed the real Hide button (firesignal)"
		end
	end
	if hideTowerUIManually() then
		return true, "firesignal unavailable or the real press didn't verify -- replicated Hide's effects manually"
	end
	return false, "UI references unavailable"
end

-- Only Hidden.Position needs a manual fixup before the next flow: a leftover
-- hidden-side position (0.76) from a previous Auto Hide never gets reset by
-- towerStarted()/towerEnded() (both manage Screen.Visible/Hidden.Visible/
-- HUDController themselves, but neither ever touches Hidden.Position).
local function restoreTowerUI()
	local _, hidden = getTowerUIRefs()
	if hidden then pcall(function() hidden.Position = UDim2.fromScale(0.5, 0.87) end) end
end

-- State machine: Idle -> SelectHard -> EquipBest -> Starting -> InRun -> back
-- to Idle once Hidden.Visible reads back false. Kaitun.State.TowerPhase is the
-- single source of truth, so two overlapping calls (already prevented by the
-- global runExclusive Busy mutex every Tick runs under) could never double up
-- the flow either way — a run already verified InRun always returns
-- immediately without touching PlayTower/EquipBestTowerTeam again.
function Ticks.AutoTower()
	if not (Mods.TowerController and Mods.TowerController.startTower) then
		logStepSkip("Tower", "Towers.TowerController module unavailable")
		return
	end
	if not Net.EquipBestTowerTeam then
		logStepSkip("Tower", "Towers.RE.EquipBestTowerTeam remote missing")
		return
	end

	if isTowerRunActive() then
		if Kaitun.State.TowerPhase ~= "InRun" then
			Kaitun.State.TowerPhase = "InRun"
			Kaitun:Log("[TOWER] Hidden.Visible=true confirmed -- run in progress, nothing to do this tick")
		end
		return
	end

	if Kaitun.State.TowerPhase == "InRun" then
		Kaitun:Log("[TOWER] Hidden.Visible=false confirmed -- previous run ended, restoring UI then restarting the flow")
		restoreTowerUI()

		-- In BoostMode="Normal", use every owned Boost only after an Infinity
		-- run finishes. This also works when TowerMode itself is "Infinity".
		local towerMode = Kaitun.Config.TowerMode
		local finishedDifficulty = Kaitun.State.LastTowerDifficulty
			or TOWER_DIFFICULTY_ORDER[Kaitun.State.TowerDifficultyIndex]
		if Kaitun.Config.BoostMode == "Normal" and finishedDifficulty == "Infinity" and Kaitun.Toggles.AutoBoost then
			Kaitun:Log("[TOWER] Infinity just finished -- BoostMode=Normal, using every owned Boost")
			Ticks.AutoBoost()
		end

		-- Only Normal advances the cycle. A named mode repeats that difficulty.
		if towerMode == "Normal" then
			Kaitun.State.TowerDifficultyIndex = (Kaitun.State.TowerDifficultyIndex % #TOWER_DIFFICULTY_ORDER) + 1
		end
	end

	-- 1) Select the next cycling tier, or the single configured tier.
	Kaitun.State.TowerPhase = "SelectHard"
	local towerMode = Kaitun.Config.TowerMode
	local targetDifficulty = towerMode == "Normal"
		and TOWER_DIFFICULTY_ORDER[Kaitun.State.TowerDifficultyIndex] or towerMode
	local towerName = getTowerNameByDifficulty(targetDifficulty)
	if not towerName then
		logStepSkip("Tower", ("no roster entry has difficulty.name == '%s' in Towers.lua -- skipping this tier"):format(targetDifficulty))
		Kaitun.State.TowerPhase = "Idle"
		if towerMode == "Normal" then
			Kaitun.State.TowerDifficultyIndex = (Kaitun.State.TowerDifficultyIndex % #TOWER_DIFFICULTY_ORDER) + 1
		end
		return
	end
	Kaitun:Log(("[TOWER] mode=%s tower=%s"):format(targetDifficulty, towerName))
	setTowerStatusText(targetDifficulty, towerName)

	-- 2) Equip Best — fire the real remote, then verify against
	-- DataController.TowerTeam() (server-authoritative state) instead of
	-- assuming the fire landed.
	Kaitun.State.TowerPhase = "EquipBest"
	safeFire(Net.EquipBestTowerTeam)
	local filled = 0
	for _ = 1, 5 do
		task.wait(0.3)
		local ok, team = pcall(Mods.DataController.TowerTeam)
		filled = 0
		if ok and type(team) == "table" then
			for _, unitKey in pairs(team) do
				if unitKey then filled += 1 end
			end
		end
		if filled > 0 then break end
	end
	local maxTeamSize = (Mods.TowerRefs and Mods.TowerRefs.MAX_TEAM_SIZE) or 4
	if filled == 0 then
		Kaitun:Log("[TOWER] EquipBestTowerTeam verified 0 slot(s) filled (no owned units, or server response not observed in time) -- starting anyway")
	else
		Kaitun:Log(("[TOWER] EquipBestTowerTeam verified: %d/%d slot(s) filled"):format(filled, maxTeamSize))
	end

	-- 3) Fight — the exact function TowerSelectionController.lua's real Fight
	-- button calls (line 125-126).
	Kaitun.State.TowerPhase = "Starting"
	local ok, started = pcall(Mods.TowerController.startTower, towerName)
	if not ok or not started then
		Kaitun:Log(("[TOWER] startTower(%s) returned false -- already running client-side, PlayTower's 3s debounce, or the tower name/roster mismatch"):format(towerName))
		Kaitun.State.TowerPhase = "Idle"
		return
	end

	-- 4) Verify against the real UI state rather than trusting the return
	-- value alone.
	for _ = 1, 10 do
		task.wait(0.2)
		if isTowerRunActive() then
			Kaitun.State.TowerPhase = "InRun"
			Kaitun.State.LastTowerDifficulty = targetDifficulty
			Kaitun:Log(("[TOWER] Fight confirmed -- Hidden.Visible=true for %s"):format(towerName))

			-- 5) Auto Hide — presses the real Hide button (never Hidden.Visible,
			-- so this can never look like "ended").
			if Kaitun.Toggles.AutoHideTower then
				local hidOk, how = applyAutoHide()
				if hidOk then
					Kaitun:Log(("[TOWER] Auto Hide applied -- %s"):format(how))
				else
					Kaitun:Log(("[TOWER] Auto Hide failed (%s) -- fight continues visible"):format(how))
				end
			end
			return
		end
	end
	Kaitun:Log(("[TOWER] startTower(%s) returned true but Hidden.Visible never became true within 2s -- treating as failed, will retry next tick"):format(towerName))
	Kaitun.State.TowerPhase = "Idle"
end

--============================================================
-- Redeem codes  (MonetizationController.lua:41,321-334 ; MonetizationService.lua:296-336 ;
-- MonetizationConfig.lua:84-104 — confirmed static list). Self-disables after one
-- pass since the code list is finite and DataController.RedeemedCodes tracks state.
--============================================================
local KNOWN_CODES = {"RELEASE", "UPDATE1", "UPDATE2", "UPDATE3", "1KCCU", "5KCCU"}

function Ticks.AutoRedeemCodes()
	if not (Net.RedeemCode and Mods.DataController) then return end
	local ok, redeemed = pcall(function() return Mods.DataController.RedeemedCodes and Mods.DataController.RedeemedCodes() end)
	redeemed = (ok and type(redeemed) == "table") and redeemed or {}
	for _, code in ipairs(KNOWN_CODES) do
		if redeemed[code] ~= true then
			safeFire(Net.RedeemCode, code)
			task.wait(0.6)
		end
	end
	Kaitun.Toggles.AutoRedeemCodes = false
	Kaitun:Log("[AutoRedeemCodes] pass complete (one-shot)")
end

--============================================================
-- Reward claims  (all confirmed no-arg RE.Claim fires, server validates)
--============================================================
-- Set once the server tells us group membership is the blocker ("Join the group
-- to claim these rewards!") — the player didn't join the Roblox group, which
-- this script cannot do for them, so retrying every 30s forever just spams that
-- same error notification for no reason. Stops asking until script restart.
local groupClaimBlocked = false

function Ticks.AutoClaimRewards()
	if Net.DailyClaim then safeFire(Net.DailyClaim) end
	if Net.OfflineClaim and Mods.DataController and Mods.DataController.PendingOfflineEarnings then
		local ok, pending = pcall(Mods.DataController.PendingOfflineEarnings)
		if ok and type(pending) == "number" and pending > 0 then
			safeFire(Net.OfflineClaim)
		end
	end
	if (not groupClaimBlocked) and Net.GroupClaim and Mods.DataController and Mods.DataController.ClaimedGroupReward then
		local ok, claimed = pcall(Mods.DataController.ClaimedGroupReward)
		if ok and claimed ~= true then
			safeFire(Net.GroupClaim)
			local note = waitForNotification(0.6)
			if note and note.notificationType == "error" and type(note.message) == "string"
				and note.message:lower():find("join the group", 1, true) then
				groupClaimBlocked = true
				Kaitun:Log("[AutoClaimRewards] group reward needs the player to join the game's Roblox group — not retrying (can't do that for you).")
			end
		end
	end
end

--============================================================
-- Quest claim  (QuestController.lua:44,241-252 ; QuestService.lua:103-138)
-- RE.Claim(period, questId, expiresAt) — verified against decompiled dump.
-- Accesses DataController.Quests[period]() directly and matches QuestConfig.Periods[period].quests.
--============================================================
function Ticks.AutoQuestClaim()
	if not (Net.QuestClaim and Mods.DataController and Mods.DataController.Quests) then return end

	local questPeriods = {"Daily", "Weekly"}
	for _, period in ipairs(questPeriods) do
		local okBucket, bucket = pcall(function()
			if type(Mods.DataController.Quests[period]) == "function" then
				return Mods.DataController.Quests[period]()
			end
			return nil
		end)

		if okBucket and type(bucket) == "table" and type(bucket.progress) == "table" and type(bucket.expiresAt) == "number" then
			local questList = nil
			if Mods.QuestConfig and Mods.QuestConfig.Periods and Mods.QuestConfig.Periods[period] then
				questList = Mods.QuestConfig.Periods[period].quests
			end

			if type(questList) ~= "table" then
				if period == "Daily" then
					questList = {
						{ id = "Playtime", target = 1800 },
						{ id = "Rolls", target = 1000 },
						{ id = "Towers", target = 2 },
						{ id = "UnitsSold", target = 500 },
					}
				elseif period == "Weekly" then
					questList = {
						{ id = "Playtime", target = 18000 },
						{ id = "Rolls", target = 7500 },
						{ id = "Towers", target = 15 },
						{ id = "UnitsSold", target = 5000 },
					}
				end
			end

			if type(questList) == "table" then
				local claimedMap = type(bucket.claimed) == "table" and bucket.claimed or {}
				for _, questItem in ipairs(questList) do
					if type(questItem) == "table" and questItem.id and type(questItem.target) == "number" then
						local questId = questItem.id
						local targetGoal = questItem.target
						local currentProgress = bucket.progress[questId] or 0
						local isClaimed = claimedMap[questId] == true

						if currentProgress >= targetGoal and not isClaimed then
							Kaitun:Log(("[QUEST] Claiming %s quest '%s' (%d/%d)..."):format(period, questId, currentProgress, targetGoal))
							safeFire(Net.QuestClaim, period, questId, bucket.expiresAt)
							task.wait(0.3)
						end
					end
				end
			end
		end
	end
end

--============================================================
-- Auto Boost ("Potion") — re-verified directly against the dump.
--
-- There is NO separate "Potion" kind anywhere: EntryRegistry.lua:31-36 lists
-- exactly 4 entry kinds in the whole game -- Unit, Boost, Token, Spin -- and
-- no file in the dump mentions "potion" in any form (case-insensitive search,
-- zero hits). "Boost" (BoostConfig.lua:45-410 — 12 categories x 3 tiers = 36
-- entries: Luck/Damage/Income at 300s, Dragon Luck/Income/Damage at 120s,
-- Cursed Luck/Damage/Income at 180s, Pirate Luck/Damage/Income at 240s) is the
-- consumable buff-item system, and is what this Tick drives.
--
-- BoostService.lua:159-182 (`RE.Use` handler) confirms the exact mechanics:
--   local v2 = Inventory[p2]()              -- p2 = inventory key; Boost entries
--                                               are stackable=true (BoostConfig.lua:47)
--                                               and keyed by their own NAME.
--   local v3 = EntryRegistry.getEntryConfig(v2.name)  -- v3.kind == "Boost"
--   EntryService.Remove(p1, p2, 1)           -- consumes exactly 1 per call
--   ActiveEntries[v2.name] = {remaining = existingRemaining + v3.duration}
--                                            -- using an already-active boost
--                                               EXTENDS it, never wastes it.
--   No DebounceUtil.Try(...) anywhere in this handler -- confirmed there is no
--   server-side per-use cooldown to respect, so none is invented here.
--
-- BoostService.lua:105-157 (`u51`, run right after every Use) separately
-- groups ActiveEntries by category and only re-arms an expiry timer for the
-- highest tier per category -- that is the SERVER's own bookkeeping for what
-- counts as "the" active buff per category, not a rule that blocks firing Use
-- on other tiers/categories. Per the explicit instruction to use every owned
-- type with nothing skipped, this Tick fires Use on every single Boost-kind
-- stack currently owned, draining each down to 0 -- no per-category "already
-- active, skip it" gate anymore.
--============================================================
local function getOwnedBoostStacks()
	local stacks = {}
	if not (Mods.DataController and Mods.DataController.Inventory and Mods.BoostConfig and Mods.BoostConfig.entries) then
		return stacks
	end
	local ok, inv = pcall(Mods.DataController.Inventory)
	if not ok or type(inv) ~= "table" then return stacks end
	for key, entry in pairs(inv) do
		if type(entry) == "table" and type(entry.amount) == "number" and entry.amount >= 1 then
			local cfg = Mods.BoostConfig.entries[entry.name]
			if cfg then
				stacks[#stacks + 1] = {key = key, name = entry.name, amount = entry.amount, category = cfg.category, tier = cfg.tier}
			end
		end
	end
	return stacks
end

-- Called after Infinity in BoostMode="Normal", or immediately after the
-- scheduler detects owned Boosts in BoostMode="Instant". It must drain EVERY
-- owned Boost-kind stack completely before
-- returning, not just one capped pass: it re-queries live inventory in an
-- outer loop until nothing owned is left, or a full pass fires zero
-- successful Use calls (server rejecting everything -- stop instead of
-- spinning forever). SAFETY_MAX_FIRES is only a circuit breaker against a
-- runaway loop, never expected to actually be hit.
function Ticks.AutoBoost()
	setCoreState("Boost")
	if not (Net.BoostUse and Mods.DataController and Mods.DataController.Inventory and Mods.BoostConfig and Mods.BoostConfig.entries) then
		logStepSkip("Boost", "missing dependency (BoostService.RE.Use / DataController.Inventory / BoostConfig)")
		return
	end

	local SAFETY_MAX_FIRES = 5000
	local totalFired = 0

	while totalFired < SAFETY_MAX_FIRES do
		local stacks = getOwnedBoostStacks()
		if #stacks == 0 then
			if totalFired == 0 then logStepSkip("Boost", "no owned Boost-kind inventory items") end
			break
		end

		local firedThisPass = 0
		for _, stack in ipairs(stacks) do
			local remaining = stack.amount
			while remaining > 0 and totalFired < SAFETY_MAX_FIRES do
				logStepStart("Boost", "Network.BoostService.RE.Use", stack.key)
				local ok = safeFire(Net.BoostUse, stack.key)
				totalFired += 1
				firedThisPass += 1
				logStepResult("Boost", ok, ("category=%s tier=%s"):format(tostring(stack.category), tostring(stack.tier)))
				if ok then
					Kaitun:Log(("[BOOST] use=%s category=%s tier=%s (%d left in stack before this fire)"):format(
						stack.name, tostring(stack.category), tostring(stack.tier), remaining))
				end
				task.wait(0.2)

				-- Verify against real Inventory state rather than assuming the
				-- fire consumed one, since EntryService.Remove could reject it.
				local okI, inv = pcall(Mods.DataController.Inventory)
				local entry = okI and type(inv) == "table" and inv[stack.key]
				local newRemaining = (entry and type(entry.amount) == "number") and entry.amount or 0
				if newRemaining >= remaining then
					Kaitun:Log(("[BOOST] use=%s did not reduce the stack (still %d) -- stopping this stack"):format(stack.name, newRemaining))
					break
				end
				remaining = newRemaining
			end
		end

		if firedThisPass == 0 then
			Kaitun:Log("[BOOST] a full pass fired 0 successful Use calls -- stopping (server is rejecting every remaining stack)")
			break
		end
	end

	if totalFired > 0 then
		Kaitun:Log(("[BOOST] drained %d Use fire(s) across all owned stacks -- fully empty before continuing"):format(totalFired))
	end
end

-- Instant mode is intentionally a small wrapper around AutoBoost: it first
-- checks inventory silently, then drains it only when something is actually
-- owned. The scheduler still supplies the normal AutoBoost toggle and global
-- mutex, so it cannot race Tower or the rest of the automation.
function Ticks.AutoBoostInstant()
	if Kaitun.Config.BoostMode ~= "Instant" then return end
	local stacks = getOwnedBoostStacks()
	if #stacks == 0 then return end
	Kaitun:Log("[BOOST] BoostMode=Instant -- owned Boost detected, consuming now")
	Ticks.AutoBoost()
end

--============================================================
-- Trade Automation Engine (Auto Trade + Cross-Server Follow)
-- Domain Coordinates: ReplicatedStorage.Network.TradeService
--============================================================
local TradeSessionState = {
	Active = false,
	CooldownExpiry = 0,
	TeleportCooldownExpiry = 0,
	CurrentPhase = "Idle",
}

local function locateTargetPlayer(accountName)
	if not accountName or accountName == "" then return nil end
	local cleanQuery = string.lower(string.gsub(tostring(accountName), "%s+", ""))
	for _, playerSubject in ipairs(Players:GetPlayers()) do
		if playerSubject ~= LocalPlayer then
			local subjectName = string.lower(string.gsub(tostring(playerSubject.Name), "%s+", ""))
			local subjectDisplay = string.lower(string.gsub(tostring(playerSubject.DisplayName), "%s+", ""))
			if subjectName == cleanQuery or subjectDisplay == cleanQuery then
				return playerSubject
			end
		end
	end
	return nil
end

local function checkTradeEligibility()
	if game.PrivateServerId ~= "" then return false end
	if LocalPlayer.AccountAge < 14 then return false end
	local rollsCount = (Mods.DataController and Mods.DataController.Rolls) and Mods.DataController.Rolls() or 0
	if rollsCount < 1000 then return false end
	return true
end

local function resolveTradeOfferAmount(entryIdentifier, thresholdQuantity, transferAllFlag)
	local balanceQuantity = getEntryAmount(entryIdentifier)
	if balanceQuantity <= 0 then return 0 end
	if thresholdQuantity > 0 and balanceQuantity < thresholdQuantity then return 0 end
	if transferAllFlag then
		return balanceQuantity
	end
	return math.min(balanceQuantity, thresholdQuantity)
end

local function broadcastMainServerIdentity()
	local targetUsername = Kaitun.Settings.TargetUsername
	if not targetUsername or targetUsername == "" then return end
	local cleanExpected = string.lower(string.gsub(tostring(targetUsername), "%s+", ""))
	local cleanLocalName = string.lower(string.gsub(tostring(LocalPlayer.Name), "%s+", ""))
	if cleanLocalName ~= cleanExpected then return end

	local currentJobId = game.JobId
	if typeof(writefile) == "function" then
		pcall(writefile, "TargetServerJobId.txt", currentJobId)
	end
	if typeof(setclipboard) == "function" then
		pcall(setclipboard, currentJobId)
	end
	Kaitun:Log(("[TRADE] Main account active in JobId: %s (Saved & Copied)"):format(currentJobId))
end

local function fetchTargetUserId(targetName)
	local okAsync, resolvedId = pcall(function()
		return Players:GetUserIdFromNameAsync(targetName)
	end)
	if okAsync and typeof(resolvedId) == "number" then
		return resolvedId
	end
	return nil
end

local function fetchPresenceJobId(targetUserId)
	local executorRequest = (typeof(request) == "function" and request)
		or (typeof(http_request) == "function" and http_request)
		or (syn and typeof(syn.request) == "function" and syn.request)
	if not executorRequest then return nil end

	local okHttp, responseEnvelope = pcall(executorRequest, {
		Url = "https://presence.roblox.com/v1/presence/users",
		Method = "POST",
		Headers = { ["Content-Type"] = "application/json" },
		Body = HttpService:JSONEncode({ userIds = { targetUserId } }),
	})
	if not (okHttp and responseEnvelope and responseEnvelope.Body) then return nil end

	local okDecode, parsedBody = pcall(function()
		return HttpService:JSONDecode(responseEnvelope.Body)
	end)
	if not (okDecode and parsedBody and parsedBody.userPresences) then return nil end

	local targetRecord = parsedBody.userPresences[1]
	if targetRecord and targetRecord.userPresenceType == 2 and targetRecord.gameId ~= "" then
		return targetRecord.gameId
	end
	return nil
end

local function readSharedServerJobId()
	if Kaitun.Settings.TargetServerJobId and Kaitun.Settings.TargetServerJobId ~= "" then
		return Kaitun.Settings.TargetServerJobId
	end
	if typeof(readfile) == "function" and typeof(isfile) == "function" then
		local fileExists = pcall(isfile, "TargetServerJobId.txt")
		if fileExists and isfile("TargetServerJobId.txt") then
			local okRead, fileContent = pcall(readfile, "TargetServerJobId.txt")
			if okRead and type(fileContent) == "string" and fileContent ~= "" then
				return string.gsub(fileContent, "%s+", "")
			end
		end
	end
	return nil
end

local function resolveTargetJobId(targetAccountName)
	local sharedJobId = readSharedServerJobId()
	if sharedJobId and sharedJobId ~= "" then
		return sharedJobId
	end

	local numericUserId = fetchTargetUserId(targetAccountName)
	if not numericUserId then return nil end

	return fetchPresenceJobId(numericUserId)
end

local function attemptServerFollow(targetAccountName)
	local cleanExpected = string.lower(string.gsub(tostring(targetAccountName), "%s+", ""))
	local cleanLocalName = string.lower(string.gsub(tostring(LocalPlayer.Name), "%s+", ""))
	if cleanLocalName == cleanExpected then return false end
	if locateTargetPlayer(targetAccountName) then return false end

	local targetJobId = resolveTargetJobId(targetAccountName)
	if not (targetJobId and targetJobId ~= "") then return false end
	if targetJobId == game.JobId then return false end

	Kaitun:Log(("[TRADE] Warping to target Server ID: %s"):format(targetJobId))
	local TeleportService = game:GetService("TeleportService")
	TeleportService:TeleportToPlaceInstance(game.PlaceId, targetJobId, LocalPlayer)
	return true
end

local function bindTradeNetworkEvents()
	local tradeEvent = Net.TradeEvent
	if not tradeEvent then return end

	tradeEvent.OnClientEvent:Connect(function(eventType, packet)
		local expectedTarget = Kaitun.Settings.TargetUsername
		local cleanExpected = string.lower(string.gsub(tostring(expectedTarget), "%s+", ""))
		local cleanLocalName = string.lower(string.gsub(tostring(LocalPlayer.Name), "%s+", ""))
		local isMainAccount = (cleanLocalName == cleanExpected)

		if eventType == "RequestReceived" then
			local senderInstance = packet.player
			local cleanSenderName = senderInstance and string.lower(string.gsub(tostring(senderInstance.Name), "%s+", "")) or ""
			local cleanSenderDisplay = senderInstance and string.lower(string.gsub(tostring(senderInstance.DisplayName), "%s+", "")) or ""

			local isFromTarget = (cleanSenderName == cleanExpected) or (cleanSenderDisplay == cleanExpected)
			local shouldAccept = Kaitun.Toggles.AutoAcceptTrades and (isMainAccount or isFromTarget)

			Kaitun:Log(("[TRADE] RequestReceived from: '%s' | IsMain: %s | Accept: %s"):format(
				tostring(senderInstance and senderInstance.Name),
				tostring(isMainAccount),
				tostring(shouldAccept)
			))

			if shouldAccept and Net.RespondToRequest then
				task.delay(0.2, function()
					Net.RespondToRequest:FireServer(true)
				end)
			end

		elseif eventType == "Started" then
			TradeSessionState.Active = true
			TradeSessionState.CurrentPhase = "Offer"
			local partnerLabel = packet.partner and packet.partner.Name or "Unknown"
			Kaitun:Log("[TRADE] Trade session started with " .. partnerLabel)

			if isMainAccount then
				Kaitun:Log("[TRADE] Main account waiting for partner items...")
			else
				task.delay(0.4, function()
					local gemsToSend = resolveTradeOfferAmount("Gems", Kaitun.Settings.GemsThreshold, Kaitun.Settings.TransferAll)
					local traitsToSend = resolveTradeOfferAmount("Trait Reroll", Kaitun.Settings.TraitThreshold, Kaitun.Settings.TransferAll)

					Kaitun:Log(("[TRADE] Submitting offer: %d Gems, %d Trait Rerolls"):format(gemsToSend, traitsToSend))

					if gemsToSend > 0 and Net.ChangeOffer then
						Net.ChangeOffer:FireServer("Gems", gemsToSend)
						task.wait(0.15)
					end
					if traitsToSend > 0 and Net.ChangeOffer then
						Net.ChangeOffer:FireServer("Trait Reroll", traitsToSend)
						task.wait(0.15)
					end

					if Net.AdvanceTrade then
						Net.AdvanceTrade:FireServer()
					end
				end)
			end

		elseif eventType == "Updated" then
			TradeSessionState.CurrentPhase = packet.phase

			if packet.phase == "Offer" and not packet.ownReady then
				if isMainAccount and packet.otherReady then
					Kaitun:Log("[TRADE] Partner locked offer. Main account locking now...")
					task.delay(0.3, function()
						if Net.AdvanceTrade then Net.AdvanceTrade:FireServer() end
					end)
				end
			end

			if packet.phase == "Confirm" and not packet.ownAccepted then
				Kaitun:Log("[TRADE] Phase reached Confirm. Finalizing in 0.5s...")
				task.delay(0.5, function()
					if Net.AdvanceTrade then Net.AdvanceTrade:FireServer() end
				end)
			end

		elseif eventType == "Ended" then
			Kaitun:Log("[TRADE] Trade session ended: " .. tostring(packet.reason))
			TradeSessionState.Active = false
			TradeSessionState.CurrentPhase = "Idle"
			TradeSessionState.CooldownExpiry = os.clock() + 10
		end
	end)
end

function Ticks.AutoTrade()
	if not Kaitun.Toggles.AutoTrade then return end
	if TradeSessionState.Active then return end

	local cleanExpected = string.lower(string.gsub(tostring(Kaitun.Settings.TargetUsername), "%s+", ""))
	local cleanLocalName = string.lower(string.gsub(tostring(LocalPlayer.Name), "%s+", ""))
	if cleanLocalName == cleanExpected or cleanExpected == "" then return end

	local availableGems = getEntryAmount("Gems")
	local availableTraits = getEntryAmount("Trait Reroll")

	local gemsReady = (Kaitun.Settings.GemsThreshold > 0 and availableGems >= Kaitun.Settings.GemsThreshold)
		or (Kaitun.Settings.GemsThreshold == 0 and availableGems > 0)
	local traitsReady = (Kaitun.Settings.TraitThreshold > 0 and availableTraits >= Kaitun.Settings.TraitThreshold)
		or (Kaitun.Settings.TraitThreshold == 0 and availableTraits > 0)
	local hasDeliveryPayload = (gemsReady or traitsReady)

	local partnerSubject = locateTargetPlayer(Kaitun.Settings.TargetUsername)

	-- 1. Smart Warp-In: วาปเข้าเซิร์ฟหลักเฉพาะเมื่อของครบเกณฑ์เท่านั้น
	if not partnerSubject and Kaitun.Toggles.AutoFollowServer and hasDeliveryPayload then
		if os.clock() >= TradeSessionState.TeleportCooldownExpiry then
			local randomTeleportJitter = math.random(10, 18)
			TradeSessionState.TeleportCooldownExpiry = os.clock() + randomTeleportJitter
			Kaitun:Log(("[TRADE] Items ready (Gems: %d, Trait: %d). Queuing warp..."):format(availableGems, availableTraits))
			attemptServerFollow(Kaitun.Settings.TargetUsername)
		end
	-- 2. Staggered Request: สุ่มกระจายเวลาส่งคำขอเทรด ป้องกันการแย่งคิวกันเอง
	elseif partnerSubject and hasDeliveryPayload and os.clock() >= TradeSessionState.CooldownExpiry then
		if checkTradeEligibility() and Net.RequestTrade then
			local randomRequestJitter = math.random(6, 11)
			TradeSessionState.CooldownExpiry = os.clock() + randomRequestJitter
			Kaitun:Log(("[TRADE] Initiating trade to %s (Gems: %d, Trait: %d | Jitter: %ds)"):format(
				partnerSubject.Name, availableGems, availableTraits, randomRequestJitter
			))
			Net.RequestTrade:FireServer(partnerSubject)
		end
	end
end

Kaitun._internal.bindTradeNetworkEvents = bindTradeNetworkEvents
Kaitun._internal.broadcastMainServerIdentity = broadcastMainServerIdentity

--============================================================
-- Scheduler
--
-- CorePipeline runs in strict, fixed order every cycle — Roll -> EquipBest ->
-- Lock -> Sell -> UpgradeDice/Luck -> Rebirth — matching the flow requested for
-- stabilizing progression from a fresh account through Rebirth. Roll has
-- Interval=0 (paced only by the outer loop's task.wait) since it needs to fire
-- as fast as the server allows.
--
-- MoneyEconomy replaces independent scheduling of AutoCollectBalance /
-- AutoRebirth / AutoDice / AutoLevelUpSlots / AutoUpgradeTree / AutoSell — see
-- Ticks.MoneyEconomy's own comment block for why (money-spenders were racing
-- Rebirth for the same funds). It runs those six in one fixed order every time
-- it's due, each still gated by its own Kaitun.Toggles.* flag.
--
-- OtherFeatures (Grade/Trait rerolling, Tower, Redeem Codes, reward/quest
-- claims) are unchanged and still run on their own independent interval
-- schedule — they are not part of the Money Economy flow.
--============================================================
-- AutoLockBest now runs more often than Sell used to catch it out, but the real
-- fix for the sell race is that AutoSell builds its own protection from live
-- data at sell time (buildProtectedSet), so a unit rolled one millisecond ago is
-- already covered before Lock or EquipBest has run at all.
local CorePipeline = {
	{Key = "AutoRoll", Interval = 0, Tick = Ticks.AutoRoll, NextRun = 0},
	{Key = "AutoPlotBest", Interval = 6, Tick = Ticks.AutoPlotBest, NextRun = 0},
	{Key = "AutoLockBest", Interval = 8, Tick = Ticks.AutoLockBest, NextRun = 0},
	{Key = "MoneyEconomy", Interval = 3, Tick = Ticks.MoneyEconomy, NextRun = 0},
}

local OtherFeatures = {
	{Key = "AutoGrade", Interval = 5, Tick = Ticks.AutoGrade, NextRun = 0},
	{Key = "AutoTrait", Interval = 5, Tick = Ticks.AutoTrait, NextRun = 0},
	-- In BoostMode="Normal", AutoBoost runs only after Infinity finishes. In
	-- BoostMode="Instant", this checks every 2 seconds and consumes as soon as
	-- owned Boost inventory is found. The AutoBoost toggle gates both modes.
	{Key = "AutoBoost", Interval = 2, Tick = Ticks.AutoBoostInstant, NextRun = 0},
	{Key = "AutoTower", Interval = 20, Tick = Ticks.AutoTower, NextRun = 0},
	{Key = "AutoRedeemCodes", Interval = 2, Tick = Ticks.AutoRedeemCodes, NextRun = 0},
	{Key = "AutoClaimRewards", Interval = 30, Tick = Ticks.AutoClaimRewards, NextRun = 0},
	{Key = "AutoQuestClaim", Interval = 20, Tick = Ticks.AutoQuestClaim, NextRun = 0},
	{Key = "AutoTrade", Interval = 5, Tick = Ticks.AutoTrade, NextRun = 0},
}

local function setupAutoResume()
	if typeof(queue_on_teleport) == "function" and Kaitun.Config.LoaderURL ~= "" then
		local src = ("loadstring(game:HttpGet(%q))()"):format(Kaitun.Config.LoaderURL)
		pcall(queue_on_teleport, src)
		Kaitun:Log("[Resume] queue_on_teleport armed")
	else
		Kaitun:Log("[GAP] Auto-reconnect needs Kaitun.Config.LoaderURL set to your own loadstring URL (queue_on_teleport available: "
			.. tostring(typeof(queue_on_teleport) == "function") .. ")")
	end
end

--============================================================
-- UltraLite -- client-only visual reduction.
--
-- It disables only Roblox cosmetic-effect classes and Lighting post effects.
-- It never deletes instances or changes Models, Parts, collision/query state,
-- GUI hierarchy, animations, remotes, or game controllers: those may be used
-- by the game's UI/target discovery and are deliberately kept intact.
--============================================================
local UltraLite = {started = false, connections = {}}
Kaitun._internal.UltraLite = UltraLite

local function ultraLiteLog(message)
	print("[UltraLite] " .. message)
end

local function applyUltraLiteTo(instance)
	if not Kaitun.Config.UltraLite then return end
	pcall(function()
		if instance:IsA("ParticleEmitter")
			or instance:IsA("Trail")
			or instance:IsA("Beam")
			or instance:IsA("Smoke")
			or instance:IsA("Fire")
			or instance:IsA("Sparkles") then
			instance.Enabled = false
		elseif instance:IsA("PostEffect") then
			-- Covers Blur, Bloom, ColorCorrection, SunRays, and DepthOfField.
			instance.Enabled = false
		end
	end)
end

local function applyUltraLiteExisting(root)
	local descendants = root:GetDescendants()
	for index, instance in ipairs(descendants) do
		applyUltraLiteTo(instance)
		-- Do not freeze a low-end client while a large map is scanned.
		if index % 250 == 0 then task.wait() end
	end
end

local function startUltraLite()
	if UltraLite.started or not Kaitun.Config.UltraLite then return end
	UltraLite.started = true

	-- These are client-side lighting quality controls only; no world instance,
	-- material, texture, or geometry is modified.
	pcall(function()
		Lighting.GlobalShadows = false
		Lighting.EnvironmentDiffuseScale = 0
		Lighting.EnvironmentSpecularScale = 0
	end)

	local cap = Kaitun.Config.FPSCap
	if typeof(setfpscap) == "function" then
		local ok = pcall(setfpscap, cap)
		ultraLiteLog(ok and ("FPS cap set to " .. tostring(cap))
			or ("setfpscap(" .. tostring(cap) .. ") failed; continuing uncapped"))
	else
		ultraLiteLog("setfpscap unsupported; continuing without an FPS cap")
	end

	-- Connect before the first scan: effects created during that scan are still
	-- caught, while later effects are handled as they are added.
	UltraLite.connections[#UltraLite.connections + 1] = Workspace.DescendantAdded:Connect(function(instance)
		task.defer(applyUltraLiteTo, instance)
	end)
	UltraLite.connections[#UltraLite.connections + 1] = Lighting.DescendantAdded:Connect(function(instance)
		task.defer(applyUltraLiteTo, instance)
	end)

	task.spawn(function()
		applyUltraLiteExisting(Workspace)
		applyUltraLiteExisting(Lighting)
		ultraLiteLog("cosmetic particles and post-processing disabled")
	end)
end

function Kaitun.Start()
	if Kaitun._internal.schedulerActive then return end
	Kaitun._internal.schedulerActive = true
	local runExclusive = Kaitun._internal.runExclusive
	task.spawn(function()
		local ok, err = pcall(function()
		Kaitun:Log("Waiting for player data to load...")
		local loaded = Kaitun._internal.waitUntilLoaded(30)
		if not loaded then
			Kaitun:Log("[ERROR] DataController never became ready — automation will not start. Check Framework.Features.Data.DataController path.")
			return
		end
		Kaitun:Log("Data loaded. Kaitun engine ready.")
		if Kaitun._internal.bindTradeNetworkEvents then
			Kaitun._internal.bindTradeNetworkEvents()
		end
		if Kaitun._internal.broadcastMainServerIdentity then
			Kaitun._internal.broadcastMainServerIdentity()
		end
		-- UltraLite is independent of every automation tick and starts only after
		-- the game's replicated data is ready.
		startUltraLite()
		if Kaitun.Config.AutoReconnect then
			setupAutoResume()
		end

		if Kaitun._internal.characterConnection then
			pcall(function() Kaitun._internal.characterConnection:Disconnect() end)
		end
		Kaitun._internal.characterConnection = LocalPlayer.CharacterAdded:Connect(function()
			Kaitun.Busy = false
		end)

		while Kaitun.Running do
			for _, feature in ipairs(CorePipeline) do
				if Kaitun.Toggles[feature.Key] and os.clock() >= feature.NextRun then
					feature.NextRun = os.clock() + feature.Interval
					local ok, err = runExclusive(feature.Key, feature.Tick)
					if not ok and err ~= "busy" then
						Kaitun:Log(("[Pipeline] %s threw: %s"):format(feature.Key, tostring(err)))
					end
				end
			end
			for _, feature in ipairs(OtherFeatures) do
				if Kaitun.Toggles[feature.Key] and os.clock() >= feature.NextRun then
					feature.NextRun = os.clock() + feature.Interval
					runExclusive(feature.Key, feature.Tick)
				end
			end
			task.wait(Kaitun.Toggles.AutoRoll and 0.15 or 1)
		end
		end)
		Kaitun._internal.schedulerActive = false
		if not ok then
			Kaitun:Log("[ERROR] scheduler: " .. tostring(err))
		end
	end)
end

Kaitun._internal.Ticks = Ticks
_G.__KaitunEngine = Kaitun
--============================================================
-- End of Part 3a. Part 3b builds the MacLib UI on top of Kaitun.
--============================================================
--============================================================

--============================================================
-- AnimeDice_Kaitun.lua  (Part 3b/3: Xyrax UI + Kaitun Engine)
--============================================================
local Kaitun = _G.__KaitunEngine
local Mods = Kaitun._internal.Mods

if Kaitun.Config.ShowUI ~= false then
-- Xyrax UI



local Players = game:GetService("Players")

local TweenService = game:GetService("TweenService")

local RunService = game:GetService("RunService")



local plr = Players.LocalPlayer



local gui = Instance.new("ScreenGui")

gui.Name = "XyraxPanel"

gui.ResetOnSpawn = false

gui.IgnoreGuiInset = true

gui.Parent = (typeof(gethui) == "function" and gethui()) or (typeof(cloneref) == "function" and cloneref(game:GetService("CoreGui"))) or plr:WaitForChild("PlayerGui")



local dim = Instance.new("Frame")

dim.Name = "Dim"

dim.Size = UDim2.new(1,0,1,0)

dim.BackgroundColor3 = Color3.new(0,0,0)

dim.BackgroundTransparency = 1

dim.BorderSizePixel = 0

dim.ZIndex = 1

dim.Parent = gui



local main = Instance.new("Frame")

main.Name = "Main"

main.Size = UDim2.new(0,480,0,210)

main.Position = UDim2.new(0.5,-240,0.5,-105)

main.BackgroundColor3 = Color3.fromRGB(16,17,22)

main.BackgroundTransparency = 0.08

main.BorderSizePixel = 0

main.ClipsDescendants = true

main.ZIndex = 2

main.Parent = gui



local corner = Instance.new("UICorner")

corner.CornerRadius = UDim.new(0,26)

corner.Parent = main



local mainScale = Instance.new("UIScale")

mainScale.Scale = 0.85

mainScale.Parent = main



local stroke = Instance.new("UIStroke")

stroke.Color = Color3.new(1,1,1)

stroke.Transparency = 0.85

stroke.Thickness = 1.6

stroke.Parent = main



local strokeGrad = Instance.new("UIGradient")

strokeGrad.Color = ColorSequence.new({

	ColorSequenceKeypoint.new(0, Color3.fromRGB(255,90,180)),

	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255,200,80)),

	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90,255,200)),

	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(140,120,255)),

	ColorSequenceKeypoint.new(1, Color3.fromRGB(255,90,180)),

})

strokeGrad.Parent = stroke



RunService.Heartbeat:Connect(function(dt)

	strokeGrad.Rotation = (strokeGrad.Rotation + dt * 40) % 360

end)



local grad = Instance.new("UIGradient")

grad.Rotation = 90

grad.Color = ColorSequence.new{

	ColorSequenceKeypoint.new(0, Color3.fromRGB(38,40,52)),

	ColorSequenceKeypoint.new(1, Color3.fromRGB(12,13,18)),

}

grad.Parent = main



local shimmer = Instance.new("Frame")

shimmer.Name = "Shimmer"

shimmer.Size = UDim2.new(0,70,0,150)

shimmer.Position = UDim2.new(0,-90,0,30)

shimmer.Rotation = 0

shimmer.BackgroundColor3 = Color3.new(1,1,1)

shimmer.BorderSizePixel = 0

shimmer.ZIndex = 6

shimmer.Parent = main



local shimmerGrad = Instance.new("UIGradient")

shimmerGrad.Transparency = NumberSequence.new({

	NumberSequenceKeypoint.new(0, 1),

	NumberSequenceKeypoint.new(0.5, 0.6),

	NumberSequenceKeypoint.new(1, 1),

})

shimmerGrad.Parent = shimmer



spawn(function()

	while gui.Parent do

		shimmer.Position = UDim2.new(0,-90,0,30)

		local tw = TweenService:Create(shimmer, TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {

			Position = UDim2.new(0,500,0,30)

		})

		tw:Play()

		tw.Completed:Wait()

		wait(2.6)

	end

end)



-- top bar (จุดสีแดงเหลืองเขียวแบบ mac)

local topBar = Instance.new("Frame")

topBar.Size = UDim2.new(1,0,0,44)

topBar.BackgroundTransparency = 1

topBar.ZIndex = 2

topBar.Parent = main



local dotColors = {

	Color3.fromRGB(255,95,87),

	Color3.fromRGB(255,189,46),

	Color3.fromRGB(39,201,63),

}



for i = 1, 3 do

	local dot = Instance.new("Frame")

	dot.Size = UDim2.new(0,11,0,11)

	dot.Position = UDim2.new(0, 18 + (i-1)*20, 0.5, -5.5)

	dot.BackgroundColor3 = dotColors[i]

	dot.BorderSizePixel = 0

	dot.ZIndex = 2

	dot.Parent = topBar



	local dc = Instance.new("UICorner")

	dc.CornerRadius = UDim.new(1,0)

	dc.Parent = dot



	spawn(function()

		wait(i * 0.2)

		TweenService:Create(dot, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {

			BackgroundTransparency = 0.45

		}):Play()

	end)

end



local title = Instance.new("TextLabel")

title.Size = UDim2.new(1,0,1,0)

title.BackgroundTransparency = 1

title.Text = "Xyrax"

title.TextColor3 = Color3.fromRGB(240,240,245)

title.Font = Enum.Font.GothamBlack

title.TextSize = 22

title.TextXAlignment = Enum.TextXAlignment.Center

title.TextYAlignment = Enum.TextYAlignment.Center

title.ZIndex = 2

title.Parent = topBar



local line1 = Instance.new("Frame")

line1.Size = UDim2.new(1,-40,0,1)

line1.Position = UDim2.new(0,20,0,44)

line1.BackgroundColor3 = Color3.new(1,1,1)

line1.BackgroundTransparency = 0.9

line1.BorderSizePixel = 0

line1.ZIndex = 2

line1.Parent = main



-- ============================

-- profile row -- avatar, name, timer

-- ============================

local profileRow = Instance.new("Frame")

profileRow.Size = UDim2.new(1,-40,0,46)

profileRow.Position = UDim2.new(0,20,0,54)

profileRow.BackgroundTransparency = 1

profileRow.ZIndex = 2

profileRow.Parent = main



local avatarGlow = Instance.new("Frame")

avatarGlow.Size = UDim2.new(0,54,0,54)

avatarGlow.Position = UDim2.new(0,-5,0.5,-27)

avatarGlow.BackgroundColor3 = Color3.fromRGB(130,150,255)

avatarGlow.BackgroundTransparency = 0.55

avatarGlow.BorderSizePixel = 0

avatarGlow.ZIndex = 1

avatarGlow.Parent = profileRow



local avatarGlowCorner = Instance.new("UICorner")

avatarGlowCorner.CornerRadius = UDim.new(1,0)

avatarGlowCorner.Parent = avatarGlow



TweenService:Create(avatarGlow, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {

	Size = UDim2.new(0,62,0,62),

	Position = UDim2.new(0,-9,0.5,-31),

	BackgroundTransparency = 0.85,

}):Play()



local avatar = Instance.new("ImageLabel")

avatar.Size = UDim2.new(0,44,0,44)

avatar.Position = UDim2.new(0,0,0.5,-22)

avatar.BackgroundColor3 = Color3.fromRGB(40,42,54)

avatar.BorderSizePixel = 0

avatar.Image = ""

avatar.ZIndex = 2

avatar.Parent = profileRow



local avCorner = Instance.new("UICorner")

avCorner.CornerRadius = UDim.new(1,0)

avCorner.Parent = avatar



local avStroke = Instance.new("UIStroke")

avStroke.Color = Color3.new(1,1,1)

avStroke.Transparency = 0.75

avStroke.Parent = avatar



spawn(function()

	local ok, img = pcall(function()

		return Players:GetUserThumbnailAsync(plr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)

	end)

	if ok then

		avatar.Image = img

	else

		warn("Xyrax: โหลด avatar ไม่ได้")

	end

end)



local nameLbl = Instance.new("TextLabel")

nameLbl.Size = UDim2.new(0,180,0,20)

nameLbl.Position = UDim2.new(0,54,0,3)

nameLbl.BackgroundTransparency = 1

nameLbl.Text = plr.DisplayName

nameLbl.TextColor3 = Color3.new(1,1,1)

nameLbl.Font = Enum.Font.GothamBold

nameLbl.TextSize = 16

nameLbl.TextXAlignment = Enum.TextXAlignment.Left

nameLbl.TextTruncate = Enum.TextTruncate.AtEnd

nameLbl.ZIndex = 2

nameLbl.Parent = profileRow



local handleLbl = Instance.new("TextLabel")

handleLbl.Size = UDim2.new(0,180,0,16)

handleLbl.Position = UDim2.new(0,54,0,23)

handleLbl.BackgroundTransparency = 1

handleLbl.Text = "@"..plr.Name

handleLbl.TextColor3 = Color3.fromRGB(150,155,168)

handleLbl.Font = Enum.Font.Gotham

handleLbl.TextSize = 12

handleLbl.TextXAlignment = Enum.TextXAlignment.Left

handleLbl.TextTruncate = Enum.TextTruncate.AtEnd

handleLbl.ZIndex = 2

handleLbl.Parent = profileRow



if plr.DisplayName == plr.Name then

	handleLbl.Visible = false

	nameLbl.Position = UDim2.new(0,54,0,0)

	nameLbl.Size = UDim2.new(0,180,1,0)

end



local sesCap = Instance.new("TextLabel")

sesCap.Size = UDim2.new(0,140,0,16)

sesCap.Position = UDim2.new(1,-140,0,3)

sesCap.BackgroundTransparency = 1

sesCap.Text = "SESSION"

sesCap.TextColor3 = Color3.fromRGB(150,155,168)

sesCap.Font = Enum.Font.GothamMedium

sesCap.TextSize = 11

sesCap.TextXAlignment = Enum.TextXAlignment.Right

sesCap.ZIndex = 2

sesCap.Parent = profileRow



local sesVal = Instance.new("TextLabel")

sesVal.Size = UDim2.new(0,140,0,22)

sesVal.Position = UDim2.new(1,-140,0,21)

sesVal.BackgroundTransparency = 1

sesVal.Text = "00:00"

sesVal.TextColor3 = Color3.new(1,1,1)

sesVal.Font = Enum.Font.GothamBold

sesVal.TextSize = 16

sesVal.TextXAlignment = Enum.TextXAlignment.Right

sesVal.ZIndex = 2

sesVal.Parent = profileRow



local startT = os.clock()

spawn(function()

	while gui.Parent do

		local t = os.clock() - startT

		local h = math.floor(t/3600)

		local m = math.floor((t%3600)/60)

		local s = math.floor(t%60)



		if h > 0 then

			sesVal.Text = string.format("%02d:%02d:%02d", h, m, s)

		else

			sesVal.Text = string.format("%02d:%02d", m, s)

		end



		wait(1)

	end

end)



local line2 = Instance.new("Frame")

line2.Size = UDim2.new(1,-40,0,1)

line2.Position = UDim2.new(0,20,0,108)

line2.BackgroundColor3 = Color3.new(1,1,1)

line2.BackgroundTransparency = 0.9

line2.BorderSizePixel = 0

line2.ZIndex = 2

line2.Parent = main



local catRig = Instance.new("Frame")

catRig.Name = "CatRig"

catRig.Size = UDim2.new(0,30,0,16)

catRig.Position = UDim2.new(0,20,0,100)

catRig.BackgroundTransparency = 1

catRig.ZIndex = 5

catRig.Parent = main



local catBody = Instance.new("Frame")

catBody.Name = "Body"

catBody.Size = UDim2.new(0,22,0,11)

catBody.Position = UDim2.new(0,4,0,4)

catBody.BackgroundColor3 = Color3.fromRGB(250,250,252)

catBody.BorderSizePixel = 0

catBody.ZIndex = 5

catBody.Parent = catRig



local catBodyCorner = Instance.new("UICorner")

catBodyCorner.CornerRadius = UDim.new(0,6)

catBodyCorner.Parent = catBody



local catHead = Instance.new("Frame")

catHead.Name = "Head"

catHead.Size = UDim2.new(0,12,0,12)

catHead.Position = UDim2.new(0,19,0,-1)

catHead.BackgroundColor3 = Color3.fromRGB(250,250,252)

catHead.BorderSizePixel = 0

catHead.ZIndex = 5

catHead.Parent = catRig



local catHeadCorner = Instance.new("UICorner")

catHeadCorner.CornerRadius = UDim.new(1,0)

catHeadCorner.Parent = catHead



local function makeEar(x)

	local ear = Instance.new("Frame")

	ear.Size = UDim2.new(0,5,0,5)

	ear.Position = UDim2.new(0,x,0,-3)

	ear.Rotation = 45

	ear.BackgroundColor3 = Color3.fromRGB(250,250,252)

	ear.BorderSizePixel = 0

	ear.ZIndex = 5

	ear.Parent = catRig

end

makeEar(20)

makeEar(27)



local eye = Instance.new("Frame")

eye.Size = UDim2.new(0,2,0,2)

eye.Position = UDim2.new(0,26,0,4)

eye.BackgroundColor3 = Color3.fromRGB(35,35,40)

eye.BorderSizePixel = 0

eye.ZIndex = 5

eye.Parent = catRig



local eyeCorner = Instance.new("UICorner")

eyeCorner.CornerRadius = UDim.new(1,0)

eyeCorner.Parent = eye



local catTail = Instance.new("Frame")

catTail.Name = "Tail"

catTail.Size = UDim2.new(0,9,0,3)

catTail.AnchorPoint = Vector2.new(1,0.5)

catTail.Position = UDim2.new(0,4,0,7)

catTail.BackgroundColor3 = Color3.fromRGB(250,250,252)

catTail.BorderSizePixel = 0

catTail.ZIndex = 5

catTail.Parent = catRig



local catTailCorner = Instance.new("UICorner")

catTailCorner.CornerRadius = UDim.new(1,0)

catTailCorner.Parent = catTail



TweenService:Create(catTail, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {

	Rotation = 25

}):Play()



spawn(function()

	local leftX = 20

	local rightX = 430 



	while gui.Parent do

		local goRight = TweenService:Create(catRig, TweenInfo.new(3.5, Enum.EasingStyle.Linear), {

			Position = UDim2.new(0, rightX, 0, 100)

		})

		goRight:Play()

		goRight.Completed:Wait()



		local goLeft = TweenService:Create(catRig, TweenInfo.new(3.5, Enum.EasingStyle.Linear), {

			Position = UDim2.new(0, leftX, 0, 100)

		})

		goLeft:Play()

		goLeft.Completed:Wait()

	end

end)



spawn(function()

	while gui.Parent do

		TweenService:Create(catBody, TweenInfo.new(0.18, Enum.EasingStyle.Sine), {Position = UDim2.new(0,4,0,2)}):Play()

		wait(0.18)

		TweenService:Create(catBody, TweenInfo.new(0.18, Enum.EasingStyle.Sine), {Position = UDim2.new(0,4,0,4)}):Play()

		wait(0.18)

	end

end)



local list = Instance.new("Frame")

list.Size = UDim2.new(1,-56,1,-126)

list.Position = UDim2.new(0,28,0,118)

list.BackgroundTransparency = 1

list.ZIndex = 2

list.Parent = main



local grid = Instance.new("UIGridLayout")

grid.CellSize = UDim2.new(0.5,-8,0,32)

grid.CellPadding = UDim2.new(0,10,0,8)

grid.SortOrder = Enum.SortOrder.LayoutOrder

grid.Parent = list



local function addStatus(txt, val, order)

	local row = Instance.new("Frame")

	row.BackgroundTransparency = 1

	row.LayoutOrder = order

	row.ZIndex = 2

	row.Parent = list



	local key = Instance.new("TextLabel")

	key.Size = UDim2.new(0.55,0,1,0)

	key.BackgroundTransparency = 1

	key.Text = txt

	key.TextColor3 = Color3.fromRGB(160,165,178)

	key.Font = Enum.Font.GothamMedium

	key.TextSize = 15

	key.TextXAlignment = Enum.TextXAlignment.Left

	key.TextYAlignment = Enum.TextYAlignment.Center

	key.ZIndex = 2

	key.Parent = row



	local v = Instance.new("TextLabel")

	v.Size = UDim2.new(0.45,0,1,0)

	v.Position = UDim2.new(0.55,0,0,0)

	v.BackgroundTransparency = 1

	v.Text = val

	v.TextColor3 = Color3.new(1,1,1)

	v.Font = Enum.Font.GothamBold

	v.TextSize = 15

	v.TextXAlignment = Enum.TextXAlignment.Right

	v.TextYAlignment = Enum.TextYAlignment.Center

	v.ZIndex = 2

	v.Parent = row



	return v

end



local rollsVal = addStatus("Rolls", "0", 1)

local gemsVal = addStatus("Gems", "0", 2)

local rerollsVal = addStatus("Rerolls", "0", 3)

local statusVal = addStatus("Status", "Idle", 4)



local function animateValue(label, newValue)

	local newNum = tonumber(newValue)

	local oldNum = tonumber(label.Text)



	if newNum and oldNum and newNum ~= oldNum then

		local steps = 14

		for i = 1, steps do

			local t = i / steps

			local shown = math.floor(oldNum + (newNum - oldNum) * t + 0.5)

			label.Text = tostring(shown)

			wait(0.02)

		end

	end



	label.Text = tostring(newValue)



	local original = label.TextColor3

	label.TextColor3 = Color3.fromRGB(255, 215, 90)

	TweenService:Create(label, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {

		TextColor3 = original

	}):Play()

end



main.BackgroundTransparency = 1

stroke.Transparency = 1

TweenService:Create(main, TweenInfo.new(0.4, Enum.EasingStyle.Quart), {BackgroundTransparency = 0.08}):Play()

TweenService:Create(stroke, TweenInfo.new(0.4), {Transparency = 0.85}):Play()

TweenService:Create(dim, TweenInfo.new(0.4, Enum.EasingStyle.Quart), {BackgroundTransparency = 0.55}):Play()

TweenService:Create(mainScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()



spawn(function()

	wait(0.6)

	local basePos = main.Position

	TweenService:Create(main, TweenInfo.new(2.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {

		Position = basePos + UDim2.new(0,0,0,7)

	}):Play()

end)



local Xyrax = {}



function Xyrax.Set(field, value)

	local label

	if field == "Level" then

		label = lvlVal

	elseif field == "Coins" then

		label = coinVal

	elseif field == "Fragments" then

		label = fragVal

	elseif field == "Status" then

		label = statusVal

	end



	if label then

		spawn(function()

			animateValue(label, value)

		end)

	end

end



function Xyrax.Show()

	main.Visible = true

	dim.Visible = true

	TweenService:Create(main, TweenInfo.new(0.3), {BackgroundTransparency = 0.08}):Play()

	TweenService:Create(dim, TweenInfo.new(0.3), {BackgroundTransparency = 0.55}):Play()

end



function Xyrax.Hide()

	TweenService:Create(main, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()

	local t = TweenService:Create(dim, TweenInfo.new(0.3), {BackgroundTransparency = 1})

	t:Play()

	t.Completed:Wait()

	main.Visible = false

	dim.Visible = false

end




local UserInputService = game:GetService("UserInputService")
local isVisible = true

local oldShow = Xyrax.Show
function Xyrax.Show()
	isVisible = true
	oldShow()
end

local oldHide = Xyrax.Hide
function Xyrax.Hide()
	isVisible = false
	oldHide()
end

UserInputService.InputBegan:Connect(function(input, gpe)
	if not gpe and input.KeyCode == Enum.KeyCode.RightControl then
		if isVisible then
			Xyrax.Hide()
		else
			Xyrax.Show()
		end
	end
end)

task.spawn(function()
	task.wait(1)
	local lastRolls, lastGems, lastRerolls, lastStatus = -1, -1, -1, ""
	while true do
		local rCount = 0
		local gCount = 0
		local trCount = 0
		local stText = "Idle"

		pcall(function()
			if Mods.DataController and Mods.DataController.Rolls then
				rCount = Mods.DataController.Rolls()
			elseif Kaitun.Stats and Kaitun.Stats.TotalRolls then
				rCount = Kaitun.Stats.TotalRolls
			end
		end)

		pcall(function()
			if type(getEntryAmount) == "function" then
				gCount = getEntryAmount("Gems")
			end
		end)

		pcall(function()
			if type(getEntryAmount) == "function" then
				trCount = getEntryAmount("Trait Reroll")
			end
		end)

		pcall(function()
			stText = Kaitun.State.CurrentStatus or Kaitun.CurrentAction or (Kaitun.Running and "Farming" or "Idle")
		end)

		if rCount ~= lastRolls then
			lastRolls = rCount
			Xyrax.Set("Rolls", rCount)
		end
		if gCount ~= lastGems then
			lastGems = gCount
			Xyrax.Set("Gems", gCount)
		end
		if trCount ~= lastRerolls then
			lastRerolls = trCount
			Xyrax.Set("Rerolls", trCount)
		end
		if stText ~= lastStatus then
			lastStatus = stText
			Xyrax.Set("Status", stText)
		end

		task.wait(0.5)
	end
end)

if Kaitun.Config.StartHidden then
	Xyrax.Hide()
end

Kaitun._internal.XyraxUI = Xyrax

return Xyrax
end -- if Kaitun.Config.ShowUI

Kaitun.Start()

--============================================================

-- AnimeDice_Kaitun.lua  (Part 4/4: Xyrax Monitor Reporter)
--
-- HARD REQUIREMENT: this section must never be able to break Kaitun. How
-- that is guaranteed, concretely:
--
--   * The ENTIRE section below is wrapped in one outer pcall. A mistake at
--     load time here (a typo, an unexpected nil) can only abort this
--     section -- it cannot unwind into anything that ran before it, and
--     Kaitun.Start() (called earlier in the file) has already spawned its
--     own independent coroutine by the time this code even begins.
--   * It runs in its own task.spawn loop, started independently of
--     CorePipeline/OtherFeatures, so the scheduler never waits on it.
--   * It never sets Kaitun.Busy and never calls runExclusive, so it cannot
--     hold or contend for the automation mutex.
--   * It never fires a game remote and never writes to Kaitun.Toggles,
--     Kaitun.Settings, Kaitun.State or Kaitun.Stats -- read-only with
--     respect to everything the automation depends on.
--   * Every read of game data (including building the Inventory/Placed
--     Units lists below) is individually pcall-wrapped, so one malformed
--     unit's attributes cannot take down the whole heartbeat.
--   * Every network call is pcall-wrapped.
--   * Explicitly fail-open on: MonitorEnabled=false, missing/malformed
--     MonitorKey, HTTP unavailable, timeout, 401, 403, 429, any 5xx, a
--     malformed JSON response, and any inventory/attribute read error --
--     every one of these logs at most once and the loop keeps sleeping;
--     Kaitun's automation continues untouched in every case.
--   * Re-running this script in the SAME Lua VM (a hot re-execute, not a
--     rejoin) does not spawn a second heartbeat loop -- see the
--     _G.__XyraxMonitorReporter guard below.
--
-- Endpoint is fixed, not configurable: the customer supplies MonitorKey
-- only.
--
-- Sent, because it is real, confirmed data (verified against the live game
-- dump, MapDump_UPD_3_Anime_Dice_113290951185459 -- every field name below
-- is a direct quote from that dump, not a guess):
--   * Roblox username/userId, client_id, current action/status, gems,
--     rebirth, a timestamp on every signed request.
--   * reroll -- EntryService.GetAmount(player, "Trait Reroll")
--     (TraitService.lua:75), the exact stackable currency Trait rerolling
--     consumes. Read the same way Gems already is:
--     Inventory["Trait Reroll"]().amount.
--   * inventory / placed_units -- see the big comment above
--     buildInventoryAndPlaced() below for exactly which fields are real and
--     where each one comes from.
--
-- Deliberately NOT sent:
--   * total_rolls / "Rolls" -- removed per instruction; Kaitun.Stats.
--     TotalRolls still exists internally (the in-game UI stats label still
--     uses it), this Reporter simply no longer forwards it.
--   * rare-drop events and free-text logs -- the customer-facing Rare Drops
--     and Logs pages were removed from the dashboard; this Reporter no
--     longer collects or sends either.
--   * unit image / asset id -- UnitConfig.lua's unit entries carry a
--     `model` (a full 3D Model/avatar rig under
--     ReplicatedStorage.Assets.Models.Units[id]), never an `.image` field.
--     EntryIcon.lua (the game's own icon-rendering code) confirms this
--     independently: for any entry without `.image` it destroys the
--     ImageLabel and renders a live ViewportFrame of the 3D model instead.
--   * a per-unit "amount"/count -- UnitConfig's own returned table sets
--     `stackable = false` (UnitConfig.lua, final return statement): each
--     rolled unit is its own separate inventory entry with its own
--     level/grade/trait, never a stacked count. Reporting a fabricated
--     "amount" would misrepresent this.
--============================================================
local __xyraxMonitorOk, __xyraxMonitorErr = pcall(function()

local Kaitun = _G.__KaitunEngine
if type(Kaitun) ~= "table" then return end

-- Stop any previous same-VM reporter before starting this one. The reporter
-- state is shared only to prevent duplicate loops; its next interval check
-- ends the replaced loop without touching Kaitun automation.
local previousReporter = _G.__XyraxMonitorReporter
if type(previousReporter) == "table" then
	previousReporter.running = false
end
local reporterState = {running = true}
_G.__XyraxMonitorReporter = reporterState

local cfg = (function()
	local ok, c = pcall(function()
		return (typeof(getgenv) == "function") and getgenv().AnimeDiceConfig or nil
	end)
	return (ok and type(c) == "table") and c or {}
end)()

if cfg.MonitorEnabled ~= true then
	reporterState.running = false
	return
end

-- Fixed endpoint -- not read from config. The only thing the customer
-- supplies is MonitorKey.
local ENDPOINT_URL = "https://dashboard.xyraxhub.xyz/api/v1/heartbeat"

-- MonitorKey is one opaque string combining the three credentials the
-- backend actually needs (key id, API key, HMAC signing secret), joined by
-- ":". None of the three can themselves contain ":" (the key id is "xm" +
-- hex; the other two are URL-safe base64 -- alphabet A-Za-z0-9-_ only), so a
-- plain split on the first two colons is unambiguous.
local RAW_MONITOR_KEY = type(cfg.MonitorKey) == "string" and cfg.MonitorKey or ""

local function parseMonitorKey(raw)
	local keyId, apiKey, signingSecret = raw:match("^([^:]+):([^:]+):(.+)$")
	if not (keyId and apiKey and signingSecret) then return nil end
	return {keyId = keyId, apiKey = apiKey, signingSecret = signingSecret}
end

local creds = RAW_MONITOR_KEY ~= "" and parseMonitorKey(RAW_MONITOR_KEY) or nil
if not creds then
	Kaitun:Log("[Monitor] disabled: MonitorKey is missing or not in the expected format")
	reporterState.running = false
	return
end
-- RAW_MONITOR_KEY is not referenced again below -- only the parsed, still-
-- secret fields inside `creds` are used, and neither this nor those are ever
-- logged (see every log line below: they name outcomes/reasons, never
-- values from `creds` or `RAW_MONITOR_KEY`).

-- Interval clamped to the 15-30s band the dashboard's online/offline
-- threshold is tuned for; a value outside it would make clients flap.
local INTERVAL = tonumber(cfg.MonitorInterval) or 20
if INTERVAL < 15 then INTERVAL = 15 elseif INTERVAL > 30 then INTERVAL = 30 end

local Players       = game:GetService("Players")
local HttpService   = game:GetService("HttpService")
local LocalPlayer   = Players.LocalPlayer
local internal      = Kaitun._internal or {}
local Mods          = internal.Mods or {}
local getEntryAmount        = internal.getEntryAmount
local getOwnedUnits         = internal.getOwnedUnits
local getUnitStorageCap     = internal.getUnitStorageCap

--========================================================
-- client_id is the current session identifier. Account identity is carried
-- separately by roblox_user_id, so the same account keeps one backend row
-- across rejoins while this value updates to the latest session. UserId is
-- retained as a prefix so two accounts owned by the same dashboard user can
-- still report from the same Roblox JobId without a session-id collision.
--
-- JobId is Roblox's unique identifier for this running server instance and
-- changes on a genuine rejoin, exactly matching the backend's session field.
--
-- game.JobId is "" (empty, never nil) specifically inside Roblox Studio,
-- never on a live server; since this Reporter only ever runs against a
-- live server through an executor, that case is handled defensively
-- rather than assumed impossible.
--========================================================

local function buildAutoClientId()
	local okUid, userId = pcall(function() return LocalPlayer.UserId end)
	local uidPart = (okUid and userId) and tostring(userId) or "unknown"

	local okJob, jobId = pcall(function() return game.JobId end)
	local instancePart
	if okJob and type(jobId) == "string" and jobId ~= "" then
		instancePart = jobId
	else
		-- Fallback remains unique to this client session when JobId is unavailable.
		local okGuid, guid = pcall(function() return HttpService:GenerateGUID(false) end)
		instancePart = (okGuid and type(guid) == "string" and guid ~= "") and guid
			or (tostring(os.clock()) .. "-" .. tostring(math.random(100000, 999999)))
	end

	return uidPart .. "-" .. instancePart
end

local CLIENT_ID = buildAutoClientId()
CLIENT_ID = tostring(CLIENT_ID):sub(1, 64):gsub("[^%w_%-%.:]", "")
if CLIENT_ID == "" then CLIENT_ID = "auto-" .. tostring(math.random(100000, 999999)) end

--========================================================
-- SHA-256 / HMAC-SHA256 (pure Luau, bit32).
-- Verified against RFC 4231 / NIST test vectors and cross-checked
-- byte-for-byte against the backend's Python implementation -- identical
-- output on the same inputs.
--========================================================
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

--========================================================
-- Real roster rarity lookup -- UnitConfig.entries[name].rarity is a plain
-- resolved string ("Common" .. "Secret I" .. "Exclusive"), set once at
-- module load (UnitConfig.lua:328). Not a function, nothing derived here.
--========================================================
local function getUnitRarity(unitName)
	local ok, rarity = pcall(function()
		local cfg2 = Mods.UnitConfig and Mods.UnitConfig.entries and Mods.UnitConfig.entries[unitName]
		return cfg2 and cfg2.rarity
	end)
	return (ok and type(rarity) == "string") and rarity or nil
end

-- entries[name].income(attrs) -- a real function, confirmed present on
-- every unit (UnitConfig.lua's createUnitEntry always sets it), returning
-- exactly the $/s value the game's own tooltip shows (EntryIcon.lua:142,
-- "$" .. NumberFormatter.FormatCompact(entryConfig.income(p1.attributes))
-- .. "/s"). Passing the unit's own attributes (level/grade/trait/mutation)
-- so the number reflects THIS specific instance, not a base/default value.
local function getUnitIncome(unitName, attrs)
	local ok, income = pcall(function()
		local cfg2 = Mods.UnitConfig and Mods.UnitConfig.entries and Mods.UnitConfig.entries[unitName]
		return cfg2 and cfg2.income and cfg2.income(attrs or {})
	end)
	return (ok and type(income) == "number") and income or nil
end

-- entries[name].chance(attrs) -- the same roster "1 in X" rarity value
-- Kaitun's own automation and the game's own tooltip use (EntryIcon.lua:83,
-- "1 in " .. NumberFormatter.FormatCompact(entryConfig.chance(p1.attributes))).
-- Genuinely absent (nil), not a bug, for the two Exclusive units (Fused
-- Zamatsu, Emelia) -- confirmed in UnitConfig.lua: their roster entry never
-- sets p2.chance, so entries[name].chance is nil for exactly those two.
local function getUnitChance(unitName, attrs)
	local ok, chance = pcall(function()
		local cfg2 = Mods.UnitConfig and Mods.UnitConfig.entries and Mods.UnitConfig.entries[unitName]
		return cfg2 and cfg2.chance and cfg2.chance(attrs or {})
	end)
	return (ok and type(chance) == "number") and chance or nil
end

--========================================================
-- Log capture removed (Logs page retired). Kaitun:Log is left completely
-- untouched here -- nothing wraps it, nothing queues its lines, nothing
-- sends them anywhere.
--========================================================

--========================================================
-- Snapshot readers. Every one is pcall-guarded and falls back to a neutral
-- value; none of them can raise into the loop below.
--========================================================
local function safeCall(fn, fallback)
	if type(fn) ~= "function" then return fallback end
	local ok, v = pcall(fn)
	if ok then return v end
	return fallback
end

local function readMoney()
	return safeCall(function()
		return Mods.DataController and Mods.DataController.Money and Mods.DataController.Money()
	end, nil)
end

local function readRebirth()
	return safeCall(function()
		return Mods.DataController and Mods.DataController.Rebirth and Mods.DataController.Rebirth()
	end, nil)
end

local function readDice()
	return safeCall(function()
		return Mods.DataController and Mods.DataController.Dice and Mods.DataController.Dice()
	end, nil)
end

--========================================================
-- Inventory ("Backpack") and Placed Units ("on Plot").
--
-- Every field below is confirmed against the live game dump, not guessed:
--
--   unit_name  -- entry.name (UnitConfig roster key)
--   rarity     -- UnitConfig.entries[name].rarity, a real resolved string
--   level      -- entry.attributes.level (UnitService.lua:323, LevelUp
--                 increments exactly this field: "Inventory[p2].attributes.
--                 level(function(p1) return (p1 or 1) + 1 end)")
--   grade      -- entry.attributes.grade (GradeService.lua:80, RollGrade
--                 sets exactly this field; keys are plain strings: "D",
--                 "C", "B", "A", "A+", "S", "S+", ... -- Grades.lua)
--   trait      -- entry.attributes.trait (TraitService.lua:96, RollTrait
--                 sets exactly this field; also a plain string key)
--   locked     -- entry.attributes.locked (UnitService.lua:347, the
--                 server's own SetLocked handler: "Inventory[i].attributes.
--                 locked(j)" where j is the boolean the player set)
--   slot_index -- (Placed Units only) the real Plot slot number a unit is
--                 standing on. DataController.Slots()[index].unitId is the
--                 exact field PlotService.lua reads/writes server-side
--                 (e.g. "Slots[i5].unitId" in EquipBest); Kaitun's own
--                 isPlaced() helper already relies on this same field.
--
-- Deliberately NOT included: a per-unit "amount" (UnitConfig sets
-- stackable = false -- each roll is its own separate entry, never a stacked
-- count; see the file-level comment above for the exact citation).
--
-- The two dashboard sections are mutually exclusive BY DISPLAY CHOICE: the
-- game's own data model still keeps a placed unit inside Inventory too (it
-- is dual-state -- placing a unit does not remove it from the inventory
-- table), so a unit currently on a slot is reported only under
-- placed_units, not duplicated into inventory as well.
--
-- Bounds: MAX_PLACED is the real, confirmed hard cap from PlotConfig.
-- GetMaxSlots() in this dump (13 slots total). MAX_INVENTORY is a payload
-- size safety limit, not a game fact -- if a player owns more than that,
-- the highest-value units (by the same roster "chance" ranking Kaitun's own
-- automation already uses) are sent first, via getOwnedUnits()'s existing
-- score-descending sort.
--========================================================
local MAX_PLACED = 32       -- real cap today is 13; generous headroom if the game adds floors
local MAX_INVENTORY = 200   -- payload safety limit, not a game constant

local function buildUnitFields(u)
	local attrs = u.attributes or {}
	return {
		unit_name = tostring(u.name):sub(1, 96),
		rarity = getUnitRarity(u.name) or "",
		level = type(attrs.level) == "number" and math.floor(attrs.level) or 1,
		grade = type(attrs.grade) == "string" and attrs.grade:sub(1, 16) or "",
		trait = type(attrs.trait) == "string" and attrs.trait:sub(1, 32) or "",
		locked = attrs.locked == true,
		-- Real $/s and roster "1 in X" for THIS instance's own attributes.
		-- chance is nil (omitted) for the two Exclusive units -- see
		-- getUnitChance's comment; never fabricated as 0 or "N/A".
		income = getUnitIncome(u.name, attrs),
		chance = getUnitChance(u.name, attrs),
	}
end

local function buildInventoryAndPlaced()
	local inventory, placed = {}, {}
	if type(getOwnedUnits) ~= "function" then return inventory, placed end
	local okUnits, units = pcall(getOwnedUnits)
	if not okUnits or type(units) ~= "table" then return inventory, placed end

	local byKey = {}
	for _, u in ipairs(units) do
		if u.key then byKey[u.key] = u end
	end

	-- Resolve which inventory keys are currently placed, from the same
	-- DataController.Slots() Kaitun's own isPlaced() reads. Deliberately
	-- mirrors isPlaced()'s own pattern exactly (pairs() over every value,
	-- no assumption about the KEY's type) -- isPlaced() has never needed to
	-- inspect the slot index itself, only the slot's .unitId field, and an
	-- earlier version of this function wrongly assumed that key had to be a
	-- plain Lua number, which silently dropped every slot if the game
	-- actually replicates it as something else (e.g. a numeric string).
	local placedKeys = {}
	local placedBySlot = {}
	local okSlots, slots = pcall(function()
		return Mods.DataController and Mods.DataController.Slots and Mods.DataController.Slots()
	end)
	if okSlots and type(slots) == "table" then
		for idx, slot in pairs(slots) do
			if type(slot) == "table" and slot.unitId then
				local u = byKey[slot.unitId]
				if u then
					placedKeys[slot.unitId] = true
					placedBySlot[#placedBySlot + 1] = {rawIdx = idx, unit = u}
				end
			end
		end
	end

	-- Order by slot number when the keys are (or convert cleanly to)
	-- numbers; falls back to string order rather than erroring if not.
	table.sort(placedBySlot, function(a, b)
		local an, bn = tonumber(a.rawIdx), tonumber(b.rawIdx)
		if an and bn then return an < bn end
		return tostring(a.rawIdx) < tostring(b.rawIdx)
	end)

	for i, entry in ipairs(placedBySlot) do
		if #placed >= MAX_PLACED then break end
		local okBuild, fields = pcall(buildUnitFields, entry.unit)
		if okBuild then
			-- Real slot number when the key is numeric (or a numeric
			-- string); never dropped for lacking a clean number.
			fields.slot_index = tonumber(entry.rawIdx) or i
			placed[#placed + 1] = fields
		end
	end

	for _, u in ipairs(units) do
		if #inventory >= MAX_INVENTORY then break end
		if not placedKeys[u.key] then
			local okBuild, fields = pcall(buildUnitFields, u)
			if okBuild then inventory[#inventory + 1] = fields end
		end
	end

	return inventory, placed
end

local function buildPayload()
	local money = readMoney()
	local rebirth = readRebirth()
	local dice = readDice()

	-- A single pcall around both list-builders: one malformed unit anywhere
	-- in Inventory/Slots must never cost the rest of the heartbeat.
	local okLists, inventory, placed = pcall(buildInventoryAndPlaced)
	if not okLists then inventory, placed = {}, {} end

	local body = {
		client_id = CLIENT_ID,
		roblox_user_id = safeCall(function() return LocalPlayer.UserId end, nil),
		roblox_username = tostring(safeCall(function() return LocalPlayer.Name end, "")):sub(1, 64),
		roblox_display_name = tostring(safeCall(function() return LocalPlayer.DisplayName end, "")):sub(1, 64),

		running = Kaitun.Running == true,
		current_action = tostring(Kaitun.CurrentAction or ""):sub(1, 64),
		core_state = tostring(Kaitun.CoreState or ""):sub(1, 64),

		-- "Trait Reroll" stackable currency -- TraitService.lua:75 confirms
		-- this exact name is what Trait rerolling consumes.
		reroll = math.floor(tonumber(type(getEntryAmount) == "function"
			and safeCall(function() return getEntryAmount("Trait Reroll") end, 0) or 0) or 0),
		gems = math.floor(tonumber(type(getEntryAmount) == "function"
			and safeCall(function() return getEntryAmount("Gems") end, 0) or 0) or 0),
		money = tonumber(money) or 0,
		rebirth = math.floor(tonumber(rebirth) or 0),
		dice_name = tostring(dice or ""):sub(1, 64),

		-- Unit Storage buff ceiling -- RollService.lua:165's own comparison
		-- (owned unit count vs this), already read internally by Kaitun's
		-- automation via getUnitStorageCap(). The owned count itself is not
		-- sent separately: it is exactly #inventory + #placed_units below.
		unit_cap = (function()
			if type(getUnitStorageCap) ~= "function" then return nil end
			local cap = safeCall(getUnitStorageCap, nil)
			return type(cap) == "number" and math.floor(cap) or nil
		end)(),

		inventory = inventory,
		placed_units = placed,
	}
	return body
end

--========================================================
-- Transport. Executors expose HTTP under several names; none is universal,
-- so all the common ones are tried and the whole thing self-disables (with
-- one log line) if none exists.
--========================================================
local httpRequest = (syn and syn.request)
	or (http and http.request)
	or http_request
	or request
	or (fluxus and fluxus.request)

if type(httpRequest) ~= "function" then
	Kaitun:Log("[Monitor] disabled: this executor exposes no HTTP request function")
	reporterState.running = false
	return
end

-- Server clock offset, learned from the signed response and applied to
-- subsequent timestamps. A client whose clock is skewed past the server's
-- signature window would otherwise never authenticate.
local clockOffset = 0

-- Classifies the outcome without ever naming or logging credential material.
-- Every one of these is fail-open: the caller only logs and backs off, it
-- never raises, never touches Kaitun state.
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
	-- GUID (executor-provided CSPRNG-backed uniqueness) mixed with the clock
	-- so two windows starting in the same tick cannot collide.
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

	local status = (okReq and type(res) == "table") and (tonumber(res.StatusCode) or 0) or 0
	if okReq and status == 200 then
		-- Resync the clock from the server's own time. A malformed JSON
		-- response here must not count as a send failure -- the heartbeat
		-- already succeeded (status 200); this is a best-effort extra.
		pcall(function()
			local decoded = HttpService:JSONDecode(res.Body)
			if type(decoded) == "table" and type(decoded.server_time) == "number" then
				clockOffset = decoded.server_time - os.time()
			end
		end)
		return true
	end
	return false, classifyFailure(status, okReq and type(res) == "table")
end

--========================================================
-- Reporter loop. Independent of the automation scheduler. Fail-open on every
-- outcome: MonitorEnabled=false and a missing/malformed MonitorKey already
-- returned above without starting this loop at all; everything from here on
-- (unreachable API, timeout, 401/403/429/5xx, malformed response, an
-- inventory read error) only logs and backs off -- Auto Farm/Roll/Tower are
-- never affected.
--========================================================
task.spawn(function()
	-- Let Kaitun.Start()'s own data-load wait finish first so the first
	-- heartbeat carries real values instead of zeros.
	task.wait(10)

	local lastFailureLogged = nil
	local backoff = 0

	Kaitun:Log(("[Monitor] reporter started (client_id=%s interval=%ds)"):format(CLIENT_ID, INTERVAL))

	while reporterState.running do
		local ok, err = pcall(function()
			if backoff > 0 then
				backoff -= 1
				return
			end

			local payload = buildPayload()
			local sent, reason = send(payload)

			if sent then
				if lastFailureLogged then
					Kaitun:Log("[Monitor] reporting recovered")
					lastFailureLogged = nil
				end
			else
				-- Log a given failure reason once, not every cycle: an
				-- extended outage (Monitor down, key revoked, rate limited)
				-- must not turn into log spam, and never affects Kaitun's
				-- own automation regardless of the reason.
				if lastFailureLogged ~= reason then
					Kaitun:Log(("[Monitor] report failed (%s) -- automation is unaffected, will keep retrying"):format(tostring(reason)))
					lastFailureLogged = reason
				end
				-- Back off to every 3rd cycle while failing.
				backoff = 2
			end
		end)

		if not ok and lastFailureLogged ~= "internal" then
			Kaitun:Log("[Monitor] reporter error: " .. tostring(err) .. " -- automation is unaffected")
			lastFailureLogged = "internal"
		end

		task.wait(INTERVAL)
	end
	reporterState.running = false
	if _G.__XyraxMonitorReporter == reporterState then
		_G.__XyraxMonitorReporter = nil
	end
end)

end) -- outer pcall

if not __xyraxMonitorOk then
	-- Deliberately does not use Kaitun:Log here -- if the reporter failed to
	-- even load, Kaitun itself may or may not still be reachable; a plain
	-- print guarantees this is visible without risking a second error.
	print("[Kaitun] [Monitor] reporter failed to load: " .. tostring(__xyraxMonitorErr) .. " -- automation is unaffected")
	if type(_G.__XyraxMonitorReporter) == "table" then
		_G.__XyraxMonitorReporter.running = false
	end
end
