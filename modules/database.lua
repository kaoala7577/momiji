--[[ RethinkDB databse interaction adapted from DannehSC/electricity-2.0 ]]

local json = require('json')
local rethink=require('luvit-reql')
local conn=rethink:connect(storage.options.database)
local database={
	_raw_database=rethink,
	_conn=conn,
	cache={},
	type='rethinkdb',
}

database.default = {
	Settings = {
		prefix = "m!",
		admin_roles = {},
		mod_roles = {},
		audit = false,
		audit_channel = "default---channel",
		modlog = false,
		modlog_channel = "default---channel",
		welcome = false,
		welcome_channel = "default---channel",
		welcome_message = "",
		introduction = false,
		introduction_channel = "default---channel",
		introduction_message = "",
		autorole = false,
		autoroles = {},
		mute_setup = false,
	},
	Roles = {},
	Notes = {},
	Ignore = {},
	Cases = {},
	Timers = {},
	Users = {},
	Hackbans = {},
}

function database:get(guild,index) --luacheck: ignore self
	local id = resolveGuild(guild)
	if database.cache[id] then
		local cached = database.cache[id]
		if cached[index]then
			return cached[index]
		else
			return cached
		end
	else
		local data,err = database._conn.reql().db('momiji').table('guilds').get(tostring(id)).run()
		if err then
			print('GET',err)
		else
			local u
			if data==nil then
				data = table.deepcopy(database.default)
				data.id = id
				database.cache[id] = data
				u = true
			else
				data.id = id
				database.cache[id] = data
				for i,v in pairs(database.default) do
					if not data[i] then
						data[i] = v
						u = true
					end
				end
				for i,v in pairs(database.default.Settings) do
					if not data.Settings[i] then
						data.Settings[i] = v
						u = true
					end
				end
			end
			if u then
				database:update(id)
			end
			return data
		end
	end
end

function database:update(guild,index,value) --luacheck: ignore self
	if not guild then error"No ID/Guild/Message provided" end
	local id=resolveGuild(guild)
	if database.cache[id] then
		if index then
			database.cache[id][index]=value
		end
		if not database.cache[id].id then
			database.cache[id].id=id
		end
		local data,err,edata=database._conn.reql().db('momiji').table('guilds').inOrRe(database.cache[id]).run()
		client:debug("GUILD: %s INDEX: %s DATA: %s", id, index, json.encode(data))
		if err then
			client:error("GUILD: %s INDEX: %s ERROR: %s\nDATA: %s", id, index, err, json.encode(data))
			print('UPDATE')
			print(err)
			p(edata)
		end
		return data,err,edata
	else
		print("Fetch data before trying to update it.")
	end
end

function database:getCached(guild,index) --luacheck: ignore self
	local id = resolveGuild(guild)
	if database.cache[id] then
		local cached=database.cache[id]
		if cached[index]then
			return cached[index]
		else
			return cached
		end
	else
		print("Cannot access cached data. Make sure it has been loaded")
	end
end

function database:delete(guild,index) --luacheck: ignore self
	if not guild then error"No ID/Guild/Message provided"end
	local id = resolveGuild(guild)
	if database.cache[id] then
		local cached = database.cache[id]
		if cached[index] then
			cached[index] = nil
		elseif cached.Timers[index] then
			cached.Timers[index] = nil
		elseif cached.Roles[index] then
			cached.Roles[index] = nil
		end
	end
	database:Update(guild)
end

return database
