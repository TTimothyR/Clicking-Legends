local ActivationHandler = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local InfoPopup = require(ReplicatedStorage.Classes.InfoPopup)
local WarningPopup = require(ReplicatedStorage.Classes.WarningPopup)
local InfiniteMath = require(ReplicatedStorage.Framework.InfiniteMath)
local ItemShopModule = require(ReplicatedStorage.Framework.Library.ItemShopModule)
local Worlds = require(ReplicatedStorage.Framework.Library.Worlds)
local Network = require(ReplicatedStorage.Framework.Network)
local DataSyncClient = require(script.Parent.DataSyncClient)
local ItemShops = require(script.Parent.ItemShops)
local MenuHandler = require(script.Parent.MenuHandler)

local activators = workspace:WaitForChild("Activations")
local uiActivators = activators:WaitForChild("UIActivators")
local teleportActivators = activators:WaitForChild("TeleportActivators")
local claimActivators = activators:WaitForChild("ClaimActivators")

local player = Players.LocalPlayer
local playerGui = player.PlayerGui :: PlayerGui

local frames = playerGui:WaitForChild("Frames")
local warningFrame = frames:WaitForChild("Warning") :: Frame
local infoFrame = frames:WaitForChild("Info") :: Frame
local itemShopFrame = frames:WaitForChild("ItemShop") :: Frame

local uiActivations: { [Part]: GuiObject } = {}
local teleportActivations: { [Part]: Part } = {}
local claimActivations: { [Part]: ModuleScript } = {}

local visibleFrame = nil
local isTeleporting = false
local activeTriggers = {}
local triggerAddedSignal = Instance.new("BindableEvent")

local function StarterToPlayer(starterInstance)
	local names = {}
	local current = starterInstance

	while current and current ~= StarterGui do
		table.insert(names, 1, current.Name)
		current = current.Parent
	end

	local target = playerGui
	for _, name in ipairs(names) do
		target = target:FindFirstChild(name)
		if not target then
			return nil
		end
	end

	return target
end

local function GetObjectValueAsync(objectValue: ObjectValue): Instance?
	local target = objectValue.Value
	if not target then
		local startTime = os.clock()

		while not objectValue.Value and (os.clock() - startTime) < 5 do
			task.wait(0.1)
		end
		target = objectValue.Value
	end
	return target
end

local function RegisterClaimActivator(claimActivator: Model)
	local targetModuleValue = claimActivator:WaitForChild("TargetModule", 5) :: ObjectValue?
	local triggerPart = claimActivator:WaitForChild("Trigger", 5) :: Part?

	if not targetModuleValue or not triggerPart then
		return
	end

	local targetModule = GetObjectValueAsync(targetModuleValue)
	if targetModule then
		claimActivations[triggerPart] = targetModule :: ModuleScript
		table.insert(activeTriggers, triggerPart)
		triggerAddedSignal:Fire()
	end
end

local function RegisterUIActivator(uiActivator: Model)
	local targetFrameValue = uiActivator:WaitForChild("TargetFrame", 5) :: ObjectValue?
	local triggerPart = uiActivator:WaitForChild("Trigger", 5) :: Part?

	if not targetFrameValue or not triggerPart then
		return
	end

	local targetFrame = GetObjectValueAsync(targetFrameValue)
	if targetFrame then
		local playerFrame = StarterToPlayer(targetFrame)
		if playerFrame then
			uiActivations[triggerPart] = playerFrame
			table.insert(activeTriggers, triggerPart)
			triggerAddedSignal:Fire()
		end
	end
end

local function RegisterTeleportActivator(teleportActivator: Model)
	local targetPartValue = teleportActivator:WaitForChild("TargetPart", 5) :: ObjectValue?
	local triggerPart = teleportActivator:WaitForChild("Trigger", 5) :: Part?

	if not targetPartValue or not triggerPart then
		return
	end

	local targetPart = GetObjectValueAsync(targetPartValue)
	if targetPart then
		teleportActivations[triggerPart] = targetPart :: Part
		table.insert(activeTriggers, triggerPart)
		triggerAddedSignal:Fire()
	end
end

local function UIActivatorTriggered(result)
	if visibleFrame ~= uiActivations[result.Instance] then
		if ItemShopModule.Shops[result.Instance.Parent.Name] then
			visibleFrame = itemShopFrame
			ItemShops.DisplayShop(result.Instance.Parent.Name)
		else
			visibleFrame = uiActivations[result.Instance]
			MenuHandler.handleOpenClose(uiActivations[result.Instance])
		end
	end
end

local function TeleportActivatorTriggered(result)
	if not isTeleporting then
		isTeleporting = true
		local worldName = result.Instance.Parent.Name
		local ownedWorlds = DataSyncClient.Get("OwnedWorlds")
		local clicks = DataSyncClient.Get("Clicks")

		if not ownedWorlds or not clicks then
			isTeleporting = false
			return
		end

		if not ownedWorlds[worldName] then
			if clicks < InfiniteMath.new(Worlds[worldName].Requirement) then
				InfoPopup.new(nil, "You do not have enough Clicks to purchase this world.", function()
					MenuHandler.handleOpenClose(infoFrame)
				end, infoFrame)
				MenuHandler.handleOpenClose(infoFrame)
				visibleFrame = infoFrame
				infoFrame:GetPropertyChangedSignal("Visible"):Once(function()
					isTeleporting = false
				end)
			else
				WarningPopup.new(
					nil,
					`Do you want to buy {result.Instance.Parent.Name} world for {InfiniteMath.new(Worlds[worldName].Requirement)
						:GetSuffix(true)} Clicks?`,
					function()
						MenuHandler.handleOpenClose(warningFrame)
						local success = Network:InvokeServer("BuyWorld", worldName)
						if success then
							Network:FireServer("Teleport", worldName)
						end
					end,
					function()
						MenuHandler.handleOpenClose(warningFrame)
					end,
					warningFrame
				)
				MenuHandler.handleOpenClose(warningFrame)
				visibleFrame = warningFrame
				warningFrame:GetPropertyChangedSignal("Visible"):Once(function()
					isTeleporting = false
				end)
			end
		else
			Network:FireServer("Teleport", worldName)
			isTeleporting = false
		end
	end
end

local function ClaimActivatorTriggered(result)
	print(result.Instance.Parent.Name)
end

local function OnCharacterAdded(character: Model)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = activeTriggers

	local triggerAddedConnection = triggerAddedSignal.Event:Connect(function()
		raycastParams.FilterDescendantsInstances = activeTriggers
	end) :: RBXScriptConnection

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid

	local connection = RunService.Heartbeat:Connect(function()
		if not character then
			return
		end

		local humanoidRoot = character:FindFirstChild("HumanoidRootPart")
		if not humanoidRoot then
			return
		end

		local result = workspace:Raycast(humanoidRoot.Position, Vector3.new(0, -20, 0), raycastParams)
		if not result then
			if visibleFrame then
				task.spawn(MenuHandler.handleOpenClose, visibleFrame)
				visibleFrame = nil
			end
		else
			if uiActivations[result.Instance] then
				UIActivatorTriggered(result)
			elseif teleportActivations[result.Instance] then
				TeleportActivatorTriggered(result)
			elseif claimActivations[result.Instance] then
				ClaimActivatorTriggered(result)
			end
		end
	end)

	humanoid.Died:Once(function()
		connection:Disconnect()
		triggerAddedConnection:Disconnect()

		if visibleFrame then
			task.spawn(MenuHandler.handleOpenClose, visibleFrame)
			visibleFrame = nil
		end
	end)
end

function ActivationHandler.Initialize()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end

	for _, claimActivator in ipairs(claimActivators:GetChildren()) do
		task.spawn(RegisterClaimActivator, claimActivator)
	end
	claimActivators.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Model") then
			RegisterClaimActivator(child)
		end
	end)

	for _, uiActivator: Model in ipairs(uiActivators:GetChildren()) do
		task.spawn(RegisterUIActivator, uiActivator)
	end
	uiActivators.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Model") then
			RegisterUIActivator(child)
		end
	end)
	for _, teleportActivator: Model in ipairs(teleportActivators:GetChildren()) do
		task.spawn(RegisterTeleportActivator, teleportActivator)
	end
	teleportActivators.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Model") then
			RegisterTeleportActivator(child)
		end
	end)

	-- for _, uiActivator: Model in ipairs(uiActivators:GetChildren()) do
	-- 	local targetFrame: ObjectValue = uiActivator:FindFirstChild("TargetFrame") :: ObjectValue
	-- 	local triggerPart = uiActivator:FindFirstChild("Trigger") :: Part
	-- 	uiActivations[triggerPart] = StarterToPlayer(targetFrame.Value)
	-- end
	-- for _, teleportActivator: Model in ipairs(teleportActivators:GetChildren()) do
	-- 	local targetPart: ObjectValue = teleportActivator:FindFirstChild("TargetPart") :: ObjectValue
	-- 	local triggerPart = teleportActivator:FindFirstChild("Trigger") :: Part
	-- 	teleportActivations[triggerPart] = targetPart.Value :: Part
	-- end
	if player.Character then
		OnCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(function(character: Model)
		OnCharacterAdded(character)
	end)
end

return ActivationHandler
