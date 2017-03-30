--[[

FINDSTATION MOD
author: w00zla

file: lib/findstation/config.lua
desc: configuration util for findstation commands

]]--

package.path = package.path .. ";data/scripts/lib/?.lua"


-- available defaults
local defaults = {
	framesectorloads = 10,
	maxresults = 30,
	maxchatresults = 18,
	maxconcurrent = 0,
	searchdelay = 0,
	searchmode = "player",
	debugoutput = false
}


local configprefix = "findstation_"
local debugoutput = nil
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
		searchmode = Config.loadValue("searchmode"),
		framesectorloads = tonumber(Config.loadValue("framesectorloads")),
		maxchatresults = tonumber(Config.loadValue("maxchatresults")),
		maxresults = tonumber(Config.loadValue("maxresults")),
		maxconcurrent = tonumber(Config.loadValue("maxconcurrent")),
		searchdelay = tonumber(Config.loadValue("searchdelay"))
	}
	
	return cfg
end


function Config.debugoutput()

	if debugoutput == nil then
		debugoutput = Config.loadValue("debugoutput")
	end	
	return debugoutput

end


-- if Config.loadValue("debugoutput") then
-- 	Config.debugoutput = Config.loadValue("debugoutput")
-- end


return Config
