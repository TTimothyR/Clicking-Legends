--!strict

local db = false

local SettingsHandler = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local framework = ReplicatedStorage:WaitForChild("Framework")
local library = framework:WaitForChild("Library")

local player = Players.LocalPlayer :: Player

local playerGui = player:WaitForChild("PlayerGui")
local frames = playerGui:WaitForChild("Frames")
local settingsFrame = frames:WaitForChild("Settings")
local main = settingsFrame:WaitForChild("Main") :: Frame
local list = main:WaitForChild("List") :: Frame
local settingsList = list:WaitForChild("ScrollingFrame") :: ScrollingFrame

local settingsConfig = require(library.SettingsConfig)
local dataSync = require(script.Parent.DataSyncClient)
local network = require(framework.Network)

local toggleMinimumXPosition = 0.2
local toggleMaximumXPosition = 0.8
local disabledColor = Color3.fromRGB(130, 154, 179)
local enabledColor = Color3.fromRGB(0, 255, 0)
local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

local sliderMinimumXPosition = 0.0
local sliderMaximumXPosition = 1.0

local toggleConnections = {}
local sliderConnections = {}

local function CreateSliderConnections(settingName, sliderFrame: Frame)
	if not sliderConnections[settingName] then
		local toggleButton = sliderFrame:FindFirstChild("Toggle") :: ImageButton
		local bar = sliderFrame:FindFirstChild("Bar") :: CanvasGroup
		sliderConnections[settingName] = {
			Connections = {},
			MouseDown = false,
		}

		local function _UpdateSliderBar(currentPosition: Vector3)
			local barAbsolutePosition = sliderFrame.AbsolutePosition
			local barAbsoluteSize = sliderFrame.AbsoluteSize

			local relativeX = (currentPosition.X - barAbsolutePosition.X) / barAbsoluteSize.X

			relativeX = math.clamp(relativeX, sliderMinimumXPosition, sliderMaximumXPosition)

			toggleButton.Position = UDim2.fromScale(relativeX, toggleButton.Position.Y.Scale)
			bar.Size = UDim2.fromScale(relativeX, bar.Size.Y.Scale)
		end

		table.insert(
			sliderConnections[settingName].Connections,
			toggleButton.MouseButton1Down:Connect(function(_: number, _: number)
				sliderConnections[settingName].MouseDown = true
			end) :: RBXScriptConnection
		)
		table.insert(
			sliderConnections[settingName].Connections,
			sliderFrame.InputBegan:Connect(function(input: InputObject)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					sliderConnections[settingName].MouseDown = true
					_UpdateSliderBar(input.Position)
				end
			end) :: RBXScriptConnection
		)
		table.insert(
			sliderConnections[settingName].Connections,
			UserInputService.InputEnded:Connect(function(input: InputObject, _: boolean)
				if not sliderConnections[settingName].MouseDown then
					return
				end

				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					sliderConnections[settingName].MouseDown = false

					local _ = network:InvokeServer("ApplySetting", settingName, toggleButton.Position.Y.Scale)
				end
			end) :: RBXScriptConnection
		)
		table.insert(
			sliderConnections[settingName].Connections,
			UserInputService.InputChanged:Connect(function(input: InputObject, _: boolean)
				if not sliderConnections[settingName].MouseDown then
					return
				end

				if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
					_UpdateSliderBar(input.Position)
				end
			end) :: RBXScriptConnection
		)
	end
end

local function CreateToggleClickConnection(settingName, toggleButton: ImageButton)
	if not toggleConnections[settingName] then
		toggleConnections[settingName] = toggleButton.MouseButton1Click:Connect(function()
			if not db then
				db = true
				task.delay(0.15, function()
					db = false
				end)

				local newValue = network:InvokeServer("ApplySetting", settingName, nil)

				local targetColor = nil
				local targetPosition = nil
				if newValue then
					targetColor = enabledColor
					targetPosition = toggleMaximumXPosition
				else
					targetColor = disabledColor
					targetPosition = toggleMinimumXPosition
				end

				local slideCircle = toggleButton:FindFirstChild("SlideCircle") :: Frame

				local colorTween = TweenService:Create(toggleButton, tweenInfo, { BackgroundColor3 = targetColor })
				local positionTween = TweenService:Create(
					slideCircle,
					tweenInfo,
					{ Position = UDim2.fromScale(targetPosition, slideCircle.Position.Y.Scale) }
				)

				colorTween:Play()
				positionTween:Play()
			end
		end) :: RBXScriptConnection
	end
end

function SettingsHandler.LoadSettings()
	local playerSettings = dataSync.Get("Settings")

	for settingName, config in pairs(settingsConfig) do
		local settingFrame = settingsList:FindFirstChild(settingName) :: Frame
		local currentValue = playerSettings[settingName]

		if config.Type == "Toggle" then
			local toggleButton = settingFrame:FindFirstChild("Toggle") :: ImageButton
			local slideCircle = toggleButton:FindFirstChild("SlideCircle") :: Frame

			if currentValue then
				slideCircle.Position = UDim2.fromScale(toggleMaximumXPosition, slideCircle.Position.Y.Scale)
				toggleButton.BackgroundColor3 = enabledColor
			else
				slideCircle.Position = UDim2.fromScale(toggleMinimumXPosition, slideCircle.Position.Y.Scale)
				toggleButton.BackgroundColor3 = disabledColor
			end

			CreateToggleClickConnection(settingName, toggleButton)
		elseif config.Type == "Slider" then
			local sliderFrame = settingFrame:FindFirstChild("Slider") :: Frame
			local toggleButton = sliderFrame:FindFirstChild("Toggle") :: ImageButton
			local bar = sliderFrame:FindFirstChild("Bar") :: CanvasGroup

			local togglePosition = (sliderMaximumXPosition - sliderMinimumXPosition) * currentValue

			toggleButton.Position = UDim2.fromScale(togglePosition, toggleButton.Position.Y.Scale)
			bar.Size = UDim2.fromScale(togglePosition, bar.Size.Y.Scale)

			CreateSliderConnections(settingName, sliderFrame)
		else
			warn("Unknown setting type, possibly a typo.")
		end
	end
end

return SettingsHandler
