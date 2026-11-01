local S = SentinelUI
local L = S.L
local IT = S:NewModule("InfoTrackers", "infotrackers")
local DT
local format, floor = string.format, math.floor

-- session stats
local kills, lootGold, lootItems, lootValue, soldGold, soldItems = 0, 0, 0, 0, 0, 0

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
	if DT then DT:Update("Auctions") DT:Update("Loot") DT:Update("Kills") end
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
	elseif event == "CHAT_MSG_COMBAT_XP_GAIN" and msg then
		if not msg:find("died") or true then kills = kills + 1 end
	end
	Refresh()
end)

function IT:NotifyAuctionSold(name, gold)
	soldItems = soldItems + 1
	soldGold = soldGold + (gold or 0)
	-- toast-style chat banner + UI error frame flash
	local txt = format("|cffffd700%s|r %s  |cff00ff00+%s|r",
		L["Auction sold"] or "Auction sold", name or "", MoneyText(gold or 0))
	if UIErrorsFrame then UIErrorsFrame:AddMessage(txt, 1, 1, 0.4, 1, 3) end
	print(txt)
	Refresh()
end

function IT:Initialize()
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
			tt:AddLine(L["Kills (session)"] or "Kills (session)", S.accent.r, S.accent.g, S.accent.b)
			tt:AddDoubleLine(L["Kills"] or "Kills", tostring(kills), 1, 1, 1, 1, 1, 1)
			tt:Show()
		end,
	})

	DT:Register("Loot", {
		update = function(slot)
			slot.text:SetText(format("|cff66c2ffL|r %d · %s |cff888888~%s|r", lootItems, Short(lootGold), Short(lootValue)))
		end,
		enter = function(slot)
			local tt = DT:Tooltip(slot)
			tt:AddLine(L["Loot (session)"] or "Loot (session)", S.accent.r, S.accent.g, S.accent.b)
			tt:AddDoubleLine(L["Items"], tostring(lootItems), 1, 1, 1, 1, 1, 1)
			tt:AddDoubleLine(L["Gold looted"] or "Gold looted", MoneyText(lootGold), 1, 1, 1, 1, 1, 1)
			tt:AddDoubleLine(L["Vendor value"] or "Vendor value", MoneyText(lootValue), 1, 1, 1, 1, 1, 1)
			tt:Show()
		end,
	})
end
