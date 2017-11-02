Events = {}

function Events.memberJoin(member)
    local settings = client:getDB():Get(member, "Settings")
    if settings['welcome_message'] ~= "" and settings['welcome_channel'] and settings['welcome'] then
        --TODO: make a system so all guilds can use embeds
        if member.guild.id == '348660188951216129' then
            member.guild:getChannel(settings['welcome_channel']):send{embed = {
				title = "Welcome to "..member.guild.name.."!",
				description = "Hello, "..member.name..". Please read through <#348660188951216130> and inform a member of staff how you identify, what pronouns you would like to use, and your age. These are required.",
				thumbnail = {url = member.avatarURL, height = 200, width = 200},
				color = discordia.Color.fromRGB(0, 255, 0).value,
			}}
        else
            member.guild:getChannel(settings['welcome_channel']):send(settings['welcome_message'])
        end
    end
    --Join message
    local channel = member.guild:getChannel(settings.audit_log_channel)
    if settings.audit_log and channel then
        channel:send {embed={
            author = {name = "Member Joined", icon_url = member.avatarURL},
            description = member.mentionString.." "..member.username.."#"..member.discriminator,
            thumbnail = {url = member.avatarURL, height = 200, width = 200},
            color = discordia.Color.fromRGB(0, 255, 0).value,
            timestamp = discordia.Date():toISO(),
            footer = {text = "ID: "..member.id}
        }}
    end
end

function Events.memberLeave(member)
    local settings = client:getDB():Get(member, "Settings")
    local channel = member.guild:getChannel(settings.audit_log_channel)
    if settings.audit_log and channel then
        channel:send {embed={
            author = {name = "Member Left", icon_url = member.avatarURL},
            description = member.mentionString.." "..member.username.."#"..member.discriminator,
            thumbnail = {url = member.avatarURL, height = 200, width = 200},
            color = discordia.Color.fromRGB(255, 0, 0).value,
            timestamp = discordia.Date():toISO(),
            footer = {text = "ID: "..member.id}
        }}
    end
end

function Events.presenceUpdate(member)
    role = '370395740406546432'
    if member.guild.id == '348660188951216129' then
    	if (member.gameType == enums.gameType.streaming) and not member:hasRole(role) then
    		member:addRole(role)
    	elseif member:hasRole(role) then
    		member:removeRole(role)
    	end
    end
end

function Events.memberRegistered(member)
    local settings = client:getDB():Get(member, "Settings")
    local channel = member.guild:getChannel(settings.introduction_channel)
    if channel and settings.introduction then
        if member.guild.i == '348660188951216129' then
            channel:send("Welcome to "..member.guild.name..", "..member.mentionString..". If you're comfortable doing so, please share a bit about yourself!")
        else
            channel:send(settings.introduction_message)
        end
	end
end

function Events.userBan(user, guild)
    local member = guild:getMember(user) or user
    local settings = client:getDB():Get(guild, "Settings")
	local channel = guild:getChannel(settings.mod_log_channel)
	if channel and member and settings.mod_log then
		channel:send {embed={
			author = {name = "Member Banned", icon_url = member.avatarURL},
			description = member.mentionString.." "..member.username.."#"..member.discriminator,
			thumbnail = {url = member.avatarURL, height = 200, width = 200},
			color = discordia.Color.fromRGB(255, 0, 0).value,
			timestamp = discordia.Date():toISO(),
			footer = {text = "ID: "..member.id}
		}}
	end
end

function Events.userUnban(user, guild)
    local member = guild:getMember(user) or user
    local settings = client:getDB():Get(guild, "Settings")
	local channel = guild:getChannel(settings.mod_log_channel)
	if channel and member and settings.mod_log then
		channel:send {embed={
			author = {name = "Member Unbanned", icon_url = member.avatarURL},
			description = member.mentionString.." "..member.username.."#"..member.discriminator,
			thumbnail = {url = member.avatarURL, height = 200, width = 200},
			color = discordia.Color.fromRGB(0, 255, 0).value,
			timestamp = discordia.Date():toISO(),
			footer = {text = "ID: "..member.id}
		}}
	end
end

function Events.messageDelete(message)
    local member = message.member or message.guild:getMember(message.author.id)
    local settings = client:getDB():Get(message, "Settings")
	local channel = message.guild:getChannel(settings.audit_log_channel)
	if channel and member and settings.audit_log then
		body = "**Message sent by "..member.mentionString.." deleted in "..message.channel.mentionString.."**\n"..message.content
		if message.attachments then
			for i,t in ipairs(message.attachments) do
				body = body.."\n[Attachment "..i.."]("..t.url..")"
			end
		end
		channel:send {embed={
			author = {name = member.username.."#"..member.discriminator, icon_url = member.avatarURL},
			description = body,
			color = discordia.Color.fromRGB(255, 0, 0).value,
			timestamp = discordia.Date():toISO(),
			footer = {text = "ID: "..member.id}
		}}
	end
end

function Events.messageDeleteUncached(channel, messageID)
    local settings = client:getDB():Get(channel, "Settings")
	local channel = channel.guild:getChannel(settings.audit_log_channel)
	if channel and settings.audit_log then
		channel:send {embed={
            author = {name = channel.guild.name, icon_url = channel.guild.iconURL},
            description = "**Uncached message deleted in** "..channel.mentionString,
            color = discordia.Color.fromRGB(255, 0, 0).value,
            timestamp = discordia.Date():toISO(),
            footer = {text = "ID: "..channel.id}
		}}
	end
end

function Events.ready()
    print("Ready!")
    client:setGame("m!help | Awoo!")
end
