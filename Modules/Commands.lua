Commands = {}

function addCommand(name, desc, cmds, usage, rank, multiArg, serverOnly, func)
	local b,e,n,g = checkArgs({'string', 'string', {'table','string'}, 'string', 'number', 'boolean', 'boolean', 'function'}, {name,desc,cmds, usage, rank,multiArg,serverOnly,func})
	if not b then
		logger:log(1, "<COMMAND LOADING> Unable to load %s (Expected: %s, Number: %s, Got: %s)", name,e,n,g)
		return
	end
	Commands[name] = {name=name, description=desc,commands=(type(cmds)=='table' and cmds or {cmds}),usage=usage,rank=rank,multi=multiArg,serverOnly=serverOnly,action=func}
end

addCommand('Ping', 'Ping!', 'ping', '', 0, false, false, function(message, args)
	local response = message:reply("Pong!")
	if response then
		response:setContent("Pong!".."`"..math.round((response.createdAt - message.createdAt)*1000).." ms`")
	end
end)

addCommand('Prefix', 'Show the prefix for the guild', 'prefix', '', 0, false, true, function(message, args)
	local settings = Database:get(message, "Settings")
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
			{name="Contribute",value="[Github](https://github.com/Mishio595/momiji)",inline=true},
		},
		color = discordia.Color.fromHex('#5DA9FF').value
	}}
end)

addCommand('Time', 'Get the current time', 'time', '', 0, false, false, function(message, args)
	message:reply(humanReadableTime(discordia.Date():toTableUTC()).." UTC")
end)

addCommand('Remind Me', 'Make a reminder!', 'remindme', '<reminder> in <time>', 0, false, false, function(message, args)
	local reminder, time = args:match("(.*)in(.*)")
	local secs = toSeconds(parseHumanTime(time))
	print(secs)
	if reminder and time and secs then
		Timing:newTimer(message.guild,secs,string.format('REMINDER||%s||%s||%s||%s',message.guild.id,message.author.id,time,reminder))
	end
end)

addCommand('Roll', 'Roll X N-sided dice', 'roll', '<XdN>', 0, false, false, function(message, args)
	local count, sides = args:match("(%d+)d(%d+)")
	count,sides = tonumber(count) or 0, tonumber(sides) or 0
	if count>0 and sides>0 then
		local roll, pretty = 0,{}
		for i=1,count do
			local cur = math.round(math.random(1,sides))
			pretty[#pretty+1]=tostring(cur)
			roll = roll+cur
		end
		message.channel:send{embed={
			fields={
				{name=string.format("%d 🎲 [1-%d]",count, sides), value=string.format("You rolled **%s** = **%d**",table.concat(pretty,","),roll)},
			},
			color = discordia.Color.fromHex('#5DA9FF').value,
		}}
	end
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
		local cmd = nil
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
	local timestamp = humanReadableTime(parseTime(guild.timestamp):toTable())
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
		message.channel:send {
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
	end
end)

addCommand('User Info', "Get information on a user", {'userinfo','ui'}, '[@user|userID]', 0, false, true, function(message, args)
	local guild = message.guild
	local member
	if args ~= "" then
		local m = guild:getMember(resolveMember(message.guild, args))
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
		local users = Database:get(message, "Users")
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
	else
		message.channel:send("Sorry, I couldn't find that user.")
	end
end)

addCommand('Urban', 'Search for a term on Urban Dictionary', {'urban', 'ud'}, '<search term>', 0, false, false, function(message, args)
    local data, err = API.misc:Urban(args, nil)
    if data then
        message:reply{embed=data}
	else
		message:reply(err)
	end
end)

addCommand('Cat', 'Meow', 'cat', '', 0, false, false, function(message, args)
    local data, err = API.misc:Cats()
    if data then
        message:reply{embed={
            image={url=data}
        }}
    end
end)

addCommand('Dog', 'Bork', 'dog', '', 0, false, false, function(message, args)
    local data, err = API.misc:Dogs()
    if data then
        message:reply{embed={
            image={url=data}
        }}
    end
end)

addCommand('Joke', 'Tell a joke', 'joke', '', 0, false, false, function(message, args)
    local data, err = API.misc:Joke()
    message:reply(data or err)
end)

addCommand('MAL Anime Search', "Search MyAnimeList for an anime", 'anime', '<search>', 0, false, true, function(message, args)
	local data, err = API.misc:Anime(args, nil)
	if data then
		message:reply{embed=data}
	else
		message:reply(err)
	end
end)

addCommand('MAL Manga Search', "Search MyAnimeList for a mnaga", 'manga', '<search>', 0, false, true, function(message, args)
	local data, err = API.misc:Manga(args, nil)
	if data then
		message:reply{embed=data}
	else
		message:reply(err)
	end
end)

addCommand('e621', 'Posts a random image from e621 with optional tags', 'e621', '[input]', 0, false, true, function(message, args)
    if not message.channel.nsfw then
        message:reply("This command can only be used in NSFW channels.")
        return
    end
    local blacklist = {'cub', 'young', 'small_cub'}
    for _,v in ipairs(blacklist) do
        if args:match(v) then
            message:reply("A tag you searched for is blacklisted: "..v)
            return
        end
    end
    message.channel:broadcastTyping()
    local data, err
    while not data do
        local try,e = API.misc:Furry(args)
        local bl = false
        for _,v in ipairs(blacklist) do
            if try.tags:match(v) then
                bl = true
            end
        end
        if try.file_ext~='swf' and try.file_ext~='webm' and not bl then
            data,err=try,e
        end
    end
    message:reply{embed={
        image={url=data.file_url},
        description=string.format("**Tags:** %s\n**Post:** [%s](%s)\n**Author:** %s\n**Score:** %s", data.tags:gsub('%_','\\_'):gsub(' ',', '), data.id, "https://e621.net/post/show/"..data.id, data.author, data.score)
    }}
end)

addCommand('Add Self Role', 'Add role(s) to yourself from the self role list', {'role', 'asr'}, '<role[, role, ...]>', 0, true, true, function(message, args)
	local member = message.member or message.guild:getMember(message.author.id)
	local selfRoles = Database:get(message, "Roles")
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
			local success = member:addRole(member.guild.roles:find(fn))
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
	local selfRoles = Database:get(message, "Roles")
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
		local success = member:removeRole(member.guild.roles:find(fn))
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
	local selfRoles = Database:get(message, "Roles")
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

addCommand('Mute', 'Mutes a user', 'mute', '<@user|userID>', 1, false, true, function(message, args)
	local settings, cases = Database:get(message, "Settings"), Database:get(message, "Cases")
	if not settings.mute_setup then
		message:reply("Mute cannot be used until `setup` has been run.")
		return
	end
	local member = message.guild:getMember(#message.mentionedUsers==1 and message.mentionedUsers:iter()() or resolveMember(message.guild, args))
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
	Database:update(message, "Cases", cases)
end)

addCommand('Unmute', 'Unmutes a user', 'unmute', '<@user|userID>', 1, false, true, function(message, args)
	local settings, cases = Database:get(message, "Settings"), Database:get(message, "Cases")
	if not settings.mute_setup then
		message:reply("Unmute cannot be used until `setup` has been run.")
		return
	end
	local member = message.guild:getMember(#message.mentionedUsers==1 and message.mentionedUsers:iter()() or resolveMember(message.guild, args))
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
	Database:update(message, "Cases", cases)
end)

--TODO: This really needs work
addCommand('Prune', 'Bulk deletes messages', 'prune', '<count>', 2, false, true, function(message, args)
	local settings = Database:get(message, "Settings")
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

addCommand('Mod Info', "Get mod-related information on a user", {'mi','modinfo'}, '<@user|userID>', 1, false, true, function(message, args)
	local m
	local pat = string.match(args, "[<@!]*(%d+)>*.*")
	if pat and pat~='18' then
		m = resolveMember(message.guild, pat)
		args = args:gsub(pat, ""):gsub("[<@!>]*",""):trim()
	end
	if m then
		local users = Database:get(message, "Users")
		if users[m.id] then
			local watchlisted = users[m.id].watchlisted
			if watchlisted then watchlisted = 'Yes' else watchlisted = 'No' end
			status = message:reply {embed={
				author = {name = m.username.."#"..m.discriminator, icon_url = m.avatarURL},
				fields = {
					{name = "Watchlisted", value = watchlisted, inline = true},
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
	local pat = string.match(args, "[<@!]*(%d+)>*.*")
	if pat then
		m = resolveMember(message.guild, pat)
		args = args:gsub(pat, ""):gsub("[<@!>]*",""):trim()
	end
	if (args == "") or not m then return end
	local notes = Database:get(message, "Notes")
	if args:startswith("add") then
		args = args:gsub("^add",""):trim()
		if args and args ~= "" then
			if notes==nil or notes[m.id]==nil then
				notes[m.id] = {
					{note=args, moderator=a.username, timestamp=discordia.Date():toISO()}
				}
			else
				notes[m.id][#notes[m.id]+1] = {note=args, moderator=a.fullname, timestamp=discordia.Date():toISO()}
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
		local notelist = ""
		if notes[m.id] then
			for i,v in ipairs(notes[m.id]) do
				notelist = notelist..string.format("**%d)** %s (Added by %s)\n",i,v.note,v.moderator)
			end
		end
		message:reply {
			embed = {
				title = "Notes for "..m.fullname,
				description = notelist,
			}
		}
	else
		message:reply("Please specify add, del, or view")
	end
	Database:update(message, "Notes", notes)
end)

addCommand('Watchlist', "Add/remove someone from the watchlist or view everyone on it", "wl", '<add|remove|list> [@user|userID]', 1, false, true, function(message, args)
	local users = Database:get(message, "Users")
	args = args:split(' ')
	local member
	for i,v in ipairs(args) do
		local pat = string.match(v, "<?@?!?(%d+)>?.*")
		if pat then
			member = resolveMember(message.guild, pat) or member
			args[i] = v:gsub(pat, ""):gsub("[<@!>]*",""):trim()
			if args[i] == "" then table.remove(args, i) end
		end
	end
	if args[1] == 'add' then
		if users[member.id] == nil then
			--This shouldn't happen, but its here just in case
			users[member.id] = { registered="", watchlisted=true, last_message="", nick=member.name }
		else
			users[member.id].watchlisted = true
		end
	elseif args[1] == 'remove' then
		if users[member.id] then
			users[member.id].watchlisted = false
		end
	elseif args[1] == 'list' then
		local list = ""
		for id,v in pairs(users) do
			if v.watchlisted then
				local mention = message.guild:getMember(id).mentionString or client:getUser(id).mentionString or id
				list = list..mention.."\n"
			end
		end
		if list ~= "" then
			message:reply {embed={
				title="Watchlist",
				description=list,
			}}
		end
	end
	Database:update(message, "Users", users)
end)

addCommand('Role Color', 'Change the color of a role', {'rolecolor', 'rolecolour', 'rc'}, '<roleName|roleID> <#hexcolor>', 1, false, true, function(message, args)
	local color = args:match("%#([0-9a-fA-F]*)")
	local role = resolveRole(message.guild,args:gsub("%#"..color,""):trim())
	if #color==6 then
		if type(role)=='table' then
			role:setColor(discordia.Color.fromHex(color))
			message.channel:sendf("Changed the color of %s to #%s",role.name,color)
		else
			message:reply("Invalid role provided")
		end
	else
		message:reply("Invalid color provided")
	end
end)

addCommand('Add Role', 'Add role(s) to the given user', 'ar', '<@user|userID> <role[, role, ...]>', 1, false, true, function(message, args)
	local member = message.guild:getMember(#message.mentionedUsers==1 and message.mentionedUsers:iter()() or resolveMember(message.guild, args))
	if member then
		args = args:gsub("<@!?%d+>",""):trim()
		args = string.split(args, ",")
		local rolesToAdd = {}
		for i,role in ipairs(args) do
			role=role:trim()
			local r = resolveRole(message.guild, role)
			if r then
				member:addRole(r)
				rolesToAdd[#rolesToAdd+1] = r.name
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

addCommand('Remove Role', 'Removes role(s) from the given user', 'rr', '<@user|userID> <role[, role, ...]>', 1, false, true, function(message, args)
	local member = message.guild:getMember(#message.mentionedUsers==1 and message.mentionedUsers:iter()() or resolveMember(message.guild, args))
	if member then
		args = args:gsub("<@!?%d+>",""):trim()
		args = string.split(args, ",")
		local rolesToRemove = {}
		for i,role in ipairs(args) do
			role=role:trim()
			local r = resolveRole(message.guild, role)
			if r then
				member:removeRole(r)
				rolesToRemove[#rolesToRemove+1] = r.name
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

addCommand('Register', 'Register a given user with the listed roles', {'reg', 'register'}, '<@user|userID> <role[, role, ...]>', 1, false, true, function(message, args)
	if message.guild.id~="348660188951216129" and message.guild.id~='375797411819552769' then return end
	local data = Database:get(message)
	local channel = message.guild:getChannel(data.Settings.modlog_channel)
	local member = message.guild:getMember(#message.mentionedUsers==1 and message.mentionedUsers:iter()() or resolveMember(message.guild, args))
	if member then
		args = args:gsub("<@!?%d+>",""):trim()
		args = string.split(args, ",")
		local rolesToAdd = {}
		for k,l in pairs(data.Roles) do
			for r,a in pairs(l) do
				for i,role in ipairs(args) do
					role=role:trim()
					if string.lower(role) == string.lower(r)  or (table.search(a, string.lower(role))) then
						if (r == 'Gamer') or (r == '18+') or not (k == 'Opt-In Roles') then
							rolesToAdd[#rolesToAdd+1] = r
						end
					end
				end
				if (k == 'Gender Identity' or k == 'Gender') then
					if rolesToAdd[#rolesToAdd]==r then hasGender = true end
				end
				if (k == 'Pronouns') then
					if rolesToAdd[#rolesToAdd]==r then hasPronouns = true end
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
			elseif message.guild.id == '375797411819552769' then
				member:addRole('375799736294178827')
			end
			if #rolesToAdd > 0 then
				if channel then
					channel:send {
						embed = {
							author = {name = "Registered", icon_url = member.avatarURL},
							description = "**Registered "..member.mentionString.." with the following roles** \n"..roleList,
							color = member:getColor().value,
							timestamp = discordia.Date():toISO(),
							footer = {text = "ID: "..member.id}
						}
					}
				end
				if data.Settings.introduction_message ~= "" and data.Settings.introduction_channel and data.Settings.introduction then
					local channel = member.guild:getChannel(data.Settings.introduction_channel)
					if channel then
						channel:send(formatMessageSimple(data.Settings.introduction_message, member))
					end
				end
				if data.Users==nil or data.Users[member.id]==nil then
					data.Users[member.id] = { registered=discordia.Date():toISO(), watchlisted=false, last_message="", nick=member.nickname or member.name }
				else
					data.Users[member.id].registered = discordia.Date():toISO()
				end
				Database:update(message, "Users", data.Users)
			end
		else
			message:reply("Invalid registration command. Make sure to include at least one of gender identity and pronouns.")
		end
	end
end)

addCommand('Config', 'Update configuration for the current guild', 'config', '<category> <option> [value]', 2, false, true, function(message, args)
	args = args:split(' ')
	for i,v in pairs(args) do args[i] = v:trim() end
	local settings = Database:get(message, "Settings")
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
				local list = ""
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
	Database:update(message, "Settings", settings)
end)

addCommand('Setup Mute', 'Sets up mute', 'setup', '', 3, false, true, function(message, args)
	local settings = Database:get(message, "Settings")
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
	Database:update(message, "Settings", settings)
end)

addCommand('Ignore', 'Ignores the given channel', 'ignore', '<channelID|link>', 2, false, true, function(message, args)
	local ignores = Database:get(message, 'Ignore')
	local channel = resolveChannel(message.guild, args)
	if channel and not ignores[channel.id] then
		ignores[channel.id] = true
	elseif channel then
		ignores[channel.id] = nil
	end
	Database:update(message, 'Ignore', ignores)
end)

addCommand('Make Role', 'Make a role for the rolelist', {'makerole','mr'}, '<roleName>, [category], [aliases]', 2, true, true, function(message, args)
	local roles = Database:get(message, "Roles")
	function fn(r) return r.name == args[1] end
	local r = message.guild.roles:find(fn)
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
			message:reply("Added "..r.name.." to "..cat.." with aliases "..table.concat(aliases,', '))
		end
	else
		message:reply(args[1].." is not a role. Please make it first.")
	end
	Database:update(message, "Roles", roles)
end)

addCommand('Delete Role', 'Remove a role from the rolelist', {'delrole','dr'}, '<roleName>', 2, false, true, function(message, args)
	local roles = Database:get(message, "Roles")
	for cat,v in pairs(roles) do
		if v[args] then
			v[args]=nil
		end
		if next(v)==nil then
			roles[cat]=nil
		end
	end
	Database:update(message, "Roles", {}) --shitty workaround to an issue in RethinkDB
	Database:update(message, "Roles", roles)
end)

addCommand('Lua', "Execute arbitrary lua code", "lua", '<code>', 4, false, false, function(message, args)
	args = string.gsub(args, "`", ""):trim()
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
		client:removeAllListeners('memberUpdate')
		client:removeAllListeners('memberRegistered')
		client:on('messageCreate', Events.messageCreate)
		client:on('memberJoin', Events.memberJoin)
		client:on('memberLeave', Events.memberLeave)
		client:on('messageDelete',Events.messageDelete)
		client:on('messageDeleteUncached',Events.messageDeleteUncached)
		client:on('userBan',Events.userBan)
		client:on('userUnban',Events.userUnban)
		client:on('presenceUpdate', Events.presenceUpdate)
		client:on('memberUpdate', Events.memberUpdate)
		client:on('memberRegistered', Events.memberRegistered)
	end
end)
