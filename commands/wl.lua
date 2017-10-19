return {
    id = "wl",
    action = function(message, args)
		local member = message.guild:getMember(utils.parseMention(args))
		if member then
			local success
			local currentVal = conn:execute(string.format([[SELECT watchlisted FROM members WHERE member_id='%s';]], member.id)):fetch()
			if currentVal == 'f' then
				success = conn:execute(string.format([[UPDATE members SET watchlisted=true WHERE member_id='%s';]], member.id))
			else
				success = conn:execute(string.format([[UPDATE members SET watchlisted=false WHERE member_id='%s';]], member.id))
			end
			return success
    	end
    end,
    permissions = {
        botOwner = false,
        guildOwner = true,
        admin = true,
        mod = true,
        everyone = false,
    },
    usage = "wl <@user|userID>",
    description = "Add or remove the mentioned user from the watchlist",
    category = "Mod",
}
