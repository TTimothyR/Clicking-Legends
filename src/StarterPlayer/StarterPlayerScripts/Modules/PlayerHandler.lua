local db = false

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Upgrades = require(ReplicatedStorage.Framework.Library.Upgrades)
local Network = require(ReplicatedStorage.Framework.Network)
local DataSyncClient = require(script.Parent.DataSyncClient)

local player = Players.LocalPlayer

local baseSpeed = 25

local PlayerHandler = {}

local function ConnectButtons()
	for _, child in ipairs(workspace.Leaderboards:GetChildren()) do
		if child:IsA("Model") then
			local lbModel: Model = child :: Model

			local listHolder = lbModel:WaitForChild("ListHolder") :: Part
			local surfaceGui = listHolder:WaitForChild("GlobalLBGui") :: SurfaceGui

			local buttons = surfaceGui:WaitForChild("Buttons") :: Frame
			local freeButton = buttons:WaitForChild("F2PButton") :: TextButton | ImageButton
			local paidButton = buttons:WaitForChild("P2WButton") :: TextButton | ImageButton

			local freeHolder = surfaceGui:WaitForChild("F2PHolder") :: ScrollingFrame
			local paidHolder = surfaceGui:WaitForChild("P2WHolder") :: ScrollingFrame

			freeButton.Click.MouseButton1Click:Connect(function()
				if not db then
					db = true
					task.delay(0.15, function()
						db = false
					end)

					freeHolder.Visible = true
					paidHolder.Visible = false
				end
			end)
			paidButton.Click.MouseButton1Click:Connect(function()
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

	humanoid.Died:Connect(function()
		Network:FireServer("TPPlayer", false)
	end)

	local upgrades = DataSyncClient.Get("UpgradeLevels")
	local walkspeedLevel = upgrades["Faster Walkspeed"]

	if walkspeedLevel == nil then
		humanoid.WalkSpeed = baseSpeed
	else
		humanoid.WalkSpeed = baseSpeed + (Upgrades["Faster Walkspeed"].Increment * walkspeedLevel)
	end
end

function PlayerHandler.Initialize()
	DataSyncClient.OnReady(function()
		Network:FireServer("ClientReady")
		ConnectButtons()

		local lowDetail = DataSyncClient.Get("Settings").LowDetail
		if lowDetail then
			task.spawn(function()
				for _, child in ipairs(game:GetDescendants()) do
					if child:IsA("ParticleEmitter") then
						child.Enabled = false
					elseif child:IsA("Part") or child:IsA("MeshPart") then
						child.CastShadow = false
					end
				end
			end)
		end

		if player.Character then
			WalkspeedHandle(player.Character)
		end

		player.CharacterAdded:Connect(function(character: Model)
			WalkspeedHandle(character)
		end)
	end)

	DataSyncClient.OnChanged("Settings", function(new, _)
		if new.LowDetail == true then
			task.spawn(function()
				for _, child in ipairs(game:GetDescendants()) do
					if child:IsA("ParticleEmitter") then
						child.Enabled = false
					elseif child:IsA("Part") or child:IsA("MeshPart") then
						child.CastShadow = false
					end
				end
			end)
		end
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
