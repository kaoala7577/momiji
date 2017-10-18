return {
    id = "uname",
    action = function(message, args)
    	if args ~= "" then
			local status = client:setUsername(args)
			return status
    	else
    		message.author:send("You need to specify a new name.")
    	end
    end,
    permissions = {
        botOwner = true,
        guildOwner = false,
        admin = false,
        mod = false,
        everyone = false,
    },
    usage = "uname <name>",
    description = "Changes the bot's username",
    category = "Bot Owner",
}
