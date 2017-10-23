local helpers = helpers or {}

helpers.readAll = function(file)
    local f = io.open(file, "rb")
    local content = f:read("*all")
    f:close()
    return content
end

helpers.saveJson = function(tbl, file)
    local f = io.open(file, "w")
    local str = json.stringify(tbl)
    f:write(str)
    f:close()
end

helpers.removeListeners = function(e, name)
    if discordia.class.isInstance(e, discordia.class.classes.Emitter) and name then
        l = e:getListeners(name)
        e:removeAllListeners(name)
        return l
    end
end

helpers.registerListeners = function(e, name, funcs)
    if discordia.class.isInstance(e, discordia.class.classes.Emitter) and name and funcs then
        for func in funcs do
            e:on(name, func)
        end
    end
end

--[[ luasql.postgres returns individual objects as strings, this lets us convert those to lua tables ]]
helpers.sqlStringToTable = function(str)
	if str:startswith('{') and str:endswith('}') then
		str = string.gsub(str, "[{}]", "")
		return str:split(',')
	end
end

--[[ Takes string that might be a user mention, returns the userID if it is ]]
helpers.parseMention = function(mention)
	return string.match(mention, "%<%@%!(%d+)%>") or string.match(mention, "%<%@(%d+)%>") or mention
end

--[[ Takes a string that might be a channel mention, returns channelID if it is ]]
helpers.parseChannel = function(mention)
	return string.match(mention, "%<%#(%d+)%>") or mention
end

--[[ creates a Date object with the given ISO-format time if valid, otherwise returns the original string ]]
helpers.parseTime = function(time)
	if string.match(time, '(%d+)-(%d+)-(%d+).(%d+):(%d+):(%d+)(.*)') then return discordia.Date.fromISO(time) else return time end
end

--[[ takes a date table in the format of os.date("*t"), returns human readable ]]
helpers.humanReadableTime = function(table)
    days = {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"}
    months = {"January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"}
	if #tostring(table.min) == 1 then table.min = "0"..table.min end
	if #tostring(table.hour) == 1 then table.hour = "0"..table.hour end
	return days[table.wday]..", "..months[table.month].." "..table.day..", "..table.year.." at "..table.hour..":"..table.min or table
end

--[[ used by the role functions, splits a user mention from the comma-separated role list ]]
helpers.parseRoleList = function(message)
	local member, roles
	if #message.mentionedUsers == 1 then
		member = message.guild:getMember(message.mentionedUsers:iter()())
		roles = message.content:gsub("<@.+>", "")
	else
		roles = message.content
	end
	roles = roles:gsub("^%"..message.guild._settings.prefix.."%g+", ""):trim()
	roles = roles:split(",")
	for i,r in ipairs(roles) do roles[i] = roles[i]:trim() end
	return roles, member
end

return helpers
