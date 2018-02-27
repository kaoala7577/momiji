--[[ Adapted from DannehSC/Electricity-2.0 ]]

local json = require('json')
local ssl = require('openssl')
local query = require('querystring')
local http = require('coro-http')
local xml = require("xmlSimple").newParser()

API={
	data={},
	endpoints={
		['DBots_Stats']='https://discordbots.org/api/bots/%s/stats', --id: the bot ID
		['Meow']='http://random.cat/meow',
		['Bork']='https://dog.ceo/api/breeds/image/random',
		['Urban']='https://api.urbandictionary.com/v0/define?term=%s', --term: a search term
		['dadjoke']='https://icanhazdadjoke.com/',
		['e621']='https://e621.net/post/index.json?limit=1&tags=%s', --limit: a number, tags: a tag string
		['Animu']='https://myanimelist.net/api/anime/search.xml?q=%s', --q: a search query
		['Mango']='https://myanimelist.net/api/manga/search.xml?q=%s', --q: a search query
		['Weather']='http://api.openweathermap.org/data/2.5/weather?units=Metric&%s=%s&appid=%s', --s: a city, country code listing
		['Danbooru']='https://danbooru.donmai.us/posts.json?limit=1&random=true&tags=%s' --limit: a number, random: true or false, tags: a tag string
	},
	misc={},
}

pcall(function()
	API.data=storage.options.apiData
end)

function API.post(endpoint,fmt,...)
	local uri
	local url=API.endpoints[endpoint]
	if url then
		if fmt then
			uri=url:format(unpack(fmt))
		else
			uri=url
		end
	end
	return http.request('POST',uri,...)
end

function API.get(endpoint,fmt,...)
	local uri
	local url=API.endpoints[endpoint]
	if url then
		if fmt then
			uri=url:format(unpack(fmt))
		else
			uri=url
		end
	end
	return http.request('GET',uri,...)
end

function API.misc.DBots_Stats_Update(info)
	return API.post('DBots_Stats',{client.user.id},{{"Content-Type","application/json"},{"Authorization",API.data.DBotsToken}},json.encode(info))
end

function API.misc.Cats()
	local _,request=API.get('Meow')
	if not json.decode(request)then
		return nil,'ERROR: Unable to decode JSON [API.misc.Cats]'
	end
	return json.decode(request).file
end

function API.misc.Dogs()
	local _,request=API.get('Bork')
	if not json.decode(request)then
		return nil,'ERROR: Unable to decode JSON [API.misc.Dogs]'
	end
	return json.decode(request).message
end

function API.misc.Joke()
	local _,data=API.get('dadjoke',nil,{{'User-Agent','luvit'},{'Accept','text/plain'}})
	return data
end

function API.misc.Weather(input)
	local t="q"
	input = input:trim()
	local tp = input:match("^%d+$")
	if tp then
		if #tp == 5 then
			t="zip"
		else
			t="id"
		end
	end
	local request = query.urlencode(input)
	if request then
		local _,data = API.get('Weather', {t,request,API.data.WeatherKey})
		local jdata = json.decode(data)
		if t=="zip" and jdata.cod~=200 then
			t="id"
			_,data = API.get('Weather', {t,request,API.data.WeatherKey})
			jdata = json.decode(data)
		end
		if jdata then
			return jdata
		else
			return nil,"ERROR: unable to json decode"
		end
	else
		return nil,"ERROR: unable to url encode"
	end
end

function API.misc.Urban(input)
	local request=query.urlencode(input:trim())
	if request then
		local _,data=API.get('Urban',{request}, {{'User-Agent','luvit'}})
		local jdata=json.decode(data)
		if jdata then
			return jdata
		else
			return nil,"ERROR: unable to json decode"
		end
	else
		return nil,"ERROR: unable to urlencode"
	end
end

function API.misc.Furry(input)
	input = input.." order:random"
	local request=query.urlencode(input:trim())
	if request then
		local _,data=API.get('e621',{request},{{'User-Agent','luvit'}})
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

function API.misc.Booru(input)
	local request=query.urlencode(input:trim())
	if request then
		local _,data=API.get('Danbooru',{request}, {{'User-Agent','luvit'}})
		local jdata=json.decode(data)
		if jdata then
			return jdata
		else
			return nil,"ERROR: unable to json decode"
		end
	else
		return nil,"ERROR: unable to urlencode"
	end
end

function API.misc.Anime(input)
	local request = query.urlencode(input)
	if request then
		local _, data = API.get('Animu',{request}, {{'Authorization', "Basic "..ssl.base64(API.data.MALauth)}})
		local xdata = xml:ParseXmlText(data)
		if xdata.anime then
			return xdata
		else
			return nil, "ERROR: unable to decode XML"
		end
	else
		return nil, "ERROR: unable to urlencode"
	end
end

function API.misc.Manga(input)
	local request = query.urlencode(input)
	if request then
		local _, data = API.get('Mango',{request}, {{'Authorization', "Basic "..ssl.base64(API.data.MALauth)}})
		local xdata = xml:ParseXmlText(data)
		if xdata.manga then
			return xdata
		else
			return nil, "ERROR: unable to decode XML"
		end
	else
		return nil, "ERROR: unable to urlencode"
	end
end
