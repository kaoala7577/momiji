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
        if pat and pat~='18' then
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
        if pat and pat~='18' then
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
        if pat and pat~='18' then
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
            local roleList = ""
            for _,role in pairs(rolesToAdd) do
                function fn(r) return r.name == role end
                member:addRole(member.guild.roles:find(fn))
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
                    users[member.id] = { registered=discordia.Date():toISO(), watchlisted=false, last_message="" }
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

addCommand('Lua', "Execute arbitrary lua code", "lua", '<code>', 4, false, false, function(message, args)
    args = string.gsub(args, "`", ""):gsub("lua", ""):trim()
    msg = message
    local printresult = ""
    local oldPrint = print
    print = function(...)
        local arg = {...}
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
        local result, len = {}, 1900
        local count = math.floor(#ret/len)>0 and math.floor(#ret/len) or 1
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
