local players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local Globals = require(ReplicatedStorage.Framework.Globals)

local function SetGroup(character)
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = Globals.CharacterGroup
		end
	end
	character.DescendantAdded:Connect(function(part)
		if part:IsA("BasePart") then
			part.CollisionGroup = Globals.CharacterGroup
		end
	end)
end

players.PlayerRemoving:Connect(function(plr: Player)
	if workspace.EquippedPets:FindFirstChild(plr.Name) then
		workspace.EquippedPets:FindFirstChild(plr.Name):Destroy()
	end
end)

if not PhysicsService:IsCollisionGroupRegistered(Globals.CharacterGroup) then
	PhysicsService:RegisterCollisionGroup(Globals.CharacterGroup)
end
if not PhysicsService:IsCollisionGroupRegistered(Globals.DebrisGroup) then
	PhysicsService:RegisterCollisionGroup(Globals.DebrisGroup)
end
PhysicsService:CollisionGroupSetCollidable(Globals.CharacterGroup, Globals.DebrisGroup, false)
PhysicsService:CollisionGroupSetCollidable(Globals.CharacterGroup, Globals.CharacterGroup, false)
PhysicsService:CollisionGroupSetCollidable(Globals.DebrisGroup, Globals.DebrisGroup, false)

local hatchesChannel = Instance.new("TextChannel")
hatchesChannel.Name = "Hatches"
hatchesChannel.Parent = TextChatService:WaitForChild("TextChannels")

hatchesChannel.ShouldDeliverCallback = function(message, _)
	if message.TextSource == nil then
		return true
	end
	return false
end

local function OnPlayerAdded(plr)
	task.spawn(function()
		task.wait(1.5)
		local success, err = pcall(function()
			hatchesChannel:AddUserAsync(plr.UserId)
		end)
		if not success then
			warn("Failed to add player to hatches channel", tostring(err))
		end
	end)

	local equip: Folder = Instance.new("Folder")
	equip.Parent = workspace.EquippedPets
	equip.Name = plr.Name
	plr.CharacterAdded:Connect(SetGroup)
end

for _, plr: Player in pairs(players:GetPlayers()) do
	OnPlayerAdded(plr)
end

players.PlayerAdded:Connect(function(plr: Player)
	OnPlayerAdded(plr)
end)
