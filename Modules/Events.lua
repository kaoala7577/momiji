--[[ Adapted from DannehSC/Electricity-2.0 ]]

Events = {}
local errLog, comLog

function Events.messageCreate(msg)
	if msg.author.bot then return end
	local private, data
	if msg.guild then private=false else private=true end
	local sender = (private and msg.author or msg.member or msg.guild:getMember(msg.author))
	local rank = getRank(sender, not private)
	if not private then
		--Load settings for the guild, Database.lua keeps a cache of requests to avoid making excessive queries
		data = Database:get(msg)
		if data.Ignore[msg.channel.id] and rank<3 then
			return
		end
		if data.Users[msg.author.id] then
			data.Users[msg.author.id].last_message = discordia.Date():toISO()
			data.Users[msg.author.id].nick = msg.author.nickname or msg.author.username
		else
			data.Users[msg.author.id] = {last_message = discordia.Date():toISO(), nick=msg.author.nickname or msg.author.username}
		end
		Database:update(msg, "Users", data.Users)
	end
	local command, rest = resolveCommand(msg.content, (not private and data.Settings.prefix or ""))
	if not command then return end --If the prefix isn't there, don't bother with anything else
	for _,tab in pairs(Commands) do
		for _,cmd in pairs(tab.commands) do
			if command:lower() == cmd:lower() then
				if tab.serverOnly and private then
					msg:reply("This command is not available in private messages.")
					return
				end
				if rank>=tab.rank then
					local args
					if tab.multi then
						args = string.split(rest, ',')
						for i,v in ipairs(args) do args[i]=v:trim() end
					else
						args = rest
					end
					local a,b = pcall(tab.action, msg, args)
					if not a then
						if errLog then
							errLog:send {embed = {
								description = b,
								footer = {text="ID: "..msg.id},
								timestamp = discordia.Date():toISO(),
								color = discordia.Color.fromRGB(255, 0 ,0).value,
							}}
						end
					end
					if comLog then
						local g = not private and msg.guild or "Private"
						comLog:send{embed={
							fields={
								{name="Guild",value=g.name.."\n"..g.id,inline=true},
								{name="Author",value=msg.author.fullname.."\n"..msg.author.id,inline=true},
								{name="Channel",value=msg.channel.name.."\n"..msg.channel.id,inline=true},
								{name="Command",value=tab.name,inline=true},
								{name="Message Content",value=msg.cleanContent},
							},
							footer = {text="Message ID: "..msg.id},
							timestamp=discordia.Date():toISO(),
						}}
					end
				else
					local ranks = {"Everyone", "Mod", "Admin", "Guild Owner", "Bot Owner"}
					msg.channel:sendf("Insufficient permission to execute command: **%s**\nRank expected: **%s**\nYour Rank: **%s**", tab.name, ranks[tab.rank+1], ranks[rank+1])
				end
			end
		end
	end
end


function Events.memberJoin(member)
	local settings = Database:get(member, "Settings")
	if settings['welcome_message'] ~= "" and settings['welcome_channel'] and settings['welcome'] then
		local typeOf = getFormatType(settings['welcome_message'], member)
		local channel = member.guild:getChannel(settings['welcome_channel'])
		if typeOf == 'plain' or not typeOf and channel then
			channel:send(formatMessageSimple(settings['welcome_message'], member))
		elseif typeOf == 'embed' and channel then
			channel:send{
				embed = formatMessageEmbed(settings['welcome_message'], member)
			}
		end
	end
	--Join message
	local channel = member.guild:getChannel(settings.audit_channel)
	if settings.audit and channel then
		channel:send {embed={
			author = {name = "Member Joined", icon_url = member.avatarURL},
			description = member.mentionString.."\n"..member.fullname,
			thumbnail = {url = member.avatarURL, height = 200, width = 200},
			color = discordia.Color.fromRGB(0, 255, 0).value,
			timestamp = discordia.Date():toISO(),
			footer = {text = "ID: "..member.id}
		}}
	end
	--Auto role
	if settings.autorole then
		for _,r in ipairs(settings.autoroles) do
			member:addRole(r)
		end
	end
	local users = Database:get(member, "Users")
	users[member.id] = { last_message=discordia.Date():toISO(), nick=member.nickname or member.username }
	Database:update(member, "Users", users)
end

function Events.memberLeave(member)
	local settings = Database:get(member, "Settings")
	local channel = member.guild:getChannel(settings.audit_channel)
	if settings.audit and channel then
		channel:send {embed={
			author = {name = "Member Left", icon_url = member.avatarURL},
			description = member.mentionString.."\n"..member.fullname,
			thumbnail = {url = member.avatarURL, height = 200, width = 200},
			color = discordia.Color.fromRGB(255, 0, 0).value,
			timestamp = discordia.Date():toISO(),
			footer = {text = "ID: "..member.id}
		}}
	end
end

function Events.presenceUpdate(member)
	local role = '370395740406546432'
	if member.guild.id == '348660188951216129' then
		if (member.gameType == enums.gameType.streaming) and not member:hasRole(role) then
			member:addRole(role)
		elseif member:hasRole(role) then
			member:removeRole(role)
		end
	end
end

function Events.memberUpdate(member)
	local users = Database:get(member, "Users")
	local settings = Database:get(member, "Settings")
	if users[member.id] and settings.audit and settings.audit_channel then
		if users[member.id].nick~=member.nickname then
			local channel = member.guild:getChannel(settings.audit_channel)
			channel:send{embed={
				author = {name="Nickname Changed", icon_url=member.avatarURL},
				description = string.format("User: **%s** changed their nickname from `%s` to `%s`",member.fullname,users[member.id].nick,member.nickname or member.username),
				color = discordia.Color.fromHex('#5DA9FF').value,
				timestamp = discordia.Date():toISO(),
				footer = {text="ID: "..member.id},
			}}
		end
	end
	if users[member.id] and type(users[member.id])=="table" then
		users[member.id].nick = member.nickname or member.username
	else
		users[member.id] = {nick = member.nickname or member.username}
	end
	Database:update(member, "Users", users)
end

function Events.userBan(user, guild)
	local member = guild:getMember(user) or user
	local settings = Database:get(guild, "Settings")
	local channel = guild:getChannel(settings.modlog_channel)
	if channel and member and settings.modlog then
		channel:send {embed={
			author = {name = "Member Banned", icon_url = member.avatarURL},
			description = member.mentionString.."\n"..member.fullname,
			thumbnail = {url = member.avatarURL, height = 200, width = 200},
			color = discordia.Color.fromRGB(255, 0, 0).value,
			timestamp = discordia.Date():toISO(),
			footer = {text = "ID: "..member.id}
		}}
	end
end

function Events.userUnban(user, guild)
	local member = guild:getMember(user) or user
	local settings = Database:get(guild, "Settings")
	local channel = guild:getChannel(settings.modlog_channel)
	if channel and member and settings.modlog then
		channel:send {embed={
			author = {name = "Member Unbanned", icon_url = member.avatarURL},
			description = member.mentionString.."\n"..member.fullname,
			thumbnail = {url = member.avatarURL, height = 200, width = 200},
			color = discordia.Color.fromRGB(0, 255, 0).value,
			timestamp = discordia.Date():toISO(),
			footer = {text = "ID: "..member.id}
		}}
	end
end

function Events.messageDelete(message)
	for i,v in ipairs(discordia.storage.bulkDeletes) do
		if message.id==v then
			table.remove(discordia.storage.bulkDeletes,i)
			return
		end
	end
	local member = message.member or message.guild:getMember(message.author.id) or message.author
	if message.author.bot then return end
	local settings = Database:get(message, "Settings")
	local channel = message.guild:getChannel(settings.audit_channel)
	if channel and member and settings.audit then
		local body = "**Message sent by "..member.mentionString.." ("..member.fullname..")".." deleted in "..message.channel.mentionString.." ("..message.channel.name..")".."**\n"..message.content
		if message.attachments then
			for i,t in ipairs(message.attachments) do
				body = body.."\n[Attachment "..i.."]("..t.url..")"
			end
		end
		channel:send {embed={
			author = {name = member.fullname, icon_url = member.avatarURL},
			description = body,
			color = discordia.Color.fromRGB(255, 0, 0).value,
			timestamp = discordia.Date():toISO(),
			footer = {text = "ID: "..member.id}
		}}
	end
end

function Events.messageDeleteUncached(channel, messageID)
	for i,v in ipairs(discordia.storage.bulkDeletes) do
		if messageID==v then
			table.remove(discordia.storage.bulkDeletes,i)
			return
		end
	end
	local settings = Database:get(channel, "Settings")
	local logChannel = channel.guild:getChannel(settings.audit_channel)
	if logChannel and settings.audit then
		logChannel:send {embed={
			author = {name = channel.guild.name, icon_url = channel.guild.iconURL},
			description = "**Uncached message deleted in** "..channel.mentionString.." ("..channel.name..")",
			color = discordia.Color.fromRGB(255, 0, 0).value,
			timestamp = discordia.Date():toISO(),
			footer = {text = "ID: "..channel.id}
		}}
	end
end

function Events.Timing(data)
	local args=string.split(data,'||')
	if args[1]=='REMINDER'then
		local g=client:getGuild(args[2])
		if g then
			local m=g:getMember(args[3])
			if not m then return end
			local time=timeBetween(toSeconds(parseHumanTime(args[4])))
			if m then
				m:send{embed={
					title='Reminder from '..time..' ago',
					description=args[5],
					color=discordia.Color.fromHex('#5DA9FF').value,
				}}
			end
		end
	end
end

function Events.raw(raw)
	local payload = json.parse(raw)
	if payload.t == 'MESSAGE_DELETE_BULK' then
		discordia.storage.bulkDeletes = payload.d.ids or {}
	end
end

function Events.ready()
	Timing:on(Events.Timing)
	for g in client.guilds:iter() do
		Database:get(g)
		Timing:load(g)
	end
	client:setGame({
		name = "Awoo! | m!help",
		type = 2,
	})
	errLog = client:getChannel('376422808852627457')
	comLog = client:getChannel('376422940570419200')
	logger:log(3, "Logged in as %s", client.user.fullname)
end
