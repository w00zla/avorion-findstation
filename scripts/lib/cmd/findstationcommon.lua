--[[

FINDSTATION MOD

version: alpha2
author: w00zla

file: lib/cmd/findstationcommon.lua
desc: library script for /findstation commands

]]--

package.path = package.path .. ";data/scripts/lib/?.lua"

-- include libraries
require("utility")
require("stringutility")


local configprefix = "findstation_"
local paramtypelabels = { pnum="Number", path="Path" }


function saveConfigValue(config, val)

	local storagekey = configprefix .. config
	Server():setValue(storagekey, val)

end


function loadConfigValue(config, default)

	local storagekey = configprefix .. config
	local val = Server():getValue(storagekey)
	if not val then
		val = default
	end
	return val

end


-- validate parameter values based on their type
function validateParameter(paramval, paramtype)

	-- paramvalidate config paramvalues by type
	if paramval and paramval ~= "" then
		if paramtype == "pnum" then
			-- positive number paramvalues
			local pnum = tonumber(configparamval)
			if pnum and pnum >= 0 then
				return pnum
			end
		elseif paramtype == "path" then
			-- path value
			-- append ending backslash
			if not string.ends(paramval, "\\") then
				paramval = paramval .. "\\"
				return paramval
			end
		end
		-- paramvalid generic string paramvalue
		return paramval
	end
	
end


-- get nice titles for parameter-types
function getParamTypeLabel(paramtype)

	local paramtypelabel = paramtype
	if paramtypelabels[paramtype] then
		paramtypelabel = paramtypelabels[paramtype]
	end
	return paramtypelabel
	
end


-- attaches script to entity if not already existing
function ensureEntityScript(entity, entityscript)
	
	if entity and not entity:hasScript(entityscript) then
		entity:addScriptOnce(entityscript)
	end

end


-- get distance to players current sector
function getCurrentCoordsDistance(x, y)

	local vecSector = vec2(Sector():getCoordinates())
	local vecCoords = vec2(x, y)
	local dist = distance(vecSector, vecCoords)

	return dist

end


-- sort table items by their key values
function pairsByKeys (t, f)
	local a = {}
	for n in pairs(t) do table.insert(a, n) end
	table.sort(a, f)
	local i = 0      -- iterator variable
	local iter = function ()   -- iterator function
		i = i + 1
		if a[i] == nil then return nil
		else return a[i], t[a[i]]
		end
	end
	return iter
end