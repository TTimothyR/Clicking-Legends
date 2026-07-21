local TradeHandler = {}
local db = false

-- Types
type InventoryConnections = { [string]: TemplateConnections }

type TemplateConnections = {
	ClickConnection: RBXScriptConnection?,
	TooltipConnections: { [number]: RBXScriptConnection },
}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")

-- Variables
repeat
	task.wait()
until players.LocalPlayer
local player: Player = players.LocalPlayer

local framework = rs:WaitForChild("Framework")
local library = framework:WaitForChild("Library")
local classes = rs:WaitForChild("Classes")

local templateConnections: TemplateConnections = {
	ClickConnection = nil,
	TooltipConnections = {},
}

local toggleButtonConnection = nil
local playerConnections = {}
local tradeConnections: InventoryConnections = {}
local tradeButtonConnections: { [number]: RBXScriptConnection } = {}
local timerConnection: RBXScriptConnection = nil
local activeRequestSender = nil
local acceptConnection = nil
local declineConnection = nil
local tradeRequestEndPos = UDim2.fromScale(0.5, 0.1)
local tradeRequestStartPos = UDim2.fromScale(0.5, -0.1)

local legendaryConnection: RBXScriptConnection = nil
local gradientsToAnimate = {}
local currentRotation: { value: number } = { value = 0 }
local animationLoaded = false :: boolean

local isPrivateServer = false
local canTrade = true
local tradeBannedMessage =
	"You are trade banned because duplicate pets have been detected in your inventory, delete pets indicated red and try again."
local privateServerMessage = "You cannot trade in a private server, please join a public server to trade."

-- UI
local playerGui = player:WaitForChild("PlayerGui")
local frames = playerGui:WaitForChild("Frames")
local infoFrame = frames:WaitForChild("Info")
local playerListFrame = frames:WaitForChild("PlayerList")
local templates = playerListFrame:WaitForChild("Templates")
local playerTemplate = templates:WaitForChild("PlayerTemplate")
local main = playerListFrame:WaitForChild("Main")
local toggleButton = main:WaitForChild("Toggle") :: ImageButton
local listFrame = main:WaitForChild("List")
local warningLabel = main:WaitForChild("WarningLabel")
local playerHolder = listFrame:WaitForChild("ScrollingFrame")

local tradeRequestFrame = frames:WaitForChild("TradeRequest")
local requestMain = tradeRequestFrame:WaitForChild("Main")
local tradeFrame = frames:WaitForChild("Trade")
local tradeTemplates = tradeFrame:WaitForChild("Templates")
local petTemplate = tradeTemplates:WaitForChild("PetTemplate")
local offerTemplate = tradeTemplates:WaitForChild("OfferTemplate")
local tradeMain = tradeFrame:WaitForChild("Main")
local timerLabel = tradeMain:WaitForChild("Timer")
local tradeButtons = tradeMain:WaitForChild("Buttons")
local youOffer = tradeMain:WaitForChild("YouOffer")
local youPets = tradeMain:WaitForChild("YouPets")
local meOffer = tradeMain:WaitForChild("MeOffer")
local mePets = tradeMain:WaitForChild("MePets")

local youButtons = tradeMain:WaitForChild("YouButtons")
local youButtonHolder = youButtons:WaitForChild("Holder")
local youGifts = tradeMain:WaitForChild("YouGifts")
local meButtons = tradeMain:WaitForChild("MeButtons")
local meButtonHolder = meButtons:WaitForChild("Holder")
local meGifts = tradeMain:WaitForChild("MeGifts")

-- Modules
local InterfaceUtility = require(ReplicatedStorage.Framework.InterfaceUtility)
local ImageService = require(ReplicatedStorage.Framework.Library.ImageService)
local network = require(framework.Network)
local globals = require(framework.Globals)
local petStats = require(library.PetStats)
local menuHandler = require(script.Parent.MenuHandler)
local infoPopup = require(classes.InfoPopup)
local dataSync = require(script.Parent.DataSyncClient)
local Tooltip = require(script.Parent.Tooltip)

local maximumTries = 7

local function UpdateTradeButton(color: string, text: string, button)
	button.Frame.UIGradient.Color = globals.ButtonPresets[color].Gradient
	button.Frame.UIStroke.Color = globals.ButtonPresets[color].StrokeColor
	button.Title.UIStroke.Color = globals.ButtonPresets[color].StrokeColor
	button.Title.Text = text
end

local function CreatePlayerFrame(plr: Player)
	local profile
	local tries = 0
	repeat
		profile = dataSync.GetOtherData(plr.UserId)
		if not profile then
			continue
		end
		tries += 1
		task.wait(0.01)
	until profile ~= nil or tries >= maximumTries

	if not profile then
		return
	end
	local clone = playerTemplate:Clone()
	clone.Parent = playerHolder
	clone.Name = plr.Name

	local inner = clone.Inner
	inner.PlayerName.Text = plr.Name
	clone.Visible = not profile.TradeBanned

	local clickCon: RBXScriptConnection
	clickCon = inner.Trade.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)
			network:FireServer("SendTradeRequest", plr)
		end
	end)
	playerConnections[plr.Name] = clickCon
end

local function CreatePetButton(clone, holder, petData): (Frame, { [number]: RBXScriptConnection })
	clone.Parent = holder
	clone.Name = petData.id

	clone.Click.Frame.Icon.Image = ImageService[petData.fullName] or ImageService["Placeholder"]

	local tooltipTbl = petData
	tooltipTbl.clicks = true
	tooltipTbl.gems = true
	tooltipTbl.ShowLevel = true
	tooltipTbl.reference = petData.id
	tooltipTbl.ShowExist = petStats[petData.petName].Secret
	tooltipTbl.FromTrade = true
	local tooltipConnections = Tooltip.SetupTooltip(clone.Click, "PetTooltip", petData)

	if petStats[petData.petName].Secret then
		clone.Click.Frame.SecretTag.Visible = true
	end

	local rarity = petStats[petData.petName].Rarity
	if petData.shiny then
		clone.Click.Glow.Visible = true
		clone.Click.Glow.Shiny.Enabled = true
		clone.Click.Frame.Shiny.Enabled = true
		clone.Click.Frame.Frame.Normal.Enabled = false
		clone.Click.Frame.Frame.Shiny.Enabled = true
		clone.Click.Frame.Icon.ShinyEffect.Visible = true

		local shinyCon = InterfaceUtility.CreateShinyEffect(clone.Click)
		clone:GetPropertyChangedSignal("Parent"):Once(function()
			shinyCon:Disconnect()
		end)

		if animationLoaded then
			table.insert(gradientsToAnimate, clone.Click.Glow.Shiny)
			table.insert(gradientsToAnimate, clone.Click.Frame.Shiny)
		end
	else
		clone.Click.Frame.BackgroundColor3 = globals.RarityColors[rarity]

		if rarity == "Legendary" then
			clone.Click.Glow.Visible = true
			clone.Click.Glow.Legendary.Enabled = true
			clone.Click.Frame.Legendary.Enabled = true

			if animationLoaded then
				table.insert(gradientsToAnimate, clone.Click.Glow.Legendary)
				table.insert(gradientsToAnimate, clone.Click.Frame.Legendary)
			end
		end
	end

	clone.Visible = true
	return clone, tooltipConnections
end

local function CleanUpRequestConnections()
	if acceptConnection then
		acceptConnection:Disconnect()
		acceptConnection = nil
	end
	if declineConnection then
		declineConnection:Disconnect()
		declineConnection = nil
	end
	activeRequestSender = nil
end

local function CleanUp()
	for _, template: TemplateConnections in pairs(tradeConnections) do
		if template.ClickConnection and template.ClickConnection.Connected then
			template.ClickConnection:Disconnect()
		end

		if template.TooltipConnections then
			for _, connection: RBXScriptConnection in ipairs(template.TooltipConnections) do
				if connection.Connected then
					connection:Disconnect()
				end
			end
		end
	end
	table.clear(tradeConnections)
	tradeConnections = {}
	for _, child: Instance in ipairs(mePets.ScrollingFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for _, child: Instance in ipairs(youPets.ScrollingFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for _, child: Instance in ipairs(meOffer.ScrollingFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for _, child: Instance in ipairs(youOffer.ScrollingFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for _, child: Instance in ipairs(meGifts.ScrollingFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for _, child: Instance in ipairs(youGifts.ScrollingFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for _, con: RBXScriptConnection in ipairs(tradeButtonConnections) do
		if con.Connected then
			con:Disconnect()
		end
	end
	table.clear(tradeButtonConnections)
	tradeButtonConnections = {}
end

local function StartLegendaryAnimations()
	globals.GetAnimatedGradients({
		mePets.ScrollingFrame,
		meGifts.ScrollingFrame,
		meOffer.ScrollingFrame,
		youPets.ScrollingFrame,
		youGifts.ScrollingFrame,
		youOffer.ScrollingFrame,
	}, gradientsToAnimate)

	legendaryConnection =
		InterfaceUtility.CreateGradientAnimation(gradientsToAnimate, currentRotation) :: RBXScriptConnection

	animationLoaded = true
end

function TradeHandler.DeclineTrade(me: Player)
	if player == me then
		infoPopup.new(nil, "You have declined the trade. Trade them again if this was a mistake!", function()
			menuHandler.handleOpenClose(infoFrame)
		end, infoFrame)
	else
		infoPopup.new(nil, "The other player has declined the trade. Trade them again if this was a mistake!", function()
			menuHandler.handleOpenClose(infoFrame)
		end, infoFrame)
	end

	menuHandler.handleOpenClose(infoFrame)
	CleanUp()
end

function TradeHandler.Ready(me: Player)
	if player == me then
		meOffer.Ready.Visible = true
		tradeButtons.Ready.Visible = false
		tradeButtons.Unready.Visible = true
	else
		youOffer.Ready.Visible = true
	end
end

function TradeHandler.Unready(me: Player)
	if player == me then
		meOffer.Ready.Visible = false
		tradeButtons.Ready.Visible = true
		tradeButtons.Unready.Visible = false
	else
		youOffer.Ready.Visible = false
	end
end

function TradeHandler.LockTrade()
	tradeButtons.Ready.Visible = false
	tradeButtons.Unready.Visible = false
	tradeButtons.Decline.Visible = false
end

function TradeHandler.TradeFinished()
	infoPopup.new(nil, "The trade has been completed.", function()
		menuHandler.handleOpenClose(infoFrame)
	end, infoFrame)

	menuHandler.handleOpenClose(infoFrame)
	CleanUp()
end

function TradeHandler.StartTimer(totalTime: number)
	timerLabel.Visible = true

	timerConnection = runService.RenderStepped:Connect(function(deltaTime)
		totalTime -= deltaTime

		if totalTime <= 0 then
			TradeHandler.StopTimer()
		end

		timerLabel.Text = totalTime .. "s"
	end)
end

function TradeHandler.StopTimer()
	timerLabel.Visible = false

	if timerConnection.Connected then
		timerConnection:Disconnect()
	end
end

function TradeHandler.ToggleGift(me: Player, id: string, gamepassName: string, state: string)
	if state == "Removed" then
		if player == me then
			meOffer.ScrollingFrame:FindFirstChild(id):Destroy()
		else
			youOffer.ScrollingFrame:FindFirstChild(id):Destroy()
		end
	elseif state == "Added" then
		local clone = offerTemplate:Clone() :: Frame
		clone.Name = id
		clone.Click.Frame.Icon.Image = ImageService[gamepassName] or ImageService["Placeholder"]
		clone.Click.Frame.Legendary.Enabled = true
		clone.Visible = true

		local tooltipConnections =
			Tooltip.SetupTooltip(clone.Click, "Gifts", { gamepassName = gamepassName, reference = id }) :: { [number]: RBXScriptConnection }

		if player == me then
			local clickConnection = clone.Click.MouseButton1Click:Connect(function()
				if not db then
					db = true
					task.delay(0.15, function()
						db = false
					end)
					network:FireServer("ToggleGift", id, gamepassName)
				end
			end) :: RBXScriptConnection

			clone.Parent = meOffer.ScrollingFrame
			clone:GetPropertyChangedSignal("Parent"):Once(function()
				clickConnection:Disconnect()
			end)
		else
			clone.Parent = youOffer.ScrollingFrame
		end
		clone:GetPropertyChangedSignal("Parent"):Once(function()
			for _, connection: RBXScriptConnection in ipairs(tooltipConnections) do
				if connection.Connected then
					connection:Disconnect()
				end
			end
			table.clear(tooltipConnections)
		end)
	end
end

function TradeHandler.TogglePet(me: Player, data, state)
	if state == "Removed" then
		if player == me then
			meOffer.ScrollingFrame:FindFirstChild(data.id):Destroy()
		else
			youOffer.ScrollingFrame:FindFirstChild(data.id):Destroy()
		end
	elseif state == "Added" then
		if player == me then
			local clone, tooltipConnections = CreatePetButton(offerTemplate:Clone(), meOffer.ScrollingFrame, data)
			local clickCon
			clickCon = clone.Click.MouseButton1Click:Connect(function()
				if not db then
					db = true
					task.delay(0.15, function()
						db = false
					end)
					network:FireServer("TogglePet", data.id)
					-- network:FireServer('Unready');
				end
			end) :: RBXScriptConnection
			clone:GetPropertyChangedSignal("Parent"):Once(function()
				clickCon:Disconnect()
				for _, connection: RBXScriptConnection in ipairs(tooltipConnections) do
					if connection.Connected then
						connection:Disconnect()
					end
				end
				table.clear(tooltipConnections)
			end)
		else
			local clone, tooltipConnections = CreatePetButton(offerTemplate:Clone(), youOffer.ScrollingFrame, data)
			clone:GetPropertyChangedSignal("Parent"):Once(function()
				for _, connection: RBXScriptConnection in ipairs(tooltipConnections) do
					if connection.Connected then
						connection:Disconnect()
					end
				end
				table.clear(tooltipConnections)
			end)
		end
	end
end

function TradeHandler.EnterTrade(_: Player, you: Player)
	-- local myProfile = network:InvokeServer("GetData")
	local yourProfile
	local tries = 0
	repeat
		yourProfile = dataSync.GetOtherData(you.UserId)
		if not yourProfile then
			continue
		end
		tries += 1
		task.wait(0.01)
	until yourProfile ~= nil or tries >= maximumTries

	if not yourProfile then
		network:FireServer("DeclineTrade")
		return
	end

	local myPets = dataSync.Get("Pets")
	local yourPets = yourProfile.Pets
	local myGifts = dataSync.Get("Gifts")
	local yourGifts = yourProfile.Gifts
	-- local yourPets = {}
	-- local yourGifts = {}

	table.sort(myPets, globals.SortPets)
	table.sort(yourPets, globals.SortPets)

	meOffer.Ready.Visible = false
	youOffer.Ready.Visible = false
	tradeButtons.Ready.Visible = true
	tradeButtons.Decline.Visible = true
	tradeButtons.Unready.Visible = false

	meGifts.Visible = false
	mePets.Visible = true
	youGifts.Visible = false
	youPets.Visible = true

	CleanUp()

	youPets.PlayerName.Text = you.Name .. "'s Inventory"
	youGifts.PlayerName.Text = you.Name .. "'s Inventory"
	youOffer.PlayerName.Text = you.Name .. "'s Offer"

	local function CreateGamepassButtons(inventory, holder)
		for id, gamepassName in pairs(inventory) do
			local clone = petTemplate:Clone() :: Frame
			clone.Name = id
			clone.Click.Frame.Legendary.Enabled = true
			clone.Click.Glow.Legendary.Enabled = true
			clone.Click.Frame.Icon.Image = ImageService[gamepassName] or ImageService["Placeholder"]
			if animationLoaded then
				table.insert(gradientsToAnimate, clone.Click.Glow.Legendary)
				table.insert(gradientsToAnimate, clone.Click.Frame.Legendary)
			end
			clone.Parent = holder
			clone.Visible = true

			local tooltipConnections = Tooltip.SetupTooltip(
				clone.Click,
				"Gifts",
				{ gamepassName = gamepassName, reference = id }
			) :: { [number]: RBXScriptConnection }

			local clickConnection = clone.Click.MouseButton1Click:Connect(function()
				if not db then
					db = true
					task.delay(0.15, function()
						db = false
					end)

					if clone.Parent == meGifts.ScrollingFrame then
						network:FireServer("ToggleGift", id, gamepassName)
					end
				end
			end) :: RBXScriptConnection

			if not tradeConnections[id] then
				tradeConnections[id] = templateConnections
			end

			tradeConnections[id].ClickConnection = clickConnection
			tradeConnections[id].TooltipConnections = tooltipConnections
		end
	end

	local function CreatePetButtons(inventory, holder)
		for _, petData in ipairs(inventory) do
			local clone, tooltipConnections = CreatePetButton(petTemplate:Clone(), holder, petData)

			local clickCon = clone.Click.MouseButton1Click:Connect(function()
				if not db then
					db = true
					task.delay(0.15, function()
						db = false
					end)
					if clone.Parent == mePets.ScrollingFrame then
						network:FireServer("TogglePet", petData.id)
						-- network:FireServer('Unready');
					end
				end
			end) :: RBXScriptConnection

			if not tradeConnections[petData.id] then
				tradeConnections[petData.id] = templateConnections
			end

			tradeConnections[petData.id].ClickConnection = clickCon
			tradeConnections[petData.id].TooltipConnections = tooltipConnections
		end
	end

	local mePetsConnection = meButtonHolder.Pets.Click.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)
			meGifts.Visible = false
			mePets.Visible = true
		end
	end) :: RBXScriptConnection
	local youPetsConnection = youButtonHolder.Pets.Click.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)
			youGifts.Visible = false
			youPets.Visible = true
		end
	end) :: RBXScriptConnection
	local meGiftsConnection = meButtonHolder.Gifts.Click.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)
			meGifts.Visible = true
			mePets.Visible = false
		end
	end) :: RBXScriptConnection
	local youGiftsConnection = youButtonHolder.Gifts.Click.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)
			youGifts.Visible = true
			youPets.Visible = false
		end
	end) :: RBXScriptConnection
	table.insert(tradeButtonConnections, mePetsConnection)
	table.insert(tradeButtonConnections, youPetsConnection)
	table.insert(tradeButtonConnections, meGiftsConnection)
	table.insert(tradeButtonConnections, youGiftsConnection)

	local readyCon: RBXScriptConnection
	local unreadyCon: RBXScriptConnection
	local declineCon: RBXScriptConnection

	readyCon = tradeButtons.Ready.Click.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)
			network:FireServer("Ready")
		end
	end)
	unreadyCon = tradeButtons.Unready.Click.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)
			network:FireServer("Unready")
		end
	end)
	declineCon = tradeButtons.Decline.Click.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)
			network:FireServer("DeclineTrade")
		end
	end)
	table.insert(tradeButtonConnections, readyCon)
	table.insert(tradeButtonConnections, unreadyCon)
	table.insert(tradeButtonConnections, declineCon)

	CreatePetButtons(myPets, mePets.ScrollingFrame)
	CreatePetButtons(yourPets, youPets.ScrollingFrame)
	CreateGamepassButtons(myGifts, meGifts.ScrollingFrame)
	CreateGamepassButtons(yourGifts, youGifts.ScrollingFrame)

	menuHandler.handleOpenClose(tradeFrame, StartLegendaryAnimations)
end

function TradeHandler.UpdateTradeButtons()
	for _, child in ipairs(playerHolder:GetChildren()) do
		if child:IsA("Frame") then
			local playerName: string = child.Name
			local profile
			local tries = 0
			repeat
				local tradePlayer = players:FindFirstChild(playerName)
				if not tradePlayer then
					continue
				end
				profile = dataSync.GetOtherData(players:FindFirstChild(playerName).UserId)
				if not profile then
					continue
				end
				tries += 1
				task.wait(0.01)
			until profile ~= nil or tries >= maximumTries

			if not profile then
				continue
			end

			if profile.TradeBanned then
				continue
			else
				if not child.Visible then
					child.Visible = true
				end
			end

			if profile.IsInTrade then
				UpdateTradeButton("Red", "Busy", child.Inner.Trade)
			elseif profile.HasTradingDisabled then
				UpdateTradeButton("Purple", "Disabled", child.Inner.Trade)
			elseif profile.TradeRequestFrom == player.Name then
				UpdateTradeButton("Orange", "Pending", child.Inner.Trade)
			else
				UpdateTradeButton("Green", "Send", child.Inner.Trade)
			end
		end
	end
end

function TradeHandler.HideTradeRequest()
	local frameTime = 0.2

	if tradeRequestFrame.Position == tradeRequestEndPos then
		tradeRequestFrame:TweenPosition(tradeRequestStartPos, Enum.EasingDirection.In, Enum.EasingStyle.Back, frameTime)
	end

	CleanUpRequestConnections()
end

function TradeHandler.TradeRequest(tradeSender: Player)
	if not canTrade then
		network:FireServer("RequestAnswer", tradeSender, false)
	end
	local frameTime = 0.2
	local function ShowUI()
		tradeRequestFrame:TweenPosition(tradeRequestEndPos, Enum.EasingDirection.Out, Enum.EasingStyle.Back, frameTime)
	end

	CleanUpRequestConnections()
	activeRequestSender = tradeSender

	local image, ready =
		players:GetUserThumbnailAsync(tradeSender.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
	requestMain.Title.Text = tradeSender.Name .. " sent you a trade request!"
	requestMain.PlayerImg.Image = ready and image or ""
	ShowUI()

	local buttons = requestMain.Buttons

	acceptConnection = buttons.Accept.Click.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)
			local sender = activeRequestSender
			TradeHandler.HideTradeRequest()
			network:FireServer("RequestAnswer", sender, true)
		end
	end)
	declineConnection = buttons.Decline.Click.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)
			local sender = activeRequestSender
			TradeHandler.HideTradeRequest()
			network:FireServer("RequestAnswer", sender, false)
		end
	end)
end

local function LoadPlayerList()
	for _, plr: Player in ipairs(players:GetPlayers()) do
		if playerHolder:FindFirstChild(plr.Name) then
			local profile
			local tries = 0
			repeat
				profile = dataSync.GetOtherData(plr.UserId)
				if not profile then
					continue
				end
				tries += 1
				task.wait(0.01)
			until profile ~= nil or tries >= maximumTries

			if not profile then
				continue
			end

			local tradeBanned = profile.TradeBanned
			playerHolder:FindFirstChild(plr.Name).Visible = not tradeBanned
			continue
		end
		if plr ~= player then
			CreatePlayerFrame(plr)
		end
	end
	for _, child: Instance in ipairs(playerHolder:GetChildren()) do
		if child:IsA("Frame") then
			if not players:FindFirstChild(child.Name) then
				child:Destroy()

				if playerConnections[child.Name] then
					if playerConnections[child.Name].Connected then
						playerConnections[child.Name]:Disconnect()
					end
					playerConnections[child.Name] = nil
				end
			end
		end
	end

	if not toggleButtonConnection or not toggleButtonConnection.Connected then
		toggleButtonConnection = toggleButton.MouseButton1Click:Connect(function()
			if not db then
				db = true
				task.delay(0.15, function()
					db = false
				end)

				local newStatus = not network:InvokeServer("ToggleTrading")

				if newStatus then
					UpdateTradeButton("Green", "On", toggleButton)
				else
					UpdateTradeButton("Red", "Off", toggleButton)
				end
			end
		end) :: RBXScriptConnection
	end
end

function TradeHandler.Initialize()
	if not game.Loaded then
		game.Loaded:Wait()
	end

	isPrivateServer = network:InvokeServer("GetPrivateServerStatus")

	tradeFrame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not tradeFrame.Visible then
			if legendaryConnection.Connected then
				legendaryConnection:Disconnect()
				table.clear(gradientsToAnimate)
				animationLoaded = false
			end
		end
	end)

	dataSync.OnReady(function()
		local tradeBanned = dataSync.Get("TradeBanned")

		if tradeBanned then
			canTrade = false
		end

		local tradingEnabled = not dataSync.Get("HasTradingDisabled")
		if tradingEnabled then
			UpdateTradeButton("Green", "On", toggleButton)
		else
			UpdateTradeButton("Red", "Off", toggleButton)
		end

		if tradeBanned or isPrivateServer then
			listFrame.Visible = false
			warningLabel.Visible = true

			if tradeBanned then
				warningLabel.Text = tradeBannedMessage
			elseif isPrivateServer then
				warningLabel.Text = privateServerMessage
			end
		end
	end)

	task.spawn(LoadPlayerList)

	dataSync.OnChanged("TradeBanned", function(new, _)
		if isPrivateServer then
			return
		end
		listFrame.Visible = not new
		warningLabel.Visible = new

		if new then
			warningLabel.Text = tradeBannedMessage
			canTrade = false
		end
	end)

	players.PlayerAdded:Connect(function(_)
		task.spawn(LoadPlayerList)
	end)
	players.PlayerRemoving:Connect(function(_, _)
		task.spawn(LoadPlayerList)
	end)
end

return TradeHandler
