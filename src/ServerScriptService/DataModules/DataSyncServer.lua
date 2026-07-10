local DataSync = {}
DataSync.Private = {}

-- Services
local players = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")

-- Variables
local framework = rs:WaitForChild("Framework")

local lastSentData = {}

-- Modules
local network = require(framework.Network)

-- Constants
local blackListedStats = {
	-- TradeRequestFrom = true,
	ClickDebounce = true,
}

local privateStats = {}
local infMathStats = {
	ActualClicks = true,
	TotalClicks = true,
	TotalGems = true,
	Clicks = true,
	Gems = true,
	Rebirths = true,
}

local function PackInfiniteMath(num)
	return { first = num.first, second = num.second }
end

local function DeepClone(value)
	if type(value) ~= "table" then
		return value
	end

	local cloned = {}
	for k, v in pairs(value) do
		cloned[k] = DeepClone(v)
	end
	return cloned
end

local function PackData(data, includePrivate)
	local out = {}
	for key, value in pairs(data) do
		if blackListedStats[key] then
			continue
		end
		if not includePrivate and privateStats[key] then
			continue
		end

		if infMathStats[key] then
			out[key] = PackInfiniteMath(value)
		elseif type(value) == "table" then
			out[key] = DeepClone(value)
		else
			out[key] = value
		end
	end

	return out
end

local function DeepEqual(a, b)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end

	for k, v in pairs(a) do
		if not DeepEqual(v, b[k]) then
			return false
		end
	end
	for k in pairs(b) do
		if a[k] == nil then
			return false
		end
	end

	return true
end

local function CalculateDifference(old, new)
	local difference = {}
	local hasChanges = false

	for key, newValue in pairs(new) do
		local oldValue = old[key]
		local changed = false

		if infMathStats[key] then
			changed = (oldValue == nil) or (oldValue.first ~= newValue.first) or (oldValue.second ~= newValue.second)
		elseif key == "Pets" then
			changed = (oldValue == nil) or (#oldValue ~= #newValue)
			if not changed then
				-- print('Pet amount not changed');
				for i, newPet in ipairs(newValue) do
					local oldPet = oldValue[i]
					if oldPet == nil then
						changed = true
						break
					end
					-- print('----------------------')
					for statName, statValue in pairs(newPet) do
						-- print(statName, oldPet[statName], statValue)
						if oldPet[statName] ~= statValue then
							changed = true
							break
						end
					end
					if not changed then
						for statName in pairs(oldPet) do
							-- print(statName, newPet[statName]);
							if newPet[statName] == nil then
								changed = true
								break
							end
						end
					end
					if changed then
						break
					end
				end
			end
		elseif type(newValue) == "table" then
			changed = not DeepEqual(oldValue, newValue)
		else
			changed = (oldValue ~= newValue)
		end

		if changed then
			difference[key] = newValue
			hasChanges = true
		end
	end

	for key in pairs(old) do
		if new[key] == nil then
			difference[key] = "__REMOVED__"
			hasChanges = true
		end
	end

	return hasChanges and difference or nil
end

function DataSync.Private.InitializePlayer(player, data)
	local snapshot = PackData(data, true)
	lastSentData[player] = snapshot
	network:FireClient(player, "FullDataSync", snapshot)
end

function DataSync.Private.SyncPlayer(player, data)
	local old = lastSentData[player]
	if not old then
		DataSync.Private.InitializePlayer(player, data)(player, data)
		return
	end

	local snapshot = PackData(data, true)
	local difference = CalculateDifference(old, snapshot)

	if difference then
		lastSentData[player] = snapshot
		network:FireClient(player, "DataSyncDifference", difference)
	end
end

function DataSync.GetOtherDataSync(requestingPlayer, targetUserId)
	if type(targetUserId) ~= "number" then
		return nil
	end

	local targetPlayer: Player = players:GetPlayerByUserId(targetUserId)
	if not targetPlayer or targetPlayer == requestingPlayer then
		return nil
	end

	local cache = lastSentData[targetPlayer]
	if not cache then
		return nil
	end

	local out = {}
	for key, value in pairs(cache) do
		if not privateStats[key] and not blackListedStats[key] then
			out[key] = value
		end
	end
	return out
end

function DataSync.Initialize()
	players.PlayerRemoving:Connect(function(player, _)
		lastSentData[player] = nil
	end)
end

return DataSync
