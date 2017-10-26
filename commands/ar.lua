return {
    id = "ar",
    action = function(message, args)
    	local roles, member = utils.parseRoleList(message)
    	local author = message.guild:getMember(message.author.id)
    	if member then
    		local rolesToAdd = {}
    		for _,role in pairs(roles) do
    			for r in message.guild.roles:iter() do
    				if string.lower(role) == string.lower(r.name) then
    					rolesToAdd[#rolesToAdd+1] = r
    				end
    			end
    		end
    		for _,role in ipairs(rolesToAdd) do
    			member:addRole(message.guild:getRole(role.id))
    		end
    		local roleList = ""
    		for _,r in ipairs(rolesToAdd) do
    			roleList = roleList..r.name.."\n"
    		end
    		if #rolesToAdd > 0 then
    			local status = message.channel:send {
    				embed = {
    					author = {name = "Roles Added", icon_url = member.avatarURL},
    					description = "**Added "..member.mentionString.." to the following roles** \n"..roleList,
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
        mod = true,
        everyone = false,
    },
    usage = "ar <@user|userID> <role[, role, ...]>",
    description = "Adds the mentioned user to the listed role(s)",
    category = "Admin",
}
