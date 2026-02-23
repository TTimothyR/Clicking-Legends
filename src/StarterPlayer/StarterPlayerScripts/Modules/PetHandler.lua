local PetHandler = {};

-- Services
local players = game:GetService('Players');
local workspace = game:GetService('Workspace');
local rs = game:GetService('ReplicatedStorage');
local runService = game:GetService('RunService');

-- Variables
repeat task.wait() until players.LocalPlayer;
local player: Player = players.LocalPlayer;
local petsFolder: Folder = workspace:WaitForChild('EquippedPets');

local framework: Folder = rs:WaitForChild('Framework');
local library: Folder = framework:WaitForChild('Library');
local assets: Folder = rs:WaitForChild('Assets');
local petModels: Folder = assets:WaitForChild('PetModels');

local tValues = {};

-- Modules
local network = require(framework.Network);
local petStats = require(library.PetStats);

-- Constants
local amplitude = 1
local frequency = 4
local rotationAngle = 15

local function CalculateYOffset(model: Model, rayDistance)
    local lowestOffset = math.huge

    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA('BasePart') then
            local relative = model.PrimaryPart.CFrame:PointToObjectSpace(part.Position);
            local bottomY = relative.Y - (part.Size.Y/2);

            lowestOffset = math.min(lowestOffset, bottomY);
        end
    end

    local params = RaycastParams.new();
    params.FilterType = Enum.RaycastFilterType.Exclude;
    params.FilterDescendantsInstances = {petsFolder, workspace.Baseplate};

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
        lowestOffset -= resultDown.Position.Y;
    elseif resultUp then
        lowestOffset -= resultUp.Position.Y;
    end

    return -lowestOffset;
end

local function handlePets(folder: Folder)
	local playerName: string = folder.Name
	local player: Player = players:FindFirstChild(playerName)

	local animConnection: RBXScriptConnection

	animConnection = runService.Heartbeat:Connect(function(dt)
		local humanoidRootPart: Part = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local radius = math.rad(360 / #folder:GetChildren())

		for i, v: Model in ipairs(folder:GetChildren()) do
			local state
            if string.find(v.Name, 'Shiny') then
                state = petStats[v.PetName.Value:gsub('Shiny ', '')].State or 'Walk';
            else
                state = petStats[v.PetName.Value].State;
            end
			local rarity = petStats[v.PetName.Value:gsub("Shiny ", "")].Rarity or "Common"
            local secret = petStats[v.PetName.Value:gsub('Shiny ', '')].Secret or false;
			if not tValues[v] then
				tValues[v] = 0
			end
			
            local center, size = v:GetBoundingBox();
			local distanceOffset = 10;
			if secret then
				distanceOffset = size.Z/1.5
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
                    local surfaceOffset = CalculateYOffset(v, 1000);
					local slope = 2 * math.cos(10 * tValues[v])
					local tilt = slope * rotationAngle
					targetPosition = Vector3.new(posX, surfaceOffset, posZ)
					local targetCframe = CFrame.new(targetPosition) * CFrame.new(Vector3.new(), humanoidRootPart.CFrame.LookVector)
					local tiltRotation = CFrame.Angles(0, 0, math.rad(tilt))

					v:PivotTo(currentCframe:Lerp(targetCframe * tiltRotation, math.clamp(5 * dt, 0, 1)))
					tValues[v] += dt
				else
					local yOffset = amplitude * math.sin(frequency * tValues[v])
                    local surfaceOffset = CalculateYOffset(v, 1000) + 2;
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
                    local surfaceOffset = CalculateYOffset(v, 1000);
					targetPosition = Vector3.new(posX,surfaceOffset, posZ)
					local lookAtCFrame = CFrame.lookAt(targetPosition, Vector3.new(humanoidRootPart.Position.X, targetPosition.Y, humanoidRootPart.Position.Z))
					v:PivotTo(currentCframe:Lerp(lookAtCFrame, math.clamp(5 * dt, 0, 1)))
				else
					local yOffset = amplitude * math.sin(frequency * tValues[v])
                    local surfaceOffset = CalculateYOffset(v, 1000) + 2;
					local slope = math.cos(frequency * tValues[v])
					local tilt = slope * rotationAngle
					targetPosition = Vector3.new(posX, yOffset + surfaceOffset, posZ)
					--local targetCframe = CFrame.new(targetPosition) * CFrame.new(Vector3.new(), humanoidRootPart.CFrame.LookVector)
					local tiltRotation = CFrame.Angles(math.rad(tilt), 0, 0)
					local lookAtCframe = CFrame.lookAt(targetPosition, Vector3.new(humanoidRootPart.Position.X, targetPosition.Y, humanoidRootPart.Position.Z))
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
    local profile = network:InvokeServer('GetOtherData', player.Name);

    local pets = profile.Pets;

    for _, data in ipairs(pets) do
        if data.equipped then
            PetHandler.UpdatePet(player, data, true);
        end
    end
end

function PetHandler.UpdatePets(player: Player)
	local profile = network:InvokeServer('GetOtherData', player.Name)
	local pets = profile.Pets

	for i, petData in ipairs(pets) do
		if petData.equipped and not petsFolder:FindFirstChild(player.Name):FindFirstChild(petData.id) then
			PetHandler.UpdatePet(player, petData, true);
		end
		if not petData.equipped and petsFolder:FindFirstChild(player.Name):FindFirstChild(petData.id) then
			PetHandler.UpdatePet(player, petData, false);
		end
	end
end

function PetHandler.UpdatePet(player: Player, petData, equip: boolean)
    if equip then
        local model: Model
        if petModels:FindFirstChild(petData.fullName) then
            model = petModels[petData.fullName]:Clone();
        else
            model = petModels[petData.petName]:Clone();
        end
        model.Parent = petsFolder:FindFirstChild(player.Name);
        model.Name = petData.id;
		
		local petName: StringValue = Instance.new('StringValue', model);
		petName.Name = 'PetName';
		petName.Value = petData.fullName;
        
		model:PivotTo(player.Character:WaitForChild('HumanoidRootPart').CFrame);
    else
        petsFolder:FindFirstChild(player.Name):FindFirstChild(petData.id):Destroy();
    end
end

function PetHandler.Initialize()
    if not game.Loaded then game.Loaded:Wait() end;

    for _, folder: Folder in ipairs(petsFolder:GetChildren()) do
        LoadPets(players:FindFirstChild(folder.Name));
        task.delay(.2, handlePets, folder);
    end
    players.PlayerAdded:Connect(function(player)
        LoadPets(player);
        task.delay(.2, handlePets, petsFolder:FindFirstChild(player.Name));
    end)
end

return PetHandler;