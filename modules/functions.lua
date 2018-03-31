--[[ Several functions adapted from DannehSC/Electricity-2.0 ]]
local functions = {}

--Type checking function, useful when strict typing is needed
function functions.checkArgs(types, vals)
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

--Given a member and a guild (or false/nil), get the rank of the member
function functions.getRank(member, private)
	if not member then return 0 end
	local rank = 0
	if not private then
		local settings = modules.database:get(member, "Settings")
		if type(settings.mod_roles)=='table' then
			for _,v in ipairs(settings['mod_roles']) do
				if member:hasRole(v) then
					rank = 1
				end
			end
		end
		if type(setting.admin_roles)=='table' then
			for _,v in ipairs(settings['admin_roles']) do
				if member:hasRole(v) then
					rank = 2
				end
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

-- This is shit, please fix
function functions.humanReadableTime(table)
	days = {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"}
	months = {"January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"}
	if #tostring(table.min) == 1 then table.min = "0"..table.min end
	if #tostring(table.hour) == 1 then table.hour = "0"..table.hour end
	return days[table.wday]..", "..months[table.month].." "..table.day..", "..table.year.." at "..table.hour..":"..table.min or table
end

-- Takes a (hopefully) ISO date string and turns it into a Date object, if not ISO formatted, returns the input
function functions.parseISOTime(time)
	if string.match(time or "", '(%d+)-(%d+)-(%d+).(%d+):(%d+):(%d+)(.*)') then return discordia.Date.fromISO(time) else return time end
end

-- Takes a string and attempts to build a time out from the current based on the input (i.e. 5m 20 seconds will build an Date object that time in the future)
function functions.parseTime(message)
	local t = discordia.Date():toTableUTC()
	for time,unit in message:gmatch('(%d+)%s*(%D+)') do
		local u = unit:lower()
		if u:startswith('d') then
			t.day = t.day+time
		elseif u:startswith('h') then
			t.hour = t.hour+time
		elseif u:startswith('m') then
			t.min = t.min+time
		elseif u:startswith('s') then
			t.sec = t.sec+time
		end
	end
	return discordia.Date.fromTableUTC(t)
end

-- Takes a Date object and returns a new Time object representing the time between the given one and the current
function functions.timeBetween(time)
	return discordia.Time.fromSeconds(discordia.Date():toSeconds()-time:toSeconds())
end

-- Takes a Date object and returns a new Time object representing the time between the given one and the current
function functions.timeUntil(time)
	return discordia.Time.fromSeconds(time:toSeconds()-discordia.Date():toSeconds())
end

-- Given a Lua date time table, create a string with the values and keys
function functions.prettyTime(t)
	local order = {days = "day", hours = "hour", minutes = "minute", seconds = "second"}
	local out = ""
	for k,v in pairsByKeys(order) do
		if t[k] then
			if t[k]==1 then
				out = out~="" and out..", "..t[k].." "..v or t[k].." "..v
			elseif t[k]~=0 then
				out = out~="" and out..", "..t[k].." "..v.."s" or t[k].." "..v.."s"
			end
		end
	end
	return out
end

-- Tries to find a Discord snowflake in the given string, returning it if one is found. returns nil on failure
function functions.getIdFromString(str)
	local d = string.match(tostring(str),"<?[@#]?!?(%d+)>?")
	if d and #d>=17 then return d else return end
end

-- attemps to resolve a guild known to the client from a provided object or ID. Do not rely on  this
function functions.resolveGuild(guild)
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

-- Resolves a channel object given a guild and a string. Will match with ID or name
function functions.resolveChannel(guild,name)
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

-- Resolves a member object given a guild and a string. Will match with ID or name
function functions.resolveMember(guild,name)
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

-- Resolves a role object given a guild and a string. Will match with ID or name
function functions.resolveRole(guild,name)
	local this = getIdFromString(name)
	local r
	if this then
		r = guild:getRole(this)
	else
		r = guild.roles:find(function(ro)
			return string.lower(ro.name)==string.lower(name)
		end)
	end
	return r
end

-- Used in message formatting, purely matches "$type:(capture)" and returns the capture group
function functions.getFormatType(str)
	local type = str:match("$type:(%S*)")
	return type
end

-- Searches a string for known replacements and replaces them
function functions.formatMessageSimple(str, member)
	for word, opt in string.gmatch(str, "{([^:{}]+):?([^:{}]*)}") do
		if word:lower()=='user' then
			if opt~="" then
				str = str:gsub("{[^{}]*}", tostring(member[opt]), 1)
			else
				str = str:gsub("{[^{}]*}", member.mentionString, 1)
			end
		elseif word:lower()=='guild' then
			if opt~="" then
				str = str:gsub("{[^{}]*}", tostring(member.guild[opt]), 1)
			else
				str = str:gsub("{[^{}]*}", member.guild.name, 1)
			end
		end
	end
	return str
end

-- Converts a string into an embed table
function functions.formatMessageEmbed(str, member)
	local embed = {}
	for word in string.gmatch(str, "$[^$]*") do
		local field, val = string.match(word, "$(%S+):(.*)")
		if field=='title' then
			embed['title'] = formatMessageSimple(val, member)
		elseif field=='description' then
			embed['description'] = formatMessageSimple(val, member)
		elseif field=='thumbnail' then
			if val:startswith('member') then
				embed['thumbnail'] = {url=member.avatarURL}
			elseif val=='guild' then
				embed['thumbnail'] = {url=member.guild.iconURL}
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

-- Black magic fuckery. Don't mess with this or everything breaks
function functions.resolveCommand(str, pre)
	local prefix = pre or "m!"
	local command,rest
	if string.match(str, "^<@!?"..client.user.id..">") then
		command, rest = str:sub(#client.user.mentionString+2):match('(%S+)%s*(.*)')
	elseif (prefix~="" and string.match(str,"^%"..prefix)) or prefix=="" then
		command, rest = str:sub(#prefix+1):match('(%S+)%s*(.*)')
	end
	return command, rest
end

-- Also black magic fuckery, but I vaguely understand how this works
function functions.getSwitches(str)
    local t = {}
	str = str:gsub("\\/", "—")
	t.rest = str:match("^([^/]*)/?"):trim()
    for switch, arg in str:gmatch("/%s*(%S*)%s*([^/]*)") do
        t[switch]=arg:trim()
    end
	for k,v in pairs(t) do
		t[k] = v:gsub("—", "/")
	end
    return t
end

-- Used to wrap and post errors in all events
function functions.dispatcher(name, ...)
	local b,e,n,g = checkArgs({'string'}, {name})
	if not b then
		client:error("<DISPATCHER> Unable to load %s (Expected: %s, Number: %s, Got: %s)", name,e,n,g)
		return
	end
	local ret, err = pcall(modules.events[name], ...)
	if not ret then
		if discordia.storage.errLog then
			discordia.storage.errLog:send {embed = {
				description = err,
				footer = {text="DISPATCHER: "..name},
				timestamp = discordia.Date():toISO(),
				color = discordia.Color.fromRGB(255, 0 ,0).value,
			}}
		end
	end
end

function functions.unregisterAllEvents()
	if not modules.events then return end
	for k,_ in pairs(modules.events) do
		if k~="Timing" and k~="ready" then
			client:removeAllListeners(k)
		end
	end
end

function functions.registerAllEvents()
	if not modules.events then return end
	for k,_ in pairs(modules.events) do
		if k~="Timing" and k~="ready" then
			client:on(k,function(...) functions.dispatcher(k,...) end)
		end
	end
end

-- Traverses a table and returns an iterator sorted by keys
function functions.pairsByKeys (t, f)
	local a = {}
	for n in pairs(t) do table.insert(a, n) end
	table.sort(a, f)
	local i = 0      -- iterator variable
	local iter = function()   -- iterator function
		i = i + 1
		if a[i] == nil then
			return nil
		else
			return a[i], t[a[i]]
		end
	end
	return iter
end

-- Load this shit to global fam
for k,v in pairs(functions) do
	_G[k] = v
end

return functions
