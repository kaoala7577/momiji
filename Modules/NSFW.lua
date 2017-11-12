addCommand('e621', 'Posts a random image from e621 with optional tags', 'e621', '[input]', 0, false, true, function(message, args)
    if not message.channel.nsfw then
        message:reply("This command can only be used in NSFW channels.")
        return
    end
    local blacklist = {'cub', 'young', 'small_cub'}
    for _,v in ipairs(blacklist) do
        if args:match(v) then
            message:reply("A tag you searched for is blacklisted: "..v)
            return
        end
    end
    message.channel:broadcastTyping()
    local data, err
    while not data do
        local try,e = API.Misc:Furry(args)
        local bl = false
        for _,v in ipairs(blacklist) do
            if try.tags:match(v) then
                bl = true
            end
        end
        if try.file_ext~='swf' and try.file_ext~='webm' and not bl then
            data,err=try,e
        end
    end
    message:reply{embed={
        image={url=data.file_url},
        description=string.format("**Tags:** %s\n**Post:** [%s](%s)\n**Author:** %s\n**Score:** %s", data.tags:gsub('%_','\\_'):gsub(' ',', '), data.id, "https://e621.net/post/show/"..data.id, data.author, data.score)
    }}
end)
