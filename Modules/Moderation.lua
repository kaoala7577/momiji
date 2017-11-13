addCommand('Mute', 'Mutes a user', 'mute', '<@user|userID>', 1, false, true, function(message, args)
	local settings, cases = Database:Get(message, "Settings"), Database:Get(message, "Cases")
	local member
	if not settings.mute_setup then
		message:reply("Mute cannot be used until `setup` has been run.")
		return
	end
	local pat = string.match(args, "[<@!]*(%d+)>*.*")
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
	local pat = string.match(args, "[<@!]*(%d+)>*.*")
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

--TODO: This really needs work
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

addCommand('Mod Info', "Get mod-related information on a user", {'mi','modinfo'}, '<@user|userID>', 1, false, true, function(message, args)
	local m
	local pat = string.match(args, "[<@!]*(%d+)>*.*")
	if pat and pat~='18' then
		m = resolveMember(message.guild, pat)
		args = args:gsub(pat, ""):gsub("[<@!>]*",""):trim()
	end
	if m then
		local users = Database:Get(message, "Users")
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
	local notes = Database:Get(message, "Notes")
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
	Database:Update(message, "Notes", notes)
end)

addCommand('Watchlist', "Add/remove someone from the watchlist or view everyone on it", "wl", '<add|remove|list> [@user|userID]', 1, false, true, function(message, args)
	local users = Database:Get(message, "Users")
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
			users[member.id] = { registered="", watchlisted=true, last_message="" }
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
	Database:Update(message, "Users", users)
end)
