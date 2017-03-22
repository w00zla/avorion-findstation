--[[

FINDSTATION MOD

version: alpha4
author: w00zla

file: player/findstation/uiloader.lua
desc:  player script for managing entity UI scripts

]]--

package.path = package.path .. ";data/scripts/lib/?.lua"

require ("utility")
require "stringutility"

require "findstation.common"

 
local lastCraft


function initialize()

	-- subscribe to event callbacks
	Player():registerCallback("onShipChanged", "onShipChanged")	
	
	addShipScript(fs_searchui) 
	
end


function onShipChanged(playerIndex, craftIndex)

	-- remove and add script to ship entities
	removeEntityScript(lastCraft, fs_searchui)	
	addShipScript(fs_searchui)	

end


function addShipScript(script) 

	-- add script to current ship entity
	if Player().craftIndex and Player().craftIndex > 0 then
		local entity = Entity(Player().craftIndex)
		if entity then
			ensureEntityScript(entity, script)
			lastCraft = entity.index	
		end
	end

end


function removeScripts()

	-- remove scripts from all ship entities
	local currentCraft = Player().craftIndex
	removeEntityScript(currentCraft, fs_searchui)
	
	if lastCraft ~= currentCraft then
		removeEntityScript(lastCraft, fs_searchui)
	end

	-- unsubscribe from event callbacks
	Player():unregisterCallback("onShipChanged", "onShipChanged")

	-- kill and remove script from entity
	terminate()
	
end
