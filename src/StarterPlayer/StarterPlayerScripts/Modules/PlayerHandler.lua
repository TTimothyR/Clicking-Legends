local db = false

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = require(ReplicatedStorage.Framework.Network)
local DataSyncClient = require(script.Parent.DataSyncClient)

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

function PlayerHandler.Initialize()
	DataSyncClient.OnReady(function()
		Network:FireServer("ClientReady")
		ConnectButtons()
	end)
end

return PlayerHandler
