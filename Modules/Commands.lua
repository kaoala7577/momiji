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

client:addCommand('Add Self Role', 'Add a role to yourself from the self role list', {'role', 'asr'}, 0, true, true, function(message, args)
    local member = message.member
    local selfRoles = message.client:getDB():Get(message, "Roles")
    local roles = args
    local rolesToAdd, rolesFailed = {}, {}
    for k,l in pairs(selfRoles) do
        for r,a in pairs(l) do
            for _,role in ipairs(roles) do
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
end)

client:addCommand('Remove Self Role', 'Remove a role from the self role list from yourself', {'derole','rsr'}, 0, true, true, function(message, args)
    local roles = args
    local member = message.member
    local selfRoles = message.client:getDB():Get(message, "Roles")
    local rolesToRemove = {}
    for _,l in pairs(selfRoles) do
        for r,a in pairs(l) do
            for _,role in pairs(roles) do
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
end)

client:addCommand('List Self Roles', 'List all roles in the self role list', 'roles', 0, false, true, function(message, args)
    local roleList, cats = {},{}
    local selfRoles = message.client:getDB():Get(message, "Roles")
    for k,v in pairs(selfRoles) do
        for r,_ in pairs(v) do
            if not roleList[k] then
                roleList[k] = r.."\n"
            else
                roleList[k] = roleList[k]..r.."\n"
            end
        end
        table.insert(cats, {name = k, value = roleList[k], inline = true})
    end
    message.channel:send {
        embed = {
            author = {name = "Self-Assignable Roles", icon_url = message.guild.iconURL},
            fields = cats,
        }
    }
end)

client:addCommand('Config', 'Update configuration for the current guild', 'config', 3, false, true, function(message, args)
    args = args:split(' ')
    for i,v in pairs(args) do args[i] = v:trim() end
    settings = client:getDB():Get(message, "Settings")
    --TODO: Think of a way to tidy this up
    if args[1] == 'prefix' then
        settings['prefix'] = args[2] and args[2] or settings['prefix']
    elseif args[1] == 'admin' then
        if args[2] == 'add' then
            settings['admin_roles'][#settings['admin_roles']+1] = args[3] and args[3] or nil
        elseif args[2] == 'remove' then
            settings['admin_roles'][args[3]] = nil
        end
    elseif args[1] == 'mod' then
        if args[2] == 'add' then
            settings['mod_roles'][#settings['mod_roles']+1] = args[3] and args[3] or nil
        elseif args[2] == 'remove' then
            settings['mod_roles'][args[3]] = nil
        end
    elseif args[1] == 'audit' then
        if args[2] == 'enable' then
            settings['audit_log'] = true
        elseif args[2] == 'disable' then
            settings['audit_log'] = false
        elseif args[2] == 'set' then
            settings['audit_log_channel'] = args[3] and args[3] or ''
        end
    elseif args[1] == 'modlog' then
        if args[2] == 'enable' then
            settings['mod_log'] = true
        elseif args[2] == 'disable' then
            settings['mod_log'] = false
        elseif args[2] == 'set' then
            settings['mod_log_channel'] = args[3] and args[3] or ''
        end
    elseif args[1] == 'welcome' then
        if args[2] == 'enable' then
            settings['welcome'] = true
        elseif args[2] == 'disable' then
            settings['welcome'] = false
        elseif args[2] == 'set' then
            settings['welcome_channel'] = args[3] and args[3] or ''
        end
    elseif args[1] == 'introduction' then
        if args[2] == 'enable' then
            settings['introduction'] = true
        elseif args[2] == 'disable' then
            settings['introduction'] = false
        elseif args[2] == 'set' then
            settings['introduction_channel'] = args[3] and args[3] or ''
        end
    end
    client:getDB():Update(message, "Settings", settings)
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
