addCommand('Config', 'Update configuration for the current guild', 'config', '<category> <option> [value]', 2, false, true, function(message, args)
    args = args:split(' ')
    for i,v in pairs(args) do args[i] = v:trim() end
    local settings = Database:Get(message, "Settings")
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
        local fields,roles,chans = {
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
        local list = ""
        for k,v in pairs(settings) do
            list = list.."**"..k.."**: "..tostring(v).."\n"
        end
        message:reply(list)
    end
    Database:Update(message, "Settings", settings)
end)

addCommand('Setup Mute', 'Sets up mute', 'setup', '', 3, false, true, function(message, args)
    local settings = Database:Get(message, "Settings")
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
        local cat = args[2] and args[2] or "Default"
        if roles[cat] then
            if not roles[cat][r.name] then roles[cat][r.name] = {} end
        else
            roles[cat] = {
                [r.name] = {}
            }
        end
        local aliases = table.slice(args, 3, #args, 1)
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

addCommand('Delete Role', 'Remove a role from the rolelist', {'delrole','dr'}, '<roleName>', 2, false, true, function(message, args)
    local roles = Database:Get(message, "Roles")
    function fn(r) return r.name == args end
    local r = message.guild.roles:find(fn)
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
