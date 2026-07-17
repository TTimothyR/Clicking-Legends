local ButtonHandler = {}
local db = false

-- Services
local players = game:GetService("Players")
local ts = game:GetService("TweenService")

-- Variables
repeat
	task.wait()
until players.LocalPlayer
local plr: Player = players.LocalPlayer

ButtonHandler.activeFrame = nil

local camera = workspace.CurrentCamera

-- UI
local playerGui = plr:WaitForChild("PlayerGui")

local frames = playerGui:WaitForChild("Frames")
local UIShadow = frames.UIShadow
local indexFrame = frames:WaitForChild("Index")
local inventoryFrame = frames:WaitForChild("Inventory")
local prizesFrame = frames:WaitForChild("Prizes")
local rebirthsFrame = frames:WaitForChild("Rebirths")
local shopFrame = frames:WaitForChild("Shop")
local playerListFrame = frames:WaitForChild("PlayerList")
local tradeFrame = frames:WaitForChild("Trade")
local infoFrame = frames:WaitForChild("Info")
local upgradesFrame = frames:WaitForChild("Upgrades")
local statsFrame = frames:WaitForChild("Stats")
local settingsFrame = frames:WaitForChild("Settings")
local dailyRewardsFrame = frames:WaitForChild("DailyRewards") :: Frame

local hud = playerGui:WaitForChild("HUD")
local left = hud:WaitForChild("Left")
local buttons = left:WaitForChild("Buttons")
local indexButton = buttons:WaitForChild("Index")
local inventoryButton = buttons:WaitForChild("Pets")
local prizesButton = buttons:WaitForChild("Prizes")
local rebirthButton = buttons:WaitForChild("Rebirth")
local shopButton = buttons:WaitForChild("Shop")
local tradeButton = buttons:WaitForChild("Trading")
local upgradeButton = buttons:WaitForChild("Upgrades")
local statsButton = buttons:WaitForChild("Stats")
local settingsButton = buttons:WaitForChild("Settings") :: ImageButton
local dailyRewardsButton = buttons:WaitForChild("DailyRewards") :: ImageButton

-- Modules
local inventoryHandler = require(script.Parent.InventoryHandler)
local rebirthHandler = require(script.Parent.RebirthHandler)
local indexHandler = require(script.Parent.IndexHandler)
local PlaytimeHandler = require(script.Parent.PlaytimeHandler)
local prizeHandler = require(script.Parent.PrizeHandler)
local settingsHandler = require(script.Parent.SettingsHandler)

-- Constants
-- Size, position;
local sizePos = {
	["Index"] = { UDim2.fromScale(0.497, 0.6), UDim2.fromScale(0.5, 0.5) },
	["Inventory"] = { UDim2.fromScale(0.588, 0.658), UDim2.fromScale(0.5, 0.5) },
	["Prizes"] = { UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.5, 0.5) },
	["Rebirths"] = { UDim2.fromScale(0.6, 0.6), UDim2.fromScale(0.5, 0.5) },
	["Shop"] = { UDim2.fromScale(0.588, 0.658), UDim2.fromScale(0.5, 0.5) },
	["PlayerList"] = { UDim2.fromScale(0.6, 0.6), UDim2.fromScale(0.5, 0.5) },
	["Trade"] = { UDim2.fromScale(0.7, 0.7), UDim2.fromScale(0.5, 0.5) },
	["Info"] = { UDim2.fromScale(0.45, 0.45), UDim2.fromScale(0.5, 0.5) },
	["Warning"] = { UDim2.fromScale(0.45, 0.45), UDim2.fromScale(0.5, 0.5) },
	["Upgrades"] = { UDim2.fromScale(0.6, 0.6), UDim2.fromScale(0.5, 0.5) },
	["Stats"] = { UDim2.fromScale(0.6, 0.6), UDim2.fromScale(0.5, 0.5) },
	["ItemShop"] = { UDim2.fromScale(0.497, 0.6), UDim2.fromScale(0.5, 0.5) },
	["Settings"] = { UDim2.fromScale(0.6, 0.6), UDim2.fromScale(0.5, 0.5) },
	["DailyRewards"] = { UDim2.fromScale(0.6, 0.6), UDim2.fromScale(0.5, 0.5) },
}
local animationTime = 0.15
local fov = camera.FieldOfView

function ButtonHandler.openFrame(frame: Frame)
	ButtonHandler.activeFrame = frame
	frame.Size = UDim2.new(0, 0, 0, 0)
	frame.Position = UDim2.fromScale(0.5, 0.85)
	frame.Visible = true

	ts
		:Create(
			UIShadow,
			TweenInfo.new(animationTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 0.5 }
		)
		:Play()

	frame:TweenSizeAndPosition(
		sizePos[frame.Name][1],
		sizePos[frame.Name][2],
		Enum.EasingDirection.Out,
		Enum.EasingStyle.Sine,
		animationTime
	)
	ts
		:Create(camera, TweenInfo.new(animationTime, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { FieldOfView = 90 })
		:Play()
end

function ButtonHandler.closeFrame(frame: Frame)
	frame:TweenSizeAndPosition(
		UDim2.new(0, 0, 0, 0),
		UDim2.fromScale(0.5, 0.85),
		Enum.EasingDirection.Out,
		Enum.EasingStyle.Sine,
		animationTime
	)
	ts
		:Create(
			UIShadow,
			TweenInfo.new(animationTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 1 }
		)
		:Play()
	ts
		:Create(camera, TweenInfo.new(animationTime, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { FieldOfView = fov })
		:Play()
	ButtonHandler.activeFrame = nil
	task.wait(animationTime)
	frame.Visible = false
end

function ButtonHandler.handleOpenClose(frame, func)
	if not db then
		db = true
		task.delay(0.15, function()
			db = false
		end)
		if (ButtonHandler.activeFrame == tradeFrame) and (frame ~= tradeFrame) and (frame ~= infoFrame) then
			return
		end
		if frame == ButtonHandler.activeFrame then
			ButtonHandler.closeFrame(frame)
			return
		end
		if ButtonHandler.activeFrame then
			ButtonHandler.closeFrame(ButtonHandler.activeFrame)
		end
		if func then
			func()
		end
		ButtonHandler.openFrame(frame)
	end
end

function ButtonHandler.Initialize()
	if not game.Loaded then
		game.Loaded:Wait()
	end

	inventoryHandler.ParseMenuHandler(ButtonHandler)

	indexButton.MouseButton1Click:Connect(function()
		ButtonHandler.handleOpenClose(indexFrame, indexHandler.LoadIndex)
	end)
	inventoryButton.MouseButton1Click:Connect(function()
		ButtonHandler.handleOpenClose(inventoryFrame, function()
			inventoryHandler.LoadInventory()
			inventoryHandler.LoadItems()
			inventoryHandler.LoadGifts()

			inventoryHandler.StartLegendaryAnimations()
		end)
	end)
	prizesButton.MouseButton1Click:Connect(function()
		ButtonHandler.handleOpenClose(prizesFrame, prizeHandler.LoadPrizes)
	end)
	rebirthButton.MouseButton1Click:Connect(function()
		ButtonHandler.handleOpenClose(rebirthsFrame, rebirthHandler.LoadRebirthButtons)
	end)
	shopButton.MouseButton1Click:Connect(function()
		ButtonHandler.handleOpenClose(shopFrame)
	end)
	tradeButton.MouseButton1Click:Connect(function()
		ButtonHandler.handleOpenClose(playerListFrame)
	end)
	upgradeButton.MouseButton1Click:Connect(function()
		ButtonHandler.handleOpenClose(upgradesFrame)
	end)
	statsButton.MouseButton1Click:Connect(function()
		ButtonHandler.handleOpenClose(statsFrame)
	end)
	dailyRewardsButton.MouseButton1Click:Connect(function()
		ButtonHandler.handleOpenClose(dailyRewardsFrame, PlaytimeHandler.LoadDailyRewards)
	end)
	settingsButton.MouseButton1Click:Connect(function()
		ButtonHandler.handleOpenClose(settingsFrame, settingsHandler.LoadSettings)
	end)

	for _, frame in ipairs(frames:GetChildren()) do
		if frame:FindFirstChild("Close") and frame.Name ~= "Warning" and frame.name ~= "Info" then
			frame:FindFirstChild("Close").MouseButton1Click:Connect(function()
				if not db then
					db = true
					task.delay(0.15, function()
						db = false
					end)
					ButtonHandler.closeFrame(frame)
				end
			end)
		end
	end
end

return ButtonHandler
