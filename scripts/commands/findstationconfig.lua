package.path = package.path .. ";data/scripts/lib/?.lua"


function execute(sender, commandName, ...)
	local args = {...}	
	local player = Player(sender)	
	
	if #args > 0 and args[1] ~= "" then	
		local galaxyname = table.concat(args, " ")	
		
		local script = "cmd/findstation.lua"		
		if not player:hasScript(script) then
			player:addScriptOnce(script)
		end
		
		player:invokeFunction(script, "updateConfig", galaxyname)

	else
		player:sendChatMessage("findstation", 0, "Missing parameters! Use '/help findstationconfig' for information.")	
	end

    return 0, "", ""
end


function getDescription()
    return "Configuration helper for the /findstation command."
end


-- called by /help command
function getHelp()
    return [[
Configuration helper for the /findstation command.
Usage:
/findstationconfig <GALAXY>
Parameter:
<GALAXY> = name of currently loaded galaxy
]]
end
