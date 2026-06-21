local DataSync = {}

-- Services
local rs = game:GetService("ReplicatedStorage")

-- Variables
local framework = rs:WaitForChild("Framework")

local cache = {}
local isReady = false
local readyCallbacks = {}
local listeners = {}

-- Modules
local network = require(framework.Network)
local infMath = require(framework.InfiniteMath)
local playerDataTemplate = require(rs.PlayerData)

-- Constants
local infMathStats = {
	ActualClicks = true,
	TotalClicks = true,
	TotalGems = true,
	Clicks = true,
	Gems = true,
	Rebirths = true,
}

local function UnpackInfiniteMath(rawData)
	return infMath.new({ rawData.first, rawData.second })
end

local function UnpackData(data)
	local out = {}

	for key, value in pairs(data) do
		if infMathStats[key] and type(value) == "table" then
			out[key] = UnpackInfiniteMath(value)
		else
			out[key] = value
		end
	end
	return out
end

local function FireListeners(key, newValue, oldValue)
	local keyListeners = listeners[key]
	if keyListeners then
		for _, callback in ipairs(keyListeners) do
			task.spawn(callback, newValue, oldValue)
		end
	end
	local wildcard = listeners["*"]
	if wildcard then
		for _, callback in ipairs(wildcard) do
			task.spawn(callback, key, newValue, oldValue)
		end
	end
end

local function ApplyDifference(difference)
	for key, newValue in pairs(difference) do
		local oldValue = cache[key]
		if newValue == "__REMOVED__" then
			cache[key] = nil
			FireListeners(key, nil, oldValue)
		else
			cache[key] = newValue
			FireListeners(key, newValue, oldValue)
		end
	end
end

function DataSync.FullDataSync(fullData)
	cache = UnpackData(fullData)
	if not isReady then
		isReady = true
		for _, callback in ipairs(readyCallbacks) do
			task.spawn(callback)
		end
		readyCallbacks = {}
	end
	for key, value in pairs(cache) do
		FireListeners(key, value, nil)
	end
end

function DataSync.DataSyncDifference(difference)
	if not isReady then
		return
	end
	ApplyDifference(UnpackData(difference))
end

function DataSync.Get(key)
	local value = cache[key]
	if value ~= nil then
		return value
	end
	local default = playerDataTemplate.DEFAULT_PLAYER_DATA[key]
	if infMathStats[key] then
		return infMath.new(default)
	end
	return default
end

function DataSync.GetAll()
	return table.clone(cache)
end

function DataSync.IsReady()
	return isReady
end

function DataSync.OnReady(callback)
	if isReady then
		task.spawn(callback)
	else
		table.insert(readyCallbacks, callback)
	end
end

function DataSync.OnChanged(key, callback)
	if not listeners[key] then
		listeners[key] = {}
	end
	table.insert(listeners[key], callback)

	return function()
		local list = listeners[key]
		if list then
			for i, callbackIteration in ipairs(list) do
				if callbackIteration == callback then
					table.remove(list, i)
					break
				end
			end
		end
	end
end

function DataSync.GetOtherData(userId)
	-- task.spawn(function()
	local raw = network:InvokeServer("GetOtherDataSync", userId)
	return raw
	-- if raw then
	--     callback(UnpackData(raw));
	-- else
	--     callback(nil);
	-- end
	-- end)
end

return DataSync
