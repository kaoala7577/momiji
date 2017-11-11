--[[ Forked from DannehSC/Electricity-2.0 ]]
query = require('querystring')
http = require('coro-http')

API={
	Data={},
	Endpoints={
		['DBots_Stats']='https://bots.discord.pw/api/bots/%s/stats',
		['Meow']='http://random.cat/meow',
		['Bork']='https://dog.ceo/api/breeds/image/random',
		['Urban']='https://api.urbandictionary.com/v0/define?term=%s',
		['Carbon']='https://www.carbonitex.net/discord/data/botdata.php',
		['dadjoke']='https://icanhazdadjoke.com/',
		['sgo']='http://setgetgo.com/',
		['e621']='https://e621.net/post/index.json?limit=1&tags=%s',
	},
	Carbon={},
	DBots={},
	Misc={},
}
pcall(function()
	API.Data=require('./apidata.lua')
end)
function API:Post(End,Fmt,...)
	local point
	local p=API.Endpoints[End]
	if p then
		if Fmt then
			point=p:format(table.unpack(Fmt))
		else
			point=p
		end
	end
	return http.request('POST',point,...)
end
function API:Get(End,Fmt,...)
	local point
	local p=API.Endpoints[End]
	if p then
		if Fmt then
			point=p:format(table.unpack(Fmt))
		else
			point=p
		end
	end
	return http.request('GET',point,...)
end
function API.DBots:Stats_Update(info)
	return API:Post('DBots_Stats',{client.user.id},{{"Content-Type","application/json"},{"Authorization",API.Data.DBots_Auth}},json.encode(info))
end
function API.Carbon:Stats_Update()
	local key=API.Data.Carbon_Key
	if not key then return end
	info={
		key=key,
		servercount=#client.guilds
	}
	return API:Post('Carbon',nil,{{"Content-Type","application/json"}},json.encode(info))
end
function API.Misc:Cats()
	local requestdata,request=API:Get('Meow')
	if not json.decode(request)then
		return nil,'ERROR: Unable to decode JSON [API.Misc:Cats]'
	end
	return json.decode(request).file
end
function API.Misc:Dogs()
	local requestdata,request=API:Get('Bork')
	if not json.decode(request)then
		return nil,'ERROR: Unable to decode JSON [API.Misc:Dogs]'
	end
	return json.decode(request).message
end
function API.Misc:Joke()
	local request,data=API:Get('dadjoke',nil,{{'User-Agent','luvit'},{'Accept','text/plain'}})
	return data
end
function API.Misc:Urban(input)
	local fmt=string.format
	local request=query.urlencode(input:trim())
	if request then
		local technical,data=API:Get('Urban',{request}, {{'User-Agent','luvit'}})
		local jdata=json.decode(data)
		if jdata then
			local t={}
			if jdata.list[1] then
				t.description = fmt('**Definition of "%s" by %s**\n%s',jdata.list[1].word,jdata.list[1].author,jdata.list[1].permalink)
				t.fields = {
					{name = "Thumbs up", value = jdata.list[1].thumbs_up or "0", inline=true},
					{name = "Thumbs down", value = jdata.list[1].thumbs_down or "0", inline=true},
					{name = "Definition", value = #jdata.list[1].definition<1000 and jdata.list[1].definition or string.sub(jdata.list[1].definition,1,1000).."..."},
					{name = "Example", value = jdata.list[1].example~='' and jdata.list[1].example or "No examples"},
				}
				t.color = discordia.Color.fromHex('#5DA9FF').value
			else
				t.title = 'No definitions found.'
			end
			return t
		else
			return nil,"ERROR: unable to json decode"
		end
	else
		return nil,"ERROR: unable to urlencode"
	end
end
function API.Misc:Furry(input)
	input = input.." order:random"
	local request=query.urlencode(input:trim())
	if request then
		local technical,data=API:Get('e621',{request},{{'User-Agent','luvit'}})
		local jdata=json.decode(data)
		if jdata then
			return jdata[1].file_url
		else
			return nil,"ERROR: unable to json decode"
		end
	else
		return nil,"ERROR: unable to urlencode"
	end
end
