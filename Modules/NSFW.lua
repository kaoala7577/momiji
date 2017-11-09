addCommand('e621', 'Posts a random image from e621 with optional tags', 'e621', '[input]', 0, false, false, function(message, args)
    if not message.channel.nsfw then
        message:reply("This command can only be used in NSFW channels.")
        return
    end
    message.channel:broadcastTyping()
    local data, err = API.Misc:Furry(args)
    message:reply{embed={
        image={url=data},
    }}
end)
