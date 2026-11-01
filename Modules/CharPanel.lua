local S = SentinelUI
local L = S.L
local CP = S:NewModule("CharPanel", "charpanel")
local format, floor, select = string.format, math.floor, select

local LEFT  = { 1, 2, 3, 15, 5, 4, 19, 9 }
local RIGHT = { 10, 6, 7, 8, 11, 12, 13, 14 }
local BOTTOM = { 16, 17, 18 }

local function QR(q)
	if q and GetItemQualityColor then
		local r, g, b = GetItemQualityColor(q)
		if r then return r, g, b end
	end
	local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
	return c and c.r or 1, c and c.g or 1, c and c.b or 1
end

local function BI()
	local bi = _G.RLBetterItem
	if bi and bi.GetItemScore then return bi end
	if S.GetModule then
		bi = S:GetModule("BetterItem") or S:GetModule("RLBetterItem")
		if bi and bi.GetItemScore then return bi end
	end
end

local function SlotScore(link)
	local bi = BI()
	if not bi then return 0 end
	local ok, sc = pcall(bi.GetItemScore, bi, link,
		bi.GetActiveScaleKey and bi:GetActiveScaleKey() or nil)
	return ok and tonumber(sc) or 0
end

-- one slim slot row: icon + name over "iLvl · GS", hairline divider below
local function SlotRow(parent, slot, side, idx)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(196, 30)
	b.slot = slot
	b.ic = b:CreateTexture(nil, "ARTWORK")
	b.ic:SetSize(24, 24)
	b.ic:SetTexCoord(0.06, 0.94, 0.06, 0.94)
	b.ib = b:CreateTexture(nil, "BORDER", nil, 1)
	b.ib:SetPoint("TOPLEFT", b.ic, -1, 1)
	b.ib:SetPoint("BOTTOMRIGHT", b.ic, 1, -1)
	b.ib:SetTexture([[Interface\Buttons\WHITE8X8]])
	b.ib:SetVertexColor(0.2, 0.2, 0.2, 0.8)
	b.nm = S:FontString(b, 10, "OUTLINE")
	b.st = S:FontString(b, 9, "OUTLINE")
	b.hr = b:CreateTexture(nil, "BACKGROUND")
	b.hr:SetHeight(1)
	b.hr:SetTexture([[Interface\Buttons\WHITE8X8]])
	b.hr:SetVertexColor(1, 1, 1, 0.06)
	if side == "L" then
		b:SetPoint("TOPLEFT", 10, -54 - (idx - 1) * 31)
		b.ic:SetPoint("LEFT", 0, 0)
		b.nm:SetPoint("LEFT", b.ic, "RIGHT", 6, 6)
		b.nm:SetPoint("RIGHT", b, "RIGHT", -2, 6)
		b.st:SetPoint("TOPLEFT", b.nm, "BOTTOMLEFT", 0, -1)
		b.nm:SetJustifyH("LEFT") b.st:SetJustifyH("LEFT")
		b.hr:SetPoint("BOTTOMLEFT", 0, 0) b.hr:SetPoint("BOTTOMRIGHT", 0, 0)
	else
		b:SetPoint("TOPRIGHT", -10, -54 - (idx - 1) * 31)
		b.ic:SetPoint("RIGHT", 0, 0)
		b.nm:SetPoint("RIGHT", b.ic, "LEFT", -6, 6)
		b.nm:SetPoint("LEFT", b, "LEFT", 2, 6)
		b.st:SetPoint("TOPRIGHT", b.nm, "BOTTOMRIGHT", 0, -1)
		b.nm:SetJustifyH("RIGHT") b.st:SetJustifyH("RIGHT")
		b.hr:SetPoint("BOTTOMLEFT", 0, 0) b.hr:SetPoint("BOTTOMRIGHT", 0, 0)
	end
	b.nm:SetWordWrap(false)
	b:SetScript("OnClick", function(_, btn)
		if btn == "LeftButton" and PickupInventoryItem then PickupInventoryItem(slot) end
	end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetInventoryItem("player", slot)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return b
end

local function Paint(b)
	local link = GetInventoryItemLink("player", b.slot)
	if not link then
		b.ic:SetTexture(134400)
		b.ic:SetVertexColor(0.2, 0.2, 0.2, 0.35)
		b.ib:SetVertexColor(0.2, 0.2, 0.2, 0.4)
		b.nm:SetText("|cff444444—|r") b.st:SetText("")
		return
	end
	local name, _, q, ilvl = GetItemInfo(link)
	local ic = GetItemInfoInstant and select(5, GetItemInfoInstant(link))
	b.ic:SetVertexColor(1, 1, 1)
	if ic then b.ic:SetTexture(ic) end
	local r, g, bl = QR(q)
	b.ib:SetVertexColor(r, g, bl, 0.85)
	b.nm:SetText(name or "...")
	b.nm:SetTextColor(r, g, bl)
	local extra = ""
	local cur, mx = GetInventoryItemDurability and GetInventoryItemDurability(b.slot)
	if cur and mx and mx > 0 then
		local pct = floor(cur / mx * 100)
		extra = format("  %s%d%%|r", pct < 25 and "|cffff4040" or "|cff6f8296", pct)
	end
	b.st:SetFormattedText("|cff6f8296iLvl|r |cffffffff%s|r  |cff6f8296GS|r |cffffffff%.0f|r%s",
		ilvl and ilvl > 0 and ilvl or "-", SlotScore(link), extra)
	if not name and C_Timer then
		C_Timer.After(1.5, function() if b:IsShown() then Paint(b) end end)
	end
end

local STATS = {
	{ h = L["Attributes"] or "Attributes" },
	{ L["Strength"], function() return UnitStat("player", 1) end },
	{ L["Agility"], function() return UnitStat("player", 2) end },
	{ L["Stamina"], function() return UnitStat("player", 3) end },
	{ L["Intellect"], function() return UnitStat("player", 4) end },
	{ L["Spirit"], function() return UnitStat("player", 5) end },
	{ L["Armor"], function() return UnitArmor("player") end },
	{ h = L["Combat"] or "Combat" },
	{ L["Hit"], function() return GetCombatRating and (GetCombatRating(6) or 0) end },
	{ L["Crit"], function() return format("%.1f%%", GetCritChance and GetCritChance() or 0) end },
	{ L["Attack power"], function() return UnitAttackPower and UnitAttackPower("player") or 0 end },
	{ L["Haste"], function() return GetCombatRating and (GetCombatRating(18) or 0) end },
	{ h = L["Spells"] or "Spells" },
	{ L["Spell hit"], function() return GetCombatRating and (GetCombatRating(8) or 0) end },
	{ L["Spell crit"], function() return format("%.1f%%", GetSpellCritChance and (GetSpellCritChance(2) or 0)) end },
	{ L["Spell damage"], function() return GetSpellBonusDamage and (GetSpellBonusDamage(2) or 0) end },
	{ L["Healing"], function() return GetSpellBonusHealing and (GetSpellBonusHealing() or 0) end },
	{ L["Mana regen"], function() local _, v = GetManaRegen and GetManaRegen() return v and floor(v) or "-" end },
	{ h = L["Defense"] or "Defense" },
	{ L["Dodge"], function() return format("%.1f%%", GetDodgeChance and GetDodgeChance() or 0) end },
	{ L["Parry"], function() return format("%.1f%%", GetParryChance and GetParryChance() or 0) end },
	{ L["Defense"], function() return GetCombatRating and (GetCombatRating(2) or 0) end },
	{ L["Resilience"], function() return GetCombatRating and (GetCombatRating(15) or 0) end },
}

function CP:Refresh()
	if not (self.frame and self.frame:IsShown()) then return end
	local f = self.frame
	for _, b in ipairs(f.slots) do pcall(Paint, b) end
	local bi = BI()
	-- active scale line (BetterItem integration)
	if bi and f.scaleInfo then
		local key = bi.GetActiveScaleKey and bi:GetActiveScaleKey()
		if key then f.scaleInfo:SetFormattedText("|cff6f8296Skala:|r |cffffffff%s|r", tostring(key)) end
	end
	if bi and bi.ComputeUnitGear then
		local ok, info = pcall(bi.ComputeUnitGear, bi, "player")
		if ok and info then
			f.gs:SetFormattedText("|cff6f8296GS|r |cffffffff%.0f|r   |cff6f8296Ø iLvl|r |cffffffff%.1f|r",
				info.score or 0, info.ilvl or 0)
		end
	end
	local i, n = 0, 0
	for _, d in ipairs(STATS) do
		n = n + 1
		local isH = d.h ~= nil
		local ok, v = true, d.h
		if not isH then ok, v = pcall(d[2]) end
		if ok and v then
			i = i + 1
			local row = f.sr[i]
			if not row then
				row = S:FontString(f.charPage, 10, "OUTLINE")
				f.sr[i] = row
			end
			if isH then
				row:SetFormattedText("|cffffd700%s|r", v)
				if S.RegisterAccent then S:RegisterAccent(row, "text") end
			else
				row:SetFormattedText("|cff9db3c8%s|r  |cffffffff%s|r", d[1], tostring(v))
			end
			row:SetPoint("TOPLEFT", f.statA, "TOPLEFT", isH and 6 or 14, -8 - (n - 1) * 16)
			row:Show()
		end
	end
	for j = i + 1, #f.sr do f.sr[j]:Hide() end
	f.model:SetUnit("player")
	f.model:SetRotation(0.15)
end

-- ---------------------------------------------------------------------------
-- tab pages: 1 character (the slot/model/stat view built in Build), 2
-- reputation, 3 skills, 4 pvp — all rendered inside our own window
-- ---------------------------------------------------------------------------
local function FillScroll(page, rows)
	local list = page.list
	for i, row in ipairs(rows) do
		local fs = list[i]
		if not fs then
			fs = S:FontString(page.child, 10, "OUTLINE")
			fs:SetPoint("TOPLEFT", 4, -(i - 1) * 15)
			list[i] = fs
		end
		fs:SetText(row)
		fs:Show()
	end
	for j = #rows + 1, #list do list[j]:Hide() end
	page.child:SetHeight(math.max(1, #rows * 15 + 4))
end

local STAND_L = {
	[1] = FACTION_STANDING_LABEL1, [2] = FACTION_STANDING_LABEL2,
	[3] = FACTION_STANDING_LABEL3, [4] = FACTION_STANDING_LABEL4,
	[5] = FACTION_STANDING_LABEL5, [6] = FACTION_STANDING_LABEL6,
	[7] = FACTION_STANDING_LABEL7, [8] = FACTION_STANDING_LABEL8,
}

local function RepRows()
	if ExpandFactionHeader then ExpandFactionHeader(0) end
	local rows = {}
	local n = GetNumFactions and GetNumFactions() or 0
	for i = 1, n do
		local name, _, stand, bot, top, earned, _, _, isHeader = GetFactionInfo(i)
		if isHeader then
			rows[#rows + 1] = "|cffffd700" .. tostring(name) .. "|r"
		elseif name then
			local pct = (top > bot) and floor((earned - bot) / (top - bot) * 100) or 0
			rows[#rows + 1] = format("  %s  |cff9db3c8—|r  %s  |cff6f8296(%d%%)|r",
				tostring(name), STAND_L[stand] or tostring(stand), pct)
		end
	end
	return rows
end

local function SkillRows()
	if ExpandSkillHeader then ExpandSkillHeader(0) end
	local rows = {}
	local n = GetNumSkillLines and GetNumSkillLines() or 0
	for i = 1, n do
		local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
		if isHeader then
			rows[#rows + 1] = "|cffffd700" .. tostring(name) .. "|r"
		elseif name then
			rows[#rows + 1] = format("  %s  |cff9db3c8—|r  |cffffffff%s|r|cff6f8296 / %s|r",
				tostring(name), tostring(rank or 0), tostring(maxRank or 0))
		end
	end
	return rows
end

local function PvPRows()
	local rows = {}
	local function add(k, v) if v then rows[#rows + 1] = format("|cff9db3c8%s|r  |cffffffff%s|r", k, tostring(v)) end end
	local hk, dk, ch = GetPVPLifetimeStats and GetPVPLifetimeStats() or nil
	local shk, sdk = GetPVPSessionStats and GetPVPSessionStats() or nil
	local yhk, ydk = GetPVPYesterdayStats and GetPVPYesterdayStats() or nil
	add(L["Rank"] or "Rank", UnitPVPRank and select(2, GetPVPRankInfo and GetPVPRankInfo(UnitPVPRank("player") or 0) or nil) or (GetPVPRankInfo and "—") or nil)
	add(L["Honorable kills"] or "Honorable kills", hk)
	add(L["Dishonorable kills"] or "Dishonorable kills", dk)
	add(L["Honor today"] or "Honor today", ch)
	add(L["HKs (session)"] or "HKs (session)", shk)
	add(L["DKs (session)"] or "DKs (session)", sdk)
	add(L["HKs (yesterday)"] or "HKs (yesterday)", yhk)
	add(L["DKs (yesterday)"] or "DKs (yesterday)", ydk)
	add(L["Honor level"], UnitHonorLevel and UnitHonorLevel("player") or nil)
	if #rows == 0 then rows[1] = "|cff888888—|r" end
	return rows
end

local PAGE_DEFS = {
	{ tab = 2, key = L["Reputation"] or "Reputation", fill = RepRows },
	{ tab = 3, key = L["Skills"] or "Skills", fill = SkillRows },
	{ tab = 4, key = L["PvP"] or "PvP", fill = PvPRows },
}

function CP:ShowPage(n)
	local f = self.frame
	if not f then return end
	f.activePage = n
	if f.charPage then f.charPage:SetShown(n == 1) end
	if f.outfitDD then f.outfitDD:SetShown(n == 1) end
	if f.scaleInfo then f.scaleInfo:SetShown(n == 1) end
	for i, tb in ipairs(f.tabs) do
		tb:SetAlpha(i == n and 1 or 0.55)
		if tb.ul then tb.ul:SetShown(i == n) end
	end
	for _, pd in ipairs(PAGE_DEFS) do
		local pg = f.pages[pd.tab]
		if pg then
			if n == pd.tab then
				FillScroll(pg, pd.fill())
				pg:Show()
			else
				pg:Hide()
			end
		end
	end
end

function CP:Build()
	if self.frame then return end
	local f = CreateFrame("Frame", "SentinelUICharPanel", UIParent)
	f:SetSize(760, 480)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	S:CreateBackdrop(f, "Default", "TOP")
	f:Hide()
	tinsert(UISpecialFrames, f:GetName())

	-- header: class-colored name + race/class, summary line below
	local _, class = UnitClass("player")
	local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	f.title = S:FontString(f, 13, "OUTLINE", S.media.unitFont)
	f.title:SetPoint("TOP", 0, -8)
	local race = UnitRace("player")
	local cname = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class] or class
	f.title:SetFormattedText("%s  |cff888888%s %d · %s, %s|r",
		UnitName("player"), L["Level"] or "Level", UnitLevel("player"), race or "?", cname or "?")
	if cc then f.title:SetTextColor(cc.r, cc.g, cc.b) end
	f.gs = S:FontString(f, 10, "OUTLINE")
	f.gs:SetPoint("TOP", 0, -26)

	f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	f.close:SetPoint("TOPRIGHT", -4, -4)
	if S.SkinCloseButton then S:SkinCloseButton(f.close) end

	-- hairline under the header
	local hr = f:CreateTexture(nil, "ARTWORK")
	f.charPage = CreateFrame("Frame", nil, f)
	f.charPage:SetAllPoints()
	hr:SetHeight(1)
	hr:SetPoint("TOPLEFT", 10, -44)
	hr:SetPoint("TOPRIGHT", -10, -44)
	hr:SetTexture([[Interface\Buttons\WHITE8X8]])
	hr:SetVertexColor(1, 1, 1, 0.08)

	-- center model, modest size, no box
	f.model = CreateFrame("DressUpModel", nil, f.charPage)
	f.model:SetPoint("TOP", -85, -60)
	f.model:SetSize(180, 300)
	f.model:SetUnit("player")
	f.model:SetRotation(0.15)

	-- stats: plain label column right of the model (no box)
	f.statA = CreateFrame("Frame", nil, f.charPage)
	f.statA:SetPoint("TOPLEFT", 415, -54)
	f.statA:SetSize(150, 310)
	S:SetTemplate(f.statA, "Transparent")
	local sl = f.statA:CreateTexture(nil, "ARTWORK")
	sl:SetWidth(1)
	sl:SetPoint("TOPLEFT", 0, 0)
	sl:SetPoint("BOTTOMLEFT", 0, 0)
	sl:SetTexture([[Interface\Buttons\WHITE8X8]])
	sl:SetVertexColor(1, 1, 1, 0.1)
	f.sr = {}

	-- slot columns
	f.slots = {}
	for i, s in ipairs(LEFT) do f.slots[#f.slots + 1] = SlotRow(f, s, "L", i) end
	for i, s in ipairs(RIGHT) do f.slots[#f.slots + 1] = SlotRow(f, s, "R", i) end

	-- weapons: one slim row centered under the model, icon over name
	for i, s in ipairs(BOTTOM) do
		local b = SlotRow(f.charPage, s, "L", 1)
		b:ClearAllPoints()
		b:SetSize(140, 56)
		b:SetPoint("TOP", f, "TOP", (i - 2) * 150 - 85, -388)
		b.ic:ClearAllPoints()
		b.ic:SetPoint("TOP", b, "TOP", 0, -4)
		b.ib:ClearAllPoints()
		b.ib:SetPoint("TOPLEFT", b.ic, -1, 1)
		b.ib:SetPoint("BOTTOMRIGHT", b.ic, 1, -1)
		b.nm:ClearAllPoints()
		b.nm:SetPoint("TOP", b.ic, "BOTTOM", 0, -2)
		b.nm:SetWidth(138)
		b.nm:SetJustifyH("CENTER")
		b.st:ClearAllPoints()
		b.st:SetPoint("TOP", b.nm, "BOTTOM", 0, 0)
		b.st:SetJustifyH("CENTER")
		f.slots[#f.slots + 1] = b
	end

	-- own tab bar with accent underline; each tab paints its page inside
	-- this window (no blizzard sub-frames involved)
	f.pages = {}
	for _, pd in ipairs(PAGE_DEFS) do
		local pg = CreateFrame("ScrollFrame", "SentinelUICharPanelPg" .. pd.tab, f, "UIPanelScrollFrameTemplate")
		pg:SetPoint("TOPLEFT", 10, -50)
		pg:SetPoint("BOTTOMRIGHT", -28, 40)
		pg.child = CreateFrame("Frame", nil, pg)
		pg.child:SetSize(680, 1)
		pg:SetScrollChild(pg.child)
		-- opaque fill: the scroll page must fully cover the character view
		-- underneath, the border comes from the template on the frame
		local bg = pg:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetTexture([[Interface\Buttons\WHITE8X8]])
		bg:SetVertexColor(0.035, 0.04, 0.055, 1)
		S:CreateBackdrop(pg, "Default")
		pg.list = {}
		pg:Hide()
		f.pages[pd.tab] = pg
	end
	f.activePage = 1
	f.tabs = {}
	local defs = {
		{ 1, L["Character"] or "Character" },
		{ 2, L["Reputation"] or "Reputation" },
		{ 3, L["Skills"] or "Skills" },
		{ 4, L["PvP"] or "PvP" },
	}
	for i, d in ipairs(defs) do
		local tb = CreateFrame("Button", nil, f)
		tb:SetSize(96, 20)
		tb:SetPoint("BOTTOM", f, "BOTTOM", (i - 2.5) * 100, 10)
		tb.txt = S:FontString(tb, 10, "OUTLINE")
		tb.txt:SetPoint("CENTER", 0, 2)
		tb.txt:SetText(d[2])
		tb.ul = tb:CreateTexture(nil, "OVERLAY")
		tb.ul:SetHeight(2)
		tb.ul:SetPoint("BOTTOMLEFT", 4, 0)
		tb.ul:SetPoint("BOTTOMRIGHT", -4, 0)
		tb.ul:SetTexture([[Interface\Buttons\WHITE8X8]])
		tb.ul:SetVertexColor(1, 0.84, 0, 0.9)
		tb.ul:Hide()
		local n = d[1]
		tb:SetScript("OnClick", function() CP:ShowPage(n) end)
		f.tabs[i] = tb
	end
	f:SetScript("OnShow", function() CP:Refresh() CP:ShowPage(f.activePage or 1) end)
	-- outfit button: click cycles through BetterItem outfits
	f.outfitDD = CreateFrame("Button", nil, f)
	f.outfitDD:SetSize(130, 20)
	f.outfitDD:SetPoint("BOTTOMLEFT", 10, 34)
	S:SkinButton(f.outfitDD)
	f.outfitDD.txt = S:FontString(f.outfitDD, 10, "OUTLINE")
	f.outfitDD.txt:SetAllPoints()
	f.outfitDD.txt:SetText(L["Outfit"] or "Outfit")
	f.outfitDD:SetScript("OnClick", function()
		local bi = BI()
		if not (bi and bi.GetOutfitNames and bi.EquipOutfit) then return end
		local names = bi:GetOutfitNames()
		if not names or #names == 0 then return end
		f.outfitIdx = ((f.outfitIdx or 0) % #names) + 1
		local nm = names[f.outfitIdx]
		bi:EquipOutfit(nm)
		f.outfitDD.txt:SetText(nm)
	end)
	f.scaleInfo = S:FontString(f, 9, "OUTLINE")
	f.scaleInfo:SetPoint("BOTTOMRIGHT", -14, 40)
	f.scaleInfo:SetJustifyH("RIGHT")
	f.ev = CreateFrame("Frame")
	f.ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	f.ev:RegisterEvent("UNIT_STATS")
	f.ev:SetScript("OnEvent", function() CP:Refresh() end)
	self.frame = f
end

function CP:Toggle()
	self:Build()
	local f = self.frame
	if f:IsShown() then f:Hide() else f:Show() end
end

-- replaces the Blizzard paperdoll on the Character tab only; reputation,
-- skills and PvP keep their native frames
local hooked
local function TryHook()
	if hooked or not CharacterFrame then return end
	hooked = true
	CharacterFrame:HookScript("OnShow", function()
		local tab = PanelTemplates_GetSelectedTab and PanelTemplates_GetSelectedTab(CharacterFrame) or 1
		if tab == 1 then
			CharacterFrame:Hide()
			if not (CP.frame and CP.frame:IsShown()) then CP:Toggle() end
		end
	end)
end

function CP:Initialize()
	if S.db.profile.charpanel and S.db.profile.charpanel.enable == false then return end
	TryHook()
end

SLASH_SUICHAR1 = "/suichar"
SlashCmdList.SUICHAR = function() CP:Toggle() end
