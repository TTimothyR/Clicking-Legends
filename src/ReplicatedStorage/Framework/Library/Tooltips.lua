local InfiniteMath = require("../InfiniteMath")
local ImageService = require("./ImageService")
local ItemUtility = require("../ItemUtility")
local PetStats = require("./PetStats")
local Globals = require("../Globals")
local ToHex = require("../Shared/ToHex")

local Tooltips = {
	PetTooltip = function(Frame, Data)
		if not Frame or not Data then
			return
		end
		local LabelsFrame = Frame:FindFirstChild("Labels")
		local TopFrame = Frame:FindFirstChild("Top")
		local Image = ((Data.shiny and `Shiny {Data.petName}` or Data.petName) or ImageService.Doggy)
		local Rarity = (PetStats[Data.petName].Rarity or "Common")

		TopFrame.Info.Title.Text = Data.petName
		TopFrame.Icon.Image = ImageService[Image] or ImageService["Placeholder"]
		TopFrame.Info.Rarity.Text = Rarity
		TopFrame.Info.Rarity.TextColor3 = Globals.RarityColors[Rarity]

		if Rarity == "Legendary" then
			TopFrame.Info.Rarity.Legendary.Enabled = true
		else
			TopFrame.Info.Rarity.Legendary.Enabled = false
		end

		if Data.clicks then
			local PetClicks = Globals.GetPetClicks(Data)
			LabelsFrame.Clicks.Visible = true
			LabelsFrame.Clicks.Amount.Text = InfiniteMath.new(PetClicks):GetSuffix(true)
		end

		if Data.gems then
			local PetGems = Globals.GetPetGems(Data)
			LabelsFrame.Gems.Visible = true
			LabelsFrame.Gems.Amount.Text = InfiniteMath.new(PetGems):GetSuffix(true)
		end

		if Data.AutoDelete then
			LabelsFrame.AutoDelete.Visible = true
		end

		if Data.Chance then
			LabelsFrame.Chance.Visible = true
			LabelsFrame.Chance.Amount.Text = `1 in {InfiniteMath.new(Data.Chance):GetSuffix(true)}`
		end

		if Data.Enchant then
			LabelsFrame.Enchant.Visible = true
			LabelsFrame.Enchant.Amount.Text = Data.Enchant
		end

		if Data.Replay then
			LabelsFrame.Replay.Visible = true
		end

		if Data.Tag then
			LabelsFrame.Tag.Visible = true
			LabelsFrame.Tag.Amount.Text = Data.Tag
		end
	end,
	Items = function(Frame, Data)
		if not Frame or not Data then
			return
		end
		local LabelsFrame = Frame:FindFirstChild("Labels")
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
		else
			TopFrame.Info.Rarity.Legendary.Enabled = false
		end

		if Description then
			LabelsFrame.Description.Text =
				string.format(Description, ToHex(Globals.BuffColors[buff]), ItemUtility.GetBuffPercentage(buff, tier))
			LabelsFrame.Description.Visible = true
		end
	end,
}

return Tooltips
