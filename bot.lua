--[[ Required for discordia ]]
local discordia = require('discordia')
_G.discordia = discordia
discordia.extensions()
local enums = discordia.enums
local client = discordia.Client({cacheAllMembers = true})
_G.client = client
local token = require'token'

--[[ Required for luaSQL which loads per-guild settings and member data ]]
local luasql = require'luasql.postgres'
local env = luasql.postgres()
local conn = env:connect('mydb')
_G.conn = conn

--[[ Required for my custom command parsing ]]
local core = require'core'
local CommandEmitter = core.Emitter:extend()
local commands = CommandEmitter:new()

--[[ Required for interval-based functions ]]
local clock = discordia.Clock()
clock:start()

local utils = require("./utils")

--TODO
--Replace this with a per-guild list
local json = require("json")
_G.selfRoles = json.parse(utils.readAll('rolelist.json'))

local cmds = {}

--[[ authorizes a command for roles based on guild._settings.admin_roles and guild._settings.mod_roles ]]
function authorize(message, admins, mods)
	if not message or (message.channel.type ~= enums.channelType.text) then return end
	local member = message.guild:getMember(message.author.id)
	if admins then
		for _,r in pairs(message.guild._settings.admin_roles) do
			if member:hasRole(message.guild:getRole(r)) then return true end
		end
	end
	if mods then
		for _,r in pairs(message.guild._settings.mod_roles) do
			if member:hasRole(message.guild:getRole(r)) then return true end
		end
	end
	return false
end

--[[ command wrapper for callbacks. prevents the bot from crashing if a command fails ]]
function safeCall(func, message, args)
	local status, ret = xpcall(func, debug.traceback, message, args)
	if ret and not status then
		local channel = client:getChannel('364148499715063818')
		channel:send {
			embed = {
				description = ret,
				timestamp = discordia.Date():toISO(),
				color = discordia.Color.fromRGB(255, 0 ,0).value,
			}
		}
	end
	local react
	if status and ret then
		react = '✅'
	else
		react = '❌'
	end
	message:addReaction(react)
end

--[[ splits a command into command and everything else. handles literally every command ]]
function commandParser(message)
	if message.author.bot then return end
	if message.channel.type == enums.channelType.text then
        local prefix = message.guild._settings.prefix
		if message.content:match("^%"..prefix) then
			local str = message.content:match("^%"..prefix.."(%g+)")
			local args = message.content:gsub("^%"..prefix..str, ""):trim()
            str = str:lower()
            if table.search(table.keys(cmds), str) then
                if cmds[str].permissions.everyone then
                    commands:emit(str, message, args)
                elseif cmds[str].permissions.mods and authorize(message, false, true) then
                    commands:emit(str, message, args)
                elseif cmds[str].permissions.admin and authorize(message, true, false) then
                    commands:emit(str, message, args)
                elseif cmds[str].permissions.guildOwner and (message.member == message.guild.owner) then
                    commands:emit(str, message, args)
                elseif cmds[str].permissions.botOwner and (message.author == client.owner) then
                    commands:emit(str, message, args)
                end
            end
		end
    else
        message:reply("I'm not currently set up to handle private messages")
    end
end
client:on('messageCreate', function(m) commandParser(m) end)

--[[ init functions: load per-guild settings and ensure that all members are cached in the members table ]]
client:on('ready', function()
	print('Logged in as '.. client.user.username)
	client:setGame("Awoo!")
	for guild in client.guilds:iter() do
		local cur = conn:execute([[SELECT * FROM settings;]])
		local row = cur:fetch({}, "a")
		while row do
			if row.guild_id == guild.id then
				guild._settings = row
				guild._settings.admin_roles = utils.sqlStringToTable(row.admin_roles)
				guild._settings.mod_roles = utils.sqlStringToTable(row.mod_roles)
			end
			row = cur:fetch(row, "a")
		end
		for member in guild.members:iter() do
			conn:execute(string.format([[INSERT INTO members (member_id, nicknames, guild_id) VALUES ('%s','{"%s"}','%s') ON CONFLICT (member_id) DO UPDATE SET guild_id='%s';]], member.id, member.name, guild.id, guild.id))
		end
	end
end)

--stupid color changing function to learn how to hook callbacks to the clock
function changeColor(time)
	local guild = client:getGuild('348660188951216129')
	if guild and (math.fmod(time.min, 10) == 0) then
		local role = guild:getRole('348665099550195713')
		local success = role:setColor(discordia.Color.fromRGB(math.floor(math.random(0, 255)), math.floor(math.random(0, 255)), math.floor(math.random(0, 255))))
		role = guild:getRole('363398104491229184')
		success = role:setColor(discordia.Color.fromRGB(math.floor(math.random(0, 255)), math.floor(math.random(0, 255)), math.floor(math.random(0, 255))))
	end
end
clock:on('min', function(time) changeColor(time) end)

--Attempt to auto-remove cooldown
clock:on('min', function(time)
	local guild = client:getGuild('348660188951216129')
	if guild then
		for member in guild.members:iter() do
			if member:hasRole('348873284265312267') then
				local reg = conn:execute(string.format([[SELECT registered FROM members WHERE member_id='%s';]], member.id)):fetch()
				if reg and reg ~= 'N/A' then
					local date = utils.parseTime(reg):toTable()
					if (time.day > date.day) and (time.hour >= date.hour) and (time.min >= date.min) then
						member:addRole('348693274917339139')
						member:removeRole('348873284265312267')
					end
				end
			end
		end
	end
end)

--Update last_message in members table. not used yet
client:on('messageCreate', function(message)
	if message.channel.type == enums.channelType.text and message.author.bot ~= true then
		local status, err = conn:execute(string.format([[UPDATE members SET last_message='%s' WHERE member_id='%s';]], discordia.Date():toISO(), message.member.id))
	end
end)

--Welcome message on memberJoin
function welcomeMessage(member)
	local channel = member.guild:getChannel(member.guild._settings.welcome_channel)
	if channel then
		channel:send("Hello "..member.name..". Welcome to "..member.guild.name.."! Please read through ".."<#348660188951216130>".." and inform a member of staff how you identify, what pronouns you would like to use, and your age. These are required.")
		--[[channel:send {
			embed = {
				author = {name = "Member Joined", icon_url = member.avatarURL},
				description = "Welcome "..member.name.." to "..member.guild.name.."! Please read through "..member.guild:getTextChannel('name', 'start-here-rules').mentionString.." and inform a member of staff how you identify and what pronouns you would like to use. These are required.",
				thumbnail = {url = member.avatarURL, height = 200, width = 200},
				color = discordia.Color(0, 255, 0).value,
				timestamp = discordia.Date():toISO(),
				footer = {text = "ID: "..member.id}
			}
		}--]]
	end
end
client:on('memberJoin', function(member) welcomeMessage(member) end)

--Post-register welcome
client:on('memberRegistered', function(member)
	local channel = member.guild:getChannel('350764752898752513')
	if channel then
		channel:send("Welcome to "..member.guild.name..", "..member.mentionString..". If you're comfortable doing so, please share a bit about yourself!")
	end
end)

--[[ Silly test func, changes based on what I need to test ]]
cmds['test'] = require("commands/test")

--Change the bot username. Owner only
cmds['uname'] = require("commands/uname")

--Change the bot nickname. Guild owner only
cmds['nick'] = require("commands/nick")

--Help page.... total shit
cmds['help'] = require("commands/help")

--change prefix
cmds['prefix'] = require("commands/prefix")

--ping
cmds['ping'] = require("commands/ping")

--lists members without roles
cmds['noroles'] = require("commands/noroles")

--serverinfo
cmds['serverinfo'] = require("commands/serverinfo")
cmds['si'] = cmds['serverinfo']
cmds['si'].usage = "si"
cmds['si'].id = "si"

--roleinfo
cmds['roleinfo'] = require("commands/roleinfo")
cmds['ri'] = cmds['roleinfo']
cmds['ri'].usage = "ri <rolename>"
cmds['ri'].id = "ri"

--userinfo
cmds['userinfo'] = require("commands/userinfo")
cmds['ui'] = cmds['userinfo']
cmds['ui'].usage = "ui [@user|userID]"
cmds['ui'].id = "ui"

cmds['modinfo'] = require("commands/modinfo")
cmds['mi'] = cmds['modinfo']
cmds['mi'].usage = "mi <@user|userID>"
cmds['mi'].id = "mi"

--addRole: Mod Function only!
cmds['ar'] = require("commands/ar")

--removeRole: Mod function only!
cmds['rr'] = require("commands/rr")

--Register, same as ar but removes Not Verified
cmds['register'] = require("commands/register")
cmds['reg'] = cmds['register']
cmds['reg'].usage = "reg <@user|userID> <role[, role, ...]>"
cmds['reg'].id = "reg"

--addSelfRole
cmds['role'] = require("commands/role")

--removeSelfRole
cmds['derole'] = require("commands/derole")

--roleList
cmds['roles'] = require("commands/roles")

--Mute: Mod only
cmds['mute'] = require("commands/mute")

--Unmute, counterpart to above
cmds['unmute'] = require("commands/unmute")

--sets up mute in every text channel. currently broken due to 2.0
function setupMute(message)
	if message.author == message.guild.owner then
		local role = message.guild:getRole('name', 'Muted')
		for channel in message.guild.textChannels do
			channel:getPermissionOverwriteFor(role):denyPermissions('sends', 'addReactions')
		end
	end
end
--commands:on('setupmute', function(m, a) safeCall(setupMute, m, a) end)

--bulk delete command
cmds['prune'] = {
    id = "prune",
    action = function(message, args)
    	local logChannel = message.guild:getChannel(message.guild._settings.modlog_channel)
    	local author = message.guild:getMember(message.author.id)
		local messageDeletes = client:getListeners('messageDelete')
		local messageDeletesUncached = client:getListeners('messageDeleteUncached')
		client:removeAllListeners('messageDelete')
		client:removeAllListeners('messageDeleteUncached')
		message:delete()
		if tonumber(args) > 0 then
			args = tonumber(args)
			local xHun, rem = math.floor(args/100), math.fmod(args, 100)
			local numDel = 0
			if xHun > 0 then
				for i=1, xHun do
					deletions = message.channel:getMessages(100)
					success = message.channel:bulkDelete(deletions)
					numDel = numDel+#deletions
				end
			end
			if rem > 0 then
				deletions = message.channel:getMessages(rem)
				success = message.channel:bulkDelete(deletions)
				numDel = numDel+#deletions
			end
			logChannel:send {
				embed = {
					description = "Moderator "..author.mentionString.." deleted "..numDel.." messages in "..message.channel.mentionString,
					color = discordia.Color.fromRGB(255, 0, 0).value,
					timestamp = discordia.Date():toISO()
				}
			}
		end
		for listener in messageDeletes do
			client:on('messageDelete', listener)
		end
		for listener in messageDeletesUncached do
			client:on('messageDeleteUncached', listener)
		end
    end,
    permissions = {
        botOwner = false,
        guildOwner = true,
        admin = true,
        mod = false,
        everyone = false,
    },
    usage = "prune <number>",
    description = "Deletes the specified number of messages from the current channel",
    category = "Admin",
}

--list all watchlisted members
cmds['listwl'] = require("commands/listwl")

--toggles the watchlist state for a member
cmds['wl'] = require("commands/wl")

--toggles the under18 state for a member
cmds['t18'] = require("commands/t18")

--[[ Note Functions ]]
cmds['note'] = require("commands/note")

cmds['lua'] = {
    id = "lua",
    action = function(message, args)
    	if not args:startswith("```") then return end
    	args = string.match(args, "```(.+)```"):gsub("lua", ""):trim()
    	printresult = ""
        utils = {
        	days = days,
        	months = months,
        	sqlStringToTable = sqlStringToTable,
        	parseMention = parseMention,
        	parseTime = parseTime,
        	parseChannel = parseChannel,
        	humanReadableTime = humanReadableTime,
        }
    	sandbox = {
    		discordia = discordia,
    		client = client,
    		enums = enums,
    		conn = conn,
            cmds = cmds,
    		message = message,
    		utils = utils,
    		printresult = printresult,
    		print = function(...)
    			arg = {...}
    			for i,v in ipairs(arg) do
    				printresult = printresult..tostring(v).."\t"
    			end
    			printresult = printresult.."\n"
    		end,
    		json = require'json',
    		require = require,
    		ipairs = ipairs,
    		pairs = pairs,
    		pcall = pcall,
    		tonumber = tonumber,
    		tostring = tostring,
    		type = type,
    		unpack = unpack,
    		select = select,
    		string = string,
    		table = table,
    		math = math,
    		io = io,
    		os = os,
    	}
    	function runSandbox(sandboxEnv, sandboxFunc, ...)
    		if not sandboxFunc then return end
    		setfenv(sandboxFunc,sandboxEnv)
    		return pcall(sandboxFunc, ...)
    	end
    	status, ret = runSandbox(sandbox, loadstring(args))
    	if not ret then ret = printresult else ret = ret.."\n"..printresult end
    	if ret ~= "" and #ret < 1800 then
            message:reply("```"..ret.."```")
        elseif ret ~= "" then
            ret1 = ret:sub(0,1800)
            ret2 = ret:sub(1801)
            message:reply("```"..ret1.."```")
            message:reply("```"..ret2.."```")
        end
    	return status
    end,
    permissions = {
        botOwner = true,
        guildOwner = false,
        admin = false,
        mod = false,
        everyone = false,
    },
    usage = "lua <code in a markdown codeblock>",
    description = "Run arbitrary lua code",
    category = "Bot Owner",
}

cmds['todo'] = require("commands/todo")

--Logging functions
--Member join message
function memberJoin(member)
	local channel = member.guild:getChannel(member.guild._settings.log_channel)
	local status, err = conn:execute(string.format([[INSERT INTO members (member_id, nicknames) VALUES ('%s', '{"%s"}');]], member.id, member.name))
	if channel then
		channel:send {
			embed = {
				author = {name = "Member Joined", icon_url = member.avatarURL},
				description = member.mentionString.." "..member.username.."#"..member.discriminator,
				thumbnail = {url = member.avatarURL, height = 200, width = 200},
				color = discordia.Color.fromRGB(0, 255, 0).value,
				timestamp = discordia.Date():toISO(),
				footer = {text = "ID: "..member.id}
			}
		}
	end
end
--Member leave message
function memberLeave(member)
	local channel = member.guild:getChannel(member.guild._settings.log_channel)
	local status, err = conn:execute(string.format([[DELETE FROM members WHERE member_id='%s';]], member.id))
	if channel then
		channel:send {
			embed = {
				author = {name = "Member Left", icon_url = member.avatarURL},
				description = member.mentionString.." "..member.username.."#"..member.discriminator,
				thumbnail = {url = member.avatarURL, height = 200, width = 200},
				color = discordia.Color.fromRGB(255, 0, 0).value,
				timestamp = discordia.Date():toISO(),
				footer = {text = "ID: "..member.id}
			}
		}
	end
end
client:on('memberJoin', function(member) memberJoin(member) end)
client:on('memberLeave', function(member) memberLeave(member) end)
--Ban message
function userBan(user, guild)
	local member = guild:getMember(user) or user
	local channel = guild:getChannel(member.guild._settings.modlog_channel)
	if channel and member then
		channel:send {
			embed = {
				author = {name = "Member Banned", icon_url = member.avatarURL},
				description = member.mentionString.." "..member.username.."#"..member.discriminator,
				thumbnail = {url = member.avatarURL, height = 200, width = 200},
				color = discordia.Color.fromRGB(255, 0, 0).value,
				timestamp = discordia.Date():toISO(),
				footer = {text = "ID: "..member.id}
			}
		}
	end
end
--Unban message
function userUnban(user, guild)
	local member = guild:getMember(user) or user
	local channel = guild:getChannel(member.guild._settings.modlog_channel)
	if channel and member then
		channel:send {
			embed = {
				author = {name = "Member Unbanned", icon_url = member.avatarURL},
				description = member.mentionString.." "..member.username.."#"..member.discriminator,
				thumbnail = {url = member.avatarURL, height = 200, width = 200},
				color = discordia.Color.fromRGB(255, 0, 0).value,
				timestamp = discordia.Date():toISO(),
				footer = {text = "ID: "..member.id}
			}
		}
	end
end
client:on('userBan', function(user, guild) userBan(user, guild) end)
client:on('userUnban', function(user, guild) userUnban(user, guild) end)
--Cached message deletion
function messageDelete(message)
	local member = message.guild:getMember(message.author.id)
	local logChannel = message.guild:getChannel(message.guild._settings.log_channel)
	if logChannel and member then
		logChannel:send {
			embed = {
				author = {name = member.username.."#"..member.discriminator, icon_url = member.avatarURL},
				description = "**Message sent by "..member.mentionString.." deleted in "..message.channel.mentionString.."**\n"..message.content,
				color = discordia.Color.fromRGB(255, 0, 0).value,
				timestamp = discordia.Date():toISO(),
				footer = {text = "ID: "..member.id}
			}
		}
	end
end
--Uncached message deletion
function messageDeleteUncached(channel, messageID)
	local logChannel = message.guild:getChannel(channel.guild._settings.log_channel)
	if logChannel then
		logChannel:send {
			embed = {
				author = {name = channel.guild.name, icon_url = channel.guild.iconURL},
				description = "**Uncached message deleted in** "..channel.mentionString,
				color = discordia.Color.fromRGB(255, 0, 0).value,
				timestamp = discordia.Date():toISO(),
				footer = {text = "ID: "..channel.id}
			}
		}
	end
end
client:on('messageDelete', function(message) messageDelete(message) end)
client:on('messageDeleteUncached', function(channel, messageID) messageDeleteUncached(channel, messageID) end)

--populate the commands
for key, tbl in pairs(cmds) do
    if type(tbl) == "table" then
        commands:on(key, function(m,a) safeCall(tbl.action,m,a) end)
    else
        print("Invalid command format", key)
    end
end
client:run(token)
