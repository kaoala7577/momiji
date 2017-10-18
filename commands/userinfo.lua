local utils = require("../utils")

return {
    id = "userinfo",
    action = function(message, args)
    	local guild = message.guild
    	local member
    	if args ~= "" then
    		if guild:getMember(parseMention(args)) then
    			member = guild:getMember(parseMention(args))
    		end
    	else
    		member = guild:getMember(message.author)
    	end
    	if member then
    		local roles = ""
    		for i in member.roles:iter() do
    			if roles == "" then roles = i.name else roles = roles..", "..i.name end
    		end
    		if roles == "" then roles = "None" end
    		local joinTime = humanReadableTime(parseTime(member.joinedAt):toTable())
    		local createTime = humanReadableTime(parseTime(member.timestamp):toTable())
    		local registerTime = parseTime(conn:execute(string.format([[SELECT registered FROM members WHERE member_id='%s';]], member.id)):fetch())
    		if registerTime ~= 'N/A' then
    			registerTime = registerTime:toTable()
    			registerTime = humanReadableTime(registerTime)
    		end
    		local status = message.channel:send {
    			embed = {
    				author = {name = member.username.."#"..member.discriminator, icon_url = member.avatarURL},
    				fields = {
    					{name = 'ID', value = member.id, inline = true},
    					{name = 'Mention', value = member.mentionString, inline = true},
    					{name = 'Nickname', value = member.name, inline = true},
    					{name = 'Status', value = member.status, inline = true},
    					{name = 'Joined', value = joinTime, inline = false},
    					{name = 'Created', value = createTime, inline = false},
    					{name = 'Registered', value = registerTime, inline = false},
                        {name = 'Extras', value = "[Fullsize Avatar]("..member.avatarURL..")", inline = false},
    					{name = 'Roles ('..#member.roles..')', value = roles, inline = false},
    				},
    				thumbnail = {url = member.avatarURL, height = 200, width = 200},
    				color = member:getColor().value,
    				timestamp = discordia.Date():toISO()
    			}
    		}
            return status
    	else
    		message.channel:send("Sorry, I couldn't find that user.")
    	end
    end,
    permissions = {
        everyone = true,
    },
    usage = "userinfo [@user|userID]",
    description = "Displays information on the given user or yourself if none mentioned",
    category = "General",
}
