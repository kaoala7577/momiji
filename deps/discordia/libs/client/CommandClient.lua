local Client = require('client/Client')
require('../../../Modules/Functions')

local CommandClient = require('class')('CommandClient', Client)

function CommandClient:__init(options)
    options = options or {}
    Client.__init(self, options)
    self._commands = {}
    self:on('messageCreate', function(m) self:onMessageCreate(m) end)
end

function CommandClient:addCommand(name, desc, cmds, usage, rank, multiArg, serverOnly, func)
    local b,e,n,g = checkArgs({'string', 'string', {'table','string'}, 'string', 'number', 'boolean', 'boolean', 'function'}, {name,desc,cmds, usage, rank,multiArg,serverOnly,func})
    if not b then
        --TODO: error throw
        print(name.." failed")
        return
    end
    self._commands[name] = {name=name, description=desc,commands=(type(cmds)=='table' and cmds or {cmds}),usage=usage,rank=rank,multi=multiArg,serverOnly=serverOnly,action=func}
end

function CommandClient:getCommands()
    return self._commands
end

function CommandClient:onMessageCreate(msg)
    local private
    local errorLog = self:getChannel('364148499715063818')
    if msg.guild then private=false else private=true end
    local sender = (private and msg.author or msg.member or msg.guild:getMember(msg.author))
    if msg.author.bot then return end
    if not private then
        --Load settings for the guild, Database.lua keeps a cache of requests to avoid mmaking excessive queries
        data = self:getDB():Get(msg)
        self._settings = data.Settings
        self._ignore = data.Ignore
        self._roles = data.Roles
        if data.Users==nil or data.Users[msg.author.id]==nil then
            data.Users[msg.author.id] = { registered="", watchlisted=false, under18=false, last_message=require('utils/Date')():toISO() }
        else
            data.Users[msg.author.id].registered = require('utils/Date')():toISO()
        end
        self:getDB():Update(msg, "Users", data.Users)
    end
    local command, rest = self:resolveCommand(msg.content, private)
    if not command then return end --If the prefix isn't there, don't bother with anything else
    local rank = getRank(sender, not private)
    for name,tab in pairs(self._commands) do
        for ind,cmd in pairs(tab.commands) do
            if command:lower() == cmd:lower() then
                if tab.serverOnly and private then
                    msg:reply("This command is not available in private messages.")
                    return
                end
                if rank>=tab.rank then
                    local args
                    if tab.multi then
                        args = string.split(rest, ',')
                        for i,v in ipairs(args) do args[i]=v:trim() end
                    else
                        args = rest
                    end
                    local a,b = pcall(tab.action, msg, args)
                    if not a then
                        errorLog:send {embed = {
            				description = b,
            				timestamp = require('utils/Date')():toISO(),
            				color = require('utils/Color').fromRGB(255, 0 ,0).value,
            			}}
                        if tab.name ~= "Prune" then msg:addReaction('❌') end
                    else
                        if tab.name ~= "Prune" then msg:addReaction('✅') end
                    end
                    --TODO: Command Logging
                else
                    if tab.name ~= "Prune" then msg:addReaction('❌') end
                    msg:reply("Insufficient permission to execute command: "..tab.name..". Rank "..tostring(tab.rank).." expected, your rank: "..tostring(rank))
                end
            end
        end
    end
end

function CommandClient:resolveCommand(str, p)
    if p then prefix = "" else prefix=self._settings.prefix end
    if not string.startswith(str,prefix)then return end
    local command, rest = str:sub(#prefix+1):match('(%S+)%s*(.*)')
    return command, rest
end

function CommandClient:loadDatabase(db)
    self._database = db
end

function CommandClient:getDB()
    return self._database
end

return CommandClient
