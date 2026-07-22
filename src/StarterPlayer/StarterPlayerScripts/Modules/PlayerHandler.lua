local db = false

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Upgrades = require(ReplicatedStorage.Framework.Library.Upgrades)
local Network = require(ReplicatedStorage.Framework.Network)
local DataSyncClient = require(script.Parent.DataSyncClient)

local player = Players.LocalPlayer

local baseSpeed = 16

local PlayerHandler = {}

local function ConnectButtons()
	for _, child in ipairs(workspace.Leaderboards:GetChildren()) do
		if child:IsA("Model") then
			local lbModel: Model = child :: Model

			local listHolder = lbModel:FindFirstChild("ListHolder") :: Part
			local surfaceGui = listHolder:FindFirstChild("GlobalLBGui") :: SurfaceGui

			local buttons = surfaceGui:FindFirstChild("Buttons") :: Frame
			local freeButton = buttons:FindFirstChild("F2PButton") :: TextButton | ImageButton
			local paidButton = buttons:FindFirstChild("P2WButton") :: TextButton | ImageButton

			local freeHolder = surfaceGui:FindFirstChild("F2PHolder") :: ScrollingFrame
			local paidHolder = surfaceGui:FindFirstChild("P2WHolder") :: ScrollingFrame

			freeButton.MouseButton1Click:Connect(function()
				if not db then
					db = true
					task.delay(0.15, function()
						db = false
					end)

					freeHolder.Visible = true
					paidHolder.Visible = false
				end
			end)
			paidButton.MouseButton1Click:Connect(function()
				if not db then
					db = true
					task.delay(0.15, function()
						db = false
					end)

					freeHolder.Visible = false
					paidHolder.Visible = true
				end
			end)
		end
	end
end

local function WalkspeedHandle(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	if not humanoid then
		return
	end

	humanoid.Died:Once(function()
		Network:FireServer("TPPlayer", false)
	end)

	local upgrades = DataSyncClient.Get("UpgradeLevels")
	local walkspeedLevel = upgrades["Faster Walkspeed"]

	humanoid.WalkSpeed = baseSpeed + (Upgrades["Faster Walkspeed"].Increment * walkspeedLevel)
end

function PlayerHandler.Initialize()
	DataSyncClient.OnReady(function()
		Network:FireServer("ClientReady")
		ConnectButtons()

		if player.Character then
			WalkspeedHandle(player.Character)
		end

		player.CharacterAdded:Connect(function(character: Model)
			WalkspeedHandle(character)
		end)
	end)

	DataSyncClient.OnChanged("UpgradeLevels", function(new, old)
		if new and old then
			if new["Faster Walkspeed"] ~= old["Faster Walkspeed"] then
				WalkspeedHandle(player.Character)
			end
		end
	end)

	task.spawn(function()
		while true do
			local success, _ = pcall(function()
				StarterGui:SetCore("ResetButtonCallback", false)
			end)

			if success then
				break
			end

			RunService.RenderStepped:Wait()
		end
	end)
end

return PlayerHandler
