local ItemShopModule = {
	Shops = {},
}

for _, v in pairs(script:GetChildren()) do
	if v:IsA("ModuleScript") then
		local module = require(v)
		ItemShopModule.Shops[v.Name] = module
	end
end

function ItemShopModule.GetShopInfo(ShopName: string)
	if not ItemShopModule.Shops[ShopName] then
		return
	end
	return ItemShopModule.Shops[ShopName]
end

function ItemShopModule.GetDropData(ShopName, ItemName)
	local ShopData = ItemShopModule.GetShopInfo(ShopName)
	if not ShopData then
		return
	end
	if not ShopData.ItemPool[ItemName] then
		return
	end
	return ShopData.ItemPool[ItemName]
end

return ItemShopModule
