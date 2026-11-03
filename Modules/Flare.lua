-- Flare: lights up action buttons for things you forgot - your own and your
-- party's class buffs (with the group version when two members lack it and the
-- reagent is in your bags), weapon enchants/poisons, low reagents, cooldowns
-- that come back in a fight, and spells on an old rank. Procs are covered by
-- the client's own overlay glow already. One glow style for everything, color
-- and duration configurable.
local _, ns = ...
local S = ns.S
local L = S.L
local FL = S:NewModule("Flare")

local ipairs, pairs, tinsert, sort = ipairs, pairs, table.insert, table.sort
local format = string.format
local InCombatLockdown = InCombatLockdown
local GetItemCount = C_Item and C_Item.GetItemCount or GetItemCount
local GetWeaponEnchantInfo = GetWeaponEnchantInfo
local CreateFrame, C_Timer = CreateFrame, C_Timer

local function SpellName(id)
	local n = S.GetSpellInfo and S.GetSpellInfo(id)
	if type(n) == "table" then n = n.name end
	return type(n) == "string" and n or nil
end

-- per-class buff reminders. buff = spell id of the self buff, group = id of the
-- party/raid version, reagent = item id the group version needs, min = members
-- missing it before the group version is suggested
local CLASS_BUFFS = {
	PRIEST = {
		{ buff = 1243, group = 25392, reagent = 17029, min = 2 },       -- PW: Fortitude / Prayer of Fortitude
		{ buff = 14752, group = 27681, reagent = 17029, min = 2 },      -- Divine Spirit / Prayer of Spirit
	},
	DRUID = {
		{ buff = 1126, group = 21849, reagent = 22147, min = 2 },       -- Mark of the Wild / Gift of the Wild
	},
	MAGE = {
		{ buff = 1459, group = 23028, reagent = 17020, min = 2 },       -- Arcane Intellect / Brilliance
		{ buff = 7302, anyOf = { 7302, 6117, 30482 } },                 -- Ice/Mage/Molten Armor
	},
	HUNTER = {
		{ buff = 13165, anyOf = { 13165, 14318, 14321, 14320, 14319, 14322, 19506 } }, -- any aspect or trueshot
	},
	PALADIN = {
		{ buff = 465, anyOf = { 465, 7294, 19746, 19876, 19888, 19891, 19892, 19893, 19894, 19895, 19896, 19897, 19898, 19899, 19900, 19901, 20218 } }, -- any aura
	},
	WARLOCK = {
		{ buff = 706, anyOf = { 687, 706, 28176 } },                    -- Demon Skin/Armor, Fel Armor
	},
	SHAMAN = {
		{ buff = 324, anyOf = { 324, 33736, 974 } },                    -- Lightning/Water/Earth Shield
	},
	WARRIOR = {
		{ buff = 6673, anyOf = { 6673, 469 } },                         -- Battle/Commanding Shout
	},
	DEATHKNIGHT = {
		{ buff = 48266, anyOf = { 48265, 48266, 48263 } },              -- presences (wrath+)
	},
}
local WEAPON_CLASSES = { ROGUE = true, SHAMAN = true }

-- paladin blessings: like the reference addon, each class gets the blessing
-- you last gave it; before that casters and healers get Wisdom and the rest
-- Kings or Might. The Greater Blessing glows once several members of a class
-- are missing it and the Symbol of Kings reagent is in your bags.
local PALA_BLESS = {
	{ key = "might", single = 19740, greater = 25782 },
	{ key = "wisdom", single = 19742, greater = 25899 },
	{ key = "kings", single = 20217, greater = 25898 },
	{ key = "salvation", single = 1038, greater = 25895 },
	{ key = "light", single = 19977, greater = 25890 },
	{ key = "sanctuary", single = 20911, greater = 25894 },
}
local KINGS_REAGENT = 21177 -- Symbol of Kings
local WISDOM_CLASSES = { MAGE = true, PRIEST = true, WARLOCK = true, DRUID = true, SHAMAN = true, PALADIN = true, HUNTER = true }
local MIGHT_CLASSES = { WARRIOR = true, ROGUE = true }

local REAGENT_WARN = 5

-- ---------------------------------------------------------------------------
-- action button scan
-- ---------------------------------------------------------------------------
local function ActionSpellID(action)
	local t, id = GetActionInfo(action)
	if t == "spell" then return id end
	if t == "macro" and GetMacroSpell then return GetMacroSpell(id) end
end

-- other button families whose names we know: own prefix scan picks up every
-- button that exists on this client, so the glows also reach gamepad bars
-- (Forever's own or from support addons) and third-party bars - without
-- depending on any of them. Addons can also hand us their button tables via
-- S:RegisterFlareButtons(table).
local EXTRA_PREFIXES = {
	"GamePad", "Gamepad", "ConsolePort", "CPB", "GPB",
	"BT4Button", "DominosActionButton", "NeuronActionButton", "ElvUI_Bar", "BAB",
	"PetActionButton", "StanceButton",
}
FL.extraButtons = {}

function S:RegisterFlareButtons(list)
	for _, b in ipairs(list or {}) do FL.extraButtons[#FL.extraButtons + 1] = b end
	spellBtns = nil
end

local function CollectButtons(out)
	out = out or {}
	local seen = {}
	local function Add(b)
		if b and b.action and not seen[b] then seen[b] = true out[#out + 1] = b end
	end
	local ab = S:GetModule("ActionBars")
	if ab and ab.buttons then for _, b in ipairs(ab.buttons) do Add(b) end end
	for _, b in ipairs(FL.extraButtons) do Add(b) end
	local names = { "ActionButton", "BonusActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
		"MultiBarLeftButton", "MultiBarRightButton" }
	for _, n in ipairs(names) do
		for i = 1, 12 do Add(_G[n .. i]) end
	end
	-- every button family that names its buttons <prefix><index>: stops at a
	-- few consecutive misses so unknown button counts just work
	for _, prefix in ipairs(EXTRA_PREFIXES) do
		local miss = 0
		for i = 1, 200 do
			local b = _G[prefix .. i]
			if b then Add(b) miss = 0 else miss = miss + 1 end
			if miss >= 8 then break end
		end
	end
	return out
end

-- ---------------------------------------------------------------------------
-- glow overlay (own color, bounce pulse)
-- ---------------------------------------------------------------------------
local function GlowOf(btn)
	local g = btn.suiFlareGlow
	if not g then
		g = CreateFrame("Frame", nil, btn, S.BackdropTemplate)
		S:SetOutside(g, btn, 2, 2)
		g:SetBackdrop({ edgeFile = S.media.blank, edgeSize = 2 })
		g:SetFrameLevel(btn:GetFrameLevel() + 6)
		local ag = g:CreateAnimationGroup()
		ag:SetLooping("BOUNCE")
		local a = ag:CreateAnimation("Alpha")
		a:SetFromAlpha(1)
		a:SetToAlpha(0.3)
		a:SetDuration(0.4)
		g.anim = ag
		btn.suiFlareGlow = g
	end
	return g
end

local reasons = {} -- btn -> { [reason] = expiresAt }

local function SetGlow(btn, reason, untilT)
	local r = reasons[btn]
	if not r then r = {} reasons[btn] = r end
	r[reason] = untilT or math.huge
	local c = FL.db and FL.db.color or { 1.0, 0.62, 0.12 }
	local g = GlowOf(btn)
	g:SetBackdropBorderColor(c[1], c[2], c[3], (FL.db and FL.db.alpha) or 1)
	g:SetAlpha((FL.db and FL.db.alpha) or 1)
	if not g:IsShown() then g:Show() g.anim:Play() end
end

local function ClearGlows()
	local now = GetTime()
	for btn, r in pairs(reasons) do
		local alive = false
		for reason, t in pairs(r) do
			if t < now then r[reason] = nil else alive = true end
		end
		if not alive then
			reasons[btn] = nil
			if btn.suiFlareGlow then btn.suiFlareGlow.anim:Stop() btn.suiFlareGlow:Hide() end
		end
	end
end

-- spell id -> buttons
local spellBtns
local function ButtonsFor(id)
	if not spellBtns then
		spellBtns = {}
		for _, b in ipairs(CollectButtons()) do
			local sid = b.action and ActionSpellID(b.action)
			if sid then spellBtns[sid] = spellBtns[sid] or {} tinsert(spellBtns[sid], b) end
		end
	end
	return spellBtns[id]
end

local function GlowSpell(id, reason, untilT)
	local list = ButtonsFor(id)
	if not list then return end
	for _, b in ipairs(list) do SetGlow(b, reason, untilT) end
end

-- ---------------------------------------------------------------------------
-- aura checks (own name resolution, works in every locale)
-- ---------------------------------------------------------------------------
local ownAuras = {}
local function RefreshOwnAuras()
	ownAuras = {}
	if not S.UnitAura then return end
	for i = 1, 40 do
		local a = S.UnitAura("player", i, "HELPFUL")
		if not a then break end
		local n = a.name or a[1]
		if n then ownAuras[n] = true end
	end
end

local function UnitHasAura(unit, names)
	if not S.UnitAura then return false end
	for i = 1, 40 do
		local a = S.UnitAura(unit, i, "HELPFUL")
		if not a then break end
		local n = a.name or a[1]
		if n and names[n] then return true end
	end
	return false
end

local function AnyOfNames(ids)
	local out = {}
	for _, id in ipairs(ids) do
		local n = SpellName(id)
		if n then out[n] = true end
	end
	return out
end

local function PartyMembers()
	local out = {}
	for i = 1, 4 do
		local u = "party" .. i
		if UnitExists(u) and not UnitIsDeadOrGhost(u) and UnitIsVisible(u) then out[#out + 1] = u end
	end
	return out
end

-- ---------------------------------------------------------------------------
-- main evaluation
-- ---------------------------------------------------------------------------
local prevCd = {}
local scanTick = 0

function FL:Evaluate(now)
	local db = self.db
	local _, class = UnitClass("player")
	local combat = InCombatLockdown()

	-- missing own buffs + party members missing yours (+ group version)
	if db.cats.buffs then
		for _, b in ipairs(CLASS_BUFFS[class] or {}) do
			local names = AnyOfNames(b.anyOf or { b.buff })
			local n, missing = 0, {}
			for _, u in ipairs(PartyMembers()) do
				if not UnitHasAura(u, names) then n = n + 1 missing[#missing + 1] = u end
			end
			local have = ownAuras[next(names)] ~= nil
			for nm in pairs(names) do if ownAuras[nm] then have = true end end
			if b.group and n >= (b.min or 2) and (not b.reagent or (tonumber(GetItemCount(b.reagent)) or 0) > 0) then
				GlowSpell(b.group, "buff")
			elseif not have then
				GlowSpell(b.buff, "buff")
			end
		end
		if class == "PALADIN" then self:CheckBlessings() end
	end

	-- weapon enchants / poisons
	if db.cats.weapon and WEAPON_CLASSES[class] and GetWeaponEnchantInfo then
		local hasMH, _, _, hasOH = GetWeaponEnchantInfo()
		for _, b in ipairs(CollectButtons()) do
			local sid = b.action and ActionSpellID(b.action)
			if sid then
				local n = SpellName(sid)
				if n and (n:find("Poison") or n:find("Gift") or n:find("Frostbrand") or n:find("Windfury") or n:find("Flametongue") or n:find("Rockbiter") or n:find("Earthliving")) then
					if not hasMH or (class == "ROGUE" and not hasOH) then SetGlow(b, "weapon") end
				end
			end
		end
	end

	-- low reagents for the group buffs of my class
	if db.cats.reagent then
		for _, b in ipairs(CLASS_BUFFS[class] or {}) do
			if b.reagent and (tonumber(GetItemCount(b.reagent)) or 0) < (db.reagentWarn or REAGENT_WARN) then
				if b.group then GlowSpell(b.group, "reagent") else GlowSpell(b.buff, "reagent") end
			end
		end
	end

	-- cooldowns that come back
	if db.cats.cooldown then
		for _, b in ipairs(CollectButtons()) do
			local sid = b.action and ActionSpellID(b.action)
			if sid and GetSpellCooldown then
				local start = GetSpellCooldown(sid)
				start = type(start) == "table" and start.startTime or start
				start = tonumber(start) or 0
				if (prevCd[sid] or 0) > 0 and start == 0 then
					SetGlow(b, "cooldown", now + (db.cooldownTime or 3))
				end
				prevCd[sid] = start
			end
		end
	end

	-- spells on an old rank
	if db.cats.rank then self:CheckRanks() end

	ClearGlows()
end

-- known blessings by localized name -> {spec}; what each class should have
local blessNames
local function BlessingSpecs()
	if not blessNames then
		blessNames = {}
		for _, b in ipairs(PALA_BLESS) do
			blessNames[#blessNames + 1] = { spec = b, single = SpellName(b.single), greater = SpellName(b.greater) }
		end
	end
	return blessNames
end

function FL:BlessingFor(classFile)
	local last = self.db.lastBless and self.db.lastBless[classFile]
	if last then
		for _, b in ipairs(BlessingSpecs()) do
			if b.spec.key == last then return b end
		end
	end
	for _, b in ipairs(BlessingSpecs()) do
		if WISDOM_CLASSES[classFile] and b.spec.key == "wisdom" then return b end
		if MIGHT_CLASSES[classFile] and b.spec.key == "might" then return b end
	end
	for _, b in ipairs(BlessingSpecs()) do
		if b.spec.key == "kings" then return b end
	end
end

function FL:BlessingKnown(entry)
	return entry and entry.single and self.nameOf and (function()
		for _, n in pairs(self.nameOf) do
			if n == entry.single then return true end
		end
	end)()
end

function FL:CheckBlessings()
	local known = {}
	if self.nameOf then for _, n in pairs(self.nameOf) do known[n] = true end end
	-- members per class that miss their assigned blessing
	local perClass, order = {}, {}
	for _, u in ipairs(PartyMembers()) do
		local _, cf = UnitClass(u)
		if cf and not UnitIsDeadOrGhost(u) then
			local b = self:BlessingFor(cf)
			if b and b.single and known[b.single] then
				if not UnitHasAura(u, { [b.single] = true, [b.greater or ""] = true }) then
					perClass[cf] = (perClass[cf] or 0) + 1
					if perClass[cf] == 1 then order[#order + 1] = cf end
				end
			end
		end
	end
	local haveKings = (tonumber(GetItemCount(KINGS_REAGENT)) or 0) > 0
	local greaterMin = self.db.greaterMin or 2
	for _, cf in ipairs(order) do
		local b = self:BlessingFor(cf)
		if perClass[cf] >= greaterMin and b.greater and known[b.greater] and haveKings then
			GlowSpell(b.spec.greater, "buff")
		else
			GlowSpell(b.spec.single, "buff")
		end
	end
end

-- remember which blessing you gave which class (UNIT_SPELLCAST_SENT also
-- carries the spell target in newer clients)
function FL:TrackBlessing(_, target, _, spellID)
	local _, myClass = UnitClass("player")
	if myClass ~= "PALADIN" or not spellID then return end
	local sname = SpellName(spellID)
	if not sname then return end
	local hit, targetName
	for _, b in ipairs(BlessingSpecs()) do
		if sname == b.single or sname == b.greater then hit = b.spec.key end
	end
	if not hit then return end
	if target and target ~= "" then
		for _, u in ipairs(PartyMembers()) do
			if UnitName(u) == target then targetName = select(2, UnitClass(u)) end
		end
		if not targetName and UnitName("target") == target then targetName = select(2, UnitClass("target")) end
	end
	targetName = targetName or "PALADIN"
	self.db.lastBless = self.db.lastBless or {}
	self.db.lastBless[targetName] = hit
end

-- spellbook scan: for every spell id its localized name and rank, plus the
-- best known rank per name. A button spell whose rank is below the best is
-- an old rank.
function FL:ScanSpellbook()
	local maxRank, nameOf, rankOf = {}, {}, {}
	if GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemName then
		for tab = 1, (GetNumSpellTabs() or 0) do
			local _, _, offset, num = GetSpellTabInfo(tab)
			for i = 1, (num or 0) do
				local slot = (offset or 0) + i
				local name, sub = GetSpellBookItemName(slot, BOOKTYPE_SPELL or "spell")
				local t, id
				if GetSpellBookItemInfo then t, id = GetSpellBookItemInfo(slot, BOOKTYPE_SPELL or "spell") end
				local rank = sub and tonumber(sub:match("(%d+)")) or 0
				if name and rank and id then
					nameOf[id] = name
					rankOf[id] = rank
					maxRank[name] = math.max(maxRank[name] or 0, rank)
				end
			end
		end
	end
	self.maxRank, self.nameOf, self.rankOf = maxRank, nameOf, rankOf
end

function FL:CheckRanks()
	local maxRank, nameOf, rankOf = self.maxRank, self.nameOf, self.rankOf
	if not (maxRank and nameOf and rankOf) then return end
	for _, b in ipairs(CollectButtons()) do
		local sid = b.action and ActionSpellID(b.action)
		local name, rank = sid and nameOf[sid], sid and rankOf[sid]
		if name and rank and maxRank[name] and rank < maxRank[name] then SetGlow(b, "rank") end
	end
end

-- ---------------------------------------------------------------------------
function FL:Initialize()
	self.db = S.db.profile.flare
	self:ScanSpellbook()
	RefreshOwnAuras()
	spellBtns = nil

	self:RegisterEvent("UNIT_AURA", function(_, unit)
		if unit == "player" then RefreshOwnAuras() FL:Refresh() end
	end)
	self:RegisterEvent("SPELLS_CHANGED", function() FL:ScanSpellbook() FL:Refresh() end)
	self:RegisterEvent("SPELL_UPDATE_COOLDOWN", function() FL:Refresh() end)
	self:RegisterEvent("BAG_UPDATE", function() FL:Refresh() end)
	self:RegisterEvent("GROUP_ROSTER_UPDATE", function() FL:Refresh() end)
	self:RegisterEvent("UNIT_INVENTORY_CHANGED", function(_, unit) if unit == "player" then FL:Refresh() end end)
	self:RegisterEvent("PLAYER_REGEN_ENABLED", function() FL:Refresh() end)
	self:RegisterEvent("ACTIONBAR_SLOT_CHANGED", function() spellBtns = nil FL:Refresh() end)
	self:RegisterEvent("UNIT_SPELLCAST_SENT", function(_, unit, target, guid, spellID)
		if unit == "player" then S:SafeCall("Flare:Blessing", FL.TrackBlessing, FL, unit, target, guid, spellID) end
	end)

	-- steady refresh for aura/cooldown transitions
	C_Timer.NewTicker(1.5, function()
		if FL.db and FL.db.enable ~= false then
			RefreshOwnAuras()
			FL:Evaluate(GetTime())
		end
	end)

	SLASH_SUIFLARE1 = "/suiflare"
	SLASH_SUIFLARE2 = "/flare"
	SlashCmdList.SUIFLARE = function() S:ToggleConfig("flare") end

	self.minimapBtn = S:CreateMinimapButton({
		name = "flare", glyph = "FL",
		hub = "raidtools", label = S.L["Flare"], order = 7,
		onLeft = function() S:ToggleConfig("flare") end,
		onRight = function()
			FL.db.cats.buffs = not FL.db.cats.buffs
		end,
		tooltip = function()
			GameTooltip:AddLine("SentinelUI " .. L["Flare"])
			GameTooltip:AddLine(L["Action buttons glow for missing buffs, weapon buffs, low reagents, cooldowns and old spell ranks."], 1, 1, 1)
			GameTooltip:AddLine(L["Left-click: options  |  Right-click: buff glow on/off"], 1, 1, 1)
		end,
	})

	C_Timer.After(1, function() RefreshOwnAuras() spellBtns = nil FL:Evaluate(GetTime()) end)
end

function FL:Refresh()
	if not self.db or self.db.enable == false then return end
	spellBtns = nil
	S:SafeCall("Flare:Eval", FL.Evaluate, FL, GetTime())
end
