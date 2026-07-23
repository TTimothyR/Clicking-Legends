local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Globals = require(ReplicatedStorage.Framework.Globals)
local PetStats = require(ReplicatedStorage.Framework.Library.PetStats)
local Network = require(ReplicatedStorage.Framework.Network)
local LegendaryChatHandler = {}

local normalFormat = "%s hatched a Legendary %s (%s%%)"
local shinyFormat = "%s hatched a Shiny Legendary %s (%s%%)"

local function GetPetColor(chance, shiny, secret)
	if secret then
		if not shiny then
			return "#fc0a0a"
		else
			return "#f8fc0a"
		end
	end
	if not shiny then
		if chance >= 0.005 then
			return "#0800ff"
		else
			return "#59ff00"
		end
	else
		if chance >= 0.005 then
			return "#3bff00"
		else
			return "#fc0a0a"
		end
	end
end

function LegendaryChatHandler.SendLegendaryMessage(player, petName, eggName, shiny)
	local chance = Globals.GetRawPetChance(petName, eggName)
	local petData = PetStats[petName]
	local color = GetPetColor(chance, shiny, petData.Secret)
	local baseChance = chance
	if shiny then
		chance /= Globals.ShinyChance
	end

	local message

	if shiny then
		message = shinyFormat:format(player.Name, petName, chance)
	else
		message = normalFormat:format(player.Name, petName, chance)
	end

	Network:FireAllClients("ShowMessage", message, color, (baseChance >= 0.02))
end

return LegendaryChatHandler
