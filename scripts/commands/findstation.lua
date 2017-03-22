--[[

FINDSTATION MOD

version: alpha3
author: w00zla

file: commands/findstation.lua
desc: auto-included script to implement custom command /findstation

]]--

package.path = package.path .. ";data/scripts/lib/?.lua"

require "findstation.common"


local playerscript = "cmd/findstation.lua"


function execute(sender, commandName, ...)
	local args = {...}	
	local player = Player(sender)	

	if #args > 0 and args[1] ~= "" then	
		local searchterm = table.concat(args, " ")	

		-- make sure entity scripts are present
		ensureEntityScript(player, playerscript)

		-- call entity function to start search
		player:invokeFunction(playerscript, "executeSearch", searchterm)
		
	else
		player:sendChatMessage("findstation", 0, "Missing parameters! Use '/help findstation' for information.")
	end

    return 0, "", ""
end


function getDescription()
    return "Find stations in any of the found sectors in the galaxy."
end


-- called by /help command
function getHelp()
    return [[
Find stations in any of the found sectors in the galaxy.
Usage:
/findstation <SEARCHTERM>
Parameter:
<SEARCHTERM> = term to search in station names (spaces possible, case-insensitive)
]]
end

