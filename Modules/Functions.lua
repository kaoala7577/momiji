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
        settings = Database:Get(member, "Settings")
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
	if string.match(time, '(%d+)-(%d+)-(%d+).(%d+):(%d+):(%d+)(.*)') then return discordia.Date.fromISO(time) else return time end
end

function getIdFromString(str)
	return str:match("<[@#]!*(.*)>")
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
	local this=getIdFromString(name) or name
    local c
	if this then
		c=guild:getChannel(this)
	else
		c=guild.textChannels:find(function(c)
			return c.name==name
		end)
	end
	return c
end

function resolveMember(guild,name)
	local this=getIdFromString(name) or name
    local m
	if this then
		m=guild:getMember(this)
	else
		m=guild.members:find(function(mem)
			return mem.name==name
		end)
	end
	return m
end

function resolveRole(guild,name)
	local this=getIdFromString(name) or name
    local m
	if this then
		m=guild:getRole(this)
	else
		m=guild.roles:find(function(mem)
			return mem.name==name
		end)
	end
	return m
end

function getFormatType(str, member)
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

function resolveCommand(str, p, pre)
    local prefix = ""
    if p then
        prefix = ""
    else
        prefix=pre or "m!"
        if not string.match(str,"^%"..prefix) or string.match(str, "^"..client.user.mentionString) then return end
    end
    local command, rest = str:sub(#prefix+1):match('(%S+)%s*(.*)')
    return command, rest
end
