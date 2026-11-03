-- BiS pools: which generated pool (Pool_<NAME>.lua) belongs to this client.
-- TBC keeps its richer built-in data (Data_Bis.lua), so it has no pool.
-- Every pool file checks this name first and returns at once when it is not
-- its own, so a client only ever keeps the data it can use.
local _, ns = ...

function ns.BisPoolName()
	local TD = ns.TalentAtlasData
	local idx = TD and TD.clientIndex or 12
	if idx == 1 then
		local season = C_Seasons and C_Seasons.GetActiveSeason and C_Seasons.GetActiveSeason()
		return season == 2 and "SOD" or "CLASSIC"
	elseif idx == 3 then return "WRATH"
	elseif idx == 4 then return "CATA"
	elseif idx == 5 then return "MISTS"
	elseif idx >= 6 then return "RETAIL" end
end
