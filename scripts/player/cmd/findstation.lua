--[[

FINDSTATION MOD

version: alpha2
author: w00zla

file: player/cmd/findstation.lua
desc: player entity script for /findstation command

]]--

if onServer() then -- make this script run server-side only

package.path = package.path .. ";data/scripts/lib/?.lua"

require "stringutility"
require "utility"

require "cmd.findstationcommon"
require "cmd.findstationxml"


-- constants / defaults
local default_framesectorchecks = 2000
local default_framesectorloads = 10
local default_maxchatresults = 18 

-- configs
local galaxypath
local framesectorchecks
local framesectorloads
local maxchatresults

-- runtime vars
local searchterm
local resultsByDistance
local resultscount
local dosearch
local searching
local sectorError
local lastX
local lastY

-- diag vars
local startTime
local readTime
local total_sectorchecks
local total_sectorloads
local total_frames


function initialize()

	-- init static settings
	maxchatresults = default_maxchatresults
	
	-- subscribe for callbacks
	Player():registerCallback("onSectorLeft", "onSectorLeft")

end


function executeSearch(term)

	local player = Player()

	-- prevent parallel search requests	
	if searching then
		print("SCRIPT findstation => parallel search execution cancelled")
		player:sendChatMessage("findstation", 0, "Search in progress ... please wait")
		return
	end
	dosearch = false
	
	-- get basic config
	galaxypath = loadConfigValue("galaxypath")
	if not galaxypath or galaxypath == "" then
		print("SCRIPT findstation => ERROR -> no galaxypath configured!")
		player:sendChatMessage("findstation", 0, "No galaxy or galaxypath configured. Execute command /findstationconfig first!")
		return
	end
	
	-- get additional config
	framesectorchecks = tonumber(loadConfigValue("framesectorchecks", default_framesectorchecks))
	framesectorloads = tonumber(loadConfigValue("framesectorloads", default_framesectorloads))
	
	-- feedback for start of search
	searchterm = term
	startTime = systemTimeMs()
	print(string.format("SCRIPT findstation => START SEARCH -> searchterm: %s | framesectorchecks: %s | framesectorloads: %s | galaxypath: %s", searchterm, framesectorchecks, framesectorloads, galaxypath))
	player:sendChatMessage("findstation", 0, string.format("Searching for '%s' in known stations...", searchterm))

	-- reset runtime and diagnostic vars
	resultscount = 0
	resultsByDistance = {}
	
	total_sectorchecks = 0
	total_sectorloads = 0
	total_frames = 0
	readTime = 0
	
	-- trigger start of search
	dosearch = true
	
end


function onSectorLeft(playerIndex, x, y) 

	if searching then
		print("SCRIPT findstation => cancelled search due to player jumping")
		Player():sendChatMessage("findstation", 0, "Search cancelled (player left sector)!")
		sectorError = true
	end

end


function updateServer(timeStep)

	-- just return if no search is pending
	if not dosearch then return end	
	searching = true
	
	total_frames = total_frames + 1
	local sectorchecks_last = total_sectorchecks
	local sectorloads_last = total_sectorloads
	
	-- do simple "bottom-top" search through all possible sectors
	local x = -499
	if lastX then x = lastX	
	else lastX = x end
	local y = -499
	if lastY then y = lastY	
	else lastY = y end

	-- start/continue processing sectors from initial/last state
	while x <= 500 do
	
		processSector(x, y)
		if sectorError then break end
		
		if y < 500 then
			y = y + 1
			lastY = y
		else
			y = -499
			lastY = nil
			x = x + 1
			lastX = x	
		end
	
		-- defer processing to next frame if any per-frame limit hits
		if (total_sectorchecks - sectorchecks_last) >= framesectorchecks then return end
		if (total_sectorloads - sectorloads_last) >= framesectorloads then return end
	end	

	-- reset search states
	lastX = nil
	lastY = nil
	dosearch = false
	searching = false
	
	-- show results and do final cleanup
	finishSearch()	
end


function processSector(x, y)

	total_sectorchecks = total_sectorchecks + 1
	--print(string.format("DEBUG findstation => checked sector (%s:%s)", x, y))
	
	if Galaxy():sectorExists(x, y) then
	
		-- read sector file and search its XML for term
		total_sectorloads = total_sectorloads + 1	
		local numresults = searchSectorFile(x, y)
		--print(string.format("DEBUG findstation => loaded sector (%s:%s) -> results: %s", x, y, numresults))
		
		if numresults then
			resultscount = resultscount + numresults	
			return numresults
		else
			return 0
		end
	end

end


function searchSectorFile(x, y)
		
	-- read sector file from disk and parse its XML
	local sectorFile = string.format("%s_%sv", x, y)
	local sectorFilePath = galaxypath .. "sectors\\" .. sectorFile
	
	--print(string.format("DEBUG findstation => sector (%s:%s) exists, reading file '%s'", x, y, sectorFilePath))
	local startRead = systemTimeMs()
	local sectorXml = readSectorFile(sectorFilePath)
	readTime = readTime + (systemTimeMs() - startRead)
	
	if not sectorXml then
		print(string.format("SCRIPT findstation => ERROR -> could not open or parse XML file for sector (%s:%s)", x, y))
		Player():sendChatMessage("findstation", 0, "Error: could not read file for sector \\s(%s:%s)! Is configured galaxy/galaxypath correct?", x, y)
		sectorError = true
		return 
	end
	
	-- search XML for stations with given term in title
	local results = searchSectorStations(sectorXml, searchterm)
	
	-- save results based on distance and coordinates
	if results and #results > 0 then	
		local coords = string.format("(%i:%i)", x, y) 
		local dist = getCurrentCoordsDistance(x, y)
		if not resultsByDistance[dist] then
			resultsByDistance[dist] = {}
		end
		resultsByDistance[dist][coords] = results
		
		return #results
	end
	
end


function finishSearch()
		
	local passedTime = systemTimeMs() - startTime	
	
	if sectorError then
		-- error while reading sector files
		print(string.format("SCRIPT findstation => SEARCH ABORTED (%s ms, frames %s, loads %s, checks %s, xml %s ms)", passedTime, total_frames, total_sectorloads, total_sectorchecks, readTime))
	else
		local player = Player()
		-- success, show results by distance
		showResults(player, resultsByDistance)
		
		print(string.format("SCRIPT findstation => END SEARCH (%s results, %s ms, %s frames, %s loads, %s checks, read %s ms)", resultscount, passedTime, total_frames, total_sectorloads, total_sectorchecks, readTime))
		--player:sendChatMessage("findstation", 0, string.format("Search done (%d results, %d ms, %d frames, %d loads, %d checks, read %d ms)", resultscount, passedTime, total_frames, total_sectorloads, total_sectorchecks, readTime))
		local passedsecs = passedTime / 1000
		player:sendChatMessage("findstation", 0, string.format("Search finished (%d results, %.1f seconds)", resultscount, passedsecs))
	end
	
	-- clear all search related variables
	startTime = nil
	readTime = nil
	total_sectorchecks = nil
	total_sectorloads = nil
	total_frames = nil
	searchterm = nil
	resultsByDistance = nil
	resultscount = nil
	sectorError = nil
	
end


function showResults(player, resultsByDistance)

	-- sort results table by key which contains distance, and show all results in chat window
	local i = 1
	for d, v1 in pairsByKeys(resultsByDistance) do
		for c, v2 in pairs(v1) do
			for _, v3 in pairs(v2) do
				player:sendChatMessage("findstation", 0, string.format("- %s \\s%s distance: %i", v3, c, d))
				if i >= maxchatresults then
					break
				else				
					i = i + 1
				end
			end
			if i >= maxchatresults then break end
		end
		if i >= maxchatresults then break end
	end

end



end