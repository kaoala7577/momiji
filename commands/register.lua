local utils = require("../utils")

return {
    id = "register",
    action = function(message)
    	local channel = message.guild:getChannel(message.guild._settings.modlog_channel)
    	local roles, member = parseRoleList(message)
    	local author = message.guild:getMember(message.author.id)
    	if member then
    		local rolesToAdd = {}
    		local hasGender, hasPronouns
    		for _,role in pairs(roles) do
    			for k,l in pairs(selfRoles) do
    				for r,a in pairs(l) do
    					if string.lower(role) == string.lower(r)  or (table.search(a, string.lower(role))) then
    						if (r == 'Gamer') or (r == '18+') or not (k == 'Opt-In Roles') then
    							rolesToAdd[#rolesToAdd+1] = r
    						end
    					end
    				end
    			end
    		end
    		for k,l in pairs(selfRoles) do
    			for _,j in pairs(rolesToAdd) do
    				if (k == 'Gender Identity') then
    					for r,_ in pairs(l) do
    						if r == j then hasGender = true end
    					end
    				end
    				if (k == 'Pronouns') then
    					for r,_ in pairs(l) do
    						if r == j then hasPronouns = true end
    					end
    				end
    			end
    		end
    		if hasGender and hasPronouns then
    			for _,role in pairs(rolesToAdd) do
    				function fn(r) return r.name == role end
    				member:addRole(member.guild.roles:find(fn))
    			end
    			function makeRoleList(roles)
    				local roleList = ""
    				for _,r in ipairs(roles) do
    					roleList = roleList..r.."\n"
    				end
    				return roleList
    			end
    			member:addRole(member.guild:getRole('348873284265312267'))
    			if #rolesToAdd > 0 then
    				channel:send {
    					embed = {
    						author = {name = "Registered", icon_url = member.avatarURL},
    						description = "**Registered "..member.mentionString.." with the following roles** \n"..makeRoleList(rolesToAdd),
    						color = member:getColor().value,
    						timestamp = discordia.Date():toISO(),
    						footer = {text = "ID: "..member.id}
    					}
    				}
    				client:emit('memberRegistered', member)
    				local status, err = conn:execute(string.format([[UPDATE members SET registered='%s' WHERE member_id='%s';]], discordia.Date():toISO(), member.id))
    				return status
    			end
    		else
    			message:reply("Invalid registration command. Make sure to include at least one of gender identity and pronouns.")
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
    usage = "register <@user|userID> <role[, role, ...]>",
    description = "Registers the mentioned user with the listed roles",
    category = "Mod",
}
