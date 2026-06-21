local ItemHandler = {}

-- Services
local players = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")

-- Variables
repeat
	task.wait()
until players.LocalPlayer
local player: Player = players.LocalPlayer

local framework = rs:WaitForChild("Framework")

local activeTimers = {}

-- UI
local playerGui = player:WaitForChild("PlayerGui")
local hud = playerGui:WaitForChild("HUD")
local potionTemplates = hud:WaitForChild("PotionTemplates")
local itemHolder = hud:WaitForChild("Items")

-- Modules
local dataSync = require(script.Parent.DataSyncClient)
local globals = require(framework.Globals)

local function UpdateDisplay(clone, endTime)
	local remainingTime = endTime - os.time()
	clone.Duration.Text = globals.FormatTime(remainingTime)
end

local function StartTimer(clone, endTime, boostType)
	if not activeTimers[boostType] then
		activeTimers[boostType] = {}
	end

	local timerCon: RBXScriptConnection

	timerCon = runService.Heartbeat:Connect(function(_)
		UpdateDisplay(clone, endTime)
	end)
	table.insert(activeTimers[boostType], timerCon)
end

local function CreateTemplate(boostType, tier, remainingDuration)
	local clone = potionTemplates:FindFirstChild(tier):Clone()
	local color = globals.BuffColors[boostType]
	clone.Liquid.ImageColor3 = color

	-- if rarity == 'Legendary' then
	--     clone.Liquid.RainbowTemplate.Enabled = true;
	-- end
	clone.Tier.Text = tier
	clone.Duration.Text = globals.FormatTime(remainingDuration)
	clone.Name = boostType
	clone.Parent = itemHolder
	clone.Visible = true

	return clone
end

function ItemHandler.UpdateActivePotions()
	local activePotions = dataSync.Get("ActivePotions")

	for boostType, tiers in pairs(activePotions) do
		task.spawn(function()
			if activeTimers[boostType] then
				for _, con: RBXScriptConnection in pairs(activeTimers[boostType]) do
					con:Disconnect()
				end
			end

			local activePotion = tiers.Active
			local tier, data = next(activePotion)

			if not tier or not data then
				if itemHolder:FindFirstChild(boostType) then
					itemHolder:FindFirstChild(boostType):Destroy()
				end
				return
			end

			local endTime = data.EndTime
			local remainingDuration = data.RemainingDuration

			local new = nil

			if itemHolder:FindFirstChild(boostType) then
				local clone = itemHolder:FindFirstChild(boostType)
				if clone.Tier.Text == tier then
					new = clone
				else
					clone:Destroy()
					new = CreateTemplate(boostType, tier, remainingDuration)
				end
			else
				new = CreateTemplate(boostType, tier, remainingDuration)
			end
			StartTimer(new, endTime, boostType)
		end)
	end
end

return ItemHandler
