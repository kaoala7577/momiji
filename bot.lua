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
local selfRoles = require'rolelist'

--Involved in date-time parsing
local days = {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"}
local months = {"January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"}

--luasql.postgres returns individual objects as strings, this lets us convert those to lua tables
local function sqlStringToTable(str)
	if str:startswith('{') and str:endswith('}') then
		str = string.gsub(str, "[{}]", "")
		return str:split(',')
	end
	return
end

--[[ init functions: load per-guild settings and ensure that all members are cached in the members table ]]
client:on('ready', function()
	print('Logged in as '.. client.user.username)
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
			conn:execute(string.format([[INSERT INTO members (member_id, nicknames) VALUES ('%s','{"%s"}');]], member.id, member.name))
		end
	end
end)

--[[ Takes string that might be a user mention, returns the userID if it is ]]
local function parseMention(mention)
	return string.match(mention, "%<%@%!(%d+)%>") or string.match(mention, "%<%@(%d+)%>") or mention
end

--[[ Takes a string that might be a channel mention, returns channelID if it is ]]
local function parseChannel(mention)
	return string.match(mention, "%<%#(%d+)%>") or mention
end

--[[ creates a Date object with the given ISO-format time if valid, otherwise returns the original string ]]
local function parseTime(time)
	if time:match('(%d+)-(%d+)-(%d+).(%d+):(%d+):(%d+)(.*)') then return discordia.Date.fromISO(time) else return time end
end

--[[ takes a date table in the format of os.date("*t"), returns human readable ]]
local function humanReadableTime(table)
	if #tostring(table.min) == 1 then table.min = "0"..table.min end
	if #tostring(table.hour) == 1 then table.hour = "0"..table.hour end
	return days[table.wday]..", "..months[table.month].." "..table.day..", "..table.year.." at "..table.hour..":"..table.min or table
end

--[[ used by the role functions, splits a user mention from the comma-separated role list ]]
local function parseRoleList(message)
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
local function authorize(message, admins, mods)
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
local function safeCall(func, message, args)
	local status, ret = xpcall(func, debug.traceback, message, args)
	if ret and not status then
		local channel = message.guild:getChannel('364148499715063818')
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
local function commandParser(message)
	if message.author ~= client.user then
		if message.channel.type == enums.channelType.text then
			if message.content:startswith("%"..message.guild._settings.prefix) then
				local str = message.content:match("^%"..message.guild._settings.prefix.."(%g+)%s*")
				local args = message.content:gsub("^%"..message.guild._settings.prefix..str, ""):trim()
				commands:emit(str:lower(), message, args)
			end
		else
			message:reply("I'm not currently set up to handle private messages")
		end
	end
end
client:on('messageCreate', function(m) commandParser(m) end)

--[[ Silly test func, changes based on what I need to test ]]
local function test(message, args)
	if args ~= "" then
		if #message.mentionedUsers == 1 then
			local success = message:reply(message.mentionedUsers:iter()().name)
			return success
		end
	end
end
commands:on('test', function(m, a) safeCall(test, m, a) end)

--stupid color changing function to learn how to hook callbacks to the clock
local function changeColor(time)
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
				local date = parseTime(conn:execute(string.format([[SELECT registered FROM members WHERE member_id='%s';]], member.id)):fetch())
				if date ~= 'N/A' then
					date = date:toTable()
					if (time.day > date.day) and (time.hour >= date.hour) and (time.min >= date.min) then
						member:addRole('348693274917339139')
						member:removeRole('348873284265312267')
					end
				end
			end
		end
	end
end)

--Change the bot username. Owner only
local function changeUsername(message, args)
	if args ~= "" then
		if message.author == client.owner then
			local success = client:setUsername(args)
			return status
		else
			message.author:send("Only the bot owner can do that.")
		end
	else
		message.author:send("You need to specify a new name.")
	end
end
commands:on('uname', function(m, a) safeCall(changeUsername, m, a) end)

--Change the bot nickname. Guild owner only
local function nick(message, args)
	if args ~= "" then
		if authorize(message, true, true) then
			local success = message.guild:getMember(client.user):setNickname(args)
			return success
		else
			message.author:send("Only moderators can do that.")
		end
	else
		message.author:send("You need to specify a new name.")
	end
end
commands:on('nick', function(m, a) safeCall(nick, m, a) end)

--make Spam! Owner Only
local function genSpam(message, args)
	if args ~= "" then
		if message.author == client.owner then
			if tonumber(args) > 0 then
				for i=1, tonumber(args)-1 do message:reply("Awoo!") end
				local success = message:reply("Final Awoo!")
				return status
			end
		else message.author:send("Only the bot owner can do that.") end
	else message.author:send("You need to specify an amount.") end
end
commands:on('genspam', function(m, a) safeCall(genSpam, m, a) end)

--Help page.... total shit
local function helpMessage(message)
	local success = message.author:send([[**How to read this doc:**
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
`.genspam <number>`: sends a number of spam messages. used for testing
`.uname <name>`: sets the bot's username]])
	return status
end
commands:on('help', function(m, a) safeCall(helpMessage, m, a) end)

--Update last_message in members table. not used yet
client:on('messageCreate', function(message)
	if message.channel.type == enums.channelType.text then
		local status, err = conn:execute(string.format([[UPDATE members SET last_message='%s' WHERE member_id='%s';]], discordia.Date():toISO(), message.member.id))
	end
end)

--change prefix
local function changePrefix(message, args)
	if args ~= "" then
		if message.member == message.guild.owner then
			local status, err = conn:execute(string.format([[UPDATE settings SET prefix='%s' WHERE guild_id='%s';]], args, message.guild.id))
			if status then
				local curr = conn:execute(string.format([[SELECT * FROM settings WHERE guild_id='%s';]], message.guild.id))
				local row = curr:fetch({}, "a")
				message.guild._settings.prefix = row.prefix
				return status
			end
		end
	end
end
commands:on('prefix', function(m,a) safeCall(changePrefix, m, a) end)

--ping
local function ping(message)
	local sw = discordia.Stopwatch()
	sw:reset()
	local response = message:reply("Pong!")
	if response then
		sw:stop()
		local success = response:setContent("Pong!".."`"..math.round(sw.milliseconds).." ms`")
		return success
	end
end
commands:on('ping', function(m,a) safeCall(ping, m, a) end)

--lists members without roles
local function noRoles(message, args)
	local authorized = authorize(message, true, false)
	if authorized then
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
		local reply
		if args ~= "" then
			message:reply(listInLines.."\n"..args)
		else
			message:reply(listInLines)
		end
	end
end
commands:on('noroles', function(m,a) safeCall(noRoles, m, a) end)

--serverinfo
local function serverInfo(message, args)
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
	local status
	if invite then
		status = message.channel:send {
			embed = {
				author = {name = guild.name, icon_url = guild.iconURL},
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
					{name = 'Invite', value = "https://discord.gg/"..invite.code, inline = false},
				},
				thumbnail = {url = guild.iconURL, height = 200, width = 200},
				color = discordia.Color.fromRGB(244, 198, 200).value,
				footer = { text = "Server Created : "..timestamp }
			}
		}
	else
		status = message.channel:send {
			embed = {
				author = {name = guild.name, icon_url = guild.iconURL},
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
				},
				thumbnail = {url = guild.iconURL, height = 200, width = 200},
				color = discordia.Color.fromRGB(244, 198, 200).value,
				footer = { text = "Server Created : "..timestamp }
			}
		}
	end
	return status
end
commands:on('serverinfo', function(m, a) safeCall(serverInfo, m, a) end)
commands:on('si', function(m, a) safeCall(serverInfo, m, a) end)

--roleinfo
local function roleInfo(message, args)
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
end
commands:on('roleinfo', function(m, a) safeCall(roleInfo, m, a) end)
commands:on('ri', function(m, a) safeCall(roleInfo, m, a) end)

--User functions
--userinfo
local function userInfo(message, args)
	local guild = message.guild
	local member = guild:getMember(message.author)
	if guild:getMember(parseMention(args)) then
		member = guild:getMember(parseMention(args))
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
		local watchlisted = conn:execute(string.format([[SELECT watchlisted FROM members WHERE member_id='%s';]], member.id)):fetch()
		local under18 = conn:execute(string.format([[SELECT under18 FROM members WHERE member_id='%s';]], member.id)):fetch()
		if watchlisted == 'f' then watchlisted = 'No' else watchlisted = 'Yes' end
		if under18 == 'f' then under18 = 'No' else under18 = 'Yes' end
		local status = message.channel:send {
			embed = {
				author = {name = member.username.."#"..member.discriminator, icon_url = member.avatarURL},
				fields = {
					{name = 'ID', value = member.id, inline = true},
					{name = 'Mention', value = member.mentionString, inline = true},
					{name = 'Nickname', value = member.name, inline = true},
					{name = 'Status', value = member.status, inline = true},
					{name = 'Joined', value = joinTime, inline = false},
					{name = 'Created', value = createTime, inline = true},
					{name = 'Registered', value = registerTime, inline = true},
					{name = 'Watchlisted', value = watchlisted, inline = true},
					{name = 'Under 18', value = under18, inline = true},
					{name = 'Roles ('..#member.roles..')', value = roles, inline = false},
				},
				thumbnail = {url = member.avatarURL, height = 200, width = 200},
				color = member:getColor().value,
				timestamp = discordia.Date():toISO()
			}
		}
		if status then
			message.channel:send {
				embed = {
					description = "[Fullsize Avatar]("..member.avatarURL..")",
					color = member:getColor().value
				}
			}
			return true
		end
	else
		message.channel:send("Sorry, I couldn't find that user.")
	end
end
commands:on('userinfo', function(m, a) safeCall(userInfo, m, a) end)
commands:on('ui', function(m, a) safeCall(userInfo, m, a) end)

--addRole: Mod Function only!
local function addRole(message, args)
	local roles, member = parseRoleList(message)
	local author = message.guild:getMember(message.author.id)
	local authorized = authorize(message, true, false)
	if authorized and member then
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
end
--removeRole: Mod function only!
local function removeRole(message, args)
	local roles, member = parseRoleList(message)
	local author = message.guild:getMember(message.author.id)
	local authorized = authorize(message, true, false)
	if authorized and member then
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
end
commands:on('ar', function(m,a) safeCall(addRole,m,a) end)
commands:on('rr', function(m,a) safeCall(removeRole,m,a) end)

--Register, same as ar but removes Not Verified
local function register(message)
	function fn(m) return m.name == message.guild._settings.modlog_channel end
	local channel = message.guild.textChannels:find(fn)
	local roles, member = parseRoleList(message)
	local author = message.guild:getMember(message.author.id)
	local authorized = authorize(message, true, true)
	if authorized and member then
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
			local function makeRoleList(roles)
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
end
commands:on('register', function(m, a) safeCall(register, m, a) end)
commands:on('reg', function(m, a) safeCall(register, m, a) end)
client:on('memberRegistered', function(member)
	local channel = member.guild:getChannel('350764752898752513')
	if channel then
		channel:send("Welcome to "..member.guild.name..", "..member.mentionString..". If you're comfortable doing so, please share a bit about yourself!")
	end
end)

--addSelfRole
local function addSelfRole(message)
	local roles = parseRoleList(message)
	local member = message.guild:getMember(message.author)
	local rolesToAdd = {}
	local rolesFailed = {}
	for i,role in ipairs(roles) do
		for k,l in pairs(selfRoles) do
			for r,a in pairs(l) do
				if string.lower(role) == string.lower(r)  or (table.search(a, string.lower(role))) then
					if member:hasRole(member.guild:getRole('348873284265312267')) and (k == 'Opt-In Roles') then
						if (r == 'Gamer') or (r == '18+') or (r == 'Momiji Dev') then
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
	local function makeRoleList(roles)
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
end
--removeSelfRole
local function removeSelfRole(message)
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
	local function makeRoleList(roles)
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
end
commands:on('role', function(m, a) safeCall(addSelfRole, m, a) end)
commands:on('asr', function(m, a) safeCall(addSelfRole, m, a) end)
commands:on('derole', function(m, a) safeCall(removeSelfRole, m, a) end)
commands:on('rsr', function(m, a) safeCall(removeSelfRole, m, a) end)

--roleList
local function roleList(message)
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
end
commands:on('roles', function(m,a) safeCall(roleList,m,a) end)

--Welcome message on memberJoin
local function welcomeMessage(member)
	function fn(m) return m.name == member.guild._settings.welcome_channel end
	local channel = member.guild.textChannels:find(fn)
	if channel then
		channel:send("Hello "..member.name..". Welcome to "..member.guild.name.."! Please read through ".."<#348660188951216130>".." and inform a member of staff how you identify and what pronouns you would like to use. These are required.")
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

--Mute: Mod only
local function mute(message, args)
	local author = message.author
	local authorized = authorize(message, true, true)
	if authorized then
		local logChannel = message.guild.textChannels:find(function(m) return m.name == message.guild._settings.modlog_channel end)
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
	end
end
--Unmute, counterpart to above
local function unmute(message)
	local author = message.author
	local authorized = authorize(message, true, true)
	if authorized then
		local logChannel = message.guild.textChannels:find(function(m) return m.name == message.guild._settings.modlog_channel end)
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
	end
end
commands:on('mute', function(m, a) safeCall(mute, m, a) end)
commands:on('unmute', function(m, a) safeCall(unmute, m, a) end)

--sets up mute in every text channel. currently broken due to 2.0
local function setupMute(message)
	if message.author == message.guild.owner then
		local role = message.guild:getRole('name', 'Muted')
		for channel in message.guild.textChannels do
			channel:getPermissionOverwriteFor(role):denyPermissions('sends', 'addReactions')
		end
	end
end
commands:on('setupmute', function(m, a) safeCall(setupMute, m, a) end)

--bulk delete command
local function bulkDelete(message, args)
	function fn(m) return m.name == message.guild._settings.modlog_channel end
	local logChannel = message.guild.textChannels:find(fn)
	local author = message.guild:getMember(message.author.id)
	local authorized = authorize(message, true, false)
	if authorized then
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
	end
end
commands:on('prune', function(m,a) safeCall(bulkDelete,m,a) end)

--manually ensure all members are present in the db. should be deprecated
local function populateMembers(message)
	if message.author == message.guild.owner.user then
		local guild = message.guild
		for member in guild.members:iter() do
			local status, err = conn:execute(string.format([[INSERT INTO members (member_id, nicknames) VALUES ('%s','{"%s"}');]], member.id, member.name))
		end
		return status
	end
end
commands:on('populate', function(m, a) safeCall(populateMembers, m, a) end)

--toggles the watchlist state for a member
local function watchlist(message, args)
	if authorize(message, true, true) then
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
	end
end
commands:on('watchlist', function(m,a) safeCall(watchlist, m, a) end)
commands:on('wl', function(m,a) safeCall(watchlist, m, a) end)

--toggles the under18 state for a member
local function toggle18(message, args)
	if authorize(message, true, true) then
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
	end
end
commands:on('toggle18', function(m,a) safeCall(toggle18, m, a) end)
commands:on('t18', function(m,a) safeCall(toggle18, m, a) end)

--Logging functions
--Member join message
local function memberJoin(member)
	function fn(m) return m.name == member.guild._settings.log_channel end
	local channel = member.guild.textChannels:find(fn)
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
local function memberLeave(member)
	function fn(m) return m.name == member.guild._settings.log_channel end
	local channel = member.guild.textChannels:find(fn)
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
local function userBan(user, guild)
	local member = guild:getMember(user) or user
	function fn(m) return m.name == guild._settings.modlog_channel end
	local channel = guild.textChannels:find(fn)
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
local function userUnban(user, guild)
	local member = guild:getMember(user) or user
	function fn(m) return m.name == guild._settings.modlog_channel end
	local channel = guild.textChannels:find(fn)
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
local function messageDelete(message)
	local member = message.member
	function fn(m) return m.name == message.guild._settings.log_channel end
	local logChannel = message.guild.textChannels:find(fn)
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
local function messageDeleteUncached(channel, messageID)
	function fn(m) return m.name == message.guild._settings.log_channel end
	local logChannel = message.guild.textChannels:find(fn)
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

client:run(token)
