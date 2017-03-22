if onServer() then -- make this script run server-side only

package.path = package.path .. ";data/scripts/lib/?.lua"

require "utility"
require "xml"


local currentgalaxy
local resultlimitchat


function initialize()

	resultlimitchat = 18
	-- get config from server entity
	currentgalaxy = Server():getValue("findstation_galaxy")

end


--[[function secure()

	print("DEBUG findstation => secure() called")
	return currentgalaxy
	
end]]--


--[[function restore(galaxyname)

	print("DEBUG findstation => restore() called")
	currentgalaxy = galaxyname
	
end]]--


function updateConfig(galaxyname)

	currentgalaxy = galaxyname
	-- save config to server entity since restore() does not work!
	Server():setValue("findstation_galaxy", currentgalaxy)
	print(string.format("DEBUG findstation => CONFIG updated -> currentgalaxy: %s", currentgalaxy))
	Player():sendChatMessage("findstation", 0, "Configuration updated")
	
end


function executeSearch(searchterm)

	local player = Player()
	
	-- check required vars for target folder 
	local appdatapath = os.getenv("APPDATA")
	if not appdatapath or appdatapath == "" then
		print("DEBUG findstation => ERROR -> no appdatapath available")
		player:sendChatMessage("findstation", 0, "Error: no appdatapath available!")
		return
	end	
	if not currentgalaxy or currentgalaxy == "" then
		print("DEBUG findstation => ERROR -> no galaxy configured")
		player:sendChatMessage("findstation", 0, "Error: no galaxy configured!")
		return
	end
	
	local startTime = systemTimeMs()
	print(string.format("DEBUG findstation => START SEARCH -> searchterm: %s | currentgalaxy: %s | appdatapath: %s", searchterm, currentgalaxy, appdatapath))
	player:sendChatMessage("findstation", 0, string.format("Searching for '%s' in known stations...", searchterm))

	local sectorsPath = appdatapath .. "\\Avorion\\galaxies\\" .. currentgalaxy .. "\\sectors\\"	
	local resultsByDistance = {}
	
	-- gather results of stations in created/existing sectors
	local sectorError
	for x = -499, 500, 1 do
		for y = -499, 500, 1 do
			if Galaxy():sectorExists(x, y) then
			
				local sectorFile = string.format("%s_%sv", x, y)
				local sectorFilePath = sectorsPath .. sectorFile
				--print(string.format("DEBUG findstation => sector (%s:%s) exists, reading file '%s'", x, y, sectorFilePath))
				local sectorXml = readSectorFile(sectorFilePath)
				if not sectorXml then
					print(string.format("DEBUG findstation => ERROR -> could not open or parse XML file for sector (%s:%s)", x, y))
					player:sendChatMessage(string.format("findstation", 0, "Error: could not read file for sector \\s(%s:%s)!", x, y))
					sectorError = true
					break
				end
				local results = searchSectorStations(sectorXml, searchterm)
				
				if results and #results > 0 then	
					local coords = string.format("(%i:%i)", x, y) 
					local dist = getCurrentCoordsDistance(x, y)
					if not resultsByDistance[dist] then
						resultsByDistance[dist] = {}
					end
					resultsByDistance[dist][coords] = results
					
					--print(string.format("DEBUG findstation => sector (%s:%s) has results (distance=%i):", x, y, dist))					
					--for _, v in pairs(results) do
					--	print(string.format("DEBUG findstation => -- %s", v))							
					--end
				end
								
			end
		end
		if sectorError then break end
	end
	
	if sectorError then
		-- error while reading sector files
		print("DEBUG findstation => END SEARCH (aborted with errors)")
	else
		-- success, show results by distance
		showResults(player, resultsByDistance)
		
		local passedTime = systemTimeMs() - startTime	
		print(string.format("DEBUG findstation => END SEARCH (done in %d ms)", passedTime))
		player:sendChatMessage("findstation", 0, string.format("Search done (%d ms)", passedTime))
	end
			
end


function showResults(player, resultsByDistance)

	-- sort results table by key which contains distance, and show all results in chat window
	local i = 1
	for d, v1 in pairsByKeys(resultsByDistance) do
		for c, v2 in pairs(v1) do
			for _, v3 in pairs(v2) do
				player:sendChatMessage("findstation", 0, string.format("- %s \\s%s distance: %i", v3, c, d))
				if i >= resultlimitchat then
					break
				else				
					i = i + 1
				end
			end
			if i >= resultlimitchat then break end
		end
		if i >= resultlimitchat then break end
	end

end


function searchSectorStations(xmlView, term)

	local xmlTitles = findTableByLabel(xmlView, "titles")
	
	if xmlView.xarg.numStations == 0 or xmlTitles.empty then
		--print("DEBUG findstation => no stations available in sector")
		return
	end
	
	local results = {}
	
	--print("DEBUG findstation => found stations:")
	for _, v in pairs(xmlTitles) do	
		if type(v) == "table" and v.xarg then
			local xmlTitle = v
			local stationstr = xmlTitle.xarg.str
			stationstr = resolveTitleTokens(stationstr, xmlTitle)
			--print(string.format("DEBUG findstation => -- %s", stationstr))
			
			-- do a case-insensitive search for the given term
			if string.find(stationstr:lower(), term:lower(), 1, true) then
				table.insert(results, stationstr)
			end
		end
	end

	return results
	
end


function resolveTitleTokens(str, xmlTitle)

	local result = str
	for t in string.gmatch(str, "${(%w+)}") do
		local tval = t
		for _, v in pairs(xmlTitle) do
			if type(v) == "table" and v.xarg and v.xarg.key == t then
				tval = v[1]			
			end
		end
		result = string.gsub(result, string.format("${%s}", t), tval)
    end

	return result
end


-- searches recursively for a (inner) table with key "label" and given value
function findTableByLabel(xmlTable, label)

	if xmlTable.label and xmlTable.label == label then
		return xmlTable
	end

	for k, v in pairs(xmlTable) do
		if type(v) == "table" then
			local result = findTableByLabel(v, label)
			if result then
				return result
			end
		end
	end

end


-- read sector XML file and parse XML into table tree-like structure
function readSectorFile(path)
	local sectorFile, err = io.open(path)
	if err then
		print(string.format("DEBUG findstation => ERROR on opening file '%s': %s'", path, err))
		return
	end
	
	local xmlString = sectorFile:read("*a")
	sectorFile:close()
	local xmlTable = collect(xmlString)
	
	--print(string.format("DEBUG findstation => XML table for file '%s':", path))
	--printTable(xmlTable)
	
	return xmlTable[2] -- removes the xml declaration item, returns only the "view" element
end


function getCurrentCoordsDistance(x, y)

	local vecSector = vec2(Sector():getCoordinates())
	local vecCoords = vec2(x, y)
	local dist = distance(vecSector, vecCoords)

	return dist

end


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


end