return {
    id = "roles",
    action = function(message, args)
    	local roleList = {}
    	for k,v in pairs(selfRoles) do
    		for r,_ in pairs(v) do
    			if not roleList[k] then
    				roleList[k] = r.."\n"
    			else
    				roleList[k] = roleList[k]..r.."\n"
    			end
    		end
    	end
    	local status = message.channel:send {
    		embed = {
    			author = {name = "Self-Assignable Roles", icon_url = message.guild.iconURL},
    			fields = {
    				{name = "Gender Identity*", value = roleList['Gender Identity'], inline = true},
    				{name = "Sexuality", value = roleList['Sexuality'], inline = true},
    				{name = "Pronouns*", value = roleList['Pronouns'], inline = true},
    				{name = "Presentation", value = roleList['Presentation'], inline = true},
    				{name = "Assigned Sex", value = roleList['Assigned Sex'], inline = true},
    				{name = "Opt-In Roles", value = roleList['Opt-In Roles'], inline = true},
    			},
    			color = discordia.Color.fromRGB(244, 198, 200).value,
    			timestamp = discordia.Date():toISO(),
    			footer = {text = "* One or more required in this category"}
    		}
    	}
    	return status
    end,
    permissions = {
        everyone = true,
    },
    usage = "roles",
    description = "Displays the self role list",
    category = "General",
}
