local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Framework = ReplicatedStorage:WaitForChild("Framework")

local Library = Framework:WaitForChild("Library")
local ActivationsHandler = {}

local ActivationsFolder = workspace:WaitForChild("Activations")

local Player = Players.LocalPlayer
local PlayerGui = Player.PlayerGui

local ItemShopModule = require(Library:WaitForChild("ItemShopModule"))
local Frames = PlayerGui:WaitForChild("Frames")
local MenuHandler = require("./MenuHandler")
local ItemShops = require("./ItemShops")

local DB = false
local Activations = {}

function ActivationsHandler.Initialize()
	for _, v in pairs(ActivationsFolder:GetChildren()) do
		if v:IsA("Model") then
			--if not Frames:FindFirstChild(v.Name) then continue end
			Activations[v.Name] = v
		end
	end

	for i, v in pairs(Activations) do
		local Root = v:WaitForChild("Root")
		if not Root then
			continue
		end

		Root.Touched:Connect(function(hit)
			if hit.Parent ~= Player.Character then
				return
			end
			if DB then
				return
			end
			DB = true
			task.delay(2, function()
				DB = false
			end)

			if ItemShopModule.Shops[i] then
				ItemShops.DisplayShop(i)
			else
				if Frames:FindFirstChild(i) then
					if Frames:FindFirstChild(i).Visible == true then
						return
					end
					MenuHandler.openFrame(Frames:FindFirstChild(i))
				else
					warn("(ActivationHandler): No frame found for " .. i)
				end
			end
		end)
	end
end

return ActivationsHandler
