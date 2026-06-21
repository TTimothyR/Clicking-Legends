local TableUtility = {}

function TableUtility.FindIndexWithId(pets, id)
	for index, petData in ipairs(pets) do
		if petData.id == id then
			return index, petData
		end
	end
	return nil, nil
end

function TableUtility.FindEgg(eggStats, petName)
	for egg, data in pairs(eggStats) do
		for pet, _ in pairs(data.Pets) do
			if pet == petName then
				return egg
			end
		end
	end
	return nil
end

return TableUtility
