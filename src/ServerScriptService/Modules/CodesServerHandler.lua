local CodesHandler = {}

-- Services
local rs = game:GetService("ReplicatedStorage")

-- Variables
local framework = rs:WaitForChild("Framework")
local library = framework:WaitForChild("Library")

-- Modules
local codeStats = require(library.Codes)
local playerData = require(script.Parent.Parent.DataModules.PlayerData)
local network = require(framework.Network)

function CodesHandler.RedeemCode(player: Player, entry: string)
	if not codeStats[entry] then
		network:FireClient(player, "CodeInfo", "Invalid Code!")
		return
	end

	if os.time() > codeStats[entry].ExpireDate then
		network:FireClient(player, "CodeInfo", "Code expired!")
		return
	end

	local profile = playerData.GetData(player)
	local redeemedCodes = profile.RedeemedCodes

	if redeemedCodes[entry] then
		network:FireClient(player, "CodeInfo", "Code already redeemed!")
		return
	end

	redeemedCodes[entry] = true
	-- Implement reward stuff here

	network:FireClient(player, "CodeInfo", "Code Redeemed!")
end

return CodesHandler
