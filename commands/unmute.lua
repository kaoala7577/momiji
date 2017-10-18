return {
    id = "unmute",
    action = function(message, args)
        local author = message.author
		local logChannel = message.guild:getChannel(message.guild._settings.modlog_channel)
		local success, member, channel
		if #message.mentionedUsers == 1 then
			channel = message.mentionedChannels:iter()()
			member = message.guild:getMember(message.mentionedUsers:iter()())
			if member and not channel then
				success = member:removeRole('349060739815964673')
				message.channel:send("Unmuting "..member.mentionString.." server-wide")
			elseif member and channel then
				if channel:getPermissionOverwriteFor(member) then
					success = channel:getPermissionOverwriteFor(member):delete()
				end
				message.channel:send("Unmuting "..member.mentionString.." in "..channel.mentionString)
			end
		end
		if success then
			logChannel:send {
				embed = {
					title = "Member Unmuted",
					fields = {
						{name = "User", value = member.mentionString, inline = true},
						{name = "Moderator", value = message.author.mentionString, inline = true},
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
    usage = "unnmute [#channel] <@user|userID>",
    description = "Attempts to unmute the mentioned user in the given channel, if provided, or server-wide",
    category = "Mod",
}
