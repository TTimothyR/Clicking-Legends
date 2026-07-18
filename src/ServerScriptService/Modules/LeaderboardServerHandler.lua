local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local UserService = game:GetService("UserService")
local Workspace = game:GetService("Workspace")
local InfiniteMath = require(ReplicatedStorage.Framework.InfiniteMath)
local ImageService = require(ReplicatedStorage.Framework.Library.ImageService)
local PlayerData = require(ServerScriptService.DataModules.PlayerData)

local leaderboardModels = Workspace:WaitForChild("Leaderboards") :: Folder
local templates = leaderboardModels:WaitForChild("Templates") :: Folder

local goldTemplate = templates:WaitForChild("GoldTemplate") :: Frame
local silverTemplate = templates:WaitForChild("SilverTemplate") :: Frame
local bronzeTemplate = templates:WaitForChild("BronzeTemplate") :: Frame
local template = templates:WaitForChild("Template") :: Frame

local nameTagTemplate = script:WaitForChild("NameTag") :: BillboardGui

local refreshTime = 10 * 60

local playerReady: { [Player]: boolean } = {}

local LeaderboardHandler = {}

type Leaderboard = {
	FreeStore: OrderedDataStore,
	PaidStore: OrderedDataStore,
	Model: Model,
	LookUp: { Free: { [string]: number }, Paid: { [string]: number } },
	IsInfMath: boolean,
}

local leaderboards = {
	TotalClicks = {
		FreeStore = DataStoreService:GetOrderedDataStore("Clicks_F2P"),
		PaidStore = DataStoreService:GetOrderedDataStore("Clicks_P2W"),
		Model = leaderboardModels:WaitForChild("Clicks"),
		LookUp = { Free = {}, Paid = {} },
		IsInfMath = true,
	},
	Eggs = {
		FreeStore = DataStoreService:GetOrderedDataStore("Eggs_F2P"),
		PaidStore = DataStoreService:GetOrderedDataStore("Eggs_P2W"),
		Model = leaderboardModels:WaitForChild("Eggs"),
		LookUp = { Free = {}, Paid = {} },
		IsInfMath = false,
	},
	Rebirths = {
		FreeStore = DataStoreService:GetOrderedDataStore("Rebirths_F2P"),
		PaidStore = DataStoreService:GetOrderedDataStore("Rebirths_P2W"),
		Model = leaderboardModels:WaitForChild("Rebirths"),
		LookUp = { Free = {}, Paid = {} },
		IsInfMath = true,
	},
	Playtime = {
		FreeStore = DataStoreService:GetOrderedDataStore("Playtime_F2P"),
		PaidStore = DataStoreService:GetOrderedDataStore("Playtime_P2W"),
		Model = leaderboardModels:WaitForChild("Playtime"),
		LookUp = { Free = {}, Paid = {} },
		IsInfMath = false,
	},
} :: { [any]: Leaderboard }

local function LoadFrames(
	datastore: OrderedDataStore,
	frameHolder: ScrollingFrame,
	leaderboardData: Leaderboard,
	category: string
)
	local success: boolean, pages: DataStorePages = pcall(function()
		return datastore:GetSortedAsync(false, 100)
	end)
	if not success then
		warn("Failed to fetch leaderboard page:", pages)
		return
	end
	local top = pages:GetCurrentPage()

	local frames = {}
	local newLookUp = {}
	for rank, data in ipairs(top) do
		newLookUp[data.key] = rank
		local clone = (rank == 1) and goldTemplate:Clone()
			or (rank == 2) and silverTemplate:Clone()
			or (rank == 3) and bronzeTemplate:Clone()
			or template:Clone()

		task.spawn(function()
			local userId = tonumber(data.key)
			local infoSuccess, info = pcall(function()
				return UserService:GetUserInfosByUserIdsAsync({ userId })
			end)
			if infoSuccess then
				clone.DisplayName.Text = info[1].DisplayName
				clone.UserName.Text = info[1].Username
				local thumbSuccess, thumb = pcall(function()
					return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
				end)
				if thumbSuccess then
					clone.PlayerIcon.Icon.Image = thumb
				end
			end
		end)

		clone.Rank.Label.Text = "#" .. rank
		clone.Amount.Text = leaderboardData.IsInfMath and InfiniteMath:ConvertFromLeaderboards(data.value):GetSuffix(true)
			or InfiniteMath.new(data.value):GetSuffix(true)

		clone.Visible = true
		clone.LayoutOrder = rank
		clone.Name = rank

		table.insert(frames, clone)
	end
	leaderboardData.LookUp[category] = newLookUp

	for _, child in ipairs(frameHolder:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for _, frame in ipairs(frames) do
		frame.Parent = frameHolder
	end

	table.clear(frames)
end

local function GetPlayerPositions(player)
	local positions = {}
	local profile = PlayerData.GetData(player)
	local category = profile.IsFreeToPlay and "Free" or "Paid"
	for name, data in pairs(leaderboards) do
		positions[name] = data.LookUp[category][tostring(player.UserId)] or 0
	end
	return positions
end

local function UpdatePositionClones(player: Player)
	local profile = PlayerData.GetData(player)
	local playerPositions = GetPlayerPositions(player)

	local character = player.Character
	local head = character:WaitForChild("Head")
	local clone = head.NameTag

	for _, child in ipairs(clone.Holder.LeaderboardPositions:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for name, rank in pairs(playerPositions) do
		if rank == 0 then
			continue
		else
			local positionClone = clone.Templates.PositionTemplate:Clone() :: Frame
			positionClone.Parent = clone.Holder.LeaderboardPositions
			positionClone.Name = name
			positionClone.Icon.Image = ImageService[name] or ImageService["Placeholder"]
			positionClone.Rank.Text = "#" .. rank
			positionClone.Rank.TextColor3 = (rank == 1) and Color3.fromRGB(233, 189, 14)
				or (rank == 2) and Color3.fromRGB(177, 177, 177)
				or (rank == 3) and Color3.fromRGB(205, 127, 50)
				or Color3.fromRGB(255, 255, 255)
			positionClone.Category.Text = profile.IsFreeToPlay and "F2P" or "P2W"

			positionClone.Visible = true
		end
	end
end

local function HandleLeaderboards()
	while true do
		for _, player: Player in ipairs(Players:GetPlayers()) do
			if player.UserId <= 0 then
				continue
			end
			local profile = PlayerData.GetData(player)
			local userIdStr = tostring(player.UserId)

			for statName, data in pairs(leaderboards) do
				local success, err = pcall(function()
					if profile.IsFreeToPlay then
						if data.IsInfMath then
							data.FreeStore:SetAsync(userIdStr, InfiniteMath.new(profile[statName]):ConvertForLeaderboards())
						else
							data.FreeStore:SetAsync(userIdStr, profile[statName])
						end
					else
						local getSuccess, score = pcall(function()
							return data.FreeStore:GetAsync(userIdStr)
						end)
						if getSuccess and score then
							pcall(function()
								data.FreeStore:RemoveAsync(userIdStr)
							end)
						end

						if data.IsInfMath then
							data.PaidStore:SetAsync(userIdStr, InfiniteMath.new(profile[statName]):ConvertForLeaderboards())
						else
							data.PaidStore:SetAsync(userIdStr, profile[statName])
						end
					end
				end)
				if not success then
					warn("Failed to write leaderboard stat", statName, "for", player, err)
				end
			end
		end

		for _, data in pairs(leaderboards) do
			LoadFrames(data.FreeStore, data.Model.ListHolder.GlobalLBGui.F2PHolder, data, "Free")
			LoadFrames(data.PaidStore, data.Model.ListHolder.GlobalLBGui.P2WHolder, data, "Paid")
		end

		for _, player: Player in ipairs(Players:GetPlayers()) do
			if playerReady[player] then
				UpdatePositionClones(player)
			end
		end

		task.wait(refreshTime)
	end
end

local function CreateNameTag(player: Player)
	local profile = PlayerData.GetData(player)
	if not profile then
		return
	end
	local character = player.Character or player.CharacterAdded:Wait()
	local head = character:WaitForChild("Head")

	if head:FindFirstChild("NameTag") then
		head:FindFirstChild("NameTag"):Destroy()
	end

	local clone = nameTagTemplate:Clone()
	clone.Parent = head
	clone.Holder.PlayerName.Text = player.Name

	UpdatePositionClones(player)
end

local function InitializePlayer(player)
	if player.Character then
		player.Character:WaitForChild("Humanoid").DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid").DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		if playerReady[player] then
			CreateNameTag(player)
		end
	end)
end

function LeaderboardHandler.ClientReady(player: Player)
	playerReady[player] = true
	CreateNameTag(player)
end

function LeaderboardHandler.Initialize()
	task.spawn(HandleLeaderboards)

	for _, player: Player in ipairs(Players:GetPlayers()) do
		InitializePlayer(player)
	end
	Players.PlayerAdded:Connect(function(player: Player)
		InitializePlayer(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player, _: Enum.PlayerExitReason)
		playerReady[player] = nil
	end)
end

return LeaderboardHandler
