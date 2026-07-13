local SoundHandler = {}

-- Services
local soundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Variables
local playingSounds = soundService:WaitForChild("PlayingSounds")
local playingMusic = soundService:WaitForChild("PlayingMusic")

local assets = ReplicatedStorage:WaitForChild("Assets") :: Folder
local sounds = assets:WaitForChild("Sounds") :: Folder
local templateMusicObj = sounds:WaitForChild("Music") :: Sound

local musicVolume, soundEffectVolume = 1 :: number, 1 :: number

local DataSyncClient = require(script.Parent.DataSyncClient)

local function StartMusic()
	local playerSettings = DataSyncClient.Get("Settings")
	musicVolume = playerSettings.Music
	soundEffectVolume = playerSettings.SFX

	local musicClone = templateMusicObj:Clone() :: Sound

	musicClone.Parent = playingMusic
	musicClone.Volume = templateMusicObj.Volume * musicVolume
	musicClone:Play()
end

function SoundHandler.PlaySound(sound: Sound)
	task.spawn(function()
		local clone = sound:Clone()
		clone.Volume = sound.Volume * soundEffectVolume
		clone.Parent = playingSounds

		clone:Play()
		clone.Ended:Wait()
		clone:Destroy()
	end)
end

function SoundHandler.Initialize()
	if not game.Loaded then
		game.Loaded:Wait()
	end

	DataSyncClient.OnReady(function()
		StartMusic()
	end)

	DataSyncClient.OnChanged("Settings", function(new, _)
		musicVolume, soundEffectVolume = new.Music, new.SFX

		if playingMusic:FindFirstChildOfClass("Sound") then
			playingMusic:FindFirstChildOfClass("Sound").Volume = templateMusicObj.Volume * musicVolume
		end
	end)
end

return SoundHandler
