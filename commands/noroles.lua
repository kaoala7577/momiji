return {
    id = "noroles",
    action = function(message, args)
		local predicate = function(member) return #member.roles == 0 end
		local list = {}
		for m in message.guild.members:findAll(predicate) do
			list[#list+1] = m.mentionString
		end
		local listInLines = " "
		for _,n in pairs(list) do
			if listInLines == " " then
				listInLines = n
			else
				listInLines = listInLines.."\n"..n
			end
		end
		local status
		if args ~= "" then
			status = message:reply(listInLines.."\n"..args)
		else
			status = message:reply(listInLines)
		end
        return status
    end,
    permissions = {
        botOwner = false,
        guildOwner = true,
        admin = true,
        mod = false,
        everyone = false,
    },
    usage = "noroles [message]",
    description = "Pings all members without any roles with an optional message",
    category = "Admin",
}
