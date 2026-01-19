local TableUtility = {}

function TableUtility.FindIndexWithId(pets, id)
	for index, petData in ipairs(pets) do
		if petData.id == id then
			return index, petData
		end
	end
	return nil, nil
end

return TableUtility