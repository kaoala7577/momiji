return {
    id = "prefix",
    action = function(message, args)
    	if args ~= "" then
			local status, err = conn:execute(string.format([[UPDATE settings SET prefix='%s' WHERE guild_id='%s';]], args, message.guild.id))
			if status then
				local curr = conn:execute(string.format([[SELECT * FROM settings WHERE guild_id='%s';]], message.guild.id))
				local row = curr:fetch({}, "a")
				message.guild._settings.prefix = row.prefix
				return status
    		end
    	end
    end,
    permissions = {
        botOwner = false,
        guildOwner = true,
        admin = false,
        mod = false,
        everyone = false,
    },
    usage = "prefix <prefix>",
    description = "Change the bot prefix for your server",
    category = "Guild Owner",
}
