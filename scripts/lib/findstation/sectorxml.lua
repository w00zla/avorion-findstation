--[[

FINDSTATION MOD
author: w00zla

file: lib/findstation/sectorxml.lua
desc: library script for reading sector files and parse the XML

]]--

package.path = package.path .. ";data/scripts/lib/?.lua"

-- include libraries
require "utility"
require "xml"


-- read sector XML file and parse XML into table tree-like structure
function readSectorFile(path)

	local sectorFile, err = io.open(path)
	if err then
		return nil, err
	end
	
	local xmlString = sectorFile:read("*a")
	sectorFile:close()
	
	local xmlTable = collect(xmlString)
	
	--debugLog("XML table for file '%s':", path)
	--printTable(xmlTable)
	
	return xmlTable[2] -- removes the xml declaration item, returns only the "view" element
end


-- search station titles in sector XML
function searchSectorStations(xmlView, term)

	-- get "titles" element
	local xmlTitles = findTableByLabel(xmlView, "titles")
	
	if xmlView.xarg.numStations == 0 or xmlTitles.empty then
		--debugLog("no stations available in sector!")
		return
	end
	
	local results = {}
	
	--debugLog("found stations:")
	for _, v in pairs(xmlTitles) do	
		if type(v) == "table" and v.xarg then
			local xmlTitle = v
			local stationstr = xmlTitle.xarg.str
			stationstr = resolveTitleTokens(stationstr, xmlTitle)
			--debugLog("-- %s", stationstr)
			
			-- do a case-insensitive search for the given term
			if string.find(stationstr:lower(), term:lower(), 1, true) then
				table.insert(results, stationstr)
			end
		end
	end

	return results
	
end


-- get "real" station title from tokenized title
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


-- searches recursively for a table with key "label" and given value
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