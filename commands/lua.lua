return {
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
