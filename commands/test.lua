return {
    id = "test",
    action = function(message, args)
    	if args ~= "" then
            logs = message.guild:getAuditLogs({type = tonumber(args), limit = 1})
            entry = logs:iter()()
            status = message:reply("```"..entry:getMember().name.."\t"..entry:getTarget().name.."```")
            return status
    	end
    end,
    permissions = {
        botOwner = true,
        guildOwner = false,
        admin = false,
        mod = false,
        everyone = false,
    },
    usage = "test [args]",
    description = "Shitty test function",
    category = "Bot Owner",
}
