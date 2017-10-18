return {
    id = "help",
    action = function(message)
	local status = message.author:send([[**How to read this doc:**
When reading the commands, arguments in angle brackets (`<>`) are mandatory
while arguments in square brackets (`[]`) are optional.
**No brackets should be included in the commands**

**Commands for everyone**
`.help`: DM this help page
`.ping`: pings the bot to see if it's awake
`.userinfo <@user|userID>`: pulls up some information on the user. If no user specified it uses the sender. Aliases: `.ui`
`.role <role[, role, ...]>`: adds all the roles listed to the sending user if the roles are on the self role list. Aliases: `.asr`
`.derole <role[, role, ...]>`: same as .role but removes the roles. Aliases: `.rsr`
`.roles`: list available self-roles
`.serverinfo`: pull up information on the server. Aliases: `.si`
`.roleinfo <rolename>`: pulls up information on the listed role. Aliases: `.ri`

**Moderator Commands**
`.mute [#channel] <@user|userID>`: mutes a user, if a channel is mentioned it only mutes them in that channel
`.unmute [#channe] <@user|userID>`: undoes mute
`.register <@user|userID> <role[, role, ...]>`: registers a user with the given roles. Aliases: `.reg`
`.watchlist <@user|userID>`: adds/removes a user from the watchlist. Aliases: `.wl`
`.toggle18 <@user|userID>`: toggles the under 18 user flag. Aliases: `.t18`
`.addnote <@user|userID> <note>`: Adds a note to the mentioned user.
`.delnote <@user|userID> <index>`: Deletes the note at index for the mentioned user.
`.viewnotes <@user|userID>`: Lists all notes on the mentioned user.]])
	message.author:send([[
**Admin Commands**
`.prune <number>`: bulk deletes a number of messages
`.ar <@user|userID> <role[, role, ...]>`: adds a user to the given roles
`.rr <@user|userID> <role[, role, ...]>`: removes a user from the given roles
`.noroles [message]`: pings every member without any roles and attaches an optional message

**Guild Owner Commands**
`.nick`: changes the bot nickname
`.prefix`: changes the prefix
`.populate`: ensures that momiji has the members table up-to-date

**Bot Owner Only**
`.uname <name>`: sets the bot's username]])
    	return status
    end,
    permissions = {
        everyone = true,
    },
    usage = "help",
    description = "DM the help page",
    category = "General",
}
