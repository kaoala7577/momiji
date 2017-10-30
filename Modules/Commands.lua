client:addCommand('Ping', 'Ping!', 'ping', 0, false, false, function(message, args)
    local response = message:reply("Pong!")
    if response then
        response:setContent("Pong!".."`"..math.round((response.createdAt - message.createdAt)*1000).." ms`")
    end
end)

--TODO: Fetch Members first
client:addCommand('Server Info', "Get information on the server", {'serverinfo','si'}, 0, false, true, function(message, args)
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
    message:reply {
        embed = {
            author = {name = guild.name, icon_url = guild.iconURL},
            fields = fields,
            thumbnail = {url = guild.iconURL, height = 200, width = 200},
            color = discordia.Color.fromRGB(244, 198, 200).value,
            footer = { text = "Server Created : "..timestamp }
        }
    }
end)

client:addCommand('Role Info', "Get information on a role", {'roleinfo', 'ri'}, 0, false, true, function(message, args)
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

client:addCommand('User Info', "Get information on a user", {'userinfo','ui'}, 0, false, true, function(message, args)
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
        --local registerTime = utils.parseTime(conn:execute(string.format([[SELECT registered FROM members WHERE member_id='%s';]], member.id)):fetch())
        -- if registerTime ~= 'N/A' then
        --     registerTime = registerTime:toTable()
        --     registerTime = humanReadableTime(registerTime)
        -- end
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
                    --{name = 'Registered', value = registerTime, inline = false},
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
end)

client:addCommand('Lua', "Execute arbitrary lua code", "lua", 4, false, false, function(message, args)
    args = string.gsub(args, "`", ""):gsub("lua", ""):trim()
    printresult = ""
    local oldPrint = print
    print = function(...)
        arg = {...}
        for i,v in ipairs(arg) do
            printresult = printresult..tostring(v).."\t"
        end
        printresult = printresult.."\n"
    end
    local a = loadstring(args)
    if a then
        setfenv(a,getfenv())
        local status, ret = pcall(a)
        if not ret then ret = printresult else ret = ret.."\n"..printresult end
        if ret ~= "" and #ret < 1800 then
            message:reply("```"..ret.."```")
        elseif ret ~= "" then
            ret1 = ret:sub(0,1800)
            ret2 = ret:sub(1801)
            message:reply("```"..ret1.."```")
            message:reply("```"..ret2.."```")
        end
    end
    print = oldPrint
end)
