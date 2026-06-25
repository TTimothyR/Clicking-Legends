local ShopHandler = {}
local db = false

-- Services
local players = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")
local mps = game:GetService("MarketplaceService")
local ts = game:GetService("TweenService")

local Classes = rs:WaitForChild("Classes")

-- Variables
repeat
	task.wait()
until players.LocalPlayer
local player: Player = players.LocalPlayer

local framework = rs:WaitForChild("Framework")
local library = framework:WaitForChild("Library")
local classes = rs:WaitForChild("Classes")

local gpConnections = {}

-- UI
local playerGui = player:WaitForChild("PlayerGui")
local frames = playerGui:WaitForChild("Frames")
local shopFrame = frames:WaitForChild("Shop")
local warningFrame = frames:WaitForChild("Warning")
local greyFrame = frames:WaitForChild("GreyFrame")
local infoFrame = frames:WaitForChild("Info")
local templates = shopFrame:WaitForChild("Templates")
local passTemplate = templates:WaitForChild("PassTemplate")
local gemsTemplate = templates:WaitForChild("GemsTemplate")
local main = shopFrame:WaitForChild("Main")
local holder = main:WaitForChild("Holder")
local scrollingHolder = holder:WaitForChild("ScrollingHolder")

local exclusivePetFrame = scrollingHolder:WaitForChild("ExclusivePets")

-- Modules
local dataSync = require(script.Parent.DataSyncClient)
local menuHandler = require(script.Parent.MenuHandler)
local inventoryHandler = require(script.Parent.InventoryHandler)
local rebirthHandler = require(script.Parent.RebirthHandler)
local shopStats = require(library.ShopStats)
local infoPopup = require(classes.InfoPopup)
local infMath = require(framework.InfiniteMath)
local WarningPopup = require(Classes:WaitForChild("WarningPopup"))

local function UpdateGamepasses(newData)
	for gpName, _ in pairs(newData) do
		local clone = scrollingHolder:FindFirstChild(gpName)
		if not clone then
			continue
		end
		for _, child in ipairs(clone.Inner.Buttons.Buy:GetChildren()) do
			child.Visible = (child.Name == "Owns")
		end
		clone.Inner.Buttons.Buy:SetAttribute("Scale", nil)
		if gpConnections[gpName] then
			gpConnections[gpName]:Disconnect()
		end
		-- clone.Inner.Buttons.Buy.PriceHolder.Title.Text = 'Owned';
	end
end

local function UpdateGemPacks(newRebirths)
	for _, child in ipairs(scrollingHolder:GetChildren()) do
		if string.match(child.Name, "GemPack") then
			child.Frame.Amount.Text = "+"
				.. infMath.new(newRebirths * shopStats.DeveloperProducts[child.Name].BaseGems):GetSuffix(true)
		end
	end
end

local function LoadShop()
	for gamepassName, data in pairs(shopStats.Gamepasses) do
		if data.GamepassID == nil then
			continue
		end
		local clone = passTemplate:Clone()
		clone.Name = gamepassName
		clone.Parent = scrollingHolder
		clone.LayoutOrder = data.LayoutOrder

		local s, info = pcall(function()
			return mps:GetProductInfoAsync(data.GamepassID, Enum.InfoType.GamePass)
		end)
		if s then
			clone.Inner.Buttons.Buy.PriceHolder.Title.Text = info.PriceInRobux or "???"
		end

		clone.Inner.PassName.Text = gamepassName
		clone.Inner.PassDescription.Text = data.Description
		-- clone.Icon.Image = to be done;

		gpConnections[gamepassName] = clone.Inner.Buttons.Buy.MouseButton1Click:Connect(function()
			if not db then
				db = true
				task.delay(0.15, function()
					db = false
				end)
				mps:PromptGamePassPurchase(player, data.GamepassID)
				ShopHandler.ShowGreyFrame()
			end
		end)
		clone.Inner.Buttons.Gift.MouseButton1Click:Connect(function()
			warn("clicked!")
			if not db then
				db = true
				task.delay(0.15, function()
					db = false
				end)
				WarningPopup.new(
					"Buy Gamepass Gift",
					`Are you sure you want to buy a {gamepassName} Gift? This gift will go into your inventory, which can be traded later on.`,
					function()
						mps:PromptProductPurchase(player, data.GiftingID)
					end,
					function()
						menuHandler.handleOpenClose(warningFrame)
					end,
					warningFrame
				)
				menuHandler.handleOpenClose(warningFrame)
			end
		end)

		clone.Visible = true
	end

	for productName, data in pairs(shopStats.DeveloperProducts) do
		if data.ProductID == nil then
			continue
		end

		local _, info = pcall(function()
			return mps:GetProductInfoAsync(data.ProductID, Enum.InfoType.Product)
		end)
		local clone
		if string.match(productName, "Pet") then
			if string.match(productName, "Combi") then
				clone = exclusivePetFrame.Inner.Bundle
				-- Pet images to be done
				clone.Buy.Discounted.Text = "" .. info.PriceInRobux
			else
				clone = exclusivePetFrame.Inner.Pets[productName]
				clone.PetName.Text = data.PetName
				-- clone.Icon.Image = to be done;
				clone.Buy.Price.Text = "" .. info.PriceInRobux
			end
		elseif string.match(productName, "Gem") then
			clone = gemsTemplate:Clone()
			clone.Parent = scrollingHolder
			clone.Name = productName
			clone.LayoutOrder = data.LayoutOrder
			clone.Frame.Buy.PriceHolder.Title.Text = info.PriceInRobux
			clone.Frame.Amount.Text = "+"
				.. infMath.new(dataSync.Get("Rebirths") * shopStats.DeveloperProducts[productName].BaseGems):GetSuffix(true)
			clone.Visible = true
		end

		local buyButton = clone:FindFirstChild("Buy", true)
		buyButton.MouseButton1Click:Connect(function()
			if not db then
				db = true
				task.delay(0.15, function()
					db = false
				end)
				mps:PromptProductPurchase(player, data.ProductID)
				ShopHandler.ShowGreyFrame()
			end
		end)
	end

	UpdateGamepasses(dataSync.Get("OwnedGamepasses"))
end

function ShopHandler.ShowGreyFrame()
	if greyFrame.Visible and greyFrame.BackgroundTransparency == 0.4 then
		return
	end

	greyFrame.Visible = true
	ts
		:Create(
			greyFrame,
			TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 0.4 }
		)
		:Play()
end

function ShopHandler.HideGreyFrame()
	if not greyFrame.Visible and greyFrame.BackgroundTransparency == 1 then
		return
	end

	local tween = ts:Create(
		greyFrame,
		TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 1 }
	)
	tween:Play()
	tween.Completed:Wait()
	greyFrame.Visible = false
end

function ShopHandler.PurchaseConfirmed()
	ShopHandler.HideGreyFrame()

	local targetFrame = menuHandler.activeFrame

	-- if not shopFrame.Visible then return end;

	infoPopup.new(nil, "Thank you for your purchase!", function()
		menuHandler.handleOpenClose(targetFrame)
	end, infoFrame)

	menuHandler.handleOpenClose(infoFrame)
end

function ShopHandler.Initialize()
	if not game.Loaded then
		game.Loaded:Wait()
	end

	inventoryHandler.ParseShopHandler(ShopHandler)

	dataSync.OnReady(function()
		LoadShop()
	end)

	dataSync.OnChanged("OwnedGamepasses", function(new, _)
		UpdateGamepasses(new)
	end)

	dataSync.OnChanged("Rebirths", function(new, _)
		UpdateGemPacks(new)
	end)

	rebirthHandler.ParseShopHandler(ShopHandler)
	-- task.spawn(function()
	--     while true do
	--         local tween1: Tween = ts:Create(shopFrame.Shine, TweenInfo.new(30, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {Rotation = 360});
	--         tween1:Play();
	--         tween1.Completed:Wait();
	--         shopFrame.Shine.Rotation = 0;
	--     end
	-- end)
end

return ShopHandler
