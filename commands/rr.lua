return {
    id = "rr",
    action = function(message, args)
    	local roles, member = parseRoleList(message)
    	local author = message.guild:getMember(message.author.id)
    	if member then
    		local rolesToRemove = {}
    		for _,role in pairs(roles) do
    			for r in message.guild.roles:iter() do
    				if string.lower(role) == string.lower(r.name) then
    					rolesToRemove[#rolesToRemove+1] = r
    				end
    			end
    		end
    		for _,role in ipairs(rolesToRemove) do
    			member:removeRole(member.guild:getRole(role.id))
    		end
    		local roleList = ""
    		for _,r in ipairs(rolesToRemove) do
    			roleList = roleList..r.name.."\n"
    		end
    		if #rolesToRemove > 0 then
    			local status = message.channel:send {
    				embed = {
    					author = {name = "Roles Removed", icon_url = member.avatarURL},
    					description = "**Removed "..member.mentionString.." from the following roles** \n"..roleList,
    					color = member:getColor().value,
    					timestamp = discordia.Date():toISO(),
    					footer = {text = "ID: "..member.id}
    				}
    			}
    			return status
    		end
    	end
    end,
    permissions = {
        botOwner = false,
        guildOwner = true,
        admin = true,
        mod = false,
        everyone = false,
    },
    usage = "rr <@user|userID> <role[, role, ...]>",
    description = "Removes the mentioned user from the listed role(s)",
    category = "Admin"
}
