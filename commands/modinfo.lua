return {
    id = "modinfo",
    action = function(message, args)
        guild = message.guild
    	local member
    	if args ~= "" then
    		if guild:getMember(parseMention(args)) then
    			member = guild:getMember(parseMention(args))
    		end
    	else
    		member = guild:getMember(message.author)
    	end
    	if member then
            local watchlisted = conn:execute(string.format([[SELECT watchlisted FROM members WHERE member_id='%s';]], member.id)):fetch()
            local under18 = conn:execute(string.format([[SELECT under18 FROM members WHERE member_id='%s';]], member.id)):fetch()
            if watchlisted == 'f' then watchlisted = 'No' else watchlisted = 'Yes' end
            if under18 == 'f' then under18 = 'No' else under18 = 'Yes' end
            status = message:reply {
                embed = {
                    author = {name = member.username.."#"..member.discriminator, icon_url = member.avatarURL},
                    fields = {
                        {name = "Watchlisted", value = watchlisted, inline = true},
                        {name = "Under 18", value = under18, inline = true},
                    },
                    thumbnail = {url = member.avatarURL, height = 200, width = 200},
    				color = member:getColor().value,
    				timestamp = discordia.Date():toISO()
                }
            }
            return status
        end
    end,
    permissions = {
        botOwner = false,
        guildOwner = true,
        admin = true,
        mod = true,
        everyone = false,
    },
    usage = "modinfo <@user|userID>",
    description = "Displays mod-relevant data, such as watchlist status, on the given user",
    category = "Mod",
}
