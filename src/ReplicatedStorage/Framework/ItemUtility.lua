local Items = require("./Library/Items")

local module = {}

function module.GetBuffPercentage(buff, tier)
	for _, data in ipairs(Items.Potions[tier].Buffs) do
		if data[1] == buff then
			return data[2]
		end
	end

	return 0
end

function module.GetItemData(ItemType, tier)
	if not Items[ItemType] then
		return
	end
	if not Items[ItemType][tier] then
		return
	end

	return Items[ItemType][tier]
end

function module.GetItemRarity(ItemType, tier)
	local ItemData = module.GetItemData(ItemType, tier)
	return (ItemType == "Potions" and ItemData.Rarity or "Common")
end

function module.GetItemType(ItemName)
	if Items.Potions[ItemName] then
		return "Potions"
	end
	return nil
end

function module.GetItemDuration(ItemName, tier)
	local ItemType = module.GetItemType(tier)
	local Lookup = (ItemType == "Potions" and ItemType)
	if not tier and ItemType ~= "Potions" then
		tier = ItemName
	end

	return string.format("%s minutes", Items[Lookup][tier].Duration / 60)
end

return module
