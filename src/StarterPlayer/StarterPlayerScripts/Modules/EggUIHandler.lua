local EggUIHandler = {};
local db = false;

-- Services
local players = game:GetService('Players');
local rs = game:GetService('ReplicatedStorage');
local workspace = game:GetService('Workspace');
local runService = game:GetService('RunService');
local uis = game:GetService('UserInputService');

-- Variables
repeat task.wait() until players.LocalPlayer;
local player: Player = players.LocalPlayer;

local eggs: Folder = workspace:WaitForChild('Eggs');

local framework: Folder = rs:WaitForChild('Framework');
local library: Folder = framework:WaitForChild('Library');
local assets: Folder = rs:WaitForChild('Assets');

local closestEgg2;
local adornees = {};
local connections = {};
local maxDistance = 15;
local autoHatching = false;

-- UI
local playerGui = player:WaitForChild('PlayerGui');
local eggUI: BillboardGui = assets:WaitForChild('EggUI');
local eggHolder: ScreenGui = playerGui:WaitForChild('EggUI');

-- Modules
local eggStats = require(library.EggStats);
local petStats = require(library.PetStats);
local network = require(framework.Network);
local globals = require(framework.Globals);

local function SetupTemplate(ui)
    local petHolder = ui.Main.PetsFrame.Holder;
    local buttons = ui.Main.Buttons;

    local profile = network:InvokeServer('GetData');
    local index = profile.PetIndex;
    local luckPercentage = profile.LuckPercentage;

    for _, item in ipairs(petHolder:GetChildren()) do
        if item:IsA('ImageButton') then
            local clickConnection: RBXScriptConnection;
            
            local petStat = petStats[item.Name];
            local rarity = petStat.Rarity;
            local discovered = index[item.Name];

            local autoDeleted = network:InvokeServer('GetAutoDeleted', item.Name);

            if autoDeleted then
                item.ImageLabel.ImageTransparency = 0.5;
            else
                item.ImageLabel.ImageTransparency = 0;
            end
            
            if discovered then
                item.ImageLabel.ImageColor3 = Color3.fromRGB(255,255,255);
            end
            
            local chance = globals.GetPetChance(luckPercentage, item.Name, ui.Name, false);
            
            item.Chance.Text = tostring(chance)..'%';
            
            clickConnection = item.MouseButton1Click:Connect(function()
                if not db then db = true task.delay(.15, function() db = false end)
                    local newStatus = network:InvokeServer('ToggleAutoDelete', item.Name);
                    if newStatus then
                        item.ImageLabel.ImageTransparency = 0.5;
                    else
                        item.ImageLabel.ImageTransparency = 0;
                    end
                end
            end)
            table.insert(connections[ui.Name], clickConnection);
        end
    end
    local singleConnection: RBXScriptConnection;
    local mutliConnection: RBXScriptConnection;
    local autoConnection: RBXScriptConnection;
    singleConnection = buttons.Hatch.MouseButton1Click:Connect(function()
        if not db then db = true task.delay(.15, function() db = false end)
            local egg = closestEgg2;
            if egg ~= '' then network:InvokeServer('OpenEgg', egg, 1) end;
        end
    end)
    mutliConnection = buttons.Multi.MouseButton1Click:Connect(function()
        if not db then db = true task.delay(.15, function() db = false end)
            local egg = closestEgg2;
            if egg ~= '' then network:InvokeServer('OpenEgg', egg, 3) end;
        end
    end)
    autoConnection = buttons.Auto.MouseButton1Click:Connect(function()
        if not db then db = true task.delay(.15, function() db = false end)
            local egg = closestEgg2
            if egg ~= "" and not autoHatching then
                EggUIHandler.AutoHatch(egg)
            end
        end
    end)
    table.insert(connections[ui.Name], singleConnection);
    table.insert(connections[ui.Name], mutliConnection);
    table.insert(connections[ui.Name], autoConnection);
end

local function GetClosestEgg()
    repeat task.wait() until #adornees == #eggHolder:GetChildren();

    runService.Heartbeat:Connect(function(deltaTime)
        local char = player.Character
        local humanoidRootPart = char and char:FindFirstChild('HumanoidRootPart');
        
        if not humanoidRootPart then return end;

        local minDistance = math.huge;
        local closestEgg1 = '';

        for i, data in ipairs(adornees) do
            local adornee = data.part;
            local distance = (humanoidRootPart.Position - adornee.Position).Magnitude;

            adornees[i].distance = distance;

            if distance < minDistance then
                minDistance = distance;
                closestEgg1 = adornee.Parent.Name;
            end
        end
        
		if closestEgg1 ~= "" and minDistance <= maxDistance then
			closestEgg2 = closestEgg1
		else
			closestEgg2 = ""
		end

        for _, ui in ipairs(eggHolder:GetChildren()) do
			if ui.Name == closestEgg2 and not player:WaitForChild("UILock").Value then
				if not next(connections[ui.Name]) then SetupTemplate(ui) end
				ui.Enabled = true
			else
				ui.Enabled = false
			end
		end

		for eggName, data in pairs(connections) do
			if eggHolder[eggName] and not eggHolder[eggName].Enabled then
				for i = #data, 1, -1 do
					data[i]:Disconnect()
					table.remove(data, i)
				end
			end
		end
    end)
end

local function ConfigureEggUI(egg: Model)
    local profile = network:InvokeServer('GetData');
    local index = profile.PetIndex;
    local clone = eggUI:Clone();
    clone.Parent = eggHolder;

    local luckPercentage = profile.LuckPercentage;

    clone.Adornee = egg:FindFirstChild('View');
    table.insert(adornees, {
        part = egg:FindFirstChild('View'),
        distance = math.huge
    })

    clone.Name = egg.Name;

    local main: Frame = clone.Main;
    local templates: Folder = main.Templates;
    local petTemplate: ImageButton = templates.Pet;
    local price: Frame = main.Price;
    local eggName: Frame = main.EggName;
    local petsFrame: Frame = main.PetsFrame;
    local holder: Frame = petsFrame.Holder

    local currentStats = eggStats[egg.Name];
    eggName.EggName.Text = tostring(egg.Name);
    price.Amount.Text = currentStats.Price[2];

    for petName, data in pairs(currentStats.Pets) do
        local petClone: ImageButton = petTemplate:Clone();
        local chance = globals.GetPetChance(luckPercentage, petName, egg.Name, false);

        petClone.Parent = holder;
        petClone.Name = petName;

        petClone.Chance.Text = tostring(chance)..'%';
        petClone.LayoutOrder = data[2];

        local discovered = index[petName];
        local autoDeleted = network:InvokeServer('GetAutoDeleted', petName);

        if autoDeleted then
            petClone.ImageLabel.ImageTransparency = 0.5;
        else
            petClone.ImageLabel.ImageTransparency = 0;
        end

        if not discovered then
            petClone.ImageLabel.ImageColor3 = Color3.fromRGB(0,0,0);
        end
        petClone.Visible = true
    end
    connections[egg.Name] = {};
end

function EggUIHandler.AutoHatch(eggName: string)
    local egg = eggName;
    autoHatching = true;
    repeat
        network:InvokeServer('OpenEgg', egg, 5);
        task.wait(0.5);
    until closestEgg2 ~= egg;
    autoHatching = false;
end

function EggUIHandler.Initialize()
    if not game.Loaded then game.Loaded:Wait() end;

    for _, egg in ipairs(eggs:GetChildren()) do
        ConfigureEggUI(egg);
    end

    task.spawn(GetClosestEgg);

    uis.InputBegan:Connect(function(input, gameProcessedEvent)
        if gameProcessedEvent then return end;

        if input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode == Enum.KeyCode.E then
                local egg = closestEgg2;
                if egg ~= '' then network:InvokeServer('OpenEgg', egg, 1) end;
            elseif input.KeyCode == Enum.KeyCode.R then
                local egg = closestEgg2;
                if egg ~= '' then network:InvokeServer('OpenEgg', egg, 3) end;
            elseif input.KeyCode == Enum.KeyCode.T then
                local egg = closestEgg2
				if egg ~= "" and not autoHatching then
					EggUIHandler.AutoHatch(egg)
				end
            end
        end
    end)
end

return EggUIHandler;