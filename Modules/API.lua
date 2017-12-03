--[[ Forked from DannehSC/Electricity-2.0 ]]

API={
	data={},
	endpoints={
		['DBots_Stats']='https://bots.discord.pw/api/bots/%s/stats', --TODO: Set this up
		['Meow']='http://random.cat/meow',
		['Bork']='https://dog.ceo/api/breeds/image/random',
		['Urban']='https://api.urbandictionary.com/v0/define?term=%s',
		['dadjoke']='https://icanhazdadjoke.com/',
		['e621']='https://e621.net/post/index.json?limit=1&tags=%s',
		['Animu']='https://myanimelist.net/api/anime/search.xml?q=%s',
		['Mango']='https://myanimelist.net/api/manga/search.xml?q=%s',
		['Weather']='http://api.openweathermap.org/data/2.5/weather?units=Metric&%s=%s&appid=%s'
	},
	misc={},
}

pcall(function()
	API.data=options.apiData
end)

function API:post(endpoint,fmt,...)
	local uri
	local url=API.endpoints[endpoint]
	if url then
		if fmt then
			uri=url:format(table.unpack(fmt))
		else
			uri=url
		end
	end
	return http.request('POST',uri,...)
end

function API:get(endpoint,fmt,...)
	local uri
	local url=API.endpoints[endpoint]
	if url then
		if fmt then
			uri=url:format(table.unpack(fmt))
		else
			uri=url
		end
	end
	return http.request('GET',uri,...)
end

function API.misc:DBots_Stats_Update(info)
	return API:post('DBots_Stats',{client.user.id},{{"Content-Type","application/json"},{"Authorization",API.data.DBots_Auth}},json.encode(info))
end

function API.misc:Cats()
	local requestdata,request=API:get('Meow')
	if not json.decode(request)then
		return nil,'ERROR: Unable to decode JSON [API.misc:Cats]'
	end
	return json.decode(request).file
end

function API.misc:Dogs()
	local requestdata,request=API:get('Bork')
	if not json.decode(request)then
		return nil,'ERROR: Unable to decode JSON [API.misc:Dogs]'
	end
	return json.decode(request).message
end

function API.misc:Joke()
	local request,data=API:get('dadjoke',nil,{{'User-Agent','luvit'},{'Accept','text/plain'}})
	return data
end

function API.misc:Weather(input)
	local fmt = string.format
	local type="q"
	input = input:trim()
	if input:match("^%d+$") then type="id" end
	local request = query.urlencode(input)
	if request then
		local t,data = API:get('Weather', {type,request,API.data.WeatherKey})
		local jdata = json.decode(data)
		if jdata then
			return jdata
		else
			return nil,"ERROR: unable to json decode"
		end
	else
		return nil,"ERROR: unable to url encode"
	end
end

function API.misc:Urban(input)
	local request=query.urlencode(input:trim())
	if request then
		local technical,data=API:get('Urban',{request}, {{'User-Agent','luvit'}})
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

function API.misc:Furry(input)
	input = input.." order:random"
	local request=query.urlencode(input:trim())
	if request then
		local technical,data=API:get('e621',{request},{{'User-Agent','luvit'}})
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
		local technical, data = API:get('Animu',{request}, {{'Authorization', "Basic "..ssl.base64(API.data.MALauth)}})
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

function API.misc:Manga(input)
	local request = query.urlencode(input)
	if request then
		local technical, data = API:get('Mango',{request}, {{'Authorization', "Basic "..ssl.base64(API.data.MALauth)}})
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
