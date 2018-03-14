-- Deps
local fs = require('fs')
local json = require('json')
local pathjoin = require('pathjoin')
local discordia = require('discordia') -- load discordia
discordia.extensions() --load extensions
local enums = discordia.enums -- load enumerations
local client = discordia.Client({
	cacheAllMembers = true,
	logLevel = enums.logLevel.info,
}) -- create client
local modules = {}
local uptime = discordia.Stopwatch() -- stopwatch to count uptime
local clock = discordia.Clock() -- clock emitter
clock:start(true)
local storage = discordia.storage
storage.bulkDeletes = {} -- initalize storage table and bulkDeletes
storage.options = json.parse(fs.readFileSync('options.json')) -- Static config file containing key-value pairs
local colors = {
	blue = discordia.Color.fromHex('#5DA9FF'),
	red = discordia.Color.fromHex('#ff4040'),
	green = discordia.Color.fromHex('#00ff7f'),
	altBlue = discordia.Color.fromHex('#7979FF'),
} -- preset colors
local ready = false

-- modules adapted from SinisterRectus/Luna
-- Create the environment for modules
local env = setmetatable({
	require = require, --luvit custom require
	discordia = discordia,
	client = client,
	enums = enums,
	modules = modules,
	uptime = uptime,
	clock = clock,
	storage = storage,
	colors = colors,
	ready = ready
}, {__index = _G})

function _G.loadModule(path, silent)
	local name = table.remove(pathjoin.splitPath(path)):gsub(".lua","")
	local success, err = pcall(function()
		local code = assert(fs.readFileSync(path))
		local fn = assert(loadstring(code, name, 't', env))
		modules[name] = fn()
	end)
	if success then
		if not silent then
			client:info('Module online: '..name)
		end
		return true
	else
		client:error("Error loading %s (%s)", name, err)
	end
end

function _G.unloadModule(name)
	if modules[name] then
		modules[name] = nil
		client:info("Module unloaded: %s", name)
	else
		client:info("Module not found: %s", name)
	end
end

-- Wrapped because luvit-reql prefers coroutines
coroutine.wrap(function()
	-- Load Modules
	-- These need to be loaded in a specific order
	loadModule('./modules/functions.lua', env)
	loadModule('./modules/api.lua', env)
	loadModule('./modules/clocks.lua', env)
	loadModule('./modules/database.lua', env)
	loadModule('./modules/timing.lua', env)
	loadModule('./modules/events.lua', env)
	loadModule('./modules/commands.lua', env)

	-- Register Client Events
	registerAllEvents()
	client:once('ready', function() dispatcher('ready') end)

	-- Register Clock Events
	clock:on('min', modules.clocks.min)
	clock:on('hour', modules.clocks.hour)

	-- Run
	client:run(storage.options.token)
end)()
