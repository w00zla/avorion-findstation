--[[

FINDSTATION MOD

version: alpha4
author: w00zla

file: lib/findstation/config.lua
desc: configuration util for findstation commands

]]--

package.path = package.path .. ";data/scripts/lib/?.lua"


-- available defaults
local defaults = {
	framesectorchecks = 2000,
	framesectorloads = 10,
	maxresults = 30,
	maxchatresults = 18
}


local configprefix = "findstation_"
local Config = {}


function Config.saveValue(config, val)

	local storagekey = configprefix .. config
	Server():setValue(storagekey, val)

end


function Config.loadValue(config)

	local storagekey = configprefix .. config
	local val = Server():getValue(storagekey)
	
	if not val and defaults[config] then
		val = defaults[config]
	end
	return val

end


function Config.getCurrent()

	local cfg = {
		galaxypath = Config.loadValue("galaxypath"),
		framesectorchecks = tonumber(Config.loadValue("framesectorchecks")),
		framesectorloads = tonumber(Config.loadValue("framesectorloads")),
		maxchatresults = tonumber(Config.loadValue("maxchatresults")),
		maxresults = tonumber(Config.loadValue("maxresults"))
	}
	
	return cfg
end


return Config
