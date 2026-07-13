local DebugDisplay = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local playerGui = player.PlayerGui
local Debug = playerGui:WaitForChild("Debug")
local holder = Debug.Holder

local Globals = require(ReplicatedStorage.Framework.Globals)
local Enchants = require(ReplicatedStorage.Framework.Library.Enchants)
local Upgrades = require(ReplicatedStorage.Framework.Library.Upgrades)
local DataSyncClient = require(script.Parent.DataSyncClient)

local statFrames = {
	[holder.EggOpens] = {
		Format = 'Egg Opens: <font color="#F5CD90">%s</font>',
		StatCallback = function()
			return DataSyncClient.Get("EggHatches")
		end,
	},
	[holder.HatchTime] = {
		Format = 'Hatch Time: <font color="#A6E3FF">%ss</font>',
		StatCallback = function()
			local ownedGamepsses = DataSyncClient.Get("OwnedGamepasses")
			local upgradeLevels = DataSyncClient.Get("UpgradeLevels")
			local baseSpeed = 1
			local baseHatchTime = Globals.BaseHatchTime

			local activePotions = DataSyncClient.Get("ActivePotions")
			if activePotions["Speed"] then
				local tier, data = next(activePotions["Speed"].Active)

				if tier and data then
					baseSpeed += Globals.GetPotionBuffAmount(tier, "Speed") / 100
				end
			end

			if ownedGamepsses["Fast Hatch"] then
				baseSpeed += 0.35
			end
			if next(upgradeLevels) ~= nil then
				baseSpeed += upgradeLevels["Faster Egg Open"] * (Upgrades["Faster Egg Open"].Increment / 100)
			end

			local totalHatchTime = baseHatchTime / baseSpeed
			return Globals.FormatChance(totalHatchTime)
		end,
	},
	[holder.Luck] = {
		Format = 'Luck: <font color="#00ff2a">+%s%%</font>',
		StatCallback = function()
			local baseLuckPercentage = DataSyncClient.Get("LuckPercentage")
			local activePotions = DataSyncClient.Get("ActivePotions")
			local ownedGamepasses = DataSyncClient.Get("OwnedGamepasses")
			local pets = DataSyncClient.Get("Pets")
			if activePotions["Lucky"] then
				local tier, data = next(activePotions["Lucky"].Active)

				if tier and data then
					baseLuckPercentage += Globals.GetPotionBuffAmount(tier, "Lucky")
				end
			end

			for _, data in ipairs(pets) do
				if not data.equipped then
					continue
				end

				if string.find(data.enchant, "Lucky") then
					baseLuckPercentage += Enchants[data.enchant].Buff
				end
			end

			local gamepass = ownedGamepasses["Double Luck"] and true or false
			if gamepass then
				baseLuckPercentage *= 2
			end
			return baseLuckPercentage
		end,
	},
	[holder.ShinyChance] = {
		Format = 'Shiny Chance: <font color="#FFFB00">1/%s</font>',
		StatCallback = function()
			return Globals.ShinyChance
		end,
	},
}

local function UpdateStats()
	for statFrame, data in pairs(statFrames) do
		statFrame.Holder.Amount.Text = data.Format:format(data.StatCallback())
	end
end

function DebugDisplay.Initialize()
	if not game.Loaded then
		game.Loaded:Wait()
	end
	DataSyncClient.OnReady(UpdateStats)

	DataSyncClient.OnChanged("EggHatches", UpdateStats)
	DataSyncClient.OnChanged("LuckPercentage", UpdateStats)
	DataSyncClient.OnChanged("ActivePotions", UpdateStats)
	DataSyncClient.OnChanged("OwnedGamepasses", UpdateStats)
	DataSyncClient.OnChanged("UpgradeLevels", UpdateStats)
	DataSyncClient.OnChanged("Pets", UpdateStats)

	DataSyncClient.OnChanged("Settings", function(new, _)
		holder.Visible = new.Debug
	end)
end

return DebugDisplay
