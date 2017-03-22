--[[

FINDSTATION MOD

version: 0.5alpha
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
local searchstart


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
	
	-- obey max concurrent searches limit if set
	if myconfig.maxconcurrent > 0 then
		local searches = getConcurrentSearchesCount()
		debugLog("concurrent searches: %s", searches)
		if searches and searches >= myconfig.maxconcurrent then
			scriptLog(player, "search execution cancelled due to concurrent search limit reached (maxconcurrent: %s)", myconfig.maxconcurrent)
			player:sendChatMessage("findstation", 0, "Too many players searching! Please wait before trying again ...")
			return
		end
	end
	
	-- obey search delay if set	
	if myconfig.searchdelay > 0 then
		local currentsearch = math.floor(systemTime())
		local lastsearch = getPlayerLastSearchTime(player.index)
		debugLog("searchdelay: %s | lastsearch: %s", myconfig.searchdelay, lastsearch)
		if lastsearch and currentsearch < (lastsearch + myconfig.searchdelay) then
			local secsleft = (lastsearch + myconfig.searchdelay) - currentsearch
			scriptLog(player, "search execution cancelled due to search delay (searchdelay: %s, secsleft: %s)", myconfig.searchdelay, secsleft)
			player:sendChatMessage("findstation", 0, "Please wait %i second(s) before searching again ...", secsleft)
			return
		end
	end

	-- start of search
	scriptLog(player, "START SEARCH -> searchterm: %s | sectorloads: %s | maxresults: %s | sectorchecks: %s | galaxypath: %s",
			term, myconfig.framesectorloads, myconfig.maxresults, myconfig.framesectorchecks, myconfig.galaxypath)
	player:sendChatMessage("findstation", 0, "Searching for '%s' in known stations...", term)
	
	-- get coords for all existing sectors by checking galaxy files 
	local sectors = getExistingSectors(myconfig.galaxypath)
	--debugLog("sectors table:")
	--printTable(sectors)

	-- get players current sector
	local startsector = vec2(Sector():getCoordinates())
	
	-- init frame-based search in sectors
	secsearch = SectorsSearch(myconfig.galaxypath)
	secsearch:initBatchProcessing(term, sectors, myconfig.framesectorloads, myconfig.maxresults, startsector)
	
	-- add concurrent search info
	if myconfig.maxconcurrent and myconfig.maxconcurrent > 0 then
		searchstart = math.floor(systemTime())
		addConcurrentSearch(searchstart)
		debugLog("added concurrent search (searchstart: %s)", searchstart)
	end
	
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
		
	-- remove concurrent search info
	if myconfig.maxconcurrent and myconfig.maxconcurrent > 0 then
		removeConcurrentSearch(searchstart)
		debugLog("removed concurrent search (searchstart: %s)", searchstart)
	end
	
	-- apply search delay even in case of errors so these cannot be abused to spam
	if myconfig.searchdelay > 0 then
		setPlayerLastSearchTime(player.index)
	end
	
	local passedTime = secsearch.endTime - secsearch.startTime	
	
	if abortsearch then
		-- feedback for search abort
		scriptLog(Player(), "SEARCH ABORTED (%s ms, %s frames, %s checks, %s loads, read %s ms)", 
				passedTime, secsearch.total_batches, secsearch.total_sectorchecks, secsearch.total_sectorloads, secsearch.readTime)
	else
		local player = Player()
		
		-- success, show results by distance
		showResults(player, secsearch.resultsByDistance)
		
		-- feedback for search end
		scriptLog(Player(), "END SEARCH (%s results, %s ms, %s frames, %s checks, %s loads, read %s ms)", 
				secsearch.resultsCount, passedTime, secsearch.total_batches, secsearch.total_sectorchecks, secsearch.total_sectorloads, secsearch.readTime)		
		local passedsecs = passedTime / 1000
		player:sendChatMessage("findstation", 0, string.format("Search finished (%d results, %.1f seconds)", secsearch.resultsCount, passedsecs))
	end
	
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