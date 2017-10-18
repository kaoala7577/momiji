return {
    id = "note",
    action = function(message, args)
	    local a = message.guild:getMember(message.author.id)
	    local m
	    if message.mentionedUsers then
	        if #message.mentionedUsers == 1 then
	            m = message.mentionedUsers:iter()()
	            args = args:gsub("<@.+>",""):trim()
	        else
				m = message.guild:getMember(args:match("%d+"))
				args = args:gsub(m.id,""):trim()
			end
	    end
	    if (args == "") or not m then return end
        local success, err
        if args:startswith("add") then
            args = args:gsub("^add",""):trim()
    	    success, err = conn:execute(string.format([[INSERT INTO notes (user_id, note, moderator, timestamp) VALUES ('%s', '%s', '%s', '%s');]], m.id, args, a.username, discordia.Date():toISO()))
        elseif args:startswith("del") then
            args = args:gsub("^del",""):trim()
            success, err = conn:execute(string.format([[DELETE FROM notes WHERE user_id='%s';]], m.id))
        elseif args:startswith("view") then
            args = args:gsub("^view",""):trim()
            local notelist = {}
    	    local cur = conn:execute(string.format([[SELECT * FROM notes WHERE user_id='%s';]], m.id))
    		local row = cur:fetch({},"a")
    		while row do
    			table.insert(notelist, {name = "Note Added by: "..row.moderator, value = row.note})
    			row = cur:fetch(row, "a")
    		end
    		success = message:reply {
    			embed = {
    				title = "Notes for "..m.username,
    				fields = notelist,
    			}
    		}
        else
            message:reply("Please specify add, del, or view")
        end
        if err then print(err) end
		return success
    end,
    permissions = {
        botOwner = false,
        guildOwner = true,
        admin = true,
        mod = true,
        everyone = false,
    },
    usage = "note <add|del|view> <@user|userID> <note>",
    description = "Add the note to, delete a note from, or view all notes for the mentioned user",
    category = "Mod",
}
