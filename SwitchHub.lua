-- Switch Hub | ver. Blox Fruits
-- Pixel-accurate Switch Hub UI + Slide-down Single/Multi-Select Drawers
-- Features:
-- 1) Fixed Deterministic Level Farm (Uses GuideData.Data.QuestData & GuideModule.Data.NPCList + Kills old zombie loops)
-- 2) Fixed Melee, Sword, Gun & Fruit Hit Registration (Faces target + CFrame.lookAt + CombatController:Attack + Global.SendHitsToServer)
-- 3) Advanced Mastery Priority System (Prioritizes Mastery during Level Farm or any farm mode: lowers HP with Melee/Sword, switches to Fruit/Gun/Sword at chosen HP %, casts skills with Aimlock)
-- 4) Complete Blox Fruits Basic Functions (Boss Farm, Chest Farm, Auto Ken, Auto Buso, Race V3/V4, Infinite Energy, NoClip, WalkOnWater, Speed, Fruits Hub, Non-Fruit Shop, Server Hop, Auto Stats, Teleport & ESP)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer

--------------------------------------------------------------------------------
-- CLEANUP ANY PREVIOUS ZOMBIE LOOPS & ISOLATE STATE TABLE
--------------------------------------------------------------------------------
local genv = getgenv and getgenv() or _G

-- Silence any old tables from earlier script versions so old loops never wake up
for _, key in ipairs({"__SwitchHubBF", "__SwitchHubBF_V2"}) do
	local oldS = genv[key]
	if type(oldS) == "table" then
		oldS.runGen = (tonumber(oldS.runGen) or 0) + 100
		oldS.levelFarm = false
		oldS.masteryFarm = false
		oldS.bossFarm = false
		oldS.allBossFarm = false
		oldS.autoFirstSeaComplete = false
		oldS.autoSecondSeaComplete = false
		oldS.trevorDeliveryActive = false
		oldS.protectedTrevorFruitTool = nil
		oldS.autoStyleShop = false
		oldS.styleShopBusy = false
		oldS.autoGrabFruits = false
		oldS.autoStats = false
		oldS.autoStoreFruits = false
		oldS.autoBuyGacha = false
		oldS.autoBuyStock = false
		oldS.espEnemies = false
		oldS.espPlayers = false
		oldS.espFruits = false
		oldS.espChests = false
		oldS.doubleDamage = false
		oldS.globalAutoSkills = false
		oldS.autoSeaEvent = false
		oldS.autoMultiFindLevi = false
		oldS.leviOwnerAutoBuyBoat = false
		oldS.autoStartLeviathan = false
		oldS.autoAttackLeviathan = false
		oldS.autoMultiSegmentsLevi = false
		oldS.autoDeliverLeviHeart = false
		if oldS.activeTween then
			pcall(function() oldS.activeTween:Cancel() end)
			oldS.activeTween = nil
		end
		if type(oldS.connections) == "table" then
			for _, conn in ipairs(oldS.connections) do
				pcall(function() conn:Disconnect() end)
			end
			oldS.connections = {}
		end
	end
end

-- Create a fresh state table for this execution so no old loop can ever share references
local S = {
	runGen = math.random(100000, 999999),
	connections = {},

	-- Farming (Max Level 2800 + Secret Quests Separated)
	maxGameLevel = 2800,
	levelFarm = false,
	farmSubMode = "Niveles", -- "Niveles", "Bones", "Katakuri", "Farm Aura", "Chest Farm"
	auraDistance = 300, -- Distance For Aura (0 to 1000, default 300)
	autoQuest = true,
	bringMobs = true,
	maxBringMobs = 3, -- Strictly max 3 as requested
	autoEquip = true,
	weaponType = "Melee", -- "Melee", "Sword", "Blox Fruit", "Gun"
	farmDistance = 20, -- 20 studs hover distance as requested
	tweenSpeed = 200, -- Smooth 200 speed as requested
	useSmartPortals = true, -- Automatically use Cursed Ship / Whirlpool / Sky / Sea 3 portals
	autoFirstSeaComplete = false,
	autoSecondSeaComplete = false,
	trevorDeliveryActive = false,
	protectedTrevorFruitTool = nil,

	-- Stack Farming (Events, Raid Bosses, Elite Hunter & Fruit Teleport / Hop)
	autoFactory = false,
	autoPirateRaid = false,
	stackTpFruit = false,
	stackTpFruitHop = false,
	autoEliteHunter = false,
	hopEliteHunter = false,
	autoTouchpadHaki = false,
	autoSummonIndra = false,
	autoAttackIndra = false,
	autoSummonSoulReaper = false,
	autoAttackSoulReaper = false,
	autoSummonDoughKing = false,
	autoAttackDoughKing = false,
	autoSummonDarkbeard = false,
	autoAttackDarkbeard = false,

	stackTaskRunning = false,
	factoryAlertUntil = 0,
	factoryArrivedEmptyClock = 0,
	wasFightingFactoryCore = false,
	pirateRaidAlertUntil = 0,
	pirateRaidActiveUntil = 0,
	pirateRaidArrivedEmptyClock = 0,
	indraAlertUntil = 0,
	soulReaperAlertUntil = 0,
	doughKingAlertUntil = 0,
	darkbeardAlertUntil = 0,
	spawnedAtClock = os.clock(),
	lastFruitPickupClock = 0,

	-- Farming Others (Dojo, Berries, Chest Hop, Law Raid, Observation V2, Auto Kill Mob & Auto Boss)
	autoDojoTrainer = false,
	autoDragonHunter = false,
	autoCollectBerries = false,
	hopFindBerry = false,
	autoChestFarm = false,
	autoChestHop = false,
	chestHopLimit = 25,
	chestsCollectedCount = 0,
	autoLawRaid = false,
	autoObservationFarm = false,
	hopObservation = false,
	autoKillMob = false,
	selectedKillMobs = {},
	selectedBoss = "None",
	bossFarm = false,
	allBossFarm = false,
	hopFindBoss = false,
	othersTaskRunning = false,

	-- Advanced Mastery Priority System
	masteryPriority = false, -- When active, overrides attack logic in Level Farm / any Farm mode!
	masteryCategory = "Blox Fruit", -- "Blox Fruit", "Gun", "Sword"
	masteryStarterWeapon = "Melee", -- "Melee", "Sword"
	masteryHealthPct = 25, -- Switch to Fruit/Gun when enemy HP <= this %
	masteryAimlock = true,

	-- Advanced Setting Skills (Global Skills Controller: Melee 3, Blox Fruit 5, Gun 2, Sword 2)
	globalAutoSkills = false,
	skillAimlock = true,
	skillsInMastery = true,
	useMeleeSkills = true,
	useFruitSkills = true,
	useGunSkills = true,
	useSwordSkills = true,
	advSkills = {
		["Melee"] = {Z = true, X = true, C = true},
		["Blox Fruit"] = {Z = true, X = true, C = true, V = false, F = false},
		["Gun"] = {Z = true, X = true},
		["Sword"] = {Z = true, X = true},
	},
	advHoldSec = {
		["Melee"] = 0,      -- 0.0s toque instantáneo por defecto
		["Blox Fruit"] = 0, -- 0.0s toque instantáneo por defecto
		["Gun"] = 0,        -- 0.0s toque instantáneo por defecto
		["Sword"] = 0,      -- 0.0s toque instantáneo por defecto
	},

	-- Combat, Double Damage, Local Player & Optimization
	preferredTeam = "Pirates",
	doubleDamage = false, -- Attacks with Fruit M1 + hides Melee M1 hit directly behind Fruit M1
	autoBuso = true,
	autoKen = false,
	autoRaceV3 = false,
	autoRaceV4 = false,
	walkOnWater = false,
	noClip = false,
	infEnergy = true,
	infGeppo = false,
	customSpeedEnabled = false,
	customWalkSpeed = 45,
	fpsBoost = false,
	reduceAttackVFX = false,
	optimizeMemory = true,

	-- Fruit & Raid Tab (Devil Fruit, Raids & Dungeons)
	autoBuyGacha = false,
	autoBuyStock = false,
	selectedStockFruits = {
		["Kitsune-Kitsune"] = true,
		["Dragon-Dragon"] = true,
		["Dough-Dough"] = true,
		["Buddha-Buddha"] = true,
		["Portal-Portal"] = true,
		["Gas-Gas"] = true,
		["Yeti-Yeti"] = true,
	},
	autoStoreFruits = false,
	autoGrabFruits = false,
	selectedRaid = "Flame",
	getLowBeliFruit = false,
	autoRaid = false,
	hopServerRaid = false,
	autoAwakeFruit = false,
	raidTaskRunning = false,

	-- Sea Events Tab (Eventos Marítimos, Leviatán & Kitsune Island)
	autoSeaEvent = false,
	selectedSeaZone = "Zona 6 (Danger 6 - ???)",
	selectedBoat = "Grand Brigade",
	seaBoatSpeed = 220,
	seaSafeBoatFly = true,
	seaReturnAt10km = true,
	seaResetOnBoatLost = true,
	seaDodgeAttacks = true,
	seaClearFog = true,
	seaUseFruitM1 = false,
	seaUseM1 = false,
	selectedSeaEvents = {
		["Terrorshark"] = true,
		["Sea Beast"] = true,
		["Pirate Ship Raid"] = true,
		["Ghost Ship Raid"] = true,
		["Shark"] = true,
		["Piranha"] = true,
		["Fish Crew Member"] = true,
		["Haunted Shipwreck"] = true,
	},
	seaWeapons = {
		["Blox Fruit"] = true,
		["Melee"] = true,
		["Sword"] = false,
		["Gun"] = false,
	},
	-- Leviathan Multi-Find, Auto Start & Heart Delivery (Tiki Outpost / Hydra Island)
	selectedLeviPlayers = {},
	autoMultiFindLevi = false,
	leviOwnerAutoBuyBoat = false,
	autoStartLeviathan = false,
	autoAttackLeviathan = false,
	autoMultiSegmentsLevi = false,
	autoDeliverLeviHeart = false,
	leviHeartDestination = "Tiki Outpost",
	-- Kitsune Island & Soul / Azure Embers Section
	tpKitsuneIsland = false,
	hopNearFullMoon = false,
	autoSpawnKitsune = false,
	autoSummonSoulEmber = false,
	autoCollectSoulEmber = false,
	soulEmberLimit = 25,
	autoTradeAzureEmber = false,
	seaTaskRunning = false,

	-- Shop Tab (All Non-Fruit Items + NPC Approach & Equip for Fighting Styles)
	selectedStyle = "Water Kung Fu",
	autoStyleShop = false,
	styleShopBusy = false,
	selectedAbility = "Buso Haki (Aura)",
	selectedSword = "Bisento",
	selectedGun = "Kabucha",

	-- Server Hop & Stats
	serverHopMode = "Low Players",
	hopOnPlayerNear = false,
	autoStats = false,
	statTarget = "Melee",
	statPointsPerTick = 3,

	-- Teleport & ESP
	espEnemies = false,
	espPlayers = false,
	espFruits = false,
	espChests = false,
	selectedSea = "Second Sea (Dressrosa)",
	selectedIsland = "Middle Town",

	-- Runtime
	statusText = "Idle",
	activeTween = nil,
	lastTweenTarget = nil,
	lockedEnemy = nil,
	lastAimPos = nil,
	cachedMobSpawns = {},
}
genv.__SwitchHubBF_V2 = S
genv.__SwitchHubBF = S
local myRunGen = S.runGen

local CoreGui = game:GetService("CoreGui")
local hui = (gethui and gethui()) or CoreGui
local guiParent = CoreGui

local function cleanupOldGuis()
	for _, container in ipairs({CoreGui, hui}) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child.Name == "SwitchHub_BloxFruits" or child.Name == "SwitchHub_Loader" then
					pcall(function() child:Destroy() end)
				end
			end
		end
	end
end
cleanupOldGuis()

if STATE and STATE.onCleanup then
	STATE.onCleanup(function()
		S.runGen = -1
		S.levelFarm = false
		S.bossFarm = false
		S.allBossFarm = false
		S.autoRaid = false
		S.hopServerRaid = false
		S.autoSeaEvent = false
		S.autoMultiFindLevi = false
		S.leviOwnerAutoBuyBoat = false
		S.autoStartLeviathan = false
		S.autoAttackLeviathan = false
		S.autoMultiSegmentsLevi = false
		S.autoDeliverLeviHeart = false
		S.autoSpawnKitsune = false
		S.hopNearFullMoon = false
		S.doubleDamage = false
		S.globalAutoSkills = false
		S.autoFirstSeaComplete = false
		S.autoSecondSeaComplete = false
		S.trevorDeliveryActive = false
		S.protectedTrevorFruitTool = nil
		if S.cleanupBoatMovers then
			pcall(S.cleanupBoatMovers)
		end
		if S.activeTween then
			pcall(function() S.activeTween:Cancel() end)
			S.activeTween = nil
		end
		cleanupOldGuis()
	end)
end

local function connect(sig, fn)
	if STATE and STATE.connect then
		return STATE.connect(sig, fn)
	end
	local c = sig:Connect(fn)
	table.insert(S.connections, c)
	return c
end

local function isAlive()
	if S.runGen ~= myRunGen or genv.__SwitchHubBF_V2 ~= S then
		return false
	end
	if STATE and STATE.alive then
		return STATE.alive()
	end
	return true
end

--------------------------------------------------------------------------------
-- SMOOTH NON-BLOCKING STARTUP LOADER (NEVER COVERS TEAM SELECTION BUTTONS)
--------------------------------------------------------------------------------
do
	local loaderGui = Instance.new("ScreenGui")
	loaderGui.Name = "SwitchHub_Loader"
	loaderGui.ResetOnSpawn = false
	loaderGui.DisplayOrder = 9600
	loaderGui.IgnoreGuiInset = true
	loaderGui.Parent = guiParent

	local card = Instance.new("Frame")
	card.Size = UDim2.new(0, 360, 0, 108)
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, 46)
	card.BackgroundColor3 = Color3.fromRGB(19, 19, 23)
	card.BorderSizePixel = 0
	card.Active = false
	card.Parent = loaderGui

	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 10)
	cc.Parent = card

	local cs = Instance.new("UIStroke")
	cs.Color = Color3.fromRGB(45, 45, 54)
	cs.Thickness = 1
	cs.Parent = card

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -90, 0, 22)
	title.Position = UDim2.new(0, 16, 0, 14)
	title.BackgroundTransparency = 1
	title.Text = "⚡ Switch Hub | ver. Blox Fruits"
	title.Font = Enum.Font.GothamBold
	title.TextSize = 14
	title.TextColor3 = Color3.fromRGB(242, 242, 247)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = card

	local dotCols = {
		Color3.fromRGB(48, 209, 88),
		Color3.fromRGB(255, 214, 10),
		Color3.fromRGB(255, 69, 58),
	}
	for i, dc in ipairs(dotCols) do
		local d = Instance.new("Frame")
		d.Size = UDim2.new(0, 9, 0, 9)
		d.Position = UDim2.new(1, -16 - (4 - i) * 14, 0, 20)
		d.BackgroundColor3 = dc
		d.BorderSizePixel = 0
		d.Parent = card
		local dcCorner = Instance.new("UICorner")
		dcCorner.CornerRadius = UDim.new(1, 0)
		dcCorner.Parent = d
	end

	local stepLbl = Instance.new("TextLabel")
	stepLbl.Size = UDim2.new(1, -32, 0, 18)
	stepLbl.Position = UDim2.new(0, 16, 0, 44)
	stepLbl.BackgroundTransparency = 1
	stepLbl.Text = "Inicializando módulos de Switch Hub..."
	stepLbl.Font = Enum.Font.Gotham
	stepLbl.TextSize = 11
	stepLbl.TextColor3 = Color3.fromRGB(145, 145, 158)
	stepLbl.TextXAlignment = Enum.TextXAlignment.Left
	stepLbl.Parent = card

	local pctLbl = Instance.new("TextLabel")
	pctLbl.Size = UDim2.new(0, 48, 0, 16)
	pctLbl.Position = UDim2.new(1, -64, 0, 68)
	pctLbl.BackgroundTransparency = 1
	pctLbl.Text = "0%"
	pctLbl.Font = Enum.Font.GothamMedium
	pctLbl.TextSize = 11
	pctLbl.TextColor3 = Color3.fromRGB(59, 130, 246)
	pctLbl.TextXAlignment = Enum.TextXAlignment.Right
	pctLbl.Parent = card

	local barTrack = Instance.new("Frame")
	barTrack.Size = UDim2.new(1, -32, 0, 6)
	barTrack.Position = UDim2.new(0, 16, 0, 90)
	barTrack.BackgroundColor3 = Color3.fromRGB(36, 36, 42)
	barTrack.BorderSizePixel = 0
	barTrack.Parent = card
	local btc = Instance.new("UICorner")
	btc.CornerRadius = UDim.new(1, 0)
	btc.Parent = barTrack

	local barFill = Instance.new("Frame")
	barFill.Size = UDim2.new(0, 0, 1, 0)
	barFill.BackgroundColor3 = Color3.fromRGB(59, 130, 246)
	barFill.BorderSizePixel = 0
	barFill.Parent = barTrack
	local bfc = Instance.new("UICorner")
	bfc.CornerRadius = UDim.new(1, 0)
	bfc.Parent = barFill

	local stages = {
		{pct = 0.25, label = "1/4 Sincronizando jugador y estado de sesión...", fn = function()
			if not game:IsLoaded() then
				pcall(function() game.Loaded:Wait() end)
			end
			if LocalPlayer and LocalPlayer.Team and LocalPlayer.Team.Name ~= "Neutral" then
				LocalPlayer:WaitForChild("Data", 0.6)
			end
		end},
		{pct = 0.55, label = "2/4 Cargando Remotes y rutas del Sea...", fn = function()
			ReplicatedStorage:WaitForChild("Remotes", 1.0)
			ReplicatedStorage:WaitForChild("Modules", 1.0)
		end},
		{pct = 0.80, label = "3/4 Escaneando islas y puntos de aparición...", fn = function()
			local wo = Workspace:FindFirstChild("_WorldOrigin") or Workspace:WaitForChild("_WorldOrigin", 0.6)
			if wo then
				wo:WaitForChild("Locations", 0.4)
			end
		end},
		{pct = 1.00, label = "4/4 Preparando interfaz de Switch Hub...", fn = function() end},
	}

	local totalLoadSeconds = 1.6
	local perStageSeconds = totalLoadSeconds / #stages

	for _, st in ipairs(stages) do
		if not isAlive() then break end
		local t0 = os.clock()
		stepLbl.Text = st.label
		pctLbl.Text = tostring(math.floor(st.pct * 100 + 0.5)) .. "%"
		pcall(function()
			TweenService:Create(barFill, TweenInfo.new(perStageSeconds * 0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(st.pct, 0, 1, 0),
			}):Play()
		end)
		pcall(st.fn)
		local elapsed = os.clock() - t0
		if elapsed < perStageSeconds and isAlive() then
			task.wait(perStageSeconds - elapsed)
		end
	end

	pcall(function() loaderGui:Destroy() end)
end
if not isAlive() then return end

--------------------------------------------------------------------------------
-- BLOX FRUITS GAME MODULES & REMOTES (SAFE LAZY INIT AFTER TEAM SELECTION)
--------------------------------------------------------------------------------
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
local CommF_ = Remotes and Remotes:WaitForChild("CommF_", 10)
local CommE = Remotes and Remotes:WaitForChild("CommE", 5)

local CombatController = nil
local AimAssistModule = nil
local CombatUtil = nil
local GlobalModule = nil
local MouseModule = nil
local QuestsModule = nil
local GuideModule = nil
local GuideData = nil

local cachedRealmSeaNum = nil

S.isChooseTeamScreenOpen = function()
	if not LocalPlayer.Team or LocalPlayer.Team.Name == "Neutral" then
		return true
	end
	local pgui = LocalPlayer:FindFirstChild("PlayerGui")
	if pgui then
		for _, guiName in ipairs({"Main (minimal)", "Main"}) do
			local g = pgui:FindFirstChild(guiName)
			local ct = g and g:FindFirstChild("ChooseTeam")
			if ct and ct:IsA("GuiObject") and ct.Visible then
				return true
			end
		end
	end
	return false
end

local function getCurrentSeaNumber()
	if cachedRealmSeaNum then
		return cachedRealmSeaNum
	end
	local pid = game.PlaceId
	if pid == 4442272183 or pid == 79091703265657 then
		return 2
	elseif pid == 7449423635 or pid == 100117331123089 then
		return 3
	elseif pid == 2753915549 or pid == 85211729168715 then
		return 1
	end
	local map = Workspace:FindFirstChild("Map")
	if map then
		if map:FindFirstChild("Turtle") or map:FindFirstChild("Boat Castle") then
			return 3
		elseif map:FindFirstChild("Dressrosa") or map:FindFirstChild("GhostShip") then
			return 2
		end
	end
	local wo = Workspace:FindFirstChild("_WorldOrigin")
	local locs = wo and wo:FindFirstChild("Locations")
	if locs then
		if locs:FindFirstChild("Tiki Outpost") or locs:FindFirstChild("Castle on the Sea") then
			return 3
		elseif locs:FindFirstChild("Kingdom of Rose") or locs:FindFirstChild("Hot and Cold") then
			return 2
		end
	end
	return 1
end

--------------------------------------------------------------------------------
-- GUN & SKILL AIMBOT + ZERO BULLET SPREAD MODULE WRAPPERS (NO METAMETHOD HOOKS!)
--------------------------------------------------------------------------------
genv.__SwitchHubOrigHooks = genv.__SwitchHubOrigHooks or {}
local OrigHooks = genv.__SwitchHubOrigHooks

local function getActiveAimlockPart()
	local curS = genv.__SwitchHubBF_V2
	if not curS or not (curS.masteryAimlock or curS.skillAimlock) then
		return nil, nil
	end
	local anyActiveTask = curS.isCastingSkillAim
		or curS.globalAutoSkills
		or curS.levelFarm
		or curS.bossFarm
		or curS.allBossFarm
		or curS.autoFirstSeaComplete
		or curS.autoSecondSeaComplete
		or curS.stackTaskRunning
		or curS.othersTaskRunning
		or curS.raidTaskRunning
		or curS.seaTaskRunning
	if not anyActiveTask then
		return nil, nil
	end

	local part = curS.lastAimPart
	local model = curS.lastAimEnemy
	if part and part.Parent and model and model.Parent then
		local eHum = model:FindFirstChildOfClass("Humanoid")
		local hVal = model:FindFirstChild("Health")
		local alive = (eHum and eHum.Health > 0)
			or (hVal and hVal:IsA("ValueBase") and tonumber(hVal.Value) ~= nil and tonumber(hVal.Value) > 0)
		if alive then
			return part, model
		end
	end

	-- Fallback auto-acquire nearest alive NPC / Sea Event within 160 studs when Auto Skills is active
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp and (curS.isCastingSkillAim or curS.globalAutoSkills) then
		local bestPart, bestModel, bestDist = nil, nil, 160
		for _, folder in ipairs({Workspace:FindFirstChild("Enemies"), Workspace:FindFirstChild("SeaBeasts"), Workspace:FindFirstChild("SeaEvents")}) do
			if folder then
				for _, m in ipairs(folder:GetChildren()) do
					if m:IsA("Model") then
						local eHum = m:FindFirstChildOfClass("Humanoid")
						local hVal = m:FindFirstChild("Health")
						local alive = (eHum and eHum.Health > 0)
							or (hVal and hVal:IsA("ValueBase") and tonumber(hVal.Value) ~= nil and tonumber(hVal.Value) > 0)
						local p = m:FindFirstChild("HumanoidRootPart")
							or m:FindFirstChild("RootPart")
							or m:FindFirstChild("Engine")
							or m:FindFirstChild("UpperTorso")
							or m:FindFirstChildWhichIsA("BasePart")
						if alive and p then
							local d = (p.Position - hrp.Position).Magnitude
							if d < bestDist then
								bestDist = d
								bestPart = p
								bestModel = m
							end
						end
					end
				end
			end
		end
		if bestPart and bestModel then
			curS.lastAimEnemy = bestModel
			curS.lastAimPart = bestPart
			curS.lastAimPos = bestPart.Position
			return bestPart, bestModel
		end
	end

	return nil, nil
end
genv.__SwitchHubGetAimPart = getActiveAimlockPart

local function updateMasteryAimTarget(enemyModel)
	if not enemyModel then
		S.lastAimEnemy = nil
		S.lastAimPart = nil
		return
	end
	if not MouseModule and S.ensureCombatModulesReady then
		S.ensureCombatModulesReady(false)
	end
	local targetPart = enemyModel:FindFirstChild("HumanoidRootPart")
		or enemyModel:FindFirstChild("RootPart")
		or enemyModel:FindFirstChild("Engine")
		or enemyModel:FindFirstChild("Body")
		or enemyModel:FindFirstChild("UpperTorso")
		or enemyModel:FindFirstChild("Head")
		or enemyModel.PrimaryPart
		or enemyModel:FindFirstChildWhichIsA("BasePart")
	if not targetPart then return end

	S.lastAimEnemy = enemyModel
	S.lastAimPart = targetPart
	S.lastAimPos = targetPart.Position

	-- 1) Update ReplicatedStorage.Mouse so Z/X/C/V/F skills via MovesetClientRunner aim dead-center at the NPC
	if MouseModule then
		pcall(function()
			local cam = Workspace.CurrentCamera
			local char = LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local originPos = (hrp and hrp.Position) or (cam and cam.CFrame.Position) or (S.lastAimPos + Vector3.new(0, 20, 0))
			local dir = (S.lastAimPos - originPos)
			local unitDir = (dir.Magnitude > 0.001) and dir.Unit or Vector3.new(0, -1, 0)
			MouseModule.Hit = CFrame.lookAt(S.lastAimPos, S.lastAimPos + unitDir)
			MouseModule.Target = targetPart
			MouseModule.Origin = CFrame.lookAt(originPos, S.lastAimPos)
			MouseModule.UnitRay = Ray.new(originPos, unitDir)
		end)
	end

	-- 2) Update equipped tool's MousePos Vector3Value if present
	local char = LocalPlayer.Character
	if char then
		for _, item in ipairs(char:GetChildren()) do
			if item:IsA("Tool") then
				local mp = item:FindFirstChild("MousePos")
				if mp and mp:IsA("Vector3Value") then
					mp.Value = S.lastAimPos
				end
			end
		end
	end
end

do
	local function applyModuleAimHooks()
		-- Hook 1: AimAssist.getTargetInfo -> Makes CombatController & modern Skills lock directly onto the NPC part
		if AimAssistModule and type(AimAssistModule.getTargetInfo) == "function" then
			if not OrigHooks.getTargetInfo then
				OrigHooks.getTargetInfo = AimAssistModule.getTargetInfo
			end
			AimAssistModule.getTargetInfo = function(...)
				local getter = genv.__SwitchHubGetAimPart
				local part, model = getter and getter()
				if part and model then
					local char = LocalPlayer.Character
					local hrp = char and char:FindFirstChild("HumanoidRootPart")
					local dist = hrp and (part.Position - hrp.Position).Magnitude or 20
					return {
						Part = part,
						Position = part.Position,
						Model = model,
						Humanoid = model:FindFirstChildOfClass("Humanoid"),
						Distance = dist,
					}
				end
				return OrigHooks.getTargetInfo(...)
			end
		end

		-- Hook 2: CombatUtil.GetTargetPosition -> Guarantees Gun & Skill raycast target position is exact center of NPC
		if CombatUtil and type(CombatUtil.GetTargetPosition) == "function" then
			if not OrigHooks.GetTargetPosition then
				OrigHooks.GetTargetPosition = CombatUtil.GetTargetPosition
			end
			CombatUtil.GetTargetPosition = function(self, originPos, aimPos, range)
				local getter = genv.__SwitchHubGetAimPart
				local part = getter and getter()
				if part then
					return part.Position
				end
				return OrigHooks.GetTargetPosition(self, originPos, aimPos, range)
			end
		end

		-- Hook 3: CombatUtil.CreateShootAngles -> Eliminates random bullet spread (±6° deviation) so 100% of shots hit
		if CombatUtil and type(CombatUtil.CreateShootAngles) == "function" then
			if not OrigHooks.CreateShootAngles then
				OrigHooks.CreateShootAngles = CombatUtil.CreateShootAngles
			end
			CombatUtil.CreateShootAngles = function(self, shootData)
				local getter = genv.__SwitchHubGetAimPart
				local part = getter and getter()
				if part then
					local count = (type(shootData) == "table" and tonumber(shootData.BulletSpreadCount)) or 1
					local res = {}
					for i = 1, math.max(1, count) do
						res[i] = {Angle = CFrame.Angles(0, 0, 0)}
					end
					return res
				end
				return OrigHooks.CreateShootAngles(self, shootData)
			end
		end

		-- Hook 4: GlobalModule.updateMouseWrapper -> Prevents screen cursor from overwriting MouseModule.Hit during Aimlock
		if GlobalModule and type(GlobalModule.updateMouseWrapper) == "function" then
			if not OrigHooks.updateMouseWrapper then
				OrigHooks.updateMouseWrapper = GlobalModule.updateMouseWrapper
			end
			GlobalModule.updateMouseWrapper = function(...)
				local ret = OrigHooks.updateMouseWrapper(...)
				local getter = genv.__SwitchHubGetAimPart
				local part = getter and getter()
				if part and MouseModule then
					pcall(function()
						local char = LocalPlayer.Character
						local hrp = char and char:FindFirstChild("HumanoidRootPart")
						local originPos = (hrp and hrp.Position) or (part.Position + Vector3.new(0, 20, 0))
						local dir = (part.Position - originPos)
						local unitDir = (dir.Magnitude > 0.001) and dir.Unit or Vector3.new(0, -1, 0)
						MouseModule.Hit = CFrame.lookAt(part.Position, part.Position + unitDir)
						MouseModule.Target = part
						MouseModule.Origin = CFrame.lookAt(originPos, part.Position)
						MouseModule.UnitRay = Ray.new(originPos, unitDir)
					end)
				end
				return ret
			end
		end
	end

	S.ensureCombatModulesReady = function(forceDataModules)
		if not QuestsModule then
			pcall(function()
				local q = ReplicatedStorage:FindFirstChild("Quests")
				if q then QuestsModule = require(q) end
			end)
		end
		if not GuideModule then
			pcall(function()
				local gm = ReplicatedStorage:FindFirstChild("GuideModule")
				if gm then GuideModule = require(gm) end
			end)
		end
		if not GuideData then
			pcall(function()
				local gm = ReplicatedStorage:FindFirstChild("GuideModule")
				local gd = gm and gm:FindFirstChild("GuideData")
				if gd then GuideData = require(gd) end
			end)
		end

		-- Never require character/HUD controllers while the player is still on the Choose Team screen!
		if S.isChooseTeamScreenOpen() or not LocalPlayer.Character then
			return forceDataModules == true
		end

		local loadedNew = false
		if not CombatController then
			pcall(function()
				local ctrl = ReplicatedStorage:FindFirstChild("Controllers")
				local cc = ctrl and ctrl:FindFirstChild("CombatController")
				if cc then CombatController = require(cc); loadedNew = true end
			end)
		end
		if not AimAssistModule then
			pcall(function()
				local ctrl = ReplicatedStorage:FindFirstChild("Controllers")
				local cc = ctrl and ctrl:FindFirstChild("CombatController")
				local aa = cc and cc:FindFirstChild("AimAssist")
				if aa then AimAssistModule = require(aa); loadedNew = true end
			end)
		end
		if not CombatUtil then
			pcall(function()
				local mods = ReplicatedStorage:FindFirstChild("Modules")
				local cu = mods and mods:FindFirstChild("CombatUtil")
				if cu then CombatUtil = require(cu); loadedNew = true end
			end)
		end
		if not GlobalModule then
			pcall(function()
				local gl = ReplicatedStorage:FindFirstChild("Global")
				if gl then GlobalModule = require(gl); loadedNew = true end
			end)
		end
		if not MouseModule then
			pcall(function()
				local ms = ReplicatedStorage:FindFirstChild("Mouse")
				if ms then MouseModule = require(ms); loadedNew = true end
			end)
		end
		if loadedNew then
			applyModuleAimHooks()
		end
		return true
	end

	-- Background initializer: waits until player has selected Pirates/Marines and spawned before requiring controllers
	task.spawn(function()
		local wasWaitingForTeam = S.isChooseTeamScreenOpen() or (LocalPlayer.Character == nil)
		while isAlive() and (S.isChooseTeamScreenOpen() or not (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart"))) do
			task.wait(0.35)
		end
		if not isAlive() then return end
		if wasWaitingForTeam then
			task.wait(0.8) -- Let Blox Fruits' own LocalScripts finish initializing controllers first
		end
		S.ensureCombatModulesReady(true)
		pcall(function()
			local utilFolder = ReplicatedStorage:FindFirstChild("Util")
			local realmMod = utilFolder and utilFolder:FindFirstChild("Realm")
			if realmMod then
				local Realm = require(realmMod)
				if type(Realm.getCurrentSeaAsync) == "function" then
					local seaStr = tostring(Realm.getCurrentSeaAsync() or "")
					if seaStr:find("3") or seaStr:lower():find("third") then
						cachedRealmSeaNum = 3
					elseif seaStr:find("2") or seaStr:lower():find("second") then
						cachedRealmSeaNum = 2
					elseif seaStr:find("1") or seaStr:lower():find("first") then
						cachedRealmSeaNum = 1
					end
				end
			end
		end)
	end)
end

local onStatusChanged = nil
local function setStatus(msg)
	S.statusText = msg
	if onStatusChanged then
		pcall(onStatusChanged, msg)
	end
end

local function ensureTeamSelected()
	if not LocalPlayer.Team or LocalPlayer.Team.Name == "Neutral" then
		if CommF_ then
			local wanted = (S.preferredTeam == "Marines") and "Marines" or "Pirates"
			pcall(function()
				CommF_:InvokeServer("SetTeam", wanted)
			end)
		end
	end
	if S.ensureCombatModulesReady then
		S.ensureCombatModulesReady(true)
	end
end

--------------------------------------------------------------------------------
-- WEAPON EQUIP, HAKI & RELIABLE MELEE / SWORD / GUN / FRUIT HIT REGISTRATION
--------------------------------------------------------------------------------
local function getToolByWeaponType(wType)
	local char = LocalPlayer.Character
	local backpack = LocalPlayer:FindFirstChild("Backpack")
	local targetTip = (wType == "Blox Fruit") and "Blox Fruit" or wType

	local function matchesTool(item)
		if not item:IsA("Tool") then return false end
		if item.ToolTip == targetTip then return true end
		local wAttr = item:GetAttribute("WeaponType")
		if wAttr then
			if wType == "Blox Fruit" and (wAttr == "Demon Fruit" or wAttr == "Blox Fruit") then
				return true
			elseif wAttr:lower() == wType:lower() then
				return true
			end
		end
		return false
	end

	if char then
		for _, item in ipairs(char:GetChildren()) do
			if matchesTool(item) then
				return item
			end
		end
	end
	if backpack then
		for _, item in ipairs(backpack:GetChildren()) do
			if matchesTool(item) then
				return item
			end
		end
		-- Fallback if chosen category is missing: pick any combat tool
		for _, item in ipairs(backpack:GetChildren()) do
			if item:IsA("Tool") and (item.ToolTip == "Melee" or item.ToolTip == "Sword" or item.ToolTip == "Blox Fruit" or item.ToolTip == "Gun") then
				return item
			end
		end
	end
	return nil
end

local lastEquipAttempt = 0
local function equipWeaponType(wType)
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return nil end

	local tool = getToolByWeaponType(wType or S.weaponType)
	if tool then
		if tool.Parent ~= char and (os.clock() - lastEquipAttempt > 0.25) then
			lastEquipAttempt = os.clock()
			pcall(function()
				hum:EquipTool(tool)
			end)
		end
		-- Update MousePos inside the tool for Aimlock on Gun & Blox Fruit skills
		if S.lastAimPos then
			local mp = tool:FindFirstChild("MousePos")
			if mp and mp:IsA("Vector3Value") then
				mp.Value = S.lastAimPos
			end
		end
	end
	return tool
end

local lastBusoClock = 0
local function ensureBusoHaki()
	if not S.autoBuso then return end
	local char = LocalPlayer.Character
	if char and not char:FindFirstChild("HasBuso") and CommF_ and (os.clock() - lastBusoClock > 2.5) then
		lastBusoClock = os.clock()
		task.spawn(function()
			pcall(function()
				CommF_:InvokeServer("Buso")
			end)
		end)
	end
end

-- Fake InputObject so CombatController:Attack(tool, fakeInput) works for Guns too
local FakeAttackInput = {
	UserInputType = Enum.UserInputType.MouseButton1,
	UserInputState = Enum.UserInputState.Begin,
	Position = Vector3.zero,
	GetPropertyChangedSignal = function()
		return {
			Connect = function()
				return {Disconnect = function() end}
			end,
		}
	end,
}

-- Collects nearby alive enemies' hit parts (including multi-segment Leviathan sweeps) so M1 & AoE hits register 100% damage
local function getEnemyHitTargets(primaryEnemy)
	local enemiesFolder = Workspace:FindFirstChild("Enemies")

	local function getHitPart(model)
		return model:FindFirstChild("UpperTorso")
			or model:FindFirstChild("Head")
			or model:FindFirstChild("RightUpperArm")
			or model:FindFirstChild("HumanoidRootPart")
			or model:FindFirstChild("RootPart")
			or model:FindFirstChild("Leviathan body")
			or model:FindFirstChild("Engine")
			or model:FindFirstChild("Body")
			or model.PrimaryPart
			or model:FindFirstChildWhichIsA("BasePart")
	end

	local primaryPart = primaryEnemy and getHitPart(primaryEnemy)
	local extraTargets = {}

	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local centerPos = (primaryPart and primaryPart.Position) or (hrp and hrp.Position)
	if not centerPos then return primaryPart, extraTargets end

	local isLeviMulti = S.autoMultiSegmentsLevi and primaryEnemy and tostring(primaryEnemy.Name):find("Leviathan") ~= nil
	local maxExtra = isLeviMulti and 8 or 2
	local maxRange = isLeviMulti and 250 or 40
	local folders = isLeviMulti
		and {enemiesFolder, Workspace:FindFirstChild("SeaBeasts"), Workspace:FindFirstChild("SeaEvents")}
		or {enemiesFolder}

	for _, folder in ipairs(folders) do
		if folder then
			for _, en in ipairs(folder:GetChildren()) do
				if en ~= primaryEnemy and en:IsA("Model") and #extraTargets < maxExtra then
					if (not isLeviMulti) or tostring(en.Name):find("Leviathan") then
						local eHum = en:FindFirstChildOfClass("Humanoid")
						local hVal = en:FindFirstChild("Health")
						local alive = (eHum and eHum.Health > 0)
							or (hVal and hVal:IsA("ValueBase") and tonumber(hVal.Value) ~= nil and tonumber(hVal.Value) > 0)
						local part = getHitPart(en)
						if alive and part and (part.Position - centerPos).Magnitude <= maxRange then
							if not primaryPart then
								primaryPart = part
							else
								table.insert(extraTargets, {en, part})
							end
						end
					end
				end
			end
		end
	end

	return primaryPart, extraTargets
end

local lastNormalSwing = 0
local fruitM1Combo = 1
local performNormalAttack
local triggerSelectedMasterySkills

do
	local weavingDoubleDamage = false
	local isCastingGlobalSkill = false
	local cachedRegisterAttackRE = nil
	local lastGlobalSkillClock = 0
	local nextAllowedSkillClock = 0
	local rotateWeaponIdx = 1
	local perCategorySkillIdx = {
		["Melee"] = 1,
		["Blox Fruit"] = 1,
		["Gun"] = 1,
		["Sword"] = 1,
	}
	local skillReadyClock = {}

	local VALID_SKILLS_BY_CATEGORY = {
		["Melee"] = {"Z", "X", "C"},
		["Blox Fruit"] = {"Z", "X", "C", "V", "F"},
		["Gun"] = {"Z", "X"},
		["Sword"] = {"Z", "X"},
	}

	local SKILL_BASE_COOLDOWN = {
		Z = 3.6,
		X = 4.8,
		C = 6.2,
		V = 9.5,
		F = 4.5,
	}

	local CATEGORY_ORDER = {"Melee", "Blox Fruit", "Gun", "Sword"}

	local function getRegisterAttackRemote()
		if cachedRegisterAttackRE and cachedRegisterAttackRE.Parent then
			return cachedRegisterAttackRE
		end
		local m = ReplicatedStorage:FindFirstChild("Modules")
		local net = m and m:FindFirstChild("Net")
		cachedRegisterAttackRE = net and net:FindFirstChild("RE/RegisterAttack")
		return cachedRegisterAttackRE
	end

	local function isToolBloxFruit(tool)
		if not tool or not tool:IsA("Tool") then return false end
		return (tool.ToolTip == "Blox Fruit")
			or (tool:GetAttribute("WeaponType") == "Demon Fruit")
	end

	local function findNearestManualTarget(maxDist)
		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then return nil end
		local bestModel = nil
		local bestDist = maxDist or 55

		for _, folder in ipairs({Workspace:FindFirstChild("Enemies"), Workspace:FindFirstChild("SeaBeasts"), Workspace:FindFirstChild("SeaEvents")}) do
			if folder then
				for _, m in ipairs(folder:GetChildren()) do
					if m:IsA("Model") then
						local eHum = m:FindFirstChildOfClass("Humanoid")
						local hVal = m:FindFirstChild("Health")
						local alive = (eHum and eHum.Health > 0)
							or (hVal and hVal:IsA("ValueBase") and tonumber(hVal.Value) ~= nil and tonumber(hVal.Value) > 0)
						local part = m:FindFirstChild("HumanoidRootPart")
							or m:FindFirstChild("RootPart")
							or m:FindFirstChild("Engine")
							or m:FindFirstChildWhichIsA("BasePart")
						if alive and part then
							local d = (part.Position - hrp.Position).Magnitude
							if d < bestDist then
								bestDist = d
								bestModel = m
							end
						end
					end
				end
			end
		end
		return bestModel
	end

	-- DOBLE DAÑO: Executes a hidden Melee M1 hit tucked right inside the Blox Fruit M1 recovery window
	local function weaveHiddenMeleeBehindFruitM1(char, fruitTool, primaryEnemy)
		if not S.doubleDamage or weavingDoubleDamage or isCastingGlobalSkill then return end
		if not CombatController and S.ensureCombatModulesReady then
			S.ensureCombatModulesReady(false)
		end
		local meleeTool = getToolByWeaponType("Melee")
		if not meleeTool or meleeTool == fruitTool then return end

		weavingDoubleDamage = true
		task.delay(0.055, function()
			pcall(function()
				if not isAlive() or not S.doubleDamage or isCastingGlobalSkill or not char or not char.Parent then
					weavingDoubleDamage = false
					return
				end
				local hum = char:FindFirstChildOfClass("Humanoid")
				if not hum or hum.Health <= 0 then
					weavingDoubleDamage = false
					return
				end

				if GlobalModule then
					GlobalModule.tapCooldown = 0
				end

				-- Micro-equip Melee right behind the Fruit M1 animation
				if meleeTool.Parent ~= char then
					hum:EquipTool(meleeTool)
				end

				local regRE = getRegisterAttackRemote()
				if regRE then
					pcall(function() regRE:FireServer(0) end)
				end
				if CombatController then
					pcall(function() CombatController:Attack(meleeTool, FakeAttackInput) end)
				end
				if GlobalModule and GlobalModule.SendHitsToServer then
					local primaryPart, extraTargets = getEnemyHitTargets(primaryEnemy)
					if primaryPart then
						GlobalModule.SendHitsToServer(primaryPart, extraTargets)
					end
				end

				-- Snap immediately back to the Blox Fruit so the Melee strike stays hidden behind Fruit M1
				task.delay(0.06, function()
					pcall(function()
						if S.doubleDamage and not isCastingGlobalSkill and fruitTool and fruitTool.Parent and hum and hum.Health > 0 and fruitTool.Parent ~= char then
							hum:EquipTool(fruitTool)
						end
					end)
					weavingDoubleDamage = false
				end)
			end)
		end)
	end

	-- Support manual MouseButton1 / Touch clicks when holding a Blox Fruit with Doble Daño active!
	connect(UserInputService.InputBegan, function(input, gpe)
		if gpe or not S.doubleDamage or weavingDoubleDamage or isCastingGlobalSkill then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if os.clock() - lastNormalSwing < 0.18 then
			return -- Automated performNormalAttack already handled this swing
		end
		local char = LocalPlayer.Character
		local held = char and char:FindFirstChildOfClass("Tool")
		if held and isToolBloxFruit(held) then
			local target = S.lastAimEnemy or findNearestManualTarget(55)
			weaveHiddenMeleeBehindFruitM1(char, held, target)
		end
	end)

	local function isCategorySkillsEnabled(cat)
		if cat == "Melee" then return S.useMeleeSkills == true
		elseif cat == "Blox Fruit" then return S.useFruitSkills == true
		elseif cat == "Gun" then return S.useGunSkills == true
		elseif cat == "Sword" then return S.useSwordSkills == true
		end
		return false
	end

	local function getHoldTimeForCategory(cat)
		local raw = S.advHoldSec and tonumber(S.advHoldSec[cat])
		if raw == nil then
			return 0
		end
		return math.clamp(raw, 0, 3.0)
	end

	local function getEnabledKeysForCategory(cat)
		local validList = VALID_SKILLS_BY_CATEGORY[cat]
		local cfg = S.advSkills and S.advSkills[cat]
		local out = {}
		if not validList or not cfg or not isCategorySkillsEnabled(cat) then
			return out
		end
		for _, k in ipairs(validList) do
			if cfg[k] then
				table.insert(out, k)
			end
		end
		return out
	end

	local function pickReadyKeyFromCategory(cat, keys, now)
		if #keys == 0 then return nil, false end
		local startIdx = perCategorySkillIdx[cat] or 1
		if startIdx > #keys then startIdx = 1 end

		for step = 0, #keys - 1 do
			local idx = ((startIdx - 1 + step) % #keys) + 1
			local k = keys[idx]
			local cdKey = cat .. "_" .. k
			if now >= (skillReadyClock[cdKey] or 0) then
				local nextIdx = (idx % #keys) + 1
				perCategorySkillIdx[cat] = nextIdx
				local wrappedCombo = (idx == #keys)
				return k, wrappedCombo
			end
		end
		return nil, true
	end

	-- UNIFIED GLOBAL ADVANCED SETTING SKILLS CONTROLLER (AUTO-ROTATES WEAPONS + INTEGRATED SEA EVENTS + PER-WEAPON HOLD)
	S.castGlobalSkills = function(preferredCategory, targetEnemy, targetPartOverride, contextMode)
		local mode = contextMode or "general"
		if mode == "mastery" then
			if not (S.globalAutoSkills or S.skillsInMastery) then return false end
		elseif mode == "sea" then
			-- Integrated directly in Sea Events & Leviathan (uses enabled weapon skill sections automatically)
			if not (S.globalAutoSkills or S.autoSeaEvent or S.autoMultiFindLevi or S.leviOwnerAutoBuyBoat or S.autoStartLeviathan or S.autoAttackLeviathan or S.autoMultiSegmentsLevi or S.seaTaskRunning) then return false end
		else
			if not S.globalAutoSkills then return false end
		end

		if weavingDoubleDamage or isCastingGlobalSkill then return false end
		if not MouseModule and S.ensureCombatModulesReady then
			S.ensureCombatModulesReady(false)
		end
		local now = os.clock()
		if now < nextAllowedSkillClock or (now - lastGlobalSkillClock < 0.45) then
			return false
		end

		local chosenCat = nil
		local keyName = nil

		if mode == "mastery" then
			-- In Mastery finisher mode, strictly cast skills from the chosen Mastery weapon so XP is not stolen
			local mCat = preferredCategory or S.masteryCategory or "Blox Fruit"
			local mKeys = getEnabledKeysForCategory(mCat)
			if #mKeys > 0 and getToolByWeaponType(mCat) then
				local pickedKey = pickReadyKeyFromCategory(mCat, mKeys, now)
				if pickedKey then
					chosenCat = mCat
					keyName = pickedKey
				end
			end
		else
			-- Conscious multi-weapon skill rotation across Melee, Blox Fruit, Gun & Sword!
			local rotCats = {}
			for _, cName in ipairs(CATEGORY_ORDER) do
				local allowInMode = true
				if mode == "sea" and S.seaWeapons then
					-- Prefer weapons selected for Sea Events if any of them have skills enabled
					allowInMode = (S.seaWeapons[cName] == true)
				end
				if allowInMode then
					local kList = getEnabledKeysForCategory(cName)
					if #kList > 0 and getToolByWeaponType(cName) then
						table.insert(rotCats, {cat = cName, keys = kList})
					end
				end
			end
			-- Fallback in Sea Events: if user unchecked seaWeapons for a skill-enabled weapon, still rotate available skill weapons
			if #rotCats == 0 and mode == "sea" then
				for _, cName in ipairs(CATEGORY_ORDER) do
					local kList = getEnabledKeysForCategory(cName)
					if #kList > 0 and getToolByWeaponType(cName) then
						table.insert(rotCats, {cat = cName, keys = kList})
					end
				end
			end

			if #rotCats > 0 then
				if rotateWeaponIdx > #rotCats then
					rotateWeaponIdx = 1
				end
				for offset = 0, #rotCats - 1 do
					local cIdx = ((rotateWeaponIdx - 1 + offset) % #rotCats) + 1
					local entry = rotCats[cIdx]
					local pickedKey, finishedWeaponCombo = pickReadyKeyFromCategory(entry.cat, entry.keys, now)
					if pickedKey then
						chosenCat = entry.cat
						keyName = pickedKey
						-- Consciously rotate to the next weapon once this weapon's selected skills combo finishes!
						if finishedWeaponCombo then
							rotateWeaponIdx = (cIdx % #rotCats) + 1
						else
							rotateWeaponIdx = cIdx
						end
						break
					end
				end
			end
		end

		if not chosenCat or not keyName then
			return false
		end

		local kc = Enum.KeyCode[keyName]
		if not kc then return false end

		local holdTime = getHoldTimeForCategory(chosenCat)
		local baseCd = SKILL_BASE_COOLDOWN[keyName] or 4.5
		skillReadyClock[chosenCat .. "_" .. keyName] = now + holdTime + baseCd
		lastGlobalSkillClock = now
		nextAllowedSkillClock = now + holdTime + 0.30
		isCastingGlobalSkill = true
		S.isCastingSkillAim = true

		local returnWeapon = nil
		if mode == "general" then
			returnWeapon = (S.doubleDamage and getToolByWeaponType("Blox Fruit")) and "Blox Fruit" or S.weaponType
		end

		task.spawn(function()
			local savedAutoRotate = nil
			local humRef = nil
			pcall(function()
				local char = LocalPlayer.Character
				if not char then return end
				local hum = char:FindFirstChildOfClass("Humanoid")
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if not hum or hum.Health <= 0 or not hrp then return end
				humRef = hum

				-- Acquire target enemy if none was passed in (e.g. standalone Auto Skills Global)
				local activeEnemy = targetEnemy or S.lastAimEnemy or findNearestManualTarget(160)

				local eqTool = getToolByWeaponType(chosenCat)
				if not eqTool then return end

				local function lockAimNow()
					local aimPart = nil
					if targetPartOverride and targetPartOverride.Parent then
						aimPart = targetPartOverride
						S.lastAimEnemy = activeEnemy
						S.lastAimPart = aimPart
						S.lastAimPos = aimPart.Position
					else
						if not activeEnemy or not activeEnemy.Parent then
							activeEnemy = findNearestManualTarget(160)
						end
						if activeEnemy then
							updateMasteryAimTarget(activeEnemy)
							aimPart = S.lastAimPart
						end
					end

					if (S.skillAimlock or S.masteryAimlock) and aimPart and aimPart.Parent and hrp and hrp.Parent then
						local aimPos = aimPart.Position
						S.lastAimPos = aimPos
						local delta = (aimPos - hrp.Position)
						local unitDir = (delta.Magnitude > 0.001) and delta.Unit or Vector3.new(0, -1, 0)

						if MouseModule then
							pcall(function()
								MouseModule.Hit = CFrame.lookAt(aimPos, aimPos + unitDir)
								MouseModule.Target = aimPart
								MouseModule.Origin = CFrame.lookAt(hrp.Position, aimPos)
								MouseModule.UnitRay = Ray.new(hrp.Position, unitDir)
							end)
						end
						if eqTool and eqTool.Parent then
							local mp = eqTool:FindFirstChild("MousePos")
							if mp and mp:IsA("Vector3Value") then
								mp.Value = aimPos
							end
						end
						-- Orient character directly toward target so Melee, Sword, Gun & Fruit directional skills hit dead-center!
						if delta.Magnitude > 1.5 and not hum.SeatPart then
							hrp.CFrame = CFrame.lookAt(hrp.Position, aimPos)
						end
					end
				end

				-- Force-equip chosen weapon WITHOUT 0.25s throttle skip, and give newly swapped tool 0.07s to bind Z/X/C/V/F!
				local switchedTool = (eqTool.Parent ~= char)
				if switchedTool then
					lastEquipAttempt = os.clock()
					pcall(function() hum:EquipTool(eqTool) end)
					local eqWait = os.clock()
					while eqTool.Parent ~= char and (os.clock() - eqWait < 0.22) do
						RunService.Heartbeat:Wait()
					end
					if eqTool.Parent ~= char then return end
					local settleStart = os.clock()
					while os.clock() - settleStart < 0.07 do
						lockAimNow()
						RunService.Heartbeat:Wait()
					end
				end

				if GlobalModule then
					GlobalModule.tapCooldown = 0
				end
				if (S.skillAimlock or S.masteryAimlock) and not hum.SeatPart then
					savedAutoRotate = hum.AutoRotate
					hum.AutoRotate = false
				end

				lockAimNow()

				if VirtualInputManager then
					VirtualInputManager:SendKeyEvent(true, kc, false, game)
					if holdTime <= 0.01 then
						-- 0.0s Instant Tap: 2 Heartbeats (~0.03s) guarantees 100% registration with zero hold delay!
						RunService.Heartbeat:Wait()
						lockAimNow()
						RunService.Heartbeat:Wait()
						lockAimNow()
					else
						local tStart = os.clock()
						while os.clock() - tStart < holdTime do
							lockAimNow()
							RunService.Heartbeat:Wait()
						end
					end
					VirtualInputManager:SendKeyEvent(false, kc, false, game)
				elseif keypress and keyrelease then
					keypress(kc)
					if holdTime <= 0.01 then
						RunService.Heartbeat:Wait()
						lockAimNow()
						RunService.Heartbeat:Wait()
					else
						local tStart = os.clock()
						while os.clock() - tStart < holdTime do
							lockAimNow()
							RunService.Heartbeat:Wait()
						end
					end
					keyrelease(kc)
				end

				-- Follow-through aim lock during skill windup/release (0.20s) so projectile/hitbox launches dead-center & never cancels!
				local followStart = os.clock()
				while os.clock() - followStart < 0.20 do
					lockAimNow()
					RunService.Heartbeat:Wait()
				end

				if GlobalModule then
					GlobalModule.tapCooldown = 0
				end

				-- Force-return smoothly to M1 weapon if rotation temporarily switched to another weapon
				if returnWeapon and returnWeapon ~= chosenCat and S.autoEquip then
					local retTool = getToolByWeaponType(returnWeapon)
					if retTool and retTool.Parent ~= char and hum.Health > 0 then
						lastEquipAttempt = os.clock()
						pcall(function() hum:EquipTool(retTool) end)
					end
				end
			end)
			if humRef and savedAutoRotate ~= nil then
				pcall(function() humRef.AutoRotate = savedAutoRotate end)
			end
			S.isCastingSkillAim = false
			isCastingGlobalSkill = false
		end)
		return true
	end

	triggerSelectedMasterySkills = function(targetEnemy)
		S.castGlobalSkills(S.masteryCategory, targetEnemy, nil, "mastery")
	end

	performNormalAttack = function(weaponTypeOverride, primaryEnemy, skipGeneralSkills)
		if isCastingGlobalSkill then return end
		local now = os.clock()
		if now - lastNormalSwing < 0.24 then return end
		lastNormalSwing = now

		local char = LocalPlayer.Character
		if not char then return end
		if not CombatController and S.ensureCombatModulesReady then
			S.ensureCombatModulesReady(false)
		end

		ensureBusoHaki()
		local targetWType = weaponTypeOverride or S.weaponType

		-- If Doble Daño is ON, lead with Blox Fruit M1 so Melee M1 hides right behind Fruit M1!
		if S.doubleDamage and (weaponTypeOverride == nil or weaponTypeOverride == "Blox Fruit" or weaponTypeOverride == S.weaponType) then
			if getToolByWeaponType("Blox Fruit") and getToolByWeaponType("Melee") then
				targetWType = "Blox Fruit"
			end
		end

		local tool = S.autoEquip and equipWeaponType(targetWType) or char:FindFirstChildOfClass("Tool")
		if not tool or tool.Parent ~= char then return end

		-- Lock Gun / Fruit / Skill aim dead-center onto the target NPC / Sea Event
		if primaryEnemy then
			updateMasteryAimTarget(primaryEnemy)
		end

		-- Clear skill tapCooldown so Fruit M1, Gun M1 and Melee M1 are never blocked
		if GlobalModule then
			GlobalModule.tapCooldown = 0
		end

		-- Dedicated Blox Fruit M1 Click support (LeftClickRemote + MousePos + Activate + CombatController)
		local isFruitTool = (targetWType == "Blox Fruit") or isToolBloxFruit(tool)
		if isFruitTool then
			pcall(function()
				local hrp = char:FindFirstChild("HumanoidRootPart")
				local aimPos = S.lastAimPos or (hrp and (hrp.Position + hrp.CFrame.LookVector * 25))
				if aimPos then
					local mp = tool:FindFirstChild("MousePos")
					if mp and mp:IsA("Vector3Value") then
						mp.Value = aimPos
					end
					local lcr = tool:FindFirstChild("LeftClickRemote")
					if lcr and lcr:IsA("RemoteEvent") and hrp then
						local dir = (aimPos - hrp.Position)
						local unitDir = (dir.Magnitude > 0.001) and dir.Unit or Vector3.new(0, -1, 0)
						fruitM1Combo = (fruitM1Combo % 4) + 1
						lcr:FireServer(unitDir, fruitM1Combo)
					end
				end
			end)
		end

		pcall(function()
			if CombatController then
				CombatController:Attack(tool, FakeAttackInput)
			end
			if isFruitTool or not CombatController then
				tool:Activate()
				VirtualUser:CaptureController()
				VirtualUser:ClickButton1(Vector2.new(0, 0))
			end
		end)

		-- Ensure Melee / Sword / Fruit M1 hit registration connects via CombatUtil's SendHitsToServer
		if targetWType == "Melee" or targetWType == "Sword" or isFruitTool then
			task.delay(0.03, function()
				pcall(function()
					if GlobalModule and GlobalModule.SendHitsToServer then
						local primaryPart, extraTargets = getEnemyHitTargets(primaryEnemy)
						if primaryPart then
							GlobalModule.SendHitsToServer(primaryPart, extraTargets)
						end
					end
				end)
			end)
		end

		-- Doble Daño: Weave hidden Melee M1 directly behind the Blox Fruit M1 swing!
		if S.doubleDamage and isFruitTool then
			weaveHiddenMeleeBehindFruitM1(char, tool, primaryEnemy)
		end

		-- Cast Global Advanced Setting Skills when enabled
		if not skipGeneralSkills and S.globalAutoSkills then
			S.castGlobalSkills(targetWType, primaryEnemy, nil, "general")
		end
	end
end

--------------------------------------------------------------------------------
-- SMART PORTAL ROUTING (CURSED SHIP, UNDERWATER CITY, UPPER SKY, SEA 3 PORTALS)
-- + SMOOTH TWEEN MOVEMENT AT 200 SPEED + ZONE PATROL
--------------------------------------------------------------------------------
local function clearFarmMover()
	if S.activeTween then
		pcall(function() S.activeTween:Cancel() end)
		S.activeTween = nil
	end
	S.lastTweenTarget = nil
	S.lastAimEnemy = nil
	S.lastAimPart = nil
	S.islandTweenBusy = false
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:FindFirstChild("SwitchHubBV") then
		hrp.SwitchHubBV:Destroy()
	end
end

local lastEntranceAttempt = 0
local lastUnlockCheck = 0
local cachedSea3PortalsUnlocked = nil
local cachedFlamingoUnlocked = nil

local function checkPortalUnlockables()
	if not CommF_ then return false, false end
	if os.clock() - lastUnlockCheck > 15 or cachedSea3PortalsUnlocked == nil then
		lastUnlockCheck = os.clock()
		task.spawn(function()
			pcall(function()
				local u = CommF_:InvokeServer("GetUnlockables")
				if type(u) == "table" then
					cachedSea3PortalsUnlocked = (u.DefeatedIndraTrueForm == true)
					cachedFlamingoUnlocked = (u.FlamingoAccess == true)
				end
			end)
		end)
	end
	return cachedSea3PortalsUnlocked == true, cachedFlamingoUnlocked == true
end
S.markFlamingoUnlocked = function()
	cachedFlamingoUnlocked = true
	lastUnlockCheck = os.clock()
end

local function tryRequestEntrance(destPos, entrancePart)
	if not CommF_ or not destPos then return false end
	if os.clock() - lastEntranceAttempt < 0.65 then return false end
	lastEntranceAttempt = os.clock()

	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then return false end

	-- Ensure character is not Sitting and Busy is false (required by AnimateEntrance / Server)
	pcall(function()
		if hum.Sit then hum.Sit = false end
		local busy = char:FindFirstChild("Busy")
		if busy and busy:IsA("BoolValue") then
			busy.Value = false
		end
	end)

	-- Also fire touch interest on the physical portal part if available
	if entrancePart and entrancePart:IsA("BasePart") and firetouchinterest then
		pcall(function()
			firetouchinterest(hrp, entrancePart, 0)
			firetouchinterest(hrp, entrancePart, 1)
		end)
	end

	local ok, res = pcall(function()
		return CommF_:InvokeServer("requestEntrance", destPos)
	end)
	if ok and typeof(res) == "Vector3" and hrp and hrp.Parent then
		if S.activeTween then
			pcall(function() S.activeTween:Cancel() end)
			S.activeTween = nil
		end
		S.lastTweenTarget = nil
		hrp.CFrame = CFrame.new(res)
		return true
	end
	if hrp and (hrp.Position - destPos).Magnitude < 120 then
		if S.activeTween then
			pcall(function() S.activeTween:Cancel() end)
			S.activeTween = nil
		end
		S.lastTweenTarget = nil
		return true
	end
	return false
end

-- Detects if moving from hrpPos to targetPos requires (or is greatly shortened by) a Portal
local function resolveSmartPortalRoute(hrpPos, targetPos)
	if S.useSmartPortals == false then return nil end
	local map = Workspace:FindFirstChild("Map")

	-- 1) SEA 2: BARCO MALDITO / CURSED SHIP (GhostShip <-> GhostShipInterior, Z > 20000)
	local ghostShip = map and map:FindFirstChild("GhostShip")
	local ghostShipInt = map and map:FindFirstChild("GhostShipInterior")
	if ghostShip or ghostShipInt or getCurrentSeaNumber() == 2 then
		local playerInShip = (hrpPos.Z > 20000)
		local targetInShip = (targetPos.Z > 20000)

		if not playerInShip and targetInShip then
			-- Need to ENTER Cursed Ship via the exterior portal door on the ship at Graveyard
			local extPart = ghostShip and ghostShip:FindFirstChild("Teleport")
			local intSpawnPart = ghostShipInt and ghostShipInt:FindFirstChild("TeleportSpawn")
			local extPortalPos = (extPart and extPart:IsA("BasePart") and extPart.Position)
				or Vector3.new(-6496.9, 89.0, -116.5)
			local intSpawnPos = (intSpawnPart and intSpawnPart:IsA("BasePart") and intSpawnPart.Position)
				or Vector3.new(923.21, 126.98, 32852.83)
			return {
				entrancePos = extPortalPos,
				exitSpawnPos = intSpawnPos,
				entrancePart = extPart,
				label = "Portal Barco Maldito (Entrada)",
			}
		elseif playerInShip and not targetInShip then
			-- Need to EXIT Cursed Ship back to Sea 2 via the interior portal door
			local intPart = ghostShipInt and ghostShipInt:FindFirstChild("Teleport")
			local extSpawnPart = ghostShip and ghostShip:FindFirstChild("TeleportSpawn")
			local intPortalPos = (intPart and intPart:IsA("BasePart") and intPart.Position)
				or Vector3.new(920.48, 154.90, 32838.96)
			local extSpawnPos = (extSpawnPart and extSpawnPart:IsA("BasePart") and extSpawnPart.Position)
				or Vector3.new(-6508.56, 89.04, -132.84)
			return {
				entrancePos = intPortalPos,
				exitSpawnPos = extSpawnPos,
				entrancePart = intPart,
				label = "Portal Barco Maldito (Salida)",
			}
		end

		-- Don Swan Boss Room in Sea 2 (Dressrosa.FlamingoEntrance <-> FlamingoExit)
		local dressrosa = map and map:FindFirstChild("Dressrosa")
		local flamEnt = dressrosa and dressrosa:FindFirstChild("FlamingoEntrance")
		local flamExit = dressrosa and dressrosa:FindFirstChild("FlamingoExit")
		if flamEnt and flamExit and flamEnt:IsA("BasePart") and flamExit:IsA("BasePart") then
			local swanCenter = flamExit.Position
			local playerInSwan = (hrpPos - swanCenter).Magnitude < 280 and hrpPos.Y < 55
			local targetInSwan = (targetPos - swanCenter).Magnitude < 280 and targetPos.Y < 55
			local _, hasFlam = checkPortalUnlockables()
			if hasFlam then
				if not playerInSwan and targetInSwan then
					return {
						entrancePos = flamEnt.Position,
						exitSpawnPos = (flamExit.CFrame * Vector3.new(0, 0, -6)),
						entrancePart = flamEnt,
						label = "Portal Don Swan (Entrada)",
					}
				elseif playerInSwan and not targetInSwan then
					return {
						entrancePos = flamExit.Position,
						exitSpawnPos = (flamEnt.CFrame * Vector3.new(0, 0, -6)),
						entrancePart = flamExit,
						label = "Portal Don Swan (Salida)",
					}
				end
			end
		end
	end

	-- 2) SEA 1: UNDERWATER CITY / ISLA GYOJIN (X > 45000) & UPPER SKYLANDS (Y > 3200)
	local tpSpawn = map and map:FindFirstChild("TeleportSpawn")
	if tpSpawn or getCurrentSeaNumber() == 1 then
		local playerInUnderwater = (hrpPos.X > 45000)
		local targetInUnderwater = (targetPos.X > 45000)

		if not playerInUnderwater and targetInUnderwater then
			local entPart = tpSpawn and tpSpawn:FindFirstChild("Entrance")
			local entPoint = tpSpawn and tpSpawn:FindFirstChild("EntrancePoint")
			local whirlpoolPos = (entPart and entPart:IsA("BasePart") and entPart.Position)
				or Vector3.new(3864.69, 6.74, -1926.21)
			local insidePos = (entPoint and entPoint:IsA("BasePart") and entPoint.Position)
				or Vector3.new(61163.85, 11.68, 1819.78)
			return {
				entrancePos = whirlpoolPos,
				exitSpawnPos = insidePos,
				entrancePart = entPart,
				label = "Portal Whirlpool (Isla Gyojin)",
			}
		elseif playerInUnderwater and not targetInUnderwater then
			local exitPart = tpSpawn and tpSpawn:FindFirstChild("Exit")
			local exitPoint = tpSpawn and tpSpawn:FindFirstChild("ExitPoint")
			local insideExitPos = (exitPart and exitPart:IsA("BasePart") and exitPart.Position)
				or Vector3.new(61163.85, 11.68, 1819.78)
			local outsidePos = (exitPoint and exitPoint:IsA("BasePart") and exitPoint.Position)
				or Vector3.new(3864.69, 6.74, -1926.21)
			return {
				entrancePos = insideExitPos,
				exitSpawnPos = outsidePos,
				entrancePart = exitPart,
				label = "Portal Salida Isla Gyojin",
			}
		end

		-- Upper Skylands (Sky.Entrance <-> SkyArea2.EntrancePoint, Y > 3200)
		local sky1 = map and map:FindFirstChild("Sky")
		local sky2 = map and map:FindFirstChild("SkyArea2")
		if sky1 or sky2 then
			local playerInUpperSky = (hrpPos.Y > 3200)
			local targetInUpperSky = (targetPos.Y > 3200)
			if not playerInUpperSky and targetInUpperSky then
				local s1Ent = sky1 and sky1:FindFirstChild("Entrance")
				local s2Pt = sky2 and sky2:FindFirstChild("EntrancePoint")
				return {
					entrancePos = (s1Ent and s1Ent:IsA("BasePart") and s1Ent.Position) or Vector3.new(-4651.87, 844.47, -1914.51),
					exitSpawnPos = (s2Pt and s2Pt:IsA("BasePart") and s2Pt.Position) or Vector3.new(-7894.62, 5547.14, -380.29),
					entrancePart = s1Ent,
					label = "Portal Upper Skylands (Entrada)",
				}
			elseif playerInUpperSky and not targetInUpperSky then
				local s2Exit = sky2 and sky2:FindFirstChild("Exit")
				local s1Pt = sky1 and sky1:FindFirstChild("ExitPoint")
				return {
					entrancePos = (s2Exit and s2Exit:IsA("BasePart") and s2Exit.Position) or Vector3.new(-7894.62, 5547.14, -380.29),
					exitSpawnPos = (s1Pt and s1Pt:IsA("BasePart") and s1Pt.Position) or Vector3.new(-4651.87, 844.47, -1914.51),
					entrancePart = s2Exit,
					label = "Portal Upper Skylands (Salida)",
				}
			end
		end
	end

	-- 3) SEA 3: CASTLE ON THE SEA <-> FLOATING TURTLE (MANSION) <-> HYDRA ISLAND PORTALS
	local turtle = map and map:FindFirstChild("Turtle")
	if turtle or getCurrentSeaNumber() == 3 then
		local hasSea3Portals = checkPortalUnlockables()
		if hasSea3Portals then
			local castleA = Vector3.new(-5091.9, 314.5, -2967.2)
			local castleB = Vector3.new(-5073.5, 314.5, -3153.0)
			local turtleB = Vector3.new(-12462.6, 374.9, -7551.8)
			local hydraA  = Vector3.new(5748.9, 610.5, -282.5)

			local directDist = (hrpPos - targetPos).Magnitude
			if directDist > 4500 then
				local sea3Links = {
					{entrancePos = castleA, exitSpawnPos = turtleB, label = "Portal Castillo -> Mansión (Turtle)"},
					{entrancePos = turtleB, exitSpawnPos = castleA, label = "Portal Mansión -> Castillo del Mar"},
					{entrancePos = castleB, exitSpawnPos = hydraA,  label = "Portal Castillo -> Hydra Island"},
					{entrancePos = hydraA,  exitSpawnPos = castleB, label = "Portal Hydra -> Castillo del Mar"},
				}
				local bestLink = nil
				local bestTotal = directDist - 3200
				for _, link in ipairs(sea3Links) do
					local viaDist = (hrpPos - link.entrancePos).Magnitude + (link.exitSpawnPos - targetPos).Magnitude
					if viaDist < bestTotal then
						bestTotal = viaDist
						bestLink = link
					end
				end
				if bestLink then
					return bestLink
				end
			end
		end
	end

	return nil
end

local function moveToCFrame(targetCF, lookAtPos)
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then return false end

	-- Anti-gravity stabilizer
	local bv = hrp:FindFirstChild("SwitchHubBV")
	if not bv then
		bv = Instance.new("BodyVelocity")
		bv.Name = "SwitchHubBV"
		bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
		bv.Velocity = Vector3.zero
		bv.Parent = hrp
	end

	local targetPos = targetCF.Position

	-- Smart Portal Check: if destination is inside Cursed Ship / Underwater City / Upper Sky / distant portal zone,
	-- go straight to the portal entrance first and teleport right inside!
	local portalRoute = resolveSmartPortalRoute(hrp.Position, targetPos)
	if portalRoute then
		local distToPortal = (hrp.Position - portalRoute.entrancePos).Magnitude
		if distToPortal <= 35 then
			hrp.CFrame = CFrame.new(portalRoute.entrancePos)
			if tryRequestEntrance(portalRoute.exitSpawnPos, portalRoute.entrancePart) then
				return false
			end
		end
		-- Redirect tween target to the portal entrance
		targetPos = portalRoute.entrancePos
		lookAtPos = nil
	end

	local finalCF = lookAtPos and CFrame.lookAt(targetPos, lookAtPos) or CFrame.new(targetPos)
	local dist = (hrp.Position - targetPos).Magnitude

	-- Close enough: snap orientation cleanly so melee/sword angle check (< 1.3 rad) always passes!
	if dist <= 5 then
		if S.activeTween then
			pcall(function() S.activeTween:Cancel() end)
			S.activeTween = nil
		end
		S.lastTweenTarget = targetPos
		hrp.CFrame = finalCF
		if portalRoute then
			tryRequestEntrance(portalRoute.exitSpawnPos, portalRoute.entrancePart)
			return false
		end
		return true
	end

	-- Stream distant areas so NPCs and portal parts load properly
	if dist > 600 then
		pcall(function()
			LocalPlayer:RequestStreamAroundAsync(targetPos, 1)
		end)
	end

	-- Do NOT restart tween every tick if heading to the same destination!
	if S.activeTween and S.lastTweenTarget and (S.lastTweenTarget - targetPos).Magnitude < 8 then
		if S.activeTween.PlaybackState == Enum.PlaybackState.Playing then
			return (not portalRoute) and (dist <= 14)
		end
	end

	if S.activeTween then
		pcall(function() S.activeTween:Cancel() end)
	end

	local speed = math.clamp(S.tweenSpeed or 200, 80, 350)
	local duration = math.max(0.08, dist / speed)
	local tw = TweenService:Create(
		hrp,
		TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
		{CFrame = finalCF}
	)
	S.activeTween = tw
	S.lastTweenTarget = targetPos
	tw:Play()
	return (not portalRoute) and (dist <= 14)
end

-- Patrol around a list of spawn CFrames (builds a multi-point perimeter so NPCs spawn)
local patrolWaypoints = {}
local patrolKey = ""
local patrolSourceCount = 0
local patrolIdx = 1
local lastPatrolAdvance = 0

local function patrolAroundSpawns(keyName, spawnList)
	if not spawnList or #spawnList == 0 then return end
	if patrolKey ~= keyName or #patrolWaypoints == 0 or (#spawnList > patrolSourceCount and patrolSourceCount < 3) then
		patrolKey = keyName
		patrolSourceCount = #spawnList
		patrolIdx = 1
		patrolWaypoints = {}

		local hoverY = math.max(12, S.farmDistance + 6)
		if #spawnList >= 3 then
			for _, cf in ipairs(spawnList) do
				table.insert(patrolWaypoints, cf.Position + Vector3.new(0, hoverY, 0))
			end
		else
			local basePos = spawnList[1].Position
			local r = 40
			local offsets = {
				Vector3.new(r, hoverY, 0),
				Vector3.new(0, hoverY, r),
				Vector3.new(-r, hoverY, 0),
				Vector3.new(0, hoverY, -r),
			}
			for _, off in ipairs(offsets) do
				table.insert(patrolWaypoints, basePos + off)
			end
		end
	end

	if patrolIdx > #patrolWaypoints then
		patrolIdx = 1
	end

	local wp = patrolWaypoints[patrolIdx]
	local reached = moveToCFrame(CFrame.new(wp))
	if reached and (os.clock() - lastPatrolAdvance > 1.2) then
		lastPatrolAdvance = os.clock()
		patrolIdx = (patrolIdx % #patrolWaypoints) + 1
	end
end

--------------------------------------------------------------------------------
-- BRING MOBS (STRICTLY MAX 3 MOBS) & TARGET LOCKING
--------------------------------------------------------------------------------
local function bringNearbyMobs(targetNamesMap, centerCFrame)
	if not S.bringMobs then return end
	local enemiesFolder = Workspace:FindFirstChild("Enemies")
	if not enemiesFolder then return end

	pcall(function()
		if sethiddenproperty then
			sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
		end
	end)

	local brought = 0
	local maxAllowed = S.maxBringMobs or 3 -- Strictly maximum 3 mobs

	for _, enemy in ipairs(enemiesFolder:GetChildren()) do
		if brought >= maxAllowed then
			break
		end
		local clean = enemy.Name:gsub(" %[Raid Boss%]", ""):gsub(" %[Boss%]", ""):gsub(" %[Lv%. %d+%]", "")
		local matches = (not targetNamesMap) or targetNamesMap[clean] or targetNamesMap[enemy.Name]
		if matches and not enemy.Name:find("%[Boss%]") then
			local eHum = enemy:FindFirstChildOfClass("Humanoid")
			local eHrp = enemy:FindFirstChild("HumanoidRootPart")
			if eHum and eHum.Health > 0 and eHrp then
				local dist = (eHrp.Position - centerCFrame.Position).Magnitude
				if dist <= 260 then
					brought = brought + 1
					pcall(function()
						eHrp.CFrame = centerCFrame
						eHrp.CanCollide = false
						eHrp.Velocity = Vector3.zero
						eHum.WalkSpeed = 0
						eHum.JumpPower = 0
					end)
				end
			end
		end
	end
end

local function findAliveEnemyFromSet(targetNamesMap, maxRadius)
	local enemiesFolder = Workspace:FindFirstChild("Enemies")
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not enemiesFolder or not hrp then return nil end

	-- Keep current locked enemy until it dies so we never ping-pong between two live mobs
	if S.lockedEnemy and S.lockedEnemy.Parent == enemiesFolder then
		local clean = S.lockedEnemy.Name:gsub(" %[Raid Boss%]", ""):gsub(" %[Boss%]", ""):gsub(" %[Lv%. %d+%]", "")
		local matches = (not targetNamesMap) or targetNamesMap[clean] or targetNamesMap[S.lockedEnemy.Name]
		local eHum = S.lockedEnemy:FindFirstChildOfClass("Humanoid")
		local eHrp = S.lockedEnemy:FindFirstChild("HumanoidRootPart")
		if matches and eHum and eHum.Health > 0 and eHrp then
			local d = (eHrp.Position - hrp.Position).Magnitude
			if not maxRadius or d <= maxRadius then
				return S.lockedEnemy
			end
		end
	end

	local bestEnemy = nil
	local bestDist = maxRadius or math.huge

	for _, enemy in ipairs(enemiesFolder:GetChildren()) do
		local clean = enemy.Name:gsub(" %[Raid Boss%]", ""):gsub(" %[Boss%]", ""):gsub(" %[Lv%. %d+%]", "")
		local matches = (not targetNamesMap) or targetNamesMap[clean] or targetNamesMap[enemy.Name]
		if matches then
			local eHum = enemy:FindFirstChildOfClass("Humanoid")
			local eHrp = enemy:FindFirstChild("HumanoidRootPart")
			if eHum and eHum.Health > 0 and eHrp then
				local d = (eHrp.Position - hrp.Position).Magnitude
				if d <= bestDist then
					bestDist = d
					bestEnemy = enemy
				end
			end
		end
	end

	S.lockedEnemy = bestEnemy
	return bestEnemy
end

--------------------------------------------------------------------------------
-- DETERMINISTIC QUEST RESOLUTION & GUIDEDATA QUEST DETECTION
--------------------------------------------------------------------------------
local function addCachedSpawn(cleanName, cf)
	if not cleanName or not cf then return end
	local list = S.cachedMobSpawns[cleanName]
	if not list then
		list = {}
		S.cachedMobSpawns[cleanName] = list
	end
	if #list >= 6 then return end
	for _, existing in ipairs(list) do
		if (existing.Position - cf.Position).Magnitude < 22 then
			return
		end
	end
	table.insert(list, cf)
end

local getCurrentSpawnMap
do
	local lastSpawnScanClock = 0
	getCurrentSpawnMap = function(force)
		local now = os.clock()
		if not force and (now - lastSpawnScanClock < 2.5) and next(S.cachedMobSpawns) ~= nil then
			return S.cachedMobSpawns
		end
		lastSpawnScanClock = now

		local worldOrigin = Workspace:FindFirstChild("_WorldOrigin")
		local enemySpawnsFolder = worldOrigin and worldOrigin:FindFirstChild("EnemySpawns")
		if enemySpawnsFolder then
			for _, sp in ipairs(enemySpawnsFolder:GetChildren()) do
				local cleanName = sp.Name:gsub(" %[Raid Boss%]", ""):gsub(" %[Boss%]", ""):gsub(" %[Lv%. %d+%]", "")
				local cf = sp:IsA("BasePart") and sp.CFrame or (sp:IsA("Model") and sp:GetPivot())
				if cf then
					addCachedSpawn(cleanName, cf)
				end
			end
		end

		-- Only seed from Workspace.Enemies if we have 0 static EnemySpawns for that mob
		local enemiesFolder = Workspace:FindFirstChild("Enemies")
		if enemiesFolder then
			for _, en in ipairs(enemiesFolder:GetChildren()) do
				local cleanName = en.Name:gsub(" %[Raid Boss%]", ""):gsub(" %[Boss%]", ""):gsub(" %[Lv%. %d+%]", "")
				if not S.cachedMobSpawns[cleanName] or #S.cachedMobSpawns[cleanName] == 0 then
					local hrp = en:FindFirstChild("HumanoidRootPart")
					if hrp then
						addCachedSpawn(cleanName, hrp.CFrame)
					end
				end
			end
		end

		return S.cachedMobSpawns
	end
end

local function findNearestEnemyRegionCFrame(refPos)
	local worldOrigin = Workspace:FindFirstChild("_WorldOrigin")
	local er = worldOrigin and worldOrigin:FindFirstChild("EnemyRegions")
	if not er or not refPos then return nil end
	local bestCF = nil
	local bestDist = math.huge
	for _, part in ipairs(er:GetChildren()) do
		if part:IsA("BasePart") then
			local d = (part.Position - refPos).Magnitude
			if d < bestDist then
				bestDist = d
				bestCF = part.CFrame
			end
		end
	end
	return bestCF
end

-- Secret / Non-Standard Quests excluded from normal 1-2800 Level Farm
local SecretQuestBlacklist = {
	["BartiloQuest"] = true,
	["CitizenQuest"] = true,
}

local function getBestQuestForPlayer()
	if not QuestsModule and S.ensureCombatModulesReady then
		S.ensureCombatModulesReady(true)
	end
	local levelObj = LocalPlayer:FindFirstChild("Data") and LocalPlayer.Data:FindFirstChild("Level")
	local rawLevel = levelObj and levelObj.Value or 1
	-- Standard Max Level is 2800 (Submerged Island quests up to Lv. 2700-2800)
	local effectiveLevel = math.clamp(rawLevel, 1, S.maxGameLevel or 2800)
	local spawnMap = getCurrentSpawnMap()
	if not QuestsModule then return nil end

	-- Map questGroup -> Quest Giver NPC CFrame via GuideModule.Data.NPCList (100% static per Sea)
	local npcPositions = {}
	local hasGuideNPCs = false
	if GuideModule and GuideModule.Data and GuideModule.Data.NPCList then
		for _, npcData in pairs(GuideModule.Data.NPCList) do
			if npcData.InternalQuestName and npcData.Position then
				npcPositions[npcData.InternalQuestName] = CFrame.new(npcData.Position)
				hasGuideNPCs = true
			end
		end
	end

	local isMarine = LocalPlayer.Team and LocalPlayer.Team.Name == "Marines"
	local candidates = {}

	for qGroup, qList in pairs(QuestsModule) do
		if not SecretQuestBlacklist[qGroup] then
			local inCurrentSea = hasGuideNPCs and (npcPositions[qGroup] ~= nil) or false
			if not hasGuideNPCs then
				for _, qData in ipairs(qList) do
					if qData.Task then
						for mName in pairs(qData.Task) do
							if spawnMap[mName] and #spawnMap[mName] > 0 then
								inCurrentSea = true
								break
							end
						end
					end
				end
			end

			if inCurrentSea then
				if not (effectiveLevel < 10 and isMarine and qGroup == "BanditQuest1")
					and not (effectiveLevel < 10 and not isMarine and qGroup == "MarineQuest") then
					for qIdx, qData in ipairs(qList) do
						local lvlReq = qData.LevelReq or 0
						if lvlReq <= effectiveLevel and qData.Task then
							for mobName, reqCount in pairs(qData.Task) do
								-- Exclude Boss (count == 1) and Secret Raid (count >= 30) tasks
								if reqCount > 1 and reqCount <= 20 then
									local npcCF = npcPositions[qGroup]
									local spawns = spawnMap[mobName]
									if not spawns or #spawns == 0 then
										local regionCF = npcCF and findNearestEnemyRegionCFrame(npcCF.Position)
										spawns = {regionCF or npcCF or CFrame.new(0, 50, 0)}
									end
									table.insert(candidates, {
										questGroup = qGroup,
										questIndex = qIdx,
										levelReq = lvlReq,
										questTitle = qData.Name or mobName,
										mobName = mobName,
										reqCount = reqCount,
										spawns = spawns,
										npcCFrame = npcCF or spawns[1],
									})
								end
							end
						end
					end
				end
			end
		end
	end

	table.sort(candidates, function(a, b)
		if a.levelReq ~= b.levelReq then
			return a.levelReq > b.levelReq
		end
		if a.questGroup ~= b.questGroup then
			return a.questGroup > b.questGroup
		end
		return a.questIndex > b.questIndex
	end)

	return candidates[1]
end

-- Uses GuideData.Data.QuestData first (authoritative client state), with TrackedQuestFrame fallback
local function getActiveQuestStatus(expectedQuestGroup, expectedMobName)
	if not GuideData and S.ensureCombatModulesReady then
		S.ensureCombatModulesReady(true)
	end
	-- 1) Authoritative check via GuideData.Data.QuestData
	if GuideData and GuideData.Data then
		local qd = GuideData.Data.QuestData
		if not qd then
			return false, false, ""
		end
		local qName = qd.InternalQuestName or ""
		local info = qd.Info or {}
		local taskTbl = info.Task or {}
		local title = tostring(info.Name or qName)
		local matches = false
		if expectedQuestGroup and qName == expectedQuestGroup and taskTbl[expectedMobName] ~= nil then
			matches = true
		elseif expectedMobName and (taskTbl[expectedMobName] ~= nil or title:lower():find(expectedMobName:lower(), 1, true)) then
			matches = true
		end
		return true, matches, title
	end

	-- 2) Fallback GUI check
	local pgui = LocalPlayer:FindFirstChild("PlayerGui")
	if not pgui then return false, false, "" end

	local tqf = pgui:FindFirstChild("TrackedQuestFrame")
	local frame = tqf and tqf:FindFirstChild("Frame")
	if tqf and tqf.Enabled and frame and frame.Visible then
		local desc = frame:FindFirstChild("description") and frame.description.Text or ""
		local hdr = frame:FindFirstChild("header")
			and frame.header:FindFirstChild("textLabel")
			and frame.header.textLabel.Text or ""
		if desc ~= "" or hdr ~= "" then
			local combined = (desc .. " " .. hdr):lower()
			local targetLow = (expectedMobName or ""):lower()
			if targetLow == "" or combined:find(targetLow, 1, true) then
				return true, true, desc
			end
			return true, false, desc
		end
	end

	return false, false, ""
end

local lastAbandonClock = 0
local function abandonCurrentQuestNonBlocking()
	if os.clock() - lastAbandonClock < 2.2 then return end
	lastAbandonClock = os.clock()

	task.spawn(function()
		pcall(function()
			local pgui = LocalPlayer:FindFirstChild("PlayerGui")
			local tqf = pgui and pgui:FindFirstChild("TrackedQuestFrame")
			local btn = tqf and tqf:FindFirstChild("Frame")
				and tqf.Frame:FindFirstChild("header")
				and tqf.Frame.header:FindFirstChild("abandonQuestButton")
			if btn and firesignal then
				firesignal(btn.Activated)
				task.wait(0.15)
				if btn.Parent then
					firesignal(btn.Activated)
				end
			end
			if CommF_ then
				CommF_:InvokeServer("AbandonQuest")
			end
		end)
	end)
end

local lastQuestStartClock = 0
local function requestStartQuestNonBlocking(questGroup, questIndex)
	if os.clock() - lastQuestStartClock < 1.8 then return end
	lastQuestStartClock = os.clock()

	task.spawn(function()
		pcall(function()
			if CommF_ then
				CommF_:InvokeServer("StartQuest", questGroup, questIndex)
			end
		end)
	end)
end

--------------------------------------------------------------------------------
-- SERVER HOP IMPLEMENTATION
--------------------------------------------------------------------------------
local isHopping = false
local function executeServerHop(modeOverride)
	if isHopping then return end
	isHopping = true
	local mode = modeOverride or S.serverHopMode or "Low Players"
	setStatus("Buscando servidor (" .. mode .. ")...")

	task.spawn(function()
		local sortOrder = (mode == "Low Players") and "Asc" or "Desc"
		local url = string.format(
			"https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=%s&limit=100&excludeFullGames=true",
			game.PlaceId,
			sortOrder
		)

		local candidates = {}
		local reqFn = request or http_request or (http and http.request)
		if reqFn then
			local ok, resp = pcall(function()
				return reqFn({Url = url, Method = "GET"})
			end)
			if ok and resp and resp.StatusCode == 200 and resp.Body then
				local decOk, decoded = pcall(function()
					return HttpService:JSONDecode(resp.Body)
				end)
				if decOk and decoded and type(decoded.data) == "table" then
					for _, srv in ipairs(decoded.data) do
						local playing = tonumber(srv.playing) or 0
						local maxP = tonumber(srv.maxPlayers) or 12
						if srv.id and srv.id ~= game.JobId and playing >= 1 and playing < (maxP - 1) then
							table.insert(candidates, {
								id = srv.id,
								playing = playing,
								maxPlayers = maxP,
								ping = tonumber(srv.ping) or 999,
							})
						end
					end
				end
			end
		end

		if #candidates > 0 then
			if mode == "Low Players" then
				table.sort(candidates, function(a, b) return a.playing < b.playing end)
			elseif mode == "Best Ping" then
				table.sort(candidates, function(a, b) return a.ping < b.ping end)
			else
				for i = #candidates, 2, -1 do
					local j = math.random(1, i)
					candidates[i], candidates[j] = candidates[j], candidates[i]
				end
			end

			for i = 1, math.min(5, #candidates) do
				local pick = candidates[i]
				setStatus(string.format("Hopping -> %d/%d jugadores (%dms)", pick.playing, pick.maxPlayers, pick.ping))
				local tpOk = pcall(function()
					TeleportService:TeleportToPlaceInstance(game.PlaceId, pick.id, LocalPlayer)
				end)
				if tpOk then
					task.wait(4)
				end
			end
		else
			setStatus("Teleportando a nuevo servidor...")
			pcall(function()
				TeleportService:Teleport(game.PlaceId, LocalPlayer)
			end)
		end

		task.wait(3)
		isHopping = false
	end)
end

--------------------------------------------------------------------------------
-- SHOP & FIGHTING STYLE TEACHER NPC APPROACH + BUY / EQUIP SYSTEM
--------------------------------------------------------------------------------
local FightingStyleData = {
	["Dark Step"] = {
		npcName = "Dark Step Teacher",
		toolNames = {"Black Leg", "Dark Step"},
		positions = {
			[1] = Vector3.new(-990.5, 14.5, 3960.2),
			[2] = Vector3.new(-4752.4, 33.9, -4848.0),
			[3] = Vector3.new(-5020.0, 314.5, -3010.0),
		},
		invoke = function()
			CommF_:InvokeServer("BuyBlackLeg", true)
			return CommF_:InvokeServer("BuyBlackLeg")
		end,
	},
	["Electro"] = {
		npcName = "Mad Scientist",
		toolNames = {"Electro", "Electric"},
		positions = {
			[1] = Vector3.new(-5380.2, 14.5, -2148.5),
			[2] = Vector3.new(-4866.2, 33.9, -4767.1),
			[3] = Vector3.new(-5000.0, 314.5, -3030.0),
		},
		invoke = function()
			pcall(function() CommF_:InvokeServer("DeliverLightningBolt") end)
			CommF_:InvokeServer("BuyElectro", true)
			local r = CommF_:InvokeServer("BuyElectro")
			if r == 0 then
				pcall(function() CommF_:InvokeServer("AcceptElectroQuest") end)
			end
			return r
		end,
	},
	["Water Kung Fu"] = {
		npcName = "Water Kung-fu Teacher",
		toolNames = {"Fishman Karate", "Water Kung Fu"},
		positions = {
			[1] = Vector3.new(61562.2, 18.5, 987.4),
			[2] = Vector3.new(-4957.7, 35.9, -4665.6),
			[3] = Vector3.new(-5040.0, 314.5, -2990.0),
		},
		invoke = function()
			pcall(function() CommF_:InvokeServer("CheckFishmanKarate") end)
			CommF_:InvokeServer("BuyFishmanKarate", true)
			return CommF_:InvokeServer("BuyFishmanKarate")
		end,
	},
	["Dragon Breath"] = {
		npcName = "Sabi",
		toolNames = {"Dragon Claw", "Dragon Breath"},
		positions = {
			[2] = Vector3.new(699.0, 185.7, 654.9),
			[3] = Vector3.new(-4980.0, 314.5, -3050.0),
		},
		invoke = function()
			CommF_:InvokeServer("BlackbeardReward", "DragonClaw", "1")
			return CommF_:InvokeServer("BlackbeardReward", "DragonClaw", "2")
		end,
	},
	["Superhuman"] = {
		npcName = "Martial Arts Master",
		toolNames = {"Superhuman"},
		positions = {
			[2] = Vector3.new(1377.1, 246.5, -5190.0),
			[3] = Vector3.new(-4965.0, 314.5, -3065.0),
		},
		invoke = function()
			CommF_:InvokeServer("BuySuperhuman", true)
			return CommF_:InvokeServer("BuySuperhuman")
		end,
	},
	["Death Step"] = {
		npcName = "Phoeyu, the Reformed",
		toolNames = {"Death Step"},
		positions = {
			[2] = Vector3.new(6356.5, 296.1, -6762.8),
			[3] = Vector3.new(-4995.0, 314.5, -3045.0),
		},
		invoke = function()
			CommF_:InvokeServer("BuyDeathStep", true)
			return CommF_:InvokeServer("BuyDeathStep")
		end,
	},
	["Sharkman Karate"] = {
		npcName = "Sharkman Teacher",
		toolNames = {"Sharkman Karate"},
		positions = {
			[2] = Vector3.new(-2599.6, 238.2, -10316.0),
			[3] = Vector3.new(-5010.0, 314.5, -3025.0),
		},
		invoke = function()
			CommF_:InvokeServer("BuySharkmanKarate", true)
			return CommF_:InvokeServer("BuySharkmanKarate")
		end,
	},
	["Electric Claw"] = {
		npcName = "Previous Hero",
		toolNames = {"Electric Claw"},
		positions = {
			[3] = Vector3.new(-10371.5, 330.8, -10131.4),
		},
		invoke = function()
			local st = CommF_:InvokeServer("BuyElectricClaw", true)
			if st == 4 then
				return CommF_:InvokeServer("BuyElectricClaw", "Start")
			end
			return CommF_:InvokeServer("BuyElectricClaw")
		end,
	},
	["Dragon Talon"] = {
		npcName = "Uzoth",
		toolNames = {"Dragon Talon"},
		positions = {
			[3] = Vector3.new(5661.9, 1210.9, 863.2),
		},
		invoke = function()
			CommF_:InvokeServer("BuyDragonTalon", true)
			return CommF_:InvokeServer("BuyDragonTalon")
		end,
	},
	["Godhuman"] = {
		npcName = "Ancient Monk",
		toolNames = {"Godhuman"},
		positions = {
			[3] = Vector3.new(-13774.2, 334.5, -9875.5),
		},
		invoke = function()
			CommF_:InvokeServer("BuyGodhuman", true)
			return CommF_:InvokeServer("BuyGodhuman")
		end,
	},
	["Sanguine Art"] = {
		npcName = "Shafi",
		toolNames = {"Sanguine Art"},
		positions = {
			[3] = Vector3.new(-16514.5, 22.8, -188.4),
		},
		invoke = function()
			CommF_:InvokeServer("BuySanguineArt", true)
			return CommF_:InvokeServer("BuySanguineArt")
		end,
	},
}

local function findTeacherNPCCFrame(npcName, styleInfo)
	for _, folder in ipairs({Workspace:FindFirstChild("NPCs"), ReplicatedStorage:FindFirstChild("NPCs")}) do
		local model = folder and folder:FindFirstChild(npcName)
		if model then
			local ok, cf = pcall(function() return model:GetPivot() end)
			if ok and cf then
				return cf, model
			end
		end
	end
	local sea = getCurrentSeaNumber()
	local fallbackPos = styleInfo.positions[sea] or styleInfo.positions[2] or styleInfo.positions[3] or styleInfo.positions[1]
	if fallbackPos then
		return CFrame.new(fallbackPos), nil
	end
	return nil, nil
end

local function equipMeleeToolInHand(preferredToolNames)
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local bp = LocalPlayer:FindFirstChild("Backpack")
	if not char or not hum or hum.Health <= 0 then return nil end

	-- 1) Check if preferred tool name is in Character or Backpack
	if type(preferredToolNames) == "table" then
		for _, cont in ipairs({char, bp}) do
			if cont then
				for _, t in ipairs(cont:GetChildren()) do
					if t:IsA("Tool") then
						for _, pName in ipairs(preferredToolNames) do
							if t.Name:lower() == pName:lower() then
								if t.Parent ~= char then
									pcall(function() hum:EquipTool(t) end)
								end
								return t
							end
						end
					end
				end
			end
		end
	end

	-- 2) Fallback: equip any Melee tool in Backpack/Character
	local meleeTool = getToolByWeaponType("Melee")
	if meleeTool then
		if meleeTool.Parent ~= char then
			pcall(function() hum:EquipTool(meleeTool) end)
		end
		return meleeTool
	end
	return nil
end

-- Approaches the Teacher NPC at speed 200, buys or switches the Fighting Style, and equips it in hand!
local function goToTeacherAndBuyOrEquipStyle(styleName, uiStatusCallback)
	if S.styleShopBusy then return end
	local info = FightingStyleData[styleName]
	if not info or not CommF_ then return end

	S.styleShopBusy = true
	task.spawn(function()
		local function report(txt)
			setStatus(txt)
			if uiStatusCallback then
				pcall(uiStatusCallback, txt)
			end
		end

		pcall(function()
			ensureTeamSelected()
			local char = LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not hrp or not hum or hum.Health <= 0 then
				report("Esperando aparición del personaje...")
				return
			end

			local npcCF = findTeacherNPCCFrame(info.npcName, info)
			if npcCF then
				local startClock = os.clock()
				report(string.format("Yendo al NPC %s (%s)...", info.npcName, styleName))

				while isAlive() and S.styleShopBusy and (os.clock() - startClock < 45) do
					char = LocalPlayer.Character
					hrp = char and char:FindFirstChild("HumanoidRootPart")
					hum = char and char:FindFirstChildOfClass("Humanoid")
					if not hrp or not hum or hum.Health <= 0 then break end

					-- Refresh live NPC CFrame once streamed into Workspace.NPCs
					local liveCF = findTeacherNPCCFrame(info.npcName, info)
					if liveCF then
						npcCF = liveCF
					end

					local standPos = (npcCF * CFrame.new(0, 0, 3.5)).Position
					local dist = (hrp.Position - npcCF.Position).Magnitude
					report(string.format("Abordando NPC %s [%dm]...", info.npcName, math.floor(dist)))

					local reached = moveToCFrame(CFrame.new(standPos), npcCF.Position)
					if reached or dist <= 9 then
						break
					end
					task.wait(0.12)
				end

				clearFarmMover()
				task.wait(0.15)
			end

			report("Comprando / Equipando " .. styleName .. " con " .. info.npcName .. "...")
			local res = nil
			pcall(function()
				res = info.invoke()
			end)

			task.wait(0.35)
			local equippedTool = equipMeleeToolInHand(info.toolNames)
			if equippedTool then
				report(string.format("¡%s comprado/equipado en mano (%s)!", styleName, equippedTool.Name))
			else
				report(string.format("NPC %s contactado (Resultado: %s)", info.npcName, tostring(res)))
			end
		end)

		S.styleShopBusy = false
	end)
end

local AbilityRemotes = {
	["Geppo (Skyjump)"]      = function() return CommF_:InvokeServer("BuyHaki", "Geppo") end,
	["Buso Haki (Aura)"]     = function() return CommF_:InvokeServer("BuyHaki", "Buso") end,
	["Soru (Flash Step)"]    = function() return CommF_:InvokeServer("BuyHaki", "Soru") end,
	["Ken Haki (Instinct)"]  = function() return CommF_:InvokeServer("KenTalk", "Buy") end,
	["Random Bone Surprise"] = function() return CommF_:InvokeServer("Bones", "Buy", 1, 1) end,
	["Stat Refund (2,500f)"] = function() return CommF_:InvokeServer("BlackbeardReward", "Refund", "2") end,
	["Race Reroll (3,000f)"] = function() return CommF_:InvokeServer("BlackbeardReward", "Reroll", "2") end,
	["Cyborg Race (2,500f)"] = function() return CommF_:InvokeServer("CyborgTrainer", "Buy") end,
	["Ghoul Race (100 Ect)"] = function() return CommF_:InvokeServer("Ectoplasm", "Change", 4) end,
}

local function buyShopItem(itemName)
	if not CommF_ then return end
	task.spawn(function()
		pcall(function()
			CommF_:InvokeServer("BuyItem", itemName)
		end)
	end)
end

local NPCManagerModule = nil
task.spawn(function()
	while isAlive() and ((S.isChooseTeamScreenOpen and S.isChooseTeamScreenOpen()) or not LocalPlayer.Character) do
		task.wait(0.5)
	end
	if not isAlive() then return end
	pcall(function()
		local nm = ReplicatedStorage:FindFirstChild("NPCManager")
		if nm then
			NPCManagerModule = require(nm)
		end
	end)
end)

local storeAnyFruitsInInventory
local buyFruitFromStock
local rollRandomFruitGacha
local gachaStatusUpdater = nil
local stockStatusUpdater = nil

do
	local gachaBusy = false
	local stockBusy = false
	local cachedFruitPrices = nil

	-- Ordered strictly cheapest-first (< $1,000,000 Beli) for Raid Microchip sacrifice
	local LOW_BELI_FRUITS_ORDERED = {
		{key = "Rocket-Rocket",   price = 5000},
		{key = "Spin-Spin",       price = 7500},
		{key = "Blade-Blade",     price = 30000},
		{key = "Chop-Chop",       price = 30000},
		{key = "Spring-Spring",   price = 60000},
		{key = "Bomb-Bomb",       price = 80000},
		{key = "Smoke-Smoke",     price = 100000},
		{key = "Spike-Spike",     price = 180000},
		{key = "Flame-Flame",     price = 250000},
		{key = "Ice-Ice",         price = 350000},
		{key = "Sand-Sand",       price = 420000},
		{key = "Dark-Dark",       price = 500000},
		{key = "Eagle-Eagle",     price = 550000},
		{key = "Falcon-Falcon",   price = 550000},
		{key = "Diamond-Diamond", price = 600000},
		{key = "Light-Light",     price = 650000},
		{key = "Rubber-Rubber",   price = 750000},
		{key = "Ghost-Ghost",     price = 940000},
		{key = "Magma-Magma",     price = 960000},
	}

	-- Full reference price table for >= $1,000,000 fruits (used for price verification; NOT all are allowed for Trevor!)
	local HIGH_BELI_FRUITS_ORDERED = {
		{key = "Quake-Quake",                 price = 1000000},
		{key = "Buddha-Buddha",               price = 1200000},
		{key = "Human-Human: Buddha",         price = 1200000},
		{key = "Love-Love",                   price = 1300000},
		{key = "Creation-Creation",           price = 1400000},
		{key = "Barrier-Barrier",             price = 1400000},
		{key = "Spider-Spider",               price = 1500000},
		{key = "String-String",               price = 1500000},
		{key = "Sound-Sound",                 price = 1700000},
		{key = "Phoenix-Phoenix",             price = 1800000},
		{key = "Bird-Bird: Phoenix",          price = 1800000},
		{key = "Portal-Portal",               price = 1900000},
		{key = "Door-Door",                   price = 1900000},
		{key = "Rumble-Rumble",               price = 2100000},
		{key = "Lightning-Lightning",         price = 2100000},
		{key = "Pain-Pain",                   price = 2300000},
		{key = "Paw-Paw",                     price = 2300000},
		{key = "Blizzard-Blizzard",           price = 2400000},
		{key = "Gravity-Gravity",             price = 2500000},
		{key = "Mammoth-Mammoth",             price = 2700000},
		{key = "T-Rex-T-Rex",                 price = 2700000},
		{key = "Dough-Dough",                 price = 2800000},
		{key = "Shadow-Shadow",               price = 2900000},
		{key = "Venom-Venom",                 price = 3000000},
		{key = "Control-Control",             price = 3200000},
		{key = "Gas-Gas",                     price = 3200000},
		{key = "Spirit-Spirit",               price = 3400000},
		{key = "Soul-Soul",                   price = 3400000},
		{key = "Dragon-Dragon",               price = 3500000},
		{key = "Yeti-Yeti",                   price = 5000000},
		{key = "Leopard-Leopard",             price = 5000000},
		{key = "Kitsune-Kitsune",             price = 8000000},
		{key = "Dragon (East)-Dragon (East)", price = 15000000},
		{key = "Dragon (West)-Dragon (West)", price = 15000000},
	}

	-- STRICT WHITELIST for Sea 3 Trevor delivery (ONLY these 8 fruits in exact priority order):
	-- 1. Quake | 2. Love | 3. Creation | 4. Spider | 5. Sound | 6. Phoenix | 7. Pain | 8. Shadow
	local TREVOR_ALLOWED_FRUITS_ORDERED = {
		{key = "Quake-Quake",        prio = 1, price = 1000000},
		{key = "Love-Love",          prio = 2, price = 1300000},
		{key = "Creation-Creation",  prio = 3, price = 1400000},
		{key = "Barrier-Barrier",    prio = 3, price = 1400000},
		{key = "Spider-Spider",      prio = 4, price = 1500000},
		{key = "String-String",      prio = 4, price = 1500000},
		{key = "Sound-Sound",        prio = 5, price = 1700000},
		{key = "Phoenix-Phoenix",    prio = 6, price = 1800000},
		{key = "Bird-Bird: Phoenix", prio = 6, price = 1800000},
		{key = "Pain-Pain",          prio = 7, price = 2300000},
		{key = "Paw-Paw",            prio = 7, price = 2300000},
		{key = "Shadow-Shadow",      prio = 8, price = 2900000},
	}

	local TREVOR_ALLOWED_KEY_PRIO = {}
	for _, entry in ipairs(TREVOR_ALLOWED_FRUITS_ORDERED) do
		TREVOR_ALLOWED_KEY_PRIO[entry.key:lower()] = entry.prio
	end

	local TREVOR_ALLOWED_BASE_PRIO = {
		["quake"]    = 1,
		["love"]     = 2,
		["creation"] = 3,
		["spider"]   = 4,
		["sound"]    = 5,
		["phoenix"]  = 6,
		["pain"]     = 7,
		["shadow"]   = 8,
	}

	local function getTrevorAllowedPriority(storageKey, displayOrToolName)
		local skLow = tostring(storageKey or ""):lower()
		if TREVOR_ALLOWED_KEY_PRIO[skLow] then
			return TREVOR_ALLOWED_KEY_PRIO[skLow]
		end
		local cleanDisp = tostring(displayOrToolName or ""):lower():gsub("%s*fruit$", ""):gsub("^%s+", ""):gsub("%s+$", "")
		if TREVOR_ALLOWED_BASE_PRIO[cleanDisp] then
			return TREVOR_ALLOWED_BASE_PRIO[cleanDisp]
		end
		return nil
	end

	local function getFruitPriceMap()
		if cachedFruitPrices then return cachedFruitPrices end
		local map = {}
		for _, entry in ipairs(LOW_BELI_FRUITS_ORDERED) do
			map[entry.key] = entry.price
		end
		for _, entry in ipairs(HIGH_BELI_FRUITS_ORDERED) do
			map[entry.key] = entry.price
		end
		pcall(function()
			local fd = require(ReplicatedStorage.Controllers.UI.FruitShop.Data)
			if type(fd) == "table" then
				for k, v in pairs(fd) do
					if type(v) == "table" and tonumber(v.Price) then
						map[tostring(k)] = tonumber(v.Price)
					end
				end
			end
		end)
		cachedFruitPrices = map
		return map
	end

	local function isPhysicalFruitTool(tool)
		if not tool or not tool:IsA("Tool") then return false end
		if tool.ToolTip == "Blox Fruit" then return false end -- Eaten / equipped Blox Fruit power
		return (tool.Name:find(" Fruit") ~= nil)
			or (tool:GetAttribute("OriginalName") ~= nil and tostring(tool:GetAttribute("OriginalName")):find("-") ~= nil)
			or (tool:FindFirstChild("EatRemote") ~= nil)
	end

	local function getVerifiedToolStorageKeyAndPrice(tool)
		local base = tool.Name:gsub(" Fruit$", "")
		local origName = tostring(tool:GetAttribute("OriginalName") or (base .. "-" .. base))
		local pMap = getFruitPriceMap()
		local exactPrice = pMap[origName] or pMap[base .. "-" .. base]
		return origName, exactPrice
	end

	local function getToolStorageKeyAndPrice(tool)
		local origName, exactPrice = getVerifiedToolStorageKeyAndPrice(tool)
		return origName, (exactPrice or 99999999)
	end

	local function hasSpecialMicrochipTool()
		for _, cont in ipairs({LocalPlayer:FindFirstChild("Backpack"), LocalPlayer.Character}) do
			if cont then
				local t = cont:FindFirstChild("Special Microchip")
				if t and t:IsA("Tool") then
					return t
				end
			end
		end
		return nil
	end
	S.hasSpecialMicrochipTool = hasSpecialMicrochipTool

	local failedStoreCooldown = setmetatable({}, {__mode = "k"})

	storeAnyFruitsInInventory = function()
		if not S.autoStoreFruits or not CommF_ then return end
		if (S.isChooseTeamScreenOpen and S.isChooseTeamScreenOpen()) or not LocalPlayer.Character then return end
		pcall(function()
			-- If "Get Fruit in Inventory Low Beli" is active and player still needs a Raid Microchip,
			-- keep 1 cheapest (< 1M Beli) physical fruit in Backpack so RaidsNpc trades it for the chip!
			local keepOneLowFruit = S.getLowBeliFruit and (not S.autoSecondSeaComplete) and (hasSpecialMicrochipTool() == nil)
			local protectedTool = nil
			local bestLowPrice = 1000000

			-- Protect ONLY the single whitelisted fruit (Quake/Love/Creation/Spider/Sound/Phoenix/Pain/Shadow) for Trevor
			local trevorProtected = nil
			if S.autoSecondSeaComplete and S.trevorDeliveryActive then
				if S.protectedTrevorFruitTool and S.protectedTrevorFruitTool.Parent then
					local sk0 = getVerifiedToolStorageKeyAndPrice(S.protectedTrevorFruitTool)
					if getTrevorAllowedPriority(sk0, S.protectedTrevorFruitTool.Name) then
						trevorProtected = S.protectedTrevorFruitTool
					end
				end
				if not trevorProtected then
					local bestPrio = math.huge
					for _, cont in ipairs({LocalPlayer.Character, LocalPlayer:FindFirstChild("Backpack")}) do
						if cont then
							for _, tool in ipairs(cont:GetChildren()) do
								if isPhysicalFruitTool(tool) then
									local sk, vPrice = getVerifiedToolStorageKeyAndPrice(tool)
									local prio = getTrevorAllowedPriority(sk, tool.Name)
									if prio and (not vPrice or vPrice >= 1000000) and prio < bestPrio then
										bestPrio = prio
										trevorProtected = tool
									end
								end
							end
						end
					end
					S.protectedTrevorFruitTool = trevorProtected
				end
			end

			local containers = {LocalPlayer:FindFirstChild("Backpack"), LocalPlayer.Character}
			if keepOneLowFruit then
				for _, cont in ipairs(containers) do
					if cont then
						for _, tool in ipairs(cont:GetChildren()) do
							if isPhysicalFruitTool(tool) and tool ~= trevorProtected then
								local _, price = getToolStorageKeyAndPrice(tool)
								if price < bestLowPrice then
									bestLowPrice = price
									protectedTool = tool
								end
							end
						end
					end
				end
			end

			local now = os.clock()
			for _, cont in ipairs(containers) do
				if cont then
					for _, tool in ipairs(cont:GetChildren()) do
						if isPhysicalFruitTool(tool) and tool ~= protectedTool and tool ~= trevorProtected then
							if now >= (failedStoreCooldown[tool] or 0) then
								local origName = getToolStorageKeyAndPrice(tool)
								local ok, res = pcall(function()
									return CommF_:InvokeServer("StoreFruit", origName, tool)
								end)
								if (not ok) or res == false or (tool.Parent == LocalPlayer.Character or tool.Parent == LocalPlayer:FindFirstChild("Backpack")) then
									-- Storage slot full (e.g. 1/1): wait 25s before retrying this tool so we never spam remotes!
									failedStoreCooldown[tool] = os.clock() + 25.0
								end
							end
						end
					end
				end
			end
		end)
	end
	S.storeAnyFruitsInInventory = storeAnyFruitsInInventory

	-- Safely stores away any non-whitelisted physical fruit in Character/Backpack before talking to Trevor
	-- so Trevor NEVER consumes Buddha, Portal, Dough, Kitsune, Dragon, etc.!
	S.safeguardOtherFruitsBeforeTrevor = function(allowedTool)
		if not CommF_ then return false end
		local hasUnsafeHighFruit = false
		for _, cont in ipairs({LocalPlayer.Character, LocalPlayer:FindFirstChild("Backpack")}) do
			if cont then
				for _, tool in ipairs(cont:GetChildren()) do
					if isPhysicalFruitTool(tool) and tool ~= allowedTool then
						local origName, vPrice = getVerifiedToolStorageKeyAndPrice(tool)
						pcall(function()
							CommF_:InvokeServer("StoreFruit", origName, tool)
						end)
						task.wait(0.1)
						if tool.Parent == LocalPlayer.Character or tool.Parent == LocalPlayer:FindFirstChild("Backpack") then
							if not vPrice or vPrice >= 1000000 then
								hasUnsafeHighFruit = true
							end
						end
					end
				end
			end
		end
		return not hasUnsafeHighFruit
	end

	-- Returns an already-held whitelisted fruit (Quake/Love/Creation/Spider/Sound/Phoenix/Pain/Shadow) in Character/Backpack
	S.getHeldTrevorMin1MFruit = function()
		if S.protectedTrevorFruitTool then
			local p = S.protectedTrevorFruitTool.Parent
			if p == LocalPlayer.Character or p == LocalPlayer:FindFirstChild("Backpack") then
				local sk, vPrice = getVerifiedToolStorageKeyAndPrice(S.protectedTrevorFruitTool)
				local prio = getTrevorAllowedPriority(sk, S.protectedTrevorFruitTool.Name)
				if prio then
					return S.protectedTrevorFruitTool, sk, (vPrice or 1000000)
				end
			end
		end
		local bestTool, bestKey, bestPrice, bestPrio = nil, nil, math.huge, math.huge
		for _, cont in ipairs({LocalPlayer.Character, LocalPlayer:FindFirstChild("Backpack")}) do
			if cont then
				for _, tool in ipairs(cont:GetChildren()) do
					if isPhysicalFruitTool(tool) then
						local sk, vPrice = getVerifiedToolStorageKeyAndPrice(tool)
						local prio = getTrevorAllowedPriority(sk, tool.Name)
						if prio and prio < bestPrio then
							bestPrio = prio
							bestTool = tool
							bestKey = sk
							bestPrice = vPrice or 1000000
						end
					end
				end
			end
		end
		if bestTool then
			S.protectedTrevorFruitTool = bestTool
			return bestTool, bestKey, bestPrice
		end
		return nil
	end

	-- Unstores ONLY ONE whitelisted fruit for Sea 3 (Quake, Love, Creation, Spider, Sound, Phoenix, Pain, or Shadow)
	S.unstoreTrevorMin1MFruit = function()
		if not CommF_ then return nil end

		local heldTool, heldKey, heldPrice = S.getHeldTrevorMin1MFruit()
		if heldTool then
			return heldTool, heldKey, heldPrice
		end

		local pMap = getFruitPriceMap()
		local candidates = {}
		local seenKeys = {}
		local queriedAnySource = false

		-- 1) Authoritative server inventory query (CommF_:InvokeServer("getInventory"))
		pcall(function()
			local inv = CommF_:InvokeServer("getInventory")
			if type(inv) == "table" then
				queriedAnySource = true
				for _, item in ipairs(inv) do
					if type(item) == "table" and tostring(item.Type or "") == "Blox Fruit" and (tonumber(item.Count) or 1) > 0 then
						local sk = tostring(item.Name or "")
						local disp = tostring(item.DisplayName or item.Name or "")
						local prio = getTrevorAllowedPriority(sk, disp)
						local val = tonumber(item.Value) or pMap[sk] or 1000000
						if sk ~= "" and prio and val >= 1000000 and not seenKeys[sk] then
							seenKeys[sk] = true
							cachedFruitPrices[sk] = val
							table.insert(candidates, {key = sk, prio = prio, price = val})
						end
					end
				end
			end
		end)

		-- 2) Fallback modern Inventory.RemoteUtil tiles (strictly whitelisted fruits only)
		if #candidates == 0 then
			pcall(function()
				local ru = require(ReplicatedStorage.Controllers.UI.Inventory.RemoteUtil)
				local idMod = debug and debug.getupvalue and debug.getupvalue(ru.invokeAction, 4)
				local prom = ru.getTiles()
				local tiles = nil
				if type(prom) == "table" then
					if type(prom.await) == "function" then
						local a, b = prom:await()
						tiles = (type(a) == "table" and a) or (type(b) == "table" and b)
					elseif type(prom._get) == "function" then
						local a, b = prom:_get()
						tiles = (type(a) == "table" and a) or (type(b) == "table" and b)
					end
				end
				if type(tiles) == "table" and type(idMod) == "table" and type(idMod.getDataFromId) == "function" then
					queriedAnySource = true
					for _, tile in pairs(tiles) do
						if type(tile) == "table" and tile.ItemId then
							local okD, data = pcall(function() return idMod.getDataFromId(tile.ItemId):unwrap() end)
							if okD and type(data) == "table" and tostring(data.Type or "") == "PhysicalMoveset" and data.StorageKey then
								local sk = tostring(data.StorageKey)
								local disp = tostring(data.DisplayName or data.Name or sk)
								local prio = getTrevorAllowedPriority(sk, disp)
								local pr = pMap[sk] or 1000000
								if prio and pr >= 1000000 and not seenKeys[sk] then
									seenKeys[sk] = true
									table.insert(candidates, {key = sk, prio = prio, price = pr})
								end
							end
						end
					end
				end
			end)
		end

		-- 3) Last-resort fallback ONLY if neither inventory API responded (tries ONLY the 8 whitelisted keys in order)
		if #candidates == 0 and not queriedAnySource then
			for _, entry in ipairs(TREVOR_ALLOWED_FRUITS_ORDERED) do
				table.insert(candidates, {key = entry.key, prio = entry.prio, price = entry.price})
			end
		end

		if #candidates == 0 then
			return nil
		end

		table.sort(candidates, function(a, b)
			if a.prio ~= b.prio then return a.prio < b.prio end
			if a.price ~= b.price then return a.price < b.price end
			return a.key < b.key
		end)

		-- Unstore ONLY the single highest-priority (cheapest) whitelisted fruit!
		for _, chosen in ipairs(candidates) do
			pcall(function()
				local char = LocalPlayer.Character
				local busyVal = char and char:FindFirstChild("Busy")
				if busyVal and busyVal:IsA("BoolValue") then
					busyVal.Value = false
				end
				CommF_:InvokeServer("LoadFruit", chosen.key)
			end)
			task.wait(0.22)

			local loadedTool, loadedKey, loadedPrice = S.getHeldTrevorMin1MFruit()
			if loadedTool then
				return loadedTool, loadedKey, loadedPrice
			end
			if queriedAnySource then
				break
			end
		end

		return nil
	end

	-- Unstores the single cheapest (< 1,000,000 Beli) physical fruit from Inventory into Backpack
	S.unstoreLowestBeliFruit = function(reportFn)
		if not CommF_ then return nil end

		-- 1) Check if a < 1M physical fruit is already in Backpack / Character
		for _, cont in ipairs({LocalPlayer:FindFirstChild("Backpack"), LocalPlayer.Character}) do
			if cont then
				for _, tool in ipairs(cont:GetChildren()) do
					if isPhysicalFruitTool(tool) then
						local sk, price = getToolStorageKeyAndPrice(tool)
						if price < 1000000 then
							return tool, sk, price
						end
					end
				end
			end
		end

		local pMap = getFruitPriceMap()
		local candidates = {}

		-- 2) Query modern Blox Fruits Inventory.RemoteUtil tiles (exact owned fruits)
		pcall(function()
			local ru = require(ReplicatedStorage.Controllers.UI.Inventory.RemoteUtil)
			local idMod = debug and debug.getupvalue and debug.getupvalue(ru.invokeAction, 4)
			local prom = ru.getTiles()
			local tiles = nil
			if type(prom) == "table" then
				if type(prom.await) == "function" then
					local a, b = prom:await()
					tiles = (type(a) == "table" and a) or (type(b) == "table" and b)
				elseif type(prom._get) == "function" then
					local a, b = prom:_get()
					tiles = (type(a) == "table" and a) or (type(b) == "table" and b)
				end
			end
			if type(tiles) == "table" and type(idMod) == "table" and type(idMod.getDataFromId) == "function" then
				for _, tile in pairs(tiles) do
					if type(tile) == "table" and tile.ItemId then
						local okD, data = pcall(function() return idMod.getDataFromId(tile.ItemId):unwrap() end)
						if okD and type(data) == "table" and tostring(data.Type or "") == "PhysicalMoveset" and data.StorageKey then
							local sk = tostring(data.StorageKey)
							local pr = pMap[sk] or 99999999
							if pr < 1000000 then
								table.insert(candidates, {key = sk, price = pr})
							end
						end
					end
				end
			end
		end)

		table.sort(candidates, function(a, b)
			if a.price ~= b.price then return a.price < b.price end
			return a.key < b.key
		end)

		local tryOrder = (#candidates > 0) and candidates or LOW_BELI_FRUITS_ORDERED
		for _, item in ipairs(tryOrder) do
			pcall(function()
				CommF_:InvokeServer("LoadFruit", item.key)
			end)
			task.wait(0.18)
			for _, cont in ipairs({LocalPlayer:FindFirstChild("Backpack"), LocalPlayer.Character}) do
				if cont then
					for _, tool in ipairs(cont:GetChildren()) do
						if isPhysicalFruitTool(tool) then
							local sk, price = getToolStorageKeyAndPrice(tool)
							if price < 1000000 then
								if reportFn then
									pcall(reportFn, string.format("🍎 Fruta Low Beli sacada: %s ($%d)", tool.Name, price))
								end
								return tool, sk, price
							end
						end
					end
				end
			end
			-- If candidates came from exact owned tiles, 1 attempt is enough unless busy
			if #candidates > 0 then
				break
			end
		end

		return nil
	end

	-- Long-Distance Blox Fruit Dealer Stock Purchase (NO NPC approach / NO movement!)
	buyFruitFromStock = function(fruitName, uiCallback)
		if not CommF_ or not fruitName or stockBusy then return end
		stockBusy = true

		task.spawn(function()
			local function report(txt)
				setStatus(txt)
				if uiCallback then pcall(uiCallback, txt) end
				if stockStatusUpdater then pcall(stockStatusUpdater, txt) end
			end

			pcall(function()
				ensureTeamSelected()
				report("🛒 Comprando a larga distancia: " .. tostring(fruitName) .. "...")

				-- Ensure Character.Busy is false so server accepts remote stock purchase
				local char = LocalPlayer.Character
				local busyVal = char and char:FindFirstChild("Busy")
				if busyVal and busyVal:IsA("BoolValue") then
					busyVal.Value = false
				end

				pcall(function()
					CommF_:InvokeServer("GetFruits")
				end)

				local res = CommF_:InvokeServer("PurchaseRawFruit", fruitName, false)
				if res == false or res == nil then
					-- Also try AdvancedFruitDealer flag in case fruit is in Mirage stock
					local advRes = nil
					pcall(function()
						advRes = CommF_:InvokeServer("PurchaseRawFruit", fruitName, true)
					end)
					if advRes then res = advRes end
				end

				if res == true then
					report("🛒 ¡Fruta comprada a larga distancia: " .. tostring(fruitName) .. "!")
				else
					report(string.format("🛒 Dealer Stock (%s): %s", tostring(fruitName), tostring(res or "No disponible / Sin Beli")))
				end
			end)

			stockBusy = false
		end)
	end

	-- Long-Distance Random Devil Fruit Gacha via GachaClient (NO NPC approach / NO movement!)
	rollRandomFruitGacha = function(uiCallback)
		if gachaBusy then return end
		gachaBusy = true

		task.spawn(function()
			local function report(txt)
				setStatus(txt)
				if uiCallback then pcall(uiCallback, txt) end
				if gachaStatusUpdater then pcall(gachaStatusUpdater, txt) end
			end

			pcall(function()
				ensureTeamSelected()

				-- Snapshot pre-existing physical fruit tools so we detect the newly rolled fruit accurately
				local beforeTools = {}
				for _, cont in ipairs({LocalPlayer:FindFirstChild("Backpack"), LocalPlayer.Character}) do
					if cont then
						for _, t in ipairs(cont:GetChildren()) do
							if isPhysicalFruitTool(t) then
								beforeTools[t] = true
							end
						end
					end
				end

				report("🎰 Comprando Random Devil Fruit a larga distancia...")

				local gachaClient = nil
				pcall(function()
					gachaClient = require(ReplicatedStorage.Controllers.GachaClient)
				end)

				local checkInfo = nil
				if gachaClient and type(gachaClient.CheckGachaAsync) == "function" then
					pcall(function()
						checkInfo = gachaClient.CheckGachaAsync("GachaData", true)
					end)
				end

				local purchaseRes = nil
				if gachaClient and type(gachaClient.PurchaseGachaAsync) == "function" then
					pcall(function()
						purchaseRes = gachaClient.PurchaseGachaAsync("GachaData")
					end)
				end

				-- Direct RF/GachaNetworkRF & Cousin fallbacks
				if purchaseRes == nil then
					pcall(function()
						local net = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("Net")
						local rf = net and net:FindFirstChild("RF/GachaNetworkRF")
						if rf and rf:IsA("RemoteFunction") then
							purchaseRes = rf:InvokeServer({Context = "Purchase", BoxName = "GachaData"})
						end
					end)
				end
				if CommF_ then
					pcall(function() CommF_:InvokeServer("Cousin", "Buy") end)
				end

				task.wait(0.4)

				local newFruitName = nil
				for _, cont in ipairs({LocalPlayer:FindFirstChild("Backpack"), LocalPlayer.Character}) do
					if cont then
						for _, t in ipairs(cont:GetChildren()) do
							if isPhysicalFruitTool(t) and not beforeTools[t] then
								newFruitName = t.Name
								break
							end
						end
					end
					if newFruitName then break end
				end

				storeAnyFruitsInInventory()

				if newFruitName then
					report("🎰 ¡Fruta obtenida a distancia: " .. newFruitName .. (S.autoStoreFruits and " (Guardada)!" or "!"))
				elseif type(checkInfo) == "table" then
					local cd = tonumber(checkInfo.Cooldown) or 0
					if cd > 0 then
						local mins = math.max(1, math.ceil(cd / 60))
						report(string.format("🎰 Random Fruit en enfriamiento (%d min restantes)", mins))
					elseif checkInfo.ErrorMessage and tostring(checkInfo.ErrorMessage) ~= "" then
						report("🎰 Random Fruit: " .. tostring(checkInfo.ErrorMessage))
					else
						report("🎰 Random Fruit solicitada (" .. tostring(purchaseRes or "En enfriamiento / Sin Beli") .. ")")
					end
				else
					report("🎰 Random Fruit solicitada a distancia (En enfriamiento de 2h o sin Beli)")
				end
			end)

			gachaBusy = false
		end)
	end
end

--------------------------------------------------------------------------------
-- PIXEL-ACCURATE SWITCH HUB UI + SLIDE-DOWN DRAWER COMPONENTS
--------------------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SwitchHub_BloxFruits"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 9500
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = guiParent

local C = {
	WindowBg       = Color3.fromRGB(22, 22, 25),
	WindowBorder   = Color3.fromRGB(38, 38, 43),
	SidebarBg      = Color3.fromRGB(18, 18, 20),
	SidebarActive  = Color3.fromRGB(27, 27, 31),
	TopBarBg       = Color3.fromRGB(26, 26, 30),
	ContentBg      = Color3.fromRGB(22, 22, 25),
	CardBg         = Color3.fromRGB(19, 19, 22),
	CardBorder     = Color3.fromRGB(35, 35, 40),
	DrawerBg       = Color3.fromRGB(14, 14, 17),
	DrawerItemBg   = Color3.fromRGB(22, 22, 27),
	DrawerActiveBg = Color3.fromRGB(28, 42, 68),
	Divider        = Color3.fromRGB(32, 32, 37),
	SearchBg       = Color3.fromRGB(16, 16, 19),
	SearchBorder   = Color3.fromRGB(38, 38, 44),
	TextWhite      = Color3.fromRGB(242, 242, 247),
	TextSub        = Color3.fromRGB(128, 128, 138),
	TextMuted      = Color3.fromRGB(102, 102, 112),
	ToggleOff      = Color3.fromRGB(72, 72, 78),
	ToggleOn       = Color3.fromRGB(59, 130, 246),
	SliderFill     = Color3.fromRGB(59, 130, 246),
	SliderTrack    = Color3.fromRGB(42, 42, 48),
	DotGreen       = Color3.fromRGB(48, 209, 88),
	DotYellow      = Color3.fromRGB(255, 214, 10),
	DotRed         = Color3.fromRGB(255, 69, 58),
	Gold           = Color3.fromRGB(197, 155, 39),
}

local MainWindow = Instance.new("Frame")
MainWindow.Name = "MainWindow"
MainWindow.Size = UDim2.new(0, 690, 0, 470)
MainWindow.AnchorPoint = Vector2.new(0.5, 0.5)
MainWindow.Position = UDim2.new(0.5, 0, 0.5, 0)
MainWindow.BackgroundColor3 = C.WindowBg
MainWindow.BorderSizePixel = 0
MainWindow.ClipsDescendants = true
MainWindow.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainWindow

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = C.WindowBorder
MainStroke.Thickness = 1
MainStroke.Parent = MainWindow

-- Draggable via top bar
do
	local dragging, dragInput, dragStart, startPos
	connect(MainWindow.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local relY = input.Position.Y - MainWindow.AbsolutePosition.Y
			if relY <= 52 then
				dragging = true
				dragStart = input.Position
				startPos = MainWindow.Position
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						dragging = false
					end
				end)
			end
		end
	end)
	connect(MainWindow.InputChanged, function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			dragInput = input
		end
	end)
	connect(UserInputService.InputChanged, function(input)
		if input == dragInput and dragging then
			local delta = input.Position - dragStart
			MainWindow.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
	end)
end

--------------------------------------------------------------------------------
-- LEFT SIDEBAR (186px wide)
--------------------------------------------------------------------------------
local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 186, 1, 0)
Sidebar.BackgroundColor3 = C.SidebarBg
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainWindow

local SidebarCorner = Instance.new("UICorner")
SidebarCorner.CornerRadius = UDim.new(0, 10)
SidebarCorner.Parent = Sidebar

local SidebarRightLine = Instance.new("Frame")
SidebarRightLine.Size = UDim2.new(0, 1, 1, 0)
SidebarRightLine.Position = UDim2.new(1, -1, 0, 0)
SidebarRightLine.BackgroundColor3 = C.Divider
SidebarRightLine.BorderSizePixel = 0
SidebarRightLine.Parent = Sidebar

local HubTitle = Instance.new("TextLabel")
HubTitle.Size = UDim2.new(1, -28, 0, 20)
HubTitle.Position = UDim2.new(0, 16, 0, 12)
HubTitle.BackgroundTransparency = 1
HubTitle.Text = "Switch Hub"
HubTitle.Font = Enum.Font.GothamMedium
HubTitle.TextSize = 15
HubTitle.TextColor3 = C.TextWhite
HubTitle.TextXAlignment = Enum.TextXAlignment.Left
HubTitle.Parent = Sidebar

local HubSub = Instance.new("TextLabel")
HubSub.Size = UDim2.new(1, -28, 0, 16)
HubSub.Position = UDim2.new(0, 16, 0, 31)
HubSub.BackgroundTransparency = 1
HubSub.Text = "ver. Blox Fruits"
HubSub.Font = Enum.Font.Gotham
HubSub.TextSize = 11
HubSub.TextColor3 = C.TextSub
HubSub.TextXAlignment = Enum.TextXAlignment.Left
HubSub.Parent = Sidebar

local SideSearchFrame = Instance.new("Frame")
SideSearchFrame.Size = UDim2.new(1, -24, 0, 34)
SideSearchFrame.Position = UDim2.new(0, 12, 0, 56)
SideSearchFrame.BackgroundColor3 = C.SearchBg
SideSearchFrame.BorderSizePixel = 0
SideSearchFrame.Parent = Sidebar

local SideSearchCorner = Instance.new("UICorner")
SideSearchCorner.CornerRadius = UDim.new(0, 8)
SideSearchCorner.Parent = SideSearchFrame

local SideSearchStroke = Instance.new("UIStroke")
SideSearchStroke.Color = C.SearchBorder
SideSearchStroke.Thickness = 1
SideSearchStroke.Parent = SideSearchFrame

local SideSearchBox = Instance.new("TextBox")
SideSearchBox.Size = UDim2.new(1, -34, 1, 0)
SideSearchBox.Position = UDim2.new(0, 10, 0, 0)
SideSearchBox.BackgroundTransparency = 1
SideSearchBox.Text = ""
SideSearchBox.PlaceholderText = "Searchable."
SideSearchBox.PlaceholderColor3 = C.TextMuted
SideSearchBox.TextColor3 = C.TextWhite
SideSearchBox.Font = Enum.Font.Gotham
SideSearchBox.TextSize = 12
SideSearchBox.TextXAlignment = Enum.TextXAlignment.Left
SideSearchBox.ClearTextOnFocus = false
SideSearchBox.Parent = SideSearchFrame

local function createSearchIcon(parent)
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(0, 16, 0, 16)
	holder.Position = UDim2.new(1, -24, 0.5, -8)
	holder.BackgroundTransparency = 1
	holder.Parent = parent

	local ring = Instance.new("Frame")
	ring.Size = UDim2.new(0, 11, 0, 11)
	ring.Position = UDim2.new(0, 1, 0, 1)
	ring.BackgroundTransparency = 1
	ring.Parent = holder
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(1, 0)
	rc.Parent = ring
	local rs = Instance.new("UIStroke")
	rs.Color = C.TextMuted
	rs.Thickness = 1.4
	rs.Parent = ring

	local handle = Instance.new("Frame")
	handle.Size = UDim2.new(0, 5, 0, 1.5)
	handle.Position = UDim2.new(0, 10, 0, 12)
	handle.Rotation = 45
	handle.BackgroundColor3 = C.TextMuted
	handle.BorderSizePixel = 0
	handle.Parent = holder
end
createSearchIcon(SideSearchFrame)

local SideTopDiv = Instance.new("Frame")
SideTopDiv.Size = UDim2.new(1, -1, 0, 1)
SideTopDiv.Position = UDim2.new(0, 0, 0, 100)
SideTopDiv.BackgroundColor3 = C.Divider
SideTopDiv.BorderSizePixel = 0
SideTopDiv.Parent = Sidebar

local TabsScroll = Instance.new("ScrollingFrame")
TabsScroll.Size = UDim2.new(1, -1, 1, -160)
TabsScroll.Position = UDim2.new(0, 0, 0, 101)
TabsScroll.BackgroundTransparency = 1
TabsScroll.BorderSizePixel = 0
TabsScroll.ScrollBarThickness = 2
TabsScroll.ScrollBarImageColor3 = Color3.fromRGB(55, 55, 65)
TabsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
TabsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
TabsScroll.Parent = Sidebar

local TabsListLayout = Instance.new("UIListLayout")
TabsListLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabsListLayout.Padding = UDim.new(0, 0)
TabsListLayout.Parent = TabsScroll

local ProfileFooter = Instance.new("Frame")
ProfileFooter.Size = UDim2.new(1, -1, 0, 59)
ProfileFooter.Position = UDim2.new(0, 0, 1, -59)
ProfileFooter.BackgroundColor3 = Color3.fromRGB(16, 16, 18)
ProfileFooter.BorderSizePixel = 0
ProfileFooter.Parent = Sidebar

local ProfileTopLine = Instance.new("Frame")
ProfileTopLine.Size = UDim2.new(1, 0, 0, 1)
ProfileTopLine.BackgroundColor3 = C.Divider
ProfileTopLine.BorderSizePixel = 0
ProfileTopLine.Parent = ProfileFooter

local AvatarImg = Instance.new("ImageLabel")
AvatarImg.Size = UDim2.new(0, 36, 0, 36)
AvatarImg.Position = UDim2.new(0, 12, 0.5, -18)
AvatarImg.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
AvatarImg.BorderSizePixel = 0
AvatarImg.Parent = ProfileFooter

local AvatarCorner = Instance.new("UICorner")
AvatarCorner.CornerRadius = UDim.new(1, 0)
AvatarCorner.Parent = AvatarImg

local AvatarStroke = Instance.new("UIStroke")
AvatarStroke.Color = Color3.fromRGB(115, 88, 32)
AvatarStroke.Thickness = 1.5
AvatarStroke.Parent = AvatarImg

task.spawn(function()
	local ok, content = pcall(function()
		return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
	end)
	if ok and content then
		AvatarImg.Image = content
	end
end)

local WelcomeLabel = Instance.new("TextLabel")
WelcomeLabel.Size = UDim2.new(0, 86, 0, 18)
WelcomeLabel.Position = UDim2.new(0, 56, 0, 12)
WelcomeLabel.BackgroundTransparency = 1
WelcomeLabel.Text = "Welcome"
WelcomeLabel.Font = Enum.Font.GothamMedium
WelcomeLabel.TextSize = 13
WelcomeLabel.TextColor3 = C.TextWhite
WelcomeLabel.TextXAlignment = Enum.TextXAlignment.Left
WelcomeLabel.Parent = ProfileFooter

local UserSubLabel = Instance.new("TextLabel")
UserSubLabel.Size = UDim2.new(0, 86, 0, 16)
UserSubLabel.Position = UDim2.new(0, 56, 0, 29)
UserSubLabel.BackgroundTransparency = 1
UserSubLabel.Text = LocalPlayer.Name:sub(1, 10) .. "..."
UserSubLabel.Font = Enum.Font.Gotham
UserSubLabel.TextSize = 11
UserSubLabel.TextColor3 = C.TextSub
UserSubLabel.TextXAlignment = Enum.TextXAlignment.Left
UserSubLabel.Parent = ProfileFooter

local CrownLabel = Instance.new("TextLabel")
CrownLabel.Size = UDim2.new(0, 24, 0, 24)
CrownLabel.Position = UDim2.new(1, -34, 0.5, -12)
CrownLabel.BackgroundTransparency = 1
CrownLabel.Text = "👑"
CrownLabel.TextSize = 15
CrownLabel.TextColor3 = C.Gold
CrownLabel.Parent = ProfileFooter

--------------------------------------------------------------------------------
-- RIGHT CONTENT AREA (504px wide)
--------------------------------------------------------------------------------
local RightPanel = Instance.new("Frame")
RightPanel.Name = "RightPanel"
RightPanel.Size = UDim2.new(1, -186, 1, 0)
RightPanel.Position = UDim2.new(0, 186, 0, 0)
RightPanel.BackgroundColor3 = C.ContentBg
RightPanel.BorderSizePixel = 0
RightPanel.Parent = MainWindow

local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, 50)
TopBar.BackgroundColor3 = C.TopBarBg
TopBar.BorderSizePixel = 0
TopBar.Parent = RightPanel

local TopBarBottomLine = Instance.new("Frame")
TopBarBottomLine.Size = UDim2.new(1, 0, 0, 1)
TopBarBottomLine.Position = UDim2.new(0, 0, 1, -1)
TopBarBottomLine.BackgroundColor3 = C.Divider
TopBarBottomLine.BorderSizePixel = 0
TopBarBottomLine.Parent = TopBar

local DotsBtn = Instance.new("TextButton")
DotsBtn.Size = UDim2.new(0, 32, 0, 32)
DotsBtn.Position = UDim2.new(0, 14, 0.5, -16)
DotsBtn.BackgroundTransparency = 1
DotsBtn.Text = "•••"
DotsBtn.Font = Enum.Font.GothamBold
DotsBtn.TextSize = 15
DotsBtn.TextColor3 = C.TextWhite
DotsBtn.Parent = TopBar

local TopTabTitle = Instance.new("TextLabel")
TopTabTitle.Size = UDim2.new(0, 130, 0, 18)
TopTabTitle.Position = UDim2.new(0, 56, 0, 8)
TopTabTitle.BackgroundTransparency = 1
TopTabTitle.Text = "Farming"
TopTabTitle.Font = Enum.Font.GothamMedium
TopTabTitle.TextSize = 14
TopTabTitle.TextColor3 = C.TextWhite
TopTabTitle.TextXAlignment = Enum.TextXAlignment.Left
TopTabTitle.Parent = TopBar

local TopTabSub = Instance.new("TextLabel")
TopTabSub.Size = UDim2.new(0, 130, 0, 15)
TopTabSub.Position = UDim2.new(0, 56, 0, 26)
TopTabSub.BackgroundTransparency = 1
TopTabSub.Text = "Farming Features"
TopTabSub.Font = Enum.Font.Gotham
TopTabSub.TextSize = 11
TopTabSub.TextColor3 = C.TextSub
TopTabSub.TextXAlignment = Enum.TextXAlignment.Left
TopTabSub.Parent = TopBar

local OptSearchFrame = Instance.new("Frame")
OptSearchFrame.Size = UDim2.new(0, 224, 0, 32)
OptSearchFrame.Position = UDim2.new(0, 194, 0.5, -16)
OptSearchFrame.BackgroundColor3 = C.SearchBg
OptSearchFrame.BorderSizePixel = 0
OptSearchFrame.Parent = TopBar

local OptSearchCorner = Instance.new("UICorner")
OptSearchCorner.CornerRadius = UDim.new(0, 8)
OptSearchCorner.Parent = OptSearchFrame

local OptSearchStroke = Instance.new("UIStroke")
OptSearchStroke.Color = C.SearchBorder
OptSearchStroke.Thickness = 1
OptSearchStroke.Parent = OptSearchFrame

local OptSearchBox = Instance.new("TextBox")
OptSearchBox.Size = UDim2.new(1, -34, 1, 0)
OptSearchBox.Position = UDim2.new(0, 10, 0, 0)
OptSearchBox.BackgroundTransparency = 1
OptSearchBox.Text = ""
OptSearchBox.PlaceholderText = "Search Option."
OptSearchBox.PlaceholderColor3 = C.TextMuted
OptSearchBox.TextColor3 = C.TextWhite
OptSearchBox.Font = Enum.Font.Gotham
OptSearchBox.TextSize = 12
OptSearchBox.TextXAlignment = Enum.TextXAlignment.Left
OptSearchBox.ClearTextOnFocus = false
OptSearchBox.Parent = OptSearchFrame

createSearchIcon(OptSearchFrame)

local PrevTabBtn = Instance.new("TextButton")
PrevTabBtn.Size = UDim2.new(0, 26, 0, 26)
PrevTabBtn.Position = UDim2.new(1, -68, 0.5, -13)
PrevTabBtn.BackgroundTransparency = 1
PrevTabBtn.Text = "‹"
PrevTabBtn.Font = Enum.Font.Gotham
PrevTabBtn.TextSize = 22
PrevTabBtn.TextColor3 = C.TextSub
PrevTabBtn.Parent = TopBar

local NextTabBtn = Instance.new("TextButton")
NextTabBtn.Size = UDim2.new(0, 26, 0, 26)
NextTabBtn.Position = UDim2.new(1, -38, 0.5, -13)
NextTabBtn.BackgroundTransparency = 1
NextTabBtn.Text = "›"
NextTabBtn.Font = Enum.Font.Gotham
NextTabBtn.TextSize = 22
NextTabBtn.TextColor3 = C.TextSub
NextTabBtn.Parent = TopBar

local PagesHolder = Instance.new("Frame")
PagesHolder.Name = "PagesHolder"
PagesHolder.Size = UDim2.new(1, 0, 1, -50)
PagesHolder.Position = UDim2.new(0, 0, 0, 50)
PagesHolder.BackgroundTransparency = 1
PagesHolder.Parent = RightPanel

--------------------------------------------------------------------------------
-- SIDEBAR TAB ICONS
--------------------------------------------------------------------------------
local function drawTabCustomIcon(parent, iconType)
	local box = Instance.new("Frame")
	box.Name = "TabIcon"
	box.Size = UDim2.new(0, 22, 0, 22)
	box.Position = UDim2.new(1, -34, 0.5, -11)
	box.BackgroundTransparency = 1
	box.Parent = parent

	local parts = {}
	local function addLine(w, h, x, y, rot)
		local f = Instance.new("Frame")
		f.Size = UDim2.new(0, w, 0, h)
		f.Position = UDim2.new(0, x, 0, y)
		f.Rotation = rot or 0
		f.BackgroundColor3 = C.TextSub
		f.BorderSizePixel = 0
		f.Parent = box
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = f
		table.insert(parts, f)
		return f
	end
	local function addRing(sz, x, y)
		local f = Instance.new("Frame")
		f.Size = UDim2.new(0, sz, 0, sz)
		f.Position = UDim2.new(0, x, 0, y)
		f.BackgroundTransparency = 1
		f.Parent = box
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = f
		local s = Instance.new("UIStroke")
		s.Color = C.TextSub
		s.Thickness = 1.5
		s.Parent = f
		table.insert(parts, s)
		return s
	end

	if iconType == "diagonal" then
		addLine(16, 2, 2, 11, 45)
		addLine(10, 2, 8, 6, 45)
		addLine(8, 2, 3, 14, -45)
	elseif iconType == "plug" then
		addLine(2, 12, 6, 5, 0)
		addLine(2, 12, 14, 5, 0)
		addLine(10, 2, 6, 15, 0)
		addRing(5, 4, 2)
	elseif iconType == "target" then
		addRing(16, 3, 3)
		addLine(3, 3, 9.5, 9.5, 0)
	elseif iconType == "bars" then
		addLine(2, 6, 3, 8, 0)
		addLine(2, 12, 7, 5, 0)
		addLine(2, 16, 11, 3, 0)
		addLine(2, 10, 15, 6, 0)
		addLine(2, 5, 19, 8.5, 0)
	elseif iconType == "badge" then
		addLine(18, 2, 2, 16, 0)
		addRing(10, 6, 4)
	elseif iconType == "totem" then
		addRing(13, 3, 3)
		addLine(9, 1.5, 5, 8, 0)
		addLine(9, 1.5, 5, 11, 0)
		addRing(6, 12, 12)
	elseif iconType == "layers" then
		addRing(12, 5, 3)
		addLine(14, 1.5, 4, 15, 15)
		addLine(14, 1.5, 4, 18, -15)
	end

	return function(isActive)
		local col = isActive and C.TextWhite or C.TextSub
		for _, p in ipairs(parts) do
			if p:IsA("UIStroke") then
				p.Color = col
			else
				p.BackgroundColor3 = col
			end
		end
	end
end

--------------------------------------------------------------------------------
-- TAB & CARD BUILDER WITH SLIDE-DOWN DRAWERS (SINGLE & MULTI SELECT)
--------------------------------------------------------------------------------
local Tabs = {}
local activeTabIndex = 1

local function selectTab(idx)
	if idx < 1 or idx > #Tabs then return end
	activeTabIndex = idx
	for i, t in ipairs(Tabs) do
		local isAct = (i == idx)
		t.Page.Visible = isAct
		t.Indicator.Visible = isAct
		t.Button.BackgroundColor3 = isAct and C.SidebarActive or C.SidebarBg
		t.TitleLabel.TextColor3 = isAct and C.TextWhite or Color3.fromRGB(210, 210, 218)
		t.SetIconActive(isAct)
		if isAct then
			TopTabTitle.Text = t.Name
			TopTabSub.Text = t.Subtitle
		end
	end
end

connect(PrevTabBtn.MouseButton1Click, function()
	local prev = activeTabIndex - 1
	if prev < 1 then prev = #Tabs end
	selectTab(prev)
end)

connect(NextTabBtn.MouseButton1Click, function()
	local nxt = activeTabIndex + 1
	if nxt > #Tabs then nxt = 1 end
	selectTab(nxt)
end)

local function createTab(name, subtitle, iconType)
	local idx = #Tabs + 1

	local tabBtn = Instance.new("TextButton")
	tabBtn.Name = name .. "_Tab"
	tabBtn.Size = UDim2.new(1, 0, 0, 52)
	tabBtn.LayoutOrder = idx
	tabBtn.BackgroundColor3 = C.SidebarBg
	tabBtn.BorderSizePixel = 0
	tabBtn.AutoButtonColor = false
	tabBtn.Text = ""
	tabBtn.Parent = TabsScroll

	local indicator = Instance.new("Frame")
	indicator.Size = UDim2.new(0, 3, 1, 0)
	indicator.Position = UDim2.new(0, 0, 0, 0)
	indicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	indicator.BorderSizePixel = 0
	indicator.Visible = false
	indicator.Parent = tabBtn

	local tTitle = Instance.new("TextLabel")
	tTitle.Size = UDim2.new(1, -50, 0, 18)
	tTitle.Position = UDim2.new(0, 14, 0, 9)
	tTitle.BackgroundTransparency = 1
	tTitle.Text = name
	tTitle.Font = Enum.Font.GothamMedium
	tTitle.TextSize = 13
	tTitle.TextColor3 = Color3.fromRGB(210, 210, 218)
	tTitle.TextXAlignment = Enum.TextXAlignment.Left
	tTitle.Parent = tabBtn

	local tSub = Instance.new("TextLabel")
	tSub.Size = UDim2.new(1, -50, 0, 15)
	tSub.Position = UDim2.new(0, 14, 0, 27)
	tSub.BackgroundTransparency = 1
	tSub.Text = subtitle
	tSub.Font = Enum.Font.Gotham
	tSub.TextSize = 11
	tSub.TextColor3 = C.TextSub
	tSub.TextXAlignment = Enum.TextXAlignment.Left
	tSub.Parent = tabBtn

	local setIconActive = drawTabCustomIcon(tabBtn, iconType)

	local bottomDiv = Instance.new("Frame")
	bottomDiv.Size = UDim2.new(1, 0, 0, 1)
	bottomDiv.Position = UDim2.new(0, 0, 1, -1)
	bottomDiv.BackgroundColor3 = C.Divider
	bottomDiv.BorderSizePixel = 0
	bottomDiv.Parent = tabBtn

	local page = Instance.new("ScrollingFrame")
	page.Name = name .. "_Page"
	page.Size = UDim2.new(1, 0, 1, 0)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 2
	page.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 68)
	page.CanvasSize = UDim2.new(0, 0, 0, 0)
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.Visible = false
	page.Parent = PagesHolder

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 12)
	pad.PaddingBottom = UDim.new(0, 14)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = page

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 10)
	layout.Parent = page

	local tabObj = {
		Name = name,
		Subtitle = subtitle,
		Button = tabBtn,
		Indicator = indicator,
		TitleLabel = tTitle,
		SetIconActive = setIconActive,
		Page = page,
		Cards = {},
	}
	table.insert(Tabs, tabObj)

	connect(tabBtn.MouseButton1Click, function()
		selectTab(idx)
	end)

	function tabObj:CreateCard(emojiAndTitle)
		local cardOrder = #self.Cards + 1
		local card = Instance.new("Frame")
		card.Name = emojiAndTitle
		card.Size = UDim2.new(1, 0, 0, 0)
		card.AutomaticSize = Enum.AutomaticSize.Y
		card.LayoutOrder = cardOrder
		card.BackgroundColor3 = C.CardBg
		card.BorderSizePixel = 0
		card.Parent = page

		local cc = Instance.new("UICorner")
		cc.CornerRadius = UDim.new(0, 8)
		cc.Parent = card

		local cs = Instance.new("UIStroke")
		cs.Color = C.CardBorder
		cs.Thickness = 1
		cs.Parent = card

		local cardLayout = Instance.new("UIListLayout")
		cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
		cardLayout.Padding = UDim.new(0, 0)
		cardLayout.Parent = card

		local header = Instance.new("Frame")
		header.Name = "Header"
		header.Size = UDim2.new(1, 0, 0, 36)
		header.LayoutOrder = 0
		header.BackgroundTransparency = 1
		header.Parent = card

		local hTitle = Instance.new("TextLabel")
		hTitle.Size = UDim2.new(1, -90, 1, 0)
		hTitle.Position = UDim2.new(0, 12, 0, 0)
		hTitle.BackgroundTransparency = 1
		hTitle.Text = emojiAndTitle
		hTitle.Font = Enum.Font.GothamMedium
		hTitle.TextSize = 13
		hTitle.TextColor3 = C.TextWhite
		hTitle.TextXAlignment = Enum.TextXAlignment.Left
		hTitle.Parent = header

		local dotsHolder = Instance.new("Frame")
		dotsHolder.Size = UDim2.new(0, 46, 0, 12)
		dotsHolder.Position = UDim2.new(1, -56, 0.5, -6)
		dotsHolder.BackgroundTransparency = 1
		dotsHolder.Parent = header

		local dotColors = {C.DotGreen, C.DotYellow, C.DotRed}
		for di, dcol in ipairs(dotColors) do
			local dot = Instance.new("Frame")
			dot.Size = UDim2.new(0, 9, 0, 9)
			dot.Position = UDim2.new(0, (di - 1) * 16, 0.5, -4.5)
			dot.BackgroundColor3 = dcol
			dot.BorderSizePixel = 0
			dot.Parent = dotsHolder
			local dc = Instance.new("UICorner")
			dc.CornerRadius = UDim.new(1, 0)
			dc.Parent = dot
		end

		local hDiv = Instance.new("Frame")
		hDiv.Size = UDim2.new(1, 0, 0, 1)
		hDiv.Position = UDim2.new(0, 0, 1, -1)
		hDiv.BackgroundColor3 = C.Divider
		hDiv.BorderSizePixel = 0
		hDiv.Parent = header

		local nextLayoutOrder = 0
		local cardAPI = {
			Frame = card,
			Title = emojiAndTitle,
			Rows = {},
		}
		table.insert(self.Cards, cardAPI)

		local function createBaseRow(title, subtitle)
			nextLayoutOrder = nextLayoutOrder + 1
			local row = Instance.new("Frame")
			row.Name = title
			row.Size = UDim2.new(1, 0, 0, 48)
			row.LayoutOrder = nextLayoutOrder
			row.BackgroundTransparency = 1
			row.Parent = card

			local rTitle = Instance.new("TextLabel")
			rTitle.Size = UDim2.new(1, -160, 0, 18)
			rTitle.Position = UDim2.new(0, 14, 0, 7)
			rTitle.BackgroundTransparency = 1
			rTitle.Text = title
			rTitle.Font = Enum.Font.GothamMedium
			rTitle.TextSize = 13
			rTitle.TextColor3 = C.TextWhite
			rTitle.TextXAlignment = Enum.TextXAlignment.Left
			rTitle.Parent = row

			local rSub = Instance.new("TextLabel")
			rSub.Size = UDim2.new(1, -160, 0, 15)
			rSub.Position = UDim2.new(0, 14, 0, 25)
			rSub.BackgroundTransparency = 1
			rSub.Text = subtitle or ""
			rSub.Font = Enum.Font.Gotham
			rSub.TextSize = 11
			rSub.TextColor3 = C.TextSub
			rSub.TextXAlignment = Enum.TextXAlignment.Left
			rSub.TextTruncate = Enum.TextTruncate.AtEnd
			rSub.Parent = row

			local rDiv = Instance.new("Frame")
			rDiv.Size = UDim2.new(1, 0, 0, 1)
			rDiv.Position = UDim2.new(0, 0, 1, -1)
			rDiv.BackgroundColor3 = C.Divider
			rDiv.BorderSizePixel = 0
			rDiv.Parent = row

			local rowEntry = {Frame = row, Title = title, Subtitle = subtitle or "", SubLabel = rSub}
			table.insert(cardAPI.Rows, rowEntry)
			return row, rSub, rowEntry
		end

		-- 1) TOGGLE ROW
		function cardAPI:AddToggle(title, subtitle, initialValue, callback)
			local row, rSub = createBaseRow(title, subtitle)
			local state = initialValue and true or false

			local pill = Instance.new("TextButton")
			pill.Size = UDim2.new(0, 40, 0, 21)
			pill.Position = UDim2.new(1, -54, 0.5, -10.5)
			pill.BackgroundColor3 = state and C.ToggleOn or C.ToggleOff
			pill.BorderSizePixel = 0
			pill.AutoButtonColor = false
			pill.Text = ""
			pill.Parent = row

			local pc = Instance.new("UICorner")
			pc.CornerRadius = UDim.new(1, 0)
			pc.Parent = pill

			local knob = Instance.new("Frame")
			knob.Size = UDim2.new(0, 17, 0, 17)
			knob.Position = state and UDim2.new(1, -19, 0.5, -8.5) or UDim2.new(0, 2, 0.5, -8.5)
			knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			knob.BorderSizePixel = 0
			knob.Parent = pill

			local kc = Instance.new("UICorner")
			kc.CornerRadius = UDim.new(1, 0)
			kc.Parent = knob

			local function setVisual(val)
				state = val
				TweenService:Create(pill, TweenInfo.new(0.15), {
					BackgroundColor3 = state and C.ToggleOn or C.ToggleOff
				}):Play()
				TweenService:Create(knob, TweenInfo.new(0.15), {
					Position = state and UDim2.new(1, -19, 0.5, -8.5) or UDim2.new(0, 2, 0.5, -8.5)
				}):Play()
			end

			connect(pill.MouseButton1Click, function()
				setVisual(not state)
				if callback then
					task.spawn(callback, state)
				end
			end)

			return {
				Set = function(val) setVisual(val) end,
				SetSubtitle = function(txt) rSub.Text = txt end,
			}
		end

		local function attachSelectorIcon(row)
			local iconBox = Instance.new("Frame")
			iconBox.Size = UDim2.new(0, 26, 0, 22)
			iconBox.Position = UDim2.new(1, -40, 0.5, -11)
			iconBox.BackgroundTransparency = 1
			iconBox.Parent = row

			for li = 1, 3 do
				local ln = Instance.new("Frame")
				ln.Size = UDim2.new(0, li == 3 and 7 or 11, 0, 1.5)
				ln.Position = UDim2.new(0, 0, 0, 5 + (li - 1) * 5)
				ln.BackgroundColor3 = C.TextSub
				ln.BorderSizePixel = 0
				ln.Parent = iconBox
			end

			local arrow = Instance.new("TextLabel")
			arrow.Size = UDim2.new(0, 12, 0, 12)
			arrow.Position = UDim2.new(0, 14, 0.5, -6)
			arrow.BackgroundTransparency = 1
			arrow.Text = "▾"
			arrow.Font = Enum.Font.GothamBold
			arrow.TextSize = 12
			arrow.TextColor3 = C.TextSub
			arrow.Parent = iconBox

			return arrow
		end

		-- 2) SINGLE-SELECT SLIDE-DOWN DRAWER
		function cardAPI:AddModeSelector(title, optionsList, currentVal, callback)
			local selectedVal = currentVal or optionsList[1] or ""
			local row, rSub, rowEntry = createBaseRow(title, selectedVal)
			local arrow = attachSelectorIcon(row)

			local triggerBtn = Instance.new("TextButton")
			triggerBtn.Size = UDim2.new(1, 0, 1, 0)
			triggerBtn.BackgroundTransparency = 1
			triggerBtn.Text = ""
			triggerBtn.Parent = row

			nextLayoutOrder = nextLayoutOrder + 1
			local drawer = Instance.new("Frame")
			drawer.Name = title .. "_Drawer"
			drawer.Size = UDim2.new(1, 0, 0, 0)
			drawer.LayoutOrder = nextLayoutOrder
			drawer.BackgroundColor3 = C.DrawerBg
			drawer.BorderSizePixel = 0
			drawer.ClipsDescendants = true
			drawer.Visible = false
			drawer.Parent = card
			rowEntry.Drawer = drawer

			local drawerScroll = Instance.new("ScrollingFrame")
			drawerScroll.Size = UDim2.new(1, -16, 1, -10)
			drawerScroll.Position = UDim2.new(0, 8, 0, 5)
			drawerScroll.BackgroundTransparency = 1
			drawerScroll.BorderSizePixel = 0
			drawerScroll.ScrollBarThickness = 2
			drawerScroll.ScrollBarImageColor3 = C.ToggleOn
			drawerScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
			drawerScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
			drawerScroll.Parent = drawer

			local dLayout = Instance.new("UIListLayout")
			dLayout.SortOrder = Enum.SortOrder.LayoutOrder
			dLayout.Padding = UDim.new(0, 4)
			dLayout.Parent = drawerScroll

			local drawerBottomLine = Instance.new("Frame")
			drawerBottomLine.Size = UDim2.new(1, 0, 0, 1)
			drawerBottomLine.Position = UDim2.new(0, 0, 1, -1)
			drawerBottomLine.BackgroundColor3 = C.Divider
			drawerBottomLine.BorderSizePixel = 0
			drawerBottomLine.Parent = drawer

			local isOpen = false
			local optionButtons = {}

			local function refreshOptionVisuals()
				for val, ui in pairs(optionButtons) do
					local act = (val == selectedVal)
					ui.Btn.BackgroundColor3 = act and C.DrawerActiveBg or C.DrawerItemBg
					ui.Bar.BackgroundColor3 = act and C.ToggleOn or C.TextMuted
					ui.Label.TextColor3 = act and C.TextWhite or C.TextSub
					ui.Check.Text = act and "✓" or ""
				end
			end

			local function setOpen(openState)
				isOpen = openState
				local count = math.max(1, #optionsList)
				local targetH = math.min(168, count * 32 + 10)
				TweenService:Create(arrow, TweenInfo.new(0.18), {
					Rotation = isOpen and 180 or 0,
					TextColor3 = isOpen and C.ToggleOn or C.TextSub,
				}):Play()
				if isOpen then
					drawer.Visible = true
					TweenService:Create(drawer, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Size = UDim2.new(1, 0, 0, targetH)
					}):Play()
				else
					local tw = TweenService:Create(drawer, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Size = UDim2.new(1, 0, 0, 0)
					})
					tw:Play()
					task.delay(0.16, function()
						if not isOpen then
							drawer.Visible = false
						end
					end)
				end
			end

			local function rebuildOptions(newList)
				optionsList = newList
				for _, child in ipairs(drawerScroll:GetChildren()) do
					if child:IsA("TextButton") then
						child:Destroy()
					end
				end
				optionButtons = {}

				for idx, optVal in ipairs(optionsList) do
					local itemBtn = Instance.new("TextButton")
					itemBtn.LayoutOrder = idx
					itemBtn.Size = UDim2.new(1, -4, 0, 28)
					itemBtn.BackgroundColor3 = C.DrawerItemBg
					itemBtn.BorderSizePixel = 0
					itemBtn.AutoButtonColor = false
					itemBtn.Text = ""
					itemBtn.Parent = drawerScroll

					local ic = Instance.new("UICorner")
					ic.CornerRadius = UDim.new(0, 6)
					ic.Parent = itemBtn

					local bar = Instance.new("Frame")
					bar.Size = UDim2.new(0, 3, 0, 14)
					bar.Position = UDim2.new(0, 8, 0.5, -7)
					bar.BackgroundColor3 = C.TextMuted
					bar.BorderSizePixel = 0
					bar.Parent = itemBtn
					local bc = Instance.new("UICorner")
					bc.CornerRadius = UDim.new(1, 0)
					bc.Parent = bar

					local lbl = Instance.new("TextLabel")
					lbl.Size = UDim2.new(1, -44, 1, 0)
					lbl.Position = UDim2.new(0, 18, 0, 0)
					lbl.BackgroundTransparency = 1
					lbl.Text = optVal
					lbl.Font = Enum.Font.GothamMedium
					lbl.TextSize = 12
					lbl.TextColor3 = C.TextSub
					lbl.TextXAlignment = Enum.TextXAlignment.Left
					lbl.Parent = itemBtn

					local chk = Instance.new("TextLabel")
					chk.Size = UDim2.new(0, 20, 1, 0)
					chk.Position = UDim2.new(1, -24, 0, 0)
					chk.BackgroundTransparency = 1
					chk.Text = ""
					chk.Font = Enum.Font.GothamBold
					chk.TextSize = 12
					chk.TextColor3 = C.ToggleOn
					chk.Parent = itemBtn

					optionButtons[optVal] = {Btn = itemBtn, Bar = bar, Label = lbl, Check = chk}

					connect(itemBtn.MouseButton1Click, function()
						selectedVal = optVal
						rSub.Text = selectedVal
						refreshOptionVisuals()
						setOpen(false)
						if callback then
							task.spawn(callback, selectedVal)
						end
					end)
				end
				refreshOptionVisuals()
			end

			rebuildOptions(optionsList)

			connect(triggerBtn.MouseButton1Click, function()
				setOpen(not isOpen)
			end)

			return {
				Set = function(val)
					selectedVal = val
					rSub.Text = val
					refreshOptionVisuals()
				end,
				SetOptions = function(newList, newSelected)
					if newSelected then
						selectedVal = newSelected
						rSub.Text = selectedVal
					end
					rebuildOptions(newList)
				end,
				IsOpen = function()
					return isOpen
				end,
			}
		end

		-- 3) MULTI-SELECT SLIDE-DOWN DRAWER
		function cardAPI:AddMultiSelector(title, optionsList, selectedMap, callback)
			selectedMap = selectedMap or {}
			local function formatSelectedSummary()
				local names = {}
				for _, opt in ipairs(optionsList) do
					if selectedMap[opt] then
						local a, b = opt:match("^(.+)%-(.+)$")
						local shortOpt = (a and a == b) and a or opt
						table.insert(names, shortOpt)
					end
				end
				if #names == 0 then
					return "Ninguno seleccionado"
				elseif #names <= 4 then
					return table.concat(names, ", ")
				else
					return string.format("%s, %s (+%d más)", names[1], names[2], #names - 2)
				end
			end

			local row, rSub, rowEntry = createBaseRow(title, formatSelectedSummary())
			local arrow = attachSelectorIcon(row)

			local triggerBtn = Instance.new("TextButton")
			triggerBtn.Size = UDim2.new(1, 0, 1, 0)
			triggerBtn.BackgroundTransparency = 1
			triggerBtn.Text = ""
			triggerBtn.Parent = row

			nextLayoutOrder = nextLayoutOrder + 1
			local drawer = Instance.new("Frame")
			drawer.Name = title .. "_MultiDrawer"
			drawer.Size = UDim2.new(1, 0, 0, 0)
			drawer.LayoutOrder = nextLayoutOrder
			drawer.BackgroundColor3 = C.DrawerBg
			drawer.BorderSizePixel = 0
			drawer.ClipsDescendants = true
			drawer.Visible = false
			drawer.Parent = card
			rowEntry.Drawer = drawer

			local drawerScroll = Instance.new("ScrollingFrame")
			drawerScroll.Size = UDim2.new(1, -16, 1, -10)
			drawerScroll.Position = UDim2.new(0, 8, 0, 5)
			drawerScroll.BackgroundTransparency = 1
			drawerScroll.BorderSizePixel = 0
			drawerScroll.ScrollBarThickness = 2
			drawerScroll.ScrollBarImageColor3 = C.ToggleOn
			drawerScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
			drawerScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
			drawerScroll.Parent = drawer

			local dLayout = Instance.new("UIListLayout")
			dLayout.SortOrder = Enum.SortOrder.LayoutOrder
			dLayout.Padding = UDim.new(0, 4)
			dLayout.Parent = drawerScroll

			local isOpen = false
			local optionButtons = {}

			local function refreshMultiVisuals()
				for val, ui in pairs(optionButtons) do
					local act = selectedMap[val] and true or false
					ui.Btn.BackgroundColor3 = act and C.DrawerActiveBg or C.DrawerItemBg
					ui.Box.BackgroundColor3 = act and C.ToggleOn or C.SliderTrack
					ui.Label.TextColor3 = act and C.TextWhite or C.TextSub
					ui.Check.Text = act and "✓" or ""
				end
				rSub.Text = formatSelectedSummary()
			end

			local function rebuildMultiOptions(newList)
				optionsList = newList
				for _, child in ipairs(drawerScroll:GetChildren()) do
					if child:IsA("TextButton") then
						child:Destroy()
					end
				end
				optionButtons = {}

				for idx, optVal in ipairs(optionsList) do
					local itemBtn = Instance.new("TextButton")
					itemBtn.LayoutOrder = idx
					itemBtn.Size = UDim2.new(1, -4, 0, 28)
					itemBtn.BackgroundColor3 = C.DrawerItemBg
					itemBtn.BorderSizePixel = 0
					itemBtn.AutoButtonColor = false
					itemBtn.Text = ""
					itemBtn.Parent = drawerScroll

					local ic = Instance.new("UICorner")
					ic.CornerRadius = UDim.new(0, 6)
					ic.Parent = itemBtn

					local chkBox = Instance.new("Frame")
					chkBox.Size = UDim2.new(0, 16, 0, 16)
					chkBox.Position = UDim2.new(0, 8, 0.5, -8)
					chkBox.BackgroundColor3 = C.SliderTrack
					chkBox.BorderSizePixel = 0
					chkBox.Parent = itemBtn
					local cbc = Instance.new("UICorner")
					cbc.CornerRadius = UDim.new(0, 4)
					cbc.Parent = chkBox

					local chk = Instance.new("TextLabel")
					chk.Size = UDim2.new(1, 0, 1, 0)
					chk.BackgroundTransparency = 1
					chk.Text = ""
					chk.Font = Enum.Font.GothamBold
					chk.TextSize = 11
					chk.TextColor3 = Color3.fromRGB(255, 255, 255)
					chk.Parent = chkBox

					local lbl = Instance.new("TextLabel")
					lbl.Size = UDim2.new(1, -38, 1, 0)
					lbl.Position = UDim2.new(0, 30, 0, 0)
					lbl.BackgroundTransparency = 1
					lbl.Text = optVal
					lbl.Font = Enum.Font.GothamMedium
					lbl.TextSize = 12
					lbl.TextColor3 = C.TextSub
					lbl.TextXAlignment = Enum.TextXAlignment.Left
					lbl.Parent = itemBtn

					optionButtons[optVal] = {Btn = itemBtn, Box = chkBox, Label = lbl, Check = chk}

					connect(itemBtn.MouseButton1Click, function()
						selectedMap[optVal] = not selectedMap[optVal]
						refreshMultiVisuals()
						if callback then
							task.spawn(callback, selectedMap)
						end
					end)
				end
				refreshMultiVisuals()
			end

			rebuildMultiOptions(optionsList)

			connect(triggerBtn.MouseButton1Click, function()
				isOpen = not isOpen
				local targetH = math.min(168, math.max(1, #optionsList) * 32 + 10)
				TweenService:Create(arrow, TweenInfo.new(0.18), {
					Rotation = isOpen and 180 or 0,
					TextColor3 = isOpen and C.ToggleOn or C.TextSub,
				}):Play()
				if isOpen then
					drawer.Visible = true
					TweenService:Create(drawer, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Size = UDim2.new(1, 0, 0, targetH)
					}):Play()
				else
					local tw = TweenService:Create(drawer, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Size = UDim2.new(1, 0, 0, 0)
					})
					tw:Play()
					task.delay(0.16, function()
						if not isOpen then drawer.Visible = false end
					end)
				end
			end)

			return {
				Refresh = refreshMultiVisuals,
				SetOptions = function(newList)
					rebuildMultiOptions(newList)
					if isOpen then
						local targetH = math.min(168, math.max(1, #optionsList) * 32 + 10)
						TweenService:Create(drawer, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
							Size = UDim2.new(1, 0, 0, targetH)
						}):Play()
					end
				end,
				IsOpen = function()
					return isOpen
				end,
			}
		end

		-- 4) SLIDER ROW (supports integer or decimal step + unit suffix, e.g. {step = 0.1, suffix = "s"})
		function cardAPI:AddSlider(title, subtitle, minVal, maxVal, defaultVal, callback, sliderOpts)
			local row, rSub = createBaseRow(title, subtitle)
			local step = (type(sliderOpts) == "table" and tonumber(sliderOpts.step)) or 1
			local suffix = (type(sliderOpts) == "table" and tostring(sliderOpts.suffix or "")) or ""
			local isDecimal = (step < 1)

			local function snapVal(raw)
				local snapped = math.floor((raw - minVal) / step + 0.5) * step + minVal
				snapped = math.clamp(snapped, minVal, maxVal)
				if isDecimal then
					return tonumber(string.format("%.2f", snapped)) or snapped
				end
				return math.floor(snapped + 0.5)
			end

			local function formatSliderText(val)
				if isDecimal then
					return string.format("%.1f%s", val, suffix)
				end
				return tostring(val) .. suffix
			end

			local curVal = snapVal(defaultVal ~= nil and defaultVal or minVal)

			local valLabel = Instance.new("TextLabel")
			valLabel.Size = UDim2.new(0, 44, 0, 16)
			valLabel.Position = UDim2.new(1, -170, 0.5, -8)
			valLabel.BackgroundTransparency = 1
			valLabel.Text = formatSliderText(curVal)
			valLabel.Font = Enum.Font.Gotham
			valLabel.TextSize = 11
			valLabel.TextColor3 = C.TextSub
			valLabel.TextXAlignment = Enum.TextXAlignment.Right
			valLabel.Parent = row

			local track = Instance.new("TextButton")
			track.Size = UDim2.new(0, 106, 0, 5)
			track.Position = UDim2.new(1, -120, 0.5, -2.5)
			track.BackgroundColor3 = C.SliderTrack
			track.BorderSizePixel = 0
			track.AutoButtonColor = false
			track.Text = ""
			track.Parent = row

			local tc = Instance.new("UICorner")
			tc.CornerRadius = UDim.new(1, 0)
			tc.Parent = track

			local span = math.max(0.0001, (maxVal - minVal))
			local pct = (curVal - minVal) / span

			local fill = Instance.new("Frame")
			fill.Size = UDim2.new(pct, 0, 1, 0)
			fill.BackgroundColor3 = C.SliderFill
			fill.BorderSizePixel = 0
			fill.Parent = track

			local fc = Instance.new("UICorner")
			fc.CornerRadius = UDim.new(1, 0)
			fc.Parent = fill

			local thumb = Instance.new("Frame")
			thumb.Size = UDim2.new(0, 13, 0, 13)
			thumb.Position = UDim2.new(pct, -6.5, 0.5, -6.5)
			thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			thumb.BorderSizePixel = 0
			thumb.Parent = track

			local thc = Instance.new("UICorner")
			thc.CornerRadius = UDim.new(1, 0)
			thc.Parent = thumb

			local sliding = false
			local function updateFromX(absX)
				local rel = math.clamp((absX - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
				local v = snapVal(minVal + rel * (maxVal - minVal))
				curVal = v
				local p = (v - minVal) / span
				valLabel.Text = formatSliderText(v)
				fill.Size = UDim2.new(p, 0, 1, 0)
				thumb.Position = UDim2.new(p, -6.5, 0.5, -6.5)
				if callback then
					task.spawn(callback, v)
				end
			end

			connect(track.InputBegan, function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					sliding = true
					updateFromX(input.Position.X)
				end
			end)
			connect(UserInputService.InputEnded, function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					sliding = false
				end
			end)
			connect(UserInputService.InputChanged, function(input)
				if sliding and input.UserInputType == Enum.UserInputType.MouseMovement then
					updateFromX(input.Position.X)
				end
			end)
		end

		-- 5) ACTION BUTTON ROW
		function cardAPI:AddButton(title, subtitle, btnText, callback)
			local row, rSub = createBaseRow(title, subtitle)

			local actBtn = Instance.new("TextButton")
			actBtn.Size = UDim2.new(0, 84, 0, 24)
			actBtn.Position = UDim2.new(1, -98, 0.5, -12)
			actBtn.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
			actBtn.BorderSizePixel = 0
			actBtn.Text = btnText or "Execute"
			actBtn.Font = Enum.Font.GothamMedium
			actBtn.TextSize = 11
			actBtn.TextColor3 = C.TextWhite
			actBtn.Parent = row

			local abc = Instance.new("UICorner")
			abc.CornerRadius = UDim.new(0, 6)
			abc.Parent = actBtn

			local abs = Instance.new("UIStroke")
			abs.Color = Color3.fromRGB(52, 52, 60)
			abs.Thickness = 1
			abs.Parent = actBtn

			connect(actBtn.MouseButton1Click, function()
				if callback then
					task.spawn(callback)
				end
			end)

			return {
				SetSubtitle = function(txt) rSub.Text = txt end,
			}
		end

		-- 6) LIVE STATUS INFO ROW WITH BADGE
		function cardAPI:AddInfoRow(title, subtitle, badgeText, badgeColor)
			local row, rSub, rowEntry = createBaseRow(title, subtitle)
			rSub.Size = UDim2.new(1, -134, 0, 15)

			local badge = Instance.new("TextLabel")
			badge.Size = UDim2.new(0, 104, 0, 22)
			badge.Position = UDim2.new(1, -118, 0.5, -11)
			badge.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
			badge.BorderSizePixel = 0
			badge.Text = badgeText or "..."
			badge.Font = Enum.Font.GothamBold
			badge.TextSize = 11
			badge.TextColor3 = badgeColor or C.ToggleOn
			badge.TextTruncate = Enum.TextTruncate.AtEnd
			badge.Parent = row

			local bc = Instance.new("UICorner")
			bc.CornerRadius = UDim.new(0, 6)
			bc.Parent = badge

			local bs = Instance.new("UIStroke")
			bs.Color = badgeColor or Color3.fromRGB(52, 52, 60)
			bs.Transparency = 0.45
			bs.Thickness = 1
			bs.Parent = badge

			return {
				SetSubtitle = function(txt)
					rSub.Text = txt
					rowEntry.Subtitle = txt
				end,
				SetBadge = function(txt, col)
					badge.Text = txt
					if col then
						badge.TextColor3 = col
						bs.Color = col
					end
				end,
			}
		end

		return cardAPI
	end

	return tabObj
end

--------------------------------------------------------------------------------
-- SEARCH FILTERING
--------------------------------------------------------------------------------
connect(SideSearchBox:GetPropertyChangedSignal("Text"), function()
	local q = SideSearchBox.Text:lower()
	for _, t in ipairs(Tabs) do
		local match = (q == "") or t.Name:lower():find(q, 1, true) or t.Subtitle:lower():find(q, 1, true)
		t.Button.Visible = match and true or false
	end
end)

connect(OptSearchBox:GetPropertyChangedSignal("Text"), function()
	local q = OptSearchBox.Text:lower()
	for _, t in ipairs(Tabs) do
		for _, c in ipairs(t.Cards) do
			if q == "" then
				c.Frame.Visible = true
				for _, r in ipairs(c.Rows) do
					r.Frame.Visible = true
				end
			else
				local anyVisible = c.Title:lower():find(q, 1, true) ~= nil
				for _, r in ipairs(c.Rows) do
					local rMatch = anyVisible
						or r.Title:lower():find(q, 1, true) ~= nil
						or r.Subtitle:lower():find(q, 1, true) ~= nil
					r.Frame.Visible = rMatch
					if r.Drawer and not rMatch then
						r.Drawer.Visible = false
					end
					if rMatch then anyVisible = true end
				end
				c.Frame.Visible = anyVisible
			end
		end
	end
end)

--------------------------------------------------------------------------------
-- BUILD THE TABS FOR BLOX FRUITS
--------------------------------------------------------------------------------
local Others = {}

do
local TabFarming   = createTab("Farming",        "Farming Features",           "diagonal")
local TabStack     = createTab("Stack Farming",  "Events, Quests & Fruits",    "plug")
local TabOthers    = createTab("Farming Others", "Dojo, Berries, Chest & Boss","layers")
local TabCombat    = createTab("Combat",         "Combat & Doble Daño",        "badge")
local TabAdvSkills = createTab("Adv. Skills",    "Advanced Setting Skills",    "target")
local TabFruits    = createTab("Fruit & Raid",   "Fruits, Raids & Dungeons",   "totem")
local TabSeaEvents = createTab("Sea Events",     "Eventos Marítimos & Botes",  "target")
local TabShop      = createTab("Shop",           "Shop Features",              "bars")
local TabServer    = createTab("Server",         "Status, Optimización & Hop", "target")
local TabTeleport  = createTab("Teleport",       "Teleport & ESP",             "layers")

local levelFarmToggleUI, srvHopBtn
local masteryPriorityToggleFarmUI
local StackUI = {}
local OthersUI = {}

-- ==================== TAB 1: FARMING ====================
local CardLevelFarm = TabFarming:CreateCard("⚔️ Level & Mode Farm (Max Lv. 2800)")
CardLevelFarm:AddModeSelector(
	"Select Farm Mode",
	{"Niveles", "Bones", "Katakuri", "Farm Aura"},
	S.farmSubMode,
	function(mode)
		S.farmSubMode = mode
		patrolKey = ""
	end
)
CardLevelFarm:AddSlider(
	"Distance For Aura",
	"Rango de detección de NPCs para Farm Aura (0 - 1000, 300 por defecto)",
	0, 1000, S.auraDistance,
	function(val)
		S.auraDistance = val
	end
)
levelFarmToggleUI = CardLevelFarm:AddToggle(
	"Auto Farm",
	"Farmea Lv. 1-2800 (excluye misiones secretas y usa Prioridad Mastery si está activa)",
	S.levelFarm,
	function(v)
		S.levelFarm = v
		if not v and not S.stackTaskRunning and not S.othersTaskRunning and not S.autoFirstSeaComplete and not S.autoSecondSeaComplete and not S.bossFarm and not S.allBossFarm then
			clearFarmMover()
			setStatus("Auto Farm detenido")
		else
			ensureTeamSelected()
		end
	end
)
CardLevelFarm:AddToggle(
	"Auto Accept Quest",
	"Detecta tu nivel real (hasta Max Lv. 2800) sin cruzar islas",
	S.autoQuest,
	function(v)
		S.autoQuest = v
	end
)
CardLevelFarm:AddToggle(
	"Smart Portal Routing",
	"Entra directo por el portal en Barco Maldito, Isla Gyojin, Upper Sky y Portales Sea 3",
	S.useSmartPortals,
	function(v)
		S.useSmartPortals = v
	end
)

-- Mastery Farm (Blox Fruit & Gun Priority) inside Farming Tab
local CardFarmingMastery = TabFarming:CreateCard("🔥 Mastery Farm (Blox Fruit & Gun)")
masteryPriorityToggleFarmUI = CardFarmingMastery:AddToggle(
	"Enable Mastery Priority",
	"Prioridad activa: golpea con Melee/Sword y remata con Blox Fruit o Gun",
	S.masteryPriority,
	function(v)
		S.masteryPriority = v
	end
)
CardFarmingMastery:AddModeSelector(
	"Select Mastery Category",
	{"Blox Fruit", "Gun"},
	S.masteryCategory,
	function(cat)
		S.masteryCategory = cat
	end
)
CardFarmingMastery:AddModeSelector(
	"Starter Damage Weapon",
	{"Melee", "Sword"},
	S.masteryStarterWeapon,
	function(w)
		S.masteryStarterWeapon = w
	end
)
CardFarmingMastery:AddSlider(
	"Switch at Enemy HP %",
	"Porcentaje de vida del NPC para cambiar a Blox Fruit / Gun y atacar",
	5, 70, S.masteryHealthPct,
	function(v)
		S.masteryHealthPct = v
	end
)
CardFarmingMastery:AddToggle(
	"Aimlock Mastery & Gun (No Spread)",
	"Centra el 100% de las balas de Gun y ataques de Fruta en el NPC",
	S.masteryAimlock,
	function(v)
		S.masteryAimlock = v
	end
)

local CardCombatConfig = TabFarming:CreateCard("🗡️ Weapon, Tween & Mob Settings")
CardCombatConfig:AddModeSelector(
	"Select Weapon Type",
	{"Melee", "Sword", "Blox Fruit", "Gun"},
	S.weaponType,
	function(w)
		S.weaponType = w
	end
)
CardCombatConfig:AddToggle(
	"Auto Equip Weapon",
	"Equipa automáticamente el arma correspondiente",
	S.autoEquip,
	function(v)
		S.autoEquip = v
	end
)
CardCombatConfig:AddToggle(
	"Bring Mobs (Max 3)",
	"Agrupa hasta un máximo de 3 enemigos frente a tu golpe",
	S.bringMobs,
	function(v)
		S.bringMobs = v
	end
)
CardCombatConfig:AddSlider(
	"Farm Hover Distance",
	"Distancia sobre el NPC (20 studs por defecto)",
	4, 35, S.farmDistance,
	function(val)
		S.farmDistance = val
	end
)
CardCombatConfig:AddSlider(
	"Tween Farm Speed",
	"Velocidad suave recomendada: 200 studs/s",
	100, 300, S.tweenSpeed,
	function(val)
		S.tweenSpeed = val
	end
)

-- ==================== TAB 2: STACK FARMING (BOSSES, EVENTS, FRUITS & QUESTS) ====================
do
	local function addStackToggle(card, stateKey, title, defaultSub, onEnableExtra)
		local uiRef
		uiRef = card:AddToggle(title, defaultSub, S[stateKey], function(v)
			S[stateKey] = v
			if v then
				if onEnableExtra then onEnableExtra() end
				ensureTeamSelected()
			else
				uiRef.SetSubtitle(defaultSub)
				if not S.levelFarm and not S.bossFarm and not S.allBossFarm and not S.autoFirstSeaComplete and not S.autoSecondSeaComplete then
					S.stackTaskRunning = false
					clearFarmMover()
				end
			end
		end)
		table.insert(StackUI, {key = stateKey, ui = uiRef})
		return uiRef
	end

	-- 1) BOSS RIP_INDRA & ELITE HUNTER
	local CardBossIndra = TabStack:CreateCard("👑 Boss rip_indra & Elite Hunter (Sea 3)")
	addStackToggle(
		CardBossIndra,
		"autoEliteHunter",
		"Auto Elite Hunter",
		"Acepta misión de Elite Hunter y derrota a Diablo, Deandre o Urban (Prioridad Stack)"
	)
	addStackToggle(
		CardBossIndra,
		"hopEliteHunter",
		"Hop Server Elite Hunter",
		"Cambia de servidor automáticamente si no hay ningún Elite Pirate disponible",
		function() S.spawnedAtClock = os.clock() end
	)
	addStackToggle(
		CardBossIndra,
		"autoTouchpadHaki",
		"Auto Touchpad Haki",
		"Se acerca a las 3 placas de Castle on the Sea y coloca el color Haki correspondiente"
	)
	addStackToggle(
		CardBossIndra,
		"autoSummonIndra",
		"Auto Summon rip_indra (Cáliz de Dios)",
		"Cuando tengas God's Chalice va al pedestal del castillo e invoca a rip_indra"
	)
	addStackToggle(
		CardBossIndra,
		"autoAttackIndra",
		"Atacar a rip_indra",
		"Detecta a rip_indra activo en el servidor y lo ataca hasta derrotarlo"
	)

	-- 2) BOSS SOUL REAPER (HALLOW ESSENCE)
	local CardSoulReaper = TabStack:CreateCard("💀 Boss Soul Reaper (Esencia Sagrada)")
	addStackToggle(
		CardSoulReaper,
		"autoSummonSoulReaper",
		"Invocar Soul Reaper (Esencia Sagrada)",
		"Cuando tengas Hallow Essence va al altar de Haunted Castle e invoca a Soul Reaper"
	)
	addStackToggle(
		CardSoulReaper,
		"autoAttackSoulReaper",
		"Atacar a Soul Reaper",
		"Detecta a Soul Reaper en Haunted Castle y lo ataca con prioridad Stack"
	)

	-- 3) BOSS DOUGH KING (SWEET CHALICE)
	local CardDoughKing = TabStack:CreateCard("🍩 Boss Dough King (Sweet Chalice)")
	addStackToggle(
		CardDoughKing,
		"autoSummonDoughKing",
		"Invocar Dough King (Sweet Chalice)",
		"Cuando tengas Sweet Chalice completa requisitos e invoca a Dough King con drip_mama"
	)
	addStackToggle(
		CardDoughKing,
		"autoAttackDoughKing",
		"Atacar a Dough King",
		"Entra a la dimensión del espejo y derrota a Dough King cuando aparezca"
	)

	-- 4) BOSS BARBANEGRA / DARKBEARD (FIST OF DARKNESS)
	local CardDarkbeard = TabStack:CreateCard("🌑 Boss Barbanegra (Fist of Darkness)")
	addStackToggle(
		CardDarkbeard,
		"autoSummonDarkbeard",
		"Invocar Barbanegra (Fist of Darkness)",
		"Cuando tengas Fist of Darkness en Sea 2 va a Dark Arena e invoca a Darkbeard"
	)
	addStackToggle(
		CardDarkbeard,
		"autoAttackDarkbeard",
		"Atacar a Barbanegra (Darkbeard)",
		"Detecta a Darkbeard activo en Dark Arena y lo ataca hasta derrotarlo"
	)

	-- 5) EVENTOS DEL JUEGO (FACTORY & PIRATE RAID)
	local CardStackEvents = TabStack:CreateCard("🏭 Eventos del Juego (Stack Priority)")
	addStackToggle(
		CardStackEvents,
		"autoFactory",
		"Auto Factory",
		"Sea 2: Detecta cuando abre la Fábrica, destruye el Core, guarda la fruta y vuelve al farm"
	)
	addStackToggle(
		CardStackEvents,
		"autoPirateRaid",
		"Auto Pirate Raid",
		"Sea 3: Detecta Pirate Raid en Castle on the Sea, limpia la incursión y vuelve al farm"
	)

	-- 6) TELEPORT FRUIT & SERVER HOP
	local CardStackFruits = TabStack:CreateCard("🍎 Teleport Fruit & Server Hop (Stack)")
	addStackToggle(
		CardStackFruits,
		"stackTpFruit",
		"Teleport Fruit",
		"Prioridad Stack: vuela hacia cualquier fruta spawneada/tirada en el mapa y la guarda"
	)
	addStackToggle(
		CardStackFruits,
		"stackTpFruitHop",
		"Teleport Fruit + Server Hop",
		"Recoge todas las frutas del mapa, las guarda y hace Server Hop automáticamente",
		function() S.spawnedAtClock = os.clock() end
	)

	-- 7) PASO DE SEA COMPLETO (SEA 1 -> SEA 2 & SEA 2 -> SEA 3 + BARTILO / TREVOR / SWAN / INDRA)
	local CardSecretQuests = TabStack:CreateCard("🌊 Paso de Sea & Misión Bartilo (Completo)")
	local sea1SubDefault = "Completa todo el Primer Sea (Lv. 700, Key, Ice Admiral) y viaja directo al Segundo Sea"
	local sea2SubDefault = "Bartilo + Trevor (Quake/Love/Creation/Spider/Sound/Phoenix/Pain/Shadow) + Swan + Indra -> Sea 3"
	local sea1ToggleUI, sea2ToggleUI

	sea1ToggleUI = CardSecretQuests:AddToggle(
		"Auto Primer Sea -> Segundo Sea (Completo)",
		sea1SubDefault,
		S.autoFirstSeaComplete,
		function(v)
			S.autoFirstSeaComplete = v
			if v then
				if S.autoSecondSeaComplete then
					S.autoSecondSeaComplete = false
					S.trevorDeliveryActive = false
					S.protectedTrevorFruitTool = nil
					if sea2ToggleUI then
						sea2ToggleUI.Set(false)
						sea2ToggleUI.SetSubtitle(sea2SubDefault)
					end
				end
				S.spawnedAtClock = os.clock()
				ensureTeamSelected()
			else
				sea1ToggleUI.SetSubtitle(sea1SubDefault)
				if not S.levelFarm and not S.bossFarm and not S.allBossFarm and not S.autoSecondSeaComplete then
					S.stackTaskRunning = false
					clearFarmMover()
				end
			end
		end
	)
	table.insert(StackUI, {key = "autoFirstSeaComplete", ui = sea1ToggleUI})

	sea2ToggleUI = CardSecretQuests:AddToggle(
		"Auto Segundo Sea -> Tercer Sea (Completo)",
		sea2SubDefault,
		S.autoSecondSeaComplete,
		function(v)
			S.autoSecondSeaComplete = v
			if v then
				if S.autoFirstSeaComplete then
					S.autoFirstSeaComplete = false
					if sea1ToggleUI then
						sea1ToggleUI.Set(false)
						sea1ToggleUI.SetSubtitle(sea1SubDefault)
					end
				end
				S.spawnedAtClock = os.clock()
				ensureTeamSelected()
			else
				S.trevorDeliveryActive = false
				S.protectedTrevorFruitTool = nil
				sea2ToggleUI.SetSubtitle(sea2SubDefault)
				if not S.levelFarm and not S.bossFarm and not S.allBossFarm and not S.autoFirstSeaComplete then
					S.stackTaskRunning = false
					clearFarmMover()
				end
			end
		end
	)
	table.insert(StackUI, {key = "autoSecondSeaComplete", ui = sea2ToggleUI})
end

-- ==================== TAB 3: FARMING OTHERS (DOJO, BERRIES, CHEST, LAW & KEN V2) ====================
do
	local function addOthersToggle(card, stateKey, title, defaultSub, onEnableExtra)
		local uiRef
		uiRef = card:AddToggle(title, defaultSub, S[stateKey], function(v)
			S[stateKey] = v
			if v then
				if onEnableExtra then onEnableExtra() end
				ensureTeamSelected()
			else
				uiRef.SetSubtitle(defaultSub)
				local anyStillOn = false
				for _, entry in ipairs(OthersUI) do
					if S[entry.key] then
						anyStillOn = true
						break
					end
				end
				if not anyStillOn and not S.levelFarm and not S.autoFirstSeaComplete and not S.autoSecondSeaComplete and not S.stackTaskRunning then
					S.othersTaskRunning = false
					clearFarmMover()
				end
			end
		end)
		table.insert(OthersUI, {key = stateKey, ui = uiRef})
		return uiRef
	end

	-- 1) DOJO QUESTS (DOJO TRAINER & DRAGON HUNTER)
	local CardDojo = TabOthers:CreateCard("🥋 Misiones del Dojo (Sea 3 - Hydra Island)")
	addOthersToggle(
		CardDojo,
		"autoDojoTrainer",
		"Auto Quest Dojo Trainer",
		"Completa automáticamente los cinturones solitarios (White, Yellow, Green, Purple, Red) y reclama recompensas"
	)
	addOthersToggle(
		CardDojo,
		"autoDragonHunter",
		"Auto Quest Dragon Hunter",
		"Acepta misiones de caza en el Dojo, tala árboles o derrota Hydra NPCs y recoge Blaze Embers"
	)

	-- 2) BERRY COLLECTOR & HOP
	local CardBerries = TabOthers:CreateCard("🍓 Recolector de Berries & Hop")
	addOthersToggle(
		CardBerries,
		"autoCollectBerries",
		"Recolectar Berries",
		"Detecta todos los arbustos con Berries activas en el mapa, vuela hacia ellas y las recolecta"
	)
	addOthersToggle(
		CardBerries,
		"hopFindBerry",
		"Hop Find Berry",
		"Recolecta todas las Berries del servidor actual y hace Server Hop cuando quedan 0",
		function() S.spawnedAtClock = os.clock() end
	)

	-- 3) CHEST FARM & CHEST HOP (MOVED OUT OF FARMING)
	local CardChestOthers = TabOthers:CreateCard("💰 Chest Farm & Auto Chest Hop")
	addOthersToggle(
		CardChestOthers,
		"autoChestFarm",
		"Auto Chest",
		"Recorre y recoge todos los cofres activos del servidor a velocidad 200"
	)
	CardChestOthers:AddSlider(
		"Cofres Antes de Hop",
		"Cantidad de cofres que recogerá antes de cambiar de servidor (Auto Chest Hop)",
		1, 100, S.chestHopLimit,
		function(val)
			S.chestHopLimit = val
		end
	)
	addOthersToggle(
		CardChestOthers,
		"autoChestHop",
		"Auto Chest Hop",
		"Agarra la cantidad configurada de cofres en la barra y ejecuta Server Hop automáticamente",
		function()
			S.chestsCollectedCount = 0
			S.spawnedAtClock = os.clock()
		end
	)

	-- 4) RAID DE LAW (ORDER RAID - SEA 2)
	local CardLawRaid = TabOthers:CreateCard("⚡ Raid de Law / Order (Sea 2 - Hot and Cold)")
	addOthersToggle(
		CardLawRaid,
		"autoLawRaid",
		"Auto Raid de Law (Comprar Chip & Atacar)",
		"Compra el Microchip con arlthmetic (1,000f), inicia la Raid secreta y ataca directamente a Order (Law)"
	)

	-- 5) OBSERVATION HAKI V2 FARM & HOP
	local CardObsV2 = TabOthers:CreateCard("👁️ Haki Observación Nivel 2 (Farm & Hop)")
	addOthersToggle(
		CardObsV2,
		"autoObservationFarm",
		"Auto Farm Haki Observación (V2)",
		"Activa Ken Haki y esquiva golpes de NPCs de forma segura para subir experiencia a Nivel 2"
	)
	addOthersToggle(
		CardObsV2,
		"hopObservation",
		"Hop Server Observación",
		"Al agotarse tus esquives (0 dodges), cambia de servidor para recargarlos al instante",
		function() S.spawnedAtClock = os.clock() end
	)
	local buyKenV2Btn
	buyKenV2Btn = CardObsV2:AddButton(
		"Comprar Observación V2 (Hungry Man - $5M)",
		"Sea 3: Va con Hungry Man e intenta desbloquear/comprar Instinct V2 al tener 5,000 EXP y Fruit Bowl",
		"Buy V2",
		function()
			if getCurrentSeaNumber() ~= 3 or not CommF_ then
				buyKenV2Btn.SetSubtitle("Debes estar en Sea 3 (Floating Turtle) para hablar con Hungry Man")
				return
			end
			task.spawn(function()
				pcall(function()
					local hmPos = Vector3.new(-10920.1, 624.2, -10266.9)
					buyKenV2Btn.SetSubtitle("Yendo con Hungry Man...")
					local t0 = os.clock()
					while isAlive() and (os.clock() - t0 < 35) do
						local ch = LocalPlayer.Character
						local h = ch and ch:FindFirstChild("HumanoidRootPart")
						if not h then break end
						if moveToCFrame(CFrame.new(hmPos + Vector3.new(0, 3, 3))) or (h.Position - hmPos).Magnitude <= 18 then
							break
						end
						task.wait(0.14)
					end
					clearFarmMover()
					CommF_:InvokeServer("KenTalk2", "Start")
					local res = CommF_:InvokeServer("KenTalk2", "Buy")
					buyKenV2Btn.SetSubtitle("Hungry Man: " .. tostring(res or "Consultado"))
				end)
			end)
		end
	)

	-- 6) AUTO KILL MOB (CURRENT SEA MOBS ONLY)
	local CardKillMob = TabOthers:CreateCard(string.format("👾 Auto Kill Mob (Sea %d)", getCurrentSeaNumber()))
	Others.uiMobMultiSelector = CardKillMob:AddMultiSelector(
		"Seleccionar Mobs (Sea Actual)",
		{"Cargando mobs del Sea..."},
		S.selectedKillMobs,
		function(map)
			S.selectedKillMobs = map
			patrolKey = ""
		end
	)
	Others.uiRefreshMobsBtn = CardKillMob:AddButton(
		"Refrescar Lista de Mobs",
		"Detecta tu Sea actual y carga todos los mobs disponibles en este Sea",
		"Refresh",
		function()
			if Others.refreshMobsUI then
				Others.refreshMobsUI()
			end
		end
	)
	addOthersToggle(
		CardKillMob,
		"autoKillMob",
		"Auto Kill Mob",
		"Vuela hacia los spawns de los mobs seleccionados de este Sea, los agrupa y los elimina"
	)

	-- 7) AUTO BOSS, ALL BOSSES, REFRESH ACTIVE STATUS & HOP SERVER FIND BOSS
	local CardBossOthers = TabOthers:CreateCard("👑 Auto Boss & Hop Find Boss")
	Others.uiBossSelector = CardBossOthers:AddModeSelector(
		"Select Boss (Estado Activo / Inactivo)",
		{"Verificando bosses..."},
		"Verificando bosses...",
		function(label)
			if Others.cleanEntityName then
				S.selectedBoss = Others.cleanEntityName(label)
			else
				S.selectedBoss = label
			end
		end
	)
	Others.uiRefreshBossBtn = CardBossOthers:AddButton(
		"Refrescar Bosses",
		"Verifica en tiempo real qué Boss está activo ahora mismo en este servidor",
		"Refresh",
		function()
			if Others.refreshBossUI then
				Others.refreshBossUI(false)
			end
		end
	)
	addOthersToggle(
		CardBossOthers,
		"bossFarm",
		"Auto Boss (Matar Boss Seleccionado)",
		"Va directo hacia el Boss elegido cuando está activo (toma su misión si aplica) y lo derrota"
	)
	addOthersToggle(
		CardBossOthers,
		"allBossFarm",
		"Matar Todos los Bosses",
		"Recorre y mata todos los Bosses activos del servidor actual uno por uno"
	)
	addOthersToggle(
		CardBossOthers,
		"hopFindBoss",
		"Hop Server Find Boss",
		"Cambia de servidor automáticamente si el Boss seleccionado (o todos los Bosses) no están activos",
		function()
			S.spawnedAtClock = os.clock()
		end
	)
end

-- ==================== TAB 3: COMBAT & DOBLE DAÑO ====================
do
	local CardAdvCombat = TabCombat:CreateCard("⚔️ Combate Avanzado (Doble Daño)")
	CardAdvCombat:AddToggle(
		"Doble Daño (Fruit M1 + Melee Oculto)",
		"Ataca con el M1 de la Fruta y encadena un golpe de Melee ocultándose detrás del M1 de la Fruta",
		S.doubleDamage,
		function(v)
			S.doubleDamage = v
			if v then
				setStatus("⚔️ Doble Daño ACTIVADO: Melee oculto detrás del M1 de Blox Fruit")
			else
				setStatus("Doble Daño desactivado")
			end
		end
	)
end

local CardHakiRace = TabCombat:CreateCard("🛡️ Haki & Race Abilities")
CardHakiRace:AddToggle("Auto Buso Haki (Aura)", "Activa automáticamente el Buso Haki al combatir", S.autoBuso, function(v)
	S.autoBuso = v
end)
CardHakiRace:AddToggle("Auto Ken Haki (Instinct)", "Activa automáticamente el Haki de Observación", S.autoKen, function(v)
	S.autoKen = v
end)
CardHakiRace:AddToggle("Auto Race V3 Ability", "Activa la habilidad racial V3 cada vez que esté lista", S.autoRaceV3, function(v)
	S.autoRaceV3 = v
end)
CardHakiRace:AddToggle("Auto Race V4 Awakening", "Activa la transformación V4 automáticamente", S.autoRaceV4, function(v)
	S.autoRaceV4 = v
end)

local CardPlayerBasic = TabCombat:CreateCard("🏃 Basic Player Functions")
CardPlayerBasic:AddToggle("Infinite Energy", "Mantiene tu barra de energía siempre al máximo", S.infEnergy, function(v)
	S.infEnergy = v
end)
CardPlayerBasic:AddToggle("Walk on Water", "Crea plataforma sobre el mar para no recibir daño", S.walkOnWater, function(v)
	S.walkOnWater = v
end)
CardPlayerBasic:AddToggle("No Clip", "Atraviesa paredes y estructuras libremente", S.noClip, function(v)
	S.noClip = v
end)
CardPlayerBasic:AddToggle("Enable Custom WalkSpeed", "Aplica velocidad de movimiento personalizada", S.customSpeedEnabled, function(v)
	S.customSpeedEnabled = v
end)
CardPlayerBasic:AddSlider("WalkSpeed Value", "Velocidad al caminar", 16, 120, S.customWalkSpeed, function(v)
	S.customWalkSpeed = v
end)

-- ==================== TAB 3.5: ADVANCED SETTING SKILLS (GLOBAL) ====================
do
	local HOLD_SLIDER_OPTS = {step = 0.1, suffix = "s"}

	local CardGlobalSkills = TabAdvSkills:CreateCard("⚙️ Control General — Advanced Setting Skills")
	CardGlobalSkills:AddToggle(
		"Activar Auto Skills Global",
		"Rota conscientemente tus armas activas y usa sus skills (integrado también con Eventos Marítimos)",
		S.globalAutoSkills,
		function(v)
			S.globalAutoSkills = v
		end
	)
	CardGlobalSkills:AddToggle(
		"Auto Apuntado de Skills (Aimbot Habilidades)",
		"Fija automáticamente las habilidades de Melee, Blox Fruit, Gun y Sword directo al centro del enemigo",
		S.skillAimlock,
		function(v)
			S.skillAimlock = v
		end
	)
	CardGlobalSkills:AddToggle(
		"Usar Skills en Prioridad Mastery",
		"Al rematar NPCs en Mastery lanza únicamente las skills del arma de Mastery (Blox Fruit o Gun)",
		S.skillsInMastery,
		function(v)
			S.skillsInMastery = v
		end
	)

	-- 1) MELEE (3 Skills: Z, X, C + Independent Hold in Seconds)
	local CardMeleeSkills = TabAdvSkills:CreateCard("🥊 Melee — 3 Habilidades (Z, X, C)")
	CardMeleeSkills:AddToggle(
		"Habilitar Skills de Melee",
		"Incluye tu estilo de pelea (Melee) en la rotación automática de habilidades",
		S.useMeleeSkills,
		function(v)
			S.useMeleeSkills = v
		end
	)
	CardMeleeSkills:AddMultiSelector(
		"Seleccionar Skills — Melee",
		{"Z", "X", "C"},
		S.advSkills["Melee"],
		function(map)
			S.advSkills["Melee"] = map
		end
	)
	CardMeleeSkills:AddSlider(
		"Tiempo de Hold — Melee (Segundos)",
		"Segundos manteniendo presionada la skill (0.0s = toque instantáneo, hasta 3.0s)",
		0, 3, S.advHoldSec["Melee"],
		function(v)
			S.advHoldSec["Melee"] = v
		end,
		HOLD_SLIDER_OPTS
	)

	-- 2) BLOX FRUIT (5 Skills: Z, X, C, V, F + Independent Hold in Seconds)
	local CardFruitSkills = TabAdvSkills:CreateCard("🍎 Blox Fruit — 5 Habilidades (Z, X, C, V, F)")
	CardFruitSkills:AddToggle(
		"Habilitar Skills de Blox Fruit",
		"Incluye tu Blox Fruit en la rotación automática de habilidades",
		S.useFruitSkills,
		function(v)
			S.useFruitSkills = v
		end
	)
	CardFruitSkills:AddMultiSelector(
		"Seleccionar Skills — Blox Fruit",
		{"Z", "X", "C", "V", "F"},
		S.advSkills["Blox Fruit"],
		function(map)
			S.advSkills["Blox Fruit"] = map
		end
	)
	CardFruitSkills:AddSlider(
		"Tiempo de Hold — Blox Fruit (Segundos)",
		"Segundos manteniendo presionada la skill (0.0s = toque instantáneo, hasta 3.0s)",
		0, 3, S.advHoldSec["Blox Fruit"],
		function(v)
			S.advHoldSec["Blox Fruit"] = v
		end,
		HOLD_SLIDER_OPTS
	)

	-- 3) GUN (2 Skills: Z, X + Independent Hold in Seconds)
	local CardGunSkills = TabAdvSkills:CreateCard("🔫 Gun — 2 Habilidades (Z, X)")
	CardGunSkills:AddToggle(
		"Habilitar Skills de Gun",
		"Incluye tu arma de fuego (Gun) en la rotación automática de habilidades",
		S.useGunSkills,
		function(v)
			S.useGunSkills = v
		end
	)
	CardGunSkills:AddMultiSelector(
		"Seleccionar Skills — Gun",
		{"Z", "X"},
		S.advSkills["Gun"],
		function(map)
			S.advSkills["Gun"] = map
		end
	)
	CardGunSkills:AddSlider(
		"Tiempo de Hold — Gun (Segundos)",
		"Segundos manteniendo presionada la skill (0.0s = toque instantáneo, hasta 3.0s)",
		0, 3, S.advHoldSec["Gun"],
		function(v)
			S.advHoldSec["Gun"] = v
		end,
		HOLD_SLIDER_OPTS
	)

	-- 4) SWORD (2 Skills: Z, X + Independent Hold in Seconds)
	local CardSwordSkills = TabAdvSkills:CreateCard("🗡️ Sword — 2 Habilidades (Z, X)")
	CardSwordSkills:AddToggle(
		"Habilitar Skills de Sword",
		"Incluye tu espada (Sword) en la rotación automática de habilidades",
		S.useSwordSkills,
		function(v)
			S.useSwordSkills = v
		end
	)
	CardSwordSkills:AddMultiSelector(
		"Seleccionar Skills — Sword",
		{"Z", "X"},
		S.advSkills["Sword"],
		function(map)
			S.advSkills["Sword"] = map
		end
	)
	CardSwordSkills:AddSlider(
		"Tiempo de Hold — Sword (Segundos)",
		"Segundos manteniendo presionada la skill (0.0s = toque instantáneo, hasta 3.0s)",
		0, 3, S.advHoldSec["Sword"],
		function(v)
			S.advHoldSec["Sword"] = v
		end,
		HOLD_SLIDER_OPTS
	)
end

-- ==================== TAB 4: FRUIT & RAID (DEVIL FRUIT, RAIDS & DUNGEONS) ====================
do
	local CardDevilFruit = TabFruits:CreateCard("🍎 Devil Fruit (Larga Distancia)")
	local autoGachaToggleUI

	-- 1) Single Auto Random Devil Fruit (Long Distance from anywhere)
	autoGachaToggleUI = CardDevilFruit:AddToggle(
		"Auto Random Devil Fruit",
		"Compra fruta aleatoria desde cualquier distancia sin acercarse al vendedor",
		S.autoBuyGacha,
		function(v)
			S.autoBuyGacha = v
			if v then
				rollRandomFruitGacha()
			end
		end
	)
	gachaStatusUpdater = function(txt)
		if autoGachaToggleUI then autoGachaToggleUI.SetSubtitle(txt) end
	end

	-- 2) Auto Store Fruit right next to Auto Random Devil Fruit
	CardDevilFruit:AddToggle(
		"Auto Store Fruit",
		"Guarda automáticamente cualquier fruta obtenida en tu inventario",
		S.autoStoreFruits,
		function(v)
			S.autoStoreFruits = v
			if v then
				storeAnyFruitsInInventory()
			end
		end
	)

	-- 3) Single Auto Buy Devil Fruit (Long Distance from anywhere, zero duplicates)
	local AllStockFruitNames = {
		"Kitsune-Kitsune", "Dragon-Dragon", "Yeti-Yeti", "Gas-Gas", "Tiger-Tiger",
		"Dough-Dough", "T-Rex-T-Rex", "Mammoth-Mammoth", "Spirit-Spirit", "Venom-Venom",
		"Control-Control", "Shadow-Shadow", "Portal-Portal", "Buddha-Buddha", "Lightning-Lightning",
		"Blizzard-Blizzard", "Pain-Pain", "Gravity-Gravity", "Phoenix-Phoenix", "Sound-Sound",
		"Spider-Spider", "Creation-Creation", "Love-Love", "Quake-Quake", "Magma-Magma",
		"Ghost-Ghost", "Rubber-Rubber", "Light-Light", "Diamond-Diamond", "Eagle-Eagle",
		"Dark-Dark", "Sand-Sand", "Ice-Ice", "Flame-Flame", "Spike-Spike", "Smoke-Smoke",
		"Bomb-Bomb", "Spring-Spring", "Blade-Blade", "Spin-Spin", "Rocket-Rocket",
	}
	CardDevilFruit:AddMultiSelector(
		"Select Devil Fruit",
		AllStockFruitNames,
		S.selectedStockFruits,
		function(map)
			S.selectedStockFruits = map
		end
	)
	local autoStockUI = CardDevilFruit:AddToggle(
		"Auto Buy Devil Fruit",
		"Compra desde cualquier distancia la fruta elegida cuando esté disponible",
		S.autoBuyStock,
		function(v)
			S.autoBuyStock = v
			if v and CommF_ then
				task.spawn(function()
					pcall(function()
						local fruits = CommF_:InvokeServer("GetFruits")
						local beliObj = LocalPlayer:FindFirstChild("Data") and LocalPlayer.Data:FindFirstChild("Beli")
						local myBeli = beliObj and beliObj.Value or 0
						if type(fruits) == "table" then
							for _, f in ipairs(fruits) do
								if f.OnSale and f.Name and S.selectedStockFruits[f.Name] and myBeli >= (tonumber(f.Price) or 0) then
									buyFruitFromStock(f.Name)
									break
								end
							end
						end
					end)
				end)
			end
		end
	)
	stockStatusUpdater = function(txt)
		if autoStockUI then autoStockUI.SetSubtitle(txt) end
	end

	-- 2) RAIDS SECTION (ALL POSSIBLE RAIDS, LOW BELI FRUIT, AUTO RAID, HOP RAID, AUTO AWAKE)
	local CardRaids = TabFruits:CreateCard("⚡ Raids (Todas las Raids & Auto Awaken)")
	local allRaidNames = {}
	local seenRaid = {}
	local function addRaidOpt(rName)
		if type(rName) == "string" and rName ~= "" and not seenRaid[rName] then
			seenRaid[rName] = true
			table.insert(allRaidNames, rName)
		end
	end
	pcall(function()
		local raidsMod = require(ReplicatedStorage:FindFirstChild("Raids"))
		if type(raidsMod) == "table" then
			for _, r in ipairs(raidsMod.raids or {}) do addRaidOpt(r) end
			for _, r in ipairs(raidsMod.advancedRaids or {}) do addRaidOpt(r) end
		end
	end)
	for _, fallbackRaid in ipairs({"Flame", "Ice", "Quake", "Light", "Dark", "Spider", "Magma", "Buddha", "Sand", "Phoenix", "Dough"}) do
		addRaidOpt(fallbackRaid)
	end
	if not seenRaid[S.selectedRaid] then
		S.selectedRaid = allRaidNames[1] or "Flame"
	end

	CardRaids:AddModeSelector(
		"Select Raid",
		allRaidNames,
		S.selectedRaid,
		function(val)
			S.selectedRaid = val
		end
	)

	local lowBeliUI = CardRaids:AddToggle(
		"Get Fruit in Inventory Low Beli",
		"Saca la fruta más barata (<1M Beli) de tu inventario para pagar el Microchip",
		S.getLowBeliFruit,
		function(v)
			S.getLowBeliFruit = v
			if v and S.unstoreLowestBeliFruit and (not S.hasSpecialMicrochipTool or not S.hasSpecialMicrochipTool()) then
				task.spawn(function()
					S.unstoreLowestBeliFruit(function(msg)
						setStatus(msg)
					end)
				end)
			elseif not v then
				storeAnyFruitsInInventory()
			end
		end
	)
	table.insert(OthersUI, {key = "getLowBeliFruit", ui = lowBeliUI})

	local autoRaidUI = CardRaids:AddToggle(
		"Auto Raid",
		"Compra el Microchip, inicia la Raid y limpia automáticamente Isla 1 -> Isla 5",
		S.autoRaid,
		function(v)
			S.autoRaid = v
			if not v then
				S.raidTaskRunning = false
				clearFarmMover()
			end
		end
	)
	table.insert(OthersUI, {key = "autoRaid", ui = autoRaidUI})

	local hopRaidUI = CardRaids:AddToggle(
		"Hop Server Raid",
		"Cambia de servidor si las cápsulas están ocupadas o no se puede iniciar la Raid",
		S.hopServerRaid,
		function(v)
			S.hopServerRaid = v
			if v then
				S.spawnedAtClock = os.clock()
			end
		end
	)
	table.insert(OthersUI, {key = "hopServerRaid", ui = hopRaidUI})

	local awakeUI = CardRaids:AddToggle(
		"Auto Awake Fruit",
		"Despierta automáticamente las habilidades de tu fruta equipada tras la Raid",
		S.autoAwakeFruit,
		function(v)
			S.autoAwakeFruit = v
			if v and Others.tryAutoAwakeFruit then
				task.spawn(function()
					Others.tryAutoAwakeFruit(true)
				end)
			end
		end
	)
	table.insert(OthersUI, {key = "autoAwakeFruit", ui = awakeUI})

	-- 3) DUNGEONS PLACEHOLDER (DEFERRED PER USER REQUEST)
	local CardDungeons = TabFruits:CreateCard("🏰 Dungeons (Próximamente)")
	local dBtn
	dBtn = CardDungeons:AddButton(
		"Dungeons (En preparación)",
		"Categoría lista — Implementación completa de Dungeons próximamente",
		"Pronto",
		function()
			if dBtn then
				dBtn.SetSubtitle("🏰 Dungeons se habilitará en una próxima actualización")
			end
		end
	)
end

-- ==================== TAB 5: SEA EVENTS (EVENTOS MARÍTIMOS) ====================
do
	local function addSeaToggle(card, stateKey, title, defaultSub, onEnableExtra, onDisableExtra)
		local uiRef
		uiRef = card:AddToggle(title, defaultSub, S[stateKey], function(v)
			S[stateKey] = v
			if v then
				if onEnableExtra then onEnableExtra() end
				ensureTeamSelected()
			else
				uiRef.SetSubtitle(defaultSub)
				if onDisableExtra then onDisableExtra() end
				if not S.autoSeaEvent and not S.autoMultiFindLevi and not S.leviOwnerAutoBuyBoat and not S.autoStartLeviathan and not S.autoAttackLeviathan and not S.autoMultiSegmentsLevi and not S.autoDeliverLeviHeart and not S.autoSpawnKitsune and not S.tpKitsuneIsland and not S.autoSummonSoulEmber and not S.autoCollectSoulEmber and not S.autoTradeAzureEmber then
					S.seaTaskRunning = false
					if S.cleanupBoatMovers then
						pcall(S.cleanupBoatMovers)
					end
					if not S.levelFarm and not S.stackTaskRunning and not S.othersTaskRunning and not S.raidTaskRunning then
						clearFarmMover()
					end
				end
			end
		end)
		table.insert(OthersUI, {key = stateKey, ui = uiRef})
		return uiRef
	end

	local CardSeaNav = TabSeaEvents:CreateCard("⛵ Navegación, Zonas & Selección de Bote")
	CardSeaNav:AddModeSelector(
		"Seleccionar Zona Marítima",
		{
			"Zona 1 (Danger 1 - Bajo)",
			"Zona 2 (Danger 2 - Moderado)",
			"Zona 3 (Danger 3 - Medio)",
			"Zona 4 (Danger 4 - Alto)",
			"Zona 5 (Danger 5 - Extremo)",
			"Zona 6 (Danger 6 - ???)",
		},
		S.selectedSeaZone,
		function(z)
			S.selectedSeaZone = z
		end
	)
	CardSeaNav:AddModeSelector(
		"Seleccionar Bote",
		{
			"Grand Brigade",
			"Beast Hunter",
			"Guardian",
			"Lantern",
			"Brigade",
			"Sloop",
			"Dinghy",
			"Miracle",
			"The Sentinel",
			"Sleigh",
		},
		S.selectedBoat,
		function(b)
			S.selectedBoat = b
		end
	)
	CardSeaNav:AddSlider(
		"Velocidad del Bote",
		"Velocidad de navegación automática hacia la zona elegida",
		100, 350, S.seaBoatSpeed,
		function(v)
			S.seaBoatSpeed = v
		end
	)
	addSeaToggle(
		CardSeaNav,
		"autoSeaEvent",
		"Auto Eventos Marítimos (Navegar & Cazar)",
		"Compra el bote, navega a la Zona elegida y ataca los eventos seleccionados",
		function()
			Others.returningFrom10km = false
		end,
		function()
			Others.hadActiveSeaBoat = false
			Others.returningFrom10km = false
		end
	)
	CardSeaNav:AddToggle(
		"Vuelo Seguro del Bote (Evitar Rocas / Olas)",
		"Mantiene el bote flotando con NoClip sobre rocas y tormentas de Rough Sea",
		S.seaSafeBoatFly,
		function(v)
			S.seaSafeBoatFly = v
		end
	)
	CardSeaNav:AddToggle(
		"Devolverse a los 10 km (10,000m)",
		"Al llegar a 10 km del puerto da media vuelta automáticamente hasta ~5 km y vuelve a salir",
		S.seaReturnAt10km,
		function(v)
			S.seaReturnAt10km = v
			if not v then
				Others.returningFrom10km = false
			end
		end
	)
	CardSeaNav:AddToggle(
		"Resetear Personaje si el Barco se Destruye o Pierde",
		"Resetea tu personaje automáticamente cuando detecta que el bote fue destruido o se perdió",
		S.seaResetOnBoatLost,
		function(v)
			S.seaResetOnBoatLost = v
		end
	)

	local CardSeaTargets = TabSeaEvents:CreateCard("🦈 Seleccionar Eventos Marítimos a Atacar")
	CardSeaTargets:AddMultiSelector(
		"Seleccionar Eventos a Atacar",
		{
			"Terrorshark",
			"Sea Beast",
			"Pirate Ship Raid",
			"Ghost Ship Raid",
			"Shark",
			"Piranha",
			"Fish Crew Member",
			"Haunted Shipwreck",
		},
		S.selectedSeaEvents,
		function(map)
			S.selectedSeaEvents = map
		end
	)
	CardSeaTargets:AddToggle(
		"Auto Esquivar Ataques Letales (Terrorshark / Sea Beast)",
		"Eleva tu altura automáticamente para evitar el rugido láser o mordida si baja tu vida",
		S.seaDodgeAttacks,
		function(v)
			S.seaDodgeAttacks = v
		end
	)
	CardSeaTargets:AddToggle(
		"Quitar Niebla Oscura Zona 6 (Clear Fog)",
		"Elimina la ceguera oscura de la Zona 6 (???) para tener visión total en el mar",
		S.seaClearFog,
		function(v)
			S.seaClearFog = v
		end
	)

	local CardSeaCombat = TabSeaEvents:CreateCard("⚔️ Armas y Clicks M1 para Eventos")
	CardSeaCombat:AddMultiSelector(
		"Seleccionar Armas (Eventos Marítimos)",
		{"Blox Fruit", "Melee", "Sword", "Gun"},
		S.seaWeapons,
		function(map)
			S.seaWeapons = map
		end
	)
	CardSeaCombat:AddToggle(
		"Usar M1 (Clicks de la Fruta) para Eventos",
		"Dispara los clicks M1 de tu Blox Fruit contra Sea Beasts, Barcos, Terrorshark y eventos",
		S.seaUseFruitM1,
		function(v)
			S.seaUseFruitM1 = v
		end
	)
	CardSeaCombat:AddToggle(
		"Usar Ataque Básico (M1 Armas) en Eventos",
		"Usa golpes básicos M1 de Melee, Sword y Gun en los eventos marítimos",
		S.seaUseM1,
		function(v)
			S.seaUseM1 = v
		end
	)

	local CardLeviathan = TabSeaEvents:CreateCard("🐉 Leviatán (Multi-Find, Auto Start & Corazón)")
	local function getLeviPlayerOptionList()
		local list = {}
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer then
				local label = (plr.DisplayName and plr.DisplayName ~= "" and plr.DisplayName ~= plr.Name)
					and string.format("%s (@%s)", plr.DisplayName, plr.Name)
					or plr.Name
				table.insert(list, label)
			end
		end
		table.sort(list, function(a, b)
			return a:lower() < b:lower()
		end)
		if #list == 0 then
			table.insert(list, "(Sin otros jugadores en el servidor)")
		end
		return list
	end

	local leviPlayersSelector = CardLeviathan:AddMultiSelector(
		"Seleccionar Jugadores (Multi-Find)",
		getLeviPlayerOptionList(),
		S.selectedLeviPlayers,
		function(map)
			map["(Sin otros jugadores en el servidor)"] = nil
			S.selectedLeviPlayers = map
		end
	)
	local leviRefreshBtn
	local function syncLeviPlayerSelector(manualRefresh)
		local freshList = getLeviPlayerOptionList()
		local validSet = {}
		local realCount = 0
		for _, opt in ipairs(freshList) do
			if opt ~= "(Sin otros jugadores en el servidor)" then
				validSet[opt] = true
				realCount = realCount + 1
			end
		end
		S.selectedLeviPlayers["(Sin otros jugadores en el servidor)"] = nil
		if manualRefresh then
			for k in pairs(S.selectedLeviPlayers) do
				if not validSet[k] then
					S.selectedLeviPlayers[k] = nil
				end
			end
		end
		if leviPlayersSelector and leviPlayersSelector.SetOptions then
			leviPlayersSelector.SetOptions(freshList)
		end
		if leviRefreshBtn and leviRefreshBtn.SetSubtitle then
			leviRefreshBtn.SetSubtitle(string.format("Lista actualizada (%d jugadores en el servidor)", realCount))
		end
	end
	leviRefreshBtn = CardLeviathan:AddButton(
		"Refrescar Jugadores (Multi-Find)",
		"Actualiza la lista de jugadores disponibles en el servidor actual",
		"Refresh",
		function()
			syncLeviPlayerSelector(true)
		end
	)
	connect(Players.PlayerAdded, function()
		task.delay(0.25, function() syncLeviPlayerSelector(false) end)
	end)
	connect(Players.PlayerRemoving, function()
		task.delay(0.25, function() syncLeviPlayerSelector(false) end)
	end)

	addSeaToggle(
		CardLeviathan,
		"autoMultiFindLevi",
		"Multi-Find Leviatán (Equipo / Multicuenta)",
		"Sincroniza con los jugadores elegidos: el dueño los espera y los demás suben a su bote",
		function()
			Others.leviCrewDeparted = false
			Others.returningFrom10km = false
		end,
		function()
			Others.leviCrewDeparted = false
		end
	)
	addSeaToggle(
		CardLeviathan,
		"leviOwnerAutoBuyBoat",
		"Auto Comprar Bote (Solo Dueño)",
		"Actívalo únicamente en el dueño para comprar y conducir el bote del equipo",
		function()
			Others.leviCrewDeparted = false
		end,
		function()
			Others.hadActiveSeaBoat = false
			Others.leviCrewDeparted = false
		end
	)
	addSeaToggle(
		CardLeviathan,
		"autoStartLeviathan",
		"Auto Start Leviatán",
		"Soborna al Spy, reúne al equipo en Frozen Dimension e inicia el Leviatán automáticamente",
		function()
			Others.spyBribeDone = false
			Others.frozenGateArriveClock = 0
		end,
		function()
			Others.frozenGateArriveClock = 0
		end
	)
	addSeaToggle(
		CardLeviathan,
		"autoAttackLeviathan",
		"Atacar Leviatán",
		"Abre la puerta en Frozen Dimension y ataca al Leviatán automáticamente"
	)
	addSeaToggle(
		CardLeviathan,
		"autoMultiSegmentsLevi",
		"Atacar Multisegmentos (Leviatán)",
		"Ataca y barre todos los segmentos del Leviatán a la vez para romper su escudo"
	)
	CardLeviathan:AddModeSelector(
		"Destino del Corazón (Tiki / Hydra)",
		{
			"Tiki Outpost",
			"Hydra Island",
		},
		S.leviHeartDestination,
		function(dest)
			S.leviHeartDestination = dest
		end
	)
	addSeaToggle(
		CardLeviathan,
		"autoDeliverLeviHeart",
		"Llevar Corazón a Tiki o Hydra",
		"Engancha el Leviathan Heart con el arpón del Beast Hunter y lo lleva a Tiki o Hydra"
	)

	local CardKitsune = TabSeaEvents:CreateCard("🦊 Kitsune Island & Soul / Azure Embers")
	addSeaToggle(
		CardKitsune,
		"tpKitsuneIsland",
		"Teleport Kitsune Island",
		"Vuela directamente hacia Kitsune Island en cuanto esté activa en el servidor"
	)
	addSeaToggle(
		CardKitsune,
		"hopNearFullMoon",
		"Hop Server (Next Night / Near Full Moon ~2 min)",
		"Busca servidor con Full Moon activa o a ~2 minutos de empezar la noche de luna llena",
		function()
			S.spawnedAtClock = os.clock()
		end
	)
	addSeaToggle(
		CardKitsune,
		"autoSpawnKitsune",
		"Auto Spawn Kitsune Island",
		"Compra bote y navega por el borde Zona 5 / Zona 6 en Full Moon hasta spawnear Kitsune Island",
		nil,
		function()
			Others.hadActiveSeaBoat = false
		end
	)
	addSeaToggle(
		CardKitsune,
		"autoSummonSoulEmber",
		"Auto Summon Soul Ember",
		"Toca automáticamente la estatua del Kitsune Shrine para invocar las Soul Embers"
	)
	addSeaToggle(
		CardKitsune,
		"autoCollectSoulEmber",
		"Auto Collect Soul Ember",
		"Atrapa todas las llamas Soul / Azure Embers alrededor de Kitsune Island hasta el límite"
	)
	CardKitsune:AddSlider(
		"Límite de Soul Embers (0 - 25)",
		"Escoge cuántas Soul Embers recolectar antes de parar o tradear (0 - 25)",
		0, 25, S.soulEmberLimit,
		function(v)
			S.soulEmberLimit = v
		end
	)
	addSeaToggle(
		CardKitsune,
		"autoTradeAzureEmber",
		"Auto Tradear Azure Ember",
		"Entrega tus Azure Embers en el Kitsune Shrine al llegar al límite elegido"
	)
end

-- ==================== TAB 6: SHOP (EVERYTHING EXCEPT FRUITS) ====================
local CardStyles = TabShop:CreateCard("🥋 Fighting Styles (NPC Approach & Equip)")
local styleList = {
	"Dark Step", "Electro", "Water Kung Fu", "Dragon Breath", "Superhuman",
	"Death Step", "Sharkman Karate", "Electric Claw", "Dragon Talon", "Godhuman", "Sanguine Art"
}
local styleShopToggleUI, styleBuyEquipBtn, styleEquipOnlyBtn

CardStyles:AddModeSelector("Select Fighting Style", styleList, S.selectedStyle, function(st)
	S.selectedStyle = st
	if S.autoStyleShop then
		goToTeacherAndBuyOrEquipStyle(S.selectedStyle, function(txt)
			if styleShopToggleUI then styleShopToggleUI.SetSubtitle(txt) end
			if styleBuyEquipBtn then styleBuyEquipBtn.SetSubtitle(txt) end
		end)
	end
end)

styleShopToggleUI = CardStyles:AddToggle(
	"Auto Go to NPC, Buy & Equip",
	"Va hacia el NPC maestro, compra el estilo o cambia a él, y se lo equipa en mano",
	S.autoStyleShop,
	function(v)
		S.autoStyleShop = v
		if v then
			goToTeacherAndBuyOrEquipStyle(S.selectedStyle, function(txt)
				styleShopToggleUI.SetSubtitle(txt)
				if styleBuyEquipBtn then styleBuyEquipBtn.SetSubtitle(txt) end
			end)
		else
			S.styleShopBusy = false
			clearFarmMover()
		end
	end
)

styleBuyEquipBtn = CardStyles:AddButton(
	"Go to NPC, Buy & Equip Style",
	"Aborda al NPC del estilo elegido, lo compra/desbloquea y lo equipa en tu mano",
	"Buy & Equip",
	function()
		goToTeacherAndBuyOrEquipStyle(S.selectedStyle, function(txt)
			styleBuyEquipBtn.SetSubtitle(txt)
			if styleShopToggleUI then styleShopToggleUI.SetSubtitle(txt) end
		end)
	end
)

styleEquipOnlyBtn = CardStyles:AddButton(
	"Go to NPC & Equip Style",
	"Si ya tienes el estilo, va al NPC para activarlo y se lo equipa en la mano",
	"Equip Style",
	function()
		goToTeacherAndBuyOrEquipStyle(S.selectedStyle, function(txt)
			styleEquipOnlyBtn.SetSubtitle(txt)
			if styleShopToggleUI then styleShopToggleUI.SetSubtitle(txt) end
		end)
	end
)

local CardAbilities = TabShop:CreateCard("⚡ Abilities, Haki & Race")
local abilityList = {
	"Buso Haki (Aura)", "Geppo (Skyjump)", "Soru (Flash Step)", "Ken Haki (Instinct)",
	"Random Bone Surprise", "Stat Refund (2,500f)", "Race Reroll (3,000f)",
	"Cyborg Race (2,500f)", "Ghoul Race (100 Ect)"
}
CardAbilities:AddModeSelector("Select Ability / Service", abilityList, S.selectedAbility, function(ab)
	S.selectedAbility = ab
end)
CardAbilities:AddButton("Buy Ability / Service", "Adquiere la habilidad o servicio seleccionado", "Buy Now", function()
	local fn = AbilityRemotes[S.selectedAbility]
	if fn then pcall(fn) end
end)

local CardSwords = TabShop:CreateCard("🗡️ Swords Shop")
local swordShopList = {
	"Katana", "Cutlass", "Dual Katana", "Iron Mace", "Triple Katana",
	"Pipe", "Dual-Headed Blade", "Bisento", "Soul Cane"
}
CardSwords:AddModeSelector("Select Sword", swordShopList, S.selectedSword, function(sw)
	S.selectedSword = sw
end)
CardSwords:AddButton("Buy Selected Sword", "Compra la espada seleccionada con Beli", "Buy Sword", function()
	buyShopItem(S.selectedSword)
end)

local CardGuns = TabShop:CreateCard("🔫 Guns & Accessories")
local gunAndAccList = {
	"Slingshot", "Musket", "Flintlock", "Refined Slingshot", "Dual Flintlock",
	"Cannon", "Black Cape", "Swordsman Hat", "Tomoe Ring"
}
CardGuns:AddModeSelector("Select Gun or Accessory", gunAndAccList, S.selectedGun, function(gn)
	S.selectedGun = gn
end)
CardGuns:AddButton("Buy Selected Item", "Compra el arma de fuego o accesorio seleccionado", "Buy Item", function()
	buyShopItem(S.selectedGun)
end)

-- ==================== TAB 6: SERVER STATUS, OPTIMIZACIÓN & HOP ====================
do
	local CardServerStatus = TabServer:CreateCard("📡 Estatus del Servidor (Tiempo Real)")
	local rowServerTime = CardServerStatus:AddInfoRow(
		"🕒 Hora del Servidor",
		"Cargando reloj del juego y tiempo activo del servidor...",
		"Cargando...",
		Color3.fromRGB(96, 165, 250)
	)
	local rowMirage = CardServerStatus:AddInfoRow(
		"🏝️ Mirage Island (Isla Espejismo)",
		"Verificando presencia de Mirage Island en el mapa...",
		"Verificando",
		Color3.fromRGB(160, 160, 175)
	)
	local rowMoon = CardServerStatus:AddInfoRow(
		"🌕 Fase de la Luna (Moon Phase)",
		"Detectando fase lunar actual del servidor...",
		"Cargando...",
		Color3.fromRGB(250, 204, 21)
	)
	local rowServerExtra = CardServerStatus:AddInfoRow(
		"🌊 Islas Especiales & Jugadores",
		"Escaneando eventos globales y jugadores conectados...",
		"0/12",
		Color3.fromRGB(52, 211, 153)
	)

	task.spawn(function()
		local MOON_NAMES = {
			[1] = "🌑 Luna Nueva / Menguante (1/5)",
			[2] = "🌒 Luna Creciente (2/5)",
			[3] = "🌓 Cuarto Lunar / Media Luna (3/5)",
			[4] = "🌔 Gibosa Creciente — Próxima Llena (4/5)",
			[5] = "🌕 Luna Llena / Full Moon (5/5)",
		}
		local MOON_BADGES = {
			[1] = {"🌑 FASE 1/5", Color3.fromRGB(148, 163, 184)},
			[2] = {"🌒 FASE 2/5", Color3.fromRGB(147, 197, 253)},
			[3] = {"🌓 FASE 3/5", Color3.fromRGB(96, 165, 250)},
			[4] = {"🌔 FASE 4/5", Color3.fromRGB(251, 191, 36)},
			[5] = {"🌕 LLENA 5/5", Color3.fromRGB(48, 209, 88)},
		}

		while isAlive() do
			pcall(function()
				local lighting = game:GetService("Lighting")
				local ct = tonumber(lighting.ClockTime) or 12.0
				local tod = tostring(lighting.TimeOfDay or "12:00:00"):sub(1, 8)
				local hhmm = tod:sub(1, 5)
				local isDay = (ct >= 6.0 and ct < 18.0)

				local upSec = math.max(0, math.floor(tonumber(Workspace.DistributedGameTime) or 0))
				local upH = math.floor(upSec / 3600)
				local upM = math.floor((upSec % 3600) / 60)
				local upS = upSec % 60
				local uptimeStr = string.format("%02dh %02dm %02ds", upH, upM, upS)

				rowServerTime.SetSubtitle(string.format(
					"Hora Juego: %s (%s)  |  Tiempo Servidor: %s",
					tod, isDay and "Día ☀️" or "Noche 🌙", uptimeStr
				))
				rowServerTime.SetBadge(
					(isDay and "☀️ " or "🌙 ") .. hhmm,
					isDay and Color3.fromRGB(251, 191, 36) or Color3.fromRGB(129, 140, 248)
				)

				-- Mirage Island live check
				local seaNum = getCurrentSeaNumber()
				local miragePos = nil
				local map = Workspace:FindFirstChild("Map")
				local mystic = map and map:FindFirstChild("MysticIsland")
				if mystic then
					local okP, cfP = pcall(function()
						return mystic:IsA("Model") and mystic:GetPivot() or mystic.CFrame
					end)
					if okP and cfP then
						miragePos = cfP.Position
					end
				end
				if not miragePos then
					local wo = Workspace:FindFirstChild("_WorldOrigin")
					local locs = wo and wo:FindFirstChild("Locations")
					if locs then
						for _, loc in ipairs(locs:GetChildren()) do
							if loc:IsA("BasePart") and (loc.Name == "Mirage Island" or loc.Name:find("Mirage")) then
								miragePos = loc.Position
								break
							end
						end
					end
				end

				if miragePos then
					local myChar = LocalPlayer.Character
					local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
					local distTxt = myHrp and string.format(" [%dm]", math.floor((myHrp.Position - miragePos).Magnitude)) or ""
					rowMirage.SetSubtitle("✨ ¡Mirage Island ACTIVA en este servidor!" .. distTxt)
					rowMirage.SetBadge("ACTIVA ✅", Color3.fromRGB(48, 209, 88))
				else
					if seaNum == 3 then
						rowMirage.SetSubtitle("No hay Mirage Island activa en este momento (Sea 3)")
					else
						rowMirage.SetSubtitle(string.format("No activa (Mirage spawnea en Sea 3 — actual: Sea %d)", seaNum))
					end
					rowMirage.SetBadge("NO ACTIVA ❌", Color3.fromRGB(255, 95, 86))
				end

				-- Moon Phase live check
				local moonPhase = tonumber(lighting:GetAttribute("MoonPhase"))
				local isBlueMoon = (lighting:GetAttribute("IsBlueMoon") == true)
				local blueMoonEnded = (lighting:GetAttribute("BlueMoonEnded") == true)
				if moonPhase == nil then
					local sky = lighting:FindFirstChildOfClass("Sky")
					local tex = sky and tostring(sky.MoonTextureId or "") or ""
					if tex:find("9709149431") then moonPhase = 5
					elseif tex:find("9709149052") then moonPhase = 4
					elseif tex:find("9709143733") then moonPhase = 3
					elseif tex:find("9709139597") then moonPhase = 2
					elseif tex ~= "" then moonPhase = 1
					end
				end

				if isBlueMoon then
					rowMoon.SetSubtitle("🔵 ¡Luna Azul (Blue Moon) ACTIVA! Santuario Kitsune abierto")
					rowMoon.SetBadge("🔵 BLUE MOON", Color3.fromRGB(56, 189, 248))
				elseif moonPhase and MOON_NAMES[moonPhase] then
					local mName = MOON_NAMES[moonPhase]
					local bInfo = MOON_BADGES[moonPhase]
					local extraNote = ""
					if moonPhase == 5 and (ct >= 18.0 or ct < 5.0) and not blueMoonEnded then
						extraNote = " — ¡ACTIVA AHORA!"
					elseif moonPhase == 5 and ct < 18.0 then
						extraNote = string.format(" — Inicia en ~%.1f min", math.max(0.1, 18.0 - ct))
					elseif moonPhase == 4 then
						local mins = (ct <= 18.0) and (18.0 - ct) or ((24.0 - ct) + 18.0)
						extraNote = string.format(" — Llena en ~%d min", math.max(1, math.floor(mins + 0.5)))
					else
						local cyclesAhead = (5 - moonPhase)
						local mins = math.max(1, math.floor((cyclesAhead - 1) * 24 + ((24.0 - ct) + 18.0)))
						extraNote = string.format(" (~%d min para Llena)", mins)
					end
					rowMoon.SetSubtitle(mName .. extraNote)
					rowMoon.SetBadge(bInfo[1], bInfo[2])
				else
					rowMoon.SetSubtitle("Reloj lunar sincronizando (" .. hhmm .. ")...")
					rowMoon.SetBadge("FASE ?/5", Color3.fromRGB(160, 160, 175))
				end

				-- Extra Special Islands & Players count
				local specials = {}
				if map then
					if map:FindFirstChild("KitsuneIsland") then table.insert(specials, "Kitsune 🦊") end
					if map:FindFirstChild("PrehistoricIsland") then table.insert(specials, "Prehistoric 🌋") end
					if map:FindFirstChild("FrozenDimension") then table.insert(specials, "Frozen ❄️") end
				end
				local wo = Workspace:FindFirstChild("_WorldOrigin")
				local locs = wo and wo:FindFirstChild("Locations")
				if locs then
					for _, l in ipairs(locs:GetChildren()) do
						if l.Name:find("Kitsune") and not table.concat(specials, " "):find("Kitsune") then
							table.insert(specials, "Kitsune 🦊")
						elseif l.Name:find("Prehistoric") and not table.concat(specials, " "):find("Prehistoric") then
							table.insert(specials, "Prehistoric 🌋")
						elseif l.Name:find("Frozen Dimension") and not table.concat(specials, " "):find("Frozen") then
							table.insert(specials, "Frozen ❄️")
						end
					end
				end
				local pCount = #Players:GetPlayers()
				local pMax = Players.MaxPlayers or 12
				local specTxt = (#specials > 0) and ("Islas activas: " .. table.concat(specials, ", ")) or "Sin otras islas míticas activas"
				rowServerExtra.SetSubtitle(string.format("Sea %d  |  %s", seaNum, specTxt))
				rowServerExtra.SetBadge(
					string.format("👥 %d/%d  Sea %d", pCount, pMax, seaNum),
					(#specials > 0) and Color3.fromRGB(48, 209, 88) or Color3.fromRGB(52, 211, 153)
				)
			end)
			task.wait(1.0)
		end
	end)

	local CardOptim = TabServer:CreateCard("🚀 Optimización & Rendimiento (FPS Boost)")
	CardOptim:AddToggle(
		"Modo Optimización (FPS Boost)",
		"Simplifica materiales, sombras, reflejos del agua y post-procesado para subir tus FPS",
		S.fpsBoost,
		function(v)
			S.fpsBoost = v
			if v and S.runOptimizationPass then
				task.spawn(function() S.runOptimizationPass(true) end)
				setStatus("🚀 FPS Boost ACTIVADO: Gráficos y materiales optimizados")
			end
		end
	)
	CardOptim:AddToggle(
		"Reducir Efectos / Partículas VFX (Anti-Lag)",
		"Oculta partículas pesadas, explosiones, humo y trazos al usar Skills y Doble Daño",
		S.reduceAttackVFX,
		function(v)
			S.reduceAttackVFX = v
			if v and S.runOptimizationPass then
				task.spawn(function() S.runOptimizationPass(false) end)
			end
		end
	)
	CardOptim:AddToggle(
		"Auto Optimizar Memoria & Caché",
		"Limpia referencias obsoletas y modera escaneos en segundo plano para evitar tirones",
		S.optimizeMemory,
		function(v)
			S.optimizeMemory = v
		end
	)
end

local CardServerHop = TabServer:CreateCard("🌐 Server Hop")
CardServerHop:AddModeSelector(
	"Server Hop Filter",
	{"Low Players", "Random Server", "Best Ping"},
	S.serverHopMode,
	function(m)
		S.serverHopMode = m
	end
)
srvHopBtn = CardServerHop:AddButton(
	"Server Hop Now",
	"Busca y entra a un nuevo servidor según el filtro",
	"Hop Now",
	function()
		executeServerHop(S.serverHopMode)
	end
)
CardServerHop:AddButton(
	"Rejoin Current Server",
	"Reconecta inmediatamente a este mismo servidor",
	"Rejoin",
	function()
		setStatus("Reconectando al servidor actual...")
		pcall(function()
			TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
		end)
	end
)
CardServerHop:AddButton(
	"Elegir / Cambiar Bando: Pirates",
	"Selecciona o cambia inmediatamente al bando de Piratas",
	"Pirates",
	function()
		S.preferredTeam = "Pirates"
		if CommF_ then
			task.spawn(function()
				pcall(function() CommF_:InvokeServer("SetTeam", "Pirates") end)
				setStatus("🏴‍☠️ Bando seleccionado: Pirates")
			end)
		end
	end
)
CardServerHop:AddButton(
	"Elegir / Cambiar Bando: Marines",
	"Selecciona o cambia inmediatamente al bando de Marines",
	"Marines",
	function()
		S.preferredTeam = "Marines"
		if CommF_ then
			task.spawn(function()
				pcall(function() CommF_:InvokeServer("SetTeam", "Marines") end)
				setStatus("⚓ Bando seleccionado: Marines")
			end)
		end
	end
)
CardServerHop:AddToggle(
	"Safe Hop on Player Nearby",
	"Cambia de servidor si otro jugador se acerca a tu zona de farm",
	S.hopOnPlayerNear,
	function(v)
		S.hopOnPlayerNear = v
	end
)

local CardStats = TabServer:CreateCard("📊 Auto Stats")
CardStats:AddModeSelector(
	"Select Priority Stat",
	{"Melee", "Defense", "Sword", "Gun", "Demon Fruit"},
	S.statTarget,
	function(st)
		S.statTarget = st
	end
)
CardStats:AddToggle(
	"Auto Upgrade Stat",
	"Asigna tus puntos de estadística automáticamente",
	S.autoStats,
	function(v)
		S.autoStats = v
	end
)
CardStats:AddSlider(
	"Points Per Upgrade",
	"Cantidad de puntos asignados por ciclo",
	1, 25, S.statPointsPerTick,
	function(v)
		S.statPointsPerTick = v
	end
)

-- ==================== TAB 7: TELEPORT & ESP ====================
local CardSeaTravel = TabTeleport:CreateCard("🌊 Sea Travel & Islands")
CardSeaTravel:AddModeSelector(
	"Select Sea Destination",
	{"First Sea (Main)", "Second Sea (Dressrosa)", "Third Sea (Zou)"},
	S.selectedSea,
	function(sea)
		S.selectedSea = sea
	end
)
CardSeaTravel:AddButton("Travel to Selected Sea", "Teletransporta al Sea seleccionado", "Travel", function()
	if not CommF_ then return end
	pcall(function()
		if S.selectedSea:find("First") then
			CommF_:InvokeServer("TravelMain")
		elseif S.selectedSea:find("Second") then
			CommF_:InvokeServer("TravelDressrosa")
		else
			CommF_:InvokeServer("TravelZou")
		end
	end)
end)

local islandNames = {}
local islandPositions = {}
do
	local function addIslandOption(name, cf)
		if not islandPositions[name] then
			islandPositions[name] = cf
			table.insert(islandNames, name)
		end
	end

	local seaNum = getCurrentSeaNumber()
	if seaNum == 2 then
		addIslandOption("Cursed Ship (Interior - Lv. 1250)", CFrame.new(923.2, 127.0, 32852.8))
		addIslandOption("Cursed Ship (Portal Exterior)", CFrame.new(-6496.9, 89.0, -116.5))
	elseif seaNum == 1 then
		addIslandOption("Underwater City (Interior - Lv. 375)", CFrame.new(61163.8, 15.0, 1819.8))
		addIslandOption("Upper Skylands (Templo - Lv. 450)", CFrame.new(-7894.6, 5550.0, -380.3))
	elseif seaNum == 3 then
		addIslandOption("Floating Turtle (Mansion)", CFrame.new(-12462.6, 375.0, -7551.8))
		addIslandOption("Castle on the Sea", CFrame.new(-5075.5, 315.0, -3150.0))
		addIslandOption("Hydra Island", CFrame.new(5748.9, 611.0, -282.5))
	end

	local wo = Workspace:FindFirstChild("_WorldOrigin")
	local locs = wo and wo:FindFirstChild("Locations")
	if locs then
		for _, loc in ipairs(locs:GetChildren()) do
			if loc:IsA("BasePart") and loc.Name ~= "Sea" and not islandPositions[loc.Name] then
				addIslandOption(loc.Name, loc.CFrame + Vector3.new(0, 40, 0))
			end
		end
	end
	table.sort(islandNames)
	if #islandNames == 0 then
		islandNames = {"Middle Town"}
	end
	S.selectedIsland = islandNames[1]
end

CardSeaTravel:AddModeSelector("Select Island", islandNames, S.selectedIsland, function(isl)
	S.selectedIsland = isl
end)
CardSeaTravel:AddButton("Tween to Island (200 Speed)", "Vuela suavemente hacia la isla elegida (usando portales si aplica)", "Tween", function()
	local targetCF = islandPositions[S.selectedIsland]
	if not targetCF then return end
	S.islandTweenBusy = true
	task.spawn(function()
		local startClock = os.clock()
		while isAlive() and S.islandTweenBusy and (os.clock() - startClock < 90) do
			local char = LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if not hrp then break end
			local pRoute = resolveSmartPortalRoute(hrp.Position, targetCF.Position)
			if pRoute then
				setStatus("Teleport Isla: " .. pRoute.label .. " -> " .. tostring(S.selectedIsland))
			else
				setStatus("Volando a isla: " .. tostring(S.selectedIsland))
			end
			local reached = moveToCFrame(targetCF)
			if reached or (hrp.Position - targetCF.Position).Magnitude <= 18 then
				setStatus("Llegaste a: " .. tostring(S.selectedIsland))
				break
			end
			task.wait(0.14)
		end
		S.islandTweenBusy = false
	end)
end)
CardSeaTravel:AddButton("Stop Tween", "Detiene cualquier movimiento activo", "Stop", function()
	clearFarmMover()
end)

local CardESP = TabTeleport:CreateCard("👁️ ESP Visuals")
CardESP:AddToggle("Enemy ESP", "Muestra nombre, vida y distancia de los NPCs", S.espEnemies, function(v)
	S.espEnemies = v
end)
CardESP:AddToggle("Player ESP", "Muestra ubicación y vida de otros jugadores", S.espPlayers, function(v)
	S.espPlayers = v
end)
CardESP:AddToggle("Devil Fruit ESP", "Resalta frutas del diablo en el mapa", S.espFruits, function(v)
	S.espFruits = v
end)
CardESP:AddToggle("Chest ESP", "Muestra cofres cercanos en pantalla", S.espChests, function(v)
	S.espChests = v
end)

onStatusChanged = function(msg)
	pcall(function()
		levelFarmToggleUI.SetSubtitle(msg)
		srvHopBtn.SetSubtitle(msg)
		for _, entry in ipairs(StackUI) do
			if S[entry.key] then
				entry.ui.SetSubtitle(msg)
			end
		end
		for _, entry in ipairs(OthersUI) do
			if S[entry.key] then
				entry.ui.SetSubtitle(msg)
			end
		end
	end)
end

selectTab(1)
end -- end 7 Tabs builder scope

-- Minimize / Restore Floating Button + RightControl
local FloatBtn = Instance.new("TextButton")
FloatBtn.Name = "SwitchHub_FloatToggle"
FloatBtn.Size = UDim2.new(0, 110, 0, 32)
FloatBtn.Position = UDim2.new(0, 18, 0.5, -16)
FloatBtn.BackgroundColor3 = C.SidebarBg
FloatBtn.BorderSizePixel = 0
FloatBtn.Text = "⚡ Switch Hub"
FloatBtn.Font = Enum.Font.GothamMedium
FloatBtn.TextSize = 12
FloatBtn.TextColor3 = C.TextWhite
FloatBtn.Visible = false
FloatBtn.Parent = ScreenGui

local fbc = Instance.new("UICorner")
fbc.CornerRadius = UDim.new(0, 8)
fbc.Parent = FloatBtn

local fbs = Instance.new("UIStroke")
fbs.Color = C.WindowBorder
fbs.Thickness = 1
fbs.Parent = FloatBtn

connect(DotsBtn.MouseButton1Click, function()
	MainWindow.Visible = false
	FloatBtn.Visible = true
end)

connect(FloatBtn.MouseButton1Click, function()
	MainWindow.Visible = true
	FloatBtn.Visible = false
end)

connect(UserInputService.InputBegan, function(input, gpe)
	if not gpe and input.KeyCode == Enum.KeyCode.RightControl then
		MainWindow.Visible = not MainWindow.Visible
		FloatBtn.Visible = not MainWindow.Visible
	end
end)

connect(LocalPlayer.Idled, function()
	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end)
end)

-- If player has NOT chosen Pirates/Marines yet, keep MainWindow minimized to FloatBtn so team buttons stay 100% uncovered,
-- then pop MainWindow open automatically as soon as they choose their team!
if S.isChooseTeamScreenOpen and S.isChooseTeamScreenOpen() then
	MainWindow.Visible = false
	FloatBtn.Visible = true
	task.spawn(function()
		while isAlive() and S.isChooseTeamScreenOpen and S.isChooseTeamScreenOpen() do
			task.wait(0.25)
		end
		if isAlive() and not MainWindow.Visible then
			MainWindow.Visible = true
			FloatBtn.Visible = false
		end
	end)
end

--------------------------------------------------------------------------------
-- BACKGROUND LOOPS (FARM, STACK FARMING, MASTERY PRIORITY, COMBAT, FRUITS, ESP)
--------------------------------------------------------------------------------
do
	local cachedSteppedChar = nil
	local cachedSteppedParts = {}
	local lastCharPartsRefresh = 0
	local waterPlaneElevated = false

	local function getCachedCharacterParts(char)
		local now = os.clock()
		if char ~= cachedSteppedChar or (now - lastCharPartsRefresh > 1.5) then
			cachedSteppedChar = char
			lastCharPartsRefresh = now
			table.clear(cachedSteppedParts)
			for _, inst in ipairs(char:GetDescendants()) do
				if inst:IsA("BasePart") then
					table.insert(cachedSteppedParts, inst)
				end
			end
		end
		return cachedSteppedParts
	end

	connect(RunService.Stepped, function()
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if char then
			if S.levelFarm or S.bossFarm or S.allBossFarm or S.autoFirstSeaComplete or S.autoSecondSeaComplete or S.stackTaskRunning or S.othersTaskRunning or S.raidTaskRunning or S.seaTaskRunning or S.styleShopBusy or S.islandTweenBusy or S.noClip then
				for _, part in ipairs(getCachedCharacterParts(char)) do
					if part.Parent and part.CanCollide then
						part.CanCollide = false
					end
				end
			end
			if S.infEnergy and char:FindFirstChild("Energy") then
				pcall(function()
					char.Energy.Value = char.Energy.MaxValue
				end)
			end
			if S.customSpeedEnabled and hum then
				hum.WalkSpeed = S.customWalkSpeed
			end
		end
		if (S.autoSeaEvent or S.autoMultiFindLevi or S.leviOwnerAutoBuyBoat or S.autoStartLeviathan or S.autoAttackLeviathan or S.autoMultiSegmentsLevi or S.autoDeliverLeviHeart or S.autoSpawnKitsune or S.seaTaskRunning) and S.seaClearFog then
			pcall(function()
				local lighting = game:GetService("Lighting")
				if lighting.FogEnd < 90000 then
					lighting.FogEnd = 100000
					lighting.FogStart = 100000
				end
				for _, ch in ipairs(lighting:GetChildren()) do
					if ch:IsA("Atmosphere") and ch.Density > 0 then
						ch.Density = 0
					end
				end
			end)
		end
		if getActiveAimlockPart() ~= nil and S.lastAimEnemy and S.lastAimEnemy.Parent then
			updateMasteryAimTarget(S.lastAimEnemy)
		end
		local shouldElevateWater = S.walkOnWater and (hum ~= nil and hum.SeatPart == nil)
		if shouldElevateWater or waterPlaneElevated then
			local map = Workspace:FindFirstChild("Map")
			local water = map and map:FindFirstChild("WaterBase-Plane")
			if water and water:IsA("BasePart") then
				if shouldElevateWater then
					if math.abs(water.Size.Y - 112) > 0.5 then
						water.Size = Vector3.new(water.Size.X, 112, water.Size.Z)
					end
					waterPlaneElevated = true
				else
					if math.abs(water.Size.Y - 80) > 0.5 then
						water.Size = Vector3.new(water.Size.X, 80, water.Size.Z)
					end
					waterPlaneElevated = false
				end
			end
		end
	end)
end

local BoneMobSet = {
	["Reborn Skeleton"] = true,
	["Living Zombie"] = true,
	["Demonic Soul"] = true,
	["Posessed Mummy"] = true,
}
local KatakuriMobSet = {
	["Cake Prince"] = true,
	["Dough King"] = true,
	["Cookie Crafter"] = true,
	["Cake Guard"] = true,
	["Baking Staff"] = true,
	["Head Baker"] = true,
}

local function collectSpawnsForSet(mobSet)
	local spawnMap = getCurrentSpawnMap()
	local list = {}
	for mobName, cfs in pairs(spawnMap) do
		if mobSet[mobName] then
			for _, cf in ipairs(cfs) do
				table.insert(list, cf)
			end
		end
	end
	return list
end

local function findNearestChestPart(excludedMap)
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil, math.huge end

	local bestPart = nil
	local bestDist = math.huge
	local CS = game:GetService("CollectionService")

	-- 1) Primary: Tagged chests across Workspace & ReplicatedStorage.Unloaded
	local tagged = CS:GetTagged("_ChestTagged")
	if tagged and #tagged > 0 then
		for _, obj in ipairs(tagged) do
			if not (excludedMap and excludedMap[obj]) and not obj:GetAttribute("IsDisabled") then
				local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
				if part and part:FindFirstChildOfClass("TouchTransmitter") then
					local d = (part.Position - hrp.Position).Magnitude
					if d < bestDist then
						bestDist = d
						bestPart = part
					end
				end
			end
		end
		if bestPart then
			return bestPart, bestDist
		end
	end

	-- 2) Fallback: ChestModels / Chests folders
	local chestsFolder = Workspace:FindFirstChild("ChestModels") or Workspace:FindFirstChild("Chests")
	local list = chestsFolder and chestsFolder:GetChildren() or Workspace:GetChildren()

	for _, obj in ipairs(list) do
		if obj.Name:find("Chest") and not (excludedMap and excludedMap[obj]) and not obj:GetAttribute("IsDisabled") then
			local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
			if part and (part.Position - hrp.Position).Magnitude < bestDist then
				bestDist = (part.Position - hrp.Position).Magnitude
				bestPart = part
			end
		end
	end
	return bestPart, bestDist
end

-- Unified Enemy Engagement: Prioritizes Mastery Mode when S.masteryPriority is active!
local function engageEnemy(enemyModel, mobGroupSet, labelPrefix)
	local eHrp = enemyModel:FindFirstChild("HumanoidRootPart") or enemyModel:FindFirstChildWhichIsA("BasePart")
	local eHum = enemyModel:FindFirstChildOfClass("Humanoid")
	if not eHrp or not eHum or eHum.Health <= 0 then return end

	-- Lock Gun & Skill Aimbot target directly onto the NPC center
	updateMasteryAimTarget(enemyModel)

	-- Hover at S.farmDistance (default 20 studs) above the enemy, facing directly at eHrp.Position
	local distY = math.clamp(S.farmDistance or 20, 4, 35)
	if enemyModel.Name == "Core" then
		distY = math.min(distY, 18)
	end
	local hoverPos = eHrp.Position + Vector3.new(0, distY, 2.5)
	moveToCFrame(CFrame.new(hoverPos), eHrp.Position)

	-- Bring up to max 3 mobs right into the primary enemy's position (skip for static Core)
	if enemyModel.Name ~= "Core" then
		bringNearbyMobs(mobGroupSet, eHrp.CFrame)
	end

	local hpPct = (eHum.Health / math.max(1, eHum.MaxHealth)) * 100

	if S.masteryPriority then
		if hpPct <= S.masteryHealthPct then
			setStatus(string.format("Mastery [%s]: Rematando %s (%d%% HP)", S.masteryCategory, enemyModel.Name, math.floor(hpPct)))
			performNormalAttack(S.masteryCategory, enemyModel, true)
			triggerSelectedMasterySkills(enemyModel)
		else
			setStatus(string.format("Mastery: Golpeando con %s (%d%% -> %d%%)", S.masteryStarterWeapon, math.floor(hpPct), S.masteryHealthPct))
			performNormalAttack(S.masteryStarterWeapon, enemyModel, true)
		end
	else
		setStatus(string.format("%s: %s [HP %d%%]", labelPrefix, enemyModel.Name, math.floor(hpPct)))
		performNormalAttack(S.weaponType, enemyModel)
	end
end

--------------------------------------------------------------------------------
-- STACK FARMING ENGINE: BOSSES, SUMMONS, HAKI TOUCHPADS, ELITE HUNTER & EVENTS
--------------------------------------------------------------------------------
local Stack = {}
do
	local CASTLE_RAID_CENTER = Vector3.new(-5530, 314, -2960)
	local CASTLE_RAID_RADIUS = 680

	local HAKI_PAD_FALLBACKS = {
		{colorName = "Snow White", pos = Vector3.new(-4971.5, 336.0, -3721.8)},
		{colorName = "Pure Red",   pos = Vector3.new(-5420.2, 313.8, -2661.5)},
		{colorName = "Winter Sky", pos = Vector3.new(-5526.6, 376.9, -2752.4)},
	}

	local ELITE_NAMES = {
		["Diablo"] = true,
		["Deandre"] = true,
		["Urban"] = true,
	}

	local ELITE_ISLAND_POSITIONS = {
		["port"]    = Vector3.new(-290.7, 44.0, 5368.5),
		["hydra"]   = Vector3.new(5229.8, 604.2, 345.1),
		["tree"]    = Vector3.new(2302.5, 50.0, -6458.0),
		["turtle"]  = Vector3.new(-13274.5, 532.0, -7579.2),
		["castle"]  = Vector3.new(-5418.9, 313.7, -2826.2),
	}

	Stack.padCooldownUntil = {}
	Stack.currentStandingPadColor = nil
	Stack.currentStandingSince = 0
	Stack.lastColorInvokeClock = 0
	Stack.castleHakiVerified = false
	Stack.castleHakiRecheckAt = 0

	Stack.lastElitePollClock = 0
	Stack.eliteAvailable = false
	Stack.eliteLastResponse = ""

	Stack.lastCakeCheckClock = 0
	Stack.cakeRemainingMobs = 0
	Stack.lastEquipSpecialClock = 0

	local function handleGameNotificationText(rawText)
		if type(rawText) ~= "string" or rawText == "" then return end
		local low = rawText:lower()

		-- Sea 2 Factory Raid notifications
		if (low:find("factory") and low:find("open")) or (low:find("fábrica") and low:find("abiert")) or (low:find("fabrica") and low:find("abiert")) then
			S.factoryAlertUntil = os.clock() + 300
			S.factoryArrivedEmptyClock = 0
		elseif (low:find("factory") and (low:find("closed") or low:find("breached") or low:find("run out")))
			or ((low:find("fábrica") or low:find("fabrica")) and (low:find("cerrad") or low:find("destruid"))) then
			S.factoryAlertUntil = 0
			storeAnyFruitsInInventory()
		end

		-- Sea 3 Pirate Raid notifications
		if (low:find("pirates") and low:find("castle")) or (low:find("piratas") and low:find("castillo")) then
			S.pirateRaidAlertUntil = os.clock() + 300
			S.pirateRaidArrivedEmptyClock = 0
		elseif (low:find("good job") and low:find("pirate"))
			or (low:find("pirates") and (low:find("defeated") or low:find("raided")))
			or (low:find("piratas") and low:find("derrotad")) then
			S.pirateRaidAlertUntil = 0
			S.pirateRaidActiveUntil = 0
			storeAnyFruitsInInventory()
		end

		-- Raid Boss Spawn notifications (rip_indra, Soul Reaper, Dough King, Darkbeard)
		if low:find("rip_indra") or low:find("sealed away") or low:find("barriers") then
			S.indraAlertUntil = os.clock() + 180
		end
		if low:find("soul reaper") or low:find("bones") and low:find("death") then
			S.soulReaperAlertUntil = os.clock() + 180
		end
		if low:find("dough king") or low:find("dimensional rift") then
			S.doughKingAlertUntil = os.clock() + 180
		end
		if low:find("darkness has been unleashed") or (low:find("oscuridad") and low:find("desatad")) or low:find("darkbeard") then
			S.darkbeardAlertUntil = os.clock() + 180
		end
	end

	task.spawn(function()
		pcall(function()
			local pgui = LocalPlayer:WaitForChild("PlayerGui", 15)
			if not pgui then return end
			local notifGui = pgui:FindFirstChild("Notifications") or pgui:WaitForChild("Notifications", 15)
			if not notifGui then return end

			for _, desc in ipairs(notifGui:GetDescendants()) do
				if desc:IsA("TextLabel") or desc:IsA("TextBox") then
					handleGameNotificationText(desc.Text)
				end
			end

			connect(notifGui.DescendantAdded, function(desc)
				task.defer(function()
					pcall(function()
						if desc:IsA("TextLabel") or desc:IsA("TextBox") then
							handleGameNotificationText(desc.Text)
						end
					end)
				end)
			end)
		end)
	end)

	function Stack.findSpecialTool(matchKeywords, excludeKeywords)
		local char = LocalPlayer.Character
		local bp = LocalPlayer:FindFirstChild("Backpack")
		for _, cont in ipairs({char, bp}) do
			if cont then
				for _, t in ipairs(cont:GetChildren()) do
					if t:IsA("Tool") then
						local orig = tostring(t:GetAttribute("OriginalName") or "")
						local combined = (orig .. " " .. t.Name):lower()
						local excluded = false
						if excludeKeywords then
							for _, ex in ipairs(excludeKeywords) do
								if combined:find(ex, 1, true) then
									excluded = true
									break
								end
							end
						end
						if not excluded then
							for _, kw in ipairs(matchKeywords) do
								if combined:find(kw, 1, true) then
									return t
								end
							end
						end
					end
				end
			end
		end
		return nil
	end

	function Stack.equipExactTool(tool)
		if not tool then return end
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if char and hum and hum.Health > 0 and tool.Parent ~= char then
			if os.clock() - Stack.lastEquipSpecialClock > 0.25 then
				Stack.lastEquipSpecialClock = os.clock()
				pcall(function()
					hum:EquipTool(tool)
				end)
			end
		end
	end

	function Stack.findRaidBoss(keywords)
		local enemies = Workspace:FindFirstChild("Enemies")
		if enemies then
			for _, en in ipairs(enemies:GetChildren()) do
				local low = en.Name:lower()
				for _, kw in ipairs(keywords) do
					if low:find(kw, 1, true) then
						local eHum = en:FindFirstChildOfClass("Humanoid")
						local ePart = en:FindFirstChild("HumanoidRootPart") or en:FindFirstChildWhichIsA("BasePart")
						if eHum and eHum.Health > 0 and ePart then
							return en, nil
						end
					end
				end
			end
		end

		for _, obj in ipairs(ReplicatedStorage:GetChildren()) do
			if obj:IsA("Model") then
				local low = obj.Name:lower()
				for _, kw in ipairs(keywords) do
					if low:find(kw, 1, true) then
						local eHum = obj:FindFirstChildOfClass("Humanoid")
						if eHum and eHum.Health > 0 then
							return nil, obj
						end
					end
				end
			end
		end

		return nil, nil
	end

	function Stack.getModelPos(model, fallbackPos)
		if model then
			local hrp = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
			if hrp then
				return hrp.Position
			end
			local ok, cf = pcall(function() return model:GetPivot() end)
			if ok and cf then
				return cf.Position
			end
		end
		return fallbackPos
	end

	-- Identifies Haki color name from a Boat Castle Summoner.Circle touchpad part
	local function classifyTouchpadColor(part)
		local c = part.Color
		if c.R > 0.82 and c.G > 0.82 and c.B > 0.82 then
			return "Snow White"
		elseif c.R > 0.72 and c.B > 0.35 and c.G < 0.55 then
			return "Winter Sky"
		elseif c.R > 0.72 and c.G < 0.35 and c.B < 0.35 then
			return "Pure Red"
		end

		local bestName = "Snow White"
		local bestDist = math.huge
		for _, fb in ipairs(HAKI_PAD_FALLBACKS) do
			local d = (part.Position - fb.pos).Magnitude
			if d < bestDist then
				bestDist = d
				bestName = fb.colorName
			end
		end
		return bestName
	end

	local function isTouchpadAlreadyGreen(btn)
		local ind = btn:FindFirstChild("Part") or btn:FindFirstChild("Glow") or btn:FindFirstChildWhichIsA("BasePart")
		if ind and ind:IsA("BasePart") then
			local ic = ind.Color
			local bn = ind.BrickColor.Name:lower()
			if (ic.G > 0.62 and ic.R < 0.45) or bn:find("green") or bn == "camo" then
				return true
			end
		end
		local bc = btn.Color
		if bc.G > 0.65 and bc.R < 0.45 then
			return true
		end
		return false
	end

	function Stack.getPendingHakiTouchpad()
		if getCurrentSeaNumber() ~= 3 then return nil end

		local map = Workspace:FindFirstChild("Map")
		local boatCastle = map and map:FindFirstChild("Boat Castle")
		local summoner = boatCastle and boatCastle:FindFirstChild("Summoner")
		local circle = summoner and summoner:FindFirstChild("Circle")

		if not circle then
			if not Stack.castleHakiVerified or os.clock() > Stack.castleHakiRecheckAt then
				return {
					needsStream = true,
					pos = Vector3.new(-5415.0, 315.0, -2825.0),
					colorName = "Castle on the Sea",
				}
			end
			return nil
		end

		local allGreen = true
		for _, item in ipairs(circle:GetChildren()) do
			local btnPart = item:IsA("BasePart") and item or item:FindFirstChildWhichIsA("BasePart")
			if btnPart then
				if not isTouchpadAlreadyGreen(btnPart) then
					allGreen = false
					local cName = classifyTouchpadColor(btnPart)
					local cdUntil = Stack.padCooldownUntil[cName] or 0
					if os.clock() >= cdUntil then
						return {
							needsStream = false,
							part = btnPart,
							pos = btnPart.Position,
							colorName = cName,
						}
					end
				end
			end
		end

		if allGreen then
			Stack.castleHakiVerified = true
			Stack.castleHakiRecheckAt = os.clock() + 60
		end
		return nil
	end

	function Stack.executeHakiTouchpadStep(padInfo, hrp)
		if padInfo.needsStream then
			setStatus("🎨 Auto Touchpad Haki: Yendo a Castle on the Sea para verificar placas...")
			local reached = moveToCFrame(CFrame.new(padInfo.pos))
			if reached or (hrp.Position - padInfo.pos).Magnitude <= 80 then
				Stack.castleHakiVerified = true
				Stack.castleHakiRecheckAt = os.clock() + 90
			end
			return
		end

		local cName = padInfo.colorName
		setStatus(string.format("🎨 Auto Touchpad Haki: Activando placa [%s]...", cName))

		-- Equip corresponding Haki/Aura color + Buso Haki
		if os.clock() - Stack.lastColorInvokeClock > 1.4 then
			Stack.lastColorInvokeClock = os.clock()
			task.spawn(function()
				pcall(function()
					if CommF_ then
						CommF_:InvokeServer("activateColor", cName)
					end
				end)
				pcall(function()
					local net = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("Net")
					local juiceRF = net and net:FindFirstChild("RF/JuiceNetworkRF")
					if juiceRF then
						juiceRF:InvokeServer({StorageName = cName, Type = "AuraSkin", Action = "Equip"})
					end
				end)
				pcall(function()
					local char = LocalPlayer.Character
					if char and not char:FindFirstChild("HasBuso") and CommF_ then
						CommF_:InvokeServer("Buso")
					end
				end)
			end)
		end

		local standCF = padInfo.part.CFrame + Vector3.new(0, 2.6, 0)
		local reached = moveToCFrame(standCF)
		if reached or (hrp.Position - padInfo.pos).Magnitude <= 14 then
			hrp.CFrame = standCF
			if firetouchinterest then
				pcall(function()
					firetouchinterest(hrp, padInfo.part, 0)
					firetouchinterest(hrp, padInfo.part, 1)
				end)
			end
			if Stack.currentStandingPadColor ~= cName then
				Stack.currentStandingPadColor = cName
				Stack.currentStandingSince = os.clock()
			elseif os.clock() - Stack.currentStandingSince > 5.5 then
				-- Player likely doesn't own this Legendary Haki color yet; cooldown so we don't block other plates/farm
				Stack.padCooldownUntil[cName] = os.clock() + 90
				Stack.currentStandingPadColor = nil
			end
		else
			Stack.currentStandingPadColor = nil
		end
	end

	function Stack.touchSummonPedestal(tool, detectionPart, fallbackPos, bossLabel, hrp)
		local targetCF = (detectionPart and detectionPart:IsA("BasePart") and detectionPart.CFrame) or CFrame.new(fallbackPos)
		local dist = (hrp.Position - targetCF.Position).Magnitude
		setStatus(string.format("✨ Invocando %s con %s [%dm]...", bossLabel, tostring(tool.Name), math.floor(dist)))

		local reached = moveToCFrame(targetCF + Vector3.new(0, 2, 0))
		if reached or dist <= 22 then
			Stack.equipExactTool(tool)
			hrp.CFrame = targetCF
			if detectionPart and detectionPart:IsA("BasePart") and firetouchinterest then
				pcall(function()
					firetouchinterest(hrp, detectionPart, 0)
					firetouchinterest(hrp, detectionPart, 1)
				end)
			end
			if detectionPart and fireproximityprompt then
				local prompt = detectionPart:FindFirstChildOfClass("ProximityPrompt")
					or (detectionPart.Parent and detectionPart.Parent:FindFirstChildOfClass("ProximityPrompt"))
				if prompt then
					pcall(function() fireproximityprompt(prompt) end)
				end
			end
		end
	end

	function Stack.findElitePirate()
		local enemies = Workspace:FindFirstChild("Enemies")
		if enemies then
			for _, en in ipairs(enemies:GetChildren()) do
				local clean = en.Name:gsub(" %[Lv%. %d+%]", ""):gsub(" %[Boss%]", "")
				if ELITE_NAMES[clean] then
					local eHum = en:FindFirstChildOfClass("Humanoid")
					local eHrp = en:FindFirstChild("HumanoidRootPart")
					if eHum and eHum.Health > 0 and eHrp then
						return en, nil, clean
					end
				end
			end
		end

		for _, obj in ipairs(ReplicatedStorage:GetChildren()) do
			if obj:IsA("Model") then
				local clean = obj.Name:gsub(" %[Lv%. %d+%]", ""):gsub(" %[Boss%]", "")
				if ELITE_NAMES[clean] then
					local eHum = obj:FindFirstChildOfClass("Humanoid")
					if eHum and eHum.Health > 0 then
						return nil, obj, clean
					end
				end
			end
		end

		return nil, nil, nil
	end

	function Stack.getActiveEliteQuestInfo()
		for eliteName in pairs(ELITE_NAMES) do
			local hasQ, matches, desc = getActiveQuestStatus(nil, eliteName)
			if hasQ and matches then
				return true, eliteName, tostring(desc or "")
			end
		end
		return false, nil, ""
	end

	function Stack.pollEliteHunterStatus()
		if getCurrentSeaNumber() ~= 3 or not CommF_ then
			return false
		end
		local liveE, repE = Stack.findElitePirate()
		if liveE or repE then
			Stack.eliteAvailable = true
			return true
		end
		local hasEliteQ = Stack.getActiveEliteQuestInfo()
		if hasEliteQ then
			Stack.eliteAvailable = true
			return true
		end
		if os.clock() - Stack.lastElitePollClock >= 5.0 then
			Stack.lastElitePollClock = os.clock()
			local ok, res = pcall(function()
				return CommF_:InvokeServer("EliteHunter")
			end)
			if ok and res ~= nil then
				local str = tostring(res):lower()
				Stack.eliteLastResponse = str
				if str:find("don't have anything") or str:find("come back later") or str:find("nada para ti") then
					Stack.eliteAvailable = false
				else
					Stack.eliteAvailable = true
				end
			end
		end
		return Stack.eliteAvailable
	end

	function Stack.executeEliteHunterStep(hrp)
		local liveE, repE, eliteName = Stack.findElitePirate()
		local hasEliteQ, qMobName, qDesc = Stack.getActiveEliteQuestInfo()

		-- Accept Elite Hunter quest first if not active
		if not hasEliteQ and S.autoQuest and CommF_ then
			local npcPos = Vector3.new(-5418.9, 313.7, -2826.2)
			setStatus("🎯 Auto Elite Hunter: Aceptando misión en Castle on the Sea...")
			local reached = moveToCFrame(CFrame.new(npcPos + Vector3.new(0, 3, 3)))
			if reached or (hrp.Position - npcPos).Magnitude <= 35 then
				pcall(function()
					CommF_:InvokeServer("EliteHunter")
				end)
			end
			if not liveE and not repE then
				return
			end
		end

		if liveE then
			engageEnemy(liveE, ELITE_NAMES, "🎯 Elite Hunter")
			return
		end

		if repE then
			local rPos = Stack.getModelPos(repE, Vector3.new(-5418.9, 330.0, -2826.2))
			setStatus(string.format("🎯 Elite Hunter: Volando hacia %s [%dm]...", tostring(eliteName or repE.Name), math.floor((hrp.Position - rPos).Magnitude)))
			moveToCFrame(CFrame.new(rPos + Vector3.new(0, 25, 0)))
			return
		end

		-- Fallback: check island mentioned in quest description or Elite Hunter response
		local hint = (tostring(qDesc) .. " " .. tostring(Stack.eliteLastResponse)):lower()
		for key, islPos in pairs(ELITE_ISLAND_POSITIONS) do
			if hint:find(key, 1, true) then
				setStatus(string.format("🎯 Elite Hunter: Buscando a %s en isla (%s)...", tostring(qMobName or "Elite"), key))
				moveToCFrame(CFrame.new(islPos + Vector3.new(0, 35, 0)))
				return
			end
		end

		setStatus("🎯 Elite Hunter: Buscando Elite Pirate activo...")
	end

	function Stack.executeSummonDoughKingStep(sweetChaliceTool, hrp)
		if CommF_ and (os.clock() - Stack.lastCakeCheckClock >= 3.5) then
			Stack.lastCakeCheckClock = os.clock()
			pcall(function()
				local res = CommF_:InvokeServer("CakePrinceSpawner", true)
				local s = tostring(res or "")
				local num = tonumber(s:match("(%d+)"))
				if num and (s:lower():find("more") or s:lower():find("defeat") or s:lower():find("faltan") or s:lower():find("derrotar")) then
					Stack.cakeRemainingMobs = num
				else
					Stack.cakeRemainingMobs = 0
				end
			end)
		end

		if Stack.cakeRemainingMobs > 0 then
			local cakeSpawns = collectSpawnsForSet(KatakuriMobSet)
			local targetSet = (#cakeSpawns > 0) and KatakuriMobSet or nil
			local mob = findAliveEnemyFromSet(targetSet)
			if mob then
				engageEnemy(mob, targetSet, string.format("🍩 Sweet Chalice (Faltan %d)", Stack.cakeRemainingMobs))
			elseif #cakeSpawns > 0 then
				setStatus(string.format("🍩 Sweet Chalice: Patrullando Cake Land (Faltan %d NPCs)...", Stack.cakeRemainingMobs))
				patrolAroundSpawns("SweetChaliceCake", cakeSpawns)
			else
				moveToCFrame(CFrame.new(-2095.0, 70.0, -12140.0))
			end
			return
		end

		-- Ready to summon Dough King at drip_mama!
		local dripPos = Vector3.new(-2151.8, 70.0, -12404.9)
		for _, folder in ipairs({Workspace:FindFirstChild("NPCs"), ReplicatedStorage:FindFirstChild("NPCs")}) do
			local m = folder and folder:FindFirstChild("drip_mama")
			if m then
				local ok, cf = pcall(function() return m:GetPivot() end)
				if ok and cf then
					dripPos = cf.Position
					break
				end
			end
		end

		local dist = (hrp.Position - dripPos).Magnitude
		setStatus(string.format("🍩 Invocando Dough King con drip_mama [%dm]...", math.floor(dist)))
		local reached = moveToCFrame(CFrame.new(dripPos + Vector3.new(0, 3, 3.5)))
		if reached or dist <= 18 then
			Stack.equipExactTool(sweetChaliceTool)
			pcall(function()
				if CommF_ then
					CommF_:InvokeServer("CakePrinceSpawner")
				end
			end)
		end
	end

	function Stack.executeAttackDoughKingStep(liveDK, repDK, hrp)
		local map = Workspace:FindFirstChild("Map")
		local cakeLoaf = map and map:FindFirstChild("CakeLoaf")
		local bigMirror = cakeLoaf and cakeLoaf:FindFirstChild("BigMirror")
		local mirrorPart = bigMirror and (bigMirror:FindFirstChild("Main") or bigMirror:FindFirstChild("Other") or bigMirror:FindFirstChildWhichIsA("BasePart"))

		if liveDK then
			local dkPos = Stack.getModelPos(liveDK, hrp.Position)
			if (hrp.Position - dkPos).Magnitude > 1400 and mirrorPart and mirrorPart:IsA("BasePart") then
				setStatus("🍩 Atacar Dough King: Entrando al espejo Dimensional Rift...")
				local reached = moveToCFrame(mirrorPart.CFrame)
				if reached or (hrp.Position - mirrorPart.Position).Magnitude <= 25 then
					hrp.CFrame = mirrorPart.CFrame
					if firetouchinterest then
						pcall(function()
							firetouchinterest(hrp, mirrorPart, 0)
							firetouchinterest(hrp, mirrorPart, 1)
						end)
					end
				end
				return
			end
			engageEnemy(liveDK, nil, "🍩 Dough King")
			return
		end

		local targetPos = (mirrorPart and mirrorPart:IsA("BasePart") and mirrorPart.Position)
			or Stack.getModelPos(repDK, Vector3.new(-2151.0, 149.0, -12404.0))
		setStatus("🍩 Atacar Dough King: Yendo a Dimensional Rift...")
		local reached = moveToCFrame(CFrame.new(targetPos))
		if reached or (hrp.Position - targetPos).Magnitude <= 25 then
			if mirrorPart and mirrorPart:IsA("BasePart") and firetouchinterest then
				hrp.CFrame = mirrorPart.CFrame
				pcall(function()
					firetouchinterest(hrp, mirrorPart, 0)
					firetouchinterest(hrp, mirrorPart, 1)
				end)
			end
			if not repDK then
				S.doughKingAlertUntil = 0
			end
		end
	end

	function Stack.findSpawnedFruitInWorkspace()
		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local refPos = hrp and hrp.Position

		local bestObj = nil
		local bestHandle = nil
		local bestDist = math.huge

		for _, obj in ipairs(Workspace:GetChildren()) do
			if obj ~= char and (obj:IsA("Tool") or obj:IsA("Model")) and not Players:GetPlayerFromCharacter(obj) then
				if obj.Name:lower():find("fruit") then
					local handle = obj:FindFirstChild("Handle")
					if handle and handle:IsA("BasePart") then
						local d = refPos and (handle.Position - refPos).Magnitude or 0
						if d < bestDist then
							bestDist = d
							bestObj = obj
							bestHandle = handle
						end
					end
				end
			end
		end

		return bestObj, bestHandle, bestDist
	end

	function Stack.findAliveFactoryCore()
		local enemies = Workspace:FindFirstChild("Enemies")
		local core = enemies and enemies:FindFirstChild("Core")
		if core then
			local eHum = core:FindFirstChildOfClass("Humanoid")
			local ePart = core:FindFirstChild("HumanoidRootPart") or core:FindFirstChildWhichIsA("BasePart")
			if eHum and eHum.Health > 0 and ePart then
				return core
			end
		end
		return nil
	end

	function Stack.isFactoryDoorOpen()
		local map = Workspace:FindFirstChild("Map")
		local dressrosa = map and map:FindFirstChild("Dressrosa")
		local factory = dressrosa and dressrosa:FindFirstChild("SmileFactory")
		local door = factory and factory:FindFirstChild("Door")
		if door and door:IsA("BasePart") then
			if (not door.CanCollide) or door.Transparency >= 0.4 then
				return true
			end
		end
		return false
	end

	function Stack.isFactoryEventActive()
		if getCurrentSeaNumber() ~= 2 then
			return false
		end
		if Stack.findAliveFactoryCore() ~= nil then
			return true
		end
		local repCore = ReplicatedStorage:FindFirstChild("Core")
		if repCore and repCore:FindFirstChildOfClass("Humanoid") and repCore:FindFirstChildOfClass("Humanoid").Health > 0 then
			return true
		end
		if Stack.isFactoryDoorOpen() then
			return true
		end
		if os.clock() < S.factoryAlertUntil then
			return true
		end
		return false
	end

	function Stack.findPirateRaidTarget()
		if getCurrentSeaNumber() ~= 3 then
			return nil, nil
		end

		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local refPos = (hrp and hrp.Position) or CASTLE_RAID_CENTER

		local bestTanky = nil
		local bestTankyDist = math.huge
		local bestMob = nil
		local bestDist = math.huge

		local enemies = Workspace:FindFirstChild("Enemies")
		if enemies then
			for _, en in ipairs(enemies:GetChildren()) do
				local lowName = en.Name:lower()
				if not lowName:find("dummy") and not lowName:find("training") and not lowName:find("rip_indra") then
					local eHum = en:FindFirstChildOfClass("Humanoid")
					local eHrp = en:FindFirstChild("HumanoidRootPart")
					if eHum and eHum.Health > 0 and eHrp then
						if (eHrp.Position - CASTLE_RAID_CENTER).Magnitude <= CASTLE_RAID_RADIUS then
							local d = (eHrp.Position - refPos).Magnitude
							if lowName:find("tanky") or eHum.MaxHealth >= 150000 then
								if d < bestTankyDist then
									bestTankyDist = d
									bestTanky = en
								end
							elseif d < bestDist then
								bestDist = d
								bestMob = en
							end
						end
					end
				end
			end
		end

		if bestTanky then
			return bestTanky, nil
		end
		if bestMob then
			return bestMob, nil
		end

		for _, obj in ipairs(ReplicatedStorage:GetChildren()) do
			if obj:IsA("Model") then
				local lowName = obj.Name:lower()
				if not lowName:find("dummy") and not lowName:find("training") and not lowName:find("rip_indra") then
					local eHum = obj:FindFirstChildOfClass("Humanoid")
					local eHrp = obj:FindFirstChild("HumanoidRootPart")
					if eHum and eHum.Health > 0 and eHrp and (eHrp.Position - CASTLE_RAID_CENTER).Magnitude <= CASTLE_RAID_RADIUS then
						return nil, obj
					end
				end
			end
		end

		return nil, nil
	end
end

--------------------------------------------------------------------------------
-- COMPLETE END-TO-END SEA PROGRESSION ENGINE (SEA 1 -> SEA 2 & SEA 2 -> SEA 3)
--------------------------------------------------------------------------------
do
	local BARTILO_PLATES_FALLBACK = {
		Vector3.new(-1850.5, 13.2, 1750.9), -- Plate1
		Vector3.new(-1858.9, 19.4, 1712.0), -- Plate2
		Vector3.new(-1803.9, 16.6, 1750.9), -- Plate3
		Vector3.new(-1858.6, 16.9, 1724.8), -- Plate4
		Vector3.new(-1869.5, 16.0, 1681.0), -- Plate5
		Vector3.new(-1800.1, 16.5, 1684.5), -- Plate6
		Vector3.new(-1819.3, 14.8, 1717.9), -- Plate7
		Vector3.new(-1813.5, 14.9, 1724.8), -- Plate8
	}

	-- Sea 1 -> Sea 2 state
	local lastSea1Poll = 0
	local sea1Prog = {TalkedDetective = false, UsedKey = false, KilledIceBoss = false}
	local sea1ReadyDressrosa = false
	local sea1BossWasAlive = false
	local sea1BossEmptySince = 0
	local lastSea1ActionClock = 0

	-- Sea 2 -> Sea 3 state
	local lastBartiloPoll = 0
	local bProg = {KilledBandits = false, KilledSpring = false, DidPlates = false}
	local bartiloFullyDone = false
	local bartiloSpokeForJeremy = false
	local bartiloSpokeForPlates = false
	local jeremyWasAlive = false
	local jeremyEmptySince = 0
	local lastBartiloTalkClock = 0

	local lastTrevorPoll = 0
	local trevorUnlocked = false
	local lastTrevorUnstoreClock = 0
	local lastTrevorTalkClock = 0

	local lastZPoll = 0
	local zCheck = nil
	local swanWasAlive = false
	local swanEmptySince = 0
	local indraWasAlive = false
	local lastZBeginClock = 0
	local lastTravelInvokeClock = 0

	local function getPlayerLevel()
		local levelObj = LocalPlayer:FindFirstChild("Data") and LocalPlayer.Data:FindFirstChild("Level")
		return (levelObj and tonumber(levelObj.Value)) or 1
	end

	local function getNPCWorldPos(npcName, fallbackVec)
		for _, folder in ipairs({Workspace:FindFirstChild("NPCs"), ReplicatedStorage:FindFirstChild("NPCs")}) do
			local m = folder and folder:FindFirstChild(npcName)
			if m then
				local p = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("Head") or m:FindFirstChildWhichIsA("BasePart")
				if p then
					return p.Position
				end
				local ok, cf = pcall(function() return m:GetPivot() end)
				if ok and cf then
					return cf.Position
				end
			end
		end
		return fallbackVec
	end

	local function findToolExactName(exactName)
		local low = exactName:lower()
		for _, cont in ipairs({LocalPlayer.Character, LocalPlayer:FindFirstChild("Backpack")}) do
			if cont then
				for _, t in ipairs(cont:GetChildren()) do
					if t:IsA("Tool") then
						local orig = tostring(t:GetAttribute("OriginalName") or ""):lower()
						if t.Name:lower() == low or orig == low then
							return t
						end
					end
				end
			end
		end
		return nil
	end

	local function farmToLevelTarget(hrp, progressLabel)
		local bestQuest = getBestQuestForPlayer()
		if not bestQuest then
			setStatus(progressLabel .. " | Buscando misión de tu nivel...")
			return
		end

		if CommF_ and bestQuest.questGroup then
			local hasQuest, matchesTarget, activeDesc = getActiveQuestStatus(bestQuest.questGroup, bestQuest.mobName)
			if hasQuest and not matchesTarget then
				setStatus(progressLabel .. " | Abandonando misión anterior (" .. tostring(activeDesc) .. ")...")
				abandonCurrentQuestNonBlocking()
				return
			end
			if not hasQuest then
				local npcTarget = bestQuest.npcCFrame * CFrame.new(0, 4, 3)
				setStatus(string.format("%s | Misión: %s", progressLabel, bestQuest.questTitle))
				local reached = moveToCFrame(npcTarget)
				if reached or (hrp.Position - bestQuest.npcCFrame.Position).Magnitude <= 30 then
					requestStartQuestNonBlocking(bestQuest.questGroup, bestQuest.questIndex)
				end
				return
			end
		end

		local mobSet = {[bestQuest.mobName] = true}
		local targetMob = findAliveEnemyFromSet(mobSet)
		if targetMob then
			engageEnemy(targetMob, mobSet, progressLabel)
		else
			setStatus(string.format("%s | Patrullando %s...", progressLabel, bestQuest.mobName))
			patrolAroundSpawns("SeaProg_" .. bestQuest.mobName, bestQuest.spawns)
		end
	end

	local function stepFirstSeaToSecondSea(hrp, hum)
		local seaNum = getCurrentSeaNumber()
		if seaNum ~= 1 then
			clearFarmMover()
			setStatus("🌊 ¡Ya estás en el Segundo/Tercer Sea! Paso desde Sea 1 completado.")
			return
		end

		local lvl = getPlayerLevel()
		if lvl < 700 then
			farmToLevelTarget(hrp, string.format("🌊 Sea 1->2 [Lv. %d/700]", lvl))
			return
		end

		if CommF_ and (os.clock() - lastSea1Poll >= 2.0) then
			lastSea1Poll = os.clock()
			pcall(function()
				local res = CommF_:InvokeServer("DressrosaQuestProgress")
				if type(res) == "table" then
					sea1Prog.TalkedDetective = (res.TalkedDetective == true)
					sea1Prog.UsedKey = (res.UsedKey == true)
					sea1Prog.KilledIceBoss = (res.KilledIceBoss == true)
				end
			end)
		end

		-- 1) Get Key from Military Detective & Open Frozen Village Cave Door
		if not sea1Prog.KilledIceBoss then
			if not sea1Prog.UsedKey then
				local keyTool = findToolExactName("Key")
				if not keyTool then
					local detPos = getNPCWorldPos("Military Detective", Vector3.new(4850.2, 5.7, 718.5))
					setStatus("🌊 Sea 1->2: Yendo con Military Detective en Prisión (obteniendo Key)...")
					local reached = moveToCFrame(CFrame.new(detPos + Vector3.new(0, 3, 3)))
					if (reached or (hrp.Position - detPos).Magnitude <= 26) and (os.clock() - lastSea1ActionClock >= 1.2) then
						lastSea1ActionClock = os.clock()
						pcall(function()
							CommF_:InvokeServer("DressrosaQuestProgress", "Detective")
						end)
						lastSea1Poll = 0
					end
					return
				else
					local map = Workspace:FindFirstChild("Map")
					local iceMap = map and map:FindFirstChild("Ice")
					local doorPart = iceMap and iceMap:FindFirstChild("Door")
					local doorPos = (doorPart and doorPart:IsA("BasePart") and doorPart.Position) or Vector3.new(1347.7, 37.3, -1325.6)
					setStatus("🌊 Sea 1->2: Abriendo puerta secreta en Frozen Village con Key...")
					local reached = moveToCFrame(CFrame.new(doorPos + Vector3.new(0, 1.5, 2)))
					if reached or (hrp.Position - doorPos).Magnitude <= 22 then
						Stack.equipExactTool(keyTool)
						pcall(function() hum:EquipTool(keyTool) end)
						hrp.CFrame = CFrame.new(doorPos)
						if doorPart and doorPart:IsA("BasePart") and firetouchinterest then
							pcall(function()
								firetouchinterest(hrp, doorPart, 0)
								firetouchinterest(hrp, doorPart, 1)
							end)
						end
						if os.clock() - lastSea1ActionClock >= 1.0 then
							lastSea1ActionClock = os.clock()
							pcall(function()
								CommF_:InvokeServer("DressrosaQuestProgress", "UseKey")
							end)
							lastSea1Poll = 0
						end
					end
					return
				end
			end

			-- 2) Defeat Ice Admiral inside Frozen Village Cave
			local iceBoss = findAliveEnemyFromSet({["Ice Admiral"] = true})
			if iceBoss then
				sea1BossWasAlive = true
				sea1BossEmptySince = 0
				engageEnemy(iceBoss, {["Ice Admiral"] = true}, "❄️ Ice Admiral [Paso a Sea 2]")
				return
			elseif sea1BossWasAlive then
				sea1BossWasAlive = false
				lastSea1Poll = 0
				return
			end

			local cavePos = Vector3.new(1345.0, 37.3, -1325.0)
			setStatus("❄️ Sea 1->2: Entrando a la cueva para derrotar a Ice Admiral...")
			local reached = moveToCFrame(CFrame.new(cavePos))
			if reached or (hrp.Position - cavePos).Magnitude <= 40 then
				local _, repIce = Stack.findRaidBoss({"ice admiral"})
				if not repIce then
					if sea1BossEmptySince == 0 then
						sea1BossEmptySince = os.clock()
					elseif (os.clock() - sea1BossEmptySince >= 6.5) and (os.clock() - S.spawnedAtClock >= 8.0) then
						local killedNow = false
						pcall(function()
							local fresh = CommF_:InvokeServer("DressrosaQuestProgress")
							if type(fresh) == "table" and fresh.KilledIceBoss == true then
								sea1Prog = fresh
								killedNow = true
							end
						end)
						sea1BossEmptySince = 0
						if not killedNow then
							clearFarmMover()
							setStatus("❄️ Ice Admiral no está activo -> Server Hop...")
							executeServerHop(S.serverHopMode)
						end
					end
				else
					sea1BossEmptySince = 0
				end
			end
			return
		end

		-- 3) Ice Admiral defeated -> Report & Travel immediately to Second Sea!
		if not sea1ReadyDressrosa and (os.clock() - lastSea1ActionClock >= 1.4) then
			lastSea1ActionClock = os.clock()
			pcall(function()
				CommF_:InvokeServer("DressrosaQuestProgress", "Detective")
				local dRes = CommF_:InvokeServer("DressrosaQuestProgress", "Dressrosa")
				if dRes == 0 then
					sea1ReadyDressrosa = true
					CommF_:InvokeServer("TravelDressrosa")
				end
			end)
		end

		if not sea1ReadyDressrosa then
			local detPos = getNPCWorldPos("Military Detective", Vector3.new(4850.2, 5.7, 718.5))
			setStatus("🌊 Sea 1->2: Reportando victoria con Military Detective...")
			local reached = moveToCFrame(CFrame.new(detPos + Vector3.new(0, 3, 3)))
			if reached or (hrp.Position - detPos).Magnitude <= 26 then
				pcall(function()
					CommF_:InvokeServer("DressrosaQuestProgress", "Detective")
					if CommF_:InvokeServer("DressrosaQuestProgress", "Dressrosa") == 0 then
						sea1ReadyDressrosa = true
					end
				end)
			end
			return
		end

		local capPos = getNPCWorldPos("Experienced Captain", Vector3.new(-656.2, 7.8, 1580.8))
		setStatus("🚢 ¡Sea 1 completado! Viajando directo al Segundo Sea con Experienced Captain...")
		local reached = moveToCFrame(CFrame.new(capPos + Vector3.new(0, 3, 3)))
		if (reached or (hrp.Position - capPos).Magnitude <= 30) and (os.clock() - lastTravelInvokeClock >= 1.5) then
			lastTravelInvokeClock = os.clock()
			pcall(function()
				CommF_:InvokeServer("DressrosaQuestProgress", "Dressrosa")
				CommF_:InvokeServer("TravelDressrosa")
			end)
		end
	end

	local function stepSecondSeaToThirdSea(hrp, hum)
		local seaNum = getCurrentSeaNumber()
		if seaNum == 3 then
			S.trevorDeliveryActive = false
			S.protectedTrevorFruitTool = nil
			clearFarmMover()
			setStatus("🌊 ¡Ya estás en el Tercer Sea! Misión completa finalizada.")
			return
		elseif seaNum == 1 then
			local lvl = getPlayerLevel()
			if lvl >= 700 and CommF_ and (os.clock() - lastTravelInvokeClock >= 3.0) then
				lastTravelInvokeClock = os.clock()
				setStatus("🚢 Viajando al Segundo Sea para iniciar progresión Sea 2 -> Sea 3...")
				pcall(function() CommF_:InvokeServer("TravelDressrosa") end)
			else
				setStatus("🌊 Estás en el Primer Sea (activa Auto Primer Sea -> Segundo Sea primero)...")
			end
			return
		end

		local lvl = getPlayerLevel()

		-- =====================================================================
		-- PHASE 1: BARTILO QUEST (Lv. 850+: 50 Swan Pirates -> Jeremy -> 8 Plates)
		-- =====================================================================
		if lvl < 850 then
			farmToLevelTarget(hrp, string.format("🔨 Sea 2->3 [Lv. %d/850 para Bartilo]", lvl))
			return
		end

		if not bartiloFullyDone and CommF_ and (os.clock() - lastBartiloPoll >= 2.2) then
			lastBartiloPoll = os.clock()
			pcall(function()
				local res = CommF_:InvokeServer("BartiloQuestProgress")
				if type(res) == "table" then
					bProg.KilledBandits = (res.KilledBandits == true)
					bProg.KilledSpring = (res.KilledSpring == true)
					bProg.DidPlates = (res.DidPlates == true)
				end
				if bProg.KilledBandits and bProg.KilledSpring and bProg.DidPlates then
					local stg = CommF_:InvokeServer("BartiloQuestProgress", "Bartilo")
					if tonumber(stg) == 3 then
						bartiloFullyDone = true
					end
				end
			end)
		end

		if not bartiloFullyDone then
			local bartiloPos = getNPCWorldPos("Bartilo", Vector3.new(-461.5, 72.3, 300.3))

			-- 1A) 50 Swan Pirates
			if not bProg.KilledBandits then
				local hasQuest, matchesTarget, activeDesc = getActiveQuestStatus("BartiloQuest", "Swan Pirate")
				if hasQuest and not matchesTarget then
					setStatus("🔨 Bartilo [1/3]: Abandonando misión anterior (" .. tostring(activeDesc) .. ")...")
					abandonCurrentQuestNonBlocking()
					return
				end
				if not hasQuest then
					setStatus("🔨 Bartilo [1/3]: Aceptando misión de 50 Swan Pirates en el Café...")
					local reached = moveToCFrame(CFrame.new(bartiloPos + Vector3.new(0, 3, 3)))
					if reached or (hrp.Position - bartiloPos).Magnitude <= 28 then
						if os.clock() - lastBartiloTalkClock >= 1.2 then
							lastBartiloTalkClock = os.clock()
							pcall(function() CommF_:InvokeServer("BartiloQuestProgress", "Bartilo") end)
						end
						requestStartQuestNonBlocking("BartiloQuest", 1)
						lastBartiloPoll = 0
					end
					return
				end

				local swanSet = {["Swan Pirate"] = true}
				local mob = findAliveEnemyFromSet(swanSet)
				if mob then
					engageEnemy(mob, swanSet, "🔨 Bartilo [50 Swan Pirates]")
				else
					local spMap = getCurrentSpawnMap()
					local swanSpawns = (spMap["Swan Pirate"] and #spMap["Swan Pirate"] > 0)
						and spMap["Swan Pirate"]
						or {CFrame.new(970, 122, 1235), CFrame.new(1055, 122, 1320)}
					setStatus("🔨 Bartilo [1/3]: Patrullando zona de Swan Pirates...")
					patrolAroundSpawns("Bartilo_SwanPirate", swanSpawns)
				end
				return
			end

			-- 1B) Boss Jeremy
			if not bProg.KilledSpring then
				if not bartiloSpokeForJeremy then
					local okS, stg = pcall(function() return CommF_:InvokeServer("BartiloQuestProgress", "Bartilo") end)
					if okS and tonumber(stg) and tonumber(stg) >= 1 then
						bartiloSpokeForJeremy = true
					else
						setStatus("🔨 Bartilo [2/3]: Hablando con Bartilo para misión de Jeremy...")
						local reached = moveToCFrame(CFrame.new(bartiloPos + Vector3.new(0, 3, 3)))
						if reached or (hrp.Position - bartiloPos).Magnitude <= 28 then
							pcall(function() CommF_:InvokeServer("BartiloQuestProgress", "Bartilo") end)
							bartiloSpokeForJeremy = true
						end
						return
					end
				end

				local jeremy = findAliveEnemyFromSet({["Jeremy"] = true})
				if jeremy then
					jeremyWasAlive = true
					jeremyEmptySince = 0
					engageEnemy(jeremy, {["Jeremy"] = true}, "🔨 Boss Jeremy [Bartilo 2/3]")
					return
				elseif jeremyWasAlive then
					jeremyWasAlive = false
					lastBartiloPoll = 0
					return
				end

				local jeremyArena = Vector3.new(2173.2, 449.0, 853.8)
				setStatus("🔨 Bartilo [2/3]: Yendo a la montaña para derrotar a Jeremy...")
				local reached = moveToCFrame(CFrame.new(jeremyArena))
				if reached or (hrp.Position - jeremyArena).Magnitude <= 45 then
					local _, repJeremy = Stack.findRaidBoss({"jeremy"})
					if not repJeremy then
						if jeremyEmptySince == 0 then
							jeremyEmptySince = os.clock()
						elseif (os.clock() - jeremyEmptySince >= 6.5) and (os.clock() - S.spawnedAtClock >= 8.0) then
							local killedNow = false
							pcall(function()
								local fresh = CommF_:InvokeServer("BartiloQuestProgress")
								if type(fresh) == "table" and fresh.KilledSpring == true then
									bProg = fresh
									killedNow = true
								end
							end)
							jeremyEmptySince = 0
							if not killedNow then
								clearFarmMover()
								setStatus("🔨 Boss Jeremy no está activo -> Server Hop...")
								executeServerHop(S.serverHopMode)
							end
						end
					else
						jeremyEmptySince = 0
					end
				end
				return
			end

			-- 1C) 8 Colosseum Gladiator Plates (Plate1 .. Plate8 in exact order)
			if not bProg.DidPlates then
				if not bartiloSpokeForPlates then
					local okS, stg = pcall(function() return CommF_:InvokeServer("BartiloQuestProgress", "Bartilo") end)
					if okS and tonumber(stg) and tonumber(stg) >= 2 then
						bartiloSpokeForPlates = true
					else
						setStatus("🔨 Bartilo [3/3]: Hablando con Bartilo para liberar gladiadores...")
						local reached = moveToCFrame(CFrame.new(bartiloPos + Vector3.new(0, 3, 3)))
						if reached or (hrp.Position - bartiloPos).Magnitude <= 28 then
							pcall(function() CommF_:InvokeServer("BartiloQuestProgress", "Bartilo") end)
							bartiloSpokeForPlates = true
						end
						return
					end
				end

				local map = Workspace:FindFirstChild("Map")
				local dressrosa = map and map:FindFirstChild("Dressrosa")
				local platesFolder = dressrosa and dressrosa:FindFirstChild("BartiloPlates")
				if not platesFolder then
					setStatus("🔨 Bartilo [3/3]: Yendo al Coliseo para cargar las 8 placas...")
					moveToCFrame(CFrame.new(BARTILO_PLATES_FALLBACK[1] + Vector3.new(0, 2.5, 0)))
					return
				end

				for i = 1, 8 do
					local platePart = platesFolder:FindFirstChild("Plate" .. tostring(i))
					if platePart and platePart:IsA("BasePart") then
						if platePart.BrickColor.Name == "Sand yellow" then
							setStatus(string.format("🔨 Bartilo [3/3]: Pisando Placa del Coliseo %d/8...", i))
							local standOffsetY = (math.floor(os.clock() * 4) % 2 == 0) and 2.5 or 1.4
							local standCF = CFrame.new(platePart.Position + Vector3.new(0, standOffsetY, 0))
							local reached = moveToCFrame(standCF)
							if reached or (hrp.Position - platePart.Position).Magnitude <= 16 then
								hrp.CFrame = standCF
								if firetouchinterest then
									pcall(function()
										firetouchinterest(hrp, platePart, 0)
										firetouchinterest(hrp, platePart, 1)
									end)
								end
							end
							return
						end
					else
						local fbPos = BARTILO_PLATES_FALLBACK[i]
						setStatus(string.format("🔨 Bartilo [3/3]: Acercándose a Placa %d/8...", i))
						moveToCFrame(CFrame.new(fbPos + Vector3.new(0, 2.5, 0)))
						return
					end
				end

				-- All 8 plates activated! Re-poll immediately
				lastBartiloPoll = 0
				pcall(function() CommF_:InvokeServer("BartiloQuestProgress", "Bartilo") end)
				return
			end

			-- 1D) Final Bartilo turn-in confirmation
			setStatus("🔨 Bartilo: Finalizando misión con Bartilo en el Café...")
			local reached = moveToCFrame(CFrame.new(bartiloPos + Vector3.new(0, 3, 3)))
			if reached or (hrp.Position - bartiloPos).Magnitude <= 28 then
				pcall(function() CommF_:InvokeServer("BartiloQuestProgress", "Bartilo") end)
				bartiloFullyDone = true
			end
			return
		end

		-- =====================================================================
		-- PHASE 2: TREVOR >= $1,000,000 FRUIT DELIVERY (Lv. 1,000+, ONLY 1 >=1M FRUIT)
		-- =====================================================================
		if lvl < 1000 then
			S.trevorDeliveryActive = false
			farmToLevelTarget(hrp, string.format("🌊 Sea 2->3 [Lv. %d/1000 para Trevor]", lvl))
			return
		end

		if not trevorUnlocked and CommF_ and (os.clock() - lastTrevorPoll >= 2.5) then
			lastTrevorPoll = os.clock()
			pcall(function()
				local u = CommF_:InvokeServer("GetUnlockables")
				if type(u) == "table" and u.FlamingoAccess == true then
					trevorUnlocked = true
				elseif tostring(CommF_:InvokeServer("TalkTrevor", "1") or "") == "0" then
					trevorUnlocked = true
				end
			end)
			if trevorUnlocked then
				S.trevorDeliveryActive = false
				S.protectedTrevorFruitTool = nil
				if S.markFlamingoUnlocked then S.markFlamingoUnlocked() end
			end
		end

		if not trevorUnlocked then
			S.trevorDeliveryActive = true
			local fruitTool, _, fruitPrice = nil, nil, nil
			if S.getHeldTrevorMin1MFruit then
				fruitTool, _, fruitPrice = S.getHeldTrevorMin1MFruit()
			end
			if not fruitTool and S.unstoreTrevorMin1MFruit and (os.clock() - lastTrevorUnstoreClock >= 4.0) then
				lastTrevorUnstoreClock = os.clock()
				fruitTool, _, fruitPrice = S.unstoreTrevorMin1MFruit()
			end

			if not fruitTool then
				clearFarmMover()
				setStatus("🍎 Trevor: Requiere Quake, Love, Creation, Spider, Sound, Phoenix, Pain o Shadow...")
				return
			end

			S.protectedTrevorFruitTool = fruitTool
			local trevorPos = getNPCWorldPos("Trevor", Vector3.new(-338.0, 331.0, 643.0))
			setStatus(string.format("🍎 Trevor: Entregando %s ($%d) [Lista permitida Sea 3]...", tostring(fruitTool.Name), tonumber(fruitPrice) or 1000000))
			local reached = moveToCFrame(CFrame.new(trevorPos + Vector3.new(0, 3, 3)))
			if reached or (hrp.Position - trevorPos).Magnitude <= 22 then
				if S.safeguardOtherFruitsBeforeTrevor and not S.safeguardOtherFruitsBeforeTrevor(fruitTool) then
					setStatus("⚠️ Guarda primero tu otra fruta >=1M no permitida en la mochila antes de entregar a Trevor...")
					return
				end
				Stack.equipExactTool(fruitTool)
				pcall(function() hum:EquipTool(fruitTool) end)
				if os.clock() - lastTrevorTalkClock >= 1.4 then
					lastTrevorTalkClock = os.clock()
					pcall(function()
						local r1 = tostring(CommF_:InvokeServer("TalkTrevor", "1") or "")
						if r1 == "0" then
							trevorUnlocked = true
						else
							if r1 ~= "2" then
								CommF_:InvokeServer("TalkTrevor", "2")
								CommF_:InvokeServer("TalkTrevor", "1")
							end
							CommF_:InvokeServer("TalkTrevor", "3")
							local u2 = CommF_:InvokeServer("GetUnlockables")
							if (type(u2) == "table" and u2.FlamingoAccess == true)
								or tostring(CommF_:InvokeServer("TalkTrevor", "1") or "") == "0" then
								trevorUnlocked = true
							end
						end
					end)
					if trevorUnlocked then
						S.trevorDeliveryActive = false
						S.protectedTrevorFruitTool = nil
						if S.markFlamingoUnlocked then S.markFlamingoUnlocked() end
						lastZPoll = 0
					end
				end
			end
			return
		end

		S.trevorDeliveryActive = false
		S.protectedTrevorFruitTool = nil
		if S.markFlamingoUnlocked then S.markFlamingoUnlocked() end

		-- =====================================================================
		-- PHASE 3: LV. 1,500 -> DON SWAN -> KING RED HEAD -> RIP_INDRA -> SEA 3
		-- =====================================================================
		if lvl < 1500 then
			farmToLevelTarget(hrp, string.format("🌊 Sea 2->3 [Lv. %d/1500 para Don Swan & Indra]", lvl))
			return
		end

		if CommF_ and (os.clock() - lastZPoll >= 1.8) then
			lastZPoll = os.clock()
			pcall(function()
				zCheck = CommF_:InvokeServer("ZQuestProgress", "Check")
			end)
		end

		local swanRoomCenter = Vector3.new(2288.8, 15.2, 905.5)
		local playerInSwanRoom = ((hrp.Position - swanRoomCenter).Magnitude < 280) and (hrp.Position.Y < 55)

		-- 3A) zCheck == nil -> Defeat Don Swan inside Mansion Room
		if zCheck == nil then
			if not playerInSwanRoom then
				local map = Workspace:FindFirstChild("Map")
				local dressrosa = map and map:FindFirstChild("Dressrosa")
				local flamEnt = dressrosa and dressrosa:FindFirstChild("FlamingoEntrance")
				local flamExit = dressrosa and dressrosa:FindFirstChild("FlamingoExit")
				local entPos = (flamEnt and flamEnt:IsA("BasePart") and flamEnt.Position) or Vector3.new(-287.5, 305.2, 592.4)
				local insidePos = (flamExit and flamExit:IsA("BasePart") and (flamExit.CFrame * Vector3.new(0, 0, -6))) or swanRoomCenter
				setStatus("🦩 Sea 2->3: Entrando a la sala de Don Swan...")
				local reachedEnt = moveToCFrame(CFrame.new(entPos))
				if reachedEnt or (hrp.Position - entPos).Magnitude <= 30 then
					hrp.CFrame = CFrame.new(entPos)
					tryRequestEntrance(insidePos, flamEnt)
				end
				return
			end

			local swanBoss = findAliveEnemyFromSet({["Don Swan"] = true})
			if swanBoss then
				swanWasAlive = true
				swanEmptySince = 0
				engageEnemy(swanBoss, {["Don Swan"] = true}, "🦩 Boss Don Swan [Paso a Sea 3]")
				return
			elseif swanWasAlive then
				swanWasAlive = false
				lastZPoll = 0
				return
			end

			setStatus("🦩 Sea 2->3: Buscando a Don Swan en la sala...")
			local reached = moveToCFrame(CFrame.new(swanRoomCenter))
			if reached or (hrp.Position - swanRoomCenter).Magnitude <= 45 then
				local _, repSwan = Stack.findRaidBoss({"don swan"})
				if not repSwan then
					if swanEmptySince == 0 then
						swanEmptySince = os.clock()
					elseif (os.clock() - swanEmptySince >= 6.5) and (os.clock() - S.spawnedAtClock >= 8.0) then
						local doneSwan = false
						pcall(function()
							local freshZ = CommF_:InvokeServer("ZQuestProgress", "Check")
							if freshZ == 0 or freshZ == 1 then
								zCheck = freshZ
								doneSwan = true
							end
						end)
						swanEmptySince = 0
						if not doneSwan then
							clearFarmMover()
							setStatus("🦩 Don Swan no está activo -> Server Hop...")
							executeServerHop(S.serverHopMode)
						end
					end
				else
					swanEmptySince = 0
				end
			end
			return
		end

		-- Exit Don Swan's room cleanly if still inside after defeating Don Swan
		if playerInSwanRoom then
			local map = Workspace:FindFirstChild("Map")
			local dressrosa = map and map:FindFirstChild("Dressrosa")
			local flamEnt = dressrosa and dressrosa:FindFirstChild("FlamingoEntrance")
			local flamExit = dressrosa and dressrosa:FindFirstChild("FlamingoExit")
			local exitDoorPos = (flamExit and flamExit:IsA("BasePart") and flamExit.Position) or Vector3.new(2284.9, 15.2, 905.5)
			local outsidePos = (flamEnt and flamEnt:IsA("BasePart") and (flamEnt.CFrame * Vector3.new(0, 0, -6))) or Vector3.new(-287.5, 305.2, 586.0)
			setStatus("🦩 Saliendo de la sala de Don Swan...")
			local reachedExit = moveToCFrame(CFrame.new(exitDoorPos))
			if reachedExit or (hrp.Position - exitDoorPos).Magnitude <= 30 then
				hrp.CFrame = CFrame.new(exitDoorPos)
				tryRequestEntrance(outsidePos, flamExit)
			end
			return
		end

		-- 3B) zCheck == 0 -> Speak to King Red Head ("Begin") & Defeat rip_indra in Sealed Colosseum!
		if zCheck == 0 then
			local inSealedIndraArena = (hrp.Position.X < -15000)
			if inSealedIndraArena then
				local indraBoss = Stack.findRaidBoss({"rip_indra"})
				if indraBoss then
					indraWasAlive = true
					engageEnemy(indraBoss, nil, "⚡ Boss rip_indra [Paso a Sea 3]")
					return
				elseif indraWasAlive then
					indraWasAlive = false
					lastZPoll = 0
					return
				end
				setStatus("⚡ Esperando aparición / cinemática de rip_indra...")
				return
			end

			local krhPos = getNPCWorldPos("King Red Head", Vector3.new(-1929.0, 12.8, 1738.0))
			setStatus("👑 Sea 2->3: Hablando con King Red Head para combatir a rip_indra...")
			local reached = moveToCFrame(CFrame.new(krhPos + Vector3.new(0, 3, 3)))
			if (reached or (hrp.Position - krhPos).Magnitude <= 28) and (os.clock() - lastZBeginClock >= 3.5) then
				lastZBeginClock = os.clock()
				pcall(function()
					CommF_:InvokeServer("ZQuestProgress", "Check")
					CommF_:InvokeServer("ZQuestProgress", "Begin")
				end)
				lastZPoll = 0
			end
			return
		end

		-- 3C) zCheck == 1 -> rip_indra defeated! Go to Mr. Captain & TravelZou immediately!
		local capPos = getNPCWorldPos("Mr. Captain", Vector3.new(-1907.0, 5.2, -2533.0))
		setStatus("🚢 ¡rip_indra derrotado! Viajando directo al Tercer Sea con Mr. Captain...")
		if os.clock() - lastTravelInvokeClock >= 2.0 then
			lastTravelInvokeClock = os.clock()
			pcall(function()
				CommF_:InvokeServer("ZQuestProgress", "Zou")
				CommF_:InvokeServer("TravelZou")
			end)
		end
		local reached = moveToCFrame(CFrame.new(capPos + Vector3.new(0, 3, 3)))
		if reached or (hrp.Position - capPos).Magnitude <= 30 then
			pcall(function()
				CommF_:InvokeServer("ZQuestProgress", "Zou")
				CommF_:InvokeServer("TravelZou")
			end)
		end
	end

	function Stack.stepSeaProgression(hrp, hum)
		if S.autoFirstSeaComplete then
			stepFirstSeaToSecondSea(hrp, hum)
		elseif S.autoSecondSeaComplete then
			stepSecondSeaToThirdSea(hrp, hum)
		end
	end
end

--------------------------------------------------------------------------------
-- FARMING OTHERS ENGINE: DOJO, DRAGON HUNTER, BERRIES, CHESTS, LAW, KEN V2, MOBS & BOSSES
--------------------------------------------------------------------------------
do
	local CS = game:GetService("CollectionService")
	local DOJO_TRAINER_POS  = Vector3.new(5862.0, 1208.3, 872.4)
	local DRAGON_HUNTER_POS = Vector3.new(5864.8, 1208.3, 886.2)
	local TIKI_DOCK_POS     = Vector3.new(-16927.5, 9.1, 433.8)
	local DANGER_ZONE_5_POS = Vector3.new(-28500.0, 18.0, 4500.0)
	local MANSION_TRADE_POS = Vector3.new(-12595.0, 337.2, -7495.0)

	local HYDRA_TREE_POINTS = {
		Vector3.new(5840.0, 1208.5, 860.0),
		Vector3.new(5285.0, 1005.0, 390.0),
		Vector3.new(5365.0, 1005.0, 260.0),
		Vector3.new(5480.0, 1005.0, 180.0),
		Vector3.new(5610.0, 1012.0, -60.0),
		Vector3.new(5190.0, 604.0, 290.0),
	}

	Others.emberQueue = {}
	Others.lastDojoPoll = 0
	Others.dojoState = nil
	Others.lastHunterPoll = 0
	Others.hunterText = ""
	Others.hunterNeedRequest = true
	Others.treeIdx = 1
	Others.lastTreeSwitch = 0
	Others.lastBoatBuy = 0

	Others.lastBerryClaimClock = 0
	Others.lastBerrySeenClock = 0

	Others.visitedChests = {}
	Others.activeChestTarget = nil
	Others.activeChestSince = 0

	Others.lastMicrochipBuy = 0
	Others.lastLawButtonClick = 0
	Others.lastKenRetryClock = 0

	-- Hook RE/DragonDojoEmber.OnClientEvent to capture exact BlazeEmber spawn coordinates
	task.spawn(function()
		pcall(function()
			local net = ReplicatedStorage:WaitForChild("Modules", 10)
				and ReplicatedStorage.Modules:WaitForChild("Net", 10)
			local emberRE = net and net:FindFirstChild("RE/DragonDojoEmber")
			if emberRE and emberRE:IsA("RemoteEvent") then
				connect(emberRE.OnClientEvent, function(payload)
					pcall(function()
						if type(payload) == "table" then
							local function addPos(v)
								if typeof(v) == "CFrame" then
									table.insert(Others.emberQueue, {pos = v.Position, exp = os.clock() + 18})
								elseif typeof(v) == "Vector3" then
									table.insert(Others.emberQueue, {pos = v, exp = os.clock() + 18})
								elseif type(v) == "table" then
									if typeof(v.CFrame) == "CFrame" then
										table.insert(Others.emberQueue, {pos = v.CFrame.Position, exp = os.clock() + 18})
									elseif typeof(v.Position) == "Vector3" then
										table.insert(Others.emberQueue, {pos = v.Position, exp = os.clock() + 18})
									end
								end
							end
							addPos(payload)
							if type(payload.Embers) == "table" then
								for _, em in pairs(payload.Embers) do
									addPos(em)
								end
							end
						end
					end)
				end)
			end
		end)
	end)

	local function getNetRemote(name)
		local m = ReplicatedStorage:FindFirstChild("Modules")
		local net = m and m:FindFirstChild("Net")
		return net and net:FindFirstChild(name)
	end

	local function getLiveNPCPos(npcName, fallbackPos)
		if NPCManagerModule and type(NPCManagerModule.getNPCsByName) == "function" then
			local ok, list = pcall(NPCManagerModule.getNPCsByName, npcName)
			if ok and type(list) == "table" and list[1] then
				local okM, model = pcall(function() return list[1]:getModel() end)
				if okM and model then
					local okP, cf = pcall(function() return model:GetPivot() end)
					if okP and cf then return cf.Position end
				end
			end
		end
		for _, f in ipairs({Workspace:FindFirstChild("NPCs"), ReplicatedStorage:FindFirstChild("NPCs")}) do
			local m = f and f:FindFirstChild(npcName)
			if m then
				local okP, cf = pcall(function() return m:GetPivot() end)
				if okP and cf then return cf.Position end
			end
		end
		return fallbackPos
	end

	-- Finds any spawned BlazeEmber in Workspace or from RE/DragonDojoEmber queue
	function Others.findActiveBlazeEmber(refPos)
		for _, folder in ipairs({Workspace, Workspace:FindFirstChild("_WorldOrigin"), Workspace:FindFirstChild("Effects")}) do
			if folder then
				for _, obj in ipairs(folder:GetChildren()) do
					local low = obj.Name:lower()
					if low:find("blazeember") or (low:find("ember") and not low:find("member")) then
						local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
						if part then
							return part.Position, part
						end
						local ok, cf = pcall(function() return obj:GetPivot() end)
						if ok and cf then
							return cf.Position, nil
						end
					end
				end
			end
		end

		for i = #Others.emberQueue, 1, -1 do
			local item = Others.emberQueue[i]
			if os.clock() > item.exp or (refPos and (refPos - item.pos).Magnitude <= 8) then
				table.remove(Others.emberQueue, i)
			else
				return item.pos, nil
			end
		end
		return nil, nil
	end

	-- Navigates into Sea Danger Zone (for Yellow / Green / Red Dojo Belt quests)
	local function navigateSeaDangerZone(targetPos, hrp, hum, statusLabel)
		local boatsFolder = Workspace:FindFirstChild("Boats")
		local myBoatSeat = nil
		if boatsFolder then
			for _, boat in ipairs(boatsFolder:GetChildren()) do
				local owner = boat:FindFirstChild("Owner")
				local seat = boat:FindFirstChildOfClass("VehicleSeat") or boat:FindFirstChild("VehicleSeat", true)
				if seat and (not owner or tostring(owner.Value) == LocalPlayer.Name or owner.Value == LocalPlayer) then
					myBoatSeat = seat
					break
				end
			end
		end

		if myBoatSeat then
			if hum.SeatPart ~= myBoatSeat then
				setStatus(statusLabel .. " -> Subiendo al bote...")
				local reached = moveToCFrame(myBoatSeat.CFrame + Vector3.new(0, 2, 0))
				if reached or (hrp.Position - myBoatSeat.Position).Magnitude <= 14 then
					hrp.CFrame = myBoatSeat.CFrame + Vector3.new(0, 1.5, 0)
					pcall(function() myBoatSeat:Sit(hum) end)
				end
				return
			end
			-- Drive boat smoothly toward target sea zone
			local boatModel = myBoatSeat:FindFirstAncestorOfClass("Model")
			local dist = (myBoatSeat.Position - targetPos).Magnitude
			local danger = tonumber(LocalPlayer:GetAttribute("DangerLevel")) or 0
			setStatus(string.format("%s [Danger %d | %dm]", statusLabel, danger, math.floor(dist)))
			if dist > 45 and boatModel then
				local stepDir = (Vector3.new(targetPos.X, myBoatSeat.Position.Y, targetPos.Z) - myBoatSeat.Position)
				if stepDir.Magnitude > 1 then
					local nextPos = myBoatSeat.Position + stepDir.Unit * math.min(dist, 38)
					pcall(function()
						boatModel:PivotTo(CFrame.lookAt(nextPos, Vector3.new(targetPos.X, nextPos.Y, targetPos.Z)))
					end)
				end
			end
			return
		end

		-- Buy boat at Tiki Outpost dock first
		setStatus(statusLabel .. " -> Yendo al muelle de Tiki Outpost por bote...")
		local reached = moveToCFrame(CFrame.new(TIKI_DOCK_POS))
		if (reached or (hrp.Position - TIKI_DOCK_POS).Magnitude <= 30) and CommF_ and (os.clock() - Others.lastBoatBuy > 4.0) then
			Others.lastBoatBuy = os.clock()
			pcall(function() CommF_:InvokeServer("BuyBoat", "Sentinel") end)
			pcall(function() CommF_:InvokeServer("BuyBoat", "Guardian") end)
			pcall(function() CommF_:InvokeServer("BuyBoat", "Dinghy") end)
		end
	end

	-- 1) AUTO QUEST DOJO TRAINER (ALL BELTS)
	function Others.stepDojoTrainer(hrp, hum)
		if getCurrentSeaNumber() ~= 3 then
			setStatus("⚠️ Auto Quest Dojo Trainer requiere estar en Sea 3 (Hydra Island)")
			return
		end

		local dojoRF = getNetRemote("RF/InteractDragonQuest")
		if not dojoRF then
			setStatus("⚠️ No se encontró RF/InteractDragonQuest")
			return
		end

		local trainerPos = getLiveNPCPos("Dojo Trainer", DOJO_TRAINER_POS)

		if os.clock() - Others.lastDojoPoll >= 4.0 then
			Others.lastDojoPoll = os.clock()
			local ok, res = pcall(function()
				return dojoRF:InvokeServer({NPC = "Dojo Trainer", Command = "RequestQuest"})
			end)
			if ok then
				Others.dojoState = res
			end
		end

		local st = Others.dojoState
		if st == nil then
			setStatus("🥋 Dojo Trainer: Abordando NPC Dojo Trainer en Hydra Island...")
			local reached = moveToCFrame(CFrame.new(trainerPos + Vector3.new(0, 3, 3.5)))
			if reached or (hrp.Position - trainerPos).Magnitude <= 18 then
				pcall(function()
					Others.dojoState = dojoRF:InvokeServer({NPC = "Dojo Trainer", Command = "RequestQuest"})
				end)
			end
			return
		elseif st == "Timeout" then
			setStatus("⏳ Dojo Trainer: En enfriamiento de 12 horas (máximo 3 cinturones por tanda)")
			clearFarmMover()
			return
		elseif st == "Completed" then
			setStatus("✅ Dojo Trainer: ¡Los 8 cinturones (White -> Black) ya están completados!")
			clearFarmMover()
			return
		elseif type(st) ~= "table" or type(st.Quest) ~= "table" then
			setStatus("⚠️ Dojo Trainer bloqueado: Requiere Lv. 1500+ y 500 Mastery en Dragon Talon")
			local reached = moveToCFrame(CFrame.new(trainerPos + Vector3.new(0, 3, 3.5)))
			if reached or (hrp.Position - trainerPos).Magnitude <= 18 then
				pcall(function()
					Others.dojoState = dojoRF:InvokeServer({NPC = "Dojo Trainer", Command = "RequestQuest"})
				end)
			end
			return
		end

		local q = st.Quest
		local belt = tostring(q.BeltName or "")
		local qName = tostring(q.QuestName or "")
		local prog = tonumber(q.Progress) or 0
		local goal = math.max(1, tonumber(q.Goal) or 1)
		local pct = math.floor((prog / goal) * 100)

		-- Claim Belt Reward automatically when Progress >= Goal!
		if prog >= goal then
			setStatus(string.format("🥋 Dojo [%s Belt]: ¡100%%! Reclamando cinturón con Dojo Trainer...", belt))
			if hum.Sit then hum.Sit = false end
			local reached = moveToCFrame(CFrame.new(trainerPos + Vector3.new(0, 3, 3.5)))
			if reached or (hrp.Position - trainerPos).Magnitude <= 20 then
				pcall(function()
					dojoRF:InvokeServer({NPC = "Dojo Trainer", Command = "ClaimQuest"})
					Others.dojoState = dojoRF:InvokeServer({NPC = "Dojo Trainer", Command = "RequestQuest"})
				end)
			end
			return
		end

		local bLow = belt:lower()
		local qLow = qName:lower()

		-- BELT 1: WHITE BELT ("Admittance" - Kill ~20 NPCs near player level)
		if bLow:find("white") or qLow:find("admittance") then
			if hum.Sit then hum.Sit = false end
			local bestQ = getBestQuestForPlayer()
			if bestQ then
				local mobSet = {[bestQ.mobName] = true}
				local mob = findAliveEnemyFromSet(mobSet)
				if mob then
					engageEnemy(mob, mobSet, string.format("🥋 White Belt [%d%%]", pct))
				else
					setStatus(string.format("🥋 White Belt [%d%%]: Patrullando %s...", pct, bestQ.mobName))
					patrolAroundSpawns("DojoWhite_" .. bestQ.mobName, bestQ.spawns)
				end
			end
			return

		-- BELT 2: YELLOW BELT ("Water Warrior" - Defeat 5 Sea Entities: Sharks / Piranhas)
		elseif bLow:find("yellow") or qLow:find("water warrior") then
			local seaMob = findAliveEnemyFromSet({["Shark"] = true, ["Piranha"] = true, ["Fish Crew Member"] = true})
			if seaMob then
				if hum.Sit then hum.Sit = false end
				engageEnemy(seaMob, nil, string.format("🥋 Yellow Belt [%d%%]", pct))
			else
				navigateSeaDangerZone(Vector3.new(-21000.0, 18.0, 1800.0), hrp, hum, string.format("🥋 Yellow Belt [%d%%]: Buscando Sharks/Piranhas", pct))
			end
			return

		-- BELT 3: ORANGE BELT ("Diplomacy" - Trade with another player -> REQUIRES ANOTHER PERSON)
		elseif bLow:find("orange") or qLow:find("diplomacy") then
			if hum.Sit then hum.Sit = false end
			setStatus(string.format("⚠️ Orange Belt [%d%%]: Requiere hacer 1 Trade con otra persona en Mansion (se reclamará solo)", pct))
			moveToCFrame(CFrame.new(MANSION_TRADE_POS))
			return

		-- BELT 4: GREEN BELT ("Beyond the Horizon" - Stay in Sea Danger Level 4-6)
		elseif bLow:find("green") or qLow:find("horizon") then
			navigateSeaDangerZone(DANGER_ZONE_5_POS, hrp, hum, string.format("🥋 Green Belt [%d%%]: Zona Peligro 4-6", pct))
			return

		-- BELT 5: BLUE BELT ("Saikeirei" - Pick up fruit dropped by player & drop one back -> REQUIRES ANOTHER PERSON)
		elseif bLow:find("blue") or qLow:find("saikeirei") then
			if hum.Sit then hum.Sit = false end
			local fObj, fHandle = Stack.findSpawnedFruitInWorkspace()
			if fObj and fHandle and (hrp.Position - fHandle.Position).Magnitude <= 350 then
				moveToCFrame(fHandle.CFrame)
			end
			setStatus(string.format("⚠️ Blue Belt [%d%%]: Requiere que otra persona tire una fruta, recogerla y devolverle otra", pct))
			return

		-- BELT 6: PURPLE BELT ("Hanto" - Defeat 3 Elite Pirates)
		elseif bLow:find("purple") or qLow:find("hanto") then
			if hum.Sit then hum.Sit = false end
			local avail = Stack.pollEliteHunterStatus()
			if avail then
				Stack.executeEliteHunterStep(hrp)
			else
				setStatus(string.format("🥋 Purple Belt [%d%%]: Esperando aparición de Elite Pirate (o activa Hop Elite)...", pct))
			end
			return

		-- BELT 7: RED BELT ("Teitoku" - Defeat Terrorshark or Rumbling Waters)
		elseif bLow:find("red") or qLow:find("teitoku") then
			local tsMob = findAliveEnemyFromSet({["Terrorshark"] = true})
			if tsMob then
				if hum.Sit then hum.Sit = false end
				engageEnemy(tsMob, nil, string.format("🥋 Red Belt [%d%%]", pct))
			else
				navigateSeaDangerZone(DANGER_ZONE_5_POS, hrp, hum, string.format("🥋 Red Belt [%d%%]: Buscando Terrorshark", pct))
			end
			return

		-- BELT 8: BLACK BELT ("Ryu to Ittai" - Collect 3 Dinosaur Bones at Prehistoric Island)
		else
			if hum.Sit then hum.Sit = false end
			for _, obj in ipairs(Workspace:GetChildren()) do
				if obj.Name:lower():find("bone") and obj.Name:lower():find("dino") then
					local p = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
					if p then
						setStatus(string.format("🥋 Black Belt [%d%%]: Recogiendo Dinosaur Bone!", pct))
						moveToCFrame(p.CFrame)
						return
					end
				end
			end
			local golem = findAliveEnemyFromSet({["Lava Golem"] = true})
			if golem then
				engageEnemy(golem, nil, string.format("🥋 Black Belt [%d%%]", pct))
				return
			end
			setStatus(string.format("⚠️ Black Belt [%d%%]: Requiere evento Prehistoric Island (3 Dinosaur Bones en equipo)", pct))
		end
	end

	-- 2) AUTO QUEST DRAGON HUNTER (BLAZE EMBERS)
	function Others.stepDragonHunter(hrp)
		if getCurrentSeaNumber() ~= 3 then
			setStatus("⚠️ Auto Quest Dragon Hunter requiere estar en Sea 3 (Hydra Island)")
			return
		end

		-- Always grab spawned Blaze Embers immediately before they fly away!
		local emberPos, emberPart = Others.findActiveBlazeEmber(hrp.Position)
		if emberPos then
			setStatus("🔥 Dragon Hunter: ¡Recogiendo Blaze Ember!")
			local reached = moveToCFrame(CFrame.new(emberPos))
			if reached or (hrp.Position - emberPos).Magnitude <= 16 then
				hrp.CFrame = CFrame.new(emberPos)
				if emberPart and firetouchinterest then
					pcall(function()
						firetouchinterest(hrp, emberPart, 0)
						firetouchinterest(hrp, emberPart, 1)
					end)
				end
			end
			return
		end

		local hunterRF = getNetRemote("RF/DragonHunter")
		if not hunterRF then
			setStatus("⚠️ No se encontró RF/DragonHunter")
			return
		end

		local hunterPos = getLiveNPCPos("Dragon Hunter", DRAGON_HUNTER_POS)

		if os.clock() - Others.lastHunterPoll >= 3.5 then
			Others.lastHunterPoll = os.clock()
			pcall(function()
				local res = hunterRF:InvokeServer({Context = "Check"})
				local txt = (type(res) == "table" and tostring(res.Text or res.Description or "")) or tostring(res or "")
				Others.hunterText = txt
				local low = txt:lower()
				if txt == "" or low:find("head back") or low:find("complete more") or low:find("would you like") or low:find("none") then
					Others.hunterNeedRequest = true
				elseif low:find("locked") or low:find("prove you're worthy") then
					Others.hunterNeedRequest = false
				else
					Others.hunterNeedRequest = false
				end
			end)
		end

		local lowTxt = Others.hunterText:lower()
		if lowTxt:find("locked") or lowTxt:find("prove you're worthy") then
			setStatus("⚠️ Dragon Hunter bloqueado: Completa primero White & Yellow Belt con Dojo Trainer")
			return
		end

		if Others.hunterNeedRequest then
			setStatus("🐉 Dragon Hunter: Pidiendo nueva misión de caza en el Dojo...")
			local reached = moveToCFrame(CFrame.new(hunterPos + Vector3.new(0, 3, 3.5)))
			if reached or (hrp.Position - hunterPos).Magnitude <= 22 then
				pcall(function()
					hunterRF:InvokeServer({Context = "RequestQuest"})
					local res = hunterRF:InvokeServer({Context = "Check"})
					Others.hunterText = (type(res) == "table" and tostring(res.Text or res.Description or "")) or tostring(res or "")
					Others.hunterNeedRequest = false
				end)
			end
			return
		end

		-- Task A: Defeat 3 Venomous Assailants
		if lowTxt:find("venomous") or lowTxt:find("assailant") then
			local mSet = {["Venomous Assailant"] = true}
			local mob = findAliveEnemyFromSet(mSet)
			if mob then
				engageEnemy(mob, mSet, "🐉 Dragon Hunter")
			else
				local sp = collectSpawnsForSet(mSet)
				if #sp == 0 then sp = {CFrame.new(4910.0, 610.0, 420.0)} end
				setStatus("🐉 Dragon Hunter: Buscando Venomous Assailant en Hydra...")
				patrolAroundSpawns("DH_Venomous", sp)
			end
			return

		-- Task B: Defeat 3 Hydra Enforcers
		elseif lowTxt:find("enforcer") or lowTxt:find("hydra enforcer") then
			local mSet = {["Hydra Enforcer"] = true}
			local mob = findAliveEnemyFromSet(mSet)
			if mob then
				engageEnemy(mob, mSet, "🐉 Dragon Hunter")
			else
				local sp = collectSpawnsForSet(mSet)
				if #sp == 0 then sp = {CFrame.new(4625.0, 1002.0, 385.0)} end
				setStatus("🐉 Dragon Hunter: Buscando Hydra Enforcer en Hydra...")
				patrolAroundSpawns("DH_Enforcer", sp)
			end
			return

		-- Task C: Destroy 10 Trees on Hydra Island
		else
			if os.clock() - Others.lastTreeSwitch > 3.2 then
				Others.lastTreeSwitch = os.clock()
				Others.treeIdx = (Others.treeIdx % #HYDRA_TREE_POINTS) + 1
			end
			local tPos = HYDRA_TREE_POINTS[Others.treeIdx]
			setStatus(string.format("🐉 Dragon Hunter: Destruyendo árboles en Hydra (%d/%d)...", Others.treeIdx, #HYDRA_TREE_POINTS))
			local reached = moveToCFrame(CFrame.new(tPos))
			if reached or (hrp.Position - tPos).Magnitude <= 20 then
				performNormalAttack(S.masteryPriority and S.masteryCategory or "Blox Fruit", nil)
				triggerSelectedMasterySkills(nil)
				pcall(function()
					local bt = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("BreakTree")
					if bt and bt:IsA("RemoteEvent") then
						bt:FireServer(tPos)
					end
				end)
			end
		end
	end

	-- 3) BERRY COLLECTOR & HOP FIND BERRY
	function Others.findNearestBerry(refPos)
		local bushes = CS:GetTagged("BerryBush")
		local bestCF = nil
		local bestDist = math.huge
		local bestCfg = nil
		local bestAttrName = nil
		local bestBerryName = nil

		for _, cfg in ipairs(bushes) do
			local parent = cfg.Parent
			if parent then
				local originCF = parent:GetAttribute("CFrame") or parent:GetAttribute("_Origin")
				if typeof(originCF) ~= "CFrame" then
					local ok, pv = pcall(function() return parent:GetPivot() end)
					if ok then originCF = pv end
				end
				if typeof(originCF) == "CFrame" then
					for attrKey, attrVal in pairs(cfg:GetAttributes()) do
						if string.sub(attrKey, 1, 12) == "_BerryCFrame" and type(attrVal) == "string" and attrVal ~= "" then
							local relCF = parent:GetAttribute(attrKey)
							local worldCF = (typeof(relCF) == "CFrame") and originCF:ToWorldSpace(relCF) or originCF
							local d = refPos and (worldCF.Position - refPos).Magnitude or 0
							if d < bestDist then
								bestDist = d
								bestCF = worldCF
								bestCfg = cfg
								bestAttrName = attrKey
								bestBerryName = attrVal
							end
						end
					end
				end
			end
		end

		return bestCF, bestCfg, bestAttrName, bestBerryName, bestDist
	end

	function Others.stepBerryFarm(hrp)
		local berryCF, cfg, attrKey, berryName, dist = Others.findNearestBerry(hrp.Position)
		if berryCF and cfg then
			Others.lastBerrySeenClock = os.clock()
			setStatus(string.format("🍓 Recolectando %s [%dm]...", tostring(berryName or "Berry"), math.floor(dist or 0)))
			local reached = moveToCFrame(berryCF + Vector3.new(0, 2, 0))
			if reached or (hrp.Position - berryCF.Position).Magnitude <= 16 then
				hrp.CFrame = berryCF
				-- Trigger native ProximityPrompt created by BerryBushClient
				if fireproximityprompt then
					for _, container in ipairs({cfg, cfg.Parent}) do
						if container then
							for _, d in ipairs(container:GetDescendants()) do
								if d:IsA("ProximityPrompt") then
									pcall(function() fireproximityprompt(d) end)
								end
							end
						end
					end
				end
				-- Fallback ClaimBerry RemoteFunction
				if os.clock() - Others.lastBerryClaimClock > 0.45 then
					Others.lastBerryClaimClock = os.clock()
					pcall(function()
						local claimRF = getNetRemote("RF/ClaimBerry")
						if claimRF and cfg.Parent then
							claimRF:InvokeServer(cfg.Parent.Name, attrKey)
						end
					end)
				end
			end
			return true
		end

		if S.hopFindBerry then
			if (os.clock() - S.spawnedAtClock >= 6.0) and (os.clock() - Others.lastBerrySeenClock >= 2.0) then
				clearFarmMover()
				setStatus("🍓 0 Berries en este servidor -> Hop Find Berry...")
				executeServerHop(S.serverHopMode)
			else
				setStatus("🍓 Escaneando arbustos de Berries antes de Server Hop...")
			end
			return true
		end

		return false
	end

	-- 4) CHEST FARM & AUTO CHEST HOP (WITH COUNTER SLIDER)
	function Others.stepChestFarm(hrp)
		local limit = math.max(1, tonumber(S.chestHopLimit) or 25)
		if S.autoChestHop and S.chestsCollectedCount >= limit then
			S.chestsCollectedCount = 0
			table.clear(Others.visitedChests)
			clearFarmMover()
			setStatus(string.format("💰 Meta de cofres alcanzada (%d/%d) -> Auto Chest Hop...", limit, limit))
			executeServerHop(S.serverHopMode)
			return true
		end

		-- Check if previous targeted chest was collected
		if Others.activeChestTarget then
			local prev = Others.activeChestTarget
			if (not prev.Parent) or prev:GetAttribute("IsDisabled") or (not prev:FindFirstChildOfClass("TouchTransmitter")) then
				if not Others.visitedChests[prev] then
					Others.visitedChests[prev] = true
					S.chestsCollectedCount = S.chestsCollectedCount + 1
				end
				Others.activeChestTarget = nil
			elseif os.clock() - Others.activeChestSince > 14.0 then
				Others.visitedChests[prev] = true
				Others.activeChestTarget = nil
			end
		end

		local chestPart, dist = findNearestChestPart(Others.visitedChests)
		if chestPart then
			if Others.activeChestTarget ~= chestPart then
				Others.activeChestTarget = chestPart
				Others.activeChestSince = os.clock()
			end
			if S.autoChestHop then
				setStatus(string.format("💰 Auto Chest Hop [%d/%d]: Yendo a cofre [%dm]...", S.chestsCollectedCount, limit, math.floor(dist or 0)))
			else
				setStatus(string.format("💰 Auto Chest [Recogidos: %d]: Yendo a cofre [%dm]...", S.chestsCollectedCount, math.floor(dist or 0)))
			end

			local reached = moveToCFrame(chestPart.CFrame + Vector3.new(0, 1.5, 0))
			if reached or (hrp.Position - chestPart.Position).Magnitude <= 14 then
				hrp.CFrame = chestPart.CFrame
				if firetouchinterest then
					pcall(function()
						firetouchinterest(hrp, chestPart, 0)
						firetouchinterest(hrp, chestPart, 1)
					end)
				end
				if not Others.visitedChests[chestPart] then
					Others.visitedChests[chestPart] = true
					S.chestsCollectedCount = S.chestsCollectedCount + 1
					Others.activeChestTarget = nil
				end
			end
			return true
		end

		if S.autoChestHop and (os.clock() - S.spawnedAtClock >= 5.5) then
			S.chestsCollectedCount = 0
			table.clear(Others.visitedChests)
			clearFarmMover()
			setStatus("💰 No quedan más cofres en el mapa -> Auto Chest Hop...")
			executeServerHop(S.serverHopMode)
			return true
		end

		setStatus("💰 Auto Chest: Esperando reaparición de cofres...")
		return true
	end

	-- 5) RAID DE LAW / ORDER (SEA 2 - BUY MICROCHIP & START / ATTACK ORDER)
	function Others.stepLawRaid(hrp, hum)
		if getCurrentSeaNumber() ~= 2 then
			setStatus("⚠️ Auto Raid de Law solo está disponible en Sea 2 (Hot and Cold)")
			return true
		end

		-- Step A: If Order (Law) is alive, attack immediately!
		local liveOrder, repOrder = Stack.findRaidBoss({"order"})
		if liveOrder then
			engageEnemy(liveOrder, nil, "⚡ Raid Law (Order)")
			return true
		elseif repOrder then
			local orderPos = Stack.getModelPos(repOrder, Vector3.new(-6217.2, 28.0, -5053.1))
			setStatus("⚡ Raid de Law: Volando hacia la arena de Order...")
			moveToCFrame(CFrame.new(orderPos + Vector3.new(0, 20, 0)))
			return true
		end

		-- Step B: Check if player already has Microchip
		local chipTool = Stack.findSpecialTool({"microchip"}, nil)
		if not chipTool then
			local fragsObj = LocalPlayer:FindFirstChild("Data") and LocalPlayer.Data:FindFirstChild("Fragments")
			local myFrags = fragsObj and fragsObj.Value or 0
			if myFrags < 1000 then
				setStatus(string.format("⚠️ Raid de Law: Necesitas 1,000 Fragmentos para el Microchip (Tienes: %d)", myFrags))
				return true
			end

			local arlPos = getLiveNPCPos("arlthmetic", Vector3.new(-4853.26, 174.09, -5611.60))
			setStatus("⚡ Raid de Law: Comprando Microchip con arlthmetic...")
			local reached = moveToCFrame(CFrame.new(arlPos + Vector3.new(0, 2, 3)))
			if (reached or (hrp.Position - arlPos).Magnitude <= 20) and CommF_ and (os.clock() - Others.lastMicrochipBuy > 2.2) then
				Others.lastMicrochipBuy = os.clock()
				pcall(function()
					CommF_:InvokeServer("BlackbeardReward", "Microchip", "1")
					CommF_:InvokeServer("BlackbeardReward", "Microchip", "2")
				end)
			end
			return true
		end

		-- Step C: Microchip is in inventory -> Unequip tools & click Secret Lab RaidSummon button!
		local map = Workspace:FindFirstChild("Map")
		local ci = map and map:FindFirstChild("CircleIsland")
		local raidSummon = ci and ci:FindFirstChild("RaidSummon")
		local btnMain = raidSummon and raidSummon:FindFirstChild("Button") and raidSummon.Button:FindFirstChild("Main")
		local cd = btnMain and btnMain:FindFirstChildOfClass("ClickDetector")
		local btnPos = (btnMain and btnMain:IsA("BasePart") and btnMain.Position) or Vector3.new(-5553.21, 224.32, -5930.35)

		setStatus("⚡ Raid de Law: Iniciando Raid en laboratorio secreto...")
		local reached = moveToCFrame(CFrame.new(btnPos + Vector3.new(0, 3, 0)))
		if reached or (hrp.Position - btnPos).Magnitude <= 22 then
			pcall(function() hum:UnequipTools() end)
			if cd and fireclickdetector and (os.clock() - Others.lastLawButtonClick > 1.5) then
				Others.lastLawButtonClick = os.clock()
				pcall(function() fireclickdetector(cd) end)
			end
		end
		return true
	end

	-- 6) OBSERVATION HAKI V2 / DODGE EXP FARM + SERVER HOP
	function Others.stepObservationFarm(hrp, hum)
		local kenActive = LocalPlayer:GetAttribute("KenActive") == true
		local kenLeft = tonumber(LocalPlayer:GetAttribute("KenDodgesLeft")) or 0
		local kenMax = math.max(1, tonumber(LocalPlayer:GetAttribute("KenMaxDodges")) or 8)

		-- Try enabling Ken Haki if dodges > 0 (or retry periodically)
		if (kenLeft > 0 and not kenActive) or (not kenActive and os.clock() - Others.lastKenRetryClock > 2.5) then
			Others.lastKenRetryClock = os.clock()
			if CommE then
				pcall(function() CommE:FireServer("Ken", true) end)
			end
		end

		local mob = findAliveEnemyFromSet(nil)
		local eHrp = mob and mob:FindFirstChild("HumanoidRootPart")

		-- If dodges are depleted (0 left and Ken inactive): Hop or wait safely in air!
		if kenLeft <= 0 and not kenActive then
			if S.hopObservation and (os.clock() - S.spawnedAtClock >= 6.0) then
				clearFarmMover()
				setStatus("👁️ Esquives agotados (0/" .. tostring(kenMax) .. ") -> Hop Server Observación...")
				executeServerHop(S.serverHopMode)
				return true
			end
			setStatus(string.format("👁️ Haki Observación: Recargando esquives (0/%d)...", kenMax))
			if eHrp then
				moveToCFrame(CFrame.new(eHrp.Position + Vector3.new(0, 42, 0)))
			end
			return true
		end

		-- Safety check: heal up high if HP < 35% so player never dies while dodging!
		local hpRatio = hum.Health / math.max(1, hum.MaxHealth)
		if hpRatio < 0.35 then
			setStatus(string.format("👁️ Haki Observación: Recuperando vida (%d%% HP)...", math.floor(hpRatio * 100)))
			if eHrp then
				moveToCFrame(CFrame.new(eHrp.Position + Vector3.new(0, 42, 0)))
			end
			return true
		end

		if mob and eHrp then
			setStatus(string.format("👁️ Farm Observación: Esquivando %s [Dodges: %d/%d]", mob.Name, kenLeft, kenMax))
			moveToCFrame(CFrame.new(eHrp.Position + Vector3.new(0, 1.5, 3.5)), eHrp.Position)
		else
			local bestQ = getBestQuestForPlayer()
			if bestQ then
				setStatus(string.format("👁️ Farm Observación: Buscando NPCs (%s) [Dodges: %d/%d]...", bestQ.mobName, kenLeft, kenMax))
				patrolAroundSpawns("KenObs_" .. bestQ.mobName, bestQ.spawns)
			else
				setStatus("👁️ Farm Observación: Acércate a una isla con NPCs...")
			end
		end
		return true
	end

	-- =========================================================================
	-- 7) AUTO KILL MOB (ALL POSSIBLE MOBS) & AUTO BOSS + LIVE ACTIVE VERIFIER
	-- =========================================================================
	Others.mobFallbackPos = {}
	Others.bossQuestInfo = {}
	Others.allBossNames = {}

	local SEA_BOSS_DEFAULTS = {
		[1] = {
			"The Gorilla King", "Bobby", "Yeti", "Mob Leader", "Vice Admiral",
			"Saber Expert", "Warden", "Chief Warden", "Swan", "Magma Admiral",
			"Fishman Lord", "Wysper", "Thunder God", "Cyborg", "Greybeard",
		},
		[2] = {
			"Diamond", "Jeremy", "Orbitus", "Don Swan", "Smoke Admiral",
			"Cursed Captain", "Darkbeard", "Order", "Awakened Ice Admiral", "Tide Keeper",
		},
		[3] = {
			"Stone", "Kilo Admiral", "Captain Elephant", "Beautiful Pirate",
			"Cake Queen", "Longma", "Tyrant of the Skies", "Soul Reaper",
			"Cake Prince", "Dough King", "rip_indra True Form",
		},
	}

	local KNOWN_BOSS_POS = {
		-- Sea 1
		["The Gorilla King"]     = Vector3.new(-1129, 6, -451),
		["Bobby"]                = Vector3.new(-1147, 15, 4350),
		["Yeti"]                 = Vector3.new(1218, 138, -1488),
		["Mob Leader"]           = Vector3.new(-2848, 8, 5342),
		["Vice Admiral"]         = Vector3.new(-5006, 29, 4352),
		["Saber Expert"]         = Vector3.new(-1458, 30, -50),
		["Warden"]               = Vector3.new(5278, 25, 845),
		["Chief Warden"]         = Vector3.new(5278, 25, 845),
		["Swan"]                 = Vector3.new(5230, 4, 749),
		["Magma Admiral"]        = Vector3.new(-5530, 12, 8467),
		["Fishman Lord"]         = Vector3.new(61351, 31, 1113),
		["Wysper"]               = Vector3.new(-7925, 5551, -636),
		["Thunder God"]          = Vector3.new(-7748, 5607, -2305),
		["Cyborg"]               = Vector3.new(6094, 74, 3826),
		["Greybeard"]            = Vector3.new(-5023, 29, 4312),
		-- Sea 2
		["Diamond"]              = Vector3.new(-1711, 199, -97),
		["Jeremy"]               = Vector3.new(2338, 448, 700),
		["Orbitus"]              = Vector3.new(-2138, 73, -4326),
		["Don Swan"]             = Vector3.new(2290, 17, 663),
		["Smoke Admiral"]        = Vector3.new(-4857, 233, -5583),
		["Cursed Captain"]       = Vector3.new(912, 181, 33340),
		["Darkbeard"]            = Vector3.new(3777, 15, -3498),
		["Order"]                = Vector3.new(-6217, 28, -5053),
		["Awakened Ice Admiral"] = Vector3.new(6552, 325, -6990),
		["Tide Keeper"]          = Vector3.new(-3760, 78, -11586),
		-- Sea 3
		["Stone"]                = Vector3.new(-1086, 40, 6791),
		["Island Empress"]       = Vector3.new(5713, 602, 202),
		["Hydra Leader"]         = Vector3.new(5713, 602, 202),
		["Kilo Admiral"]         = Vector3.new(2889, 424, -7233),
		["Captain Elephant"]     = Vector3.new(-13376, 319, -8423),
		["Beautiful Pirate"]     = Vector3.new(5312, 22, -125),
		["Cake Queen"]           = Vector3.new(-709, 382, -11150),
		["Longma"]               = Vector3.new(-10238, 390, -9549),
		["Tyrant of the Skies"]  = Vector3.new(-16250, 155, 1395),
		["Soul Reaper"]          = Vector3.new(-9570, 172, 6151),
		["Cake Prince"]          = Vector3.new(-2145, 70, -12405),
		["Dough King"]           = Vector3.new(-2145, 70, -12405),
		["rip_indra True Form"]  = Vector3.new(-5560, 314, -2680),
	}

	local SEA_EXTRA_MOBS = {
		[1] = {"Shanda", "Royal Squad", "Royal Soldier", "Galley Pirate", "Galley Captain"},
		[2] = {"Factory Staff", "Swan Pirate", "Ship Deckhand", "Ship Engineer", "Ship Steward", "Ship Officer"},
		[3] = {
			"Reborn Skeleton", "Living Zombie", "Demonic Soul", "Posessed Mummy",
			"Cookie Crafter", "Cake Guard", "Baking Staff", "Head Baker",
			"Venomous Assailant", "Hydra Enforcer", "Shark", "Piranha", "Terrorshark",
		},
	}

	function Others.cleanEntityName(raw)
		local s = tostring(raw or "")
		s = s:gsub("^🟢%s*", ""):gsub("^🔴%s*", "")
		s = s:gsub("%s*%[ACTIVO%]", ""):gsub("%s*%[Inactivo%]", "")
		s = s:gsub("%s*%[Lv%.%s*%d+%]", ""):gsub("%s*%[Boss%]", ""):gsub("%s*%[Raid Boss%]", "")
		s = s:gsub("^%s+", ""):gsub("%s+$", "")
		return s
	end

	local function isDummyOrCutsceneEntity(clean, seaNum)
		if clean == "" or clean == "MenuMarine" or clean == "MenuPirate" then
			return true
		end
		-- In Sea 2, "rip_indra" at (-26952, 22, 329) is the locked Sea 3 transition cutscene NPC
		if seaNum == 2 and clean:lower() == "rip_indra" then
			return true
		end
		return false
	end

	local function getSeaQuestNPCPositions()
		local npcPositions = {}
		if GuideModule and GuideModule.Data and GuideModule.Data.NPCList then
			for _, npcData in pairs(GuideModule.Data.NPCList) do
				if npcData.InternalQuestName and npcData.Position then
					npcPositions[npcData.InternalQuestName] = CFrame.new(npcData.Position)
				end
			end
		end
		return npcPositions
	end

	function Others.collectAllPossibleMobs()
		local seaNum = getCurrentSeaNumber()
		local npcPositions = getSeaQuestNPCPositions()
		local hasGuideNPCs = (next(npcPositions) ~= nil)
		local seen = {}
		local bossKnown = {}
		for _, list in pairs(SEA_BOSS_DEFAULTS) do
			for _, b in ipairs(list) do bossKnown[b] = true end
		end
		bossKnown["Island Empress"] = true
		bossKnown["Hydra Leader"] = true

		local seaQuestMobs = {}

		if QuestsModule then
			for qGroup, qList in pairs(QuestsModule) do
				for _, qData in ipairs(qList) do
					local lvl = tonumber(qData.LevelReq) or 0
					local inSea = false
					if hasGuideNPCs then
						inSea = (npcPositions[qGroup] ~= nil)
					else
						if seaNum == 1 then
							inSea = (lvl < 700)
						elseif seaNum == 2 then
							inSea = (lvl >= 700 and lvl < 1500)
						else
							inSea = (lvl >= 1500)
						end
					end

					if qData.Task then
						for mobName, cnt in pairs(qData.Task) do
							local clean = Others.cleanEntityName(mobName)
							if cnt == 1 then
								bossKnown[clean] = true
							elseif inSea and cnt > 1 and not isDummyOrCutsceneEntity(clean, seaNum) then
								local npcCF = npcPositions[qGroup]
								if npcCF and not Others.mobFallbackPos[clean] then
									local regCF = findNearestEnemyRegionCFrame(npcCF.Position)
									Others.mobFallbackPos[clean] = regCF or npcCF
								end
								if not seen[clean] then
									seen[clean] = true
									table.insert(seaQuestMobs, {name = clean, lvl = lvl})
								end
							end
						end
					end
				end
			end
		end

		table.sort(seaQuestMobs, function(a, b)
			if a.lvl ~= b.lvl then return a.lvl < b.lvl end
			return a.name < b.name
		end)

		local result = {}
		for _, entry in ipairs(seaQuestMobs) do
			table.insert(result, entry.name)
		end

		-- Live EnemySpawns, Workspace.Enemies & ReplicatedStorage non-boss mobs in THIS Sea only
		local wo = Workspace:FindFirstChild("_WorldOrigin")
		local es = wo and wo:FindFirstChild("EnemySpawns")
		if es then
			for _, sp in ipairs(es:GetChildren()) do
				if not sp.Name:find("%[Boss%]") and not sp.Name:find("%[Raid Boss%]") then
					local clean = Others.cleanEntityName(sp.Name)
					if not seen[clean] and not bossKnown[clean] and not isDummyOrCutsceneEntity(clean, seaNum) then
						seen[clean] = true
						table.insert(result, clean)
					end
				end
			end
		end

		for _, folder in ipairs({Workspace:FindFirstChild("Enemies"), ReplicatedStorage}) do
			if folder then
				for _, ch in ipairs(folder:GetChildren()) do
					if ch:IsA("Model") and ch:FindFirstChildOfClass("Humanoid") then
						local isB = (ch:GetAttribute("IsBoss") == true) or ch.Name:find("%[Boss%]") or ch.Name:find("%[Raid Boss%]")
						local clean = Others.cleanEntityName(ch.Name)
						if not isB and not seen[clean] and not bossKnown[clean] and not isDummyOrCutsceneEntity(clean, seaNum) then
							seen[clean] = true
							table.insert(result, clean)
						end
					end
				end
			end
		end

		for _, extra in ipairs(SEA_EXTRA_MOBS[seaNum] or {}) do
			if not seen[extra] and not bossKnown[extra] then
				seen[extra] = true
				table.insert(result, extra)
			end
		end

		return result
	end

	function Others.refreshMobsUI()
		local seaNum = getCurrentSeaNumber()
		local mobs = Others.collectAllPossibleMobs()
		local validSet = {}
		for _, m in ipairs(mobs) do
			validSet[m] = true
		end
		if type(S.selectedKillMobs) == "table" then
			for k in pairs(S.selectedKillMobs) do
				if not validSet[k] then
					S.selectedKillMobs[k] = nil
				end
			end
		end
		if Others.uiMobMultiSelector and Others.uiMobMultiSelector.SetOptions then
			Others.uiMobMultiSelector.SetOptions(mobs)
		end
		if Others.uiRefreshMobsBtn and Others.uiRefreshMobsBtn.SetSubtitle then
			Others.uiRefreshMobsBtn.SetSubtitle(string.format("Sea %d detectado: %d mobs de este Sea disponibles", seaNum, #mobs))
		end
		return mobs
	end

	-- Scans & verifies LIVE which Bosses are currently spawned/active in Workspace.Enemies or ReplicatedStorage
	function Others.scanBossesStatus()
		local seaNum = getCurrentSeaNumber()
		local npcPositions = getSeaQuestNPCPositions()
		local seenBoss = {}
		local orderedBosses = {}
		local bossLevels = {}

		local function registerBoss(clean, lvl)
			if clean == "" or isDummyOrCutsceneEntity(clean, seaNum) then return end
			if not seenBoss[clean] then
				seenBoss[clean] = true
				bossLevels[clean] = lvl or bossLevels[clean] or 9999
				table.insert(orderedBosses, clean)
			elseif lvl and lvl < (bossLevels[clean] or 9999) then
				bossLevels[clean] = lvl
			end
		end

		-- 1) Quest Bosses in current Sea (from QuestsModule + GuideModule)
		if QuestsModule then
			for qGroup, qList in pairs(QuestsModule) do
				local npcCF = npcPositions[qGroup]
				if npcCF then
					for qIdx, qData in ipairs(qList) do
						local lvl = tonumber(qData.LevelReq) or 0
						if qData.Task then
							for mobName, cnt in pairs(qData.Task) do
								if cnt == 1 then
									local clean = Others.cleanEntityName(mobName)
									registerBoss(clean, lvl)
									Others.bossQuestInfo[clean] = {
										questGroup = qGroup,
										questIndex = qIdx,
										levelReq = lvl,
										npcCFrame = npcCF,
									}
								end
							end
						end
					end
				end
			end
		end

		-- 2) Default Sea Bosses & Raid Bosses
		for idx, bName in ipairs(SEA_BOSS_DEFAULTS[seaNum] or SEA_BOSS_DEFAULTS[2]) do
			registerBoss(bName, 5000 + idx)
		end
		if seaNum == 3 and not seenBoss["Hydra Leader"] and not seenBoss["Island Empress"] then
			registerBoss("Hydra Leader", 1675)
		end

		-- 3) Any Boss spawns in _WorldOrigin.EnemySpawns
		local wo = Workspace:FindFirstChild("_WorldOrigin")
		local es = wo and wo:FindFirstChild("EnemySpawns")
		if es then
			for _, sp in ipairs(es:GetChildren()) do
				if sp.Name:find("%[Boss%]") or sp.Name:find("%[Raid Boss%]") then
					local clean = Others.cleanEntityName(sp.Name)
					registerBoss(clean, 8000)
					local cf = sp:IsA("BasePart") and sp.CFrame or (sp:IsA("Model") and sp:GetPivot())
					if cf then
						addCachedSpawn(clean, cf)
					end
				end
			end
		end

		-- 4) LIVE VERIFICATION: Check Workspace.Enemies & ReplicatedStorage right now!
		local activeMap = {}
		local enemiesFolder = Workspace:FindFirstChild("Enemies")
		if enemiesFolder then
			for _, en in ipairs(enemiesFolder:GetChildren()) do
				if en:IsA("Model") then
					local h = en:FindFirstChildOfClass("Humanoid")
					if h and h.Health > 0 then
						local clean = Others.cleanEntityName(en.Name)
						local isB = seenBoss[clean]
							or (en:GetAttribute("IsBoss") == true)
							or en.Name:find("%[Boss%]")
							or en.Name:find("%[Raid Boss%]")
						if isB and not isDummyOrCutsceneEntity(clean, seaNum) then
							registerBoss(clean, tonumber(en:GetAttribute("Level")) or 8500)
							activeMap[clean] = {live = en, rep = nil}
						end
					end
				end
			end
		end

		for _, ch in ipairs(ReplicatedStorage:GetChildren()) do
			if ch:IsA("Model") then
				local h = ch:FindFirstChildOfClass("Humanoid")
				if h and h.Health > 0 then
					local clean = Others.cleanEntityName(ch.Name)
					local isB = seenBoss[clean]
						or (ch:GetAttribute("IsBoss") == true)
						or ch.Name:find("%[Boss%]")
						or ch.Name:find("%[Raid Boss%]")
					if isB and not isDummyOrCutsceneEntity(clean, seaNum) then
						registerBoss(clean, tonumber(ch:GetAttribute("Level")) or 8500)
						if not activeMap[clean] then
							activeMap[clean] = {live = nil, rep = ch}
						end
					end
				end
			end
		end

		table.sort(orderedBosses, function(a, b)
			local actA = (activeMap[a] ~= nil)
			local actB = (activeMap[b] ~= nil)
			if actA ~= actB then
				return actA
			end
			local lvA = bossLevels[a] or 9999
			local lvB = bossLevels[b] or 9999
			if lvA ~= lvB then
				return lvA < lvB
			end
			return a < b
		end)

		Others.allBossNames = orderedBosses

		local formattedList = {}
		local activeNames = {}
		local currentSelectedFormatted = nil
		local curBossClean = Others.cleanEntityName(S.selectedBoss)

		if curBossClean == "" or curBossClean == "None" or not seenBoss[curBossClean] then
			curBossClean = orderedBosses[1] or "Diamond"
			S.selectedBoss = curBossClean
		end

		for _, clean in ipairs(orderedBosses) do
			local isAct = (activeMap[clean] ~= nil)
			local label = isAct
				and ("🟢 " .. clean .. " [ACTIVO]")
				or ("🔴 " .. clean .. " [Inactivo]")
			table.insert(formattedList, label)
			if isAct then
				table.insert(activeNames, clean)
			end
			if clean == curBossClean then
				currentSelectedFormatted = label
			end
		end

		local summary
		if #activeNames == 0 then
			summary = string.format("🔴 0/%d Bosses activos en este servidor", #orderedBosses)
		elseif #activeNames <= 3 then
			summary = string.format("🟢 Activos ahora (%d/%d): %s", #activeNames, #orderedBosses, table.concat(activeNames, ", "))
		else
			summary = string.format(
				"🟢 Activos ahora (%d/%d): %s, %s, %s (+%d más)",
				#activeNames,
				#orderedBosses,
				activeNames[1],
				activeNames[2],
				activeNames[3],
				#activeNames - 3
			)
		end

		return formattedList, currentSelectedFormatted, activeMap, activeNames, summary
	end

	function Others.refreshBossUI(isAutoBackground)
		if isAutoBackground and Others.uiBossSelector and Others.uiBossSelector.IsOpen and Others.uiBossSelector.IsOpen() then
			return
		end
		local formattedList, selectedFormatted, activeMap, activeNames, summary = Others.scanBossesStatus()
		if Others.uiBossSelector and Others.uiBossSelector.SetOptions then
			Others.uiBossSelector.SetOptions(formattedList, selectedFormatted)
		end
		if Others.uiRefreshBossBtn and Others.uiRefreshBossBtn.SetSubtitle then
			Others.uiRefreshBossBtn.SetSubtitle(summary)
		end
		return activeMap, activeNames, summary
	end

	function Others.findLiveOrRepBoss(cleanTarget)
		if not cleanTarget or cleanTarget == "" then return nil, nil end
		local seaNum = getCurrentSeaNumber()
		local tLow = cleanTarget:lower()

		local enemiesFolder = Workspace:FindFirstChild("Enemies")
		if enemiesFolder then
			for _, en in ipairs(enemiesFolder:GetChildren()) do
				if en:IsA("Model") then
					local h = en:FindFirstChildOfClass("Humanoid")
					local r = en:FindFirstChild("HumanoidRootPart")
					if h and h.Health > 0 and r then
						local clean = Others.cleanEntityName(en.Name)
						if not isDummyOrCutsceneEntity(clean, seaNum) and clean:lower() == tLow then
							return en, nil
						end
					end
				end
			end
		end

		for _, ch in ipairs(ReplicatedStorage:GetChildren()) do
			if ch:IsA("Model") then
				local h = ch:FindFirstChildOfClass("Humanoid")
				if h and h.Health > 0 then
					local clean = Others.cleanEntityName(ch.Name)
					if not isDummyOrCutsceneEntity(clean, seaNum) and clean:lower() == tLow then
						return nil, ch
					end
				end
			end
		end

		return nil, nil
	end

	function Others.getBossTargetPos(cleanName, repModel)
		if repModel then
			local ok, cf = pcall(function() return repModel:GetPivot() end)
			if ok and cf and cf.Position.Magnitude > 5 then
				return cf.Position
			end
			local r = repModel:FindFirstChild("HumanoidRootPart")
			if r and r.Position.Magnitude > 5 then
				return r.Position
			end
		end
		local spawnMap = getCurrentSpawnMap()
		if spawnMap[cleanName] and #spawnMap[cleanName] > 0 then
			return spawnMap[cleanName][1].Position
		end
		if KNOWN_BOSS_POS[cleanName] then
			return KNOWN_BOSS_POS[cleanName]
		end
		local qInfo = Others.bossQuestInfo[cleanName]
		if qInfo and qInfo.npcCFrame then
			return qInfo.npcCFrame.Position
		end
		return nil
	end

	function Others.findNearestActiveBoss(refPos, skipLockedSwan)
		local _, _, activeMap = Others.scanBossesStatus()
		local _, hasFlam = checkPortalUnlockables()
		local bestName, bestLive, bestRep = nil, nil, nil
		local bestScore = math.huge

		for cleanName, entry in pairs(activeMap) do
			local skip = false
			if skipLockedSwan and cleanName == "Don Swan" and not hasFlam then
				skip = true
			end
			if not skip then
				if entry.live then
					local r = entry.live:FindFirstChild("HumanoidRootPart")
					local d = (r and refPos) and (r.Position - refPos).Magnitude or 0
					-- Prioritize already-streamed bosses in Workspace.Enemies
					if (d - 50000) < bestScore then
						bestScore = d - 50000
						bestName = cleanName
						bestLive = entry.live
						bestRep = nil
					end
				elseif entry.rep then
					local pos = Others.getBossTargetPos(cleanName, entry.rep)
					local d = (pos and refPos) and (pos - refPos).Magnitude or 25000
					if d < bestScore then
						bestScore = d
						bestName = cleanName
						bestLive = nil
						bestRep = entry.rep
					end
				end
			end
		end

		return bestName, bestLive, bestRep
	end

	-- Optional helper: grabs the Boss Quest if Auto Accept Quest is ON and player meets LevelReq
	function Others.ensureBossQuestIfEligible(cleanBossName, hrp)
		if not S.autoQuest or not CommF_ then return false end
		local qInfo = Others.bossQuestInfo[cleanBossName]
		if not qInfo or not qInfo.questGroup then return false end

		local lvlObj = LocalPlayer:FindFirstChild("Data") and LocalPlayer.Data:FindFirstChild("Level")
		local myLvl = lvlObj and lvlObj.Value or 1
		if myLvl < (qInfo.levelReq or 0) then
			return false
		end

		local hasQuest, matchesTarget, activeDesc = getActiveQuestStatus(qInfo.questGroup, cleanBossName)
		if hasQuest and matchesTarget then
			return false
		end
		if hasQuest and not matchesTarget then
			setStatus(string.format("👑 Abandonando misión anterior (%s) para Boss %s...", tostring(activeDesc), cleanBossName))
			abandonCurrentQuestNonBlocking()
			return true
		end

		local npcTarget = qInfo.npcCFrame * CFrame.new(0, 4, 3)
		setStatus(string.format("👑 Tomando misión del Boss: %s (Lv. %d)...", cleanBossName, qInfo.levelReq))
		local reached = moveToCFrame(npcTarget)
		if reached or (hrp.Position - qInfo.npcCFrame.Position).Magnitude <= 30 then
			requestStartQuestNonBlocking(qInfo.questGroup, qInfo.questIndex)
		end
		return true
	end

	function Others.stepBossFarm(hrp)
		-- Mode 1: Auto Boss (Selected Boss)
		if S.bossFarm then
			local targetName = Others.cleanEntityName(S.selectedBoss)
			local liveBoss, repBoss = Others.findLiveOrRepBoss(targetName)

			if liveBoss or repBoss then
				if Others.ensureBossQuestIfEligible(targetName, hrp) then
					return true
				end
				if liveBoss then
					engageEnemy(liveBoss, nil, "👑 Boss: " .. targetName)
				else
					local pos = Others.getBossTargetPos(targetName, repBoss)
					if pos then
						setStatus(string.format("🟢 %s [ACTIVO]: Volando hacia su ubicación [%dm]...", targetName, math.floor((hrp.Position - pos).Magnitude)))
						moveToCFrame(CFrame.new(pos + Vector3.new(0, 20, 0)))
					else
						setStatus("🟢 " .. targetName .. " [ACTIVO]: Buscando isla...")
					end
				end
				return true
			end

			-- Selected Boss is INACTIVE right now:
			if not S.allBossFarm then
				if S.hopFindBoss then
					if os.clock() - S.spawnedAtClock >= 5.5 then
						clearFarmMover()
						setStatus("🔴 " .. targetName .. " Inactivo en este servidor -> Hop Server Find Boss...")
						executeServerHop(S.serverHopMode)
					else
						setStatus("🔍 Verificando estado de " .. targetName .. " antes de Server Hop...")
					end
					return true
				end
				if S.levelFarm then
					return false -- Let Level Farm run while waiting for Boss respawn
				end
				setStatus("🔴 " .. targetName .. " [Inactivo] — Esperando aparición (o activa Hop Server Find Boss)...")
				return true
			end
		end

		-- Mode 2: Matar Todos los Bosses (Auto All Bosses)
		if S.allBossFarm then
			local bName, liveBoss, repBoss = Others.findNearestActiveBoss(hrp.Position, true)
			if bName and (liveBoss or repBoss) then
				if Others.ensureBossQuestIfEligible(bName, hrp) then
					return true
				end
				if liveBoss then
					engageEnemy(liveBoss, nil, "👑 All Bosses: " .. bName)
				else
					local pos = Others.getBossTargetPos(bName, repBoss)
					if pos then
						setStatus(string.format("🟢 All Bosses -> %s [ACTIVO] [%dm]...", bName, math.floor((hrp.Position - pos).Magnitude)))
						moveToCFrame(CFrame.new(pos + Vector3.new(0, 20, 0)))
					end
				end
				return true
			end

			-- 0 Active Bosses remaining in server:
			if S.hopFindBoss then
				if os.clock() - S.spawnedAtClock >= 5.5 then
					clearFarmMover()
					setStatus("👑 0 Bosses activos restantes -> Hop Server Find Boss...")
					executeServerHop(S.serverHopMode)
				else
					setStatus("🔍 Verificando Bosses activos del servidor antes de Server Hop...")
				end
				return true
			end
			if S.levelFarm then
				return false
			end
			setStatus("✅ Todos los Bosses activos derrotados — Esperando reaparición...")
			return true
		end

		-- Mode 3: Only Hop Server Find Boss enabled (finds server with selected boss active)
		if S.hopFindBoss then
			local targetName = Others.cleanEntityName(S.selectedBoss)
			local liveBoss, repBoss = Others.findLiveOrRepBoss(targetName)
			if liveBoss or repBoss then
				clearFarmMover()
				setStatus("🟢 ¡" .. targetName .. " ENCONTRADO Y ACTIVO en este servidor!")
			elseif os.clock() - S.spawnedAtClock >= 5.5 then
				clearFarmMover()
				setStatus("🔴 " .. targetName .. " Inactivo -> Hop Server Find Boss...")
				executeServerHop(S.serverHopMode)
			else
				setStatus("🔍 Verificando si " .. targetName .. " está activo en este servidor...")
			end
			return true
		end

		return false
	end

	-- Auto Kill Mob (Selected Mobs from All Possible Mobs)
	function Others.stepAutoKillMob(hrp)
		local targetSet = {}
		local selectedList = {}
		for mobName, enabled in pairs(S.selectedKillMobs or {}) do
			if enabled then
				local clean = Others.cleanEntityName(mobName)
				targetSet[clean] = true
				table.insert(selectedList, clean)
			end
		end

		if #selectedList == 0 then
			clearFarmMover()
			setStatus("⚠️ Auto Kill Mob: Selecciona al menos 1 mob en 'Seleccionar Mobs'")
			return true
		end

		table.sort(selectedList)
		local labelShort = (#selectedList == 1) and selectedList[1] or string.format("%s (+%d)", selectedList[1], #selectedList - 1)

		-- 1) Alive in Workspace.Enemies
		local liveMob = findAliveEnemyFromSet(targetSet)
		if liveMob then
			engageEnemy(liveMob, targetSet, "👾 Kill Mob: " .. labelShort)
			return true
		end

		-- 2) Alive unstreamed in ReplicatedStorage
		local bestRepPos = nil
		local bestRepDist = math.huge
		local bestRepName = nil
		for _, ch in ipairs(ReplicatedStorage:GetChildren()) do
			if ch:IsA("Model") then
				local h = ch:FindFirstChildOfClass("Humanoid")
				if h and h.Health > 0 then
					local clean = Others.cleanEntityName(ch.Name)
					if targetSet[clean] then
						local ok, cf = pcall(function() return ch:GetPivot() end)
						if ok and cf and cf.Position.Magnitude > 5 then
							local d = (cf.Position - hrp.Position).Magnitude
							if d < bestRepDist then
								bestRepDist = d
								bestRepPos = cf.Position
								bestRepName = clean
							end
						end
					end
				end
			end
		end
		if bestRepPos then
			setStatus(string.format("👾 Auto Kill Mob: Volando hacia %s [%dm]...", tostring(bestRepName), math.floor(bestRepDist)))
			moveToCFrame(CFrame.new(bestRepPos + Vector3.new(0, 20, 0)))
			return true
		end

		-- 3) Patrol known spawns / quest regions for selected mobs
		local spawns = collectSpawnsForSet(targetSet)
		if #spawns == 0 then
			for _, mName in ipairs(selectedList) do
				local fb = Others.mobFallbackPos[mName]
				if fb then
					table.insert(spawns, fb)
				end
			end
		end

		if #spawns > 0 then
			setStatus("👾 Auto Kill Mob: Patrullando spawns de " .. labelShort .. "...")
			patrolAroundSpawns("AutoKillMob_" .. table.concat(selectedList, "|"), spawns)
		else
			setStatus("⚠️ Auto Kill Mob: Los mobs seleccionados pertenecen a otro Sea o no tienen spawn aquí")
		end
		return true
	end

	-- =========================================================================
	-- 8) DEVIL FRUIT RAIDS (ALL RAIDS, LOW BELI CHIP, HOP RAID & AUTO AWAKE)
	-- =========================================================================
	Others.wasInRaid = false
	Others.raidEnteredAt = 0
	Others.raidIslandIdx = 1
	Others.islandClearClock = 0
	Others.postRaidAwakenUntil = 0
	Others.lastAwakenTry = 0
	Others.lastLowFruitPull = 0
	Others.lastRaidChipBuy = 0
	Others.lastRaidBtnClick = 0
	Others.summonArriveClock = 0
	Others.chipFailCount = 0

	function Others.tryAutoAwakeFruit(forceReport)
		if not CommF_ then return false end
		local awakenedAny = false
		pcall(function()
			local checkRes = CommF_:InvokeServer("Awakener", "Check")
			if checkRes ~= nil and checkRes ~= false then
				local awkRes = CommF_:InvokeServer("Awakener", "Awaken")
				if awkRes ~= nil and awkRes ~= false then
					awakenedAny = true
					setStatus("✨ ¡Habilidad de Fruta Despertada (Auto Awake Fruit)!")
				end
			end
		end)
		if forceReport and not awakenedAny then
			setStatus("✨ Auto Awake Fruit activo: Despertará tu fruta al completar la Raid")
		end
		return awakenedAny
	end

	function Others.isInAwakeningRoom(hrp)
		if not hrp then return false end
		local wo = Workspace:FindFirstChild("_WorldOrigin")
		local locs = wo and wo:FindFirstChild("Locations")
		if locs then
			for _, l in ipairs(locs:GetChildren()) do
				if l:IsA("BasePart") and l.Name:lower():find("awakening") and (l.Position - hrp.Position).Magnitude < 500 then
					return true
				end
			end
		end
		for _, folder in ipairs({Workspace:FindFirstChild("NPCs"), ReplicatedStorage:FindFirstChild("NPCs")}) do
			local npc = folder and folder:FindFirstChild("Mysterious Entity")
			if npc then
				local ok, cf = pcall(function() return npc:GetPivot() end)
				if ok and cf and (cf.Position - hrp.Position).Magnitude < 350 then
					return true
				end
			end
		end
		return false
	end

	function Others.findRaidIslandPart(islandNum, refPos)
		local wo = Workspace:FindFirstChild("_WorldOrigin")
		local locs = wo and wo:FindFirstChild("Locations")
		if not locs or not refPos then return nil, math.huge end
		local targetName = "Island " .. tostring(islandNum)
		local bestPart = nil
		local bestDist = 4800
		for _, l in ipairs(locs:GetChildren()) do
			if l:IsA("BasePart") and l.Name == targetName then
				local d = (l.Position - refPos).Magnitude
				if d < bestDist then
					bestDist = d
					bestPart = l
				end
			end
		end
		return bestPart, bestDist
	end

	function Others.isPlayerInRaid(hrp)
		local pg = LocalPlayer:FindFirstChild("PlayerGui")
		local main = pg and pg:FindFirstChild("Main")
		if main then
			local thl = main:FindFirstChild("TopHUDList")
			local rt = thl and thl:FindFirstChild("RaidTimer")
			if rt and rt:IsA("GuiObject") and rt.Visible and tostring(rt.Text or ""):find("%d") then
				return true
			end
			local tmr = main:FindFirstChild("Timer")
			if tmr and tmr:IsA("GuiObject") and tmr.Visible and tostring(tmr.Text or ""):find("%d") then
				return true
			end
		end
		if hrp then
			for i = 1, 5 do
				local part, dist = Others.findRaidIslandPart(i, hrp.Position)
				if part and dist < 2400 then
					return true
				end
			end
		end
		return false
	end

	function Others.stepRaidFarm(hrp, hum)
		local inRaid = Others.isPlayerInRaid(hrp)

		-- 1) ACTIVE RAID EXECUTION (ISLAND 1 -> ISLAND 5 + KILL ALL MOBS)
		if inRaid then
			if not Others.wasInRaid then
				Others.wasInRaid = true
				Others.raidEnteredAt = os.clock()
				Others.raidIslandIdx = 1
				Others.islandClearClock = 0
				Others.summonArriveClock = 0
				Others.chipFailCount = 0
			end

			pcall(function()
				if sethiddenproperty then
					sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
				end
			end)

			local mob = findAliveEnemyFromSet(nil, 2600)
			if mob then
				local mHrp = mob:FindFirstChild("HumanoidRootPart")
				if mHrp then
					for k = 1, 5 do
						local iPart, iDist = Others.findRaidIslandPart(k, mHrp.Position)
						if iPart and iDist < 900 and k > Others.raidIslandIdx then
							Others.raidIslandIdx = k
						end
					end
				end
				Others.islandClearClock = 0
				engageEnemy(mob, nil, string.format("⚡ Raid %s [Isla %d/5]", tostring(S.selectedRaid), Others.raidIslandIdx))
				return true
			end

			-- No alive mobs nearby -> Advance / hover over current Raid Island!
			if Others.islandClearClock > 0
				and (os.clock() - Others.islandClearClock >= 3.8)
				and (os.clock() - Others.raidEnteredAt >= 5.5)
				and Others.raidIslandIdx < 5
			then
				local nextPart = Others.findRaidIslandPart(Others.raidIslandIdx + 1, hrp.Position)
				if nextPart then
					Others.raidIslandIdx = Others.raidIslandIdx + 1
					Others.islandClearClock = 0
				end
			end

			local islPart = Others.findRaidIslandPart(Others.raidIslandIdx, hrp.Position)
			if not islPart then
				for k = 5, 1, -1 do
					local p = Others.findRaidIslandPart(k, hrp.Position)
					if p then
						Others.raidIslandIdx = k
						islPart = p
						break
					end
				end
			end

			if islPart then
				local hoverPos = islPart.Position + Vector3.new(0, 26, 0)
				setStatus(string.format("⚡ Raid %s: Yendo / Esperando oleada en Isla %d/5...", tostring(S.selectedRaid), Others.raidIslandIdx))
				local reached = moveToCFrame(CFrame.new(hoverPos))
				if reached or (hrp.Position - hoverPos).Magnitude <= 65 then
					if Others.islandClearClock == 0 then
						Others.islandClearClock = os.clock()
					end
				end
			else
				setStatus(string.format("⚡ Raid %s activa: Esperando carga de isla...", tostring(S.selectedRaid)))
			end
			return true
		end

		-- 2) POST-RAID AWAKENING ROOM HANDLER
		if Others.wasInRaid then
			Others.wasInRaid = false
			Others.raidEnteredAt = 0
			Others.raidIslandIdx = 1
			Others.islandClearClock = 0
			Others.postRaidAwakenUntil = os.clock() + 5.5
		end

		local inAwkRoom = Others.isInAwakeningRoom(hrp)
		if S.autoAwakeFruit and (os.clock() < Others.postRaidAwakenUntil or inAwkRoom) then
			if os.clock() - Others.lastAwakenTry > 1.5 then
				Others.lastAwakenTry = os.clock()
				Others.tryAutoAwakeFruit(false)
			end
			if S.autoRaid then
				if os.clock() < Others.postRaidAwakenUntil then
					setStatus("✨ Raid completada! Despertando fruta en Awakening Room...")
					return true
				elseif inAwkRoom then
					pcall(function() CommF_:InvokeServer("Awakener", "Teleport") end)
					setStatus("✨ Saliendo de Awakening Room para repetir Raid...")
					return true
				end
			end
		end

		if not S.autoRaid then
			return false
		end

		-- 3) BUY SPECIAL MICROCHIP & START RAID AT RAIDSUMMON2
		local seaNum = getCurrentSeaNumber()
		if seaNum ~= 2 and seaNum ~= 3 then
			setStatus("⚠️ Auto Raid requiere estar en Sea 2 o Sea 3 (Lv. 1100+)")
			return true
		end

		local chipTool = S.hasSpecialMicrochipTool and S.hasSpecialMicrochipTool()
		if not chipTool then
			Others.summonArriveClock = 0

			-- Pull cheapest (< 1M Beli) fruit from Inventory if enabled
			if S.getLowBeliFruit and S.unstoreLowestBeliFruit and (os.clock() - Others.lastLowFruitPull > 2.2) then
				Others.lastLowFruitPull = os.clock()
				S.unstoreLowestBeliFruit()
			end

			if CommF_ and (os.clock() - Others.lastRaidChipBuy > 2.5) then
				Others.lastRaidChipBuy = os.clock()
				pcall(function()
					CommF_:InvokeServer("RaidsNpc", "Select", S.selectedRaid)
				end)
				chipTool = S.hasSpecialMicrochipTool and S.hasSpecialMicrochipTool()
				if chipTool then
					Others.chipFailCount = 0
				else
					Others.chipFailCount = (Others.chipFailCount or 0) + 1
				end
			end

			if not chipTool then
				if (Others.chipFailCount or 0) >= 2 and S.hopServerRaid and (os.clock() - S.spawnedAtClock >= 8.0) then
					clearFarmMover()
					setStatus("⚡ Sin Microchip disponible -> Hop Server Raid...")
					executeServerHop(S.serverHopMode)
					return true
				end
				setStatus(string.format("⚡ Auto Raid [%s]: Comprando Special Microchip%s...", tostring(S.selectedRaid), S.getLowBeliFruit and " (Fruta Low Beli)" or ""))
				return true
			end
		end

		-- Player holds "Special Microchip" -> Go to RaidSummon2 & fire ClickDetector!
		local map = Workspace:FindFirstChild("Map")
		local raidSummon2 = nil
		if seaNum == 2 then
			local ci = map and map:FindFirstChild("CircleIsland")
			raidSummon2 = ci and ci:FindFirstChild("RaidSummon2")
		else
			local bc = map and map:FindFirstChild("Boat Castle")
			raidSummon2 = bc and bc:FindFirstChild("RaidSummon2")
		end

		local btnMain = raidSummon2 and raidSummon2:FindFirstChild("Button") and raidSummon2.Button:FindFirstChild("Main")
		local cd = btnMain and btnMain:FindFirstChildOfClass("ClickDetector")
		local podPart = raidSummon2 and raidSummon2:FindFirstChild("Raid1") and raidSummon2.Raid1:FindFirstChild("Color")
		local btnPos = (btnMain and btnMain:IsA("BasePart") and btnMain.Position)
			or ((seaNum == 2) and Vector3.new(-6528.17, 306.51, -4670.70) or Vector3.new(-5017.5, 314.8, -2825.4))

		setStatus(string.format("⚡ Auto Raid [%s]: Iniciando Raid en cápsula...", tostring(S.selectedRaid)))
		local targetStandPos = btnPos + Vector3.new(0, 3, 0)
		if Others.summonArriveClock > 0 and (os.clock() - Others.summonArriveClock > 4.5) and podPart and podPart:IsA("BasePart") then
			targetStandPos = podPart.Position + Vector3.new(0, 3, 0)
		end

		local reached = moveToCFrame(CFrame.new(targetStandPos))
		if reached or (hrp.Position - btnPos).Magnitude <= 28 then
			if Others.summonArriveClock == 0 then
				Others.summonArriveClock = os.clock()
			end
			pcall(function() hum:UnequipTools() end)
			if cd and fireclickdetector and (os.clock() - Others.lastRaidBtnClick > 1.4) then
				Others.lastRaidBtnClick = os.clock()
				pcall(function() fireclickdetector(cd) end)
			end
			if S.hopServerRaid and (os.clock() - Others.summonArriveClock > 15.0) and (os.clock() - S.spawnedAtClock >= 10.0) then
				clearFarmMover()
				setStatus("⚡ Cápsulas de Raid ocupadas -> Hop Server Raid...")
				executeServerHop(S.serverHopMode)
				return true
			end
		end
		return true
	end

	-- =========================================================================
	-- 9) SEA EVENTS & KITSUNE ISLAND SUITE (ZONES 1-6, 10KM RETURN, BOAT RESET, FRUIT M1 & EMBERS)
	-- =========================================================================
	Others.lastBoatBuyClock = 0
	Others.boatBuyFails = 0
	Others.hadActiveSeaBoat = false
	Others.returningFrom10km = false
	Others.lastBoatResetClock = 0
	Others.seaPatrolIdx = 1
	Others.lastSeaPatrolSwitch = 0
	Others.kitSpawnPatrolIdx = 1
	Others.lastKitPatrolSwitch = 0
	Others.seaWeaponIdx = 1
	Others.lastSeaWeaponSwitch = 0
	Others.seaSkillIdx = 1
	Others.lastSeaSkillCast = 0
	Others.lastStatueTouch = 0
	Others.lastShrinePray = 0
	Others.leviSegmentIdx = 1
	Others.lastLeviSegSwitch = 0
	Others.lastLeviGateOpen = 0
	Others.lastHarpoonShot = 0
	Others.leviCrewDeparted = false
	Others.spyBribeDone = false
	Others.spyBusy = false
	Others.lastSpyCheck = 0
	Others.frozenGateArriveClock = 0
	Others.cachedInvAzureEmbers = 0
	Others.lastEmberInvPoll = 0
	Others.emberInvPolling = false
	Others.sessionSoulEmbers = 0
	Others.lastTouchedEmberObj = nil
	Others.lastTouchedEmberClock = 0
	Others.blueMoonTimeLeft = nil
	Others.lastBlueMoonTickClock = 0
	Others.wasBlueMoon = false

	-- Listen to Blue Moon countdown timer ticks if server broadcasts them
	task.spawn(function()
		pcall(function()
			local net = ReplicatedStorage:WaitForChild("Modules", 10)
				and ReplicatedStorage.Modules:WaitForChild("Net", 10)
			local bmTick = net and net:FindFirstChild("RE/BlueMoonTimerTick")
			if bmTick and bmTick:IsA("RemoteEvent") then
				connect(bmTick.OnClientEvent, function(a, b)
					local sec = tonumber(a) or tonumber(b)
					if sec then
						Others.blueMoonTimeLeft = sec
						Others.lastBlueMoonTickClock = os.clock()
					end
				end)
			end
		end)
	end)

	local SEA_WEAPON_ORDER = {"Blox Fruit", "Melee", "Sword", "Gun"}

	local SEA3_DOCK_ORIGIN = Vector3.new(-16917.2, 28, 515.4) -- Tiki Outpost Boat Dealer
	local SEA2_DOCK_ORIGIN = Vector3.new(-2818.8, 28, -9428.7) -- Sea 2 Open Ocean Dock

	-- Real Danger Zone 1..6 coordinates spanning 1.8 km -> 9.5 km from Tiki Outpost (10 km = -26917)
	local SEA3_ZONE_CENTERS = {
		[1] = Vector3.new(-18700, 28, 500),
		[2] = Vector3.new(-20300, 28, 500),
		[3] = Vector3.new(-21900, 28, 500),
		[4] = Vector3.new(-23500, 28, 500),
		[5] = Vector3.new(-25100, 28, 500),
		[6] = Vector3.new(-26400, 28, 500),
	}

	local SEA2_ZONE_CENTERS = {
		[1] = Vector3.new(-4400, 28, -10250),
		[2] = Vector3.new(-5800, 28, -11000),
		[3] = Vector3.new(-7200, 28, -11750),
		[4] = Vector3.new(-8600, 28, -12500),
		[5] = Vector3.new(-10000, 28, -13250),
		[6] = Vector3.new(-11200, 28, -13900),
	}

	function Others.resolveBoatKey(boatChoice)
		local isMarine = (LocalPlayer.Team and LocalPlayer.Team.Name == "Marines")
		if boatChoice == "Grand Brigade" then
			return isMarine and "MarineGrandBrigade" or "PirateGrandBrigade"
		elseif boatChoice == "Brigade" then
			return isMarine and "MarineBrigade" or "PirateBrigade"
		elseif boatChoice == "Sloop" then
			return isMarine and "MarineSloop" or "PirateSloop"
		end
		return tostring(boatChoice or "Dinghy")
	end

	function Others.findMyBoat()
		local boatsFolder = Workspace:FindFirstChild("Boats")
		if not boatsFolder then return nil, nil end
		for _, b in ipairs(boatsFolder:GetChildren()) do
			if b:IsA("Model") then
				local owner = b:FindFirstChild("Owner")
				local isMine = owner and (owner.Value == LocalPlayer or tostring(owner.Value) == LocalPlayer.Name)
				if not isMine and b:GetAttribute("Owner") then
					local attr = tostring(b:GetAttribute("Owner"))
					isMine = (attr == LocalPlayer.Name or attr == tostring(LocalPlayer.UserId))
				end
				if isMine then
					local hVal = b:FindFirstChild("Health")
					local bHum = b:FindFirstChildOfClass("Humanoid")
					local alive = true
					if hVal and hVal:IsA("ValueBase") and tonumber(hVal.Value) ~= nil then
						alive = (tonumber(hVal.Value) > 0)
					elseif bHum then
						alive = (bHum.Health > 0)
					end
					local seat = b:FindFirstChildOfClass("VehicleSeat") or b:FindFirstChild("VehicleSeat", true)
					if alive and seat then
						return b, seat
					end
				end
			end
		end
		return nil, nil
	end

	function Others.cleanupBoatMovers()
		local boatsFolder = Workspace:FindFirstChild("Boats")
		if not boatsFolder then return end
		for _, b in ipairs(boatsFolder:GetChildren()) do
			local seat = b:FindFirstChildOfClass("VehicleSeat") or b:FindFirstChild("VehicleSeat", true)
			if seat then
				local bv = seat:FindFirstChild("SwitchHubBoatBV")
				if bv then bv:Destroy() end
				local bg = seat:FindFirstChild("SwitchHubBoatBG")
				if bg then bg:Destroy() end
			end
		end
	end
	S.cleanupBoatMovers = Others.cleanupBoatMovers

	function Others.parkBoatSafely(boat, seat)
		if not boat or not seat then return end
		pcall(function()
			local bv = seat:FindFirstChild("SwitchHubBoatBV")
			if not bv then
				bv = Instance.new("BodyVelocity")
				bv.Name = "SwitchHubBoatBV"
				bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
				bv.Parent = seat
			end
			bv.Velocity = Vector3.zero
			if S.seaSafeBoatFly and seat.Position.Y < 30 then
				boat:PivotTo(CFrame.new(seat.Position.X, 32, seat.Position.Z))
			end
		end)
	end

	function Others.checkBoatLostAndReset(myBoat, mySeat, hrp, hum)
		if not S.seaResetOnBoatLost or not Others.hadActiveSeaBoat then
			return false
		end
		local boatMissing = (not myBoat) or (not mySeat)
		local boatTooFar = (mySeat ~= nil) and ((hrp.Position - mySeat.Position).Magnitude > 2200)
		if (boatMissing or boatTooFar) and (os.clock() - Others.lastBoatResetClock > 8.0) then
			Others.hadActiveSeaBoat = false
			Others.returningFrom10km = false
			Others.lastBoatResetClock = os.clock()
			Others.cleanupBoatMovers()
			clearFarmMover()
			setStatus("💀 Barco destruido o perdido detectado -> Reseteando personaje...")
			pcall(function()
				if hum.SeatPart or hum.Sit then
					hum.Sit = false
				end
				hum.Health = 0
			end)
			return true
		end
		return false
	end

	function Others.getBestBoatDealerPos(seaNum, refPos)
		local isLuxury = (S.selectedBoat == "Miracle" or S.selectedBoat == "The Sentinel" or S.selectedBoat == "Sleigh")
		local npcTargets = isLuxury and {"Luxury Boat Dealer", "Boat Dealer"} or {"Boat Dealer", "Marine Boat Dealer"}

		if NPCManagerModule and type(NPCManagerModule.getNPCsByName) == "function" then
			local bestPos = nil
			local bestScore = math.huge
			for _, tName in ipairs(npcTargets) do
				local ok, list = pcall(NPCManagerModule.getNPCsByName, tName)
				if ok and type(list) == "table" then
					for _, obj in ipairs(list) do
						local okM, m = pcall(function() return obj.getModel and obj:getModel() end)
						if okM and m then
							local okP, cf = pcall(function() return m:GetPivot() end)
							if okP and cf then
								local p = cf.Position
								-- In Sea 3, strongly prefer Tiki Outpost Boat Dealer (X < -15000) right at Zone 1 border!
								local score = refPos and (p - refPos).Magnitude or 0
								if seaNum == 3 and p.X < -15000 then
									score = score - 100000
								end
								if score < bestScore then
									bestScore = score
									bestPos = p
								end
							end
						end
					end
				end
			end
			if bestPos then
				return bestPos
			end
		end

		if seaNum == 3 then
			return Vector3.new(-16917.2, 9.1, 515.4) -- Tiki Outpost Boat Dealer
		else
			return Vector3.new(-2818.8, 2.0, -9428.7) -- Sea 2 Open Ocean Dock
		end
	end

	function Others.ensureBoatAndBoard(seaNum, myBoat, mySeat, hrp, hum, labelPrefix)
		-- 1) If we previously sailed out and the boat was destroyed or lost, reset character!
		if Others.checkBoatLostAndReset(myBoat, mySeat, hrp, hum) then
			return false
		end

		-- 2) Buy boat at Boat Dealer if none owned
		if not myBoat or not mySeat then
			Others.hadActiveSeaBoat = false
			Others.returningFrom10km = false
			local dealerPos = Others.getBestBoatDealerPos(seaNum, hrp.Position)
			local d = (hrp.Position - dealerPos).Magnitude
			setStatus(string.format("%s: Yendo al Boat Dealer para comprar %s [%dm]...", labelPrefix, tostring(S.selectedBoat), math.floor(d)))
			local reached = moveToCFrame(CFrame.new(dealerPos + Vector3.new(0, 3, 2)))
			if (reached or d <= 24) and CommF_ and (os.clock() - Others.lastBoatBuyClock > 2.2) then
				Others.lastBoatBuyClock = os.clock()
				local boatKey = Others.resolveBoatKey(S.selectedBoat)
				pcall(function()
					CommF_:InvokeServer("BuyBoat", boatKey)
				end)
				local checkB = Others.findMyBoat()
				if not checkB then
					Others.boatBuyFails = Others.boatBuyFails + 1
					if Others.boatBuyFails >= 2 then
						local fallbackKey = Others.resolveBoatKey("Brigade")
						pcall(function() CommF_:InvokeServer("BuyBoat", fallbackKey) end)
						if not Others.findMyBoat() then
							pcall(function() CommF_:InvokeServer("BuyBoat", "Dinghy") end)
						end
						Others.boatBuyFails = 0
					end
				else
					Others.boatBuyFails = 0
				end
			end
			return false
		end

		-- 3) Board the VehicleSeat
		if hum.SeatPart ~= mySeat then
			local dSeat = (hrp.Position - mySeat.Position).Magnitude
			setStatus(string.format("%s: Subiendo a tu bote (%s) [%dm]...", labelPrefix, tostring(myBoat.Name), math.floor(dSeat)))
			if dSeat > 18 then
				moveToCFrame(mySeat.CFrame + Vector3.new(0, 3, 0))
			else
				clearFarmMover()
				pcall(function()
					hrp.CFrame = mySeat.CFrame + Vector3.new(0, 2, 0)
					mySeat:Sit(hum)
				end)
			end
			return false
		end

		return true
	end

	function Others.driveBoatSeatTo(myBoat, mySeat, wp, hrp, seaNum)
		if S.activeTween then
			pcall(function() S.activeTween:Cancel() end)
			S.activeTween = nil
		end
		if hrp:FindFirstChild("SwitchHubBV") then
			hrp.SwitchHubBV:Destroy()
		end

		if S.seaSafeBoatFly then
			pcall(function()
				for _, p in ipairs(myBoat:GetDescendants()) do
					if p:IsA("BasePart") and p ~= mySeat and p.CanCollide then
						p.CanCollide = false
					end
				end
			end)
		end

		local dockOrigin = (seaNum == 3) and SEA3_DOCK_ORIGIN or SEA2_DOCK_ORIGIN
		local distFromDock = Vector2.new(mySeat.Position.X - dockOrigin.X, mySeat.Position.Z - dockOrigin.Z).Magnitude
		if distFromDock >= 300 then
			Others.hadActiveSeaBoat = true
		end

		local delta = wp - mySeat.Position
		local speed = math.clamp(tonumber(S.seaBoatSpeed) or 220, 100, 350)
		pcall(function()
			local bv = mySeat:FindFirstChild("SwitchHubBoatBV")
			if not bv then
				bv = Instance.new("BodyVelocity")
				bv.Name = "SwitchHubBoatBV"
				bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
				bv.Parent = mySeat
			end
			local bg = mySeat:FindFirstChild("SwitchHubBoatBG")
			if not bg then
				bg = Instance.new("BodyGyro")
				bg.Name = "SwitchHubBoatBG"
				bg.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
				bg.P = 9000
				bg.D = 500
				bg.Parent = mySeat
			end
			if delta.Magnitude > 5 then
				bv.Velocity = delta.Unit * speed
				local flatTarget = Vector3.new(wp.X, mySeat.Position.Y, wp.Z)
				if (flatTarget - mySeat.Position).Magnitude > 2 then
					bg.CFrame = CFrame.lookAt(mySeat.Position, flatTarget)
				end
			else
				bv.Velocity = Vector3.zero
			end
		end)

		return distFromDock, delta.Magnitude
	end

	-- =========================================================================
	-- KITSUNE ISLAND, MOON PHASE & SOUL / AZURE EMBER HELPERS
	-- =========================================================================
	function Others.findKitsuneIslandInfo()
		local map = Workspace:FindFirstChild("Map")
		local kitModel = map and map:FindFirstChild("KitsuneIsland")
		local shrinePos = nil
		local islPos = nil

		if kitModel then
			local shrine = kitModel:FindFirstChild("MoonShrine")
				or kitModel:FindFirstChild("KitsuneStatue", true)
				or kitModel:FindFirstChild("Statue", true)
			if shrine then
				local okS, cfS = pcall(function()
					return shrine:IsA("Model") and shrine:GetPivot() or shrine.CFrame
				end)
				if okS and cfS then
					shrinePos = cfS.Position
				end
			end
			local okI, cfI = pcall(function() return kitModel:GetPivot() end)
			if okI and cfI then
				islPos = cfI.Position
			end
			if not shrinePos then
				shrinePos = islPos
			end
		end

		if not islPos then
			local wo = Workspace:FindFirstChild("_WorldOrigin")
			local locs = wo and wo:FindFirstChild("Locations")
			if locs then
				for _, l in ipairs(locs:GetChildren()) do
					if l:IsA("BasePart") and l.Name:find("Kitsune") then
						islPos = l.Position
						shrinePos = shrinePos or l.Position
						break
					end
				end
			end
		end

		return kitModel, shrinePos, islPos
	end

	function Others.getMoonStatus()
		local lighting = game:GetService("Lighting")
		local moonPhase = tonumber(lighting:GetAttribute("MoonPhase"))
		local isBlueMoon = (lighting:GetAttribute("IsBlueMoon") == true)
		local blueMoonEnded = (lighting:GetAttribute("BlueMoonEnded") == true)
		local ct = tonumber(lighting.ClockTime) or 12.0

		if moonPhase == nil then
			local sky = lighting:FindFirstChildOfClass("Sky")
			local tex = sky and tostring(sky.MoonTextureId or "") or ""
			if tex:find("9709149431") then
				moonPhase = 5
			elseif tex:find("9709149052") then
				moonPhase = 4
			elseif tex:find("9709143733") then
				moonPhase = 3
			end
		end

		-- Blox Fruits ClockTime: 1.0 game hour ≈ 1 real minute (60s); Full Moon night starts at 18.0!
		-- Near Full Moon (~2 min) = MoonPhase 4 at 15.6..18.2 OR MoonPhase 5 active/starting (15.4..24 or 0..4.3)
		local isNearOrFullMoon = isBlueMoon
			or (moonPhase == 5 and (not blueMoonEnded) and (ct >= 15.4 or ct <= 4.3))
			or (moonPhase == 4 and (ct >= 15.6 and ct <= 18.3))

		return moonPhase, isBlueMoon, blueMoonEnded, ct, isNearOrFullMoon
	end

	function Others.pollAzureEmberInventoryCount()
		if Others.emberInvPolling or (os.clock() - Others.lastEmberInvPoll < 1.5) then
			return
		end
		Others.emberInvPolling = true
		Others.lastEmberInvPoll = os.clock()
		task.spawn(function()
			local foundCount = nil
			pcall(function()
				local ru = require(ReplicatedStorage.Controllers.UI.Inventory.RemoteUtil)
				local prom = ru.getTiles()
				local tiles = nil
				if type(prom) == "table" then
					if type(prom.await) == "function" then
						local a, b = prom:await()
						tiles = (type(a) == "table" and a) or (type(b) == "table" and b)
					elseif type(prom._get) == "function" then
						local a, b = prom:_get()
						tiles = (type(a) == "table" and a) or (type(b) == "table" and b)
					end
				end
				if type(tiles) == "table" then
					local total = 0
					for _, tile in pairs(tiles) do
						if type(tile) == "table" and tonumber(tile.ItemId) == 595 then
							total = total + (tonumber(tile.Count or tile.Quantity or tile.Amount) or 1)
						end
					end
					foundCount = total
				end
			end)

			if foundCount == nil and CommF_ then
				pcall(function()
					local inv = CommF_:InvokeServer("getInventory")
					if type(inv) == "table" then
						local total = 0
						for _, item in pairs(inv) do
							if type(item) == "table" and tostring(item.Name or "") == "Azure Ember" then
								total = total + (tonumber(item.Count or item.Quantity) or 1)
							end
						end
						foundCount = total
					end
				end)
			end

			if foundCount ~= nil then
				Others.cachedInvAzureEmbers = foundCount
				-- Sync session counter downward if Azure Embers were just traded away
				if foundCount < Others.sessionSoulEmbers then
					Others.sessionSoulEmbers = foundCount
				end
			end
			Others.emberInvPolling = false
		end)
	end

	function Others.getSoulEmberCount(hrp)
		Others.pollAzureEmberInventoryCount()
		local attachedNear = 0
		if hrp then
			for _, obj in ipairs(Workspace:GetChildren()) do
				if obj.Name == "AttachedAzureEmber" or obj:GetAttribute("IsPlayerEmber") == true then
					local p = (obj:IsA("Model") and obj.PrimaryPart) or (obj:IsA("BasePart") and obj) or obj:FindFirstChildWhichIsA("BasePart")
					if p and (p.Position - hrp.Position).Magnitude <= 45 then
						attachedNear = attachedNear + 1
					end
				end
			end
		end
		-- Check if last touched EmberTemplate disappeared (collected!)
		if Others.lastTouchedEmberObj and not Others.lastTouchedEmberObj.Parent then
			Others.lastTouchedEmberObj = nil
			Others.sessionSoulEmbers = math.min(25, (Others.sessionSoulEmbers or 0) + 1)
			Others.lastEmberInvPoll = 0
			Others.pollAzureEmberInventoryCount()
		end
		local best = math.max(Others.cachedInvAzureEmbers or 0, attachedNear, Others.sessionSoulEmbers or 0)
		return math.clamp(best, 0, 25)
	end

	function Others.findNearestUncollectedSoulEmber(refPos)
		local bestObj, bestPart, bestDist = nil, nil, 2600
		for _, obj in ipairs(Workspace:GetChildren()) do
			-- CRITICAL: Ignore AttachedAzureEmber (IsPlayerEmber == true) orbiting players!
			if (obj.Name == "EmberTemplate" or (obj.Name:find("Ember") and obj.Name ~= "AttachedAzureEmber" and not obj.Name:find("Blaze")))
				and obj:GetAttribute("IsPlayerEmber") ~= true then
				local part = (obj:IsA("Model") and obj.PrimaryPart)
					or (obj:IsA("BasePart") and obj)
					or obj:FindFirstChildWhichIsA("BasePart")
				if part then
					local d = (part.Position - refPos).Magnitude
					if d < bestDist then
						bestDist = d
						bestObj = obj
						bestPart = part
					end
				end
			end
		end
		return bestObj, bestPart, bestDist
	end

	function Others.stepKitsuneSuite(hrp, hum)
		local anyKit = S.tpKitsuneIsland or S.hopNearFullMoon or S.autoSpawnKitsune
			or S.autoSummonSoulEmber or S.autoCollectSoulEmber or S.autoTradeAzureEmber
		if not anyKit then
			return false
		end

		local seaNum = getCurrentSeaNumber()
		if seaNum ~= 3 then
			setStatus("⚠️ Opciones de Kitsune Island requieren estar en Sea 3")
			return true
		end

		local kitModel, shrinePos, islPos = Others.findKitsuneIslandInfo()
		local moonPhase, isBlueMoon, blueMoonEnded, ct, isNearOrFullMoon = Others.getMoonStatus()
		if Others.wasBlueMoon and not isBlueMoon then
			Others.blueMoonTimeLeft = nil
		end
		Others.wasBlueMoon = isBlueMoon

		local myBoat, mySeat = Others.findMyBoat()

		-- =====================================================================
		-- CASE A: KITSUNE ISLAND IS SPAWNED ON THE SERVER!
		-- =====================================================================
		if islPos then
			local targetShrine = shrinePos or islPos
			if myBoat and mySeat then
				Others.parkBoatSafely(myBoat, mySeat)
			end
			if hum.SeatPart then
				hum.Sit = false
			end

			local emberCount = Others.getSoulEmberCount(hrp)
			local limit = math.clamp(tonumber(S.soulEmberLimit) or 25, 0, 25)
			local bmLeft = (Others.lastBlueMoonTickClock > 0 and (os.clock() - Others.lastBlueMoonTickClock < 5.0))
				and Others.blueMoonTimeLeft or nil

			-- 1) Auto Trade Azure Ember when limit is reached (or before Blue Moon expires / ends)
			local shouldTradeNow = S.autoTradeAzureEmber and (emberCount > 0) and (
				(limit == 0)
				or (emberCount >= limit)
				or (isBlueMoon and bmLeft ~= nil and bmLeft <= 18)
				or (not isBlueMoon and blueMoonEnded)
				or (not S.autoCollectSoulEmber and not isBlueMoon)
			)
			if shouldTradeNow then
				local dShrine = (hrp.Position - targetShrine).Magnitude
				setStatus(string.format("🦊 Auto Tradear Azure Ember (%d/%d): Entregando en Kitsune Shrine [%dm]...", emberCount, limit, math.floor(dShrine)))
				local reached = moveToCFrame(CFrame.new(targetShrine + Vector3.new(0, 6, 0)))
				if (reached or dShrine <= 40) and (os.clock() - Others.lastShrinePray > 2.0) then
					Others.lastShrinePray = os.clock()
					pcall(function()
						local prayRF = getNetRemote("RF/KitsuneStatuePray")
						if prayRF then
							prayRF:InvokeServer()
						end
					end)
					Others.sessionSoulEmbers = 0
					Others.cachedInvAzureEmbers = 0
					Others.lastEmberInvPoll = 0
					Others.pollAzureEmberInventoryCount()
					storeAnyFruitsInInventory()
				end
				return true
			end

			-- If Blue Moon already finished and embers were traded, Hop Server if hopNearFullMoon is ON
			if S.hopNearFullMoon and blueMoonEnded and (not isBlueMoon) and emberCount == 0 and (os.clock() - Others.lastShrinePray > 4.5) and (os.clock() - S.spawnedAtClock >= 10.0) then
				Others.cleanupBoatMovers()
				clearFarmMover()
				setStatus("🌕 Kitsune Island finalizada -> Hop Server buscando otra Full Moon (~2 min)...")
				executeServerHop(S.serverHopMode)
				return true
			end

			-- 2) Auto Collect Soul Ember (up to 0..25 Slider Limit)
			if S.autoCollectSoulEmber then
				if limit == 0 or emberCount >= limit then
					moveToCFrame(CFrame.new(targetShrine + Vector3.new(0, 12, 0)))
					setStatus(string.format("🔥 Límite de Soul Embers alcanzado (%d/%d) — En Kitsune Shrine", emberCount, limit))
					return true
				end

				local emberObj, emberPart, emberDist = Others.findNearestUncollectedSoulEmber(hrp.Position)
				if emberPart then
					setStatus(string.format("🔥 Auto Collect Soul Ember (%d/%d): Atrapando llama [%dm]...", emberCount, limit, math.floor(emberDist)))
					local reached = moveToCFrame(emberPart.CFrame)
					if reached or (hrp.Position - emberPart.Position).Magnitude <= 22 then
						hrp.CFrame = emberPart.CFrame
						Others.lastTouchedEmberObj = emberObj
						Others.lastTouchedEmberClock = os.clock()
						if firetouchinterest then
							pcall(function()
								firetouchinterest(hrp, emberPart, 0)
								firetouchinterest(hrp, emberPart, 1)
							end)
						end
						pcall(function()
							local colRE = getNetRemote("RE/CollectBlueEmber")
							if colRE then
								colRE:FireServer()
							end
						end)
					end
					return true
				elseif isBlueMoon then
					moveToCFrame(CFrame.new(targetShrine + Vector3.new(0, 32, 0)))
					setStatus(string.format("🔥 Blue Moon activa (%d/%d Soul Embers) — Esperando siguiente oleada...", emberCount, limit))
					return true
				end
			end

			-- 3) Auto Summon Soul Ember (Touch Kitsune Statue during Full Moon to start Blue Moon)
			if S.autoSummonSoulEmber and (not isBlueMoon) and (not blueMoonEnded) then
				local dShrine = (hrp.Position - targetShrine).Magnitude
				setStatus(string.format("🦊 Auto Summon Soul Ember: Tocando Kitsune Shrine [%dm]...", math.floor(dShrine)))
				local reached = moveToCFrame(CFrame.new(targetShrine + Vector3.new(0, 5, 0)))
				if (reached or dShrine <= 42) and (os.clock() - Others.lastStatueTouch > 1.8) then
					Others.lastStatueTouch = os.clock()
					pcall(function()
						local touchRE = getNetRemote("RE/TouchKitsuneStatue")
						if touchRE then
							touchRE:FireServer()
						end
					end)
					if kitModel and fireproximityprompt then
						for _, d in ipairs(kitModel:GetDescendants()) do
							if d:IsA("ProximityPrompt") then
								pcall(function() fireproximityprompt(d) end)
							end
						end
					end
				end
				return true
			end

			-- 4) Teleport Kitsune Island / Auto Spawn Kitsune Island standby on Shrine
			if S.tpKitsuneIsland or S.autoSpawnKitsune then
				local dShrine = math.floor((hrp.Position - targetShrine).Magnitude)
				setStatus(string.format("🦊 Kitsune Island [%dm] — Soul Embers: %d/%d", dShrine, emberCount, limit))
				moveToCFrame(CFrame.new(targetShrine + Vector3.new(0, 14, 0)))
				return true
			end
		end

		-- =====================================================================
		-- CASE B: KITSUNE ISLAND IS NOT SPAWNED YET
		-- =====================================================================
		-- 1) Hop Server (Next Night / Near Full Moon ~2 min)
		if S.hopNearFullMoon and (not isNearOrFullMoon) then
			if os.clock() - S.spawnedAtClock >= 6.5 then
				Others.cleanupBoatMovers()
				clearFarmMover()
				setStatus(string.format("🌕 Luna %s/5 (Hora %.1f) sin Full Moon cercana (~2 min) -> Hop Server...", tostring(moonPhase or "?"), ct))
				executeServerHop(S.serverHopMode)
			else
				setStatus("🌕 Escaneando fase lunar del servidor antes de Hop Server...")
			end
			return true
		end

		-- 2) Auto Spawn Kitsune Island (Sail Boat across Danger Zone 5 <-> Zone 6 boundary)
		if S.autoSpawnKitsune then
			if not Others.ensureBoatAndBoard(seaNum, myBoat, mySeat, hrp, hum, "🦊 Auto Spawn Kitsune") then
				return true
			end

			local sailY = S.seaSafeBoatFly and 28 or 10
			local kitWaypoints = {
				Vector3.new(-25000, sailY, 500), -- Zone 5 edge
				Vector3.new(-26800, sailY, 500), -- Zone 6 (???) spawn trigger (< 10 km from Tiki!)
			}
			if Others.kitSpawnPatrolIdx > #kitWaypoints then
				Others.kitSpawnPatrolIdx = 1
			end
			local wp = kitWaypoints[Others.kitSpawnPatrolIdx]
			local distFromDock, remDist = Others.driveBoatSeatTo(myBoat, mySeat, wp, hrp, seaNum)
			if remDist <= 65 and (os.clock() - Others.lastKitPatrolSwitch > 1.5) then
				Others.lastKitPatrolSwitch = os.clock()
				Others.kitSpawnPatrolIdx = (Others.kitSpawnPatrolIdx % #kitWaypoints) + 1
			end
			setStatus(string.format("🦊 Auto Spawn Kitsune: Cruzando Zona 5/6 [Luna %s/5 | Hora %.1f | %.1f km]...", tostring(moonPhase or "?"), ct, distFromDock / 1000))
			return true
		end

		-- 3) If Auto Sea Event is ALSO running, let stepSeaEvents sail normally until Kitsune spawns!
		if S.autoSeaEvent then
			return false
		end

		if S.hopNearFullMoon and isNearOrFullMoon then
			setStatus(string.format("🌕 ¡Full Moon / Próxima Noche (~2 min) lista! [Luna %s/5 | Hora %.1f]", tostring(moonPhase or "5"), ct))
			return true
		end

		if S.tpKitsuneIsland then
			setStatus("🦊 Teleport Kitsune Island: Esperando a que aparezca Kitsune Island en el mapa...")
			return true
		end

		return false
	end

	-- =========================================================================
	-- LEVIATHAN SUITE: FROZEN DIMENSION, MULTI-SEGMENTS & HEART DELIVERY (TIKI / HYDRA)
	-- =========================================================================
	function Others.isSeaModelAlive(m)
		if not m then return false end
		local hVal = m:FindFirstChild("Health")
		if hVal and hVal:IsA("ValueBase") and tonumber(hVal.Value) ~= nil then
			return tonumber(hVal.Value) > 0
		end
		local hum = m:FindFirstChildOfClass("Humanoid")
		if hum then
			return hum.Health > 0
		end
		return false
	end

	function Others.getLeviathanModelPart(m)
		if not m then return nil end
		local preferred = m:FindFirstChild("HumanoidRootPart")
			or m:FindFirstChild("RootPart")
			or m:FindFirstChild("Leviathan body")
			or m:FindFirstChild("Body")
			or m:FindFirstChild("Head")
			or m.PrimaryPart
		if preferred and preferred:IsA("BasePart") and preferred.Position.Y > -150 then
			return preferred
		end
		local bestPart = nil
		local bestY = -150
		for _, ch in ipairs(m:GetDescendants()) do
			if ch:IsA("BasePart") and ch.Position.Y > bestY then
				bestY = ch.Position.Y
				bestPart = ch
			end
		end
		return bestPart or preferred
	end

	function Others.findLeviathanHeart()
		for _, container in ipairs({Workspace, Workspace:FindFirstChild("SeaEvents"), Workspace:FindFirstChild("_WorldOrigin")}) do
			if container then
				for _, obj in ipairs(container:GetChildren()) do
					local nm = obj.Name
					if nm == "LeviathanHeart" or nm == "Leviathan Heart" or nm:find("LeviathanHeart") then
						local part = (obj:IsA("BasePart") and obj)
							or (obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChild("Heart") or obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")))
							or obj:FindFirstChildWhichIsA("BasePart")
						if part then
							return obj, part
						end
					end
				end
			end
		end
		return nil, nil
	end

	function Others.scanLeviathanEntities(refPos)
		local segments = {}
		local seen = {}
		local mainBoss, mainPart = nil, nil
		local mainBestDist = math.huge

		for _, folder in ipairs({Workspace:FindFirstChild("SeaBeasts"), Workspace:FindFirstChild("Enemies"), Workspace:FindFirstChild("SeaEvents")}) do
			if folder then
				for _, m in ipairs(folder:GetChildren()) do
					if m:IsA("Model") and not seen[m] and m.Name:find("Leviathan") then
						seen[m] = true
						if Others.isSeaModelAlive(m) then
							local part = Others.getLeviathanModelPart(m)
							if part then
								local d = refPos and (part.Position - refPos).Magnitude or 0
								if d <= 4500 then
									if m.Name:find("Segment") then
										table.insert(segments, {model = m, part = part, dist = d, name = m.Name})
									else
										if d < mainBestDist then
											mainBestDist = d
											mainBoss = m
											mainPart = part
										end
									end
								end
							end
						end
					end
				end
			end
		end

		table.sort(segments, function(a, b)
			if a.name ~= b.name then
				return a.name < b.name
			end
			return a.dist < b.dist
		end)

		return segments, mainBoss, mainPart
	end

	function Others.findFrozenDimension()
		local frozenPos = nil
		local watcherPos = nil

		local wo = Workspace:FindFirstChild("_WorldOrigin")
		local locs = wo and wo:FindFirstChild("Locations")
		if locs then
			for _, l in ipairs(locs:GetChildren()) do
				if l:IsA("BasePart") and l.Name:find("Frozen") then
					frozenPos = l.Position
					break
				end
			end
		end

		local map = Workspace:FindFirstChild("Map")
		local fdModel = map and map:FindFirstChild("FrozenDimension")
		if fdModel then
			local ok, cf = pcall(function() return fdModel:GetPivot() end)
			if ok and cf then
				frozenPos = frozenPos or cf.Position
			end
			local watcher = fdModel:FindFirstChild("Frozen Watcher", true) or fdModel:FindFirstChild("FrozenWatcher", true)
			if watcher then
				local okW, cfW = pcall(function()
					return watcher:IsA("Model") and watcher:GetPivot() or watcher.CFrame
				end)
				if okW and cfW then
					watcherPos = cfW.Position
				end
			end
		end

		if not watcherPos and NPCManagerModule and type(NPCManagerModule.getNPCsByName) == "function" then
			local ok, list = pcall(NPCManagerModule.getNPCsByName, "Frozen Watcher")
			if ok and type(list) == "table" then
				for _, obj in ipairs(list) do
					local okM, m = pcall(function() return obj.getModel and obj:getModel() end)
					if okM and m then
						local okP, cf = pcall(function() return m:GetPivot() end)
						if okP and cf then
							watcherPos = cf.Position
							frozenPos = frozenPos or watcherPos
							break
						end
					end
				end
			end
		end

		return frozenPos, watcherPos
	end

	function Others.getSelectedLeviPlayers()
		local out = {}
		local map = S.selectedLeviPlayers
		if type(map) ~= "table" then return out end
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer then
				local label = (plr.DisplayName and plr.DisplayName ~= "" and plr.DisplayName ~= plr.Name)
					and string.format("%s (@%s)", plr.DisplayName, plr.Name)
					or plr.Name
				if map[label] == true or map[plr.Name] == true then
					table.insert(out, plr)
				end
			end
		end
		return out
	end

	function Others.tryAutoBribeSpy()
		if not S.autoStartLeviathan or Others.spyBribeDone or Others.spyBusy or not CommF_ then
			return
		end
		if os.clock() - Others.lastSpyCheck < 4.5 then
			return
		end
		Others.spyBusy = true
		Others.lastSpyCheck = os.clock()
		task.spawn(function()
			pcall(function()
				local status = CommF_:InvokeServer("InfoLeviathan", "1")
				if status == 5 then
					Others.spyBribeDone = true
				elseif type(status) == "number" and status >= 1 and status <= 4 then
					for _ = 1, 4 do
						local frags = LocalPlayer:FindFirstChild("Data") and LocalPlayer.Data:FindFirstChild("Fragments")
						if not frags or frags.Value < 1500 then
							break
						end
						CommF_:InvokeServer("InfoLeviathan", "2")
						task.wait(0.35)
						local nextSt = CommF_:InvokeServer("InfoLeviathan", "1")
						if nextSt == 5 then
							Others.spyBribeDone = true
							break
						elseif type(nextSt) ~= "number" or nextSt < 1 or nextSt > 4 then
							break
						end
					end
				end
			end)
			Others.spyBusy = false
		end)
	end

	function Others.findSelectedTeamBoat(selectedPlayers)
		local boatsFolder = Workspace:FindFirstChild("Boats")
		if not boatsFolder or #selectedPlayers == 0 then
			return nil, nil, nil
		end

		local selByName = {}
		local selById = {}
		local selByPlr = {}
		for _, plr in ipairs(selectedPlayers) do
			selByName[plr.Name] = plr
			selById[tostring(plr.UserId)] = plr
			selByPlr[plr] = plr
		end

		for _, b in ipairs(boatsFolder:GetChildren()) do
			if b:IsA("Model") and Others.isSeaModelAlive(b) then
				local seat = b:FindFirstChildOfClass("VehicleSeat") or b:FindFirstChild("VehicleSeat", true)
				if seat then
					local matchedPlr = nil
					local ownerVal = b:FindFirstChild("Owner")
					if ownerVal then
						matchedPlr = selByPlr[ownerVal.Value] or selByName[tostring(ownerVal.Value)]
					end
					if not matchedPlr and b:GetAttribute("Owner") then
						local attr = tostring(b:GetAttribute("Owner"))
						matchedPlr = selByName[attr] or selById[attr]
					end
					if not matchedPlr and seat.Occupant and seat.Occupant.Parent then
						local occPlr = Players:GetPlayerFromCharacter(seat.Occupant.Parent)
						if occPlr and selByPlr[occPlr] then
							matchedPlr = occPlr
						end
					end
					if matchedPlr then
						return b, seat, matchedPlr
					end
				end
			end
		end
		return nil, nil, nil
	end

	function Others.boardPassengerSeatOnBoat(boat, vehSeat, hrp, hum, avoidHarpoonSeat)
		if not boat or not vehSeat then return false end
		local curSeat = hum.SeatPart
		if curSeat and curSeat:IsDescendantOf(boat) and curSeat ~= vehSeat then
			local isHarpoonSeat = (curSeat.Parent ~= nil and curSeat.Parent.Name == "Harpoon")
			if not (avoidHarpoonSeat and isHarpoonSeat) then
				clearFarmMover()
				return true
			end
		end

		local regularSeat, regDist = nil, math.huge
		local fallbackSeat, fbDist = nil, math.huge
		for _, inst in ipairs(boat:GetDescendants()) do
			if inst:IsA("Seat") and not inst:IsA("VehicleSeat") and inst.Occupant == nil then
				local isHarpoon = (inst.Parent ~= nil and inst.Parent.Name == "Harpoon")
				local d = (inst.Position - hrp.Position).Magnitude
				if not isHarpoon then
					if d < regDist then
						regDist = d
						regularSeat = inst
					end
				elseif not avoidHarpoonSeat then
					if d < fbDist then
						fbDist = d
						fallbackSeat = inst
					end
				end
			end
		end

		local targetSeat = regularSeat or fallbackSeat
		if targetSeat then
			if curSeat and curSeat ~= targetSeat then
				hum.Sit = false
			end
			local dS = (hrp.Position - targetSeat.Position).Magnitude
			if dS > 18 then
				moveToCFrame(targetSeat.CFrame + Vector3.new(0, 3, 0))
			else
				clearFarmMover()
				pcall(function()
					hrp.CFrame = targetSeat.CFrame + Vector3.new(0, 2, 0)
					targetSeat:Sit(hum)
				end)
			end
			return false
		end

		-- All passenger seats full (e.g. 8-12 crewmates): ride smoothly on the boat deck
		local deckCF = vehSeat.CFrame * CFrame.new(0, 4.5, 3.5)
		if (hrp.Position - deckCF.Position).Magnitude > 22 then
			moveToCFrame(deckCF)
			return false
		else
			clearFarmMover()
			hrp.CFrame = deckCF
			return true
		end
	end

	function Others.getCrewAboardStatus(boat, vehSeat, selectedPlayers)
		local aboardCount = 0
		local missingAll = {}
		local missingNearby = {}
		for _, plr in ipairs(selectedPlayers) do
			local pChar = plr.Character
			local pHum = pChar and pChar:FindFirstChildOfClass("Humanoid")
			local pHrp = pChar and pChar:FindFirstChild("HumanoidRootPart")
			local isAboard = false
			if pHum and pHum.Health > 0 then
				if pHum.SeatPart and pHum.SeatPart:IsDescendantOf(boat) then
					isAboard = true
				elseif pHrp and (pHrp.Position - vehSeat.Position).Magnitude <= 38 then
					isAboard = true
				end
			end
			if isAboard then
				aboardCount = aboardCount + 1
			else
				table.insert(missingAll, plr.DisplayName or plr.Name)
				if pHum and pHum.Health > 0 and pHrp and (pHrp.Position - vehSeat.Position).Magnitude <= 1250 then
					table.insert(missingNearby, plr.DisplayName or plr.Name)
				end
			end
		end
		return aboardCount, missingAll, missingNearby
	end

	function Others.ensureLeviOwnerBoatAndHelm(hrp, hum)
		local myBoat, mySeat = Others.findMyBoat()
		if Others.checkBoatLostAndReset(myBoat, mySeat, hrp, hum) then
			Others.leviCrewDeparted = false
			return nil, nil, false
		end

		if not myBoat or not mySeat then
			Others.hadActiveSeaBoat = false
			Others.leviCrewDeparted = false
			Others.returningFrom10km = false
			local dealerPos = Others.getBestBoatDealerPos(3, hrp.Position)
			local d = (hrp.Position - dealerPos).Magnitude
			local wantBH = (S.selectedBoat == "Beast Hunter") or S.autoDeliverLeviHeart
			local boatLabel = wantBH and "Beast Hunter" or tostring(S.selectedBoat)
			setStatus(string.format("⛵ Dueño Auto Bote: Yendo al Boat Dealer para comprar %s [%dm]...", boatLabel, math.floor(d)))
			local reached = moveToCFrame(CFrame.new(dealerPos + Vector3.new(0, 3, 2)))
			if (reached or d <= 24) and CommF_ and (os.clock() - Others.lastBoatBuyClock > 2.2) then
				Others.lastBoatBuyClock = os.clock()
				if wantBH then
					pcall(function() CommF_:InvokeServer("BuyBoat", "Beast Hunter") end)
				end
				if not Others.findMyBoat() then
					local boatKey = Others.resolveBoatKey(S.selectedBoat)
					pcall(function() CommF_:InvokeServer("BuyBoat", boatKey) end)
				end
				if not Others.findMyBoat() then
					Others.boatBuyFails = Others.boatBuyFails + 1
					if Others.boatBuyFails >= 2 then
						pcall(function() CommF_:InvokeServer("BuyBoat", Others.resolveBoatKey("Brigade")) end)
						if not Others.findMyBoat() then
							pcall(function() CommF_:InvokeServer("BuyBoat", "Dinghy") end)
						end
						Others.boatBuyFails = 0
					end
				else
					Others.boatBuyFails = 0
				end
			end
			return nil, nil, false
		end

		if hum.SeatPart ~= mySeat then
			if hum.SeatPart then
				hum.Sit = false
			end
			local dSeat = (hrp.Position - mySeat.Position).Magnitude
			setStatus(string.format("⛵ Dueño Auto Bote: Subiendo al timón de %s [%dm]...", tostring(myBoat.Name), math.floor(dSeat)))
			if dSeat > 18 then
				moveToCFrame(mySeat.CFrame + Vector3.new(0, 3, 0))
			else
				clearFarmMover()
				pcall(function()
					hrp.CFrame = mySeat.CFrame + Vector3.new(0, 2, 0)
					mySeat:Sit(hum)
				end)
			end
			return myBoat, mySeat, false
		end

		return myBoat, mySeat, true
	end

	function Others.hasActiveLeviathanTarget()
		if getCurrentSeaNumber() ~= 3 then
			return false
		end
		if S.autoMultiFindLevi or S.leviOwnerAutoBuyBoat then
			return true
		end
		if S.autoDeliverLeviHeart then
			local _, hPart = Others.findLeviathanHeart()
			if hPart then return true end
		end
		if S.autoStartLeviathan then
			Others.tryAutoBribeSpy()
			local frozenPos = Others.findFrozenDimension()
			if frozenPos then return true end
		end
		if S.autoAttackLeviathan or S.autoMultiSegmentsLevi then
			local char = LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local segments, mainBoss = Others.scanLeviathanEntities(hrp and hrp.Position or nil)
			if S.autoMultiSegmentsLevi and #segments > 0 then
				return true
			end
			if S.autoAttackLeviathan and (mainBoss ~= nil or #segments > 0) then
				return true
			end
			if S.autoAttackLeviathan then
				local frozenPos = Others.findFrozenDimension()
				if frozenPos then return true end
			end
		end
		return false
	end

	function Others.findBeastHunterBoat(refPos)
		local myBoat, mySeat = Others.findMyBoat()
		if myBoat and mySeat and (myBoat.Name == "Beast Hunter" or myBoat:FindFirstChild("Harpoon")) then
			return myBoat, mySeat, myBoat:FindFirstChild("Harpoon"), true
		end

		local boatsFolder = Workspace:FindFirstChild("Boats")
		if not boatsFolder then return nil, nil, nil, false end

		local bestBoat, bestSeat, bestHarpoon, bestDist = nil, nil, nil, 4500
		for _, b in ipairs(boatsFolder:GetChildren()) do
			if b:IsA("Model") and (b.Name == "Beast Hunter" or b:FindFirstChild("Harpoon")) then
				local harpoon = b:FindFirstChild("Harpoon")
				local seat = b:FindFirstChildOfClass("VehicleSeat") or b:FindFirstChild("VehicleSeat", true)
				if harpoon and seat and Others.isSeaModelAlive(b) then
					local d = refPos and (seat.Position - refPos).Magnitude or 0
					if d < bestDist then
						bestDist = d
						bestBoat = b
						bestSeat = seat
						bestHarpoon = harpoon
					end
				end
			end
		end
		return bestBoat, bestSeat, bestHarpoon, false
	end

	function Others.isLeviathanHeartHooked(heartObj, heartPart, boat, boatSeat)
		if not heartPart or not boatSeat then return false end
		local dist = (heartPart.Position - boatSeat.Position).Magnitude
		-- HarpoonChain breaks if distance > 550 studs
		if dist > 525 then
			return false
		end

		if heartObj:GetAttribute("Welded") == true or heartObj:GetAttribute("Hooked") == true or heartPart:GetAttribute("Welded") == true then
			return true
		end

		for _, container in ipairs({Workspace, Workspace:FindFirstChild("_WorldOrigin")}) do
			if container then
				for _, ch in ipairs(container:GetChildren()) do
					if ch:GetAttribute("Welded") == true then
						local p = ch:IsA("BasePart") and ch or ch:FindFirstChildWhichIsA("BasePart")
						if not p or (p.Position - heartPart.Position).Magnitude <= 120 then
							return true
						end
					elseif container.Name == "_WorldOrigin" and (ch.Name == "Chain1" or ch.Name == "Link1") and ch:IsA("BasePart") then
						if (ch.Position - boatSeat.Position).Magnitude <= 540 and (ch.Position - heartPart.Position).Magnitude <= 540 then
							return true
						end
					end
				end
			end
		end

		for _, desc in ipairs(heartObj:GetDescendants()) do
			if desc:GetAttribute("Welded") == true or desc.Name == "CannonBall" then
				return true
			elseif desc:IsA("JointInstance") or desc:IsA("WeldConstraint") or desc:IsA("RopeConstraint") or desc:IsA("SpringConstraint") then
				local p0 = desc:IsA("Constraint") and (desc.Attachment0 and desc.Attachment0.Parent) or desc.Part0
				local p1 = desc:IsA("Constraint") and (desc.Attachment1 and desc.Attachment1.Parent) or desc.Part1
				if (p0 and boat and p0:IsDescendantOf(boat)) or (p1 and boat and p1:IsDescendantOf(boat)) then
					return true
				end
			end
		end

		return false
	end

	function Others.evalHarpoonBarrelCFrame(turretSeat, bw, tw, u11, u12)
		local seatCF = turretSeat.CFrame
		if bw and bw.Part0 and bw.Part1 then
			local bwC0 = CFrame.new(bw.C0.Position) * CFrame.Angles(0, u11, 0)
			local bwC1 = CFrame.new(bw.C1.Position) * CFrame.Angles(0, u11 * 2, 0)
			if bw.Part0 == turretSeat then
				seatCF = bw.Part1.CFrame * bwC1 * bwC0:Inverse()
			elseif bw.Part1 == turretSeat then
				seatCF = bw.Part0.CFrame * bwC0 * bwC1:Inverse()
			end
		end

		local barrelCF = seatCF
		if tw and tw.Part0 and tw.Part1 then
			local twC0 = CFrame.new(tw.C0.Position) * CFrame.Angles(u12, 0, 0)
			if tw.Part0 == turretSeat then
				barrelCF = seatCF * twC0 * tw.C1:Inverse()
			elseif tw.Part1 == turretSeat then
				barrelCF = seatCF * tw.C1 * twC0:Inverse()
			end
		end
		return barrelCF
	end

	function Others.solveAndFireHarpoon(harpoon, turretSeat, heartPart)
		if not harpoon or not turretSeat or not heartPart or not CommF_ then
			return false, math.huge
		end

		local char = LocalPlayer.Character
		local busy = char and char:FindFirstChild("Busy")
		if busy and busy:IsA("BoolValue") and busy.Value then
			busy.Value = false
		end

		local bw = turretSeat:FindFirstChild("BoatWeld")
		local tw = turretSeat:FindFirstChild("TubeWeld")
		local g = Workspace.Gravity
		local targetPos = heartPart.Position

		local bestYaw, bestPitch, bestErr = 0, 0, math.huge

		-- Coarse sweep over exact Harpoon angle bounds: u11 in [-1.134464, 1.134464], u12 in [-0.1745329, 0.7853981]
		for yi = 0, 20 do
			local yaw = -1.134464 + (2.268928 * (yi / 20))
			for pi = 0, 12 do
				local pitch = -0.1745329 + (0.9599310 * (pi / 12))
				local bCF = Others.evalHarpoonBarrelCFrame(turretSeat, bw, tw, yaw, pitch)
				local p0 = bCF.Position
				local t = (targetPos - p0).Magnitude / 400
				local pred = p0 + (bCF.LookVector * (400 * t)) - Vector3.new(0, 0.5 * g * t * t, 0)
				local err = (pred - targetPos).Magnitude
				if err < bestErr then
					bestErr = err
					bestYaw = yaw
					bestPitch = pitch
				end
			end
		end

		-- Fine local refinement around (bestYaw, bestPitch)
		local baseY, baseP = bestYaw, bestPitch
		for yi = -4, 4 do
			local yaw = math.clamp(baseY + yi * 0.028, -1.134464, 1.134464)
			for pi = -4, 4 do
				local pitch = math.clamp(baseP + pi * 0.020, -0.1745329, 0.7853981)
				local bCF = Others.evalHarpoonBarrelCFrame(turretSeat, bw, tw, yaw, pitch)
				local p0 = bCF.Position
				local t = (targetPos - p0).Magnitude / 400
				local pred = p0 + (bCF.LookVector * (400 * t)) - Vector3.new(0, 0.5 * g * t * t, 0)
				local err = (pred - targetPos).Magnitude
				if err < bestErr then
					bestErr = err
					bestYaw = yaw
					bestPitch = pitch
				end
			end
		end

		if bestErr > 22 then
			return false, bestErr
		end

		pcall(function()
			if bw then
				bw.C0 = CFrame.new(bw.C0.Position) * CFrame.Angles(0, bestYaw, 0)
				bw.C1 = CFrame.new(bw.C1.Position) * CFrame.Angles(0, bestYaw * 2, 0)
			end
			if tw then
				tw.C0 = CFrame.new(tw.C0.Position) * CFrame.Angles(bestPitch, 0, 0)
			end
		end)

		if not harpoon:FindFirstChild("Cooldown") and (os.clock() - Others.lastHarpoonShot > 1.15) then
			Others.lastHarpoonShot = os.clock()
			local firePitch, fireYaw = bestPitch, bestYaw
			task.spawn(function()
				pcall(function()
					CommF_:InvokeServer("FireHarpoon", firePitch, fireYaw, harpoon, Workspace:GetServerTimeNow())
				end)
			end)
		end

		return true, bestErr
	end

	function Others.driveBeastHunterSmooth(boat, boatSeat, targetPos, faceDirXZ, speedLimit, hrp)
		if S.activeTween then
			pcall(function() S.activeTween:Cancel() end)
			S.activeTween = nil
		end
		if hrp and hrp:FindFirstChild("SwitchHubBV") then
			hrp.SwitchHubBV:Destroy()
		end

		pcall(function()
			for _, p in ipairs(boat:GetDescendants()) do
				if p:IsA("BasePart") and not p:IsA("Seat") and not p:IsA("VehicleSeat") and p.CanCollide then
					p.CanCollide = false
				end
			end

			local bv = boatSeat:FindFirstChild("SwitchHubBoatBV")
			if not bv then
				bv = Instance.new("BodyVelocity")
				bv.Name = "SwitchHubBoatBV"
				bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
				bv.Parent = boatSeat
			end
			local bg = boatSeat:FindFirstChild("SwitchHubBoatBG")
			if not bg then
				bg = Instance.new("BodyGyro")
				bg.Name = "SwitchHubBoatBG"
				bg.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
				bg.P = 9000
				bg.D = 500
				bg.Parent = boatSeat
			end

			local delta = targetPos - boatSeat.Position
			if speedLimit <= 0 or delta.Magnitude <= 4 then
				bv.Velocity = Vector3.zero
			else
				bv.Velocity = delta.Unit * math.min(speedLimit, math.max(35, delta.Magnitude * 2.2))
			end

			local lookVec = faceDirXZ
			if not lookVec or lookVec.Magnitude < 0.01 then
				local flat = Vector3.new(delta.X, 0, delta.Z)
				if flat.Magnitude > 1 then
					lookVec = flat.Unit
				end
			end
			if lookVec and lookVec.Magnitude > 0.01 then
				bg.CFrame = CFrame.lookAt(boatSeat.Position, boatSeat.Position + Vector3.new(lookVec.X, 0, lookVec.Z))
			end
		end)
	end

	function Others.getHeartDeliveryWaypoint(seatPos)
		local sailY = 23
		local destChoice = tostring(S.leviHeartDestination or "Tiki Outpost")

		if destChoice:find("Hydra") then
			-- Resolve Hydra Island ocean shore dynamically if streamed, fallback to exact Sea 3 Hydra shore
			local hydraShore = Vector3.new(5480, sailY, -285)
			local wo = Workspace:FindFirstChild("_WorldOrigin")
			local locs = wo and wo:FindFirstChild("Locations")
			local hLoc = locs and locs:FindFirstChild("Hydra Island")
			if hLoc and hLoc:IsA("BasePart") then
				hydraShore = Vector3.new(hLoc.Position.X - 240, sailY, hLoc.Position.Z)
			end

			-- Bypass Tiki Outpost cleanly when coming from Danger Zone 6 so Tiki NEVER steals the heart!
			if seatPos.X < -15800 then
				return Vector3.new(-16500, sailY, 2750), hydraShore, "Hydra Island (Rodeando Tiki)"
			elseif seatPos.X < -4500 and seatPos.Z > 900 then
				return Vector3.new(-4200, sailY, 1800), hydraShore, "Hydra Island"
			else
				return hydraShore, hydraShore, "Hydra Island"
			end
		else
			-- Tiki Outpost delivery route
			local tikiShore = Vector3.new(-16580, sailY, 260)
			local wo = Workspace:FindFirstChild("_WorldOrigin")
			local locs = wo and wo:FindFirstChild("Locations")
			local tLoc = locs and locs:FindFirstChild("Tiki Outpost")
			if tLoc and tLoc:IsA("BasePart") then
				tikiShore = Vector3.new(tLoc.Position.X - 60, sailY, tLoc.Position.Z + 80)
			end

			if seatPos.X < -17200 then
				return Vector3.new(-16950, sailY, 480), tikiShore, "Tiki Outpost"
			else
				return tikiShore, tikiShore, "Tiki Outpost"
			end
		end
	end

	function Others.stepLeviathanSuite(hrp, hum)
		local anyLevi = S.autoMultiFindLevi or S.leviOwnerAutoBuyBoat or S.autoStartLeviathan
			or S.autoAttackLeviathan or S.autoMultiSegmentsLevi or S.autoDeliverLeviHeart
		if not anyLevi then
			return false
		end

		local seaNum = getCurrentSeaNumber()
		if seaNum ~= 3 then
			if S.autoSeaEvent then
				return false
			end
			setStatus("⚠️ Opciones de Leviatán requieren estar en Sea 3")
			return true
		end

		if S.autoStartLeviathan then
			Others.tryAutoBribeSpy()
		end

		local selectedPlayers = S.autoMultiFindLevi and Others.getSelectedLeviPlayers() or {}

		-- =====================================================================
		-- PRIORITY 1: DELIVER LEVIATHAN HEART TO TIKI OUTPOST OR HYDRA ISLAND
		-- =====================================================================
		if S.autoDeliverLeviHeart then
			local heartObj, heartPart = Others.findLeviathanHeart()
			if heartObj and heartPart then
				pcall(function()
					if sethiddenproperty then
						sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
					end
				end)

				local bhBoat, bhSeat, harpoon, isMyBH = Others.findBeastHunterBoat(heartPart.Position)
				if not bhBoat or not bhSeat or not harpoon then
					local dealerPos = Others.getBestBoatDealerPos(3, hrp.Position)
					if (S.leviOwnerAutoBuyBoat or not S.autoMultiFindLevi) and (hrp.Position - dealerPos).Magnitude <= 2200 then
						setStatus("❤️ Leviathan Heart activo: Comprando Beast Hunter en el muelle...")
						local reached = moveToCFrame(CFrame.new(dealerPos + Vector3.new(0, 3, 2)))
						if (reached or (hrp.Position - dealerPos).Magnitude <= 24) and CommF_ and (os.clock() - Others.lastBoatBuyClock > 2.2) then
							Others.lastBoatBuyClock = os.clock()
							pcall(function() CommF_:InvokeServer("BuyBoat", "Beast Hunter") end)
						end
					else
						-- Stay close above LeviathanHeart so it never despawns while waiting for crew's Beast Hunter
						moveToCFrame(CFrame.new(heartPart.Position + Vector3.new(0, 32, 0)))
						setStatus("❤️ Leviathan Heart encontrado: Esperando bote Beast Hunter con arpón cerca...")
					end
					return true
				end

				-- In Multi-Find mode, if we are a Passenger (not Owner) and a selected teammate / boat owner is alive nearby,
				-- ride on a passenger seat so the Owner controls Harpoon & Helm with zero conflict!
				if S.autoMultiFindLevi and (not S.leviOwnerAutoBuyBoat) and (not isMyBH) then
					local activeCrewLeader = false
					local bOwner = bhBoat:FindFirstChild("Owner") and bhBoat.Owner.Value
					if typeof(bOwner) == "Instance" and bOwner:IsA("Player") and bOwner ~= LocalPlayer then
						local oHum = bOwner.Character and bOwner.Character:FindFirstChildOfClass("Humanoid")
						local oHrp = bOwner.Character and bOwner.Character:FindFirstChild("HumanoidRootPart")
						if oHum and oHum.Health > 0 and oHrp and (oHrp.Position - bhSeat.Position).Magnitude <= 1600 then
							activeCrewLeader = true
						end
					end
					if not activeCrewLeader then
						for _, plr in ipairs(selectedPlayers) do
							local pHum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
							local pHrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
							if pHum and pHum.Health > 0 and pHrp and (pHrp.Position - bhSeat.Position).Magnitude <= 1600 then
								if (bhSeat.Occupant == pHum) or (bOwner and tostring(bOwner) == plr.Name) then
									activeCrewLeader = true
									break
								end
							end
						end
					end

					if activeCrewLeader then
						local _, finalGoal, destLabel = Others.getHeartDeliveryWaypoint(bhSeat.Position)
						local remKm = Vector2.new(finalGoal.X - bhSeat.Position.X, finalGoal.Z - bhSeat.Position.Z).Magnitude / 1000
						Others.boardPassengerSeatOnBoat(bhBoat, bhSeat, hrp, hum, true)
						setStatus(string.format("❤️ Multi-Find (Equipo): En Beast Hunter acompañando Corazón -> %s [%.1f km]...", destLabel, remKm))
						return true
					end
				end

				local turretSeat = harpoon:FindFirstChild("Seat") or harpoon:FindFirstChildWhichIsA("Seat", true)
				local hooked = Others.isLeviathanHeartHooked(heartObj, heartPart, bhBoat, bhSeat)

				if not hooked then
					-- Step 1A: Position & orient Beast Hunter ~82 studs from LeviathanHeart so Harpoon turret faces it cleanly
					local bw = turretSeat and turretSeat:FindFirstChild("BoatWeld")
					local tw = turretSeat and turretSeat:FindFirstChild("TubeWeld")
					local neutralBarrelCF = turretSeat and Others.evalHarpoonBarrelCFrame(turretSeat, bw, tw, 0, 0) or bhSeat.CFrame

					local flatToHeart = Vector3.new(heartPart.Position.X - bhSeat.Position.X, 0, heartPart.Position.Z - bhSeat.Position.Z)
					local hDist = flatToHeart.Magnitude
					local dirToHeart = (hDist > 0.5) and flatToHeart.Unit or Vector3.new(0, 0, -1)

					local curBarrelFlat = Vector3.new(neutralBarrelCF.LookVector.X, 0, neutralBarrelCF.LookVector.Z)
					curBarrelFlat = (curBarrelFlat.Magnitude > 0.01) and curBarrelFlat.Unit or Vector3.new(bhSeat.CFrame.LookVector.X, 0, bhSeat.CFrame.LookVector.Z).Unit
					local angDiff = math.atan2(dirToHeart.X, dirToHeart.Z) - math.atan2(curBarrelFlat.X, curBarrelFlat.Z)
					while angDiff > math.pi do angDiff = angDiff - 2 * math.pi end
					while angDiff < -math.pi do angDiff = angDiff + 2 * math.pi end

					local driver = bhSeat.Occupant
					local otherDriving = (driver ~= nil and driver ~= hum)
					local needsBoatAlign = (not otherDriving) and (hDist > 145 or hDist < 42 or math.abs(angDiff) > 0.62)

					if needsBoatAlign then
						if hum.SeatPart ~= bhSeat then
							if hum.SeatPart then hum.Sit = false end
							local dS = (hrp.Position - bhSeat.Position).Magnitude
							setStatus(string.format("❤️ Subiendo al timón del Beast Hunter para alinear arpón [%dm]...", math.floor(dS)))
							if dS > 18 then
								moveToCFrame(bhSeat.CFrame + Vector3.new(0, 3, 0))
							else
								clearFarmMover()
								pcall(function()
									hrp.CFrame = bhSeat.CFrame + Vector3.new(0, 2, 0)
									bhSeat:Sit(hum)
								end)
							end
							return true
						end

						local standPos = Vector3.new(heartPart.Position.X, 23, heartPart.Position.Z) - (dirToHeart * 82)
						local rotBoatLook = (CFrame.Angles(0, angDiff, 0) * Vector3.new(bhSeat.CFrame.LookVector.X, 0, bhSeat.CFrame.LookVector.Z))
						Others.driveBeastHunterSmooth(bhBoat, bhSeat, standPos, rotBoatLook, 185, hrp)
						setStatus(string.format("❤️ Alineando Beast Hunter frente al Leviathan Heart [%dm]...", math.floor(hDist)))
						return true
					end

					-- Boat is aligned within turret cone! Park boat and sit on Harpoon Seat to fire!
					if not otherDriving then
						Others.driveBeastHunterSmooth(bhBoat, bhSeat, Vector3.new(bhSeat.Position.X, 23, bhSeat.Position.Z), nil, 0, hrp)
					end

					if turretSeat then
						local turretOcc = turretSeat.Occupant
						if turretOcc and turretOcc ~= hum then
							setStatus("❤️ Compañero en el arpón: Esperando enganche del Leviathan Heart...")
							return true
						end

						if hum.SeatPart ~= turretSeat then
							if hum.SeatPart then
								hum.Sit = false
								task.wait(0.05)
							end
							local dT = (hrp.Position - turretSeat.Position).Magnitude
							setStatus(string.format("🎯 Sentándose en el Arpón del Beast Hunter [%dm]...", math.floor(dT)))
							if dT > 18 then
								moveToCFrame(turretSeat.CFrame + Vector3.new(0, 3, 0))
							else
								clearFarmMover()
								pcall(function()
									hrp.CFrame = turretSeat.CFrame + Vector3.new(0, 2, 0)
									turretSeat:Sit(hum)
								end)
							end
							return true
						end

						local firedOk, aimErr = Others.solveAndFireHarpoon(harpoon, turretSeat, heartPart)
						if not firedOk and not otherDriving then
							-- Fallback if turret angle exceeded cone: hop back to helm next tick
							hum.Sit = false
							setStatus(string.format("🎯 Reajustando ángulo del Beast Hunter (error %.0fm)...", aimErr or 0))
						else
							setStatus(string.format("🎯 Disparando Arpón al Leviathan Heart [%dm]...", math.floor(hDist)))
						end
						return true
					end
				else
					-- Step 1B: LEVIATHAN HEART IS HOOKED! Tow smoothly to Tiki Outpost or Hydra Island without snapping chain (< 550m)!
					local wp, finalGoal, destLabel = Others.getHeartDeliveryWaypoint(bhSeat.Position)
					local remTotal = Vector2.new(finalGoal.X - bhSeat.Position.X, finalGoal.Z - bhSeat.Position.Z).Magnitude
					local tetherDist = (heartPart.Position - bhSeat.Position).Magnitude

					local driver = bhSeat.Occupant
					if driver and driver ~= hum then
						setStatus(string.format("❤️ Corazón enganchado [Cadena %dm/550m] -> Rumbo a %s [%.1f km]...", math.floor(tetherDist), destLabel, remTotal / 1000))
						return true
					end

					if hum.SeatPart ~= bhSeat then
						if hum.SeatPart then
							hum.Sit = false
							task.wait(0.05)
						end
						local dS = (hrp.Position - bhSeat.Position).Magnitude
						setStatus(string.format("❤️ ¡Corazón enganchado! Subiendo a conducir Beast Hunter -> %s...", destLabel))
						if dS > 18 then
							moveToCFrame(bhSeat.CFrame + Vector3.new(0, 3, 0))
						else
							clearFarmMover()
							pcall(function()
								hrp.CFrame = bhSeat.CFrame + Vector3.new(0, 2, 0)
								bhSeat:Sit(hum)
							end)
						end
						return true
					end

					-- Dynamic anti-snap speed control (chain snaps at 550 studs in HarpoonChain!)
					local maxTowSpeed = math.clamp(tonumber(S.seaBoatSpeed) or 185, 110, 195)
					if tetherDist > 330 then
						maxTowSpeed = 0 -- Pause so heart reels in safely
					elseif tetherDist > 240 then
						maxTowSpeed = 95
					end

					Others.driveBeastHunterSmooth(bhBoat, bhSeat, wp, nil, maxTowSpeed, hrp)
					if maxTowSpeed == 0 then
						setStatus(string.format("❤️ Cuidando cadena [%dm/550m]: Esperando que el Corazón se acerque -> %s...", math.floor(tetherDist), destLabel))
					else
						setStatus(string.format("❤️ Remolcando Leviathan Heart a %s [%.2f km | Cadena %dm]...", destLabel, remTotal / 1000, math.floor(tetherDist)))
					end
					return true
				end
			end
		end

		-- =====================================================================
		-- PRIORITY 2: ATTACK LEVIATHAN MULTI-SEGMENTS & LEVIATHAN BOSS
		-- =====================================================================
		if S.autoAttackLeviathan or S.autoMultiSegmentsLevi then
			local segments, mainBoss, mainPart = Others.scanLeviathanEntities(hrp.Position)
			local chosenModel, chosenPart, combatLabel = nil, nil, nil

			if S.autoMultiSegmentsLevi and #segments > 0 then
				if not S.isCastingSkillAim and (os.clock() - Others.lastLeviSegSwitch >= 0.85) then
					Others.lastLeviSegSwitch = os.clock()
					Others.leviSegmentIdx = (Others.leviSegmentIdx % #segments) + 1
				end
				if Others.leviSegmentIdx > #segments or Others.leviSegmentIdx < 1 then
					Others.leviSegmentIdx = 1
				end
				local segEntry = segments[Others.leviSegmentIdx]
				chosenModel = segEntry.model
				chosenPart = segEntry.part
				combatLabel = string.format("🐉 Multisegmentos Leviatán (%d activos)", #segments)
			elseif S.autoAttackLeviathan and mainBoss and mainPart then
				chosenModel = mainBoss
				chosenPart = mainPart
				combatLabel = (#segments > 0)
					and string.format("🐉 Atacando Leviatán (%d segmentos vivos)", #segments)
					or "🐉 Atacando Leviatán"
			elseif S.autoAttackLeviathan and #segments > 0 then
				chosenModel = segments[1].model
				chosenPart = segments[1].part
				combatLabel = string.format("🐉 Atacando Segmento de Leviatán (%d vivos)", #segments)
			end

			if chosenModel and chosenPart then
				local myBoat, mySeat = Others.findMyBoat()
				if myBoat and mySeat then
					Others.parkBoatSafely(myBoat, mySeat)
				end
				if hum.SeatPart then
					hum.Sit = false
					task.wait(0.05)
				end

				pcall(function()
					if sethiddenproperty then
						sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
					end
				end)

				local useCloseHover = (S.seaWeapons and S.seaWeapons["Blox Fruit"] and S.seaUseFruitM1) or S.seaUseM1
				local hoverY = useCloseHover and 34 or 46
				local hpRatio = hum.Health / math.max(1, hum.MaxHealth)
				if S.seaDodgeAttacks and hpRatio < 0.40 then
					hoverY = math.max(hoverY + 38, 80)
				end

				-- Never dip into sea water (< Y=32) even if a Leviathan segment dives under waves!
				local safeY = math.max(chosenPart.Position.Y + hoverY, 32)
				local combatPos = Vector3.new(chosenPart.Position.X, safeY, chosenPart.Position.Z + 2.5)
				local dist = math.floor((hrp.Position - chosenPart.Position).Magnitude)

				setStatus(string.format("%s [%dm]...", combatLabel, dist))
				moveToCFrame(CFrame.new(combatPos), chosenPart.Position)
				Others.fireSeaEventWeaponsAndSkills(chosenModel, chosenPart, "Leviathan")
				return true
			end

			-- =================================================================
			-- PRIORITY 3: OPEN FROZEN DIMENSION GATE (AUTO START / ATTACK LEVIATHAN)
			-- =================================================================
		end

		if S.autoStartLeviathan or S.autoAttackLeviathan then
			local frozenPos, watcherPos = Others.findFrozenDimension()
			if frozenPos then
				local myBoat, mySeat = Others.findMyBoat()
				if myBoat and mySeat then
					Others.parkBoatSafely(myBoat, mySeat)
				end
				if hum.SeatPart then
					hum.Sit = false
				end
				local gateTarget = (watcherPos or frozenPos) + Vector3.new(0, 14, 0)
				local dGate = math.floor((hrp.Position - gateTarget).Magnitude)
				local reached = moveToCFrame(CFrame.new(gateTarget))

				if reached or dGate <= 85 then
					if Others.frozenGateArriveClock == 0 then
						Others.frozenGateArriveClock = os.clock()
					end

					local crewReadyToOpen = true
					local readyGateCount = 0
					if S.autoMultiFindLevi and #selectedPlayers > 0 then
						for _, plr in ipairs(selectedPlayers) do
							local pChar = plr.Character
							local pHum = pChar and pChar:FindFirstChildOfClass("Humanoid")
							local pHrp = pChar and pChar:FindFirstChild("HumanoidRootPart")
							if pHum and pHum.Health > 0 and pHrp and (pHrp.Position - gateTarget).Magnitude <= 260 then
								readyGateCount = readyGateCount + 1
							end
						end
						if readyGateCount < #selectedPlayers and (os.clock() - Others.frozenGateArriveClock < 14.0) then
							crewReadyToOpen = false
						end
					end

					if not crewReadyToOpen then
						setStatus(string.format("❄️ Auto Start Leviatán: Esperando al equipo en Frozen Watcher (%d/%d listos)...", readyGateCount, #selectedPlayers))
						return true
					end

					-- Owner triggers immediately; Passengers trigger after 3s as backup so gate always opens!
					local canInvokeNow = S.leviOwnerAutoBuyBoat
						or (not S.autoMultiFindLevi)
						or (os.clock() - Others.frozenGateArriveClock >= 3.0)

					setStatus(string.format("❄️ Auto Start Leviatán: ¡Equipo listo! Abriendo puerta en Frozen Dimension [%dm]...", dGate))
					if canInvokeNow and CommF_ and (os.clock() - Others.lastLeviGateOpen > 2.2) then
						Others.lastLeviGateOpen = os.clock()
						task.spawn(function()
							pcall(function()
								CommF_:InvokeServer("OpenLeviathanGate")
							end)
						end)
					end
				else
					setStatus(string.format("❄️ Frozen Dimension detectada [%dm]: Yendo al Frozen Watcher...", dGate))
				end
				return true
			else
				Others.frozenGateArriveClock = 0
			end
		end

		-- =====================================================================
		-- PRIORITY 4: MULTI-FIND TEAM SYNC & OWNER AUTO BOAT TO ZONE 6 (???)
		-- =====================================================================
		if S.autoMultiFindLevi or S.leviOwnerAutoBuyBoat then
			-- Clear immediate Sea Event threats attacking the crew boat if Auto Eventos Marítimos is ON
			if S.autoSeaEvent then
				local targetInfo = Others.findActiveSeaEventTarget(hrp.Position)
				if targetInfo and targetInfo.part and targetInfo.model and (targetInfo.part.Position - hrp.Position).Magnitude <= 950 then
					local myBoat, mySeat = Others.findMyBoat()
					if myBoat and mySeat then
						Others.parkBoatSafely(myBoat, mySeat)
					end
					if hum.SeatPart then
						hum.Sit = false
						task.wait(0.05)
					end
					local hoverY = targetInfo.hoverY or 26
					if S.seaDodgeAttacks and (hum.Health / math.max(1, hum.MaxHealth)) < 0.38 then
						hoverY = math.max(hoverY + 35, 72)
					end
					local combatPos = targetInfo.part.Position + Vector3.new(0, hoverY, 2.5)
					setStatus(string.format("🤝 Equipo limpiando %s [%dm]...", targetInfo.label, math.floor((hrp.Position - targetInfo.part.Position).Magnitude)))
					moveToCFrame(CFrame.new(combatPos), targetInfo.part.Position)
					if targetInfo.bringable then
						bringNearbyMobs(nil, targetInfo.part.CFrame)
					end
					Others.fireSeaEventWeaponsAndSkills(targetInfo.model, targetInfo.part, targetInfo.kind)
					return true
				end
			end

			-- ROLE A: BOAT OWNER (Auto Comprar Bote ON)
			if S.leviOwnerAutoBuyBoat then
				local myBoat, mySeat, seatedAtHelm = Others.ensureLeviOwnerBoatAndHelm(hrp, hum)
				if not myBoat or not mySeat or not seatedAtHelm then
					return true
				end

				local distFromDock = Vector2.new(mySeat.Position.X - SEA3_DOCK_ORIGIN.X, mySeat.Position.Z - SEA3_DOCK_ORIGIN.Z).Magnitude
				if S.autoMultiFindLevi and #selectedPlayers > 0 then
					local aboardCount, missingAll, missingNearby = Others.getCrewAboardStatus(myBoat, mySeat, selectedPlayers)
					if (not Others.leviCrewDeparted or distFromDock < 650) and aboardCount < #selectedPlayers then
						Others.parkBoatSafely(myBoat, mySeat)
						local missTxt = table.concat(missingAll, ", ")
						setStatus(string.format("🤝 Multi-Find (Dueño): Esperando equipo en el bote (%d/%d — falta: %s)...", aboardCount, #selectedPlayers, missTxt))
						return true
					elseif Others.leviCrewDeparted and #missingNearby > 0 then
						Others.parkBoatSafely(myBoat, mySeat)
						setStatus(string.format("🤝 Multi-Find (Dueño): Esperando que %s suba de nuevo al bote...", table.concat(missingNearby, ", ")))
						return true
					end
				end

				Others.leviCrewDeparted = true

				if S.seaReturnAt10km then
					if distFromDock >= 10000 then
						Others.returningFrom10km = true
					elseif Others.returningFrom10km and distFromDock <= 5000 then
						Others.returningFrom10km = false
					end
				else
					Others.returningFrom10km = false
				end

				local sailY = S.seaSafeBoatFly and 28 or 12
				if Others.returningFrom10km then
					local distNow = Others.driveBoatSeatTo(myBoat, mySeat, Vector3.new(-21650, sailY, 500), hrp, 3)
					setStatus(string.format("↩️ Multi-Find (10 km): Regresando a 5.0 km [%.2f km]...", distNow / 1000))
					return true
				end

				local center = SEA3_ZONE_CENTERS[6]
				local offsets = {
					Vector3.new(0, 0, 0),
					Vector3.new(-450, 0, 480),
					Vector3.new(-900, 0, 0),
					Vector3.new(-450, 0, -480),
				}
				if Others.seaPatrolIdx > #offsets then
					Others.seaPatrolIdx = 1
				end
				local wp = Vector3.new(center.X, sailY, center.Z) + offsets[Others.seaPatrolIdx]
				local distNow, remDist = Others.driveBoatSeatTo(myBoat, mySeat, wp, hrp, 3)
				if remDist <= 55 and (os.clock() - Others.lastSeaPatrolSwitch > 1.5) then
					Others.lastSeaPatrolSwitch = os.clock()
					Others.seaPatrolIdx = (Others.seaPatrolIdx % #offsets) + 1
				end

				setStatus(string.format("🐉 Multi-Find (Dueño): Buscando Frozen Dimension en Zona 6 [%.1f km | Equipo %d]...", distNow / 1000, #selectedPlayers + 1))
				return true
			end

			-- ROLE B: CREWMATE / PASSENGER (Auto Comprar Bote OFF, Multi-Find ON)
			if S.autoMultiFindLevi then
				if #selectedPlayers == 0 then
					setStatus("⚠️ Multi-Find: Selecciona al dueño / jugadores en 'Seleccionar Jugadores (Multi-Find)'")
					return true
				end

				local teamBoat, teamSeat, leaderPlr = Others.findSelectedTeamBoat(selectedPlayers)
				if teamBoat and teamSeat then
					local distDock = Vector2.new(teamSeat.Position.X - SEA3_DOCK_ORIGIN.X, teamSeat.Position.Z - SEA3_DOCK_ORIGIN.Z).Magnitude
					local isSeated = Others.boardPassengerSeatOnBoat(teamBoat, teamSeat, hrp, hum, false)
					local leaderName = leaderPlr and (leaderPlr.DisplayName or leaderPlr.Name) or "Equipo"
					if isSeated then
						setStatus(string.format("🤝 Multi-Find: En el bote de %s buscando Frozen Dimension [%.1f km]...", leaderName, distDock / 1000))
					else
						setStatus(string.format("🤝 Multi-Find: Subiendo al bote de %s...", leaderName))
					end
					return true
				else
					-- Wait near the first selected player (if near Tiki) or at Tiki Boat Dealer until Owner buys the boat
					local waitPos = Vector3.new(-16917.2, 14.0, 515.4)
					local waitName = selectedPlayers[1].DisplayName or selectedPlayers[1].Name
					for _, plr in ipairs(selectedPlayers) do
						local pHrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
						if pHrp and (pHrp.Position - SEA3_DOCK_ORIGIN).Magnitude <= 2500 then
							waitPos = pHrp.Position + Vector3.new(4, 3, 4)
							waitName = plr.DisplayName or plr.Name
							break
						end
					end
					if (hrp.Position - waitPos).Magnitude > 22 then
						moveToCFrame(CFrame.new(waitPos))
					else
						clearFarmMover()
					end
					setStatus(string.format("🤝 Multi-Find: Esperando que el dueño (%s) compre el bote...", waitName))
					return true
				end
			end
		end

		return false
	end

	function Others.findActiveSeaEventTarget(refPos)
		local sel = S.selectedSeaEvents or {}
		local enemies = Workspace:FindFirstChild("Enemies")

		local function isEntityAlive(m)
			local hVal = m:FindFirstChild("Health")
			if hVal and hVal:IsA("ValueBase") and tonumber(hVal.Value) ~= nil then
				return tonumber(hVal.Value) > 0, tonumber(hVal.Value), tonumber(hVal:GetAttribute("MaxValue")) or tonumber(hVal.Value)
			end
			local hum = m:FindFirstChildOfClass("Humanoid")
			if hum then
				return hum.Health > 0, hum.Health, hum.MaxHealth
			end
			return false, 0, 1
		end

		-- 1) Terrorshark (Highest danger priority)
		if sel["Terrorshark"] and enemies then
			for _, en in ipairs(enemies:GetChildren()) do
				if en.Name:find("Terrorshark") then
					local alive = isEntityAlive(en)
					local part = en:FindFirstChild("HumanoidRootPart") or en:FindFirstChildWhichIsA("BasePart")
					if alive and part and (part.Position - refPos).Magnitude <= 2800 then
						return {kind = "Terrorshark", label = "🦈 Terrorshark", model = en, part = part, hoverY = 34}
					end
				end
			end
		end

		-- 2) Sea Beast (Workspace.SeaBeasts)
		if sel["Sea Beast"] then
			local sbFolder = Workspace:FindFirstChild("SeaBeasts")
			if sbFolder then
				local bestSB, bestPart, bestDist = nil, nil, 3200
				for _, sb in ipairs(sbFolder:GetChildren()) do
					if sb:IsA("Model") and not sb.Name:find("Leviathan") then
						local alive = isEntityAlive(sb)
						local part = sb:FindFirstChild("HumanoidRootPart")
							or sb:FindFirstChild("RootPart")
							or sb.PrimaryPart
							or sb:FindFirstChildWhichIsA("BasePart")
						if alive and part and part.Position.Y > -120 then
							local d = (part.Position - refPos).Magnitude
							if d < bestDist then
								bestDist = d
								bestSB = sb
								bestPart = part
							end
						end
					end
				end
				if bestSB and bestPart then
					local sbHover = ((S.seaWeapons and S.seaWeapons["Blox Fruit"] and S.seaUseFruitM1) or S.seaUseM1) and 34 or 52
					return {kind = "Sea Beast", label = "🐉 Sea Beast", model = bestSB, part = bestPart, hoverY = sbHover}
				end
			end
		end

		-- 3) Pirate Ship Raid & Ghost Ship Raid (PirateBrigade, PirateGrandBrigade, FishBoat / GhostShip)
		if sel["Pirate Ship Raid"] or sel["Ghost Ship Raid"] then
			for _, folder in ipairs({enemies, Workspace:FindFirstChild("SeaEvents")}) do
				if folder then
					for _, ship in ipairs(folder:GetChildren()) do
						if ship:IsA("Model") then
							local n = ship.Name
							local isPirateShip = sel["Pirate Ship Raid"] and (n == "PirateBrigade" or n == "PirateGrandBrigade")
							local isGhostShip = sel["Ghost Ship Raid"] and (n == "FishBoat" or n:find("GhostShip"))
							if isPirateShip or isGhostShip then
								local alive = isEntityAlive(ship)
								local part = ship:FindFirstChild("Engine")
									or ship:FindFirstChild("Body")
									or ship:FindFirstChildOfClass("VehicleSeat")
									or ship:FindFirstChild("HumanoidRootPart")
									or ship.PrimaryPart
									or ship:FindFirstChildWhichIsA("BasePart")
								if alive and part and (part.Position - refPos).Magnitude <= 2800 then
									return {
										kind = isGhostShip and "Ghost Ship Raid" or "Pirate Ship Raid",
										label = isGhostShip and "👻 Ghost Ship Raid" or "🏴‍☠️ Pirate Ship Raid",
										model = ship,
										part = part,
										hoverY = 26,
									}
								end
							end
						end
					end
				end
			end
		end

		-- 4) Ocean Mobs (Piranha -> Shark -> Fish Crew Member -> Haunted Shipwreck)
		if enemies then
			local bestMob, bestPart, bestKind, bestHover, bestScore = nil, nil, nil, 22, math.huge
			for _, en in ipairs(enemies:GetChildren()) do
				local alive = isEntityAlive(en)
				local part = en:FindFirstChild("HumanoidRootPart") or en:FindFirstChildWhichIsA("BasePart")
				if alive and part then
					local d = (part.Position - refPos).Magnitude
					if d <= 2000 then
						local clean = Others.cleanEntityName(en.Name)
						local matchedKind = nil
						local hover = 22
						local prioBonus = 0
						if sel["Piranha"] and clean:find("Piranha") then
							matchedKind = "Piranha"
							hover = 26
							prioBonus = -500 -- Kill Piranhas first!
						elseif sel["Shark"] and clean == "Shark" then
							matchedKind = "Shark"
							hover = 22
						elseif sel["Fish Crew Member"] and (clean:find("Fish Crew") or clean:find("Fisherman")) then
							matchedKind = "Fish Crew Member"
							hover = 22
						elseif sel["Haunted Shipwreck"] and (clean:find("Haunted") or clean:find("Shipwreck")) then
							matchedKind = "Haunted Shipwreck"
							hover = 22
						end
						if matchedKind and (d + prioBonus) < bestScore then
							bestScore = d + prioBonus
							bestMob = en
							bestPart = part
							bestKind = matchedKind
							bestHover = hover
						end
					end
				end
			end
			if bestMob and bestPart then
				return {
					kind = bestKind,
					label = "🌊 " .. tostring(bestKind),
					model = bestMob,
					part = bestPart,
					hoverY = bestHover,
					bringable = true,
				}
			end
		end

		return nil
	end

	function Others.fireSeaEventWeaponsAndSkills(targetModel, targetPart, kind)
		if not targetModel or not targetPart then return end

		-- Update Aimlock target directly onto Sea Beast / Ship / Sea Mob part!
		S.lastAimEnemy = targetModel
		S.lastAimPart = targetPart
		S.lastAimPos = targetPart.Position
		if MouseModule then
			pcall(function()
				local cam = Workspace.CurrentCamera
				local camPos = cam and cam.CFrame.Position or (S.lastAimPos + Vector3.new(0, 30, 0))
				local dir = (S.lastAimPos - camPos)
				local unitDir = (dir.Magnitude > 0.001) and dir.Unit or Vector3.new(0, -1, 0)
				MouseModule.Hit = CFrame.new(S.lastAimPos)
				MouseModule.Target = targetPart
				MouseModule.UnitRay = Ray.new(camPos, unitDir)
			end)
		end

		-- Build ordered list of enabled Sea Event weapons (Blox Fruit, Melee, Sword, Gun)
		local activeWeapons = {}
		for _, wName in ipairs(SEA_WEAPON_ORDER) do
			if S.seaWeapons and S.seaWeapons[wName] and getToolByWeaponType(wName) then
				table.insert(activeWeapons, wName)
			end
		end
		if #activeWeapons == 0 then
			table.insert(activeWeapons, S.weaponType or "Blox Fruit")
		end

		if #activeWeapons > 1 and (os.clock() - Others.lastSeaWeaponSwitch >= 2.0) then
			Others.lastSeaWeaponSwitch = os.clock()
			Others.seaWeaponIdx = (Others.seaWeaponIdx % #activeWeapons) + 1
		end
		if Others.seaWeaponIdx > #activeWeapons then
			Others.seaWeaponIdx = 1
		end

		local curWeapon = activeWeapons[Others.seaWeaponIdx]
		ensureBusoHaki()
		local tool = equipWeaponType(curWeapon)
		if tool then
			local mp = tool:FindFirstChild("MousePos")
			if mp and mp:IsA("Vector3Value") then
				mp.Value = S.lastAimPos
			end
		end

		-- Fire Blox Fruit M1 Clicks (LeftClickRemote + Click + Hitbox) or Weapon M1s
		if curWeapon == "Blox Fruit" then
			if S.seaUseFruitM1 then
				performNormalAttack("Blox Fruit", targetModel, true)
			end
		elseif S.seaUseM1 then
			performNormalAttack(curWeapon, targetModel, true)
		end

		-- Centralized Global Skills controller (Advanced Setting Skills tab)
		S.castGlobalSkills(curWeapon, targetModel, targetPart, "sea")
	end

	function Others.stepSeaEvents(hrp, hum)
		local seaNum = getCurrentSeaNumber()
		if seaNum ~= 2 and seaNum ~= 3 then
			setStatus("⚠️ Eventos Marítimos requieren estar en Sea 2 o Sea 3")
			return true
		end

		local myBoat, mySeat = Others.findMyBoat()

		-- 1) Check Active Hostile Sea Events (Terrorshark, Sea Beast, Pirate/Ghost Ship, Shark, Piranha, Crew)
		local targetInfo = Others.findActiveSeaEventTarget(hrp.Position)
		if targetInfo and targetInfo.part and targetInfo.model then
			if myBoat and mySeat then
				Others.parkBoatSafely(myBoat, mySeat)
			end
			if hum.SeatPart then
				hum.Sit = false
				task.wait(0.05)
			end

			pcall(function()
				if sethiddenproperty then
					sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
				end
			end)

			local hoverY = targetInfo.hoverY or 25
			local hpRatio = hum.Health / math.max(1, hum.MaxHealth)
			if S.seaDodgeAttacks then
				if hpRatio < 0.38 then
					hoverY = math.max(hoverY + 35, 72)
				elseif targetInfo.kind == "Terrorshark" and (math.floor(os.clock() * 1.5) % 4 == 0) then
					hoverY = hoverY + 18
				end
			end

			local combatPos = targetInfo.part.Position + Vector3.new(0, hoverY, 2.5)
			setStatus(string.format("%s: Atacando con Armas / Skills [%dm]...", targetInfo.label, math.floor((hrp.Position - targetInfo.part.Position).Magnitude)))
			moveToCFrame(CFrame.new(combatPos), targetInfo.part.Position)

			if targetInfo.bringable then
				bringNearbyMobs(nil, targetInfo.part.CFrame)
			end

			Others.fireSeaEventWeaponsAndSkills(targetInfo.model, targetInfo.part, targetInfo.kind)
			return true
		end

		if not S.autoSeaEvent then
			return false
		end

		-- 4 & 5) Reset if boat was destroyed/lost, otherwise buy & board Boat
		if not Others.ensureBoatAndBoard(seaNum, myBoat, mySeat, hrp, hum, "⛵ Eventos Marítimos") then
			return true
		end

		-- 6) Seated in VehicleSeat! Sail to Selected Zone + 10 km Turnaround check!
		local dockOrigin = (seaNum == 3) and SEA3_DOCK_ORIGIN or SEA2_DOCK_ORIGIN
		local curDistFromDock = Vector2.new(mySeat.Position.X - dockOrigin.X, mySeat.Position.Z - dockOrigin.Z).Magnitude

		if S.seaReturnAt10km then
			if curDistFromDock >= 10000 then
				Others.returningFrom10km = true
			elseif Others.returningFrom10km and curDistFromDock <= 5000 then
				Others.returningFrom10km = false
			end
		else
			Others.returningFrom10km = false
		end

		local zoneNum = math.clamp(tonumber(tostring(S.selectedSeaZone):match("(%d)")) or 6, 1, 6)
		local zoneTable = (seaNum == 3) and SEA3_ZONE_CENTERS or SEA2_ZONE_CENTERS
		local sailY = S.seaSafeBoatFly and 28 or 10

		if Others.returningFrom10km then
			local returnTarget = (seaNum == 3)
				and Vector3.new(-21650, sailY, 500)
				or Vector3.new(-7000, sailY, -11650)
			local distNow = Others.driveBoatSeatTo(myBoat, mySeat, returnTarget, hrp, seaNum)
			setStatus(string.format("↩️ Límite 10 km alcanzado [%.2f km] -> Devolviéndose hacia 5.0 km...", distNow / 1000))
			return true
		end

		local center = zoneTable[zoneNum] or zoneTable[6]
		local offsets = {
			Vector3.new(0, 0, 0),
			Vector3.new(-450, 0, 480),
			Vector3.new(-900, 0, 0),
			Vector3.new(-450, 0, -480),
		}
		if Others.seaPatrolIdx > #offsets then
			Others.seaPatrolIdx = 1
		end
		local wp = Vector3.new(center.X, sailY, center.Z) + offsets[Others.seaPatrolIdx]
		local distToCenter = Vector2.new(center.X - mySeat.Position.X, center.Z - mySeat.Position.Z).Magnitude
		local distNow, remDist = Others.driveBoatSeatTo(myBoat, mySeat, wp, hrp, seaNum)

		if remDist <= 55 and (os.clock() - Others.lastSeaPatrolSwitch > 1.5) then
			Others.lastSeaPatrolSwitch = os.clock()
			Others.seaPatrolIdx = (Others.seaPatrolIdx % #offsets) + 1
		end

		if distToCenter > 900 then
			setStatus(string.format("⛵ Navegando hacia Zona %d [%dm restantes | %.1f km]...", zoneNum, math.floor(distToCenter), distNow / 1000))
		else
			setStatus(string.format("🌊 Patrullando en Zona %d [%.1f km / 10 km] — Esperando Eventos...", zoneNum, distNow / 1000))
		end
		return true
	end

	-- Initialize Mob & Boss Catalogs immediately + periodic live Boss status check
	pcall(Others.refreshMobsUI)
	pcall(Others.refreshBossUI, false)
	task.spawn(function()
		while isAlive() do
			task.wait(5)
			pcall(Others.refreshBossUI, true)
		end
	end)
end

-- Main Farm Loop (Single authoritative loop with Full Stack Priority)
task.spawn(function()
	while isAlive() do
		task.wait(0.14)
		pcall(function()
			if not isAlive() then return end

			-- Yield while approaching NPC in Shop / Fruit Gacha / Fruit Stock
			if S.styleShopBusy then
				return
			end

			local seaNum = getCurrentSeaNumber()
			local anyDirectFarm = S.levelFarm
			local anyStackToggle = S.autoFirstSeaComplete or S.autoSecondSeaComplete
				or S.stackTpFruit or S.stackTpFruitHop
				or S.autoFactory or S.autoPirateRaid
				or S.autoEliteHunter or S.hopEliteHunter or S.autoTouchpadHaki
				or S.autoSummonIndra or S.autoAttackIndra
				or S.autoSummonSoulReaper or S.autoAttackSoulReaper
				or S.autoSummonDoughKing or S.autoAttackDoughKing
				or S.autoSummonDarkbeard or S.autoAttackDarkbeard
			local anyOthersToggle = S.autoDojoTrainer or S.autoDragonHunter
				or S.autoCollectBerries or S.hopFindBerry
				or S.autoChestFarm or S.autoChestHop
				or S.autoLawRaid
				or S.autoObservationFarm or S.hopObservation
				or S.autoKillMob
				or S.bossFarm or S.allBossFarm or S.hopFindBoss
				or S.autoRaid or S.hopServerRaid or S.autoAwakeFruit
				or S.autoSeaEvent or S.autoMultiFindLevi or S.leviOwnerAutoBuyBoat or S.autoStartLeviathan
				or S.autoAttackLeviathan or S.autoMultiSegmentsLevi or S.autoDeliverLeviHeart
				or S.tpKitsuneIsland or S.hopNearFullMoon
				or S.autoSpawnKitsune or S.autoSummonSoulEmber
				or S.autoCollectSoulEmber or S.autoTradeAzureEmber

			if not anyDirectFarm and not anyStackToggle and not anyOthersToggle and not S.autoGrabFruits then
				S.stackTaskRunning = false
				S.othersTaskRunning = false
				S.raidTaskRunning = false
				S.seaTaskRunning = false
				return
			end

			-- 1) Evaluate Spawned Fruits (strictly disabled when Auto Segundo Sea -> Tercer Sea is active so NO extra fruit is ever picked up!)
			local spawnedFruit, fruitHandle, fruitDist = nil, nil, math.huge
			if not S.autoSecondSeaComplete and not S.autoFirstSeaComplete and (S.stackTpFruit or S.stackTpFruitHop or (S.autoGrabFruits and not anyDirectFarm)) then
				spawnedFruit, fruitHandle, fruitDist = Stack.findSpawnedFruitInWorkspace()
			end

			-- 2) Evaluate Raid Bosses (Attack & Summon items)
			local liveIndra, repIndra = nil, nil
			if seaNum == 3 and (S.autoAttackIndra or S.autoSummonIndra) then
				liveIndra, repIndra = Stack.findRaidBoss({"rip_indra"})
			end
			local attackIndraNow = (seaNum == 3) and S.autoAttackIndra
				and (liveIndra ~= nil or repIndra ~= nil or os.clock() < S.indraAlertUntil)

			local liveReaper, repReaper = nil, nil
			if seaNum == 3 and (S.autoAttackSoulReaper or S.autoSummonSoulReaper) then
				liveReaper, repReaper = Stack.findRaidBoss({"soul reaper"})
			end
			local attackReaperNow = (seaNum == 3) and S.autoAttackSoulReaper
				and (liveReaper ~= nil or repReaper ~= nil or os.clock() < S.soulReaperAlertUntil)

			local liveDK, repDK = nil, nil
			if seaNum == 3 and (S.autoAttackDoughKing or S.autoSummonDoughKing) then
				liveDK, repDK = Stack.findRaidBoss({"dough king"})
			end
			local attackDKNow = (seaNum == 3) and S.autoAttackDoughKing
				and (liveDK ~= nil or repDK ~= nil or os.clock() < S.doughKingAlertUntil)

			local liveDarkbeard, repDarkbeard = nil, nil
			if seaNum == 2 and (S.autoAttackDarkbeard or S.autoSummonDarkbeard) then
				liveDarkbeard, repDarkbeard = Stack.findRaidBoss({"darkbeard", "barbanegra"})
			end
			local attackDarkbeardNow = (seaNum == 2) and S.autoAttackDarkbeard
				and (liveDarkbeard ~= nil or repDarkbeard ~= nil or os.clock() < S.darkbeardAlertUntil)

			-- Summon items check (only when boss is NOT already alive)
			local godsChaliceTool = (seaNum == 3 and S.autoSummonIndra and not liveIndra and not repIndra)
				and Stack.findSpecialTool({"god's chalice", "gods chalice", "cáliz de dios", "caliz de dios", "chalice"}, {"sweet", "dulce", "cocoa"})
				or nil

			local hallowEssenceTool = (seaNum == 3 and S.autoSummonSoulReaper and not liveReaper and not repReaper)
				and Stack.findSpecialTool({"hallow essence", "esencia sagrada", "esencia hueca"}, nil)
				or nil

			local sweetChaliceTool = (seaNum == 3 and S.autoSummonDoughKing and not liveDK and not repDK)
				and Stack.findSpecialTool({"sweet chalice", "cáliz dulce", "caliz dulce"}, nil)
				or nil

			local fistOfDarknessTool = (seaNum == 2 and S.autoSummonDarkbeard and not liveDarkbeard and not repDarkbeard)
				and Stack.findSpecialTool({"fist of darkness", "puño de la oscuridad", "puno de la oscuridad", "puño oscuro"}, nil)
				or nil

			-- Haki Touchpads check
			local pendingHakiPad = nil
			if seaNum == 3 and (S.autoTouchpadHaki or godsChaliceTool ~= nil) then
				pendingHakiPad = Stack.getPendingHakiTouchpad()
			end

			-- Game Events check
			local factoryNow = S.autoFactory and Stack.isFactoryEventActive()
			local raidMob, raidRepMob = nil, nil
			if S.autoPirateRaid and seaNum == 3 then
				raidMob, raidRepMob = Stack.findPirateRaidTarget()
				if raidMob or raidRepMob then
					S.pirateRaidActiveUntil = math.max(S.pirateRaidActiveUntil, os.clock() + 16)
				end
			end
			local pirateRaidNow = S.autoPirateRaid and seaNum == 3
				and (raidMob ~= nil or raidRepMob ~= nil or os.clock() < S.pirateRaidAlertUntil or os.clock() < S.pirateRaidActiveUntil)

			-- Elite Hunter check
			local eliteNow = false
			local eliteHopNow = false
			if seaNum == 3 and (S.autoEliteHunter or S.hopEliteHunter) then
				local avail = Stack.pollEliteHunterStatus()
				if avail and S.autoEliteHunter then
					eliteNow = true
				elseif not avail and S.hopEliteHunter then
					eliteHopNow = true
				end
			end

			local shouldRunStackNow = S.autoFirstSeaComplete
				or S.autoSecondSeaComplete
				or (spawnedFruit ~= nil)
				or S.stackTpFruitHop
				or attackIndraNow
				or attackDKNow
				or attackReaperNow
				or attackDarkbeardNow
				or (pendingHakiPad ~= nil)
				or (godsChaliceTool ~= nil)
				or (hallowEssenceTool ~= nil)
				or (sweetChaliceTool ~= nil)
				or (fistOfDarknessTool ~= nil)
				or factoryNow
				or S.wasFightingFactoryCore
				or pirateRaidNow
				or eliteNow
				or eliteHopNow

			local hasActiveBerry = false
			if S.autoCollectBerries or S.hopFindBerry then
				local bCF = Others.findNearestBerry(nil)
				hasActiveBerry = (bCF ~= nil) or S.hopFindBerry
			end
			local hasActiveLeviathan = false
			local anyLeviToggle = S.autoMultiFindLevi or S.leviOwnerAutoBuyBoat or S.autoStartLeviathan
				or S.autoAttackLeviathan or S.autoMultiSegmentsLevi or S.autoDeliverLeviHeart
			if anyLeviToggle then
				hasActiveLeviathan = Others.hasActiveLeviathanTarget()
			end
			local shouldRunOthersNow = S.autoDojoTrainer
				or S.autoDragonHunter
				or hasActiveBerry
				or hasActiveLeviathan
				or S.autoChestFarm
				or S.autoChestHop
				or S.autoLawRaid
				or S.autoObservationFarm
				or S.hopObservation
				or S.autoKillMob
				or S.bossFarm
				or S.allBossFarm
				or S.hopFindBoss
				or S.autoRaid
				or S.hopServerRaid
				or S.autoAwakeFruit
				or S.autoSeaEvent
				or S.tpKitsuneIsland
				or S.hopNearFullMoon
				or S.autoSpawnKitsune
				or S.autoSummonSoulEmber
				or S.autoCollectSoulEmber
				or S.autoTradeAzureEmber

			if not shouldRunStackNow and not shouldRunOthersNow and not anyDirectFarm then
				if S.stackTaskRunning or S.othersTaskRunning or S.raidTaskRunning or S.seaTaskRunning then
					S.stackTaskRunning = false
					S.othersTaskRunning = false
					S.raidTaskRunning = false
					S.seaTaskRunning = false
					if S.cleanupBoatMovers then
						pcall(S.cleanupBoatMovers)
					end
					clearFarmMover()
				end
				if anyLeviToggle then
					if seaNum ~= 3 then
						setStatus("⚠️ Opciones de Leviatán requieren estar en Sea 3")
					elseif S.autoStartLeviathan and Others.spyBribeDone then
						setStatus("🐉 Auto Start Leviatán: Spy listo — esperando Frozen Dimension / Leviatán...")
					else
						setStatus("🐉 En espera de Frozen Dimension, Leviatán o Leviathan Heart...")
					end
				elseif S.autoCollectBerries then
					setStatus("🍓 Escaneando arbustos: 0 Berries activas ahora mismo...")
				else
					setStatus("En espera de eventos, Berries o jefes...")
				end
				return
			end

			ensureTeamSelected()
			local char = LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not hrp or not hum or hum.Health <= 0 then
				setStatus("Esperando aparición del personaje...")
				return
			end

			-- Safe hop check
			if S.hopOnPlayerNear then
				for _, plr in ipairs(Players:GetPlayers()) do
					if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
						if (plr.Character.HumanoidRootPart.Position - hrp.Position).Magnitude < 150 then
							executeServerHop(S.serverHopMode)
							return
						end
					end
				end
			end

			-- ACTIVE RAID PRIORITY: Never abandon an already-started Devil Fruit Raid mid-wave!
			if (S.autoRaid or S.autoAwakeFruit) and Others.isPlayerInRaid(hrp) then
				S.raidTaskRunning = true
				Others.stepRaidFarm(hrp, hum)
				return
			end

			-- STACK PRIORITY 0: COMPLETE SEA PROGRESSION (SEA 1 -> SEA 2 & SEA 2 -> SEA 3 + BARTILO / TREVOR / SWAN / INDRA)
			if S.autoFirstSeaComplete or S.autoSecondSeaComplete then
				S.stackTaskRunning = true
				Stack.stepSeaProgression(hrp, hum)
				return
			end

			-- STACK PRIORITY 1: TELEPORT FRUIT & TELEPORT FRUIT + SERVER HOP
			if spawnedFruit and fruitHandle then
				S.stackTaskRunning = true
				setStatus(string.format("🍎 Teleport Fruit: Yendo por %s [%dm]", tostring(spawnedFruit.Name), math.floor(fruitDist or 0)))
				local reached = moveToCFrame(fruitHandle.CFrame + Vector3.new(0, 2, 0))
				if reached or (hrp.Position - fruitHandle.Position).Magnitude <= 22 then
					hrp.CFrame = fruitHandle.CFrame
					if firetouchinterest then
						pcall(function()
							firetouchinterest(hrp, fruitHandle, 0)
							firetouchinterest(hrp, fruitHandle, 1)
						end)
					end
					S.lastFruitPickupClock = os.clock()
					storeAnyFruitsInInventory()
				end
				return
			elseif S.stackTpFruitHop then
				S.stackTaskRunning = true
				storeAnyFruitsInInventory()
				if (os.clock() - S.spawnedAtClock >= 5.0) and (os.clock() - S.lastFruitPickupClock >= 1.8) then
					clearFarmMover()
					setStatus("🍎 0 frutas en el mapa -> Server Hop...")
					executeServerHop(S.serverHopMode)
				else
					setStatus("🍎 Escaneando frutas del servidor antes de Server Hop...")
				end
				return
			end

			-- STACK PRIORITY 2: ATTACK ACTIVE RAID BOSSES (INDRA, DOUGH KING, SOUL REAPER, DARKBEARD)
			if attackIndraNow then
				S.stackTaskRunning = true
				if liveIndra then
					engageEnemy(liveIndra, nil, "👑 Boss rip_indra")
				else
					local indraPos = Stack.getModelPos(repIndra, Vector3.new(-5560.4, 330.0, -2681.5))
					setStatus("👑 Atacar rip_indra: Yendo a Castle on the Sea...")
					local reached = moveToCFrame(CFrame.new(indraPos))
					if (reached or (hrp.Position - indraPos).Magnitude <= 45) and not repIndra then
						S.indraAlertUntil = 0
					end
				end
				return
			end

			if attackDKNow then
				S.stackTaskRunning = true
				Stack.executeAttackDoughKingStep(liveDK, repDK, hrp)
				return
			end

			if attackReaperNow then
				S.stackTaskRunning = true
				if liveReaper then
					engageEnemy(liveReaper, nil, "💀 Soul Reaper")
				else
					local reaperPos = Stack.getModelPos(repReaper, Vector3.new(-9570.0, 172.1, 6151.0))
					setStatus("💀 Atacar Soul Reaper: Yendo a Haunted Castle...")
					local reached = moveToCFrame(CFrame.new(reaperPos))
					if (reached or (hrp.Position - reaperPos).Magnitude <= 45) and not repReaper then
						S.soulReaperAlertUntil = 0
					end
				end
				return
			end

			if attackDarkbeardNow then
				S.stackTaskRunning = true
				if liveDarkbeard then
					engageEnemy(liveDarkbeard, nil, "🌑 Barbanegra (Darkbeard)")
				else
					local dbPos = Stack.getModelPos(repDarkbeard, Vector3.new(3778.7, 38.0, -3499.4))
					setStatus("🌑 Atacar Barbanegra: Yendo a Dark Arena...")
					local reached = moveToCFrame(CFrame.new(dbPos))
					if (reached or (hrp.Position - dbPos).Magnitude <= 50) and not repDarkbeard then
						S.darkbeardAlertUntil = 0
					end
				end
				return
			end

			-- STACK PRIORITY 3: AUTO TOUCHPAD HAKI & AUTO SUMMON RAID BOSSES (WHEN HOLDING ITEM)
			if pendingHakiPad then
				S.stackTaskRunning = true
				Stack.executeHakiTouchpadStep(pendingHakiPad, hrp)
				return
			end

			if godsChaliceTool then
				S.stackTaskRunning = true
				local map = Workspace:FindFirstChild("Map")
				local bc = map and map:FindFirstChild("Boat Castle")
				local det = bc and bc:FindFirstChild("Summoner") and bc.Summoner:FindFirstChild("Detection")
				Stack.touchSummonPedestal(godsChaliceTool, det, Vector3.new(-5561.2, 314.2, -2669.0), "rip_indra", hrp)
				return
			end

			if hallowEssenceTool then
				S.stackTaskRunning = true
				local map = Workspace:FindFirstChild("Map")
				local hc = map and map:FindFirstChild("Haunted Castle")
				local det = hc and hc:FindFirstChild("Summoner") and hc.Summoner:FindFirstChild("Detection")
				Stack.touchSummonPedestal(hallowEssenceTool, det, Vector3.new(-8932.3, 146.8, 6063.3), "Soul Reaper", hrp)
				return
			end

			if sweetChaliceTool then
				S.stackTaskRunning = true
				Stack.executeSummonDoughKingStep(sweetChaliceTool, hrp)
				return
			end

			if fistOfDarknessTool then
				S.stackTaskRunning = true
				local map = Workspace:FindFirstChild("Map")
				local da = map and map:FindFirstChild("DarkbeardArena")
				local det = da and da:FindFirstChild("Summoner") and da.Summoner:FindFirstChild("Detection")
				Stack.touchSummonPedestal(fistOfDarknessTool, det, Vector3.new(3778.7, 14.9, -3499.4), "Barbanegra (Darkbeard)", hrp)
				return
			end

			-- STACK PRIORITY 4: GAME EVENTS (AUTO FACTORY & AUTO PIRATE RAID)
			if S.wasFightingFactoryCore and not factoryNow then
				S.wasFightingFactoryCore = false
				storeAnyFruitsInInventory()
				setStatus("🏭 Auto Factory completado! Guardando recompensa...")
			elseif factoryNow then
				S.stackTaskRunning = true
				local coreEnemy = Stack.findAliveFactoryCore()
				if coreEnemy then
					S.wasFightingFactoryCore = true
					S.factoryArrivedEmptyClock = 0
					engageEnemy(coreEnemy, nil, "🏭 Auto Factory")
					storeAnyFruitsInInventory()
				else
					local factoryStandPos = Vector3.new(448.5, 199.4, -441.3)
					setStatus("🏭 Auto Factory: Yendo a Smile Factory...")
					local reached = moveToCFrame(CFrame.new(factoryStandPos))
					if reached or (hrp.Position - factoryStandPos).Magnitude <= 35 then
						if S.factoryArrivedEmptyClock == 0 then
							S.factoryArrivedEmptyClock = os.clock()
						elseif (os.clock() - S.factoryArrivedEmptyClock > 5.0) and not Stack.isFactoryDoorOpen() and not ReplicatedStorage:FindFirstChild("Core") then
							S.factoryAlertUntil = 0
							S.factoryArrivedEmptyClock = 0
						end
					end
				end
				return
			end

			if pirateRaidNow then
				S.stackTaskRunning = true
				if raidMob then
					S.pirateRaidArrivedEmptyClock = 0
					engageEnemy(raidMob, nil, "🏴‍☠️ Pirate Raid")
					storeAnyFruitsInInventory()
				else
					local repPos = raidRepMob and raidRepMob:FindFirstChild("HumanoidRootPart") and raidRepMob.HumanoidRootPart.Position
					local castleStandPos = repPos and (repPos + Vector3.new(0, 20, 0)) or Vector3.new(-5543.5, 332.0, -2964.2)
					setStatus("🏴‍☠️ Auto Pirate Raid: Yendo/Esperando oleada en Castle on the Sea...")
					local reached = moveToCFrame(CFrame.new(castleStandPos))
					if (reached or (hrp.Position - castleStandPos).Magnitude <= 45) and not raidRepMob then
						if S.pirateRaidArrivedEmptyClock == 0 then
							S.pirateRaidArrivedEmptyClock = os.clock()
						elseif os.clock() - S.pirateRaidArrivedEmptyClock > 15.0 then
							S.pirateRaidAlertUntil = 0
							S.pirateRaidActiveUntil = 0
							S.pirateRaidArrivedEmptyClock = 0
							storeAnyFruitsInInventory()
						end
					end
				end
				return
			end

			-- STACK PRIORITY 5: ELITE HUNTER & HOP SERVER ELITE HUNTER (SEA 3)
			if eliteNow then
				S.stackTaskRunning = true
				Stack.executeEliteHunterStep(hrp)
				return
			elseif eliteHopNow then
				S.stackTaskRunning = true
				if os.clock() - S.spawnedAtClock >= 6.0 then
					clearFarmMover()
					setStatus("🎯 Sin Elite Pirate activo -> Hop Server Elite Hunter...")
					executeServerHop(S.serverHopMode)
				else
					setStatus("🎯 Verificando Elite Hunter antes de Server Hop...")
				end
				return
			end

			S.stackTaskRunning = false

			-- =========================================================================
			-- RAIDS, SEA EVENTS & FARMING OTHERS EXECUTION
			-- =========================================================================
			if S.autoRaid or S.hopServerRaid or S.autoAwakeFruit then
				if Others.stepRaidFarm(hrp, hum) then
					S.raidTaskRunning = true
					return
				end
			end
			S.raidTaskRunning = false

			if S.autoMultiFindLevi or S.leviOwnerAutoBuyBoat or S.autoStartLeviathan or S.autoAttackLeviathan or S.autoMultiSegmentsLevi or S.autoDeliverLeviHeart then
				if Others.stepLeviathanSuite(hrp, hum) then
					S.seaTaskRunning = true
					return
				end
			end

			if S.tpKitsuneIsland or S.hopNearFullMoon or S.autoSpawnKitsune or S.autoSummonSoulEmber or S.autoCollectSoulEmber or S.autoTradeAzureEmber then
				if Others.stepKitsuneSuite(hrp, hum) then
					S.seaTaskRunning = true
					return
				end
			end

			if S.autoSeaEvent then
				if Others.stepSeaEvents(hrp, hum) then
					S.seaTaskRunning = true
					return
				end
			end
			S.seaTaskRunning = false

			if S.bossFarm or S.allBossFarm or S.hopFindBoss then
				if Others.stepBossFarm(hrp) then
					S.othersTaskRunning = true
					return
				end
			end

			if S.autoLawRaid then
				S.othersTaskRunning = true
				Others.stepLawRaid(hrp, hum)
				return
			end

			if S.autoCollectBerries or S.hopFindBerry then
				if Others.stepBerryFarm(hrp) then
					S.othersTaskRunning = true
					return
				end
			end

			if S.autoDragonHunter then
				S.othersTaskRunning = true
				Others.stepDragonHunter(hrp)
				return
			end

			if S.autoDojoTrainer then
				S.othersTaskRunning = true
				Others.stepDojoTrainer(hrp, hum)
				return
			end

			if S.autoChestFarm or S.autoChestHop then
				S.othersTaskRunning = true
				Others.stepChestFarm(hrp)
				return
			end

			if S.autoObservationFarm or S.hopObservation then
				S.othersTaskRunning = true
				Others.stepObservationFarm(hrp, hum)
				return
			end

			if S.autoKillMob then
				S.othersTaskRunning = true
				Others.stepAutoKillMob(hrp)
				return
			end

			S.othersTaskRunning = false
			if not anyDirectFarm then
				clearFarmMover()
				return
			end

			local mode = S.farmSubMode or "Niveles"

			-- MODE A: BONES FARM
			if mode == "Bones" and S.levelFarm then
				local boneSpawns = collectSpawnsForSet(BoneMobSet)
				local targetSet = (#boneSpawns > 0) and BoneMobSet or nil
				local mob = findAliveEnemyFromSet(targetSet)
				if mob then
					engageEnemy(mob, targetSet, "Bones Farm")
				elseif #boneSpawns > 0 then
					setStatus("Patrullando Haunted Castle para spawnear Skeletons...")
					patrolAroundSpawns("Bones", boneSpawns)
				else
					local bestQ = getBestQuestForPlayer()
					if bestQ then
						setStatus("Patrullando zona actual para Bones/Mobs...")
						patrolAroundSpawns("BonesFallback_" .. bestQ.mobName, bestQ.spawns)
					end
				end
				return
			end

			-- MODE B: KATAKURI (CAKE PRINCE / DOUGH KING)
			if mode == "Katakuri" and S.levelFarm then
				local boss = findAliveEnemyFromSet({["Cake Prince"] = true, ["Dough King"] = true})
				if boss then
					engageEnemy(boss, {["Cake Prince"] = true, ["Dough King"] = true}, "Katakuri Boss")
					return
				end
				local cakeSpawns = collectSpawnsForSet(KatakuriMobSet)
				local targetSet = (#cakeSpawns > 0) and KatakuriMobSet or nil
				local mob = findAliveEnemyFromSet(targetSet)
				if mob then
					engageEnemy(mob, targetSet, "Katakuri Farm")
				elseif #cakeSpawns > 0 then
					setStatus("Patrullando Cake Land para spawnear NPCs de Katakuri...")
					patrolAroundSpawns("Katakuri", cakeSpawns)
				else
					local bestQ = getBestQuestForPlayer()
					if bestQ then
						setStatus("Patrullando zona (Viaja a Third Sea para Cake Land)...")
						patrolAroundSpawns("KatakuriFallback_" .. bestQ.mobName, bestQ.spawns)
					end
				end
				return
			end

			-- MODE C: FARM AURA
			if mode == "Farm Aura" and S.levelFarm then
				ensureBusoHaki()
				local auraRad = math.clamp(tonumber(S.auraDistance) or 300, 0, 1000)
				local mob = (auraRad > 0) and findAliveEnemyFromSet(nil, auraRad) or nil
				if mob then
					engageEnemy(mob, nil, string.format("Farm Aura [%dm]", auraRad))
				else
					setStatus(string.format("Farm Aura: Buscando NPCs en rango (%d studs)...", auraRad))
				end
				return
			end

			-- MODE D: NIVELES (DETERMINISTIC LEVEL 1-2800 QUEST FARM + MASTERY PRIORITY)
			local bestQuest = getBestQuestForPlayer()
			if not bestQuest then
				setStatus("Buscando misión correspondiente a tu nivel (Max Lv. 2800)...")
				return
			end

			if S.autoQuest and CommF_ and bestQuest.questGroup then
				local hasQuest, matchesTarget, activeDesc = getActiveQuestStatus(bestQuest.questGroup, bestQuest.mobName)
				if hasQuest and not matchesTarget then
					setStatus("Abandonando misión anterior (" .. tostring(activeDesc) .. ")...")
					abandonCurrentQuestNonBlocking()
					return
				end
				if not hasQuest then
					local npcTarget = bestQuest.npcCFrame * CFrame.new(0, 4, 3)
					local pRoute = resolveSmartPortalRoute(hrp.Position, npcTarget.Position)
					if pRoute then
						setStatus(string.format("Yendo a %s -> %s (Lv. %d)", pRoute.label, bestQuest.questTitle, bestQuest.levelReq))
					else
						setStatus(string.format("Yendo a misión: %s (Lv. %d)", bestQuest.questTitle, bestQuest.levelReq))
					end
					local reached = moveToCFrame(npcTarget)
					if reached or (hrp.Position - bestQuest.npcCFrame.Position).Magnitude <= 30 then
						requestStartQuestNonBlocking(bestQuest.questGroup, bestQuest.questIndex)
					end
					return
				end
			end

			-- Quest is active (or AutoQuest is off): find alive quest mob or patrol the spawn zone!
			local mobSet = {[bestQuest.mobName] = true}
			local targetMob = findAliveEnemyFromSet(mobSet)
			if targetMob then
				engageEnemy(targetMob, mobSet, "Level Farm (Lv." .. bestQuest.levelReq .. ")")
			else
				setStatus("Patrullando zona para spawnear: " .. bestQuest.mobName)
				patrolAroundSpawns("Quest_" .. bestQuest.mobName, bestQuest.spawns)
			end
		end)
	end
end)

-- Secondary Loop: Auto Stats, Auto Haki/Race, Auto Store Fruits, Low Beli Unstore, Auto Awake, Long-Distance Gacha & Stock
local lastGachaAttempt = 0
local lastStockCheck = 0

do
	local lastLowBeliTick = 0
	local lastAwakeTick = 0

	task.spawn(function()
		while isAlive() do
			task.wait(1.2)
			pcall(function()
				if not isAlive() then return end
				if (S.isChooseTeamScreenOpen and S.isChooseTeamScreenOpen()) or not LocalPlayer.Character then
					return
				end

				-- 1) Auto Stats
				if S.autoStats and CommF_ then
					local pts = LocalPlayer:FindFirstChild("Data") and LocalPlayer.Data:FindFirstChild("Points")
					if pts and pts.Value > 0 then
						CommF_:InvokeServer("AddPoint", S.statTarget, math.min(pts.Value, S.statPointsPerTick))
					end
				end

				-- 2) Auto Ken Haki & Race V3 / V4
				if S.autoKen and CommE then
					pcall(function()
						CommE:FireServer("Ken", true)
					end)
				end
				if S.autoRaceV3 and CommE then
					pcall(function()
						CommE:FireServer("ActivateAbility")
					end)
				end
				if S.autoRaceV4 then
					local char = LocalPlayer.Character
					local bp = LocalPlayer:FindFirstChild("Backpack")
					local awk = (char and char:FindFirstChild("Awakening")) or (bp and bp:FindFirstChild("Awakening"))
					if awk and awk:FindFirstChild("RemoteFunction") then
						pcall(function()
							awk.RemoteFunction:InvokeServer(true)
						end)
					end
				end

				-- 3) Auto Store Fruits (protects 1 Low Beli fruit when Get Fruit in Inventory Low Beli is active!)
				if S.autoStoreFruits then
					storeAnyFruitsInInventory()
				end

				-- 4) Standalone Get Fruit in Inventory Low Beli (keeps 1 cheapest < 1M fruit ready in Backpack; paused during Sea 2 progression!)
				if S.getLowBeliFruit and (not S.autoSecondSeaComplete) and S.unstoreLowestBeliFruit and (os.clock() - lastLowBeliTick > 5.5) then
					if not (S.hasSpecialMicrochipTool and S.hasSpecialMicrochipTool()) and not Others.isPlayerInRaid(nil) then
						lastLowBeliTick = os.clock()
						S.unstoreLowestBeliFruit()
					end
				end

				-- 5) Background Auto Awake Fruit check (awakens equipped fruit moves when in Awakening Room / eligible)
				if S.autoAwakeFruit and Others.tryAutoAwakeFruit and (os.clock() - lastAwakeTick > 5.0) then
					lastAwakeTick = os.clock()
					Others.tryAutoAwakeFruit(false)
				end

				-- 6) Auto Random Devil Fruit (Long Distance via GachaClient, zero movement; paused during Trevor delivery!)
				if S.autoBuyGacha and (not S.trevorDeliveryActive) and (os.clock() - lastGachaAttempt > 45) then
					lastGachaAttempt = os.clock()
					rollRandomFruitGacha()
				end

				-- 7) Auto Buy Selected Fruit Stock (Long Distance via PurchaseRawFruit, zero movement!)
				if S.autoBuyStock and CommF_ and (os.clock() - lastStockCheck > 12) then
					lastStockCheck = os.clock()
					local fruits = CommF_:InvokeServer("GetFruits")
					local beliObj = LocalPlayer:FindFirstChild("Data") and LocalPlayer.Data:FindFirstChild("Beli")
					local myBeli = beliObj and beliObj.Value or 0
					if type(fruits) == "table" then
						for _, f in ipairs(fruits) do
							if f.OnSale and f.Name and S.selectedStockFruits[f.Name] and myBeli >= (tonumber(f.Price) or 0) then
								buyFruitFromStock(f.Name)
								break
							end
						end
					end
				end
			end)
		end
	end)
end

-- BillboardGui ESP Loop
local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "SwitchHub_ESP"
ESPFolder.Parent = ScreenGui

local function updateESPBillboards()
	if not (S.espEnemies or S.espPlayers or S.espFruits or S.espChests) then
		if #ESPFolder:GetChildren() > 0 then
			ESPFolder:ClearAllChildren()
		end
		return
	end
	ESPFolder:ClearAllChildren()
	local myChar = LocalPlayer.Character
	local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
	if not myHrp then return end

	local function createTag(adornee, text, col)
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.new(0, 180, 0, 32)
		bb.StudsOffset = Vector3.new(0, 3.5, 0)
		bb.AlwaysOnTop = true
		bb.Adornee = adornee
		bb.Parent = ESPFolder

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = text
		lbl.Font = Enum.Font.GothamBold
		lbl.TextSize = 12
		lbl.TextColor3 = col
		lbl.TextStrokeTransparency = 0.25
		lbl.Parent = bb
	end

	if S.espEnemies and Workspace:FindFirstChild("Enemies") then
		for _, en in ipairs(Workspace.Enemies:GetChildren()) do
			local hrp = en:FindFirstChild("HumanoidRootPart")
			local hum = en:FindFirstChildOfClass("Humanoid")
			if hrp and hum and hum.Health > 0 then
				local d = math.floor((hrp.Position - myHrp.Position).Magnitude)
				createTag(hrp, string.format("%s [%dm]\nHP: %d/%d", en.Name, d, math.floor(hum.Health), math.floor(hum.MaxHealth)), Color3.fromRGB(255, 95, 86))
			end
		end
	end

	if S.espPlayers then
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
				local hrp = plr.Character.HumanoidRootPart
				local hum = plr.Character:FindFirstChildOfClass("Humanoid")
				local d = math.floor((hrp.Position - myHrp.Position).Magnitude)
				local hp = hum and math.floor(hum.Health) or 0
				createTag(hrp, string.format("👤 %s [%dm] (%d HP)", plr.DisplayName, d, hp), Color3.fromRGB(59, 130, 246))
			end
		end
	end

	if S.espFruits then
		for _, obj in ipairs(Workspace:GetChildren()) do
			if obj ~= myChar and (obj:IsA("Tool") or obj:IsA("Model")) and not Players:GetPlayerFromCharacter(obj) and obj.Name:lower():find("fruit") then
				local handle = obj:FindFirstChild("Handle")
				if handle and handle:IsA("BasePart") then
					local d = math.floor((handle.Position - myHrp.Position).Magnitude)
					createTag(handle, string.format("🍎 %s [%dm]", obj.Name, d), Color3.fromRGB(48, 209, 88))
				end
			end
		end
	end

	if S.espChests then
		local tagged = game:GetService("CollectionService"):GetTagged("_ChestTagged")
		if #tagged > 0 then
			for _, obj in ipairs(tagged) do
				if not obj:GetAttribute("IsDisabled") then
					local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
					if part and part:IsDescendantOf(Workspace) and part:FindFirstChildOfClass("TouchTransmitter") then
						local d = math.floor((part.Position - myHrp.Position).Magnitude)
						createTag(part, string.format("💰 %s [%dm]", obj.Name, d), Color3.fromRGB(255, 214, 10))
					end
				end
			end
		else
			local chestsFolder = Workspace:FindFirstChild("ChestModels") or Workspace:FindFirstChild("Chests")
			local list = chestsFolder and chestsFolder:GetChildren() or Workspace:GetChildren()
			for _, obj in ipairs(list) do
				if obj.Name:find("Chest") then
					local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
					if part then
						local d = math.floor((part.Position - myHrp.Position).Magnitude)
						createTag(part, string.format("💰 %s [%dm]", obj.Name, d), Color3.fromRGB(255, 214, 10))
					end
				end
			end
		end
	end
end

task.spawn(function()
	while isAlive() do
		task.wait(0.8)
		pcall(updateESPBillboards)
	end
end)

--------------------------------------------------------------------------------
-- OPTIMIZATION ENGINE (FPS BOOST, ANTI-LAG COMBAT VFX & MEMORY HYGIENE)
--------------------------------------------------------------------------------
do
	local optimBusy = false

	local function isProtectedVisualInstance(inst)
		if not inst then return true end
		local cur = inst
		while cur and cur ~= Workspace do
			local nm = cur.Name
			if nm == "EmberTemplate" or nm == "AttachedAzureEmber" or nm:find("Ember") or nm:find("Fruit") or nm == "KitsuneIsland" or nm:find("Leviathan") or nm == "FrozenDimension" or nm == "Harpoon" or nm == "CannonBall" then
				return true
			end
			cur = cur.Parent
		end
		return false
	end

	local function muteVFXInstance(inst)
		if not inst or isProtectedVisualInstance(inst) then return end
		if inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam") or inst:IsA("Sparkles") or inst:IsA("Smoke") or inst:IsA("Fire") then
			inst.Enabled = false
		elseif inst:IsA("Explosion") then
			inst.BlastPressure = 0
			inst.Visible = false
		end
	end

	S.runOptimizationPass = function(fullMapScan)
		if optimBusy then return end
		optimBusy = true
		pcall(function()
			if S.fpsBoost then
				local lighting = game:GetService("Lighting")
				lighting.GlobalShadows = false
				for _, eff in ipairs(lighting:GetChildren()) do
					if eff:IsA("PostEffect") then
						eff.Enabled = false
					end
				end
				local terrain = Workspace:FindFirstChildOfClass("Terrain")
				if terrain then
					terrain.WaterWaveSize = 0
					terrain.WaterWaveSpeed = 0
					terrain.WaterReflectance = 0
				end
				pcall(function()
					settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
				end)

				if fullMapScan then
					local map = Workspace:FindFirstChild("Map")
					if map then
						local desc = map:GetDescendants()
						for i, obj in ipairs(desc) do
							if i % 450 == 0 then
								task.wait()
								if not isAlive() or not S.fpsBoost then break end
							end
							if not isProtectedVisualInstance(obj) then
								if obj:IsA("BasePart") then
									obj.CastShadow = false
									obj.Reflectance = 0
									if obj.Material ~= Enum.Material.ForceField and obj.Material ~= Enum.Material.Neon then
										obj.Material = Enum.Material.SmoothPlastic
									end
								elseif obj:IsA("Decal") or obj:IsA("Texture") then
									obj.Transparency = 1
								end
							end
						end
					end
				end
			end

			if S.reduceAttackVFX then
				local wo = Workspace:FindFirstChild("_WorldOrigin")
				if wo then
					for _, ch in ipairs(wo:GetChildren()) do
						if ch:IsA("ParticleEmitter") or ch:IsA("Beam") or ch:IsA("Trail") then
							ch.Enabled = false
						end
					end
				end
				local enemies = Workspace:FindFirstChild("Enemies")
				if enemies then
					for _, e in ipairs(enemies:GetDescendants()) do
						muteVFXInstance(e)
					end
				end
			end
		end)
		optimBusy = false
	end

	connect(Workspace.DescendantAdded, function(inst)
		if S.reduceAttackVFX then
			pcall(muteVFXInstance, inst)
		end
		if S.fpsBoost and inst:IsA("BasePart") and not isProtectedVisualInstance(inst) then
			pcall(function()
				inst.CastShadow = false
				inst.Reflectance = 0
			end)
		end
	end)

	task.spawn(function()
		local lastMemClean = os.clock()
		while isAlive() do
			task.wait(8.0)
			pcall(function()
				if S.fpsBoost or S.reduceAttackVFX then
					S.runOptimizationPass(false)
				end
				if S.optimizeMemory and (os.clock() - lastMemClean >= 25.0) then
					lastMemClean = os.clock()
					if S.lastAimEnemy and not S.lastAimEnemy.Parent then
						S.lastAimEnemy = nil
						S.lastAimPart = nil
					end
				end
			end)
		end
	end)
end

pcall(function()
	if typeof(writefile) == "function" then
		writefile("mcp/switch_hub_loaded", tostring(os.time()))
	end
end)
