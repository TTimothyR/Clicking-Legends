local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
local tutorialUI = playerGui:WaitForChild("Tutorial") :: ScreenGui
local tutorialFrame = tutorialUI:WaitForChild("Frame") :: Frame

local Globals = require(ReplicatedStorage.Framework.Globals)
local TutorialSteps = require(ReplicatedStorage.Framework.Library.TutorialSteps)
local DataSyncClient = require(script.Parent.DataSyncClient)
local TutorialHandler = {}

local function UpdateTutorial(tutorialFinished, tutorialProgress)
	if tutorialFinished == nil then
		tutorialFinished = DataSyncClient.Get("TutorialFinished")
	end
	if tutorialFinished then
		tutorialUI.Enabled = false
		return
	end

	if tutorialProgress == nil then
		tutorialProgress = DataSyncClient.Get("TutorialProgress")
	end

	tutorialFrame.Step.Text = "Step " .. tutorialProgress.Step .. "/" .. #TutorialSteps
	tutorialFrame.Quest.Text = TutorialSteps[tutorialProgress.Step].Text
		.. " ("
		.. Globals.FormatCount(tutorialProgress.Progress)
		.. "/"
		.. TutorialSteps[tutorialProgress.Step].Goal
		.. ")"
	tutorialFrame.Info.Text = TutorialSteps[tutorialProgress.Step].Info or ""
	tutorialFrame.Info.Visible = TutorialSteps[tutorialProgress.Step].Info and true or false

	tutorialUI.Enabled = true
end

function TutorialHandler.Initialize()
	DataSyncClient.OnReady(function()
		UpdateTutorial(nil, nil)
	end)
	DataSyncClient.OnChanged("TutorialFinished", function(new, _)
		UpdateTutorial(new)
	end)
	DataSyncClient.OnChanged("TutorialProgress", function(new, _)
		UpdateTutorial(nil, new)
	end)
end

return TutorialHandler
