return function(ItemPool)
	local chances = {}
	local totalWeight = 0
	for item, chance in pairs(ItemPool) do
		chances[item] = chance
		totalWeight += chance
	end

	local roll = math.random() * totalWeight
	local currentWeight = 0

	for item, chance in pairs(chances) do
		currentWeight += chance
		if roll <= currentWeight then
			local Item = item
			return Item
		end
	end
	return nil
end
