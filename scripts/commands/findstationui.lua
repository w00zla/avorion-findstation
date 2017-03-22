--[[

FINDSTATION MOD

version: 0.5alpha
author: w00zla

file: commands/findstationui.lua
desc: auto-included script to implement custom command /findstationui

]]--


package.path = package.path .. ";data/scripts/lib/?.lua"

require "findstation.common"


function execute(sender, commandName, ...)
	local args = {...}	
	local player = Player(sender)	

	if #args == 0 or args[1] == "enable" then	
	
		-- make sure entity scripts are present
		ensureEntityScript(player, fs_uiloader)
		scriptLog(player, "search UI script-loader was attached to player entity")
		player:sendChatMessage("findstation", 0, "Search UI enabled")
		
	elseif args[1] == "disable" then
		
		if player:hasScript(fs_uiloader) then
			player:invokeFunction(fs_uiloader, "removeScripts")		
			scriptLog(player, "search UI script-loader was removed from player entity")
		end	
		
		player:sendChatMessage("findstation", 0, "Search UI disabled")
		
	else
		player:sendChatMessage("findstation", 0, "Missing parameters! Use '/help findstationui' for information.")
	end

    return 0, "", ""
end


function getDescription()
    return "Enables/disables the UI (menu item & window) for station search."
end


-- called by /help command
function getHelp()
    return [[
Enables/disables the UI (menu item & window) for station search.
Usage:
/findstationui
/findstationui enable
/findstationui disable
]]
end


