--[[

FINDSTATION MOD
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
fs_debugoutput = true


local modInfo = {
	name = "findstation",
	version = "0.6a",
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
	
	debugLog("scandir() -> cmd: %s", cmd)
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
		local dist = math.ceil(getCoordsDistance(refsector.x, refsector.y, coords.x, coords.y))
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

	if fs_debugoutput and msg and msg ~= "" then
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


function getPlayerKnownLocations(galaxypath, player, coords)

	-- build path to player's data file
	local datafilepath = galaxypath .. string.format("players/player_%i.dat", player.index)
	debugLog("datafilepath: %s", datafilepath)
	
	local f, err = io.open(datafilepath, "rb")
	if err then
		return nil, err
	end

	local data = f:read("*all")
		
	-- search for index strings
	local pos_ks, end_ks = string.find(data, "known_sectors")	
	if not pos_ks then
		return nil, "known_sectors string not found"
	end

	local pos_c, end_c = string.find(data, "coords", end_ks)
	if not pos_c then
		return nil, "coords string not found"
	end

	local results = {}
	
	-- parse coordinates data
	local offset_cd = end_c + 4
	debugLog("offset_cd: %s", offset_cd)
	
	-- get amount of stored coordinates
	f:seek("set", offset_cd)
	local cd_count = f:read(4)	
	cd_count = bytes_to_int(cd_count, "lit", false)			
	debugLog("cd_count: %s", cd_count)
	
	-- parse XY value-pairs for coordinates			
	for i = 1, cd_count, 1 do
		local offset_cdxy = offset_cd + 4 + ((i - 1) * 8)	
		f:seek("set", offset_cdxy)
		
		local coordx = f:read(4)
		coordx = bytes_to_int(coordx, "lit", true)							
		local coordy = f:read(4)
		coordy = bytes_to_int(coordy, "lit", true)			
		
		if coords then
			if coordx ~= coords.x and coordy ~= coords.y then
				results[i] = vec2(coordx, coordy)
			end
		else
			results[i] = vec2(coordx, coordy)
		end		
	end
	
	f:close()

	return results

end


-- convert a byte string to its integer representation (taking care of endianness at byte level, and signedness)
-- credits to jpjacobs (http://stackoverflow.com/questions/5241799/lua-dealing-with-non-ascii-byte-streams-byteorder-change)
function bytes_to_int(str, endian, signed) 

	-- use length of string to determine 8,16,32,64 bits
    local t={str:byte(1,-1)}
    if endian=="big" then --reverse bytes
        local tt={}
        for k=1,#t do
            tt[#t-k+1]=t[k]
        end
        t=tt
    end
    local n=0
    for k=1,#t do
        n=n+t[k]*2^((k-1)*8)
    end
    if signed then
        n = (n > 2^(#t*8-1) -1) and (n - 2^(#t*8)) or n -- if last bit set, negative.
    end
    return n
	
end


function getServerGalaxyPath()
	
	local cmd, galaxypath, found
	local BinaryFormat = string.sub(package.cpath,-3)
	
	-- get commandline of running avorion server process  
    if BinaryFormat == "dll" then
		-- WINDOWS: needs PowerShell and WMI installed, hopefully this works on most modern windozes
		cmd = 'powershell -command "Get-WmiObject Win32_Process -Filter \\"name = \'AvorionServer.exe\'\\" | ForEach { $_.CommandLine }"'
    else
		-- LINUX: standard ps commmand, hopefully parameters work for all distros this way
		cmd = "ps -fC AvorionServer"
    end
	debugLog("getServerGalaxyPath() -> cmd: %s", cmd)
	
	local pfile = io.popen(cmd)
    for l in pfile:lines() do
		-- parse command line info for server parameters
		debugLog("getServerGalaxyPath() -> %s", l)
		local cgn = string.match(l, "%-%-galaxy%-name%s([^%s%c]+)")
		if cgn then
			if found then
				-- if more than one instance is found, abort
				-- (since dont know how to differentiate between instances yet)
				debugLog("getServerGalaxyPath() -> multiple server instances found, cannot determine datapath", cmd)
				return nil
			else						
				local datapath 
				-- check if the "--datapath" parameter is defined or if using default directory
				local cdp = string.match(l, "%-%-datapath%s([^%s%c]+)")	
				if cdp then
					datapath = cdp
					if not string.ends(datapath, "/") then
						datapath = datapath .. "/"				
					end
				else
					datapath = getDefaultDataPath()
				end
				galaxypath = datapath .. cgn .. "/"
				found = true
			end
		end
    end	
    pfile:close()
	
	return galaxypath
	
end