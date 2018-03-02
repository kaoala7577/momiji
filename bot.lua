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

local utils = {}

function utils.loadModule(path, silent)
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

function utils.unloadModule(name)
	if modules[name] then
		modules[name] = nil
		client:info("Module unloaded: %s", name)
	else
		client:info("Module not found: %s", name)
	end
end

function utils.loadModules(path)
	for k, v in fs.scandirSync(path) do
		local joined = pathjoin.pathJoin(path, k)
		if v == 'file' then
			if k:find('.lua', -4, true) then
				utils.loadModule(joined)
			end
		else
			utils.loadModules(joined)
		end
	end
end

storage.utils = utils

coroutine.wrap(function()
	-- Load Modules
	-- These need to be loaded in a specific order
	utils.loadModule('./modules/functions.lua')
	utils.loadModule('./modules/api.lua')
	utils.loadModule('./modules/clocks.lua')
	utils.loadModule('./modules/database.lua')
	utils.loadModule('./modules/timing.lua')
	utils.loadModule('./modules/events.lua')
	utils.loadModule('./modules/commands.lua')

	-- Register Client Events
	registerAllEvents()
	client:once('ready', function() dispatcher('ready') end)

	-- Register Clock Events
	clock:on('min', modules.clocks.min)
	clock:on('hour', modules.clocks.hour)

	-- Run
	client:run(storage.options.token)
end)()
