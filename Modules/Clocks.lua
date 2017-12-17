Clocks = {}

function Clocks.min(time)
	--Color Change
	local guild = client:getGuild('348660188951216129')
	if guild and (math.fmod(time.min, 10) == 0) then
		local role
		if ColorChange.me then
			role = guild:getRole('348665099550195713')
			role:setColor(discordia.Color.fromRGB(math.floor(math.random(0, 255)), math.floor(math.random(0, 255)), math.floor(math.random(0, 255))))
		end
		role = guild:getRole('363398104491229184')
		role:setColor(discordia.Color.fromRGB(math.floor(math.random(0, 255)), math.floor(math.random(0, 255)), math.floor(math.random(0, 255))))
	end
	--Auto-remove Cooldown
	if guild then
		local users = Database:get(guild, "Users")
		for member in guild.members:iter() do
			if member:hasRole('348873284265312267') then
				if users[member.id] then
					local reg = users[member.id].registered
					if parseISOTime(reg) ~= reg then
						local date = parseISOTime(reg):toTableUTC()
						if (time.day > date.day) and (time.hour >= date.hour) and (time.min >= date.min) then
							member:addRole('348693274917339139')
							member:removeRole('348873284265312267')
						end
					end
				end
			end
		end
	end
end
