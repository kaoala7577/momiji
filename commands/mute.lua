return {
    id = "mute",
    action = function(message, args)
    	local author = message.author
		local logChannel = message.guild:getChannel(message.guild._settings.modlog_channel)
		local success, member, channel
		local reason = ""
		if #message.mentionedUsers == 1 then
			channel = message.mentionedChannels:iter()()
			member = message.guild:getMember(message.mentionedUsers:iter()())
			if member and not channel then
				success = member:addRole('349060739815964673')
				message.channel:send("Muting "..member.mentionString.." server-wide")
			elseif member and channel then
				success = channel:getPermissionOverwriteFor(member):denyPermissions(enums.permission.sendMessages, enums.permission.addReactions)
				message.channel:send("Muting "..member.mentionString.." in "..channel.mentionString)
			end
			if args ~= "" then
				if member and channel then
					reason = args:gsub("<@.+>", ""):gsub("<#.+>", "")
				elseif member then
					reason = args:gsub("<@.+>", "")
				end
			end
		end
		if reason == "" then reason = "None" end
		if success then
			logChannel:send {
				embed = {
					title = "Member Muted",
					fields = {
						{name = "User", value = member.mentionString, inline = true},
						{name = "Moderator", value = message.author.mentionString, inline = true},
						{name = "Reason", value = reason, inline = true},
					},
				}
			}
		end
		return success
    end,
    permissions = {
        botOwner = false,
        guildOwner = true,
        admin = true,
        mod = true,
        everyone = false,
    },
    usage = "mute [#channel] <@user|userID>",
    description = "Mutes the mentioned user in the given channel, if provided, or server-wide",
    category = "Mod",
}
