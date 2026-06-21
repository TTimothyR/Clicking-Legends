local CodesHandler = {}
local db = false

-- Services
local players = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")

-- Variables
repeat
	task.wait()
until players.LocalPlayer
local player: Player = players.LocalPlayer

local framework = rs:WaitForChild("Framework")

local currentInput = ""

-- UI
local playerGui = player:WaitForChild("PlayerGui")
local frames: ScreenGui = playerGui:WaitForChild("Frames")
local shopFrame = frames:WaitForChild("Shop")
local main = shopFrame:WaitForChild("Main")
local everythingHolder = main:WaitForChild("Holder")
local holder = everythingHolder:WaitForChild("ScrollingHolder")
local codesFrame = holder:WaitForChild("Codes")
local innerCodes = codesFrame:WaitForChild("Inner")
local redeemButton = innerCodes:WaitForChild("Redeem")
local inputFrame = innerCodes:WaitForChild("Input")
local textBox = inputFrame:WaitForChild("TextBox")

-- Modules
local dataSync = require(script.Parent.DataSyncClient)
local network = require(framework.Network)

local function ConnectInput()
	textBox.Focused:Connect(function()
		textBox.Text = ""
		currentInput = textBox.Text
	end)
	textBox:GetPropertyChangedSignal("Text"):Connect(function()
		currentInput = textBox.Text
	end)
	redeemButton.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)
			network:FireServer("RedeemCode", currentInput)
			currentInput = ""
		end
	end)
end

function CodesHandler.CodeInfo(text)
	textBox.Text = text
	task.delay(3, function()
		textBox.Text = ""
	end)
end

function CodesHandler.Initialize()
	dataSync.OnReady(ConnectInput)
end
return CodesHandler
