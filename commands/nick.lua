return {
    id = "nick",
    action = function(message, args)
    	if args ~= "" then
			local success = message.guild:getMember(client.user):setNickname(args)
			return success
    	else
    		message.author:send("You need to specify a new name.")
    	end
    end,
    permissions = {
        botOwner = false,
        guildOwner = true,
        admin = false,
        mod = false,
        everyone = false,
    },
    usage = "nick <name>",
    description = "Change the nickname of the bot on your server",
    category = "Guild Owner",
}
