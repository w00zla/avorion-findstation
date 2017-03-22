--[[

FINDSTATION MOD

version: alpha4
author: w00zla

file: player/findstation/searchcmd.lua
desc: player entity script for /findstation command

]]--

if onServer() then -- make this script run server-side only

package.path = package.path .. ";data/scripts/lib/?.lua"

require "utility"
require "stringutility"

require "findstation.common"

Config = require("findstation.config")
SectorsSearch = require("findstation.sectorssearch")


-- config
local myconfig

-- runtime vars
local secsearch
local dosearch
local searching
local abortsearch


function initialize()
	
	-- subscribe for callbacks
	Player():registerCallback("onSectorLeft", "onSectorLeft")

end


function onSectorLeft(playerIndex, x, y) 

	if searching then
		scriptLog(Player(), "cancelled search due to player jumping")
		Player():sendChatMessage("findstation", 0, "Search cancelled (player left sector)!")
		abortsearch = true
	end

end


function executeSearch(term)

	local player = Player()

	-- prevent parallel search requests	
	if searching then
		scriptLog(player, "parallel search execution cancelled")
		player:sendChatMessage("findstation", 0, "Search in progress ... please wait")
		return
	end
	dosearch = false
	
	-- get current configuration 
	myconfig = Config.getCurrent()
	if not myconfig.galaxypath or myconfig.galaxypath == "" then
		scriptLog(player, "ERROR -> no galaxypath configured!")
		player:sendChatMessage("findstation", 0, "No galaxy or galaxypath configured. Execute command /findstationconfig first!")
		return
	end

	-- start of search
	scriptLog(player, "START SEARCH -> searchterm: %s | sectorloads: %s | maxresults: %s | sectorchecks: %s | galaxypath: %s",
			term, myconfig.framesectorloads, myconfig.maxresults, myconfig.framesectorchecks, myconfig.galaxypath)
	player:sendChatMessage("findstation", 0, "Searching for '%s' in known stations...", term)
	
	local sectors = getExistingSectors(myconfig.galaxypath)
	--debugLog("sectors table:")
	--printTable(sectors)
	
	local startx, starty = Sector():getCoordinates()
	local startsector = { x=startx, y=starty }
	
	-- init frame-based search in sectors
	secsearch = SectorsSearch(myconfig.galaxypath)
	secsearch:initBatchProcessing(term, sectors, myconfig.framesectorloads, myconfig.maxresults, startsector)
	
	-- trigger start of frame-based search
	dosearch = true
	abortsearch = false
	
end


function updateServer(timeStep)

	-- just return if no search is pending
	if not dosearch then return end	
	searching = true
	
	if not abortsearch then
	
		-- search in batch of sectors per frame
		--local res = secsearch:continueBatchProcessing()
		local res = secsearch:continueBatchProcessing()
		
		if res == false then
			-- batch finished 
			return
		elseif res == nil then
			-- error
			scriptLog(Player(), "ERROR while processing sectors -> %s", secsearch.error)
			Player():sendChatMessage("findstation", 0, "Error: %s", secsearch.error)
			abortsearch = true
		end
		
	end
	
	dosearch = false
	searching = false

	-- show results and do final cleanup
	finishSearch()	
	
end


function finishSearch()
		
	local passedTime = secsearch.endTime - secsearch.startTime	
	
	if abortsearch then
		-- error while reading sector files
		scriptLog(Player(), "SEARCH ABORTED (%s ms, %s frames, %s checks, %s loads, read %s ms)", 
				passedTime, secsearch.total_batches, secsearch.total_sectorchecks, secsearch.total_sectorloads, secsearch.readTime)
	else
		local player = Player()
		-- success, show results by distance
		showResults(player, secsearch.resultsByDistance)
		
		scriptLog(Player(), "END SEARCH (%s results, %s ms, %s frames, %s checks, %s loads, read %s ms)", 
				secsearch.resultsCount, passedTime, secsearch.total_batches, secsearch.total_sectorchecks, secsearch.total_sectorloads, secsearch.readTime)
		
		local passedsecs = passedTime / 1000
		player:sendChatMessage("findstation", 0, string.format("Search finished (%d results, %.1f seconds)", secsearch.resultsCount, passedsecs))
	end
	
	secsearch = nil
	
	-- remove the script from the entity
	terminate()
end


function showResults(player, resultsByDistance)

	-- sort results table by key which contains distance, and show all results in chat window
	local i = 1
	for d, v1 in pairsByKeys(resultsByDistance) do
		for c, v2 in pairs(v1) do
			for _, v3 in pairs(v2) do
				if d == 0 then
					player:sendChatMessage("findstation", 0, string.format("- %s (current sector)", v3))
				else
					player:sendChatMessage("findstation", 0, string.format("- %s \\s(%s) distance: %i", v3, c, d))
				end
				if i >= myconfig.maxchatresults then
					break
				else				
					i = i + 1
				end
			end
			if i >= myconfig.maxchatresults then break end
		end
		if i >= myconfig.maxchatresults then break end
	end

end



end