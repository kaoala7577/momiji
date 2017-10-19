return {
    id = "t18",
    action = function(message, args)
		local member = message.guild:getMember(utils.parseMention(args))
		if member then
			local success
			local currentVal = conn:execute(string.format([[SELECT under18 FROM members WHERE member_id='%s';]], member.id)):fetch()
			if currentVal == 'f' then
				success = conn:execute(string.format([[UPDATE members SET under18=true WHERE member_id='%s';]], member.id))
			else
				success = conn:execute(string.format([[UPDATE members SET under18=false WHERE member_id='%s';]], member.id))
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
    usage = "t18 <@user|userID>",
    description = "Add or remove the Under 18 flag from the mentioned user",
    category = "Mod",
}
