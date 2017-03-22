package.path = package.path .. ";data/scripts/lib/?.lua"


function execute(sender, commandName, ...)
	local args = {...}	
	local player = Player(sender)	

	if #args > 0 and args[1] ~= "" then	
		local searchterm = table.concat(args, " ")	

		local script = "cmd/findstation.lua"
		if not player:hasScript(script) then
			player:sendChatMessage("findstation", 0, "Execute command /findstationconfig first!")
			return
		end

		player:invokeFunction(script, "executeSearch", searchterm)
		
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

