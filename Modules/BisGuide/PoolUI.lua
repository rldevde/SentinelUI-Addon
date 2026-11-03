-- BiS pool browser and tooltip lines for every client that has no built-in
-- BiS database (Era, Season of Discovery, Wrath, Cata, Mists, Retail and the
-- Forever client). The data comes from the generated Pool_<NAME>.lua files:
-- per class and spec a flat list of item ids with a tag (phase / category),
-- a source and, where known, the slot. Slots missing in the data are read from
-- the client's own item data at runtime.
local _, ns = ...
local S = ns.S
local L = S.L
local TA = S:GetModule("TalentAtlas")
local BP = {}
TA.BisPool = BP

local _G = _G
local ipairs, pairs, tinsert, sort, format = ipairs, pairs, table.insert, table.sort, string.format
local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local RequestItem = C_Item and C_Item.RequestLoadItemDataByID

local SPECS = {
	DEATHKNIGHT = { "Blood", "Frost", "Unholy" },
	DEMONHUNTER = { "Havoc", "Vengeance", "Devourer" },
	DRUID = { "Balance", "Feral DPS", "Feral Tank", "Restoration" },
	EVOKER = { "Devastation", "Preservation", "Augmentation" },
	HUNTER = { "Beast Mastery", "Marksmanship", "Survival" },
	MAGE = { "Arcane", "Fire", "Frost" },
	MONK = { "Brewmaster", "Mistweaver", "Windwalker" },
	PALADIN = { "Holy", "Protection", "Retribution" },
	PRIEST = { "Discipline", "Holy", "Shadow" },
	ROGUE = { "Assassination", "Combat", "Subtlety" },
	SHAMAN = { "Elemental", "Enhancement", "Restoration" },
	WARLOCK = { "Affliction", "Demonology", "Destruction" },
	WARRIOR = { "Arms", "Fury", "Protection" },
}
-- names that differ from the classic tab order: Guardian arrived with Mists,
-- Outlaw with Legion
local POOL_SPECS = {
	MISTS = { DRUID = { "Balance", "Feral", "Guardian", "Restoration" } },
	RETAIL = {
		DRUID = { "Balance", "Feral", "Guardian", "Restoration" },
		ROGUE = { "Assassination", "Outlaw", "Subtlety" },
	},
}
local CLASS_ORDER = { "DEATHKNIGHT", "DEMONHUNTER", "DRUID", "EVOKER", "HUNTER", "MAGE", "MONK", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR" }

local SLOT_ORDER = { "INVTYPE_HEAD", "INVTYPE_NECK", "INVTYPE_SHOULDER", "INVTYPE_CLOAK", "INVTYPE_CHEST", "INVTYPE_ROBE",
	"INVTYPE_WRIST", "INVTYPE_HAND", "INVTYPE_WAIST", "INVTYPE_LEGS", "INVTYPE_FEET", "INVTYPE_FINGER", "INVTYPE_TRINKET",
	"INVTYPE_2HWEAPON", "INVTYPE_WEAPON", "INVTYPE_WEAPONMAINHAND", "INVTYPE_WEAPONOFFHAND", "INVTYPE_HOLDABLE",
	"INVTYPE_SHIELD", "INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT", "INVTYPE_THROWN", "INVTYPE_RELIC" }
local SLOT_RANK = {}
for i, k in ipairs(SLOT_ORDER) do SLOT_RANK[k] = i end
SLOT_RANK.INVTYPE_ROBE = SLOT_RANK.INVTYPE_CHEST
local OTHER = "OTHER"

local CATEGORY = { BISO = "BiS Overall", BISR = "BiS in Raid", BISM = "BiS in M+", BISMR = "BiS in M+/Raid", TRINKETS = "Trinkets" }

function BP:Pool()
	local name = ns.BisPoolName and ns.BisPoolName()
	return name and ns.BisPools and ns.BisPools[name], name
end

function BP:Available() return self:Pool() ~= nil end

function BP:SpecName(class, i)
	local _, name = self:Pool()
	local list = (POOL_SPECS[name] and POOL_SPECS[name][class]) or SPECS[class]
	return list and list[i] or ("#" .. i)
end

-- "BIS,PVE,P4" / "PREBIS,PVE,SODP8" / retail category key -> readable label
function BP:TagLabel(tag)
	if not tag or tag == "" then return "" end
	if CATEGORY[tag] then return L[CATEGORY[tag]] end
	local kind, content, phase = tag:match("^([A-Z]+),([A-Z]+),([A-Z0-9]+)$")
	if not kind then return tag end
	local out
	local sod = phase:match("^SODP?(%d+)$")
	local ph = phase:match("^P(%d+)$")
	if sod then out = format(L["SoD phase %s"], sod)
	elseif ph then out = format(L["Phase %s"], ph)
	else out = phase end
	if kind == "PREBIS" then out = L["Pre-BiS"] .. " - " .. out end
	if content == "PVP" then out = out .. " (PvP)" end
	return out
end

function BP:SourceLabel(P, srcIdx)
	local key = P.src[srcIdx]
	if not key then return "" end
	local n = (GetLocale() == "deDE" and P.namesDE and P.namesDE[key]) or (P.names and P.names[key])
	if n then
		return (n[2] and n[2] ~= "") and (n[1] .. ", " .. n[2]) or n[1]
	end
	if key:find("^catalyst") then return L["Catalyst"] end
	return key
end

-- flat quadruple list of one class/spec -> items
function BP:Items(P, class, spec)
	local list = P.d[class] and P.d[class][spec]
	local out = {}
	if not list then return out end
	for i = 1, #list, 4 do
		out[#out + 1] = { id = list[i], tag = P.tags[list[i + 1]] or "", src = list[i + 2], slot = P.slots[list[i + 3]] }
	end
	return out
end

local function SlotOf(item)
	local slot = item.slot
	if not slot or slot == "" then
		local _, _, _, equip = GetItemInfoInstant(item.id)
		slot = equip
	end
	if not slot or slot == "" then return OTHER end
	return SLOT_RANK[slot] and slot or OTHER
end

-- ---------------------------------------------------------------------------
-- tooltip lines: which of your specs want this item
-- ---------------------------------------------------------------------------
local byItem
local function BuildIndex(P)
	byItem = {}
	for class, specs in pairs(P.d) do
		for spec, list in pairs(specs) do
			for i = 1, #list, 4 do
				local id = list[i]
				byItem[id] = byItem[id] or {}
				tinsert(byItem[id], { class, spec, P.tags[list[i + 1]] or "", list[i + 2] })
			end
		end
	end
end

function BP:OnTooltipItem(tt)
	local db = S.db.profile.bisguide
	if db and db.tooltip == false then return end
	local P = self:Pool()
	if not P then return end
	local _, link = tt:GetItem()
	local id = link and tonumber(link:match("item:(%d+)"))
	if not id then return end
	if not byItem then BuildIndex(P) end
	local hits = byItem[id]
	if not hits then return end
	local _, myClass = UnitClass("player")
	local lines, seen = {}, {}
	for _, h in ipairs(hits) do
		if h[1] == myClass or not (db and db.ownSpecOnly) then
			local label = self:SpecName(h[1], h[2])
			local key = h[1] .. label .. h[3]
			if not seen[key] then
				seen[key] = true
				local cn = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[h[1]] or h[1]
				local text = h[1] == myClass and L[label] or (L[label] .. " (" .. cn .. ")")
				lines[#lines + 1] = { h[1] == myClass and 0 or 1, text, self:TagLabel(h[3]), h[4] }
			end
		end
	end
	if #lines == 0 then return end
	sort(lines, function(a, b) if a[1] ~= b[1] then return a[1] < b[1] end return a[2] < b[2] end)
	tt:AddLine(" ")
	tt:AddLine("|cff" .. S.accentHex .. L["BiS Guide"] .. "|r")
	for i = 1, math.min(#lines, 6) do
		local ln = lines[i]
		tt:AddDoubleLine(ln[2], ln[3], 0.9, 0.9, 0.95, 0.65, 0.7, 0.8)
		if db and db.tooltipSource ~= false and ln[4] and ln[4] > 0 and i == 1 then
			tt:AddLine(self:SourceLabel(P, ln[4]), 0.55, 0.6, 0.7)
		end
	end
	if #lines > 6 then tt:AddLine("+" .. (#lines - 6), 0.55, 0.6, 0.7) end
end

-- ---------------------------------------------------------------------------
-- browser window
-- ---------------------------------------------------------------------------
local win
local state = { class = nil, spec = 1, tagIdx = 1 }
local ROW_H = 22

local function Cycle(list, cur, dir)
	local n = #list
	if n == 0 then return cur end
	local i = 1
	for k, v in ipairs(list) do if v == cur then i = k end end
	return list[((i - 1 + dir) % n) + 1]
end

function BP:ClassList(P)
	local out = {}
	for _, c in ipairs(CLASS_ORDER) do if P.d[c] then out[#out + 1] = c end end
	return out
end

function BP:SpecList(P, class)
	local out = {}
	for i in pairs(P.d[class] or {}) do out[#out + 1] = i end
	sort(out)
	return out
end

function BP:TagList(P, class, spec)
	local out, seen = {}, {}
	local list = P.d[class] and P.d[class][spec] or {}
	for i = 1, #list, 4 do
		local t = P.tags[list[i + 1]] or ""
		if not seen[t] then seen[t] = true out[#out + 1] = t end
	end
	-- retail categories in a fixed order, phase tags newest first
	local CAT_RANK = { BISO = 1, BISMR = 2, BISR = 3, BISM = 4, TRINKETS = 5 }
	sort(out, function(a, b)
		local ra, rb = CAT_RANK[a], CAT_RANK[b]
		if ra or rb then return (ra or 99) < (rb or 99) end
		return a > b
	end)
	return out
end

function BP:Build()
	if win then return win end
	local f = CreateFrame("Frame", "SentinelUIBisPool", UIParent, S.BackdropTemplate)
	f:SetSize(540, 580)
	f:SetPoint("CENTER")
	f:SetMovable(true) f:EnableMouse(true) f:RegisterForDrag("LeftButton")
	f:SetClampedToScreen(true) f:SetFrameStrata("DIALOG") f:SetToplevel(true)
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	S:SkinFrame(f, "Default")
	tinsert(UISpecialFrames, "SentinelUIBisPool")
	f.title = S:FontString(f, 13, "OUTLINE")
	f.title:SetPoint("TOP", 0, -10)
	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -6, -6)
	S:SkinCloseButton(close)
	close:SetScript("OnClick", function() f:Hide() end)

	local function Pick(label, x, fn)
		local b = CreateFrame("Button", nil, f, S.BackdropTemplate)
		b:SetSize(160, 22)
		b:SetPoint("TOPLEFT", x, -38)
		S:SetTemplate(b, "Default")
		b.text = S:FontString(b, 11)
		b.text:SetPoint("CENTER")
		b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		b:SetScript("OnClick", function(_, btn) fn(btn == "RightButton" and -1 or 1) end)
		b:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
			GameTooltip:AddLine(label, 1, 1, 1)
			GameTooltip:AddLine(L["Left click: next  |  Right click: previous"], 0.7, 0.7, 0.7)
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
		return b
	end
	f.classBtn = Pick(L["Class"], 12, function(d)
		local P = BP:Pool()
		state.class = Cycle(BP:ClassList(P), state.class, d)
		state.spec, state.tagIdx = BP:SpecList(P, state.class)[1], 1
		BP:Refresh()
	end)
	f.specBtn = Pick(L["Spec"], 180, function(d)
		local P = BP:Pool()
		state.spec = Cycle(BP:SpecList(P, state.class), state.spec, d)
		state.tagIdx = 1
		BP:Refresh()
	end)
	f.tagBtn = Pick(L["Phase"], 348, function(d)
		local P = BP:Pool()
		local tags = BP:TagList(P, state.class, state.spec)
		state.tagIdx = ((state.tagIdx - 1 + d) % math.max(#tags, 1)) + 1
		BP:Refresh()
	end)

	local sf = CreateFrame("ScrollFrame", "SentinelUIBisPoolScroll", f, "UIPanelScrollFrameTemplate")
	sf:SetPoint("TOPLEFT", 12, -70)
	sf:SetPoint("BOTTOMRIGHT", -30, 34)
	local child = CreateFrame("Frame", nil, sf)
	child:SetSize(480, 10)
	sf:SetScrollChild(child)
	f.scroll, f.child, f.rows = sf, child, {}

	f.foot = S:FontString(f, 10)
	f.foot:SetPoint("BOTTOMLEFT", 14, 12)
	f.foot:SetTextColor(0.55, 0.6, 0.7)

	f:SetScript("OnShow", function() BP:Refresh() end)
	f:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	local pending
	f:SetScript("OnEvent", function()
		if f:IsShown() and not pending then
			pending = true
			C_Timer.After(0.3, function() pending = nil if f:IsShown() then BP:Refresh() end end)
		end
	end)
	win = f
	return f
end

local function Row(f, i)
	local r = f.rows[i]
	if r then return r end
	r = CreateFrame("Button", nil, f.child)
	r:SetHeight(ROW_H)
	r:SetPoint("TOPLEFT", 0, 0)
	r:SetPoint("RIGHT", f.child, "RIGHT", 0, 0)
	r.icon = r:CreateTexture(nil, "ARTWORK")
	r.icon:SetSize(18, 18)
	r.icon:SetPoint("LEFT", 2, 0)
	r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	r.name = S:FontString(r, 11)
	r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
	r.name:SetWidth(250)
	r.name:SetJustifyH("LEFT")
	r.src = S:FontString(r, 10)
	r.src:SetPoint("LEFT", r.name, "RIGHT", 6, 0)
	r.src:SetPoint("RIGHT", r, "RIGHT", -2, 0)
	r.src:SetJustifyH("LEFT")
	r.src:SetTextColor(0.6, 0.65, 0.75)
	r.head = S:FontString(r, 11, "OUTLINE")
	r.head:SetPoint("LEFT", 2, 0)
	r.hl = r:CreateTexture(nil, "HIGHLIGHT")
	r.hl:SetAllPoints()
	r.hl:SetColorTexture(1, 1, 1, 0.07)
	r:SetScript("OnEnter", function(self)
		if not self.itemId then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetItemByID(self.itemId)
		GameTooltip:Show()
	end)
	r:SetScript("OnLeave", function() GameTooltip:Hide() end)
	r:SetScript("OnClick", function(self)
		if self.itemId and IsModifiedClick("CHATLINK") then
			local _, link = GetItemInfo(self.itemId)
			if link then ChatEdit_InsertLink(link) end
		end
	end)
	f.rows[i] = r
	return r
end

function BP:Refresh()
	local P, poolName = self:Pool()
	if not (P and win) then return end
	local f = win
	local _, myClass = UnitClass("player")
	if not state.class or not P.d[state.class] then
		state.class = P.d[myClass] and myClass or self:ClassList(P)[1]
		state.spec, state.tagIdx = self:SpecList(P, state.class)[1], 1
	end
	if not P.d[state.class][state.spec] then state.spec = self:SpecList(P, state.class)[1] end
	local tags = self:TagList(P, state.class, state.spec)
	state.tagIdx = math.min(state.tagIdx, math.max(#tags, 1))
	local tag = tags[state.tagIdx] or ""

	local cn = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[state.class] or state.class
	f.title:SetText("|cff" .. S.accentHex .. L["BiS Guide"] .. "|r  " .. poolName)
	f.classBtn.text:SetText(cn)
	f.specBtn.text:SetText(L[self:SpecName(state.class, state.spec)])
	f.tagBtn.text:SetText(self:TagLabel(tag))

	-- group by slot
	local groups, order = {}, {}
	for _, it in ipairs(self:Items(P, state.class, state.spec)) do
		if it.tag == tag then
			local s = SlotOf(it)
			if not groups[s] then groups[s] = {} order[#order + 1] = s end
			tinsert(groups[s], it)
		end
	end
	sort(order, function(a, b)
		local ra, rb = SLOT_RANK[a] or 99, SLOT_RANK[b] or 99
		return ra < rb
	end)

	local n, y, count = 0, 0, 0
	local function NextRow()
		n = n + 1
		local r = Row(f, n)
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", 0, -y)
		r:SetPoint("RIGHT", f.child, "RIGHT", 0, 0)
		r:Show()
		y = y + ROW_H
		return r
	end
	for _, s in ipairs(order) do
		local h = NextRow()
		h.itemId = nil
		h.icon:Hide() h.name:SetText("") h.src:SetText("")
		h.head:SetText("|cff" .. S.accentHex .. (s == OTHER and L["Other"] or (_G[s] or s)) .. "|r")
		h.head:Show()
		sort(groups[s], function(a, b) return a.id > b.id end)
		for _, it in ipairs(groups[s]) do
			local r = NextRow()
			r.itemId = it.id
			r.head:Hide()
			local name, _, quality = GetItemInfo(it.id)
			if not name and RequestItem then RequestItem(it.id) end
			local icon = select(5, GetItemInfoInstant(it.id))
			r.icon:SetTexture(icon)
			r.icon:Show()
			local c = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
			r.name:SetText((c and c.hex or "|cffffffff") .. (name or ("item:" .. it.id)) .. "|r")
			r.src:SetText(self:SourceLabel(P, it.src))
			count = count + 1
		end
	end
	for i = n + 1, #f.rows do f.rows[i]:Hide() end
	f.child:SetHeight(math.max(y, 10))
	f.foot:SetText(format("%s  |  %d %s  |  %s %s", self:TagLabel(tag), count, L["items"], L["Data from"], P.date or "?"))
end

function BP:Open(class, spec)
	if not self:Available() then
		S:Print(L["BiS Guide"] .. ": " .. L["not available"])
		return
	end
	local f = self:Build()
	if class then
		local P = self:Pool()
		if P.d[class] then
			state.class = class
			state.spec = spec and P.d[class][spec] and spec or self:SpecList(P, class)[1]
			state.tagIdx = 1
		end
	end
	if f:IsShown() and not class then f:Hide() else f:Show() self:Refresh() end
end

-- tooltip hook + slash command (only where this pool is the BiS source)
function BP:Initialize()
	if not self:Available() then return end
	if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item,
			function(tt) S:SafeCall("BisPool:Tip", BP.OnTooltipItem, BP, tt) end)
	else
		GameTooltip:HookScript("OnTooltipSetItem", function(tt) S:SafeCall("BisPool:Tip", BP.OnTooltipItem, BP, tt) end)
	end
	SLASH_SUIBIS1 = "/suibis"
	SLASH_SUIBIS2 = "/bisguide"
	SlashCmdList["SUIBIS"] = function() BP:Open() end
end
