local SettingsHandler = {}

local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local dataModules = ServerScriptService:WaitForChild("DataModules")
local framework = ReplicatedStorage:WaitForChild("Framework")
local library = framework:WaitForChild("Library")

local dataSync = require(dataModules.DataSyncServer)
local playerData = require(dataModules.PlayerData)
local settingsConfig = require(library.SettingsConfig)

local applyFunctions = {
	["SFX"] = function(value)
		-- Do something to change the volume (idk if it should be here but i think so?)
	end,

	["Music"] = function(value)
		-- Do something to change the volume (idk if it should be here but i think so?)
	end,
}

local function SetupPlayerSettings(player: Player)
	local profile = playerData.GetData(player)
	local playerSettings = profile.Settings

	if next(playerSettings) == nil then
		for settingName, config in pairs(settingsConfig) do
			profile.Settings[settingName] = config.DefaultValue
		end
	end

	dataSync.SyncPlayer(player, profile)
end

function SettingsHandler.ApplySetting(player: Player, settingName, value)
	if not settingsConfig[settingName] then
		return
	end

	local profile = playerData.GetData(player)
	local playerSettings = profile.Settings

	if playerSettings[settingName] == nil then
		playerSettings[settingName] = settingsConfig[settingName].DefaultValue
	end

	if value == nil then
		value = not playerSettings[settingName]
	end

	profile.Settings[settingName] = value

	dataSync.SyncPlayer(player, profile)

	if applyFunctions[settingName] then
		applyFunctions[settingName](value)
	end

	return playerSettings[settingName]
end

function SettingsHandler.Initialize()
	for _, player: Player in ipairs(Players:GetPlayers()) do
		SetupPlayerSettings(player)
	end
	Players.PlayerAdded:Connect(function(player: Player)
		SetupPlayerSettings(player)
	end)
end

return SettingsHandler
