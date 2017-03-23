--[[

FINDSTATION MOD
author: w00zla

file: entity/findstation/searchui.lua
desc: entity script providing a GUI window for search

]]--

package.path = package.path .. ";data/scripts/lib/?.lua"

require ("utility")
require "stringutility"

require "findstation.common"

Config = require("findstation.config")
SectorsSearch = require("findstation.sectorssearch")


-- client / UI vars

local mywindow
local ctls = {
	txtSearchTerm = nil,
	btnDoSearch = nil,
	lstResults = nil,
	lblInfo = nil,
	btnNextPage = nil,
	btnPrevPage = nil
}
local resultFrame = {}
local resultTitleLabel = {}
local resultCoordsLabel = {}
local resultDistLabel = {}
local resultButton = {}
local resultdata = {}
local pagenum = 1
local pagerows = 15

	
-- server/ search vars

local myconfig
local myplayerindex
local secsearch
local searchstart
local dosearch
local searching
local abortsearch
local uierror
local uiwarn
local resultsLocal = {}


function getIcon(seed, rarity)
    return "data/textures/icons/findstation/searchstation.png"
end


function interactionPossible(player)
    return true, ""
end


function onShowWindow()

	ctls.txtSearchTerm.text = ""
	ctls.txtSearchTerm.active = true
	ctls.btnDoSearch.active = true
	
	if #resultdata == 0 then
		ctls.btnPrevPage.active = false
		ctls.btnNextPage.active = false
	end
	
end


function onCloseWindow()

	if onClient() then
        invokeServerFunction("onCloseWindow")
        return
    end

    if searching then
		scriptLog(Player(), "cancelled search because UI window was closed")
		abortsearch = true
	end

end


function initUI()

    local size = vec2(600, 715)
    local res = getResolution()

	-- create window
    local menu = ScriptUI()
    mywindow = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    menu:registerWindow(mywindow, "Find Station")

    mywindow.caption = "Find Station"
    mywindow.showCloseButton = 1
    mywindow.moveable = 1
	
	local hsplit = UIVerticalSplitter(Rect(10, 10, size.x - 10, 50), 10, 0, 0.5)
	hsplit.rightSize = 240
	
	-- textbox for search term
	ctls.txtSearchTerm = mywindow:createTextBox(hsplit.left, "onSearchTermChanged")
	
	-- search button
	ctls.btnDoSearch = mywindow:createButton(hsplit.right, "Search", "onDoSearchPressed")
	
	-- info label
	ctls.lblInfo = mywindow:createLabel(vec2(15, 62), "", 15)
	ctls.lblInfo.caption = getModInfoLine()
	ctls.lblInfo.color = ColorRGB(0.2, 0.2, 0.2)
	
	ctls.pnlResults = mywindow:createContainer(Rect(10, 90, size.x - 10, size.y - 10))
	
	buildResultsUI(ctls.pnlResults, pagerows)

	scriptLog(nil, "search UI initialized successfully")
	
end


function buildResultsUI(parent, rowscount)

	local size = parent.size
	
	parent:createFrame(Rect(size))
		
    local titleLabelX = 10
    local coordLabelX = -170
	local distLabelX = -60
	
	-- footer
    ctls.btnPrevPage = parent:createButton(Rect(10, size.y - 40, 60, size.y - 10), "<", "onPrevPagePressed")	
    ctls.btnNextPage = parent:createButton(Rect(size.x - 60, size.y - 40, size.x - 10, size.y - 10), ">", "onNextPagePressed")	
	
	local y = 35
    for i = 1, rowscount do
	
		local yText = y + 6
		
		-- create controls for one result row
		
		local split1 = UIVerticalSplitter(Rect(10, y, size.x - 10, 30 + y), 10, 0, 0.5)
        split1.rightSize = 30

		local frame = parent:createFrame(split1.left)
		
		local xl = split1.left.lower.x
		local xu = split1.left.upper.x
		
		if i == 1 then
			-- header 
			parent:createLabel(vec2(xl + titleLabelX, 10), "Station", 14)
			parent:createLabel(vec2(xu + coordLabelX, 10), "Coord", 14)
			parent:createLabel(vec2(xu + distLabelX, 10), "Dist", 14)
		end
		
		local titleLabel = parent:createLabel(vec2(xl + titleLabelX, yText), "title", 15)
		local coordLabel = parent:createLabel(vec2(xu + coordLabelX, yText), "coord", 15)
		local distLabel = parent:createLabel(vec2(xu + distLabelX, yText), "dis", 15)
		
		titleLabel.font = "Arial"
        coordLabel.font = "Arial"
        distLabel.font = "Arial"
		
		local button = parent:createButton(split1.right, "", "onLookAtPressed")
		button.icon = "data/textures/icons/look-at.png"
		
		resultFrame[i] = frame
		resultTitleLabel[i] = titleLabel
		resultCoordsLabel[i] = coordLabel
		resultDistLabel[i] = distLabel
		resultButton[i] = button
		
		frame:hide()
		titleLabel:hide()
		coordLabel:hide()
		distLabel:hide()
		button:hide()
			
		y = y + 35	
	end

end


function refreshUI(term, resultsSector, resultsByDistance, searchtime)

	-- reset controls
	ctls.txtSearchTerm.text = ""
	ctls.txtSearchTerm.active = true
	ctls.btnDoSearch.active = true
	ctls.lblInfo.caption = ""
	ctls.lblInfo.color = ColorRGB(1, 1, 1)
		
	resultdata = {}
	local passedsecs = searchtime / 1000
	
	-- collect local sector results if available
	local i = 0
	for _, v in pairs(resultsSector) do
		i = i + 1
		resultdata[i] = {
			title = v.title,
			coords = vec2(Sector():getCoordinates()),
			entity = v.entity
		}	
	end

	-- sort results table by key which contains distance
	for d, v1 in pairsByKeys(resultsByDistance) do
		for c, v2 in pairs(v1) do
			for _, v3 in pairs(v2) do
				i = i + 1
				resultdata[i] = {
					title = v3,
					coords = vec2(string.match(c, "([%d%-]+):([%d%-]+)")),
					dist = d
				}					
			end
		end
	end
	
	if i > 0 then
		ctls.lblInfo.caption = string.format("%i results for \"%s\"  (%.1f seconds)", i, term, passedsecs)
		showResults()
	else
		ctls.lblInfo.caption = string.format("No results for \"%s\"  (%.1f seconds)", term, passedsecs)
	end
	
	-- set initial paging
	pagenum = 1
	ctls.btnPrevPage.active = false
	ctls.btnNextPage.active = (#resultdata > pagerows)

end


function refreshUIInfo(term, msg, msgtype)

	ctls.txtSearchTerm.text = ""
	ctls.txtSearchTerm.active = true
	ctls.btnDoSearch.active = true

	ctls.lblInfo.caption = msg
	if msgtype == "error" then
		ctls.lblInfo.color = ColorRGB(1, 0, 0)
	elseif msgtype == "warning" then
		ctls.lblInfo.color = ColorRGB(1, 0.5, 0)
	else
		ctls.lblInfo.color = ColorRGB(1, 1, 1)
	end
	
	scriptLog(nil, "SEARCH ABORTED -> term: %s | msg: %s | msgtype: %s", term, msg, msgtype)
	
end 


function onSearchTermChanged()
end


function onDoSearchPressed()
	
	ctls.lblInfo.color = ColorRGB(1, 1, 1)
	for i = 1, pagerows, 1 do
		resultFrame[i]:hide()
		resultTitleLabel[i]:hide()
		resultCoordsLabel[i]:hide()
		resultDistLabel[i]:hide()
		resultButton[i]:hide()
	end

	local term = ctls.txtSearchTerm.text
	if term and term ~= "" then
	
		ctls.txtSearchTerm.active = false
		ctls.btnDoSearch.active = false
		ctls.lblInfo.caption = "Searching..."
		
		scriptLog(nil, "START SEARCH -> term: %s", term)
		invokeServerFunction("executeSearch", Player().index, term)
	
	else	
		ctls.lblInfo.caption = "Please enter search term!"	
	end
	
end


function onLookAtPressed(sender)

	for i, button in pairs(resultButton) do
		if button.index == sender.index then
			local result = resultdata[((pagenum - 1) * pagerows) + i]
			
			if result.entity then
				Player().selectedObject = Entity(result.entity)
			else
				GalaxyMap():setSelectedCoordinates(result.coords.x, result.coords.y)
				GalaxyMap():show(result.coords.x, result.coords.y)
			end
			
		end
	end

end


function onPrevPagePressed()

	if pagenum > 1 then
		pagenum = pagenum - 1
	end
	
	if pagenum == 1 then
		ctls.btnPrevPage.active = false
		if #resultdata > pagerows then
			ctls.btnNextPage.active = true
		end
	end
	
	showResults(pagenum)
	
end


function onNextPagePressed()

	if (pagerows * pagenum) < #resultdata then
		pagenum = pagenum + 1
	end
	
	if pagenum > 1 then
		ctls.btnPrevPage.active = true
	end
	if (pagerows * pagenum) >= #resultdata then
		ctls.btnNextPage.active = false
	end
	
	showResults(pagenum)

end


function onSectorChanged()

	if onClient() then
        invokeServerFunction("onSectorChanged")
        return
    end

    if searching then
		scriptLog(Player(), "cancelled search due to player jumping")
		uiwarn = "Cancelled search because of jump!"
		abortsearch = true	
	end
	
end


function executeSearch(playerindex, term)

	myplayerindex = playerindex

	-- prevent parallel search requests	
	if searching then
		scriptLog(Player(), "parallel search execution cancelled")
		return
	end
	dosearch = false
		
	-- get current configuration 
	myconfig = Config.getCurrent()
	if not myconfig.galaxypath or myconfig.galaxypath == "" then
		scriptLog(Player(), "ERROR -> no galaxypath configured!")
		invokeClientFunction(Player(myplayerindex), "refreshUIInfo", term, "Error: no galaxy/galaxypath is configured!", "error")
		return
	end
	
	-- obey max concurrent searches limit if set
	if myconfig.maxconcurrent > 0 then
		local searches = getConcurrentSearchesCount()
		debugLog("concurrent searches: %s", searches)
		if searches and searches >= myconfig.maxconcurrent then
			scriptLog(Player(), "search execution cancelled due to concurrent search limit reached (maxconcurrent: %s)", myconfig.maxconcurrent)
			invokeClientFunction(Player(myplayerindex), "refreshUIInfo", term, "Too many players searching! Please wait before trying again ...", "warning")
			return
		end
	end
	
	-- obey search delay if set	
	if myconfig.searchdelay > 0 then
		local currentsearch = math.floor(systemTime())
		local lastsearch = getPlayerLastSearchTime(Player().index)
		debugLog("searchdelay: %s | lastsearch: %s", myconfig.searchdelay, lastsearch)
		if lastsearch and currentsearch < (lastsearch + myconfig.searchdelay) then
			local secsleft = (lastsearch + myconfig.searchdelay) - currentsearch
			scriptLog(Player(), "search execution cancelled due to search delay (searchdelay: %s, secsleft: %s)", myconfig.searchdelay, secsleft)
			invokeClientFunction(Player(myplayerindex), "refreshUIInfo", term, string.format("Please wait %i second(s) before searching again ...", secsleft), "warning")
			return
		end
	end

	-- start of search
	scriptLog(Player(), "START SEARCH -> searchterm: %s | sectorloads: %s | maxresults: %s | galaxypath: %s",
			term, myconfig.framesectorloads, myconfig.maxresults, myconfig.galaxypath)
			
	-- search current sector via API first (to get entity indices)
	resultsLocal = searchCurrentSectorStations(term)
	
	-- get players current sector
	local startsector = vec2(Sector():getCoordinates())
	
	local sectors = nil
	local calltime = systemTimeMs()

	if myconfig.searchmode == "galaxy" then
		-- get coords for all existing sectors by checking their XML files 		
		sectors = getExistingSectors(myconfig.galaxypath, startsector)
		debugLog("getExistingSectors() time: %s ms", (systemTimeMs() - calltime))
	else
		-- get coords for all player discovered sectors by parsing the player-dat file
		sectors = getPlayerKnownLocations(myconfig.galaxypath, Player(), startsector)
		debugLog("getPlayerKnownLocations() time: %s ms", (systemTimeMs() - calltime))
	end
	
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
			uierror = string.format("Error: %s", secsearch.error)
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
		setPlayerLastSearchTime(Player().index)
	end
		
	local passedTime = secsearch.endTime - secsearch.startTime	
	
	if abortsearch then
		-- error while reading sector files
		scriptLog(Player(), "SEARCH ABORTED (%s ms, %s frames, %s checks, %s loads, read %s ms)", 
				passedTime, secsearch.total_batches, secsearch.total_sectorchecks, secsearch.total_sectorloads, secsearch.readTime)
	
		if uierror then
			invokeClientFunction(Player(myplayerindex), "refreshUIInfo", secsearch.searchterm, uierror, "error")
		elseif uiwarn then
			invokeClientFunction(Player(myplayerindex), "refreshUIInfo", secsearch.searchterm, uiwarn, "warning")
		end
	else
		-- success, show results by distance
		scriptLog(Player(), "END SEARCH (%s results, %s ms, %s frames, %s checks, %s loads, read %s ms)", 
				secsearch.resultsCount, passedTime, secsearch.total_batches, secsearch.total_sectorchecks, secsearch.total_sectorloads, secsearch.readTime)
		
		invokeClientFunction(Player(myplayerindex), "refreshUI", secsearch.searchterm, resultsLocal, secsearch.resultsByDistance, passedTime)		
	end
	
	secsearch = nil
	resultsLocal = nil
	uierror = nil

end


function showResults()

	local baseidx = (pagerows * (pagenum - 1)) + 1
	local upperidx = pagerows * pagenum
	local ctlidx = 1
	for i = baseidx, upperidx, 1 do
	
		if resultdata[i] then
			
			resultTitleLabel[ctlidx].caption = resultdata[i].title
			resultCoordsLabel[ctlidx].caption = tostring(resultdata[i].coords)
			if resultdata[i].entity then
				resultDistLabel[ctlidx].caption = "-"
			else
				resultDistLabel[ctlidx].caption = math.ceil(resultdata[i].dist)
			end			
		
			resultFrame[ctlidx]:show()
			resultTitleLabel[ctlidx]:show()
			resultCoordsLabel[ctlidx]:show()
			resultDistLabel[ctlidx]:show()
			resultButton[ctlidx]:show()
		else
			resultFrame[ctlidx]:hide()
			resultTitleLabel[ctlidx]:hide()
			resultCoordsLabel[ctlidx]:hide()
			resultDistLabel[ctlidx]:hide()
			resultButton[ctlidx]:hide()
		end
		
		ctlidx = ctlidx + 1
	end

end