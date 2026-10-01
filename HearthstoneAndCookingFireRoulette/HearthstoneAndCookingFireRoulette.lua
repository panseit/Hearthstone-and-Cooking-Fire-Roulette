local addonName, ns = ...
local L = ns.L

-- Cooking fire toys by item ID. New entries are enabled by default.
local FIRE_TOYS = {
	163211, -- Akunda's Firesticks
	34686,  -- Brazier of Dancing Flames
	203757, -- Brazier of Madness
	116435, -- Cozy Bonfire
	153039, -- Crystalline Campfire
	104309, -- Eternal Kiln
	184404, -- Ever-Abundant Hearth
	127652, -- Felflame Campfire
	67097,  -- Grim Campfire
	128536, -- Leylight Brazier
	70722,  -- Little Wickerman
	198402, -- Maruuk Cooking Pot
	182780, -- Muckpool Cookpot
	116757, -- Steamworks Sausage Grill
	219403, -- Stonebound Lantern
	199892, -- Tuskarr Traveling Soup Pot
}

-- Hearthstone toys by item ID. All of them return you to your home inn and share the Hearthstone's cooldown.
-- New entries are enabled by default.
local HEARTHSTONE_TOYS = {
	166747, -- Brewfest Reveler's Hearthstone
	190237, -- Broker Translocation Matrix
	265100, -- Corewarden's Hearthstone
	246565, -- Cosmic Hearthstone
	93672,  -- Dark Portal
	208704, -- Deepdweller's Earthen Hearthstone
	188952, -- Dominated Hearthstone
	210455, -- Draenic Hologem
	190196, -- Enlightened Hearthstone
	172179, -- Eternal Traveler's Hearthstone
	54452,  -- Ethereal Portal
	236687, -- Explosive Hearthstone
	166746, -- Fire Eater's Hearthstone
	162973, -- Greatfather Winter's Hearthstone
	163045, -- Headless Horseman's Hearthstone
	209035, -- Hearthstone of the Flame
	168907, -- Holographic Digitalization Hearthstone
	184353, -- Kyrian Hearthstone
	257736, -- Lightcalled Hearthstone
	165669, -- Lunar Elder's Hearthstone
	264367, -- Mycomancer's Hearthspore
	263489, -- Naaru's Enfold
	182773, -- Necrolord Hearthstone
	180290, -- Night Fae Hearthstone
	165802, -- Noble Gardener's Hearthstone
	228940, -- Notorious Thread's Hearthstone
	200630, -- Ohn'ir Windsage's Hearthstone
	245970, -- P.O.S.T. Master's Express Hearthstone
	206195, -- Path of the Naaru
	165670, -- Peddlefeet's Lovely Hearthstone
	263933, -- Preyseeker's Hearthstone
	235016, -- Redeployment Module
	212337, -- Stone of the Hearth
	64488,  -- The Innkeeper's Daughter
	193588, -- Timewalker's Hearthstone
	142542, -- Tome of Town Portal
	183716, -- Venthyr Sinstone
}

-- Covenant hearthstones work for members of their covenant, and for every character once the account has reached
-- Renown 80 with that covenant (its account-wide "Renowned" achievement).
local COVENANT_HEARTHSTONES = {
	[184353] = { covenant = 1, renowned = 15242 }, -- Kyrian Hearthstone
	[183716] = { covenant = 2, renowned = 15245 }, -- Venthyr Sinstone
	[180290] = { covenant = 3, renowned = 15244 }, -- Night Fae Hearthstone
	[182773] = { covenant = 4, renowned = 15243 }, -- Necrolord Hearthstone
}
-- Hearthstones limited to some races, by the race's file name from UnitRace.
local RACE_HEARTHSTONES = {
	[210455] = { races = { Draenei = true, LightforgedDraenei = true }, note = L.DRAENEI_ONLY }, -- Draenic Hologem
}

local COOKING_FIRE_SPELL = 818
local COOKING_FIRE_ICON = 135805
local HEARTHSTONE_ITEM = 6948
local QUESTION_MARK_ICON = 134400 -- the "?" icon, which here means "show the next pick"
local NEXT_PICK = "next" -- the "?" choice in the icon grid
local LOGO_TEXTURE = "Interface\\AddOns\\" .. addonName .. "\\media\\logo"
local MAX_MACRO_NAME = 16 -- characters; the game's own macro window allows no more
local FALLBACK = "spell" -- marks the Cooking Fire spell as the current pick
-- Fires that show a targeting circle and go where you click (their spell's DEST_LOCATION target flag).
local CLICK_TO_PLACE = {
	[FALLBACK] = true, -- Cooking Fire
	[163211] = true, -- Akunda's Firesticks
	[203757] = true, -- Brazier of Madness
	[184404] = true, -- Ever-Abundant Hearth
	[128536] = true, -- Leylight Brazier
	[182780] = true, -- Muckpool Cookpot
	[219403] = true, -- Stonebound Lantern
	[199892] = true, -- Tuskarr Traveling Soup Pot
}
local MIN_REAL_COOLDOWN = 2 -- toys trigger the global cooldown, which isn't a real toy cooldown
local REROLL_DELAY = 1 -- give the game time to apply the new cooldown before picking the next one
local SETTLE_DELAY = 2 -- seconds after a loading screen before bags, spells and toys can be trusted
-- When nothing at all looks usable, look again every RECHECK_DELAY seconds, up to RECHECK_TRIES times, before
-- believing it: during and after loading screens the game can report no toys, spells or items for a while.
local RECHECK_DELAY, RECHECK_TRIES = 5, 6
-- A pending update or a loading-screen pause normally ends within seconds. One older than this lost its timer,
-- so the next update request clears it instead of waiting forever.
local STUCK_AFTER = 10
local ITEM_LOAD_TIMEOUT = 5 -- seconds to wait for every item's data before starting with the ones that arrived
local ROW_HEIGHT = 26
local ICON_SIZE, ICON_GAP = 32, 4
-- Stops for the two gradient words of the addon's name, the same as in the .toc title.
local HEARTHSTONE_GRADIENT = {
	{ 0, 0xFF, 0xFF, 0xFF },
	{ 1, 0x3F, 0xA9, 0xFF },
}
local FIRE_GRADIENT = {
	{ 0, 0xFF, 0x2B, 0x1C },
	{ 1, 0xA0, 0x52, 0x2D },
}

-- Prefer the namespaced APIs and fall back to the older globals.
local GetItemCooldown = (C_Container and C_Container.GetItemCooldown) or (C_Item and C_Item.GetItemCooldown) or GetItemCooldown
local GetItemSpell = (C_Item and C_Item.GetItemSpell) or GetItemSpell
local GetItemCount = (C_Item and C_Item.GetItemCount) or GetItemCount

local itemInfo = {} -- [itemID] = { name = , icon = }
local itemModes = {} -- [itemID] = the macro it belongs to, for every item the game knows
local itemsWanted, itemsHave = 0, 0
local itemsLoaded = false -- true once every item arrived or ITEM_LOAD_TIMEOUT passed
-- False until SETTLE_DELAY after each loading screen, when the game can still report empty bags, no spells and no
-- toys. Every pause ends on its own timer; settleCount tells the latest timer from older ones.
local worldReady, settleCount = false, 0
local pausedAt -- GetTime() when the latest pause began
local lastCast -- the player's latest cast, for /hcfr status: { at =, spellID = or hidden = true, mode = }
local RequestUpdate

local eventFrame = CreateFrame("Frame")

-- The two macros. Besides the fields below, each gets its saved settings (db) on load, and keeps:
--   current          the itemID or FALLBACK the macro uses now
--   lastUsed         the itemID or FALLBACK most recently used or interrupted mid-cast
--   nothingChecks    how many times in a row nothing at all looked usable
--   queuedAt         GetTime() when the pending update was queued
--   updatedAt        GetTime() of the latest macro update, for /hcfr status
--   warnedNone, warnedMacrosFull, cooldownTimer, updateQueued, forceQueued
local fires = {
	dbKey = "fires",
	defaultMacroName = L.DEFAULT_FIRE_MACRO_NAME,
	tabName = L.TAB_FIRES,
	listHeader = L.TOYS_HEADER,
	nextTitle = L.NEXT_FIRE,
	nextTooltip = L.NEXT_FIRE_TOOLTIP,
	keys = { FALLBACK }, -- the Cooking Fire spell, then the toys
	iconsPerRow = 9,
	spellToKey = { [COOKING_FIRE_SPELL] = FALLBACK },
}
local hearthstones = {
	dbKey = "hearthstones",
	defaultMacroName = L.DEFAULT_HEARTH_MACRO_NAME,
	tabName = L.TAB_HEARTHSTONES,
	listHeader = L.HEARTHSTONES_HEADER,
	nextTitle = L.NEXT_HEARTHSTONE,
	nextTooltip = L.NEXT_HEARTHSTONE_TOOLTIP,
	keys = { HEARTHSTONE_ITEM }, -- the Hearthstone item, then the toys
	iconsPerRow = 14,
	spellToKey = {},
}
for _, itemID in ipairs(FIRE_TOYS) do
	fires.keys[#fires.keys + 1] = itemID
end
for _, itemID in ipairs(HEARTHSTONE_TOYS) do
	hearthstones.keys[#hearthstones.keys + 1] = itemID
end
local MODES = { fires, hearthstones } -- also the order of the options tabs

------------------------------------------------------------------------------------------------------------------------
-- Name and chat
------------------------------------------------------------------------------------------------------------------------
-- Colors each letter along the gradient stops; spaces stay uncolored.
local function GradientText(text, stops)
	local chars, letters = {}, 0
	for ch in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
		chars[#chars + 1] = ch
		if ch ~= " " then
			letters = letters + 1
		end
	end

	local out, n = {}, 0
	for _, ch in ipairs(chars) do
		if ch == " " then
			out[#out + 1] = ch
		else
			local t = letters > 1 and n / (letters - 1) or 0
			n = n + 1
			for i = 2, #stops do
				local a, b = stops[i - 1], stops[i]
				if t <= b[1] then
					local f = (t - a[1]) / (b[1] - a[1])
					local function mix(c)
						return math.floor(a[c] + (b[c] - a[c]) * f + 0.5)
					end
					out[#out + 1] = ("|cff%02x%02x%02x%s"):format(mix(2), mix(3), mix(4), ch)
					break
				end
			end
		end
	end
	return table.concat(out) .. "|r"
end

-- "Hearthstone" white to blue, "Cooking Fire" red to brown, "and" and "Roulette" in the game's usual gold.
local COLORED_NAME = GradientText(L.NAME_HEARTHSTONE, HEARTHSTONE_GRADIENT)
	.. NORMAL_FONT_COLOR:WrapTextInColorCode(L.NAME_AND)
	.. GradientText(L.NAME_COOKING_FIRE, FIRE_GRADIENT)
	.. NORMAL_FONT_COLOR:WrapTextInColorCode(L.NAME_ROULETTE)
local CHAT_PREFIX = COLORED_NAME .. ": "

local function Print(msg)
	print(CHAT_PREFIX .. msg)
end

local function ItemName(itemID)
	return itemInfo[itemID] and itemInfo[itemID].name or ("item:" .. itemID)
end

local function CooldownLeft(itemID)
	local start, duration = GetItemCooldown(itemID)
	if start and duration and start > 0 and duration > MIN_REAL_COOLDOWN then
		return math.max(start + duration - GetTime(), 0)
	end
	return 0
end

-- Never picks the one that was just used when there's another option.
local function PickRandom(mode, list)
	if #list > 1 then
		for i, key in ipairs(list) do
			if key == mode.lastUsed then
				table.remove(list, i)
				break
			end
		end
	end
	return list[math.random(#list)]
end

------------------------------------------------------------------------------------------------------------------------
-- Picking a fire
------------------------------------------------------------------------------------------------------------------------
local function KnowsCookingFire()
	if IsPlayerSpell then
		return IsPlayerSpell(COOKING_FIRE_SPELL)
	end
	return C_SpellBook.IsSpellKnown(COOKING_FIRE_SPELL)
end

local function CookingFireName()
	local name
	if C_Spell and C_Spell.GetSpellName then
		name = C_Spell.GetSpellName(COOKING_FIRE_SPELL)
	else
		name = GetSpellInfo(COOKING_FIRE_SPELL)
	end
	return name or L.COOKING_FIRE
end

-- Returns the next pick (itemID or FALLBACK); when every toy is on cooldown, the seconds until one is ready; and when
-- no toy is collected, the warning to show.
function fires:Choose(forceNew)
	local db = self.db
	local collected, ready = {}, {}
	local soonest
	for _, itemID in ipairs(FIRE_TOYS) do
		if itemInfo[itemID] and not db.disabled[itemID] and PlayerHasToy(itemID) then
			collected[#collected + 1] = itemID
			local left = CooldownLeft(itemID)
			if left == 0 then
				ready[#ready + 1] = itemID
			elseif not soonest or left < soonest then
				soonest = left
			end
		end
	end

	-- Many fire toys share a cooldown, so this is common right after placing one.
	local wait = #ready == 0 and soonest or nil
	local knowsSpell = KnowsCookingFire()
	if knowsSpell and not db.disabled[FALLBACK] then
		ready[#ready + 1] = FALLBACK -- the spell has no cooldown
	end

	if #ready > 0 then
		if not forceNew and tContains(ready, self.current) then
			return self.current, wait
		end
		return PickRandom(self, ready), wait
	end

	if #collected == 0 then
		return FALLBACK, nil, L.NO_TOYS
	end

	-- Every toy is on cooldown and the spell isn't in the rotation: fall back to it anyway if known.
	if knowsSpell then
		return FALLBACK, wait
	end
	if not forceNew and tContains(collected, self.current) then
		return self.current, wait
	end
	return PickRandom(self, collected), wait
end

function fires:Macro(choice)
	if choice == FALLBACK then
		return COOKING_FIRE_ICON, "#showtooltip\n/cast " .. CookingFireName()
	end
	return itemInfo[choice].icon, "#showtooltip\n/use " .. itemInfo[choice].name
end

function fires:RowName(key)
	if key == FALLBACK then
		return CookingFireName()
	end
	return ItemName(key)
end

-- Whether the row's fire can be placed, and the notes shown after its name.
function fires:RowStatus(key)
	local notes = {}
	local usable
	if key == FALLBACK then
		notes[#notes + 1] = L.SPELL
		usable = KnowsCookingFire()
	else
		usable = PlayerHasToy(key)
	end
	if CLICK_TO_PLACE[key] then
		notes[#notes + 1] = L.CLICK_TO_PLACE
	end
	if not usable then
		notes[#notes + 1] = key == FALLBACK and L.NOT_LEARNED or L.NOT_COLLECTED
	end
	return usable, notes
end

------------------------------------------------------------------------------------------------------------------------
-- Picking a hearthstone
------------------------------------------------------------------------------------------------------------------------
-- Whether this character meets a hearthstone's covenant or race limit, if it has one.
local function MeetsLimit(itemID)
	local covenant = COVENANT_HEARTHSTONES[itemID]
	if covenant then
		if C_Covenants.GetActiveCovenantID() == covenant.covenant then
			return true
		end
		local _, _, _, completed = GetAchievementInfo(covenant.renowned)
		return completed == true
	end
	local limit = RACE_HEARTHSTONES[itemID]
	if limit then
		local _, race = UnitRace("player")
		return limit.races[race] == true
	end
	return true
end

-- The note explaining a hearthstone's covenant or race limit, e.g. "Night Fae or Renown 80 only".
local function LimitNote(itemID)
	local covenant = COVENANT_HEARTHSTONES[itemID]
	if covenant then
		local data = C_Covenants.GetCovenantData(covenant.covenant)
		return L.COVENANT_ONLY:format(data and data.name or L.COVENANT)
	end
	local limit = RACE_HEARTHSTONES[itemID]
	return limit and limit.note
end

-- The Hearthstone item counts while it's in your bags; a toy once it's collected and your character meets its limit.
local function CanUseHearthstone(itemID)
	if itemID == HEARTHSTONE_ITEM then
		return GetItemCount(HEARTHSTONE_ITEM) > 0
	end
	return PlayerHasToy(itemID) and MeetsLimit(itemID)
end

-- Returns the next pick (an itemID), plus the warning to show when none is usable (the second value is always nil,
-- matching fires:Choose). Every hearthstone shares one cooldown, so unlike the fires there's no other one to switch
-- to while it runs: the pick just changes after each use.
function hearthstones:Choose(forceNew)
	local usable = {}
	for _, itemID in ipairs(self.keys) do
		if itemInfo[itemID] and not self.db.disabled[itemID] and CanUseHearthstone(itemID) then
			usable[#usable + 1] = itemID
		end
	end

	if #usable == 0 then
		return HEARTHSTONE_ITEM, nil, L.NO_HEARTHSTONES
	end

	if not forceNew and tContains(usable, self.current) then
		return self.current
	end
	return PickRandom(self, usable)
end

function hearthstones:Macro(choice)
	local info = itemInfo[choice]
	if not info then
		-- The game never sent this item's data (only possible for the Hearthstone fallback); its ID works as well.
		return C_Item.GetItemIconByID(choice) or QUESTION_MARK_ICON, "#showtooltip\n/use item:" .. choice
	end
	return info.icon, "#showtooltip\n/use " .. info.name
end

function hearthstones:RowName(key)
	return ItemName(key)
end

-- Whether the row's hearthstone can be used, and the notes shown after its name.
function hearthstones:RowStatus(key)
	local notes = {}
	if key == HEARTHSTONE_ITEM then
		notes[#notes + 1] = L.ITEM
		if GetItemCount(HEARTHSTONE_ITEM) == 0 then
			notes[#notes + 1] = L.NOT_IN_BAGS
		end
	else
		if not PlayerHasToy(key) then
			notes[#notes + 1] = L.NOT_COLLECTED
		end
		-- Only worth a note when it's the reason the hearthstone can't be used.
		if not MeetsLimit(key) then
			notes[#notes + 1] = LimitNote(key)
		end
	end
	return CanUseHearthstone(key), notes
end

------------------------------------------------------------------------------------------------------------------------
-- Macros
------------------------------------------------------------------------------------------------------------------------
local function WriteMacro(mode, icon, body)
	local name = mode.db.macroName
	local index = GetMacroIndexByName(name)
	if index == 0 then
		if GetNumMacros() >= (MAX_ACCOUNT_MACROS or 120) then
			if not mode.warnedMacrosFull then
				mode.warnedMacrosFull = true
				Print(L.MACROS_FULL:format(name))
			end
			return
		end
		CreateMacro(name, icon, body)
		Print(L.MACRO_CREATED:format(name))
		return
	end

	local _, currentIcon, currentBody = GetMacroInfo(index)
	if currentIcon ~= icon or currentBody ~= body then
		EditMacro(index, nil, icon, body)
	end
end

local function UpdateMacro(mode, forceNew)
	if mode.cooldownTimer then
		mode.cooldownTimer:Cancel()
		mode.cooldownTimer = nil
	end

	local choice, wait, nothingWarning = mode:Choose(forceNew)
	if nothingWarning then
		-- Leave the macro alone and look again later, rather than switch to the fallback on a bad reading.
		mode.nothingChecks = (mode.nothingChecks or 0) + 1
		if mode.nothingChecks <= RECHECK_TRIES then
			C_Timer.After(RECHECK_DELAY, function()
				RequestUpdate(mode, forceNew)
			end)
			return
		end
		if not mode.warnedNone then
			mode.warnedNone = true
			Print(nothingWarning)
		end
	else
		mode.nothingChecks = 0
	end
	mode.current = choice
	if wait then
		-- Toys are back once this fires, so pick again rather than keep a pick made for lack of them.
		mode.cooldownTimer = C_Timer.NewTimer(wait + 0.5, function()
			mode.cooldownTimer = nil
			RequestUpdate(mode, true)
		end)
	end

	-- The tooltip always names the next pick; only the icon can be fixed.
	local icon, body = mode:Macro(choice)
	WriteMacro(mode, mode.db.macroIcon or icon, body)
	mode.updatedAt = GetTime()
end

-- Batches update requests and waits until out of combat, since macros can't be edited in combat.
function RequestUpdate(mode, forceNew)
	if forceNew then
		mode.forceQueued = true
	end
	-- Safety net: never stay blocked by a pending update or a pause whose timer was lost.
	local now = GetTime()
	if mode.updateQueued and now - mode.queuedAt > STUCK_AFTER then
		mode.updateQueued = false
	end
	if not worldReady and pausedAt and now - pausedAt > STUCK_AFTER then
		worldReady = true
	end
	if mode.updateQueued or not (itemsLoaded and worldReady) then
		return
	end
	mode.updateQueued = true
	mode.queuedAt = now
	C_Timer.After(0.2, function()
		mode.updateQueued = false
		if not worldReady then
			return -- a loading screen began; the update runs after it, and forceQueued keeps a pending reroll
		end
		if InCombatLockdown() then
			eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
			return
		end
		local force = mode.forceQueued
		mode.forceQueued = false
		UpdateMacro(mode, force)
	end)
end

local function RequestAllUpdates()
	for _, mode in ipairs(MODES) do
		RequestUpdate(mode)
	end
end

------------------------------------------------------------------------------------------------------------------------
-- Item data
------------------------------------------------------------------------------------------------------------------------
-- When an item arrives, it joins its macro's choices; once all have arrived (or ITEM_LOAD_TIMEOUT passed), the
-- macros start updating.
local function ItemArrived(mode, key, item)
	if itemInfo[key] then
		return -- a retry and the first request can both come back
	end
	itemInfo[key] = { name = item:GetItemName(), icon = item:GetItemIcon() }
	local _, spellID = GetItemSpell(key)
	if spellID then
		mode.spellToKey[spellID] = key
	end
	itemsHave = itemsHave + 1
	if itemsLoaded then
		RequestUpdate(mode)
	elseif itemsHave == itemsWanted then
		itemsLoaded = true
		RequestAllUpdates()
	end
end

local function RequestItem(mode, key)
	local item = Item:CreateFromItemID(key)
	item:ContinueOnItemLoad(function()
		ItemArrived(mode, key, item)
	end)
end

-- The game silently drops the request for an item it fails to load, so ask again for any still missing.
local function RequestMissingItems()
	for key, mode in pairs(itemModes) do
		if not itemInfo[key] then
			RequestItem(mode, key)
		end
	end
end

local function LoadItems()
	-- Count them all first, so items that are already cached and arrive at once can't finish the count early.
	for _, mode in ipairs(MODES) do
		for _, key in ipairs(mode.keys) do
			-- Every key but the Cooking Fire spell is an item.
			if key ~= FALLBACK and (not C_Item.DoesItemExistByID or C_Item.DoesItemExistByID(key)) then
				itemModes[key] = mode
				itemsWanted = itemsWanted + 1
			end
		end
	end
	for key, mode in pairs(itemModes) do
		RequestItem(mode, key)
	end

	-- Don't let one item that never arrives keep both macros waiting: start with the ones that did.
	C_Timer.After(ITEM_LOAD_TIMEOUT, function()
		if not itemsLoaded then
			itemsLoaded = true
			RequestMissingItems()
			RequestAllUpdates()
		end
	end)
end

------------------------------------------------------------------------------------------------------------------------
-- Options panel
------------------------------------------------------------------------------------------------------------------------
-- Counts characters, not bytes, so accented and non-Latin names get the full limit.
local function IsTooLong(name)
	return (strlenutf8 and strlenutf8(name) or #name) > MAX_MACRO_NAME
end

-- One tab: the macro's name, its icon and the list of what it can pick. Returns the page and its refresh function.
local function CreatePage(mode, parent)
	local db = mode.db
	local page = CreateFrame("Frame", nil, parent)

	-- Macro name
	local nameLabel = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	nameLabel:SetPoint("TOPLEFT")
	nameLabel:SetText(L.MACRO_NAME)

	local nameBox = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
	nameBox:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 6, -6)
	nameBox:SetSize(200, 20)
	nameBox:SetAutoFocus(false)

	local nameError = page:CreateFontString(nil, "ARTWORK", "GameFontRed")
	nameError:SetPoint("LEFT", nameBox, "RIGHT", 12, 0)
	nameError:Hide()

	local function ShowNameError(text)
		nameError:SetText(text)
		nameError:Show()
		return false
	end

	local function ApplyMacroName()
		local name = strtrim(nameBox:GetText())
		if name == "" or name == db.macroName then
			nameBox:SetText(db.macroName)
			nameError:Hide()
			return true
		end
		if IsTooLong(name) then
			return ShowNameError(L.NAME_TOO_LONG:format(MAX_MACRO_NAME))
		end
		if InCombatLockdown() then
			return ShowNameError(L.NAME_IN_COMBAT)
		end
		local ours = GetMacroIndexByName(db.macroName)
		local existing = GetMacroIndexByName(name)
		if existing ~= 0 and existing ~= ours then
			return ShowNameError(L.NAME_TAKEN)
		end
		-- The other tab's macro may not exist yet, so compare with its saved name too.
		for _, other in ipairs(MODES) do
			if other ~= mode and other.db.macroName == name then
				return ShowNameError(L.NAME_TAKEN)
			end
		end

		db.macroName = name
		if ours ~= 0 then
			EditMacro(ours, name)
			Print(L.MACRO_RENAMED:format(name))
		else
			RequestUpdate(mode)
		end
		nameError:Hide()
		return true
	end

	nameBox:SetScript("OnEnterPressed", function(self)
		if ApplyMacroName() then
			self:ClearFocus()
		end
	end)
	nameBox:SetScript("OnEscapePressed", function(self)
		self:SetText(db.macroName)
		nameError:Hide()
		self:ClearFocus()
	end)
	nameBox:SetScript("OnEditFocusLost", ApplyMacroName)
	nameBox:SetScript("OnTextChanged", function(self, userInput)
		if not userInput then
			return
		end
		if IsTooLong(strtrim(self:GetText())) then
			ShowNameError(L.NAME_TOO_LONG:format(MAX_MACRO_NAME))
		else
			nameError:Hide()
		end
	end)

	-- Macro icon: "?" shows the next pick's icon, the rest are this tab's choices.
	local iconLabel = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	iconLabel:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", -6, -20)
	iconLabel:SetText(L.MACRO_ICON)

	local iconChoices = {
		{ key = NEXT_PICK, icon = QUESTION_MARK_ICON },
	}
	for _, key in ipairs(mode.keys) do
		local icon = key == FALLBACK and COOKING_FIRE_ICON or C_Item.GetItemIconByID(key)
		iconChoices[#iconChoices + 1] = { key = key, icon = icon }
	end

	local perRow = mode.iconsPerRow
	local step = ICON_SIZE + ICON_GAP
	local iconGrid = CreateFrame("Frame", nil, page)
	iconGrid:SetPoint("TOPLEFT", iconLabel, "BOTTOMLEFT", 0, -6)
	iconGrid:SetSize(perRow * step - ICON_GAP, math.ceil(#iconChoices / perRow) * step - ICON_GAP)

	local function ShowIconTooltip(button)
		local key = button.choice.key
		GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
		if key == NEXT_PICK then
			GameTooltip:SetText(mode.nextTitle)
			GameTooltip:AddLine(mode.nextTooltip, 1, 1, 1, true)
		elseif key == FALLBACK then
			GameTooltip:SetSpellByID(COOKING_FIRE_SPELL)
		else
			GameTooltip:SetItemByID(key)
		end
		GameTooltip:Show()
	end

	local iconButtons = {}
	local function RefreshIcon()
		for _, button in ipairs(iconButtons) do
			local choice = button.choice
			if choice.key == NEXT_PICK then
				button.selected:SetShown(db.macroIcon == nil)
			else
				button.selected:SetShown(db.macroIcon == choice.icon)
			end
		end
	end

	for i, choice in ipairs(iconChoices) do
		local button = CreateFrame("Button", nil, iconGrid)
		button:SetSize(ICON_SIZE, ICON_SIZE)
		button:SetPoint("TOPLEFT", ((i - 1) % perRow) * step, -math.floor((i - 1) / perRow) * step)
		button.choice = choice
		button.texture = button:CreateTexture(nil, "ARTWORK")
		button.texture:SetAllPoints()
		button.texture:SetTexture(choice.icon)
		button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
		button.selected = button:CreateTexture(nil, "OVERLAY")
		button.selected:SetAllPoints()
		button.selected:SetTexture("Interface\\Buttons\\CheckButtonHilight")
		button.selected:SetBlendMode("ADD")
		button:SetScript("OnClick", function(self)
			if self.choice.key == NEXT_PICK then
				db.macroIcon = nil
			else
				db.macroIcon = self.choice.icon
			end
			RefreshIcon()
			RequestUpdate(mode)
		end)
		button:SetScript("OnEnter", ShowIconTooltip)
		button:SetScript("OnLeave", GameTooltip_Hide)
		iconButtons[i] = button
	end

	-- What the macro can pick
	local listLabel = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	listLabel:SetPoint("TOPLEFT", iconGrid, "BOTTOMLEFT", 0, -20)
	listLabel:SetText(mode.listHeader)

	local selectAll = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
	selectAll:SetPoint("TOPLEFT", listLabel, "BOTTOMLEFT", 0, -8)
	selectAll:SetSize(120, 22)
	selectAll:SetText(L.SELECT_ALL)

	local deselectAll = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
	deselectAll:SetPoint("LEFT", selectAll, "RIGHT", 8, 0)
	deselectAll:SetSize(120, 22)
	deselectAll:SetText(L.DESELECT_ALL)

	local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", selectAll, "BOTTOMLEFT", 0, -8)
	scroll:SetPoint("BOTTOMRIGHT")

	-- One row per key: the spell or item on top, then the toys.
	local keys = mode.keys
	local list = CreateFrame("Frame", nil, scroll)
	list:SetSize(1, #keys * ROW_HEIGHT)
	scroll:SetScrollChild(list)
	scroll:SetScript("OnSizeChanged", function(_, width)
		list:SetWidth(width)
	end)

	local function SelectionChanged()
		mode.warnedNone = false
		-- The player just chose this, so if nothing is left, say so right away instead of looking again.
		mode.nothingChecks = RECHECK_TRIES
		RequestUpdate(mode)
	end

	local rows = {}
	for _, key in ipairs(keys) do
		local check = CreateFrame("CheckButton", nil, list, "UICheckButtonTemplate")
		check:SetSize(24, 24)
		check:SetHitRectInsets(0, -250, 0, 0) -- let the label toggle it too
		check.key = key
		check.label = check:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		check.label:SetPoint("LEFT", check, "RIGHT", 4, 0)
		check:SetScript("OnClick", function(self)
			db.disabled[self.key] = not self:GetChecked() or nil
			SelectionChanged()
		end)
		rows[#rows + 1] = check
	end

	local topKey = keys[1]
	local function Refresh()
		-- The spell or item stays on top; toys follow sorted by their localised name.
		table.sort(rows, function(a, b)
			if a.key == topKey then
				return b.key ~= topKey
			elseif b.key == topKey then
				return false
			end
			return mode:RowName(a.key) < mode:RowName(b.key)
		end)
		for i, check in ipairs(rows) do
			local key = check.key
			check:ClearAllPoints()
			check:SetPoint("TOPLEFT", 4, -(i - 1) * ROW_HEIGHT)
			check:SetChecked(not db.disabled[key])

			local usable, notes = mode:RowStatus(key)
			local text = mode:RowName(key)
			if #notes > 0 then
				text = text .. " " .. RED_FONT_COLOR:WrapTextInColorCode("(" .. table.concat(notes, ", ") .. ")")
			end
			check.label:SetText(text)
			check.label:SetTextColor((usable and HIGHLIGHT_FONT_COLOR or GRAY_FONT_COLOR):GetRGB())
		end
		nameBox:SetText(db.macroName)
		nameError:Hide()
		RefreshIcon()
	end

	selectAll:SetScript("OnClick", function()
		wipe(db.disabled)
		Refresh()
		SelectionChanged()
	end)
	deselectAll:SetScript("OnClick", function()
		for _, key in ipairs(keys) do
			db.disabled[key] = true
		end
		Refresh()
		SelectionChanged()
	end)

	return page, Refresh
end

local function CreateOptionsPanel()
	local panel = CreateFrame("Frame")
	-- The AddOns list sorts by the raw name, so keep the first letter uncolored to stay in alphabetical place.
	local listName = COLORED_NAME:gsub("^|cff%x%x%x%x%x%x", "", 1)
	local category = Settings.RegisterCanvasLayoutCategory(panel, listName)
	Settings.RegisterAddOnCategory(category)
	ns.category = category

	local logo = panel:CreateTexture(nil, "ARTWORK")
	logo:SetPoint("TOPLEFT", 16, -12)
	logo:SetSize(48, 48)
	logo:SetTexture(LOGO_TEXTURE)

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("LEFT", logo, "RIGHT", 10, 0)
	title:SetText(COLORED_NAME)

	-- Tabs over a bordered box, laid out like the tabs in the game's own Graphics settings.
	local box = CreateFrame("Frame", nil, panel)
	box:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 12, -24)
	box:SetPoint("BOTTOMRIGHT", -10, 32)

	local border = CreateFrame("Frame", nil, box, "NineSlicePanelTemplate")
	border:ClearAllPoints()
	border:SetPoint("TOPLEFT", -12, -14)
	border:SetPoint("BOTTOMRIGHT", -6, -16)
	NineSliceUtil.ApplyUniqueCornersLayout(border, "OptionsFrame")

	local tabs, pages, refreshers = {}, {}, {}
	for i, mode in ipairs(MODES) do
		local tab = CreateFrame("Button", nil, box, "MinimalTabTemplate")
		tab.Text:SetText(mode.tabName)
		tab:SetWidth(tab.Text:GetStringWidth() + 40)
		if i == 1 then
			tab:SetPoint("TOPLEFT", 18, 10)
		else
			tab:SetPoint("TOPLEFT", tabs[i - 1], "TOPRIGHT", 5, 0)
		end
		tabs[i] = tab

		local page, refresh = CreatePage(mode, box)
		page:SetPoint("TOPLEFT", 4, -35)
		page:SetPoint("BOTTOMRIGHT", -36, 4) -- leaves room for the list's scroll bar
		page:SetShown(i == 1)
		pages[i], refreshers[i] = page, refresh
	end

	local tabGroup = CreateRadioButtonGroup()
	tabGroup:AddButtons(tabs)
	tabGroup:SelectAtIndex(1)
	tabGroup:RegisterCallback(ButtonGroupBaseMixin.Event.Selected, function(_, _, index)
		for i, page in ipairs(pages) do
			page:SetShown(i == index)
		end
		PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
	end, panel)

	panel:SetScript("OnShow", function()
		for _, refresh in ipairs(refreshers) do
			refresh()
		end
	end)
end

------------------------------------------------------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------------------------------------------------------
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("LOADING_SCREEN_DISABLED")
eventFrame:RegisterEvent("TOYS_UPDATED")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
eventFrame:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		if ... ~= addonName then
			return
		end
		self:UnregisterEvent("ADDON_LOADED")
		HearthstoneAndCookingFireRouletteDB = HearthstoneAndCookingFireRouletteDB or {}
		local db = HearthstoneAndCookingFireRouletteDB
		for _, mode in ipairs(MODES) do
			db[mode.dbKey] = db[mode.dbKey] or {}
			mode.db = db[mode.dbKey]
			mode.db.macroName = mode.db.macroName or mode.defaultMacroName
			mode.db.disabled = mode.db.disabled or {}
		end
		CreateOptionsPanel()
		LoadItems()
	elseif event == "PLAYER_ENTERING_WORLD" or event == "LOADING_SCREEN_DISABLED" then
		-- After logging in, reloading or any loading screen (a hearthstone, a portal), give bags, spells and the toy
		-- collection a moment to arrive before trusting them. The pause always ends on this timer, whatever order
		-- the game sends these events in.
		worldReady = false
		pausedAt = GetTime()
		settleCount = settleCount + 1
		local settle = settleCount
		C_Timer.After(SETTLE_DELAY, function()
			if settle == settleCount then
				worldReady = true
				if itemsLoaded then
					RequestMissingItems()
				end
				RequestAllUpdates()
			end
		end)
	elseif event == "PLAYER_REGEN_ENABLED" then
		self:UnregisterEvent("PLAYER_REGEN_ENABLED")
		RequestAllUpdates()
	elseif event == "TOYS_UPDATED" then
		RequestAllUpdates()
	elseif event == "BAG_UPDATE_DELAYED" then
		-- The Hearthstone item may have entered or left your bags.
		RequestUpdate(hearthstones)
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
		local _, _, spellID = ...
		if issecretvalue and issecretvalue(spellID) then
			lastCast = { at = GetTime(), hidden = true }
			return
		end
		lastCast = { at = GetTime(), spellID = spellID }
		for _, mode in ipairs(MODES) do
			local key = mode.spellToKey[spellID]
			if key then
				lastCast.mode = mode
				mode.lastUsed = key
				if event == "UNIT_SPELLCAST_INTERRUPTED" then
					-- A stopped cast starts no cooldown, so there's nothing to wait for.
					RequestUpdate(mode, true)
				else
					C_Timer.After(REROLL_DELAY, function()
						RequestUpdate(mode, true)
					end)
				end
			end
		end
	end
end)

------------------------------------------------------------------------------------------------------------------------
-- Slash command
------------------------------------------------------------------------------------------------------------------------
-- "/hcfr status" prints what the addon is doing, to find out why the macros aren't changing.
local function PrintStatus()
	local now = GetTime()
	local function YesNo(value)
		return value and L.YES or L.NO
	end
	local function Ago(t)
		return t and L.SECONDS_AGO:format(now - t) or L.NEVER
	end

	local GetMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
	Print(L.STATUS_HEADER:format(GetMetadata and GetMetadata(addonName, "Version") or "?"))
	local missing = {}
	for key in pairs(itemModes) do
		if not itemInfo[key] then
			missing[#missing + 1] = key
		end
	end
	table.sort(missing)
	local items
	if #missing == 0 then
		items = L.STATUS_ITEMS_ALL:format(itemsWanted)
	elseif itemsLoaded then
		items = L.STATUS_ITEMS_MISSING:format(itemsHave, itemsWanted, table.concat(missing, ", "))
	else
		items = L.STATUS_ITEMS_WAITING:format(itemsHave, itemsWanted)
	end
	local ready = worldReady and L.YES or L.STATUS_PAUSED:format(pausedAt and now - pausedAt or 0)
	print(L.STATUS_GENERAL:format(items, ready, YesNo(InCombatLockdown())))
	for _, mode in ipairs(MODES) do
		local name = mode.db.macroName
		local pending = mode.updateQueued and L.STATUS_PENDING:format(now - mode.queuedAt) or L.NO
		print(L.STATUS_MACRO:format(name, YesNo(GetMacroIndexByName(name) ~= 0),
			mode.current and mode:RowName(mode.current) or L.NONE, pending, YesNo(mode.forceQueued), Ago(mode.updatedAt)))
	end
	if not lastCast then
		print(L.STATUS_CAST_NONE)
	elseif lastCast.hidden then
		print(L.STATUS_CAST_HIDDEN:format(Ago(lastCast.at)))
	else
		local whose = lastCast.mode and lastCast.mode.db.macroName or L.STATUS_NOT_OURS
		print(L.STATUS_CAST:format(lastCast.spellID, whose, Ago(lastCast.at)))
	end
end

SLASH_HEARTHSTONEANDCOOKINGFIREROULETTE1 = "/hcfr"
SlashCmdList.HEARTHSTONEANDCOOKINGFIREROULETTE = function(msg)
	if strtrim(msg or ""):lower() == "status" then
		PrintStatus()
		return
	end
	Settings.OpenToCategory(ns.category:GetID())
end
