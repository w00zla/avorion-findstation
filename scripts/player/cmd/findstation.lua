--[[

FINDSTATION MOD

version: alpha3
author: w00zla

file: player/cmd/findstation.lua
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
local dosearch
local searching
local secsearch
local abortsearch


function initialize()
	
	-- subscribe for callbacks
	Player():registerCallback("onSectorLeft", "onSectorLeft")

end


function onSectorLeft(playerIndex, x, y) 

	if searching then
		print("SCRIPT findstation => cancelled search due to player jumping")
		Player():sendChatMessage("findstation", 0, "Search cancelled (player left sector)!")
		abortsearch = true
	end

end


function getConfig()

	local cfg = {
		galaxypath = Config.loadValue("galaxypath"),
		framesectorchecks = tonumber(Config.loadValue("framesectorchecks")),
		framesectorloads = tonumber(Config.loadValue("framesectorloads")),
		maxchatresults = tonumber(Config.loadValue("maxchatresults")),
		maxresults = tonumber(Config.loadValue("maxresults"))
	}

	if not cfg.galaxypath or cfg.galaxypath == "" then
		print("SCRIPT findstation => ERROR -> no galaxypath configured!")
		player:sendChatMessage("findstation", 0, "No galaxy or galaxypath configured. Execute command /findstationconfig first!")
		return
	end
	
	return cfg
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
	
	-- get current configuration 
	myconfig = getConfig()
	if not myconfig then return end

	-- init start of search
	print(string.format("SCRIPT findstation => START SEARCH -> searchterm: %s | sectorloads: %s | maxresults: %s | sectorchecks: %s | galaxypath: %s",
			term, myconfig.framesectorloads, myconfig.maxresults, myconfig.framesectorchecks, myconfig.galaxypath))
	player:sendChatMessage("findstation", 0, string.format("Searching for '%s' in known stations...", term))
	
	secsearch = SectorsSearch(myconfig.galaxypath)
	--secsearch:initBTBatchProcessing(term, myconfig.framesectorchecks, myconfig.framesectorloads)
	
	local sectors = getExistingSectors(myconfig.galaxypath)
	--print("DEBUG findstation => sectors table:")
	--printTable(sectors)
	
	local startx, starty = Sector():getCoordinates()
	local startsector = { x=startx, y=starty }
	
	secsearch:initBatchProcessing(term, sectors, myconfig.framesectorloads, myconfig.maxresults, startsector)
	
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
			print(string.format("SCRIPT findstation => ERROR while processing sectors -> %s", secsearch.error))
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
		print(string.format("SCRIPT findstation => SEARCH ABORTED (%s ms, frames %s, loads %s, checks %s, xml %s ms)", 
				passedTime, secsearch.total_batches, secsearch.total_sectorloads, secsearch.total_sectorchecks, secsearch.readTime))
	else
		local player = Player()
		-- success, show results by distance
		showResults(player, secsearch.resultsByDistance)
		
		print(string.format("SCRIPT findstation => END SEARCH (%s results, %s ms, %s frames, %s loads, %s checks, read %s ms)", 
				secsearch.resultsCount, passedTime, secsearch.total_batches, secsearch.total_sectorloads, secsearch.total_sectorchecks, secsearch.readTime))
		
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
				player:sendChatMessage("findstation", 0, string.format("- %s \\s%s distance: %i", v3, c, d))
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