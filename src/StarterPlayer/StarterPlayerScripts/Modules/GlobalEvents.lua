local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Framework = ReplicatedStorage:WaitForChild("Framework")

local Library = Framework:WaitForChild("Library")

local GlobalEvents = {}

local Player = Players.LocalPlayer
local PlayerGui = Player.PlayerGui
local HUD = PlayerGui:WaitForChild("HUD")
local Boost = HUD:WaitForChild("Boost")

local Worlds = require(ReplicatedStorage.Framework.Library.Worlds)
local DataSyncClient = require(script.Parent.DataSyncClient)
local GlobalEventsModule = require(Library:WaitForChild("GlobalEventsModule"))
local Globals = require(Framework:WaitForChild("Globals"))

local shouldHideEvents = false

function GlobalEvents.Initialize()
	DataSyncClient.OnReady(function()
		shouldHideEvents = DataSyncClient.Get("Settings").HideEvents
		Boost.Title.Text = string.format("🌍 World Boost: x%s 🌍", Worlds[DataSyncClient.Get("CurrentWorld")].Boost)
	end)
	DataSyncClient.OnChanged("Settings", function(new, _)
		shouldHideEvents = new.HideEvents
	end)
	DataSyncClient.OnChanged("CurrentWorld", function(new, _)
		Boost.Title.Text = string.format("🌍 World Boost: x%s 🌍", Worlds[new].Boost)
	end)

	task.spawn(function()
		while true do
			for i, _ in pairs(GlobalEventsModule.Events) do
				local attribute = workspace:GetAttribute(i)
				local EventFrame = Boost:FindFirstChild(i)
				if not attribute or not EventFrame then
					continue
				end

				if attribute > os.time() and not shouldHideEvents then
					EventFrame.Visible = true
					EventFrame.Timer.Text = `({Globals.FormatTime(attribute - os.time(), false)})`
				else
					EventFrame.Visible = false
				end
			end
			task.wait(1)
		end
	end)
end

return GlobalEvents
