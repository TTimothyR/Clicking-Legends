local Players = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local sss = game:GetService("ServerScriptService")

local PlayerDataTemplate = require(rs.PlayerData)
local ProfileStore = require(sss.DataModules.ProfileStore)
local leaderstats = require(sss.DataModules.leaderstats)
local dataSync = require(script.Parent.DataSyncServer);

local v = "24"
local dataKey = "OfficialV"..v
if runService:IsStudio() then
	dataKey = "TestV"..v
end

local PlayerStore = ProfileStore.New(dataKey, PlayerDataTemplate.DEFAULT_PLAYER_DATA)
local Profiles: {[player]: typeof(PlayerStore:StartSessionAsync())} = {}

local Local = {}
local Shared = {}

function Local.OnStart()
	for _, player: Player in Players:GetPlayers() do
		task.spawn(Local.LoadProfile, player)
	end
	
	Players.PlayerAdded:Connect(function(player: Player)
		task.spawn(Local.LoadProfile, player)
	end)
	Players.PlayerRemoving:Connect(Local.RemoveProfile)
end

function Local.LoadProfile(player: Player)
	local profile = PlayerStore:StartSessionAsync(`{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	
	if profile == nil then
		return player:Kick("Loading profile failed. Please rejoin.")
	end
	
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	
	profile.OnSessionEnd:Connect(function()
		Profiles[player] = nil
		player:Kick("Profile session ended. Please rejoin.")
	end)
	
	local isInGame = player.Parent == Players
	if isInGame then
		Profiles[player] = profile
	else
		profile:EndSession()
	end
	leaderstats:CreateLeaderstats(player, profile)
	profile.Data.ClickDebounce = false

	dataSync.InitializePlayer(player, profile.Data);
end

function Local.RemoveProfile(player: Player)
	local profile = Profiles[player]
	if profile ~= nil then
		profile:EndSession()
	end
end

function Shared.GetData(player: Player): PlayerDataTemplate.PlayerData?
	local profile = nil
	while wait(0.01) do
		profile = Profiles[player]
		if profile then break end
	end
	return profile.Data
end

function Shared.GetOtherData(player: Player, playerName: string): PlayerDataTemplate.PlayerData?
	local plr = Players:FindFirstChild(playerName)
	local profile = nil
	while wait(0.01) do
		profile = Profiles[plr]
		if profile then break end
	end
	return profile.Data
end

-- Example use SERVER
--function Shared.UpdateClicks(player: Player, amount: number)
--	local data = Shared.GetData(player)
--	if not data then return end
	
--	local clicks = data.Clicks
	
--	data.Clicks += amount
--end

Local.OnStart()

return Shared