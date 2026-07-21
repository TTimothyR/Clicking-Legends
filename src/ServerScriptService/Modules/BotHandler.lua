local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local config = {
	BOT_URL = "https://clrbot.onrender.com",
	ROBLOX_SECRET = "hG7kP2mN9qR4",
	HATCH_CHANNEL = "1521124425913729136",
	TEST_CHANNEL = "1525084250347409438",
}

local headers = {
	["Content-Type"] = "application/json",
	["x-roblox-secret"] = config.ROBLOX_SECRET,
}

local framework = ReplicatedStorage:WaitForChild("Framework")
local library = framework:WaitForChild("Library")
local PlayerData = require(ServerScriptService.DataModules.PlayerData)
local Globals = require(ReplicatedStorage.Framework.Globals)
local petStats = require(library.PetStats)

local CACHE_TTL = Globals.ExistRefreshTime -- seconds
local CACHE_TOPIC = "PetExistCache"
local existCache = {}
local fetchInProgress = false

local BotHandler = {}
BotHandler.Private = {}

local function PostRaw(endPoint, jsonBody)
	local s, result = pcall(function()
		return HttpService:RequestAsync({
			Url = config.BOT_URL .. endPoint,
			Method = "POST",
			Headers = headers,
			Body = jsonBody,
		})
	end)
	if not s then
		warn("[BotBridge] HTTP error on " .. endPoint .. ": " .. tostring(result))
		return nil
	end
	if result.StatusCode ~= 200 then
		warn("[BotBridge] Non-200 on " .. endPoint .. ": " .. tostring(result.StatusCode) .. " " .. tostring(result.Body))
		return nil
	end
	local decodeOk, decoded = pcall(HttpService.JSONDecode, HttpService, result.Body)
	if not decodeOk then
		warn("[BotBridge] JSONDecode failed for " .. endPoint .. ": " .. tostring(decoded))
		return nil
	end
	return decoded
end

local function Sanitise(value, depth)
	depth = depth or 0
	if depth > 8 then
		return nil
	end
	local t = typeof(value)
	if t == "string" or t == "number" or t == "boolean" then
		return value
	end
	if t == "table" then
		local out = {}
		for k, v in pairs(value) do
			if typeof(k) == "string" then
				local sv = Sanitise(v, depth + 1)
				if sv ~= nil then
					out[k] = sv
				end
			end
		end
		return out
	end
	return nil
end

local function Post(endPoint, payload)
	local encodeOk, body = pcall(HttpService.JSONEncode, HttpService, Sanitise(payload))
	if not encodeOk then
		warn("[BotBridge] JSONEncode failed for " .. endPoint .. ": " .. tostring(body))
		return nil
	end
	return PostRaw(endPoint, body)
end

local function SyncPetStats()
	local payload = {}
	for petName, data in pairs(petStats) do
		if data.Secret == true or data.Exclusive == true then
			payload[petName] = {
				isShiny = false,
				imageId = tostring(data.ImageId or ""),
			}
		end
	end
	if next(payload) == nil then
		warn("[BotBridge] No secret pets found in PetStats to sync.")
		return
	end
	local testOk, testErr = pcall(HttpService.JSONEncode, HttpService, { pets = payload })
	if not testOk then
		warn("[BotBridge] PetStats payload failed JSON encoding: " .. tostring(testErr))
		return
	end
	local result = Post("/sync-pets", { pets = payload })
	if result and result.ok then
		print(("[BotBridge] Synced %d secret pets to Discord bot."):format(result.synced))
	else
		warn("[BotBridge] sync-pets failed.")
	end
end

local function HandleLinkCommand(player, token)
	local result = Post("/confirm-link", {
		token = token,
		robloxUsername = player.Name,
	})
	if not result then
		warn("[BotBridge] /confirm-link failed for " .. player.Name)
		return false
	end
	if result.ok then
		print(("[BotBridge] %s linked to Discord ID %s"):format(player.Name, tostring(result.discordId)))
		return true
	else
		warn(("[BotBridge] Link failed for %s: %s"):format(player.Name, tostring(result.error)))
		return false
	end
end

local function FetchAllAndBroadcast()
	if fetchInProgress then
		return
	end
	fetchInProgress = true

	local s, result = pcall(function()
		return HttpService:RequestAsync({
			Url = config.BOT_URL .. "/pet-exist-all",
			Method = "GET",
			Headers = headers,
		})
	end)

	fetchInProgress = false

	if not s or result.StatusCode ~= 200 then
		warn("[BotBridge] pet-exist-all fetch failed: " .. tostring(result))
		return
	end

	local ok, data = pcall(HttpService.JSONDecode, HttpService, result.Body)
	if not ok or not data.ok or type(data.pets) ~= "table" then
		warn("[BotBridge] pet-exist-all decode failed")
		return
	end

	local now = os.clock()

	for key, value in pairs(data.pets) do
		existCache[key] = { value = value, fetchedAt = now }
	end

	local broadcastOk, broadcastJson = pcall(HttpService.JSONEncode, HttpService, data.pets)
	if broadcastOk then
		pcall(MessagingService.PublishAsync, MessagingService, CACHE_TOPIC, broadcastJson)
	end
end

-- Players.PlayerAdded:Connect(function(player)
-- 	player.Chatted:Connect(function(message)
-- 		local token = message:match("^/linkdiscord%s+(%S+)$")
-- 		if token then
-- 			task.spawn(HandleLinkCommand, player, token:upper())
-- 		end
-- 	end)
-- end)

-- ── 3. Hatch BindableFunction ─────────────────────────────────────────────────
-- Usage (server script):
--   local changes = {
--       { petName = "Void Serpent", isShiny = false, imageId = "12345678", delta = 1 },
--   }
--   task.spawn(function()
--       ServerStorage.Hatch:Invoke(player.Name, HttpService:JSONEncode(changes))
--   end)

function BotHandler.Private.Hatch(playerName, changesJson)
	local ok, changes = pcall(HttpService.JSONDecode, HttpService, changesJson)
	if not ok or type(changes) ~= "table" then
		warn("[BotBridge] Hatch: invalid changesJson — " .. tostring(changes))
		return
	end
	local channelId = RunService:IsStudio() and config.TEST_CHANNEL or config.HATCH_CHANNEL
	local bodyOk, body = pcall(HttpService.JSONEncode, HttpService, {
		playerName = tostring(playerName),
		channelId = channelId,
		changes = changes,
	})
	if not bodyOk then
		warn("[BotBridge] Hatch: JSONEncode failed — " .. tostring(body))
		return
	end
	PostRaw("/hatch", body)
end

function BotHandler.Private.Craft(changesJson)
	local ok, changes = pcall(HttpService.JSONDecode, HttpService, changesJson)
	if not ok or type(changes) ~= "table" then
		warn("[BotBridge] Craft: invalid changesJson — " .. tostring(changes))
		return
	end
	local bodyOk, body = pcall(HttpService.JSONEncode, HttpService, { changes = changes })
	if not bodyOk then
		warn("[BotBridge] Craft: JSONEncode failed — " .. tostring(body))
		return
	end
	PostRaw("/craft", body)
end

function BotHandler.Private.Delete(changesJson)
	local ok, changes = pcall(HttpService.JSONDecode, HttpService, changesJson)
	if not ok or type(changes) ~= "table" then
		warn("[BotBridge] Delete: invalid changesJson — " .. tostring(changes))
		return
	end
	local bodyOk, body = pcall(HttpService.JSONEncode, HttpService, { changes = changes })
	if not bodyOk then
		warn("[BotBridge] Delete: JSONEncode failed — " .. tostring(body))
		return
	end
	PostRaw("/delete", body)
end

function BotHandler.GetPetExist(_, petName, isShiny)
	if typeof(petName) ~= "string" then
		return nil
	end
	isShiny = isShiny == true

	local cacheKey = petName .. (isShiny and "_shiny" or "_base")
	local cached = existCache[cacheKey]

	if cached and (os.clock() - cached.fetchedAt) < CACHE_TTL then
		return cached.value
	end

	FetchAllAndBroadcast()

	local updated = existCache[cacheKey]
	if updated then
		return updated.value
	end
	if cached then
		return cached.value
	end
	return nil
end

function BotHandler.LinkPlayer(player: Player, code: string)
	if code == "" then
		return false
	end
	local profile = PlayerData.GetData(player)
	if profile.LastBotVerifyAttempt + Globals.BotVerifyRequestCooldown > os.time() then
		return (profile.LastBotVerifyAttempt + Globals.BotVerifyRequestCooldown - os.time())
	end

	profile.LastBotVerifyAttempt = os.time()

	local success = HandleLinkCommand(player, code)

	return success
end

function BotHandler.Initialize()
	task.spawn(SyncPetStats)

	MessagingService:SubscribeAsync(CACHE_TOPIC, function(message)
		local ok, pets = pcall(HttpService.JSONDecode, HttpService, message.Data)
		if not ok or type(pets) ~= "table" then
			return
		end
		local now = os.clock()
		for key, value in pairs(pets) do
			existCache[key] = { value = value, fetchedAt = now }
		end
	end)

	task.spawn(function()
		while true do
			task.wait(CACHE_TTL)
			task.spawn(FetchAllAndBroadcast)
		end
	end)
end

return BotHandler
