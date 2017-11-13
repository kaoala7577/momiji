--[[ RethinkDB databse interaction forked from DannehSC/electricity-2.0 ]]

local options = require('./options.lua')
local rethink=require('luvit-reql')
local conn=rethink:connect(options)
local ts,fmt=tostring,string.format

Database={
	_raw_database=rethink,
	_conn=conn,
	Cache={},
	Type='rethinkdb',
}

Database.Default = {
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

function Database:Get(guild,index)
	local id,guild=resolveGuild(guild)
	if Database.Cache[id]then
		local Cached=Database.Cache[id]
		if Cached[index]then
			return Cached[index]
		else
			return Cached
		end
	else
		local data,err=Database._conn.reql().db('momiji').table('guilds').get(tostring(id)).run()
		if err then
			print('GET',err)
		else
			local u
			if data[1]==nil then
				data=table.deepcopy(Database.Default)
				data.id=id
				Database.Cache[id]=data
				u=true
			else
				local d=data[1]
				Database.Cache[id]=d
				Database.Cache[id]['id']=id
				for i,v in pairs(Database.Default)do
					if not d[i] then
						d[i]=v
						u=true
					end
				end
				for i,v in pairs(Database.Default.Settings)do
					if not d.Settings[i]then
						d.Settings[i]=v
						u=true
					end
				end
			end
			if u then
				Database:Update(id)
			end
			return data[1]
		end
	end
end

function Database:Update(guild,index,value)
	if not guild then error"No ID/Guild/Message provided" end
	local id,guild=resolveGuild(guild)
	if Database.Cache[id] then
		if index then
			Database.Cache[id][index]=value
		end
		if not Database.Cache[id].id then
			Database.Cache[id].id=id
		end
		local data,err,edata=Database._conn.reql().db('momiji').table('guilds').inOrUp(Database.Cache[id]).run()
		if err then
			print('UPDATE')
			print(err)
			p(edata)
		end
	else
		print("Fetch data before trying to update it. You fool.")
	end
end

function Database:Delete(guild,query,index)
	if not guild then error"No ID/Guild/Message provided"end
	local id,guild=resolveGuild(guild)
	if Database.Cache[id]then
		local Cached=Database.Cache[id]
		if Cached[index]then
			Cached[index]=nil
		end
	end
	local data,err=conn.reql().db('momiji').table('guilds').get(id).getField(query).filter({id=index}).delete().run()
	if err then
		print('DELETE',err)
		return err
	else
		return data
	end
end

function Database:GetCached(guild)
	local id,guild=resolveGuild(guild)
	if Database.Cache[id]then
		return Database.Cache[id]
	end
end
