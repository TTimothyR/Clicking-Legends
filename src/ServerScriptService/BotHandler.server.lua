-- Services
local players = game:GetService('Players');
local rs = game:GetService('ReplicatedStorage');
local httpService = game:GetService('HttpService');

-- Variables
local framework = rs:WaitForChild('Framework');
local library = framework:WaitForChild('Library');

local config = {
    BOT_URL = 'https://clrbot.onrender.com',
    ROBLOX_SECRET = 'hG7kP2mN9qR4',
    HATCH_CHANNEL = '1480590775111913676',
    KEEP_ALIVE_INTERVAL = 4*60
};

local headers = {
    ["Content-Type"] = "application/json",
    ["x-roblox-secret"] = config.ROBLOX_SECRET
};

-- Modules
local petStats = require(library.PetStats);

local function Sanitise(value, depth)
	depth = depth or 0
	if depth > 8 then return nil end
	local t = typeof(value)
	if t == "string" or t == "number" or t == "boolean" then
		return value
	elseif t == "table" then
		local out = {}
		for k, v in pairs(value) do
			if typeof(k) == "string" then   -- JSON keys must be strings
				local sv = Sanitise(v, depth + 1)
				if sv ~= nil then
					out[k] = sv
				end
			end
		end
		return out
	end
	-- Instances, Vectors, EnumItems etc. are silently dropped
	return nil
end

local function Post(endPoint, payload)
    local safe = Sanitise(payload);
    local encodeOk, body = pcall(function()
		return httpService:JSONEncode(safe)
	end)
	if not encodeOk then
		warn("[BotBridge] JSONEncode failed for " .. endPoint .. ": " .. tostring(body))
		return nil
	end
    local s, result = pcall(function()
        return httpService:RequestAsync({
            Url = config.BOT_URL..endPoint,
            Method = "POST",
            Headers = headers,
            Body = body
        });
    end)
    if not s then
        warn('HTTP error on '..endPoint..': '..tostring(result));
        return nil;
    end
    if result.StatusCode ~= 200 then
        warn('Non-200 on '..endPoint..': '..result.StatusCode..' '..tostring(result.Body));
        return nil;
    end

    local decodeOk, decoded = pcall(httpService.JSONDecode, httpService, result.Body)
	if not decodeOk then
		warn("[BotBridge] JSONDecode failed for " .. endPoint .. " response: " .. tostring(decoded))
		return nil
	end 
    return decoded;
end

local function SyncPetStats()
    local payload = {};
    for name, data in pairs(petStats) do
        payload[name] = {
            rarity = data.Rarity,
            clicks = data.Clicks,
            gems = data.GemMulti,
            secret = data.Secret
        }
    end
   
    local testOk, testErr = pcall(httpService.JSONEncode, httpService, { pets = payload })
	if not testOk then
		warn("[BotBridge] PetStats payload failed JSON encoding — check for non-serialisable values in your PetStats module: " .. tostring(testErr))
		return
	end

	local result = Post("/sync-pets", { pets = payload })
	if result and result.ok then
		print(("[BotBridge] Synced %d pets to Discord bot."):format(result.synced))
	else
		warn("[BotBridge] sync-pets failed. See errors above for details.")
	end
end

task.spawn(SyncPetStats);

-- task.spawn(function()
--     while true do
--         task.wait(config.KEEP_ALIVE_INTERVAL);
--         pcall(function()
--             httpService:GetAsync(config.BOT_URL.."/ping");
--         end)
--     end
-- end)

local function SecretHatch(playerName: string, petName: string, rarity: string)
    task.spawn(function()
        Post('/hatch', {
            playerName = playerName,
            petName = petName,
            rarity = rarity,
            channelId = config.HATCH_CHANNEL
        })
    end)
end
local NotifyHatchBindable = Instance.new("BindableFunction")
NotifyHatchBindable.Name = "NotifyHatch"
NotifyHatchBindable.Parent = game:GetService("ServerStorage")

NotifyHatchBindable.OnInvoke = function(playerName, petName, rarity)
    SecretHatch(playerName, petName, rarity)
end

local HatchBindable = Instance.new("BindableFunction")
HatchBindable.Name = "Hatch"
HatchBindable.Parent = game:GetService("ServerStorage")
HatchBindable.OnInvoke = function(playerName, changesJson)
    local body = httpService:JSONEncode({
        playerName = playerName,
        channelId  = config.HATCH_CHANNEL,
        changes    = httpService:JSONDecode(changesJson)
    })
    -- send body directly, bypass Post's encoding
    pcall(function()
        httpService:RequestAsync({
            Url = config.BOT_URL .. '/hatch',
            Method = "POST",
            Headers = headers,
            Body = body
        })
    end)
end

local GetPetExist = Instance.new("RemoteFunction")
GetPetExist.Name = "GetPetExist"
GetPetExist.Parent = rs

GetPetExist.OnServerInvoke = function(player, petName, isShiny)
	if typeof(petName) ~= "string" then return nil end
	isShiny = isShiny == true -- ensure boolean
	local shinyParam = isShiny and "true" or "false"
	local url = config.BOT_URL .. "/pet-exist?name=" .. httpService:UrlEncode(petName) .. "&shiny=" .. shinyParam
	local s, result = pcall(function()
		return httpService:RequestAsync({
			Url     = url,
			Method  = "GET",
			Headers = headers,
		})
	end)
	if not s or result.StatusCode ~= 200 then return nil end
	local ok, data = pcall(httpService.JSONDecode, httpService, result.Body)
	if not ok or not data.ok then return nil end
	return data.totalExisting
end