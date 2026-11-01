-- Messenger: every whisper/bnet-whisper conversation gets
-- its own small chat window with history, timestamps, clickable links and a
-- reply editbox. Optionally hides whispers from the regular chat frames.
local _, ns = ...
local S = ns.S
local L = S.L
local MS = S:NewModule("Messenger", "messenger")
local pairs, ipairs, wipe = pairs, ipairs, wipe
local format, date, tostring = format, date, tostring
local strlower, strtrim = strlower, strtrim
local tinsert, tremove, tsort = tinsert, table.remove, table.sort
local CreateFrame = CreateFrame
local UnitName = UnitName
local SendChatMessage = SendChatMessage
local GameTooltip = GameTooltip
local C_Timer = C_Timer
local PlaySound = PlaySound
local InCombatLockdown = InCombatLockdown
local UnitIsAFK = UnitIsAFK
local UnitIsDND = UnitIsDND
local IsShiftKeyDown = IsShiftKeyDown
local IsControlKeyDown = IsControlKeyDown

local WIN_W, WIN_H = 430, 300
local WIN_MIN_W, WIN_MIN_H = 330, 220
local TAB_H = 20
local convs = {}      -- key -> conv { name, target, bnet, bnID, class, lines, frame, tab, seq }
local convSeq = 0     -- creation order -> stable left-to-right tab order
local mainWin         -- the single tabbed messenger window
local activeConv      -- conversation whose page is currently visible
local lastConv
local pendingPopups = {}  -- convs waiting until combat ends
local Append          -- forward decl: used by the reply editbox handler
local RefreshTitle    -- forward decl: used by the ? action button
local ActivateTab, UpdateTabs, LayoutTabs  -- forward decls

local function ConvKey(sender, bnet, bnID)
	if bnet then return "bn:" .. tostring(bnID or sender) end
	return "w:" .. tostring(sender or "?")
end

local function ShortName(name)
	return (name:match("^([^%-]+)")) or name
end

-- history lives in the account-wide global DB so every character sees all
-- conversations (shared account-wide history). Old per-character entries are
-- merged in once and then removed.
local function Hist()
	local g = S.db and S.db.global
	if g and (not MS.db or MS.db.accountHistory ~= false) then
		g.messengerHist = g.messengerHist or {}
		local old = S.private and S.private.messengerHist
		if old then
			for key, h in pairs(old) do
				local dst = g.messengerHist[key] or {}
				local seen = {}
				for _, l in ipairs(dst) do seen[(l.t or 0) .. "|" .. (l.m or "") .. "|" .. tostring(l.me)] = true end
				for _, l in ipairs(h) do
					local k = (l.t or 0) .. "|" .. (l.m or "") .. "|" .. tostring(l.me)
					if not seen[k] then dst[#dst + 1] = l seen[k] = true end
				end
				table.sort(dst, function(a, b) return (a.t or 0) < (b.t or 0) end)
				g.messengerHist[key] = dst
			end
			S.private.messengerHist = nil
		end
		return g.messengerHist
	end
	S.private.messengerHist = S.private.messengerHist or {}
	return S.private.messengerHist
end

local function Conv(sender, bnet, bnID)
	local key = ConvKey(sender, bnet, bnID)
	local c = convs[key]
	-- whisper names can come back with or without realm suffix; reuse an
	-- existing conversation matched by short name so replies land in the
	-- window the user actually opened (e.g. "/sm Araya" vs "Araya-Realm")
	if not c and not bnet and sender then
		local short = ShortName(sender)
		for _, conv in pairs(convs) do
			if not conv.bnet and ShortName(conv.target) == short then c = conv break end
		end
		if c then convs[key] = c end
	end
	if c then return c end
	convSeq = convSeq + 1
	c = { key = key, target = sender, bnet = bnet, bnID = bnID, name = ShortName(sender or "?"), lines = {}, seq = convSeq }
	convs[key] = c
	-- replay stored history; also match older keys that carry a realm suffix
	local h = Hist()[key]
	if not h and not bnet and sender then
		local short = ShortName(sender)
		for hk in pairs(Hist()) do
			local stored = hk:match("^w:(.+)$")
			if stored and ShortName(stored) == short then h = Hist()[hk] break end
		end
	end
	if h then
		for _, l in ipairs(h) do c.lines[#c.lines + 1] = l end
		-- session marker (transient, not stored in history)
		if #c.lines > 0 then c.lines[#c.lines + 1] = { t = time(), sys = true } end
	end
	return c
end

local function PushLine(c, text, mine)
	local line = { t = time(), m = text, me = mine and true or false }
	c.lines[#c.lines + 1] = line
	local hist = Hist()
	hist[c.key] = hist[c.key] or {}
	tinsert(hist[c.key], line)
	local cap = (MS.db and MS.db.historySize) or 100
	while #hist[c.key] > cap do tremove(hist[c.key], 1) end
	return line
end

local function ClassHex(cls)
	local cc = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
	return cc and format("%02x%02x%02x", cc.r * 255, cc.g * 255, cc.b * 255) or "9d9da1"
end

local function ClassName(cls)
	local names = LOCALIZED_CLASS_NAMES_MALE or LOCALIZED_CLASS_NAMES_FEMALE
	return (cls and names and names[cls]) or cls
end

-- character info (guild/level/class) is filled passively: FillFromUnits when
-- the partner is in our group, GUID lookup on whispers, and WHO_LIST_UPDATE
-- results when the user runs /who manually. SendWho itself is protected and
-- must NOT be called from addon code (ADDON_ACTION_BLOCKED).

-- flat message rows (no bubbles): a thin colored edge bar marks the side,
-- a small meta line carries name/time and the message text flows below
local ROW_GAP = 6
local BLANK = [[Interface\Buttons\WHITE8X8]]

-- emoticons: rendered as inline textures (own pixel icons in Media/Textures)
local SMILE_DIR = [[Interface\AddOns\SentinelUI\Media\Textures\Msg_]]
local SMILE_ORDER = { ":-)", ";-)", ":-D", ":-(", ":-P", ":-p", ":)", ";)", ":D", ":(", ":P", ":p", "<3", "o.O", "O.o", "^^" }
local SMILE_MAP = {
	[":)"] = "Smile", [":-)"] = "Smile", [";)"] = "Wink", [";-)"] = "Wink",
	[":D"] = "Laugh", [":-D"] = "Laugh", ["^^"] = "Laugh",
	[":("] = "Sad", [":-("] = "Sad",
	[":P"] = "Tongue", [":-P"] = "Tongue", [":p"] = "Tongue", [":-p"] = "Tongue",
	["<3"] = "Heart", ["o.O"] = "Confuse", ["O.o"] = "Confuse",
}
local function Smileys(text)
	if MS.db and MS.db.smilies == false then return text end
	for _, pat in ipairs(SMILE_ORDER) do
		text = text:gsub(pat:gsub("%W", "%%%0"), "|T" .. SMILE_DIR .. SMILE_MAP[pat] .. ":12:12:0:0|t")
	end
	return text
end

-- plain-frame scrolling: content moves up inside a clipped container instead of
-- relying on the ScrollFrame widget (whose scroll child rendered nothing here)
local function SetScroll(f, pos)
	local maxScroll = math.max(0, f.content:GetHeight() - f.scroll:GetHeight())
	f.scrollPos = math.max(0, math.min(maxScroll, pos or 0))
	f.content:ClearAllPoints()
	f.content:SetPoint("TOPLEFT", f.scroll, "TOPLEFT", 0, f.scrollPos)
end

local function AddBubbleRaw(c, l)
	local f = c.frame
	if not f then return end
	local maxScroll = math.max(0, f.content:GetHeight() - f.scroll:GetHeight())
	local atBottom = not f:IsShown() or (f.scrollPos or 0) >= maxScroll - 8
	f.chatH = f.chatH or 6

	-- transient session markers render as a centered divider line
	if l.sys then
		local sep = S:FontString(f.content, 9, nil, S.media.font, nil, "CENTER")
		sep:SetPoint("TOP", f.content, "TOP", 0, -f.chatH)
		sep:SetText("|cff556070— " .. (L["new session"] or "new session") .. (l.t and (" " .. date("%H:%M", l.t)) or "") .. " —|r")
		f.chatH = f.chatH + 14 + ROW_GAP
		f.content:SetHeight(f.chatH + 6)
		if atBottom then SetScroll(f, 1e9) end
		return
	end

	local row = CreateFrame("Frame", nil, f.content)
	row:SetPoint(l.me and "TOPRIGHT" or "TOPLEFT", f.content, l.me and "TOPRIGHT" or "TOPLEFT", 0, -f.chatH)
	row:SetWidth(WIN_W - 16)

	-- colored edge bar: incoming = class color on the left, own = accent right
	local bar = row:CreateTexture(nil, "ARTWORK")
	bar:SetTexture(BLANK)
	bar:SetWidth(2)
	if l.me then
		bar:SetPoint("TOPRIGHT", row, "TOPRIGHT", -2, -2)
		bar:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -2, 2)
		bar:SetVertexColor(S.accent.r, S.accent.g, S.accent.b, 0.95)
	else
		bar:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -2)
		bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 2, 2)
		local cc = c.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.class]
		if cc then bar:SetVertexColor(cc.r, cc.g, cc.b, 0.95)
		else bar:SetVertexColor(0.45, 0.45, 0.50, 0.95) end
	end

	-- meta line: "Name · HH:MM" (incoming) or just "HH:MM" (own)
	local meta = S:FontString(row, 9, nil, S.media.font, nil, l.me and "RIGHT" or "LEFT")
	meta:SetPoint(l.me and "TOPRIGHT" or "TOPLEFT", row, l.me and "TOPRIGHT" or "TOPLEFT", l.me and -12 or 12, -4)
	local timeStr = (not MS.db or MS.db.timestamps ~= false) and l.t and date("%H:%M", l.t) or nil
	if l.me then
		meta:SetText(timeStr and "|cff666f7a" .. timeStr .. "|r" or "")
	else
		meta:SetText(format("|cff%s%s|r%s", ClassHex(c.class), c.name or "?",
			timeStr and "  |cff666f7a" .. timeStr .. "|r" or ""))
	end

	local fs = S:FontString(row, 12, nil, S.media.font, nil, l.me and "RIGHT" or "LEFT")
	fs:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -16)
	fs:SetPoint("TOPRIGHT", row, "TOPRIGHT", -12, -16)
	fs:SetWordWrap(true)
	fs:SetText(Smileys(l.m or ""))
	fs:SetTextColor(0.92, 0.93, 0.94)
	row.fs = fs

	row:SetHeight(16 + fs:GetStringHeight() + 8)

	-- hairline divider under the row
	local div = row:CreateTexture(nil, "BORDER")
	div:SetTexture(BLANK)
	div:SetHeight(1)
	div:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 10, 0)
	div:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -10, 0)
	div:SetVertexColor(1, 1, 1, 0.06)

	-- day separator
	local day = date("%x", l.t)
	if day ~= f.lastDay then
		f.lastDay = day
		local label = day == date("%x") and (L["Today"] or "Today") or date("%d.%m.%Y", l.t)
		local sep = S:FontString(f.content, 9, nil, S.media.font, nil, "CENTER")
		sep:SetPoint("TOP", f.content, "TOP", 0, -f.chatH)
		sep:SetText("|cff666f7a— " .. label .. " —|r")
		f.chatH = f.chatH + 16 + ROW_GAP
		row:ClearAllPoints()
		row:SetPoint(l.me and "TOPRIGHT" or "TOPLEFT", f.content, l.me and "TOPRIGHT" or "TOPLEFT", 0, -f.chatH)
	end
	f.lastBubble = row
	f.chatH = f.chatH + row:GetHeight() + ROW_GAP
	f.content:SetHeight(f.chatH + 6)

	-- links: hover shows tooltip, click opens, shift-click inserts into reply box
	row:EnableMouse(true)
	row:SetScript("OnEnter", function()
		local link = l.m:match("|H(.-)|h")
		if link then
			GameTooltip:SetOwner(row, "ANCHOR_CURSOR")
			GameTooltip:SetHyperlink(link)
			GameTooltip:Show()
		end
	end)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)
	row:SetScript("OnMouseUp", function(_, btn)
		if btn ~= "LeftButton" then return end
		local link = l.m:match("|H(.-)|h")
		if not link then return end
		if IsShiftKeyDown() then
			if f.editbox and f.editbox:HasFocus() then f.editbox:Insert(link) elseif ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
		elseif ChatFrame_OnHyperlinkShow then
			ChatFrame_OnHyperlinkShow(row, link, nil, btn)
		end
	end)

	if atBottom or l.me then SetScroll(f, 1e9) end
end

-- bubble creation must never break silently: route errors into the addon log
local function AddBubble(c, l)
	S:SafeCall("Messenger:AddBubble", AddBubbleRaw, c, l)
end

-- conversation window: ONE shared window with a tab strip. Every whisper
-- conversation is a tab on a single movable, resizable window instead of a
-- separate frame per contact. The window remembers its geometry.

local function SaveGeom(f)
	MS.private = MS.private or {}
	MS.private.messengerMain = { x = f:GetLeft(), y = f:GetTop(), w = f:GetWidth(), h = f:GetHeight() }
end

-- rebuild every page's content width after a resize; rows have a fixed
-- width set at creation, so re-point them and let the fontstrings rewrap
local function ResizePages()
	for _, conv in pairs(convs) do
		local p = conv.frame
		if p and p.content and p.scroll then
			local w = p.scroll:GetWidth()
			if w and w > 0 then
				p.content:SetWidth(w)
				for _, ch in ipairs({ p.content:GetChildren() }) do
					if ch.fs then ch:SetWidth(w) end
				end
			end
			SetScroll(p, p.scrollPos or 0)
		end
	end
end

-- sorted list of live conversations (stable creation order)
local function ConvList()
	local list = {}
	local seen = {}
	for _, c in pairs(convs) do
		if not seen[c] then seen[c] = true list[#list + 1] = c end
	end
	table.sort(list, function(x, y) return (x.seq or 0) < (y.seq or 0) end)
	return list
end

UpdateTabs = function()
	for _, c in pairs(convs) do
		local t = c.tab
		if t then
			local n = c.unread or 0
			t.label:SetText(format("|cff%s%s|r%s", ClassHex(c.class), c.name or "?",
				n > 0 and format(" |cffff4040(%d)|r", n) or ""))
			local w = t.label:GetStringWidth() or 60
			t:SetWidth(math.max(56, math.min(140, w + 24)))
			local on = c == activeConv
			t.bar:SetVertexColor(S.accent.r, S.accent.g, S.accent.b, on and 1 or 0)
		end
	end
end

LayoutTabs = function()
	if not mainWin then return end
	local x = 0
	for _, c in ipairs(ConvList()) do
		local t = c.tab
		if t then
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", mainWin.tabBar, "TOPLEFT", x, 0)
			x = x + (t:GetWidth() or 90) + 3
		end
	end
end

local function RemoveConv(c)
	for k, v in pairs(convs) do if v == c then convs[k] = nil end end
	if c.tab then c.tab:Hide() end
	if c.frame then
		c.frame:Hide()
		if c.frame.editbox then c.frame.editbox:Hide() end
	end
	if lastConv == c then lastConv = nil end
	if activeConv == c then
		activeConv = nil
		local other = ConvList()[1]
		if other then ActivateTab(other) elseif mainWin then mainWin:Hide() end
	end
	LayoutTabs()
	MS:UpdateBadge()
end

local function CreateTab(c)
	local t = CreateFrame("Button", nil, mainWin.tabBar)
	t:SetHeight(TAB_H)
	t:SetWidth(90)
	S:SetTemplate(t, "Default")
	t.label = S:FontString(t, 10, "OUTLINE", S.media.font, nil, "CENTER")
	t.label:SetPoint("CENTER")
	-- accent underline for the active tab
	t.bar = t:CreateTexture(nil, "OVERLAY")
	t.bar:SetTexture(BLANK)
	t.bar:SetPoint("BOTTOMLEFT", 1, 1)
	t.bar:SetPoint("BOTTOMRIGHT", -1, 1)
	t.bar:SetHeight(2)
	t.bar:SetVertexColor(S.accent.r, S.accent.g, S.accent.b, 0)
	t:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
	t:SetScript("OnClick", function(_, btn)
		if btn == "MiddleButton" then RemoveConv(c)
		elseif btn == "RightButton" then MS:ConvMenu(c)
		else
			if not mainWin:IsShown() then mainWin:Show() end
			ActivateTab(c)
		end
	end)
	t:SetScript("OnEnter", function(bb)
		GameTooltip:SetOwner(bb, "ANCHOR_BOTTOM")
		GameTooltip:SetText(L["Left-click: open  |  Right-click: menu  |  Middle-click: close tab"] or "Left-click: open  |  Right-click: menu  |  Middle-click: close tab")
		GameTooltip:Show()
	end)
	t:SetScript("OnLeave", function() GameTooltip:Hide() end)
	c.tab = t
end

local function EnsureMain()
	if mainWin then return mainWin end
	local f = CreateFrame("Frame", "SentinelUIMessenger", UIParent)
	f:SetSize(WIN_W, WIN_H)
	MS.private = MS.private or {}
	local pos = MS.private.messengerMain
	if pos and pos.x then
		f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.x, pos.y)
		if pos.w and pos.w > WIN_MIN_W then f:SetSize(pos.w, pos.h or WIN_H) end
	else
		f:SetPoint("CENTER", UIParent, "CENTER", 60, 40)
	end
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)  -- newest/clicked window rises inside its strata
	f:SetToplevel(true)  -- newest/clicked window rises inside its strata
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:SetResizable(true)
	if f.SetMinResize then f:SetMinResize(WIN_MIN_W, WIN_MIN_H) end
	S:SetTemplate(f, "Default", "TOP")

	-- accent header band
	f.title = S:FontString(f, 11, "OUTLINE", S.media.unitFont, nil, "LEFT")
	f.title:SetPoint("TOPLEFT", 10, -8)
	S:RegisterAccent(f.title, "text")
	f.subtitle = S:FontString(f, 9, nil, S.media.font, nil, "LEFT")
	f.subtitle:SetPoint("TOPLEFT", 10, -20)
	f.subtitle:SetTextColor(0.55, 0.60, 0.55)
	local rule = f:CreateTexture(nil, "ARTWORK")
	rule:SetTexture(BLANK)
	rule:SetPoint("TOPLEFT", 1, -30)
	rule:SetPoint("TOPRIGHT", -1, -30)
	rule:SetHeight(1)
	rule:SetVertexColor(S.accent.r, S.accent.g, S.accent.b, 0.9)

	-- drag zone: only the header band moves the window, so chat text stays
	-- clickable
	f.drag = CreateFrame("Button", nil, f)
	f.drag:SetPoint("TOPLEFT", 1, -1)
	f.drag:SetPoint("TOPRIGHT", -1, -1)
	f.drag:SetHeight(29)
	f.drag:RegisterForDrag("LeftButton")
	f.drag:SetScript("OnDragStart", function() f:StartMoving() end)
	f.drag:SetScript("OnDragStop", function() f:StopMovingOrSizing() SaveGeom(f) end)

	-- title click zone: shift inserts the name, ctrl invites, right-click menu
	f.titleBtn = CreateFrame("Button", nil, f.drag)
	f.titleBtn:SetPoint("TOPLEFT", 4, -2)
	f.titleBtn:SetSize(190, 26)
	f.titleBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	f.titleBtn:SetScript("OnClick", function(_, btn)
		local c = activeConv
		if not c then return end
		if btn == "RightButton" then
			MS:ConvMenu(c)
		elseif IsShiftKeyDown() then
			local p = c.frame
			if p and p.editbox then p.editbox:SetFocus() p.editbox:Insert(c.target or c.name) end
		elseif IsControlKeyDown() and not c.bnet then
			local inv = C_PartyInfo and C_PartyInfo.InviteUnit or InviteUnit
			if inv then inv(c.target) end
		end
	end)
	f.titleBtn:SetScript("OnEnter", function(bb)
		GameTooltip:SetOwner(bb, "ANCHOR_BOTTOM")
		GameTooltip:SetText(L["Shift: insert name  |  Ctrl: invite  |  Right-click: menu"] or "Shift: insert name  |  Ctrl: invite  |  Right-click: menu")
		GameTooltip:Show()
	end)
	f.titleBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

	f.close = CreateFrame("Button", nil, f)
	f.close:SetSize(16, 16)
	f.close:SetPoint("TOPRIGHT", -7, -6)
	-- the header drag button covers this area: raise the close button above
	-- it and register clicks explicitly, otherwise OnClick never fires
	f.close:SetFrameLevel(f:GetFrameLevel() + 10)
	f.close:RegisterForClicks("LeftButtonUp")
	S:CreateBackdrop(f.close, "Default")
	f.close.fs = S:FontString(f.close, 12, "OUTLINE", S.media.numberFont, nil, "CENTER")
	f.close.fs:SetPoint("CENTER")
	f.close.fs:SetText("x")
	f.close:SetScript("OnClick", function() f:Hide() end)

	-- action buttons work on the ACTIVE conversation
	local function ActionBtn(label, tip, onClick)
		local b = CreateFrame("Button", nil, f)
		b:SetSize(16, 16)
		b:SetFrameLevel(f:GetFrameLevel() + 10)
		b:RegisterForClicks("LeftButtonUp")
		S:CreateBackdrop(b, "Default")
		b.fs = S:FontString(b, 10, "OUTLINE", S.media.numberFont, nil, "CENTER")
		b.fs:SetPoint("CENTER")
		b.fs:SetText(label)
		b:SetScript("OnClick", function() if activeConv then S:SafeCall("Messenger:Action", onClick) end end)
		b:SetScript("OnEnter", function(bb)
			GameTooltip:SetOwner(bb, "ANCHOR_BOTTOM")
			GameTooltip:SetText(tip)
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
		return b
	end
	f.btnInvite = ActionBtn("E", L["Invite to group"], function()
		local inv = C_PartyInfo and C_PartyInfo.InviteUnit or InviteUnit
		if inv and activeConv then inv(activeConv.target) end
	end)
	f.btnFriend = ActionBtn("F", L["Add friend"], function()
		local add = C_FriendList and C_FriendList.AddFriend or AddFriend
		if add and activeConv then add(activeConv.target) end
	end)
	f.btnWho = ActionBtn("?", L["Who"], function() if activeConv then RefreshTitle(activeConv) end end)
	f.btnIgnore = ActionBtn("I", IGNORE or "Ignore", function()
		local ig = C_FriendList and C_FriendList.AddIgnore or AddIgnore
		if ig and activeConv then ig(activeConv.target) end
	end)
	f.btnLog = ActionBtn("L", L["Chat Logs"] or "Chat Logs", function() if activeConv then MS:OpenHistory(activeConv.key) end end)
	f.btnInvite:SetPoint("RIGHT", f.close, "LEFT", -5, 0)
	f.btnFriend:SetPoint("RIGHT", f.btnInvite, "LEFT", -4, 0)
	f.btnIgnore:SetPoint("RIGHT", f.btnFriend, "LEFT", -4, 0)
	f.btnWho:SetPoint("RIGHT", f.btnIgnore, "LEFT", -4, 0)
	f.btnLog:SetPoint("RIGHT", f.btnWho, "LEFT", -4, 0)

	-- tab strip under the header
	f.tabBar = CreateFrame("Frame", nil, f)
	f.tabBar:SetPoint("TOPLEFT", 6, -32)
	f.tabBar:SetPoint("TOPRIGHT", -6, -32)
	f.tabBar:SetHeight(TAB_H + 2)

	-- resize grip, bottom right (Blizzard chat grip look)
	f.grip = CreateFrame("Button", nil, f)
	f.grip:SetSize(16, 16)
	f.grip:SetPoint("BOTTOMRIGHT", -2, 2)
	local gt = f.grip:CreateTexture(nil, "OVERLAY")
	gt:SetAllPoints()
	gt:SetTexture([[Interface\ChatFrame\UI-ChatIM-SizeGrabber-Down]])
	f.grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
	f.grip:SetScript("OnMouseUp", function() f:StopMovingOrSizing() SaveGeom(f) ResizePages() end)

	f:SetScript("OnSizeChanged", function() ResizePages() end)
	f:SetScript("OnShow", function()
		local c = activeConv or lastConv
		if not c then
			for _, v in ipairs(ConvList()) do c = v break end
		end
		if c then ActivateTab(c) end
		MS:UpdateBadge()
	end)
	f:Hide()
	tinsert(UISpecialFrames, "SentinelUIMessenger")
	mainWin = f
	return f
end

-- per-conversation page: clipped chat scroll area inside the shared window,
-- plus the reply editbox (kept on the window because it lives below the page)
local function EnsurePage(c)
	EnsureMain()
	if c.frame then
		if not c.tab then CreateTab(c) end
		LayoutTabs()
		return c.frame
	end
	local p = CreateFrame("Frame", nil, mainWin)
	p:SetPoint("TOPLEFT", 8, -(34 + TAB_H + 6))
	p:SetPoint("BOTTOMRIGHT", -8, 36)
	p:Hide()

	local chatBox = CreateFrame("Frame", nil, p)
	chatBox:SetAllPoints(p)
	if chatBox.SetClipsChildren then chatBox:SetClipsChildren(true) end
	chatBox:EnableMouseWheel(true)
	chatBox:SetScript("OnMouseWheel", function(_, d)
		SetScroll(p, (p.scrollPos or 0) - d * 60)
	end)
	local content = CreateFrame("Frame", nil, chatBox)
	content:SetPoint("TOPLEFT", chatBox, "TOPLEFT")
	content:SetSize(WIN_W - 16, 8)
	p.scroll, p.content = chatBox, content
	-- shared header widgets live on the window; the page borrows them so
	-- RefreshTitle can keep writing f.title / f.subtitle / f.btn*
	p.title, p.subtitle = mainWin.title, mainWin.subtitle
	p.btnInvite, p.btnFriend, p.btnWho, p.btnIgnore, p.btnLog =
		mainWin.btnInvite, mainWin.btnFriend, mainWin.btnWho, mainWin.btnIgnore, mainWin.btnLog

	local eb = CreateFrame("EditBox", nil, mainWin)
	eb:SetPoint("BOTTOMLEFT", 10, 8)
	eb:SetPoint("BOTTOMRIGHT", -22, 8)
	eb:SetHeight(20)
	eb:SetAutoFocus(false)
	eb:SetMultiLine(false)
	eb:SetMaxLetters(255)
	eb:EnableMouse(true)
	-- without a font object typed text renders nothing and the box looks dead
	eb:SetFont(S.media.font or STANDARD_TEXT_FONT, 12, "OUTLINE")
	eb:SetTextColor(1, 1, 1)
	eb:SetTextInsets(6, 6, 0, 0)
	S:SkinEditBox(eb)
	eb.hint = S:FontString(eb, 10, nil, S.media.unitFont, nil, "LEFT")
	eb.hint:SetPoint("LEFT", 4, 0)
	eb.hint:SetText(L["Whisper reply"] .. "...")
	eb.hint:SetTextColor(0.4, 0.4, 0.45)
	eb:SetScript("OnEditFocusGained", function(e) e.hint:Hide() end)
	eb:SetScript("OnEditFocusLost", function(e) if e:GetText() == "" then e.hint:Show() end end)
	eb:SetScript("OnEnterPressed", function(e)
		local text = e:GetText()
		if text and text ~= "" then
			if c.bnet then
				if BNSendWhisper then BNSendWhisper(c.bnID, text) end
			else
				SendChatMessage(text, "WHISPER", nil, c.target)
			end
			-- local echo: show immediately, dedup the INFORM echo
			Append(c, text, true)
			lastConv = c
		end
		e:SetText("")
		-- the reply box stays focused so you can keep typing
		e.histIdx = nil
		if MS.db and MS.db.keepFocus == false then e:ClearFocus() end
	end)
	eb:SetScript("OnEscapePressed", function(e) e:ClearFocus() end)
	-- input history: arrow up/down walks your own sent messages
	eb:SetAltArrowKeyMode(false)
	eb:SetScript("OnArrowPressed", function(e, key)
		if key ~= "UP" and key ~= "DOWN" then
			e:SetPropagateKeyboardInput(true)
			return
		end
		if key == "UP" and not e.histIdx then e.draft = e:GetText() end
		local step = key == "UP" and -1 or 1
		local i = (e.histIdx or (#c.lines + 1)) + step
		while i >= 1 and i <= #c.lines do
			local l = c.lines[i]
			if l.me and l.m then
				e.histIdx = i
				e:SetText(l.m)
				e:SetPropagateKeyboardInput(false)
				return
			end
			i = i + step
		end
		if step > 0 then e.histIdx = nil e:SetText(e.draft or "") e.draft = nil end
		e:SetPropagateKeyboardInput(false)
	end)
	p.editbox = eb
	eb:Hide()

	CreateTab(c)
	c.frame = p
	LayoutTabs()
	UpdateTabs()
	return p
end

-- guild/level/class via unit API when the partner is in our party/raid
-- (no /who needed — works even if the who query is throttled)
local function FillFromUnits(c)
	if c.bnet or (c.level and c.guild) then return end
	local short = ShortName(c.target)
	local units = { "player", "party1", "party2", "party3", "party4" }
	for i = 1, 40 do units[#units + 1] = "raid" .. i end
	for _, u in ipairs(units) do
		local name = UnitName(u)
		if name and ShortName(name) == short then
			if not c.level then c.level = UnitLevel(u) end
			if not c.class then local _, cls = UnitClass(u) c.class = cls end
			if not c.race then local race = UnitRace(u) c.race = race end
			if not c.guild then local g = GetGuildInfo(u) if g then c.guild = g end end
			return
		end
	end
end

RefreshTitle = function(c)
	local f = c.frame
	if not f then return end
	FillFromUnits(c)
	-- the header belongs to the window, so only the active conversation may
	-- paint it; other conversations still get their tab label refreshed
	if c ~= activeConv then UpdateTabs() return end
	local cc = c.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.class]
	if f.btnInvite then
		f.btnInvite:SetShown(not c.bnet)
		f.btnFriend:SetShown(not c.bnet)
		f.btnIgnore:SetShown(not c.bnet)
	end
	local cls = c.classStr or ClassName(c.class)
	if c.bnet then
		f.title:SetText(c.name .. " |cff888888(BNet)|r")
	else
		local tag = cls and format(" |cff888888(|r|cff%s%s|r|cff888888)|r", ClassHex(c.class), cls) or ""
		if cc then
			f.title:SetText(format("|cff%02x%02x%02x%s|r%s", cc.r * 255, cc.g * 255, cc.b * 255, c.name, tag))
		else
			f.title:SetText(c.name .. tag)
		end
	end
	-- subtitle: level · race · <guild>
	if f.subtitle then
		if c.bnet then
			f.subtitle:SetText("")
		else
			local bits = {}
			if c.level then bits[#bits + 1] = format("%s %d", L["Level"] or "Level", c.level) end
			if c.race then bits[#bits + 1] = c.race end
			if c.guild and c.guild ~= "" then bits[#bits + 1] = "|cff33cc66<" .. c.guild .. ">|r" end
			f.subtitle:SetText(table.concat(bits, "  ·  "))
		end
	end
	UpdateTabs()
end

ActivateTab = function(c)
	activeConv = c
	lastConv = c
	for _, conv in pairs(convs) do
		if conv.frame then
			conv.frame:Hide()
			if conv.frame.editbox then conv.frame.editbox:Hide() end
		end
	end
	local p = c.frame
	if not p._loaded then
		p._loaded = true
		for _, l in ipairs(c.lines) do AddBubble(c, l) end
	end
	p:Show()
	if p.editbox then p.editbox:Show() end
	RefreshTitle(c)
	c.unread = nil
	SetScroll(p, 1e9)
	UpdateTabs()
	MS:UpdateBadge()
	if not MS.db or MS.db.autoFocus ~= false then p.editbox:SetFocus() end
end

local function ShowConv(c, quiet)
	local p = EnsurePage(c)
	if quiet and mainWin:IsShown() then
		-- window already open: don't steal the tab, just flag the unread badge
		UpdateTabs()
		return
	end
	mainWin:Show()
	ActivateTab(c)
end

Append = function(c, text, mine)
	PushLine(c, text, mine)
	if c.frame and c.frame._loaded then AddBubble(c, c.lines[#c.lines]) end
end

-- events --------------------------------------------------------------------
function MS:OnWhoList()
	local getNum = C_FriendList and C_FriendList.GetNumWhoResults or GetNumWhoResults
	local getInfo = C_FriendList and C_FriendList.GetWhoInfo or GetWhoInfo
	if not getNum or not getInfo then return end
	for i = 1, getNum() do
		local w = getInfo(i)
		local fullName, guild, level, classStr
		if type(w) == "table" then
			fullName, guild, level, classStr = w.fullName, w.fullGuildName, w.level, w.classStr
		else
			fullName, guild, level, _, classStr = w
		end
		if fullName then
			for _, c in pairs(convs) do
				if not c.bnet and ShortName(c.target) == ShortName(fullName) then
					c.guild = guild
					c.level = level
					c.classStr = classStr
					RefreshTitle(c)
				end
			end
		end
	end
end

function MS:OnWhisper(event, msg, sender, _, _, _, _, _, _, _, _, guid, bnID)
	local bnet = event == "CHAT_MSG_BN_WHISPER" or event == "CHAT_MSG_BN_WHISPER_INFORM"
	local mine = event == "CHAT_MSG_WHISPER_INFORM" or event == "CHAT_MSG_BN_WHISPER_INFORM"
	if not sender or sender == "" then return end
	local c = Conv(sender, bnet, bnet and bnID or nil)
	if guid and guid ~= "" and GetPlayerInfoByGUID then
		local _, cls, race = pcall(function()
			local _, englishClass, localizedRace = GetPlayerInfoByGUID(guid)
			return englishClass, localizedRace
		end)
		if cls and not c.class then c.class = cls end
		if race and not c.race then c.race = race end
		if cls or race then RefreshTitle(c) end
	end
	-- the sent line is already echoed locally on Enter; skip the matching
	-- WHISPER_INFORM echo so it doesn't show up twice
	if mine then
		local last = c.lines[#c.lines]
		if last and last.me and last.m == msg and (time() - (last.t or 0)) < 5 then
			lastConv = c
			return
		end
	end
	Append(c, msg, mine)
	lastConv = c
	if not mine then
		-- the intercept filter removes the whisper before Blizzard's handler
		-- records the reply target, so keep the native R-key path alive by
		-- registering the last teller ourselves
		if ChatEdit_SetLastTellTarget then
			S:SafeCall("Messenger:LastTell", ChatEdit_SetLastTellTarget, sender, guid)
		end
	end
	if not mine then
		-- whisper notify sound
		if (not self.db or self.db.sound ~= false) and PlaySound and SOUNDKIT and SOUNDKIT.TELL_MESSAGE then
			PlaySound(SOUNDKIT.TELL_MESSAGE, "Master")
		end
		-- AFK/DND auto reply (once per conversation until we come back)
		if self.db and self.db.autoReply and not c.afkReplied and (UnitIsAFK("player") or UnitIsDND("player")) then
			c.afkReplied = true
			local reply = self.db.autoReplyMsg ~= "" and self.db.autoReplyMsg
				or "|cff33bbff[SentinelUI]|r " .. (L["auto reply: currently away"] or "auto reply: currently away")
			if c.bnet then if BNSendWhisper then BNSendWhisper(c.bnID, reply) end
			else SendChatMessage(reply, "WHISPER", nil, c.target) end
		end
	end
	if not self.db or self.db.popup ~= false then
		-- in combat the window queues instead of popping up mid-fight
		if InCombatLockdown() and (not self.db or self.db.combatSuppress ~= false) then
			pendingPopups[c] = true
		else
			ShowConv(c, true)
		end
	end
	if not mine and (not c.frame or not c.frame:IsShown()) then
		c.unread = (c.unread or 0) + 1
	end
	UpdateTabs()
	self:UpdateBadge()
end

function MS:OnRegen()
	for c in pairs(pendingPopups) do ShowConv(c) end
	wipe(pendingPopups)
end

function MS:OnFlags(_, unit)
	if unit == "player" and not UnitIsAFK("player") and not UnitIsDND("player") then
		for _, c in pairs(convs) do c.afkReplied = nil end
	end
end

-- filter: hide whispers from the regular chat frames when intercept is on;
-- during combat the messenger window queues until PLAYER_REGEN_ENABLED, so the
-- whisper stays visible in the normal chat until the window can actually show
local function WhisperFilter(_, event)
	if InCombatLockdown() and (not MS.db or MS.db.combatSuppress ~= false) then
		return false
	end
	return MS.db and MS.db.intercept ~= false
end

function MS:SetIntercept(on)
	local events = { "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM" }
	for _, ev in ipairs(events) do
		if on then
			ChatFrame_AddMessageEventFilter(ev, WhisperFilter)
		else
			ChatFrame_RemoveMessageEventFilter(ev, WhisperFilter)
		end
	end
end

-- unread badge + minimap button ------------------------------------------------
function MS:UnreadTotal()
	local n = 0
	for _, c in pairs(convs) do n = n + (c.unread or 0) end
	return n
end

function MS:UpdateBadge()
	if not self.minimapBtn or not self.minimapBtn.badge then return end
	local n = self:UnreadTotal()
	self.minimapBtn.badge:SetText(n > 0 and n or "")
end

-- per-contact action menu (right-click the window title): invite, friend,
-- ignore, who, archive, export, clear history, close
local convActionMenu
function MS:ConvMenu(c)
	if not convActionMenu then
		convActionMenu = CreateFrame("Frame", "SentinelUIMessengerConvMenu", UIParent, "UIDropDownMenuTemplate")
	end
	UIDropDownMenu_Initialize(convActionMenu, function(_, level)
		local function Item(text, func, disabled)
			local info = UIDropDownMenu_CreateInfo()
			info.text = text
			info.notCheckable = true
			info.disabled = disabled
			info.func = func
			UIDropDownMenu_AddButton(info, level)
		end
		if not c.bnet then
			Item(L["Invite to group"], function()
				local inv = C_PartyInfo and C_PartyInfo.InviteUnit or InviteUnit
				if inv then inv(c.target) end
			end)
			Item(L["Add friend"], function()
				local add = C_FriendList and C_FriendList.AddFriend or AddFriend
				if add then add(c.target) end
			end)
			Item(IGNORE or "Ignore", function()
				local ig = C_FriendList and C_FriendList.AddIgnore or AddIgnore
				if ig then ig(c.target) end
			end)
			Item(L["Who"], function() RefreshTitle(c) end)
		end
		Item(L["Chat Logs"] or "Chat Logs", function() MS:OpenHistory(c.key) end)
		Item(L["Export"] or "Export", function() MS:ExportLog(c.key) end)
		Item(L["Clear history"] or "Clear history", function()
			Hist()[c.key] = nil
			wipe(c.lines)
			if c.frame then
				for _, ch in ipairs({ c.frame.content:GetChildren() }) do ch:Hide() end
				c.frame.chatH = nil
				c.frame.lastDay = nil
				SetScroll(c.frame, 0)
			end
		end)
		Item(CLOSE or "Close", function() if mainWin then mainWin:Hide() end end)
	end, "MENU")
	ToggleDropDownMenu(1, nil, convActionMenu, "cursor", 0, 0)
end

local convMenu
function MS:OpenMenu()
	if not convMenu then
		convMenu = CreateFrame("Frame", "SentinelUIMessengerDropDown", UIParent, "UIDropDownMenuTemplate")
	end
	UIDropDownMenu_Initialize(convMenu, function(_, level)
		local h = UIDropDownMenu_CreateInfo()
		h.text = "|cff33bbff" .. (L["Chat Logs"] or "Chat Logs") .. "|r"
		h.notCheckable = true
		h.func = function() MS:OpenHistory() end
		UIDropDownMenu_AddButton(h, level)
		for _, c in pairs(convs) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = c.name .. ((c.unread and c.unread > 0) and format(" |cffff4040(%d)|r", c.unread) or "")
			info.notCheckable = true
			info.func = function() ShowConv(c) lastConv = c end
			UIDropDownMenu_AddButton(info, level)
		end
		if not next(convs) then
			local info = UIDropDownMenu_CreateInfo()
			info.text = L["No whisper conversations yet."]
			info.notCheckable = true
			info.disabled = true
			UIDropDownMenu_AddButton(info, level)
		end
	end, "MENU")
	ToggleDropDownMenu(1, nil, convMenu, "cursor", 0, 0)
end

-- chat log viewer: list of stored conversations, a read view and a copyable
-- export box (history + export)
local logWin, expWin

local function Transcript(key)
	local h = Hist()[key]
	local name = key:match("^w:(.+)$") or key:match("^bn:(.+)$") or key
	local me = UnitName("player") or "Me"
	local out = {}
	for i, l in ipairs(h or {}) do
		local who = l.me and me or ShortName(name)
		out[i] = format("[%s] %s: %s", date("%d.%m.%Y %H:%M", l.t or 0), who, l.m or "")
	end
	return table.concat(out, "\n")
end

local function ViewLog(key)
	local f = logWin
	for _, r in ipairs(f.rows) do r:Hide() end
	f.viewKey = key
	local name = key:match("^w:(.+)$") or key
	f.title:SetText("SentinelUI " .. (L["Chat Logs"] or "Chat Logs") .. " — " .. ShortName(name))
	f.detail:SetWidth(f.content:GetWidth() - 12)
	f.detail:SetText(Transcript(key))
	f.detail:Show()
	f.content:SetHeight(f.detail:GetStringHeight() + 14)
	SetScroll(f, 0)
	f.btnBack:Show()
	f.btnExport:Show()
	f.btnOpen:Show()
end

local function RefreshLogList()
	local f = logWin
	f.viewKey = nil
	f.title:SetText("SentinelUI " .. (L["Chat Logs"] or "Chat Logs"))
	f.detail:Hide()
	f.btnBack:Hide()
	f.btnExport:Hide()
	f.btnOpen:Hide()
	for _, r in ipairs(f.rows) do r:Hide() end
	wipe(f.rows)
	local q = f.search and strlower(f.search:GetText() or "") or ""
	local items = {}
	for key, h in pairs(Hist()) do
		if #h > 0 then
			local name = key:match("^w:(.+)$") or key:match("^bn:(.+)$") or key
			if q == "" or strlower(name):find(q, 1, true) then
				items[#items + 1] = { key = key, name = ShortName(name), n = #h, last = h[#h].t or 0 }
			end
		end
	end
	table.sort(items, function(a, b) return a.last > b.last end)
	local y = 4
	for _, it in ipairs(items) do
		local row = CreateFrame("Button", nil, f.content)
		S:CreateBackdrop(row, "Transparent")
		row:SetPoint("TOPLEFT", f.content, "TOPLEFT", 4, -y)
		row:SetPoint("TOPRIGHT", f.content, "TOPRIGHT", -4, -y)
		row:SetHeight(34)
		local n = S:FontString(row, 11, nil, S.media.font, nil, "LEFT")
		n:SetPoint("TOPLEFT", 10, -4)
		n:SetText("|cff33bbff" .. it.name .. "|r")
		local i = S:FontString(row, 9, nil, S.media.font, nil, "LEFT")
		i:SetPoint("BOTTOMLEFT", 10, 5)
		i:SetText("|cff666f7a" .. format(L["%d messages"], it.n) .. " · " .. date("%d.%m %H:%M", it.last) .. "|r")
		local del = CreateFrame("Button", nil, row)
		del:SetSize(14, 14)
		del:SetPoint("RIGHT", -8, 0)
		S:CreateBackdrop(del, "Default")
		local dx = S:FontString(del, 11, "OUTLINE", S.media.numberFont, nil, "CENTER")
		dx:SetPoint("CENTER")
		dx:SetText("x")
		del:SetScript("OnClick", function()
			Hist()[it.key] = nil
			if convs[it.key] then convs[it.key] = nil end
			RefreshLogList()
		end)
		row:SetScript("OnClick", function() ViewLog(it.key) end)
		f.rows[#f.rows + 1] = row
		y = y + 34 + 3
	end
	if #items == 0 then
		local e = S:FontString(f.content, 10, nil, S.media.font, nil, "CENTER")
		e:SetPoint("TOP", f.content, "TOP", 0, -30)
		e:SetText("|cff666f7a" .. (L["No chat logs stored yet."] or "No chat logs stored yet.") .. "|r")
		f.rows[#f.rows + 1] = e
	end
	f.content:SetHeight(y + 6)
	SetScroll(f, 0)
end

local function SmallBtn(parent, text, onClick)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(88, 20)
	b:SetText(text)
	b:SetScript("OnClick", onClick)
	if S.SkinButton then S:SkinButton(b) end
	return b
end

function MS:ExportLog(key)
	if not expWin then
		local f = CreateFrame("Frame", "SentinelUIMsgExport", UIParent)
		f:SetSize(400, 340)
		f:SetPoint("CENTER", UIParent, "CENTER", 140, -20)
		f:SetFrameStrata("FULLSCREEN_DIALOG")
		f:SetToplevel(true)  -- newest/clicked window rises inside its strata
		f:SetToplevel(true)  -- newest/clicked window rises inside its strata
		f:SetClampedToScreen(true)
		f:EnableMouse(true)
		f:SetMovable(true)
		f:RegisterForDrag("LeftButton")
		f:SetScript("OnDragStart", f.StartMoving)
		f:SetScript("OnDragStop", f.StopMovingOrSizing)
		S:SetTemplate(f, "Default", "TOP")
		f.title = S:FontString(f, 11, "OUTLINE", S.media.unitFont, nil, "LEFT")
		f.title:SetPoint("TOPLEFT", 10, -8)
		S:RegisterAccent(f.title, "text")
		f.close = CreateFrame("Button", nil, f)
		f.close:SetSize(16, 16)
		f.close:SetPoint("TOPRIGHT", -7, -6)
		S:CreateBackdrop(f.close, "Default")
		f.close.fs = S:FontString(f.close, 12, "OUTLINE", S.media.numberFont, nil, "CENTER")
		f.close.fs:SetPoint("CENTER")
		f.close.fs:SetText("x")
		f.close:SetScript("OnClick", function() f:Hide() end)
		local hint = S:FontString(f, 9, nil, S.media.font, nil, "LEFT")
		hint:SetPoint("TOPLEFT", 10, -22)
		hint:SetText("|cff666f7a" .. (L["Click into the text, then Ctrl+A and Ctrl+C to copy."] or "Click into the text, then Ctrl+A and Ctrl+C to copy.") .. "|r")
		local scroll = CreateFrame("ScrollFrame", "SentinelUIMsgExportScroll", f, "UIPanelScrollFrameTemplate")
		scroll:SetPoint("TOPLEFT", 10, -38)
		scroll:SetPoint("BOTTOMRIGHT", -30, 12)
		local edit = CreateFrame("EditBox", nil, scroll)
		edit:SetMultiLine(true)
		edit:SetAutoFocus(false)
		edit:SetFontObject(ChatFontNormal)
		edit:SetWidth(340)
		edit:SetScript("OnEscapePressed", function(e) e:ClearFocus() end)
		scroll:SetScrollChild(edit)
		f.edit = edit
		f:Hide()
		tinsert(UISpecialFrames, "SentinelUIMsgExport")
		expWin = f
	end
	local name = key and (key:match("^w:(.+)$") or key) or ""
	expWin.title:SetText((L["Export"] or "Export") .. " — " .. ShortName(name))
	expWin.edit:SetText(Transcript(key))
	expWin:Show()
end

function MS:OpenHistory(key)
	if not logWin then
		local f = CreateFrame("Frame", "SentinelUIMsgLog", UIParent)
		f:SetSize(340, 360)
		f:SetPoint("CENTER", UIParent, "CENTER", -140, 30)
		f:SetFrameStrata("DIALOG")
		f:SetToplevel(true)  -- newest/clicked window rises inside its strata
		f:SetToplevel(true)  -- newest/clicked window rises inside its strata
		f:SetClampedToScreen(true)
		f:EnableMouse(true)
		f:SetMovable(true)
		f:RegisterForDrag("LeftButton")
		f:SetScript("OnDragStart", f.StartMoving)
		f:SetScript("OnDragStop", f.StopMovingOrSizing)
		S:SetTemplate(f, "Default", "TOP")
		f.title = S:FontString(f, 11, "OUTLINE", S.media.unitFont, nil, "LEFT")
		f.title:SetPoint("TOPLEFT", 10, -8)
		f.title:SetText("SentinelUI " .. (L["Chat Logs"] or "Chat Logs"))
		S:RegisterAccent(f.title, "text")
		f.close = CreateFrame("Button", nil, f)
		f.close:SetSize(16, 16)
		f.close:SetPoint("TOPRIGHT", -7, -6)
		S:CreateBackdrop(f.close, "Default")
		f.close.fs = S:FontString(f.close, 12, "OUTLINE", S.media.numberFont, nil, "CENTER")
		f.close.fs:SetPoint("CENTER")
		f.close.fs:SetText("x")
		f.close:SetScript("OnClick", function() f:Hide() end)

		-- search box filters the conversation list by name
		local search = CreateFrame("EditBox", nil, f)
		search:SetPoint("TOPLEFT", 10, -26)
		search:SetSize(140, 18)
		search:SetAutoFocus(false)
		search:SetMaxLetters(60)
		search:SetFont(S.media.font or STANDARD_TEXT_FONT, 11)
		search:SetTextColor(1, 1, 1)
		search:SetTextInsets(4, 4, 0, 0)
		S:SkinEditBox(search)
		search.hint = S:FontString(search, 10, nil, S.media.font, nil, "LEFT")
		search.hint:SetPoint("LEFT", 4, 0)
		search.hint:SetText(SEARCH or "Search")
		search.hint:SetTextColor(0.4, 0.4, 0.45)
		search:SetScript("OnEditFocusGained", function(e) e.hint:Hide() end)
		search:SetScript("OnEditFocusLost", function(e) if e:GetText() == "" then e.hint:Show() end end)
		search:SetScript("OnTextChanged", function() if not f.viewKey then RefreshLogList() end end)
		search:SetScript("OnEscapePressed", function(e) e:ClearFocus() end)
		search:SetScript("OnEnterPressed", function(e) e:ClearFocus() end)
		f.search = search

		local box = CreateFrame("Frame", nil, f)
		box:SetPoint("TOPLEFT", 8, -48)
		box:SetPoint("BOTTOMRIGHT", -8, 42)
		if box.SetClipsChildren then box:SetClipsChildren(true) end
		box:EnableMouseWheel(true)
		box:SetScript("OnMouseWheel", function(_, d) SetScroll(f, (f.scrollPos or 0) - d * 60) end)
		local content = CreateFrame("Frame", nil, box)
		content:SetPoint("TOPLEFT", box, "TOPLEFT")
		content:SetSize(324, 8)
		f.scroll, f.content = box, content
		f.rows = {}

		-- read view: one wrapped text block inside the same scroll area
		f.detail = S:FontString(content, 11, nil, S.media.font, nil, "LEFT")
		f.detail:SetPoint("TOPLEFT", 6, -4)
		f.detail:SetWordWrap(true)
		f.detail:Hide()

		f.btnBack = SmallBtn(f, "« " .. (L["Back"] or "Back"), RefreshLogList)
		f.btnBack:SetPoint("BOTTOMLEFT", 10, 12)
		f.btnExport = SmallBtn(f, L["Export"] or "Export", function()
			if f.viewKey then MS:ExportLog(f.viewKey) end
		end)
		f.btnExport:SetPoint("BOTTOM", 0, 12)
		f.btnOpen = SmallBtn(f, L["Open"] or "Open", function()
			local name = f.viewKey and f.viewKey:match("^w:(.+)$")
			if name then
				local c = Conv(name)
				ShowConv(c)
				lastConv = c
				f:Hide()
			end
		end)
		f.btnOpen:SetPoint("BOTTOMRIGHT", -10, 12)

		f:SetScript("OnShow", function() if not f.viewKey then RefreshLogList() end end)
		f:Hide()
		tinsert(UISpecialFrames, "SentinelUIMsgLog")
		logWin = f
	end
	if key then ViewLog(key) else RefreshLogList() end
	logWin:Show()
end

function MS:UpdateMinimap()
	if self.db and self.db.minimapButton == false then
		if self.minimapBtn then self.minimapBtn:Hide() end
		return
	end
	if not self.minimapBtn then
		self.private.messengerMinimap = self.private.messengerMinimap or {}
		self.minimapBtn = S:CreateMinimapButton({
			name = "Messenger",
			glyph = "MS",
			store = self.private.messengerMinimap,
			angle = 250,
			onLeft = function() MS:Open() end,
			onRight = function() MS:OpenMenu() end,
			tooltip = function()
				GameTooltip:SetText("SentinelUI " .. L["Messenger"])
				local n = MS:UnreadTotal()
				if n > 0 then
					GameTooltip:AddLine(format("|cffff4040%d|r %s", n, L["unread messages"]))
				end
				GameTooltip:AddLine(L["Left-click: open  |  Right-click: conversations  |  Drag: move"], 0.8, 0.8, 0.8)
			end,
		})
		local badge = S:FontString(self.minimapBtn, 10, "THICKOUTLINE", S.media.numberFont, nil, "CENTER")
		badge:SetPoint("TOPRIGHT", 4, 4)
		badge:SetTextColor(1, 0.25, 0.25)
		self.minimapBtn.badge = badge
	end
	self.minimapBtn:Show()
	self.minimapBtn:UpdatePosition()
	self:UpdateBadge()
end

function MS:Open(name)
	if name and name ~= "" then
		if name == "log" or name == "logs" or name == "verlauf" then
			MS:OpenHistory()
			return
		end
		-- find an existing conversation by short name first (history keys carry the realm)
		local c
		for key, conv in pairs(convs) do
			if ShortName(conv.target) == name or conv.target == name then c = conv break end
		end
		if not c then
			for key in pairs(Hist()) do
				local stored = key:match("^w:(.+)$")
				if stored and ShortName(stored) == name then c = Conv(stored) break end
			end
		end
		c = c or Conv(name)
		ShowConv(c)
		lastConv = c
		return
	end
	if lastConv then ShowConv(lastConv) return end
	S:Print(L["No whisper conversations yet."])
end

function MS:Initialize()
	self.db = S.db.profile.messenger
	self:RegisterEvent("CHAT_MSG_WHISPER", "OnWhisper")
	self:RegisterEvent("CHAT_MSG_WHISPER_INFORM", "OnWhisper")
	self:RegisterEvent("CHAT_MSG_BN_WHISPER", "OnWhisper")
	self:RegisterEvent("CHAT_MSG_BN_WHISPER_INFORM", "OnWhisper")
	self:RegisterEvent("WHO_LIST_UPDATE", "OnWhoList")
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnRegen")
	self:RegisterEvent("PLAYER_FLAGS_CHANGED", "OnFlags")
	self:SetIntercept(self.db.intercept ~= false)
	self:UpdateMinimap()
	-- route whisper-reply entry points (R key, name-click "whisper") into the
	-- messenger windows instead of the blizzard chat editbox
	local function ReplyToLast()
		if not (MS.db and MS.db.intercept ~= false) or not lastConv then return false end
		if InCombatLockdown() then
			pendingPopups[lastConv] = true
		else
			S:SafeCall("Messenger:Reply", function()
				ShowConv(lastConv)
				-- OnShow only fires on the hidden->shown transition; when the
				-- window is already open we still want the reply box focused
				local f = lastConv.frame
				if f and f.editbox and (not MS.db or MS.db.autoFocus ~= false) then
					f.editbox:SetFocus()
				end
			end)
		end
		return true
	end
	-- "ReplyTell" is the function the R-key binding calls directly on this
	-- client (its internal UpdateHeader crashes when chatType lookup fails)
	for _, fn in ipairs({ "ChatFrame_ReplyTell", "ChatFrame_ReplyTell2", "ChatEdit_ReplyTell", "ReplyTell" }) do
		local orig = _G[fn]
		if orig then
			_G[fn] = function(...)
				if ReplyToLast() then return end
				return orig(...)
			end
		end
	end
	local origSendTell = _G.ChatFrame_SendTell
	if origSendTell then
		_G.ChatFrame_SendTell = function(name, chatFrame)
			if MS.db and MS.db.intercept ~= false and type(name) == "string" and name ~= "" then
				-- keep the realm suffix so cross-realm replies still resolve
				if InCombatLockdown() then
					local c = Conv(name)
					pendingPopups[c] = true
					lastConv = c
				else
					S:SafeCall("Messenger:Reply", function() MS:Open(name) end)
				end
				return
			end
			return origSendTell(name, chatFrame)
		end
	end
	local origBNetTell = _G.ChatFrame_SendBNetTell
	if origBNetTell then
		_G.ChatFrame_SendBNetTell = function(name)
			if MS.db and MS.db.intercept ~= false and type(name) == "string" and name ~= "" then
				S:SafeCall("Messenger:BNetReply", function()
					local bnID
					if C_BattleNet and C_BattleNet.GetFriendNumFriends and C_BattleNet.GetFriendAccountInfo then
						for i = 1, C_BattleNet.GetFriendNumFriends() do
							local info = C_BattleNet.GetFriendAccountInfo(i)
							if info and (info.accountName == name or info.battleTag == name) then bnID = info.bnetAccountID break end
						end
					end
					ShowConv(Conv(name, true, bnID))
					lastConv = convs[ConvKey(name, true, bnID)]
				end)
				return
			end
			return origBNetTell(name)
		end
	end
	-- own command names (/msg, /w are built-ins and must not be shadowed)
	local open = function(msg) MS:Open(strtrim(msg or "")) end
	S:RegisterChatCommand("smsg", open)
	S:RegisterChatCommand("sm", open)
	S:RegisterChatCommand("smsgdbg", function()
		for key, c in pairs(convs) do
			local f = c.frame
			S:Print(format("%s: lines=%d frame=%s loaded=%s",
				key, #c.lines, tostring(f ~= nil), f and tostring(f._loaded) or "-"))
			if f then
				S:Print(format("  f shown=%s | chatBox shown=%s size=%sx%s scrollPos=%s",
					tostring(f:IsShown()), tostring(f.scroll:IsShown()),
					tostring(f.scroll:GetWidth()), tostring(f.scroll:GetHeight()),
					tostring(f.scrollPos)))
				S:Print(format("  content shown=%s size=%sx%s top=%s left=%s chatH=%s",
					tostring(f.content:IsShown()), tostring(f.content:GetWidth()),
					tostring(f.content:GetHeight()), tostring(f.content:GetTop()), tostring(f.content:GetLeft()),
					tostring(f.chatH)))
				local lb = f.lastBubble
				if lb then
					S:Print(format("  bubble shown=%s size=%sx%s top=%s left=%s parent=%s",
						tostring(lb:IsShown()), tostring(lb:GetWidth()), tostring(lb:GetHeight()),
						tostring(lb:GetTop()), tostring(lb:GetLeft()), tostring(lb:GetParent() == f.content)))
					if lb.fs then
						S:Print(format("  fs text=%s w=%s h=%s font=%s",
							tostring(lb.fs:GetText()), tostring(lb.fs:GetWidth()),
							tostring(lb.fs:GetStringHeight()), tostring(lb.fs:GetFont())))
					end
				end
			end
		end
		if not next(convs) then S:Print("no conversations") end
	end)
	-- render check: inject a fake line so we can see whether bubbles draw at all
	S:RegisterChatCommand("smsgtest", function()
		local c = lastConv or (next(convs) and convs[next(convs)])
		if not c then c = Conv("Testdummy") end
		ShowConv(c)
		-- direct bubble draw without PushLine so nothing pollutes history
		S:SafeCall("Messenger:AddBubble", AddBubbleRaw, c, { t = time(), m = "TEST-IN " .. date("%H:%M:%S"), me = false })
		S:SafeCall("Messenger:AddBubble", AddBubbleRaw, c, { t = time(), m = "TEST-OUT " .. date("%H:%M:%S"), me = true })
		S:Print("smsgtest: 2 test bubbles drawn, run /smsgdbg for geometry")
	end)
end

function MS:Update()
	self.db = S.db.profile.messenger
	self:SetIntercept(self.db.intercept ~= false)
	self:UpdateMinimap()
end
