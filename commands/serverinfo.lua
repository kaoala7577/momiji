local utils = require("../utils")

return {
    id = "serverinfo",
    action = function(message, args)
    	local guild = message.guild
    	if client:getGuild(args) then
    		guild = client:getGuild(args)
    	end
    	local humans, bots, online = 0,0,0
    	local invite
    	for member in guild.members:iter() do
    		if member.bot then
    			bots = bots+1
    		else
    			humans = humans+1
    		end
    		if not (member.status == 'offline') then
    			online = online+1
    		end
    	end
    	for inv in guild:getInvites():iter() do
    		if inv.inviter == guild.owner.user and not inv.temporary then
    			invite = inv
    		end
    	end
    	timestamp = humanReadableTime(parseTime(guild.timestamp):toTable())
        fields = {
            {name = 'ID', value = guild.id, inline = true},
            {name = 'Name', value = guild.name, inline = true},
            {name = 'Owner', value = guild.owner.mentionString, inline = true},
            {name = 'Region', value = guild.region, inline = true},
            {name = 'Total Channels', value = #guild.textChannels+#guild.voiceChannels, inline = true},
            {name = 'Text Channels', value = #guild.textChannels, inline = true},
            {name = 'Voice Channels', value = #guild.voiceChannels, inline = true},
            {name = 'Members', value = #guild.members, inline = true},
            {name = 'Humans', value = humans, inline = true},
            {name = 'Bots', value = bots, inline = true},
            {name = 'Online', value = online, inline = true},
            {name = 'Roles', value = #guild.roles, inline = true},
            {name = 'Emojis', value = #guild.emojis, inline = true},
        }
    	if invite then
            table.insert(fields, {name = 'Invite', value = "https://discord.gg/"..invite.code, inline = false})
        end
    	status = message.channel:send {
    		embed = {
    			author = {name = guild.name, icon_url = guild.iconURL},
    			fields = fields,
    			thumbnail = {url = guild.iconURL, height = 200, width = 200},
    			color = discordia.Color.fromRGB(244, 198, 200).value,
    			footer = { text = "Server Created : "..timestamp }
    		}
    	}
    	return status
    end,
    permissions = {
        everyone = true,
    },
    usage = "serverinfo",
    description = "Displays information on the server",
    category = "General",
}
