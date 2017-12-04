--[[ Adapted from Timed.lua DannehSC/Electricity-2.0 ]]

local fmt = string.format

Timing = {
	_callbacks = {},
	_timers = {},
}

function Timing:on(f)
	assert(type(f)=='function','Error: X3F - callback not function')
	table.insert(self._callbacks,f)
end

function Timing:fire(...)
	for _,cb in pairs(self._callbacks)do
		coroutine.wrap(cb)(...)
	end
end

function Timing:load(guild)
	local timers = Database:get(guild).Timers or {}
	for id,timer in pairs(timers) do
		if timer.endTime<os.time() then
			coroutine.wrap(function() self:delete(guild,id) end)()
			if timer.stopped==true then return end
			self:fire(timer.data)
		else
			self:newTimer(guild,timer.endTime-os.time(),timer.data,true)
		end
	end
end

function Timing.save(guild,id,timer)
	local timers = Database:get(guild, "Timers")
	timers[id] = timer
	p(timer)
	Database:update(guild,'Timers',timers)
end

function Timing:delete(guild,id)
	local data = Database:get(guild,'Timers')
	if data then
		self._timers[id] = nil
		data[id] = nil
		Database:update(guild,'Timers',data)
	end
end

function Timing:newTimer(guild,secs,data,ign)
	if type(secs)~='number'then secs = 5 end
	local ms = secs*1000
	assert(guild~=nil,'Error 9F2 - guild nil')
	assert(type(data)=='string','Error CXT - data not string')
	local id = ssl.base64(fmt('%s|%s|%s',ssl.random(20),ms,data),true):gsub('/','')
	timer.setTimeout(ms,function()
		coroutine.wrap(function()
			if not self._timers[id] then return end
			if self._timers[id].stopped then return end
			self:fire(data)
			self:delete(guild,id)
		end)()
	end)
	local tab = {duration=secs,endTime=os.time()+secs,stopped=false,data=data}
	self._timers[id] = tab
	if not ign then self.save(guild,id,tab) end
	return id
end

function Timing:endTimer(timerId)
	if self._timers[timerId]==nil then
		client:warning('Invalid timerId passed to Timer:endTimer')
	else
		self._timers[timerId].stopped=true
	end
end

function Timing:getTimers(txt)
	local t={}
	for i,v in pairs(self._timers) do
		if v.data:find(txt) then
			t[i]=v
		end
	end
	return t
end
