-- Deps
local fs = require('fs')
local json = require('json')
-- local ssl = require('openssl')
-- local timer = require("timer")
-- local query = require('querystring')
-- local http = require('coro-http')
-- local xml = require("xmlSimple").newParser()
-- local pprint = require("pretty-print")
-- local uv = require("uv")
-- local ffi = require("ffi")

-- Globals
discordia = require('discordia') -- load discordia
enums = discordia.enums -- load enumerations
client = discordia.Client({
	cacheAllMembers = true,
}) -- create client
uptime = discordia.Stopwatch() -- stopwatch to count uptime
clock = discordia.Clock() -- clock emitter
logger = discordia.Logger(4, '%F %T', 'discordia.log')
storage = discordia.storage
storage.bulkDeletes = {} -- initalize storage table and bulkDeletes
storage.options = json.parse(fs.readFileSync('options.json')) -- Static config file containing key-value pairs
colors = {
	blue = discordia.Color.fromHex('#5DA9FF'),
	red = discordia.Color.fromHex('#ff4040'),
	green = discordia.Color.fromHex('#00ff7f'),
	altBlue = discordia.Color.fromHex('#7979FF'),
} -- preset colors

-- loadModule adapted from DannehSC/Electricity-2.0
function loadModule(name)
	name = name..'.lua'
	local data,others = fs.readFileSync('./Modules/'..name)
	if data then
		local f, err = loadstring(data,name)
		if not f then
			logger:log(1, "<SYNTAX> Error loading %s (%s)", name, err)
			return false
		else
			setfenv(f, getfenv())
			local stat, ret = pcall(f)
			if not stat then
				logger:log(1, "<RUNTIME> Error loading %s (%s)", name, ret)
				return false
			else
				client:info('Module online: '..name)
			end
		end
	else
		logger:log(1, "<LOADING> Error loading %s (%s)", name, tostring(others))
		return false
	end
	return true
end

coroutine.wrap(function()
	-- Load Modules
	loadModule('utilities')
	loadModule('functions')
	loadModule('database')
	loadModule('events')
	loadModule('clocks')
	loadModule('timing')
	loadModule('api')
	loadModule('commands')

	-- Register Client Events
	registerAllEvents()
	client:once('ready', function() dispatcher('ready') end)

	-- Register Clock Events
	clock:on('min', clocks.min)
	clock:on('hour', clocks.hour)

	-- Run
	client:run(storage.options.token)
end)()
