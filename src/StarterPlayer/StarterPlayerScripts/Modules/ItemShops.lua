local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Framework = ReplicatedStorage:WaitForChild("Framework")

local Library = Framework:WaitForChild("Library")

local ItemShopModule = require(Library:WaitForChild("ItemShopModule"))
local InfiniteMath = require(Framework:WaitForChild("InfiniteMath"))
local ImageService = require(Library:WaitForChild("ImageService"))
local ShopStats = require(Library:WaitForChild("ShopStats"))
local Network = require(Framework:WaitForChild("Network"))
local Globals = require(Framework:WaitForChild("Globals"))

local DataSyncClient = require("./DataSyncClient")
local MenuHandler = require("./MenuHandler")

local Player = Players.LocalPlayer
local PlayerGui = Player.PlayerGui
local Frames = PlayerGui:WaitForChild("Frames")
local ItemShopFrame = Frames:WaitForChild("ItemShop")
local Main = ItemShopFrame:WaitForChild("Main")
local List = Main:WaitForChild("List")
local Holder = List:WaitForChild("Holder")

local CurrentShop = nil

local ItemShops = {}

local function ClearOldItems()
	for _, v in pairs(Holder:GetChildren()) do
		if v:IsA("Frame") then
			v:Destroy()
		end
	end
end

local function UpdateRestockButton(color: string, text: string, button)
	button.Frame.UIGradient.Color = Globals.ButtonPresets[color].Gradient
	button.Frame.UIStroke.Color = Globals.ButtonPresets[color].StrokeColor
	button.Frame.Remaining.UIStroke.Color = Globals.ButtonPresets[color].StrokeColor
	button.Frame.TextLabel.UIStroke.Color = Globals.ButtonPresets[color].StrokeColor
	button.Frame.TextLabel.Text = text
end

function ItemShops.DisplayShop(shopName: string)
	ClearOldItems()
	if not ItemShopModule.Shops[shopName] then
		return
	end
	local ItemShopsData = DataSyncClient.Get("ItemShops")
	local DailyShopRerolls = DataSyncClient.Get("DailyShopRerolls")
	local nextDailyReroll = DataSyncClient.Get("NextDailyReroll")
	local ShopInData = ItemShopsData[shopName]
	if not ShopInData then
		return
	end
	local _Info = ItemShopModule.GetShopInfo(shopName)
	CurrentShop = shopName
	Network:FireServer("SetCurrentShop", shopName)

	if Frames.ItemShop.Visible == false then
		MenuHandler.openFrame(Frames.ItemShop)
	end

	ItemShopFrame.Title.Text = _Info.Name
	Main.FreeRerolls.Frame.Remaining.Text = `{DailyShopRerolls} Remaining`
	local text = (DailyShopRerolls > 0) and "Free Reroll" or Globals.FormatTime(nextDailyReroll - os.time(), false)
	local color = (DailyShopRerolls > 0) and "Green" or "Red"

	UpdateRestockButton(color, text, Main.FreeRerolls)

	for item, stock in pairs(ShopInData.Items) do
		local Template = script.DropTemplate:Clone()
		Template.Name = item
		Template.Parent = Holder

		local nameSplit = string.split(item, "_")
		local buff, tier = nameSplit[1], nameSplit[2]
		local DropData = ItemShopModule.GetDropData(shopName, item)
		local ItemHolder = Template.ItemHolder
		local Inside = ItemHolder.Inside
		local BuyButton = Template.Buy :: GuiButton
		local CostFrame = BuyButton.Holder.Cost

		Template.Stock.Text = `{InfiniteMath.new(stock):GetSuffix(false)} in stock`
		Inside.Icon.Image = ImageService[item]
		Inside.Item.Text = `{buff} {tier}`

		CostFrame.Amount.Text = InfiniteMath.new(DropData[3]):GetSuffix(true)
		CostFrame.Icon.Image = ImageService[_Info.Currency]

		BuyButton.MouseButton1Click:Connect(function()
			Network:FireServer("BuyShopItem", shopName, item)
		end)

		if stock < 1 then
			BuyButton.BoughtAll.Visible = true
		else
			BuyButton.BoughtAll.Visible = false
		end
	end
end

function ItemShops.Initialize()
	DataSyncClient.OnChanged("ItemShops", function(_, _)
		if CurrentShop then
			ItemShops.DisplayShop(CurrentShop)
		end
		--ItemShops.DisplayShop("TestShop")
	end)
	DataSyncClient.OnChanged("DailyShopRerolls", function(_, _)
		if CurrentShop then
			ItemShops.DisplayShop(CurrentShop)
		end
	end)
	Main.InstantRestock.MouseButton1Click:Connect(function()
		MarketplaceService:PromptProductPurchase(Player, ShopStats.DeveloperProducts.RestockItemShop.ProductID)
	end)
	Main.FreeRerolls.MouseButton1Click:Connect(function()
		local _ = Network:InvokeServer("UseDailyRestock")
	end)

	task.spawn(function()
		while task.wait(1) do
			if not CurrentShop then
				continue
			end
			local ItemShopsData = DataSyncClient.Get("ItemShops")
			local nextDailyReroll = DataSyncClient.Get("NextDailyReroll")
			local DailyShopRerolls = DataSyncClient.Get("DailyShopRerolls")

			local ShopInData = ItemShopsData[CurrentShop]
			if not ShopInData then
				continue
			end

			if DailyShopRerolls == 0 then
				UpdateRestockButton("Red", Globals.FormatTime(nextDailyReroll - os.time(), false), Main.FreeRerolls)
			end

			Main.Restock.TextLabel.Text = `Restocks in: {Globals.FormatTime(ShopInData.NextRestock - os.time(), true)}`
		end
	end)
end

return ItemShops
