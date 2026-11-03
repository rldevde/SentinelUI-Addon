-- Player buffs / debuffs / weapon enchants via SecureAuraHeaderTemplate (right click cancels).
local _, ns = ...
local S = ns.S
local L = S.L
local A = S:NewModule("Auras")

local floor, max, min, format = math.floor, math.max, math.min, format
local IsSecret = S.IsSecret

local DEBUFF_COLORS = {
	Magic = { 0.2, 0.6, 1 }, Curse = { 0.6, 0, 1 }, Disease = { 0.6, 0.4, 0 }, Poison = { 0, 0.6, 0 },
}

local function TemplateFor(size)
	size = floor((size or 32) / 2 + 0.5) * 2
	return "SentinelUIAuraTemplate" .. max(16, min(64, size))
end

local function UpdateTimer(btn, elapsed)
	btn.wait = (btn.wait or 0) - elapsed
	if btn.wait > 0 then return end
	if not btn.expiration then btn.time:SetText("") btn.wait = 1 return end
	local remain = btn.expiration - GetTime()
	if remain <= 0 then btn.time:SetText("") btn.wait = 0.5 return end
	local text, nextUpdate = S:FormatTime(remain)
	btn.time:SetText(text)
	local fade = A.db and A.db.fadeThreshold or 6
	if remain <= fade then
		btn.time:SetTextColor(1, 0.3, 0.25)
		btn:SetAlpha(0.55 + 0.45 * math.abs(math.sin(GetTime() * 3)))
		btn.wait = 0.05
	else
		btn.time:SetTextColor(0.95, 0.95, 0.95)
		btn:SetAlpha(1)
		btn.wait = nextUpdate
	end
end

local function OnEnter(btn)
	GameTooltip:SetOwner(btn, "ANCHOR_BOTTOMLEFT", -5, -5)
	local slot = btn:GetAttribute("target-slot")
	if slot then
		GameTooltip:SetInventoryItem("player", slot)
	else
		local index = btn:GetAttribute("index")
		if index then GameTooltip:SetUnitAura(btn.header:GetAttribute("unit") or "player", index, btn.filter) end
	end
	GameTooltip:Show()
end

function A:UpdateAura(btn, index)
	if not btn.icon then return end -- spawned in combat, init deferred to regen
	local header = btn.header
	if not header then return end -- uninitialized combat-spawned button
	local unit = header:GetAttribute("unit") or "player"
	local aura = S.GetAura(unit, index, btn.filter)
	if not aura then
		-- assigned slot but the aura is gone: hide the whole button so no
		-- empty black square lingers (alpha, not Hide - combat safe)
		btn.icon:SetAlpha(0)
		btn.icon:SetTexture(nil)
		btn.count:SetText("")
		btn.time:SetText("")
		btn.cd:Hide()
		if btn.suiBackdrop then btn.suiBackdrop:SetAlpha(0) end
		return
	end
	btn.icon:SetAlpha(1)
	if btn.suiBackdrop then btn.suiBackdrop:SetAlpha(1) end
	-- icon via the spell texture API first: aura.icon can be nil or a secret
	-- value this client hides from SetTexture (both end as black squares);
	-- GetSpellTexture on the spell id returns a real file path either way
	local tex
	if aura.spellId and not IsSecret(aura.spellId) and GetSpellTexture then
		tex = GetSpellTexture(aura.spellId)
	end
	if not tex and aura.icon and not IsSecret(aura.icon) then tex = aura.icon end
	btn.icon:SetTexture(tex or 134400)
	local count = aura.applications
	if IsSecret(count) then
		btn.count:SetText(C_UnitAuras.GetAuraApplicationDisplayCount and aura.auraInstanceID and C_UnitAuras.GetAuraApplicationDisplayCount(unit, aura.auraInstanceID, 2, 999) or "")
	else
		btn.count:SetText(count and count > 1 and count or "")
	end
	local duration, expiration = aura.duration, aura.expirationTime
	if IsSecret(duration) or IsSecret(expiration) then
		btn.expiration = nil
		btn.time:SetText("")
		if C_UnitAuras.GetAuraDuration and btn.cd.SetCooldownFromDurationObject and aura.auraInstanceID then
			local obj = C_UnitAuras.GetAuraDuration(unit, aura.auraInstanceID)
			if obj then btn.cd:SetCooldownFromDurationObject(obj) btn.cd:Show() end
		end
	elseif duration and duration > 0 then
		btn.expiration = expiration
		if self.db.cooldownSwipe then btn.cd:SetCooldown(expiration - duration, duration) btn.cd:Show() else btn.cd:Hide() end
		btn.wait = 0
	else
		btn.expiration = nil
		btn.time:SetText("")
		btn.cd:Hide()
		btn:SetAlpha(1)
	end
	if btn.filter == "HARMFUL" then
		local dtype = aura.dispelName
		local c = (not IsSecret(dtype) and dtype and DEBUFF_COLORS[dtype]) or { 0.8, 0.1, 0.1 }
		btn.suiBackdrop:SetBackdropBorderColor(c[1], c[2], c[3])
	end
end

function A:UpdateWeapon(btn, slot)
	local texture = GetInventoryItemTexture("player", slot)
	btn.icon:SetTexture(texture)
	btn.count:SetText("")
	local hasMain, mainExp, _, _, hasOff, offExp = GetWeaponEnchantInfo()
	local exp = slot == 16 and mainExp or offExp
	if exp then btn.expiration = GetTime() + exp / 1000 btn.wait = 0 else btn.expiration = nil end
	btn.cd:Hide()
	btn.suiBackdrop:SetBackdropBorderColor(0.6, 0.2, 0.9)
end

-- Called from the XML template OnLoad
function S:InitAuraButton(btn)
	if InCombatLockdown() then
		-- combat-spawned buttons: wiring happens on regen; UpdateAura guards
		-- missing regions until then
		return
	end
	S:SafeCall("Auras:Init", function()
		local header = btn:GetParent()
		btn.header = header
		btn.filter = header:GetAttribute("filter")
		-- the secure cancelaura handler reads unit/filter/index off the BUTTON;
		-- on this client the header does not forward them reliably -> set them
		-- ourselves or CancelUnitBuff silently does nothing.
		-- Up AND Down: the client runs secure clicks on key-down when the
		-- ActionButtonUseKeyDown cvar is set (default on modern classic) - with
		-- only "Up" registered the right click never reaches the handler.
		-- protected attribute writes are blocked mid-combat; buttons spawning
		-- during a fight get their cancel-click wiring after regen instead of
		-- silently never getting it
		local function WireSecure(btn2)
			if InCombatLockdown() then return S:RunOutOfCombat(WireSecure, btn2) end
			btn2:RegisterForClicks("RightButtonUp", "RightButtonDown")
			btn2:SetAttribute("unit", header:GetAttribute("unit") or "player")
			btn2:SetAttribute("filter", btn2.filter)
			btn2:SetAttribute("type2", "cancelaura")
		end
		WireSecure(btn)
		-- like the reference implementation: when the header assigns this
		-- button an aura index, the button fills itself right away instead of
		-- waiting for our next refresh pass - works mid-combat too since the
		-- header's own update just spawned it
		-- like the reference: the button fills itself when the header assigns
		-- an index/target-slot; only the content calls are insecure, the
		-- layout pass stays untouched
		btn:SetScript("OnAttributeChanged", function(self2, attr, value)
			if attr == "index" and value then
				S:SafeCall("Auras:BtnFill", A.UpdateAura, A, self2, value)
			elseif attr == "target-slot" and value then
				S:SafeCall("Auras:BtnFill", A.UpdateWeapon, A, self2, value)
			end
		end)
		local db = A.db[btn.filter == "HARMFUL" and "debuffs" or "buffs"]
		S:CreateBackdrop(btn, "Default")
		btn.icon = btn:CreateTexture(nil, "ARTWORK")
		S:SetInside(btn.icon, btn, 0, 0)
		btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		btn.cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
		S:SetInside(btn.cd, btn, 0, 0)
		btn.cd:SetReverse(true)
		btn.cd:SetDrawEdge(false)
		btn.cd:SetHideCountdownNumbers(true)
		btn.cd:SetSwipeColor(0, 0, 0, 0.55)
		local textHolder = CreateFrame("Frame", nil, btn)
		textHolder:SetAllPoints()
		textHolder:SetFrameLevel(btn:GetFrameLevel() + 3)
		btn.count = S:FontString(textHolder, A.db.fontSize, "OUTLINE", S.media.numberFont)
		btn.count:SetPoint("BOTTOMRIGHT", -1, 2)
		btn.time = S:FontString(btn, A.db.fontSize, "OUTLINE", S.media.numberFont)
		btn.time:SetPoint("TOP", btn, "BOTTOM", 0, -2)
		btn.time:SetShown(db.showDuration)
		btn:SetScript("OnUpdate", UpdateTimer)
		btn:SetScript("OnEnter", OnEnter)
		btn:SetScript("OnLeave", GameTooltip_Hide)
		-- deliberately no OnAttributeChanged hook here: an insecure hook on a
		-- protected button taints the secure aura-update call chain mid-combat
		-- -> ClearAllPoints ADDON_ACTION_BLOCKED. Contents refresh via our own
		-- UNIT_AURA driver (combat-safe partial refresh) instead.
		local index = btn:GetAttribute("index")
		if index then A:UpdateAura(btn, index) end
	end)
end

function A:ConfigureHeader(header)
	if InCombatLockdown() then return S:RunOutOfCombat(self.ConfigureHeader, self, header) end
	local db = self.db[header.kind]
	local size = (db and db.size) or 32
	header:SetAttribute("config-width", size)
	header:SetAttribute("config-height", size)
	local db = self.db[header.kind]
	local size = floor((db.size or 32) / 2 + 0.5) * 2
	local left = db.growthX == "LEFT"
	local down = db.growthY == "DOWN"
	header:SetAttribute("template", TemplateFor(size))
	if header.kind == "buffs" then
		header:SetAttribute("includeWeapons", 1)
		header:SetAttribute("weaponTemplate", TemplateFor(size))
	end
	header:SetAttribute("point", (down and "TOP" or "BOTTOM") .. (left and "RIGHT" or "LEFT"))
	header:SetAttribute("xOffset", (left and -1 or 1) * (size + db.spacing))
	header:SetAttribute("yOffset", 0)
	header:SetAttribute("wrapAfter", db.perRow)
	header:SetAttribute("wrapXOffset", 0)
	header:SetAttribute("wrapYOffset", (down and -1 or 1) * (size + db.wrapSpacing))
	header:SetAttribute("maxWraps", db.maxWraps)
	header:SetAttribute("minWidth", db.perRow * (size + db.spacing))
	header:SetAttribute("minHeight", (size + db.wrapSpacing) * db.maxWraps)
	header:SetAttribute("sortMethod", db.sortMethod)
	header:SetAttribute("sortDirection", db.sortDir)
	header:SetAttribute("separateOwn", db.separateOwn)
	header:SetSize(db.perRow * (size + db.spacing), (size + db.wrapSpacing) * db.maxWraps)
	for i = 1, 40 do
		local child = header:GetAttribute("child" .. i)
		if not child then break end
		child:SetSize(size, size)
		if not child.icon then S:InitAuraButton(child) end
	end
	local anchor = header:GetAttribute("point")
	header:ClearAllPoints()
	header:SetPoint(anchor, header.holder, anchor)
	header.holder:SetSize(header:GetWidth(), header:GetHeight())
end

function A:CreateHeader(kind)
	local filter = kind == "buffs" and "HELPFUL" or "HARMFUL"
	local holder = CreateFrame("Frame", "SentinelUIPlayer" .. (kind == "buffs" and "Buffs" or "Debuffs") .. "Holder", UIParent)
	holder:SetSize(200, 40)
	local header = CreateFrame("Frame", "SentinelUIPlayer" .. (kind == "buffs" and "Buffs" or "Debuffs"), UIParent, "SecureAuraHeaderTemplate")
	header.kind, header.holder = kind, holder
	header:SetClampedToScreen(true)
	header:SetAttribute("unit", "player")
	header:SetAttribute("filter", filter)
	-- secure snippet like the reference: only the size is set inside the
	-- restricted environment, everything else happens in addon code
	header:SetAttribute("initialConfigFunction", [[
		local header = self:GetParent()
		self:SetWidth(header:GetAttribute("config-width") or 32)
		self:SetHeight(header:GetAttribute("config-height") or 32)
	]])
	if RegisterAttributeDriver and (S.isRetail or S.isWrath or S.isCata or S.isMists) then
		RegisterAttributeDriver(header, "unit", "[vehicleui] vehicle; player")
	end
	self:ConfigureHeader(header)
	local pos = kind == "buffs" and { "TOPRIGHT", "UIParent", "TOPRIGHT", -(S.db.profile.minimap.size + 18), -6 } or { "TOPRIGHT", "SentinelUIMover_buffs", "BOTTOMRIGHT", 0, -12 }
	S:CreateMover(holder, kind, kind == "buffs" and L["Player Buffs"] or L["Player Debuffs"], pos, "auras")
	self:ConfigureHeader(header)
	header:Show()
	-- the header keeps its own event/update system (like the reference
	-- implementation): the template's spawn/layout path is fully secure as
	-- long as no addon code runs inside it
	-- the template keeps its own secure update: it can spawn and lay out
	-- aura buttons even in combat, which is exactly what it was built for.
	-- The old ADDON_ACTION_BLOCKED came from our insecure attribute hooks in
	-- the same call chain, which are deferred to after combat now.
	self[kind] = header
end

-- plain (insecure) overlay icons used IN COMBAT for auras that arrived after
-- the header last spawned a button: protected children cannot be created
-- mid-fight, but display frames can, so every new buff shows immediately and
-- the secure button takes over at regen. No cancelaura in combat either way.
local function OverlayFor(self, header, n)
	header.suiOverlays = header.suiOverlays or {}
	local ov = header.suiOverlays[n]
	if ov then return ov end
	local db = self.db[header.kind]
	local size = math.floor((db.size or 32) / 2 + 0.5) * 2
	ov = CreateFrame("Button", nil, header)
	ov:SetSize(size, size)
	S:CreateBackdrop(ov, "Default")
	ov.icon = ov:CreateTexture(nil, "ARTWORK")
	S:SetInside(ov.icon, ov, 0, 0)
	ov.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	ov.cd = CreateFrame("Cooldown", nil, ov, "CooldownFrameTemplate")
	S:SetInside(ov.cd, ov, 0, 0)
	ov.cd:SetReverse(true)
	ov.cd:SetDrawEdge(false)
	ov.cd:SetHideCountdownNumbers(true)
	ov.cd:SetSwipeColor(0, 0, 0, 0.55)
	local th = CreateFrame("Frame", nil, ov)
	th:SetAllPoints()
	th:SetFrameLevel(ov:GetFrameLevel() + 3)
	ov.count = S:FontString(th, self.db.fontSize, "OUTLINE", S.media.numberFont)
	ov.count:SetPoint("BOTTOMRIGHT", -1, 2)
	ov.time = S:FontString(ov, self.db.fontSize, "OUTLINE", S.media.numberFont)
	ov.time:SetPoint("TOP", ov, "BOTTOM", 0, -2)
	ov.filter = header:GetAttribute("filter")
	ov.header = header
	ov:SetScript("OnEnter", OnEnter)
	ov:SetScript("OnLeave", GameTooltip_Hide)
	header.suiOverlays[n] = ov
	return ov
end

local function HideOverlays(header, from)
	for i = from or 1, header.suiOverlays and #header.suiOverlays or 0 do
		header.suiOverlays[i]:Hide()
		header.suiOverlays[i].suiIndex = nil
	end
end

function A:CombatOverlay(header)
	if not header then return end
	local db = self.db[header.kind]
	local unit = header:GetAttribute("unit") or "player"
	local filter = header:GetAttribute("filter") or "HELPFUL"
	local used = {}
	for _, child in ipairs({ header:GetChildren() }) do
		if child.GetAttribute then
			local ix = child:GetAttribute("index")
			if ix then used[ix] = true end
		end
	end
	local size = math.floor((db.size or 32) / 2 + 0.5) * 2
	local perRow, spacing = db.perRow or 8, (db.spacing or 2)
	local left = db.growthX == "LEFT"
	local down = db.growthY == "DOWN"
	-- display order must equal the header's own sorting or overlays land on
	-- wrong slots: own auras first (separateOwn), then by time (longest
	-- first for "-"), INDEX falls back to raw aura order
	local order = {}
	for i = 1, 40 do
		local a = S.GetAura(unit, i, filter)
		if not a then break end
		local exp = a.expirationTime
		-- aura fields can be SECRET values in combat on this client: any
		-- comparison with them errors and would kill the whole overlay pass
		if IsSecret(exp) then exp = 0 end
		local own = a.isFromPlayerOrPlayerPet
		if IsSecret(own) then own = nil end
		order[#order + 1] = { index = i, exp = tonumber(exp) or 0, own = own }
	end
	local byTime = (db.sortMethod or "TIME") == "TIME"
	local asc = db.sortDir == "+"
	table.sort(order, function(a, b)
		if db.separateOwn == 1 and a.own ~= b.own then return a.own end
		if byTime then
			if a.exp ~= b.exp then return asc and a.exp < b.exp or a.exp > b.exp end
		elseif a.index ~= b.index then
			return asc and a.index < b.index or a.index > b.index
		end
		return a.index < b.index
	end)
	local pt = header:GetAttribute("point") or "TOPRIGHT"
	local n = 0
	for slot = 1, #order do
		local e = order[slot]
		if used[e.index] then e.skip = true else
		n = n + 1
		local ov = OverlayFor(self, header, n)
		ov.suiIndex = e.index
		local col, row = (slot - 1) % perRow, math.floor((slot - 1) / perRow)
		ov:ClearAllPoints()
		ov:SetPoint(pt, header, pt,
			(left and -1 or 1) * (col * (size + spacing)),
			(down and -1 or 1) * (row * (size + (db.wrapSpacing or spacing))))
		ov:Show()
		S:SafeCall("Auras:Overlay", self.UpdateAura, self, ov, e.index)
		end
	end
	HideOverlays(header, n + 1)
end

function A:CombatRefresh(header)
	-- contents of already-spawned buttons are plain display ops (icon, timer,
	-- stacks) -> safe even in combat; auras without a spawned button get an
	-- insecure overlay icon so they still show mid-fight
	if not header then return end
	self:CombatOverlay(header)
	for _, child in ipairs({ header:GetChildren() }) do
		if child.GetAttribute then
			local index = child:GetAttribute("index")
			if index then
				S:SafeCall("Auras:CombatUpdate", self.UpdateAura, self, child, index)
			else
				local slot = child:GetAttribute("target-slot")
				if slot then S:SafeCall("Auras:CombatWeapon", self.UpdateWeapon, self, child, slot) end
			end
		end
	end
end

-- SecureAuraHeader_Update is a file-local on this client (not reachable from
-- addon code); the template's own OnAttributeChanged calls it internally when
-- "unit" changes -> re-set it to re-enter the full spawn/layout path.
function A:RefreshHeaders(unit)
	if InCombatLockdown() then return self:CombatRefresh() end
	if unit and unit ~= "player" then return end
	for _, header in pairs({ self.buffs, self.debuffs }) do
		if InCombatLockdown() then
			self:CombatRefresh(header)
		else
			-- the header spawns and layouts itself (secure path); we only wire
			-- children that spawned without regions and fill their contents
			for _, child in ipairs({ header:GetChildren() }) do
				if not child.icon then S:InitAuraButton(child) end
			end
			HideOverlays(header, 1)
			self:CombatRefresh(header)
		end
	end
end

function A:UNIT_AURA(_, unit) self:RefreshHeaders(unit) end
function A:UNIT_INVENTORY_CHANGED(_, unit) self:RefreshHeaders(unit) end
function A:GROUP_ROSTER_UPDATE() self:RefreshHeaders() end

function A:DisableBlizzard()
	for _, name in ipairs({ "BuffFrame", "DebuffFrame", "TemporaryEnchantFrame" }) do
		local f = _G[name]
		if f then
			f:UnregisterAllEvents()
			f:SetParent(S.hiddenFrame)
			f:Hide()
		end
	end
end

function A:Update()
	if self.buffs then self:ConfigureHeader(self.buffs) end
	if self.debuffs then self:ConfigureHeader(self.debuffs) end
end

function A:Initialize()
	if self.private.disableBlizzard then self:DisableBlizzard() end
	self:CreateHeader("buffs")
	self:CreateHeader("debuffs")
	self:RegisterEvent("UNIT_AURA")
	self:RegisterEvent("UNIT_INVENTORY_CHANGED")
	self:RegisterEvent("GROUP_ROSTER_UPDATE")
	-- initial fill + refresh after zoning/reloads (attribute re-set path is
	-- safe out of combat; inside combat only contents refresh)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", function() A:RefreshHeaders() end)
	self:RegisterEvent("PLAYER_REGEN_ENABLED", function() A:RefreshHeaders() end)

	SLASH_SUIAURAT1 = "/suiauras"
	SlashCmdList.SUIAURAT = function()
		local h = A.buffs
		if not h then print("no header") return end
		local want = 0
		for i = 1, 40 do if not S.GetAura("player", i, "HELPFUL") then break end want = want + 1 end
		local spawned = 0
		for _, c in ipairs({ h:GetChildren() }) do
			if c.GetAttribute and c:GetAttribute("index") then spawned = spawned + 1 end
		end
		local ov, ovShown = 0, 0
		for _, o in ipairs(h.suiOverlays or {}) do
			ov = ov + 1
			if o:IsShown() then ovShown = ovShown + 1 end
		end
		print("|cff88ccffAuras:|r combat=" .. tostring(InCombatLockdown()),
			"live=" .. want, "buttons=" .. spawned,
			"overlays=" .. ovShown .. "/" .. ov)
	end
	self:RefreshHeaders()
end
