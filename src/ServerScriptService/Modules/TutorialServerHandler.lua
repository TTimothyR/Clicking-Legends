local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataSyncServer = require(ServerScriptService.DataModules.DataSyncServer).Private
local TutorialSteps = require(ReplicatedStorage.Framework.Library.TutorialSteps)
local PlayerData = require(ServerScriptService.DataModules.PlayerData)
local TutorialHandler = {}

function TutorialHandler.Advance(player, stepId, amount)
	local profile = PlayerData.GetData(player)
	if not profile then
		return
	end

	local currentStep = profile.TutorialProgress.Step
	if not TutorialSteps[currentStep] or TutorialSteps[currentStep].ID ~= stepId then
		return
	end

	if string.find(TutorialSteps[currentStep].ID, "Clicks") then
		profile.TutorialProgress.Progress = profile.Clicks:Reverse() + amount
	else
		profile.TutorialProgress.Progress += amount or 1
	end
	if profile.TutorialProgress.Progress >= TutorialSteps[currentStep].Goal then
		profile.TutorialProgress.Step += 1
		if TutorialSteps[currentStep + 1] then
			if string.find(TutorialSteps[currentStep + 1].ID, "Clicks") then
				profile.TutorialProgress.Progress = profile.Clicks:Reverse()
			else
				profile.TutorialProgress.Progress = 0
			end
		end
	end

	if profile.TutorialProgress.Step > #TutorialSteps then
		profile.TutorialFinished = true
	end

	DataSyncServer.SyncPlayer(player, profile)
end

return TutorialHandler
