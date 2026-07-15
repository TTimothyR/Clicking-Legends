-- ── Services ──────────────────────────────────────────────────────────────────
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")

-- ── Config ────────────────────────────────────────────────────────────────────
local config = {
	BOT_URL = "https://clrbot.onrender.com",
	ROBLOX_SECRET = "hG7kP2mN9qR4",
	HATCH_CHANNEL = "1521124425913729136",
}

local headers = {
	["Content-Type"] = "application/json",
	["x-roblox-secret"] = config.ROBLOX_SECRET,
}

-- ── Modules ───────────────────────────────────────────────────────────────────
local framework = ReplicatedStorage:WaitForChild("Framework")
local library = framework:WaitForChild("Library")
local petStats = require(library.PetStats)

-- ── HTTP helpers ──────────────────────────────────────────────────────────────
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

-- ── 1. Sync secret PetStats ───────────────────────────────────────────────────
local function SyncPetStats()
	local payload = {}
	for petName, data in pairs(petStats) do
		if data.Secret == true then
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

task.spawn(SyncPetStats)

-- ── 2. Account linking ────────────────────────────────────────────────────────
local function HandleLinkCommand(player, token)
	local result = Post("/confirm-link", {
		token = token,
		robloxUsername = player.Name,
	})
	if not result then
		warn("[BotBridge] /confirm-link failed for " .. player.Name)
		return
	end
	if result.ok then
		print(("[BotBridge] %s linked to Discord ID %s"):format(player.Name, tostring(result.discordId)))
	else
		warn(("[BotBridge] Link failed for %s: %s"):format(player.Name, tostring(result.error)))
	end
end

Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		local token = message:match("^/linkdiscord%s+(%S+)$")
		if token then
			task.spawn(HandleLinkCommand, player, token:upper())
		end
	end)
end)

-- ── 3. Hatch BindableFunction ─────────────────────────────────────────────────
-- Usage (server script):
--   local changes = {
--       { petName = "Void Serpent", isShiny = false, imageId = "12345678", delta = 1 },
--   }
--   task.spawn(function()
--       ServerStorage.Hatch:Invoke(player.Name, HttpService:JSONEncode(changes))
--   end)

local HatchBindable = Instance.new("BindableFunction")
HatchBindable.Name = "Hatch"
HatchBindable.Parent = ServerStorage
HatchBindable.OnInvoke = function(playerName, changesJson)
	local ok, changes = pcall(HttpService.JSONDecode, HttpService, changesJson)
	if not ok or type(changes) ~= "table" then
		warn("[BotBridge] Hatch: invalid changesJson — " .. tostring(changes))
		return
	end
	local bodyOk, body = pcall(HttpService.JSONEncode, HttpService, {
		playerName = tostring(playerName),
		channelId = config.HATCH_CHANNEL,
		changes = changes,
	})
	if not bodyOk then
		warn("[BotBridge] Hatch: JSONEncode failed — " .. tostring(body))
		return
	end
	PostRaw("/hatch", body)
end

-- ── 4. Craft BindableFunction ─────────────────────────────────────────────────
-- Usage (server script):
--   local changes = {
--       { petName = "Void Serpent", isShiny = false, delta = -8 },
--       { petName = "Void Serpent", isShiny = true,  delta = 1  },
--   }
--   task.spawn(function()
--       ServerStorage.Craft:Invoke(HttpService:JSONEncode(changes))
--   end)

local CraftBindable = Instance.new("BindableFunction")
CraftBindable.Name = "Craft"
CraftBindable.Parent = ServerStorage
CraftBindable.OnInvoke = function(changesJson)
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

-- ── 5. Delete BindableFunction ────────────────────────────────────────────────
-- Usage (server script):
--   local changes = {
--       { petName = "Void Serpent", isShiny = false, delta = -1 },
--   }
--   task.spawn(function()
--       ServerStorage.Delete:Invoke(HttpService:JSONEncode(changes))
--   end)

local DeleteBindable = Instance.new("BindableFunction")
DeleteBindable.Name = "Delete"
DeleteBindable.Parent = ServerStorage
DeleteBindable.OnInvoke = function(changesJson)
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

-- ── 6. GetPetExist RemoteFunction — globally cached via MessagingService ──────
--
-- How it works:
--   • Each server keeps a local in-memory cache of { value, fetchedAt } per pet.
--   • When a server's cache is cold or stale it fetches ALL secret pets from the
--     bot in one request, caches every result locally, then broadcasts the full
--     cache to every other server via MessagingService.
--   • New servers that start cold immediately receive a broadcast from whichever
--     server next hits its 10-minute refresh, but also do their own fetch on
--     first request so they're never blocked waiting for a broadcast.
--   • Net result: exactly 1 bot fetch per 10 minutes across the entire game,
--     regardless of how many servers or players are calling GetPetExist.
--
-- Usage (LocalScript):
--   local count      = ReplicatedStorage.GetPetExist:InvokeServer("Void Serpent", false)
--   local shinyCount = ReplicatedStorage.GetPetExist:InvokeServer("Void Serpent", true)
--   -- returns number or nil if pet not found / bot unreachable

local CACHE_TTL = 10 * 60 -- seconds
local CACHE_TOPIC = "PetExistCache"
local existCache = {} -- [cacheKey] = { value, fetchedAt }
local fetchInProgress = false -- prevents concurrent fetches racing each other

-- Fetch ALL secret pets at once and cache + broadcast the results
local function FetchAllAndBroadcast()
	if fetchInProgress then
		return
	end
	fetchInProgress = true

	-- Build query: fetch every known secret pet in one go
	-- We hit a generic /pet-exist-all endpoint (added below to bot)
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

	-- Update local cache
	for key, value in pairs(data.pets) do
		existCache[key] = { value = value, fetchedAt = now }
	end

	-- Broadcast to all other servers
	-- Encode as a flat { key = count } table so MessagingService handles it fine
	local broadcastOk, broadcastJson = pcall(HttpService.JSONEncode, HttpService, data.pets)
	if broadcastOk then
		pcall(MessagingService.PublishAsync, MessagingService, CACHE_TOPIC, broadcastJson)
	end
end

-- Subscribe to cache broadcasts from other servers
-- When any server fetches, all others update instantly
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

-- Periodic refresh: this server independently refreshes every 10 minutes
-- so the cache never goes permanently stale if MessagingService drops a message
task.spawn(function()
	while true do
		task.wait(CACHE_TTL)
		task.spawn(FetchAllAndBroadcast)
	end
end)

local GetPetExist = Instance.new("RemoteFunction")
GetPetExist.Name = "GetPetExist"
GetPetExist.Parent = ReplicatedStorage
GetPetExist.OnServerInvoke = function(_, petName, isShiny)
	if typeof(petName) ~= "string" then
		return nil
	end
	isShiny = isShiny == true

	local cacheKey = petName .. (isShiny and "_shiny" or "_base")
	local cached = existCache[cacheKey]

	-- Return cached value if still fresh
	if cached and (os.clock() - cached.fetchedAt) < CACHE_TTL then
		return cached.value
	end

	-- Cache cold or stale — fetch all pets and broadcast
	-- This is the only code path that ever hits the bot for exist counts
	FetchAllAndBroadcast()

	-- Return freshly cached value, or stale value if fetch failed, or nil
	local updated = existCache[cacheKey]
	if updated then
		return updated.value
	end
	if cached then
		return cached.value
	end
	return nil
end
