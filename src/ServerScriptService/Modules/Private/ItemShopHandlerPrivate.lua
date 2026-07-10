local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Framework = ReplicatedStorage:WaitForChild("Framework")

local Library = Framework:WaitForChild("Library")
local Shared = Framework:WaitForChild("Shared")

local ItemShopModule = require(Library:WaitForChild("ItemShopModule"))
local GetRandomItem = require(Shared:WaitForChild("GetRandomItem"))

local DataModules = ServerScriptService.DataModules
local PlayerData = require(DataModules.PlayerData)

local DataSyncServer = require(DataModules.DataSyncServer).Private

local ItemShopHandlerPrivate = {}

function ItemShopHandlerPrivate.ChooseShopItems(ShopName: string)
	local _Info = ItemShopModule.GetShopInfo(ShopName)
	if not _Info then
		return
	end

	local ItemPool = _Info.ItemPool
	local ModifiedPool = {}
	for i, v in pairs(ItemPool) do
		ModifiedPool[i] = v[2]
	end

	local ItemTbl = {}
	for _ = 1, 3 do
		local Item = GetRandomItem(ModifiedPool)
		if ItemTbl[Item] then
			repeat
				task.wait()
				Item = GetRandomItem(ModifiedPool)
			until not ItemTbl[Item]
		end
		ItemTbl[Item] = math.random(1, 5)
	end

	return ItemTbl
end

function ItemShopHandlerPrivate.RestockShop(plr: Player, ShopName: string, IsForced: boolean)
	local Profile = PlayerData.GetData(plr)
	if not Profile then
		return
	end

	local ItemShops = Profile.ItemShops
	local _ShopData = ItemShops[ShopName]
	if not _ShopData then
		return
	end

	local _Info = ItemShopModule.GetShopInfo(ShopName)
	if not _Info then
		return
	end

	if not IsForced then
		local DailyRerolls = Profile.DailyShopRerolls
		if DailyRerolls < 1 then
			return
		end

		Profile.DailyShopRerolls -= 1
	end

	local NewItems = ItemShopHandlerPrivate.ChooseShopItems(ShopName)

	_ShopData.Items = NewItems
	_ShopData.NextRestock = (os.time() + _Info.RestockTime)
	DataSyncServer.SyncPlayer(plr, Profile)
end

return ItemShopHandlerPrivate
