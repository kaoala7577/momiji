Clocks = {}

--Currently, this file is entirely specific to my guild and I have no reason to expand it as of this time
function Clocks.min(time)
	--Color Change
	local guilds = { transcend = client:getGuild('348660188951216129'), enbyfolk = client:getGuild('407926063281209344')}
	local roles = {
		transcend = {
			cooldown = '348873284265312267',
			member = '348693274917339139'
		},
		enbyfolk = {
			cooldown = '409109782612672513',
			member = '407928336094855168'
		}
	}
	if guilds.transcend and (math.fmod(time.min, 10) == 0) then
		local role
		role = guilds.trancend:getRole('348665099550195713')
		role:setColor(discordia.Color.fromRGB(math.floor(math.random(0, 255)), math.floor(math.random(0, 255)), math.floor(math.random(0, 255))))
		role = guilds.transend:getRole('363398104491229184')
		role:setColor(discordia.Color.fromRGB(math.floor(math.random(0, 255)), math.floor(math.random(0, 255)), math.floor(math.random(0, 255))))
	end
	--Auto-remove Cooldown
	for name,guild in pairs(guilds) do
		local users = Database:get(guild, "Users")
		for member in guild.members:iter() do
			if member:hasRole(roles[name].cooldown) then
				if users[member.id] then
					local reg = users[member.id].registered
					print(reg)
					if parseISOTime(reg) ~= reg then
						local old = parseISOTime(reg):toSeconds()
						local new = discordia.Date.fromISO(reg):toSeconds()
						if new-old>60*60*24 then
							member:addRole(roles[name].member)
							member:removeRole(roles[name].cooldown)
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
