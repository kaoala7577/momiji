return {
    id = "ping",
    action = function(message)
    	local response = message:reply("Pong!")
    	if response then
    		local success = response:setContent("Pong!".."`"..math.round((response.createdAt - message.createdAt)*1000).." ms`")
    		return success
    	end
    end,
    permissions = {
        everyone = true,
    },
    usage = "ping",
    description = "Tests if the bot is alive and returns the message turnaround time",
    category = "General",
}
