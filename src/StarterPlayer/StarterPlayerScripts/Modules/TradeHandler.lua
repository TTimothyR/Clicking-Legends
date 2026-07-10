local TradeHandler = {}
local db = false

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
local library = framework:WaitForChild("Library")
local classes = rs:WaitForChild("Classes")

local toggleButtonConnection = nil
local playerConnections = {}
local tradeConnections = {}
local timerConnection: RBXScriptConnection = nil
local activeRequestSender = nil
local acceptConnection = nil
local declineConnection = nil
local tradeRequestEndPos = UDim2.fromScale(0.5, 0.1)
local tradeRequestStartPos = UDim2.fromScale(0.5, -0.1)

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
local network = require(framework.Network)
local globals = require(framework.Globals)
local petStats = require(library.PetStats)
local menuHandler = require(script.Parent.MenuHandler)
local infoPopup = require(classes.InfoPopup)
local dataSync = require(script.Parent.DataSyncClient)

local function UpdateTradeButton(color: string, text: string, button)
	button.Frame.UIGradient.Color = globals.ButtonPresets[color].Gradient
	button.Frame.UIStroke.Color = globals.ButtonPresets[color].StrokeColor
	button.Title.UIStroke.Color = globals.ButtonPresets[color].StrokeColor
	button.Title.Text = text
end

local function CreatePlayerFrame(plr: Player)
	local profile = dataSync.GetOtherData(plr.UserId)
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

local function CreatePetButton(clone, holder, petData)
	clone.Parent = holder
	clone.Name = petData.id

	local rarity = petStats[petData.petName].Rarity
	clone.Frame.BackgroundColor3 = globals.RarityColors[rarity]
	if rarity == "Legendary" then
		clone.Glow.Visible = true
		clone.Frame.Legendary.Enabled = true
	end

	clone.Visible = true
	return clone
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
	for _, child: Instance in ipairs(mePets.ScrollingFrame:GetChildren()) do
		if child:IsA("ImageButton") then
			child:Destroy()
		end
	end
	for _, child: Instance in ipairs(youPets.ScrollingFrame:GetChildren()) do
		if child:IsA("ImageButton") then
			child:Destroy()
		end
	end
	for _, child: Instance in ipairs(meOffer.Pets:GetChildren()) do
		if child:IsA("ImageButton") then
			child:Destroy()
		end
	end
	for _, child: Instance in ipairs(youOffer.Pets:GetChildren()) do
		if child:IsA("ImageButton") then
			child:Destroy()
		end
	end
	for _, child: Instance in ipairs(meGifts.ScrollingFrame:GetChildren()) do
		if child:IsA("ImageButton") then
			child:Destroy()
		end
	end
	for _, child: Instance in ipairs(youGifts.ScrollingFrame:GetChildren()) do
		if child:IsA("ImageButton") then
			child:Destroy()
		end
	end

	for _, con: RBXScriptConnection in ipairs(tradeConnections) do
		if con.Connected then
			con:Disconnect()
		end
	end
	tradeConnections = {}
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
			meOffer.Pets:FindFirstChild(id):Destroy()
		else
			youOffer.Pets:FindFirstChild(id):Destroy()
		end
	elseif state == "Added" then
		local clone = offerTemplate:Clone() :: ImageButton
		clone.Name = id
		-- add the icon here
		clone.Frame.Legendary.Enabled = true

		if player == me then
			local clickConnection = clone.MouseButton1Click:Connect(function()
				if not db then
					db = true
					task.delay(0.15, function()
						db = false
					end)
					network:FireServer("ToggleGift", id, gamepassName)
				end
			end) :: RBXScriptConnection
			clone:GetPropertyChangedSignal("Parent"):Once(function()
				clickConnection:Disconnect()
			end)

			clone.Parent = meOffer.Pets
		else
			clone.Parent = youOffer.Pets
		end
	end
end

function TradeHandler.TogglePet(me: Player, data, state)
	if state == "Removed" then
		if player == me then
			meOffer.Pets:FindFirstChild(data.id):Destroy()
		else
			youOffer.Pets:FindFirstChild(data.id):Destroy()
		end
	elseif state == "Added" then
		local clone: ImageButton = offerTemplate:Clone()

		if player == me then
			clone = CreatePetButton(clone, meOffer.Pets, data)
			local clickCon: RBXScriptConnection
			clickCon = clone.MouseButton1Click:Connect(function()
				if not db then
					db = true
					task.delay(0.15, function()
						db = false
					end)
					network:FireServer("TogglePet", data.id)
					-- network:FireServer('Unready');
				end
			end)
			clone:GetPropertyChangedSignal("Parent"):Once(function()
				clickCon:Disconnect()
			end)
		else
			clone = CreatePetButton(clone, youOffer.Pets, data)
		end
	end
end

function TradeHandler.EnterTrade(_: Player, you: Player)
	-- local myProfile = network:InvokeServer('GetData');
	local yourProfile = dataSync.GetOtherData(you.UserId)
	local myPets = dataSync.Get("Pets")
	local yourPets = yourProfile.Pets
	local myGifts = dataSync.Get("Gifts")
	local yourGifts = yourProfile.Gifts

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
			local clone = petTemplate:Clone() :: ImageButton
			clone.Name = id
			-- Add the gamepass icon here
			clone.Frame.Legendary.Enabled = true
			clone.Parent = holder
			clone.Visible = true

			local clickConnection = clone.MouseButton1Click:Connect(function()
				if not db then
					db = true
					task.delay(0.15, function()
						db = false
					end)

					if clone.Parent == meGifts.ScrollingFrame then
						network:FireServer("ToggleGift", id, gamepassName)
					end
				end
			end)
			table.insert(tradeConnections, clickConnection)
		end
	end

	local function CreatePetButtons(inventory, holder)
		for _, petData in ipairs(inventory) do
			local clone: ImageButton = petTemplate:Clone()
			clone = CreatePetButton(clone, holder, petData)

			local clickCon: RBXScriptConnection
			clickCon = clone.MouseButton1Click:Connect(function()
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
			end)
			table.insert(tradeConnections, clickCon)
		end
	end

	local mePetsConnection = meButtonHolder.Pets.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)
			meGifts.Visible = false
			mePets.Visible = true
		end
	end) :: RBXScriptConnection
	local youPetsConnection = youButtonHolder.Pets.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)
			youGifts.Visible = false
			youPets.Visible = true
		end
	end) :: RBXScriptConnection
	local meGiftsConnection = meButtonHolder.Gifts.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)
			meGifts.Visible = true
			mePets.Visible = false
		end
	end) :: RBXScriptConnection
	local youGiftsConnection = youButtonHolder.Gifts.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)
			youGifts.Visible = true
			youPets.Visible = false
		end
	end) :: RBXScriptConnection
	table.insert(tradeConnections, mePetsConnection)
	table.insert(tradeConnections, youPetsConnection)
	table.insert(tradeConnections, meGiftsConnection)
	table.insert(tradeConnections, youGiftsConnection)

	local readyCon: RBXScriptConnection
	local unreadyCon: RBXScriptConnection
	local declineCon: RBXScriptConnection

	readyCon = tradeButtons.Ready.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)
			network:FireServer("Ready")
		end
	end)
	unreadyCon = tradeButtons.Unready.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)
			network:FireServer("Unready")
		end
	end)
	declineCon = tradeButtons.Decline.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)
			network:FireServer("DeclineTrade")
		end
	end)
	table.insert(tradeConnections, readyCon)
	table.insert(tradeConnections, unreadyCon)
	table.insert(tradeConnections, declineCon)

	CreatePetButtons(myPets, mePets.ScrollingFrame)
	CreatePetButtons(yourPets, youPets.ScrollingFrame)
	CreateGamepassButtons(myGifts, meGifts.ScrollingFrame)
	CreateGamepassButtons(yourGifts, youGifts.ScrollingFrame)

	menuHandler.handleOpenClose(tradeFrame)
end

function TradeHandler.UpdateTradeButtons()
	for _, child in ipairs(playerHolder:GetChildren()) do
		if child:IsA("Frame") then
			local playerName: string = child.Name
			local profile = dataSync.GetOtherData(players:FindFirstChild(playerName).UserId)

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

	acceptConnection = buttons.Accept.MouseButton1Click:Connect(function()
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
	declineConnection = buttons.Decline.MouseButton1Click:Connect(function()
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
			local tradeBanned = dataSync.GetOtherData(plr.UserId).TradeBanned
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

				playerConnections[child.Name]:Disconnect()
				playerConnections[child.Name] = nil
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
