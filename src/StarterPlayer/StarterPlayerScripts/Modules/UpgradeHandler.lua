local UpgradeHandler = {}
local db = false

-- Services
local rs = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")

local Assets = rs:WaitForChild("Assets")

local Sounds = Assets:WaitForChild("Sounds")

local Framework = rs:WaitForChild("Framework")

local InterfaceUtility = require(Framework:WaitForChild("InterfaceUtility"))

local SoundHandler = require("./SoundHandler")

-- Variables
repeat
	task.wait()
until players.LocalPlayer
local player: Player = players.LocalPlayer

local framework = rs:WaitForChild("Framework")
local library = framework:WaitForChild("Library")

local buttonConnections = {}

-- UI
local playerGui = player:WaitForChild("PlayerGui")
local frames = playerGui:WaitForChild("Frames")
local upgradeFrame = frames:WaitForChild("Upgrades")
local templates = upgradeFrame:WaitForChild("Templates")
local upgradeTemplate = templates:WaitForChild("UpgradeTemplate")
local main = upgradeFrame:WaitForChild("Main")
local list = main:WaitForChild("List")
local holder = list:WaitForChild("ScrollingFrame")

-- Modules
local dataSync = require(script.Parent.DataSyncClient)
local upgrades = require(library.Upgrades)
local imageService = require(library.ImageService)
local infMath = require(framework.InfiniteMath)
local globals = require(framework.Globals)
local network = require(framework.Network)

local function UpdatePurchaseButton(color: string, button)
	button.Frame.UIGradient.Color = globals.ButtonPresets[color].Gradient
	button.Frame.UIStroke.Color = globals.ButtonPresets[color].StrokeColor
	button.Title.UIStroke.Color = globals.ButtonPresets[color].StrokeColor
end

local function LoadUpgrades()
	local gems = dataSync.Get("Gems")
	local upgradeLevels = dataSync.Get("UpgradeLevels")

	for upgradeName, data in pairs(upgrades) do
		if not holder:FindFirstChild(upgradeName) then
			local clone = upgradeTemplate:Clone()
			clone.Name = upgradeName
			clone.LayoutOrder = data.Order
			clone.Parent = holder

			local level = upgradeLevels[upgradeName] or 0

			local cost = infMath.new(data.BasePrice * math.pow(globals.UpgradeMultiplier, level))

			local inner = clone.Inner
			inner.UpgradeName.Text = upgradeName .. "! (" .. level .. "/" .. data.Maximum .. ")"
			inner.Amount.Text = cost:GetSuffix(true)
			inner.Desc.Text = string.format(data.Description, data.Increment)
			inner.IconHolder.ImageLabel.Image = imageService[upgradeName]

			if level == data.Maximum then
				UpdatePurchaseButton("Gray", inner.Purchase)
			elseif gems >= cost then
				UpdatePurchaseButton("Green", inner.Purchase)
			else
				UpdatePurchaseButton("Red", inner.Purchase)
			end

			if level ~= data.Maximum then
				buttonConnections[upgradeName] = inner.Purchase.MouseButton1Click:Connect(function()
					if not db then
						db = true
						task.delay(0.15, function()
							db = false
						end)
						local invoked = network:InvokeServer("BuyUpgrade", upgradeName)
						if invoked then
							InterfaceUtility.PlayWhiteOutAnim(upgradeFrame.Template, upgradeFrame.AnimationFrames, 0.25, 1.25)
							InterfaceUtility.PlayFOV(100, true, 90)
							SoundHandler.PlaySound(Sounds.Upgrade)
						end
					end
				end)
			end

			clone.Visible = true
		end
	end
end

local function UpdateUpgradeFrames()
	local gems = dataSync.Get("Gems")
	local upgradeLevels = dataSync.Get("UpgradeLevels")

	for upgradeName, data in pairs(upgrades) do
		if not holder:FindFirstChild(upgradeName) then
			continue
		end
		local clone = holder:FindFirstChild(upgradeName)

		local level = upgradeLevels[upgradeName] or 0

		local cost = infMath.new(data.BasePrice * math.pow(globals.UpgradeMultiplier, level))

		local inner = clone.Inner
		inner.UpgradeName.Text = upgradeName .. "! (" .. level .. "/" .. data.Maximum .. ")"
		inner.Amount.Text = cost:GetSuffix(true)

		if level == data.Maximum then
			UpdatePurchaseButton("Gray", inner.Purchase)
		elseif gems >= cost then
			UpdatePurchaseButton("Green", inner.Purchase)
		else
			UpdatePurchaseButton("Red", inner.Purchase)
		end

		if level == data.Maximum then
			if buttonConnections[upgradeName] and buttonConnections[upgradeName].Connected then
				buttonConnections[upgradeName]:Disconnect()
			end
		end
	end
end

function UpgradeHandler.Initialize()
	if not game.Loaded then
		game.Loaded:Wait()
	end

	dataSync.OnReady(function()
		task.delay(1, LoadUpgrades)
	end)

	dataSync.OnChanged("UpgradeLevels", function(_, _)
		UpdateUpgradeFrames()
	end)
	dataSync.OnChanged("Gems", function()
		UpdateUpgradeFrames()
	end)
end

return UpgradeHandler
