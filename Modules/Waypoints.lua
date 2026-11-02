--[[
	SentinelUI TomTom-style waypoint module.

	Replicates the TomTom feature set: waypoint queue, crazy arrow with
	distance/ETA, minimap + worldmap icons, corpse arrow, /way slash
	commands and the TomTom Lua API surface so addons like Questie can
	feed waypoints into SentinelUI. If the real TomTom addon is loaded we
	stay out of its way for the global API (Questie then talks to it),
	while our arrow/commands still work on their own.
]]

local S = SentinelUI
local TT = S:NewModule("Waypoints", "waypoints")
local L = S.L
local DT

local GetBestMap = C_Map and C_Map.GetBestMapForUnit
local GetPlayerPos = C_Map and C_Map.GetPlayerMapPosition
local GetWorldPos = C_Map and C_Map.GetWorldPosFromMapPos
local GetMapInfo = C_Map and C_Map.GetMapInfo
local WorldPosToMapPos = C_Map and C_Map.GetMapPosFromWorldPos

local TWO_PI = math.pi * 2

-- ------------------------------------------------------------------------
-- waypoints storage: waypoints[mapID][key] = uid
-- key is m:x:y:title like TomTom's GetKey
-- ------------------------------------------------------------------------
local waypoints = {}
local active, corpseWp

local function WKey(m, x, y, title)
	return table.concat({ m or 0, x or 0, y or 0, title or "" }, ":")
end

local function PlayerPos()
	local m = GetBestMap and GetBestMap("player")
	if not m then return end
	local p = GetPlayerPos and GetPlayerPos(m, "player")
	if not p then return m, nil, nil end
	return m, p.x, p.y
end

-- world-space position (yards) for a map point, or nil
local function WorldPos(m, x, y)
	if not (GetWorldPos and x and y and m) then return end
	local w = CreateVector2D and CreateVector2D(x, y)
	if not w then return end
	-- returns (instanceID, Vector2D); older clients may return the vector alone
	local ok, a, b = pcall(GetWorldPos, m, w)
	local wp = type(b) == "table" and b or (type(a) == "table" and a) or nil
	if ok and wp then return wp.x, wp.y end
end

-- unit vectors of the map's east (x) and south (y) axes in world space; the
-- world-axis convention is calibrated per map instead of assumed
local basisCache = {}
local function Basis(m)
	local c = basisCache[m]
	if c then return c[1], c[2], c[3], c[4] end
	local ox, oy = WorldPos(m, 0, 0)
	local ex, ey = WorldPos(m, 1, 0)
	local sx, sy = WorldPos(m, 0, 1)
	if not (ox and ex and sx) then return end
	local function unit(x, y)
		local l = math.sqrt(x * x + y * y)
		if l == 0 then return 0, 0 end
		return x / l, y / l
	end
	local e1, e2 = unit(ex - ox, ey - oy)
	local s1, s2 = unit(sx - ox, sy - oy)
	basisCache[m] = { e1, e2, s1, s2 }
	return e1, e2, s1, s2
end

-- distance in yards and heading (radians, counter-clockwise from north,
-- same convention as GetPlayerFacing)
local function DistDir(uid)
	local pm, px, py = PlayerPos()
	if not px then return end
	local wx, wy = WorldPos(uid[1], uid[2], uid[3])
	local pwX, pwY = WorldPos(pm, px, py)
	local east, south
	if wx and pwX then
		local dx, dy = wx - pwX, wy - pwY
		local e1, e2, s1, s2 = Basis(pm)
		if not e1 then return math.sqrt(dx * dx + dy * dy), 0 end
		east, south = dx * e1 + dy * e2, dx * s1 + dy * s2
	elseif uid[1] == pm then
		east, south = (uid[2] - px) * 1000, (uid[3] - py) * 1000
	else
		return
	end
	return math.sqrt(east * east + south * south), math.atan2(-east, -south)
end

local function FireCB(uid, what, arg)
	local cb = uid.callbacks and uid.callbacks[what]
	if type(cb) == "function" then pcall(cb, nil, uid, arg) end
end

-- ------------------------------------------------------------------------
-- crazy arrow
-- ------------------------------------------------------------------------
local arrow, arrTex, arrDist, arrTitle, arrTTA
local lastDist, tta, speedBuf, speedN

local function ArrowShown() return arrow and arrow:IsShown() end

function TT:UpdateArrow()
	if not arrow then return end
	if not active then arrow:Hide() return end
	arrow:Show()
	local dist = DistDir(active)
	if dist then
		arrDist:SetFormattedText("%d yds", dist)
		arrTitle:SetText(active.title or "")
	else
		arrDist:SetText("")
		arrTitle:SetText(active.title or "")
	end
end

local function BuildArrow()
	if arrow then return end
	arrow = CreateFrame("Frame", "SentinelWaypointArrow", UIParent)
	arrow:SetSize(72, 92)
	arrow:SetPoint("CENTER", UIParent, "CENTER", 0, 220)
	arrow:SetClampedToScreen(true)
	arrow:EnableMouse(true)
	arrow:SetMovable(true)
	arrow:RegisterForDrag("LeftButton")
	arrow:SetScript("OnDragStart", arrow.StartMoving)
	arrow:SetScript("OnDragStop", arrow.StopMovingOrSizing)

	arrTex = arrow:CreateTexture(nil, "ARTWORK")
	arrTex:SetSize(56, 56)
	arrTex:SetPoint("TOP", 0, -4)
	arrTex:SetTexture([[Interface\MINIMAP\MinimapArrow]])

	arrTitle = S:FontString(arrow, 9, "OUTLINE")
	arrTitle:SetPoint("TOP", arrTex, "BOTTOM", 0, 2)

	arrDist = S:FontString(arrow, 10, "OUTLINE")
	arrDist:SetPoint("TOP", arrTitle, "BOTTOM", 0, -1)

	arrTTA = S:FontString(arrow, 9, "OUTLINE")
	arrTTA:SetPoint("TOP", arrDist, "BOTTOM", 0, -1)

	local elapsed, throttle = 0, 0
	arrow:SetScript("OnUpdate", function(self, e)
		throttle = throttle + e
		elapsed = e
		if throttle < 0.05 then return end
		e = throttle
		throttle = 0
		if not active then self:Hide() return end
		local dist, dir = DistDir(active)
		if not dist then arrDist:SetText(""); return end
		local facing = GetPlayerFacing and GetPlayerFacing() or 0
		if dir then
			local a = (dir - facing + math.pi) % TWO_PI - math.pi
			if arrTex.SetRotation then arrTex:SetRotation(a) end
			local perc = math.abs((math.pi - math.abs(a)) / math.pi)
			if perc > 0.85 then arrTex:SetVertexColor(0.3, 1, 0.3)
			elseif perc > 0.4 then arrTex:SetVertexColor(1, 0.85, 0.2)
			else arrTex:SetVertexColor(1, 0.3, 0.25) end
		end
		arrDist:SetFormattedText("%d yds", dist)
		if TT.db.showETA ~= false then
			local spd = lastDist and math.max(lastDist - dist, 0) or 0
			lastDist = dist
			tta = (tta or 0) + e
			if spd > 0.5 and tta > 0.5 then
				local eta = math.abs(dist / spd)
				arrTTA:SetFormattedText("%d:%02d", math.floor(eta / 60), math.floor(eta % 60))
				tta = 0
			end
		end
		-- arrival: flip arrow + fire clear callbacks
		local arrive = (active.arrivaldistance or TT.db.arrival or 15)
		if dist <= arrive then
			arrTex:SetVertexColor(0.4, 1, 0.5)
			FireCB(active, "arrived", dist)
			local uid = active
			TT:ClearWaypoint(active)
			if not uid.persistent then TT:RemoveWaypoint(uid) end
			if TT.db.setclosest ~= false then TT:SetClosestWaypoint() end
		else
			FireCB(active, "distance", dist)
		end
	end)
end

function TT:SetCrazyArrow(uid, arrivaldistance, title)
	BuildArrow()
	active = uid
	if arrivaldistance then uid.arrivaldistance = arrivaldistance end
	if title then uid.title = title end
	lastDist, tta = nil, 0
	self:UpdateArrow()
end

-- ------------------------------------------------------------------------
-- map icons (minimap + worldmap), small pooled dots
-- ------------------------------------------------------------------------
local pins = {}
local function GetPin(i)
	local p = pins[i]
	if not p then
		p = CreateFrame("Frame", nil, Minimap)
		p:SetSize(12, 12)
		p.tex = p:CreateTexture(nil, "OVERLAY")
		p.tex:SetAllPoints()
		p.tex:SetTexture([[Interface\MINIMAP\ObjectIconsAtlas]])
		p.tex:SetTexCoord(0.296875, 0.3125, 0.25, 0.28125) -- waypoint pin glyph
		pins[i] = p
	end
	return p
end

local function UpdateMinimapPins()
	local pm, pmx, pmy = PlayerPos()
	local pwx, pwy = WorldPos(pm, pmx, pmy)
	local i = 1
	for m, set in pairs(waypoints) do
		for _, uid in pairs(set) do
			if uid.minimap ~= false and m == pm then
				local wx, wy = WorldPos(m, uid[2], uid[3])
				if wx and pwx then
					local pin = GetPin(i)
					local dx, dy = wx - pwx, wy - pwy
					local d = math.sqrt(dx * dx + dy * dy)
					local r = math.min(d * 0.4, (Minimap:GetWidth() / 2) - 10)
					local a = math.atan2(dy, dx)
					pin:SetParent(Minimap)
					pin:ClearAllPoints()
					pin:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
					pin:Show()
					i = i + 1
				end
			end
		end
	end
	for j = i, #pins do pins[j]:Hide() end
end

-- ------------------------------------------------------------------------
-- public API (TomTom-compatible)
-- ------------------------------------------------------------------------
function TT:AddWaypoint(m, x, y, opts)
	opts = opts or {}
	local key = WKey(m, x, y, opts.title)
	if waypoints[m] and waypoints[m][key] then return waypoints[m][key] end
	local uid = { m, x, y, title = opts.title, from = opts.from or "?" }
	for k, v in pairs(opts) do if uid[k] == nil then uid[k] = v end end
	waypoints[m] = waypoints[m] or {}
	waypoints[m][key] = uid
	if opts.crazy ~= false then self:SetCrazyArrow(uid, opts.arrivaldistance, opts.title) end
	if not opts.silent then
		S:Print(format("|cffffff78TomTom|r %s (%.1f, %.1f) %s", L["Waypoint"], x * 100, y * 100, opts.title or ""))
	end
	UpdateMinimapPins()
	return uid
end

function TT:RemoveWaypoint(uid)
	if type(uid) ~= "table" then return end
	local set = waypoints[uid[1]]
	if set then set[WKey(uid[1], uid[2], uid[3], uid.title)] = nil end
	if active == uid then
		active = nil
		if arrow then arrow:Hide() end
		self:SetClosestWaypoint()
	end
	UpdateMinimapPins()
end

function TT:ClearWaypoint(uid)
	if active == uid then
		active = nil
		if arrow then arrow:Hide() end
	end
end

function TT:ClearAllWaypoints()
	wipe(waypoints)
	active = nil
	if arrow then arrow:Hide() end
	UpdateMinimapPins()
end

function TT:IsValidWaypoint(uid)
	return type(uid) == "table" and waypoints[uid[1]] and waypoints[uid[1]][WKey(uid[1], uid[2], uid[3], uid.title)] == uid
end

function TT:WaypointExists(m, x, y, desc)
	local set = waypoints[m]
	if not set then return end
	for _, uid in pairs(set) do
		if math.abs(uid[2] - x) < 0.001 and math.abs(uid[3] - y) < 0.001 then return uid end
	end
end

function TT:GetClosestWaypoint()
	local pm = PlayerPos()
	local best, bd
	for m, set in pairs(waypoints) do
		for _, uid in pairs(set) do
			local d = select(1, DistDir(uid)) or math.huge
			if m == pm and (not bd or d < bd) then bd, best = d, uid end
		end
	end
	return best
end

function TT:SetClosestWaypoint(verbose)
	local wp = self:GetClosestWaypoint()
	if wp then self:SetCrazyArrow(wp, wp.arrivaldistance, wp.title) return wp end
end

function TT:GetDistanceToWaypoint(uid) return (DistDir(uid) or 0) end
function TT:GetDirectionToWaypoint(uid) local _, d = DistDir(uid) return d or 0 end
function TT:ShowHideWaypoint(uid, show)
	if uid then uid.minimap, uid.world = show and true or false, show and true or false end
	UpdateMinimapPins()
end
function TT:SetCustomWaypoint(m, x, y, opts)
	opts = opts or {}; opts.crazy = true
	return self:AddWaypoint(m, x, y, opts)
end
function TT:WaypointC(m, x, y, show, cb, mini, world)
	return self:AddWaypoint(m, x, y, { callbacks = cb, minimap = mini, world = world, silent = not show })
end

local function ListWaypoints()
	local n = 0
	for m, set in pairs(waypoints) do
		for _, uid in pairs(set) do
			n = n + 1
			S:Print(format("%d) %s |cff888888%.1f, %.1f map %d|r", n, uid.title or "?", uid[2] * 100, uid[3] * 100, m))
		end
	end
	if n == 0 then S:Print(L["No waypoints"] or "No waypoints") end
end

-- ------------------------------------------------------------------------
-- zone-name -> mapID (lazy scan of C_Map, cached)
-- ------------------------------------------------------------------------
local nameToMap
local function ResolveZone(name)
	if not name or name == "" then return end
	if not nameToMap then
		nameToMap = {}
		for id = 1, 4000 do
			local ok, info = pcall(GetMapInfo, id)
			if ok and info and info.name and (info.mapType == 2 or info.mapType == 3 or info.mapType == 4) then
				local nm = info.name:gsub("%s", ""):lower()
				if not nameToMap[nm] then nameToMap[nm] = id end
			end
		end
	end
	local q = name:gsub("%s", ""):lower()
	if nameToMap[q] then return nameToMap[q] end
	for nm, id in pairs(nameToMap) do if nm:find(q, 1, true) then return id end end
end

-- /way [zone] x y [title]
local function ParseWay(msg)
	msg = strtrim(msg or "")
	if msg == "" or msg == "help" then
		S:Print("/way [zone] x y [title] · /cway · /waylist · /wayresetall")
		return
	end
	local m
	local rest = msg
	-- "Zone x y desc" where zone may be multiword: try longest match
	local mapID, coords = GetBestMap and GetBestMap("player"), nil
	local parts = {}
	for w in msg:gmatch("%S+") do parts[#parts + 1] = w end
	local zi
	for i = #parts - 2, 1, -1 do
		local cand = table.concat(parts, " ", 1, i)
		local id = ResolveZone(cand)
		if id then mapID, zi = id, i break end
	end
	local nums = {}
	for i = (zi or 0) + 1, #parts do
		local n = tonumber((parts[i]:gsub(",", ".")))
		if n then nums[#nums + 1] = n else break end
	end
	local title
	if #nums >= 2 then
		local ti = (zi or 0) + #nums + 1
		if parts[ti] then title = table.concat(parts, " ", ti) end
	end
	local x, y = nums[1], nums[2]
	if x and y then
		TT:AddWaypoint(mapID, x / 100, y / 100, { title = title, from = "slash" })
	else
		S:Print(L["Usage: /way [zone] x y [title]"] or "Usage: /way [zone] x y [title]")
	end
end

-- ------------------------------------------------------------------------
-- corpse arrow
-- ------------------------------------------------------------------------
local function CorpseCheck()
	if not (TT.db.corpse ~= false) then return end
	if UnitIsDeadOrGhost("player") then
		local pm = PlayerPos()
		local cp = C_DeathInfo and C_DeathInfo.GetCorpseMapPosition and C_DeathInfo.GetCorpseMapPosition(pm)
		if cp and (cp.x > 0 or cp.y > 0) then
			if not corpseWp or corpseWp[2] ~= cp.x or corpseWp[3] ~= cp.y then
				if corpseWp then TT:RemoveWaypoint(corpseWp) end
				corpseWp = TT:AddWaypoint(pm, cp.x, cp.y, { title = L["Corpse"], silent = true, crazy = true, persistent = false })
			end
		end
	elseif corpseWp then
		TT:RemoveWaypoint(corpseWp)
		corpseWp = nil
	end
end

-- ------------------------------------------------------------------------
-- TomTom facade: only install the global when the real addon is absent
-- ------------------------------------------------------------------------
local function InstallFacade()
	if _G.TomTom then return end
	local api = {}
	for _, n in ipairs({ "AddWaypoint", "RemoveWaypoint", "ClearWaypoint", "ClearAllWaypoints",
		"IsValidWaypoint", "WaypointExists", "GetClosestWaypoint", "SetClosestWaypoint",
		"GetDistanceToWaypoint", "GetDirectionToWaypoint", "ShowHideWaypoint",
		"SetCustomWaypoint", "WaypointC", "SetCrazyArrow" }) do
		api[n] = function(_, ...) return TT[n](TT, ...) end
	end
	api.db = { profile = { arrow = { setclosest = true } } }
	_G.TomTom = api
	-- Questie gates parts of its UI on IsAddOnLoaded("TomTom"); report the
	-- facade as loaded so those controls appear
	local function wrap(tbl, fn)
		local orig = tbl and tbl[fn]
		if type(orig) ~= "function" then return end
		tbl[fn] = function(name, ...)
			if name == "TomTom" then return true, true end
			return orig(name, ...)
		end
	end
	wrap(_G, "IsAddOnLoaded")
	wrap(C_AddOns, "IsAddOnLoaded")
end

-- ------------------------------------------------------------------------
-- init / events
-- ------------------------------------------------------------------------
local f = CreateFrame("Frame")
function TT:Initialize()
	BuildArrow()
	f:RegisterEvent("PLAYER_DEAD")
	f:RegisterEvent("PLAYER_ALIVE")
	f:RegisterEvent("PLAYER_UNGHOST")
	f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	local tick = 0
	f:SetScript("OnUpdate", function(_, e)
		tick = tick + e
		if tick > 1 then tick = 0 CorpseCheck() UpdateMinimapPins() end
	end)
	InstallFacade()
	SLASH_SUIWAY1 = "/way"
	SLASH_SUIWAY2 = "/tway"
	SLASH_SUIWAY3 = "/tomtomway"
	SlashCmdList.SUIWAY = ParseWay
	SLASH_SUIWAYC1 = "/cway"
	SLASH_SUIWAYC2 = "/closestway"
	SlashCmdList.SUIWAYC = function() TT:SetClosestWaypoint(true) end
	SLASH_SUIWAYL1 = "/waylist"
	SlashCmdList.SUIWAYL = ListWaypoints
	SLASH_SUIWAYR1 = "/wayresetall"
	SlashCmdList.SUIWAYR = function() TT:ClearAllWaypoints() end
end

function TT:PLAYER_DEAD() CorpseCheck() end
function TT:PLAYER_ALIVE() CorpseCheck() end
function TT:PLAYER_UNGHOST() CorpseCheck() end
function TT:ZONE_CHANGED_NEW_AREA() if self.db.setclosest ~= false then self:SetClosestWaypoint() end end
f:SetScript("OnEvent", function(_, ev, ...) local h = TT[ev] if h then h(TT, ...) end end)

-- worldmap ctrl+click -> waypoint
if WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child then
	local hook = WorldMapFrame.ScrollContainer.Child
	hook:HookScript("OnMouseDown", function(_, btn)
		if btn ~= "RightButton" or not IsControlKeyDown() then return end
		local cX, cY = GetCursorPosition()
		local s = WorldMapFrame.ScrollContainer.Child:GetEffectiveScale()
		local l, t = WorldMapFrame.ScrollContainer.Child:GetLeft(), WorldMapFrame.ScrollContainer.Child:GetTop()
		local mx = (cX / s - l) / WorldMapFrame.ScrollContainer.Child:GetWidth()
		local my = (t - cY / s) / WorldMapFrame.ScrollContainer.Child:GetHeight()
		local map = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
		if map and mx >= 0 and mx <= 1 and my >= 0 and my <= 1 then
			TT:AddWaypoint(map, mx, my, { title = format("%.1f, %.1f", mx * 100, my * 100), from = "mapclick" })
		end
	end)
end
