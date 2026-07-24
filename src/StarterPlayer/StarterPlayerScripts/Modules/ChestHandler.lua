local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Globals = require(ReplicatedStorage.Framework.Globals)
local Chests = require(ReplicatedStorage.Framework.Library.Chests)
local DataSyncClient = require(script.Parent.DataSyncClient)

local activations = workspace:WaitForChild("Activations")
local claimActivators = activations:WaitForChild("ClaimActivators")
local ChestHandler = {}

local connections = {}

local function CreateChestTimer(chestName, label: TextLabel, availableTimestamp)
	if connections[chestName] then
		return
	end
	local timerConnection

	timerConnection = RunService.Heartbeat:Connect(function(_: number)
		if availableTimestamp - os.time() > 0 then
			label.Text = Globals.FormatTime((availableTimestamp - os.time()), true)
		else
			timerConnection:Disconnect()
			connections[chestName] = nil
			label.Text = "Ready to claim!"
		end
	end)

	connections[chestName] = timerConnection
end

local function InitiateChests()
	local playerChests = DataSyncClient.Get("Chests")
	for chestName, data in pairs(Chests) do
		local model = claimActivators:WaitForChild(chestName, 5)

		if not model then
			continue
		end

		local uiPart = model:WaitForChild("Part")
		local billboard = uiPart:WaitForChild("BillboardGui")
		local holder = billboard:WaitForChild("Frame")

		if not playerChests[chestName] then
			holder.RespawnTime.Text = "Ready to claim!"
			continue
		end

		local lastClaimed = playerChests[chestName].LastClaimed

		if lastClaimed + data.RespawnTime < os.time() then
			holder.RespawnTime.Text = "Ready to claim!"
		else
			CreateChestTimer(chestName, holder.RespawnTime, (lastClaimed + data.RespawnTime))
		end
	end
end

function ChestHandler.Initialize()
	DataSyncClient.OnReady(function()
		InitiateChests()
	end)
	DataSyncClient.OnChanged("Chests", function(_, _)
		InitiateChests()
	end)
end

return ChestHandler
