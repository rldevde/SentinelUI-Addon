local S = SentinelUI
local L = S.L
local IT = S:NewModule("InfoTrackers", "infotrackers")
local DT
local format, floor = string.format, math.floor

-- session stats
local kills, lootGold, lootItems, lootValue, soldGold, soldItems = 0, 0, 0, 0, 0, 0

local function DB()
	if type(SentinelUITrackerDB) ~= "table" then SentinelUITrackerDB = {} end
	local d = SentinelUITrackerDB
	d.last = d.last or {}
	d.total = d.total or { kills = 0, items = 0, gold = 0, value = 0, soldItems = 0, soldGold = 0 }
	return d
end

local function Save()
	local d = DB()
	local s = d.session or {}
	s.kills, s.items, s.gold = kills, lootItems, lootGold
	s.value, s.soldItems, s.soldGold = lootValue, soldItems, soldGold
	d.session = s
end

local function Short(copper)
	local g = floor(copper / 10000)
	local s = floor(copper / 100) % 100
	if g > 0 then return format("%dg %ds", g, s) end
	return format("%ds", s)
end

local function MoneyText(copper)
	return GetMoneyString and GetMoneyString(copper, true) or Short(copper)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("AUCTION_OWNED_LIST_UPDATE")
ev:RegisterEvent("AUCTION_MULTISELL_UPDATE")
ev:RegisterEvent("CHAT_MSG_LOOT")
ev:RegisterEvent("CHAT_MSG_MONEY")
ev:RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN")
ev:RegisterEvent("PLAYER_XP_UPDATE")

local function Refresh()
	if DT and DT.Update then DT:Update("Auctions") DT:Update("Loot") DT:Update("Kills") end
end
ev:SetScript("OnEvent", function(_, event, msg, arg2)
	if event == "CHAT_MSG_SYSTEM" and msg then
		-- "Your auction of <item> has sold" (en) / deDE variant
		local name = msg:match("[Aa]uction of (.-) has sold") or msg:match("[Aa]uktion.-%s+(.-)%s+wurde") or msg:match("[Vv]erkauft.-%s+(.+)")
		if name or (msg:find("auction") and msg:find("sold")) or msg:find("[Vv]ersteigert") then
			IT:NotifyAuctionSold(name or "?")
		end
	elseif event == "CHAT_MSG_LOOT" and msg then
		lootItems = lootItems + 1
		local link = msg:match("(|Hitem:[^|]+|h%[[^%]]+%]|h)")
		if link then
			local price = select(11, GetItemInfo(link)) or 0
			local qty = tonumber(msg:match("x(%d+)")) or 1
			lootValue = lootValue + price * qty
		end
	elseif event == "CHAT_MSG_MONEY" and msg then
		local g = msg:match("(%d+)%s-[Gg]old") or msg:match("(%d+)%s*G")
		local s2 = msg:match("(%d+)%s-[Ss]ilber") or msg:match("(%d+)%s*S")
		local c = msg:match("(%d+)%s-[Kk]upfer") or msg:match("(%d+)%s*K")
		lootGold = lootGold + (tonumber(g) or 0) * 10000 + (tonumber(s2) or 0) * 100 + (tonumber(c) or 0)
		-- auction payout arrives as money chat right after a sale too
		soldGold = soldGold + 0
		Save()
	elseif event == "CHAT_MSG_COMBAT_XP_GAIN" and msg then
		if not msg:find("died") or true then kills = kills + 1 Save() end
	end
	Refresh()
end)

function IT:NotifyAuctionSold(name, gold)
	soldItems = soldItems + 1
	soldGold = soldGold + (gold or 0)
	Save()
	-- toast-style chat banner + UI error frame flash
	local txt = format("|cffffd700%s|r %s  |cff00ff00+%s|r",
		L["Auction sold"] or "Auction sold", name or "", MoneyText(gold or 0))
	if UIErrorsFrame then UIErrorsFrame:AddMessage(txt, 1, 1, 0.4, 1, 3) end
	print(txt)
	Refresh()
end

local function Rollover()
	local d = DB()
	if d.session then
		d.last = d.session
		local t = d.total
		t.kills = t.kills + (d.session.kills or 0)
		t.items = t.items + (d.session.items or 0)
		t.gold = t.gold + (d.session.gold or 0)
		t.value = t.value + (d.session.value or 0)
		t.soldItems = t.soldItems + (d.session.soldItems or 0)
		t.soldGold = t.soldGold + (d.session.soldGold or 0)
	end
	d.session = { kills = 0, items = 0, gold = 0, value = 0, soldItems = 0, soldGold = 0 }
end

function IT:Initialize()
	-- a session is a real login, not a /reload: the event tells them apart
	local lg = CreateFrame("Frame")
	lg:RegisterEvent("PLAYER_ENTERING_WORLD")
	lg:SetScript("OnEvent", function(_, _, isLogin, isReload)
		if isLogin and not isReload then
			Rollover()
		elseif isReload then
			-- lua state resets on /reload too: restore the running session
			-- so "this session" survives a reload but rolls on real login
			local d = DB()
			local s = d.session or {}
			kills, lootItems, lootGold = s.kills or 0, s.items or 0, s.gold or 0
			lootValue, soldItems, soldGold = s.value or 0, s.soldItems or 0, s.soldGold or 0
			if DT then Refresh() end
		end
	end)
	DT = S:GetModule("DataTexts")
	if not (DT and DT.Register) then return end

	DT:Register("Auctions", {
		interval = 5,
		update = function(slot)
			local n = GetNumAuctionItems and GetNumAuctionItems("owner") or 0
			slot.text:SetText(format("|cffffd700AH|r %d  |cff00ff00+%s|r", n, Short(soldGold)))
		end,
		enter = function(slot)
			local tt = DT:Tooltip(slot)
			tt:AddLine(L["Auctions"] or "Auctions", S.accent.r, S.accent.g, S.accent.b)
			local n = GetNumAuctionItems and GetNumAuctionItems("owner") or 0
			tt:AddDoubleLine(L["Running"] or "Running", tostring(n), 1, 1, 1, 1, 1, 1)
			tt:AddDoubleLine(L["Sold (session)"] or "Sold (session)", tostring(soldItems), 1, 1, 1, 1, 1, 1)
			tt:AddDoubleLine(L["Gold earned"] or "Gold earned", MoneyText(soldGold), 1, 1, 1, 1, 1, 1)
			local d = DB()
			tt:AddDoubleLine(L["Sold (total)"] or "Sold (total)", tostring(d.total.soldItems or 0), 1, 1, 1, 0.7, 0.7, 0.7)
			tt:AddDoubleLine(L["Gold (total)"] or "Gold (total)", MoneyText(d.total.soldGold or 0), 1, 1, 1, 0.7, 0.7, 0.7)
			tt:Show()
		end,
		click = function()
			if AuctionFrame and AuctionFrame:IsShown() then HideUIPanel(AuctionFrame)
			elseif AuctionFrame then ShowUIPanel(AuctionFrame) end
		end,
	})

	DT:Register("Kills", {
		update = function(slot)
			slot.text:SetText(format("|cffff4040K|r %d", kills))
		end,
		enter = function(slot)
			local tt = DT:Tooltip(slot)
			local d = DB()
			tt:AddLine(L["Kills"] or "Kills", S.accent.r, S.accent.g, S.accent.b)
			tt:AddDoubleLine(L["Session"], tostring(kills), 1, 1, 1, 1, 1, 1)
			tt:AddDoubleLine(L["Last session"] or "Last session", tostring(d.last.kills or 0), 1, 1, 1, 0.7, 0.7, 0.7)
			tt:AddDoubleLine(L["Total"], tostring(d.total.kills or 0), 1, 1, 1, 1, 1, 1)
			tt:Show()
		end,
	})

	DT:Register("Loot", {
		update = function(slot)
			slot.text:SetText(format("|cff66c2ffL|r %d · %s |cff888888~%s|r", lootItems, Short(lootGold), Short(lootValue)))
		end,
		enter = function(slot)
			local tt = DT:Tooltip(slot)
			local d = DB()
			tt:AddLine(L["Loot"] or "Loot", S.accent.r, S.accent.g, S.accent.b)
			tt:AddDoubleLine(L["Items (session)"] or "Items (session)", tostring(lootItems), 1, 1, 1, 1, 1, 1)
			tt:AddDoubleLine(L["Gold looted"] or "Gold looted", MoneyText(lootGold), 1, 1, 1, 1, 1, 1)
			tt:AddDoubleLine(L["Vendor value"] or "Vendor value", MoneyText(lootValue), 1, 1, 1, 1, 1, 1)
			tt:AddDoubleLine(L["Items (last)"] or "Items (last)", tostring(d.last.items or 0), 1, 1, 1, 0.7, 0.7, 0.7)
			tt:AddDoubleLine(L["Gold (last)"] or "Gold (last)", MoneyText(d.last.gold or 0), 1, 1, 1, 0.7, 0.7, 0.7)
			tt:AddDoubleLine(L["Items (total)"] or "Items (total)", tostring(d.total.items or 0), 1, 1, 1, 1, 1, 1)
			tt:AddDoubleLine(L["Gold (total)"] or "Gold (total)", MoneyText(d.total.gold or 0), 1, 1, 1, 1, 1, 1)
			tt:Show()
		end,
	})
end
