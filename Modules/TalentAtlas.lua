-- TalentAtlas: class/race/talent guide browser, ported from the standalone
-- TalentAtlas addon into the SentinelUI module pattern.
local TA = S:NewModule("TalentAtlas", "talentatlas")
local L = S.L
local ns = {}
TA.frame = CreateFrame("Frame")


local CLASSIC = 1
local TBC = 2
local WRATH = 3
local MISTS = 5
local LEGION = 7
local BATTLE_FOR_AZEROTH = 8
local DRAGONFLIGHT = 10

ns.Expansions = {
	[1] = "Classic",
	[2] = "The Burning Crusade",
	[3] = "Wrath of the Lich King",
	[4] = "Cataclysm",
	[5] = "Mists of Pandaria",
	[6] = "Warlords of Draenor",
	[7] = "Legion",
	[8] = "Battle for Azeroth",
	[9] = "Shadowlands",
	[10] = "Dragonflight",
	[11] = "The War Within",
	[12] = "Midnight",
}

ns.Classes = {
	{ key = "druid", name = "Druid", roles = "Tank, Healer, Melee DPS, Ranged DPS", trees = "Balance, Feral, Restoration", specs = "Balance, Feral, Guardian, Restoration", armor = "Leather", resources = "Mana, Energy, Rage, Astral Power", overview = "Shapeshifter with flexible melee, ranged, tanking and healing playstyles.", since = CLASSIC },
	{ key = "hunter", name = "Hunter", roles = "Ranged DPS, Melee DPS", trees = "Beast Mastery, Marksmanship, Survival", specs = "Beast Mastery, Marksmanship, Survival", armor = "Mail", resources = "Focus", overview = "Weapon specialist who fights at range or in melee and often works with an animal companion.", since = CLASSIC },
	{ key = "mage", name = "Mage", roles = "Ranged DPS", trees = "Arcane, Fire, Frost", specs = "Arcane, Fire, Frost", armor = "Cloth", resources = "Mana", overview = "Ranged spellcaster focused on elemental damage, crowd control and mobility.", since = CLASSIC },
	{ key = "paladin", name = "Paladin", roles = "Tank, Healer, Melee DPS", trees = "Holy, Protection, Retribution", specs = "Holy, Protection, Retribution", armor = "Plate", resources = "Mana, Holy Power", overview = "Armored holy warrior combining weapon damage, defensive tools and group support.", since = CLASSIC, faction = "Alliance" },
	{ key = "priest", name = "Priest", roles = "Healer, Ranged DPS", trees = "Discipline, Holy, Shadow", specs = "Discipline, Holy, Shadow", armor = "Cloth", resources = "Mana, Insanity", overview = "A versatile healer with both direct and damage-prevention tools, plus a shadow damage path.", since = CLASSIC },
	{ key = "rogue", name = "Rogue", roles = "Melee DPS", trees = "Assassination, Combat, Subtlety", specs = "Assassination, Outlaw, Subtlety", armor = "Leather", resources = "Energy, Combo Points", overview = "Stealth-focused melee fighter using mobility, control and finishers.", since = CLASSIC },
	{ key = "shaman", name = "Shaman", roles = "Healer, Melee DPS, Ranged DPS", trees = "Elemental, Enhancement, Restoration", specs = "Elemental, Enhancement, Restoration", armor = "Mail", resources = "Mana, Maelstrom", overview = "Elemental caster and weapon fighter with healing, totems and group utility.", since = CLASSIC, faction = "Horde" },
	{ key = "warlock", name = "Warlock", roles = "Ranged DPS", trees = "Affliction, Demonology, Destruction", specs = "Affliction, Demonology, Destruction", armor = "Cloth", resources = "Mana, Soul Shards", overview = "Ranged damage caster who commands demons and uses curses, damage-over-time and direct spells.", since = CLASSIC },
	{ key = "warrior", name = "Warrior", roles = "Tank, Melee DPS", trees = "Arms, Fury, Protection", specs = "Arms, Fury, Protection", armor = "Plate", resources = "Rage", overview = "Weapon-driven frontline fighter with strong physical damage, mobility and defensive options.", since = CLASSIC },
	{ key = "deathknight", name = "Death Knight", roles = "Tank, Melee DPS", specs = "Blood, Frost, Unholy", armor = "Plate", resources = "Runes, Runic Power", overview = "Rune-powered melee fighter combining heavy armor, diseases and dark magic.", since = WRATH },
	{ key = "monk", name = "Monk", roles = "Tank, Healer, Melee DPS", specs = "Brewmaster, Mistweaver, Windwalker", armor = "Leather", resources = "Energy, Mana, Chi", overview = "Mobile martial artist with distinct tanking, healing and damage specializations.", since = MISTS },
	{ key = "demonhunter", name = "Demon Hunter", roles = "Tank, Melee DPS", specs = "Havoc, Vengeance", armor = "Leather", resources = "Fury, Pain", overview = "Highly mobile fel-powered fighter specializing in aggressive damage or active tanking.", since = LEGION },
	{ key = "evoker", name = "Evoker", roles = "Ranged DPS, Healer, Support", specs = "Devastation, Preservation, Augmentation", armor = "Mail", resources = "Mana, Essence", overview = "Dracthyr spellcaster with empowered abilities, mid-range magic, healing and support.", since = DRAGONFLIGHT },
}

ns.Races = {
	{ key = "human", name = "Human", faction = "Alliance", since = CLASSIC, traits = "Diplomacy, Will to Survive" },
	{ key = "dwarf", name = "Dwarf", faction = "Alliance", since = CLASSIC, traits = "Stoneform, Explorer" },
	{ key = "nightelf", name = "Night Elf", faction = "Alliance", since = CLASSIC, traits = "Shadowmeld, Quickness" },
	{ key = "gnome", name = "Gnome", faction = "Alliance", since = CLASSIC, traits = "Escape Artist, Expansive Mind" },
	{ key = "orc", name = "Orc", faction = "Horde", since = CLASSIC, traits = "Blood Fury, Hardiness" },
	{ key = "undead", name = "Undead", faction = "Horde", since = CLASSIC, traits = "Will of the Forsaken, Touch of the Grave" },
	{ key = "tauren", name = "Tauren", faction = "Horde", since = CLASSIC, traits = "War Stomp, Endurance" },
	{ key = "troll", name = "Troll", faction = "Horde", since = CLASSIC, traits = "Berserking, Regeneration" },
	{ key = "bloodelf", name = "Blood Elf", faction = "Horde", since = TBC, traits = "Arcane Torrent, Arcane Acuity" },
	{ key = "draenei", name = "Draenei", faction = "Alliance", since = TBC, traits = "Gift of the Naaru, Heroic Presence" },
	{ key = "worgen", name = "Worgen", faction = "Alliance", since = 4, traits = "Darkflight, Two Forms" },
	{ key = "goblin", name = "Goblin", faction = "Horde", since = 4, traits = "Rocket Jump, Best Deals Anywhere" },
	{ key = "pandaren", name = "Pandaren", faction = "Both", since = MISTS, traits = "Quaking Palm, Epicurean" },
	{ key = "nightborne", name = "Nightborne", faction = "Horde", since = LEGION, traits = "Ancient History, Arcane Pulse" },
	{ key = "highmountaintauren", name = "Highmountain Tauren", faction = "Horde", since = LEGION, traits = "Bull Rush, Mountaineer" },
	{ key = "voidelf", name = "Void Elf", faction = "Alliance", since = LEGION, traits = "Spatial Rift, Preternatural Calm" },
	{ key = "lightforgeddraenei", name = "Lightforged Draenei", faction = "Alliance", since = LEGION, traits = "Light's Judgment, Forge of Light" },
	{ key = "darkirondwarf", name = "Dark Iron Dwarf", faction = "Alliance", since = BATTLE_FOR_AZEROTH, traits = "Fireblood, Mole Machine" },
	{ key = "kul-tiran", name = "Kul Tiran", faction = "Alliance", since = BATTLE_FOR_AZEROTH, traits = "Haymaker, Brush It Off" },
	{ key = "magharorc", name = "Mag'har Orc", faction = "Horde", since = BATTLE_FOR_AZEROTH, traits = "Ancestral Call, Open Skies" },
	{ key = "zandalari-troll", name = "Zandalari Troll", faction = "Horde", since = BATTLE_FOR_AZEROTH, traits = "Embrace of the Loa, Pterrordax Swoop" },
	{ key = "mechagnome", name = "Mechagnome", faction = "Alliance", since = BATTLE_FOR_AZEROTH, traits = "Combat Analysis, Hyper Organic Light Originator" },
	{ key = "dracthyr", name = "Dracthyr", faction = "Both", since = DRAGONFLIGHT, traits = "Soar, Visage, racials vary by faction" },
	{ key = "earthen", name = "Earthen", faction = "Both", since = 11, traits = "Azerite Surge, Ingest Minerals" },
	{ key = "haranir", name = "Haranir", faction = "Both", since = 12, traits = "Race abilities vary by game version" },
	{ key = "vulpera", name = "Vulpera", faction = "Horde", since = BATTLE_FOR_AZEROTH, traits = "Make Camp, Nose For Trouble" },
}

ns.Builds = {
	-- Add reviewed recommendations here; each record must target one exact patch.
	-- { expansion = 12, patch = "12.0.5", class = "mage", spec = "Arcane",
	--   content = "Raid", title = "Single target", summary = "...",
	--   talentString = "...", source = "Editorial review", reviewed = "2026-10-31" },
}


local function AddLabel(parent, text, size, color)
	local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetFont("Fonts\\FRIZQT__.TTF", size, "")
	label:SetTextColor(color[1], color[2], color[3])
	label:SetText(text or "")
	return label
end

local function AddTalentCard(parent, x, y, name, icon, rank, maxRank, selected, colors, L, compact)
	local card = CreateFrame("Frame", nil, parent)
	card:SetSize(compact and 48 or 162, compact and 48 or 56)
	card:SetPoint("TOPLEFT", x, -y)
	card:EnableMouse(true)
	local bg = card:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	if selected then
		bg:SetColorTexture(0.20, 0.15, 0.07, 0.98)
	else
		bg:SetColorTexture(0.075, 0.085, 0.105, 0.98)
	end
	for edge = 1, 4 do
		local line = card:CreateTexture(nil, "BORDER")
		line:SetColorTexture(selected and colors[1] or 0.24, selected and colors[2] or 0.26, selected and colors[3] or 0.30, 1)
		if edge == 1 then
			line:SetPoint("TOPLEFT")
			line:SetPoint("TOPRIGHT")
			line:SetHeight(1)
		elseif edge == 2 then
			line:SetPoint("BOTTOMLEFT")
			line:SetPoint("BOTTOMRIGHT")
			line:SetHeight(1)
		elseif edge == 3 then
			line:SetPoint("TOPLEFT")
			line:SetPoint("BOTTOMLEFT")
			line:SetWidth(1)
		else
			line:SetPoint("TOPRIGHT")
			line:SetPoint("BOTTOMRIGHT")
			line:SetWidth(1)
		end
	end

	local texture = card:CreateTexture(nil, "ARTWORK")
	texture:SetSize(compact and 34 or 34, compact and 34 or 34)
	if compact then
		texture:SetPoint("CENTER")
	else
		texture:SetPoint("LEFT", 10, 0)
	end
	if icon then
		texture:SetTexture(icon)
	else
		texture:SetColorTexture(0.18, 0.20, 0.23, 1)
	end

	local progress
	if maxRank and maxRank > 1 then
		progress = L["Current rank: %d / %d"]:format(rank or 0, maxRank)
	elseif selected then
		progress = L["Current talent setup"]
	else
		progress = L["Unselected"]
	end
	if compact then
		local rankLabel = AddLabel(card, selected and tostring(rank or 1) or "", 9, colors)
		rankLabel:SetPoint("BOTTOMRIGHT", -4, 3)
		card:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(name, colors[1], colors[2], colors[3])
			GameTooltip:AddLine(progress, 1, 1, 1)
			GameTooltip:Show()
		end)
		card:SetScript("OnLeave", function() GameTooltip:Hide() end)
	else
		local title = AddLabel(card, name, 11, { 0.91, 0.92, 0.94 })
		title:SetPoint("TOPLEFT", texture, "TOPRIGHT", 8, -2)
		title:SetPoint("RIGHT", card, "RIGHT", -5, 0)
		title:SetJustifyH("LEFT")
		title:SetWordWrap(true)
		local detail = AddLabel(card, progress, 9, selected and colors or { 0.57, 0.61, 0.67 })
		detail:SetPoint("BOTTOMLEFT", texture, "BOTTOMRIGHT", 8, 2)
		detail:SetJustifyH("LEFT")
	end
	return card
end

local function MakeTreePanel(parent, x, width, title, colors)
	local panel = CreateFrame("Frame", nil, parent)
	panel:SetPoint("TOPLEFT", x, 0)
	panel:SetWidth(width)
	panel:SetHeight(100)
	local bg = panel:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0.055, 0.065, 0.082, 0.98)
	for edge = 1, 4 do
		local border = panel:CreateTexture(nil, "BORDER")
		border:SetColorTexture(0.22, 0.24, 0.28, 1)
		if edge == 1 then
			border:SetPoint("TOPLEFT")
			border:SetPoint("TOPRIGHT")
			border:SetHeight(1)
		elseif edge == 2 then
			border:SetPoint("BOTTOMLEFT")
			border:SetPoint("BOTTOMRIGHT")
			border:SetHeight(1)
		elseif edge == 3 then
			border:SetPoint("TOPLEFT")
			border:SetPoint("BOTTOMLEFT")
			border:SetWidth(1)
		else
			border:SetPoint("TOPRIGHT")
			border:SetPoint("BOTTOMRIGHT")
			border:SetWidth(1)
		end
	end
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
	for tab = 1, tabCount do
		local treeName, _, pointsSpent = GetTalentTabInfo(tab)
		treeName = treeName or (L["Talent tree"] .. " " .. tab)
		local panel = MakeTreePanel(parent, (tab - 1) * (panelWidth + gap), panelWidth, treeName, colors)
		if pointsSpent then
			local spent = AddLabel(panel, tostring(pointsSpent) .. " " .. L["Points spent"], 9, { 0.60, 0.64, 0.70 })
			spent:SetPoint("TOPLEFT", 9, -29)
		end

		local talentCount = GetNumTalents and GetNumTalents(tab) or 0
		for talent = 1, talentCount do
			local name, icon, _, _, rank, maxRank = GetTalentInfo(tab, talent)
			if name then
				local row = CreateFrame("Frame", nil, panel)
				row:SetSize(panelWidth - 14, 32)
				row:SetPoint("TOPLEFT", 7, -47 - ((talent - 1) * 35))
				row:EnableMouse(true)
				local rowBG = row:CreateTexture(nil, "BACKGROUND")
				rowBG:SetAllPoints()
				if (rank or 0) > 0 then
					rowBG:SetColorTexture(0.20, 0.15, 0.07, 0.96)
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
				local points = AddLabel(row, ("%d/%d"):format(rank or 0, maxRank or 0), 9, (rank or 0) > 0 and colors or { 0.57, 0.61, 0.67 })
				points:SetPoint("RIGHT", row, "RIGHT", -4, 0)
			end
		end
		local height = 55 + (talentCount * 35)
		panel:SetHeight(height)
		contentHeight = math.max(contentHeight, height)
	end

	return contentHeight
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
	for treeIndex, treeID in ipairs(config.treeIDs) do
		local nodes = C_Traits.GetTreeNodes(treeID) or {}
		local visible = {}
		local maxX, maxY = 0, 0
		for _, nodeID in ipairs(nodes) do
			local info = C_Traits.GetNodeInfo(configID, nodeID)
			if info and info.isVisible ~= false then
				local x, y = tonumber(info.posX), tonumber(info.posY)
				if x and y then
					visible[#visible + 1] = { id = nodeID, info = info, x = x, y = y }
					maxX, maxY = math.max(maxX, x), math.max(maxY, y)
				end
			end
		end
		if #visible > 0 then
			local treeName = L["Talent tree"] .. " " .. treeIndex
			if treeCount == 2 then
				treeName = treeIndex == 1 and L["Class tree"] or L["Specialization tree"]
			end
			local panel = MakeTreePanel(parent, (treeIndex - 1) * (panelWidth + gap), panelWidth, treeName, colors)
			for _, node in ipairs(visible) do
				local info = node.info
				local entryID = info.activeEntryID
				if not entryID and info.activeEntry then
					entryID = info.activeEntry.entryID or info.activeEntry.ID
				end
				local entryInfo
				if entryID and type(C_Traits.GetEntryInfo) == "function" then
					entryInfo = C_Traits.GetEntryInfo(configID, entryID)
				elseif info.entryIDs and info.entryIDs[1] and type(C_Traits.GetEntryInfo) == "function" then
					entryInfo = C_Traits.GetEntryInfo(configID, info.entryIDs[1])
				end
				local name, icon = ReadSpell(entryInfo and entryInfo.definitionID)
				local rows = 12
				local x = 5 + (maxX > 0 and node.x / maxX or 0) * math.max(0, panelWidth - 58)
				local y = 48 + math.floor((maxY > 0 and node.y / maxY or 0) * (rows - 1)) * 54
				local rank = info.ranksPurchased or (info.activeEntryID and 1) or 0
				AddTalentCard(
					panel,
					x,
					y,
					name or (L["Talent tree"] .. " " .. node.id),
					icon,
					rank,
					info.maxRanks,
					rank > 0,
					colors,
					L,
					true
				)
			end
			local height = 60 + (rows * 54)
			panel:SetHeight(height)
			contentHeight = math.max(contentHeight, height)
		end
	end
	return contentHeight > 0 and contentHeight or false
end

function ns.DrawCurrentTalents(parent, colors, L)
	local height = DrawModernTalents(parent, colors, L)
	if height == nil then height = DrawClassicTalents(parent, colors, L) end
	return height
end

local addon = TA.frame

local GOLD = { S.accent.r, S.accent.g, S.accent.b }
local PANEL = { 0.055, 0.065, 0.082, 0.98 }
local PANEL_LIGHT = { 0.09, 0.105, 0.13, 0.98 }
local TEXT = { 0.91, 0.92, 0.94 }
local MUTED = { 0.57, 0.61, 0.67 }
local selectedPage = "Overview"
local selectedEntry
local searchText = ""
local mainFrame
local minimapButton
local scrollChild
local contentScrollFrame
local contentTitle
local searchBox
local settingSearchText
local pageButtons = {}

local function AddBackground(frame, color)
	local texture = frame:CreateTexture(nil, "BACKGROUND")
	texture:SetAllPoints()
	texture:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
	return texture
end

local function AddBorder(frame, color)
	local borderColor = color or { 0.22, 0.24, 0.28, 1 }
	local edges = {}
	for i = 1, 4 do
		edges[i] = frame:CreateTexture(nil, "BORDER")
		edges[i]:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
	end
	edges[1]:SetPoint("TOPLEFT")
	edges[1]:SetPoint("TOPRIGHT")
	edges[1]:SetHeight(1)
	edges[2]:SetPoint("BOTTOMLEFT")
	edges[2]:SetPoint("BOTTOMRIGHT")
	edges[2]:SetHeight(1)
	edges[3]:SetPoint("TOPLEFT")
	edges[3]:SetPoint("BOTTOMLEFT")
	edges[3]:SetWidth(1)
	edges[4]:SetPoint("TOPRIGHT")
	edges[4]:SetPoint("BOTTOMRIGHT")
	edges[4]:SetWidth(1)
end

local function MakeLabel(parent, text, size, color, font)
	local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
	label:SetFont("Fonts\\FRIZQT__.TTF", size or 13, "")
	label:SetTextColor(color[1], color[2], color[3])
	label:SetText(text or "")
	return label
end

local function MakeButton(parent, text, width, height, onClick)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(width, height)
	AddBackground(button, PANEL_LIGHT)
	AddBorder(button)
	button.label = MakeLabel(button, text, 12, TEXT)
	button.label:SetPoint("CENTER")
	button:SetScript("OnClick", onClick)
	button:SetScript("OnEnter", function(self)
		self:GetRegions():SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.12)
	end)
	button:SetScript("OnLeave", function(self)
		local region = self:GetRegions()
		if region then region:SetColorTexture(PANEL_LIGHT[1], PANEL_LIGHT[2], PANEL_LIGHT[3], 1) end
	end)
	return button
end

local function GetClientInfo()
	local _, _, _, interface = GetBuildInfo()
	interface = tonumber(interface) or 0
	local expansion = 1
	local client = "Classic"

	if interface >= 120000 then
		expansion, client = 12, "Retail"
	elseif interface >= 110000 then
		expansion, client = 11, "Retail"
	elseif interface >= 100000 then
		expansion, client = 10, "Retail"
	elseif interface >= 90000 then
		expansion, client = 9, "Retail"
	elseif interface >= 80000 then
		expansion, client = 8, "Retail"
	elseif interface >= 70000 then
		expansion, client = 7, "Retail"
	elseif interface >= 60000 then
		expansion, client = 6, "Retail"
	elseif interface >= 50500 then
		expansion, client = 5, "Mists of Pandaria Classic"
	elseif interface >= 40400 then
		expansion, client = 4, "Cataclysm Classic"
	elseif interface >= 30400 then
		expansion, client = 3, "Wrath Classic"
	elseif interface >= 20500 then
		expansion, client = 2, "Burning Crusade Classic"
	elseif interface >= 11500 then
		expansion, client = 1, "Classic"
	end

	return expansion, client, interface
end

local function GetCurrentRaceName()
	return select(1, UnitRace("player")) or UNKNOWN or "Unknown"
end

local function TranslateList(value)
	if not value then return "" end
	local translated = {}
	for part in value:gmatch("[^,]+") do
		local item = part:match("^%s*(.-)%s*$")
		translated[#translated + 1] = L[item]
	end
	return table.concat(translated, ", ")
end

local function GetClassProfile(entry)
	local expansion = GetClientInfo()
	if expansion <= 3 and entry.trees then
		return L["Talent trees"], TranslateList(entry.trees)
	end
	return L["Specializations"], TranslateList(entry.specs or entry.trees)
end

local function Matches(entry, needle)
	if needle == "" then return true end
	needle = needle:lower()
	local haystack = table.concat({
		L[entry.name or ""],
		TranslateList(entry.roles),
		TranslateList(entry.specs),
		TranslateList(entry.trees),
		L[entry.faction or ""],
		TranslateList(entry.traits),
		L[ns.Expansions[entry.since] or ""],
	}, " "):lower()
	return haystack:find(needle, 1, true) ~= nil
end

local function ClearContent()
	for _, child in ipairs({ scrollChild:GetChildren() }) do
		child:Hide()
		child:SetParent(nil)
	end
	scrollChild:SetHeight(1)
end

local function AddCard(entry, index, kind)
	local card = CreateFrame("Button", nil, scrollChild)
	card:SetHeight(112)
	card:SetPoint("TOPLEFT", 0, -((index - 1) * 122))
	card:SetPoint("TOPRIGHT", 0, -((index - 1) * 122))
	AddBackground(card, index % 2 == 0 and PANEL or PANEL_LIGHT)
	AddBorder(card)

	local marker = card:CreateTexture(nil, "ARTWORK")
	marker:SetWidth(3)
	marker:SetPoint("TOPLEFT", 1, -1)
	marker:SetPoint("BOTTOMLEFT", 1, 1)
	marker:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.9)

	local name = MakeLabel(card, L[entry.name], 17, TEXT, "GameFontNormalLarge")
	name:SetPoint("TOPLEFT", 17, -13)
	name:SetJustifyH("LEFT")

	local caption
	if kind == "class" then
		caption = L["Roles"] .. ": " .. TranslateList(entry.roles)
	else
		caption = L["Faction"] .. ": " .. L[entry.faction] .. "  |  " .. L["Available since"] .. ": " .. L[ns.Expansions[entry.since] or "?"]
	end
	local sub = MakeLabel(card, caption, 11, GOLD)
	sub:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -6)
	sub:SetJustifyH("LEFT")
	sub:SetWidth(690)

	local details
	if kind == "class" then
		local profileLabel, profiles = GetClassProfile(entry)
		details = profileLabel .. ": " .. profiles
	else
		details = L["Racial traits"] .. ": " .. TranslateList(entry.traits)
	end
	local body = MakeLabel(card, details, 11, MUTED)
	body:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -8)
	body:SetPoint("RIGHT", card, "RIGHT", -14, 0)
	body:SetJustifyH("LEFT")
	body:SetWordWrap(true)

	card:SetScript("OnClick", function()
		selectedEntry = { data = entry, kind = kind }
		addon:Render()
	end)
	card:SetScript("OnEnter", function(self)
		self:SetAlpha(0.82)
	end)
	card:SetScript("OnLeave", function(self)
		self:SetAlpha(1)
	end)
end

local function AddInfoPanel(titleText, lines, index)
	local panel = CreateFrame("Frame", nil, scrollChild)
	panel:SetPoint("TOPLEFT", 0, -((index - 1) * 136))
	panel:SetPoint("TOPRIGHT", 0, -((index - 1) * 136))
	panel:SetHeight(124)
	AddBackground(panel, PANEL_LIGHT)
	AddBorder(panel)

	local title = MakeLabel(panel, titleText, 16, GOLD)
	title:SetPoint("TOPLEFT", 16, -14)
	title:SetJustifyH("LEFT")
	local body = MakeLabel(panel, lines, 12, TEXT)
	body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
	body:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
	body:SetJustifyH("LEFT")
	body:SetWordWrap(true)
end

local function RenderOverview()
	local expansion, client, interface = GetClientInfo()
	local className, classToken = UnitClass("player")
	local raceName = GetCurrentRaceName()
	local level = UnitLevel("player")

	AddInfoPanel(
		L["Your character"],
		("%s / %s / %s %s"):format(
			className or UNKNOWN,
			raceName,
			L["Level"],
			level or "?"
		),
		1
	)
	AddInfoPanel(
		L["Detected client"],
		("%s / %s / %s %s"):format(client, L["Version"], interface, L[ns.Expansions[expansion] or ""]),
		2
	)
	AddInfoPanel(
		L["Guide library"],
		L["Guides are version-specific."] .. " " .. L["Builds must be reviewed for each game version and patch before being recommended."],
		3
	)
	AddInfoPanel(
		L["Class overview"],
		("%s / %s"):format(classToken or "", L["Select a class or race to explore its guide."]),
		4
	)
	scrollChild:SetHeight(4 * 136)
end

local function RenderEntries(kind)
	local expansion = GetClientInfo()
	local source = kind == "class" and ns.Classes or ns.Races
	local shown = 0

	for _, entry in ipairs(source) do
		if entry.since <= expansion and Matches(entry, searchText) then
			shown = shown + 1
			AddCard(entry, shown, kind)
		end
	end

	if shown == 0 then
		AddInfoPanel(L["No results"], L["No matching entries found."], 1)
		shown = 1
	end
	scrollChild:SetHeight(shown * 122)
end

local function RenderBuilds()
	local expansion, client = GetClientInfo()
	local shown = 0
	for _, build in ipairs(ns.Builds) do
		if build.expansion == expansion then
			shown = shown + 1
			local title = table.concat({ build.class or "", build.spec or "", build.content or "" }, " / ")
			local metadata = build.patch and (L["Patch"] .. ": " .. build.patch) or ""
			if build.reviewed then
				metadata = metadata .. (metadata ~= "" and "  |  " or "") .. L["Reviewed"] .. ": " .. build.reviewed
			end
			local body = (build.title or "") .. "\n" .. (build.summary or "")
			if metadata ~= "" then body = body .. "\n" .. metadata end
			if build.source then body = body .. "\n" .. L["Source"] .. ": " .. build.source end
			AddInfoPanel(title, body, shown)
		end
	end
	if shown == 0 then
		local text = L["No reviewed builds are bundled yet."] .. "\n\n"
			.. L["Builds must be reviewed for each game version and patch before being recommended."] .. "\n\n"
			.. L["Detected client"] .. ": " .. client .. " / " .. L[ns.Expansions[expansion] or ""]
		AddInfoPanel(L["Build guide"], text, 1)
		AddInfoPanel(
			L["Guide inspiration"],
			L["Guide structure based on Icy Veins and Wowhead. Guide text and recommendations must be independently authored and reviewed."],
			2
		)
		shown = 2
	end
	scrollChild:SetHeight(shown * 136)
end

local function RenderTalents()
	local height = ns.DrawCurrentTalents(scrollChild, GOLD, L)
	if height == nil then
		AddInfoPanel(L["Talents"], L["Talent APIs are not available on this client."], 1)
		scrollChild:SetHeight(136)
	elseif height == false then
		AddInfoPanel(L["Talents"], L["No active talent configuration was found."], 1)
		scrollChild:SetHeight(136)
	else
		scrollChild:SetHeight(height)
	end
end

local function RenderDetails()
	local entry = selectedEntry.data
	local kind = selectedEntry.kind
	if kind == "class" then
		local profileLabel, profiles = GetClassProfile(entry)
		local classInfo = L["Roles"] .. ": " .. TranslateList(entry.roles) .. "\n"
			.. profileLabel .. ": " .. profiles .. "\n"
			.. L["Available since"] .. ": " .. L[ns.Expansions[entry.since] or ""]
		local combatInfo = L["Armor type"] .. ": " .. L[entry.armor or "Unknown"] .. "\n"
			.. L["Primary resources (modern; vary by version)"] .. ": " .. TranslateList(entry.resources) .. "\n"
			.. L["Resource and armor details can change between expansions."]
		AddInfoPanel(L[entry.name], classInfo, 1)
		AddInfoPanel(L["Combat profile"], combatInfo, 2)
		AddInfoPanel(L["How this class plays"], L[entry.overview or ""], 3)

		local _, classToken = UnitClass("player")
		if classToken and classToken:lower() == entry.key then
			local specialization
			if type(GetSpecialization) == "function" and type(GetSpecializationInfo) == "function" then
				local index = GetSpecialization()
				if index then specialization = select(2, GetSpecializationInfo(index)) end
			end
			local characterInfo = L["Class"] .. ": " .. L[entry.name] .. "\n"
				.. L["Race"] .. ": " .. GetCurrentRaceName() .. "\n"
				.. L["Level"] .. ": " .. tostring(UnitLevel("player") or "?")
			if specialization then characterInfo = characterInfo .. "\n" .. L["Specialization"] .. ": " .. specialization end
			AddInfoPanel(L["Your character"], characterInfo, 4)
			scrollChild:SetHeight(4 * 136)
		else
			scrollChild:SetHeight(3 * 136)
		end
	else
		local line = L["Faction"] .. ": " .. L[entry.faction] .. "\n"
			.. L["Racial traits"] .. ": " .. TranslateList(entry.traits) .. "\n"
			.. L["Available since"] .. ": " .. L[ns.Expansions[entry.since] or ""] .. "\n"
			.. L["Race note"]
		AddInfoPanel(L[entry.name], line, 1)
		AddInfoPanel(L["Details"], L["Race details and class availability depend on the selected game version."], 2)
		scrollChild:SetHeight(272)
	end
end

function addon:Render()
	if not mainFrame or not mainFrame:IsShown() then return end
	ClearContent()
	if contentScrollFrame then contentScrollFrame:SetVerticalScroll(0) end

	if selectedEntry then
		contentTitle:SetText(L[selectedEntry.data.name])
		searchBox:Hide()
		RenderDetails()
	elseif selectedPage == "Overview" then
		contentTitle:SetText(L["TalentAtlas"])
		searchBox:Hide()
		RenderOverview()
	elseif selectedPage == "Classes" then
		contentTitle:SetText(L["Classes"])
		searchBox:Show()
		if searchBox:GetText() ~= searchText then
			settingSearchText = true
			searchBox:SetText(searchText)
			settingSearchText = nil
		end
		RenderEntries("class")
	elseif selectedPage == "Races" then
		contentTitle:SetText(L["Races"])
		searchBox:Show()
		if searchBox:GetText() ~= searchText then
			settingSearchText = true
			searchBox:SetText(searchText)
			settingSearchText = nil
		end
		RenderEntries("race")
	elseif selectedPage == "Talents" then
		contentTitle:SetText(L["Talents"])
		searchBox:Hide()
		RenderTalents()
	else
		contentTitle:SetText(L["Builds"])
		searchBox:Hide()
		RenderBuilds()
	end
end

local function SetPage(page)
	selectedPage = page
	selectedEntry = nil
	searchText = ""
	for key, button in pairs(pageButtons) do
		button.label:SetTextColor(key == page and GOLD[1] or TEXT[1], key == page and GOLD[2] or TEXT[2], key == page and GOLD[3] or TEXT[3])
	end
	addon:Render()
end

local function CreateMainFrame()
	local frame = CreateFrame("Frame", "TalentAtlasMainFrame", UIParent)
	frame:SetSize(900, 610)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	AddBackground(frame, PANEL)
	AddBorder(frame, { 0.29, 0.25, 0.18, 1 })

	local top = CreateFrame("Frame", nil, frame)
	top:SetPoint("TOPLEFT", 1, -1)
	top:SetPoint("TOPRIGHT", -1, -1)
	top:SetHeight(54)
	AddBackground(top, { 0.075, 0.082, 0.098, 1 })

	local accent = top:CreateTexture(nil, "ARTWORK")
	accent:SetPoint("TOPLEFT")
	accent:SetPoint("BOTTOMLEFT")
	accent:SetWidth(3)
	accent:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)

	local title = MakeLabel(top, L["TalentAtlas"], 21, GOLD, "GameFontNormalLarge")
	title:SetPoint("LEFT", 20, 0)
	local subtitle = MakeLabel(top, L["Open with /talentatlas"], 10, MUTED)
	subtitle:SetPoint("LEFT", title, "RIGHT", 13, 0)

	local close = MakeButton(top, "X", 32, 30, function() frame:Hide() end)
	close:SetPoint("RIGHT", -12, 0)

	local sidebar = CreateFrame("Frame", nil, frame)
	sidebar:SetPoint("TOPLEFT", 1, -55)
	sidebar:SetPoint("BOTTOMLEFT", 1, 1)
	sidebar:SetWidth(166)
	AddBackground(sidebar, { 0.045, 0.052, 0.067, 1 })

	local pages = { "Overview", "Classes", "Races", "Talents", "Builds" }
	for index, page in ipairs(pages) do
		local button = MakeButton(sidebar, L[page], 142, 38, function() SetPage(page) end)
		button:SetPoint("TOPLEFT", 12, -18 - ((index - 1) * 47))
		pageButtons[page] = button
	end

	local footer = MakeLabel(sidebar, L["Drag to move"], 10, MUTED)
	footer:SetPoint("BOTTOMLEFT", 15, 15)

	local content = CreateFrame("Frame", nil, frame)
	content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 1, 0)
	content:SetPoint("BOTTOMRIGHT", -1, 1)
	AddBackground(content, PANEL)

	contentTitle = MakeLabel(content, "", 18, GOLD, "GameFontNormalLarge")
	contentTitle:SetPoint("TOPLEFT", 22, -18)

	searchBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
	searchBox:SetSize(230, 24)
	searchBox:SetPoint("TOPRIGHT", -22, -16)
	searchBox:SetAutoFocus(false)
	searchBox:SetScript("OnTextChanged", function(self)
		if settingSearchText then return end
		searchText = self:GetText() or ""
		if selectedPage == "Classes" or selectedPage == "Races" then addon:Render() end
	end)
	searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

	local divider = content:CreateTexture(nil, "ARTWORK")
	divider:SetPoint("TOPLEFT", 22, -52)
	divider:SetPoint("TOPRIGHT", -22, -52)
	divider:SetHeight(1)
	divider:SetColorTexture(0.22, 0.24, 0.28, 1)

	local scrollFrame = CreateFrame("ScrollFrame", nil, content)
	contentScrollFrame = scrollFrame
	scrollFrame:SetPoint("TOPLEFT", 22, -67)
	scrollFrame:SetPoint("BOTTOMRIGHT", -22, 20)
	scrollFrame:EnableMouseWheel(true)
	scrollChild = CreateFrame("Frame", nil, scrollFrame)
	scrollChild:SetWidth(690)
	scrollChild:SetHeight(1)
	scrollFrame:SetScrollChild(scrollChild)
	scrollFrame:SetScript("OnMouseWheel", function(self, delta)
		local current = self:GetVerticalScroll()
		local maximum = math.max(0, scrollChild:GetHeight() - self:GetHeight())
		self:SetVerticalScroll(math.max(0, math.min(maximum, current - delta * 42)))
	end)

	frame:SetMovable(true)
	top:EnableMouse(true)
	top:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" then frame:StartMoving() end
	end)
	top:SetScript("OnMouseUp", function() frame:StopMovingOrSizing() end)
	frame:Hide()
	mainFrame = frame
	frame:SetScript("OnShow", function() addon:Render() end)
	return frame
end

function TA:Toggle()
	if not mainFrame then CreateMainFrame() end
	if mainFrame:IsShown() then
		mainFrame:Hide()
	else
		mainFrame:Show()
		SetPage(selectedPage)
	end
end

function TA:Initialize()
	SLASH_TALENTATLAS1 = "/talentatlas"
	SLASH_SATLAS1 = "/sta"
	SlashCmdList.TALENTATLAS = function() TA:Toggle() end
	SlashCmdList.SATLAS = function() TA:Toggle() end

	self.db.minimap = self.db.minimap or { hide = false }
	self.minimapBtn = S:CreateMinimapButton({
		name = "talentatlas",
		icon = "Interface\\Icons\\INV_Misc_Book_09",
		angle = 250,
		store = self.db.minimap,
		onLeft = function() TA:Toggle() end,
		onRight = function()
			if not mainFrame then CreateMainFrame() end
			mainFrame:Show()
			SetPage("Builds")
		end,
		tooltip = function()
			GameTooltip:AddLine(L["TalentAtlas"])
			GameTooltip:AddLine(L["Click: open TalentAtlas"], 1, 1, 1)
			GameTooltip:AddLine(L["Right-click: open build guide"], 0.7, 0.7, 0.7)
		end,
	})
	local bb = S.GetModule and S:GetModule("ButtonBars")
	if bb and bb.GrabButton and self.minimapBtn and self.minimapBtn:GetParent() == Minimap then
		pcall(bb.GrabButton, bb, self.minimapBtn, "SentinelUIMinimapButton_talentatlas")
	end
	self.minimapBtn:SetShown(not self.db.minimap.hide)
end
