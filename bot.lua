fs = require('fs')
json = require('json')
ssl = require('openssl')
timer = require("timer")
query = require('querystring')
http = require('coro-http')
xml = require("xmlSimple").newParser()
pprint = require("pretty-print")
uv = require("uv")
ffi = require("ffi")

options = json.parse(fs.readFileSync('options.json'))
discordia = require('discordia')
enums = discordia.enums
client = discordia.Client({
	cacheAllMembers = true,
})
logger = discordia.Logger(4, '%F %T', 'discordia.log')
uptime = discordia.Stopwatch()
clock = discordia.Clock()
clock:start(true)
discordia.storage.bulkDeletes = {}

Colors = {
	blue = discordia.Color.fromHex('#5DA9FF'),
	red = discordia.Color.fromHex('#ff4040'),
	green = discordia.Color.fromHex('#00ff7f'),
	altBlue = discordia.Color.fromHex('#7979FF'),
}

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
	loadModule('Utilities')
	loadModule('Functions')
	loadModule('Database')
	loadModule('Events')
	loadModule('Clocks')
	loadModule('Timing')
	loadModule('API')
	loadModule('Commands')

	-- Register Client Events
	registerAllEvents()
	client:once('ready', function() dispatcher('ready') end)

	-- Register Clock Events
	clock:on('min', Clocks.min)
	clock:on('hour', Clocks.hour)

	-- Run
	client:run(options.token)
end)()
