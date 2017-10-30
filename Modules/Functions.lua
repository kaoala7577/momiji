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
        --TODO: Mod Roles: rank 1
        --      Admin Role: rank 2
        --      Guild Owner: rank 3
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

function parseMention(mention)
	return string.match(mention, "%<%@%!(%d+)%>") or string.match(mention, "%<%@(%d+)%>") or mention
end

function getIdFromString(str)
	local fs=str:find('<')
	local fe=str:find('>')
	if not fs or not fe then return end
	return str:sub(fs+2,fe-1)
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
	if this then
		c=guild:getChannel(this)
	else
		c=guild.textChannels:find(function(c)
			return c.name==name
		end)
	end
	return c
end
