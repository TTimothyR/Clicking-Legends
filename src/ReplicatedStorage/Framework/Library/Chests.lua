local GroupService = game:GetService("GroupService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local ShopStats = require(script.Parent.ShopStats)
local DataSyncClient = require(StarterPlayer.StarterPlayerScripts.Modules.DataSyncClient)
local Globals = require(ReplicatedStorage.Framework.Globals)
local Network = require(ReplicatedStorage.Framework.Network)
local Chests = {
	["GroupChest"] = {
		RespawnTime = 3 * 3600,
		Rolls = 3,
		ItemPool = {
			-- [Name] = {Type, Weight}
			["Lucky_I"] = { "Potions", 50 },
			["Fox"] = { "Pets", 50 },
		},
		ClaimCallback = function(player: Player)
			if RunService:IsClient() then
				if not player:IsInGroupAsync(Globals.GroupID) then
					local s, result = pcall(function()
						return GroupService:PromptJoinAsync(Globals.GroupID)
					end)
					if s then
						if result == Enum.GroupMembershipStatus.Joined then
							Network:FireServer("ClaimChest", "GroupChest")
						end
					end
				else
					Network:FireServer("ClaimChest", "GroupChest")
				end
			end
		end,
	},
	["VIPChest"] = {
		RespawnTime = 2 * 3600,
		Rolls = 6,
		ItemPool = {
			["Rebirths_II"] = { "Potions", 50 },
			["Candy Stack"] = { "Pets", 50 },
		},
		ClaimCallback = function(player)
			if RunService:IsClient() then
				local ownedGamepasses = DataSyncClient.Get("OwnedGamepasses")
				if not ownedGamepasses["VIP"] then
					MarketplaceService:PromptGamePassPurchase(player, ShopStats.Gamepasses["VIP"].GamepassID)
					local ShopHandler = require(StarterPlayer.StarterPlayerScripts.Modules.ShopHandler)
					ShopHandler.ShowGreyFrame()
				else
					Network:FireServer("ClaimChest", "VIPChest")
				end
			end
		end,
	},
}

return Chests
