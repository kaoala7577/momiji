fs = require('fs')
json = require('json')
ssl = require('openssl')
timer = require("timer")
query = require('querystring')
http = require('coro-http')
xml = require("xmlSimple").newParser()

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

ColorChange = {
	me = false
}

function loadModule(name)
	name=name..'.lua'
	local data,others=fs.readFileSync('./Modules/'..name)
	if data then
		local a,b=loadstring(data,name)
		if not a then
			logger:log(1, "<SYNTAX> Error loading %s (%s)", name, b)
			return false
		else
			setfenv(a,getfenv())
			local c,d=pcall(a)
			if not c then
				logger:log(1, "<RUNTIME> Error loading %s (%s)", name, d)
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
	loadModule('Timed')
	loadModule('API')
	loadModule('Commands')

	-- Register Client Events
	registerAllEvents()
	client:once('ready', Events.ready)

	-- Register Clock Events
	clock:on('min', Clocks.min)

	-- Run
	client:run(options.token)
end)()
