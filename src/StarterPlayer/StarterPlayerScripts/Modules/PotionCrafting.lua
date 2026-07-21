local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Framework = ReplicatedStorage:WaitForChild("Framework")

local Library = Framework:WaitForChild("Library")
local Shared = Framework:WaitForChild("Shared")

local PotionCraftingUtility = require(Framework:WaitForChild("PotionCraftingUtility"))
local RomanToNumber = require(Shared:WaitForChild("RomanToNumber"))
local ImageService = require(Library:WaitForChild("ImageService"))
local InfiniteMath = require(Framework:WaitForChild("InfiniteMath"))
local Network = require(Framework:WaitForChild("Network"))
local Globals = require(Framework:WaitForChild("Globals"))
local Items = require(Library:WaitForChild("Items"))

local PotionCrafting = {}

local Player = Players.LocalPlayer
local PlayerGui = Player.PlayerGui
local Frames = PlayerGui:WaitForChild("Frames")
local PotionCraftingFrame = Frames:WaitForChild("PotionCrafting")
local Main = PotionCraftingFrame:WaitForChild("Main")
local List = Main.List
local ScrollingFrame = List.ScrollingFrame

local DataSyncClient = require("./DataSyncClient")

local function Clear()
	for _, child in ScrollingFrame:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

local function LoadPotions()
	Clear()
	local ItemsInventory = DataSyncClient.Get("Items")
	local PotionInventory = ItemsInventory.Potions

	for tier, data in pairs(Items.Potions) do
		if tier == "I" or tier == Globals.BestPotionTier then
			continue
		end
		local NonRomanTier = RomanToNumber(tier)
		local NextTier, NextTierRoman = PotionCraftingUtility.GetNextTier(NonRomanTier)
		if NextTier == nil then
			continue
		end

		local Buffs = data.Buffs

		for _, BuffData in pairs(Buffs) do
			local Name, _ = BuffData[1], BuffData[2]
			local LowerTierPotion = {
				Tier = tier,
				NumberTier = NonRomanTier,
				Name = Name,
			}
			local HigherTierPotion = {
				Tier = NextTierRoman,
				NumberTier = NextTier,
				Name = Name,
			}

			local LowerTierKey = `{LowerTierPotion.Name}_{LowerTierPotion.Tier}`
			local HigherTierKey = `{HigherTierPotion.Name}_{HigherTierPotion.Tier}`

			local Template = script.Template:Clone() :: Frame
			Template.Name = `{Name} {tier} Recipe`
			Template.Icon.Image = ImageService[`{HigherTierKey}`]
			Template.Title.Text = `{HigherTierPotion.Name} {HigherTierPotion.Tier}`
			Template.Visible = true
			Template.Parent = ScrollingFrame
			Template.LayoutOrder = NonRomanTier

			local clickConnection = Template.Buttons.Craft.MouseButton1Click:Connect(function()
				Network:FireServer("CraftPotion", LowerTierPotion, HigherTierPotion)
			end) :: RBXScriptConnection

			Template:GetPropertyChangedSignal("Parent"):Once(function()
				clickConnection:Disconnect()
			end)

			local RequirementFrame = Template.Requirement
			local AmountInInv = (PotionInventory[`{LowerTierKey}`] or 0)
			local RequiredAmt = PotionCraftingUtility.PotionsRequired[NextTierRoman]

			RequirementFrame.Label.Text = `{InfiniteMath.new(AmountInInv):GetSuffix(false)} / {InfiniteMath.new(RequiredAmt)
				:GetSuffix(false)} {LowerTierPotion.Name} {LowerTierPotion.Tier}`
			RequirementFrame.Label.TextColor3 = (
				AmountInInv >= RequiredAmt and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
			)
			RequirementFrame.Icon.Image = ImageService[`{LowerTierKey}`]
		end
	end
end

function PotionCrafting.Initialize()
	if not game.Loaded then
		game.Loaded:Wait()
	end

	DataSyncClient.OnChanged("Items", function()
		LoadPotions()
	end)

	--LoadPotions()
end

return PotionCrafting
