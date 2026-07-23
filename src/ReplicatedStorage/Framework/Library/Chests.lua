local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Network = require(ReplicatedStorage.Framework.Network)
local Chests = {
	["GroupChest"] = {
		RespawnTime = 10,
		Rolls = 3,
		ItemPool = {
			-- [Name] = {Type, Weight}
			["Lucky_I"] = { "Potions", 50 },
			["Fox"] = { "Pets", 50 },
		},
		ClaimCallback = function()
			if RunService:IsClient() then
				Network:FireServer("ClaimChest", "GroupChest")
			end
		end,
	},
	["VIPChest"] = {
		RespawnTime = 20,
		Rolls = 6,
		ItemPool = {
			["Rebirths_II"] = { "Potions", 50 },
			["Candy Stack"] = { "Pets", 50 },
		},
		ClaimCallback = function()
			if RunService:IsClient() then
				Network:FireServer("ClaimChest", "VIPChest")
			end
		end,
	},
}

return Chests
