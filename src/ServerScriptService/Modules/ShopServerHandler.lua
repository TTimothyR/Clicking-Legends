local ShopHandler = {}

-- Services
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local players = game:GetService("Players")
local mps = game:GetService("MarketplaceService")
local rs = game:GetService("ReplicatedStorage")

-- Variables
local framework = rs:WaitForChild("Framework")
local library = framework:WaitForChild("Library")

-- Modules
local BotHandler = require(script.Parent.BotHandler).Private
local LogHandler = require(ServerScriptService.Modules.Private.LogHandler)
local GenerateID = require(ReplicatedStorage.Framework.GenerateID)
local ImageService = require(ReplicatedStorage.Framework.Library.ImageService)
local shopStats = require(library.ShopStats)
local network = require(framework.Network)
local infMath = require(framework.InfiniteMath)
local playerData = require(script.Parent.Parent.DataModules.PlayerData)
local dataSync = require(script.Parent.Parent.DataModules.DataSyncServer).Private
local rewardHandler = require(script.Parent.Private.RewardHandler)

local ItemShopHandlerPrivate = require("./Private/ItemShopHandlerPrivate")

-- Constants
local gpIDToName = {}
local productIDToName = {}
local callbacks = {
	["+500 Pet Storage"] = function(player: Player)
		local profile = playerData.GetData(player)
		profile.PetStorage += 500

		dataSync.SyncPlayer(player, profile)
	end,
	["Extra Equips"] = function(player: Player)
		local profile = playerData.GetData(player)
		profile.PetEquips += 3

		dataSync.SyncPlayer(player, profile)
	end,
	["Extra Egg"] = function(player: Player)
		local profile = playerData.GetData(player)
		profile.EggHatches += 1

		dataSync.SyncPlayer(player, profile)
	end,
	["VIP"] = function(player: Player)
		local profile = playerData.GetData(player)
		profile.PetStorage += 100

		dataSync.SyncPlayer(player, profile)
	end,

	["Gift"] = function(player: Player, gamepassName: string)
		local profile = playerData.GetData(player)
		if not profile then
			warn("Profile not found. Gift likely not granted, please contact the developers.")
		end

		profile.Gifts[GenerateID.NewID()] = gamepassName

		dataSync.SyncPlayer(player, profile)
	end,

	["Pet"] = function(player: Player, pets)
		local changes = {}
		for _, data in pairs(pets) do
			local shiny = (data.PetName:find("Shiny ") ~= nil)
			local _ = rewardHandler.ClaimPet(player, data.PetName, shiny, data.Enchant)

			task.spawn(function()
				table.insert(changes, {
					petName = data.PetName,
					isShiny = shiny,
					imageId = tostring(ImageService[data.PetName]:gsub("rbxassetid://", "")) or "",
					chance = 100,
					delta = 1,
					showHatch = false,
				})
			end)
		end

		task.spawn(function()
			BotHandler.Hatch(player.Name, HttpService:JSONEncode(changes))
		end)
		local profile = playerData.GetData(player)
		dataSync.SyncPlayer(player, profile)
	end,
	["Gem"] = function(player: Player, baseGems: number, additionalRewards)
		local profile = playerData.GetData(player)
		local toAdd = infMath.new(profile.Rebirths * baseGems)
		profile.Gems = infMath.new(profile.Gems + toAdd)
		local leaderstats = player:FindFirstChild("leaderstats") :: Folder
		leaderstats.Gems.Value = profile.Gems:GetSuffix(true)

		for _, reward in ipairs(additionalRewards) do
			local rewardType = reward[1]

			if rewardType == "Pet" then
				local _ = rewardHandler.ClaimPet(player, reward[2], reward[3], "")
			elseif rewardType == "Potion" then
				rewardHandler.ClaimPotion(player, reward[2], reward[3])
			end
		end

		dataSync.SyncPlayer(player, profile)
	end,
	["RestockShop"] = function(player: Player)
		local profile = playerData.GetData(player)
		local CurrentShop = profile.CurrentItemShop

		if CurrentShop then
			ItemShopHandlerPrivate.RestockShop(player, CurrentShop, true)
		end

		dataSync.SyncPlayer(player, profile)
	end,
}

local function GamepassPurchaseHandler()
	for gpName, data in pairs(shopStats.Gamepasses) do
		if data.GamepassID then
			gpIDToName[data.GamepassID] = gpName
		end
	end

	mps.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
		if not wasPurchased then
			network:FireClient(player, "HideGreyFrame")
			return
		end

		local gpName = gpIDToName[gamePassId]
		if not gpName then
			network:FireClient(player, "HideGreyFrame")
			return
		end

		local _, info = pcall(function()
			return mps:GetProductInfoAsync(gamePassId, Enum.InfoType.GamePass)
		end)

		LogHandler.LogPurchase(player, gpName, "Gamepass", info and info.PriceInRobux)

		local profile = playerData.GetData(player)
		profile.OwnedGamepasses[gpName] = true
		profile.IsFreeToPlay = false

		profile.TotalRobuxSpent += info.PriceInRobux

		dataSync.SyncPlayer(player, profile)

		if callbacks[gpName] then
			callbacks[gpName](player)
		end

		network:FireClient(player, "PurchaseConfirmed")
	end)
end

local function ProductPurchaseHandler()
	for productName, data in pairs(shopStats.DeveloperProducts) do
		if data.ProductID then
			productIDToName[data.ProductID] = productName
		end
	end
	for gamepass, data in pairs(shopStats.Gamepasses) do
		if data.GiftingID then
			productIDToName[data.GiftingID] = gamepass
		end
	end

	mps.PromptProductPurchaseFinished:Connect(function(userId, _, isPurchased)
		if not isPurchased then
			network:FireClient(players:GetPlayerByUserId(userId), "HideGreyFrame")
		end
	end)

	mps.ProcessReceipt = function(receiptInfo)
		local player = players:GetPlayerByUserId(receiptInfo.PlayerId)
		if not player then
			-- network:FireClient(player, 'HideGreyFrame');
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local productName = productIDToName[receiptInfo.ProductId]
		if not productName then
			network:FireClient(player, "HideGreyFrame")
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		local _, info = pcall(function()
			return mps:GetProductInfoAsync(receiptInfo.ProductId, Enum.InfoType.Product)
		end)
		LogHandler.LogPurchase(player, productName, "DeveloperProduct", info and info.PriceInRobux)
		local profile = playerData.GetData(player)
		profile.TotalRobuxSpent += info.PriceInRobux

		local productData = shopStats.DeveloperProducts[productName]
		if string.match(productName, "Pet") and not string.match(productName, "Storage") then
			local pets = {}
			if string.match(productName, "Combi") then
				table.insert(pets, shopStats.DeveloperProducts["Pet1"])
				table.insert(pets, shopStats.DeveloperProducts["Pet2"])
			else
				table.insert(pets, productData)
			end
			callbacks["Pet"](player, pets)
		elseif string.match(productName, "GemPack") then
			callbacks["Gem"](player, productData.BaseGems, (productData.AdditionalRewards or {}))
		elseif receiptInfo.ProductId == 3608435738 then
			callbacks["RestockShop"](player)
		else
			callbacks["Gift"](player, productName)
		end

		if receiptInfo.ProductId ~= 3608435738 then
			network:FireClient(player, "PurchaseConfirmed")
		end

		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
end

local function EnsureGamepassOwnership(player: Player)
	local profile = playerData.GetData(player)
	local ownedPasses = profile.OwnedGamepasses

	for gpName, data in pairs(shopStats.Gamepasses) do
		if ownedPasses[gpName] then
			continue
		end
		-- if mps:UserOwnsGamePassAsync(player.UserId, data.GamepassID) or player.UserId == 4528900607 then
		ownedPasses[gpName] = true
		if callbacks[gpName] then
			callbacks[gpName](player)
		end
		-- end
	end

	dataSync.SyncPlayer(player, profile)
end

function ShopHandler.UseGamepass(player: Player, id: string, gamepassName: string)
	local profile = playerData.GetData(player)
	local ownedGamepasses = profile.OwnedGamepasses
	local gifts = profile.Gifts

	if profile.TradeBanned then
		return
	end

	if profile.IsInTrade then
		return
	end

	if ownedGamepasses[gamepassName] then
		return
	end
	if not gifts[id] then
		return
	end
	if gifts[id] ~= gamepassName then
		return
	end

	ownedGamepasses[gamepassName] = true
	gifts[id] = nil
	profile.IsFreeToPlay = false

	if callbacks[gamepassName] then
		callbacks[gamepassName](player)
	end

	dataSync.SyncPlayer(player, profile)
end

function ShopHandler.Initialize()
	GamepassPurchaseHandler()
	ProductPurchaseHandler()

	for _, player: Player in ipairs(players:GetPlayers()) do
		EnsureGamepassOwnership(player)
	end

	players.PlayerAdded:Connect(function(player)
		EnsureGamepassOwnership(player)
	end)
end

return ShopHandler
