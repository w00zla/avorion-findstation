--[[

FINDSTATION MOD
author: w00zla

file: commands/findstationconfig.lua
desc: auto-included script to implement custom command /findstationconfig

]]--


package.path = package.path .. ";data/scripts/lib/?.lua"

require "findstation.common"
Config = require("findstation.config")


function execute(sender, commandName, ...)
	local args = {...}	
	local player = Player(sender)	
	
	if #args > 0 and args[1] ~= "" then	
		-- parse command args
		local configkey = string.lower(args[1])
		local configval = table.concat(args, " ", 2)	
		
		-- validate and save config option
		updateConfig(player, configkey, configval)

	else
		player:sendChatMessage("findstation", 0, "Missing parameters! Use '/help findstationconfig' for information.")	
	end

    return 0, "", ""
end


function updateConfig(player, configkey, configval)

	-- validate configuration options and values
	
	local valid = false
	local paramtype = ""
	local config = configkey
	
	if configkey == "galaxy" then
		configval = validateParameter(configval, "Name")
		if configval then
			local datapath = getDefaultDataPath()
			if not datapath then
				scriptLog(player, "ERROR: unable to determine default datapath!")
				player:sendChatMessage("findstation", 0, "Error: unable to determine default datapath!")
			end
			configkey = "galaxypath"
			galaxyname = configval
			configval = datapath .. configval .. "/"
			if not checkFileExists(configval .. "server.ini") then
				player:sendChatMessage("findstation", 0, "Error: Unable to find directory for galaxy '%s'!", galaxyname)
				return
			end
			valid = true
		end
	elseif configkey == "galaxypath" then
		configval = validateParameter(configval, "path")
		if configval then
			if not checkFileExists(configval .. "server.ini") then
				player:sendChatMessage("findstation", 0, "Error: Path '%s' is not a valid galaxy directory ('server.ini' file not found)!", configval)
				return
			end
			valid = true
		end
	elseif configkey == "searchmode" then
		configval = validateParameter(configval, "mode")
		if configval then
			configval = configval:lower()
			if configval ~= "player" and configval ~= "galaxy" then
				player:sendChatMessage("findstation", 0, "Error: Invalid search mode (use 'player' or 'galaxy')!")
				return
			end
			valid = true
		end
	elseif configkey == "framesectorloads" then
		configval = validateParameter(configval, "pnum")
		if configval then valid = true end
	elseif configkey == "maxresults" then
		configval = validateParameter(configval, "pnum")
		if configval then valid = true end
	elseif configkey == "maxconcurrent" then
		configval = validateParameter(configval, "pnum")
		if configval then valid = true end
	elseif configkey == "searchdelay" then
		configval = validateParameter(configval, "pnum")
		if configval then valid = true end
	else
		-- unknown config
		scriptLog(player, "unknown configuration (key: %s | val: %s)", configkey, configval)
		player:sendChatMessage("findstation", 0, "Error: Unknown configuration '%s'!", configkey)
		return
	end
	
	if valid then
		-- valid update -> save config
		Config.saveValue(configkey, configval)		
		scriptLog(player, "CONFIG updated -> key: %s | val: %s", configkey, configval)
		player:sendChatMessage("findstation", 0, "Configuration updated successfully")
	else
		-- invalid value	
		local paramtypelabel = getParamTypeLabel(paramtype)
		scriptLog(player, "invalid config value -> key: %s | val: %s | paramtype: %s", configkey, configval, paramtype)
		player:sendChatMessage("findstation", 0, "Error: %s parameter required for config '%s'!", paramtype, configkey)
	end

end


function getDescription()
    return "Configuration helper for the /findstation command."
end


-- called by /help command
function getHelp()
    return [[
Configuration helper for the /findstation command.
Usage:
/findstationconfig galaxy <GALAXYNAME>
/findstationconfig galaxypath <GALAXYPATH>
/findstationconfig searchmode <MODE>
/findstationconfig maxresults <NUMBER>
/findstationconfig framesectorloads <NUMBER>
/findstationconfig maxconcurrent <NUMBER>
/findstationconfig searchdelay <NUMBER>
Parameter:
<GALAXYNAME> = name of current galaxy
<GALAXYPATH> = full directory path for galaxy
<MODE> = one of the available search modes 'player' or 'galaxy'
<NUMBER> = any positive number or 0
]]
end
