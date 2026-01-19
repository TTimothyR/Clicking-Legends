local generateID = {}

function generateID.NewID()
	local characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	local id = ""
	for i = 1, 10 do
		local randomIndex = math.random(1, #characters)
		id = id .. characters:sub(randomIndex, randomIndex)
	end
	return id
end

return generateID