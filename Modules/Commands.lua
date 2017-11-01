client:addCommand('Ping', 'Ping!', 'ping', '', 0, false, false, function(message, args)
    local response = message:reply("Pong!")
    if response then
        response:setContent("Pong!".."`"..math.round((response.createdAt - message.createdAt)*1000).." ms`")
    end
end)

client:addCommand('Time', 'Get the current time', 'time', 0, false, false, function(message, args)
    message:reply(humanReadableTime(discordia.Date():toTableUTC()).." UTC")
end)

client:addCommand('Help', 'Display help information', 'help', '[command]', 0, false, false, function(message, args)
    local cmds = client:getCommands()
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

--TODO: Fetch Members first
client:addCommand('Server Info', "Get information on the server", {'serverinfo','si'}, '[serverID]', 0, false, true, function(message, args)
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

client:addCommand('Role Info', "Get information on a role", {'roleinfo', 'ri'}, '<roleName>', 0, false, true, function(message, args)
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

client:addCommand('User Info', "Get information on a user", {'userinfo','ui'}, '[@user|userID]', 0, false, true, function(message, args)
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
        local users = client:getDB():Get(message, "Users")
        local registerTime = "N/A"
        if users[member.id] then
            if users[member.id].registered ~= "" then
                registerTime = humanReadableTime(parseTime(users[member.id].registered):toTableUTC())
            end
        end
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
                    {name = 'Registered', value = registerTime, inline = false},
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

client:addCommand('Add Self Role', 'Add role(s) to yourself from the self role list', {'role', 'asr'}, '<role[, role, ...]>', 0, true, true, function(message, args)
    local member = message.member or message.guild:getMember(message.author.id)
    local selfRoles = message.client:getDB():Get(message, "Roles")
    if not selfRoles then return end
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

client:addCommand('Remove Self Role', 'Remove role(s) from the self role list from yourself', {'derole','rsr'}, '<role[, role, ...]>', 0, true, true, function(message, args)
    local roles = args
    local member = message.member or message.guild:getMember(message.author.id)
    local selfRoles = message.client:getDB():Get(message, "Roles")
    if not selfRoles then return end
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
    local roleList = ""
    for _,role in ipairs(rolesToRemove) do
        function fn(r) return r.name == role end
        member:removeRole(member.guild.roles:find(fn))
        roleList = roleList..role.."\n"
    end
    if #rolesToRemove > 0 then
        message.channel:send {
            embed = {
                author = {name = "Roles Removed", icon_url = member.avatarURL},
                description = "**Removed "..member.mentionString.." from the following roles** \n"..roleList,
                color = member:getColor().value,
                timestamp = discordia.Date():toISO(),
                footer = {text = "ID: "..member.id}
            }
        }
    end
end)

client:addCommand('List Self Roles', 'List all roles in the self role list', 'roles', '', 0, false, true, function(message, args)
    local roleList, cats = {},{}
    local selfRoles = message.client:getDB():Get(message, "Roles")
    if not selfRoles then return end
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

client:addCommand('Add Role', 'Add role(s) to the given user', 'ar', '<@user|userID> <role[, role, ...]>', 1, true, true, function(message, args)
    local member
    for i,v in ipairs(args) do
        pat = string.match(v, "[<@!]*(%d+)>*.*")
        if pat then
            member = resolveMember(message.guild, pat)
            args[i] = v:gsub(pat, ""):gsub("[<@!>]*",""):trim()
            if args[i] == "" then table.remove(args, i) end
        end
    end
    if member then
		local rolesToAdd = {}
		for _,role in pairs(args) do
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
			message.channel:send {
				embed = {
					author = {name = "Roles Added", icon_url = member.avatarURL},
					description = "**Added "..member.mentionString.." to the following roles** \n"..roleList,
					color = member:getColor().value,
					timestamp = discordia.Date():toISO(),
					footer = {text = "ID: "..member.id}
				}
			}
		end
	end
end)

client:addCommand('Remove Role', 'Removes role(s) from the given user', 'rr', '<@user|userID> <role[, role, ...]>', 1, true, true, function(message, args)
    local member
    for i,v in ipairs(args) do
        pat = string.match(v, "[<@!]*(%d+)>*.*")
        if pat then
            member = resolveMember(message.guild, pat)
            args[i] = v:gsub(pat, ""):gsub("[<@!>]*",""):trim()
            if args[i] == "" then table.remove(args, i) end
        end
    end
    if member then
        local rolesToRemove = {}
        for _,role in pairs(args) do
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
            message.channel:send {
                embed = {
                    author = {name = "Roles Removed", icon_url = member.avatarURL},
                    description = "**Removed "..member.mentionString.." from the following roles** \n"..roleList,
                    color = member:getColor().value,
                    timestamp = discordia.Date():toISO(),
                    footer = {text = "ID: "..member.id}
                }
            }
        end
    end
end)

client:addCommand('Register', 'Register a given user with the listed roles', {'reg', 'register'}, '<@user|userID> <role[, role, ...]>', 1, true, true, function(message, args)
    if message.guild.id ~= "348660188951216129" then return end
    local settings, selfRoles, users = client:getDB():Get(message, "Settings"), client:getDB():Get(message, "Roles"), client:getDB():Get(message, "Users")
    local channel = message.guild:getChannel(settings.mod_log_channel)
    local member
    for i,v in ipairs(args) do
        pat = string.match(v, "[<@!]*(%d+)>*.*")
        if pat then
            member = resolveMember(message.guild, pat)
            args[i] = v:gsub(pat, ""):gsub("[<@!>]*",""):trim()
            if args[i] == "" then table.remove(args, i) end
        end
    end
    if member then
        local rolesToAdd = {}
        local hasGender, hasPronouns
        for k,l in pairs(selfRoles) do
            for r,a in pairs(l) do
                for _,role in pairs(args) do
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
            local roleList, under18 = "", true
            for _,role in pairs(rolesToAdd) do
                function fn(r) return r.name == role end
                member:addRole(member.guild.roles:find(fn))
                if role == "18+" then under18 = false end
                roleList = roleList..role.."\n"
            end
            member:addRole('348873284265312267')
            if #rolesToAdd > 0 then
                channel:send {
                    embed = {
                        author = {name = "Registered", icon_url = member.avatarURL},
                        description = "**Registered "..member.mentionString.." with the following roles** \n"..roleList,
                        color = member:getColor().value,
                        timestamp = discordia.Date():toISO(),
                        footer = {text = "ID: "..member.id}
                    }
                }
                client:emit('memberRegistered', member)
                if users==nil or users[member.id]==nil then
                    users[member.id] = { registered=discordia.Date():toISO(), watchlisted=false, under18=under18, last_message="" }
                else
                    users[member.id].registered = discordia.Date():toISO()
                end
                client:getDB():Update(message, "Users", users)
            end
        else
            message:reply("Invalid registration command. Make sure to include at least one of gender identity and pronouns.")
        end
    end
end)

client:addCommand('Mod Info', "Get mod-related information on a user", {'mi','modinfo'}, '<@user|userID>', 1, false, true, function(message, args)
    local m
    pat = string.match(args, "[<@!]*(%d+)>*.*")
    if pat then
        m = resolveMember(message.guild, pat)
        args = args:gsub(pat, ""):gsub("[<@!>]*",""):trim()
    end
    if m then
        local users = client:getDB():Get(message, "Users")
        if users[m.id] then
            local watchlisted, under18 = users[m.id].watchlisted, users[m.id].under18
            if watchlisted then watchlisted = 'Yes' else watchlisted = 'No' end
            if under18 then under18 = 'Yes' else under18 = 'No' end
            status = message:reply {embed={
                author = {name = m.username.."#"..m.discriminator, icon_url = m.avatarURL},
                fields = {
                    {name = "Watchlisted", value = watchlisted, inline = true},
                    {name = "Under 18", value = under18, inline = true},
                },
                thumbnail = {url = m.avatarURL, height = 200, width = 200},
				color = m:getColor().value,
				timestamp = discordia.Date():toISO()
            }}
        end
    end
end)

client:addCommand('Notes', 'Add the note to, delete a note from, or view all notes for the mentioned user', 'note', '<add|del|view> [@user|userID] [note|index]', 1, false, true, function(message, args)
    local a = message.member or message.guild:getMember(message.author.id)
    local m
    pat = string.match(args, "[<@!]*(%d+)>*.*")
    if pat then
        m = resolveMember(message.guild, pat)
        args = args:gsub(pat, ""):gsub("[<@!>]*",""):trim()
    end
    if (args == "") or not m then return end
    local notes = client:getDB():Get(message, "Notes")
    if args:startswith("add") then
        args = args:gsub("^add",""):trim()
        if args and args ~= "" then
            if notes==nil or notes[m.id]==nil then
                notes[m.id] = {
                    {note=args, moderator=a.username, timestamp=discordia.Date():toISO()}
                }
            else
                notes[m.id][#notes[m.id]+1] = {note=args, moderator=a.username, timestamp=discordia.Date():toISO()}
            end
        end
    elseif args:startswith("del") then
        args = tonumber(args:gsub("^del",""):trim())
        if args and args ~= "" then
            if notes[m.id] then
                table.remove(notes[m.id], args)
            end
        end
    elseif args:startswith("view") then
        local notelist = {}
        if notes[m.id] then
            for i,v in ipairs(notes[m.id]) do
                table.insert(notelist, {name = i.." : added by "..v.moderator, value = v.note})
            end
        end
        message:reply {
            embed = {
                footer = {text = "Notes for "..m.username},
                fields = notelist,
            }
        }
    else
        message:reply("Please specify add, del, or view")
    end
    client:getDB():Update(message, "Notes", notes)
end)

client:addCommand('Watchlist', "Add/remove someone from the watchlist or view everyone on it", "wl", '<add|remove|list> [@user|userID]', 1, false, true, function(message, args)
    local users = client:getDB():Get(message, "Users")
    args = args:split(' ')
    local member
    for i,v in ipairs(args) do
        pat = string.match(v, "[<@!]*(%d+)>*.*")
        if pat then
            member = resolveMember(message.guild, pat)
            args[i] = v:gsub(pat, ""):gsub("[<@!>]*",""):trim()
            if args[i] == "" then table.remove(args, i) end
        end
    end
    if args[1] == 'add' then
        if users[member.id] == nil then
            --This shouldn't happen, but its here just in case
            users[member.id] = { registered="", watchlisted=true, under18=false, last_message="" }
        else
            users[member.id].watchlisted = true
        end
    elseif args[1] == 'remove' then
        if users[member.id] then
            users[member.id].watchlisted = false
        end
    elseif args[1] == 'list' then
        list = ""
        for id,v in pairs(users) do
            if v.watchlisted then
                list = list..message.guild:getMember(id).mentionString.."\n"
            end
        end
        if list ~= "" then
            message:reply {embed={
                title="Watchlist",
                description=list,
            }}
        end
    end
    client:getDB():Update(message, "Users", users)
end)

client:addCommand('Toggle 18', "Toggles the under18 flag on a user", 't18', '<@user|userID>', 1, false, true, function(message, args)
    local users = client:getDB():Get(message, "Users")
    local m
    pat = string.match(args, "[<@!]*(%d+)>*.*")
    if pat then
        m = resolveMember(message.guild, pat)
        args = args:gsub(pat, ""):gsub("[<@!>]*",""):trim()
    end
    if m then
        if users[m.id] then
            users[m.id].under18 = not users[m.id].under18
        end
    end
    client:getDB():Update(message, "Users", users)
end)

client:addCommand('Mute', 'Mutes a user', 'mute', '<@user|userID>', 1, false, true, function(message, args)
    local settings, cases = client:getDB():Get(message, "Settings"), client:getDB():Get(message, "Cases")
    local member
    pat = string.match(args, "[<@!]*(%d+)>*.*")
    if pat then
        member = resolveMember(message.guild, pat)
        args = args:gsub(pat, ""):gsub("[<@!>]*",""):trim()
    end
    if member then
        local role = message.guild.roles:find(function(r) return r.name == 'Muted' end)
        member:addRole(role)
        if cases==nil or cases[member.id]==nil then
            cases[member.id] = {
                {type="mute", reason=args, moderator=message.author.id, timestamp=discordia.Date():toISO()}
            }
        else
            cases[member.id][#cases[member.id]+1] = {type="mute", reason=args, moderator=message.author.id, timestamp=discordia.Date():toISO()}
        end
        if settings.mod_log then
            message.guild:getChannel(settings.mod_log_channel):send{embed={
                title = "Member Muted",
                fields = {
                    {name = "User", value = member.mentionString, inline = true},
                    {name = "Moderator", value = message.author.mentionString, inline = true},
                    {name = "Reason", value = args, inline = true},
                },
            }}
        end
    end
    client:getDB():Update(message, "Cases", cases)
end)

client:addCommand('Unmute', 'Unmutes a user', 'unmute', '<@user|userID>', 1, false, true, function(message, args)
    local settings, cases = client:getDB():Get(message, "Settings"), client:getDB():Get(message, "Cases")
    local member
    pat = string.match(args, "[<@!]*(%d+)>*.*")
    if pat then
        member = resolveMember(message.guild, pat)
        args = args:gsub(pat, ""):gsub("[<@!>]*",""):trim()
    end
    if member then
        local role = message.guild.roles:find(function(r) return r.name == 'Muted' end)
        member:removeRole(role)
        if cases==nil or cases[member.id]==nil then
            cases[member.id] = {
                {type="unmute", moderator=message.author.id, timestamp=discordia.Date():toISO()}
            }
        else
            cases[member.id][#cases[member.id]+1] = {type="unmute", moderator=message.author.id, timestamp=discordia.Date():toISO()}
        end
        if settings.mod_log then
            message.guild:getChannel(settings.mod_log_channel):send{embed={
                title = "Member Unmuted",
                fields = {
                    {name = "User", value = member.mentionString, inline = true},
                    {name = "Moderator", value = message.author.mentionString, inline = true},
                },
            }}
        end
    end
    client:getDB():Update(message, "Cases", cases)
end)

client:addCommand('Prune', 'Bulk deletes messages', 'prune', '<count>', 2, false, true, function(message, args)
    local settings = client:getDB():Get(message, "Settings")
    local author = message.member or message.guild:getMember(message.author.id)
    client:removeAllListeners(client, 'messageDelete')
    client:removeAllListeners(client, 'messageDeleteUncached')
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
        if settings.mod_log then
            message.guild:getChannel(settings.mod_log_channel):send {embed={
                description = "Moderator "..author.mentionString.." deleted "..numDel.." messages in "..message.channel.mentionString,
                color = discordia.Color.fromRGB(255, 0, 0).value,
                timestamp = discordia.Date():toISO()
            }}
        end
    end
    client:on('messageDelete', Events.messageDelete)
    client:on('messageDeleteUncached', Events.messageDeleteUncached)
end)

client:addCommand('Setup Mute', 'Sets up mute', 'setup', '', 3, false, true, function(message, args)
    local role = message.guild.roles:find(function(r) return r.name == 'Muted' end)
    if not role then
        role = guild:createRole("Muted")
    end
    for c in message.guild.textChannels:iter() do
        c:getPermissionOverwriteFor(role):denyPermissions(enums.permission.sendMessages, enums.permission.addReactions)
    end
    for c in message.guild.voiceChannels:iter() do
        c:getPermissionOverwriteFor(role):denyPermissions(enums.permission.speak)
    end
end)

client:addCommand('Config', 'Update configuration for the current guild', 'config', '<category> <option> [value]', 3, false, true, function(message, args)
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
        elseif args[2] == 'message' then
            settings['welcome_message'] = table.join(table.slice(args, 3, #args, 1), ' ')
        end
    elseif args[1] == 'introduction' then
        if args[2] == 'enable' then
            settings['introduction'] = true
        elseif args[2] == 'disable' then
            settings['introduction'] = false
        elseif args[2] == 'set' then
            settings['introduction_channel'] = args[3] and args[3] or ''
        elseif args[2] == 'message' then
            settings['introduction_message'] = table.join(table.slice(args, 3, #args, 1), ' ')
        end
    end
    client:getDB():Update(message, "Settings", settings)
end)

client:addCommand('Lua', "Execute arbitrary lua code", "lua", '<code>', 4, false, false, function(message, args)
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
        --TODO: Expand pagination
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

client:addCommand('Reload', 'Reload a module', 'reload', '<module>', 4, false, false, function(message, args)
    if args ~= "" then loadModule(args) end
end)
