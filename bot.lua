-- Deps
local discordia = require('discordia') -- load discordia
local settings = require('./res/settings')
discordia.extensions() --load extensions
require('./res/functions')() --load helper functions

local modules = {}
local uptime = discordia.Stopwatch() -- stopwatch to count uptime
local clock = discordia.Clock() -- clock emitter

local client = discordia.Client({
	cacheAllMembers = true,
	logLevel = discordia.enums.logLevel.info,
}) -- create client

local env = setmetatable({
	require = require, --luvit custom require
	discordia = discordia,
	client = client,
	modules = modules,
	uptime = uptime,
	clock = clock,
}, {__index = _G})

local loader = require('./res/loader')(client, modules, env)

-- Wrapped because luvit-reql prefers coroutines
coroutine.wrap(function()
	-- Load Modules
	local loadModule = loader.loadModule
	loadModule('./modules/api.lua')
	loadModule('./modules/clocks.lua')
	loadModule('./modules/database.lua')
	loadModule('./modules/timing.lua')
	loadModule('./modules/events.lua')
	loadModule('./modules/helpers.lua')
	loadModule('./modules/commands.lua')

	-- Register Client Events
	registerAllEvents()
	client:once('ready', function() dispatcher('ready') end)

	-- Register Clock Events
	clock:on('min', modules.clocks.min)
	clock:on('hour', modules.clocks.hour)

	-- Run
	client:run("Bot "..settings.token)
end)()
