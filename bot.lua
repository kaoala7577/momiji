--[[ Required for discordia ]]
local discordia = require('discordia')
discordia.extensions()
local enums = discordia.enums
local client = discordia.Client({cacheAllMembers = true})
local token = require'token'

--[[ Required for luaSQL which loads per-guild settings and member data ]]
local luasql = require'luasql.postgres'
local env = luasql.postgres()
local conn = env:connect('mydb')

--[[ Required for my custom command parsing ]]
local core = require'core'
local CommandEmitter = core.Emitter:extend()
local commands = CommandEmitter:new()

--[[ Required for interval-based functions ]]
local clock = discordia.Clock()
clock:start()

--[[ Crude way of getting self roles ]]
--TODO
--Replace this with a per-guild list
local json = require'json'
function readAll(file)
    local f = io.open(file, "rb")
    local content = f:read("*all")
    f:close()
    return content
end
function saveJson(tbl, file)
    local f = io.open(file, "w")
    local str = json.stringify(tbl)
    f:write(str)
    f:close()
end
local selfRoles = json.parse(readAll('rolelist.json'))

local cmds = {}

--[[ luasql.postgres returns individual objects as strings, this lets us convert those to lua tables ]]
function sqlStringToTable(str)
	if str:startswith('{') and str:endswith('}') then
		str = string.gsub(str, "[{}]", "")
		return str:split(',')
	end
end

--[[ Takes string that might be a user mention, returns the userID if it is ]]
function parseMention(mention)
	return string.match(mention, "%<%@%!(%d+)%>") or string.match(mention, "%<%@(%d+)%>") or mention
end

--[[ Takes a string that might be a channel mention, returns channelID if it is ]]
function parseChannel(mention)
	return string.match(mention, "%<%#(%d+)%>") or mention
end

--[[ creates a Date object with the given ISO-format time if valid, otherwise returns the original string ]]
function parseTime(time)
	if string.match(time, '(%d+)-(%d+)-(%d+).(%d+):(%d+):(%d+)(.*)') then return discordia.Date.fromISO(time) else return time end
end

--[[ takes a date table in the format of os.date("*t"), returns human readable ]]
function humanReadableTime(table)
    days = {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"}
    months = {"January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"}
	if #tostring(table.min) == 1 then table.min = "0"..table.min end
	if #tostring(table.hour) == 1 then table.hour = "0"..table.hour end
	return days[table.wday]..", "..months[table.month].." "..table.day..", "..table.year.." at "..table.hour..":"..table.min or table
end

--[[ used by the role functions, splits a user mention from the comma-separated role list ]]
function parseRoleList(message)
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

--[[ authorizes a command for roles based on guild._settings.admin_roles and guild._settings.mod_roles ]]
function authorize(message, admins, mods)
	if not message or (message.channel.type ~= enums.channelType.text) then return end
	local member = message.guild:getMember(message.author.id)
	if admins then
		for _,r in pairs(message.guild._settings.admin_roles) do
			if member:hasRole(message.guild:getRole(r)) then return true end
		end
	end
	if mods then
		for _,r in pairs(message.guild._settings.mod_roles) do
			if member:hasRole(message.guild:getRole(r)) then return true end
		end
	end
	return false
end

--[[ command wrapper for callbacks. prevents the bot from crashing if a command fails ]]
function safeCall(func, message, args)
	local status, ret = xpcall(func, debug.traceback, message, args)
	if ret and not status then
		local channel = client:getChannel('364148499715063818')
		channel:send {
			embed = {
				description = ret,
				timestamp = discordia.Date():toISO(),
				color = discordia.Color.fromRGB(255, 0 ,0).value,
			}
		}
	end
	local react
	if status and ret then
		react = '✅'
	else
		react = '❌'
	end
	message:addReaction(react)
end

--[[ splits a command into command and everything else. handles literally every command ]]
function commandParser(message)
	if message.author.bot then return end
	if message.channel.type == enums.channelType.text then
        local prefix = message.guild._settings.prefix
		if message.content:match("^%"..prefix) then
			local str = message.content:match("^%"..prefix.."(%g+)")
			local args = message.content:gsub("^%"..prefix..str, ""):trim()
            str = str:lower()
            if table.search(table.keys(cmds), str) then
                if cmds[str].permissions.everyone then
                    commands:emit(str, message, args)
                elseif cmds[str].permissions.mods and authorize(message, false, true) then
                    commands:emit(str, message, args)
                elseif cmds[str].permissions.admin and authorize(message, true, false) then
                    commands:emit(str, message, args)
                elseif cmds[str].permissions.guildOwner and (message.member == message.guild.owner) then
                    commands:emit(str, message, args)
                elseif cmds[str].permissions.botOwner and (message.author == client.owner) then
                    commands:emit(str, message, args)
                end
            end
		end
    else
        message:reply("I'm not currently set up to handle private messages")
    end
end
client:on('messageCreate', function(m) commandParser(m) end)

--[[ init functions: load per-guild settings and ensure that all members are cached in the members table ]]
client:on('ready', function()
	print('Logged in as '.. client.user.username)
	client:setGame("Awoo!")
	for guild in client.guilds:iter() do
		local cur = conn:execute([[SELECT * FROM settings;]])
		local row = cur:fetch({}, "a")
		while row do
			if row.guild_id == guild.id then
				guild._settings = row
				guild._settings.admin_roles = sqlStringToTable(row.admin_roles)
				guild._settings.mod_roles = sqlStringToTable(row.mod_roles)
			end
			row = cur:fetch(row, "a")
		end
		for member in guild.members:iter() do
			conn:execute(string.format([[INSERT INTO members (member_id, nicknames, guild_id) VALUES ('%s','{"%s"}','%s') ON CONFLICT (member_id) DO UPDATE SET guild_id='%s';]], member.id, member.name, guild.id, guild.id))
		end
	end
end)

--stupid color changing function to learn how to hook callbacks to the clock
function changeColor(time)
	local guild = client:getGuild('348660188951216129')
	if guild and (math.fmod(time.min, 10) == 0) then
		local role = guild:getRole('348665099550195713')
		local success = role:setColor(discordia.Color.fromRGB(math.floor(math.random(0, 255)), math.floor(math.random(0, 255)), math.floor(math.random(0, 255))))
		role = guild:getRole('363398104491229184')
		success = role:setColor(discordia.Color.fromRGB(math.floor(math.random(0, 255)), math.floor(math.random(0, 255)), math.floor(math.random(0, 255))))
	end
end
clock:on('min', function(time) changeColor(time) end)

--Attempt to auto-remove cooldown
clock:on('min', function(time)
	local guild = client:getGuild('348660188951216129')
	if guild then
		for member in guild.members:iter() do
			if member:hasRole('348873284265312267') then
				local reg = conn:execute(string.format([[SELECT registered FROM members WHERE member_id='%s';]], member.id)):fetch()
				if reg and reg ~= 'N/A' then
					local date = parseTime(reg):toTable()
					if (time.day > date.day) and (time.hour >= date.hour) and (time.min >= date.min) then
						member:addRole('348693274917339139')
						member:removeRole('348873284265312267')
					end
				end
			end
		end
	end
end)

--Update last_message in members table. not used yet
client:on('messageCreate', function(message)
	if message.channel.type == enums.channelType.text and message.author.bot ~= true then
		local status, err = conn:execute(string.format([[UPDATE members SET last_message='%s' WHERE member_id='%s';]], discordia.Date():toISO(), message.member.id))
	end
end)

--Welcome message on memberJoin
function welcomeMessage(member)
	local channel = member.guild:getChannel(member.guild._settings.welcome_channel)
	if channel then
		channel:send("Hello "..member.name..". Welcome to "..member.guild.name.."! Please read through ".."<#348660188951216130>".." and inform a member of staff how you identify, what pronouns you would like to use, and your age. These are required.")
		--[[channel:send {
			embed = {
				author = {name = "Member Joined", icon_url = member.avatarURL},
				description = "Welcome "..member.name.." to "..member.guild.name.."! Please read through "..member.guild:getTextChannel('name', 'start-here-rules').mentionString.." and inform a member of staff how you identify and what pronouns you would like to use. These are required.",
				thumbnail = {url = member.avatarURL, height = 200, width = 200},
				color = discordia.Color(0, 255, 0).value,
				timestamp = discordia.Date():toISO(),
				footer = {text = "ID: "..member.id}
			}
		}--]]
	end
end
client:on('memberJoin', function(member) welcomeMessage(member) end)

--Post-register welcome
client:on('memberRegistered', function(member)
	local channel = member.guild:getChannel('350764752898752513')
	if channel then
		channel:send("Welcome to "..member.guild.name..", "..member.mentionString..". If you're comfortable doing so, please share a bit about yourself!")
	end
end)

--[[ Silly test func, changes based on what I need to test ]]
cmds['test'] = {
    id = "test",
    action = function(message, args)
    	if args ~= "" then
            logs = message.guild:getAuditLogs({type = tonumber(args), limit = 1})
            entry = logs:iter()()
            status = message:reply("```"..entry:getMember().name.."\t"..entry:getTarget().name.."```")
            return status
    	end
    end,
    permissions = {
        botOwner = true,
        guildOwner = false,
        admin = false,
        mod = false,
        everyone = false,
    },
    usage = "test [args]",
    description = "Shitty test function",
    category = "Bot Owner",
}

--Change the bot username. Owner only
cmds['uname'] = {
    id = "uname",
    action = function(message, args)
    	if args ~= "" then
			local success = client:setUsername(args)
			return status
    	else
    		message.author:send("You need to specify a new name.")
    	end
    end,
    permissions = {
        botOwner = true,
        guildOwner = false,
        admin = false,
        mod = false,
        everyone = false,
    },
    usage = "uname <name>",
    description = "Changes the bot's username",
    category = "Bot Owner",
}

--Change the bot nickname. Guild owner only
cmds['nick'] = {
    id = "nick",
    action = function(message, args)
    	if args ~= "" then
			local success = message.guild:getMember(client.user):setNickname(args)
			return success
    	else
    		message.author:send("You need to specify a new name.")
    	end
    end,
    permissions = {
        botOwner = false,
        guildOwner = true,
        admin = false,
        mod = false,
        everyone = false,
    },
    usage = "nick <name>",
    description = "Change the nickname of the bot on your server",
    category = "Guild Owner",
}


--Help page.... total shit
cmds['help'] = {
    id = "help",
    action = function(message)
	local status = message.author:send([[**How to read this doc:**
When reading the commands, arguments in angle brackets (`<>`) are mandatory
while arguments in square brackets (`[]`) are optional.
**No brackets should be included in the commands**

**Commands for everyone**
`.help`: DM this help page
`.ping`: pings the bot to see if it's awake
`.userinfo <@user|userID>`: pulls up some information on the user. If no user specified it uses the sender. Aliases: `.ui`
`.role <role[, role, ...]>`: adds all the roles listed to the sending user if the roles are on the self role list. Aliases: `.asr`
`.derole <role[, role, ...]>`: same as .role but removes the roles. Aliases: `.rsr`
`.roles`: list available self-roles
`.serverinfo`: pull up information on the server. Aliases: `.si`
`.roleinfo <rolename>`: pulls up information on the listed role. Aliases: `.ri`

**Moderator Commands**
`.mute [#channel] <@user|userID>`: mutes a user, if a channel is mentioned it only mutes them in that channel
`.unmute [#channe] <@user|userID>`: undoes mute
`.register <@user|userID> <role[, role, ...]>`: registers a user with the given roles. Aliases: `.reg`
`.watchlist <@user|userID>`: adds/removes a user from the watchlist. Aliases: `.wl`
`.toggle18 <@user|userID>`: toggles the under 18 user flag. Aliases: `.t18`
`.addnote <@user|userID> <note>`: Adds a note to the mentioned user.
`.delnote <@user|userID> <index>`: Deletes the note at index for the mentioned user.
`.viewnotes <@user|userID>`: Lists all notes on the mentioned user.]])
	message.author:send([[
**Admin Commands**
`.prune <number>`: bulk deletes a number of messages
`.ar <@user|userID> <role[, role, ...]>`: adds a user to the given roles
`.rr <@user|userID> <role[, role, ...]>`: removes a user from the given roles
`.noroles [message]`: pings every member without any roles and attaches an optional message

**Guild Owner Commands**
`.nick`: changes the bot nickname
`.prefix`: changes the prefix
`.populate`: ensures that momiji has the members table up-to-date

**Bot Owner Only**
`.uname <name>`: sets the bot's username]])
    	return status
    end,
    permissions = {
        everyone = true,
    },
    usage = "help",
    description = "DM the help page",
    category = "General",
}

--change prefix
cmds['prefix'] = {
    id = "prefix",
    action = function(message, args)
    	if args ~= "" then
			local status, err = conn:execute(string.format([[UPDATE settings SET prefix='%s' WHERE guild_id='%s';]], args, message.guild.id))
			if status then
				local curr = conn:execute(string.format([[SELECT * FROM settings WHERE guild_id='%s';]], message.guild.id))
				local row = curr:fetch({}, "a")
				message.guild._settings.prefix = row.prefix
				return status
    		end
    	end
    end,
    permissions = {
        botOwner = false,
        guildOwner = true,
        admin = false,
        mod = false,
        everyone = false,
    },
    usage = "prefix <prefix>",
    description = "Change the bot prefix for your server",
    category = "Guild Owner",
}

--ping
cmds['ping'] = {
    id = "ping",
    action = function(message)
    	local response = message:reply("Pong!")
    	if response then
    		local success = response:setContent("Pong!".."`"..math.round((response.createdAt - message.createdAt)*1000).." ms`")
    		return success
    	end
    end,
    permissions = {
        everyone = true,
    },
    usage = "ping",
    description = "Tests if the bot is alive and returns the message turnaround time",
    category = "General",
}

--lists members without roles
cmds['noroles'] = {
    id = "noroles",
    action = function(message, args)
		local predicate = function(member) return #member.roles == 0 end
		local list = {}
		for m in message.guild.members:findAll(predicate) do
			list[#list+1] = m.mentionString
		end
		local listInLines = " "
		for _,n in pairs(list) do
			if listInLines == " " then
				listInLines = n
			else
				listInLines = listInLines.."\n"..n
			end
		end
		local status
		if args ~= "" then
			status = message:reply(listInLines.."\n"..args)
		else
			status = message:reply(listInLines)
		end
        return status
    end,
    permissions = {
        botOwner = false,
        guildOwner = true,
        admin = true,
        mod = false,
        everyone = false,
    },
    usage = "noroles [message]",
    description = "Pings all members without any roles with an optional message",
    category = "Admin",
}

--serverinfo
cmds['serverinfo'] = {
    id = "serverinfo",
    action = function(message, args)
    	local guild = message.guild
    	if client:getGuild(args) then
    		guild = client:getGuild(args)
    	end
    	local humans, bots, online = 0,0,0
    	local invite
    	for member in guild.members:iter() do
    		if member.bot then
    			bots = bots+1
    		else
    			humans = humans+1
    		end
    		if not (member.status == 'offline') then
    			online = online+1
    		end
    	end
    	for inv in guild:getInvites():iter() do
    		if inv.inviter == guild.owner.user and not inv.temporary then
    			invite = inv
    		end
    	end
    	timestamp = humanReadableTime(parseTime(guild.timestamp):toTable())
        fields = {
            {name = 'ID', value = guild.id, inline = true},
            {name = 'Name', value = guild.name, inline = true},
            {name = 'Owner', value = guild.owner.mentionString, inline = true},
            {name = 'Region', value = guild.region, inline = true},
            {name = 'Total Channels', value = #guild.textChannels+#guild.voiceChannels, inline = true},
            {name = 'Text Channels', value = #guild.textChannels, inline = true},
            {name = 'Voice Channels', value = #guild.voiceChannels, inline = true},
            {name = 'Members', value = #guild.members, inline = true},
            {name = 'Humans', value = humans, inline = true},
            {name = 'Bots', value = bots, inline = true},
            {name = 'Online', value = online, inline = true},
            {name = 'Roles', value = #guild.roles, inline = true},
            {name = 'Emojis', value = #guild.emojis, inline = true},
        }
    	if invite then
            table.insert(fields, {name = 'Invite', value = "https://discord.gg/"..invite.code, inline = false})
        end
    	status = message.channel:send {
    		embed = {
    			author = {name = guild.name, icon_url = guild.iconURL},
    			fields = fields,
    			thumbnail = {url = guild.iconURL, height = 200, width = 200},
    			color = discordia.Color.fromRGB(244, 198, 200).value,
    			footer = { text = "Server Created : "..timestamp }
    		}
    	}
    	return status
    end,
    permissions = {
        everyone = true,
    },
    usage = "serverinfo",
    description = "Displays information on the server",
    category = "General",
}
cmds['si'] = cmds['serverinfo']
cmds['si'].usage = "si"
cmds['si'].id = "si"

--roleinfo
cmds['roleinfo'] = {
    id = "roleinfo",
    action = function(message, args)
    	local role = message.guild.roles:find(function(r) return r.name:lower() == args:lower() end)
    	if role then
    		local hex = string.match(role:getColor():toHex(), "%x+")
    		local count = 0
    		for m in message.guild.members:iter() do
    			if m:hasRole(role) then count = count + 1 end
    		end
    		local hoisted, mentionable
    		if role.hoisted then hoisted = "Yes" else hoisted = "No" end
    		if role.mentionable then mentionable = "Yes" else mentionable = "No" end
    		local status = message.channel:send {
    			embed = {
    				thumbnail = {url = "http://www.colorhexa.com/"..hex:lower()..".png", height = 150, width = 150},
    				fields = {
    					{name = "Name", value = role.name, inline = true},
    					{name = "ID", value = role.id, inline = true},
    					{name = "Hex", value = role:getColor():toHex(), inline = true},
    					{name = "Hoisted", value = hoisted, inline = true},
    					{name = "Mentionable", value = mentionable, inline = true},
    					{name = "Position", value = role.position, inline = true},
    					{name = "Members", value = count, inline = true},
    				},
    				color = role:getColor().value,
    			}
    		}
    		return status
    	end
    end,
    permissions = {
        everyone = true,
    },
    usage = "roleinfo <rolename>",
    description = "Displays information on the given role",
    category = "General",
}
cmds['ri'] = cmds['roleinfo']
cmds['ri'].usage = "ri <rolename>"
cmds['ri'].id = "ri"

--userinfo
cmds['userinfo'] = {
    id = "userinfo",
    action = function(message, args)
    	local guild = message.guild
    	local member
    	if args ~= "" then
    		if guild:getMember(parseMention(args)) then
    			member = guild:getMember(parseMention(args))
    		end
    	else
    		member = guild:getMember(message.author)
    	end
    	if member then
    		local roles = ""
    		for i in member.roles:iter() do
    			if roles == "" then roles = i.name else roles = roles..", "..i.name end
    		end
    		if roles == "" then roles = "None" end
    		local joinTime = humanReadableTime(parseTime(member.joinedAt):toTable())
    		local createTime = humanReadableTime(parseTime(member.timestamp):toTable())
    		local registerTime = parseTime(conn:execute(string.format([[SELECT registered FROM members WHERE member_id='%s';]], member.id)):fetch())
    		if registerTime ~= 'N/A' then
    			registerTime = registerTime:toTable()
    			registerTime = humanReadableTime(registerTime)
    		end
    		local status = message.channel:send {
    			embed = {
    				author = {name = member.username.."#"..member.discriminator, icon_url = member.avatarURL},
    				fields = {
    					{name = 'ID', value = member.id, inline = true},
    					{name = 'Mention', value = member.mentionString, inline = true},
    					{name = 'Nickname', value = member.name, inline = true},
    					{name = 'Status', value = member.status, inline = true},
    					{name = 'Joined', value = joinTime, inline = false},
    					{name = 'Created', value = createTime, inline = false},
    					{name = 'Registered', value = registerTime, inline = false},
                        {name = 'Extras', value = "[Fullsize Avatar]("..member.avatarURL..")", inline = false},
    					{name = 'Roles ('..#member.roles..')', value = roles, inline = false},
    				},
    				thumbnail = {url = member.avatarURL, height = 200, width = 200},
    				color = member:getColor().value,
    				timestamp = discordia.Date():toISO()
    			}
    		}
            return status
    	else
    		message.channel:send("Sorry, I couldn't find that user.")
    	end
    end,
    permissions = {
        everyone = true,
    },
    usage = "userinfo [@user|userID]",
    description = "Displays information on the given user or yourself if none mentioned",
    category = "General",
}
cmds['ui'] = cmds['userinfo']
cmds['ui'].usage = "ui [@user|userID]"
cmds['ui'].id = "ui"

cmds['modinfo'] = {
    id = "modinfo",
    action = function(message, args)
        guild = message.guild
    	local member
    	if args ~= "" then
    		if guild:getMember(parseMention(args)) then
    			member = guild:getMember(parseMention(args))
    		end
    	else
    		member = guild:getMember(message.author)
    	end
    	if member then
            local watchlisted = conn:execute(string.format([[SELECT watchlisted FROM members WHERE member_id='%s';]], member.id)):fetch()
            local under18 = conn:execute(string.format([[SELECT under18 FROM members WHERE member_id='%s';]], member.id)):fetch()
            if watchlisted == 'f' then watchlisted = 'No' else watchlisted = 'Yes' end
            if under18 == 'f' then under18 = 'No' else under18 = 'Yes' end
            status = message:reply {
                embed = {
                    author = {name = member.username.."#"..member.discriminator, icon_url = member.avatarURL},
                    fields = {
                        {name = "Watchlisted", value = watchlisted, inline = true},
                        {name = "Under 18", value = under18, inline = true},
                    },
                    thumbnail = {url = member.avatarURL, height = 200, width = 200},
    				color = member:getColor().value,
    				timestamp = discordia.Date():toISO()
                }
            }
            return status
        end
    end,
    permissions = {
        botOwner = false,
        guildOwner = true,
        admin = true,
        mod = true,
        everyone = false,
    },
    usage = "modinfo <@user|userID>",
    description = "Displays mod-relevant data, such as watchlist status, on the given user",
    category = "Mod",
}
cmds['mi'] = cmds['modinfo']
cmds['mi'].usage = "mi <@user|userID>"
cmds['mi'].id = "mi"

--addRole: Mod Function only!
cmds['ar'] = {
    id = "ar",
    action = function(message, args)
    	local roles, member = parseRoleList(message)
    	local author = message.guild:getMember(message.author.id)
    	if member then
    		local rolesToAdd = {}
    		for _,role in pairs(roles) do
    			for r in message.guild.roles:iter() do
    				if string.lower(role) == string.lower(r.name) then
    					rolesToAdd[#rolesToAdd+1] = r
    				end
    			end
    		end
    		for _,role in ipairs(rolesToAdd) do
    			member:addRole(message.guild:getRole(role.id))
    		end
    		local roleList = ""
    		for _,r in ipairs(rolesToAdd) do
    			roleList = roleList..r.name.."\n"
    		end
    		if #rolesToAdd > 0 then
    			local status = message.channel:send {
    				embed = {
    					author = {name = "Roles Added", icon_url = member.avatarURL},
    					description = "**Added "..member.mentionString.." to the following roles** \n"..roleList,
    					color = member:getColor().value,
    					timestamp = discordia.Date():toISO(),
    					footer = {text = "ID: "..member.id}
    				}
    			}
    			return status
    		end
    	end
    end,
    permissions = {
        botOwner = false,
        guildOwner = true,
        admin = true,
        mod = false,
        everyone = false,
    },
    usage = "ar <@user|userID> <role[, role, ...]>",
    description = "Adds the mentioned user to the listed role(s)",
    category = "Admin",
}

--removeRole: Mod function only!
cmds['rr'] = {
    id = "rr",
    action = function(message, args)
    	local roles, member = parseRoleList(message)
    	local author = message.guild:getMember(message.author.id)
    	if member then
    		local rolesToRemove = {}
    		for _,role in pairs(roles) do
    			for r in message.guild.roles:iter() do
    				if string.lower(role) == string.lower(r.name) then
    					rolesToRemove[#rolesToRemove+1] = r
    				end
    			end
    		end
    		for _,role in ipairs(rolesToRemove) do
    			member:removeRole(member.guild:getRole(role.id))
    		end
    		local roleList = ""
    		for _,r in ipairs(rolesToRemove) do
    			roleList = roleList..r.name.."\n"
    		end
    		if #rolesToRemove > 0 then
    			local status = message.channel:send {
    				embed = {
    					author = {name = "Roles Removed", icon_url = member.avatarURL},
    					description = "**Removed "..member.mentionString.." from the following roles** \n"..roleList,
    					color = member:getColor().value,
    					timestamp = discordia.Date():toISO(),
    					footer = {text = "ID: "..member.id}
    				}
    			}
    			return status
    		end
    	end
    end,
    permissions = {
        botOwner = false,
        guildOwner = true,
        admin = true,
        mod = false,
        everyone = false,
    },
    usage = "rr <@user|userID> <role[, role, ...]>",
    description = "Removes the mentioned user from the listed role(s)",
    category = "Admin"
}

--Register, same as ar but removes Not Verified
cmds['register'] = {
    id = "register",
    action = function(message)
    	local channel = message.guild:getChannel(message.guild._settings.modlog_channel)
    	local roles, member = parseRoleList(message)
    	local author = message.guild:getMember(message.author.id)
    	if member then
    		local rolesToAdd = {}
    		local hasGender, hasPronouns
    		for _,role in pairs(roles) do
    			for k,l in pairs(selfRoles) do
    				for r,a in pairs(l) do
    					if string.lower(role) == string.lower(r)  or (table.search(a, string.lower(role))) then
    						if (r == 'Gamer') or (r == '18+') or not (k == 'Opt-In Roles') then
    							rolesToAdd[#rolesToAdd+1] = r
    						end
    					end
    				end
    			end
    		end
    		for k,l in pairs(selfRoles) do
    			for _,j in pairs(rolesToAdd) do
    				if (k == 'Gender Identity') then
    					for r,_ in pairs(l) do
    						if r == j then hasGender = true end
    					end
    				end
    				if (k == 'Pronouns') then
    					for r,_ in pairs(l) do
    						if r == j then hasPronouns = true end
    					end
    				end
    			end
    		end
    		if hasGender and hasPronouns then
    			for _,role in pairs(rolesToAdd) do
    				function fn(r) return r.name == role end
    				member:addRole(member.guild.roles:find(fn))
    			end
    			function makeRoleList(roles)
    				local roleList = ""
    				for _,r in ipairs(roles) do
    					roleList = roleList..r.."\n"
    				end
    				return roleList
    			end
    			member:addRole(member.guild:getRole('348873284265312267'))
    			if #rolesToAdd > 0 then
    				channel:send {
    					embed = {
    						author = {name = "Registered", icon_url = member.avatarURL},
    						description = "**Registered "..member.mentionString.." with the following roles** \n"..makeRoleList(rolesToAdd),
    						color = member:getColor().value,
    						timestamp = discordia.Date():toISO(),
    						footer = {text = "ID: "..member.id}
    					}
    				}
    				client:emit('memberRegistered', member)
    				local status, err = conn:execute(string.format([[UPDATE members SET registered='%s' WHERE member_id='%s';]], discordia.Date():toISO(), member.id))
    				return status
    			end
    		else
    			message:reply("Invalid registration command. Make sure to include at least one of gender identity and pronouns.")
    		end
    	end
    end,
    permissions = {
        botOwner = false,
        guildOwner = true,
        admin = true,
        mod = true,
        everyone = false,
    },
    usage = "register <@user|userID> <role[, role, ...]>",
    description = "Registers the mentioned user with the listed roles",
    category = "Mod",
}
cmds['reg'] = cmds['register']
cmds['reg'].usage = "reg <@user|userID> <role[, role, ...]>"
cmds['reg'].id = "reg"

--addSelfRole
cmds['role'] = {
    id = "role",
    action = function(message)
    	local roles = parseRoleList(message)
    	local member = message.guild:getMember(message.author)
    	local rolesToAdd = {}
    	local rolesFailed = {}
    	for i,role in ipairs(roles) do
    		for k,l in pairs(selfRoles) do
    			for r,a in pairs(l) do
    				if string.lower(role) == string.lower(r)  or (table.search(a, string.lower(role))) then
    					if member:hasRole(member.guild:getRole('348873284265312267')) and (k == 'Opt-In Roles') then
    						if (r == 'Gamer') or (r == '18+') or (r == 'Momiji Dev') or (r == 'D&D') then
    							rolesToAdd[#rolesToAdd+1] = r
    						else rolesFailed[#rolesFailed+1] = r.." is only available after cooldown" end
    					elseif (member:hasRole(member.guild:getRole('349051015758348289')) or member:hasRole(member.guild:getRole('349051017226354729'))) and (k == 'Opt-In Roles') then
    						if not (r == 'NSFW-Selfies' or r == 'NSFW-Nb' or r == 'NSFW-Fem' or r == 'NSFW-Masc') then
    							rolesToAdd[#rolesToAdd+1] = r
    						else rolesFailed[#rolesFailed+1] = r.." is not available to cis people" end
    					else
    						rolesToAdd[#rolesToAdd+1] = r
    					end
    				end
    			end
    		end
    	end
    	local rolesAdded = {}
    	for _,role in ipairs(rolesToAdd) do
    		function fn(r) return r.name == role end
    		if not member:hasRole(member.guild.roles:find(fn)) then
    			rolesAdded[#rolesAdded+1] = role
    			member:addRole(member.guild.roles:find(fn))
    		else rolesFailed[#rolesFailed+1] = "You already have "..role end
    	end
    	function makeRoleList(roles)
    		local roleList = ""
    		for _,r in ipairs(roles) do
    			roleList = roleList..r.."\n"
    		end
    		return roleList
    	end
    	local status
    	if #rolesAdded > 0 then
    		status = message.channel:send {
    			embed = {
    				author = {name = "Roles Added", icon_url = member.avatarURL},
    				description = "**Added "..member.mentionString.." to the following roles** \n"..makeRoleList(rolesAdded),
    				color = member:getColor().value,
    				timestamp = discordia.Date():toISO(),
    				footer = {text = "ID: "..member.id}
    			}
    		}
    	end
    	if #rolesFailed > 0 then
    		message.channel:send {
    			embed = {
    				author = {name = "Roles Failed to be Added", icon_url = member.avatarURL},
    				description = "**Failed to add the following roles to** "..member.mentionString.."\n"..makeRoleList(rolesFailed),
    				color = member:getColor().value,
    				timestamp = discordia.Date():toISO(),
    				footer = {text = "ID: "..member.id}
    			}
    		}
    	end
    	return status
    end,
    permissions = {
        everyone = true,
    },
    usage = "role <role[, role, ...]>",
    description = "Adds the listed role(s) to yourself from the self role list",
    category = "General",
}

--removeSelfRole
cmds['derole'] = {
    id = "derole",
    action = function(message)
    	local roles = parseRoleList(message)
    	local member = message.guild:getMember(message.author)
    	local rolesToRemove = {}
    	for _,role in pairs(roles) do
    		for _,l in pairs(selfRoles) do
    			for r,a in pairs(l) do
    				if (string.lower(role) == string.lower(r)) or (table.search(a, string.lower(role))) then
    					rolesToRemove[#rolesToRemove+1] = r
    				end
    			end
    		end
    	end
    	for _,role in ipairs(rolesToRemove) do
    		function fn(r) return r.name == role end
    		member:removeRole(member.guild.roles:find(fn))
    	end
    	function makeRoleList(roles)
    		local roleList = ""
    		for _,r in ipairs(roles) do
    			roleList = roleList..r.."\n"
    		end
    		return roleList
    	end
    	if #rolesToRemove > 0 then
    		local status = message.channel:send {
    			embed = {
    				author = {name = "Roles Removed", icon_url = member.avatarURL},
    				description = "**Removed "..member.mentionString.." from the following roles** \n"..makeRoleList(rolesToRemove),
    				color = member:getColor().value,
    				timestamp = discordia.Date():toISO(),
    				footer = {text = "ID: "..member.id}
    			}
    		}
    		return status
    	end
    end,
    permissions = {
        everyone = true,
    },
    usage = "derole <role[, role, ...]>",
    description = "Removes the listed role(s) from yourself from the self role list",
    category = "General",
}

--roleList
cmds['roles'] = {
    id = "roles",
    action = function(message, args)
    	local roleList = {}
    	for k,v in pairs(selfRoles) do
    		for r,_ in pairs(v) do
    			if not roleList[k] then
    				roleList[k] = r.."\n"
    			else
    				roleList[k] = roleList[k]..r.."\n"
    			end
    		end
    	end
    	local status = message.channel:send {
    		embed = {
    			author = {name = "Self-Assignable Roles", icon_url = message.guild.iconURL},
    			fields = {
    				{name = "Gender Identity*", value = roleList['Gender Identity'], inline = true},
    				{name = "Sexuality", value = roleList['Sexuality'], inline = true},
    				{name = "Pronouns*", value = roleList['Pronouns'], inline = true},
    				{name = "Presentation", value = roleList['Presentation'], inline = true},
    				{name = "Assigned Sex", value = roleList['Assigned Sex'], inline = true},
    				{name = "Opt-In Roles", value = roleList['Opt-In Roles'], inline = true},
    			},
    			color = discordia.Color.fromRGB(244, 198, 200).value,
    			timestamp = discordia.Date():toISO(),
    			footer = {text = "* One or more required in this category"}
    		}
    	}
    	return status
    end,
    permissions = {
        everyone = true,
    },
    usage = "roles",
    description = "Displays the self role list",
    category = "General",
}

--Mute: Mod only
cmds['mute'] = {
    id = "mute",
    action = function(message, args)
    	local author = message.author
		local logChannel = message.guild:getChannel(message.guild._settings.modlog_channel)
		local success, member, channel
		local reason = ""
		if #message.mentionedUsers == 1 then
			channel = message.mentionedChannels:iter()()
			member = message.guild:getMember(message.mentionedUsers:iter()())
			if member and not channel then
				success = member:addRole('349060739815964673')
				message.channel:send("Muting "..member.mentionString.." server-wide")
			elseif member and channel then
				success = channel:getPermissionOverwriteFor(member):denyPermissions(enums.permission.sendMessages, enums.permission.addReactions)
				message.channel:send("Muting "..member.mentionString.." in "..channel.mentionString)
			end
			if args ~= "" then
				if member and channel then
					reason = args:gsub("<@.+>", ""):gsub("<#.+>", "")
				elseif member then
					reason = args:gsub("<@.+>", "")
				end
			end
		end
		if reason == "" then reason = "None" end
		if success then
			logChannel:send {
				embed = {
					title = "Member Muted",
					fields = {
						{name = "User", value = member.mentionString, inline = true},
						{name = "Moderator", value = message.author.mentionString, inline = true},
						{name = "Reason", value = reason, inline = true},
					},
				}
			}
		end
		return success
    end,
    permissions = {
        botOwner = false,
        guildOwner = true,
        admin = true,
        mod = true,
        everyone = false,
    },
    usage = "mute [#channel] <@user|userID>",
    description = "Mutes the mentioned user in the given channel, if provided, or server-wide",
    category = "Mod",
}

--Unmute, counterpart to above
cmds['unmute'] = {
    id = "unmute",
    action = function(message, args)
        local author = message.author
		local logChannel = message.guild:getChannel(message.guild._settings.modlog_channel)
		local success, member, channel
		if #message.mentionedUsers == 1 then
			channel = message.mentionedChannels:iter()()
			member = message.guild:getMember(message.mentionedUsers:iter()())
			if member and not channel then
				success = member:removeRole('349060739815964673')
				message.channel:send("Unmuting "..member.mentionString.." server-wide")
			elseif member and channel then
				if channel:getPermissionOverwriteFor(member) then
					success = channel:getPermissionOverwriteFor(member):delete()
				end
				message.channel:send("Unmuting "..member.mentionString.." in "..channel.mentionString)
			end
		end
		if success then
			logChannel:send {
				embed = {
					title = "Member Unmuted",
					fields = {
						{name = "User", value = member.mentionString, inline = true},
						{name = "Moderator", value = message.author.mentionString, inline = true},
					},
				}
			}
		end
		return success
    end,
    permissions = {
        botOwner = false,
        guildOwner = true,
        admin = true,
        mod = true,
        everyone = false,
    },
    usage = "unnmute [#channel] <@user|userID>",
    description = "Attempts to unmute the mentioned user in the given channel, if provided, or server-wide",
    category = "Mod",
}

--sets up mute in every text channel. currently broken due to 2.0
function setupMute(message)
	if message.author == message.guild.owner then
		local role = message.guild:getRole('name', 'Muted')
		for channel in message.guild.textChannels do
			channel:getPermissionOverwriteFor(role):denyPermissions('sends', 'addReactions')
		end
	end
end
--commands:on('setupmute', function(m, a) safeCall(setupMute, m, a) end)

--bulk delete command
cmds['prune'] = {
    id = "prune",
    action = function(message, args)
    	local logChannel = message.guild:getChannel(message.guild._settings.modlog_channel)
    	local author = message.guild:getMember(message.author.id)
		local messageDeletes = client:getListeners('messageDelete')
		local messageDeletesUncached = client:getListeners('messageDeleteUncached')
		client:removeAllListeners('messageDelete')
		client:removeAllListeners('messageDeleteUncached')
		message:delete()
		if tonumber(args) > 0 then
			args = tonumber(args)
			local xHun, rem = math.floor(args/100), math.fmod(args, 100)
			local numDel = 0
			if xHun > 0 then
				for i=1, xHun do
					deletions = message.channel:getMessages(100)
					success = message.channel:bulkDelete(deletions)
					numDel = numDel+#deletions
				end
			end
			if rem > 0 then
				deletions = message.channel:getMessages(rem)
				success = message.channel:bulkDelete(deletions)
				numDel = numDel+#deletions
			end
			logChannel:send {
				embed = {
					description = "Moderator "..author.mentionString.." deleted "..numDel.." messages in "..message.channel.mentionString,
					color = discordia.Color.fromRGB(255, 0, 0).value,
					timestamp = discordia.Date():toISO()
				}
			}
		end
		for listener in messageDeletes do
			client:on('messageDelete', listener)
		end
		for listener in messageDeletesUncached do
			client:on('messageDeleteUncached', listener)
		end
    end,
    permissions = {
        botOwner = false,
        guildOwner = true,
        admin = true,
        mod = false,
        everyone = false,
    },
    usage = "prune <number>",
    description = "Deletes the specified number of messages from the current channel",
    category = "Admin",
}

--manually ensure all members are present in the db. should be deprecated
cmds['populate'] = {
    id = "populate",
    action = function(message)
		local guild = message.guild
		for member in guild.members:iter() do
			local status, err = conn:execute(string.format([[INSERT INTO members (member_id, nicknames) VALUES ('%s','{"%s"}');]], member.id, member.name))
		end
		return status
    end,
    permissions = {
        botOwner = false,
        guildOwner = true,
        admin = false,
        mod = false,
        everyone = false,
    },
    usage = "populate",
    description = "Manually ensures all guild members are loaded into the members table",
    category = "Guild Owner",
}

--list all watchlisted members
cmds['listwl'] = {
    id = "listwl",
    action = function(message, args)
		local cur = conn:execute([[SELECT member_id FROM members WHERE watchlisted=true;]])
		local row = cur:fetch({}, "a")
		local success = row ~= nil or false
		local members = {}
		while row do
			table.insert(members, row.member_id)
			row = cur:fetch(row, "a")
		end
		if members then
			local list = "**Count: "..#members.."**"
			for _,m in pairs(members) do
				local member = message.guild:getMember(m)
				if list ~= "" then list = list.."\n"..member.username.."#"..member.discriminator..":"..member.mentionString else list = member.username.."#"..member.discriminator..":"..member.mentionString end
			end
			message:reply {
				embed = {
					title = "Watchlisted Members",
					description = list,
				}
			}
		else
			message:reply("No members are watchlisted.")
		end
		return success
    end,
    permissions = {
        botOwner = false,
        guildOwner = true,
        admin = true,
        mod = true,
        everyone = false,
    },
    usage = "listwl",
    description = "Lists all watchlisted users",
    category = "Mod",
}

--toggles the watchlist state for a member
cmds['wl'] = {
    id = "wl",
    action = function(message, args)
		local member = message.guild:getMember(parseMention(args))
		if member then
			local success
			local currentVal = conn:execute(string.format([[SELECT watchlisted FROM members WHERE member_id='%s';]], member.id)):fetch()
			if currentVal == 'f' then
				success = conn:execute(string.format([[UPDATE members SET watchlisted=true WHERE member_id='%s';]], member.id))
			else
				success = conn:execute(string.format([[UPDATE members SET watchlisted=false WHERE member_id='%s';]], member.id))
			end
			return success
    	end
    end,
    permissions = {
        botOwner = false,
        guildOwner = true,
        admin = true,
        mod = true,
        everyone = false,
    },
    usage = "wl <@user|userID>",
    description = "Add or remove the mentioned user from the watchlist",
    category = "Mod",
}

--toggles the under18 state for a member
cmds['t18'] = {
    id = "t18",
    action = function(message, args)
		local member = message.guild:getMember(parseMention(args))
		if member then
			local success
			local currentVal = conn:execute(string.format([[SELECT under18 FROM members WHERE member_id='%s';]], member.id)):fetch()
			if currentVal == 'f' then
				success = conn:execute(string.format([[UPDATE members SET under18=true WHERE member_id='%s';]], member.id))
			else
				success = conn:execute(string.format([[UPDATE members SET under18=false WHERE member_id='%s';]], member.id))
			end
			return success
		end
    end,
    permissions = {
        botOwner = false,
        guildOwner = true,
        admin = true,
        mod = true,
        everyone = false,
    },
    usage = "t18 <@user|userID>",
    description = "Add or remove the Under 18 flag from the mentioned user",
    category = "Mod",
}

--[[ Note Functions ]]
cmds['note'] = {
    id = "note",
    action = function(message, args)
	    local a = message.guild:getMember(message.author.id)
	    local m
	    if message.mentionedUsers then
	        if #message.mentionedUsers == 1 then
	            m = message.mentionedUsers:iter()()
	            args = args:gsub("<@.+>",""):trim()
	        else
				m = message.guild:getMember(args:match("%d+"))
				args = args:gsub(m.id,""):trim()
			end
	    end
	    if (args == "") or not m then return end
        local success, err
        if args:startswith("add") then
            args = args:gsub("^add",""):trim()
    	    success, err = conn:execute(string.format([[INSERT INTO notes (user_id, note, moderator, timestamp) VALUES ('%s', '%s', '%s', '%s');]], m.id, args, a.username, discordia.Date():toISO()))
        elseif args:startswith("del") then
            args = args:gsub("^del",""):trim()
            success, err = conn:execute(string.format([[DELETE FROM notes WHERE user_id='%s';]], m.id))
        elseif args:startswith("view") then
            args = args:gsub("^view",""):trim()
            local notelist = {}
    	    local cur = conn:execute(string.format([[SELECT * FROM notes WHERE user_id='%s';]], m.id))
    		local row = cur:fetch({},"a")
    		while row do
    			table.insert(notelist, {name = "Note Added by: "..row.moderator, value = row.note})
    			row = cur:fetch(row, "a")
    		end
    		success = message:reply {
    			embed = {
    				title = "Notes for "..m.username,
    				fields = notelist,
    			}
    		}
        else
            message:reply("Please specify add, del, or view")
        end
        if err then print(err) end
		return success
    end,
    permissions = {
        botOwner = false,
        guildOwner = true,
        admin = true,
        mod = true,
        everyone = false,
    },
    usage = "note <add|del|view> <@user|userID> <note>",
    description = "Add the note to, delete a note from, or view all notes for the mentioned user",
    category = "Mod",
}

cmds['lua'] = {
    id = "lua",
    action = function(message, args)
    	if not args:startswith("```") then return end
    	args = string.match(args, "```(.+)```"):gsub("lua", ""):trim()
    	printresult = ""
        utils = {
        	days = days,
        	months = months,
        	sqlStringToTable = sqlStringToTable,
        	parseMention = parseMention,
        	parseTime = parseTime,
        	parseChannel = parseChannel,
        	humanReadableTime = humanReadableTime,
        }
    	sandbox = {
    		discordia = discordia,
    		client = client,
    		enums = enums,
    		conn = conn,
            cmds = cmds,
    		message = message,
    		utils = utils,
    		printresult = printresult,
    		print = function(...)
    			arg = {...}
    			for i,v in ipairs(arg) do
    				printresult = printresult..tostring(v).."\t"
    			end
    			printresult = printresult.."\n"
    		end,
    		json = require'json',
    		require = require,
    		ipairs = ipairs,
    		pairs = pairs,
    		pcall = pcall,
    		tonumber = tonumber,
    		tostring = tostring,
    		type = type,
    		unpack = unpack,
    		select = select,
    		string = string,
    		table = table,
    		math = math,
    		io = io,
    		os = os,
    	}
    	function runSandbox(sandboxEnv, sandboxFunc, ...)
    		if not sandboxFunc then return end
    		setfenv(sandboxFunc,sandboxEnv)
    		return pcall(sandboxFunc, ...)
    	end
    	status, ret = runSandbox(sandbox, loadstring(args))
    	if not ret then ret = printresult else ret = ret.."\n"..printresult end
    	if ret ~= "" and #ret < 1800 then
            message:reply("```"..ret.."```")
        elseif ret ~= "" then
            ret1 = ret:sub(0,1800)
            ret2 = ret:sub(1801)
            message:reply("```"..ret1.."```")
            message:reply("```"..ret2.."```")
        end
    	return status
    end,
    permissions = {
        botOwner = true,
        guildOwner = false,
        admin = false,
        mod = false,
        everyone = false,
    },
    usage = "lua <code in a markdown codeblock>",
    description = "Run arbitrary lua code",
    category = "Bot Owner",
}

cmds['todo'] = {
    id = "todo",
    action = function(message, args)
        todo = readAll('TODO.md')
        status = message:reply("```markdown\n"..todo.."```")
        return status
    end,
    permissions = {
        botOwner = true,
        guildOwner = false,
        admin = false,
        mod = false,
        everyone = false,
    },
    usage = "todo",
    description = "View the github TODO.md via discord",
    category = "Bot Owner",
}

--Logging functions
--Member join message
function memberJoin(member)
	local channel = member.guild:getChannel(member.guild._settings.log_channel)
	local status, err = conn:execute(string.format([[INSERT INTO members (member_id, nicknames) VALUES ('%s', '{"%s"}');]], member.id, member.name))
	if channel then
		channel:send {
			embed = {
				author = {name = "Member Joined", icon_url = member.avatarURL},
				description = member.mentionString.." "..member.username.."#"..member.discriminator,
				thumbnail = {url = member.avatarURL, height = 200, width = 200},
				color = discordia.Color.fromRGB(0, 255, 0).value,
				timestamp = discordia.Date():toISO(),
				footer = {text = "ID: "..member.id}
			}
		}
	end
end
--Member leave message
function memberLeave(member)
	local channel = member.guild:getChannel(member.guild._settings.log_channel)
	local status, err = conn:execute(string.format([[DELETE FROM members WHERE member_id='%s';]], member.id))
	if channel then
		channel:send {
			embed = {
				author = {name = "Member Left", icon_url = member.avatarURL},
				description = member.mentionString.." "..member.username.."#"..member.discriminator,
				thumbnail = {url = member.avatarURL, height = 200, width = 200},
				color = discordia.Color.fromRGB(255, 0, 0).value,
				timestamp = discordia.Date():toISO(),
				footer = {text = "ID: "..member.id}
			}
		}
	end
end
client:on('memberJoin', function(member) memberJoin(member) end)
client:on('memberLeave', function(member) memberLeave(member) end)
--Ban message
function userBan(user, guild)
	local member = guild:getMember(user) or user
	local channel = guild:getChannel(member.guild._settings.modlog_channel)
	if channel and member then
		channel:send {
			embed = {
				author = {name = "Member Banned", icon_url = member.avatarURL},
				description = member.mentionString.." "..member.username.."#"..member.discriminator,
				thumbnail = {url = member.avatarURL, height = 200, width = 200},
				color = discordia.Color.fromRGB(255, 0, 0).value,
				timestamp = discordia.Date():toISO(),
				footer = {text = "ID: "..member.id}
			}
		}
	end
end
--Unban message
function userUnban(user, guild)
	local member = guild:getMember(user) or user
	local channel = guild:getChannel(member.guild._settings.modlog_channel)
	if channel and member then
		channel:send {
			embed = {
				author = {name = "Member Unbanned", icon_url = member.avatarURL},
				description = member.mentionString.." "..member.username.."#"..member.discriminator,
				thumbnail = {url = member.avatarURL, height = 200, width = 200},
				color = discordia.Color.fromRGB(255, 0, 0).value,
				timestamp = discordia.Date():toISO(),
				footer = {text = "ID: "..member.id}
			}
		}
	end
end
client:on('userBan', function(user, guild) userBan(user, guild) end)
client:on('userUnban', function(user, guild) userUnban(user, guild) end)
--Cached message deletion
function messageDelete(message)
	local member = message.guild:getMember(message.author.id)
	local logChannel = message.guild:getChannel(message.guild._settings.log_channel)
	if logChannel and member then
		logChannel:send {
			embed = {
				author = {name = member.username.."#"..member.discriminator, icon_url = member.avatarURL},
				description = "**Message sent by "..member.mentionString.." deleted in "..message.channel.mentionString.."**\n"..message.content,
				color = discordia.Color.fromRGB(255, 0, 0).value,
				timestamp = discordia.Date():toISO(),
				footer = {text = "ID: "..member.id}
			}
		}
	end
end
--Uncached message deletion
function messageDeleteUncached(channel, messageID)
	local logChannel = message.guild:getChannel(channel.guild._settings.log_channel)
	if logChannel then
		logChannel:send {
			embed = {
				author = {name = channel.guild.name, icon_url = channel.guild.iconURL},
				description = "**Uncached message deleted in** "..channel.mentionString,
				color = discordia.Color.fromRGB(255, 0, 0).value,
				timestamp = discordia.Date():toISO(),
				footer = {text = "ID: "..channel.id}
			}
		}
	end
end
client:on('messageDelete', function(message) messageDelete(message) end)
client:on('messageDeleteUncached', function(channel, messageID) messageDeleteUncached(channel, messageID) end)

--populate the commands
for key, tbl in pairs(cmds) do
    if type(tbl) == "table" then
        commands:on(key, function(m,a) safeCall(tbl.action,m,a) end)
    else
        print("Invalid command format", key)
    end
end
client:run(token)
