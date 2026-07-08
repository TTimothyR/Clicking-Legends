local PetHandler = {}

-- Services
local players = game:GetService("Players")
local workspace = game:GetService("Workspace")
local rs = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")

-- Variables
repeat
	task.wait()
until players.LocalPlayer
local plr = players.LocalPlayer
local petsFolder = workspace:WaitForChild("EquippedPets")

local framework = rs:WaitForChild("Framework")
local library = framework:WaitForChild("Library")
local assets = rs:WaitForChild("Assets")
local petModels = assets:WaitForChild("PetModels")

local tValues = {}

local hideAllPets = false
local hideOtherPets = false
local equippedPetsData = {}

-- Modules
local petStats = require(library.PetStats)
local dataSync = require(script.Parent.DataSyncClient)

-- Constants
local amplitude = 1
local frequency = 4
local rotationAngle = 15

local function CalculateYOffset(model, rayDistance)
	local lowestOffset = math.huge

	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			local relative = model.PrimaryPart.CFrame:PointToObjectSpace(part.Position)
			local bottomY = relative.Y - (part.Size.Y / 2)

			lowestOffset = math.min(lowestOffset, bottomY)
		end
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.PetCollidables }

	local resultDown: RaycastResult = workspace:Raycast(
		model.PrimaryPart.Position - Vector3.new(0, lowestOffset, 0),
		Vector3.new(0, -rayDistance, 0),
		params
	)
	local resultUp: RaycastResult = workspace:Raycast(
		model.PrimaryPart.Position - Vector3.new(0, lowestOffset, 0),
		Vector3.new(0, rayDistance, 0),
		params
	)

	if resultDown then
		lowestOffset -= resultDown.Position.Y
	elseif resultUp then
		lowestOffset -= resultUp.Position.Y
	end

	return -lowestOffset
end

local function ShouldShowPets(ownerName: string): boolean
	if hideAllPets then
		return false
	end
	if hideOtherPets and ownerName ~= plr.name then
		return false
	end

	return true
end

local function SpawnPetModel(player: Player, petData)
	local folder = petsFolder:FindFirstChild(player.Name)
	if not folder or folder:FindFirstChild(petData.id) then
		return
	end

	local model
	if petModels:FindFirstChild(petData.fullName) then
		model = petModels[petData.fullName]:Clone() :: Model
	else
		model = petModels[petData.petName]:Clone() :: Model
	end
	model.Parent = folder
	model.Name = petData.id

	local petName = Instance.new("StringValue") :: StringValue
	petName.Parent = model
	petName.Name = "PetName"
	petName.Value = petData.petName

	if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
		local char = player.Character
		local root = char.HumanoidRootPart

		model:PivotTo(root.CFrame)
	end
end

local function DestroyPetModel(player: Player, petId: string)
	local folder = petsFolder:FindFirstChild(player.Name) :: Folder
	local model = folder and folder:FindFirstChild(petId) :: Model
	if model then
		model:Destroy()
	end
end

local function SyncPetVisibility()
	for playerName, pets in pairs(equippedPetsData) do
		local player = players:FindFirstChild(playerName) :: Player
		if not player then
			continue
		end
		local visible = ShouldShowPets(playerName)
		for id, petData in pairs(pets) do
			if visible then
				SpawnPetModel(player, petData)
			else
				DestroyPetModel(player, id)
			end
		end
	end
end

local function handlePets(folder: Folder)
	local playerName = folder.Name
	local player = players:FindFirstChild(playerName)

	local animConnection: RBXScriptConnection

	animConnection = runService.Heartbeat:Connect(function(dt)
		local humanoidRootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local radius = math.rad(360 / #folder:GetChildren())

		for i, v in ipairs(folder:GetChildren()) do
			local state
			if string.find(v.Name, "Shiny") then
				state = petStats[v.PetName.Value:gsub("Shiny ", "")].State or "Walk"
			else
				state = petStats[v.PetName.Value].State
			end
			local secret = petStats[v.PetName.Value:gsub("Shiny ", "")].Secret or false
			if not tValues[v] then
				tValues[v] = 0
			end

			local _, size = v:GetBoundingBox()
			local distanceOffset = 10
			if secret then
				distanceOffset = distanceOffset / 2 + size.Z / 1.5
			end

			local posX = humanoidRootPart.Position.X + (distanceOffset * math.cos(radius * i))
			local posZ = humanoidRootPart.Position.Z + (distanceOffset * math.sin(radius * i))
			local targetPosition

			local velocity = player.Character.PrimaryPart.Velocity
			velocity -= Vector3.new(0, velocity.Y, 0)
			local isMoving = dt < velocity.Magnitude

			local currentCframe = v:GetPivot()

			if isMoving then
				if state == "Walk" then
					local surfaceOffset = CalculateYOffset(v, 1000)
					local slope = 2 * math.cos(10 * tValues[v])
					local tilt = slope * rotationAngle
					targetPosition = Vector3.new(posX, surfaceOffset, posZ)
					local targetCframe = CFrame.new(targetPosition) * CFrame.new(Vector3.new(), humanoidRootPart.CFrame.LookVector)
					local tiltRotation = CFrame.Angles(0, 0, math.rad(tilt))

					v:PivotTo(currentCframe:Lerp(targetCframe * tiltRotation, math.clamp(5 * dt, 0, 1)))
					tValues[v] += dt
				else
					local yOffset = amplitude * math.sin(frequency * tValues[v])
					local surfaceOffset = CalculateYOffset(v, 1000) + 2
					local slope = math.cos(frequency * tValues[v])
					local tilt = slope * rotationAngle
					targetPosition = Vector3.new(posX, yOffset + surfaceOffset, posZ)
					local targetCframe = CFrame.new(targetPosition) * CFrame.new(Vector3.new(), humanoidRootPart.CFrame.LookVector)
					local tiltRotation = CFrame.Angles(math.rad(tilt), 0, 0)

					v:PivotTo(currentCframe:Lerp(targetCframe * tiltRotation, math.clamp(5 * dt, 0, 1)))
					tValues[v] += dt
				end
			else
				if state == "Walk" then
					local surfaceOffset = CalculateYOffset(v, 1000)
					targetPosition = Vector3.new(posX, surfaceOffset, posZ)
					local lookAtCFrame = CFrame.lookAt(
						targetPosition,
						Vector3.new(humanoidRootPart.Position.X, targetPosition.Y, humanoidRootPart.Position.Z)
					)
					v:PivotTo(currentCframe:Lerp(lookAtCFrame, math.clamp(5 * dt, 0, 1)))
				else
					local yOffset = amplitude * math.sin(frequency * tValues[v])
					local surfaceOffset = CalculateYOffset(v, 1000) + 2
					local slope = math.cos(frequency * tValues[v])
					local tilt = slope * rotationAngle
					targetPosition = Vector3.new(posX, yOffset + surfaceOffset, posZ)
					--local targetCframe = CFrame.new(targetPosition) * CFrame.new(Vector3.new(), humanoidRootPart.CFrame.LookVector)
					local tiltRotation = CFrame.Angles(math.rad(tilt), 0, 0)
					local lookAtCframe = CFrame.lookAt(
						targetPosition,
						Vector3.new(humanoidRootPart.Position.X, targetPosition.Y, humanoidRootPart.Position.Z)
					)
					v:PivotTo(currentCframe:Lerp(lookAtCframe * tiltRotation, math.clamp(5 * dt, 0, 1)))
					tValues[v] += dt
				end
			end
		end
	end)
	folder.DescendantRemoving:Connect(function(descendant)
		if tValues[descendant] then
			tValues[descendant] = nil
		end
	end)
	folder:GetPropertyChangedSignal("Parent"):Once(function()
		animConnection:Disconnect()
	end)
end

local function LoadPets(player: Player)
	local character = workspace:FindFirstChild(player.Name)
	if not character then
		return
	end
	-- local profile = dataSync.GetOtherData(player.UserId);
	local pets = nil
	repeat
		if player == plr then
			pets = dataSync.Get("Pets")
		else
			local profile = dataSync.GetOtherData(player.UserId)
			if not profile then
				break
			end
			pets = profile.Pets
		end
		if type(pets) ~= "table" then
			task.wait(0.1)
		end
	until type(pets) == "table"

	if pets then
		for _, data in ipairs(pets) do
			if data.equipped then
				PetHandler.UpdatePet(player, data, true)
			end
		end
	end
end

function PetHandler.UpdatePets(player: Player, pets)
	for _, petData in ipairs(pets) do
		if petData.equipped and not petsFolder:FindFirstChild(player.Name):FindFirstChild(petData.id) then
			PetHandler.UpdatePet(player, petData, true)
		end
		if not petData.equipped and petsFolder:FindFirstChild(player.Name):FindFirstChild(petData.id) then
			PetHandler.UpdatePet(player, petData, false)
		end
	end
end

function PetHandler.UpdatePet(player, petData, equip: boolean)
	local character = workspace:FindFirstChild(player.Name)
	if not character then
		return
	end

	equippedPetsData[player.Name] = equippedPetsData[player.Name] or {}

	if equip then
		equippedPetsData[player.Name][petData.id] = petData
		if ShouldShowPets(player.Name) then
			SpawnPetModel(player, petData)
		end
	else
		equippedPetsData[player.Name][petData.id] = nil
		DestroyPetModel(player, petData.id)
	end
end

function PetHandler.Initialize()
	if not game.Loaded then
		game.Loaded:Wait()
	end

	dataSync.OnChanged("Settings", function(new, _)
		hideAllPets = new.HideAll
		hideOtherPets = new.HideOthers
		SyncPetVisibility()
	end)

	dataSync.OnReady(function()
		local playerSettings = dataSync.Get("Settings")
		hideAllPets = playerSettings.HideAll
		hideOtherPets = playerSettings.HideOthers

		for _, folder: Folder in ipairs(petsFolder:GetChildren()) do
			LoadPets(players:FindFirstChild(folder.Name))
			task.delay(0.2, handlePets, folder)
		end
	end)
	players.PlayerAdded:Connect(function(player)
		LoadPets(player)
		task.delay(0.2, handlePets, petsFolder:FindFirstChild(player.Name))
	end)
end

return PetHandler
