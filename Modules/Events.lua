Events = {}
local errLog, comLog

function Events.messageCreate(msg)
    if msg.author.bot then return end
    local private
    if msg.guild then private=false else private=true end
    local sender = (private and msg.author or msg.member or msg.guild:getMember(msg.author))
    if not private then
        --Load settings for the guild, Database.lua keeps a cache of requests to avoid mmaking excessive queries
        data = Database:Get(msg)
        if data.Users==nil or data.Users[msg.author.id]==nil then
            data.Users[msg.author.id] = { registered="", watchlisted=false, under18=false, last_message=discordia.Date():toISO() }
        else
            data.Users[msg.author.id].last_message = discordia.Date():toISO()
        end
        Database:Update(msg, "Users", data.Users)
    end
    if msg.content == client.user.mentionString.." prefix" then msg:reply("The prefix for "..msg.guild.name.." is `"..data.Settings.prefix.."`") end
    local command, rest = resolveCommand(msg.content, private, data.Settings.prefix)
    if not command then return end --If the prefix isn't there, don't bother with anything else
    local rank = getRank(sender, not private)
    for name,tab in pairs(Commands) do
        for ind,cmd in pairs(tab.commands) do
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
                                color = require('utils/Color').fromRGB(255, 0 ,0).value,
                            }}
                        end
                        if tab.name ~= "Prune" then msg:addReaction('❌') end
                    else
                        if tab.name ~= "Prune" then msg:addReaction('✅') end
                    end
                    if comLog then
                        comLog:send{embed={
                            fields={
                                {name="Command",value=tab.name,inline=true},
                                {name="Guild",value=msg.guild.name,inline=true},
                                {name="Author",value=msg.author.fullname,inline=true},
                                {name="Message Content",value="```"..msg.content.."```"},
                            },
                            footer = {text="ID: "..msg.id},
                            timestamp=discordia.Date():toISO(),
                        }}
                    end
                else
                    if tab.name ~= "Prune" then msg:addReaction('❌') end
                    msg:reply("Insufficient permission to execute command: "..tab.name..". Rank "..tostring(tab.rank).." expected, your rank: "..tostring(rank))
                end
            end
        end
    end
end


function Events.memberJoin(member)
    local settings = Database:Get(member, "Settings")
    if settings['welcome_message'] ~= "" and settings['welcome_channel'] and settings['welcome'] then
        --TODO: make a system so all guilds can use embeds
        channel = member.guild:getChannel(settings['welcome_channel'])
        if member.guild.id == '348660188951216129' then
            channel:send{embed = {
				title = "Welcome to "..member.guild.name.."!",
				description = "Hello, "..member.name..". Please read through <#348660188951216130> and inform a member of staff how you identify, what pronouns you would like to use, and your age. These are required.",
				thumbnail = {url = member.avatarURL, height = 200, width = 200},
				color = discordia.Color.fromRGB(0, 255, 0).value,
			}}
        else
            channel:send(formatMessageSimple(settings['welcome_message'], member))
        end
    end
    --Join message
    local channel = member.guild:getChannel(settings.audit_channel)
    if settings.audit and channel then
        channel:send {embed={
            author = {name = "Member Joined", icon_url = member.avatarURL},
            description = member.mentionString.." "..member.username.."#"..member.discriminator,
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
end

function Events.memberLeave(member)
    local settings = Database:Get(member, "Settings")
    local channel = member.guild:getChannel(settings.audit_channel)
    if settings.audit and channel then
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
    local settings = Database:Get(member, "Settings")
    if settings['introduction_message'] ~= "" and settings['introduction_channel'] and settings['introduction'] then
        --TODO: make a system so all guilds can use embeds
        channel = member.guild:getChannel(settings['introduction_channel'])
        channel:send(formatMessageSimple(settings['introduction_message'], member))
    end
end

function Events.userBan(user, guild)
    local member = guild:getMember(user) or user
    local settings = Database:Get(guild, "Settings")
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
    local settings = Database:Get(guild, "Settings")
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
    local member = message.member or message.guild:getMember(message.author.id) or message.author
    local settings = Database:Get(message, "Settings")
	local channel = message.guild:getChannel(settings.audit_channel)
	if channel and member and settings.audit then
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
    local settings = Database:Get(channel, "Settings")
	local channel = channel.guild:getChannel(settings.audit_channel)
	if channel and settings.audit then
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
    errLog = client:getChannel('376422808852627457')
    comLog = client:getChannel('376422940570419200')
end
