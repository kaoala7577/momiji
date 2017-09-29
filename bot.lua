local discordia = require('discordia')
local client = discordia.Client({cacheAllMembers = true})
local token = require'token'
local luasql = require'luasql.postgres'
local env = luasql.postgres()
local conn = env:connect('mydb')
discordia.extensions()
local enums = discordia.enums

local clock = discordia.Clock()
clock:start()

local selfRoles = require'rolelist'

local days = {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"}
local months = {"January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"}

local function sqlStringToTable(str)
	if str:startswith('{') and str:endswith('}') then
		str = string.gsub(str, "[{}]", "")
		return str:split(',')
	end
	return
end

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
	end
end)

local function parseMention(mention)
	return string.match(mention, "%<%@%!(%d+)%>") or string.match(mention, "%<%@(%d+)%>") or mention
end

local function parseChannel(mention)
	return string.match(mention, "%<%#(%d+)%>") or mention
end

local function parseTime(time)
	if time:match('(%d+)-(%d+)-(%d+).(%d+):(%d+):(%d+)(.*)') then return discordia.Date.fromISO(time) else return time end
end

local function humanReadableTime(table)
	return days[table.wday]..", "..months[table.month].." "..table.day..", "..table.year.." at "..table.hour..":"..table.min or table
end

local function stripPrefix(message)
	return string.gsub(message.content, "%"..message.guild._settings.prefix, "")
end

local function parseCommands(message, useDelim, firstIsMention)
	local strippedMessage = stripPrefix(message)
	local command = string.match(strippedMessage, "^(%g+)%s+")
	local messageWithoutPrefix = {command}
	strippedMessage = string.gsub(strippedMessage, "^(%g+)%s+", "")

	if firstIsMention then
		messageWithoutPrefix[2] = string.match(strippedMessage, "^(%g+)%s+")
		strippedMessage = string.gsub(strippedMessage, "^(%g+)%s+", "")
	end
	if useDelim then
		for _,word in pairs(string.split(strippedMessage, ",")) do
			messageWithoutPrefix[#messageWithoutPrefix+1] = word
		end
	else
		for word in string.gmatch(strippedMessage, "%g+") do
			messageWithoutPrefix[#messageWithoutPrefix+1] = string.gsub(word, "%,", "")
		end
	end
	for i, w in ipairs(messageWithoutPrefix) do
		messageWithoutPrefix[i] = messageWithoutPrefix[i]:trim()
	end
	return messageWithoutPrefix
end

local function getCommand(message, useDelim, firstIsMention)
	local commandWithArgs = {}
	if message.channel.type ~= enums.channelType.text then return commandWithArgs end
	if message.content:match('^%'..message.guild._settings.prefix) then
		commandWithArgs = parseCommands(message, useDelim, firstIsMention)
	end
	return commandWithArgs
end

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

--stupid color changing function to learn how to hook callbacks to the clock
local function changeColor(time)
	local guild = client:getGuild('348660188951216129')
	if guild and (math.fmod(time.min, 10) == 0) then
		local role = guild:getRole('348665099550195713')
		local success = role:setColor(discordia.Color.fromRGB(math.floor(math.random(0, 255)), math.floor(math.random(0, 255)), math.floor(math.random(0, 255))))
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
local function changeUsername(message)
	local commandWithArgs = getCommand(message, false, false)
	if message.author == client.owner then
		if commandWithArgs[2] and commandWithArgs[1] == 'uname' then
			print("Changing username to "..commandWithArgs[2])
			client:setUsername(commandWithArgs[2])
		end
	end
end
client:on('messageCreate', function(message) changeUsername(message) end)

--make Spam! Owner Only
local function makeSpam(message)
	local commandWithArgs = getCommand(message, false, false)
	if message.author == client.owner then
		if commandWithArgs[1] == 'genspam' then
			message:delete()
			if commandWithArgs[2] then
				for i=1, commandWithArgs[2] do message.channel:send("Awoo!") end
			end
		end
	end
end
client:on('messageCreate', function(message) makeSpam(message) end)

--Help page.... total shit
client:on('messageCreate', function(message)
	local commandWithArgs = getCommand(message, false, false)
	if commandWithArgs[1] == 'help' then
		message.author:send([[**Commands for everyone**
`.ping`: pings the bot to see if it's awake
`.userinfo` <@user|userID>: pulls up some information on the user. If no user specified it uses the sender. Aliases: `.ui`
`.role <role[, role, ...]>`: adds all the roles listed to the sending user if the roles are on the self role list. Aliases: `.asr`
`.derole <role[, role, ...]>`: same as .role but removes the roles. Aliases: `.rsr`
`.roles`: list available self-roles
`.serverinfo`: pull up information on the server. Aliases: `.si`
`.roleinfo <rolename>`: pulls up information on the listed role. Aliases: `.ri`

**Moderator Commands**
`.mute [#channel] <@user|userID>`: mutes a user, if a channel is mentioned it only mutes them in that channel
`.unmute [#channe] <@user|userID>`: undoes mute
`.register <@user|userID> <role[, role, ...]>`: registers a user with the given roles. Aliases: `.reg`
`.ar <@user|userID> <role[, role, ...]>`: adds a user to the given roles
`.rr <@user|userID> <role[, role, ...]>`: removes a user from the given roles
`.watchlist <@user|userID>`: adds/removes a user from the watchlist. Aliases: `.wl`
`.toggle18 <@user|userID>`: toggles the under 18 user flag. Aliases: `.t18`

**Admin Commands**
`.prune <number>`: bulk deletes a number of messages]])
	end
end)

client:on('messageCreate', function(message)
	if message.channel.type == enums.channelType.text then
		local status, err = conn:execute(string.format([[UPDATE members SET last_message='%s' WHERE member_id='%s';]], discordia.Date():toISO(), message.member.id))
	end
end)

--change prefix
local function changePrefix(message)
	local commandWithArgs = getCommand(message, false, false)
	if commandWithArgs[1] == 'prefix' and message.author == message.guild.owner.user then
		conn:execute(string.format([[UPDATE settings SET prefix='%s' WHERE guild_id='%s';]], commandWithArgs[2], message.guild.id))
		local curr = conn:execute(string.format([[SELECT * FROM settings WHERE guild_id='%s';]], message.guild.id))
		local row = curr:fetch({}, "a")
		message.guild._settings.prefix = row.prefix
	end
end
client:on('messageCreate', function(m) changePrefix(m) end)

--ping
local function ping(message)
	local commandWithArgs = getCommand(message, false, false)
	if commandWithArgs[1] == 'ping' then
		local sw = discordia.Stopwatch()
		sw:reset()
		if message.channel:send("Pong!") then
			sw:stop()
			message.channel:getLastMessage():setContent("Pong!".."`"..math.round(sw.milliseconds).." ms`")
		end
	end
end
client:on('messageCreate', function(message) ping(message) end)

--lists members without roles
local function noRoles(message)
	local commandWithArgs = getCommand(message, false, false)
	local authorized = authorize(message, true, false)
	if commandWithArgs[1] == 'noroles' and authorized then
		local predicate = function(member) return #member.roles == 0 end
		local list = {}
		message:delete()
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
		if #commandWithArgs > 1 then
			for i,word in ipairs(commandWithArgs) do
				if i > 1 then if reply then reply = reply.." "..word else reply = word end end
			end
			message:reply(listInLines.."\n"..reply)
		else
			message:reply(listInLines)
		end
	end
end
client:on('messageCreate', function(message) noRoles(message) end)

--serverinfo
local function serverInfo(message)
	local commandWithArgs = getCommand(message, false, false)
	local guild = message.guild
	if commandWithArgs[1] == 'serverinfo' or commandWithArgs[1] == 'si' then
		if client:getGuild(commandWithArgs[2]) then
			guild = client:getGuild(commandWithArgs[2])
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
		if invite then
			message.channel:send {
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
					--timestamp = discordia.Date():toISO(),
					footer = { text = "Server Created : "..timestamp }
				}
			}
		else
			message.channel:send {
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
					--timestamp = discordia.Date():toISO(),
					footer = { text = "Server Created : "..timestamp }
				}
			}
		end
	end
end
client:on('messageCreate', function(message) serverInfo(message) end)

--roleinfo
local function roleInfo(message)
	local commandWithArgs = getCommand(message, true, false)
	if commandWithArgs[1] == 'roleinfo' or commandWithArgs[1] == 'ri' then
		local role = message.guild.roles:find(function(r) return r.name == commandWithArgs[2] end)
		if role then
			local hex = string.match(role:getColor():toHex(), "%x+")
			local count = 0
			for m in message.guild.members:iter() do
				if m:hasRole(role) then count = count + 1 end
			end
			local hoisted, mentionable
			if role.hoist then hoisted = "Yes" else hoisted = "No" end
			if role.mentionable then mentionable = "Yes" else mentionable = "No" end
			message.channel:send {
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
		end
	end
end
client:on('messageCreate', function(message) roleInfo(message) end)

--User functions
--userinfo
local function userInfo(message)
	local commandWithArgs = getCommand(message, false, false)
	local guild = message.guild
	if commandWithArgs[1] == 'userinfo' or commandWithArgs[1] == 'ui'  then
		local member = guild:getMember(message.author)
		if commandWithArgs[2] then
			member = guild:getMember(parseMention(commandWithArgs[2]))
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
			message.channel:send {
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
			message.channel:send {
				embed = {
					description = "[Fullsize Avatar]("..member.avatarURL..")",
					color = member:getColor().value
				}
			}
		else
			message.channel:send("Sorry, I couldn't find that user.")
		end
	end
end
client:on('messageCreate', function(message) userInfo(message) end)

--addRole: Mod Function only!
local function addRole(message)
	local commandWithArgs = getCommand(message, true, true)
	if commandWithArgs[1] == 'ar' then
		local member = message.guild:getMember(parseMention(commandWithArgs[2]))
		local author = message.guild:getMember(message.author.id)
		local authorized = authorize(message, true, true)
		if authorized and member then
			local rolesToAdd = {}
			for i,role in ipairs(commandWithArgs) do
				if i>2 then
					for r in message.guild.roles:iter() do
						if string.lower(role) == string.lower(r.name) then
							rolesToAdd[#rolesToAdd+1] = r
						end
					end
				end
			end
			for _,role in ipairs(rolesToAdd) do
				member:addRole(member.guild:getRole(role.id))
			end
			local function makeRoleList(roles)
				local roleList = ""
				for _,r in ipairs(roles) do
					roleList = roleList..r.name.."\n"
				end
				return roleList
			end
			if #rolesToAdd > 0 then
				message.channel:send {
					embed = {
						author = {name = "Roles Added", icon_url = member.avatarURL},
						description = "**Added "..member.mentionString.." to the following roles** \n"..makeRoleList(rolesToAdd),
						color = member:getColor().value,
						timestamp = discordia.Date():toISO(),
						footer = {text = "ID: "..member.id}
					}
				}
			end
		end
	end
end
--removeRole: Mod function only!
local function removeRole(message)
	local commandWithArgs = getCommand(message, true, true)
	if commandWithArgs[1] == 'rr' then
		local member = message.guild:getMember(parseMention(commandWithArgs[2]))
		local author = message.guild:getMember(message.author.id)
		local authorized = authorize(message, true, true)
		if authorized and member then
			local rolesToRemove = {}
			for i,role in ipairs(commandWithArgs) do
				for r in message.guild.roles:iter() do
					if string.lower(role) == string.lower(r.name) then
						rolesToRemove[#rolesToRemove+1] = r
					end
				end
			end
			for _,role in ipairs(rolesToRemove) do
				member:removeRole(member.guild:getRole(role.id))
			end
			local function makeRoleList(roles)
				local roleList = ""
				for _,r in ipairs(roles) do
					roleList = roleList..r.name.."\n"
				end
				return roleList
			end
			if #rolesToRemove > 0 then
				message.channel:send {
					embed = {
						author = {name = "Roles Removed", icon_url = member.avatarURL},
						description = "**Removed "..member.mentionString.." from the following roles** \n"..makeRoleList(rolesToRemove),
						color = member:getColor().value,
						timestamp = discordia.Date():toISO(),
						footer = {text = "ID: "..member.id}
					}
				}
			end
		end
	end
end
--Register, same as ar but removes Not Verified
local function register(message)
	local commandWithArgs = getCommand(message, true, true)
	if commandWithArgs[1] == 'register' or commandWithArgs[1] == 'reg' then
		function fn(m) return m.name == message.guild._settings.modlog_channel end
		local channel = message.guild.textChannels:find(fn)
		local member = message.guild:getMember(parseMention(commandWithArgs[2]))
		local author = message.guild:getMember(message.author.id)
		local authorized = authorize(message, true, true)
		if authorized and member then
			local rolesToAdd = {}
			local hasGender, hasPronouns
			for i,role in ipairs(commandWithArgs) do
				if i>2 then
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
				for _,role in ipairs(rolesToAdd) do
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
				end
			else
				message:reply("Invalid registration command. Make sure to include at least one of gender identity and pronouns.")
			end
			message:delete()
		end
	end
end
client:on('messageCreate', function(message) addRole(message) end)
client:on('messageCreate', function(message) removeRole(message) end)
client:on('messageCreate', function(message) register(message) end)
client:on('memberRegistered', function(member)
	local channel = member.guild:getChannel('350764752898752513')
	if channel then
		channel:send("Welcome to "..member.guild.name..", "..member.mentionString..". If you're comfortable doing so, please share a bit about yourself!")
	end
end)

--addSelfRole
local function addSelfRole(message)
	local commandWithArgs = getCommand(message, true, false)
	if commandWithArgs[1] == 'asr' or commandWithArgs[1] == 'role' then
		local member = message.guild:getMember(message.author)
		local rolesToAdd = {}
		local rolesFailed = {}
		for i,role in ipairs(commandWithArgs) do
			if i>1 then
				for k,l in pairs(selfRoles) do
					for r,a in pairs(l) do
						if string.lower(role) == string.lower(r)  or (table.search(a, string.lower(role))) then
							if member:hasRole(member.guild:getRole('name', 'Cooldown')) and (k == 'Opt-In Roles') then
								if (r == 'Gamer') or (r == '18+') or (r == 'Momiji Dev') then
									rolesToAdd[#rolesToAdd+1] = r
								else rolesFailed[#rolesFailed+1] = r.." is only available after cooldown" end
							elseif (member:hasRole(member.guild:getRole('name', 'Cis Male')) or member:hasRole(member.guild:getRole('name', 'Cis Female'))) and (k == 'Opt-In Roles') then
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
		if #rolesAdded > 0 then
			message.channel:send {
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
	end
end
--removeSelfRole
local function removeSelfRole(message)
	local commandWithArgs = getCommand(message, true, false)
	if commandWithArgs[1] == 'rsr' or commandWithArgs[1] == 'derole' then
		local member = message.guild:getMember(message.author)
		local rolesToRemove = {}
		for i,role in ipairs(commandWithArgs) do
			if i>1 then
				for _,l in pairs(selfRoles) do
					for r,a in pairs(l) do
						if (string.lower(role) == string.lower(r)) or (table.search(a, string.lower(role))) then
							rolesToRemove[#rolesToRemove+1] = r
						end
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
			message.channel:send {
				embed = {
					author = {name = "Roles Removed", icon_url = member.avatarURL},
					description = "**Removed "..member.mentionString.." from the following roles** \n"..makeRoleList(rolesToRemove),
					color = member:getColor().value,
					timestamp = discordia.Date():toISO(),
					footer = {text = "ID: "..member.id}
				}
			}
		end
	end
end
client:on('messageCreate', function(message) addSelfRole(message) end)
client:on('messageCreate', function(message) removeSelfRole(message) end)

--roleList
local function roleList(message)
	local commandWithArgs = getCommand(message, true, false)
	if commandWithArgs[1] == 'roles' then
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
		message.channel:send {
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
	end
end
client:on('messageCreate', function(message) roleList(message) end)

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
local function mute(message)
	local commandWithArgs = getCommand(message, false, false)
	if commandWithArgs[1] == 'mute' then
		local author = message.guild:getMember(message.author.id)
		local authorized = authorize(message, true, true)
		if authorized then
			--Syntax here is a bit odd, this will be true if the 2nd arg is NOT a channel mention. i.e. We're expecting a user mention
			function fn(m) return m.name == message.guild._settings.modlog_channel end
			local logChannel = message.guild.textChannels:find(fn)
			local member
			local reason = ""
			if parseChannel(commandWithArgs[2]) == commandWithArgs[2] then
				member = message.guild:getMember(parseMention(commandWithArgs[2]))
				if member then
					for i,j in ipairs(commandWithArgs) do if i>2 then reason = reason.." "..j end end
					member:addRole('349060739815964673')
					message.channel:send("Muting "..member.mentionString.." server-wide")
				end
			else --This will go through if the 2nd arg happens to be a channel mention because the ID will be returned by parseChannel()
				local channelID = parseChannel(commandWithArgs[2])
				local channel = message.guild:getChannel(channelID)
				member = message.guild:getMember(parseMention(commandWithArgs[3]))
				if member and channel then
					for i,j in ipairs(commandWithArgs) do if i>3 then reason = reason.." "..j end end
					channel:getPermissionOverwriteFor(member):denyPermissions(enums.permission.sendMessages, enums.permission.addReactions)
					message.channel:send("Muting "..member.mentionString.." in "..channel.mentionString)
				end
			end
			if reason == "" then reason = "None" end
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
	end
end
--Unmute, counterpart to above
local function unmute(message)
	local commandWithArgs = getCommand(message, false, false)
	if commandWithArgs[1] == 'unmute' then
		local author = message.guild:getMember(message.author.id)
		local authorized = authorize(message, true, true)
		if authorized then
			function fn(m) return m.name == message.guild._settings.modlog_channel end
			local logChannel = message.guild.textChannels:find(fn)
			local member
			--Syntax here is a bit odd, this will be true if the 2nd arg is NOT a channel mention. i.e. We're expecting a user mention
			if parseChannel(commandWithArgs[2]) == commandWithArgs[2] then
				member = message.guild:getMember(parseMention(commandWithArgs[2]))
				if member then
					member:removeRole('349060739815964673')
					message.channel:send("Unmuting "..member.mentionString.." server-wide")
				end
			else --This will go through if the 2nd arg happens to be a channel mention because the ID will be returned by parseChannel()
				local channelID = parseChannel(commandWithArgs[2])
				local channel = message.guild:getChannel(channelID)
				member = message.guild:getMember(parseMention(commandWithArgs[3]))
				if member and channel then
					if channel:getPermissionOverwriteFor(member).allowedPermissions then
						channel:getPermissionOverwriteFor(member):denyPermissions(enums.permission.sendMessages, enums.permission.addReactions)
					else
						channel:getPermissionOverwriteFor(member):delete()
					end
					message.channel:send("Unmuting "..member.mentionString.." in "..channel.mentionString)
				end
			end
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
	end
end
client:on('messageCreate', function(message) mute(message) end)
client:on('messageCreate', function(message) unmute(message) end)

local function setupMute(message)
	local commandWithArgs = getCommand(message, false, false)
	if commandWithArgs[1] == 'setupmute' then
		if message.author == message.guild.owner then
			local role = message.guild:getRole('name', 'Muted')
			for channel in message.guild.textChannels do
				channel:getPermissionOverwriteFor(role):denyPermissions('sends', 'addReactions')
			end
		end
	end
end
client:on('messageCreate', function(message) setupMute(message) end)

local function prune(message)
	local commandWithArgs = getCommand(message, false, false)
	if commandWithArgs[1] == 'prune' then
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
			if tonumber(commandWithArgs[2]) then
				commandWithArgs[2] = tonumber(commandWithArgs[2])
				local xHun, rem = math.floor(commandWithArgs[2]/100), math.fmod(commandWithArgs[2], 100)
				local numDel = 0
				if xHun > 0 then
					for i=1, xHun do
						deletions = message.channel:getMessages(100)
						success = message.channel:bulkDelete(deletions)
						numDel = numDel+100
					end
				end
				if rem > 0 then
					deletions = message.channel:getMessages(rem)
					success = message.channel:bulkDelete(deletions)
					numDel = numDel+rem
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
end
client:on('messageCreate', function(message) prune(message) end)

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
--Caches message deletion
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

local function populateMembers(message)
	local commandWithArgs = getCommand(message, false, false)
	if commandWithArgs[1] == 'populate' and message.author == message.guild.owner.user then
		local guild = message.guild
		for member in guild.members:iter() do
			local status, err = conn:execute(string.format([[INSERT INTO members (member_id, nicknames) VALUES ('%s','{"%s"}');]], member.id, member.name))
		end
	end
end
client:on('messageCreate', function(m) populateMembers(m) end)

local function watchlist(message)
	local commandWithArgs = getCommand(message, false, false)
	local authorized = authorize(message, true, true)
	if authorized and (commandWithArgs[1] == 'watchlist' or commandWithArgs[1] == 'wl') then
		local member = message.guild:getMember(parseMention(commandWithArgs[2]))
		if member then
			local currentVal = conn:execute(string.format([[SELECT watchlisted FROM members WHERE member_id='%s';]], member.id)):fetch()
			if currentVal == 'f' then
				conn:execute(string.format([[UPDATE members SET watchlisted=true WHERE member_id='%s';]], member.id))
			else
				conn:execute(string.format([[UPDATE members SET watchlisted=false WHERE member_id='%s';]], member.id))
			end
		end
	end
end
client:on('messageCreate', function(m) watchlist(m) end)

local function toggle18(message)
	local commandWithArgs = getCommand(message, false, false)
	local authorized = authorize(message, true, true)
	if authorized and (commandWithArgs[1] == 'toggle18' or commandWithArgs[1] == 't18') then
		local member = message.guild:getMember(parseMention(commandWithArgs[2]))
		if member then
			local currentVal = conn:execute(string.format([[SELECT under18 FROM members WHERE member_id='%s';]], member.id)):fetch()
			if currentVal == 'f' then
				conn:execute(string.format([[UPDATE members SET under18=true WHERE member_id='%s';]], member.id))
			else
				conn:execute(string.format([[UPDATE members SET under18=false WHERE member_id='%s';]], member.id))
			end
		end
	end
end
client:on('messageCreate', function(m) toggle18(m) end)

client:run(token)
