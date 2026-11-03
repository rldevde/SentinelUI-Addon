-- CraftWatch: profit tag on every recipe row in the profession window.
-- sale price minus material cost, colored green/red; prices come from the
-- Auction House scan DB / price history, vendor price as fallback.
local _, ns = ...
local S = ns.S
local L = S.L
local CW = S:NewModule("CraftWatch", "craftwatch")

local function ItemID(link)
	return link and tonumber(link:match("item:(%d+)"))
end

local function Price(id)
	if not id then return end
	-- freshest: AH scan DB
	local db = S.db.global.auctionDB
	if db then
		local key = (GetRealmName() or "?") .. "-" .. (UnitFactionGroup("player") or "?")
		local e = db[key] and db[key][id]
		if e and e.p then return e.p end
	end
	-- price history store (min observed)
	local ph = S:GetModule("PriceHistory")
	if ph and ph.db and ph.db.items then
		local e = ph.db.items[id]
		if e and e.min then return e.min end
	end
	-- vendor floor: sell price (vendor-bought mats are close to this)
	local sp = GetItemInfo and select(11, GetItemInfo(id))
	if sp and sp > 0 then return sp end
end

local function CraftCost(i)
	local total = 0
	local n = GetNumTradeSkillReagents and GetNumTradeSkillReagents(i) or 0
	for j = 1, n do
		local cnt = select(3, GetTradeSkillReagentInfo(i, j))
		local link = GetTradeSkillReagentItemLink and GetTradeSkillReagentItemLink(i, j)
		local p = Price(ItemID(link))
		if p and cnt then total = total + p * cnt end
	end
	return total
end

local function Profit(i)
	local link = GetTradeSkillItemLink and GetTradeSkillItemLink(i)
	local id = ItemID(link)
	if not id then return end
	local sell = Price(id)
	if not sell then return end
	local made = 1
	if GetTradeSkillNumMade then
		local lo, hi = GetTradeSkillNumMade(i)
		made = ((lo or 1) + (hi or lo or 1)) / 2
	end
	local cost = CraftCost(i)
	return sell * made - cost, cost
end

local function Store()
	S.db.global.craftwatch = S.db.global.craftwatch or {}
	local g = S.db.global.craftwatch
	g.recipes = g.recipes or {}
	g.ledger = g.ledger or {}
	return g
end

local function RecordRecipes()
	if not GetNumTradeSkills then return end
	local prof = GetTradeSkillLine and GetTradeSkillLine() or "?"
	local who = UnitName("player")
	local rec = Store().recipes
	for i = 1, GetNumTradeSkills() do
		local name, stype = GetTradeSkillInfo(i)
		if name and stype ~= "header" then
			local id = ItemID(GetTradeSkillItemLink and GetTradeSkillItemLink(i))
			if id then rec[id] = { name = name, prof = prof, who = who } end
		end
	end
end

local function LedgerAdd(itemID, name)
	local g = Store()
	g.ledger[#g.ledger + 1] = { id = itemID, name = name, t = time() }
	while #g.ledger > 50 do table.remove(g.ledger, 1) end
end

local function MoneyShort(c)
	local a = math.abs(c)
	if a >= 10000 then return format("%.1fg", c / 10000)
	elseif a >= 100 then return format("%ds", c / 100)
	else return format("%dc", c) end
end

function CW:PaintRows()
	local frame = _G.TradeSkillFrame
	if not frame or not frame:IsShown() then return end
	RecordRecipes()
	-- TBC/classic recipe rows are named TradeSkillSkill1..N (index via GetID)
	for i = 1, 20 do
		local btn = _G["TradeSkillSkill" .. i]
		if not btn then break end
		if not btn.suiProfit then
			btn.suiProfit = S:FontString(btn, 10, "OUTLINE")
			btn.suiProfit:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
			btn.suiProfit:SetJustifyH("RIGHT")
		end
		btn.suiProfit:SetText("")
		if btn:IsShown() and GetTradeSkillInfo then
			local idx = btn.GetID and btn:GetID()
			if idx then
				local name, stype = GetTradeSkillInfo(idx)
				if name and stype ~= "header" then
					local p, cost = S:SafeCall("CraftWatch:Profit", Profit, idx)
					if p then
						local m = (cost or 0) > 0 and format(" (%d%%)", math.floor(p / cost * 100 + 0.5)) or ""
						btn.suiProfit:SetFormattedText("%s%s%s|r",
							p >= 0 and "|cff33ff33+" or "|cffff3333", MoneyShort(p), m)
					end
				end
			end
		end
	end
end

function CW:ShowBest()
	local f = self.best
	if not f then
		f = CreateFrame("Frame", "SentinelUICraftWatchBest", UIParent, "BackdropTemplate")
		f:SetSize(380, 420)
		f:SetPoint("CENTER")
		S:CreateBackdrop(f, "Default")
		f:SetBackdropColor(0.05, 0.05, 0.08, 0.95)
		f:SetMovable(true) f:EnableMouse(true) f:RegisterForDrag("LeftButton")
		f:SetScript("OnDragStart", f.StartMoving) f:SetScript("OnDragStop", f.StopMovingOrSizing)
		f:SetClampedToScreen(true)
		local t = S:FontString(f, 13, "OUTLINE")
		t:SetPoint("TOP", 0, -8) t:SetText(L["Best Crafts"])
		local c = CreateFrame("Button", nil, f, "UIPanelCloseButton")
		c:SetPoint("TOPRIGHT", -4, -4)
		f.rows = {}
		for i = 1, 18 do
			local r = S:FontString(f, 11)
			r:SetPoint("TOPLEFT", 12, -30 - (i - 1) * 21)
			r:SetWidth(356) r:SetJustifyH("LEFT")
			f.rows[i] = r
		end
		self.best = f
	end
	local list, priced = {}, 0
	for id, r in pairs(Store().recipes) do
		local sell = Price(id)
		if sell then priced = priced + 1 end
		list[#list + 1] = { name = r.name, prof = r.prof, who = r.who, p = sell }
	end
	table.sort(list, function(a, b) return (a.p or -1) > (b.p or -1) end)
	if #list == 0 then
		f.rows[1]:SetText(L["No recipes recorded yet - open a profession window once."])
	elseif priced == 0 then
		f.rows[1]:SetText(L["No prices yet - run an auction house scan."])
	end
	for i = 1, 18 do
		local e = list[i]
		if e then
			f.rows[i]:SetFormattedText("|cffcccccc%s|r |cff888888(%s, %s)|r  %s",
				e.name, e.prof, e.who, e.p and ("|cff33ff33+" .. MoneyShort(e.p) .. "|r") or "|cff888888?|r")
		elseif #list > 0 then
			f.rows[i]:SetText("")
		end
	end
	f:Show()
end

function CW:Initialize()
	self.db = S.db.profile.craftwatch
	if not self.db.enable then return end
	if TradeSkillFrame then
		TradeSkillFrame:HookScript("OnShow", function() C_Timer.After(0.1, function() CW:PaintRows() end) end)
	end
	if TradeSkillFrame_Update then hooksecurefunc("TradeSkillFrame_Update", function() CW:PaintRows() end) end
	self:RegisterEvent("TRADE_SKILL_SHOW", function() C_Timer.After(0.2, function() CW:PaintRows() end) end)
	self:RegisterEvent("TRADE_SKILL_UPDATE", function() C_Timer.After(0.2, function() CW:PaintRows() end) end)
	SLASH_SUICW1 = "/suicraft"
	SlashCmdList.SUICW = function(msg)
		if (msg or ""):match("best") then CW:ShowBest() else CW:PaintRows() end
	end
	CW:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, _, spellID)
		if unit ~= "player" or not spellID then return end
		local nm = S.GetSpellInfo and S.GetSpellInfo(spellID)
		if type(nm) == "table" then nm = nm.name end
		if type(nm) ~= "string" then return end
		for id, r in pairs(Store().recipes) do
			if r.name == nm then LedgerAdd(id, nm) break end
		end
	end)
	self.minimapBtn = S:CreateMinimapButton({
		name = "craftwatch", glyph = "CW",
		hub = "character", label = S.L["Craft Watch"], order = 6,
		onLeft = function() CW:ShowBest() end,
		onRight = function() S:ToggleConfig("craftwatch") end,
		tooltip = function()
			GameTooltip:AddLine("SentinelUI " .. L["Craft Watch"])
			GameTooltip:AddLine(L["Shows profit or loss on every recipe in the profession window."], 1, 1, 1)
		end,
	})
end
