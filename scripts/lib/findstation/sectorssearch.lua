--[[

FINDSTATION MOD

version: 0.5alpha
author: w00zla

file: lib/findstation/sectorssearch.lua
desc: class for searches in sector XML files

]]--

package.path = package.path .. ";data/scripts/lib/?.lua"

require ("utility")
require ("stringutility")

require "findstation.common"
require "findstation.sectorxml"


local SectorsSearch = {}
SectorsSearch.__index = SectorsSearch


local function new(galaxypath)

	local obj = setmetatable({}, SectorsSearch)

    obj:initialize(galaxypath)

    return obj
end


function SectorsSearch:initialize(galaxypath)

	-- configs
	self.galaxypath = galaxypath
	
	-- runtime vars
	self.searchterm = ""
	self.batchloads = 0
	self.resultlimit = 0
	self.resultsCount = 0
	self.resultsByDistance = {}
	
end


function SectorsSearch:initSearchExecution()

	-- reset runtime and diagnostic vars
	self.resultsCount = 0
	self.resultsByDistance = {}
	self.error = nil
	
	self.readTime = 0
	self.total_sectorchecks = 0
	self.total_sectorloads = 0	
	self.total_batches = 0	
	
	self.startTime = 0
	self.endTime = 0

end


function SectorsSearch:initBatchProcessing(searchterm, sectors, batchloads, resultlimit, startsector)

	-- set search parameters
	self.searchterm = searchterm
	self.batchloads = batchloads
	self.resultlimit = resultlimit
	
	-- general search init
	self:initSearchExecution()
	
	-- sort target sectors by distance	
	self.sectors = sortSectorsByDistance(sectors, startsector)
	
end


function SectorsSearch:continueBatchProcessing()

	if self.startTime == 0 then
		self.startTime = systemTimeMs()
	end
	
	self.total_batches = self.total_batches + 1
	local sectorloads_last = self.total_sectorloads

	while self.sectors and #self.sectors > 0 do
	
		local sec = self.sectors[1]
		self:processSector(sec.x, sec.y)
		if self.error then return end
	
		table.remove(self.sectors, 1)
		
		-- defer processing to next frame if any per-frame limit hits
		if self.batchloads > 0 and 
			(self.total_sectorloads - sectorloads_last) >= self.batchloads then 
			return false 
		end
		if self.resultlimit > 0 and 
			self.resultsCount >= self.resultlimit then 
			break
		end
		
	end

	self.endTime = systemTimeMs()
		
	return true

end


function SectorsSearch:processSector(x, y)

	self.total_sectorchecks = self.total_sectorchecks + 1
	--debugLog("checked sector (%s:%s)", x, y)
	if not Galaxy():sectorExists(x, y) then return end
	
	-- read sector file and search its XML for term
	self.total_sectorloads = self.total_sectorloads + 1	
	local numresults = self:searchSectorFile(x, y)
	--debugLog("loaded sector (%s:%s) -> results: %s", x, y, numresults)
	
	if numresults then
		self.resultsCount = self.resultsCount + numresults	
		return numresults
	else
		numresults = 0
	end

	return numresults
	
end


function SectorsSearch:searchSectorFile(x, y)
		
	-- read sector file from disk and parse its XML
	local sectorFile = string.format("%s_%sv", x, y)
	local sectorFilePath = self.galaxypath .. "sectors/" .. sectorFile
	
	--debugLog("sector (%s:%s) exists, reading file '%s'", x, y, sectorFilePath)
	local startRead = systemTimeMs()
	local sectorXml, err = readSectorFile(sectorFilePath)
	self.readTime = self.readTime + (systemTimeMs() - startRead)
	
	if not sectorXml then
		scriptLog(Player(), "ERROR: XML for sector (%s:%s) could not be retrieved! Message: %s", x, y, err)
		if err then
			self.error = err
		else
			self.error = string.format("XML for sector (%s:%s) could not be retrieved!", x, y)
		end
		return 
	end
	
	-- search XML for stations with given term in title
	local results = searchSectorStations(sectorXml, self.searchterm)
	
	-- save results based on distance and coordinates
	if results and #results > 0 then	
		local coords = string.format("%i:%i", x, y) 
		local dist = getCurrentCoordsDistance(x, y)
		if not self.resultsByDistance[dist] then
			self.resultsByDistance[dist] = {}
		end
		self.resultsByDistance[dist][coords] = results
		
		return #results
	end
	
end


return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})

