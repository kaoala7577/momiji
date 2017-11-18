local token = require('token')

-- Globals
discordia = require('discordia')
enums = discordia.enums
client = discordia.Client({
	cacheAllMembers = true,
})
logger = discordia.Logger(4, '%F %T', 'discordia.log')
fs = require('fs')
json = require('json')
uptime = discordia.Stopwatch()
clock = discordia.Clock()
clock:start(true)

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
	client:on('messageCreate', Events.messageCreate)
	client:on('memberJoin', Events.memberJoin)
	client:on('memberLeave', Events.memberLeave)
	client:on('messageDelete',Events.messageDelete)
	client:on('messageDeleteUncached',Events.messageDeleteUncached)
	client:on('userBan',Events.userBan)
	client:on('userUnban',Events.userUnban)
	client:on('presenceUpdate', Events.presenceUpdate)
	client:on('memberUpdate', Events.memberUpdate)
	client:on('memberRegistered', Events.memberRegistered)
	client:once('ready',Events.ready)

	-- Register Clock Events
	clock:on('min', Clocks.min)

	-- Run
	client:run(token)
end)()
