return {
    id = "roleinfo",
    action = function(message, args)
    	local role = message.guild.roles:find(function(r) return r.name:lower() == args:lower() end)
    	if role then
    		local hex = string.match(role:getColor():toHex(), "%x+")
    		local count = 0
    		for m in message.guild.members:iter() do
    			if m:hasRole(role) then count = count + 1 end
    		end
    		local hoisted, mentionable
    		if role.hoisted then hoisted = "Yes" else hoisted = "No" end
    		if role.mentionable then mentionable = "Yes" else mentionable = "No" end
    		local status = message.channel:send {
    			embed = {
    				thumbnail = {url = "http://www.colorhexa.com/"..hex:lower()..".png", height = 150, width = 150},
    				fields = {
    					{name = "Name", value = role.name, inline = true},
    					{name = "ID", value = role.id, inline = true},
    					{name = "Hex", value = role:getColor():toHex(), inline = true},
    					{name = "Hoisted", value = hoisted, inline = true},
    					{name = "Mentionable", value = mentionable, inline = true},
    					{name = "Position", value = role.position, inline = true},
    					{name = "Members", value = count, inline = true},
    				},
    				color = role:getColor().value,
    			}
    		}
    		return status
    	end
    end,
    permissions = {
        everyone = true,
    },
    usage = "roleinfo <rolename>",
    description = "Displays information on the given role",
    category = "General",
}
