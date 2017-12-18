--[[ RethinkDB databse interaction adapted from DannehSC/electricity-2.0 ]]

local rethink=require('luvit-reql')
local conn=rethink:connect(options.database)

Database={
	_raw_database=rethink,
	_conn=conn,
	cache={},
	type='rethinkdb',
}

Database.default = {
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
}

function Database:get(guild,index) --luacheck: ignore self
	local id = resolveGuild(guild)
	if Database.cache[id] then
		local cached=Database.cache[id]
		if cached[index]then
			return cached[index]
		else
			return cached
		end
	else
		local data,err = Database._conn.reql().db('momiji').table('guilds').get(id).run()
		if err then
			print('GET',err)
		else
			local u
			if data==nil then
				data = table.deepcopy(Database.default)
				data.id = id
				Database.cache[id] = data
				u = true
			else
				local d = data
				Database.cache[id] = d
				Database.cache[id]['id'] = id
				for i,v in pairs(Database.default) do
					if not d[i] then
						d[i] = v
						u = true
					end
				end
				for i,v in pairs(Database.default.Settings) do
					if not d.Settings[i] then
						d.Settings[i] = v
						u = true
					end
				end
			end
			if u then
				Database:update(id)
			end
			local cached = Database.cache[id]
			if cached[index] then
				return cached[index]
			else
				return cached
			end
		end
	end
end

function Database:update(guild,index,value) --luacheck: ignore self
	if not guild then error"No ID/Guild/Message provided" end
	local id=resolveGuild(guild)
	if Database.cache[id] then
		if index then
			Database.cache[id][index]=value
		end
		if not Database.cache[id].id then
			Database.cache[id].id=id
		end
		local data,err,edata=Database._conn.reql().db('momiji').table('guilds').inOrUp(Database.cache[id]).run()
		if err then
			print('UPDATE')
			print(err)
			p(edata)
		end
		return data,err,edata
	else
		print("Fetch data before trying to update it.")
	end
end
