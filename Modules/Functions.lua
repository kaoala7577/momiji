--[[ Seeveral functions adapted from DannehSC/Electricity-2.0 ]]

function checkArgs(types, vals)
	for i,v in ipairs(types) do
		if type(v)=='table' then
			local t1=true
			if type(vals[i])~=v[1] then
				t1=false
			end
			if t1==false then
				if type(vals[i])~=v[2] then
					return false,v,i,type(vals[i])
				end
			end
		else
			if type(vals[i])~=v then
				return false,v,i,type(vals[i])
			end
		end
	end
	return true,'',#vals
end

function getRank(member, server)
	if not member then return 0 end
	local rank = 0
	if server then
		local settings = Database:get(member, "Settings")
		for _,v in ipairs(settings['mod_roles']) do
			if member:hasRole(v) then
				rank = 1
			end
		end
		for _,v in ipairs(settings['admin_roles']) do
			if member:hasRole(v) then
				rank = 2
			end
		end
		if member.id == member.guild.owner.id then
			rank = 3
		end
	end
	if member.id == member.client.owner.id then
		rank = 4
	end
	return rank
end

function humanReadableTime(table)
	days = {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"}
	months = {"January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"}
	if #tostring(table.min) == 1 then table.min = "0"..table.min end
	if #tostring(table.hour) == 1 then table.hour = "0"..table.hour end
	return days[table.wday]..", "..months[table.month].." "..table.day..", "..table.year.." at "..table.hour..":"..table.min or table
end

function parseTime(time)
	if string.match(time or "", '(%d+)-(%d+)-(%d+).(%d+):(%d+):(%d+)(.*)') then return discordia.Date.fromISO(time) else return time end
end

--TODO: make these compatible with discordia.Date
function parseHumanTime(message)
	local t={}
	for time,unit in message:gmatch('(%d+)%s*(%S+)') do
		local u=unit:lower()
		if u:startswith('y') then
			t.years=time
		elseif u:startswith('mo') then
			t.months=time
		elseif u:startswith('w') then
			t.weeks=time
		elseif u:startswith('d') then
			t.days=time
		elseif u:startswith('h') then
			t.hours=time
		elseif u:startswith('m') then
			t.minutes=time
		elseif u:startswith('s') then
			t.seconds=time
		end
	end
	return t
end

function toSeconds(tim)
	if not type(tim)=='table'then return 0 end
	local s=0
	local secs={
		years=31536000,
		months=60*60*24*31,
		weeks=60*60*24*7,
		days=60*60*24,
		hours=60*60,
		minutes=60,
		seconds=1,
	}
	for typ,val in pairs(tim)do
		s=s+(secs[typ]*val)
	end
	return s
end

function fromSeconds(tim)
	local secs={
		years=31536000,
		months=60*60*24*31,
		weeks=60*60*24*7,
		days=60*60*24,
		hours=60*60,
		minutes=60,
		seconds=1,
	}
	local ret={
		years=0,
		months=0,
		weeks=0,
		days=0,
		hours=0,
		minutes=0,
		seconds=0,
	}
	for typ,val in pairs(secs)do
		if tim>=tonumber(val)then
			repeat
				tim=tim-tonumber(val)
				ret[typ]=ret[typ]+1
			until tim<tonumber(val)
		end
	end
	return ret
end

function timeBetween(tim)
	local dat,str=fromSeconds(tim),''
	for i,v in pairs(dat)do
		if v>0 then
			local s=tostring(i)
			str=str..', '..tostring(v)..' '..(v==1 and s:sub(1,#s-1)or s)
		end
	end
	return str:sub(3)
end

function getIdFromString(str)
	return string.match(tostring(str),"<?[@#]?!?(%d*)>?")
end

function resolveGuild(guild)
	local ts=tostring
	if not guild then error"No ID/Guild/Message provided" end
	local id
	if type(guild)=='table'then
		if guild['guild']then
			id=ts(guild.guild.id)
		else
			id=ts(guild.id)
		end
	else
		id=ts(guild)
		guild=client:getGuild(id)
	end
	return id,guild
end

function resolveChannel(guild,name)
	local this=getIdFromString(name)
	local c
	if this then
		c=guild:getChannel(this)
	else
		c=guild.textChannels:find(function(ch)
			return string.lower(ch.name)==string.lower(name)
		end)
	end
	return c
end

function resolveMember(guild,name)
	local this = getIdFromString(name)
	local m
	if this then
		m = guild:getMember(this)
	else
		m = guild.members:find(function(mem)
			return string.lower(mem.name)==string.lower(name)
		end)
	end
	return m
end

function resolveRole(guild,name)
	local this = getIdFromString(name)
	local r
	if this and this~='' then
		r = guild:getRole(this)
	else
		r = guild.roles:find(function(ro)
			return string.lower(ro.name)==string.lower(name)
		end)
	end
	return r
end

function getFormatType(str)
	local type = str:match("$type:(%S*)")
	return type
end

function formatMessageSimple(str, member)
	for word in string.gmatch(str, "{%S+}") do
		if word:lower()=='{user}' then
			str = str:gsub(word, member.mentionString)
		elseif word:lower()=='{guild}' then
			str = str:gsub(word, member.guild.name)
		end
	end
	return str
end

function formatMessageEmbed(str, member)
	local embed = {}
	for word in string.gmatch(str, "$[^$]*") do
		local field, val = string.match(word, "$(%S+):(.*)")
		if field=='title' then
			embed['title'] = formatMessageSimple(val, member)
		elseif field=='description' then
			embed['description'] = formatMessageSimple(val, member)
		elseif field=='thumbnail' then
			if val:startswith('member') then
				embed['thumbnail'] = {url=member.avatarURL, height=200,width=200}
			elseif val=='guild' then
				embed['thumbnail'] = {url=member.guild.iconURL, height=200,width=200}
			end
		elseif field=='color' then
			local color = val:match("#([0-9a-fA-F]*)")
			if #color==6 then
				embed['color'] = discordia.Color.fromHex(color).value
			end
		end
	end
	return embed
end

function resolveCommand(str, pre)
	local prefix = pre or "m!"
	local command,rest
	if string.match(str, "^<@!?"..client.user.id..">") then
		command, rest = str:sub(#client.user.mentionString+2):match('(%S+)%s*(.*)')
	elseif (prefix~="" and string.match(str,"^%"..prefix)) or prefix=="" then
		command, rest = str:sub(#prefix+1):match('(%S+)%s*(.*)')
	end
	return command, rest
end

function unregisterAllEvents()
	if not Events then return end
	for k,_ in pairs(Events) do
		if k~="Timing" and k~="ready" then
			client:removeAllListeners(k)
		end
	end
end

function registerAllEvents()
	if not Events then return end
	for k,v in pairs(Events) do
		if k~="Timing" and k~="ready" then
			client:on(k,v)
		end
	end
end
