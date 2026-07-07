local StarterPlayer = game:GetService("StarterPlayer")

local StarterPlayerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")

local Modules = StarterPlayerScripts:WaitForChild("Modules")

local DataSyncClient = require(Modules:WaitForChild("DataSyncClient"))

local PetUtility = {}

function PetUtility.GetPetData(id: string)
	local pets = DataSyncClient.Get("Pets")

	for _, data in ipairs(pets) do
		if data.id == id then
			return data
		end
	end
	return nil
end

return PetUtility
