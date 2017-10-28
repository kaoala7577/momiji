return {
    id = "prune",
    action = function(message, args)
    	local logChannel = message.guild:getChannel(message.guild._settings.modlog_channel)
    	local author = message.guild:getMember(message.author.id)
        local messageDeletes = utils.removeListeners(client, 'messageDelete')
		local messageDeletesUncached = utils.removeListeners(client, 'messageDeleteUncached')
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
			logChannel:send {
				embed = {
					description = "Moderator "..author.mentionString.." deleted "..numDel.." messages in "..message.channel.mentionString,
					color = discordia.Color.fromRGB(255, 0, 0).value,
					timestamp = discordia.Date():toISO()
				}
			}
		end
        utils.registerListeners(client, 'messageDelete', messageDeletes)
		utils.registerListeners(client, 'messageDeleteUncached', messageDeletesUncached)
    end,
    permissions = {
        botOwner = false,
        guildOwner = true,
        admin = true,
        mod = false,
        everyone = false,
    },
    usage = "prune <number>",
    description = "Deletes the specified number of messages from the current channel",
    category = "Admin",
}
