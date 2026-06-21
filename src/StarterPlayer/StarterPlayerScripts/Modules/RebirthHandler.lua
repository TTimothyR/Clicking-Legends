local RebirthHandler = {}
local db = false

-- Services
local players = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")
local mps = game:GetService("MarketplaceService")

-- Variables
repeat
	task.wait()
until players.LocalPlayer
local player: Player = players.LocalPlayer

local shopHandlerLoaded = false

local framework = rs:WaitForChild("Framework")
local library = framework:WaitForChild("Library")
local autoRebirthStatus = false
local autoRebirthSelect = false
local selectedIndex = nil
local isLoaded = false

local unlimRebirthPurchaseCon: RBXScriptConnection = nil

-- UI
local playerGui = player:WaitForChild("PlayerGui")
local frames = playerGui:WaitForChild("Frames")
local rebirthFrame = frames:WaitForChild("Rebirths")
local main = rebirthFrame:WaitForChild("Main")
local templates = main:WaitForChild("Templates")
local rebirthTemplate = templates:WaitForChild("RebirthTemplate")
local list = main:WaitForChild("List")
local holder = list:WaitForChild("ScrollingFrame")
local autoRebirthFrame = main:WaitForChild("AutoRebirth")
local autoRebirthToggle = autoRebirthFrame:WaitForChild("Toggle")
local autoRebirthSettings = rebirthFrame:WaitForChild("AutoSettings")

-- Modules
local rebirthStats = require(library.RebirthStats)
local shopStats = require(library.ShopStats)
local globals = require(framework.Globals)
local infMath = require(framework.InfiniteMath)
local network = require(framework.Network)
local dataSync = require(script.Parent.DataSyncClient)
local shopHandler

local function UpdateButtonColor(inner, color: string)
	inner.Click.Frame.UIGradient.Color = globals.ButtonPresets[color].Gradient
	inner.Click.Frame.UIStroke.Color = globals.ButtonPresets[color].StrokeColor
	inner.Click.Title.UIStroke.Color = globals.ButtonPresets[color].StrokeColor

	if color == "Purple" then
		if tonumber(inner.Parent.Name) == selectedIndex then
			inner.Click.Title.Text = "Selected"
		else
			inner.Click.Title.Text = "Select"
		end
	else
		inner.Click.Title.Text = "Rebirth"
	end
end

local function UpdateButton(inner: Frame, price)
	local color = ""
	local currentClicks = dataSync.Get("Clicks")

	if price == nil then
		color = "Red"
	else
		if currentClicks >= price then
			color = "Green"
		else
			color = "Red"
		end
	end
	UpdateButtonColor(inner, color)
end

local function UpdateButtons(fromSignal: boolean)
	if not isLoaded then
		return
	end
	local currentRebirths = dataSync.Get("Rebirths")
	local currentClicks = dataSync.Get("Clicks")
	local ownedGamepasses = dataSync.Get("OwnedGamepasses")
	if (rebirthFrame.Visible or not fromSignal) and not autoRebirthSelect then
		for index, rebirths in ipairs(rebirthStats) do
			local clone = holder:FindFirstChild(index)

			if index == 1 and rebirths == 0 then
				rebirths = infMath.new(currentClicks / (globals.RebirthBasePrice * currentRebirths))
				rebirths = infMath.floor(rebirths)

				if not ownedGamepasses["Unlimited Rebirths"] then
					clone.Inner.Locked.Visible = true
					unlimRebirthPurchaseCon = clone.Inner.Locked.Buy.MouseButton1Click:Connect(function()
						if not db then
							db = true
							task.delay(0.15, function()
								db = false
							end)
							mps:PromptGamePassPurchase(player, shopStats.Gamepasses["Unlimited Rebirths"].GamepassID)
							shopHandler.ShowGreyFrame()
						end
					end)
				end
			end

			local word = (rebirths == 1) and "Rebirth" or "Rebirths"

			local cost = infMath.new(globals.RebirthBasePrice * rebirths * currentRebirths)

			local inner = clone.Inner
			inner.Amount.Text = "+" .. tostring(rebirths) .. " " .. word .. " (" .. cost:GetSuffix(true) .. " Clicks)"
			if rebirths == infMath.new(0) then
				UpdateButton(inner, nil)
			else
				UpdateButton(inner, cost)
			end

			inner.AutoStroke.Enabled = (selectedIndex == index)

			clone.Visible = true
		end
		main.Rebirths.Amount.Text = "Rebirths: " .. currentRebirths:GetSuffix(true)
	end

	for index, rebirths in ipairs(rebirthStats) do
		local cost = infMath.new(globals.RebirthBasePrice * rebirths * currentRebirths)
		if autoRebirthStatus and selectedIndex == index and (currentClicks >= cost) then
			network:FireServer("AttemptRebirth", index)
		end
	end
end

local function UpdateAutoRebirthButton(status: boolean)
	local color = ""
	local text = ""
	if status then
		color = "Green"
		text = "On"
	else
		color = "Red"
		text = "Off"
	end
	autoRebirthToggle.Frame.UIGradient.Color = globals.ButtonPresets[color].Gradient
	autoRebirthToggle.Frame.UIStroke.Color = globals.ButtonPresets[color].StrokeColor
	autoRebirthToggle.Title.UIStroke.Color = globals.ButtonPresets[color].StrokeColor
	autoRebirthToggle.Title.Text = text
end

local function CheckUnlimitedRebirthsOwned(newData)
	if newData["Unlimited Rebirths"] then
		if holder:FindFirstChild("1") then
			holder:FindFirstChild("1").Inner.Locked.Visible = false

			if unlimRebirthPurchaseCon.Connected then
				unlimRebirthPurchaseCon:Disconnect()
			end
		end
	end
end

function RebirthHandler.LoadRebirthButtons()
	if #holder:GetChildren() - 1 == #rebirthStats then
		UpdateButtons(false)
		return
	end
	for index, _ in ipairs(rebirthStats) do
		local clone = rebirthTemplate:Clone()
		local inner = clone.Inner
		clone.Parent = holder
		clone.LayoutOrder = index
		clone.Name = index

		inner.Click.MouseButton1Click:Connect(function()
			if not db then
				db = true
				task.delay(0.15, function()
					db = false
				end)
				if autoRebirthSelect then
					if index == 1 then
						return
					end
					network:FireServer("SetAutoRebirthIndex", index)
					autoRebirthSelect = false
				else
					network:FireServer("AttemptRebirth", index)
				end
			end
		end)
	end
	isLoaded = true
	UpdateButtons(false)
end

local function LoadAutoRebirthLocked()
	local upgradeLevels = dataSync.Get("UpgradeLevels")
	local autoRebirthUnlocked = (upgradeLevels["Auto Rebirth"] == 1)

	autoRebirthSettings.Locked.Visible = not autoRebirthUnlocked
	autoRebirthToggle.Locked.Visible = not autoRebirthUnlocked
end

function RebirthHandler.ParseShopHandler(module)
	if shopHandlerLoaded then
		return
	end
	shopHandlerLoaded = true
	shopHandler = module
end

function RebirthHandler.Initialize()
	if not game.Loaded then
		game.Loaded:Wait()
	end

	dataSync.OnReady(function()
		autoRebirthStatus = dataSync.Get("AutoRebirthStatus")
		selectedIndex = dataSync.Get("AutoRebirthIndex")

		UpdateAutoRebirthButton(autoRebirthStatus)
		LoadAutoRebirthLocked()
	end)

	dataSync.OnChanged("Clicks", function()
		UpdateButtons(true)
	end)

	dataSync.OnChanged("Rebirths", function()
		UpdateButtons(true)
	end)

	dataSync.OnChanged("AutoRebirthStatus", function(new)
		autoRebirthStatus = new
		UpdateAutoRebirthButton(new)
	end)

	dataSync.OnChanged("AutoRebirthIndex", function(new)
		selectedIndex = new
		UpdateButtons(false)
	end)

	dataSync.OnChanged("OwnedGamepasses", function(new, _)
		CheckUnlimitedRebirthsOwned(new)
	end)

	dataSync.OnChanged("UpgradeLevels", function(new, _)
		if new["Auto Rebirth"] == 1 then
			autoRebirthSettings.Locked.Visible = false
			autoRebirthToggle.Locked.Visible = false
		end
	end)

	autoRebirthToggle.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)
			network:FireServer("ToggleAutoRebirth")
		end
	end)

	autoRebirthSettings.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)
			if dataSync.Get("UpgradeLevels")["Auto Rebirth"] == 0 then
				return
			end
			if not autoRebirthSelect then
				autoRebirthSelect = true
				for _, child in ipairs(holder:GetChildren()) do
					if child:IsA("Frame") then
						if child.Name == "1" then
							child.Visible = false
						end
						UpdateButtonColor(child.Inner, "Purple")
					end
				end
			else
				autoRebirthSelect = false
				UpdateButtons(false)
			end
		end
	end)
end

return RebirthHandler
