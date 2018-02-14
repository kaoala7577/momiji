--[[ Adapted from DannehSC/Electricity-2.0 ]]

Events = {}
local errLog, comLog, guildLog

function Events.messageCreate(msg)
	if msg.author.bot then return end
	local private, data
	if msg.guild then private=false else private=true end
	local sender = (private and msg.author or msg.member or msg.guild:getMember(msg.author))
	local rank = getRank(sender, not private)
	if not private then
		--Load settings for the guild, Database.lua keeps a cache of requests to avoid making excessive queries
		data = Database:getCached(msg)
		if data.Ignore[msg.channel.id] and rank<3 then
			return
		end
	end
	if msg.content:lower():match("%s?i need a hug%s?") then
		msg.channel:sendf("*hugs %s*", msg.author.mentionString)
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
						local g = not private and msg.guild or {name="Private", id=""}
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
							color = Colors.blue.value,
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
	--Reference Hackban list
	local hackbans = Database:get(member, "Hackbans")
	if table.search(hackbans, member.id) then
		return member:ban("Hackban")
	end
	--Welcome message
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
			color = Colors.green.value,
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
	--Create user entry in DB
	if member.guild.totalMemberCount<600 then --Temporary workaround until reql fixes its shit
		local roles = {}
		for role in member.roles:iter() do
			table.insert(roles, role.id)
		end
		local users = Database:get(member, "Users")
		users[member.id] = {last_message=discordia.Date():toISO(), nick=member.nickname, roles=roles}
		Database:update(member, "Users", users)
	end
end

function Events.memberLeave(member)
	local settings = Database:get(member, "Settings")
	local channel = member.guild:getChannel(settings.audit_channel)
	if settings.audit and channel then
		channel:send {embed={
			author = {name = "Member Left", icon_url = member.avatarURL},
			description = member.mentionString.."\n"..member.fullname,
			thumbnail = {url = member.avatarURL, height = 200, width = 200},
			color = Colors.red.value,
			timestamp = discordia.Date():toISO(),
			footer = {text = "ID: "..member.id}
		}}
	end
	--Wait a few seconds for the audit log to populate
	timer.sleep(3*1000)
	--End wait
	local guild = member.guild
	channel = guild:getChannel(settings.modlog_channel)
	if channel and member and settings.modlog then
		local audit = guild:getAuditLogs({
			limit = 1,
			type = enums.actionType.memberKick,
		}):iter()()
		if audit and audit:getTarget().id ~= member.id then audit = nil end
		local reason = audit and audit.reason or nil
		channel:send{embed={
			author = {name = "Member Kicked", icon_url = member.avatarURL},
			description = string.format("%s\n%s\n**Responsible Moderator: ** %s\n**Reason:** %s", member.mentionString, member.fullname, audit and audit:getMember().fullname or "N/A", reason or "None"),
			thumbnail = {url = member.avatarURL, height = 200, width = 200},
			color = Colors.red.value,
			timestamp = discordia.Date():toISO(),
			footer = {text = "ID: "..member.id}
		}}
	end
	--kill their entry in the DB
	local users = Database:get(member, "Users")
	users[member.id] = nil
	Database:update(member, "Users", users)
end

function Events.presenceUpdate(member)
	if member.user.bot == true then return end
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
	local channel = member.guild:getChannel(settings.audit_channel)
	local newRoles = {}
	for role in member.roles:iter() do
		table.insert(newRoles, role.id)
	end
	if users[member.id] and settings.audit and channel then
		if users[member.id].nick~=member.nickname then
			channel:send{embed={
				title = "Nickname Changed",
				description = string.format("**User:** %s\n**Old:** %s\n**New:** %s",member.fullname,users[member.id].nick or "None",member.nickname or "None"),
				thumbnail = {url=member.avatarURL},
				color = Colors.blue.value,
				timestamp = discordia.Date():toISO(),
				footer = {text="ID: "..member.id},
			}}
		end
		local oldRoles = users[member.id].roles
		local changedRoles, t = {}, ""
		local longer = #oldRoles>#newRoles and oldRoles or newRoles
		for _,v in ipairs(longer) do
			local role = member.guild:getRole(v)
			if table.search(oldRoles, v) and not table.search(newRoles, v) then
				t = "Removed"
				table.insert(changedRoles,role.name)
			elseif table.search(newRoles, v) and not table.search(oldRoles, v) then
				t = "Added"
				table.insert(changedRoles,role.name)
			end
		end
		if changedRoles[1]~=nil then
			local changes = table.concat(changedRoles, ", ")
			channel:send{embed={
				title = "Roles Changed",
				description = string.format("**User:** %s\n**%s:** %s", member.fullname, t, changes),
				thumbnail = {url=member.avatarURL},
				color = Colors.blue.value,
				timestamp = discordia.Date():toISO(),
				footer = {text="ID: "..member.id}
			}}
		end
	end
	if member.guild.totalMemberCount<600 then
		if users[member.id] then
			users[member.id].nick = member.nickname
			users[member.id].roles = newRoles
		else
			users[member.id] = {nick = member.nickname, roles = newRoles}
		end
		Database:update(member, "Users", users)
	end
end

function Events.userBan(user, guild)
	--Wait a few seconds for the audit log to populate
	timer.sleep(3*1000)
	--End wait
	local member = guild:getMember(user) or user
	local settings = Database:get(guild, "Settings")
	local channel = guild:getChannel(settings.modlog_channel)
	if channel and member and settings.modlog then
		local audit = guild:getAuditLogs({
			limit = 1,
			type = enums.actionType.memberBanAdd,
		}):iter()()
		if audit and audit:getTarget().id ~= user.id then audit = nil end
		local reason = audit and audit.reason or nil
		channel:send{embed={
			author = {name = "Member Banned", icon_url = member.avatarURL},
			description = string.format("%s\n%s\n**Responsible Moderator: ** %s\n**Reason:** %s", member.mentionString, member.fullname, audit and audit:getMember().fullname or "N/A", reason or "None"),
			thumbnail = {url = member.avatarURL, height = 200, width = 200},
			color = Colors.red.value,
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
			color = Colors.green.value,
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
		local body = "**Author:** "..member.mentionString.." ("..member.fullname..")\n**Channel:** "..message.channel.mentionString.." ("..message.channel.name..")\n**Content:**\n"..message.content
		if message.attachments then
			for i,t in ipairs(message.attachments) do
				body = body.."\n[Attachment "..i.."]("..t.url..")"
			end
		end
		channel:send {embed={
			author = {name = "Message Deleted", icon_url = member.avatarURL},
			description = body,
			color = Colors.red.value,
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
			author = {name = "Uncached Message Deleted", icon_url = channel.guild.iconURL},
			description = "**Channel:** "..channel.mentionString.." ("..channel.name..")",
			color = Colors.red.value,
			timestamp = discordia.Date():toISO(),
			footer = {text = "ID: "..channel.id}
		}}
	end
end

function Events.guildCreate(guild)
	API.misc.DBots_Stats_Update({server_count=#client.guilds})
	guild.owner:sendf("Thanks for inviting me to %s! To get started, you should read the help page with the command `m!help` and configure your settings. If you've got questions or just want to receive updates, join my support server (link is in the `m!info` response)", guild.name)
	guildLog:send{embed={
		title = "Joined Guild",
		description = string.format("**Name:** %s\n**ID:** %s\n**Owner:** %s (%s)", guild.name, guild.id, guild.owner.fullname, guild.owner.id),
		color = Colors.green.value,
		timestamp = discordia.Date():toISO(),
	}}
end

function Events.guildDelete(guild)
	guildLog:send{embed={
		title = "Left Guild",
		description = string.format("**Name:** %s\n**ID:** %s\n**Owner:** %s (%s)", guild.name, guild.id, guild.owner.fullname, guild.owner.id),
		color = Colors.red.value,
		timestamp = discordia.Date():toISO(),
	}}
end

function Events.Timing(data)
	local args = string.split(data,'||')
	if args[1]=='REMINDER' then
		local g = client:getGuild(args[2])
		if g then
			local m = g:getMember(args[3])
			local time = args[4]
			if m then
				m:send{embed={
					title='Reminder from '..time..' ago',
					description=args[5],
					color=Colors.blue.value,
				}}
			end
		end
	elseif args[1]=='UNMUTE' then
		local g = client:getGuild(args[2])
		if g then
			local settings = Database:get(g, "Settings")
			local m = g:getMember(args[3])
			local time = args[4]
			if m then
				local s = m:removeRole(g.roles:find(function(r) return r.name=='Muted' end))
				if s and settings.modlog and settings.modlog_channel then
					g:getChannel(settings.modlog_channel):send{embed={
						title = "Member Unmuted Automatically",
						fields = {
							{name = "Member", value = m.mentionString.."\n"..m.fullname, inline = true},
							{name = "Moderator", value = client.user.mentionString.."\n"..client.user.fullname, inline = true},
							{name = "Duration", value = time, inline = true},
						}
					}}
				end
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
	API.misc.DBots_Stats_Update({server_count=#client.guilds})
	errLog = client:getChannel('376422808852627457')
	comLog = client:getChannel('376422940570419200')
	guildLog = client:getChannel('406115496833056789')
	Timing:on(Events.Timing)
	for g in client.guilds:iter() do
		Database:get(g)
		Timing:load(g)
	end
	client:setGame({
		name = string.format("%s guilds | m!help", #client.guilds),
		type = 2,
	})
	logger:log(3, "Logged in as %s", client.user.fullname)
end
