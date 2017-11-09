Commands = {}

function addCommand(name, desc, cmds, usage, rank, multiArg, serverOnly, func)
    local b,e,n,g = checkArgs({'string', 'string', {'table','string'}, 'string', 'number', 'boolean', 'boolean', 'function'}, {name,desc,cmds, usage, rank,multiArg,serverOnly,func})
    if not b then
        logger:log(1, "<COMMAND LOADING> Unable to load %s (Expected: %s, Number: %s, Got: %s)", name,e,n,g)
        return
    end
    Commands[name] = {name=name, description=desc,commands=(type(cmds)=='table' and cmds or {cmds}),usage=usage,rank=rank,multi=multiArg,serverOnly=serverOnly,action=func}
end

addCommand('Add Self Role', 'Add role(s) to yourself from the self role list', {'role', 'asr'}, '<role[, role, ...]>', 0, true, true, function(message, args)
    local member = message.member or message.guild:getMember(message.author.id)
    local selfRoles = Database:Get(message, "Roles")
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
            success = member:addRole(member.guild.roles:find(fn))
            if success then rolesAdded[#rolesAdded+1] = role end
        else rolesFailed[#rolesFailed+1] = "You already have "..role end
    end
    if #rolesAdded > 0 then
        message.channel:send {
            embed = {
                author = {name = "Roles Added", icon_url = member.avatarURL},
                description = "**Added "..member.mentionString.." to the following roles** \n"..table.concat(rolesAdded,"\n"),
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
                description = "**Failed to add the following roles to** "..member.mentionString.."\n"..table.concat(rolesFailed,"\n"),
                color = member:getColor().value,
                timestamp = discordia.Date():toISO(),
                footer = {text = "ID: "..member.id}
            }
        }
    end
end)

addCommand('Remove Self Role', 'Remove role(s) from the self role list from yourself', {'derole','rsr'}, '<role[, role, ...]>', 0, true, true, function(message, args)
    local roles = args
    local member = message.member or message.guild:getMember(message.author.id)
    local selfRoles = Database:Get(message, "Roles")
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
        success = member:removeRole(member.guild.roles:find(fn))
        if success then roleList = roleList..role.."\n" end
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

addCommand('List Self Roles', 'List all roles in the self role list', 'roles', '', 0, false, true, function(message, args)
    local roleList, cats = {},{}
    local selfRoles = Database:Get(message, "Roles")
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

addCommand('Add Role', 'Add role(s) to the given user', 'ar', '<@user|userID> <role[, role, ...]>', 1, true, true, function(message, args)
    local member
    for i,v in ipairs(args) do
        pat = string.match(v, "<?@?!?(%d+)>?.*")
        if pat then
            member = resolveMember(message.guild, pat) or member
            args[i] = v:gsub(pat, ""):gsub("[<@!>]*",""):trim()
            if args[i] == "" then table.remove(args, i) end
        end
    end
    if member then
		local rolesToAdd = {}
		for _,role in pairs(args) do
			for r in message.guild.roles:iter() do
				if string.lower(role) == string.lower(r.name) then
                    success = member:addRole(message.guild:getRole(r.id))
					if success then rolesToAdd[#rolesToAdd+1] = r.name end
				end
			end
		end
		if #rolesToAdd > 0 then
			message.channel:send {
				embed = {
					author = {name = "Roles Added", icon_url = member.avatarURL},
					description = "**Added "..member.mentionString.." to the following roles** \n"..table.concat(rolesToAdd,"\n"),
					color = member:getColor().value,
					timestamp = discordia.Date():toISO(),
					footer = {text = "ID: "..member.id}
				}
			}
		end
	end
end)

addCommand('Remove Role', 'Removes role(s) from the given user', 'rr', '<@user|userID> <role[, role, ...]>', 1, true, true, function(message, args)
    local member
    for i,v in ipairs(args) do
        pat = string.match(v, "<?@?!?(%d+)>?.*")
        if pat then
            member = resolveMember(message.guild, pat) or member
            args[i] = v:gsub(pat, ""):gsub("[<@!>]*",""):trim()
            if args[i] == "" then table.remove(args, i) end
        end
    end
    if member then
        local rolesToRemove = {}
        for _,role in pairs(args) do
            for r in message.guild.roles:iter() do
                if string.lower(role) == string.lower(r.name) then
                    success = member:removeRole(r)
                    if success then rolesToRemove[#rolesToRemove+1] = r.name end
                end
            end
        end
        if #rolesToRemove > 0 then
            message.channel:send {
                embed = {
                    author = {name = "Roles Removed", icon_url = member.avatarURL},
                    description = "**Removed "..member.mentionString.." from the following roles** \n"..table.concat(rolesToRemove,"\n"),
                    color = member:getColor().value,
                    timestamp = discordia.Date():toISO(),
                    footer = {text = "ID: "..member.id}
                }
            }
        end
    end
end)

addCommand('Register', 'Register a given user with the listed roles', {'reg', 'register'}, '<@user|userID> <role[, role, ...]>', 1, true, true, function(message, args)
    if not (message.guild.id == "348660188951216129" or message.guild.id == '375797411819552769') then return end
    local settings, selfRoles, users = Database:Get(message, "Settings"), Database:Get(message, "Roles"), Database:Get(message, "Users")
    local channel = client:getChannel(settings.modlog_channel)
    local member
    for i,v in ipairs(args) do
        pat = string.match(v, "<?@?!?(%d+)>?.*")
        if pat then
            member = resolveMember(message.guild, pat) or member
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
                if (k == 'Gender Identity' or k == 'Gender') then
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
            if message.guild.id == "348660188951216129" then
                member:addRole('348873284265312267')
            elseif message.guild.id == "375797411819552769" then
                member:addRole('375799736294178827')
            end
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
                Database:Update(message, "Users", users)
            end
        else
            message:reply("Invalid registration command. Make sure to include at least one of gender identity and pronouns.")
        end
    end
end)

addCommand('Mod Info', "Get mod-related information on a user", {'mi','modinfo'}, '<@user|userID>', 1, false, true, function(message, args)
    local m
    pat = string.match(args, "[<@!]*(%d+)>*.*")
    if pat then
        m = resolveMember(message.guild, pat)
        args = args:gsub(pat, ""):gsub("[<@!>]*",""):trim()
    end
    if m then
        local users = Database:Get(message, "Users")
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

addCommand('Notes', 'Add the note to, delete a note from, or view all notes for the mentioned user', 'note', '<add|del|view> [@user|userID] [note|index]', 1, false, true, function(message, args)
    local a = message.member or message.guild:getMember(message.author.id)
    local m
    pat = string.match(args, "[<@!]*(%d+)>*.*")
    if pat then
        m = resolveMember(message.guild, pat)
        args = args:gsub(pat, ""):gsub("[<@!>]*",""):trim()
    end
    if (args == "") or not m then return end
    local notes = Database:Get(message, "Notes")
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
    Database:Update(message, "Notes", notes)
end)

addCommand('Watchlist', "Add/remove someone from the watchlist or view everyone on it", "wl", '<add|remove|list> [@user|userID]', 1, false, true, function(message, args)
    local users = Database:Get(message, "Users")
    args = args:split(' ')
    local member
    for i,v in ipairs(args) do
        pat = string.match(v, "<?@?!?(%d+)>?.*")
        if pat then
            member = resolveMember(message.guild, pat) or member
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
    Database:Update(message, "Users", users)
end)

addCommand('Toggle 18', "Toggles the under18 flag on a user", 't18', '<@user|userID>', 1, false, true, function(message, args)
    local users = Database:Get(message, "Users")
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
    Database:Update(message, "Users", users)
end)

addCommand('Mute', 'Mutes a user', 'mute', '<@user|userID>', 1, false, true, function(message, args)
    local settings, cases = Database:Get(message, "Settings"), Database:Get(message, "Cases")
    local member
    if not settings.mute_setup then
        message:reply("Mute cannot be used until `setup` has been run.")
        return
    end
    pat = string.match(args, "[<@!]*(%d+)>*.*")
    if pat then
        member = resolveMember(message.guild, pat) or member
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
        if settings.modlog then
            message.guild:getChannel(settings.modlog_channel):send{embed={
                title = "Member Muted",
                fields = {
                    {name = "User", value = member.mentionString, inline = true},
                    {name = "Moderator", value = message.author.mentionString, inline = true},
                    {name = "Reason", value = args, inline = true},
                },
            }}
        end
    end
    Database:Update(message, "Cases", cases)
end)

addCommand('Unmute', 'Unmutes a user', 'unmute', '<@user|userID>', 1, false, true, function(message, args)
    local settings, cases = Database:Get(message, "Settings"), Database:Get(message, "Cases")
    if not settings.mute_setup then
        message:reply("Unmute cannot be used until `setup` has been run.")
        return
    end
    local member
    pat = string.match(args, "[<@!]*(%d+)>*.*")
    if pat then
        member = resolveMember(message.guild, pat) or member
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
        if settings.modlog then
            message.guild:getChannel(settings.modlog_channel):send{embed={
                title = "Member Unmuted",
                fields = {
                    {name = "User", value = member.mentionString, inline = true},
                    {name = "Moderator", value = message.author.mentionString, inline = true},
                },
            }}
        end
    end
    Database:Update(message, "Cases", cases)
end)

addCommand('Prune', 'Bulk deletes messages', 'prune', '<count>', 2, false, true, function(message, args)
    local settings = Database:Get(message, "Settings")
    local author = message.member or message.guild:getMember(message.author.id)
    client:removeAllListeners('messageDelete')
    client:removeAllListeners('messageDeleteUncached')
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
        if settings.modlog then
            message.guild:getChannel(settings.modlog_channel):send {embed={
                description = "Moderator "..author.mentionString.." deleted "..numDel.." messages in "..message.channel.mentionString,
                color = discordia.Color.fromRGB(255, 0, 0).value,
                timestamp = discordia.Date():toISO()
            }}
        end
    end
    client:on('messageDelete', Events.messageDelete)
    client:on('messageDeleteUncached', Events.messageDeleteUncached)
end)

addCommand('Make Role', 'Make a role for the rolelist', {'makerole','mr'}, '<roleName>, [category], [aliases]', 2, true, true, function(message, args)
    local roles = Database:Get(message, "Roles")
    function fn(r) return r.name == args[1] end
    r = message.guild.roles:find(fn)
    if r then
        for k,v in pairs(roles) do
            if v[args[1]] then
                message:reply(args[1].." already exists in "..k)
                return
            end
        end
        cat = args[2] and args[2] or "Default"
        if roles[cat] then
            if not roles[cat][r.name] then roles[cat][r.name] = {} end
        else
            roles[cat] = {
                [r.name] = {}
            }
        end
        aliases = table.slice(args, 3, #args, 1)
        if aliases ~= {} then
            for i,v in ipairs(aliases) do
                table.insert(roles[cat][r.name], v)
            end
        end
        if table.concat(aliases,', ')=='' then
            message:reply("Added "..r.name.." to "..cat)
        else
            message:reply("Added "..r.name.." to "..cat.." wtih aliases "..table.concat(aliases,', '))
        end
    else
        message:reply(args[1].." is not a role. Please make it first.")
    end
    Database:Update(message, "Roles", roles)
end)

--TODO: Make Delrank
addCommand('Delete Role', 'Remove a role from the rolelist', {'delrole','dr'}, '<roleName>', 2, false, true, function(message, args)
    local roles = Database:Get(message, "Roles")
    function fn(r) return r.name == args end
    r = message.guild.roles:find(fn)
    if r then
        for cat,v in pairs(roles) do
            if v[args] then
                v[args]=nil
            end
            if next(v)==nil then
                roles[cat]=nil
            end
        end
    else
        message:reply(args.." is not a role.")
    end
    Database:Update(message, "Roles", {}) --shitty workaround to an issue in RethinkDB
    Database:Update(message, "Roles", roles)
end)

addCommand('Ignore', 'Ignores the given channel', 'ignore', '<channelID|link>', 2, false, true, function(message, args)
    local ignores = Database:Get(message, 'Ignore')
    local channel = resolveChannel(message.guild, args)
    if channel and not ignores[channel.id] then
        ignores[channel.id] = true
    elseif channel then
        ignores[channel.id] = nil
    end
    Database:Update(message, 'Ignore', ignores)
end)

addCommand('Config', 'Update configuration for the current guild', 'config', '<category> <option> [value]', 2, false, true, function(message, args)
    args = args:split(' ')
    for i,v in pairs(args) do args[i] = v:trim() end
    settings = Database:Get(message, "Settings")
    local switches = {
        roles = {'admin', 'mod'},
        channels = {'audit', 'modlog', 'welcome', 'introduction'},
    }
    for _,v in pairs(switches.roles) do
        if args[1]==v then
            if args[2] == 'add' then
                settings[v..'_roles'][#settings[v..'_roles']+1] = args[3] and args[3] or nil
            elseif args[2] == 'remove' then
                for i,j in ipairs(settings[v..'_roles']) do
                    if j==args[3] then
                        table.remove(settings[v..'_roles'],i)
                    end
                end
            elseif args[2] == 'list' then
                list = ""
                for i,j in ipairs(settings[v..'_roles']) do
                    role = message.guild:getRole(j)
                    if role then
                        if list=="" then
                            list=role.name
                        else
                            list=list..role.name.."\n"
                        end
                    end
                end
                if list~="" then message:reply(list) end
            end
        end
    end
    for _,v in pairs(switches.channels) do
        if args[1]==v then
            if args[2] == 'enable' then
                settings[v] = true
            elseif args[2] == 'disable' then
                settings[v] = false
            elseif args[2] == 'set' then
                local channel = resolveChannel(message.guild, args[3])
                settings[v..'_channel'] = channel.id or ''
            elseif args[2] == 'message' and (v=='welcome' or v=='introduction') then
                settings[v..'_message'] = table.concat(table.slice(args, 3, #args, 1), ' ')
            end
        end
    end
    if args[1] == 'prefix' then
        settings['prefix'] = args[2] and args[2] or settings['prefix']
    elseif args[1] == 'autorole' then
        if args[2] == 'enable' then
            settings['autorole'] = true
        elseif args[2] == 'disable' then
            settings['autorole'] = true
        elseif args[2] == 'add' then
            if args[3] then settings['autoroles'][#settings['autoroles']+1] = args[3] end
        elseif args[2] == 'remove' then
            for i,v in ipairs(settings['autoroles']) do
                if v==args[3] then
                    table.remove(settings['autoroles'],i)
                end
            end
        end
    elseif args[1] == 'help' then
        fields,roles,chans = {
            {name="prefix", value="Usage: config prefix <newPrefix>"},
            {name="autorole", value="Subcommands:\nenable\ndisable\nadd <roleID>\nremove <roleID>"},
        },"",""
        for _,v in pairs(switches.roles) do
            if roles == "" then roles=v else roles=roles..", "..v end
        end
        table.insert(fields, {name = roles, value = "Subcommands:\nadd <roleID>\nremove <roleID>\nlist"})
        for _,v in pairs(switches.channels) do
            if chans == "" then chans=v else chans=chans..", "..v end
        end
        table.insert(fields, {name = chans, value = "Subcommands:\nenable\ndisable\nset <channelID>\nmessage <message>\n\n**Notes:** message only works for welcome and introduction.\n{user} is replaced with the member's mention\n{guild} is replace with the guild name"})
        message:reply{embed={
            fields = fields,
        }}
    elseif args[1]=="" then
        list = ""
        for k,v in pairs(settings) do
            list = list.."**"..k.."**: "..tostring(v).."\n"
        end
        message:reply(list)
    end
    Database:Update(message, "Settings", settings)
end)

addCommand('Setup Mute', 'Sets up mute', 'setup', '', 3, false, true, function(message, args)
    settings = Database:Get(message, "Settings")
    local role = message.guild.roles:find(function(r) return r.name == 'Muted' end)
    if not role then
        role = message.guild:createRole("Muted")
    end
    for c in message.guild.textChannels:iter() do
        c:getPermissionOverwriteFor(role):denyPermissions(enums.permission.sendMessages, enums.permission.addReactions)
    end
    for c in message.guild.voiceChannels:iter() do
        c:getPermissionOverwriteFor(role):denyPermissions(enums.permission.speak)
    end
    settings.mute_setup = true
    Database:Update(message, "Settings", settings)
end)

addCommand('Lua', "Execute arbitrary lua code", "lua", '<code>', 4, false, false, function(message, args)
    args = string.gsub(args, "`", ""):gsub("lua", ""):trim()
    msg = message
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
        result, len = {}, 1900
        count = math.floor(#ret/len)>0 and math.floor(#ret/len) or 1
        for i=1,count do
            result[i] = string.sub(ret, (len*(i-1)), (len*(i)))
        end
        for _,v in pairs(result) do
            if v ~= "" then message:reply("```"..v.."```") end
        end
    end
    print = oldPrint
end)

addCommand('Reload', 'Reload a module', 'reload', '<module>', 4, false, false, function(message, args)
    if args ~= "" then loadModule(args) end
    if args=='Events' then
        client:removeAllListeners('messageCreate')
    	client:removeAllListeners('memberJoin')
    	client:removeAllListeners('memberLeave')
    	client:removeAllListeners('messageDelete')
    	client:removeAllListeners('messageDeleteUncached')
    	client:removeAllListeners('userBan')
    	client:removeAllListeners('userUnban')
    	client:removeAllListeners('presenceUpdate')
    	client:removeAllListeners('memberRegistered')
        client:on('messageCreate', Events.messageCreate)
    	client:on('memberJoin', Events.memberJoin)
    	client:on('memberLeave', Events.memberLeave)
    	client:on('messageDelete',Events.messageDelete)
    	client:on('messageDeleteUncached',Events.messageDeleteUncached)
    	client:on('userBan',Events.userBan)
    	client:on('userUnban',Events.userUnban)
    	client:on('presenceUpdate', Events.presenceUpdate)
    	client:on('memberRegistered', Events.memberRegistered)
    end
end)
