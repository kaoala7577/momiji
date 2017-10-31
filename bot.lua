token = require('token')
discordia = require('discordia')
enums = discordia.enums
client = discordia.CommandClient()
logger = discordia.Logger(4, '%F %T', 'discordia.log')
fs = require('fs')
json = require('json')
uptime = discordia.Stopwatch()

function loadModule(name)
	name=name..'.lua'
	local data,others=fs.readFileSync('./Modules/'..name)
	if data then
		local a,b=loadstring(data,name)
		if not a then
			logger:log(2, "<SYNTAX> Error loading %s (%s)", name, b)
			return false
		else
			setfenv(a,getfenv())
			local c,d=pcall(a)
			if not c then
				logger:log(2, "<RUNTIME> Error loading %s (%s)", name, d)
				return false
			else
				client:info('Module online: '..name)
			end
		end
	else
		logger:log(2, "<LOADING> Error loading %s (%s)", name, tostring(others))
		return false
	end
end

coroutine.wrap(function()
	loadModule('Utilities')
	loadModule('Functions')
	loadModule('Commands')
	--loadModule('Events')
	--loadModule('Timed')
	--loadModule('API')
	--client:on('messageCreate',Events.messageCreate)
	--client:on('messageUpdate',Events.messageUpdate)
	--client:on('guildCreate',Events.guildCreate)
	--client:on('guildDelete',Events.guildDelete)
	--client:once('ready',Events.ready)
	client:loadDatabase(require("./Data/Database"))
	client:run(token)
end)()

--[[ init functions: load per-guild settings and ensure that all members are cached in the members table ]]
-- client:on('ready', function()
-- 	print('Logged in as '.. client.user.username)
-- 	client:setGame(".help | Awoo!")
-- 	for guild in client.guilds:iter() do
-- 		local cur = conn:execute([[SELECT * FROM settings;]])
-- 		local row = cur:fetch({}, "a")
-- 		while row do
-- 			if row.guild_id == guild.id then
-- 				guild._settings = row
-- 				guild._settings.admin_roles = utils.sqlStringToTable(row.admin_roles)
-- 				guild._settings.mod_roles = utils.sqlStringToTable(row.mod_roles)
-- 			end
-- 			row = cur:fetch(row, "a")
-- 		end
-- 		for member in guild.members:iter() do
-- 			conn:execute(string.format([[INSERT INTO members (member_id, nicknames, guild_id) VALUES ('%s','{"%s"}','%s') ON CONFLICT (member_id) DO UPDATE SET guild_id='%s';]], member.id, member.name, guild.id, guild.id))
-- 		end
-- 	end
-- end)

-- --stupid color changing function to learn how to hook callbacks to the clock
-- function changeColor(time)
-- 	local guild = client:getGuild('348660188951216129')
-- 	if guild and (math.fmod(time.min, 10) == 0) then
-- 		local role, success
-- 		if colorChange.owner then
-- 			role = guild:getRole('348665099550195713')
-- 			success = role:setColor(discordia.Color.fromRGB(math.floor(math.random(0, 255)), math.floor(math.random(0, 255)), math.floor(math.random(0, 255))))
-- 		end
-- 		if colorChange.first then
-- 			role = guild:getRole('363398104491229184')
-- 			success = role:setColor(discordia.Color.fromRGB(math.floor(math.random(0, 255)), math.floor(math.random(0, 255)), math.floor(math.random(0, 255))))
-- 		end
-- 	end
-- end
-- clock:on('min', function(time) funcWrapper(changeColor,time) end)
--
-- --Attempt to auto-remove cooldown
-- function removeCooldown(time)
-- 	local guild = client:getGuild('348660188951216129')
-- 	if guild then
-- 		for member in guild.members:iter() do
-- 			if member:hasRole('348873284265312267') then
-- 				local reg = conn:execute(string.format([[SELECT registered FROM members WHERE member_id='%s';]], member.id)):fetch()
-- 				if reg and reg ~= 'N/A' then
-- 					local date = utils.parseTime(reg):toTable()
-- 					if (time.day > date.day) and (time.hour >= date.hour) and (time.min >= date.min) then
-- 						member:addRole('348693274917339139')
-- 						member:removeRole('348873284265312267')
-- 					end
-- 				end
-- 			end
-- 		end
-- 	end
-- end
-- clock:on('min', function(time) funcWrapper(removeCooldown,time) end)
--
-- function autoPrune(time)
-- 	if time.wday == 6 and time.hour == 23 and time.min == 59 then
-- 		local guild = client:getGuild('348660188951216129')
-- 		local logChannel = guild:getChannel(message.guild._settings.modlog_channel)
-- 		local channels = {guild:getChanne('348694677538603008'), guild:getChannel('371768023549345793')}
-- 		local messageDeletes = utils.removeListeners(client, 'messageDelete')
-- 		local messageDeletesUncached = utils.removeListeners(client, 'messageDeleteUncached')
-- 		local numDel = 0
-- 		function fn(m) return not m.pinned end
-- 		for _,v in pairs(channels) do
-- 			numDel = 0
-- 			pins = v:getPinnedMessages()
-- 			while #v.messages ~= #pins do
-- 				toDelete = {}
-- 				for m in v:getMessages(100):findAll(fn) do
-- 					table.insert(toDelete, m.id)
-- 				end
-- 				if #toDelete > 0 then deleted = v:bulkDelete(toDelete) end
-- 				numDel = numDel + #toDelete
-- 			end
-- 			logChannel:send {
-- 				embed = {
-- 					description = "Moderator "..client.user.mentionString.." deleted "..numDel.." messages in "..channel.mentionString,
-- 					color = discordia.Color.fromRGB(255, 0, 0).value,
-- 					timestamp = discordia.Date():toISO()
-- 				}
-- 			}
-- 		end
-- 		utils.registerListeners(client, 'messageDelete', messageDeletes)
-- 		utils.registerListeners(client, 'messageDeleteUncached', messageDeletesUncached)
-- 	end
-- end
-- clock:on('min', function(time) funcWrapper(autoPrune,time) end)
--
-- --Update last_message in members table. not used yet
-- function lastMessage(message)
-- 	if message.channel.type == enums.channelType.text and message.author.bot ~= true then
-- 		local status, err = conn:execute(string.format([[UPDATE members SET last_message='%s' WHERE member_id='%s';]], discordia.Date():toISO(), message.member.id))
-- 	end
-- end
-- client:on('messageCreate', function(m) funcWrapper(lastMessage,m) end)
--
-- --Welcome message on memberJoin
-- function welcomeMessage(member)
-- 	local channel = member.guild:getChannel(member.guild._settings.welcome_channel)
-- 	if channel then
-- 		--channel:send("Hello "..member.name..". Welcome to "..member.guild.name.."! Please read through ".."<#348660188951216130>".." and inform a member of staff how you identify, what pronouns you would like to use, and your age. These are required.")
-- 		channel:send {
-- 			embed = {
-- 				title = "Welcome to "..member.guild.name.."!",
-- 				description = "Hello, "..member.name..". Please read through <#348660188951216130> and inform a member of staff how you identify, what pronouns you would like to use, and your age. These are required.",
-- 				thumbnail = {url = member.avatarURL, height = 200, width = 200},
-- 				color = discordia.Color.fromRGB(0, 255, 0).value,
-- 			}
-- 		}
-- 	end
-- end
-- client:on('memberJoin', function(member) funcWrapper(welcomeMessage,member) end)
--
-- --Post-register welcome
-- function postRegisterGreeting(member)
-- 	local channel = member.guild:getChannel('350764752898752513')
-- 	if channel then
-- 		channel:send("Welcome to "..member.guild.name..", "..member.mentionString..". If you're comfortable doing so, please share a bit about yourself!")
-- 	end
-- end
-- client:on('memberRegistered', function(m) funcWrapper(postRegisterGreeting,m) end)
--
-- --Streaming role
-- function nowLive(member)
-- 	role = '370395740406546432'
-- 	if (member.gameType == enums.gameType.streaming) and not member:hasRole(role) then
-- 		member:addRole(role)
-- 	elseif member:hasRole(role) then
-- 		member:removeRole(role)
-- 	end
-- end
-- client:on('presenceUpdate', function(m) funcWrapper(nowLive,m) end)
--
-- --[[ Commands ]]
--
-- --Attempt to load all commands from commands
-- for k, v in fs.scandirSync("./commands/") do
-- 	if v == 'file' and k:find(".lua") then
-- 		local name = k:gsub(".lua","")
-- 		cmds[name] = require('./commands/'..name)
-- 	end
-- end
--
-- --Set additional commands here
-- cmds['clr'] = {
-- 	id = 'clr',
-- 	action = function(message, args)
-- 		if args == 'owner' then
-- 			colorChange.owner = not colorChange.owner
-- 			return true
-- 		elseif args == 'first' then
-- 			colorChange.first = not colorChange.first
-- 			return true
-- 		end
-- 	end,
-- 	permissions = {
-- 		botOwner = true,
-- 		guildOwner = true,
-- 		admin = false,
-- 		mod = false,
-- 		everyone = false,
-- 	},
-- 	usage = "clr <owner|first>",
-- 	description = "Toggles the color changer",
-- 	category = "Guild Owner",
-- }
--
--
-- cmds['prune'] = {
-- 	id = "prune",
-- 	action = function(message, args)
-- 		local logChannel = message.guild:getChannel(message.guild._settings.modlog_channel)
-- 		local messageDeletes = utils.removeListeners(client, 'messageDelete')
-- 		local messageDeletesUncached = utils.removeListeners(client, 'messageDeleteUncached')
-- 		message:delete()
-- 		if tonumber(args) > 0 then
-- 			args = tonumber(args)
-- 			local xHun, rem = math.floor(args/100), math.fmod(args, 100)
-- 			local numDel = 0
-- 			if xHun > 0 then
-- 				for i=1, xHun do
-- 					toDelete = message.channel:getMessages(100)
-- 					if #toDelete > 0 then deleted = message.channel:bulkDelete(toDelete) end
-- 					numDel = numDel + #toDelete
-- 				end
-- 			end
-- 			if rem > 0 then
-- 				toDelete = message.channel:getMessages(rem)
-- 				if #toDelete > 0 then deleted = message.channel:bulkDelete(toDelete) end
-- 				numDel = numDel + #toDelete
-- 			end
-- 			logChannel:send {
-- 				embed = {
-- 					description = "Moderator "..message.author.mentionString.." deleted "..numDel.." messages in "..message.channel.mentionString,
-- 					color = discordia.Color.fromRGB(255, 0, 0).value,
-- 					timestamp = discordia.Date():toISO()
-- 				}
-- 			}
-- 		end
-- 		utils.registerListeners(client, 'messageDelete', messageDeletes)
-- 		utils.registerListeners(client, 'messageDeleteUncached', messageDeletesUncached)
-- 	end,
-- 	permissions = {
-- 		botOwner = false,
-- 		guildOwner = true,
-- 		admin = true,
-- 		mod = false,
-- 		everyone = false,
-- 	},
-- 	usage = "prune <number>",
-- 	description = "Deletes the specified number of messages from the current channel",
-- 	category = "Admin",
-- }
--
-- --sets up mute in every text channel. currently broken due to 2.0
-- function setupMute(message)
-- 	if message.author == message.guild.owner then
-- 		local role = message.guild:getRole('name', 'Muted')
-- 		for channel in message.guild.textChannels do
-- 			channel:getPermissionOverwriteFor(role):denyPermissions('sends', 'addReactions')
-- 		end
-- 	end
-- end
-- --commands:on('setupmute', function(m, a) safeCall(setupMute, m, a) end)
--
-- --Logging functions
-- --Member join message
-- function memberJoin(member)
-- 	local channel = member.guild:getChannel(member.guild._settings.log_channel)
-- 	local status, err = conn:execute(string.format([[INSERT INTO members (member_id, nicknames) VALUES ('%s', '{"%s"}');]], member.id, member.name))
-- 	if channel then
-- 		channel:send {
-- 			embed = {
-- 				author = {name = "Member Joined", icon_url = member.avatarURL},
-- 				description = member.mentionString.." "..member.username.."#"..member.discriminator,
-- 				thumbnail = {url = member.avatarURL, height = 200, width = 200},
-- 				color = discordia.Color.fromRGB(0, 255, 0).value,
-- 				timestamp = discordia.Date():toISO(),
-- 				footer = {text = "ID: "..member.id}
-- 			}
-- 		}
-- 	end
-- end
-- --Member leave message
-- function memberLeave(member)
-- 	local channel = member.guild:getChannel(member.guild._settings.log_channel)
-- 	local status, err = conn:execute(string.format([[DELETE FROM members WHERE member_id='%s';]], member.id))
-- 	if channel then
-- 		channel:send {
-- 			embed = {
-- 				author = {name = "Member Left", icon_url = member.avatarURL},
-- 				description = member.mentionString.." "..member.username.."#"..member.discriminator,
-- 				thumbnail = {url = member.avatarURL, height = 200, width = 200},
-- 				color = discordia.Color.fromRGB(255, 0, 0).value,
-- 				timestamp = discordia.Date():toISO(),
-- 				footer = {text = "ID: "..member.id}
-- 			}
-- 		}
-- 	end
-- end
-- client:on('memberJoin', function(member) funcWrapper(memberJoin,member) end)
-- client:on('memberLeave', function(member) funcWrapper(memberLeave,member) end)
--
-- --Ban message
-- function userBan(user, guild)
-- 	local member = guild:getMember(user) or user
-- 	local channel = guild:getChannel(member.guild._settings.modlog_channel)
-- 	if channel and member then
-- 		channel:send {
-- 			embed = {
-- 				author = {name = "Member Banned", icon_url = member.avatarURL},
-- 				description = member.mentionString.." "..member.username.."#"..member.discriminator,
-- 				thumbnail = {url = member.avatarURL, height = 200, width = 200},
-- 				color = discordia.Color.fromRGB(255, 0, 0).value,
-- 				timestamp = discordia.Date():toISO(),
-- 				footer = {text = "ID: "..member.id}
-- 			}
-- 		}
-- 	end
-- end
-- --Unban message
-- function userUnban(user, guild)
-- 	local member = guild:getMember(user) or user
-- 	local channel = guild:getChannel(member.guild._settings.modlog_channel)
-- 	if channel and member then
-- 		channel:send {
-- 			embed = {
-- 				author = {name = "Member Unbanned", icon_url = member.avatarURL},
-- 				description = member.mentionString.." "..member.username.."#"..member.discriminator,
-- 				thumbnail = {url = member.avatarURL, height = 200, width = 200},
-- 				color = discordia.Color.fromRGB(255, 0, 0).value,
-- 				timestamp = discordia.Date():toISO(),
-- 				footer = {text = "ID: "..member.id}
-- 			}
-- 		}
-- 	end
-- end
-- client:on('userBan', function(user, guild) funcWrapper(userBan,user,guild) end)
-- client:on('userUnban', function(user, guild) funcWrapper(userUnban,user,guild) end)
--
-- --Cached message deletion
-- function messageDelete(message)
-- 	local member = message.member
-- 	local logChannel = message.guild:getChannel(message.guild._settings.log_channel)
-- 	if logChannel and member then
-- 		body = "**Message sent by "..member.mentionString.." deleted in "..message.channel.mentionString.."**\n"..message.content
-- 		if message.attachments then
-- 			for i,t in ipairs(message.attachments) do
-- 				body = body.."\n[Attachment "..i.."]("..t.url..")"
-- 			end
-- 		end
-- 		logChannel:send {
-- 			embed = {
-- 				author = {name = member.username.."#"..member.discriminator, icon_url = member.avatarURL},
-- 				description = body,
-- 				color = discordia.Color.fromRGB(255, 0, 0).value,
-- 				timestamp = discordia.Date():toISO(),
-- 				footer = {text = "ID: "..member.id}
-- 			}
-- 		}
-- 	end
-- end
-- --Uncached message deletion
-- function messageDeleteUncached(channel, messageID)
-- 	local logChannel = channel.guild:getChannel(channel.guild._settings.log_channel)
-- 	if logChannel then
-- 		logChannel:send {
-- 			embed = {
-- 				author = {name = channel.guild.name, icon_url = channel.guild.iconURL},
-- 				description = "**Uncached message deleted in** "..channel.mentionString,
-- 				color = discordia.Color.fromRGB(255, 0, 0).value,
-- 				timestamp = discordia.Date():toISO(),
-- 				footer = {text = "ID: "..channel.id}
-- 			}
-- 		}
-- 	end
-- end
-- client:on('messageDelete', function(message) funcWrapper(messageDelete,message) end)
-- client:on('messageDeleteUncached', function(channel, messageID) funcWrapper(messageDeleteUncached,channel,messageID) end)
