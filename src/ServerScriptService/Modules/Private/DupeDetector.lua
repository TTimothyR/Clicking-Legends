local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local LogHandler = require(script.Parent.LogHandler)
local PlayerData = require(ServerScriptService.DataModules.PlayerData)
local DupeDetector = {}

function DupeDetector.ScanServer()
	local allPets: { [string]: Player } = {}
	local dupedIds: { [string]: { Player } } = {}

	for _, player in ipairs(Players:GetPlayers()) do
		if player then
			local profile = PlayerData.GetData(player)

			if profile and profile.Pets then
				local pets = profile.Pets
				for _, petData in ipairs(pets) do
					local petId = petData.id
					if petId then
						if allPets[petId] then
							if not dupedIds[petId] then
								dupedIds[petId] = { allPets[petId] }
							end
							table.insert(dupedIds[petId], player)
						else
							allPets[petId] = player
						end
					end
				end
			end
		end
	end
	local function GetAllUserIds(playerTable)
		local ids = {}
		for _, player in ipairs(playerTable) do
			if player then
				table.insert(ids, player.UserId)
			end
		end
		return ids
	end
	for petId, playerTable in pairs(dupedIds) do
		local userIdsToBan = GetAllUserIds(playerTable)

		local s, err = pcall(function()
			Players:BanAsync({
				UserIds = userIdsToBan,
				Duration = -1,
				DisplayReason = "You have been permanently banned for duping.",
				PrivateReason = "Banned for duping.",
				ExcludeAltAccounts = false,
			})
		end)

		LogHandler.LogDupe(playerTable, { petId }, "ServerWide")

		if not s then
			warn("Failed to ban users:", tostring(err))
			for _, id in ipairs(userIdsToBan) do
				warn("Ban this person:", id)
			end
		end
	end
end

return DupeDetector
