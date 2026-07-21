local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataSyncServer = require(ServerScriptService.DataModules.DataSyncServer).Private
local InfiniteMath = require(ReplicatedStorage.Framework.InfiniteMath)
local PlayerData = require(ServerScriptService.DataModules.PlayerData)
local Worlds = require(ReplicatedStorage.Framework.Library.Worlds)

local teleportPads = workspace:WaitForChild("TeleportPads")

local WorldHandler = {}

function WorldHandler.BuyWorld(player: Player, worldName: string)
	if not Worlds[worldName] then
		return false
	end

	local profile = PlayerData.GetData(player)
	if profile.OwnedWorlds[worldName] then
		return false
	end

	if profile.Clicks < InfiniteMath.new(Worlds[worldName].Requirement) then
		return false
	end
	local leaderstats = player:FindFirstChild("leaderstats") :: Folder
	profile.Clicks -= InfiniteMath.new(Worlds[worldName].Requirement)

	leaderstats.Clicks.Value = profile.Clicks:GetSuffix(true)

	profile.OwnedWorlds[worldName] = true

	DataSyncServer.SyncPlayer(player, profile)

	return true
end

function WorldHandler.Teleport(player: Player, worldName)
	if not Worlds[worldName] then
		return
	end

	local profile = PlayerData.GetData(player)
	if not profile.OwnedWorlds[worldName] then
		return
	end

	if not teleportPads:FindFirstChild(worldName) then
		warn("Teleport pad not found")
		return
	end

	if not player.Character then
		return
	end

	profile.CurrentWorld = worldName

	-- Blackout UI
	player.Character:MoveTo(teleportPads[worldName].Position)
	-- Fade Blackout UI

	DataSyncServer.SyncPlayer(player, profile)
end

return WorldHandler
