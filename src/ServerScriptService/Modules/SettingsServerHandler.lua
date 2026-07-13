--!strict

local SettingsHandler = {}

local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local dataModules = ServerScriptService:WaitForChild("DataModules")
local framework = ReplicatedStorage:WaitForChild("Framework")
local library = framework:WaitForChild("Library")

local dataSync = require(dataModules.DataSyncServer).Private
local playerData = require(dataModules.PlayerData)
local settingsConfig = require(library.SettingsConfig)

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

function SettingsHandler.ApplySetting(player: Player, settingName, value: boolean | number)
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

	if type(value) == "number" then
		value = math.clamp(value, settingsConfig[settingName].MinimumValue, settingsConfig[settingName].MaximumValue)
	end

	profile.Settings[settingName] = value

	dataSync.SyncPlayer(player, profile)
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
