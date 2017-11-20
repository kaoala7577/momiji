--[[ Forked from DannehSC/Electricity-2.0 ]]
query = require('querystring')
http = require('coro-http')
xml = require("xmlSimple").newParser()
local substitutions = require('htmlsubs')

API={
	data={},
	endpoints={
		['DBots_Stats']='https://bots.discord.pw/api/bots/%s/stats',
		['Meow']='http://random.cat/meow',
		['Bork']='https://dog.ceo/api/breeds/image/random',
		['Urban']='https://api.urbandictionary.com/v0/define?term=%s',
		['dadjoke']='https://icanhazdadjoke.com/',
		['sgo']='http://setgetgo.com/',
		['e621']='https://e621.net/post/index.json?limit=1&tags=%s',
		['Animu']='https://myanimelist.net/api/anime/search.xml?q=%s',
		['Mango']='https://myanimelist.net/api/manga/search.xml?q=%s',
	},
	DBots={},
	misc={},
}

pcall(function()
	API.data=require('./apidata.lua')
end)

function API:Post(End,Fmt,...)
	local point
	local p=API.endpoints[End]
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
	local p=API.endpoints[End]
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
	return API:Post('DBots_Stats',{client.user.id},{{"Content-Type","application/json"},{"Authorization",API.data.DBots_Auth}},json.encode(info))
end

function API.misc:Cats()
	local requestdata,request=API:Get('Meow')
	if not json.decode(request)then
		return nil,'ERROR: Unable to decode JSON [API.misc:Cats]'
	end
	return json.decode(request).file
end

function API.misc:Dogs()
	local requestdata,request=API:Get('Bork')
	if not json.decode(request)then
		return nil,'ERROR: Unable to decode JSON [API.misc:Dogs]'
	end
	return json.decode(request).message
end

function API.misc:Joke()
	local request,data=API:Get('dadjoke',nil,{{'User-Agent','luvit'},{'Accept','text/plain'}})
	return data
end

function API.misc:Urban(input)
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

function API.misc:Furry(input)
	input = input.." order:random"
	local request=query.urlencode(input:trim())
	if request then
		local technical,data=API:Get('e621',{request},{{'User-Agent','luvit'}})
		local jdata=json.decode(data)
		if jdata then
			return jdata[1]
		else
			return nil,"ERROR: unable to json decode"
		end
	else
		return nil,"ERROR: unable to urlencode"
	end
end

function API.misc:Anime(input)
	local request = query.urlencode(input)
	if request then
		local technical, data = API:Get('Animu',{request}, {{'Authorization', "Basic "..ssl.base64(API.data.MALauth)}})
		local xdata = xml:ParseXmlText(data)
		if xdata.anime then
			local t={}
			t.color = discordia.Color.fromHex('#5DA9FF').value
			if xdata.anime:children()[1] then
				local syn = xdata:children()[1]:children()[1].synopsis:value():gsub("<br />",""):gsub("%[/?i%]","*"):gsub("%[/?b%]","**")
				for k,v in pairs(substitutions) do
					syn = string.gsub(syn,k,v)
				end
				t.description=string.format("**[%s](https://myanimelist.net/anime/%s)**\n%s\n\n**Episodes:** %s\n**Score:** %s\n**Status: ** %s",xdata:children()[1]:children()[1].title:value(),xdata:children()[1]:children()[1].id:value(),syn,xdata:children()[1]:children()[1].episodes:value(),xdata:children()[1]:children()[1].score:value(),xdata:children()[1]:children()[1].status:value())
				t.thumbnail={url=xdata:children()[1]:children()[1].image:value()}
			else
				t.title="No results found for search "..input
			end
			return t
		else
			return nil, "ERROR: unable to decode XML"
		end
	else
		return nil, "ERROR: unable to urlencode"
	end
end

function API.misc:Manga(input)
	local request = query.urlencode(input)
	if request then
		local technical, data = API:Get('Mango',{request}, {{'Authorization', "Basic "..ssl.base64(API.data.MALauth)}})
		local xdata = xml:ParseXmlText(data)
		if xdata.manga then
			local t={}
			t.color = discordia.Color.fromHex('#5DA9FF').value
			if xdata.manga:children()[1] then
				local syn = xdata:children()[1]:children()[1].synopsis:value():gsub("<br />",""):gsub("%[/?i%]","*"):gsub("%[/?b%]","**")
				for k,v in pairs(substitutions) do
					syn = string.gsub(syn,k,v)
				end
				t.description=string.format("**[%s](https://myanimelist.net/manga/%s)**\n%s\n\n**Volumes:** %s\n**Chapters:** %s\n**Score:** %s\n**Status: ** %s",xdata:children()[1]:children()[1].title:value(),xdata:children()[1]:children()[1].id:value(),syn,xdata:children()[1]:children()[1].volumes:value(),xdata:children()[1]:children()[1].chapters:value(),xdata:children()[1]:children()[1].score:value(),xdata:children()[1]:children()[1].status:value())
				t.thumbnail={url=xdata:children()[1]:children()[1].image:value()}
			else
				t.title="No results found for search "..input
			end
			return t
		else
			return nil, "ERROR: unable to decode XML"
		end
	else
		return nil, "ERROR: unable to urlencode"
	end
end
