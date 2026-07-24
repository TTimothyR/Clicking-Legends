local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Framework = ReplicatedStorage:WaitForChild("Framework")

local Library = Framework:WaitForChild("Library")

local ItemShopModule = require(Library:WaitForChild("ItemShopModule"))
local Network = require(Framework:WaitForChild("Network"))

local ItemShopHandlerPrivate = require("./Private/ItemShopHandlerPrivate")
local DataSyncServer = require("../DataModules/DataSyncServer").Private
local PlayerData = require("../DataModules/PlayerData")

local ItemShopHandler = {}

local function ValidateDistance(player: Player, part)
	local maxDistance = 15

	local character = player.Character
	local distance = (character.HumanoidRootPart.Position - part.Position).Magnitude
	return distance <= maxDistance
end

function ItemShopHandler.BuyShopItem(plr: Player, ShopName: string, Item: string)
	if type(ShopName) ~= "string" and type(Item) ~= "string" then
		return
	end

	if not workspace.Activations.UIActivators[ShopName] then
		return
	end

	if not ValidateDistance(plr, workspace.Activations.UIActivators[ShopName].Trigger) then
		return
	end

	local profile = PlayerData.GetData(plr)
	if not profile then
		return
	end

	local _Info = ItemShopModule.GetShopInfo(ShopName)
	if not _Info then
		return
	end

	local _ItemData = ItemShopModule.GetDropData(ShopName, Item)
	if not _ItemData then
		return
	end

	local Type, _, Price, Amount = _ItemData[1], _ItemData[2], _ItemData[3], _ItemData[4]

	local Currency = profile[_Info.Currency]

	if Currency >= Price and profile.ItemShops[ShopName].Items[Item] > 0 then
		profile[_Info.Currency] = profile[_Info.Currency] - Price

		if profile.Items[Type][Item] then
			profile.Items[Type][Item] += Amount
		else
			profile.Items[Type][Item] = Amount
		end

		profile.ItemShops[ShopName].Items[Item] -= 1
		DataSyncServer.SyncPlayer(plr, profile)

		if Type == "Potions" then
			Network:FireClient(plr, "NewItem", {
				itemName = Item,
				amount = 1,
				type = "Potions",
			})
		end
	end
end

function ItemShopHandler.UseDailyRestock(plr: Player)
	local Profile = PlayerData.GetData(plr)
	if not Profile then
		return
	end

	local CurrentShop = Profile.CurrentItemShop
	if not CurrentShop then
		return
	end
	if not ItemShopModule.Shops[CurrentShop] then
		return
	end

	local DailyRestocks = Profile.DailyShopRerolls

	if DailyRestocks >= 1 then
		ItemShopHandlerPrivate.RestockShop(plr, CurrentShop, false)
		DataSyncServer.SyncPlayer(plr, Profile)
	end
	return true
end

function ItemShopHandler.SetCurrentShop(plr, ShopName: string)
	if not ItemShopModule.Shops[ShopName] then
		return
	end

	local Profile = PlayerData.GetData(plr)
	if not Profile then
		return
	end

	Profile.CurrentItemShop = ShopName

	DataSyncServer.SyncPlayer(plr, Profile)
end

function ItemShopHandler.Initialize()
	local function OnPlayerAdded(player)
		local profile = PlayerData.GetData(player)
		if not profile then
			return
		end

		local ItemShopsData = profile.ItemShops

		for i, _ in pairs(ItemShopModule.Shops) do
			if not ItemShopsData[i] then
				ItemShopsData[i] = {
					NextRestock = os.time(),
					Items = ItemShopHandlerPrivate.ChooseShopItems(i),
				}
			end
		end
	end
	for _, player in pairs(Players:GetPlayers()) do
		OnPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(function(plr: Player)
		OnPlayerAdded(plr)
	end)

	task.spawn(function()
		while task.wait(1) do
			for _, Player in pairs(Players:GetPlayers()) do
				local Profile = PlayerData.GetData(Player)
				if not Profile then
					continue
				end

				for i, _ in pairs(ItemShopModule.Shops) do
					local ItemShops = Profile.ItemShops
					if not ItemShops[i] then
						continue
					end

					if ItemShops[i].NextRestock <= os.time() then
						ItemShopHandlerPrivate.RestockShop(Player, i, true)
					end
				end

				if Profile.NextDailyReroll <= os.time() then
					Profile.DailyShopRerolls = 3
					Profile.NextDailyReroll = os.time() + 86400
					DataSyncServer.SyncPlayer(Player, Profile)
				end
			end
		end
	end)
end

return ItemShopHandler
