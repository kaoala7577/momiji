return {
    id = "help",
    action = function(message, args, cmds)
        local status
        if args == "" then
            local help, order = {}, {
                "General", "Mod", "Admin", "Guild Owner", "Bot Owner",
            }
            for com, tbl in pairs(cmds) do
                if not help[tbl.category] then help[tbl.category] = "" end
                help[tbl.category] = help[tbl.category].."`"..tbl.usage.."` - "..tbl.description.."\n"
            end
            local sorted,c = {},1
            for _,v in ipairs(order) do
                if sorted[c] and #sorted[c]+string.len("**"..v.."**\n"..help[v]) >= 2000 then
                    c = c+1
                end
                if not sorted[c] then
                    sorted[c] = ""
                end
                sorted[c] = sorted[c].."**"..v.."**\n"..help[v]
            end
            message.author:send([[**How to read this doc:**
When reading the commands, arguments in angle brackets (`<>`) are mandatory
while arguments in square brackets (`[]`) are optional.
A pipe character `|` means "or," so `a|b` means a **or** b.
No brackets should be included in the commands]])
            for _,v in ipairs(sorted) do status = message.author:send(v) end
        end
    	return status
    end,
    permissions = {
        everyone = true,
    },
    usage = "help",
    description = "DM the help page",
    category = "General",
}
