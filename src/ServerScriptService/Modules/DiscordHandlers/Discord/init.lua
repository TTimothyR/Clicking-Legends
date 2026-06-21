local Discord = {}
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Framework = ReplicatedStorage:WaitForChild("Framework")

local Library = Framework:WaitForChild("Library")

local ImageService = require(Library:WaitForChild("ImageService"))
local EggStats = require(Library:WaitForChild("EggStats"))
local Modules = ServerScriptService.Modules
local DiscordHandlers = Modules.DiscordHandlers
local DiscordManager = require(DiscordHandlers.DiscordManager)
local FormatBigNumbers = require(script.FormatBigNumbers)
local Testing = RunService:IsStudio()
local DataStore = Testing and DataStoreService:GetDataStore("Testing_Pet_Count_01")
	or DataStoreService:GetDataStore("Pet_Count_01")

local BloxlinkAPI = "7ac26cbd-a3a4-4288-8961-cd4b41a8dfbc"
local DiscordServer = "1518177955690315806"
local BloxlinkCache = {}

local function AddCommas(num)
	local f, k = tostring(num), nil
	while true do
		f, k = string.gsub(f, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then
			break
		end
	end
	return f
end

local function GetExistKey(PetName, Tier)
	local BaseName = PetName
	if Tier then
		return Tier .. "." .. BaseName
	end
	return BaseName
end

local function Increment(PetName, Tier)
	local PetKey = GetExistKey(PetName, Tier)
	local success, err = pcall(function()
		DataStore:IncrementAsync(PetKey, 1)
	end)
	if not success then
		warn(err)
	end
end

local function GetExist(PetKey)
	local success, result = pcall(function()
		return DataStore:GetAsync(PetKey)
	end)
	if not success then
		warn(result)
	end
	return result or 0
end

local function GetDiscordIDAsync(RobloxID)
	if BloxlinkCache[RobloxID] then
		return BloxlinkCache[RobloxID]
	end

	warn(BloxlinkCache)

	warn(DiscordServer, RobloxID)

	local url = string.format("https://api.blox.link/v4/public/guilds/%s/roblox-to-discord/%d", DiscordServer, RobloxID)
	warn(url)
	local discordId = nil
	local success, response = pcall(function()
		return HttpService:GetAsync(url, true, { ["Authorization"] = BloxlinkAPI })
	end)

	warn(success, response)

	if success then
		local data = HttpService:JSONDecode(response)
		warn(data)
		if data.discordIDs and #data.discordIDs > 0 then
			discordId = data.discordIDs[1]
			BloxlinkCache[RobloxID] = discordId
		end
	end

	return discordId
end

function Discord.SecretPet(Player, PetName, Tier, EggName)
	task.spawn(function()
		Increment(PetName, Tier)

		local PetChance = (EggName and EggStats[EggName].Pets[PetName][1] or 100)
		local IsProduct = false
		local FormattedChance = PetChance < 1 and ("1 / **%s**"):format(FormatBigNumbers(100 / PetChance))
			or ("**%i%s**"):format(PetChance, "%")

		--local TierData = Tier and TierService:GetTierData(Tier)
		local ExistKey = GetExistKey(PetName, Tier)
		local Description = ("**Hatched By:** ``%s``\n%s\n **Exist Count:** ``%s``"):format(
			Player.Name,
			("The rarity of hatching this pet is %s"):format(FormattedChance),
			AddCommas(GetExist(ExistKey))
		)
		--if Tier and TierFormattedChance then
		--	Description = Description .. ("\n**Tier:** %s (%s)"):format(Tier, TierFormattedChance)
		--end

		local IsMythic = PetName:find("Mythic")
		local SecretName = IsMythic and PetName:gsub("^Mythic ", "") or PetName
		local FinalColor = IsMythic and (Tier and 0x00ff77 or 0x0a37ff) or (Tier and 0xffb246 or 0x000000)
		local FinalTitle = ("%s%s"):format(Tier and Tier .. " " or "", IsMythic and ("Mythic " .. SecretName) or PetName)

		local ImageID = ImageService[PetName]
		local NewImageID = ImageID
		for i = 1, string.len(ImageID) do
			if tonumber(NewImageID) then
				break
			end
			NewImageID = string.sub(ImageID, i, string.len(ImageID))
		end

		if IsProduct then
			local Content = "Wow! " .. Player.Name .. " hatched a Robux Pet (" .. PetName .. "), congrats!"
			DiscordManager:Send({
				Type = Testing and "TestRobux" or "Robux",
				Content = Content,
				Author = "New Robux Pet hatched!",
				Title = FinalTitle,
				Color = tonumber(FinalColor),
				Description = Description,
				ImageType = "Asset",
				ImageID = NewImageID,
				Field = {},
			})
		else
			task.spawn(function()
				local DiscordID = GetDiscordIDAsync(Player.UserId)
				warn(DiscordID)
				local Content = DiscordID and ("Wow! <@" .. DiscordID .. "> hatched an Ancient Pet (" .. PetName .. "), congrats!")
					or ("Wow! " .. Player.Name .. " hatched an Ancient Pet (" .. PetName .. "), congrats!")
				DiscordManager:Send({
					Type = Testing and "Test" or "Hatch",
					Content = Content,
					Author = "New Secret Pet hatched!",
					Title = FinalTitle,
					Color = tonumber(FinalColor),
					Description = Description,
					ImageType = "Asset",
					ImageID = NewImageID,
					Field = {},
				})
			end)
		end
	end)
end

return Discord
