addCommand('Ping', 'Ping!', 'ping', '', 0, false, false, function(message, args)
    local response = message:reply("Pong!")
    if response then
        response:setContent("Pong!".."`"..math.round((response.createdAt - message.createdAt)*1000).." ms`")
    end
end)

addCommand('Prefix', 'Show the prefix for the guild', 'prefix', '', 0, false, true, function(message, args)
    local settings = Database:Get(message, "Settings")
    message:reply("The prefix for "..message.guild.name.." is `"..settings.prefix.."`")
end)

addCommand('Info', 'Info on the bot', 'info', '', 0, false, false, function(message, args)
    message:reply{embed={
        author = {name=client.user.name, icon_url=client.user.avatarURL},
        thumbnail = {url=client.user.avatarURL},
        timestamp = discordia.Date():toISO(),
        description = "I'm a moderation bot created in the [Lua](http://www.lua.org/) scripting language using the [Discordia](https://github.com/SinisterRectus/Discordia) framework.",
        fields = {
            {name="Guilds",value=#client.guilds,inline=true},
            {name="Shards",value=client.shardCount,inline=true},
            {name="Owner",value=client.owner.fullname,inline=true},
            {name="Support Server",value="[Momiji's House](https://discord.gg/YYdpsNc)",inline=true},
            {name="Invite me!",value="[Invite](https://discordapp.com/oauth2/authorize/?permissions=335670488&scope=bot&client_id=345316276098433025)",inline=true},
            {name="Github",value="https://github.com/Mishio595/momiji",inline=true},
        },
    }}
end)

addCommand('Time', 'Get the current time', 'time', '', 0, false, false, function(message, args)
    message:reply(humanReadableTime(discordia.Date():toTableUTC()).." UTC")
end)

addCommand('Help', 'Display help information', 'help', '[command]', 0, false, false, function(message, args)
    local cmds = Commands
    local order = {
        "General", "Mod", "Admin", "Guild Owner", "Bot Owner",
    }
    if args == "" then
        local help = {}
        for com, tbl in pairs(cmds) do
            if not help[tbl.rank+1] then help[tbl.rank+1] = "" end
            if type(tbl.commands)=='string' then
                help[tbl.rank+1] = help[tbl.rank+1].."`"..tbl.name.." "..tbl.usage.."` - "..tbl.description.."\n"
            elseif type(tbl.commands)=='table' then
                names = ""
                for _,v in pairs(tbl.commands) do
                    if names == "" then names = v else names = names.."|"..v end
                end
                help[tbl.rank+1] = help[tbl.rank+1].."`"..names.." "..tbl.usage.."` - "..tbl.description.."\n"
            end
        end
        local sorted,c = {},1
        for i,v in ipairs(order) do
            if sorted[c] and #sorted[c]+string.len("**"..v.."**\n"..help[i]) >= 2000 then
                c = c+1
            end
            if not sorted[c] then
                sorted[c] = ""
            end
            sorted[c] = sorted[c].."**"..v.."**\n"..help[i]
        end
        message.author:send("**How to read this doc:**\nWhen reading the commands, arguments in angle brackets (`<>`) are mandatory\nwhile arguments in square brackets (`[]`) are optional.\nA pipe character `|` means or, so `a|b` means a **or** b.\nNo brackets should be included in the commands")
        for _,v in ipairs(sorted) do status = message.author:send(v) end
    else
        cmd = nil
        for k,v in pairs(cmds) do
            if args == v.name then
                cmd = v
                break
            end
            for _,j in pairs(v.commands) do
                if j == args then
                    cmd = v
                    break
                end
            end
        end
        if cmd then
            names = ""
            for _,v in pairs(cmd.commands) do
                if names == "" then names = v else names = names.."|"..v end
            end
            message:reply {embed={
                title = cmd.name,
                description = cmd.description,
                fields = {
                    {name = "Usage", value = names.." "..cmd.usage},
                    {name = "Rank required", value = order[cmd.rank+1]},
                },
            }}
        end
    end
end)

addCommand('Server Info', "Get information on the server", {'serverinfo','si'}, '[serverID]', 0, false, true, function(message, args)
    local guild = message.guild
    if client:getGuild(args) then
        guild = client:getGuild(args)
    end
    local humans, bots, online = 0,0,0
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
    timestamp = humanReadableTime(parseTime(guild.timestamp):toTable())
    fields = {
        {name = 'ID', value = guild.id, inline = true},
        {name = 'Name', value = guild.name, inline = true},
        {name = 'Owner', value = guild.owner.mentionString, inline = true},
        {name = 'Region', value = guild.region, inline = true},
        {name = 'Channels ['..#guild.textChannels+#guild.voiceChannels..']', value = "Text: "..#guild.textChannels.."\nVoice: "..#guild.voiceChannels, inline = true},
        {name = 'Members ['..online.."/"..#guild.members..']', value = "Humans: "..humans.."\nBots: "..bots, inline = true},
        {name = 'Roles', value = #guild.roles, inline = true},
        {name = 'Emojis', value = #guild.emojis, inline = true},
    }
    message:reply {
        embed = {
            author = {name = guild.name, icon_url = guild.iconURL},
            fields = fields,
            thumbnail = {url = guild.iconURL, height = 200, width = 200},
            color = discordia.Color.fromHex('#5DA9FF').value,
            footer = { text = "Server Created : "..timestamp }
        }
    }
end)

addCommand('Role Info', "Get information on a role", {'roleinfo', 'ri'}, '<roleName>', 0, false, true, function(message, args)
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
end)

addCommand('User Info', "Get information on a user", {'userinfo','ui'}, '[@user|userID]', 0, false, true, function(message, args)
    local guild = message.guild
    local member
    if args ~= "" then
        m = guild:getMember(resolveMember(message.guild, args))
        if m then
            member = m
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
        local joinTime = humanReadableTime(parseTime(member.joinedAt):toTableUTC())
        local createTime = humanReadableTime(parseTime(member.timestamp):toTableUTC())
        local users = Database:Get(message, "Users")
        local registerTime = "N/A"
        if users[member.id] then
            if users[member.id].registered ~= "" then
                registerTime = humanReadableTime(parseTime(users[member.id].registered):toTableUTC())
            end
        end
        local fields = {
            {name = 'ID', value = member.id, inline = true},
            {name = 'Mention', value = member.mentionString, inline = true},
            {name = 'Nickname', value = member.name, inline = true},
            {name = 'Status', value = member.status, inline = true},
            {name = 'Joined', value = joinTime, inline = false},
            {name = 'Created', value = createTime, inline = false},
        }
        if message.guild.id=='348660188951216129' then table.insert(fields, {name = 'Registered', value = registerTime, inline = false}) end
        table.insert(fields, {name = 'Extras', value = "[Fullsize Avatar]("..member.avatarURL..")", inline = false})
        table.insert(fields, {name = 'Roles ('..#member.roles..')', value = roles, inline = false})
        message.channel:send {
            embed = {
                author = {name = member.username.."#"..member.discriminator, icon_url = member.avatarURL},
                fields = fields,
                thumbnail = {url = member.avatarURL, height = 200, width = 200},
                color = member:getColor().value,
                timestamp = discordia.Date():toISO()
            }
        }
        return status
    else
        message.channel:send("Sorry, I couldn't find that user.")
    end
end)
