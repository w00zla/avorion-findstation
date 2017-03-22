--[[

FINDSTATION MOD

version: alpha2
author: w00zla

file: commands/findstationconfig.lua
desc: auto-included script to implement custom command /findstationconfig

]]--


package.path = package.path .. ";data/scripts/lib/?.lua"

require "cmd.findstationcommon"


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
	-- TODO: validate directories by reading some standard galaxy file
	
	local valid = false
	local paramtype = ""
	local config = configkey
	
	if configkey == "galaxy" then
		paramtype = "Name"		
		if validateParameter(configval, paramtype) then
			-- get %APPDATA% path because game uses this as base directory to save galaxies 
			-- this is by default, even for dedicated servers!
			local appdatapath = os.getenv("APPDATA")
			if not appdatapath or appdatapath == "" then
				print("DEBUG findstation => ERROR -> no appdatapath available")
				player:sendChatMessage("findstation", 0, "Error: no appdatapath available!")
				return
			end	
			configkey = "galaxypath"
			configval = appdatapath .. "\\Avorion\\galaxies\\" .. configval .. "\\"
			valid = true
		end
	elseif configkey == "galaxypath" then
		paramtype = "path"
		valid = validateParameter(configval, paramtype)	
	elseif configkey == "framesectorchecks" then
		paramtype = "pnum"
		valid = validateParameter(configval, paramtype)	
	elseif configkey == "framesectorloads" then
		paramtype = "pnum"
		valid = validateParameter(configval, paramtype)	
	else
		-- unknown config
		print(string.format("SCRIPT findstation => unknown configuration -> configkey: %s | configval: %s", configkey, configval))
		player:sendChatMessage("findstation", 0, "Error: Unknown configuration '%s'!", configkey)
		return
	end
	
	if valid then
		-- valid update -> save config
		saveConfigValue(configkey, configval)
		print(string.format("SCRIPT findstation => CONFIG updated -> configkey: %s | configval: %s", configkey, configval))
		player:sendChatMessage("findstation", 0, "Configuration updated successfully")
	else
		-- invalid value	
		local paramtypelabel = getParamTypeLabel(paramtype)
		print(string.format("SCRIPT findstation => invalid config value -> configkey: %s | configval: %s | paramtype: %s", configkey, configval, paramtype))
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
/findstationconfig framesectorchecks <NUMBER>
/findstationconfig framesectorloads <NUMBER>
Parameter:
<GALAXYNAME> = name of current galaxy
<GALAXYPATH> = full directory path for galaxy
<NUMBER> = any positive number or 0
]]
end
