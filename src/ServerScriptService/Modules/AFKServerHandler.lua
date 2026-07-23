local AFKHandler = {}

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")

local dataModules = ServerScriptService:WaitForChild("DataModules")
local teleportPads = workspace:WaitForChild("TeleportPads")

local playerData = require(dataModules.PlayerData)

local function SetPlayerPosition(player: Player)
	local profile = playerData.GetData(player)
	print(profile.SavedPlayerPosition, profile.CurrentWorld)
	if profile.SavedPlayerPosition == nil then
		if profile.CurrentWorld ~= "Spawn" then
			local character = player.Character or player.CharacterAdded:Wait()
			if character and character.Parent then
				character:MoveTo(teleportPads[profile.CurrentWorld].Position)
			end
		end
		return
	end

	local pos = profile.SavedPlayerPosition
	local character = player.Character or player.CharacterAdded:Wait()
	if character and character.Parent then
		character:PivotTo(CFrame.new(Vector3.new(pos[1], pos[2], pos[3])))
		-- else
		-- 	player.CharacterAdded:Once(function(char: Model)
		-- 		char:PivotTo(CFrame.new(Vector3.new(pos[1], pos[2], pos[3])))
		-- 	end)
	end
end

function AFKHandler.ResetAFKReport(player: Player)
	local profile = playerData.GetData(player)

	profile.AFKStartTime = 0
	profile.PreAFKInfo = {}
	profile.SavedPlayerPosition = nil
end

function AFKHandler.StartAFK(player: Player)
	local profile = playerData.GetData(player)
	local startTime = tick()

	if profile.AFKStartTime ~= 0 then
		return
	end

	profile.AFKStartTime = startTime
	profile.PreAFKInfo["Rebirths"] = profile.Rebirths
	profile.PreAFKInfo["Eggs"] = profile.Eggs

	profile.PreAFKInfo["Pets"] = {}

	local character = player.Character
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")

	if humanoidRootPart then
		local rootPosition = humanoidRootPart.Position
		profile.SavedPlayerPosition = { rootPosition.X, rootPosition.Y, rootPosition.Z }
	end
end

function AFKHandler.StopAFK(player: Player)
	local profile = playerData.GetData(player)

	if profile.AFKStartTime == 0 then
		return nil
	end

	local startTime = profile.AFKStartTime
	local endTime = tick()

	local startRebirths = profile.PreAFKInfo["Rebirths"]
	local endRebirths = profile.Rebirths
	local startEggs = profile.PreAFKInfo["Eggs"]
	local endEggs = profile.Eggs

	local petsGotten = {}

	if profile.PreAFKInfo["Pets"] ~= nil then
		petsGotten = table.clone(profile.PreAFKInfo["Pets"])
	end

	AFKHandler.ResetAFKReport(player)

	if not startRebirths then
		return {
			deltaTime = (endTime - startTime) or 0,
			deltaEggs = (endEggs - startEggs) or 0,
			petsHatched = petsGotten,
		}
	end

	return {
		deltaTime = (endTime - startTime) or 0,
		deltaRebirths = (endRebirths - startRebirths) or 0,
		deltaEggs = (endEggs - startEggs) or 0,
		petsHatched = petsGotten,
	}
end

function AFKHandler.TPPlayer(player: Player, afk: boolean)
	local tpParameters = Instance.new("TeleportOptions")
	tpParameters:SetTeleportData({ isAFK = afk })

	local success, error = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { player }, tpParameters)
	end)

	if not success then
		warn(error)
	end
end

function AFKHandler.Initialize()
	for _, player in ipairs(Players:GetPlayers()) do
		SetPlayerPosition(player)
	end
	Players.PlayerAdded:Connect(function(player: Player)
		SetPlayerPosition(player)
	end)
end

return AFKHandler
