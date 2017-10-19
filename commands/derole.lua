return {
    id = "derole",
    action = function(message)
    	local roles = utils.parseRoleList(message)
    	local member = message.guild:getMember(message.author)
    	local rolesToRemove = {}
    	for _,role in pairs(roles) do
    		for _,l in pairs(selfRoles) do
    			for r,a in pairs(l) do
    				if (string.lower(role) == string.lower(r)) or (table.search(a, string.lower(role))) then
    					rolesToRemove[#rolesToRemove+1] = r
    				end
    			end
    		end
    	end
    	for _,role in ipairs(rolesToRemove) do
    		function fn(r) return r.name == role end
    		member:removeRole(member.guild.roles:find(fn))
    	end
    	function makeRoleList(roles)
    		local roleList = ""
    		for _,r in ipairs(roles) do
    			roleList = roleList..r.."\n"
    		end
    		return roleList
    	end
    	if #rolesToRemove > 0 then
    		local status = message.channel:send {
    			embed = {
    				author = {name = "Roles Removed", icon_url = member.avatarURL},
    				description = "**Removed "..member.mentionString.." from the following roles** \n"..makeRoleList(rolesToRemove),
    				color = member:getColor().value,
    				timestamp = discordia.Date():toISO(),
    				footer = {text = "ID: "..member.id}
    			}
    		}
    		return status
    	end
    end,
    permissions = {
        everyone = true,
    },
    usage = "derole <role[, role, ...]>",
    description = "Removes the listed role(s) from yourself from the self role list",
    category = "General",
}
