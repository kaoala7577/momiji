Events = {}

function Events.memberJoin(member)
    local settings = client:getDB():Get(member, "Settings")
    if settings['welcome_message'] ~= "" and settings['welcome_channel'] and settings['welcome'] then
        --TODO: make a system so all guilds can use embeds
        if member.guild.id == '348660188951216129' then
            member.guild:getChannel(settings['welcome_channel']):send{embed = {
				title = "Welcome to "..member.guild.name.."!",
				description = "Hello, "..member.name..". Please read through <#348660188951216130> and inform a member of staff how you identify, what pronouns you would like to use, and your age. These are required.",
				thumbnail = {url = member.avatarURL, height = 200, width = 200},
				color = discordia.Color.fromRGB(0, 255, 0).value,
			}}
        else
            member.guild:getChannel(settings['welcome_channel']):send(settings['welcome_message'])
        end
    end
end

function Events.ready()
    client:setGame("m!help | Awoo!")
end
