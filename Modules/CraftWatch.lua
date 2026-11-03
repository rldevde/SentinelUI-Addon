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
	return sell * made - CraftCost(i)
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
					local p = S:SafeCall("CraftWatch:Profit", Profit, idx)
					if p then
						btn.suiProfit:SetFormattedText("%s%s|r",
							p >= 0 and "|cff33ff33+" or "|cffff3333", MoneyShort(p))
					end
				end
			end
		end
	end
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
	SlashCmdList.SUICW = function() CW:PaintRows() end
	self.minimapBtn = S:CreateMinimapButton({
		name = "craftwatch", glyph = "CW",
		hub = "character", label = S.L["Craft Watch"], order = 6,
		onLeft = function() CW:PaintRows() end,
		tooltip = function()
			GameTooltip:AddLine("SentinelUI " .. L["Craft Watch"])
			GameTooltip:AddLine(L["Shows profit or loss on every recipe in the profession window."], 1, 1, 1)
		end,
	})
end
