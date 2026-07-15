local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enchants = require(script.Parent.Enchants)
local ShopStats = require(script.Parent.ShopStats)
local InfiniteMath = require("../InfiniteMath")
local ImageService = require("./ImageService")
local ItemUtility = require("../ItemUtility")
local PetUtility = require("../PetUtility")
local PetStats = require("./PetStats")
local Globals = require("../Globals")
local ToHex = require("../Shared/ToHex")

local getPetExist = ReplicatedStorage:WaitForChild("GetPetExist") :: RemoteFunction

local existCache = {}

local function HideAll(labelsFrame: Frame)
	for _, child in ipairs(labelsFrame:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child.Visible = false
		end
	end
end

local Tooltips = {
	PetTooltip = function(Frame, Data, FromShop)
		if not Frame or not Data then
			return
		end
		if not FromShop then
			FromShop = false
		end
		local LabelsFrame = Frame:FindFirstChild("Labels")
		HideAll(LabelsFrame)
		local TopFrame = Frame:FindFirstChild("Top")
		local Image = ((Data.shiny and `Shiny {Data.petName}` or Data.petName) or ImageService.Doggy)
		local Rarity = (PetStats[Data.petName].Rarity or "Common")
		local PetData = PetUtility.GetPetData(Data.id)

		TopFrame.Info.Title.Text = Data.petName
		TopFrame.Icon.Image = ImageService[Image] or ImageService["Placeholder"]
		TopFrame.Info.Rarity.Text = Rarity
		TopFrame.Info.Rarity.TextColor3 = Globals.RarityColors[Rarity]

		if PetStats[Data.petName].Secret then
			TopFrame.Info.Rarity.Secret.Enabled = true
			TopFrame.Info.Rarity.Legendary.Enabled = false
			TopFrame.Info.Rarity.Text = "Secret"
		else
			if Rarity == "Legendary" then
				TopFrame.Info.Rarity.Legendary.Enabled = true
				TopFrame.Info.Rarity.Secret.Enabled = false
			else
				TopFrame.Info.Rarity.Legendary.Enabled = false
				TopFrame.Info.Rarity.Secret.Enabled = false
			end
		end

		if Data.ShowExist then
			local fullName = Data.shiny and "Shiny " .. Data.petName or Data.petName
			local count = 0

			if existCache[fullName] and (os.time() - existCache[fullName].fetchTime) < Globals.ExistRefreshTime then
				count = existCache[fullName].count
			else
				count = getPetExist:InvokeServer(Data.petName, Data.shiny)
				existCache[fullName] = { count = count, fetchTime = os.time() }
			end

			LabelsFrame.ExistHolder.Amount.Text = `{count} Exist`
			LabelsFrame.ExistHolder.Visible = true
		else
			LabelsFrame.ExistHolder.Visible = false
		end

		if Data.clicks then
			local PetClicks = FromShop and Globals.GetPetClicks(Data) or Globals.GetPetClicks(PetData)
			LabelsFrame.Clicks.Visible = true
			LabelsFrame.Clicks.Amount.Text = InfiniteMath.new(PetClicks):GetSuffix(true)
		end

		if Data.gems then
			local PetGems = FromShop and Globals.GetPetGems(Data) or Globals.GetPetGems(PetData)
			LabelsFrame.Gems.Visible = true
			LabelsFrame.Gems.Amount.Text = InfiniteMath.new(PetGems):GetSuffix(true)
		end

		if Data.ShowLevel then
			local xpNeeded = Globals.XPForNextLevel(PetData.level, PetData.shiny)

			LabelsFrame.Level.Visible = true
			LabelsFrame.Level.Progress.Level.Text = `Level {PetData.level}`
			LabelsFrame.Level.Progress.XP.Text = PetData.xp .. " / " .. InfiniteMath.new(xpNeeded):GetSuffix(true) .. " XP"

			LabelsFrame.Level.Progress.Green.Size = UDim2.fromScale(PetData.xp / xpNeeded, 1)
		else
			LabelsFrame.Level.Visible = false
		end

		if Data.AutoDelete then
			LabelsFrame.AutoDelete.Visible = true
		end

		if Data.Chance then
			LabelsFrame.Chance.Visible = true
			LabelsFrame.Chance.Amount.Text = `1 in {InfiniteMath.new(Data.Chance):GetSuffix(true)}`
		end

		if Data.enchant and Data.enchant ~= "" then
			local split = string.split(Data.enchant, "_")
			local name, tier = split[1], split[2]

			local tierColor = Color3.fromRGB(255, 255, 255)

			if Enchants[Data.enchant].Rarity == "Exclusive" then
				tierColor = Globals.RarityColors.Epic
			end

			LabelsFrame.Enchant.Text = string.format(
				Enchants.Description[name],
				ToHex(Enchants.Colors[name]),
				name,
				ToHex(tierColor),
				tier,
				ToHex(Enchants.Colors[name]),
				Enchants[Data.enchant].Buff
			)
			LabelsFrame.Enchant.Visible = true
		end

		if Data.Replay then
			LabelsFrame.Replay.Visible = true
		end

		if Data.Tag then
			LabelsFrame.Tag.Visible = true
			LabelsFrame.Tag.Amount.Text = Data.Tag
		end
	end,
	Gifts = function(frame: Frame, data: { [any]: any })
		if not frame or not data then
			return
		end

		local labelsFrame = frame:FindFirstChild("Labels") :: Frame
		HideAll(labelsFrame)
		local topFrame = frame:FindFirstChild("Top") :: Frame

		topFrame.Info.Title.Text = data.gamepassName
		topFrame.Icon.Image = ImageService[data.gamepassName] or ImageService["Placeholder"]

		local rarity = "Legendary"

		topFrame.Info.Rarity.TextColor3 = Globals.RarityColors[rarity]
		if rarity == "Legendary" then
			topFrame.Info.Rarity.TextColor3 = Color3.fromRGB(255, 255, 255)
			topFrame.Info.Rarity.Legendary.Enabled = true
			topFrame.Info.Rarity.Secret.Enabled = false
		else
			topFrame.Info.Rarity.Legendary.Enabled = false
			topFrame.Info.Rarity.Secret.Enabled = false
		end
		topFrame.Info.Rarity.Text = rarity

		labelsFrame.Description.Text = ShopStats.Gamepasses[data.gamepassName].Description
		labelsFrame.Description.Visible = true
	end,
	Items = function(Frame, Data)
		if not Frame or not Data then
			return
		end
		local LabelsFrame = Frame:FindFirstChild("Labels")
		HideAll(LabelsFrame)
		local TopFrame = Frame:FindFirstChild("Top")

		local ItemName = Data.itemName
		local nameSplit = string.split(ItemName, "_")
		local buff, tier = nameSplit[1], nameSplit[2]

		local ItemType = ItemUtility.GetItemType(tier)
		local Rarity = ItemUtility.GetItemRarity(ItemType, tier)
		local Description = (ItemType == "Potions" and Globals.PotionDescriptions[buff] or "")

		TopFrame.Info.Title.Text = (ItemType == "Potions" and buff .. " " .. tier or ItemName)
		TopFrame.Icon.Image = ImageService[ItemName] or ImageService["Placeholder"]
		TopFrame.Info.Rarity.TextColor3 = Globals.RarityColors[Rarity]
		TopFrame.Info.Rarity.Text = ItemUtility.GetItemDuration(buff, tier)

		if Rarity == "Legendary" then
			TopFrame.Info.Rarity.TextColor3 = Color3.fromRGB(255, 255, 255)
			TopFrame.Info.Rarity.Legendary.Enabled = true
			TopFrame.Info.Rarity.Secret.Enabled = false
		else
			TopFrame.Info.Rarity.Legendary.Enabled = false
			TopFrame.Info.Rarity.Secret.Enabled = false
		end

		if Description then
			LabelsFrame.Description.Text =
				string.format(Description, ToHex(Globals.BuffColors[buff]), ItemUtility.GetBuffPercentage(buff, tier))
			LabelsFrame.Description.Visible = true
		end
	end,
}

return Tooltips
