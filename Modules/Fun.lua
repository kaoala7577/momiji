addCommand('Urban', 'Search for a term on Urban Dictionary', {'urban', 'ud'}, '<search term>', 0, false, false, function(message, args)
    local data, err = API.Misc:Urban(args, nil)
    if data then
        message:reply{embed=data}
    end
end)

addCommand('Cat', 'Meow', 'cat', '', 0, false, false, function(message, args)
    local data, err = API.Misc:Cats()
    if data then
        message:reply{embed={
            image={url=data}
        }}
    end
end)

addCommand('Dog', 'Bork', 'dog', '', 0, false, false, function(message, args)
    local data, err = API.Misc:Dogs()
    if data then
        message:reply{embed={
            image={url=data}
        }}
    end
end)

addCommand('Joke', 'Tell a joke', 'joke', '', 0, false, false, function(message, args)
    local data, err = API.Misc:Joke()
    message:reply(data or err)
end)
