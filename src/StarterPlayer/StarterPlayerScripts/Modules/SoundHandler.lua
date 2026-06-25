local SoundHandler = {}

-- Services
local soundService = game:GetService("SoundService")

-- Variables
local playingSounds: Folder = soundService:WaitForChild("PlayingSounds")

function SoundHandler.PlaySound(sound: Sound)
	task.spawn(function()
		local clone = sound:Clone()
		clone.Parent = playingSounds

		clone:Play()
		clone.Ended:Wait()
		clone:Destroy()
	end)
end

return SoundHandler
