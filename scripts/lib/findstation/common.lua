--[[

FINDSTATION MOD

version: 0.5alpha
author: w00zla

file: lib/findstation/common.lua
desc: general library script for findstation commands

]]--

package.path = package.path .. ";data/scripts/lib/?.lua"

require("utility")
require("stringutility")

require("findstation.config")

-- globals
fs_searchcmd = "findstation/searchcmd.lua"
fs_uiloader = "findstation/uiloader.lua"
fs_searchui = "findstation/searchui.lua"

-- DEBUG
local debugoutput = false


local modInfo = {
	name = "findstation",
	version = "0.5a",
	author = "w00zla"
}

local searchlifetime = 15
local paramtypelabels = { pnum="Number", path="Path" }


-- validate parameter value based on type
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
			if not string.ends(paramval, "/") then
				paramval = paramval .. "/"				
			end
			return paramval
		end
		-- generic string param
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
function ensureEntityScript(entity, entityscript, ...)
	
	if tonumber(entity) then
		entity = Entity(entity)
	end
	
	if entity and not entity:hasScript(entityscript) then
		entity:addScriptOnce(entityscript, ...)
		debugLog("script was added to entity (index: %s, script: %s)", entity.index, entityscript)
	end

end


function removeEntityScript(entity, entityscript)

	if tonumber(entity) then
		entity = Entity(entity)
	end

	if entity and entity:hasScript(entityscript) then
		entity:removeScript(entityscript)
		debugLog("script was removed from entity (index: %s, script: %s)", entity.index, entityscript)
	end	

end


-- get distance to players current sector
function getCurrentCoordsDistance(x, y)

	local vecSector = vec2(Sector():getCoordinates())
	local vecCoords = vec2(x, y)
	local dist = distance(vecSector, vecCoords)

	return dist

end


-- get distance between coordinates
function getCoordsDistance(x1, y1, x2, y2)

	local vecs1 = vec2(x1, y1)
	local vecs2 = vec2(x2, y2)
	local dist = distance(vecs1, vecs2)

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


-- gets all existing files in given directory
function scandir(directory, pattern)

    local i, t, popen = 0, {}, io.popen
    --local BinaryFormat = package.cpath:match("%p[\\|/]?%p(%a+)")
	local BinaryFormat = string.sub(package.cpath,-3)
	local cmd = ""
	if not string.ends(directory, "/") then
		directory = directory .. "/"				
	end
	local path = directory	
	if pattern then 	
		path = path .. pattern
	end
    if BinaryFormat == "dll" then
		path = string.gsub(path, "/", "\\")
		cmd =   'dir "'..path..'" /b /a-d'
    else
		path = string.gsub(path, "\\", "/")
		cmd = "ls " .. path
    end
	
	debugLog("scandir cmd: %s", cmd)
    local pfile = popen(cmd)
    for filename in pfile:lines() do
		i = i + 1
		if string.starts(filename, directory) then
			t[i] = string.sub(filename, string.len(directory) + 1)
		else
			t[i] = filename
		end		
    end
    pfile:close()
    return t
	
end


function sortSectorsByDistance(sectors, refsector)
	
	local sectorsByDist = {}
	local sorted = {}
	
	for _, coords in pairs(sectors) do 
		local dist = getCoordsDistance(refsector.x, refsector.y, coords.x, coords.y)
		if not sectorsByDist[dist] then
			sectorsByDist[dist] = {}
		end
		table.insert(sectorsByDist[dist], coords)
	end
	
	for d, v1 in pairsByKeys(sectorsByDist) do
		for _, v2 in pairs(v1) do
			table.insert(sorted, v2)
		end
	end

	return sorted
	
end


function getExistingSectors(galaxypath, coords)

	local sectorspath = galaxypath .. "sectors/"
	local sectors = {}
	
	-- scan directory for sector XML files 
	local secfiles = scandir(sectorspath, "*v")
	for _, v in pairs(secfiles) do 
		local secCoords = parseSectorFilename(v)
		if coords then
			if secCoords.x ~= coords.x and secCoords.y ~= coords.y then
				table.insert(sectors, secCoords)
			end
		else
			table.insert(sectors, secCoords)
		end
	end

	return sectors
	
end


-- parse "XXX_YYY" style string for sector coordinates
function parseSectorFilename(filename)

	local coordX, coordY = string.match(filename, "([%d%-]+)_([%d%-]+)")
	if coordY and coordX then	
		return vec2(tonumber(coordX), tonumber(coordY))
	end
	
end


function searchCurrentSectorStations(term)

	local results = {}
	
	for _, station in pairs({Sector():getEntitiesByType(EntityType.Station)}) do
		-- do a case-insensitive search for the given term
		if string.find(station.title:lower(), term:lower(), 1, true) then
			local title = station.title % station:getTitleArguments()
			table.insert(results, {title=title, entity=station.index})
		end
	end

	return results 
end


function checkFileExists(filepath)

	local sectorFile, err = io.open(filepath)
	if not sectorFile or err then
		return false
	end
	sectorFile:close()

	return true
	
end


function getDefaultDataPath()

	-- get APPDATA path (linux: HOME directory) because game uses this as base directory to save galaxies 
	-- this is by default, even for dedicated servers!

	local datapath 
	
	local appdatadir = os.getenv("APPDATA")
	-- windows
	if appdatadir and appdatadir ~= "" then
		datapath = appdatadir .. "/Avorion/galaxies/"
	else
		-- linux
		local homedir = os.getenv("HOME")
		if homedir and homedir ~= "" then
			datapath = homedir .. "/.avorion/galaxies/"
		end
	end	
	
	return datapath
	
end


function getModInfoLine()

	return string.format("%s [v%s] by %s", modInfo.name, modInfo.version, modInfo.author)

end

function scriptLog(player, msg, ...)

	if msg and msg ~= "" then
		local pinfo = ""
		if player then pinfo = " p#" .. tostring(player.index) end
		local prefix = string.format("SCRIPT %s [v%s]%s => ", modInfo.name, modInfo.version, pinfo)
		printsf(prefix .. msg, ...)
	end
	
end


function debugLog(msg, ...)

	if debugoutput and msg and msg ~= "" then
		local pinfo = ""
		local player = Player()
		if player then pinfo = " p#" .. tostring(player.index) end
		local prefix = string.format("SCRIPT %s [v%s]%s DEBUG => ", modInfo.name, modInfo.version, pinfo)
		printsf(prefix .. msg, ...)
	end
	
end


function printsf(message, ...)

	message = string.format(message, ...)
	print(message)
	
end


function getConcurrentSearchData()
	
	local val = Config.loadValue("concurrentsearches")
	local data = {}
	if val then
		data = tostring(val):split(";")
	end
	return data
	
end


function setConcurrentSearchData(data)
	
	if data then
		local val = table.concat(data, ";")	
		Config.saveValue("concurrentsearches", val)
	end
	
end


function addConcurrentSearch(searchtime)

	if searchtime then
		local data = getConcurrentSearchData()
		table.insert(data, searchtime)
		setConcurrentSearchData(data)
	end
	
end


function removeConcurrentSearch(searchtime)

	local data = getConcurrentSearchData()
	local remidx
	if searchtime then
		for i, v in pairs(data) do
			local numval = tonumber(v)
			if numval and numval == searchtime then
				remidx = i
				break
			end
		end
		
		if remidx then
			table.remove(data, remidx)
			setConcurrentSearchData(data)
		end
	end
	
end


function getConcurrentSearchesCount()

	local res = 0
	local valid = {}
	local expiretime = systemTime() - searchlifetime
	
	local data = getConcurrentSearchData()
	for i, v in pairs(data) do
		local numval = tonumber(v)
		if numval and numval >= expiretime then
			table.insert(valid, numval)
			res = res + 1
		end
	end
	
	if #valid ~= #data then
		setConcurrentSearchData(valid)
	end

	return res
	
end


function setPlayerLastSearchTime(playerIndex)

	local searchtime = math.floor(systemTime())
	local valstr = string.format("%i=%i", playerIndex, searchtime)
	
	local val = Config.loadValue("searchtimes")	
	local data = {}
	
	if val then
		data = val:split(";")
		local editidx = 0
		for i, v in pairs(data) do
			local pi, timestamp = string.match(v, "(%d+)=(%d+)")
			if pi and tonumber(pi) == playerIndex then
				editidx = i
				break
			end
		end

		if editidx > 0 then
			data[editidx] = valstr
		else
			table.insert(data, valstr)
		end
	else
		table.insert(data, valstr)
	end
	
	val = table.concat(data, ";")
	Config.saveValue("searchtimes", val)

end


function getPlayerLastSearchTime(playerIndex)

	local val = Config.loadValue("searchtimes")	
	if val then
		local data = val:split(";")
		for _, v in pairs(data) do
			local pi, timestamp = string.match(v, "(%d+)=(%d+)")
			if pi and tonumber(pi) == playerIndex then
				return tonumber(timestamp)
			end
		end
	end

end
