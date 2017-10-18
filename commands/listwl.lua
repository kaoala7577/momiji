return {
    id = "listwl",
    action = function(message, args)
		local cur = conn:execute([[SELECT member_id FROM members WHERE watchlisted=true;]])
		local row = cur:fetch({}, "a")
		local success = row ~= nil or false
		local members = {}
		while row do
			table.insert(members, row.member_id)
			row = cur:fetch(row, "a")
		end
		if members then
			local list = "**Count: "..#members.."**"
			for _,m in pairs(members) do
				local member = message.guild:getMember(m)
				if list ~= "" then list = list.."\n"..member.username.."#"..member.discriminator..":"..member.mentionString else list = member.username.."#"..member.discriminator..":"..member.mentionString end
			end
			message:reply {
				embed = {
					title = "Watchlisted Members",
					description = list,
				}
			}
		else
			message:reply("No members are watchlisted.")
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
    usage = "listwl",
    description = "Lists all watchlisted users",
    category = "Mod",
}
