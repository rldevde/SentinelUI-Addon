-- TalentAtlas: class / race / talent guide, stat caps with live values and
-- links into the BisGuide windows. Data lives in TalentAtlas/Data.lua.
local _, ns = ...
local S = ns.S
local L = S.L
local TA = S:NewModule("TalentAtlas", "talentatlas")
local TD = ns.TalentAtlasData
local format, max, min, floor = string.format, math.max, math.min, math.floor
local tinsert = table.insert

local GOLD = { S.accent.r, S.accent.g, S.accent.b }
local PANEL_LIGHT = { 0.09, 0.105, 0.13, 0.98 }
local TEXT = { 0.91, 0.92, 0.94 }
local MUTED = { 0.57, 0.61, 0.67 }

local function RefreshTheme()
	local accent = S.accent or { r = 0.92, g = 0.68, b = 0.20 }
	GOLD[1], GOLD[2], GOLD[3] = accent.r, accent.g, accent.b
	local general = S.db and S.db.profile and S.db.profile.general
	local fade = general and general.backdropFadeColor
	if fade then PANEL_LIGHT[1], PANEL_LIGHT[2], PANEL_LIGHT[3], PANEL_LIGHT[4] = fade.r or 0.045, fade.g or 0.05, fade.b or 0.075, fade.a or 0.92 end
end

local function AddLabel(parent, text, size, color)
	local fs = S:FontString(parent, size or 12, nil, S.media.font, nil, "LEFT")
	fs:SetTextColor(color[1], color[2], color[3])
	fs:SetText(text or "")
	return fs
end

local D = {}

local function MakeTreePanel(parent, x, width, title, colors)
	local panel = CreateFrame("Frame", nil, parent, S.BackdropTemplate)
	panel:SetPoint("TOPLEFT", x, 0)
	panel:SetWidth(width)
	panel:SetHeight(100)
	S:SetTemplate(panel, "Default", "TOP")
	local header = AddLabel(panel, title, 13, colors)
	header:SetPoint("TOPLEFT", 9, -10)
	header:SetPoint("RIGHT", panel, "RIGHT", -7, 0)
	header:SetJustifyH("LEFT")
	return panel
end

local function DrawClassicTalents(parent, colors, L)
	if type(GetNumTalentTabs) ~= "function" or type(GetTalentInfo) ~= "function" then
		return nil
	end

	local tabCount = GetNumTalentTabs()
	if not tabCount or tabCount == 0 then return nil end

	local gap = 10
	local panelWidth = (parent:GetWidth() - (gap * (tabCount - 1))) / tabCount
	local contentHeight = 0
	local totalSpent = 0
	for tab = 1, tabCount do
		local r1, r2, r3, _, r5 = GetTalentTabInfo(tab)
		local treeName, apiPointsSpent
		if type(r1) == "number" and type(r2) == "string" then
			-- Anniversary TBC returns (tabID, name, icon); later Classic APIs
			-- may add pointsSpent in slot 5. Never mistake the icon ID for points.
			treeName, apiPointsSpent = r2, tonumber(r5)
		else
			-- Era-style API: (name, icon, pointsSpent, ...)
			treeName, apiPointsSpent = r1, tonumber(r3)
		end
		treeName = treeName or (L["Talent tree"] .. " " .. tab)
		local panel = MakeTreePanel(parent, (tab - 1) * (panelWidth + gap), panelWidth, treeName, colors)

		local talentCount = GetNumTalents and GetNumTalents(tab) or 0
		local treeSpent = 0
		for talent = 1, talentCount do
			local name, icon, _, _, rank, maxRank = GetTalentInfo(tab, talent)
			if name then
				rank = tonumber(rank) or 0
				maxRank = tonumber(maxRank) or 0
				treeSpent = treeSpent + rank
				local row = CreateFrame("Frame", nil, panel)
				row:SetSize(panelWidth - 14, 32)
				row:SetPoint("TOPLEFT", 7, -47 - ((talent - 1) * 35))
				row:EnableMouse(true)
				local rowBG = row:CreateTexture(nil, "BACKGROUND")
				rowBG:SetAllPoints()
				if rank > 0 then
					rowBG:SetColorTexture(colors[1] * 0.24, colors[2] * 0.24, colors[3] * 0.24, 0.96)
				else
					rowBG:SetColorTexture(0.085, 0.095, 0.115, 0.92)
				end
				local talentIcon = row:CreateTexture(nil, "ARTWORK")
				talentIcon:SetSize(24, 24)
				talentIcon:SetPoint("LEFT", 4, 0)
				if icon then talentIcon:SetTexture(icon) end
				local talentName = AddLabel(row, name, 10, { 0.91, 0.92, 0.94 })
				talentName:SetPoint("LEFT", talentIcon, "RIGHT", 5, 0)
				talentName:SetPoint("RIGHT", row, "RIGHT", -31, 0)
				talentName:SetJustifyH("LEFT")
				local points = AddLabel(row, ("%d/%d"):format(rank, maxRank), 9, rank > 0 and colors or { 0.57, 0.61, 0.67 })
				points:SetPoint("RIGHT", row, "RIGHT", -4, 0)
			end
		end
		totalSpent = totalSpent + treeSpent
		local spent = AddLabel(panel, format(L["%d points spent"], treeSpent), 9, { 0.60, 0.64, 0.70 })
		spent:SetPoint("TOPLEFT", 9, -29)
		if apiPointsSpent and apiPointsSpent ~= treeSpent then
			spent:SetText(format(L["%d points spent (API: %d)"], treeSpent, apiPointsSpent))
		end
		local height = 55 + (talentCount * 35)
		panel:SetHeight(height)
		contentHeight = math.max(contentHeight, height)
	end

	local total = AddLabel(parent, format(L["Total: %d points"], totalSpent), 11, colors)
	total:SetPoint("TOPLEFT", 0, 0)
	for _, child in ipairs({ parent:GetChildren() }) do
		if child ~= total and child.SetPoint and child.GetPoint then
			-- Keep the tree columns below the total summary.
			local point, relativeTo, relativePoint, x, y = child:GetPoint(1)
			if point == "TOPLEFT" and relativeTo == parent then
				child:ClearAllPoints()
				child:SetPoint("TOPLEFT", x or 0, (y or 0) - 22)
			end
		end
	end
	return contentHeight + 22
end

local function ReadSpell(definitionID)
	if not definitionID or not C_Traits or type(C_Traits.GetDefinitionInfo) ~= "function" then return nil end
	local definition = C_Traits.GetDefinitionInfo(definitionID)
	if not definition then return nil end

	local name = definition.overrideName
	local icon = definition.overrideIcon
	local spellID = definition.spellID
	if spellID and C_Spell and type(C_Spell.GetSpellInfo) == "function" then
		local spell = C_Spell.GetSpellInfo(spellID)
		if spell then
			name = name or spell.name
			icon = icon or spell.iconID
		end
	elseif spellID and type(GetSpellInfo) == "function" then
		name = name or GetSpellInfo(spellID)
		icon = icon or (type(GetSpellTexture) == "function" and GetSpellTexture(spellID))
	end
	return name, icon
end

local function DrawModernTalents(parent, colors, L)
	if not C_ClassTalents or type(C_ClassTalents.GetActiveConfigID) ~= "function"
		or not C_Traits or type(C_Traits.GetConfigInfo) ~= "function"
		or type(C_Traits.GetTreeNodes) ~= "function"
		or type(C_Traits.GetNodeInfo) ~= "function" then
		return nil
	end

	local configID = C_ClassTalents.GetActiveConfigID()
	if not configID then return false end
	local config = C_Traits.GetConfigInfo(configID)
	if not config or not config.treeIDs then return false end

	local treeCount = #config.treeIDs
	if treeCount == 0 then return false end
	local gap = 10
	local panelWidth = (parent:GetWidth() - (gap * (treeCount - 1))) / treeCount
	local contentHeight = 0
	local totalSpent = 0
	for treeIndex, treeID in ipairs(config.treeIDs) do
		local nodes = C_Traits.GetTreeNodes(treeID) or {}
		local visible = {}
		for _, nodeID in ipairs(nodes) do
			local info = C_Traits.GetNodeInfo(configID, nodeID)
			if info and info.isVisible ~= false and info.isGranted ~= true then
				visible[#visible + 1] = { id = nodeID, info = info }
			end
		end
		table.sort(visible, function(a, b)
			local ay, by = tonumber(a.info.posY) or 0, tonumber(b.info.posY) or 0
			if ay == by then return (tonumber(a.info.posX) or 0) < (tonumber(b.info.posX) or 0) end
			return ay < by
		end)
		if #visible > 0 then
			local treeName = L["Talent tree"] .. " " .. treeIndex
			if treeCount >= 2 then
				treeName = treeIndex == 1 and L["Class tree"] or L["Specialization tree"]
				if treeCount > 2 and treeIndex == treeCount then treeName = L["Hero tree"] end
			end
			local panel = MakeTreePanel(parent, (treeIndex - 1) * (panelWidth + gap), panelWidth, treeName, colors)
			local spent = 0
			for rowIndex, node in ipairs(visible) do
				local info = node.info
				local entryID = info.activeEntryID
				if not entryID and info.activeEntry then
					entryID = info.activeEntry.entryID or info.activeEntry.ID
				end
				local entryInfo
				if entryID and type(C_Traits.GetEntryInfo) == "function" then
					entryInfo = C_Traits.GetEntryInfo(configID, entryID)
				elseif info.entryIDs and #info.entryIDs == 1 and type(C_Traits.GetEntryInfo) == "function" then
					entryInfo = C_Traits.GetEntryInfo(configID, info.entryIDs[1])
				end
				local name, icon = ReadSpell(entryInfo and entryInfo.definitionID)
				local rank = tonumber(info.ranksPurchased or info.activeRank)
				local maxRank = tonumber(info.maxRanks)
				if rank then spent = spent + rank end
				local row = CreateFrame("Frame", nil, panel)
				row:SetSize(panelWidth - 14, 30)
				row:SetPoint("TOPLEFT", 7, -47 - ((rowIndex - 1) * 33))
				local rowBG = row:CreateTexture(nil, "BACKGROUND")
				rowBG:SetAllPoints()
				rowBG:SetColorTexture(
					rank and rank > 0 and colors[1] * 0.24 or PANEL_LIGHT[1],
					rank and rank > 0 and colors[2] * 0.24 or PANEL_LIGHT[2],
					rank and rank > 0 and colors[3] * 0.24 or PANEL_LIGHT[3],
					0.96
				)
				local talentIcon = row:CreateTexture(nil, "ARTWORK")
				talentIcon:SetSize(22, 22)
				talentIcon:SetPoint("LEFT", 4, 0)
				if icon then talentIcon:SetTexture(icon) end
				local label = name or (info.entryIDs and #info.entryIDs > 1 and L["Unselected choice"] or format(L["Talent node %d"], node.id))
				local talentName = S:FontString(row, 9, nil, S.media.font, nil, "LEFT")
				talentName:SetPoint("LEFT", talentIcon, "RIGHT", 5, 0)
				talentName:SetPoint("RIGHT", row, "RIGHT", -42, 0)
				talentName:SetText(label)
				talentName:SetTextColor(0.88, 0.89, 0.91)
				local points = S:FontString(row, 9, nil, S.media.font, nil, "RIGHT")
				points:SetPoint("RIGHT", row, "RIGHT", -4, 0)
				points:SetText(rank and (maxRank and format("%d/%d", rank, maxRank) or tostring(rank)) or "?")
				points:SetTextColor(rank and rank > 0 and colors[1] or 0.58, rank and rank > 0 and colors[2] or 0.60, rank and rank > 0 and colors[3] or 0.64)
			end
			totalSpent = totalSpent + spent
			local summary = S:FontString(panel, 9, nil, S.media.font, nil, "LEFT")
			summary:SetPoint("TOPLEFT", 9, -29)
			summary:SetText(format(L["%d ranks purchased"], spent))
			summary:SetTextColor(0.62, 0.64, 0.68)
			local height = 55 + (#visible * 33)
			panel:SetHeight(height)
			contentHeight = math.max(contentHeight, height)
		end
	end
	if contentHeight > 0 then
		local total = S:FontString(parent, 11, "OUTLINE", S.media.font, nil, "LEFT")
		total:SetPoint("TOPLEFT", 0, 0)
		total:SetText(format(L["Active ranks: %d"], totalSpent))
		total:SetTextColor(colors[1], colors[2], colors[3])
		for _, child in ipairs({ parent:GetChildren() }) do
			if child ~= total and child.SetPoint and child.GetPoint then
				local point, relativeTo, relativePoint, x, y = child:GetPoint(1)
				if point == "TOPLEFT" and relativeTo == parent then
					child:ClearAllPoints()
					child:SetPoint("TOPLEFT", x or 0, (y or 0) - 22)
				end
			end
		end
		return contentHeight + 22
	end
	return false
end

function D.DrawCurrentTalents(parent, colors, L)
	local height = DrawModernTalents(parent, colors, L)
	if height == nil then height = DrawClassicTalents(parent, colors, L) end
	return height
end


-------------------------------------------------------------------------------
-- window state / helpers
-------------------------------------------------------------------------------
local PAGES = {
	{ "overview", "Overview" }, { "classes", "Classes" }, { "races", "Races" },
	{ "caps", "Stat Caps" }, { "trees", "Talent Trees" }, { "talents", "My Talents" }, { "guides", "Guides" },
}
local ROLE_LABEL = { TANK = "Tank", HEALER = "Healer", DPS = "DPS" }
local ROLE_COLOR = { TANK = { 0.40, 0.62, 1.0 }, HEALER = { 0.35, 0.85, 0.45 }, DPS = { 1.0, 0.48, 0.36 } }
local FACTION_COLOR = { Alliance = { 0.45, 0.62, 1.0 }, Horde = { 1.0, 0.38, 0.33 }, Both = { 0.82, 0.82, 0.86 } }
local ICON_SHEET = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local TBC_CLASSES = { "DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR" }

local WIN_W, WIN_H, SIDE_W = 980, 640, 160
local CONTENT_W = 744

local mainFrame, scrollFrame, scrollChild, contentTitle, searchBox, thumb, track
local sideButtons = {}
local root
local page, selClass, selRace, searchText = "overview", nil, nil, ""
local guideClass, guideSpec
local settingSearch

local function Hex(c) return format("|cff%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255) end

local function ClassColor(file)
	local t = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS or {})[file]
	if t then return { t.r, t.g, t.b } end
	return { 1, 1, 1 }
end

local function ClassName(file)
	local c = TD.classes[file]
	local name = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[file]
	if type(name) ~= "string" then name = L[c and c.name or file] end
	return name
end

local function SetClassIcon(tex, file)
	tex:SetTexture(ICON_SHEET)
	local t = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[file]
	if t then tex:SetTexCoord(t[1], t[2], t[3], t[4]) else tex:SetTexCoord(0, 1, 0, 1) end
end

local function TranslateList(value)
	if not value then return "" end
	local out = {}
	for part in value:gmatch("[^,]+") do out[#out + 1] = L[part:match("^%s*(.-)%s*$")] end
	return table.concat(out, ", ")
end

local function TranslateEach(list)
	local out = {}
	for _, v in ipairs(list or {}) do out[#out + 1] = L[v] end
	return table.concat(out, ", ")
end

local function GetClientInfo()
	local _, _, _, interface = GetBuildInfo()
	interface = tonumber(interface) or 0
	local steps = {
		{ 120000, 12, "Retail" }, { 110000, 11, "Retail" }, { 100000, 10, "Retail" }, { 90000, 9, "Retail" },
		{ 80000, 8, "Retail" }, { 70000, 7, "Retail" }, { 60000, 6, "Retail" }, { 50500, 5, "Mists of Pandaria Classic" },
		{ 40400, 4, "Cataclysm Classic" }, { 30400, 3, "Wrath Classic" }, { 20500, 2, "Burning Crusade Classic" },
		{ 11500, 1, "Classic" },
	}
	for _, s in ipairs(steps) do
		if interface >= s[1] then return s[2], s[3], interface end
	end
	return 1, "Classic", interface
end

local function PlayerClassFile()
	local _, file = UnitClass("player")
	return file
end

local function ClassRoles(file)
	local c = TD.classes[file]
	if not c then return "" end
	if c.specs then
		local seen, list = {}, {}
		for _, s in ipairs(c.specs) do
			if not seen[s.role] then seen[s.role] = true list[#list + 1] = L[ROLE_LABEL[s.role]] end
		end
		return table.concat(list, ", ")
	end
	return TranslateList(c.roles)
end

local function ClassIndex(file)
	for i, f in ipairs(TBC_CLASSES) do if f == file then return i end end
end

-- BisGuide hooks ------------------------------------------------------------
local function BG() local m = S:GetModule("BisGuide") return m and m.initialized and m or nil end

local function OpenBis(file, specName)
	local bg, ci = BG(), ClassIndex(file)
	if not (bg and ci and bg.OpenBrowser) then S:Print(L["BiS Guide"] .. ": " .. L["not available"]) return end
	local si
	if specName and bg.SpecIndex then
		local ok, v = pcall(bg.SpecIndex, bg, ci, specName)
		si = ok and v or nil
	end
	bg:OpenBrowser(ci, si)
end

local function OpenWindow(kind)
	local bg = BG()
	if not (bg and bg.ToggleWindow) then S:Print(L["BiS Guide"] .. ": " .. L["not available"]) return end
	bg:ToggleWindow(kind)
end

-- widgets -------------------------------------------------------------------
local function MakeButton(parent, text, width, height, onClick)
	local b = CreateFrame("Button", nil, parent, S.BackdropTemplate)
	b:SetSize(width, height)
	S:SetTemplate(b, "Default")
	b.label = AddLabel(b, text, 11, TEXT)
	b.label:SetPoint("CENTER")
	b.label:SetJustifyH("CENTER")
	b:SetScript("OnClick", onClick)
	b:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.9) end)
	b:SetScript("OnLeave", function(self)
		if self.selected then self:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.9)
		else self:SetBackdropBorderColor(0.17, 0.18, 0.23, 1) end
	end)
	return b
end

local function SetSelected(b, on)
	b.selected = on
	b.label:SetTextColor(on and GOLD[1] or TEXT[1], on and GOLD[2] or TEXT[2], on and GOLD[3] or TEXT[3])
	if on then b:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.9) else b:SetBackdropBorderColor(0.17, 0.18, 0.23, 1) end
end

-- vertical layout context ------------------------------------------------------
local Ctx = {}
Ctx.__index = Ctx
local function NewCtx(parent, width) return setmetatable({ p = parent, y = 0, w = width }, Ctx) end

function Ctx:Gap(n) self.y = self.y + (n or 8) end

function Ctx:Header(text)
	local fs = AddLabel(self.p, text, 12, GOLD)
	fs:SetPoint("TOPLEFT", 0, -self.y)
	local line = self.p:CreateTexture(nil, "ARTWORK")
	line:SetPoint("TOPLEFT", 0, -(self.y + 18))
	line:SetSize(self.w, 1)
	line:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.45)
	self.y = self.y + 28
end

function Ctx:Text(text, size, color, indent, gap)
	local fs = AddLabel(self.p, text, size or 11, color or TEXT)
	fs:SetWordWrap(true)
	fs:SetJustifyH("LEFT")
	fs:SetWidth(self.w - (indent or 0))
	fs:SetPoint("TOPLEFT", indent or 0, -self.y)
	local h = fs:GetStringHeight()
	if not h or h < 12 then h = 12 end
	self.y = self.y + h + (gap or 4)
	return fs
end

function Ctx:Row(label, value, labelW)
	labelW = labelW or 130
	local a = AddLabel(self.p, label, 11, MUTED)
	a:SetPoint("TOPLEFT", 0, -self.y)
	a:SetWidth(labelW)
	local b = AddLabel(self.p, value, 11, TEXT)
	b:SetWordWrap(true)
	b:SetWidth(self.w - labelW - 8)
	b:SetPoint("TOPLEFT", labelW + 8, -self.y)
	local h = b:GetStringHeight()
	if not h or h < 12 then h = 12 end
	self.y = self.y + h + 5
end

function Ctx:Bullets(list, color)
	for _, item in ipairs(list or {}) do self:Text("•  " .. L[item], 11, color or TEXT, 6, 3) end
end

function Ctx:Back(onClick)
	local b = MakeButton(self.p, "<  " .. L["Back"], 96, 20, onClick)
	b:SetPoint("TOPLEFT", 0, -self.y)
	self.y = self.y + 30
end

function Ctx:BeginCard(clickable)
	local f = CreateFrame(clickable and "Button" or "Frame", nil, self.p, S.BackdropTemplate)
	f:SetPoint("TOPLEFT", 0, -self.y)
	f:SetWidth(self.w)
	f:SetHeight(40)
	S:SetTemplate(f, "Default", "TOP")
	local box = CreateFrame("Frame", nil, f)
	box:SetPoint("TOPLEFT", 12, -10)
	box:SetSize(self.w - 24, 10)
	return f, NewCtx(box, self.w - 24)
end

function Ctx:EndCard(card, inner, minH)
	local h = max(minH or 0, inner.y + 20)
	card:SetHeight(h)
	self.y = self.y + h + 8
end

local function Clear()
	if root then root:Hide() root:SetParent(nil) end
	root = nil
end

-------------------------------------------------------------------------------
-- pages
-------------------------------------------------------------------------------
local Render

local pendingItems
local treeClass, treeMode, treeFocus, treeSig
local TreeIndexForSpec
local itemNames = {}
local function ItemLabel(id)
	if itemNames[id] then return itemNames[id] end
	local name = GetItemInfo and GetItemInfo(id)
	if not name and C_Item and C_Item.GetItemNameByID then name = C_Item.GetItemNameByID(id) end
	if type(name) == "string" then itemNames[id] = name return name end
	if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
	pendingItems = true
	return "[" .. id .. "]"
end

local function ItemList(ids)
	local t = {}
	for _, id in ipairs(ids or {}) do t[#t + 1] = ItemLabel(id) end
	return table.concat(t, ", ")
end

local SLOT_NAME = {
	head = HEAD_SLOT, neck = NECK_SLOT, shoulder = SHOULDER_SLOT, back = BACK_SLOT, chest = CHEST_SLOT,
	wrist = WRIST_SLOT, hands = HANDS_SLOT, waist = WAIST_SLOT, legs = LEGS_SLOT, feet = FEET_SLOT,
	["finger 1"] = FINGER0SLOT, ["finger 2"] = FINGER1SLOT, ["trinket 1"] = TRINKET0SLOT, ["trinket 2"] = TRINKET1SLOT,
	weapon = MAINHANDSLOT, ["off hand"] = SECONDARYHANDSLOT, ranged = RANGEDSLOT,
}

-- enchants and gems from the best-in-slot list of the newest phase
local function BisPicks(data, cidx, si)
	local phases = data.phases or {}
	local slots = data.bis and data.bis[cidx] and data.bis[cidx][si] and data.bis[cidx][si][#phases]
	if not slots then return nil end
	local enchantNames = {}
	for name, e in pairs(data.enchants or {}) do
		if type(e) == "table" and e.i then enchantNames[e.i] = name end
	end
	local enchants, gemCount, gemOrder = {}, {}, {}
	for _, se in ipairs(slots) do
		local it = se.i and se.i[1]
		if it then
			local e = it[3]
			if type(e) == "table" and e.i then
				local label = enchantNames[e.i]
				if not label then
					if e.item then label = ItemLabel(e.i)
					else label = (GetSpellInfo and GetSpellInfo(e.i)) or ("[" .. e.i .. "]") end
				end
				enchants[#enchants + 1] = (type(SLOT_NAME[se.s]) == "string" and SLOT_NAME[se.s] or tostring(se.s)) .. ": " .. tostring(label)
			end
			if type(it[4]) == "table" then
				for _, gid in ipairs(it[4]) do
					if type(gid) == "number" then
						if not gemCount[gid] then gemCount[gid] = 0 gemOrder[#gemOrder + 1] = gid end
						gemCount[gid] = gemCount[gid] + 1
					end
				end
			end
		end
	end
	table.sort(gemOrder, function(a, b) return gemCount[a] > gemCount[b] end)
	local gems = {}
	for i = 1, math.min(4, #gemOrder) do gems[#gems + 1] = ItemLabel(gemOrder[i]) .. " x" .. gemCount[gemOrder[i]] end
	return enchants, gems
end

local function SpecBlock(ctx, file, s)
	local card, inner = ctx:BeginCard()
	local rc = ROLE_COLOR[s.role] or TEXT
	local head = AddLabel(inner.p, L[s.name], 13, ClassColor(file))
	head:SetPoint("TOPLEFT", 0, 0)
	local tag = AddLabel(inner.p, "[" .. L[ROLE_LABEL[s.role]] .. "]", 11, rc)
	tag:SetPoint("LEFT", head, "RIGHT", 8, 0)
	inner.y = 22
	inner:Row(L["Primary stat"], L[s.primary], 110)
	local stats = {}
	for _, st in ipairs(s.stats) do stats[#stats + 1] = L[st] end
	inner:Row(L["Stat priority"], table.concat(stats, "  >  "), 110)
	inner:Row(L["Cap"], L[s.cap] or s.cap, 110)
	local data = _G.SUIBisData
	local cidx = ClassIndex(file)
	if data and cidx then
		local si
		for i, n in ipairs(data.specs and data.specs[cidx] or {}) do if n == s.name then si = i end end
		local cons = si and data.consumes and data.consumes[cidx] and data.consumes[cidx][si]
		if cons then
			if cons.bestFlask then inner:Row(L["Flask"], ItemList(cons.bestFlask), 110) end
			if cons.bestFood then inner:Row(L["Food"], ItemList(cons.bestFood), 110) end
			if cons.bestPotion then inner:Row(L["Potion"], ItemList(cons.bestPotion), 110) end
		end
		if si then
			local enchants, gems = BisPicks(data, cidx, si)
			if enchants and #enchants > 0 then inner:Row(L["Enchants"], table.concat(enchants, ";  "), 110) end
			if gems and #gems > 0 then inner:Row(L["Gems"], table.concat(gems, ",  "), 110) end
		end
		local rot = si and data.rot and data.rot[cidx] and data.rot[cidx][si]
		if rot and rot.steps then
			for n, step in ipairs(rot.steps) do
				if n > 8 then break end
				local parts = {}
				for _, seg in ipairs(step) do parts[#parts + 1] = seg.v or "" end
				inner:Row(n == 1 and L["Rotation"] or "", n .. ". " .. table.concat(parts), 110)
			end
		end
	end
	if file and ClassIndex(file) then
		local b = MakeButton(card, L["BiS Guide"], 96, 20, function() OpenBis(file, s.name) end)
		b:SetPoint("TOPRIGHT", -12, -10)
		local tb = MakeButton(card, L["Talent Trees"], 100, 20, function()
			local data = _G.SUIBisData
			local ti = data and data.tal and data.tal[ClassIndex(file)] and TreeIndexForSpec(data, ClassIndex(file), s.name)
			treeClass, treeMode, treeFocus, treeSig, page = file, "calc", ti, nil, "trees"
			Render()
		end)
		tb:SetPoint("RIGHT", b, "LEFT", -6, 0)
	end
	ctx:EndCard(card, inner)
end

local function ClassDetail(ctx, file)
	local c = TD.classes[file]
	ctx.title = ClassName(file)
	ctx:Back(function() selClass = nil Render(true) end)
	if ClassIndex(file) then
		local tb = MakeButton(ctx.p, L["Talent Trees"], 120, 20, function() treeClass, treeMode, page = file, "all", "trees" Render() end)
		tb:SetPoint("TOPLEFT", 104, -(ctx.y - 30))
	end

	local card, inner = ctx:BeginCard()
	local icon = card:CreateTexture(nil, "ARTWORK")
	icon:SetSize(40, 40)
	icon:SetPoint("TOPLEFT", 12, -10)
	SetClassIcon(icon, file)
	local name = AddLabel(card, ClassName(file), 16, ClassColor(file))
	name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -2)
	local sub = AddLabel(card, L["Roles"] .. ": " .. ClassRoles(file) .. "    " .. L["Resource"] .. ": " .. TranslateList(c.resource), 11, MUTED)
	sub:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -5)
	card:SetHeight(64)
	inner.p:SetHeight(1)
	ctx.y = ctx.y + 72

	if not c.specs then
		ctx:Header(L["Overview"])
		ctx:Text(L[c.overview or ""], 11, TEXT)
		ctx:Row(L["Armor type"], TranslateEach(c.armor))
		ctx:Row(L["Available since"], L[TD.expansions[c.since] or ""])
		return
	end

	ctx:Header(L["Equipment"])
	ctx:Row(L["Armor type"], TranslateEach(c.armor))
	ctx:Row(L["Weapons"], TranslateEach(c.weapons))
	for _, e in ipairs(c.extra or {}) do ctx:Row("", L[e]) end
	ctx:Gap(6)

	ctx:Header(L["Reagents & consumables"])
	if #c.reagents == 0 then
		ctx:Text(L["No class reagents."], 11, MUTED)
	else
		for _, r in ipairs(c.reagents) do ctx:Row(L[r[1]], L[r[2]], 260) end
	end
	ctx:Gap(6)

	ctx:Header(L["Specializations"])
	for _, s in ipairs(c.specs) do SpecBlock(ctx, file, s) end
	ctx:Gap(2)

	local rec = TD.recommend and TD.recommend[file]
	if rec then
		ctx:Header(L["Best races and professions"])
		if rec.races then for _, line in ipairs(rec.races) do ctx:Row(L["Races"], L[line], 90) end end
		if rec.professions then for _, line in ipairs(rec.professions) do ctx:Row(L["Professions"], L[line], 90) end end
		ctx:Gap(6)
	end

	ctx:Header(L["Raid and group utility"])
	ctx:Bullets(c.utility)
	ctx:Gap(6)

	ctx:Header(L["Playable races"])
	local names = {}
	for _, r in ipairs(TD.races) do
		if r.classes then
			for _, cf in ipairs(r.classes) do
				if cf == file then names[#names + 1] = Hex(FACTION_COLOR[r.faction] or TEXT) .. L[r.name] .. "|r" end
			end
		end
	end
	ctx:Text(table.concat(names, ",  "), 11, TEXT)
end

local function ClassList(ctx)
	ctx.title = L["Classes"]
	local expansion = GetClientInfo()
	local q = searchText:lower()
	local shown = 0
	for _, file in ipairs(TD.classOrder) do
		local c = TD.classes[file]
		local hay = (ClassName(file) .. " " .. ClassRoles(file) .. " " .. TranslateList(c.resource) .. " " .. TranslateEach(c.armor)):lower()
		if c.since <= expansion and (q == "" or hay:find(q, 1, true)) then
			shown = shown + 1
			local card = ctx:BeginCard(true)
			card:SetHeight(58)
			local icon = card:CreateTexture(nil, "ARTWORK")
			icon:SetSize(36, 36)
			icon:SetPoint("LEFT", 12, 0)
			SetClassIcon(icon, file)
			local n = AddLabel(card, ClassName(file), 14, ClassColor(file))
			n:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, 0)
			local sub = AddLabel(card, ClassRoles(file) .. "   |   " .. TranslateEach(c.armor) .. "   |   " .. TranslateList(c.resource), 10, MUTED)
			sub:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 12, 0)
			sub:SetWidth(ctx.w - 80)
			card:SetScript("OnClick", function() selClass = file Render() end)
			card:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.9) end)
			card:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.17, 0.18, 0.23, 1) end)
			ctx.y = ctx.y + 58 + 8
		end
	end
	if shown == 0 then ctx:Text(L["No matching entries found."], 11, MUTED) end
end

local function RaceDetail(ctx, race)
	ctx.title = L[race.name]
	ctx:Back(function() selRace = nil Render(true) end)
	local fc = FACTION_COLOR[race.faction] or TEXT
	local card, inner = ctx:BeginCard()
	local n = AddLabel(card, L[race.name], 16, fc)
	n:SetPoint("TOPLEFT", 12, -10)
	local sub = AddLabel(card, L[race.faction] .. (race.zone and ("   |   " .. L["Starting zone"] .. ": " .. L[race.zone]) or "")
		.. "   |   " .. L["Available since"] .. ": " .. L[TD.expansions[race.since] or ""], 11, MUTED)
	sub:SetPoint("TOPLEFT", n, "BOTTOMLEFT", 0, -5)
	card:SetHeight(56)
	ctx.y = ctx.y + 64
	if not race.racials then
		ctx:Header(L["Racial abilities"])
		ctx:Text(TranslateList(race.traits), 11, TEXT)
		return
	end
	ctx:Header(L["Playable classes"])
	local names = {}
	for _, cf in ipairs(race.classes) do names[#names + 1] = Hex(ClassColor(cf)) .. ClassName(cf) .. "|r" end
	ctx:Text(table.concat(names, ",  "), 11, TEXT)
	ctx:Gap(6)
	ctx:Header(L["Racial abilities"])
	for _, r in ipairs(race.racials) do
		local only = ""
		if r[3] then
			local t = {}
			for token in r[3]:gmatch("[A-Z]+") do t[#t + 1] = ClassName(token) end
			only = "  " .. Hex(MUTED) .. "(" .. L["only"] .. " " .. table.concat(t, ", ") .. ")|r"
		end
		ctx:Row(L[r[1]], L[r[2]] .. only, 170)
	end
end

local function RaceList(ctx)
	ctx.title = L["Races"]
	local expansion = GetClientInfo()
	local q = searchText:lower()
	local shown = 0
	for _, race in ipairs(TD.races) do
		local classesText = ""
		if race.classes then
			local t = {}
			for _, cf in ipairs(race.classes) do t[#t + 1] = Hex(ClassColor(cf)) .. ClassName(cf) .. "|r" end
			classesText = table.concat(t, ", ")
		end
		local hay = (L[race.name] .. " " .. L[race.faction] .. " " .. (race.traits and TranslateList(race.traits) or "")):lower()
		if race.racials then for _, r in ipairs(race.racials) do hay = hay .. " " .. L[r[1]]:lower() end end
		if race.since <= expansion and (q == "" or hay:find(q, 1, true)) then
			shown = shown + 1
			local card = ctx:BeginCard(true)
			card:SetHeight(52)
			local fc = FACTION_COLOR[race.faction] or TEXT
			local bar = card:CreateTexture(nil, "ARTWORK")
			bar:SetPoint("TOPLEFT", 1, -1)
			bar:SetPoint("BOTTOMLEFT", 1, 1)
			bar:SetWidth(3)
			bar:SetColorTexture(fc[1], fc[2], fc[3], 0.9)
			local n = AddLabel(card, L[race.name], 14, fc)
			n:SetPoint("TOPLEFT", 14, -8)
			local detail = classesText ~= "" and classesText or TranslateList(race.traits)
			local sub = AddLabel(card, L[race.faction] .. "   |   " .. detail, 10, MUTED)
			sub:SetPoint("TOPLEFT", n, "BOTTOMLEFT", 0, -4)
			sub:SetWidth(ctx.w - 30)
			card:SetScript("OnClick", function() selRace = race Render() end)
			card:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.9) end)
			card:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.17, 0.18, 0.23, 1) end)
			ctx.y = ctx.y + 52 + 8
		end
	end
	if shown == 0 then ctx:Text(L["No matching entries found."], 11, MUTED) end
end

local function LiveValues(ctx)
	local function num(f, ...) if type(f) ~= "function" then return nil end local ok, v = pcall(f, ...) return ok and tonumber(v) or nil end
	local rows = {}
	local function add(label, value, cap, unit)
		if value == nil then return end
		local ok = cap and value >= cap
		local col = cap and (ok and "|cff40ff40" or "|cffffcc00") or "|cffffffff"
		rows[#rows + 1] = { label, format("%s%s|r%s", col, tostring(floor(value * 100 + 0.5) / 100), cap and ("   |cff888888/ " .. cap .. (unit or "") .. "|r") or "") }
	end
	if CR_HIT_MELEE then add(L["Melee hit rating"], num(GetCombatRating, CR_HIT_MELEE), 142) end
	if CR_HIT_RANGED then add(L["Ranged hit rating"], num(GetCombatRating, CR_HIT_RANGED), 142) end
	if CR_HIT_SPELL then add(L["Spell hit rating"], num(GetCombatRating, CR_HIT_SPELL), 202) end
	add(L["Expertise"], num(GetExpertise), 26)
	if UnitDefense then
		local base, mod = UnitDefense("player")
		if type(base) == "number" then add(L["Defense"], base + (tonumber(mod) or 0), 490) end
	end
	if CR_RESILIENCE_CRIT_TAKEN then add(L["Resilience rating"], num(GetCombatRating, CR_RESILIENCE_CRIT_TAKEN)) end
	if CR_CRIT_MELEE then add(L["Melee crit rating"], num(GetCombatRating, CR_CRIT_MELEE)) end
	if #rows == 0 then
		ctx:Text(L["These values are not available on this client."], 11, MUTED)
		return
	end
	for _, r in ipairs(rows) do ctx:Row(r[1], r[2], 190) end
	ctx:Text(L["Green means the raid-boss cap from the table above is reached (before talent and group bonuses)."], 10, MUTED)
end

local function CapsPage(ctx)
	ctx.title = L["Stat Caps"]
	ctx:Header(L["Caps against raid bosses (level 73)"])
	for _, row in ipairs(TD.caps) do
		local card, inner = ctx:BeginCard()
		local h = AddLabel(inner.p, L[row[1]], 12, GOLD)
		h:SetPoint("TOPLEFT", 0, 0)
		local v = AddLabel(inner.p, L[row[2]], 12, TEXT)
		v:SetPoint("TOPRIGHT", 0, 0)
		v:SetJustifyH("RIGHT")
		inner.y = 20
		inner:Text(L[row[3]], 10, MUTED, 0, 0)
		ctx:EndCard(card, inner)
	end
	ctx:Gap(4)
	ctx:Header(L["Rating needed per 1% (level 70)"])
	local line = {}
	for _, r in ipairs(TD.ratings) do line[#line + 1] = L[r[1]] .. ": |cffffffff" .. r[2] .. "|r" end
	ctx:Text(table.concat(line, "     "), 11, MUTED)
	ctx:Gap(6)
	ctx:Header(L["Your current values"])
	LiveValues(ctx)
	ctx:Gap(8)
	ctx:Header(L["Sources"])
	ctx:Bullets(TD.sources, MUTED)
end

local function OverviewPage(ctx)
	ctx.title = L["TalentAtlas"]
	local file = PlayerClassFile()
	local expansion, client, interface = GetClientInfo()
	local card = ctx:BeginCard()
	card:SetHeight(70)
	local icon = card:CreateTexture(nil, "ARTWORK")
	icon:SetSize(44, 44)
	icon:SetPoint("LEFT", 12, 0)
	SetClassIcon(icon, file)
	local n = AddLabel(card, (UnitName("player") or "?"), 16, ClassColor(file))
	n:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -2)
	local sub = AddLabel(card, format("%s  |  %s  |  %s %s", ClassName(file) or "?", select(1, UnitRace("player")) or "?", L["Level"], tostring(UnitLevel("player") or "?")), 11, MUTED)
	sub:SetPoint("TOPLEFT", n, "BOTTOMLEFT", 0, -5)
	local cl = AddLabel(card, format("%s  %s  (%s)", L[client] or client, L["Version"] .. " " .. interface, L[TD.expansions[expansion] or ""]), 10, MUTED)
	cl:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 12, 0)
	ctx.y = ctx.y + 78

	local c = TD.classes[file]
	if c and c.specs then
		ctx:Header(L["Your class at a glance"])
		ctx:Row(L["Armor type"], TranslateEach(c.armor))
		ctx:Row(L["Resource"], TranslateList(c.resource))
		if #c.reagents > 0 then
			local t = {}
			for _, r in ipairs(c.reagents) do t[#t + 1] = L[r[1]] end
			ctx:Row(L["Reagents"], table.concat(t, "; "))
		else
			ctx:Row(L["Reagents"], L["No class reagents."])
		end
		for _, s in ipairs(c.specs) do
			ctx:Row(L[s.name], Hex(ROLE_COLOR[s.role]) .. L[ROLE_LABEL[s.role]] .. "|r  " .. L[s.cap], 130)
		end
		ctx:Gap(8)
	end

	ctx:Header(L["Quick access"])
	local x = 0
	local function Quick(text, w, fn)
		local b = MakeButton(ctx.p, text, w, 24, fn)
		b:SetPoint("TOPLEFT", x, -ctx.y)
		x = x + w + 8
	end
	Quick(L["Your class guide"], 130, function() selClass = file page = "classes" Render() end)
	Quick(L["Stat Caps"], 100, function() page = "caps" Render() end)
	Quick(L["Talent Trees"], 110, function() treeClass, treeMode, page = file, "all", "trees" Render() end)
	Quick(L["BiS Guide"], 100, function() OpenBis(file) end)
	Quick(L["Consumables"], 110, function() OpenWindow("consumes") end)
	Quick(L["Rotation"], 100, function() OpenWindow("rotation") end)
	Quick(L["Talent builds"], 120, function() OpenWindow("talents") end)
	ctx.y = ctx.y + 36
	ctx:Text(L["Select a class or race to explore its guide."], 10, MUTED)
end

local function TalentsPage(ctx)
	ctx.title = L["My Talents"]
	local height = D.DrawCurrentTalents(ctx.p, GOLD, L)
	if height == nil then
		ctx:Text(L["Talent APIs are not available on this client."], 11, MUTED)
	elseif height == false then
		ctx:Text(L["No active talent configuration was found."], 11, MUTED)
	else
		ctx.y = ctx.y + height
	end
end

-- talent trees of every class: an interactive calculator (data: BisGuide's
-- SUIBisData.tal / .builds). Left click adds a point, right click removes one.
treeClass, treeMode, treeFocus, treeSig = nil, "calc", nil, nil
local treePts = {}

local MAX_POINTS = 61
local TREE_W, TREE_GAP, ICON, STEP_X, STEP_Y = 232, 6, 38, 54, 44

local function MyTalentMap()
	local map = {}
	if type(GetNumTalentTabs) ~= "function" or type(GetTalentInfo) ~= "function" then return map end
	for tab = 1, (GetNumTalentTabs() or 0) do
		map[tab] = {}
		for i = 1, (GetNumTalents and GetNumTalents(tab) or 0) do
			local _, _, tier, col, rank = GetTalentInfo(tab, i)
			if tier and col then map[tab][tier .. ":" .. col] = { idx = i, rank = tonumber(rank) or 0 } end
		end
	end
	return map
end

local function TreeTotal(ti)
	local n = 0
	for _, v in pairs(treePts[ti] or {}) do n = n + v end
	return n
end

local function AllTotal()
	local n = 0
	for ti in pairs(treePts) do n = n + TreeTotal(ti) end
	return n
end

function TA:GetTalentCalcState()
	local points = {}
	for ti, tree in pairs(treePts) do
		points[ti] = {}
		for i, rank in pairs(tree) do points[ti][i] = rank end
	end
	return { class = treeClass, mode = treeMode, focus = treeFocus, total = AllTotal(), points = points }
end

local function RowPoints(td, pts, beforeRow)
	local n = 0
	for i, t in ipairs(td.tal or {}) do
		if (t.row or 1) < beforeRow then n = n + (pts[i] or 0) end
	end
	return n
end

local function TierOpen(td, pts, row) return RowPoints(td, pts, row) >= ((row or 1) - 1) * 5 end

-- prerequisite lookup: TD.prereqs[class][tree][talentIdx] = {preIdx, neededRank}
local function PrereqMap()
	return TD.prereqs and treeClass and TD.prereqs[treeClass] or nil
end

local function PrereqFor(ti, i)
	local m = PrereqMap()
	local e = m and m[ti] and m[ti][i]
	return e and e[1] or nil, e and e[2] or nil
end

local function CanAdd(ti, td, i)
	local t = td.tal[i]
	local pts = treePts[ti]
	if (pts[i] or 0) >= (t.r or 1) then return false, L["Talent is at maximum rank."] end
	if AllTotal() >= MAX_POINTS then return false, format(L["All %d talent points are spent."], MAX_POINTS) end
	if not TierOpen(td, pts, t.row or 1) then return false, format(L["Needs %d points in this tree first."], ((t.row or 1) - 1) * 5) end
	local pre, qty = PrereqFor(ti, i)
	if pre and (pts[pre] or 0) < qty then
		local name = td.tal[pre] and td.tal[pre].n or "?"
		return false, format(L["Requires %s (rank %d)."], name, qty)
	end
	return true
end

local function CanRemove(ti, td, i)
	local pts = treePts[ti]
	if (pts[i] or 0) <= 0 then return false end
	pts[i] = pts[i] - 1
	local ok = true
	for j, t in ipairs(td.tal) do
		if (pts[j] or 0) > 0 and not TierOpen(td, pts, t.row or 1) then ok = false break end
	end
	if ok then
		local m = PrereqMap()
		for dep, e in pairs((m and m[ti]) or {}) do
			if e[1] == i and (pts[dep] or 0) > 0 and (pts[i] or 0) < e[2] then ok = false break end
		end
	end
	pts[i] = pts[i] + 1
	return ok
end

local function LoadPoints(data, ci, mode, file)
	treePts = {}
	for ti = 1, #data.tal[ci] do treePts[ti] = {} end
	if mode == "mine" then
		local map = MyTalentMap()
		for ti, td in ipairs(data.tal[ci]) do
			for i, t in ipairs(td.tal or {}) do
				local e = map[ti] and map[ti][(t.row or 0) .. ":" .. (t.col or 0)]
				if e and e.rank > 0 then treePts[ti][i] = e.rank end
			end
		end
	elseif mode:sub(1, 2) == "b:" then
		local si, bi = mode:match("^b:(%d+):(%d+)$")
		local specName = data.specs and data.specs[ci] and data.specs[ci][tonumber(si)]
		local bld = specName and data.builds and data.builds[ci] and data.builds[ci][specName] and data.builds[ci][specName][tonumber(bi)]
		for ti = 1, #data.tal[ci] do
			local src = bld and bld.t and bld.t[ti]
			if src then
				for i = 1, #(data.tal[ci][ti].tal or {}) do
					-- BisGuide talent data is indexed from zero (see Extras.lua).
					-- Falling back to src[i] shifts points into the next talent
					-- whenever a talent is intentionally unspent.
					local v = src[i - 1]
					if v and v > 0 then treePts[ti][i] = v end
				end
			end
		end
	end
end

function TreeIndexForSpec(data, ci, specName)
	local word = (specName or ""):lower():match("^%S+")
	if not word then return nil end
	for ti, td in ipairs(data.tal[ci] or {}) do
		if (td.tree or ""):lower():find(word, 1, true) then return ti end
	end
end

local function DrawTree(ctx, x, ti, td, data, ci, onChange)
	local height = 40 + 9 * STEP_Y + 8
	local panel = CreateFrame("Frame", nil, ctx.p, S.BackdropTemplate)
	panel:SetPoint("TOPLEFT", x, -ctx.y)
	panel:SetSize(TREE_W, height)
	S:SetTemplate(panel, "Default", "TOP")

	local base = td.bg and ("Interface\\TalentFrame\\" .. td.bg .. "-") or nil
	if base then
		for _, q in ipairs({ { "TOPLEFT", "TopLeft" }, { "TOPRIGHT", "TopRight" }, { "BOTTOMLEFT", "BottomLeft" }, { "BOTTOMRIGHT", "BottomRight" } }) do
			local t = panel:CreateTexture(nil, "BACKGROUND")
			t:SetPoint(q[1], 1, q[1]:find("TOP") and -1 or 1)
			t:SetSize(116, 116)
			t:SetTexture(base .. q[2])
			t:SetVertexColor(1, 1, 1, 0.28)
		end
	end

	local pts = treePts[ti]
	local spent, total = TreeTotal(ti), 0
	for i, t in ipairs(td.tal or {}) do
		local talentIndex, talentData = i, t
		local treeIndex, treeData, treePoints = ti, td, pts
		total = total + (talentData.r or 0)
		local rank = treePoints[talentIndex] or 0
		local currentRank = rank
		local open = TierOpen(treeData, treePoints, talentData.row or 1)
		local tierOpen = open
		local b = CreateFrame("Button", nil, panel, S.BackdropTemplate)
		b.suiTalentTree, b.suiTalentIndex = treeIndex, talentIndex
		b:SetSize(ICON, ICON)
		b:SetPoint("TOPLEFT", 12 + ((talentData.col or 1) - 1) * STEP_X, -(40 + ((talentData.row or 1) - 1) * STEP_Y))
		b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		S:SetTemplate(b, "Default")
		local tex = b:CreateTexture(nil, "ARTWORK")
		tex:SetPoint("TOPLEFT", 2, -2)
		tex:SetPoint("BOTTOMRIGHT", -2, 2)
		tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		if talentData.i then tex:SetTexture(talentData.i) end
		-- learned-state ring: 4 thin gold edge lines instead of a fill --
		-- a full-cell WHITE8X8 floods the icon on this client
		local glow = CreateFrame("Frame", nil, b)
		glow:SetAllPoints()
		glow:SetFrameLevel(b:GetFrameLevel() + 1)
		local edges = {}
		for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", "TOP", "TOP", 0, 0, 1 },
							 { "BOTTOMLEFT", "BOTTOMRIGHT", "BOTTOM", "BOTTOM", 0, 0, 1 },
							 { "TOPLEFT", "BOTTOMLEFT", "LEFT", "LEFT", 0, 0, 0 },
							 { "TOPRIGHT", "BOTTOMRIGHT", "RIGHT", "RIGHT", 0, 0, 0 } }) do
			local t = glow:CreateTexture(nil, "OVERLAY")
			t:SetTexture([[Interface\Buttons\WHITE8X8]])
			t:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.85)
			t:ClearAllPoints()
			t:SetPoint(e[1])
			t:SetPoint(e[2])
			if e[3] == "TOP" then t:SetHeight(1)
			elseif e[3] == "BOTTOM" then t:SetHeight(1)
			else t:SetWidth(1) end
			edges[#edges + 1] = t
		end
		glow:Hide()
		b.suiLearned = glow
		local lbl = S:FontString(b, 10, "OUTLINE", S.media.numberFont or S.media.font, nil, "RIGHT")
		lbl:SetPoint("BOTTOMRIGHT", -2, 2)
		tex:SetDesaturated(rank == 0)
		b:SetAlpha((rank > 0 or open) and 1 or 0.45)
		if rank > 0 then
			local full = rank >= (talentData.r or 1)
			lbl:SetText(rank .. "/" .. (talentData.r or 1))
			lbl:SetTextColor(full and 0.3 or 1, full and 1 or 0.82, full and 0.3 or 0.1)
			b.suiLearned:Show()
		else
			if b.suiLearned then b.suiLearned:Hide() end
			lbl:SetText((talentData.r or 1) > 1 and ("0/" .. talentData.r) or "")
			lbl:SetTextColor(0.7, 0.7, 0.7)
		end
		b:SetScript("OnClick", function(_, button)
			if button == "RightButton" then
				if CanRemove(treeIndex, treeData, talentIndex) then
					treePoints[talentIndex] = (treePoints[talentIndex] or 0) - 1
					if treePoints[talentIndex] <= 0 then treePoints[talentIndex] = nil end
					onChange()
				end
			else
				local ok, why = CanAdd(treeIndex, treeData, talentIndex)
				if ok then
					treePoints[talentIndex] = (treePoints[talentIndex] or 0) + 1
					onChange()
				elseif why then
					S:Print(L[td.tree] .. " - " .. (talentData.n or "?") .. ": " .. why)
				end
			end
		end)
		b:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:ClearLines()
			GameTooltip:AddLine(talentData.n or "?", GOLD[1], GOLD[2], GOLD[3])
			GameTooltip:AddLine(format(L["Rank %d / %d"], currentRank, talentData.r or 1), 1, 1, 1)
			GameTooltip:AddLine(format(L["Tier %d"], talentData.row or 1), 0.6, 0.6, 0.65)
			if not tierOpen and currentRank == 0 then
				GameTooltip:AddLine(format(L["Needs %d points in this tree first."], ((talentData.row or 1) - 1) * 5), 1, 0.4, 0.4)
			end
			local pre, qty = PrereqFor(treeIndex, talentIndex)
			if pre then
				local pn = treeData.tal[pre] and treeData.tal[pre].n or "?"
				local met = (treePoints[pre] or 0) >= qty
				GameTooltip:AddLine(format(L["Requires %s (rank %d)."], pn, qty), met and 0.4 or 1, met and 1 or 0.4, met and 0.4 or 0.4)
			end
			GameTooltip:AddLine(L["Left click: add a point  |  Right click: remove one"], 0.55, 0.75, 0.55)
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	end

	-- prerequisite connectors (Wowhead TBC data): L-shaped lines from the
	-- required talent to the dependent one, gold once the rank is met
	local preMap = PrereqMap()
	for dep, e in pairs((preMap and preMap[ti]) or {}) do
		local dt_, pt_ = td.tal[dep], td.tal[e[1]]
		if dt_ and pt_ then
			local met = (pts[e[1]] or 0) >= e[2]
			local r, g, b, a = GOLD[1], GOLD[2], GOLD[3], 0.9
			if not met then r, g, b, a = 0.6, 0.32, 0.32, 0.55 end
			local x1 = 12 + ((pt_.col or 1) - 1) * STEP_X + ICON / 2
			local y1 = 40 + ((pt_.row or 1) - 1) * STEP_Y + ICON
			local x2 = 12 + ((dt_.col or 1) - 1) * STEP_X + ICON / 2
			local y2 = 40 + ((dt_.row or 1) - 1) * STEP_Y + ICON / 2
			local function seg(hx1, hy1, hx2, hy2)
				local t = panel:CreateTexture(nil, "BACKGROUND")
				t:SetColorTexture(r, g, b, a)
				if hx1 == hx2 then
					t:SetSize(2, math.abs(hy2 - hy1))
					t:SetPoint("TOPLEFT", hx1 - 1, -math.min(hy1, hy2))
				else
					t:SetSize(math.abs(hx2 - hx1), 2)
					t:SetPoint("TOPLEFT", math.min(hx1, hx2), -(hy1 - 1))
				end
			end
			if x1 == x2 then
				seg(x1, y1, x1, 40 + ((dt_.row or 1) - 1) * STEP_Y)
			else
				seg(x1, y1, x1, y2)
				seg(x1, y2, x2, y2)
			end
			local mark = panel:CreateTexture(nil, "BACKGROUND")
			mark:SetColorTexture(r, g, b, a)
			mark:SetSize(5, 5)
			mark:SetPoint("CENTER", panel, "TOPLEFT", x2, -y2)
		end
	end

	local head = CreateFrame("Button", nil, panel)
	head:SetPoint("TOPLEFT", 0, 0)
	head:SetPoint("TOPRIGHT", 0, 0)
	head:SetHeight(34)
	head:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	local name = S:FontString(head, 12, "OUTLINE", S.media.font, nil, "LEFT")
	name:SetPoint("TOPLEFT", 12, -10)
	name:SetText(L[td.tree] or td.tree or "?")
	name:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
	local cnt = S:FontString(head, 11, "OUTLINE", S.media.numberFont or S.media.font, nil, "RIGHT")
	cnt:SetPoint("TOPRIGHT", -12, -11)
	cnt:SetText(spent .. " / " .. total)
	cnt:SetTextColor(spent > 0 and 0.35 or 0.62, spent > 0 and 1 or 0.64, spent > 0 and 0.45 or 0.68)
	head:SetScript("OnClick", function(_, button)
		if button == "RightButton" then treePts[ti] = {} onChange() else treeFocus = (treeFocus == ti) and nil or ti onChange(true) end
	end)
	head:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:ClearLines()
		GameTooltip:AddLine(L["Click: focus this tree  |  Right click: reset this tree"], 0.8, 0.8, 0.85)
		GameTooltip:Show()
	end)
	head:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return height
end

local function TreesPage(ctx)
	ctx.title = L["Talent Trees"]
	local data = _G.SUIBisData
	local file = PlayerClassFile()
	treeClass = treeClass or (ClassIndex(file) and file) or "WARRIOR"
	local ci = ClassIndex(treeClass) or 1
	if not (data and data.tal and data.tal[ci]) then
		ctx:Text(L["Talent tree data is not available."], 11, MUTED)
		return
	end
	local sig = treeClass .. ":" .. treeMode
	if sig ~= treeSig then treeSig = sig LoadPoints(data, ci, treeMode, file) end
	local function changed(keepFocus) Render(true) end

	ctx:Header(L["Class"])
	local x = 0
	for _, f in ipairs(TBC_CLASSES) do
		local chosenClass = f
		local b = MakeButton(ctx.p, ClassName(chosenClass), 78, 22, function() treeClass, treeMode, treeFocus, treeSig = chosenClass, "calc", nil, nil Render(true) end)
		b.label:SetTextColor(unpack(ClassColor(f)))
		b:SetPoint("TOPLEFT", x, -ctx.y)
		if chosenClass == treeClass then b.selected = true b:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.9) end
		x = x + 82
		if x + 82 > ctx.w then x = 0 ctx.y = ctx.y + 26 end
	end
	if x ~= 0 then ctx.y = ctx.y + 26 end
	ctx:Gap(4)

	ctx:Header(L["Specialization"])
	x = 0
	local function Btn(text, w, selected, fn)
		if x + w > ctx.w then x = 0 ctx.y = ctx.y + 28 end
		local b = MakeButton(ctx.p, text, w, 22, fn)
		b:SetPoint("TOPLEFT", x, -ctx.y)
		SetSelected(b, selected)
		x = x + w + 6
		return b
	end
	Btn(L["All trees"], 90, treeFocus == nil, function() treeFocus = nil Render(true) end)
	for ti, td in ipairs(data.tal[ci]) do
		local treeIndex, treeData = ti, td
		Btn(L[treeData.tree] or treeData.tree, max(90, #(treeData.tree or "") * 7 + 24), treeFocus == treeIndex, function() treeFocus = treeIndex Render(true) end)
	end
	ctx.y = ctx.y + 30

	ctx:Header(L["Load"])
	x = 0
	Btn(L["Empty"], 80, treeMode == "calc", function() treeMode = "calc" treeSig = nil Render(true) end)
	if treeClass == file then
		Btn(L["My talents"], 100, treeMode == "mine", function() treeMode = "mine" treeSig = nil Render(true) end)
	end
	for si, specName in ipairs(data.specs and data.specs[ci] or {}) do
		for bi, bld in ipairs((data.builds and data.builds[ci] and data.builds[ci][specName]) or {}) do
			local modeId = "b:" .. si .. ":" .. bi
			local label = L[specName] .. " - " .. (bld.n or "?")
			Btn(label, max(90, #label * 6 + 24), treeMode == modeId, function() treeMode = modeId treeSig = nil Render(true) end)
		end
	end
	ctx.y = ctx.y + 30

	local used = AllTotal()
	local summary = AddLabel(ctx.p, format(L["%d of %d talent points used, %d left"], used, MAX_POINTS, MAX_POINTS - used), 11, used > 0 and { 0.35, 1, 0.45 } or MUTED)
	summary:SetPoint("TOPLEFT", 0, -ctx.y)
	local reset = MakeButton(ctx.p, L["Reset all"], 90, 20, function() treeSig = nil treeMode = "calc" LoadPoints(data, ci, "calc", file) treeSig = treeClass .. ":calc" Render(true) end)
	reset:SetPoint("TOPRIGHT", 0, -(ctx.y - 4))
	ctx.y = ctx.y + 28

	local h = 0
	if treeFocus and data.tal[ci][treeFocus] then
		h = DrawTree(ctx, 0, treeFocus, data.tal[ci][treeFocus], data, ci, changed)
	else
		for ti, td in ipairs(data.tal[ci]) do
			h = max(h, DrawTree(ctx, (ti - 1) * (TREE_W + TREE_GAP), ti, td, data, ci, changed))
		end
	end
	ctx.y = ctx.y + h + 10
	ctx:Text(L["Left click adds a point, right click removes one; a tier needs 5 points per tier above it in the same tree, and prerequisite talents are enforced. Click a tree title to focus it, right click it to reset that tree. Other classes show the English names from the guide data."], 10, MUTED)
end

local function GuidesPage(ctx)
	ctx.title = L["Guides"]
	guideClass = guideClass or PlayerClassFile()
	if not TD.classes[guideClass] or not TD.classes[guideClass].specs then guideClass = "WARRIOR" end
	ctx:Header(L["Class"])
	local x = 0
	for _, file in ipairs(TBC_CLASSES) do
		local chosenClass = file
		local b = MakeButton(ctx.p, ClassName(chosenClass), 78, 22, function() guideClass = chosenClass guideSpec = nil Render(true) end)
		b.label:SetTextColor(unpack(ClassColor(file)))
		b:SetPoint("TOPLEFT", x, -ctx.y)
		if chosenClass == guideClass then b:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.9) b.selected = true end
		x = x + 82
		if x + 82 > ctx.w then x = 0 ctx.y = ctx.y + 26 end
	end
	if x ~= 0 then ctx.y = ctx.y + 26 end
	ctx:Gap(4)
	local c = TD.classes[guideClass]
	ctx:Header(L["Specializations"])
	x = 0
	for _, s in ipairs(c.specs) do
		local chosenSpec = s.name
		local b = MakeButton(ctx.p, L[chosenSpec], 130, 22, function() guideSpec = chosenSpec Render(true) end)
		b:SetPoint("TOPLEFT", x, -ctx.y)
		SetSelected(b, guideSpec == chosenSpec)
		x = x + 136
	end
	ctx.y = ctx.y + 32
	ctx:Header(L["Open"])
	x = 0
	local function Act(text, w, fn)
		local b = MakeButton(ctx.p, text, w, 24, fn)
		b:SetPoint("TOPLEFT", x, -ctx.y)
		x = x + w + 8
	end
	Act(L["BiS Guide"], 120, function() OpenBis(guideClass, guideSpec) end)
	Act(L["Consumables"], 120, function() OpenWindow("consumes") end)
	Act(L["Rotation"], 120, function() OpenWindow("rotation") end)
	Act(L["Talent builds"], 130, function() OpenWindow("talents") end)
	ctx.y = ctx.y + 38
	ctx:Text(L["BiS Guide opens for the selected class and specialization. Consumables, rotation and talent builds open for your own character."], 10, MUTED)
	ctx:Gap(6)
	if guideSpec then
		for _, s in ipairs(c.specs) do if s.name == guideSpec then SpecBlock(ctx, guideClass, s) end end
	end
end

-------------------------------------------------------------------------------
-- window
-------------------------------------------------------------------------------
local function UpdateThumb()
	if not (scrollFrame and thumb and track) then return end
	local range = scrollFrame:GetVerticalScrollRange() or 0
	local viewH = scrollFrame:GetHeight() or 1
	local totalH = viewH + range
	if range <= 0 then thumb:Hide() return end
	thumb:Show()
	local th = max(24, (track:GetHeight() or 100) * viewH / totalH)
	thumb:SetHeight(th)
	local pos = (scrollFrame:GetVerticalScroll() or 0) / range
	thumb:ClearAllPoints()
	thumb:SetPoint("TOP", track, "TOP", 0, -pos * ((track:GetHeight() or 100) - th))
end

local function UpdateNav()
	for key, b in pairs(sideButtons) do
		local on = key == page
		b.bg:SetColorTexture(1, 1, 1, on and 0.07 or 0)
		b.bar:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], on and 1 or 0)
		b.fs:SetTextColor(on and GOLD[1] or 0.72, on and GOLD[2] or 0.72, on and GOLD[3] or 0.75)
	end
end

function Render(keepScroll)
	if not mainFrame or not mainFrame:IsShown() then return end
	RefreshTheme()
	Clear()
	root = CreateFrame("Frame", nil, scrollChild)
	root:SetPoint("TOPLEFT", 0, 0)
	root:SetSize(CONTENT_W, 1)
	local ctx = NewCtx(root, CONTENT_W)
	local listPage = (page == "classes" and not selClass) or (page == "races" and not selRace)
	searchBox:SetShown(listPage)
	if listPage and searchBox:GetText() ~= searchText then
		settingSearch = true
		searchBox:SetText(searchText)
		settingSearch = nil
	end
	local ok, err = pcall(function()
		if page == "overview" then OverviewPage(ctx)
		elseif page == "classes" then
			if selClass and TD.classes[selClass] then ClassDetail(ctx, selClass) else ClassList(ctx) end
		elseif page == "races" then
			if selRace then RaceDetail(ctx, selRace) else RaceList(ctx) end
		elseif page == "caps" then CapsPage(ctx)
		elseif page == "trees" then TreesPage(ctx)
		elseif page == "talents" then TalentsPage(ctx)
		else GuidesPage(ctx) end
	end)
	if not ok then
		S:LogError(tostring(err), "TalentAtlas:Render")
		ctx:Text(L["This page could not be built; the error was logged."], 11, MUTED)
	end
	contentTitle:SetText(ctx.title or "")
	root:SetHeight(max(1, ctx.y))
	scrollChild:SetHeight(max(1, ctx.y + 10))
	if not keepScroll then scrollFrame:SetVerticalScroll(0) end
	UpdateNav()
	UpdateThumb()
	if pendingItems then
		pendingItems = nil
		if C_Timer and C_Timer.After then
			C_Timer.After(2, function() if mainFrame and mainFrame:IsShown() then Render(true) end end)
		end
	end
end

local function SetPage(key)
	if page ~= key then selClass, selRace, searchText = nil, nil, "" end
	page = key
	Render()
end

local function BuildWindow()
	if mainFrame then return mainFrame end
	RefreshTheme()
	local f = CreateFrame("Frame", "SentinelUITalentAtlas", UIParent, S.BackdropTemplate)
	f:SetSize(WIN_W, WIN_H)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)  -- newest/clicked window rises inside its strata
	f:SetToplevel(true)  -- newest/clicked window rises inside its strata
	f:SetClampedToScreen(true)
	f:SetMovable(true) f:EnableMouse(true) f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	S:SkinFrame(f, "Default")
	tinsert(UISpecialFrames, "SentinelUITalentAtlas")

	-- header band: same look as GuildHub
	local head = CreateFrame("Frame", nil, f)
	head:SetPoint("TOPLEFT", 0, 0)
	head:SetPoint("TOPRIGHT", 0, 0)
	head:SetHeight(44)
	local hbg = head:CreateTexture(nil, "BACKGROUND")
	hbg:SetAllPoints()
	hbg:SetColorTexture(0.05, 0.05, 0.07, 0.9)
	local rule = head:CreateTexture(nil, "ARTWORK")
	rule:SetPoint("BOTTOMLEFT")
	rule:SetPoint("BOTTOMRIGHT")
	rule:SetHeight(1)
	rule:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.9)
	local title = S:FontString(head, 14, "OUTLINE", S.media.font, nil, "LEFT")
	title:SetPoint("LEFT", 14, 0)
	title:SetText("|cff" .. (S.accentHex or "ebad33") .. "SENTINEL|r " .. L["Talent Atlas"])
	local sub = S:FontString(head, 11, nil, S.media.font, nil, "LEFT")
	sub:SetPoint("LEFT", title, "RIGHT", 10, -1)
	sub:SetTextColor(0.55, 0.55, 0.6)
	sub:SetText(L["Classes, races and talents"])
	local close = CreateFrame("Button", nil, head)
	close:SetSize(30, 30)
	close:SetPoint("RIGHT", -8, 0)
	close.fs = S:FontString(close, 13, "OUTLINE", S.media.font, nil, "CENTER")
	close.fs:SetPoint("CENTER")
	close.fs:SetText("x")
	close.fs:SetTextColor(0.6, 0.6, 0.6)
	close:SetScript("OnClick", function() f:Hide() end)
	close:SetScript("OnEnter", function() close.fs:SetTextColor(1, 0.4, 0.4) end)
	close:SetScript("OnLeave", function() close.fs:SetTextColor(0.6, 0.6, 0.6) end)

	-- sidebar
	local side = CreateFrame("Frame", nil, f, S.BackdropTemplate)
	side:SetPoint("TOPLEFT", 8, -52)
	side:SetPoint("BOTTOMLEFT", 8, 8)
	side:SetWidth(SIDE_W)
	S:SetTemplate(side, "Default")
	local y = 10
	for _, p in ipairs(PAGES) do
		local key = p[1]
		local b = CreateFrame("Button", nil, side)
		b:SetPoint("TOPLEFT", 8, -y)
		b:SetSize(SIDE_W - 16, 22)
		b.bg = b:CreateTexture(nil, "BACKGROUND")
		b.bg:SetAllPoints()
		b.bg:SetColorTexture(1, 1, 1, 0)
		b.bar = b:CreateTexture(nil, "OVERLAY")
		b.bar:SetPoint("TOPLEFT", -4, 0)
		b.bar:SetSize(2, 22)
		b.bar:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0)
		b.fs = S:FontString(b, 11, nil, S.media.font, nil, "LEFT")
		b.fs:SetPoint("LEFT", 8, 0)
		b.fs:SetText(L[p[2]])
		b.fs:SetTextColor(0.72, 0.72, 0.75)
		b:SetScript("OnClick", function() SetPage(key) end)
		b:SetScript("OnEnter", function() if page ~= key then b.bg:SetColorTexture(1, 1, 1, 0.06) end end)
		b:SetScript("OnLeave", function() b.bg:SetColorTexture(1, 1, 1, page == key and 0.07 or 0) end)
		sideButtons[key] = b
		y = y + 24
	end
	local ver = S:FontString(side, 9, nil, S.media.font, nil, "LEFT")
	ver:SetPoint("BOTTOMLEFT", 12, 8)
	ver:SetText("|cff555544" .. L["Drag to move"] .. "|r")

	-- content
	local content = CreateFrame("Frame", nil, f, S.BackdropTemplate)
	content:SetPoint("TOPLEFT", side, "TOPRIGHT", 6, 0)
	content:SetPoint("BOTTOMRIGHT", -8, 8)
	S:SetTemplate(content, "Default")

	contentTitle = S:FontString(content, 13, "OUTLINE", S.media.font, nil, "LEFT")
	contentTitle:SetPoint("TOPLEFT", 16, -14)
	contentTitle:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

	searchBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
	searchBox:SetSize(220, 22)
	searchBox:SetPoint("TOPRIGHT", -18, -10)
	searchBox:SetAutoFocus(false)
	S:SkinEditBox(searchBox)
	searchBox:SetScript("OnTextChanged", function(self)
		if settingSearch then return end
		searchText = self:GetText() or ""
		Render(false)
		self:SetFocus()
	end)
	searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

	local divider = content:CreateTexture(nil, "ARTWORK")
	divider:SetPoint("TOPLEFT", 16, -42)
	divider:SetPoint("TOPRIGHT", -16, -42)
	divider:SetHeight(1)
	divider:SetColorTexture(0.17, 0.18, 0.23, 1)

	scrollFrame = CreateFrame("ScrollFrame", nil, content)
	scrollFrame:SetPoint("TOPLEFT", 16, -52)
	scrollFrame:SetPoint("BOTTOMRIGHT", -26, 12)
	scrollFrame:EnableMouseWheel(true)
	scrollChild = CreateFrame("Frame", nil, scrollFrame)
	scrollChild:SetWidth(CONTENT_W)
	scrollChild:SetHeight(1)
	scrollFrame:SetScrollChild(scrollChild)
	scrollFrame:SetScript("OnMouseWheel", function(self, delta)
		local maximum = max(0, scrollChild:GetHeight() - self:GetHeight())
		self:SetVerticalScroll(max(0, min(maximum, self:GetVerticalScroll() - delta * 48)))
		UpdateThumb()
	end)

	track = CreateFrame("Frame", nil, content)
	track:SetPoint("TOPRIGHT", -10, -52)
	track:SetPoint("BOTTOMRIGHT", -10, 12)
	track:SetWidth(4)
	local tbg = track:CreateTexture(nil, "BACKGROUND")
	tbg:SetAllPoints()
	tbg:SetColorTexture(1, 1, 1, 0.05)
	thumb = track:CreateTexture(nil, "ARTWORK")
	thumb:SetWidth(4)
	thumb:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.8)

	f:Hide()
	f:SetScript("OnShow", function() Render(true) end)
	mainFrame = f
	return f
end

function TA:Open(key, arg, mode)
	BuildWindow()
	if key then
		page = key
		if key == "classes" then selClass = arg end
		if key == "trees" then treeClass, treeMode, treeFocus, treeSig = arg, mode or "calc", nil, nil end
		if key == "races" then
			selRace = nil
			for _, r in ipairs(TD.races) do if r.key == arg then selRace = r end end
		end
	end
	if mainFrame:IsShown() then Render() else mainFrame:Show() end
end

function TA:Toggle()
	BuildWindow()
	if mainFrame:IsShown() then mainFrame:Hide() else mainFrame:Show() end
end

function TA:Initialize()
	SLASH_TALENTATLAS1 = "/talentatlas"
	SLASH_SATLAS1 = "/sta"
	SlashCmdList.TALENTATLAS = function() TA:Toggle() end
	SlashCmdList.SATLAS = function() TA:Toggle() end

	self.db.minimap = self.db.minimap or { hide = false }
	self.minimapBtn = S:CreateMinimapButton({
		name = "talentatlas",
		glyph = "TA",
		angle = 250,
		store = self.db.minimap,
		onLeft = function() TA:Toggle() end,
		onRight = function() TA:Open("caps") end,
		tooltip = function()
			GameTooltip:AddLine(L["TalentAtlas"])
			GameTooltip:AddLine(L["Click: open TalentAtlas"], 1, 1, 1)
			GameTooltip:AddLine(L["Right-click: stat caps"], 0.7, 0.7, 0.7)
		end,
	})
	local bb = S.GetModule and S:GetModule("ButtonBars")
	if bb and bb.GrabButton and self.minimapBtn and self.minimapBtn:GetParent() == Minimap then
		pcall(bb.GrabButton, bb, self.minimapBtn, "SentinelUIMinimapButton_talentatlas")
	end
	self.minimapBtn:SetShown(not self.db.minimap.hide)
end
