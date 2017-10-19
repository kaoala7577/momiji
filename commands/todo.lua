return {
    id = "todo",
    action = function(message, args)
        todo = utils.readAll('TODO.md')
        status = message:reply("```markdown\n"..todo.."```")
        return status
    end,
    permissions = {
        botOwner = true,
        guildOwner = false,
        admin = false,
        mod = false,
        everyone = false,
    },
    usage = "todo",
    description = "View the github TODO.md via discord",
    category = "Bot Owner",
}
