local IndexHandler = {};
local db = false;

-- Services
local players = game:GetService('Players');
local rs = game:GetService('ReplicatedStorage');

-- Variables
repeat task.wait() until players.LocalPlayer;
local player: Player = players.LocalPlayer;

local framework: Folder = rs:WaitForChild('Framework');
local library: Folder = framework:WaitForChild('Library');

local clickConnections = {};
local shinySelected: boolean = false;
local selectedEgg: string = nil;

-- UI
local playerGui: PlayerGui = player:WaitForChild('PlayerGui');
local frames: ScreenGui = playerGui:WaitForChild('Frames');
local indexFrame: Frame = frames:WaitForChild('Index');
local templates: Folder = indexFrame:WaitForChild('Templates');
local eggTemplate: ImageButton = templates:WaitForChild('EggTemplate');
local petTemplate: ImageButton = templates:WaitForChild('PetTemplate');
local main: Frame = indexFrame:WaitForChild('Main');
local eggsFrame: Frame = main:WaitForChild('Eggs');
local eggHolder: ScrollingFrame = eggsFrame:WaitForChild('EggHolder');
local petsFrame: Frame = main:WaitForChild('Pets');
local miscFrame: ScrollingFrame = petsFrame:WaitForChild('ScrollingFrame');
local petHolder: ScrollingFrame = miscFrame:WaitForChild('PetHolder');
local buttons: Frame = miscFrame:WaitForChild('Buttons');
local normalButton: ImageButton = buttons:WaitForChild('Normal');
local shinyButton: ImageButton = buttons:WaitForChild('Shiny');
local discoveryFrame: Frame = miscFrame:WaitForChild('Discovery');
local lockedFrame: Frame = discoveryFrame:WaitForChild('Locked');

-- Modules
local network = require(framework.Network);
local globals = require(framework.Globals);
local eggStats = require(library.EggStats);
local petStats = require(library.PetStats);

local function GetTotalPetCount(eggName: string)
    local count = 0
    for _, _ in pairs(eggStats[eggName].Pets) do
        count += 1
    end
    return count;
end

local function GetPlayerPetCount(eggName: string)
    local profile = network:InvokeServer('GetData');
    local index = profile.PetIndex

    local normalCount = 0
    local shinyCount = 0
    for pet, _ in pairs(eggStats[eggName].Pets) do
        if index[pet] then
            normalCount += 1
        end
        if index['Shiny '..pet] then
            shinyCount += 1;
        end
    end

    return normalCount, shinyCount;
end

local function LoadPets(index, eggName: string, shiny: boolean)
    for _, child in ipairs(petHolder:GetChildren()) do
        if child:IsA('ImageButton') then
            child:Destroy();
        end
    end

    for pet, data in pairs(eggStats[eggName].Pets) do
        local clone: ImageButton = petTemplate:Clone();
        clone.Name = pet;
        clone.Parent = petHolder;
        clone.LayoutOrder = data[2];

        local rarity = petStats[pet].Rarity;
        clone.Frame.BackgroundColor3 = globals.RarityColors[rarity];
        if rarity == 'Legendary' then
            clone.Glow.Visible = true;
            clone.Frame.Legendary.Enabled = true;
        end

        if not shiny then
            if not index[pet] then
                clone.Frame.Icon.ImageColor3 = Color3.fromRGB(0,0,0);
            end
        else
            if not index['Shiny '..pet] then
                clone.Frame.Icon.ImageColor3 = Color3.fromRGB(0,0,0);
            end
        end

        clone.Visible = true;
    end
    
    local petsInEgg = GetTotalPetCount(eggName);
    local normalCount, shinyCount = GetPlayerPetCount(eggName);

    local visible = shiny and (shinyCount ~= petsInEgg) or (normalCount ~= petsInEgg);
    if visible then
        lockedFrame.Amount.Text = 'Discover '..petsInEgg..' Pets!';
        local progress = shiny and shinyCount or normalCount;
        lockedFrame.XP.Progress.Text = progress..'/'..petsInEgg;
    end
    lockedFrame.Visible = visible;
end

local function SelectEgg(eggName: string)
    local profile = network:InvokeServer('GetData');
    local index = profile.PetIndex;
    selectedEgg = eggName;
    
    LoadPets(index, eggName, shinySelected);

    miscFrame.Visible = true;
end

function IndexHandler.LoadIndex()
    for _, child in ipairs(eggHolder:GetChildren()) do
        if child:IsA('ImageButton') then
            child:Destroy();
        end
    end

    for _, con: RBXScriptConnection in ipairs(clickConnections) do
        if con.Connected then
            con:Disconnect();
        end
    end

    for eggName, _ in pairs(eggStats) do
        local clone: ImageButton = eggTemplate:Clone();
        clone.Name = eggName;
        clone.Parent = eggHolder;
        
        local infoFrame: Frame = clone.Frame;
        local petsInEgg = GetTotalPetCount(eggName);
        local normal, shiny = GetPlayerPetCount(eggName);

        infoFrame.EggName.Text = eggName;
        infoFrame.LimitedTag.Visible = eggStats[eggName].Limited;
        infoFrame.NormalCollected.Text = normal..'/'..petsInEgg;
        infoFrame.ShinyCollected.Text = shiny..'/'..petsInEgg;

        local clickCon = clone.MouseButton1Click:Connect(function()
            if not db then db = true task.delay(.15, function() db = false end)
                SelectEgg(eggName);
            end
        end)
        table.insert(clickConnections, clickCon);

        clone.Visible = true;
    end
end

function IndexHandler.Initialize()
    if not game.Loaded then game.Loaded:Wait() end;

    normalButton.MouseButton1Click:Connect(function()
        if not db then db = true task.delay(.15, function() db = false end)
            shinySelected = false;
            if selectedEgg then
                SelectEgg(selectedEgg);
            end
        end
    end)    
    shinyButton.MouseButton1Click:Connect(function()
        if not db then db = true task.delay(.15, function() db = false end)
            shinySelected = true;
            if selectedEgg then
                SelectEgg(selectedEgg);
            end
        end
    end)
end

return IndexHandler;