return {
    id = "role",
    action = function(message)
    	local roles = parseRoleList(message)
    	local member = message.guild:getMember(message.author)
    	local rolesToAdd = {}
    	local rolesFailed = {}
    	for i,role in ipairs(roles) do
    		for k,l in pairs(selfRoles) do
    			for r,a in pairs(l) do
    				if string.lower(role) == string.lower(r)  or (table.search(a, string.lower(role))) then
    					if member:hasRole(member.guild:getRole('348873284265312267')) and (k == 'Opt-In Roles') then
    						if (r == 'Gamer') or (r == '18+') or (r == 'Momiji Dev') or (r == 'D&D') then
    							rolesToAdd[#rolesToAdd+1] = r
    						else rolesFailed[#rolesFailed+1] = r.." is only available after cooldown" end
    					elseif (member:hasRole(member.guild:getRole('349051015758348289')) or member:hasRole(member.guild:getRole('349051017226354729'))) and (k == 'Opt-In Roles') then
    						if not (r == 'NSFW-Selfies' or r == 'NSFW-Nb' or r == 'NSFW-Fem' or r == 'NSFW-Masc') then
    							rolesToAdd[#rolesToAdd+1] = r
    						else rolesFailed[#rolesFailed+1] = r.." is not available to cis people" end
    					else
    						rolesToAdd[#rolesToAdd+1] = r
    					end
    				end
    			end
    		end
    	end
    	local rolesAdded = {}
    	for _,role in ipairs(rolesToAdd) do
    		function fn(r) return r.name == role end
    		if not member:hasRole(member.guild.roles:find(fn)) then
    			rolesAdded[#rolesAdded+1] = role
    			member:addRole(member.guild.roles:find(fn))
    		else rolesFailed[#rolesFailed+1] = "You already have "..role end
    	end
    	function makeRoleList(roles)
    		local roleList = ""
    		for _,r in ipairs(roles) do
    			roleList = roleList..r.."\n"
    		end
    		return roleList
    	end
    	local status
    	if #rolesAdded > 0 then
    		status = message.channel:send {
    			embed = {
    				author = {name = "Roles Added", icon_url = member.avatarURL},
    				description = "**Added "..member.mentionString.." to the following roles** \n"..makeRoleList(rolesAdded),
    				color = member:getColor().value,
    				timestamp = discordia.Date():toISO(),
    				footer = {text = "ID: "..member.id}
    			}
    		}
    	end
    	if #rolesFailed > 0 then
    		message.channel:send {
    			embed = {
    				author = {name = "Roles Failed to be Added", icon_url = member.avatarURL},
    				description = "**Failed to add the following roles to** "..member.mentionString.."\n"..makeRoleList(rolesFailed),
    				color = member:getColor().value,
    				timestamp = discordia.Date():toISO(),
    				footer = {text = "ID: "..member.id}
    			}
    		}
    	end
    	return status
    end,
    permissions = {
        everyone = true,
    },
    usage = "role <role[, role, ...]>",
    description = "Adds the listed role(s) to yourself from the self role list",
    category = "General",
}
