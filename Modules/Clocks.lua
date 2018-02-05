Clocks = {}

--Currently, this file is entirely specific to my guild and I have no reason to expand it as of this time
function Clocks.min(time)
	--Color Change
	local guild = client:getGuild('348660188951216129')
	local guild2 = client:getGuild('407926063281209344')
	if guild and (math.fmod(time.min, 10) == 0) then
		local role
		role = guild:getRole('348665099550195713')
		role:setColor(discordia.Color.fromRGB(math.floor(math.random(0, 255)), math.floor(math.random(0, 255)), math.floor(math.random(0, 255))))
		role = guild:getRole('363398104491229184')
		role:setColor(discordia.Color.fromRGB(math.floor(math.random(0, 255)), math.floor(math.random(0, 255)), math.floor(math.random(0, 255))))
	end
	--Auto-remove Cooldown
	if guild then
		local users = Database:get(guild, "Users")
		--Transcend
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
	if guild2 then
		local users = Database:get(guild2, "Users")
		--Enby Folk
		for member in guild2.members:iter() do
			if member:hasRole('409109782612672513') then
				if users[member.id] then
					local reg = users[member.id].registered
					if parseISOTime(reg) ~= reg then
						local date = parseISOTime(reg):toTableUTC()
						if (time.day > date.day) and (time.hour >= date.hour) and (time.min >= date.min) then
							member:addRole('407928336094855168')
							member:removeRole('409109782612672513')
						end
					end
				end
			end
		end
	end
end

function Clocks.hour()
	API.misc.DBots_Stats_Update({server_count=#client.guilds})
	client:setGame({
		name = string.format("%s guilds | m!help", #client.guilds),
		type = 2,
	})
end
