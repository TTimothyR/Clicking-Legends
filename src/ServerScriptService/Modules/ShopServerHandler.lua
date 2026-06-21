local ShopHandler = {}

-- Services
local players = game:GetService("Players")
local mps = game:GetService("MarketplaceService")
local rs = game:GetService("ReplicatedStorage")

-- Variables
local framework = rs:WaitForChild("Framework")
local library = framework:WaitForChild("Library")

-- Modules
local shopStats = require(library.ShopStats)
local network = require(framework.Network)
local infMath = require(framework.InfiniteMath)
local playerData = require(script.Parent.Parent.DataModules.PlayerData)
local dataSync = require(script.Parent.Parent.DataModules.DataSyncServer)
local rewardHandler = require(script.Parent.Private.RewardHandler)

-- Constants
local gpIDToName = {}
local productIDToName = {}
local callbacks = {
	["+100 Pet Storage"] = function(player: Player)
		local profile = playerData.GetData(player)
		profile.PetStorage += 100

		dataSync.SyncPlayer(player, profile)
	end,
	["+500 Pet Storage"] = function(player: Player)
		local profile = playerData.GetData(player)
		profile.PetStorage += 500

		dataSync.SyncPlayer(player, profile)
	end,
	["+3 Pet Equips"] = function(player: Player)
		local profile = playerData.GetData(player)
		profile.PetEquips += 3

		dataSync.SyncPlayer(player, profile)
	end,
	["+2 Eggs"] = function(player: Player)
		local profile = playerData.GetData(player)
		profile.EggHatches += 2

		dataSync.SyncPlayer(player, profile)
	end,

	["Pet"] = function(player: Player, petNames)
		for _, petName in pairs(petNames) do
			local _ = rewardHandler.ClaimPet(player, petName, false)
		end

		local profile = playerData.GetData(player)
		dataSync.SyncPlayer(player, profile)
	end,
	["Gem"] = function(player: Player, baseGems: number)
		local profile = playerData.GetData(player)
		local toAdd = infMath.new(profile.Rebirths * baseGems)
		profile.Gems = infMath.new(profile.Gems + toAdd)
		local leaderstats = player:FindFirstChild("leaderstats") :: Folder
		leaderstats.Gems.Value = profile.Gems:GetSuffix(true)

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

		local profile = playerData.GetData(player)
		profile.OwnedGamepasses[gpName] = true

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

		if string.match(productName, "Pet") then
			local petNames = {}
			if string.match(productName, "Combi") then
				table.insert(petNames, shopStats.DeveloperProducts["Pet1"].PetName)
				table.insert(petNames, shopStats.DeveloperProducts["Pet2"].PetName)
			else
				table.insert(petNames, shopStats.DeveloperProducts[productName].PetName)
			end
			callbacks["Pet"](player, petNames)
		elseif string.match(productName, "GemPack") then
			callbacks["Gem"](player, shopStats.DeveloperProducts[productName].BaseGems)
		end

		network:FireClient(player, "PurchaseConfirmed")

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
		if mps:UserOwnsGamePassAsync(player.UserId, data.GamepassID) then
			ownedPasses[gpName] = true
		end
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
