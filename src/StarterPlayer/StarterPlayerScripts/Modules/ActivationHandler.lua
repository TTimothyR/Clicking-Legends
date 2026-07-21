local ActivationHandler = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local InfoPopup = require(ReplicatedStorage.Classes.InfoPopup)
local WarningPopup = require(ReplicatedStorage.Classes.WarningPopup)
local InfiniteMath = require(ReplicatedStorage.Framework.InfiniteMath)
local Worlds = require(ReplicatedStorage.Framework.Library.Worlds)
local Network = require(ReplicatedStorage.Framework.Network)
local DataSyncClient = require(script.Parent.DataSyncClient)
local MenuHandler = require(script.Parent.MenuHandler)

local activators = workspace:WaitForChild("Activations")
local uiActivators = activators:WaitForChild("UIActivators")
local teleportActivators = activators:WaitForChild("TeleportActivators")

local player = Players.LocalPlayer
local playerGui = player.PlayerGui :: PlayerGui

local frames = playerGui:WaitForChild("Frames")
local warningFrame = frames:WaitForChild("Warning") :: Frame
local infoFrame = frames:WaitForChild("Info") :: Frame

local uiActivations: { [Part]: GuiObject } = {}
local teleportActivations: { [Part]: Part } = {}

local visibleFrame = nil
local isTeleporting = false

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

local function OnCharacterAdded(character: Model)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	local includeTable = {}
	for part, _ in pairs(uiActivations) do
		table.insert(includeTable, part)
	end
	for part, _ in pairs(teleportActivations) do
		table.insert(includeTable, part)
	end
	raycastParams.FilterDescendantsInstances = includeTable

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
				if visibleFrame ~= uiActivations[result.Instance] then
					visibleFrame = uiActivations[result.Instance]
					MenuHandler.handleOpenClose(uiActivations[result.Instance])
				end
			elseif teleportActivations[result.Instance] then
				if not isTeleporting then
					isTeleporting = true
					local worldName = result.Instance.Parent.Name
					local ownedWorlds = DataSyncClient.Get("OwnedWorlds")
					if not ownedWorlds[worldName] then
						local clicks = DataSyncClient.Get("Clicks")

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
		end
	end)

	humanoid.Died:Once(function()
		connection:Disconnect()

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

	for _, uiActivator: Model in ipairs(uiActivators:GetChildren()) do
		local targetFrame: ObjectValue = uiActivator:FindFirstChild("TargetFrame") :: ObjectValue
		local triggerPart = uiActivator:FindFirstChild("Trigger") :: Part
		uiActivations[triggerPart] = StarterToPlayer(targetFrame.Value)
	end
	for _, teleportActivator: Model in ipairs(teleportActivators:GetChildren()) do
		local targetPart: ObjectValue = teleportActivator:FindFirstChild("TargetPart") :: ObjectValue
		local triggerPart = teleportActivator:FindFirstChild("Trigger") :: Part
		teleportActivations[triggerPart] = targetPart.Value :: Part
	end
	if player.Character then
		OnCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(function(character: Model)
		OnCharacterAdded(character)
	end)
end

return ActivationHandler
