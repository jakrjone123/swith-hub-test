-- Switch Hub [ Series X ] | All-In-One Kaitun Edition (Version 2 - Standalone Codebase)
-- Separate project from Switch Hub V1 (switch_hub_bloxfruits.luau)
-- One-Click Autonomous Progression:
--   Tier 1: Priority Raid/World Bosses (Katakuri V2 / Dough King -> Mirror Fractal, Rip Indra -> Valkyrie Helm,
--           Katakuri V1 / Cake Prince -> Spikey Trident, Soul Reaper -> Hallow Scythe, Darkbeard -> Dark Fragment)
--   Tier 2: Level 1 -> Max (2800) + Sea 1 -> Sea 2 -> Sea 3 Story Quests + Automatic Melee Mastery Rotation
--   Tier 3: Full Godhuman Pipeline (All Prerequisite Styles Mastery 400 + Material Farming + Purchase)
--   Tier 4: Cursed Dual Katana (Yama 30 Elites + Tushita 5 Torches/Longma + 350 Mastery + Crypt Trials)
--   Tier 5: Soul Guitar (500 Bones + 250 Ectoplasm + Dark Fragment + Full Moon 6-Stage Puzzle)
--   Tier 6: Priority Swords & Guns Unlock (Rengoku, Midnight Blade, Buddy Sword, Canvander, Koko, TTK, Kabucha, etc.)
--   Tier 7: Final Endgame — Mirage Island + Mirror Fractal Moon Resonance + Blue Gear + Temple Lever

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

--------------------------------------------------------------------------------
-- 1. ISOLATED RUNTIME STATE & PREVIOUS KAITUN INSTANCE CLEANUP
--------------------------------------------------------------------------------
local genv = (getgenv and getgenv()) or _G

do
	local prev = genv.__SwitchHubSeriesX_Kaitun
	if type(prev) == "table" then
		prev.alive = false
		prev.autoFarm = false
		prev.runId = -1
		if prev.activeTween then
			pcall(function() prev.activeTween:Cancel() end)
			prev.activeTween = nil
		end
		if prev.afkMode then
			pcall(function() RunService:Set3dRenderingEnabled(true) end)
		end
		if type(prev.connections) == "table" then
			for _, c in ipairs(prev.connections) do
				pcall(function() c:Disconnect() end)
			end
			prev.connections = {}
		end
	end

	local hui = (gethui and gethui()) or CoreGui
	for _, container in ipairs({CoreGui, hui}) do
		if container then
			for _, ch in ipairs(container:GetChildren()) do
				if ch.Name == "SwitchHub_SeriesX_Kaitun" or ch.Name == "SwitchHub_SeriesX_AFK" then
					pcall(function() ch:Destroy() end)
				end
			end
		end
	end
end

local KX = {
	runId = math.random(100000, 999999),
	alive = true,
	connections = {},
	startTime = os.time(),
	spawnedAtClock = os.clock(),

	-- Master 1-Click Kaitun Switch
	autoFarm = false,
	preferredTeam = "Pirates",
	statusText = "Idle (Ready)",
	phaseText = "Standby",

	-- Settings (⚙️ Tab)
	autoSpinAndStoreFruits = true,
	autoGrabGroundFruits = true,
	autoEatAllowedFruits = false, -- Stores all spun fruits first; eats ONLY if enabled & fruit is checked below
	allowedEatFruits = {
		["Buddha-Buddha"] = true,
		["Light-Light"] = true,
		["Magma-Magma"] = true,
		["Ice-Ice"] = true,
		["Flame-Flame"] = false,
		["Kitsune-Kitsune"] = false,
		["Gas-Gas"] = false,
	},
	smart2xExpCodes = true,
	autoStats = true,
	autoBuso = true,
	autoKen = true,
	autoRaceV3 = true,
	smartServerHop = true,
	autoRaid = true, -- Priority Auto Dungeon Raid over Level Farm (uses fruits <= 1,000,000 Beli)
	raidKillAuraUpTo3 = true, -- Kill Aura active on Islands 1-3 + Fighting Style (Melee) on all islands
	selectedRaidType = "Auto", -- "Auto" (matches fruit or Flame), "Flame", "Ice", "Light", "Magma", "Buddha", "Dark"
	tweenSpeed = 185, -- Balanced anti-rubberband speed (165 Segura / 185 Moderada / 205 Rápida)
	attackInterval = 0.095, -- Moderate fast-click cadence (~10.5 clicks/sec, safe & smooth)
	noAttackAnimation = true, -- Removes character M1 swing/hit animation & lunge
	fpsBoost = false,
	afkMode = false,

	-- Redeemed / Expired 2x EXP Codes Persistence
	redeemedCodes = {},
	expBoostUntilClock = 0,
	hudExpSeconds = 0,
	lastCodeAttemptClock = 0,

	-- Live Game State Snapshot (Updated Continuously for UI & Brain)
	worldNum = 1,
	level = 1,
	maxLevel = 2800,
	beli = 0,
	fragments = 0,
	devilFruit = "None",
	awakenedText = "-",
	eliteProgress = 0,

	-- Live Ownership Maps & Real-Time Weapon Telemetry
	currentMeleeToolName = "None",
	currentMeleeCanon = "None",
	currentMeleeIcon = "🥊",
	currentMeleeLevel = 0,
	currentMeleeExp = 0,
	currentMeleeMaxExp = 1,
	currentMeleePct = 0,
	ownedMelees = {},
	meleeMastery = {},
	meleeExp = {},
	meleeMaxExp = {},
	ownedSwords = {},
	swordMastery = {},
	ownedGuns = {},
	gunMastery = {},
	ownedAccessories = {},
	materials = {
		["Bones"] = 0,
		["Ectoplasm"] = 0,
		["Dark Fragment"] = 0,
		["Conjured Cocoa"] = 0,
		["Alucard Fragment"] = 0,
		["Fish Tail"] = 0,
		["Magma Ore"] = 0,
		["Mystic Droplet"] = 0,
		["Dragon Scale"] = 0,
		["Fire Essence"] = 0,
	},
	questsDone = {
		saber = false,
		dressrosa = false,
		bartilo = false,
		donSwan = false,
		ripIndraSea2 = false,
		deathStep = false,
		sharkmanKarate = false,
		electricClaw = false,
		dragonTalon = false,
		mirrorFractal = false,
		pullLever = false,
		blueGear = false,
	},

	-- Navigation, Raid & Combat Runtime
	activeTween = nil,
	activeTweenTargetPos = nil,
	lastAimEnemy = nil,
	lastAimPart = nil,
	lastAimPos = nil,
	lastCombatTool = nil,
	protectedTool = nil,
	storedFruits = {},
	wasInRaid = false,
	raidIslandIdx = 1,
	raidCooldownUntil = 0,
	lastRaidStatus = "Standby",
	failedStoreCooldown = {},
	fruitAttemptStart = {},
	ignoredFruits = {},
	styleSwitchCooldown = {},
	uiRefreshCallbacks = {},
}

genv.__SwitchHubSeriesX_Kaitun = KX
local MY_RUN_ID = KX.runId

local function isAlive()
	return KX.alive and KX.runId == MY_RUN_ID and genv.__SwitchHubSeriesX_Kaitun == KX
end

local function connect(sig, fn)
	local c = sig:Connect(fn)
	table.insert(KX.connections, c)
	return c
end

local function setStatus(statusMsg, phaseMsg)
	KX.statusText = tostring(statusMsg or "Idle")
	if phaseMsg then
		KX.phaseText = tostring(phaseMsg)
	end
end

--------------------------------------------------------------------------------
-- 2. PERSISTENT CONFIG & SMART 2x EXP CODE STATE (PER USER ID)
--------------------------------------------------------------------------------
local CONFIG_FOLDER = "SwitchHub_SeriesX"
local CONFIG_FILE = CONFIG_FOLDER .. "/kaitun_" .. tostring(LocalPlayer and LocalPlayer.UserId or 0) .. ".json"

local function saveConfig()
	if typeof(writefile) ~= "function" then return end
	pcall(function()
		if typeof(isfolder) == "function" and typeof(makefolder) == "function" and not isfolder(CONFIG_FOLDER) then
			makefolder(CONFIG_FOLDER)
		end
		local payload = {
			autoFarm = KX.autoFarm,
			preferredTeam = KX.preferredTeam,
			autoSpinAndStoreFruits = KX.autoSpinAndStoreFruits,
			autoGrabGroundFruits = KX.autoGrabGroundFruits,
			autoEatAllowedFruits = KX.autoEatAllowedFruits,
			allowedEatFruits = KX.allowedEatFruits,
			smart2xExpCodes = KX.smart2xExpCodes,
			autoStats = KX.autoStats,
			autoBuso = KX.autoBuso,
			autoKen = KX.autoKen,
			autoRaceV3 = KX.autoRaceV3,
			smartServerHop = KX.smartServerHop,
			autoRaid = KX.autoRaid,
			raidKillAuraUpTo3 = KX.raidKillAuraUpTo3,
			selectedRaidType = KX.selectedRaidType,
			tweenSpeed = KX.tweenSpeed,
			noAttackAnimation = KX.noAttackAnimation,
			fpsBoost = KX.fpsBoost,
			afkMode = KX.afkMode,
			redeemedCodes = KX.redeemedCodes,
			ownedMelees = KX.ownedMelees,
			meleeMastery = KX.meleeMastery,
			meleeExp = KX.meleeExp,
			meleeMaxExp = KX.meleeMaxExp,
		}
		writefile(CONFIG_FILE, HttpService:JSONEncode(payload))
	end)
end

local function loadConfig()
	if typeof(readfile) ~= "function" or typeof(isfile) ~= "function" then return end
	pcall(function()
		if not isfile(CONFIG_FILE) then return end
		local raw = readfile(CONFIG_FILE)
		local decoded = HttpService:JSONDecode(raw)
		if type(decoded) ~= "table" then return end
		if type(decoded.autoFarm) == "boolean" then KX.autoFarm = decoded.autoFarm end
		if type(decoded.preferredTeam) == "string" then KX.preferredTeam = decoded.preferredTeam end
		if type(decoded.autoSpinAndStoreFruits) == "boolean" then KX.autoSpinAndStoreFruits = decoded.autoSpinAndStoreFruits end
		if type(decoded.autoGrabGroundFruits) == "boolean" then KX.autoGrabGroundFruits = decoded.autoGrabGroundFruits end
		if type(decoded.autoEatAllowedFruits) == "boolean" then KX.autoEatAllowedFruits = decoded.autoEatAllowedFruits end
		if type(decoded.allowedEatFruits) == "table" then
			for k, v in pairs(decoded.allowedEatFruits) do
				KX.allowedEatFruits[tostring(k)] = (v == true)
			end
		end
		if type(decoded.smart2xExpCodes) == "boolean" then KX.smart2xExpCodes = decoded.smart2xExpCodes end
		if type(decoded.autoStats) == "boolean" then KX.autoStats = decoded.autoStats end
		if type(decoded.autoBuso) == "boolean" then KX.autoBuso = decoded.autoBuso end
		if type(decoded.autoKen) == "boolean" then KX.autoKen = decoded.autoKen end
		if type(decoded.autoRaceV3) == "boolean" then KX.autoRaceV3 = decoded.autoRaceV3 end
		if type(decoded.smartServerHop) == "boolean" then KX.smartServerHop = decoded.smartServerHop end
		if type(decoded.autoRaid) == "boolean" then KX.autoRaid = decoded.autoRaid end
		if type(decoded.raidKillAuraUpTo3) == "boolean" then KX.raidKillAuraUpTo3 = decoded.raidKillAuraUpTo3 end
		if type(decoded.selectedRaidType) == "string" then KX.selectedRaidType = decoded.selectedRaidType end
		if tonumber(decoded.tweenSpeed) then
			KX.tweenSpeed = math.clamp(math.floor(tonumber(decoded.tweenSpeed)), 160, 210)
		end
		if type(decoded.noAttackAnimation) == "boolean" then
			KX.noAttackAnimation = decoded.noAttackAnimation
		end
		if type(decoded.fpsBoost) == "boolean" then KX.fpsBoost = decoded.fpsBoost end
		if type(decoded.afkMode) == "boolean" then KX.afkMode = decoded.afkMode end
		if type(decoded.redeemedCodes) == "table" then
			for k, v in pairs(decoded.redeemedCodes) do
				if v then KX.redeemedCodes[tostring(k)] = true end
			end
		end
		if type(decoded.ownedMelees) == "table" then
			for k, v in pairs(decoded.ownedMelees) do
				if v then KX.ownedMelees[tostring(k)] = true end
			end
		end
		if type(decoded.meleeMastery) == "table" then
			for k, v in pairs(decoded.meleeMastery) do
				local n = tonumber(v)
				if n and n > 0 then KX.meleeMastery[tostring(k)] = n end
			end
		end
		if type(decoded.meleeExp) == "table" then
			for k, v in pairs(decoded.meleeExp) do
				local n = tonumber(v)
				if n and n >= 0 then KX.meleeExp[tostring(k)] = n end
			end
		end
		if type(decoded.meleeMaxExp) == "table" then
			for k, v in pairs(decoded.meleeMaxExp) do
				local n = tonumber(v)
				if n and n > 0 then KX.meleeMaxExp[tostring(k)] = n end
			end
		end
	end)
end
loadConfig()

--------------------------------------------------------------------------------
-- 3. REMOTES, SEA DETECTION & LAZY GAME MODULE INITIALIZER (NO METAMETHODS!)
--------------------------------------------------------------------------------
if not game:IsLoaded() then
	pcall(function() game.Loaded:Wait() end)
end

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
local CommF_ = Remotes and Remotes:WaitForChild("CommF_", 10)
local CommE = Remotes and Remotes:WaitForChild("CommE", 5)
local RedeemRF = Remotes and Remotes:FindFirstChild("Redeem")

local QuestsModule = nil
local GuideModule = nil
local GuideData = nil
local CombatController = nil
local AimAssistModule = nil
local CombatUtil = nil
local GlobalModule = nil
local MouseModule = nil

genv.__SwitchHubSeriesX_OrigHooks = genv.__SwitchHubSeriesX_OrigHooks or {}
local OrigHooks = genv.__SwitchHubSeriesX_OrigHooks

local function isChooseTeamScreenOpen()
	if not LocalPlayer.Team or LocalPlayer.Team.Name == "Neutral" then
		return true
	end
	local pgui = LocalPlayer:FindFirstChild("PlayerGui")
	if pgui then
		for _, gName in ipairs({"Main (minimal)", "Main"}) do
			local g = pgui:FindFirstChild(gName)
			local ct = g and g:FindFirstChild("ChooseTeam")
			if ct and ct:IsA("GuiObject") and ct.Visible then
				return true
			end
		end
	end
	return false
end
KX.isChooseTeamScreenOpen = isChooseTeamScreenOpen

local function getCurrentSeaNumber()
	local pid = game.PlaceId
	if pid == 4442272183 or pid == 79091703265657 then
		return 2
	elseif pid == 7449423635 or pid == 100117331123089 then
		return 3
	elseif pid == 2753915549 or pid == 85211729168715 then
		return 1
	end
	local locs = Workspace:FindFirstChild("_WorldOrigin") and Workspace._WorldOrigin:FindFirstChild("Locations")
	if locs then
		if locs:FindFirstChild("Tiki Outpost") or locs:FindFirstChild("Castle on the Sea") then
			return 3
		elseif locs:FindFirstChild("Kingdom of Rose") or locs:FindFirstChild("Hot and Cold") then
			return 2
		end
	end
	local map = Workspace:FindFirstChild("Map")
	if map then
		if map:FindFirstChild("Turtle") or map:FindFirstChild("Boat Castle") then
			return 3
		elseif map:FindFirstChild("Dressrosa") or map:FindFirstChild("GhostShip") then
			return 2
		end
	end
	return 1
end
KX.getCurrentSeaNumber = getCurrentSeaNumber

local function getActiveAimPart()
	local cur = genv.__SwitchHubSeriesX_Kaitun
	if not cur or not cur.alive or not cur.autoFarm then
		return nil, nil
	end
	local part, model = cur.lastAimPart, cur.lastAimEnemy
	if part and part.Parent and model and model.Parent then
		local eHum = model:FindFirstChildOfClass("Humanoid")
		local hVal = model:FindFirstChild("Health")
		local alive = (eHum and eHum.Health > 0)
			or (hVal and hVal:IsA("ValueBase") and (tonumber(hVal.Value) or 0) > 0)
		if alive then
			return part, model
		end
	end
	return nil, nil
end
genv.__SwitchHubSeriesX_GetAim = getActiveAimPart

do
	local function installPureLuaAimWrappers()
		if AimAssistModule and type(AimAssistModule.getTargetInfo) == "function" then
			if not OrigHooks.getTargetInfo then
				OrigHooks.getTargetInfo = AimAssistModule.getTargetInfo
			end
			AimAssistModule.getTargetInfo = function(...)
				local getter = genv.__SwitchHubSeriesX_GetAim
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

		if CombatUtil and type(CombatUtil.GetTargetPosition) == "function" then
			if not OrigHooks.GetTargetPosition then
				OrigHooks.GetTargetPosition = CombatUtil.GetTargetPosition
			end
			CombatUtil.GetTargetPosition = function(self, originPos, aimPos, range)
				local getter = genv.__SwitchHubSeriesX_GetAim
				local part = getter and getter()
				if part then
					return part.Position
				end
				return OrigHooks.GetTargetPosition(self, originPos, aimPos, range)
			end
		end

		if CombatUtil and type(CombatUtil.CreateShootAngles) == "function" then
			if not OrigHooks.CreateShootAngles then
				OrigHooks.CreateShootAngles = CombatUtil.CreateShootAngles
			end
			CombatUtil.CreateShootAngles = function(self, shootData)
				local getter = genv.__SwitchHubSeriesX_GetAim
				local part = getter and getter()
				if part then
					local count = (type(shootData) == "table" and tonumber(shootData.BulletSpreadCount)) or 1
					local out = {}
					for i = 1, math.max(1, count) do
						out[i] = {Angle = CFrame.Angles(0, 0, 0)}
					end
					return out
				end
				return OrigHooks.CreateShootAngles(self, shootData)
			end
		end

		if GlobalModule and type(GlobalModule.updateMouseWrapper) == "function" then
			if not OrigHooks.updateMouseWrapper then
				OrigHooks.updateMouseWrapper = GlobalModule.updateMouseWrapper
			end
			GlobalModule.updateMouseWrapper = function(...)
				local ret = OrigHooks.updateMouseWrapper(...)
				local getter = genv.__SwitchHubSeriesX_GetAim
				local part = getter and getter()
				if part and MouseModule then
					pcall(function()
						local char = LocalPlayer.Character
						local hrp = char and char:FindFirstChild("HumanoidRootPart")
						local orig = (hrp and hrp.Position) or (part.Position + Vector3.new(0, 20, 0))
						local dir = part.Position - orig
						local unitDir = (dir.Magnitude > 0.001) and dir.Unit or Vector3.new(0, -1, 0)
						MouseModule.Hit = CFrame.lookAt(part.Position, part.Position + unitDir)
						MouseModule.Target = part
						MouseModule.Origin = CFrame.lookAt(orig, part.Position)
						MouseModule.UnitRay = Ray.new(orig, unitDir)
					end)
				end
				return ret
			end
		end
	end

	KX.ensureModulesReady = function(onlyData)
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
		if onlyData or isChooseTeamScreenOpen() or not LocalPlayer.Character then
			return
		end

		local loadedAny = false
		if not CombatController then
			pcall(function()
				local c = ReplicatedStorage:FindFirstChild("Controllers")
				local cc = c and c:FindFirstChild("CombatController")
				if cc then CombatController = require(cc); loadedAny = true end
			end)
		end
		if not AimAssistModule then
			pcall(function()
				local c = ReplicatedStorage:FindFirstChild("Controllers")
				local cc = c and c:FindFirstChild("CombatController")
				local aa = cc and cc:FindFirstChild("AimAssist")
				if aa then AimAssistModule = require(aa); loadedAny = true end
			end)
		end
		if not CombatUtil then
			pcall(function()
				local m = ReplicatedStorage:FindFirstChild("Modules")
				local cu = m and m:FindFirstChild("CombatUtil")
				if cu then CombatUtil = require(cu); loadedAny = true end
			end)
		end
		if not GlobalModule then
			pcall(function()
				local gl = ReplicatedStorage:FindFirstChild("Global")
				if gl then GlobalModule = require(gl); loadedAny = true end
			end)
		end
		if not MouseModule then
			pcall(function()
				local ms = ReplicatedStorage:FindFirstChild("Mouse")
				if ms then MouseModule = require(ms); loadedAny = true end
			end)
		end
		if loadedAny then
			installPureLuaAimWrappers()
		end
	end
end

--------------------------------------------------------------------------------
-- 4. CANONICAL ITEM LISTS, SMART 2x EXP CODES & REAL-TIME MELEE/EXP SCANNER
--------------------------------------------------------------------------------
local MELEE_ENTRIES = {
	{ui = "Dark Step", icon = "🦵", keys = {"Black Leg", "Dark Step"}},
	{ui = "Electro", icon = "⚡", keys = {"Electro", "Electric"}},
	{ui = "Water Kung Fu", icon = "🌊", keys = {"Fishman Karate", "Water Kung Fu"}},
	{ui = "Dragon Breath", icon = "🐉", keys = {"Dragon Claw", "Dragon Breath"}},
	{ui = "Superhuman", icon = "💥", keys = {"Superhuman"}},
	{ui = "Death Step", icon = "🔥", keys = {"Death Step"}},
	{ui = "Sharkman Karate", icon = "🦈", keys = {"Sharkman Karate"}},
	{ui = "Electric Claw", icon = "🌩️", keys = {"Electric Claw"}},
	{ui = "Dragon Talon", icon = "🐲", keys = {"Dragon Talon"}},
	{ui = "Godhuman", icon = "🌟", keys = {"Godhuman"}},
	{ui = "Sanguine Art", icon = "🩸", keys = {"Sanguine Art"}},
}

local SWORD_LIST = {
	{ui = "Saber", icon = "🗡️", keys = {"Saber"}},
	{ui = "Bisento", icon = "🔱", keys = {"Bisento"}},
	{ui = "Soul Cane", icon = "🦯", keys = {"Soul Cane"}},
	{ui = "Rengoku", icon = "🔥", keys = {"Rengoku"}},
	{ui = "Yama", icon = "👹", keys = {"Yama"}},
	{ui = "Koko", icon = "⚡", keys = {"Koko"}},
	{ui = "Spikey Trident", icon = "🍩", keys = {"Spikey Trident"}},
	{ui = "Buddy Sword", icon = "🎀", keys = {"Buddy Sword"}},
	{ui = "Canvander", icon = "🌸", keys = {"Canvander", "Cavender"}},
	{ui = "Tushita", icon = "✨", keys = {"Tushita"}},
	{ui = "Hallow Scythe", icon = "💀", keys = {"Hallow Scythe"}},
	{ui = "Midnight Blade", icon = "🌑", keys = {"Midnight Blade"}},
	{ui = "Shizu", icon = "💧", keys = {"Shizu", "Shisui"}},
	{ui = "Saishi", icon = "🍃", keys = {"Saishi", "Saddi"}},
	{ui = "Oroshi", icon = "🌪️", keys = {"Oroshi", "Wando"}},
	{ui = "Dark Dagger", icon = "🗡️", keys = {"Dark Dagger"}},
	{ui = "True Triple Katana", icon = "⚔️", keys = {"True Triple Katana"}},
	{ui = "Cursed Dual Katana", icon = "🩸", keys = {"Cursed Dual Katana"}},
}

local GUN_LIST = {
	{ui = "Soul Guitar", icon = "🎸", keys = {"Soul Guitar", "Skull Guitar"}},
	{ui = "Venom Bow", icon = "🏹", keys = {"Venom Bow"}},
	{ui = "Kabucha", icon = "🎯", keys = {"Kabucha"}},
	{ui = "Acidum Rifle", icon = "🧪", keys = {"Acidum Rifle"}},
	{ui = "Serpent Bow", icon = "🐍", keys = {"Serpent Bow"}},
	{ui = "Bizarre Rifle", icon = "🔮", keys = {"Bizarre Rifle"}},
}

-- Strictly 2x EXP codes ONLY (NO stat reset codes included!)
local EXP_CODES_ORDERED = {
	"Sub2CaptainMaui",
	"DEVSCOOKING",
	"KITTGAMING",
	"Sub2Fer999",
	"Enyu_is_Pro",
	"Magicbus",
	"JCWK",
	"Starcodeheo",
	"Bluxxy",
	"fudd10_v2",
	"SUB2GAMERROBOT_EXP1",
	"Sub2NoobMaster123",
	"Sub2Daigrock",
	"Axiore",
	"TantaiGaming",
	"StrawHatMaine",
	"Sub2OfficialNoobie",
	"TheGreatAce",
	"BANEXPLOIT",
	"NOMOREHACK",
	"WildDares",
	"BossBuild",
	"GetPranked",
	"EARN_FRUITS",
	"FIGHT4FRUIT",
	"NOEXPLOITER",
	"NOOB2ADMIN",
	"CODESLIDE",
	"ADMINDARES",
	"krazydares",
	"TRIPLEABUSE",
	"SEATROLLING",
	"24NOADMIN",
	"REWARDFUN",
	"NEWTROLL",
	"SECRET_ADMIN",
}

do
	local MELEE_ALIAS_MAP = {
		["combat"] = {ui = "Combat", icon = "👊"},
	}
	for _, entry in ipairs(MELEE_ENTRIES) do
		MELEE_ALIAS_MAP[entry.ui:lower()] = entry
		for _, k in ipairs(entry.keys) do
			MELEE_ALIAS_MAP[k:lower()] = entry
		end
	end

	function KX.resolveMeleeCanonical(rawName)
		local clean = tostring(rawName or ""):gsub("^%s+", ""):gsub("%s+$", "")
		local hit = MELEE_ALIAS_MAP[clean:lower()]
		if hit then
			return hit.ui, hit.icon
		end
		return clean ~= "" and clean or "None", "🥊"
	end

	function KX.calcMasteryMaxExp(lvl)
		lvl = math.max(1, tonumber(lvl) or 1)
		if lvl >= 600 then
			return 0
		end
		return math.floor((lvl ^ 2.26) + 69)
	end

	local function parseHudEquippedExpPair()
		local pgui = LocalPlayer:FindFirstChild("PlayerGui")
		if not pgui then return nil, nil end
		local mainGui = pgui:FindFirstChild("Main") or pgui:FindFirstChild("Main (minimal)")
		if not mainGui then return nil, nil end
		local candidates = {}
		local sk = mainGui:FindFirstChild("Skills")
		if sk and sk:FindFirstChild("Level") and sk.Level:FindFirstChild("Exp") then
			table.insert(candidates, sk.Level.Exp)
		end
		local mob = mainGui:FindFirstChild("MobileMasteryLevel")
		if mob and mob:FindFirstChild("Exp") then
			table.insert(candidates, mob.Exp)
		end
		for _, lbl in ipairs(candidates) do
			if lbl:IsA("TextLabel") then
				local cleaned = tostring(lbl.Text or ""):gsub(",", ""):gsub("%s+", "")
				local cStr, mStr = cleaned:match("(%d+)/(%d+)")
				local cNum, mNum = tonumber(cStr), tonumber(mStr)
				if cNum and mNum and mNum > 0 then
					return cNum, mNum
				end
			end
		end
		return nil, nil
	end

	-- Fast zero-yield scanner (safe to call every 0.3s for real-time Melee & EXP UI)
	KX.scanRealtimeMeleeAndWeapons = function()
		local char = LocalPlayer.Character
		local bp = LocalPlayer:FindFirstChild("Backpack")
		local foundActiveMelee = nil
		local activeInChar = false

		for idx, container in ipairs({char, bp}) do
			if container then
				for _, t in ipairs(container:GetChildren()) do
					if t:IsA("Tool") then
						local lvObj = t:FindFirstChild("Level")
						local expObj = t:FindFirstChild("Exp")
						local mast = (lvObj and tonumber(lvObj.Value)) or tonumber(t:GetAttribute("Level")) or 0
						local expVal = (expObj and tonumber(expObj.Value)) or tonumber(t:GetAttribute("Exp")) or 0

						if t.ToolTip == "Melee" then
							if not foundActiveMelee then
								foundActiveMelee = t
								activeInChar = (idx == 1)
							end
							local canonName, canonIcon = KX.resolveMeleeCanonical(t.Name)
							local maxExpVal = KX.calcMasteryMaxExp(mast)
							if activeInChar then
								local hudCur, hudMax = parseHudEquippedExpPair()
								if hudCur and hudMax and math.abs(hudCur - expVal) <= 5 then
									maxExpVal = hudMax
								end
							elseif (KX.meleeMaxExp[canonName] or 0) > 0 and (KX.meleeMastery[canonName] == mast) then
								maxExpVal = KX.meleeMaxExp[canonName]
							end

							KX.ownedMelees[t.Name] = true
							KX.ownedMelees[canonName] = true
							KX.meleeMastery[t.Name] = math.max(KX.meleeMastery[t.Name] or 0, mast)
							KX.meleeMastery[canonName] = math.max(KX.meleeMastery[canonName] or 0, mast)
							KX.meleeExp[canonName] = math.floor(expVal)
							KX.meleeMaxExp[canonName] = maxExpVal

							if t == foundActiveMelee then
								KX.currentMeleeToolName = t.Name
								KX.currentMeleeCanon = canonName
								KX.currentMeleeIcon = canonIcon
								KX.currentMeleeLevel = mast
								KX.currentMeleeExp = math.floor(expVal)
								KX.currentMeleeMaxExp = maxExpVal
								if mast >= 600 then
									KX.currentMeleePct = 100
								elseif maxExpVal > 0 then
									KX.currentMeleePct = math.clamp((expVal / maxExpVal) * 100, 0, 100)
								else
									KX.currentMeleePct = 0
								end
							end
						elseif t.ToolTip == "Sword" then
							KX.ownedSwords[t.Name] = true
							KX.swordMastery[t.Name] = math.max(KX.swordMastery[t.Name] or 0, mast)
						elseif t.ToolTip == "Gun" then
							KX.ownedGuns[t.Name] = true
							KX.gunMastery[t.Name] = math.max(KX.gunMastery[t.Name] or 0, mast)
						end
					end
				end
			end
		end

		-- Match Sword/Gun aliases onto UI canonical names continuously
		for _, entry in ipairs(SWORD_LIST) do
			for _, k in ipairs(entry.keys) do
				if KX.ownedSwords[k] then
					KX.ownedSwords[entry.ui] = true
					if (KX.swordMastery[k] or 0) > (KX.swordMastery[entry.ui] or 0) then
						KX.swordMastery[entry.ui] = KX.swordMastery[k]
					end
				end
			end
		end
		for _, entry in ipairs(GUN_LIST) do
			for _, k in ipairs(entry.keys) do
				if KX.ownedGuns[k] then
					KX.ownedGuns[entry.ui] = true
					if (KX.gunMastery[k] or 0) > (KX.gunMastery[entry.ui] or 0) then
						KX.gunMastery[entry.ui] = KX.gunMastery[k]
					end
				end
			end
		end
	end

	local function parseHud2xExpSeconds()
		local pgui = LocalPlayer:FindFirstChild("PlayerGui")
		if not pgui then return 0 end
		for _, gName in ipairs({"Main", "Main (minimal)", "HUDRoot"}) do
			local g = pgui:FindFirstChild(gName)
			if g then
				for _, d in ipairs(g:GetDescendants()) do
					if d:IsA("TextLabel") and d.Visible then
						local txt = d.Text or ""
						local low = txt:lower()
						if low:find("2x exp") or low:find("x2 exp") or low:find("exp boost") or low:find("double exp") then
							local h, m, s = txt:match("(%d+)%s*:%s*(%d+)%s*:%s*(%d+)")
							if h and m and s then
								return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s)
							end
							local m2, s2 = txt:match("(%d+)%s*:%s*(%d+)")
							if m2 and s2 then
								return tonumber(m2) * 60 + tonumber(s2)
							end
							local mins = low:match("(%d+)%s*m")
							local secs = low:match("(%d+)%s*s")
							if mins or secs then
								return (tonumber(mins) or 0) * 60 + (tonumber(secs) or 0)
							end
							return 60
						end
					end
				end
			end
		end
		return 0
	end

	KX.getRemaining2xExpSeconds = function()
		local hudSec = parseHud2xExpSeconds()
		KX.hudExpSeconds = hudSec
		local localRem = math.max(0, math.floor(KX.expBoostUntilClock - os.clock()))
		return math.max(hudSec, localRem)
	end

	-- Redeems ONE 2x EXP code only when active timer == 0, then waits until it finishes before redeeming the next!
	KX.stepSmart2xExpCodes = function()
		if not KX.smart2xExpCodes or not KX.autoFarm then return end
		if isChooseTeamScreenOpen() then return end
		if KX.level >= KX.maxLevel then return end
		if KX.getRemaining2xExpSeconds() > 0 then return end
		if os.clock() - KX.lastCodeAttemptClock < 4.0 then return end

		if not RedeemRF then
			RedeemRF = Remotes and Remotes:FindFirstChild("Redeem")
		end
		if not RedeemRF then return end

		for _, code in ipairs(EXP_CODES_ORDERED) do
			if not KX.redeemedCodes[code] then
				KX.lastCodeAttemptClock = os.clock()
				KX.redeemedCodes[code] = true
				saveConfig()

				local ok, res = pcall(function()
					return RedeemRF:InvokeServer(code)
				end)
				local msg = tostring(res or ""):lower()
				task.wait(1.0)
				local afterSec = KX.getRemaining2xExpSeconds()

				if afterSec > 0 or (ok and (msg:find("success") or msg:find("2x") or msg:find("exp") or msg:find("minute") or msg:find("redeem")) and not msg:find("already") and not msg:find("invalid") and not msg:find("expired")) then
					if afterSec <= 0 then
						-- Fallback 15-minute guard if HUD takes a moment to render
						KX.expBoostUntilClock = os.clock() + (15 * 60)
					end
					setStatus("⚡ Código 2x EXP activado: " .. code, "2x EXP Boost")
					return
				end
				-- If invalid/already redeemed, return and let next tick try the next code smoothly without spamming
				return
			end
		end
	end

	local lastInvScanClock = 0
	KX.scanPlayerState = function(forceNow)
		KX.worldNum = getCurrentSeaNumber()
		KX.maxLevel = tonumber(LocalPlayer:GetAttribute("LevelCap")) or 2800

		local data = LocalPlayer:FindFirstChild("Data")
		if data then
			local lv = data:FindFirstChild("Level")
			local bl = data:FindFirstChild("Beli")
			local fr = data:FindFirstChild("Fragments")
			local df = data:FindFirstChild("DevilFruit")
			if lv then KX.level = tonumber(lv.Value) or KX.level end
			if bl then KX.beli = tonumber(bl.Value) or KX.beli end
			if fr then KX.fragments = tonumber(fr.Value) or KX.fragments end
			if df then KX.devilFruit = (tostring(df.Value) ~= "" and tostring(df.Value)) or "None" end
		end

		KX.scanRealtimeMeleeAndWeapons()

		if isChooseTeamScreenOpen() or not CommF_ then
			return
		end
		if not forceNow and (os.clock() - lastInvScanClock < 4.0) then
			return
		end
		lastInvScanClock = os.clock()

		-- Server Inventory Scan (Swords, Guns, Accessories, Materials & Stored Fruits via RemoteUtil + getInventoryWeapons)
		local matReset = {
			["Bones"] = 0,
			["Ectoplasm"] = 0,
			["Dark Fragment"] = 0,
			["Conjured Cocoa"] = 0,
			["Alucard Fragment"] = 0,
			["Fish Tail"] = 0,
			["Magma Ore"] = 0,
			["Mystic Droplet"] = 0,
			["Dragon Scale"] = 0,
			["Fire Essence"] = 0,
		}
		local sawAnyInventorySource = false
		local freshStoredFruits = {}

		local function ingestInventoryEntry(iName, iType, cnt, mast)
			iName = tostring(iName or "")
			iType = tostring(iType or "")
			cnt = tonumber(cnt) or 1
			mast = tonumber(mast) or 0
			if iName == "" then return end
			if iType == "Sword" then
				KX.ownedSwords[iName] = true
				KX.swordMastery[iName] = math.max(KX.swordMastery[iName] or 0, mast)
			elseif iType == "Gun" then
				KX.ownedGuns[iName] = true
				KX.gunMastery[iName] = math.max(KX.gunMastery[iName] or 0, mast)
			elseif iType == "Wear" or iType == "Accessory" then
				KX.ownedAccessories[iName] = true
				if iName == "Valkyrie Helm" then
					KX.ownedAccessories["Valkyrie Helm"] = true
				end
			elseif iType == "Material" then
				matReset[iName] = (matReset[iName] or 0) + cnt
				if iName == "Mirror Fractal" then
					KX.ownedAccessories["Mirror Fractal"] = true
					KX.questsDone.mirrorFractal = true
				elseif iName == "Valkyrie Helm" then
					KX.ownedAccessories["Valkyrie Helm"] = true
				end
			elseif iType == "Blox Fruit" or iType == "PhysicalMoveset" then
				freshStoredFruits[iName] = (freshStoredFruits[iName] or 0) + cnt
			end
		end

		pcall(function()
			local inv = CommF_:InvokeServer("getInventory")
			if type(inv) == "table" and #inv > 0 then
				sawAnyInventorySource = true
				for _, item in ipairs(inv) do
					if type(item) == "table" then
						ingestInventoryEntry(item.Name, item.Type, item.Count, item.Mastery or item.Level)
					end
				end
			end
		end)

		pcall(function()
			local gw = CommF_:InvokeServer("getInventoryWeapons")
			if type(gw) == "table" and #gw > 0 then
				for _, item in ipairs(gw) do
					if type(item) == "table" then
						ingestInventoryEntry(item.Name, item.Type, item.Count or 1, item.Mastery or item.Level)
					end
				end
			end
		end)

		pcall(function()
			local uiCtrl = ReplicatedStorage:FindFirstChild("Controllers") and ReplicatedStorage.Controllers:FindFirstChild("UI")
			local invCtrl = uiCtrl and uiCtrl:FindFirstChild("Inventory")
			local ruMod = invCtrl and invCtrl:FindFirstChild("RemoteUtil")
			if ruMod then
				local ru = require(ruMod)
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
					if not sawAnyInventorySource then
						for k in pairs(matReset) do matReset[k] = 0 end
					end
					sawAnyInventorySource = true
					for _, tile in pairs(tiles) do
						if type(tile) == "table" and tile.ItemId then
							local okD, data = pcall(function() return idMod.getDataFromId(tile.ItemId):unwrap() end)
							if okD and type(data) == "table" then
								local tp = tostring(data.Type or "")
								local sk = tostring(data.StorageKey or data.Name or data.DisplayName or "")
								local cnt = tonumber(tile.Count or tile.Quantity or tile.Amount) or 1
								local mast = tonumber(tile.Mastery or data.Mastery) or 0
								ingestInventoryEntry(sk, tp, cnt, mast)
							end
						end
					end
				end
			end
		end)

		if sawAnyInventorySource then
			for k, v in pairs(matReset) do
				KX.materials[k] = v
			end
			KX.storedFruits = freshStoredFruits
		end

		KX.scanRealtimeMeleeAndWeapons()

		if KX.ownedSwords["Saber"] then
			KX.questsDone.saber = true
		end
		if KX.ownedAccessories["Mirror Fractal"] then
			KX.questsDone.mirrorFractal = true
		end
		if KX.level >= 700 and KX.worldNum >= 2 then
			KX.questsDone.dressrosa = true
		end
		if KX.level >= 1500 and KX.worldNum >= 3 then
			KX.questsDone.bartilo = true
			KX.questsDone.donSwan = true
			KX.questsDone.ripIndraSea2 = true
		end

		-- Awakened moves summary
		pcall(function()
			local awk = CommF_:InvokeServer("Awakener", "Check")
			if type(awk) == "table" and awk.AwakenedMoves then
				local moves = {}
				for mv, okAwk in pairs(awk.AwakenedMoves) do
					if okAwk then table.insert(moves, tostring(mv)) end
				end
				table.sort(moves)
				KX.awakenedText = (#moves > 0) and table.concat(moves, " ") or "-"
			end
		end)

		-- Elite Hunter progress in Sea 3
		if KX.worldNum == 3 then
			pcall(function()
				local ep = CommF_:InvokeServer("EliteHunter", "Progress")
				if tonumber(ep) then
					KX.eliteProgress = tonumber(ep)
				end
			end)
		end

		-- Fighting style ownership queries (non-buying check argument = true)
		pcall(function()
			if not KX.ownedMelees["Dark Step"] and CommF_:InvokeServer("BuyBlackLeg", true) == 1 then
				KX.ownedMelees["Dark Step"] = true
			end
			if not KX.ownedMelees["Electro"] and CommF_:InvokeServer("BuyElectro", true) == 1 then
				KX.ownedMelees["Electro"] = true
			end
			if not KX.ownedMelees["Water Kung Fu"] and CommF_:InvokeServer("BuyFishmanKarate", true) == 1 then
				KX.ownedMelees["Water Kung Fu"] = true
			end
			if not KX.ownedMelees["Superhuman"] and CommF_:InvokeServer("BuySuperhuman", true) == 1 then
				KX.ownedMelees["Superhuman"] = true
			end
			if not KX.ownedMelees["Death Step"] and CommF_:InvokeServer("BuyDeathStep", true) == 1 then
				KX.ownedMelees["Death Step"] = true
				KX.questsDone.deathStep = true
			end
			if not KX.ownedMelees["Sharkman Karate"] and CommF_:InvokeServer("BuySharkmanKarate", true) == 1 then
				KX.ownedMelees["Sharkman Karate"] = true
				KX.questsDone.sharkmanKarate = true
			end
			if not KX.ownedMelees["Electric Claw"] and CommF_:InvokeServer("BuyElectricClaw", true) == 1 then
				KX.ownedMelees["Electric Claw"] = true
				KX.questsDone.electricClaw = true
			end
			if not KX.ownedMelees["Dragon Talon"] and CommF_:InvokeServer("BuyDragonTalon", true) == 1 then
				KX.ownedMelees["Dragon Talon"] = true
				KX.questsDone.dragonTalon = true
			end
			if not KX.ownedMelees["Godhuman"] and CommF_:InvokeServer("BuyGodhuman", true) == 1 then
				KX.ownedMelees["Godhuman"] = true
			end
			if not KX.ownedMelees["Sanguine Art"] and CommF_:InvokeServer("BuySanguineArt", true) == 1 then
				KX.ownedMelees["Sanguine Art"] = true
			end
		end)

		-- Sea 2 Bartilo, Don Swan & Rip Indra quest status
		if KX.worldNum == 2 then
			pcall(function()
				if not KX.questsDone.bartilo then
					local bp2 = CommF_:InvokeServer("BartiloQuestProgress")
					if type(bp2) == "table" and bp2.KilledBandits and bp2.KilledSpring and bp2.DidPlates then
						KX.questsDone.bartilo = true
					end
				end
				if not KX.questsDone.donSwan then
					local zq = CommF_:InvokeServer("GetUnlockables")
					if type(zq) == "table" and zq.FlamingoAccess then
						KX.questsDone.donSwan = true
					end
				end
				if not KX.questsDone.ripIndraSea2 then
					local zp = CommF_:InvokeServer("ZQuestProgress", "Check")
					if tonumber(zp) == 1 then
						KX.questsDone.ripIndraSea2 = true
					end
				end
			end)
		end
	end
end

--------------------------------------------------------------------------------
-- 5. NAVIGATION, SMART PORTALS, SERVER HOP, COMBAT & QUEST ENGINE
--------------------------------------------------------------------------------
do
	-- Generic distance portals ONLY for open-world Sea 1 & Sea 3 hubs!
	-- Sea 2 interiors (Don Swan Room & Cursed Ship) are handled deterministically by interior bounds so they NEVER rubberband!
	local SEA_PORTALS = {
		[1] = {
			Vector3.new(-4651.8, 845.2, -1912.6),  -- Sky 1
			Vector3.new(-7894.6, 5547.1, -380.2),  -- Sky 2
			Vector3.new(61163.8, 11.7, 1819.7),    -- Underwater City
			Vector3.new(3864.6, 6.7, -1926.2),     -- Whirlpool
		},
		[2] = {},
		[3] = {
			Vector3.new(-5075.5, 314.5, -3150.0),  -- Castle on the Sea
			Vector3.new(5756.8, 610.4, -253.9),    -- Hydra Island
			Vector3.new(-12463.8, 375.0, -7551.6), -- Mansion (Floating Turtle)
			Vector3.new(28282.5, 14896.8, 105.1),  -- Temple of Time
		},
	}

	local SWAN_ROOM_CENTER = Vector3.new(2288.8, 15.2, 905.5)
	local CURSED_SHIP_INSIDE = Vector3.new(923.2, 126.9, 32852.8)
	local CURSED_SHIP_OUTSIDE = Vector3.new(-6508.5, 89.0, -132.8)

	function KX.isPosInSwanRoom(pos)
		return pos ~= nil and ((pos - SWAN_ROOM_CENTER).Magnitude < 280) and (pos.Y < 55)
	end

	function KX.isPosInCursedShip(pos)
		return pos ~= nil and (pos.Z > 20000)
	end

	local lastPortalClock = 0
	local lastStreamClock = 0
	local lastTravelClock = 0
	local lastQuestReqClock = 0
	local lastAbandonClock = 0
	local lastBusoClock = 0
	local lastKenClock = 0
	local lastRaceV3Clock = 0
	local lastAttackClock = 0
	local lastSkillClock = 0
	local cachedRegAttack = nil
	local cachedSendHits = nil

	local FakeInput = {
		UserInputType = Enum.UserInputType.MouseButton1,
		UserInputState = Enum.UserInputState.Begin,
		Position = Vector3.zero,
		GetPropertyChangedSignal = function()
			return {Connect = function() return {Disconnect = function() end} end}
		end,
	}

	function KX.getRootAndHum()
		local ch = LocalPlayer.Character
		if not ch then return nil, nil end
		local hrp = ch:FindFirstChild("HumanoidRootPart")
		local hum = ch:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum or hum.Health <= 0 then return nil, nil end
		return hrp, hum
	end

	function KX.hasToolAnywhere(nameOrList)
		local names = (type(nameOrList) == "table") and nameOrList or {tostring(nameOrList)}
		local ch = LocalPlayer.Character
		local bp = LocalPlayer:FindFirstChild("Backpack")
		for _, c in ipairs({ch, bp}) do
			if c then
				for _, item in ipairs(c:GetChildren()) do
					if item:IsA("Tool") then
						for _, target in ipairs(names) do
							if item.Name == target or item.Name:lower() == target:lower() then
								return item
							end
						end
					end
				end
			end
		end
		return nil
	end

	function KX.equipExactTool(tool)
		if not tool or not tool.Parent then return false end
		local _, hum = KX.getRootAndHum()
		if not hum then return false end
		if tool.Parent ~= LocalPlayer.Character then
			pcall(function() hum:EquipTool(tool) end)
		end
		return true
	end

	function KX.equipCategory(cat)
		local ch = LocalPlayer.Character
		local bp = LocalPlayer:FindFirstChild("Backpack")
		if not ch then return nil end

		local function isMatch(t)
			if not t:IsA("Tool") then return false end
			if t.ToolTip == cat then return true end
			local wa = tostring(t:GetAttribute("WeaponType") or "")
			if cat == "Blox Fruit" and (wa == "Demon Fruit" or wa == "Blox Fruit") then
				return true
			end
			return wa:lower() == cat:lower()
		end

		for _, t in ipairs(ch:GetChildren()) do
			if isMatch(t) then return t end
		end
		if bp then
			for _, t in ipairs(bp:GetChildren()) do
				if isMatch(t) then
					KX.equipExactTool(t)
					return t
				end
			end
			for _, t in ipairs(bp:GetChildren()) do
				if t:IsA("Tool") and (t.ToolTip == "Melee" or t.ToolTip == "Sword" or t.ToolTip == "Blox Fruit") then
					KX.equipExactTool(t)
					return t
				end
			end
		end
		return nil
	end

	function KX.stopTween()
		if KX.activeTween then
			pcall(function() KX.activeTween:Cancel() end)
			KX.activeTween = nil
		end
		KX.activeTweenTargetPos = nil
		local hrp = KX.getRootAndHum()
		if hrp then
			local bv = hrp:FindFirstChild("KX_AntiFall")
			if bv and not KX.autoFarm then
				pcall(function() bv:Destroy() end)
			end
		end
	end

	function KX.ensureAntiFall(hrp)
		if not hrp then return end
		pcall(function()
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
		end)
		local bv = hrp:FindFirstChild("KX_AntiFall")
		if not bv then
			bv = Instance.new("BodyVelocity")
			bv.Name = "KX_AntiFall"
			bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
			bv.Velocity = Vector3.zero
			bv.Parent = hrp
		else
			bv.Velocity = Vector3.zero
		end
	end

	function KX.tryRequestPortalEntrance(destVec, touchPart)
		local hrp = KX.getRootAndHum()
		if hrp and touchPart and touchPart:IsA("BasePart") and firetouchinterest then
			pcall(function()
				firetouchinterest(hrp, touchPart, 0)
				firetouchinterest(hrp, touchPart, 1)
			end)
		end
		if CommF_ and destVec and (os.clock() - lastPortalClock >= 2.2) then
			lastPortalClock = os.clock()
			KX.stopTween()
			pcall(function()
				CommF_:InvokeServer("requestEntrance", destVec)
			end)
		end
	end

	function KX.moveToCFrame(targetCF, customSpeed)
		local hrp, hum = KX.getRootAndHum()
		if not hrp or not hum then return false end
		KX.ensureAntiFall(hrp)

		if hum.Sit and not KX.ridingMirageBoat then
			hum.Sit = false
		end

		local targetPos = targetCF.Position

		-- Deterministic Sea 2 interior portal routing (Don Swan Room & Cursed Ship)
		if KX.worldNum == 2 then
			local playerInSwan = KX.isPosInSwanRoom(hrp.Position)
			local targetInSwan = KX.isPosInSwanRoom(targetPos)
			if playerInSwan and not targetInSwan then
				local dress = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Dressrosa")
				local flamExit = dress and dress:FindFirstChild("FlamingoExit")
				local flamEnt = dress and dress:FindFirstChild("FlamingoEntrance")
				local exitDoorPos = (flamExit and flamExit:IsA("BasePart") and flamExit.Position) or Vector3.new(2284.9, 15.2, 905.5)
				local outsidePos = (flamEnt and flamEnt:IsA("BasePart") and (flamEnt.CFrame * Vector3.new(0, 0, -6))) or Vector3.new(-287.5, 305.2, 586.0)
				if (hrp.Position - exitDoorPos).Magnitude <= 32 then
					hrp.CFrame = CFrame.new(exitDoorPos)
					KX.tryRequestPortalEntrance(outsidePos, flamExit)
					return false
				end
				targetPos = exitDoorPos
			elseif targetInSwan and not playerInSwan and KX.questsDone.donSwan then
				local dress = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Dressrosa")
				local flamEnt = dress and dress:FindFirstChild("FlamingoEntrance")
				local flamExit = dress and dress:FindFirstChild("FlamingoExit")
				local entPos = (flamEnt and flamEnt:IsA("BasePart") and flamEnt.Position) or Vector3.new(-287.5, 305.2, 592.4)
				local insidePos = (flamExit and flamExit:IsA("BasePart") and (flamExit.CFrame * Vector3.new(0, 0, -6))) or SWAN_ROOM_CENTER
				if (hrp.Position - entPos).Magnitude <= 32 then
					hrp.CFrame = CFrame.new(entPos)
					KX.tryRequestPortalEntrance(insidePos, flamEnt)
					return false
				end
				targetPos = entPos
			else
				local playerInShip = KX.isPosInCursedShip(hrp.Position)
				local targetInShip = KX.isPosInCursedShip(targetPos)
				if targetInShip and not playerInShip then
					if CommF_ and (os.clock() - lastPortalClock >= 3.2) then
						lastPortalClock = os.clock()
						KX.stopTween()
						pcall(function() CommF_:InvokeServer("requestEntrance", CURSED_SHIP_INSIDE) end)
						task.wait(0.2)
						hrp = KX.getRootAndHum()
						if not hrp then return false end
					end
					if not KX.isPosInCursedShip(hrp.Position) then
						targetPos = CURSED_SHIP_OUTSIDE
					end
				elseif playerInShip and not targetInShip then
					if CommF_ and (os.clock() - lastPortalClock >= 3.2) then
						lastPortalClock = os.clock()
						KX.stopTween()
						pcall(function() CommF_:InvokeServer("requestEntrance", CURSED_SHIP_OUTSIDE) end)
						task.wait(0.2)
						hrp = KX.getRootAndHum()
						if not hrp then return false end
					end
				end
			end
		end

		local dist = (hrp.Position - targetPos).Magnitude
		if dist <= 16 then
			KX.stopTween()
			KX.ensureAntiFall(hrp)
			hrp.CFrame = (targetPos == targetCF.Position) and targetCF or CFrame.new(targetPos)
			return targetPos == targetCF.Position
		end

		-- Pre-stream far target chunks so streaming lag never causes server rubberband
		if dist > 600 and (os.clock() - lastStreamClock >= 2.5) then
			lastStreamClock = os.clock()
			local streamPos = targetPos
			task.spawn(function()
				pcall(function() LocalPlayer:RequestStreamAroundAsync(streamPos, 1) end)
			end)
		end

		-- Smart Portal Shortcut in Sea 1 & Sea 3 ONLY when saving > 2,200 studs
		local portals = SEA_PORTALS[KX.worldNum]
		if portals and #portals > 0 and CommF_ and dist > 3200 and (os.clock() - lastPortalClock >= 8.0) then
			local bestPortal = nil
			local bestRemDist = dist - 2200
			for _, pPos in ipairs(portals) do
				local rem = (pPos - targetPos).Magnitude
				if rem < bestRemDist and (hrp.Position - pPos).Magnitude > 450 then
					bestRemDist = rem
					bestPortal = pPos
				end
			end
			if bestPortal then
				lastPortalClock = os.clock()
				KX.stopTween()
				pcall(function()
					CommF_:InvokeServer("requestEntrance", bestPortal)
				end)
				task.wait(0.25)
				hrp = KX.getRootAndHum()
				if not hrp then return false end
				dist = (hrp.Position - targetPos).Magnitude
				if dist <= 20 and targetPos == targetCF.Position then
					hrp.CFrame = targetCF
					return true
				end
			end
		end

		-- Sticky Tween: Keep current tween gliding smoothly if target hasn't shifted > 10 studs!
		if KX.activeTween
			and KX.activeTween.PlaybackState == Enum.PlaybackState.Playing
			and KX.activeTweenTargetPos
			and (KX.activeTweenTargetPos - targetPos).Magnitude <= 10 then
			return false
		end

		local spd = customSpeed or math.clamp(tonumber(KX.tweenSpeed) or 185, 160, 210)
		local dur = math.max(0.15, dist / spd)
		if KX.activeTween then
			pcall(function() KX.activeTween:Cancel() end)
		end
		local tw = TweenService:Create(
			hrp,
			TweenInfo.new(dur, Enum.EasingStyle.Linear),
			{CFrame = CFrame.new(targetPos)}
		)
		KX.activeTween = tw
		KX.activeTweenTargetPos = targetPos
		tw:Play()
		return false
	end

	function KX.travelToSea(targetSea)
		if KX.worldNum == targetSea or not CommF_ then return true end
		if os.clock() - lastTravelClock < 4.5 then return false end
		lastTravelClock = os.clock()
		KX.stopTween()
		setStatus("🚢 Viajando automáticamente al Sea " .. tostring(targetSea) .. "...", "Sea Travel")
		pcall(function()
			if targetSea == 1 then
				CommF_:InvokeServer("TravelMain")
			elseif targetSea == 2 then
				CommF_:InvokeServer("TravelDressrosa")
			elseif targetSea == 3 then
				CommF_:InvokeServer("TravelZou")
			end
		end)
		return false
	end

	local lastHopClock = 0
	function KX.serverHop(reason)
		if not KX.smartServerHop then return false end
		if os.clock() - lastHopClock < 18.0 or (os.clock() - KX.spawnedAtClock < 14.0) then
			return false
		end
		lastHopClock = os.clock()
		saveConfig()
		setStatus("🌐 Server Hop: " .. tostring(reason or "Buscando objetivo..."), "Server Hop")

		task.spawn(function()
			local reqFn = request or http_request or (http and http.request)
			local cursor = ""
			for _ = 1, 3 do
				local url = string.format(
					"https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100%s",
					game.PlaceId,
					cursor ~= "" and ("&cursor=" .. cursor) or ""
				)
				local bodyStr = nil
				pcall(function()
					if reqFn then
						local r = reqFn({Url = url, Method = "GET"})
						bodyStr = r and r.Body
					else
						bodyStr = game:HttpGet(url)
					end
				end)
				if bodyStr then
					local okJ, parsed = pcall(function() return HttpService:JSONDecode(bodyStr) end)
					if okJ and type(parsed) == "table" and type(parsed.data) == "table" then
						for _, srv in ipairs(parsed.data) do
							local playing = tonumber(srv.playing) or 0
							local maxP = tonumber(srv.maxPlayers) or 12
							if srv.id and srv.id ~= game.JobId and playing >= 2 and playing <= (maxP - 2) then
								pcall(function()
									TeleportService:TeleportToPlaceInstance(game.PlaceId, srv.id, LocalPlayer)
								end)
								task.wait(2.5)
							end
						end
						cursor = tostring(parsed.nextPageCursor or "")
						if cursor == "" then break end
					end
				end
			end
			pcall(function()
				TeleportService:Teleport(game.PlaceId, LocalPlayer)
			end)
		end)
		return true
	end

	function KX.getNPCWorldPos(npcName, fallbackVec)
		for _, folder in ipairs({Workspace:FindFirstChild("NPCs"), ReplicatedStorage:FindFirstChild("NPCs")}) do
			local m = folder and folder:FindFirstChild(npcName)
			if m then
				local ok, cf = pcall(function() return m:GetPivot() end)
				if ok and cf then return cf.Position end
			end
		end
		return fallbackVec
	end

	function KX.isModelAlive(m)
		if not m or not m.Parent then return false end
		local hum = m:FindFirstChildOfClass("Humanoid")
		if hum then return hum.Health > 0 end
		local hv = m:FindFirstChild("Health")
		if hv and hv:IsA("ValueBase") then
			return (tonumber(hv.Value) or 0) > 0
		end
		return false
	end

	function KX.getModelRoot(m)
		if not m then return nil end
		return m:FindFirstChild("HumanoidRootPart")
			or m:FindFirstChild("RootPart")
			or m:FindFirstChild("UpperTorso")
			or m:FindFirstChild("Head")
			or m.PrimaryPart
			or m:FindFirstChildWhichIsA("BasePart")
	end

	local function cleanEntityName(raw)
		return tostring(raw or "")
			:gsub("%s*%[Lv%.%s*%d+%]", "")
			:gsub("%s*%[Boss%]", "")
			:gsub("%s*%[Raid Boss%]", "")
			:gsub("^%s+", "")
			:gsub("%s+$", "")
	end

	-- Exact boss matcher: NEVER matches "Swan Pirate" when searching for "Don Swan"!
	function KX.findExactBoss(exactNamesList, checkRepStorage)
		local set = {}
		for _, n in ipairs(exactNamesList) do
			set[cleanEntityName(n):lower()] = true
		end
		local enemies = Workspace:FindFirstChild("Enemies")
		if enemies then
			for _, m in ipairs(enemies:GetChildren()) do
				if m:IsA("Model") and KX.isModelAlive(m) then
					local cLow = cleanEntityName(m.Name):lower()
					if set[cLow] then
						return m, true
					end
				end
			end
		end
		if checkRepStorage then
			for _, m in ipairs(ReplicatedStorage:GetChildren()) do
				if m:IsA("Model") and KX.isModelAlive(m) then
					local cLow = cleanEntityName(m.Name):lower()
					if set[cLow] then
						return m, false
					end
				end
			end
		end
		return nil, false
	end

	function KX.findBossOrEnemy(namesList, checkRepStorage)
		return KX.findExactBoss(namesList, checkRepStorage)
	end

	function KX.findNearestAliveFromSet(mobSet)
		local hrp = KX.getRootAndHum()
		local ref = hrp and hrp.Position or Vector3.zero
		local enemies = Workspace:FindFirstChild("Enemies")
		if not enemies then return nil end
		local best, bestDist = nil, math.huge
		for _, m in ipairs(enemies:GetChildren()) do
			if m:IsA("Model") and (not mobSet or mobSet[m.Name]) and KX.isModelAlive(m) then
				local p = KX.getModelRoot(m)
				if p then
					local d = (p.Position - ref).Magnitude
					if d < bestDist then
						bestDist = d
						best = m
					end
				end
			end
		end
		return best
	end

	function KX.getSpawnMap()
		local out = {}
		local wo = Workspace:FindFirstChild("_WorldOrigin")
		local spFolder = wo and wo:FindFirstChild("EnemySpawns")
		if spFolder then
			for _, sp in ipairs(spFolder:GetChildren()) do
				if sp:IsA("BasePart") then
					local clean = sp.Name:gsub("%s*%[Lv%.%s*%d+%]", ""):gsub("^%s+", ""):gsub("%s+$", "")
					out[clean] = out[clean] or {}
					table.insert(out[clean], sp.CFrame)
				end
			end
		end
		return out
	end

	function KX.bringClusterMobs(anchorPos, mobSet)
		if sethiddenproperty then
			pcall(function() sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge) end)
		end
		local enemies = Workspace:FindFirstChild("Enemies")
		if not enemies or not anchorPos then return end
		local brought = 0
		for _, m in ipairs(enemies:GetChildren()) do
			if brought >= 3 then break end
			if m:IsA("Model") and (not mobSet or mobSet[m.Name]) and KX.isModelAlive(m) then
				local p = KX.getModelRoot(m)
				local eHum = m:FindFirstChildOfClass("Humanoid")
				if p and (p.Position - anchorPos).Magnitude <= 290 and m.Name ~= "Dough King" and m.Name ~= "rip_indra True Form" and m.Name ~= "Cake Prince" and m.Name ~= "Soul Reaper" and m.Name ~= "Darkbeard" then
					pcall(function()
						p.CFrame = CFrame.new(anchorPos)
						p.CanCollide = false
						p.AssemblyLinearVelocity = Vector3.zero
						if eHum then
							eHum.WalkSpeed = 0
							eHum.JumpPower = 0
						end
					end)
					brought = brought + 1
				end
			end
		end
	end

	function KX.ensureCombatBuffs()
		local ch = LocalPlayer.Character
		if not ch then return end
		if KX.autoBuso and CommF_ and not ch:FindFirstChild("HasBuso") and (os.clock() - lastBusoClock >= 2.8) then
			lastBusoClock = os.clock()
			task.spawn(function() pcall(function() CommF_:InvokeServer("Buso") end) end)
		end
		if KX.autoKen and CommE and (os.clock() - lastKenClock >= 6.0) then
			lastKenClock = os.clock()
			task.spawn(function() pcall(function() CommE:FireServer("Ken", true) end) end)
		end
		if KX.autoRaceV3 and CommE and (os.clock() - lastRaceV3Clock >= 8.0) then
			lastRaceV3Clock = os.clock()
			task.spawn(function() pcall(function() CommE:FireServer("ActivateAbility") end) end)
		end
	end

	function KX.suppressHitAnimations(hum)
		if not KX.noAttackAnimation then return end
		if not hum then
			local ch = LocalPlayer.Character
			hum = ch and ch:FindFirstChildOfClass("Humanoid")
		end
		if not hum then return end

		if CombatUtil and type(CombatUtil.GetMovesetAnimCache) == "function" then
			pcall(function()
				local cache = CombatUtil:GetMovesetAnimCache(hum)
				if type(cache) == "table" then
					for k, wrap in pairs(cache) do
						local ks = tostring(k)
						if ks:find("-basic", 1, true)
							or ks:find("-Shoot", 1, true)
							or ks:find("-Reload", 1, true)
							or ks:find("-SmallReload", 1, true) then
							local tr = (type(wrap) == "table" and wrap._Object) or wrap
							if typeof(tr) == "Instance" and tr:IsA("AnimationTrack") and tr.IsPlaying then
								tr:Stop(0)
							end
						end
					end
				end
			end)
		end

		local animator = hum:FindFirstChildOfClass("Animator")
		if animator then
			pcall(function()
				for _, tr in ipairs(animator:GetPlayingAnimationTracks()) do
					local tName = tostring(tr.Name or "")
					local tLow = tName:lower()
					if tName:find("-basic", 1, true)
						or tName:find("-Shoot", 1, true)
						or tName:find("-Reload", 1, true)
						or tName:find("-SmallReload", 1, true)
						or tLow:find("slash", 1, true)
						or tLow:find("swing", 1, true)
						or tLow:find("punch", 1, true)
						or (
							not tr.Looped
							and tr.Priority == Enum.AnimationPriority.Action
							and not tLow:find("idle", 1, true)
							and not tLow:find("equip", 1, true)
						) then
						tr:Stop(0)
					end
				end
			end)
		end
	end

	function KX.fireWeaponClick(tool, enemyModel, ePart)
		local hrp, hum = KX.getRootAndHum()
		if not hrp or not hum or not ePart or not ePart.Parent then return end

		local interval = math.clamp(tonumber(KX.attackInterval) or 0.095, 0.075, 0.25)
		if os.clock() - lastAttackClock < interval then return end
		lastAttackClock = os.clock()

		if MouseModule then
			pcall(function()
				local dir = (ePart.Position - hrp.Position)
				local unit = (dir.Magnitude > 0.01) and dir.Unit or Vector3.new(0, -1, 0)
				MouseModule.Hit = CFrame.lookAt(ePart.Position, ePart.Position + unit)
				MouseModule.Target = ePart
				MouseModule.Origin = CFrame.lookAt(hrp.Position, ePart.Position)
			end)
		end

		if tool then
			local mp = tool:FindFirstChild("MousePos")
			if mp and mp:IsA("Vector3Value") then
				mp.Value = ePart.Position
			end
		end

		local extraHits = {}
		local enemies = Workspace:FindFirstChild("Enemies")
		if enemies then
			for _, m in ipairs(enemies:GetChildren()) do
				if m ~= enemyModel and m:IsA("Model") and KX.isModelAlive(m) and #extraHits < 3 then
					local p2 = KX.getModelRoot(m)
					if p2 and (p2.Position - ePart.Position).Magnitude <= 45 then
						table.insert(extraHits, {m, p2})
					end
				end
			end
		end

		local tip = tool and tostring(tool.ToolTip or "") or ""
		local wt = tool and tostring(tool:GetAttribute("WeaponType") or "") or ""
		local isGun = (tip == "Gun" or wt == "Gun")
		local isFruit = (tip == "Blox Fruit" or wt == "Demon Fruit" or wt == "Blox Fruit")

		if isGun then
			pcall(function()
				if CombatController and type(CombatController.Attack) == "function" and tool then
					CombatController:Attack(tool, FakeInput)
				end
			end)
		elseif isFruit then
			pcall(function()
				local lcr = tool and tool:FindFirstChild("LeftClickRemote")
				if lcr and lcr:IsA("RemoteEvent") then
					local dir = (ePart.Position - hrp.Position)
					lcr:FireServer(dir.Magnitude > 0.01 and dir.Unit or Vector3.new(0, -1, 0), 1)
				end
				if CombatController and type(CombatController.Attack) == "function" and tool then
					CombatController:Attack(tool, FakeInput)
				end
				if tool then tool:Activate() end
			end)
		else
			-- Melee / Sword: When noAttackAnimation is ON, send direct server combo hits
			-- so client swing animations, camera shake & forward lunge never trigger!
			if not KX.noAttackAnimation then
				pcall(function()
					if CombatController and type(CombatController.Attack) == "function" and tool then
						CombatController:Attack(tool, FakeInput)
					end
				end)
			end

			pcall(function()
				if not cachedRegAttack or not cachedRegAttack.Parent then
					local net = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("Net")
					cachedRegAttack = net and net:FindFirstChild("RE/RegisterAttack")
					cachedSendHits = net and net:FindFirstChild("RE/RegisterHit")
				end
				if cachedRegAttack then
					cachedRegAttack:FireServer(0)
				end
				if GlobalModule and type(GlobalModule.SendHitsToServer) == "function" then
					GlobalModule.SendHitsToServer(ePart, extraHits)
				elseif cachedSendHits then
					cachedSendHits:FireServer(ePart, extraHits)
				end
			end)
		end

		if KX.noAttackAnimation then
			KX.suppressHitAnimations(hum)
		end
	end

	function KX.attackTarget(enemyModel, preferredWeaponCategory, exactToolName)
		local hrp = KX.getRootAndHum()
		local ePart = KX.getModelRoot(enemyModel)
		if not hrp or not ePart then return end

		KX.ensureModulesReady(false)
		KX.ensureCombatBuffs()

		KX.lastAimEnemy = enemyModel
		KX.lastAimPart = ePart
		KX.lastAimPos = ePart.Position

		local hoverCF = CFrame.lookAt(ePart.Position + Vector3.new(0, 19, 0), ePart.Position)
		if (hrp.Position - hoverCF.Position).Magnitude > 22 then
			KX.moveToCFrame(hoverCF)
			return
		end
		KX.stopTween()
		KX.ensureAntiFall(hrp)
		hrp.CFrame = hoverCF

		local tool = nil
		if exactToolName then
			tool = KX.hasToolAnywhere(exactToolName)
			if tool then KX.equipExactTool(tool) end
		end
		if not tool then
			tool = KX.equipCategory(preferredWeaponCategory or "Melee")
		end
		KX.lastCombatTool = tool

		KX.fireWeaponClick(tool, enemyModel, ePart)

		-- Weave Z / X skills gently when fighting bosses or leveling sword/melee mastery
		if (os.clock() - lastSkillClock >= 3.2) and tool and (tool.ToolTip == "Melee" or tool.ToolTip == "Sword") then
			lastSkillClock = os.clock()
			local key = (math.floor(os.clock()) % 2 == 0) and Enum.KeyCode.Z or Enum.KeyCode.X
			pcall(function()
				VirtualInputManager:SendKeyEvent(true, key, false, game)
				task.delay(0.06, function()
					pcall(function() VirtualInputManager:SendKeyEvent(false, key, false, game) end)
				end)
			end)
		end
	end

	function KX.engageTarget(enemyModel, clusterSet, label, weaponCat, exactToolName)
		if not enemyModel then return end
		local p = KX.getModelRoot(enemyModel)
		if p and clusterSet then
			KX.bringClusterMobs(p.Position, clusterSet)
		end
		setStatus(label .. " -> " .. tostring(enemyModel.Name), KX.phaseText)
		KX.attackTarget(enemyModel, weaponCat, exactToolName)
	end

	local SecretBlacklist = {
		["BartiloQuest"] = true,
		["CitizenQuest"] = true,
	}

	function KX.getBestLevelQuest()
		KX.ensureModulesReady(true)
		if not QuestsModule then return nil end

		local effLvl = math.clamp(KX.level, 1, KX.maxLevel)
		local spMap = KX.getSpawnMap()
		local npcPosMap = {}
		local hasGuide = false
		if GuideModule and GuideModule.Data and GuideModule.Data.NPCList then
			for _, nd in pairs(GuideModule.Data.NPCList) do
				if nd.InternalQuestName and nd.Position then
					npcPosMap[nd.InternalQuestName] = CFrame.new(nd.Position)
					hasGuide = true
				end
			end
		end

		local isMarine = LocalPlayer.Team and LocalPlayer.Team.Name == "Marines"
		local list = {}

		for qGroup, qArr in pairs(QuestsModule) do
			if not SecretBlacklist[qGroup] then
				local inSea = hasGuide and (npcPosMap[qGroup] ~= nil) or false
				if not hasGuide then
					for _, qd in ipairs(qArr) do
						if qd.Task then
							for mName in pairs(qd.Task) do
								if spMap[mName] and #spMap[mName] > 0 then
									inSea = true
									break
								end
							end
						end
					end
				end

				if inSea then
					if not (effLvl < 10 and isMarine and qGroup == "BanditQuest1")
						and not (effLvl < 10 and not isMarine and qGroup == "MarineQuest") then
						for qIdx, qd in ipairs(qArr) do
							local req = tonumber(qd.LevelReq) or 0
							if req <= effLvl and qd.Task then
								for mName, cnt in pairs(qd.Task) do
									if cnt > 1 and cnt <= 20 then
										local npcCF = npcPosMap[qGroup]
										local sps = spMap[mName]
										if not sps or #sps == 0 then
											sps = {npcCF or CFrame.new(0, 60, 0)}
										end
										table.insert(list, {
											questGroup = qGroup,
											questIndex = qIdx,
											levelReq = req,
											mobName = mName,
											spawns = sps,
											npcCFrame = npcCF or sps[1],
										})
									end
								end
							end
						end
					end
				end
			end
		end

		table.sort(list, function(a, b)
			if a.levelReq ~= b.levelReq then return a.levelReq > b.levelReq end
			if a.questGroup ~= b.questGroup then return a.questGroup > b.questGroup end
			return a.questIndex > b.questIndex
		end)
		return list[1]
	end

	function KX.getActiveQuestInfo(expectedGroup, expectedMob)
		KX.ensureModulesReady(true)
		if GuideData and GuideData.Data then
			local qd = GuideData.Data.QuestData
			if not qd then return false, false end
			local qName = tostring(qd.InternalQuestName or "")
			local info = qd.Info or {}
			local tasks = info.Task or {}
			local title = tostring(info.Name or qName)
			local matches = (expectedGroup and qName == expectedGroup and tasks[expectedMob] ~= nil)
				or (expectedMob and (tasks[expectedMob] ~= nil or title:lower():find(expectedMob:lower(), 1, true)))
			return true, matches
		end
		local pgui = LocalPlayer:FindFirstChild("PlayerGui")
		if pgui then
			local mainGui = pgui:FindFirstChild("Main") or pgui:FindFirstChild("Main (minimal)")
			local qFrame = mainGui and mainGui:FindFirstChild("Quest")
			if qFrame and qFrame:IsA("GuiObject") and qFrame.Visible then
				local cont = qFrame:FindFirstChild("Container")
				local qt = cont and cont:FindFirstChild("QuestTitle")
				local titleLbl = qt and qt:FindFirstChild("Title")
				local titleTxt = (titleLbl and tostring(titleLbl.Text or "") or ""):lower()
				if titleTxt ~= "" then
					return true, (not expectedMob or titleTxt:find(expectedMob:lower(), 1, true) ~= nil)
				end
			end
			local tqf = pgui:FindFirstChild("TrackedQuestFrame")
			local frm = tqf and tqf:FindFirstChild("Frame")
			if tqf and tqf.Enabled and frm and frm.Visible then
				local desc = (frm:FindFirstChild("description") and frm.description.Text or ""):lower()
				if desc ~= "" then
					return true, (not expectedMob or desc:find(expectedMob:lower(), 1, true) ~= nil)
				end
			end
		end
		return false, false
	end

	function KX.ensureQuestAccepted(qInfo, hrp)
		if not qInfo or not CommF_ then return true end
		local hasQ, matches = KX.getActiveQuestInfo(qInfo.questGroup, qInfo.mobName)
		if hasQ and matches then
			return true
		end
		if hasQ and not matches then
			if os.clock() - lastAbandonClock >= 1.2 then
				lastAbandonClock = os.clock()
				pcall(function() CommF_:InvokeServer("AbandonQuest") end)
			end
			return false
		end
		setStatus("📜 Aceptando Quest: " .. tostring(qInfo.mobName) .. " (Lv. " .. tostring(qInfo.levelReq) .. ")", KX.phaseText)
		local reached = KX.moveToCFrame(qInfo.npcCFrame * CFrame.new(0, 3, 2))
		if reached or (hrp.Position - qInfo.npcCFrame.Position).Magnitude <= 28 then
			if os.clock() - lastQuestReqClock >= 1.1 then
				lastQuestReqClock = os.clock()
				pcall(function()
					CommF_:InvokeServer("StartQuest", qInfo.questGroup, qInfo.questIndex)
				end)
			end
		end
		return false
	end

	local patrolIdx = 1
	local lastPatrolSwitch = 0
	function KX.farmMobSpawns(mobName, spawns, label, weaponCat, exactToolName)
		local mobSet = {[mobName] = true}
		local enemy = KX.findNearestAliveFromSet(mobSet)
		if enemy then
			KX.engageTarget(enemy, mobSet, label, weaponCat, exactToolName)
			return
		end
		if spawns and #spawns > 0 then
			if os.clock() - lastPatrolSwitch >= 2.2 then
				lastPatrolSwitch = os.clock()
				patrolIdx = (patrolIdx % #spawns) + 1
			end
			local sp = spawns[((patrolIdx - 1) % #spawns) + 1]
			setStatus(label .. " (Esperando spawn: " .. tostring(mobName) .. ")", KX.phaseText)
			KX.moveToCFrame(sp * CFrame.new(0, 22, 0))
		end
	end
end

--------------------------------------------------------------------------------
-- 6. FRUIT GACHA + SAFE STORE + EAT POLICY, AUTO STATS, FPS BOOST & AFK MODE
--------------------------------------------------------------------------------
do
	local PROTECTED_ITEM_NAMES = {
		["God's Chalice"] = true,
		["Sweet Chalice"] = true,
		["Fist of Darkness"] = true,
		["Hallow Essence"] = true,
		["Fire Essence"] = true,
		["Library Key"] = true,
		["Water Key"] = true,
		["Hidden Key"] = true,
		["Relic"] = true,
		["Torch"] = true,
		["Holy Torch"] = true,
		["Cup"] = true,
		["Flower 1"] = true,
		["Flower 2"] = true,
		["Flower 3"] = true,
		["Special Microchip"] = true,
		["Core Brain"] = true,
	}

	local lastGachaClock = 0
	local lastStoreCheckClock = 0

	local function isPhysicalFruit(tool)
		if not tool or not tool:IsA("Tool") then return false end
		if PROTECTED_ITEM_NAMES[tool.Name] or tool == KX.protectedTool then return false end
		if tool.ToolTip == "Blox Fruit" or tool.ToolTip == "Melee" or tool.ToolTip == "Sword" or tool.ToolTip == "Gun" then
			return false
		end
		return (tool.Name:find(" Fruit") ~= nil)
			or (tool:FindFirstChild("EatRemote") ~= nil)
			or (tostring(tool:GetAttribute("OriginalName") or ""):find("-") ~= nil)
	end

	local function getFruitStorageKey(tool)
		local orig = tool:GetAttribute("OriginalName")
		if orig and tostring(orig) ~= "" then
			return tostring(orig)
		end
		local base = tool.Name:gsub(" Fruit$", "")
		return base .. "-" .. base
	end

	-- Exclusive movement task for spawned map fruits (ONLY called during normal grinding and RETURNS true so zero concurrent movement happens!)
	function KX.tryGrabGroundFruit(hrp)
		if not KX.autoGrabGroundFruits or not hrp then
			return false
		end
		local now = os.clock()
		for _, obj in ipairs(Workspace:GetChildren()) do
			local ignoreUntil = KX.ignoredFruits[obj]
			if (not ignoreUntil or now >= ignoreUntil)
				and (obj:IsA("Tool") or obj:IsA("Model"))
				and obj.Name:lower():find("fruit")
				and not Players:GetPlayerFromCharacter(obj) then
				local handle = obj:FindFirstChild("Handle")
				if handle and handle:IsA("BasePart") then
					local dist = (handle.Position - hrp.Position).Magnitude
					local unreachableSwan = (KX.worldNum == 2 and KX.isPosInSwanRoom(handle.Position) and not KX.isPosInSwanRoom(hrp.Position))
					if dist <= 1800 and not unreachableSwan then
						if not KX.fruitAttemptStart[obj] then
							KX.fruitAttemptStart[obj] = now
						elseif (now - KX.fruitAttemptStart[obj]) > 8.5 then
							-- Timed out (stuck behind geometry or claimed) -> ignore for 3 mins so Kaitun never stalls!
							KX.ignoredFruits[obj] = now + 180.0
							KX.fruitAttemptStart[obj] = nil
						else
							KX.phaseText = "Bonus: Map Fruit Pickup"
							setStatus("🍎 Recogiendo fruta del mapa: " .. tostring(obj.Name), KX.phaseText)
							local reached = KX.moveToCFrame(handle.CFrame * CFrame.new(0, 2, 0))
							if reached or (hrp.Position - handle.Position).Magnitude <= 18 then
								hrp.CFrame = handle.CFrame
								if firetouchinterest then
									pcall(function()
										firetouchinterest(hrp, handle, 0)
										firetouchinterest(hrp, handle, 1)
									end)
								end
								KX.ignoredFruits[obj] = now + 10.0
								KX.fruitAttemptStart[obj] = nil
							end
							return true
						end
					end
				end
			end
		end
		return false
	end

	-- Background NON-MOVING support step (Gacha spin + Store/Eat fruits in backpack)
	function KX.stepFruitSpinStoreAndEat()
		if not KX.autoFarm or isChooseTeamScreenOpen() or not CommF_ then return end

		-- 1) Spin Random Fruit Gacha on cooldown (keeps reserve Beli if saving for a style)
		if KX.autoSpinAndStoreFruits and KX.beli >= 350000 and (os.clock() - lastGachaClock >= 75.0) then
			lastGachaClock = os.clock()
			task.spawn(function()
				pcall(function()
					CommF_:InvokeServer("Cousin", "Buy")
				end)
				pcall(function()
					local gc = ReplicatedStorage:FindFirstChild("Controllers") and ReplicatedStorage.Controllers:FindFirstChild("GachaClient")
					if gc then
						local mod = require(gc)
						if type(mod) == "table" and type(mod.PurchaseGachaAsync) == "function" then
							mod.PurchaseGachaAsync("GachaData")
						end
					end
				end)
			end)
		end

		-- 3) Store ALL physical fruits first; eat ONLY if user enabled Auto Eat Allowed Fruits & fruit is whitelisted
		if os.clock() - lastStoreCheckClock >= 2.2 then
			lastStoreCheckClock = os.clock()
			local ch = LocalPlayer.Character
			local bp = LocalPlayer:FindFirstChild("Backpack")
			for _, c in ipairs({ch, bp}) do
				if c then
					for _, tool in ipairs(c:GetChildren()) do
						if isPhysicalFruit(tool) then
							local sKey = getFruitStorageKey(tool)

							-- Optional Eat Policy (only if user explicitly turned on Auto Eat Allowed Fruits & current fruit isn't already whitelisted)
							if KX.autoEatAllowedFruits and KX.allowedEatFruits[sKey] and not KX.allowedEatFruits[KX.devilFruit] then
								KX.equipExactTool(tool)
								task.wait(0.15)
								pcall(function()
									local eatRem = tool:FindFirstChild("EatRemote")
									if eatRem and eatRem:IsA("RemoteFunction") then
										eatRem:InvokeServer()
									end
								end)
								return
							end

							-- Otherwise ALWAYS store into inventory (with per-tool cooldown if cap is full)
							if KX.autoSpinAndStoreFruits then
								local cd = KX.failedStoreCooldown[tool]
								if not cd or os.clock() >= cd then
									local okS, resS = pcall(function()
										return CommF_:InvokeServer("StoreFruit", sKey, tool)
									end)
									if (not okS) or resS ~= true then
										KX.failedStoreCooldown[tool] = os.clock() + 35.0
									end
								end
							end
						end
					end
				end
			end
		end
	end

	function KX.stepSmartStats()
		if not KX.autoStats or not KX.autoFarm or isChooseTeamScreenOpen() or not CommF_ then return end
		local data = LocalPlayer:FindFirstChild("Data")
		local ptsObj = data and data:FindFirstChild("Points")
		local stFolder = data and data:FindFirstChild("Stats")
		local pts = ptsObj and tonumber(ptsObj.Value) or 0
		if pts <= 0 or not stFolder then return end

		local function getStatLv(sName)
			local node = stFolder:FindFirstChild(sName)
			local lv = node and node:FindFirstChild("Level")
			return lv and tonumber(lv.Value) or 1
		end

		local meleeLv = getStatLv("Melee")
		local defLv = getStatLv("Demon Fruit") -- wait: Defense is "Defense"!
		defLv = getStatLv("Defense")
		local swordLv = getStatLv("Sword")
		local cap = KX.maxLevel

		local targetStat = "Melee"
		if meleeLv < cap and meleeLv <= (defLv * 2) then
			targetStat = "Melee"
		elseif defLv < cap then
			targetStat = "Defense"
		elseif meleeLv < cap then
			targetStat = "Melee"
		elseif swordLv < cap then
			targetStat = "Sword"
		else
			targetStat = "Demon Fruit"
		end

		pcall(function()
			CommF_:InvokeServer("AddPoint", targetStat, math.min(pts, 15))
		end)
	end

	function KX.applyFpsBoost(enable)
		KX.fpsBoost = (enable == true)
		if not KX.fpsBoost then return end
		pcall(function()
			Lighting.GlobalShadows = false
			Lighting.FogEnd = 9e9
			settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
			for _, v in ipairs(Lighting:GetChildren()) do
				if v:IsA("PostEffect") or v:IsA("Atmosphere") then
					v.Enabled = false
				end
			end
			for _, d in ipairs(Workspace:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Material = Enum.Material.SmoothPlastic
					d.Reflectance = 0
				elseif d:IsA("ParticleEmitter") or d:IsA("Trail") then
					d.Enabled = false
				end
			end
		end)
	end

	function KX.applyAfkMode(enable)
		KX.afkMode = (enable == true)
		local hui = (gethui and gethui()) or CoreGui
		local existing = CoreGui:FindFirstChild("SwitchHub_SeriesX_AFK") or (hui and hui:FindFirstChild("SwitchHub_SeriesX_AFK"))
		if existing then
			pcall(function() existing:Destroy() end)
		end

		pcall(function()
			RunService:Set3dRenderingEnabled(not KX.afkMode)
		end)

		if KX.afkMode then
			local bgGui = Instance.new("ScreenGui")
			bgGui.Name = "SwitchHub_SeriesX_AFK"
			bgGui.IgnoreGuiInset = true
			bgGui.ResetOnSpawn = false
			bgGui.DisplayOrder = 9400 -- Directly behind Switch Hub [ Series X ] (9500)
			bgGui.Parent = CoreGui

			local backdrop = Instance.new("Frame")
			backdrop.Size = UDim2.new(1, 0, 1, 0)
			backdrop.BackgroundColor3 = Color3.fromRGB(7, 3, 12)
			backdrop.BorderSizePixel = 0
			backdrop.Parent = bgGui

			local tag = Instance.new("TextLabel")
			tag.Size = UDim2.new(1, 0, 0, 26)
			tag.Position = UDim2.new(0, 0, 1, -36)
			tag.BackgroundTransparency = 1
			tag.Font = Enum.Font.RobotoMono
			tag.TextSize = 13
			tag.TextColor3 = Color3.fromRGB(148, 82, 210)
			tag.Text = "Switch Hub [ Series X ] — AFK Low-GPU Mode Active (3D Render Paused)"
			tag.Parent = backdrop
		end
	end
end

--------------------------------------------------------------------------------
-- 7. MASTER KAITUN PRIORITY ENGINE — TIERS 1, 2 & 3
--    Tier 1: Priority Bosses (Katakuri V2, Rip Indra, Katakuri V1, Soul Reaper, Darkbeard)
--    Tier 2: Level 1 -> Max + Sea 1/2/3 Storyline + Melee Mastery Rotation
--    Tier 3: Full Godhuman Unlock (Prerequisites + Mastery 400 + Materials)
--------------------------------------------------------------------------------
do
	local CAKE_LAND_MOBS = {
		["Cookie Crafter"] = true,
		["Cake Guard"] = true,
		["Baking Staff"] = true,
		["Head Baker"] = true,
	}
	local HAUNTED_MOBS = {
		["Reborn Skeleton"] = true,
		["Living Zombie"] = true,
		["Demonic Soul"] = true,
		["Posessed Mummy"] = true,
	}
	local BARTILO_PLATES_POS = {
		Vector3.new(-1850.5, 13.2, 1750.8),
		Vector3.new(-1810.2, 13.2, 1775.4),
		Vector3.new(-1770.8, 13.2, 1765.0),
		Vector3.new(-1745.0, 13.2, 1730.2),
		Vector3.new(-1765.5, 13.2, 1695.0),
		Vector3.new(-1805.0, 13.2, 1685.5),
		Vector3.new(-1845.2, 13.2, 1700.4),
		Vector3.new(-1865.0, 13.2, 1725.0),
	}

	local lastCakeSpawnerPoll = 0
	local cakeRemaining = 500
	local lastBonesRollClock = 0

	-- =========================================================================
	-- TIER 1: SPECIAL BOSS INTERRUPTS (KATAKURI V2, RIP INDRA, KATAKURI V1, SOUL REAPER, DARKBEARD)
	-- =========================================================================
	function KX.tryStepPriorityBosses(hrp)
		local sea = KX.worldNum

		if sea == 3 then
			-- 1A) KATAKURI V2 (DOUGH KING) -> MIRROR FRACTAL & VALKYRIE / RED KEY
			local dkModel, dkInEnemies = KX.findBossOrEnemy({"Dough King"}, true)
			local sweetChalice = KX.hasToolAnywhere("Sweet Chalice")
			local godsChalice = KX.hasToolAnywhere("God's Chalice")

			-- Craft Sweet Chalice if holding God's Chalice + >=10 Conjured Cocoa & Mirror Fractal missing
			if godsChalice and not sweetChalice and (KX.materials["Conjured Cocoa"] or 0) >= 10 and not KX.ownedAccessories["Mirror Fractal"] then
				KX.phaseText = "Tier 1: Katakuri V2 (Craft Sweet Chalice)"
				local scPos = KX.getNPCWorldPos("SweetChaliceNpc", Vector3.new(-1990.5, 38.0, -11855.0))
				setStatus("🍩 Fabricando Sweet Chalice para Katakuri V2...", KX.phaseText)
				if KX.moveToCFrame(CFrame.new(scPos + Vector3.new(0, 3, 2))) or (hrp.Position - scPos).Magnitude <= 25 then
					KX.equipExactTool(godsChalice)
					pcall(function() CommF_:InvokeServer("SweetChaliceNpc") end)
				end
				return true
			end

			if dkModel then
				KX.phaseText = "Tier 1: Boss Katakuri V2 (Dough King)"
				local map = Workspace:FindFirstChild("Map")
				local mirror = map and map:FindFirstChild("CakeLoaf") and map.CakeLoaf:FindFirstChild("BigMirror")
				local mirrorPart = mirror and (mirror:FindFirstChild("Main") or mirror:FindFirstChild("Other") or mirror:FindFirstChildWhichIsA("BasePart"))
				local dkPart = KX.getModelRoot(dkModel)
				if (not dkInEnemies) or (dkPart and (hrp.Position - dkPart.Position).Magnitude > 1400) then
					if mirrorPart and mirrorPart:IsA("BasePart") then
						setStatus("🍩 Entrando al espejo dimensional de Katakuri V2...", KX.phaseText)
						if KX.moveToCFrame(mirrorPart.CFrame) or (hrp.Position - mirrorPart.Position).Magnitude <= 25 then
							hrp.CFrame = mirrorPart.CFrame
							if firetouchinterest then
								pcall(function()
									firetouchinterest(hrp, mirrorPart, 0)
									firetouchinterest(hrp, mirrorPart, 1)
								end)
							end
						end
						return true
					end
				end
				if dkInEnemies then
					KX.engageTarget(dkModel, nil, "🍩 Derrotando a Katakuri V2 (Dough King)", "Melee")
					return true
				end
			end

			if sweetChalice then
				KX.phaseText = "Tier 1: Invocando Katakuri V2 (Sweet Chalice)"
				if os.clock() - lastCakeSpawnerPoll >= 3.5 then
					lastCakeSpawnerPoll = os.clock()
					pcall(function()
						local r = tostring(CommF_:InvokeServer("CakePrinceSpawner", true) or "")
						local n = tonumber(r:match("(%d+)"))
						cakeRemaining = (n and (r:lower():find("more") or r:lower():find("defeat") or r:lower():find("faltan"))) and n or 0
					end)
				end
				if cakeRemaining > 0 then
					local mob = KX.findNearestAliveFromSet(CAKE_LAND_MOBS)
					if mob then
						KX.engageTarget(mob, CAKE_LAND_MOBS, "🍩 Sweet Chalice (Faltan " .. tostring(cakeRemaining) .. ")", "Melee")
					else
						setStatus("🍩 Patrullando Cake Land (" .. tostring(cakeRemaining) .. " restantes)...", KX.phaseText)
						KX.moveToCFrame(CFrame.new(-2095.0, 70.0, -12140.0))
					end
				else
					local dripPos = KX.getNPCWorldPos("drip_mama", Vector3.new(-2151.8, 70.0, -12404.9))
					setStatus("🍩 Invocando a Katakuri V2 con drip_mama...", KX.phaseText)
					if KX.moveToCFrame(CFrame.new(dripPos + Vector3.new(0, 3, 3))) or (hrp.Position - dripPos).Magnitude <= 22 then
						KX.equipExactTool(sweetChalice)
						pcall(function() CommF_:InvokeServer("CakePrinceSpawner") end)
					end
				end
				return true
			end

			-- 1B) RIP INDRA TRUE FORM (SEA 3) -> VALKYRIE HELM / DARK DAGGER / PORTALS / TUSHITA
			local indraModel, indraInEnemies = KX.findBossOrEnemy({"rip_indra True Form"}, true)
			if indraModel then
				KX.phaseText = "Tier 1: Boss Rip Indra"
				if indraInEnemies then
					KX.engageTarget(indraModel, nil, "👑 Derrotando a Rip Indra True Form", "Melee")
				else
					local castlePos = Vector3.new(-5543.5, 313.8, -2664.2)
					setStatus("👑 Volando a Castle on the Sea por Rip Indra...", KX.phaseText)
					KX.moveToCFrame(CFrame.new(castlePos + Vector3.new(0, 25, 0)))
				end
				return true
			end

			if godsChalice then
				KX.phaseText = "Tier 1: Invocando Rip Indra (God's Chalice)"
				local pedestalPos = Vector3.new(-5560.4, 314.2, -2664.8)
				setStatus("👑 Colocando God's Chalice en el altar de Castle on the Sea...", KX.phaseText)
				if KX.moveToCFrame(CFrame.new(pedestalPos + Vector3.new(0, 3, 0))) or (hrp.Position - pedestalPos).Magnitude <= 20 then
					KX.equipExactTool(godsChalice)
					local castle = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Boat Castle")
					local summoner = castle and castle:FindFirstChild("Summoner") and castle.Summoner:FindFirstChild("Detection")
					if summoner and summoner:IsA("BasePart") and firetouchinterest then
						pcall(function()
							firetouchinterest(hrp, summoner, 0)
							firetouchinterest(hrp, summoner, 1)
						end)
					end
				end
				return true
			end

			-- 1C) KATAKURI V1 (CAKE PRINCE) -> SPIKEY TRIDENT / PALE SCARF
			local cpModel, cpInEnemies = KX.findBossOrEnemy({"Cake Prince"}, true)
			if os.clock() - lastCakeSpawnerPoll >= 6.0 then
				lastCakeSpawnerPoll = os.clock()
				pcall(function()
					local r = tostring(CommF_:InvokeServer("CakePrinceSpawner", true) or "")
					local n = tonumber(r:match("(%d+)"))
					cakeRemaining = (n and (r:lower():find("more") or r:lower():find("defeat") or r:lower():find("faltan"))) and n or 0
				end)
			end
			if cpModel then
				KX.phaseText = "Tier 1: Boss Katakuri V1 (Cake Prince)"
				local map = Workspace:FindFirstChild("Map")
				local mirror = map and map:FindFirstChild("CakeLoaf") and map.CakeLoaf:FindFirstChild("BigMirror")
				local mirrorPart = mirror and (mirror:FindFirstChild("Main") or mirror:FindFirstChild("Other") or mirror:FindFirstChildWhichIsA("BasePart"))
				local cpPart = KX.getModelRoot(cpModel)
				if (not cpInEnemies) or (cpPart and (hrp.Position - cpPart.Position).Magnitude > 1400) then
					if mirrorPart and mirrorPart:IsA("BasePart") then
						setStatus("🍰 Entrando a la dimensión de Katakuri V1 (Cake Prince)...", KX.phaseText)
						if KX.moveToCFrame(mirrorPart.CFrame) or (hrp.Position - mirrorPart.Position).Magnitude <= 25 then
							hrp.CFrame = mirrorPart.CFrame
							if firetouchinterest then
								pcall(function()
									firetouchinterest(hrp, mirrorPart, 0)
									firetouchinterest(hrp, mirrorPart, 1)
								end)
							end
						end
						return true
					end
				end
				if cpInEnemies then
					KX.engageTarget(cpModel, nil, "🍰 Derrotando a Katakuri V1 (Cake Prince)", "Melee")
					return true
				end
			elseif cakeRemaining == 0 and not sweetChalice then
				KX.phaseText = "Tier 1: Abriendo Portal Katakuri V1"
				local dripPos = KX.getNPCWorldPos("drip_mama", Vector3.new(-2151.8, 70.0, -12404.9))
				setStatus("🍰 Portal listo (0/500) -> Invocando Katakuri V1...", KX.phaseText)
				if KX.moveToCFrame(CFrame.new(dripPos + Vector3.new(0, 3, 3))) or (hrp.Position - dripPos).Magnitude <= 22 then
					pcall(function() CommF_:InvokeServer("CakePrinceSpawner") end)
					cakeRemaining = 500
				end
				return true
			end

			-- 1D) SOUL REAPER -> HALLOW SCYTHE / HOLY CROWN
			local srModel, srInEnemies = KX.findBossOrEnemy({"Soul Reaper"}, true)
			local hallowEssence = KX.hasToolAnywhere("Hallow Essence")
			if srModel then
				KX.phaseText = "Tier 1: Boss Soul Reaper"
				if srInEnemies then
					KX.engageTarget(srModel, nil, "💀 Derrotando a Soul Reaper", "Melee")
				else
					local srPos = Vector3.new(-9570.0, 315.9, 6726.8)
					setStatus("💀 Volando a Haunted Castle por Soul Reaper...", KX.phaseText)
					KX.moveToCFrame(CFrame.new(srPos + Vector3.new(0, 20, 0)))
				end
				return true
			end
			if hallowEssence then
				KX.phaseText = "Tier 1: Invocando Soul Reaper (Hallow Essence)"
				local altarPos = Vector3.new(-8932.3, 146.8, 6062.5)
				setStatus("💀 Colocando Hallow Essence en el altar de Haunted Castle...", KX.phaseText)
				if KX.moveToCFrame(CFrame.new(altarPos + Vector3.new(0, 2, 0))) or (hrp.Position - altarPos).Magnitude <= 20 then
					KX.equipExactTool(hallowEssence)
					local hc = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Haunted Castle")
					local summoner = hc and hc:FindFirstChild("Summoner") and hc.Summoner:FindFirstChild("Detection")
					if summoner and summoner:IsA("BasePart") and firetouchinterest then
						pcall(function()
							firetouchinterest(hrp, summoner, 0)
							firetouchinterest(hrp, summoner, 1)
						end)
					end
				end
				return true
			end
			-- Opportunistic Death King roll if carrying plenty of Bones (> 550 so 500 stay reserved for Soul Guitar)
			if (KX.materials["Bones"] or 0) >= 550 and (os.clock() - lastBonesRollClock >= 12.0) then
				lastBonesRollClock = os.clock()
				pcall(function() CommF_:InvokeServer("Bones", "Buy", 1, 1) end)
			end
		elseif sea == 2 then
			-- 1E) DARKBEARD -> DARK FRAGMENT
			local dbModel, dbInEnemies = KX.findBossOrEnemy({"Darkbeard"}, true)
			local fistOfDarkness = KX.hasToolAnywhere("Fist of Darkness")
			if dbModel then
				KX.phaseText = "Tier 1: Boss Darkbeard"
				if dbInEnemies then
					KX.engageTarget(dbModel, nil, "🌑 Derrotando a Darkbeard", "Melee")
				else
					local arenaPos = Vector3.new(3777.5, 25.0, -3498.8)
					setStatus("🌑 Volando a Dark Arena por Darkbeard...", KX.phaseText)
					KX.moveToCFrame(CFrame.new(arenaPos + Vector3.new(0, 25, 0)))
				end
				return true
			end
			if fistOfDarkness then
				KX.phaseText = "Tier 1: Invocando Darkbeard (Fist of Darkness)"
				local pedPos = Vector3.new(3777.5, 15.0, -3498.8)
				setStatus("🌑 Activando Fist of Darkness en Dark Arena...", KX.phaseText)
				if KX.moveToCFrame(CFrame.new(pedPos + Vector3.new(0, 2, 0))) or (hrp.Position - pedPos).Magnitude <= 20 then
					KX.equipExactTool(fistOfDarkness)
					local da = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("DarkbeardArena")
					local det = da and da:FindFirstChild("Summoner") and da.Summoner:FindFirstChild("Detection")
					if det and det:IsA("BasePart") and firetouchinterest then
						pcall(function()
							firetouchinterest(hrp, det, 0)
							firetouchinterest(hrp, det, 1)
						end)
					end
				end
				return true
			end
		end

		return false
	end

	-- =========================================================================
	-- SMART MELEE ROTATION HELPER (PREPARES GODHUMAN AUTOMATICALLY WHILE GRINDING)
	-- =========================================================================
	local STYLE_PIPELINE = {
		{name = "Black Leg", alt = "Dark Step", buyArg = "BuyBlackLeg", reqMast = 400, beli = 150000, frag = 0, minSea = 1},
		{name = "Electro", alt = "Electro", buyArg = "BuyElectro", reqMast = 400, beli = 500000, frag = 0, minSea = 1},
		{name = "Fishman Karate", alt = "Water Kung Fu", buyArg = "BuyFishmanKarate", reqMast = 400, beli = 750000, frag = 0, minSea = 1},
		{name = "Dragon Claw", alt = "Dragon Breath", isDragonClaw = true, reqMast = 400, beli = 0, frag = 1500, minSea = 2},
		{name = "Superhuman", alt = "Superhuman", buyArg = "BuySuperhuman", reqMast = 400, beli = 3000000, frag = 0, minSea = 2},
		{name = "Death Step", alt = "Death Step", buyArg = "BuyDeathStep", reqMast = 400, beli = 2500000, frag = 5000, minSea = 2},
		{name = "Sharkman Karate", alt = "Sharkman Karate", buyArg = "BuySharkmanKarate", reqMast = 400, beli = 2500000, frag = 5000, minSea = 2},
		{name = "Electric Claw", alt = "Electric Claw", buyArg = "BuyElectricClaw", reqMast = 400, beli = 3000000, frag = 5000, minSea = 3},
		{name = "Dragon Talon", alt = "Dragon Talon", buyArg = "BuyDragonTalon", reqMast = 400, beli = 3000000, frag = 5000, minSea = 3},
	}

	local lastStyleCheckClock = 0
	function KX.getStyleMastery(entry)
		return math.max(KX.meleeMastery[entry.name] or 0, KX.meleeMastery[entry.alt] or 0)
	end

	function KX.stepPassiveMeleeRotation()
		if KX.ownedMelees["Godhuman"] or not CommF_ then return end
		if os.clock() - lastStyleCheckClock < 15.0 then return end
		lastStyleCheckClock = os.clock()

		KX.scanRealtimeMeleeAndWeapons()

		-- Keep leveling current non-starter style until Mastery 400!
		if KX.currentMeleeCanon ~= "None"
			and KX.currentMeleeCanon ~= "Combat"
			and KX.currentMeleeLevel > 0
			and KX.currentMeleeLevel < 400 then
			return
		end

		local now = os.clock()
		for _, st in ipairs(STYLE_PIPELINE) do
			local cdUntil = KX.styleSwitchCooldown[st.alt]
			if KX.worldNum >= st.minSea
				and KX.getStyleMastery(st) < st.reqMast
				and (not cdUntil or now >= cdUntil) then
				if KX.beli >= st.beli and KX.fragments >= st.frag then
					pcall(function()
						if st.isDragonClaw then
							CommF_:InvokeServer("BlackbeardReward", "DragonClaw", "1")
							CommF_:InvokeServer("BlackbeardReward", "DragonClaw", "2")
						else
							CommF_:InvokeServer(st.buyArg, true)
							CommF_:InvokeServer(st.buyArg)
						end
					end)
					task.wait(0.55)
					KX.scanRealtimeMeleeAndWeapons()
					saveConfig()
					if KX.currentMeleeCanon ~= st.alt then
						-- Teacher quest / prerequisites not unlocked yet -> cooldown 5 mins so it NEVER loops!
						KX.styleSwitchCooldown[st.alt] = os.clock() + 300.0
					end
					return
				end
			end
		end
	end

	function KX.stepStandardSeaLevelFarm(hrp, customLabel)
		KX.stepPassiveMeleeRotation()
		local qInfo = KX.getBestLevelQuest()
		if qInfo then
			if KX.ensureQuestAccepted(qInfo, hrp) then
				local lbl = customLabel or ("⚔️ Farm Level [" .. tostring(KX.level) .. "]")
				KX.farmMobSpawns(qInfo.mobName, qInfo.spawns, lbl, "Melee")
			end
		else
			local mob = KX.findNearestAliveFromSet(CAKE_LAND_MOBS)
			if mob then
				KX.engageTarget(mob, CAKE_LAND_MOBS, customLabel or "⚔️ Farm Level (Cake Land)", "Melee")
			else
				KX.moveToCFrame(CFrame.new(-2095.0, 70.0, -12140.0))
			end
		end
	end

	-- =========================================================================
	-- TIER 1.5: AUTO DUNGEON RAID (PRIORITY OVER LEVEL FARM • FRUITS <= 1M BELI
	--           • KILL AURA ISLANDS 1-3 + FIGHTING STYLE MELEE ON ALL ISLANDS)
	-- =========================================================================
	local RAID_FRUITS_MAX_1M = {
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
		{key = "Quake-Quake",     price = 1000000},
	}

	local RAID_FRUIT_PRICE_MAP = {}
	for _, entry in ipairs(RAID_FRUITS_MAX_1M) do
		RAID_FRUIT_PRICE_MAP[entry.key] = entry.price
	end

	local STANDARD_RAID_CHIPS = {
		["Flame-Flame"]   = "Flame",
		["Ice-Ice"]       = "Ice",
		["Quake-Quake"]   = "Quake",
		["Light-Light"]   = "Light",
		["Dark-Dark"]     = "Dark",
		["Spider-Spider"] = "Spider",
		["String-String"] = "Spider",
		["Rumble-Rumble"] = "Rumble",
		["Lightning-Lightning"] = "Rumble",
		["Magma-Magma"]   = "Magma",
		["Buddha-Buddha"] = "Buddha",
		["Sand-Sand"]     = "Sand",
	}

	local raidEnteredAt = 0
	local islandClearClock = 0
	local summonArriveClock = 0
	local raidChipFailCount = 0
	local lastRaidChipBuyClock = 0
	local lastRaidFruitLoadClock = 0
	local lastRaidBtnClickClock = 0
	local lastRaidPortalClock = 0
	local postRaidAwakenUntil = 0
	local lastAwakenTryClock = 0
	local lastKillAuraPulseClock = 0

	function KX.getPreferredRaidChipName()
		local sel = tostring(KX.selectedRaidType or "Auto")
		if sel ~= "" and sel ~= "Auto" then
			return sel
		end
		local dfChip = STANDARD_RAID_CHIPS[tostring(KX.devilFruit or "")]
		if dfChip then
			return dfChip
		end
		return "Flame"
	end

	local function isPhysicalFruitToolForRaid(tool)
		if not tool or not tool:IsA("Tool") then return false end
		if tool.ToolTip == "Blox Fruit" or tool.ToolTip == "Melee" or tool.ToolTip == "Sword" or tool.ToolTip == "Gun" then
			return false
		end
		return (tool.Name:find(" Fruit") ~= nil)
			or (tool:FindFirstChild("EatRemote") ~= nil)
			or (tostring(tool:GetAttribute("OriginalName") or ""):find("-") ~= nil)
	end

	local function getPhysicalFruitKeyAndMax1MPrice(tool)
		local orig = tostring(tool:GetAttribute("OriginalName") or "")
		if orig == "" then
			local base = tool.Name:gsub(" Fruit$", "")
			orig = base .. "-" .. base
		end
		return orig, RAID_FRUIT_PRICE_MAP[orig]
	end

	function KX.findRaidIslandPart(islandNum, refPos)
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

	function KX.isPlayerInRaid(hrp)
		local pg = LocalPlayer:FindFirstChild("PlayerGui")
		local main = pg and (pg:FindFirstChild("Main") or pg:FindFirstChild("Main (minimal)"))
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
				local part, dist = KX.findRaidIslandPart(i, hrp.Position)
				if part and dist < 2400 then
					return true
				end
			end
		end
		return false
	end

	function KX.isInAwakeningRoom(hrp)
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

	-- Kill Aura strictly for Raid Islands 1, 2, and 3!
	function KX.applyRaidKillAura(centerPos)
		if not KX.raidKillAuraUpTo3 or (KX.raidIslandIdx or 1) > 3 then
			return
		end
		if os.clock() - lastKillAuraPulseClock < 0.16 then
			return
		end
		lastKillAuraPulseClock = os.clock()

		pcall(function()
			if sethiddenproperty then
				sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
			end
		end)

		local enemies = Workspace:FindFirstChild("Enemies")
		if not enemies or not centerPos then return end
		for _, m in ipairs(enemies:GetChildren()) do
			if m:IsA("Model") and KX.isModelAlive(m) then
				local eHum = m:FindFirstChildOfClass("Humanoid")
				local eRoot = KX.getModelRoot(m)
				if eHum and eRoot and (eRoot.Position - centerPos).Magnitude <= 550 then
					pcall(function()
						eRoot.CanCollide = false
						eRoot.AssemblyLinearVelocity = Vector3.zero
						eHum.WalkSpeed = 0
						eHum.JumpPower = 0
						eHum.Health = 0
					end)
				end
			end
		end
	end

	-- Stores any > 1,000,000 Beli physical fruit in Character/Backpack so RaidsNpc NEVER consumes a >1M fruit!
	function KX.safeguardHighValueFruitsBeforeRaid(allowedLowTool)
		if not CommF_ then return false end
		local hasUnsafeHighFruit = false
		for _, cont in ipairs({LocalPlayer.Character, LocalPlayer:FindFirstChild("Backpack")}) do
			if cont then
				for _, tool in ipairs(cont:GetChildren()) do
					if isPhysicalFruitToolForRaid(tool) and tool ~= allowedLowTool then
						local origKey, lowPrice = getPhysicalFruitKeyAndMax1MPrice(tool)
						local canUseLow = lowPrice and lowPrice <= 1000000 and (origKey ~= "Quake-Quake" or KX.questsDone.donSwan)
						if not canUseLow then
							pcall(function()
								CommF_:InvokeServer("StoreFruit", origKey, tool)
							end)
							task.wait(0.1)
							if tool.Parent == LocalPlayer.Character or tool.Parent == LocalPlayer:FindFirstChild("Backpack") then
								hasUnsafeHighFruit = true
							end
						end
					end
				end
			end
		end
		return not hasUnsafeHighFruit
	end

	function KX.getHeldRaidFruitMax1M()
		local bestTool, bestKey, bestPrice = nil, nil, math.huge
		for _, cont in ipairs({LocalPlayer:FindFirstChild("Backpack"), LocalPlayer.Character}) do
			if cont then
				for _, tool in ipairs(cont:GetChildren()) do
					if isPhysicalFruitToolForRaid(tool) then
						local origKey, lowPrice = getPhysicalFruitKeyAndMax1MPrice(tool)
						local allowQuake = (origKey ~= "Quake-Quake") or KX.questsDone.donSwan
						local wantToEat = KX.autoEatAllowedFruits and KX.allowedEatFruits[origKey] and not KX.allowedEatFruits[KX.devilFruit]
						if lowPrice and lowPrice <= 1000000 and allowQuake and (not wantToEat) and lowPrice < bestPrice then
							bestPrice = lowPrice
							bestTool = tool
							bestKey = origKey
						end
					end
				end
			end
		end
		return bestTool, bestKey, bestPrice
	end

	function KX.hasOrCanLoadRaidFruitMax1M()
		local held = KX.getHeldRaidFruitMax1M()
		if held then return true end
		for _, entry in ipairs(RAID_FRUITS_MAX_1M) do
			local fk = entry.key
			local allowQuake = (fk ~= "Quake-Quake") or KX.questsDone.donSwan
			local wantToEat = KX.autoEatAllowedFruits and KX.allowedEatFruits[fk] and not KX.allowedEatFruits[KX.devilFruit]
			if allowQuake and (not wantToEat) and (KX.storedFruits[fk] or 0) > 0 then
				return true
			end
		end
		return false
	end

	function KX.ensureRaidFruitMax1MInBackpack()
		local heldTool, heldKey, heldPrice = KX.getHeldRaidFruitMax1M()
		if heldTool then
			KX.protectedTool = heldTool
			return heldTool, heldKey, heldPrice
		end
		if not CommF_ or (os.clock() - lastRaidFruitLoadClock < 2.2) then
			return nil
		end
		lastRaidFruitLoadClock = os.clock()

		-- Refresh storedFruits from modern Inventory.RemoteUtil tiles if needed
		local candidates = {}
		for _, entry in ipairs(RAID_FRUITS_MAX_1M) do
			local fk = entry.key
			local allowQuake = (fk ~= "Quake-Quake") or KX.questsDone.donSwan
			local wantToEat = KX.autoEatAllowedFruits and KX.allowedEatFruits[fk] and not KX.allowedEatFruits[KX.devilFruit]
			if allowQuake and (not wantToEat) and (KX.storedFruits[fk] or 0) > 0 then
				table.insert(candidates, entry)
			end
		end

		local tryList = (#candidates > 0) and candidates or RAID_FRUITS_MAX_1M
		for _, entry in ipairs(tryList) do
			local fk = entry.key
			local allowQuake = (fk ~= "Quake-Quake") or KX.questsDone.donSwan
			local wantToEat = KX.autoEatAllowedFruits and KX.allowedEatFruits[fk] and not KX.allowedEatFruits[KX.devilFruit]
			if allowQuake and not wantToEat then
				pcall(function()
					local ch = LocalPlayer.Character
					local busy = ch and ch:FindFirstChild("Busy")
					if busy and busy:IsA("BoolValue") then busy.Value = false end
					CommF_:InvokeServer("LoadFruit", fk)
				end)
				task.wait(0.18)
				local loadedTool, loadedKey, loadedPrice = KX.getHeldRaidFruitMax1M()
				if loadedTool then
					if KX.storedFruits[loadedKey] and KX.storedFruits[loadedKey] > 0 then
						KX.storedFruits[loadedKey] = KX.storedFruits[loadedKey] - 1
					end
					KX.protectedTool = loadedTool
					return loadedTool, loadedKey, loadedPrice
				end
				if #candidates > 0 then
					break
				end
			end
		end
		return nil
	end

	function KX.needsFragmentsForProgression()
		if not KX.ownedMelees["Godhuman"] then
			for _, st in ipairs(STYLE_PIPELINE) do
				if (st.frag or 0) > 0 and KX.getStyleMastery(st) < st.reqMast then
					if KX.fragments < st.frag then
						return true
					end
				end
			end
			if KX.fragments < 15000 then
				return true
			end
		end
		if not KX.ownedGuns["Soul Guitar"] and KX.fragments < 5000 then
			return true
		end
		if not KX.ownedGuns["Kabucha"] and KX.fragments < 1500 then
			return true
		end
		return false
	end

	function KX.tryStepAutoRaid(hrp, hum)
		local inRaid = KX.isPlayerInRaid(hrp)
		local raidChip = KX.getPreferredRaidChipName()

		-- 1) ACTIVE DUNGEON RAID EXECUTION (ISLAND 1 -> ISLAND 5)
		--    Islands 1-3: Kill Aura + Fighting Style (Melee)
		--    Islands 4-5: Fighting Style (Melee) Only!
		if inRaid then
			if not KX.wasInRaid then
				KX.wasInRaid = true
				raidEnteredAt = os.clock()
				KX.raidIslandIdx = 1
				islandClearClock = 0
				summonArriveClock = 0
				raidChipFailCount = 0
				KX.protectedTool = nil
			end

			KX.stepPassiveMeleeRotation()

			pcall(function()
				if sethiddenproperty then
					sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
				end
			end)

			-- Update current island index if player or mob is near a higher island (1..5)
			for k = 1, 5 do
				local iPart, iDist = KX.findRaidIslandPart(k, hrp.Position)
				if iPart and iDist < 650 and k > (KX.raidIslandIdx or 1) then
					KX.raidIslandIdx = k
				end
			end

			local mob = KX.findNearestAliveFromSet(nil)
			if mob then
				local mRoot = KX.getModelRoot(mob)
				if mRoot and (mRoot.Position - hrp.Position).Magnitude <= 2600 then
					for k = 1, 5 do
						local iPart, iDist = KX.findRaidIslandPart(k, mRoot.Position)
						if iPart and iDist < 900 and k > (KX.raidIslandIdx or 1) then
							KX.raidIslandIdx = k
						end
					end
					islandClearClock = 0
					local curIsl = KX.raidIslandIdx or 1
					local useKA = (curIsl <= 3) and KX.raidKillAuraUpTo3
					local modeTag = useKA and "Kill Aura + Melee" or "Solo Melee"
					KX.phaseText = string.format("Auto Raid [%s] • Isla %d/5 (%s)", raidChip, curIsl, modeTag)
					KX.lastRaidStatus = string.format("Isla %d/5 (%s)", curIsl, modeTag)

					-- Always attack with Fighting Style (Melee) so mastery & hits register cleanly
					KX.engageTarget(
						mob,
						(not useKA) and nil or nil,
						string.format("⚡ Raid %s [Isla %d/5 • %s]", raidChip, curIsl, modeTag),
						"Melee"
					)
					if not useKA and mRoot then
						KX.bringClusterMobs(mRoot.Position, nil)
					end
					if useKA then
						KX.applyRaidKillAura(hrp.Position)
					end
					return true
				end
			end

			-- No alive mobs on current island -> Advance to next Raid Island (1 -> 2 -> 3 -> 4 -> 5)!
			if islandClearClock > 0
				and (os.clock() - islandClearClock >= 3.2)
				and (os.clock() - raidEnteredAt >= 5.0)
				and (KX.raidIslandIdx or 1) < 5 then
				local nextPart = KX.findRaidIslandPart((KX.raidIslandIdx or 1) + 1, hrp.Position)
				if nextPart then
					KX.raidIslandIdx = (KX.raidIslandIdx or 1) + 1
					islandClearClock = 0
				end
			end

			local islPart = KX.findRaidIslandPart(KX.raidIslandIdx or 1, hrp.Position)
			if not islPart then
				for k = 5, 1, -1 do
					local p = KX.findRaidIslandPart(k, hrp.Position)
					if p then
						KX.raidIslandIdx = k
						islPart = p
						break
					end
				end
			end

			local curIsl = KX.raidIslandIdx or 1
			local useKA = (curIsl <= 3) and KX.raidKillAuraUpTo3
			local modeTag = useKA and "Kill Aura + Melee" or "Solo Melee"
			KX.phaseText = string.format("Auto Raid [%s] • Isla %d/5 (%s)", raidChip, curIsl, modeTag)
			KX.lastRaidStatus = string.format("Isla %d/5 (%s)", curIsl, modeTag)

			if islPart then
				local hoverPos = islPart.Position + Vector3.new(0, 26, 0)
				setStatus(string.format("⚡ Raid %s: Avanzando / Esperando oleada en Isla %d/5 (%s)...", raidChip, curIsl, modeTag), KX.phaseText)
				local reached = KX.moveToCFrame(CFrame.new(hoverPos))
				if reached or (hrp.Position - hoverPos).Magnitude <= 55 then
					if islandClearClock == 0 then
						islandClearClock = os.clock()
					end
					if useKA then
						KX.applyRaidKillAura(hrp.Position)
					end
				end
			else
				setStatus(string.format("⚡ Raid %s activa: Esperando carga de Isla %d/5...", raidChip, curIsl), KX.phaseText)
			end
			return true
		end

		-- 2) POST-RAID AWAKENING ROOM HANDLER
		if KX.wasInRaid then
			KX.wasInRaid = false
			raidEnteredAt = 0
			KX.raidIslandIdx = 1
			islandClearClock = 0
			postRaidAwakenUntil = os.clock() + 4.5
			KX.lastRaidStatus = "Raid Completada (+Fragmentos)"
		end

		local inAwkRoom = KX.isInAwakeningRoom(hrp)
		if os.clock() < postRaidAwakenUntil or inAwkRoom then
			if CommF_ and (os.clock() - lastAwakenTryClock >= 1.5) then
				lastAwakenTryClock = os.clock()
				pcall(function()
					CommF_:InvokeServer("Awakener", "Check")
					CommF_:InvokeServer("Awakener", "Awaken")
				end)
			end
			if inAwkRoom and CommF_ then
				pcall(function() CommF_:InvokeServer("Awakener", "Teleport") end)
				setStatus("✨ Saliendo de Awakening Room tras completar la Raid...", "Auto Raid")
				return true
			elseif os.clock() < postRaidAwakenUntil then
				setStatus("✨ ¡Raid completada! Verificando despertar / fragmentos...", "Auto Raid")
				return true
			end
		end

		if not KX.autoRaid then
			KX.lastRaidStatus = "Off"
			return false
		end

		-- Must be in Sea 2 or Sea 3 and Lv >= 1100 to purchase Special Microchip from RaidsNpc
		if (KX.worldNum ~= 2 and KX.worldNum ~= 3) or KX.level < 1100 then
			KX.lastRaidStatus = (KX.level < 1100) and ("Req. Lv.1100 (" .. tostring(KX.level) .. ")") or "Esperando Sea 2/3"
			return false
		end

		local chipTool = KX.hasToolAnywhere("Special Microchip")
		if not chipTool then
			if os.clock() < (KX.raidCooldownUntil or 0) then
				local remCd = math.max(1, math.ceil((KX.raidCooldownUntil or 0) - os.clock()))
				KX.lastRaidStatus = string.format("En espera (%ds)", remCd)
				return false
			end

			local hasFruitMax1M = KX.hasOrCanLoadRaidFruitMax1M()
			local needFrags = KX.needsFragmentsForProgression()
			if not hasFruitMax1M and not (needFrags and KX.beli >= 1100000) then
				KX.raidCooldownUntil = os.clock() + 60.0
				KX.lastRaidStatus = "Sin Fruta <=1M disponible"
				return false
			end

			summonArriveClock = 0
			KX.phaseText = "Tier 1.5: Auto Raid (Preparando Microchip <=1M)"

			local lowFruitTool, lowFruitKey, lowFruitPrice = KX.ensureRaidFruitMax1MInBackpack()
			if not KX.safeguardHighValueFruitsBeforeRaid(lowFruitTool) then
				-- Unsafe >1M fruit in backpack that couldn't be stored -> never risk it!
				KX.protectedTool = nil
				KX.raidCooldownUntil = os.clock() + 60.0
				KX.lastRaidStatus = "Protegiendo Fruta >1M"
				return false
			end

			if CommF_ and (os.clock() - lastRaidChipBuyClock >= 2.2) then
				lastRaidChipBuyClock = os.clock()
				setStatus(
					string.format(
						"⚡ Auto Raid [%s]: Comprando Special Microchip %s...",
						raidChip,
						lowFruitKey and ("con " .. tostring(lowFruitKey) .. " ($" .. tostring(lowFruitPrice or 0) .. ")") or "(Beli)"
					),
					KX.phaseText
				)
				pcall(function()
					CommF_:InvokeServer("RaidsNpc", "Select", raidChip)
				end)
				task.wait(0.25)
				chipTool = KX.hasToolAnywhere("Special Microchip")
				if chipTool then
					raidChipFailCount = 0
					KX.protectedTool = nil
				else
					raidChipFailCount = raidChipFailCount + 1
				end
			end

			if not chipTool then
				if raidChipFailCount >= 2 then
					raidChipFailCount = 0
					KX.protectedTool = nil
					KX.raidCooldownUntil = os.clock() + 75.0
					KX.lastRaidStatus = "Cooldown Chip (75s)"
					return false
				end
				return true
			end
		end

		-- 3) HOLDING "SPECIAL MICROCHIP" -> FLY TO RAIDSUMMON2 CAPSULE & START RAID!
		KX.protectedTool = nil
		KX.phaseText = string.format("Tier 1.5: Auto Raid [%s] (Iniciando Cápsula)", raidChip)
		KX.lastRaidStatus = "Iniciando en Cápsula (" .. raidChip .. ")"

		local map = Workspace:FindFirstChild("Map")
		local raidSummon2 = nil
		if KX.worldNum == 2 then
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
			or ((KX.worldNum == 2) and Vector3.new(-6528.17, 306.51, -4670.70) or Vector3.new(-5017.5, 314.8, -2825.4))

		-- Fast Sea 3 Castle on the Sea portal shortcut if far from RaidSummon2
		if KX.worldNum == 3 and (hrp.Position - btnPos).Magnitude > 1200 and CommF_ and (os.clock() - lastRaidPortalClock >= 3.5) then
			lastRaidPortalClock = os.clock()
			KX.stopTween()
			pcall(function()
				CommF_:InvokeServer("requestEntrance", Vector3.new(-5075.5, 314.5, -3150.0))
			end)
			task.wait(0.25)
			hrp, hum = KX.getRootAndHum()
			if not hrp or not hum then return true end
		end

		setStatus(string.format("⚡ Auto Raid [%s]: Activando cápsula de Raid...", raidChip), KX.phaseText)
		local targetStandPos = btnPos + Vector3.new(0, 3, 0)
		if summonArriveClock > 0 and (os.clock() - summonArriveClock > 4.0) and podPart and podPart:IsA("BasePart") then
			targetStandPos = podPart.Position + Vector3.new(0, 3, 0)
		end

		local reached = KX.moveToCFrame(CFrame.new(targetStandPos))
		if reached or (hrp.Position - btnPos).Magnitude <= 28 then
			if summonArriveClock == 0 then
				summonArriveClock = os.clock()
			end
			pcall(function() hum:UnequipTools() end)
			if cd and fireclickdetector and (os.clock() - lastRaidBtnClickClock >= 1.3) then
				lastRaidBtnClickClock = os.clock()
				pcall(function() fireclickdetector(cd) end)
			end
			if (os.clock() - summonArriveClock > 16.0) then
				summonArriveClock = 0
				KX.raidCooldownUntil = os.clock() + 45.0
				KX.serverHop("Cápsulas de Raid ocupadas")
				return true
			end
		end
		return true
	end

	-- =========================================================================
	-- TIER 2: LEVEL 1 -> MAX (2800) + SEA 1/2/3 STORYLINE + SABER
	-- =========================================================================
	local JUNGLE_BUTTONS_FALLBACK = {
		Vector3.new(-1612.0, 36.9, 148.0),
		Vector3.new(-1428.0, 62.8, -50.0),
		Vector3.new(-1317.0, 31.8, -110.0),
		Vector3.new(-1182.0, 23.0, 368.0),
		Vector3.new(-2151.0, 29.5, -10.0),
	}

	function KX.stepSea1SaberQuest(hrp)
		KX.phaseText = "Tier 2: Unlocking Saber (Sea 1)"
		if KX.worldNum ~= 1 then
			KX.travelToSea(1)
			return
		end
		local prog = nil
		pcall(function() prog = CommF_:InvokeServer("ProQuestProgress") end)
		local platesDone = (type(prog) == "table" and prog.Plates and #prog.Plates >= 5) or false

		if type(prog) == "table" and prog.KilledMob then
			-- Kill Saber Expert if Relic already placed!
			local relicTool = KX.hasToolAnywhere("Relic")
			if relicTool then
				local doorPos = Vector3.new(-1406.6, 29.9, 4.5)
				setStatus("🗡️ Colocando Relic en la puerta de Saber Expert...", KX.phaseText)
				if KX.moveToCFrame(CFrame.new(doorPos)) or (hrp.Position - doorPos).Magnitude <= 20 then
					KX.equipExactTool(relicTool)
					pcall(function() CommF_:InvokeServer("ProQuestProgress", "PlaceRelic") end)
				end
				return
			end
			local saberBoss, inEn = KX.findBossOrEnemy({"Saber Expert"}, true)
			if saberBoss and inEn then
				KX.engageTarget(saberBoss, nil, "🗡️ Derrotando a Saber Expert", "Melee")
			else
				local bossRoom = Vector3.new(-1458.8, 29.8, -50.6)
				setStatus("🗡️ Esperando / Buscando a Saber Expert...", KX.phaseText)
				if KX.moveToCFrame(CFrame.new(bossRoom)) then
					KX.serverHop("Saber Expert respawn")
				end
			end
			return
		end

		-- Step plates -> Torch -> Burn -> Cup -> Water -> SickMan -> RichMan -> Mob Leader -> RichMan
		if not platesDone then
			local jMap = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Jungle")
			local btns = jMap and jMap:FindFirstChild("QuestPlates")
			if btns then
				for _, bModel in ipairs(btns:GetChildren()) do
					local bPart = bModel:FindFirstChild("Button")
					if bPart and bPart:IsA("BasePart") and bPart.BrickColor.Name ~= "Camo" then
						setStatus("🗡️ Saber Puzzle: Pisando botón de Jungle...", KX.phaseText)
						if KX.moveToCFrame(bPart.CFrame * CFrame.new(0, 1.5, 0)) then
							hrp.CFrame = bPart.CFrame
							if firetouchinterest then
								pcall(function()
									firetouchinterest(hrp, bPart, 0)
									firetouchinterest(hrp, bPart, 1)
								end)
							end
						end
						return
					end
				end
			else
				KX.moveToCFrame(CFrame.new(JUNGLE_BUTTONS_FALLBACK[1]))
				return
			end
		end

		if type(prog) == "table" and not prog.UsedTorch then
			local torch = KX.hasToolAnywhere("Torch")
			if not torch then
				local torchPos = Vector3.new(-1610.0, 12.1, 163.0)
				setStatus("🗡️ Saber Puzzle: Tomando Antorcha en Jungle...", KX.phaseText)
				KX.moveToCFrame(CFrame.new(torchPos))
				pcall(function() CommF_:InvokeServer("ProQuestProgress", "GetTorch") end)
			else
				local desertDoor = Vector3.new(1114.6, 5.0, 4350.2)
				setStatus("🗡️ Saber Puzzle: Quemando puerta secreta en Desert...", KX.phaseText)
				if KX.moveToCFrame(CFrame.new(desertDoor)) then
					KX.equipExactTool(torch)
					pcall(function() CommF_:InvokeServer("ProQuestProgress", "DestroyTorch") end)
				end
			end
			return
		end

		if type(prog) == "table" and not prog.UsedCup then
			local cup = KX.hasToolAnywhere("Cup")
			if not cup then
				local cupPos = Vector3.new(1113.7, 7.2, 4365.2)
				setStatus("🗡️ Saber Puzzle: Recogiendo Copa en Desert...", KX.phaseText)
				if KX.moveToCFrame(CFrame.new(cupPos)) then
					pcall(function() CommF_:InvokeServer("ProQuestProgress", "GetCup") end)
				end
			else
				local leakPos = Vector3.new(1395.8, 37.5, -1324.6)
				setStatus("🗡️ Saber Puzzle: Llenando Copa en Frozen Village y ayudando a Sick Man...", KX.phaseText)
				if KX.moveToCFrame(CFrame.new(leakPos)) then
					KX.equipExactTool(cup)
					pcall(function()
						CommF_:InvokeServer("ProQuestProgress", "FillCup", cup)
						CommF_:InvokeServer("ProQuestProgress", "SickMan")
					end)
				end
			end
			return
		end

		if type(prog) == "table" and not prog.TalkedSon then
			pcall(function() CommF_:InvokeServer("ProQuestProgress", "RichSon") end)
			return
		end

		if type(prog) == "table" and not prog.KilledMob then
			local ml, inEn = KX.findBossOrEnemy({"Mob Leader"}, true)
			if ml and inEn then
				KX.engageTarget(ml, nil, "🗡️ Derrotando a Mob Leader (Saber)", "Melee")
			else
				local mlPos = Vector3.new(-2848.5, 7.4, 5342.4)
				setStatus("🗡️ Yendo a la cueva de Mob Leader...", KX.phaseText)
				KX.moveToCFrame(CFrame.new(mlPos))
			end
			pcall(function() CommF_:InvokeServer("ProQuestProgress", "RichSon") end)
		end
	end

	function KX.stepSea1ToSea2Quest(hrp)
		KX.phaseText = "Tier 2: Dressrosa Quest (Sea 1 -> Sea 2)"
		local dProg = nil
		pcall(function() dProg = CommF_:InvokeServer("DressrosaQuestProgress") end)
		if type(dProg) == "table" and dProg.KilledIceBoss then
			local capPos = KX.getNPCWorldPos("Experienced Captain", Vector3.new(-656.2, 7.8, 1580.8))
			setStatus("🚢 Viajando al Segundo Sea con Experienced Captain...", KX.phaseText)
			if KX.moveToCFrame(CFrame.new(capPos + Vector3.new(0, 3, 3))) then
				pcall(function()
					CommF_:InvokeServer("DressrosaQuestProgress", "Dressrosa")
					CommF_:InvokeServer("TravelDressrosa")
				end)
			end
			return
		end

		local keyTool = KX.hasToolAnywhere("Key")
		if not keyTool and (not dProg or not dProg.UsedKey) then
			local detPos = KX.getNPCWorldPos("Military Detective", Vector3.new(4851.9, 5.6, 718.5))
			setStatus("🔑 Obteniendo Key con Military Detective (Prison)...", KX.phaseText)
			if KX.moveToCFrame(CFrame.new(detPos + Vector3.new(0, 3, 3))) then
				pcall(function() CommF_:InvokeServer("DressrosaQuestProgress", "Detective") end)
			end
			return
		end

		if keyTool then
			local doorPos = Vector3.new(1347.7, 37.3, -1325.6)
			setStatus("🔑 Abriendo puerta de Ice Admiral en Frozen Village...", KX.phaseText)
			if KX.moveToCFrame(CFrame.new(doorPos)) then
				KX.equipExactTool(keyTool)
				pcall(function() CommF_:InvokeServer("DressrosaQuestProgress", "UseKey") end)
			end
			return
		end

		local iceBoss, inEn = KX.findBossOrEnemy({"Ice Admiral"}, true)
		if iceBoss and inEn then
			KX.engageTarget(iceBoss, nil, "❄️ Derrotando a Ice Admiral (Sea 2 Unlock)", "Melee")
		else
			local cavePos = Vector3.new(1348.0, 37.3, -1328.0)
			setStatus("❄️ Esperando a Ice Admiral...", KX.phaseText)
			if KX.moveToCFrame(CFrame.new(cavePos)) then
				KX.serverHop("Ice Admiral respawn")
			end
		end
	end

	function KX.stepBartiloQuest(hrp)
		KX.phaseText = "Tier 2: Quest Bartilo (Sea 2)"
		local bp2 = nil
		pcall(function() bp2 = CommF_:InvokeServer("BartiloQuestProgress") end)
		local bartiloPos = KX.getNPCWorldPos("Bartilo", Vector3.new(-461.5, 72.3, 300.3))

		if type(bp2) == "table" and bp2.KilledBandits and bp2.KilledSpring and bp2.DidPlates then
			pcall(function() CommF_:InvokeServer("BartiloQuestProgress", "Bartilo") end)
			KX.questsDone.bartilo = true
			return
		end

		if not bp2 or not bp2.KilledBandits then
			local hasQ, matches = KX.getActiveQuestInfo("BartiloQuest", "Swan Pirate")
			if not (hasQ and matches) then
				setStatus("🔨 Bartilo [1/3]: Aceptando 50 Swan Pirates...", KX.phaseText)
				if KX.moveToCFrame(CFrame.new(bartiloPos + Vector3.new(0, 3, 3))) then
					pcall(function()
						CommF_:InvokeServer("BartiloQuestProgress", "Bartilo")
						CommF_:InvokeServer("StartQuest", "BartiloQuest", 1)
					end)
				end
				return
			end
			KX.farmMobSpawns("Swan Pirate", {CFrame.new(970, 122, 1235), CFrame.new(1055, 122, 1320)}, "🔨 Bartilo [50 Swan Pirates]", "Melee")
			return
		end

		if not bp2.KilledSpring then
			pcall(function() CommF_:InvokeServer("BartiloQuestProgress", "Bartilo") end)
			local jeremy, inEn = KX.findBossOrEnemy({"Jeremy"}, true)
			if jeremy and inEn then
				KX.engageTarget(jeremy, nil, "🔨 Bartilo [2/3]: Derrotando a Jeremy", "Melee")
			else
				local jPos = Vector3.new(2173.2, 449.0, 853.8)
				setStatus("🔨 Bartilo [2/3]: Buscando a Jeremy...", KX.phaseText)
				if KX.moveToCFrame(CFrame.new(jPos)) then
					KX.serverHop("Jeremy Boss respawn")
				end
			end
			return
		end

		if not bp2.DidPlates then
			pcall(function() CommF_:InvokeServer("BartiloQuestProgress", "Bartilo") end)
			local dress = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Dressrosa")
			local pf = dress and dress:FindFirstChild("BartiloPlates")
			if not pf then
				KX.moveToCFrame(CFrame.new(BARTILO_PLATES_POS[1] + Vector3.new(0, 3, 0)))
				return
			end
			for i = 1, 8 do
				local p = pf:FindFirstChild("Plate" .. tostring(i))
				if p and p:IsA("BasePart") and p.BrickColor.Name == "Sand yellow" then
					setStatus("🔨 Bartilo [3/3]: Activando Placa " .. tostring(i) .. "/8...", KX.phaseText)
					if KX.moveToCFrame(CFrame.new(p.Position + Vector3.new(0, 2, 0))) then
						hrp.CFrame = CFrame.new(p.Position + Vector3.new(0, 2, 0))
						if firetouchinterest then
							pcall(function()
								firetouchinterest(hrp, p, 0)
								firetouchinterest(hrp, p, 1)
							end)
						end
					end
					return
				end
			end
			pcall(function() CommF_:InvokeServer("BartiloQuestProgress", "Bartilo") end)
		end
	end

	local lastTrevorPoll = 0
	local lastTrevorLoadAttempt = 0
	local lastZProgPoll = 0
	local cachedZProg = nil
	local swanWasAlive = false
	local swanEmptySince = 0
	local s2IndraWasAlive = false
	local lastZBeginInvoke = 0
	local lastZTravelInvoke = 0

	local TREVOR_SPARE_FRUITS = {
		"Quake-Quake",
		"Love-Love",
		"Creation-Creation",
		"Spider-Spider",
		"Sound-Sound",
		"Phoenix-Phoenix",
		"Pain-Pain",
		"Blizzard-Blizzard",
		"Shadow-Shadow",
		"Gravity-Gravity",
	}

	function KX.stepSea2ToSea3Quest(hrp)
		KX.phaseText = "Tier 2: Sea 2 -> Sea 3 Unlock"
		if not KX.questsDone.bartilo then
			KX.stepBartiloQuest(hrp)
			return
		end

		-- Phase 1: Trevor >=1M Fruit Access ("FlamingoAccess")
		if not KX.questsDone.donSwan and (os.clock() - lastTrevorPoll >= 3.0) then
			lastTrevorPoll = os.clock()
			pcall(function()
				local u = CommF_:InvokeServer("GetUnlockables")
				if type(u) == "table" and u.FlamingoAccess then
					KX.questsDone.donSwan = true
				end
			end)
		end

		if not KX.questsDone.donSwan then
			local held1M = nil
			for _, fk in ipairs(TREVOR_SPARE_FRUITS) do
				if not (KX.autoEatAllowedFruits and KX.allowedEatFruits[fk]) then
					local base = fk:match("^(.-)%-") or fk
					local t = KX.hasToolAnywhere(base .. " Fruit")
					if t then
						held1M = t
						break
					end
				end
			end

			if not held1M and (os.clock() - lastTrevorLoadAttempt >= 8.0) then
				lastTrevorLoadAttempt = os.clock()
				for _, fk in ipairs(TREVOR_SPARE_FRUITS) do
					if not (KX.autoEatAllowedFruits and KX.allowedEatFruits[fk]) then
						pcall(function() CommF_:InvokeServer("LoadFruit", fk) end)
						local base = fk:match("^(.-)%-") or fk
						held1M = KX.hasToolAnywhere(base .. " Fruit")
						if held1M then break end
					end
				end
			end

			if held1M then
				KX.protectedTool = held1M
				local trevorPos = KX.getNPCWorldPos("Trevor", Vector3.new(-336.5, 331.8, 639.0))
				setStatus("🦩 Entregando fruta >=1M a Trevor para abrir Don Swan...", KX.phaseText)
				if KX.moveToCFrame(CFrame.new(trevorPos)) or (hrp.Position - trevorPos).Magnitude <= 25 then
					KX.equipExactTool(held1M)
					pcall(function()
						CommF_:InvokeServer("TalkTrevor", "1")
						CommF_:InvokeServer("TalkTrevor", "2")
						CommF_:InvokeServer("TalkTrevor", "3")
						local u = CommF_:InvokeServer("GetUnlockables")
						if type(u) == "table" and u.FlamingoAccess then
							KX.questsDone.donSwan = true
						end
					end)
					if KX.questsDone.donSwan then
						KX.protectedTool = nil
						lastZProgPoll = 0
					end
				end
				return
			end

			-- No >=1M fruit available yet -> Decisively farm highest Sea 2 quest + Gacha + map fruits (NEVER walk into locked room!)
			if KX.tryGrabGroundFruit(hrp) then
				return
			end
			KX.phaseText = "Tier 2: Farm Sea 2 (Esperando Fruta >=1M Trevor)"
			KX.stepStandardSeaLevelFarm(hrp, "🦩 Farm Nivel/Beli [Buscando fruta >=1M para Trevor]")
			return
		end

		KX.protectedTool = nil

		-- Phase 2: Poll ZQuestProgress ("Check" -> nil: Don Swan | 0: King Red Head & rip_indra | 1: TravelZou)
		if os.clock() - lastZProgPoll >= 2.0 then
			lastZProgPoll = os.clock()
			pcall(function()
				cachedZProg = CommF_:InvokeServer("ZQuestProgress", "Check")
			end)
		end

		local swanRoomCenter = Vector3.new(2288.8, 15.2, 905.5)
		local playerInSwanRoom = KX.isPosInSwanRoom(hrp.Position)

		-- 2A) cachedZProg == nil -> Enter Don Swan's room & defeat exact boss "Don Swan"!
		if cachedZProg == nil then
			if not playerInSwanRoom then
				setStatus("🦩 Sea 2->3: Entrando a la sala de Don Swan...", KX.phaseText)
				KX.moveToCFrame(CFrame.new(swanRoomCenter))
				return
			end

			local swanBoss, swanInEn = KX.findExactBoss({"Don Swan"}, true)
			if swanBoss and swanInEn then
				swanWasAlive = true
				swanEmptySince = 0
				KX.engageTarget(swanBoss, nil, "🦩 Derrotando a Don Swan [Paso a Sea 3]", "Melee")
				return
			elseif swanWasAlive then
				swanWasAlive = false
				lastZProgPoll = 0
				return
			end

			setStatus("🦩 Sea 2->3: Buscando a Don Swan en la sala...", KX.phaseText)
			local reachedRoom = KX.moveToCFrame(CFrame.new(swanRoomCenter))
			if reachedRoom or (hrp.Position - swanRoomCenter).Magnitude <= 45 then
				if not swanBoss then
					if swanEmptySince == 0 then
						swanEmptySince = os.clock()
					elseif (os.clock() - swanEmptySince >= 6.5) and (os.clock() - KX.spawnedAtClock >= 10.0) then
						swanEmptySince = 0
						local freshZ = nil
						pcall(function() freshZ = CommF_:InvokeServer("ZQuestProgress", "Check") end)
						if freshZ == 0 or freshZ == 1 then
							cachedZProg = freshZ
						else
							KX.serverHop("Don Swan no activo (Paso a Sea 3)")
						end
					end
				else
					swanEmptySince = 0
				end
			end
			return
		end

		-- Exit Don Swan's room cleanly before moving to Colosseum / Mr. Captain
		if playerInSwanRoom then
			setStatus("🦩 Saliendo de la sala de Don Swan...", KX.phaseText)
			KX.moveToCFrame(CFrame.new(-287.5, 305.2, 586.0))
			return
		end

		-- 2B) cachedZProg == 0 -> Speak to King Red Head ("Begin") & Defeat rip_indra in Sealed Colosseum!
		if tonumber(cachedZProg) == 0 then
			local inSealedIndraArena = (hrp.Position.X < -15000)
			if inSealedIndraArena then
				local s2Indra, s2In = KX.findExactBoss({"rip_indra"}, true)
				if s2Indra and s2In then
					s2IndraWasAlive = true
					KX.engageTarget(s2Indra, nil, "👑 Derrotando a rip_indra [Paso a Sea 3]", "Melee")
					return
				elseif s2IndraWasAlive then
					s2IndraWasAlive = false
					lastZProgPoll = 0
					return
				end
				setStatus("👑 Esperando aparición / cinemática de rip_indra...", KX.phaseText)
				return
			end

			local krhPos = KX.getNPCWorldPos("King Red Head", Vector3.new(-1929.0, 12.8, 1738.0))
			setStatus("👑 Sea 2->3: Hablando con King Red Head para combatir a rip_indra...", KX.phaseText)
			local reachedKrh = KX.moveToCFrame(CFrame.new(krhPos + Vector3.new(0, 3, 3)))
			if (reachedKrh or (hrp.Position - krhPos).Magnitude <= 28) and (os.clock() - lastZBeginInvoke >= 3.5) then
				lastZBeginInvoke = os.clock()
				pcall(function()
					CommF_:InvokeServer("ZQuestProgress", "Check")
					CommF_:InvokeServer("ZQuestProgress", "Begin")
				end)
				lastZProgPoll = 0
			end
			return
		end

		-- 2C) cachedZProg == 1 -> rip_indra defeated! Travel directly to Sea 3!
		KX.questsDone.ripIndraSea2 = true
		local capPos = KX.getNPCWorldPos("Mr. Captain", Vector3.new(-1907.0, 5.2, -2533.0))
		setStatus("🚢 ¡Sea 3 desbloqueado! Viajando al Tercer Sea con Mr. Captain...", KX.phaseText)
		if os.clock() - lastZTravelInvoke >= 2.5 then
			lastZTravelInvoke = os.clock()
			pcall(function()
				CommF_:InvokeServer("ZQuestProgress", "Zou")
				CommF_:InvokeServer("TravelZou")
			end)
		end
		KX.moveToCFrame(CFrame.new(capPos + Vector3.new(0, 3, 3)))
	end

	function KX.stepLevelingTier2(hrp)
		-- 1) Sea 1 Saber milestone at Lv >= 200
		if KX.level >= 200 and not KX.ownedSwords["Saber"] and KX.worldNum == 1 then
			KX.stepSea1SaberQuest(hrp)
			return
		end

		-- 2) Sea 1 -> Sea 2 transition at Lv >= 700
		if KX.level >= 700 and KX.worldNum == 1 then
			KX.stepSea1ToSea2Quest(hrp)
			return
		end

		-- 3) Sea 2 Bartilo milestone at Lv >= 850
		if KX.level >= 850 and KX.worldNum == 2 and not KX.questsDone.bartilo then
			KX.stepBartiloQuest(hrp)
			return
		end

		-- 4) Sea 2 -> Sea 3 transition at Lv >= 1500
		if KX.level >= 1500 and KX.worldNum == 2 then
			KX.stepSea2ToSea3Quest(hrp)
			return
		end

		-- 5) Ensure player is in highest unlocked Sea for optimal EXP
		if KX.level >= 1500 and KX.worldNum < 3 then
			KX.travelToSea(3)
			return
		elseif KX.level >= 700 and KX.worldNum < 2 then
			KX.travelToSea(2)
			return
		end

		-- 6) Exclusive Map Fruit Pickup (returns true when moving so zero concurrent tasks run!)
		if KX.tryGrabGroundFruit(hrp) then
			return
		end

		-- 7) Standard Sea Quest Leveling + Passive Melee Rotation
		KX.phaseText = string.format("Tier 2: Farm Level (%d / %d)", KX.level, KX.maxLevel)
		KX.stepStandardSeaLevelFarm(hrp)
	end

	-- =========================================================================
	-- TIER 3: FULL GODHUMAN UNLOCK PIPELINE
	-- =========================================================================
	local GODHUMAN_MATS = {
		{mat = "Fish Tail", need = 20, sea = 3, mob = "Fishman Raider", spawns = {CFrame.new(-10565, 332, -8460), CFrame.new(-10820, 332, -8850)}},
		{mat = "Magma Ore", need = 20, sea = 2, mob = "Lava Pirate", spawns = {CFrame.new(-5235, 15, -4750), CFrame.new(-5420, 15, -5100)}},
		{mat = "Mystic Droplet", need = 10, sea = 2, mob = "Water Fighter", spawns = {CFrame.new(-3350, 240, -10540), CFrame.new(-3510, 240, -10390)}},
		{mat = "Dragon Scale", need = 10, sea = 3, mob = "Dragon Crew Archer", spawns = {CFrame.new(6620, 378, 240), CFrame.new(6750, 378, 410)}},
	}

	function KX.stepGodhumanTier3(hrp)
		KX.phaseText = "Tier 3: Unlocking Godhuman"

		-- 1) Ensure special keys/essences for Death Step / Sharkman Karate / Dragon Talon / Electric Claw
		for _, st in ipairs(STYLE_PIPELINE) do
			if KX.getStyleMastery(st) < 400 then
				-- Unlock special quests if style cannot be bought yet
				if st.name == "Death Step" and not KX.ownedMelees["Death Step"] then
					local libKey = KX.hasToolAnywhere("Library Key")
					if libKey then
						if KX.worldNum ~= 2 then KX.travelToSea(2); return end
						local door = Vector3.new(6375.5, 296.6, -6841.5)
						if KX.moveToCFrame(CFrame.new(door)) then
							KX.equipExactTool(libKey)
						end
					end
					local okBuy = nil
					pcall(function() okBuy = CommF_:InvokeServer("BuyDeathStep") end)
					if okBuy ~= 1 and not KX.ownedMelees["Death Step"] then
						if KX.worldNum ~= 2 then KX.travelToSea(2); return end
						local adm, inEn = KX.findBossOrEnemy({"Awakened Ice Admiral"}, true)
						if adm and inEn then
							KX.engageTarget(adm, nil, "🔑 Buscando Library Key (Death Step)", "Melee")
						else
							if KX.moveToCFrame(CFrame.new(6473.0, 297.0, -6944.0)) then
								KX.serverHop("Awakened Ice Admiral for Library Key")
							end
						end
						return
					end
				elseif st.name == "Sharkman Karate" and not KX.ownedMelees["Sharkman Karate"] then
					local wKey = KX.hasToolAnywhere("Water Key")
					if wKey then
						if KX.worldNum ~= 2 then KX.travelToSea(2); return end
						local daigPos = Vector3.new(-2604.5, 239.5, -10315.0)
						if KX.moveToCFrame(CFrame.new(daigPos)) then
							KX.equipExactTool(wKey)
							pcall(function()
								CommF_:InvokeServer("BuySharkmanKarate", true)
								CommF_:InvokeServer("BuySharkmanKarate")
							end)
						end
						return
					end
					local okBuy = nil
					pcall(function() okBuy = CommF_:InvokeServer("BuySharkmanKarate") end)
					if okBuy ~= 1 and not KX.ownedMelees["Sharkman Karate"] then
						if KX.worldNum ~= 2 then KX.travelToSea(2); return end
						local tk, inEn = KX.findBossOrEnemy({"Tide Keeper"}, true)
						if tk and inEn then
							KX.engageTarget(tk, nil, "🔑 Buscando Water Key (Sharkman Karate)", "Melee")
						else
							if KX.moveToCFrame(CFrame.new(-3570.0, 123.0, -11555.0)) then
								KX.serverHop("Tide Keeper for Water Key")
							end
						end
						return
					end
				elseif st.name == "Electric Claw" and not KX.ownedMelees["Electric Claw"] then
					if KX.worldNum ~= 3 then KX.travelToSea(3); return end
					local heroPos = Vector3.new(-10371.5, 330.8, -10131.4)
					local mansionPos = Vector3.new(-12550.0, 337.0, -7480.0)
					local stg = nil
					pcall(function() stg = CommF_:InvokeServer("BuyElectricClaw", true) end)
					if stg == 4 then
						if KX.moveToCFrame(CFrame.new(heroPos)) then
							pcall(function() CommF_:InvokeServer("BuyElectricClaw", "Start") end)
							task.wait(0.3)
							KX.moveToCFrame(CFrame.new(mansionPos), 205)
						end
						return
					end
					pcall(function() CommF_:InvokeServer("BuyElectricClaw") end)
				elseif st.name == "Dragon Talon" and not KX.ownedMelees["Dragon Talon"] then
					if KX.worldNum ~= 3 then KX.travelToSea(3); return end
					local fireEss = KX.hasToolAnywhere("Fire Essence")
					if fireEss then
						local uzothPos = Vector3.new(5661.9, 1210.9, 863.2)
						if KX.moveToCFrame(CFrame.new(uzothPos)) then
							KX.equipExactTool(fireEss)
							pcall(function()
								CommF_:InvokeServer("BuyDragonTalon", true)
								CommF_:InvokeServer("BuyDragonTalon")
							end)
						end
						return
					end
					local okBuy = nil
					pcall(function() okBuy = CommF_:InvokeServer("BuyDragonTalon") end)
					if okBuy ~= 1 and not KX.ownedMelees["Dragon Talon"] then
						if (KX.materials["Bones"] or 0) >= 50 and (os.clock() - lastBonesRollClock >= 6.0) then
							lastBonesRollClock = os.clock()
							pcall(function() CommF_:InvokeServer("Bones", "Buy", 1, 1) end)
						end
						local mob = KX.findNearestAliveFromSet(HAUNTED_MOBS)
						if mob then
							KX.engageTarget(mob, HAUNTED_MOBS, "🔥 Farm Bones para Fire Essence (Dragon Talon)", "Melee")
						else
							KX.moveToCFrame(CFrame.new(-9515.0, 142.1, 5535.0))
						end
						return
					end
				else
					pcall(function()
						if st.isDragonClaw then
							CommF_:InvokeServer("BlackbeardReward", "DragonClaw", "1")
							CommF_:InvokeServer("BlackbeardReward", "DragonClaw", "2")
						else
							CommF_:InvokeServer(st.buyArg)
						end
					end)
				end

				-- Grind Mastery to 400 in Sea 3 Cake Land / Haunted Castle!
				if KX.worldNum ~= 3 then KX.travelToSea(3); return end
				local curMast = KX.getStyleMastery(st)
				local mob = KX.findNearestAliveFromSet(CAKE_LAND_MOBS) or KX.findNearestAliveFromSet(HAUNTED_MOBS)
				if mob then
					KX.engageTarget(mob, CAKE_LAND_MOBS, string.format("🥊 Mastery %s (%d/400)", st.alt, curMast), "Melee")
				else
					setStatus(string.format("🥊 Subiendo Mastery de %s (%d/400)...", st.alt, curMast), KX.phaseText)
					KX.moveToCFrame(CFrame.new(-2095.0, 70.0, -12140.0))
				end
				return
			end
		end

		-- 2) Farm Godhuman Materials (Fish Tail x20, Magma Ore x20, Mystic Droplet x10, Dragon Scale x10)
		for _, mInfo in ipairs(GODHUMAN_MATS) do
			local have = KX.materials[mInfo.mat] or 0
			if have < mInfo.need then
				if KX.worldNum ~= mInfo.sea then
					KX.travelToSea(mInfo.sea)
					return
				end
				KX.farmMobSpawns(
					mInfo.mob,
					mInfo.spawns,
					string.format("🧪 Material Godhuman: %s (%d/%d)", mInfo.mat, have, mInfo.need),
					"Melee"
				)
				return
			end
		end

		-- 3) Purchase Godhuman at Ancient Monk!
		if KX.worldNum ~= 3 then
			KX.travelToSea(3)
			return
		end
		local monkPos = Vector3.new(-13774.2, 334.5, -9875.5)
		setStatus("⚡ Comprando Godhuman con Ancient Monk...", KX.phaseText)
		if KX.moveToCFrame(CFrame.new(monkPos + Vector3.new(0, 3, 2))) then
			pcall(function()
				CommF_:InvokeServer("BuyGodhuman", true)
				local r = CommF_:InvokeServer("BuyGodhuman")
				if r == 1 then
					KX.ownedMelees["Godhuman"] = true
				end
			end)
		end
	end
end

--------------------------------------------------------------------------------
-- 8. MASTER KAITUN PRIORITY ENGINE — TIERS 4, 5, 6 & 7 + DISPATCHER
--    Tier 4: Cursed Dual Katana (Yama + Tushita + 350 Mastery + Crypt Trials)
--    Tier 5: Soul Guitar (500 Bones + 250 Ectoplasm + Dark Fragment + Puzzle)
--    Tier 6: Priority Swords & Guns Unlock
--    Tier 7: Final Endgame — Mirage Island + Mirror Fractal + Blue Gear (LAST!)
--------------------------------------------------------------------------------
do
	local ELITE_NAMES = {"Deandre", "Diablo", "Urban"}
	local TUSHITA_TORCHES = {
		Vector3.new(-10752.0, 417.0, -9366.0),
		Vector3.new(-11672.0, 334.0, -9474.0),
		Vector3.new(-12132.0, 521.0, -10655.0),
		Vector3.new(-13336.0, 486.0, -6985.0),
		Vector3.new(-13489.0, 332.0, -7925.0),
	}
	local CURSED_SHIP_MOBS = {
		["Ship Deckhand"] = true,
		["Ship Engineer"] = true,
		["Ship Steward"] = true,
		["Ship Officer"] = true,
	}
	local HAUNTED_ZOMBIE_SET = {["Living Zombie"] = true}
	local HAUNTED_ALL_SET = {
		["Reborn Skeleton"] = true,
		["Living Zombie"] = true,
		["Demonic Soul"] = true,
		["Posessed Mummy"] = true,
	}
	local CAKE_MOBS_SET = {
		["Cookie Crafter"] = true,
		["Cake Guard"] = true,
		["Baking Staff"] = true,
		["Head Baker"] = true,
	}

	-- =========================================================================
	-- TIER 4: CURSED DUAL KATANA (CDK) PIPELINE
	-- =========================================================================
	function KX.needsCDK()
		return KX.level >= 2200 and not KX.ownedSwords["Cursed Dual Katana"]
	end

	function KX.stepCDKTier4(hrp)
		KX.phaseText = "Tier 4: Cursed Dual Katana (CDK)"
		if KX.worldNum ~= 3 then
			KX.travelToSea(3)
			return
		end

		-- 4A) Unlock Yama (30 Elite Pirates -> Hydra Waterfall Sealed Katana)
		if not KX.ownedSwords["Yama"] then
			if (KX.eliteProgress or 0) < 30 then
				local eliteBoss, inEn = KX.findBossOrEnemy(ELITE_NAMES, true)
				if eliteBoss and inEn then
					KX.engageTarget(eliteBoss, nil, string.format("🗡️ Yama: Derrotando Elite (%d/30)", KX.eliteProgress), "Melee")
					return
				end
				local ehPos = Vector3.new(-5418.9, 313.7, -2826.2)
				setStatus(string.format("🗡️ Yama: Consultando Elite Hunter (%d/30)...", KX.eliteProgress), KX.phaseText)
				if KX.moveToCFrame(CFrame.new(ehPos)) then
					local resp = ""
					pcall(function() resp = tostring(CommF_:InvokeServer("EliteHunter") or ""):lower() end)
					if resp:find("don't have") or resp:find("come back") then
						KX.serverHop("Buscando Elite Pirate para Yama")
					end
				end
				return
			end

			-- Pull Sealed Katana at Hydra Waterfall!
			local yamaRoom = Vector3.new(5251.0, 10.5, 428.0)
			setStatus("🗡️ Extrayendo Yama bajo la cascada de Hydra Island...", KX.phaseText)
			if KX.moveToCFrame(CFrame.new(yamaRoom)) then
				local wf = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Waterfall")
				local sealed = wf and wf:FindFirstChild("SealedKatana")
				local cd = sealed and sealed:FindFirstChildWhichIsA("ClickDetector", true)
				if cd and fireclickdetector then
					for _ = 1, 5 do
						pcall(function() fireclickdetector(cd) end)
						task.wait(0.2)
					end
				end
			end
			return
		end

		-- 4B) Level Yama to Mastery >= 350
		if (KX.swordMastery["Yama"] or 0) < 350 then
			pcall(function() CommF_:InvokeServer("LoadItem", "Yama") end)
			local mob = KX.findNearestAliveFromSet(CAKE_MOBS_SET) or KX.findNearestAliveFromSet(HAUNTED_ALL_SET)
			if mob then
				KX.engageTarget(mob, CAKE_MOBS_SET, string.format("🗡️ Mastery Yama (%d/350)", KX.swordMastery["Yama"] or 0), "Sword", "Yama")
			else
				KX.moveToCFrame(CFrame.new(-2095.0, 70.0, -12140.0))
			end
			return
		end

		-- 4C) Unlock Tushita (Longma / Holy Torch 1-5)
		if not KX.ownedSwords["Tushita"] then
			local longma, lmInEn = KX.findBossOrEnemy({"Longma"}, true)
			if longma and lmInEn then
				KX.engageTarget(longma, nil, "🗡️ Derrotando a Longma (Tushita)", "Melee")
				return
			end

			local holyTorch = KX.hasToolAnywhere("Holy Torch")
			if holyTorch then
				KX.equipExactTool(holyTorch)
				local turtle = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Turtle")
				local torchesFolder = turtle and turtle:FindFirstChild("QuestTorches")
				for idx, tPos in ipairs(TUSHITA_TORCHES) do
					local tObj = torchesFolder and torchesFolder:FindFirstChild("Torch" .. tostring(idx))
					local lit = tObj and tObj:FindFirstChild("Particles") and tObj.Particles:FindFirstChild("PointLight") and tObj.Particles.PointLight.Enabled
					if not lit then
						setStatus(string.format("🔥 Tushita: Encendiendo Antorcha Sagrada %d/5...", idx), KX.phaseText)
						if KX.moveToCFrame(CFrame.new(tPos + Vector3.new(0, 2, 0))) then
							hrp.CFrame = CFrame.new(tPos)
							if tObj and tObj:IsA("BasePart") and firetouchinterest then
								pcall(function()
									firetouchinterest(hrp, tObj, 0)
									firetouchinterest(hrp, tObj, 1)
								end)
							end
						end
						return
					end
				end
			end

			-- Check Longma room; if door already open, wait/hop Longma; else wait for Rip Indra portal
			local lmRoom = Vector3.new(-10238.0, 389.8, -9549.8)
			setStatus("🗡️ Buscando a Longma / Portal de Tushita...", KX.phaseText)
			if KX.moveToCFrame(CFrame.new(lmRoom)) then
				KX.serverHop("Longma / Rip Indra para Tushita")
			end
			return
		end

		-- 4D) Level Tushita to Mastery >= 350
		if (KX.swordMastery["Tushita"] or 0) < 350 then
			pcall(function() CommF_:InvokeServer("LoadItem", "Tushita") end)
			local mob = KX.findNearestAliveFromSet(CAKE_MOBS_SET) or KX.findNearestAliveFromSet(HAUNTED_ALL_SET)
			if mob then
				KX.engageTarget(mob, CAKE_MOBS_SET, string.format("🗡️ Mastery Tushita (%d/350)", KX.swordMastery["Tushita"] or 0), "Sword", "Tushita")
			else
				KX.moveToCFrame(CFrame.new(-2095.0, 70.0, -12140.0))
			end
			return
		end

		-- 4E) Complete CDK Crypt Trials & Defeat Cursed Skeleton Boss
		local skelBoss, skInEn = KX.findBossOrEnemy({"Cursed Skeleton Boss"}, true)
		if skelBoss and skInEn then
			KX.engageTarget(skelBoss, nil, "⚔️ Derrotando a Cursed Skeleton Boss (CDK!)", "Sword", "Tushita")
			return
		end

		local cryptPos = Vector3.new(-12361.7, 603.4, -6550.5)
		setStatus(string.format("⚔️ Ejecutando ritual Cursed Dual Katana (Alucard %d/6)...", KX.materials["Alucard Fragment"] or 0), KX.phaseText)
		if KX.moveToCFrame(CFrame.new(cryptPos)) then
			pcall(function()
				CommF_:InvokeServer("CDKQuest", "OpenDoor")
				CommF_:InvokeServer("CDKQuest", "OpenDoor", true)
				if (KX.materials["Alucard Fragment"] or 0) < 6 then
					CommF_:InvokeServer("CDKQuest", "Progress", "Good")
					CommF_:InvokeServer("CDKQuest", "StartTrial", "Good")
					CommF_:InvokeServer("CDKQuest", "Progress", "Evil")
					CommF_:InvokeServer("CDKQuest", "StartTrial", "Evil")
				else
					-- Place gems & summon Cursed Skeleton Boss
					local altar = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Turtle") and Workspace.Map.Turtle:FindFirstChild("Cursed")
					local ped = altar and altar:FindFirstChild("Pedestal3")
					if ped and ped:FindFirstChild("ProximityPrompt") and fireproximityprompt then
						fireproximityprompt(ped.ProximityPrompt)
					end
				end
			end)

			-- Progress active Haze / Trial mobs if spawned
			local hazeMob = KX.findNearestAliveFromSet(HAUNTED_ALL_SET) or KX.findNearestAliveFromSet(CAKE_MOBS_SET)
			if hazeMob then
				KX.engageTarget(hazeMob, nil, "⚔️ Completando Trial de CDK", "Sword", "Yama")
			end
		end
	end

	-- =========================================================================
	-- TIER 5: SOUL GUITAR COMPLETE PIPELINE
	-- =========================================================================
	local function isFullMoonActive()
		local sky = Lighting:FindFirstChildOfClass("Sky")
		if sky and tostring(sky.MoonTextureId):find("9709149431") then
			return true
		end
		return false
	end

	function KX.needsSoulGuitar()
		return KX.level >= 2300 and not KX.ownedGuns["Soul Guitar"]
	end

	function KX.stepSoulGuitarTier5(hrp)
		KX.phaseText = "Tier 5: Soul Guitar"

		-- 5A) Ensure 500 Bones (Sea 3 Haunted Castle)
		if (KX.materials["Bones"] or 0) < 500 then
			if KX.worldNum ~= 3 then KX.travelToSea(3); return end
			local mob = KX.findNearestAliveFromSet(HAUNTED_ALL_SET)
			if mob then
				KX.engageTarget(mob, HAUNTED_ALL_SET, string.format("🦴 Farm Bones para Soul Guitar (%d/500)", KX.materials["Bones"] or 0), "Melee")
			else
				KX.moveToCFrame(CFrame.new(-9515.0, 142.1, 5535.0))
			end
			return
		end

		-- 5B) Ensure 250 Ectoplasm (Sea 2 Cursed Ship)
		if (KX.materials["Ectoplasm"] or 0) < 250 then
			if KX.worldNum ~= 2 then KX.travelToSea(2); return end
			local mob = KX.findNearestAliveFromSet(CURSED_SHIP_MOBS)
			if mob then
				KX.engageTarget(mob, CURSED_SHIP_MOBS, string.format("👻 Farm Ectoplasm para Soul Guitar (%d/250)", KX.materials["Ectoplasm"] or 0), "Melee")
			else
				KX.moveToCFrame(CFrame.new(915.0, 126.0, 33150.0))
			end
			return
		end

		-- 5C) Ensure 1 Dark Fragment (Sea 2 Darkbeard)
		if (KX.materials["Dark Fragment"] or 0) < 1 then
			if KX.worldNum ~= 2 then KX.travelToSea(2); return end
			local db, dbIn = KX.findBossOrEnemy({"Darkbeard"}, true)
			if db and dbIn then
				KX.engageTarget(db, nil, "🌑 Derrotando Darkbeard por Dark Fragment", "Melee")
				return
			end
			setStatus("🌑 Buscando Fist of Darkness / Darkbeard para Soul Guitar...", KX.phaseText)
			KX.serverHop("Darkbeard / Fist of Darkness para Soul Guitar")
			return
		end

		-- 5D) Haunted Castle Soul Guitar Puzzle & Craft (Sea 3)
		if KX.worldNum ~= 3 then
			KX.travelToSea(3)
			return
		end

		local gpState = nil
		pcall(function() gpState = CommF_:InvokeServer("GuitarPuzzleProgress", "Check") end)

		if not gpState then
			-- Need Full Moon to Pray at Gravestone!
			if not isFullMoonActive() or (Lighting.ClockTime > 5.5 and Lighting.ClockTime < 18.0) then
				setStatus("🌕 Buscando Luna Llena para rezar en Haunted Castle (Soul Guitar)...", KX.phaseText)
				KX.serverHop("Full Moon para Soul Guitar")
				return
			end
			local gravePos = Vector3.new(-8654.3, 140.9, 6167.5)
			setStatus("🌕 Rezando en la lápida de Haunted Castle (Luna Llena)...", KX.phaseText)
			if KX.moveToCFrame(CFrame.new(gravePos)) then
				pcall(function()
					CommF_:InvokeServer("gravestoneEvent", 2)
					CommF_:InvokeServer("gravestoneEvent", 2, true)
				end)
			end
			return
		end

		if type(gpState) == "table" then
			-- Stage 1: Kill 6 Living Zombies simultaneously
			if not gpState.Swamp then
				local zCenter = Vector3.new(-10171.0, 138.6, 5935.0)
				if KX.moveToCFrame(CFrame.new(zCenter + Vector3.new(0, 18, 0))) then
					KX.bringClusterMobs(zCenter, HAUNTED_ZOMBIE_SET)
					local zMob = KX.findNearestAliveFromSet(HAUNTED_ZOMBIE_SET)
					if zMob then
						KX.engageTarget(zMob, HAUNTED_ZOMBIE_SET, "🎸 Soul Guitar [1/5]: 6 Living Zombies simultáneos", "Melee")
					end
				end
				return
			end

			-- Stage 2: Graveyard Sign Plaques
			if not gpState.Gravestones then
				setStatus("🎸 Soul Guitar [2/5]: Resolviendo placas del cementerio...", KX.phaseText)
				local gravePos = Vector3.new(-8654.3, 140.9, 6167.5)
				KX.moveToCFrame(CFrame.new(gravePos))
				pcall(function() CommF_:InvokeServer("GuitarPuzzleProgress", "Gravestones") end)
				return
			end

			-- Stage 3: Speak to Ghost in Mansion
			if not gpState.Ghost then
				local ghostPos = Vector3.new(-9755.4, 271.1, 6290.6)
				setStatus("🎸 Soul Guitar [3/5]: Hablando con el Fantasma...", KX.phaseText)
				if KX.moveToCFrame(CFrame.new(ghostPos)) then
					pcall(function() CommF_:InvokeServer("GuitarPuzzleProgress", "Ghost") end)
				end
				return
			end

			-- Stage 4: Trophies Alignment
			if not gpState.Trophies then
				local trPos = Vector3.new(-9530.0, 6.2, 6054.0)
				setStatus("🎸 Soul Guitar [4/5]: Alineando trofeos...", KX.phaseText)
				if KX.moveToCFrame(CFrame.new(trPos)) then
					pcall(function() CommF_:InvokeServer("GuitarPuzzleProgress", "Trophies") end)
				end
				return
			end

			-- Stage 5: Basement Colored Pipes
			if not gpState.Pipes then
				local pipePos = Vector3.new(-9530.0, 6.2, 6135.0)
				setStatus("🎸 Soul Guitar [5/5]: Conectando tuberías de colores...", KX.phaseText)
				if KX.moveToCFrame(CFrame.new(pipePos)) then
					pcall(function() CommF_:InvokeServer("GuitarPuzzleProgress", "Pipes") end)
				end
				return
			end
		end

		-- Final Stage: Craft Soul Guitar!
		setStatus("🎸 Fabricando Soul Guitar...", KX.phaseText)
		pcall(function()
			CommF_:InvokeServer("soulGuitarBuy", true)
			CommF_:InvokeServer("soulGuitarBuy")
		end)
	end

	-- =========================================================================
	-- TIER 6: PRIORITY SWORDS & GUNS UNLOCK (IMPORTANCE ORDER)
	-- =========================================================================
	local BOSS_WEAPON_TARGETS = {
		{kind = "Sword", ui = "Rengoku", sea = 2, boss = "Awakened Ice Admiral", pos = Vector3.new(6473.0, 297.0, -6944.0)},
		{kind = "Sword", ui = "Buddy Sword", sea = 3, boss = "Cake Queen", pos = Vector3.new(-710.0, 381.6, -11150.0)},
		{kind = "Sword", ui = "Canvander", sea = 3, boss = "Beautiful Pirate", pos = Vector3.new(5312.0, 22.6, -125.0)},
		{kind = "Gun", ui = "Venom Bow", sea = 3, boss = "Hydra Leader", pos = Vector3.new(5742.0, 468.0, 200.0)},
		{kind = "Gun", ui = "Serpent Bow", sea = 3, boss = "Hydra Leader", pos = Vector3.new(5742.0, 468.0, 200.0)},
	}

	function KX.tryStepWeaponsTier6(hrp)
		-- 6A) Direct Beli / Fragment / Ectoplasm Purchases when affordable
		if not KX.ownedSwords["Bisento"] and KX.beli >= 1200000 then
			KX.phaseText = "Tier 6: Unlocking Bisento"
			if KX.worldNum ~= 1 then KX.travelToSea(1); return true end
			pcall(function() CommF_:InvokeServer("BuyItem", "Bisento") end)
		end

		if not KX.ownedSwords["Soul Cane"] and KX.beli >= 750000 then
			KX.phaseText = "Tier 6: Unlocking Soul Cane"
			if KX.worldNum ~= 1 then KX.travelToSea(1); return true end
			pcall(function() CommF_:InvokeServer("BuyItem", "Soul Cane") end)
		end

		if not KX.ownedGuns["Kabucha"] and KX.fragments >= 1500 then
			KX.phaseText = "Tier 6: Unlocking Kabucha"
			pcall(function() CommF_:InvokeServer("BlackbeardReward", "Slingshot", "2") end)
		end

		if not KX.ownedSwords["Midnight Blade"] and (KX.materials["Ectoplasm"] or 0) >= 100 then
			KX.phaseText = "Tier 6: Unlocking Midnight Blade"
			if KX.worldNum ~= 2 then KX.travelToSea(2); return true end
			pcall(function() CommF_:InvokeServer("Ectoplasm", "Buy", 3) end)
		end

		if not KX.ownedGuns["Bizarre Rifle"] and (KX.materials["Ectoplasm"] or 0) >= 25 then
			KX.phaseText = "Tier 6: Unlocking Bizarre Rifle"
			if KX.worldNum ~= 2 then KX.travelToSea(2); return true end
			pcall(function() CommF_:InvokeServer("Ectoplasm", "Buy", 1) end)
		end

		-- Hidden Key -> Rengoku secret chest immediately if holding Hidden Key!
		local hiddenKey = KX.hasToolAnywhere("Hidden Key")
		if hiddenKey and not KX.ownedSwords["Rengoku"] then
			KX.phaseText = "Tier 6: Opening Rengoku Chest"
			if KX.worldNum ~= 2 then KX.travelToSea(2); return true end
			local chestPos = Vector3.new(6571.1, 299.2, -6967.8)
			if KX.moveToCFrame(CFrame.new(chestPos)) then
				KX.equipExactTool(hiddenKey)
			end
			return true
		end

		-- Legendary Sword Dealer opportunistic check in Sea 2 + True Triple Katana craft
		if KX.worldNum == 2 and KX.beli >= 2000000 then
			if not (KX.ownedSwords["Shizu"] and KX.ownedSwords["Saishi"] and KX.ownedSwords["Oroshi"]) then
				pcall(function() CommF_:InvokeServer("LegendarySwordDealer", "2") end)
			elseif not KX.ownedSwords["True Triple Katana"] and KX.beli >= 2000000 then
				local s1 = (KX.swordMastery["Shizu"] or 0) >= 300
				local s2 = (KX.swordMastery["Saishi"] or 0) >= 300
				local s3 = (KX.swordMastery["Oroshi"] or 0) >= 300
				if s1 and s2 and s3 then
					pcall(function() CommF_:InvokeServer("MysteriousMan", "2") end)
				end
			end
		end

		-- 6B) Boss-Dropped Swords & Guns in Current Sea (before jumping to Mirage)
		for _, bw in ipairs(BOSS_WEAPON_TARGETS) do
			local owns = (bw.kind == "Sword") and KX.ownedSwords[bw.ui] or KX.ownedGuns[bw.ui]
			if not owns then
				KX.phaseText = "Tier 6: Weapon Hunt (" .. bw.ui .. ")"
				if KX.worldNum ~= bw.sea then
					KX.travelToSea(bw.sea)
					return true
				end
				local bossModel, inEn = KX.findBossOrEnemy({bw.boss}, true)
				if bossModel and inEn then
					KX.engageTarget(bossModel, nil, "🗡️ Desbloqueando " .. bw.ui .. " (" .. bw.boss .. ")", "Melee")
					return true
				elseif KX.moveToCFrame(CFrame.new(bw.pos)) then
					KX.serverHop("Buscando " .. bw.boss .. " para " .. bw.ui)
					return true
				end
				return true
			end
		end

		return false
	end

	-- =========================================================================
	-- TIER 7: FINAL ENDGAME — MIRAGE ISLAND, MIRROR FRACTAL RESONANCE & BLUE GEAR
	--         ("ÚLTIMO DE LO ÚLTIMO DESPUÉS DE COMPLETAR TODO LO ANTERIOR")
	-- =========================================================================
	local MIRAGE_SAIL_TARGET = Vector3.new(-21500.0, 26.0, 5200.0)

	local function findMirageIsland()
		local map = Workspace:FindFirstChild("Map")
		if map and map:FindFirstChild("MysticIsland") then
			return map.MysticIsland
		end
		local locs = Workspace:FindFirstChild("_WorldOrigin") and Workspace._WorldOrigin:FindFirstChild("Locations")
		if locs and locs:FindFirstChild("Mirage Island") then
			return locs["Mirage Island"]
		end
		return nil
	end

	function KX.stepMirageEndgameTier7(hrp)
		KX.phaseText = "Tier 7 (Endgame): Mirage Island & Blue Gear"
		if KX.worldNum ~= 3 then
			KX.travelToSea(3)
			return
		end

		-- Ensure Mirror Fractal is owned first! If not, farm Dough King / Conjured Cocoa in Cake Land!
		if not KX.ownedAccessories["Mirror Fractal"] then
			KX.phaseText = "Tier 7 Prep: Mirror Fractal (Katakuri V2)"
			local mob = KX.findNearestAliveFromSet(CAKE_MOBS_SET)
			if mob then
				KX.engageTarget(mob, CAKE_MOBS_SET, string.format("🍩 Farm Conjured Cocoa / Katakuri V2 (%d/10)", KX.materials["Conjured Cocoa"] or 0), "Melee")
			else
				KX.moveToCFrame(CFrame.new(-2095.0, 70.0, -12140.0))
			end
			return
		end

		local mirage = findMirageIsland()
		if mirage then
			KX.ridingMirageBoat = false
			-- 1) Look for spawned Blue Gear on MysticIsland
			local map = Workspace:FindFirstChild("Map")
			local mystic = map and map:FindFirstChild("MysticIsland")
			if mystic then
				for _, d in ipairs(mystic:GetDescendants()) do
					if d:IsA("BasePart") and (d.Name == "Part" or d.Name:lower():find("gear")) and d.Transparency < 0.9 and d.MeshId ~= "" then
						if tostring(d.Color):find("0.") and d.Size.Magnitude < 12 then
							-- Collect Blue Gear!
							setStatus("⚙️ ¡Blue Gear detectado en Mirage Island! Recolectando...", KX.phaseText)
							if KX.moveToCFrame(d.CFrame * CFrame.new(0, 2, 0)) then
								hrp.CFrame = d.CFrame
								if firetouchinterest then
									pcall(function()
										firetouchinterest(hrp, d, 0)
										firetouchinterest(hrp, d, 1)
									end)
								end
								KX.questsDone.blueGear = true
							end
							return
						end
					end
				end

				-- 2) Stand on highest peak of Mirage Island, look at Moon & activate Race V3!
				local highestPart, maxY = nil, -math.huge
				for _, d in ipairs(mystic:GetDescendants()) do
					if d:IsA("BasePart") and d.Position.Y > maxY then
						maxY = d.Position.Y
						highestPart = d
					end
				end
				if highestPart then
					local peakPos = highestPart.Position + Vector3.new(0, 6, 0)
					setStatus("🌙 Mirage Island: Resonando Mirror Fractal mirando a la Luna...", KX.phaseText)
					if KX.moveToCFrame(CFrame.new(peakPos)) then
						pcall(function()
							local cam = Workspace.CurrentCamera
							local moonDir = Lighting:GetMoonDirection()
							if cam and moonDir then
								cam.CFrame = CFrame.lookAt(cam.CFrame.Position, cam.CFrame.Position + moonDir * 500)
							end
							if CommE then
								CommE:FireServer("ActivateAbility")
							end
						end)
					end
					return
				end
			end
		end

		-- Sail boat into Sea Danger Zone 5-6 to spawn Mirage Island!
		local boats = Workspace:FindFirstChild("Boats")
		local myBoat = nil
		if boats then
			for _, b in ipairs(boats:GetChildren()) do
				local owner = b:FindFirstChild("Owner")
				if owner and tostring(owner.Value) == LocalPlayer.Name and b:FindFirstChild("VehicleSeat") then
					myBoat = b
					break
				end
			end
		end

		if not myBoat then
			KX.ridingMirageBoat = false
			local dealerPos = Vector3.new(-16927.5, 9.1, 433.8) -- Tiki Outpost Boat Dealer
			setStatus("🚤 Comprando bote en Tiki Outpost para buscar Mirage Island...", KX.phaseText)
			if KX.moveToCFrame(CFrame.new(dealerPos)) then
				pcall(function() CommF_:InvokeServer("BuyBoat", "Guardian") end)
			end
			return
		end

		local seat = myBoat:FindFirstChild("VehicleSeat")
		if seat then
			local _, hum = KX.getRootAndHum()
			if hum and hum.SeatPart ~= seat then
				KX.ridingMirageBoat = true
				if KX.moveToCFrame(seat.CFrame * CFrame.new(0, 2, 0)) then
					hrp.CFrame = seat.CFrame
					seat:Sit(hum)
				end
				return
			end
			KX.ridingMirageBoat = true
			setStatus("🌊 Navegando en Zona Peligrosa buscando Mirage Island...", KX.phaseText)
			pcall(function()
				myBoat:PivotTo(CFrame.lookAt(
					seat.Position:Lerp(MIRAGE_SAIL_TARGET, 0.025),
					MIRAGE_SAIL_TARGET
				))
			end)
		end
	end

	-- =========================================================================
	-- MASTER KAITUN SINGLE-BUTTON STEP DISPATCHER
	-- =========================================================================
	function KX.stepMasterKaitun()
		if not KX.autoFarm then
			KX.ridingMirageBoat = false
			return
		end

		-- Step 0: Auto Team Selection if on Pirates/Marines screen
		if isChooseTeamScreenOpen() then
			if CommF_ then
				local team = (KX.preferredTeam == "Marines") and "Marines" or "Pirates"
				setStatus("🏴‍☠️ Seleccionando bando automáticamente: " .. team .. "...", "Team Select")
				pcall(function() CommF_:InvokeServer("SetTeam", team) end)
			end
			return
		end

		local hrp, hum = KX.getRootAndHum()
		if not hrp or not hum then
			setStatus("⏳ Esperando aparición del personaje...", "Spawning")
			return
		end

		-- Background Kaitun Support Systems
		KX.stepSmart2xExpCodes()
		KX.stepFruitSpinStoreAndEat()
		KX.stepSmartStats()

		-- TIER 1: Priority Raid / World Bosses (Interrupts leveling whenever active or summonable!)
		if KX.tryStepPriorityBosses(hrp) then
			return
		end

		-- WORLD ADVANCEMENT PRIORITY: Advance Sea 1 -> Sea 2 (Lv 700+) and Sea 2 -> Sea 3 (Lv 1500+ once unlocked)
		if KX.worldNum == 1 and KX.level >= 700 then
			KX.stepSea1ToSea2Quest(hrp)
			return
		elseif KX.worldNum == 2 and KX.level >= 1500 and KX.questsDone.ripIndraSea2 then
			KX.travelToSea(3)
			return
		end

		-- TIER 1.5: Priority Auto Dungeon Raid over Level Farm (Fruits <= 1M Beli • Kill Aura Islas 1-3 + Melee)
		if KX.tryStepAutoRaid(hrp, hum) then
			return
		end

		-- TIER 2: Leveling 1 -> MaxLevel (2800) + Sea 1/2/3 Storyline + Melee Mastery Rotation
		if KX.level < KX.maxLevel or KX.worldNum < 3 then
			if KX.level >= 1500 and KX.worldNum < 3 then
				if KX.worldNum == 2 then
					KX.stepSea2ToSea3Quest(hrp)
				else
					KX.travelToSea(3)
				end
				return
			end
			KX.stepLevelingTier2(hrp)
			return
		end

		-- TIER 3: Full Godhuman Unlock
		if not KX.ownedMelees["Godhuman"] then
			KX.stepGodhumanTier3(hrp)
			return
		end

		-- TIER 4: Cursed Dual Katana (CDK)
		if KX.needsCDK() then
			KX.stepCDKTier4(hrp)
			return
		end

		-- TIER 5: Soul Guitar
		if KX.needsSoulGuitar() then
			KX.stepSoulGuitarTier5(hrp)
			return
		end

		-- TIER 6: Remaining Priority Swords & Guns
		if KX.tryStepWeaponsTier6(hrp) then
			return
		end

		-- TIER 7: Final Endgame — Mirage Island + Mirror Fractal + Blue Gear (Strictly LAST!)
		if not KX.questsDone.blueGear then
			KX.stepMirageEndgameTier7(hrp)
			return
		end

		KX.phaseText = "Completed (100%)"
		setStatus("🏆 ¡Kaitun Series X completado al 100%!", KX.phaseText)
	end
end

--------------------------------------------------------------------------------
-- 9. UPGRADED SERIES X UI: EMOJIS + REAL-TIME MELEE & EXP TRACKER
--------------------------------------------------------------------------------
do
	local THEME = {
		BgOuter       = Color3.fromRGB(10, 4, 15),
		BgInner       = Color3.fromRGB(13, 5, 20),
		BgBox         = Color3.fromRGB(16, 7, 25),
		BgCard        = Color3.fromRGB(24, 10, 38),
		BorderOuter   = Color3.fromRGB(126, 42, 180),
		BorderInner   = Color3.fromRGB(86, 26, 124),
		BorderBox     = Color3.fromRGB(98, 32, 144),
		VeinLine      = Color3.fromRGB(26, 10, 40),
		AccentPurple  = Color3.fromRGB(168, 86, 240),
		AccentBright  = Color3.fromRGB(206, 140, 255),
		TextPrimary   = Color3.fromRGB(232, 226, 242),
		TextSecondary = Color3.fromRGB(172, 158, 192),
		CheckBg       = Color3.fromRGB(36, 15, 56),
		GreenOk       = Color3.fromRGB(86, 220, 112),
		RedMissing    = Color3.fromRGB(228, 70, 82),
		ExpTrack      = Color3.fromRGB(38, 16, 58),
	}

	local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "SwitchHub_SeriesX_Kaitun"
	ScreenGui.ResetOnSpawn = false
	ScreenGui.IgnoreGuiInset = true
	ScreenGui.DisplayOrder = 9500 -- Below Blox Fruits CustomCursor (10000) so cursor stays visible!
	ScreenGui.Parent = CoreGui

	local MainWin = Instance.new("Frame")
	MainWin.Name = "MainWindow"
	MainWin.Size = UDim2.new(0, 650, 0, 665)
	MainWin.AnchorPoint = Vector2.new(0.5, 0.5)
	MainWin.Position = UDim2.new(0.5, 0, 0.5, 0)
	MainWin.BackgroundColor3 = THEME.BgOuter
	MainWin.BorderSizePixel = 0
	MainWin.ClipsDescendants = true
	MainWin.Parent = ScreenGui

	local mainCorner = Instance.new("UICorner")
	mainCorner.CornerRadius = UDim.new(0, 5)
	mainCorner.Parent = MainWin

	-- Auto-scale cleanly on smaller 720p/768p screens so the entire panel stays crisp and visible
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = MainWin
	local function updateWindowScale()
		local cam = Workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1366, 768)
		local targetScale = math.clamp(math.min((vp.Y - 36) / 675, (vp.X - 36) / 660), 0.70, 1.0)
		uiScale.Scale = targetScale
	end
	updateWindowScale()
	if Workspace.CurrentCamera then
		connect(Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), updateWindowScale)
	end

	local outerStroke = Instance.new("UIStroke")
	outerStroke.Color = THEME.BorderOuter
	outerStroke.Thickness = 1.5
	outerStroke.Parent = MainWin

	-- Subtle dark purple organic diagonal veins in background matching the Series X theme
	local bgDecor = Instance.new("Frame")
	bgDecor.Size = UDim2.new(1, 0, 1, 0)
	bgDecor.BackgroundTransparency = 1
	bgDecor.ZIndex = 1
	bgDecor.Parent = MainWin
	for i = 1, 7 do
		local vLine = Instance.new("Frame")
		vLine.Size = UDim2.new(0, 2, 1.3, 0)
		vLine.Position = UDim2.new(i * 0.13, 0, -0.15, 0)
		vLine.Rotation = (i % 2 == 0) and 22 or -19
		vLine.BackgroundColor3 = THEME.VeinLine
		vLine.BackgroundTransparency = 0.42
		vLine.BorderSizePixel = 0
		vLine.ZIndex = 1
		vLine.Parent = bgDecor
	end

	local InnerFrame = Instance.new("Frame")
	InnerFrame.Name = "InnerFrame"
	InnerFrame.Size = UDim2.new(1, -12, 1, -12)
	InnerFrame.Position = UDim2.new(0, 6, 0, 6)
	InnerFrame.BackgroundColor3 = THEME.BgInner
	InnerFrame.BackgroundTransparency = 0.22
	InnerFrame.BorderSizePixel = 0
	InnerFrame.ZIndex = 2
	InnerFrame.Parent = MainWin

	local innerCorner = Instance.new("UICorner")
	innerCorner.CornerRadius = UDim.new(0, 4)
	innerCorner.Parent = InnerFrame

	local innerStroke = Instance.new("UIStroke")
	innerStroke.Color = THEME.BorderInner
	innerStroke.Thickness = 1
	innerStroke.Parent = InnerFrame

	-- =========================================================================
	-- TOP HEADER BAR: ⚡ Switch Hub [ Series X ] | 📊 General ⚙️  [🟢 ACTIVE] —
	-- =========================================================================
	local HeaderBar = Instance.new("Frame")
	HeaderBar.Name = "HeaderBar"
	HeaderBar.Size = UDim2.new(1, -12, 0, 34)
	HeaderBar.Position = UDim2.new(0, 6, 0, 6)
	HeaderBar.BackgroundColor3 = THEME.BgOuter
	HeaderBar.BorderSizePixel = 0
	HeaderBar.ZIndex = 4
	HeaderBar.Parent = InnerFrame

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 4)
	headerCorner.Parent = HeaderBar

	local headerStroke = Instance.new("UIStroke")
	headerStroke.Color = THEME.BorderBox
	headerStroke.Thickness = 1
	headerStroke.Parent = HeaderBar

	local HeaderAccentLine = Instance.new("Frame")
	HeaderAccentLine.Size = UDim2.new(1, 0, 0, 1)
	HeaderAccentLine.Position = UDim2.new(0, 0, 1, -1)
	HeaderAccentLine.BackgroundColor3 = THEME.AccentPurple
	HeaderAccentLine.BackgroundTransparency = 0.45
	HeaderAccentLine.BorderSizePixel = 0
	HeaderAccentLine.ZIndex = 5
	HeaderAccentLine.Parent = HeaderBar

	local BrandLabel = Instance.new("TextLabel")
	BrandLabel.Size = UDim2.new(0, 224, 1, 0)
	BrandLabel.Position = UDim2.new(0, 10, 0, 0)
	BrandLabel.BackgroundTransparency = 1
	BrandLabel.Font = Enum.Font.RobotoMono
	BrandLabel.TextSize = 14
	BrandLabel.TextColor3 = THEME.AccentBright
	BrandLabel.TextXAlignment = Enum.TextXAlignment.Left
	BrandLabel.Text = "⚡ Switch Hub [ Series X ]"
	BrandLabel.ZIndex = 5
	BrandLabel.Parent = HeaderBar

	local PipeLabel = Instance.new("TextLabel")
	PipeLabel.Size = UDim2.new(0, 14, 1, 0)
	PipeLabel.Position = UDim2.new(0, 234, 0, 0)
	PipeLabel.BackgroundTransparency = 1
	PipeLabel.Font = Enum.Font.RobotoMono
	PipeLabel.TextSize = 14
	PipeLabel.TextColor3 = THEME.TextSecondary
	PipeLabel.Text = "|"
	PipeLabel.ZIndex = 5
	PipeLabel.Parent = HeaderBar

	local GeneralTabBtn = Instance.new("TextButton")
	GeneralTabBtn.Size = UDim2.new(0, 88, 1, -4)
	GeneralTabBtn.Position = UDim2.new(0, 250, 0, 2)
	GeneralTabBtn.BackgroundTransparency = 1
	GeneralTabBtn.Font = Enum.Font.RobotoMono
	GeneralTabBtn.TextSize = 13
	GeneralTabBtn.TextColor3 = THEME.TextPrimary
	GeneralTabBtn.Text = "📊 General"
	GeneralTabBtn.ZIndex = 5
	GeneralTabBtn.Parent = HeaderBar

	local GeneralUnderline = Instance.new("Frame")
	GeneralUnderline.Size = UDim2.new(1, 0, 0, 2)
	GeneralUnderline.Position = UDim2.new(0, 0, 1, -2)
	GeneralUnderline.BackgroundColor3 = THEME.AccentPurple
	GeneralUnderline.BorderSizePixel = 0
	GeneralUnderline.ZIndex = 6
	GeneralUnderline.Parent = GeneralTabBtn

	local GearTabBtn = Instance.new("TextButton")
	GearTabBtn.Size = UDim2.new(0, 34, 1, -4)
	GearTabBtn.Position = UDim2.new(0, 342, 0, 2)
	GearTabBtn.BackgroundTransparency = 1
	GearTabBtn.Font = Enum.Font.GothamBold
	GearTabBtn.TextSize = 14
	GearTabBtn.TextColor3 = THEME.TextSecondary
	GearTabBtn.Text = "⚙️"
	GearTabBtn.ZIndex = 5
	GearTabBtn.Parent = HeaderBar

	local GearUnderline = Instance.new("Frame")
	GearUnderline.Size = UDim2.new(1, -4, 0, 2)
	GearUnderline.Position = UDim2.new(0, 2, 1, -2)
	GearUnderline.BackgroundColor3 = THEME.AccentPurple
	GearUnderline.BorderSizePixel = 0
	GearUnderline.Visible = false
	GearUnderline.ZIndex = 6
	GearUnderline.Parent = GearTabBtn

	-- Live Running State Badge in Header
	local StateBadge = Instance.new("Frame")
	StateBadge.Size = UDim2.new(0, 96, 0, 20)
	StateBadge.Position = UDim2.new(1, -134, 0.5, -10)
	StateBadge.BackgroundColor3 = THEME.BgCard
	StateBadge.BorderSizePixel = 0
	StateBadge.ZIndex = 5
	StateBadge.Parent = HeaderBar

	local sbCorner = Instance.new("UICorner")
	sbCorner.CornerRadius = UDim.new(0, 10)
	sbCorner.Parent = StateBadge

	local sbStroke = Instance.new("UIStroke")
	sbStroke.Color = THEME.BorderOuter
	sbStroke.Thickness = 1
	sbStroke.Parent = StateBadge

	local LblStateBadge = Instance.new("TextLabel")
	LblStateBadge.Size = UDim2.new(1, 0, 1, 0)
	LblStateBadge.BackgroundTransparency = 1
	LblStateBadge.Font = Enum.Font.RobotoMono
	LblStateBadge.TextSize = 11
	LblStateBadge.TextColor3 = THEME.TextSecondary
	LblStateBadge.Text = "🟣 STANDBY"
	LblStateBadge.ZIndex = 6
	LblStateBadge.Parent = StateBadge

	local MinBtn = Instance.new("TextButton")
	MinBtn.Size = UDim2.new(0, 28, 0, 24)
	MinBtn.Position = UDim2.new(1, -32, 0.5, -12)
	MinBtn.BackgroundTransparency = 1
	MinBtn.Font = Enum.Font.RobotoMono
	MinBtn.TextSize = 15
	MinBtn.TextColor3 = THEME.AccentBright
	MinBtn.Text = "—"
	MinBtn.ZIndex = 5
	MinBtn.Parent = HeaderBar

	-- Draggable window via HeaderBar
	do
		local dragging, dragStart, startPos = false, nil, nil
		connect(HeaderBar.InputBegan, function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = true
				dragStart = inp.Position
				startPos = MainWin.Position
				inp.Changed:Connect(function()
					if inp.UserInputState == Enum.UserInputState.End then
						dragging = false
					end
				end)
			end
		end)
		connect(UserInputService.InputChanged, function(inp)
			if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement and dragStart and startPos then
				local delta = (inp.Position - dragStart) / math.max(uiScale.Scale, 0.5)
				MainWin.Position = UDim2.new(
					startPos.X.Scale,
					startPos.X.Offset + delta.X,
					startPos.Y.Scale,
					startPos.Y.Offset + delta.Y
				)
			end
		end)
	end

	-- Floating Toggle Pill (Left Edge so Choose Team Pirates/Marines is never covered)
	local FloatPill = Instance.new("TextButton")
	FloatPill.Name = "SeriesX_FloatToggle"
	FloatPill.Size = UDim2.new(0, 156, 0, 32)
	FloatPill.Position = UDim2.new(0, 16, 0.5, -16)
	FloatPill.BackgroundColor3 = THEME.BgOuter
	FloatPill.BorderSizePixel = 0
	FloatPill.Font = Enum.Font.RobotoMono
	FloatPill.TextSize = 12
	FloatPill.TextColor3 = THEME.AccentBright
	FloatPill.Text = "⚡ [ Series X ] Abrir"
	FloatPill.Visible = false
	FloatPill.Parent = ScreenGui

	local pillCorner = Instance.new("UICorner")
	pillCorner.CornerRadius = UDim.new(0, 6)
	pillCorner.Parent = FloatPill

	local pillStroke = Instance.new("UIStroke")
	pillStroke.Color = THEME.BorderOuter
	pillStroke.Thickness = 1.3
	pillStroke.Parent = FloatPill

	connect(MinBtn.MouseButton1Click, function()
		MainWin.Visible = false
		FloatPill.Visible = true
	end)
	connect(FloatPill.MouseButton1Click, function()
		MainWin.Visible = true
		FloatPill.Visible = false
	end)
	connect(UserInputService.InputBegan, function(inp, gpe)
		if not gpe and inp.KeyCode == Enum.KeyCode.RightControl then
			MainWin.Visible = not MainWin.Visible
			FloatPill.Visible = not MainWin.Visible
		end
	end)

	-- =========================================================================
	-- PAGE CONTAINERS: GENERAL PAGE & SETTINGS (⚙️) PAGE
	-- =========================================================================
	local function makePageScroll(name, visible)
		local sf = Instance.new("ScrollingFrame")
		sf.Name = name
		sf.Size = UDim2.new(1, -12, 1, -52)
		sf.Position = UDim2.new(0, 6, 0, 46)
		sf.BackgroundTransparency = 1
		sf.BorderSizePixel = 0
		sf.ScrollBarThickness = 3
		sf.ScrollBarImageColor3 = THEME.BorderOuter
		sf.CanvasSize = UDim2.new(0, 0, 0, 0)
		sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
		sf.Visible = visible
		sf.ZIndex = 3
		sf.Parent = InnerFrame
		return sf
	end

	local GeneralPage = makePageScroll("GeneralPage", true)
	local SettingsPage = makePageScroll("SettingsPage", false)

	local function selectPage(which)
		local isGen = (which == "General")
		GeneralPage.Visible = isGen
		SettingsPage.Visible = not isGen
		GeneralUnderline.Visible = isGen
		GearUnderline.Visible = not isGen
		GeneralTabBtn.TextColor3 = isGen and THEME.TextPrimary or THEME.TextSecondary
		GearTabBtn.TextColor3 = (not isGen) and THEME.AccentBright or THEME.TextSecondary
	end

	connect(GeneralTabBtn.MouseButton1Click, function() selectPage("General") end)
	connect(GearTabBtn.MouseButton1Click, function() selectPage("Settings") end)

	local function createTwoColumns(page)
		local leftCol = Instance.new("Frame")
		leftCol.Name = "LeftCol"
		leftCol.Size = UDim2.new(0.50, -4, 0, 0)
		leftCol.Position = UDim2.new(0, 2, 0, 2)
		leftCol.AutomaticSize = Enum.AutomaticSize.Y
		leftCol.BackgroundTransparency = 1
		leftCol.ZIndex = 3
		leftCol.Parent = page

		local lLayout = Instance.new("UIListLayout")
		lLayout.SortOrder = Enum.SortOrder.LayoutOrder
		lLayout.Padding = UDim.new(0, 8)
		lLayout.Parent = leftCol

		local rightCol = Instance.new("Frame")
		rightCol.Name = "RightCol"
		rightCol.Size = UDim2.new(0.50, -6, 0, 0)
		rightCol.Position = UDim2.new(0.50, 4, 0, 2)
		rightCol.AutomaticSize = Enum.AutomaticSize.Y
		rightCol.BackgroundTransparency = 1
		rightCol.ZIndex = 3
		rightCol.Parent = page

		local rLayout = Instance.new("UIListLayout")
		rLayout.SortOrder = Enum.SortOrder.LayoutOrder
		rLayout.Padding = UDim.new(0, 8)
		rLayout.Parent = rightCol

		local bPadL = Instance.new("UIPadding")
		bPadL.PaddingBottom = UDim.new(0, 10)
		bPadL.Parent = leftCol

		local bPadR = Instance.new("UIPadding")
		bPadR.PaddingBottom = UDim.new(0, 10)
		bPadR.Parent = rightCol

		return leftCol, rightCol
	end

	-- Creates a Legend/Fieldset Box with purple title interrupting top border
	local function createFieldsetBox(parentCol, titleText, order)
		local wrap = Instance.new("Frame")
		wrap.Name = titleText .. "_Fieldset"
		wrap.Size = UDim2.new(1, 0, 0, 0)
		wrap.AutomaticSize = Enum.AutomaticSize.Y
		wrap.BackgroundTransparency = 1
		wrap.LayoutOrder = order
		wrap.ZIndex = 3
		wrap.Parent = parentCol

		local box = Instance.new("Frame")
		box.Name = "Box"
		box.Size = UDim2.new(1, 0, 0, 0)
		box.Position = UDim2.new(0, 0, 0, 7)
		box.AutomaticSize = Enum.AutomaticSize.Y
		box.BackgroundColor3 = THEME.BgBox
		box.BackgroundTransparency = 0.22
		box.BorderSizePixel = 0
		box.ZIndex = 3
		box.Parent = wrap

		local boxCorner = Instance.new("UICorner")
		boxCorner.CornerRadius = UDim.new(0, 4)
		boxCorner.Parent = box

		local bStroke = Instance.new("UIStroke")
		bStroke.Color = THEME.BorderBox
		bStroke.Thickness = 1
		bStroke.Parent = box

		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 12)
		pad.PaddingBottom = UDim.new(0, 8)
		pad.PaddingLeft = UDim.new(0, 10)
		pad.PaddingRight = UDim.new(0, 8)
		pad.Parent = box

		local list = Instance.new("UIListLayout")
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Padding = UDim.new(0, 4)
		list.Parent = box

		local legend = Instance.new("TextLabel")
		legend.Name = "Legend"
		legend.AutomaticSize = Enum.AutomaticSize.X
		legend.Size = UDim2.new(0, 0, 0, 15)
		legend.Position = UDim2.new(0, 10, 0, 0)
		legend.BackgroundColor3 = THEME.BgOuter
		legend.BorderSizePixel = 0
		legend.Font = Enum.Font.RobotoMono
		legend.TextSize = 12
		legend.TextColor3 = THEME.AccentBright
		legend.Text = " " .. titleText .. " "
		legend.ZIndex = 5
		legend.Parent = wrap

		return box
	end

	local function addInfoTextRow(box, defaultText, order)
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 0, 0)
		lbl.AutomaticSize = Enum.AutomaticSize.Y
		lbl.BackgroundTransparency = 1
		lbl.LayoutOrder = order or 1
		lbl.Font = Enum.Font.RobotoMono
		lbl.TextSize = 12
		lbl.TextWrapped = true
		lbl.TextColor3 = THEME.TextPrimary
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Text = defaultText
		lbl.ZIndex = 4
		lbl.Parent = box
		return lbl
	end

	-- Creates a live checklist row supporting active highlight & real-time EXP/Mastery suffix
	local function addChecklistItemRow(box, itemLabel, order)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 17)
		row.BackgroundTransparency = 1
		row.LayoutOrder = order
		row.ZIndex = 4
		row.Parent = box

		local badge = Instance.new("Frame")
		badge.Size = UDim2.new(0, 13, 0, 13)
		badge.Position = UDim2.new(0, 0, 0.5, -6)
		badge.BackgroundColor3 = THEME.GreenOk
		badge.BackgroundTransparency = 1
		badge.BorderSizePixel = 0
		badge.ZIndex = 4
		badge.Parent = row

		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, 3)
		bc.Parent = badge

		local icon = Instance.new("TextLabel")
		icon.Size = UDim2.new(1, 0, 1, 0)
		icon.BackgroundTransparency = 1
		icon.Font = Enum.Font.GothamBold
		icon.TextSize = 11
		icon.TextColor3 = THEME.RedMissing
		icon.Text = "✕"
		icon.ZIndex = 5
		icon.Parent = badge

		local txt = Instance.new("TextLabel")
		txt.Size = UDim2.new(1, -18, 1, 0)
		txt.Position = UDim2.new(0, 17, 0, 0)
		txt.BackgroundTransparency = 1
		txt.Font = Enum.Font.RobotoMono
		txt.TextSize = 11
		txt.TextTruncate = Enum.TextTruncate.AtEnd
		txt.TextColor3 = THEME.TextPrimary
		txt.TextXAlignment = Enum.TextXAlignment.Left
		txt.Text = ": " .. itemLabel
		txt.ZIndex = 4
		txt.Parent = row

		local function setOwned(owned, extraSuffix, isActiveHighlight)
			if owned then
				badge.BackgroundTransparency = 0.05
				badge.BackgroundColor3 = isActiveHighlight and THEME.AccentBright or THEME.GreenOk
				icon.Text = "✓"
				icon.TextColor3 = Color3.fromRGB(16, 20, 24)
			else
				badge.BackgroundTransparency = 1
				icon.Text = "✕"
				icon.TextColor3 = THEME.RedMissing
			end
			txt.TextColor3 = isActiveHighlight and THEME.AccentBright or (owned and THEME.TextPrimary or THEME.TextSecondary)
			txt.Text = ": " .. itemLabel .. (extraSuffix or "")
		end
		setOwned(false)
		return setOwned
	end

	-- Creates a purple square checkbox "[■] Auto Farm"
	local function addPurpleCheckbox(box, labelText, initialValue, order, onChanged)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, 0, 0, 20)
		btn.BackgroundTransparency = 1
		btn.Text = ""
		btn.LayoutOrder = order
		btn.ZIndex = 4
		btn.Parent = box

		local sq = Instance.new("Frame")
		sq.Size = UDim2.new(0, 13, 0, 13)
		sq.Position = UDim2.new(0, 1, 0.5, -6)
		sq.BackgroundColor3 = THEME.CheckBg
		sq.BorderSizePixel = 0
		sq.ZIndex = 4
		sq.Parent = btn

		local sqCorner = Instance.new("UICorner")
		sqCorner.CornerRadius = UDim.new(0, 2)
		sqCorner.Parent = sq

		local sqStroke = Instance.new("UIStroke")
		sqStroke.Color = THEME.BorderOuter
		sqStroke.Thickness = 1
		sqStroke.Parent = sq

		local fill = Instance.new("Frame")
		fill.Size = UDim2.new(1, -3, 1, -3)
		fill.Position = UDim2.new(0, 1.5, 0, 1.5)
		fill.BackgroundColor3 = THEME.AccentPurple
		fill.BorderSizePixel = 0
		fill.Visible = (initialValue == true)
		fill.ZIndex = 5
		fill.Parent = sq

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -22, 1, 0)
		lbl.Position = UDim2.new(0, 21, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.RobotoMono
		lbl.TextSize = 12
		lbl.TextColor3 = THEME.TextPrimary
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Text = labelText
		lbl.ZIndex = 4
		lbl.Parent = btn

		local curState = (initialValue == true)
		local function setVal(v, silent)
			curState = (v == true)
			fill.Visible = curState
			if not silent and onChanged then
				onChanged(curState)
			end
		end

		connect(btn.MouseButton1Click, function()
			setVal(not curState, false)
		end)

		return setVal, lbl
	end

	-- =========================================================================
	-- BUILD GENERAL PAGE (UPGRADED TWO-COLUMN KAITUN SERIES X LAYOUT)
	-- =========================================================================
	local GenLeft, GenRight = createTwoColumns(GeneralPage)

	-- LEFT 1: ⏱️ Time
	local BoxTime = createFieldsetBox(GenLeft, "⏱️ Time", 1)
	local LblTime = addInfoTextRow(BoxTime, "⏳ 0 Hr(s), 0 Min(s), 0 Sec(s)", 1)

	-- LEFT 2: 👤 Status
	local BoxStatus = createFieldsetBox(GenLeft, "👤 Status", 2)
	local LblName = addInfoTextRow(BoxStatus, "🪪 Name : " .. tostring(LocalPlayer.Name), 1)
	local LblWorld = addInfoTextRow(BoxStatus, "🌍 World : Sea 1 • ⭐ Lv. 1", 2)
	local LblFruit = addInfoTextRow(BoxStatus, "🍎 Fruit : None", 3)
	local LblAwaken = addInfoTextRow(BoxStatus, "✨ Awaken : -", 4)
	local LblExp2x = addInfoTextRow(BoxStatus, "🚀 2x EXP : Inactive", 5)

	-- LEFT 3: 📜 Quest
	local BoxQuest = createFieldsetBox(GenLeft, "📜 Quest", 3)
	local QuestRows = {
		saber          = addChecklistItemRow(BoxQuest, "🗡️ Quest Saber", 1),
		dressrosa      = addChecklistItemRow(BoxQuest, "❄️ Quest Dressrosa", 2),
		bartilo        = addChecklistItemRow(BoxQuest, "🔨 Quest Bartilo", 3),
		donSwan        = addChecklistItemRow(BoxQuest, "🦩 Quest Don Swan", 4),
		ripIndraSea2   = addChecklistItemRow(BoxQuest, "👑 Quest Rip Indra", 5),
		deathStep      = addChecklistItemRow(BoxQuest, "🔥 Quest Death Step", 6),
		sharkmanKarate = addChecklistItemRow(BoxQuest, "🦈 Quest Sharkman Karate", 7),
		electricClaw   = addChecklistItemRow(BoxQuest, "🌩️ Quest Electric Claw", 8),
		dragonTalon    = addChecklistItemRow(BoxQuest, "🐲 Quest Dragon Talon", 9),
		mirrorFractal  = addChecklistItemRow(BoxQuest, "🪞 Mirror Fractal", 10),
		blueGear       = addChecklistItemRow(BoxQuest, "⚙️ Mirage & Blue Gear", 11),
	}

	-- LEFT 4: 🥊 Melee (REAL-TIME ACTIVE MELEE + LIVE EXP BAR + ALL STYLES)
	local BoxMelee = createFieldsetBox(GenLeft, "🥊 Melee (Real-Time)", 4)

	local ActiveMeleeCard = Instance.new("Frame")
	ActiveMeleeCard.Name = "ActiveMeleeCard"
	ActiveMeleeCard.Size = UDim2.new(1, 0, 0, 52)
	ActiveMeleeCard.BackgroundColor3 = THEME.BgCard
	ActiveMeleeCard.BackgroundTransparency = 0.12
	ActiveMeleeCard.BorderSizePixel = 0
	ActiveMeleeCard.LayoutOrder = 0
	ActiveMeleeCard.ZIndex = 4
	ActiveMeleeCard.Parent = BoxMelee

	local amCorner = Instance.new("UICorner")
	amCorner.CornerRadius = UDim.new(0, 4)
	amCorner.Parent = ActiveMeleeCard

	local amStroke = Instance.new("UIStroke")
	amStroke.Color = THEME.AccentPurple
	amStroke.Thickness = 1
	amStroke.Transparency = 0.25
	amStroke.Parent = ActiveMeleeCard

	local LblActiveMeleeTitle = Instance.new("TextLabel")
	LblActiveMeleeTitle.Size = UDim2.new(1, -12, 0, 16)
	LblActiveMeleeTitle.Position = UDim2.new(0, 6, 0, 4)
	LblActiveMeleeTitle.BackgroundTransparency = 1
	LblActiveMeleeTitle.Font = Enum.Font.RobotoMono
	LblActiveMeleeTitle.TextSize = 12
	LblActiveMeleeTitle.TextColor3 = THEME.AccentBright
	LblActiveMeleeTitle.TextXAlignment = Enum.TextXAlignment.Left
	LblActiveMeleeTitle.TextTruncate = Enum.TextTruncate.AtEnd
	LblActiveMeleeTitle.Text = "⚡ Actual: Detectando..."
	LblActiveMeleeTitle.ZIndex = 5
	LblActiveMeleeTitle.Parent = ActiveMeleeCard

	local LblActiveMeleeExp = Instance.new("TextLabel")
	LblActiveMeleeExp.Size = UDim2.new(1, -12, 0, 15)
	LblActiveMeleeExp.Position = UDim2.new(0, 6, 0, 21)
	LblActiveMeleeExp.BackgroundTransparency = 1
	LblActiveMeleeExp.Font = Enum.Font.RobotoMono
	LblActiveMeleeExp.TextSize = 11
	LblActiveMeleeExp.TextColor3 = THEME.TextPrimary
	LblActiveMeleeExp.TextXAlignment = Enum.TextXAlignment.Left
	LblActiveMeleeExp.TextTruncate = Enum.TextTruncate.AtEnd
	LblActiveMeleeExp.Text = "✨ EXP: 0 / 0 (0.0%)"
	LblActiveMeleeExp.ZIndex = 5
	LblActiveMeleeExp.Parent = ActiveMeleeCard

	local ExpBarTrack = Instance.new("Frame")
	ExpBarTrack.Size = UDim2.new(1, -12, 0, 6)
	ExpBarTrack.Position = UDim2.new(0, 6, 0, 40)
	ExpBarTrack.BackgroundColor3 = THEME.ExpTrack
	ExpBarTrack.BorderSizePixel = 0
	ExpBarTrack.ZIndex = 5
	ExpBarTrack.Parent = ActiveMeleeCard

	local ebTrackCorner = Instance.new("UICorner")
	ebTrackCorner.CornerRadius = UDim.new(1, 0)
	ebTrackCorner.Parent = ExpBarTrack

	local ExpBarFill = Instance.new("Frame")
	ExpBarFill.Size = UDim2.new(0, 0, 1, 0)
	ExpBarFill.BackgroundColor3 = THEME.AccentPurple
	ExpBarFill.BorderSizePixel = 0
	ExpBarFill.ZIndex = 6
	ExpBarFill.Parent = ExpBarTrack

	local ebFillCorner = Instance.new("UICorner")
	ebFillCorner.CornerRadius = UDim.new(1, 0)
	ebFillCorner.Parent = ExpBarFill

	local ebGrad = Instance.new("UIGradient")
	ebGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, THEME.AccentPurple),
		ColorSequenceKeypoint.new(1, THEME.AccentBright),
	})
	ebGrad.Parent = ExpBarFill

	local MeleeRows = {}
	for i, entry in ipairs(MELEE_ENTRIES) do
		MeleeRows[entry.ui] = addChecklistItemRow(BoxMelee, entry.icon .. " " .. entry.ui, i)
	end

	-- LEFT 5: 🎒 Information
	local BoxInfo = createFieldsetBox(GenLeft, "🎒 Information", 5)
	local LblBone = addInfoTextRow(BoxInfo, "🦴 Bone : 0", 1)
	local LblEcto = addInfoTextRow(BoxInfo, "👻 Ectoplasm : 0", 2)
	local LblElite = addInfoTextRow(BoxInfo, "🎯 Elite Hunter : 0/30", 3)
	local LblDarkFrag = addInfoTextRow(BoxInfo, "🌑 Dark Fragment : 0", 4)
	local LblCocoa = addInfoTextRow(BoxInfo, "🍫 Conjured Cocoa : 0", 5)
	local LblAlucard = addInfoTextRow(BoxInfo, "🩸 Alucard Frag : 0/6", 6)
	local LblValkyrie = addInfoTextRow(BoxInfo, "🪖 Valkyrie Helm : No", 7)
	local LblCurrency = addInfoTextRow(BoxInfo, "💰 Beli : 0  |  💎 Frag : 0", 8)

	-- RIGHT 1: ⚔️ Farming (THE 1-CLICK KAITUN BUTTON + AUTO RAID PRIORITY!)
	local BoxFarming = createFieldsetBox(GenRight, "⚔️ Farming & Auto Raid", 1)
	local setAutoFarmUI
	setAutoFarmUI = addPurpleCheckbox(BoxFarming, "⚡ Auto Farm (All-In-One Kaitun)", KX.autoFarm, 1, function(enabled)
		KX.autoFarm = enabled
		if not enabled then
			KX.lastAimEnemy = nil
			KX.lastAimPart = nil
			KX.stopTween()
			setStatus("⏸️ Idle (Paused)", "Standby")
		else
			setStatus("🚀 Iniciando Kaitun Series X...", "Initializing")
		end
		saveConfig()
	end)
	addPurpleCheckbox(BoxFarming, "🔥 Auto Raid (Prioridad Frutas <=1M)", KX.autoRaid, 2, function(v)
		KX.autoRaid = v
		KX.raidCooldownUntil = 0
		saveConfig()
	end)
	addPurpleCheckbox(BoxFarming, "💥 Kill Aura Raid (Islas 1-3 + Melé)", KX.raidKillAuraUpTo3, 3, function(v)
		KX.raidKillAuraUpTo3 = v
		saveConfig()
	end)
	local LblFarmStatus = addInfoTextRow(BoxFarming, "📡 Status : " .. tostring(KX.statusText), 4)
	local LblFarmPhase = addInfoTextRow(BoxFarming, "🧭 Phase : " .. tostring(KX.phaseText), 5)
	LblFarmPhase.TextColor3 = THEME.TextSecondary
	local LblRaidInfo = addInfoTextRow(BoxFarming, "⚡ Raid : " .. tostring(KX.lastRaidStatus), 6)
	LblRaidInfo.TextColor3 = THEME.AccentBright

	-- RIGHT 2: 🗡️ Sword (All 18 Swords + Live Mastery)
	local BoxSword = createFieldsetBox(GenRight, "🗡️ Sword", 2)
	local SwordRows = {}
	for i, entry in ipairs(SWORD_LIST) do
		SwordRows[entry.ui] = addChecklistItemRow(BoxSword, entry.icon .. " " .. entry.ui, i)
	end

	-- RIGHT 3: 🔫 Gun (All 6 Guns + Live Mastery)
	local BoxGun = createFieldsetBox(GenRight, "🔫 Gun", 3)
	local GunRows = {}
	for i, entry in ipairs(GUN_LIST) do
		GunRows[entry.ui] = addChecklistItemRow(BoxGun, entry.icon .. " " .. entry.ui, i)
	end

	-- =========================================================================
	-- BUILD SETTINGS PAGE (⚙️ ICON NEXT TO GENERAL)
	-- =========================================================================
	local SetLeft, SetRight = createTwoColumns(SettingsPage)

	local BoxCoreCfg = createFieldsetBox(SetLeft, "⚙️ Kaitun Engine", 1)
	local TeamBtn = Instance.new("TextButton")
	TeamBtn.Size = UDim2.new(1, 0, 0, 24)
	TeamBtn.BackgroundColor3 = THEME.CheckBg
	TeamBtn.BorderSizePixel = 0
	TeamBtn.LayoutOrder = 1
	TeamBtn.Font = Enum.Font.RobotoMono
	TeamBtn.TextSize = 12
	TeamBtn.TextColor3 = THEME.AccentBright
	TeamBtn.Text = "🏴‍☠️ Team : " .. tostring(KX.preferredTeam) .. " (Click)"
	TeamBtn.ZIndex = 4
	TeamBtn.Parent = BoxCoreCfg
	local tbCorner = Instance.new("UICorner")
	tbCorner.CornerRadius = UDim.new(0, 4)
	tbCorner.Parent = TeamBtn
	local tbStroke = Instance.new("UIStroke")
	tbStroke.Color = THEME.BorderBox
	tbStroke.Thickness = 1
	tbStroke.Parent = TeamBtn

	connect(TeamBtn.MouseButton1Click, function()
		KX.preferredTeam = (KX.preferredTeam == "Pirates") and "Marines" or "Pirates"
		local tIcon = (KX.preferredTeam == "Pirates") and "🏴‍☠️" or "⚓"
		TeamBtn.Text = tIcon .. " Team : " .. KX.preferredTeam .. " (Click)"
		saveConfig()
		if CommF_ then
			task.spawn(function()
				pcall(function() CommF_:InvokeServer("SetTeam", KX.preferredTeam) end)
			end)
		end
	end)

	local function getSpeedLabelText(spd)
		if spd <= 170 then
			return "✈️ Velocidad : 🐢 Segura (" .. tostring(spd) .. ") [Click]"
		elseif spd >= 200 then
			return "✈️ Velocidad : ⚡ Rápida (" .. tostring(spd) .. ") [Click]"
		end
		return "✈️ Velocidad : ⚖️ Moderada (" .. tostring(spd) .. ") [Click]"
	end

	local SpeedBtn = Instance.new("TextButton")
	SpeedBtn.Size = UDim2.new(1, 0, 0, 24)
	SpeedBtn.BackgroundColor3 = THEME.CheckBg
	SpeedBtn.BorderSizePixel = 0
	SpeedBtn.LayoutOrder = 2
	SpeedBtn.Font = Enum.Font.RobotoMono
	SpeedBtn.TextSize = 11
	SpeedBtn.TextColor3 = THEME.AccentBright
	SpeedBtn.Text = getSpeedLabelText(KX.tweenSpeed)
	SpeedBtn.ZIndex = 4
	SpeedBtn.Parent = BoxCoreCfg
	local spCorner = Instance.new("UICorner")
	spCorner.CornerRadius = UDim.new(0, 4)
	spCorner.Parent = SpeedBtn
	local spStroke = Instance.new("UIStroke")
	spStroke.Color = THEME.BorderBox
	spStroke.Thickness = 1
	spStroke.Parent = SpeedBtn

	connect(SpeedBtn.MouseButton1Click, function()
		if KX.tweenSpeed <= 170 then
			KX.tweenSpeed = 185
		elseif KX.tweenSpeed < 200 then
			KX.tweenSpeed = 205
		else
			KX.tweenSpeed = 165
		end
		SpeedBtn.Text = getSpeedLabelText(KX.tweenSpeed)
		if KX.activeTween then
			pcall(function() KX.activeTween:Cancel() end)
			KX.activeTween = nil
		end
		saveConfig()
	end)

	addPurpleCheckbox(BoxCoreCfg, "🚫 Sin Animación de Golpe (No Hit Anim)", KX.noAttackAnimation, 3, function(v)
		KX.noAttackAnimation = v; saveConfig()
	end)
	addPurpleCheckbox(BoxCoreCfg, "🚀 Smart 2x EXP Codes", KX.smart2xExpCodes, 4, function(v)
		KX.smart2xExpCodes = v; saveConfig()
	end)
	addPurpleCheckbox(BoxCoreCfg, "📊 Auto Stats (Melee/Def/Sword)", KX.autoStats, 5, function(v)
		KX.autoStats = v; saveConfig()
	end)
	addPurpleCheckbox(BoxCoreCfg, "🛡️ Auto Buso Haki", KX.autoBuso, 6, function(v)
		KX.autoBuso = v; saveConfig()
	end)
	addPurpleCheckbox(BoxCoreCfg, "👁️ Auto Ken (Observation)", KX.autoKen, 7, function(v)
		KX.autoKen = v; saveConfig()
	end)
	addPurpleCheckbox(BoxCoreCfg, "⚡ Auto Race V3", KX.autoRaceV3, 8, function(v)
		KX.autoRaceV3 = v; saveConfig()
	end)
	addPurpleCheckbox(BoxCoreCfg, "🌐 Smart Server Hop", KX.smartServerHop, 9, function(v)
		KX.smartServerHop = v; saveConfig()
	end)

	local RAID_CHIP_CYCLE = {"Auto", "Flame", "Ice", "Light", "Magma", "Buddha", "Dark"}
	local RaidChipBtn = Instance.new("TextButton")
	RaidChipBtn.Size = UDim2.new(1, 0, 0, 24)
	RaidChipBtn.BackgroundColor3 = THEME.CheckBg
	RaidChipBtn.BorderSizePixel = 0
	RaidChipBtn.LayoutOrder = 10
	RaidChipBtn.Font = Enum.Font.RobotoMono
	RaidChipBtn.TextSize = 11
	RaidChipBtn.TextColor3 = THEME.AccentBright
	RaidChipBtn.Text = "🔥 Raid Chip : " .. tostring(KX.selectedRaidType) .. " [Click]"
	RaidChipBtn.ZIndex = 4
	RaidChipBtn.Parent = BoxCoreCfg
	local rcCorner = Instance.new("UICorner")
	rcCorner.CornerRadius = UDim.new(0, 4)
	rcCorner.Parent = RaidChipBtn
	local rcStroke = Instance.new("UIStroke")
	rcStroke.Color = THEME.BorderBox
	rcStroke.Thickness = 1
	rcStroke.Parent = RaidChipBtn

	connect(RaidChipBtn.MouseButton1Click, function()
		local curIdx = 1
		for i, n in ipairs(RAID_CHIP_CYCLE) do
			if n == KX.selectedRaidType then
				curIdx = i
				break
			end
		end
		KX.selectedRaidType = RAID_CHIP_CYCLE[(curIdx % #RAID_CHIP_CYCLE) + 1]
		RaidChipBtn.Text = "🔥 Raid Chip : " .. tostring(KX.selectedRaidType) .. " [Click]"
		saveConfig()
	end)

	local BoxPerf = createFieldsetBox(SetLeft, "🚀 Performance & AFK", 2)
	addPurpleCheckbox(BoxPerf, "💨 FPS Boost (Low GPU/CPU)", KX.fpsBoost, 1, function(v)
		KX.applyFpsBoost(v); saveConfig()
	end)
	addPurpleCheckbox(BoxPerf, "🌙 AFK Mode (3D Render Off)", KX.afkMode, 2, function(v)
		KX.applyAfkMode(v); saveConfig()
	end)

	local BoxFruitCfg = createFieldsetBox(SetRight, "🎰 Fruit Gacha & Store", 1)
	addPurpleCheckbox(BoxFruitCfg, "🎲 Auto Spin & Store Fruits", KX.autoSpinAndStoreFruits, 1, function(v)
		KX.autoSpinAndStoreFruits = v; saveConfig()
	end)
	addPurpleCheckbox(BoxFruitCfg, "🍎 Auto Grab Map Fruits", KX.autoGrabGroundFruits, 2, function(v)
		KX.autoGrabGroundFruits = v; saveConfig()
	end)
	addPurpleCheckbox(BoxFruitCfg, "🍽️ Eat Allowed Fruits Only", KX.autoEatAllowedFruits, 3, function(v)
		KX.autoEatAllowedFruits = v; saveConfig()
	end)
	addInfoTextRow(BoxFruitCfg, "ℹ️ Todas las frutas se guardan primero salvo que 'Eat Allowed' esté activo.", 4).TextColor3 = THEME.TextSecondary

	local BoxEatList = createFieldsetBox(SetRight, "🍽️ Allowed Fruits To Eat", 2)
	local EAT_CANDIDATES = {
		{key = "Buddha-Buddha", label = "🟡 Buddha-Buddha"},
		{key = "Light-Light", label = "✨ Light-Light"},
		{key = "Magma-Magma", label = "🌋 Magma-Magma"},
		{key = "Ice-Ice", label = "❄️ Ice-Ice"},
		{key = "Flame-Flame", label = "🔥 Flame-Flame"},
		{key = "Gas-Gas", label = "💨 Gas-Gas"},
		{key = "Kitsune-Kitsune", label = "🦊 Kitsune-Kitsune"},
	}
	for idx, entry in ipairs(EAT_CANDIDATES) do
		local fKey = entry.key
		addPurpleCheckbox(BoxEatList, entry.label, KX.allowedEatFruits[fKey] == true, idx, function(v)
			KX.allowedEatFruits[fKey] = v
			saveConfig()
		end)
	end

	-- Apply persisted FPS Boost / AFK Mode if saved
	if KX.fpsBoost then task.defer(function() KX.applyFpsBoost(true) end) end
	if KX.afkMode then task.defer(function() KX.applyAfkMode(true) end) end

	-- Keep Choose Team screen uncovered when Auto Farm is OFF at launch!
	if isChooseTeamScreenOpen() and not KX.autoFarm then
		MainWin.Visible = false
		FloatPill.Visible = true
		task.spawn(function()
			while isAlive() and isChooseTeamScreenOpen() and not KX.autoFarm do
				task.wait(0.3)
			end
			if isAlive() and not MainWin.Visible then
				MainWin.Visible = true
				FloatPill.Visible = false
			end
		end)
	end

	-- =========================================================================
	-- REAL-TIME UI & MELEE/EXP REFRESH LOOP (0.35s TICK)
	-- =========================================================================
	local function formatCompact(n)
		n = tonumber(n) or 0
		if n >= 1e6 then
			return string.format("%.2fM", n / 1e6)
		elseif n >= 1e3 then
			return string.format("%.1fK", n / 1e3)
		end
		return tostring(math.floor(n))
	end

	local function formatCommas(n)
		local s = tostring(math.floor(tonumber(n) or 0))
		local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
		return out
	end

	task.spawn(function()
		while isAlive() do
			pcall(function()
				-- Instant real-time Melee + Mastery + EXP read on every UI frame!
				KX.scanRealtimeMeleeAndWeapons()

				if KX.autoFarm then
					LblStateBadge.Text = "🟢 KAITUN ON"
					LblStateBadge.TextColor3 = THEME.GreenOk
					sbStroke.Color = THEME.GreenOk
				else
					LblStateBadge.Text = "🟣 STANDBY"
					LblStateBadge.TextColor3 = THEME.TextSecondary
					sbStroke.Color = THEME.BorderOuter
				end

				local elapsed = math.max(0, os.time() - KX.startTime)
				local hrs = math.floor(elapsed / 3600)
				local mins = math.floor((elapsed % 3600) / 60)
				local secs = elapsed % 60
				LblTime.Text = string.format("⏳ %d Hr(s), %d Min(s), %d Sec(s)", hrs, mins, secs)

				LblName.Text = "🪪 Name : " .. tostring(LocalPlayer.Name)
				LblWorld.Text = string.format("🌍 World : Sea %d  •  ⭐ Lv. %d/%d", KX.worldNum, KX.level, KX.maxLevel)
				LblFruit.Text = "🍎 Fruit : " .. (KX.devilFruit ~= "None" and KX.devilFruit or "None")
				LblAwaken.Text = "✨ Awaken : " .. (KX.awakenedText ~= "-" and KX.awakenedText or "-")

				local rem2x = KX.getRemaining2xExpSeconds()
				if rem2x > 0 then
					LblExp2x.Text = string.format("🚀 2x EXP : %dm %02ds", math.floor(rem2x / 60), rem2x % 60)
					LblExp2x.TextColor3 = THEME.GreenOk
				else
					LblExp2x.Text = "🚀 2x EXP : Inactive"
					LblExp2x.TextColor3 = THEME.TextSecondary
				end

				LblFarmStatus.Text = "📡 Status : " .. tostring(KX.statusText)
				LblFarmPhase.Text = "🧭 Phase : " .. tostring(KX.phaseText)
				LblRaidInfo.Text = string.format(
					"⚡ Raid [%s] : %s",
					tostring(KX.getPreferredRaidChipName()),
					tostring(KX.lastRaidStatus or "Standby")
				)

				-- Update Active Real-Time Melee + EXP Card
				if KX.currentMeleeCanon ~= "None" then
					LblActiveMeleeTitle.Text = string.format(
						"⚡ En uso: %s %s  •  🔥 Mas. %d",
						tostring(KX.currentMeleeIcon or "🥊"),
						tostring(KX.currentMeleeCanon),
						KX.currentMeleeLevel or 0
					)
					if (KX.currentMeleeLevel or 0) >= 600 then
						LblActiveMeleeExp.Text = "✨ EXP: MAX (600 / 600) • 100%"
						ExpBarFill.Size = UDim2.new(1, 0, 1, 0)
					else
						local curE = KX.currentMeleeExp or 0
						local maxE = math.max(1, KX.currentMeleeMaxExp or 1)
						local pct = math.clamp(KX.currentMeleePct or 0, 0, 100)
						LblActiveMeleeExp.Text = string.format(
							"✨ EXP: %s / %s  (%.1f%%)",
							formatCommas(curE),
							formatCommas(maxE),
							pct
						)
						ExpBarFill.Size = UDim2.new(pct / 100, 0, 1, 0)
					end
				else
					LblActiveMeleeTitle.Text = "⚡ En uso: Sin Melé detectada"
					LblActiveMeleeExp.Text = "✨ EXP: - / -"
					ExpBarFill.Size = UDim2.new(0, 0, 1, 0)
				end

				for qKey, setter in pairs(QuestRows) do
					setter(KX.questsDone[qKey] == true)
				end

				for mName, setter in pairs(MeleeRows) do
					local isAct = (KX.currentMeleeCanon == mName)
					local owned = (KX.ownedMelees[mName] == true) or isAct
					local mast = KX.meleeMastery[mName] or 0
					local expVal = KX.meleeExp[mName]
					local maxExp = KX.meleeMaxExp[mName]
					local suffix = ""
					if isAct then
						if mast >= 600 then
							suffix = " ⚡ [Lv.600 MAX]"
						else
							suffix = string.format(
								" ⚡ [Lv.%d | %s EXP %.0f%%]",
								mast,
								formatCompact(KX.currentMeleeExp or 0),
								KX.currentMeleePct or 0
							)
						end
					elseif mast > 0 then
						if mast >= 600 then
							suffix = " [Lv.600 MAX]"
						elseif expVal and maxExp and maxExp > 0 then
							local p = math.clamp((expVal / maxExp) * 100, 0, 100)
							suffix = string.format(" [Lv.%d | %s EXP %.0f%%]", mast, formatCompact(expVal), p)
						else
							suffix = " [Lv." .. tostring(mast) .. "]"
						end
					end
					setter(owned, suffix, isAct)
				end

				for sName, setter in pairs(SwordRows) do
					local sm = KX.swordMastery[sName] or 0
					local sfx = (sm > 0) and (" [Mas. " .. tostring(sm) .. "]") or ""
					setter(KX.ownedSwords[sName] == true, sfx, false)
				end

				for gName, setter in pairs(GunRows) do
					local gm = KX.gunMastery[gName] or 0
					local gfx = (gm > 0) and (" [Mas. " .. tostring(gm) .. "]") or ""
					setter(KX.ownedGuns[gName] == true, gfx, false)
				end

				LblBone.Text = "🦴 Bone : " .. tostring(KX.materials["Bones"] or 0)
				LblEcto.Text = "👻 Ectoplasm : " .. tostring(KX.materials["Ectoplasm"] or 0)
				LblElite.Text = "🎯 Elite Hunter : " .. tostring(KX.eliteProgress or 0) .. "/30"
				LblDarkFrag.Text = "🌑 Dark Fragment : " .. tostring(KX.materials["Dark Fragment"] or 0)
				LblCocoa.Text = "🍫 Conjured Cocoa : " .. tostring(KX.materials["Conjured Cocoa"] or 0)
				LblAlucard.Text = "🩸 Alucard Frag : " .. tostring(KX.materials["Alucard Fragment"] or 0) .. "/6"
				LblValkyrie.Text = "🪖 Valkyrie Helm : " .. (KX.ownedAccessories["Valkyrie Helm"] and "✅ Yes" or "No")
				LblCurrency.Text = string.format("💰 Beli : %s  |  💎 Frag : %s", formatCompact(KX.beli), formatCompact(KX.fragments))
			end)
			task.wait(0.35)
		end
	end)
end

--------------------------------------------------------------------------------
-- 10. PHYSICS, ANTI-AFK, WATER SAFETY & MASTER KAITUN RUNTIME LOOPS
--------------------------------------------------------------------------------
connect(LocalPlayer.Idled, function()
	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.zero)
	end)
end)

connect(LocalPlayer.CharacterAdded, function()
	KX.spawnedAtClock = os.clock()
	task.wait(0.8)
	if isAlive() then
		KX.ensureModulesReady(false)
	end
end)

connect(RunService.Stepped, function()
	if not isAlive() then return end
	local ch = LocalPlayer.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")

	-- NoClip, Hit Animation Suppression & Infinite Energy while Auto Farm is active
	if KX.autoFarm and ch then
		for _, p in ipairs(ch:GetDescendants()) do
			if p:IsA("BasePart") and p.CanCollide then
				p.CanCollide = false
			end
		end
		local en = ch:FindFirstChild("Energy")
		if en and en:IsA("ValueBase") and tonumber(en.MaxValue) then
			en.Value = en.MaxValue
		end
		if KX.noAttackAnimation and hum then
			KX.suppressHitAnimations(hum)
		end
	end

	-- Walk on Water safety on foot while farming (never interferes with boats!)
	local map = Workspace:FindFirstChild("Map")
	local wb = map and map:FindFirstChild("WaterBase-Plane")
	if wb and wb:IsA("BasePart") then
		if KX.autoFarm and hum and hum.SeatPart == nil then
			wb.Size = Vector3.new(wb.Size.X, 112, wb.Size.Z)
		else
			wb.Size = Vector3.new(wb.Size.X, 80, wb.Size.Z)
		end
	end
end)

-- Live Inventory & Quest Scanner Loop
task.spawn(function()
	while isAlive() do
		pcall(function() KX.scanPlayerState(false) end)
		task.wait(2.5)
	end
end)

-- Dedicated Moderate Fast-Click Combat Loop (~10.5 clicks/sec, smooth & safe)
task.spawn(function()
	while isAlive() do
		if KX.autoFarm and KX.lastAimEnemy then
			pcall(function()
				local enemy = KX.lastAimEnemy
				if enemy and KX.isModelAlive(enemy) then
					local hrp, hum = KX.getRootAndHum()
					local ePart = KX.getModelRoot(enemy)
					if hrp and hum and ePart then
						local hoverPos = ePart.Position + Vector3.new(0, 19, 0)
						if (hrp.Position - hoverPos).Magnitude <= 26 then
							KX.ensureAntiFall(hrp)
							hrp.CFrame = CFrame.lookAt(hoverPos, ePart.Position)
							local ch = LocalPlayer.Character
							local tool = (ch and ch:FindFirstChildOfClass("Tool")) or KX.lastCombatTool
							KX.fireWeaponClick(tool, enemy, ePart)
						end
					end
				else
					KX.lastAimEnemy = nil
					KX.lastAimPart = nil
				end
			end)
			task.wait(math.clamp(tonumber(KX.attackInterval) or 0.095, 0.08, 0.20))
		else
			task.wait(0.18)
		end
	end
end)

-- Master Kaitun 1-Click Engine Loop
task.spawn(function()
	if not isChooseTeamScreenOpen() and LocalPlayer.Character then
		task.wait(0.6)
		KX.ensureModulesReady(false)
		pcall(function() KX.scanPlayerState(true) end)
	end
	while isAlive() do
		if KX.autoFarm then
			local okStep, errStep = pcall(KX.stepMasterKaitun)
			if not okStep then
				warn("[SwitchHub Kaitun Step Error]", errStep)
			end
			task.wait(0.22)
		else
			task.wait(0.45)
		end
	end
end)

-- Auto-Requeue on Sea Travel / Server Hop so 1-Click Kaitun continues seamlessly across servers!
connect(LocalPlayer.OnTeleport, function()
	if not isAlive() or KX.teleportQueued then return end
	KX.teleportQueued = true
	saveConfig()
	pcall(function()
		local qfn = queue_on_teleport or queueteleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
		if typeof(qfn) == "function" then
			qfn('loadstring(game:HttpGet("https://raw.githubusercontent.com/jakrjone123/swith-hub-test/refs/heads/main/SwitchHubKaitun.lua"))()')
		end
	end)
end)

pcall(function()
	if typeof(writefile) == "function" then
		writefile("mcp/switch_hub_kaitun_loaded", tostring(os.time()))
	end
end)
