local InventoryHandler = {};
local db = false;

-- Services
local players = game:GetService('Players');
local rs = game:GetService('ReplicatedStorage');

-- Variables
repeat task.wait() until players.LocalPlayer;
local player: Player = players.LocalPlayer;

local framework = rs:WaitForChild('Framework');
local library = framework:WaitForChild('Library');

local selectedPetID: string = nil;
local clickConnections = {};

-- UI
local playerGui = player:WaitForChild('PlayerGui');
local frames: ScreenGui = playerGui:WaitForChild('Frames');
local inventoryFrame: Frame = frames:WaitForChild('Inventory');
local templates: Folder = inventoryFrame:WaitForChild('Templates');
local normalTemplate: ImageButton = templates:WaitForChild('Normal');
local secretTemplate: ImageButton = templates:WaitForChild('Secret');
local main: Frame = inventoryFrame:WaitForChild('Main');
local inventory: Frame = main:WaitForChild('Inventory');
local holder: ScrollingFrame = inventory:WaitForChild('ScrollingFrame');

local petInfo: Frame = main:WaitForChild('PetInfo');
local petInfoHolder: Frame = petInfo:WaitForChild('Holder');

-- Modules
local network = require(framework.Network);
local infMath = require(framework.InfiniteMath);
local petStats = require(library.PetStats);
local globals = require(framework.Globals);

-- Constants
local maxColSecret = 3;
local maxColNormal = 6;

local function SeperatePets(petsTbl)
    local normalTbl = {};
    local secretTbl = {};
    
    for i, petData in ipairs(petsTbl) do
        if petStats[petData.petName].Secret then
            table.insert(secretTbl, petData);
        else
            table.insert(normalTbl, petData);
        end
    end

    return normalTbl, secretTbl
end

local function SortPets(petA, petB)
    local rarityA = petStats[petA.petName].Rarity;
    local rarityB = petStats[petB.petName].Rarity;

    local rarityOrderA = globals.RarityOrder[rarityA] or 0;
    local rarityOrderB = globals.RarityOrder[rarityB] or 0;

    if rarityOrderA ~= rarityOrderB then
        return rarityOrderA > rarityOrderB;
    end
end

local function GetPetData(id: string)
    local profile = network:InvokeServer('GetData');

    local pets = profile.Pets;

    for i, data in ipairs(pets) do
        if data.id == id then
            return data;
        end
    end
    return nil;
end

local function LoadPetInfo(id: string)
    local petData = GetPetData(id);
    if not petData then
        warn('Player does not own pet with ID:', id);
    end

    local date = os.date('*t', petData.date);

    petInfoHolder.PetName.Text = petData.fullName;
    petInfoHolder.FoundDate.Text = 'Found on '..date.day..'/'..date.month..'/'..(date.year-2000);
    petInfoHolder.Level.Text = 'Level '..petData.level;

    local petStat = petStats[petData.petName];

    petInfoHolder.Stats.Clicks.Amount.Text = infMath.new(petStat.Clicks):GetSuffix(true);
    petInfoHolder.Stats.Gems.Amount.Text = petStat.GemMulti;

    petInfoHolder.Visible = true;
end

function InventoryHandler.LoadInventory()
    local profile = network:InvokeServer('GetData');
    if not profile then
        warn('Failed to load player profile');
        return;
    end
    holder:ClearAllChildren();
    for _, con: RBXScriptConnection in ipairs(clickConnections) do
        if con.Connected then
            con:Disconnect();
        end
    end

    local pets = profile.Pets;
    local normalTbl, secretTbl = SeperatePets(pets);
    table.sort(normalTbl, SortPets);

    local lastRow = 0;
    local lastColumn = 0;

    for i, petData in ipairs(secretTbl) do
        local row = math.floor((i-1)/maxColSecret);
        lastRow = (row+1)*2
        local column = math.floor((i-1)%maxColSecret);
        lastColumn = ((column+1)%maxColSecret)*2;

        local clone: ImageButton = secretTemplate:Clone();
        clone.Name = petData.fullName;
        clone.Parent = holder;
        clone.Frame.PetName.Text = petData.petName;

        local clickCon: RBXScriptConnection
        clickCon = clone.MouseButton1Click:Connect(function()
            if not db then db = true task.delay(.15, function() db = false end)
                if selectedPetID == petData.id then
                    selectedPetID = nil;
                    petInfoHolder.Visible = false;
                else
                    LoadPetInfo(petData.id);
                end
            end
        end)
        table.insert(clickConnections, clickCon);
        
        clone.Position = UDim2.new(
            clone.Size.X.Scale*column + clone.Size.X.Scale/2, 
            0, 
            clone.Size.Y.Scale*row + clone.Size.Y.Scale/2, 
            0
        );

        clone.Visible = true;
    end

    local savedColumn = lastColumn;
    local rowsFilled = 0;
    local finalIndex = 0;
    local secretRows = math.ceil(#secretTbl/maxColSecret);
    local yPaddingCorrection = 0.043;

    for i, petData in ipairs(normalTbl) do
        if lastColumn > 0 and rowsFilled < 2 then
            local targetColumn = lastColumn + 1;
            local row = math.floor((i-1)/(maxColNormal-savedColumn))
            
            lastColumn += 1;
            if lastColumn == 6 then
                rowsFilled += 1;
                lastColumn = savedColumn;
                lastRow += 1;
            end

            local clone: ImageButton = normalTemplate:Clone();
            clone.Name = petData.fullName;
            clone.Parent = holder;
            clone.Position = UDim2.new(
                clone.Size.X.Scale*(targetColumn-1) + clone.Size.X.Scale/2, 
                0, 
                secretTemplate.Size.Y.Scale*(secretRows-1) + (clone.Size.Y.Scale-yPaddingCorrection)*row + clone.Size.Y.Scale/2, 
                0
            );

            local rarity = petData.rarity;
            clone.Frame.BackgroundColor3 = globals.RarityColors[rarity];
            if rarity == 'Legendary' then
                clone.Glow.Visible = true;
                clone.Frame.Legendary.Enabled = true;
            end

            local clickCon: RBXScriptConnection
            clickCon = clone.MouseButton1Click:Connect(function()
                if not db then db = true task.delay(.15, function() db = false end)
                    if selectedPetID == petData.id then
                        selectedPetID = nil;
                        petInfoHolder.Visible = false;
                    else
                        LoadPetInfo(petData.id);
                    end
                end
            end)
            table.insert(clickConnections, clickCon);
            
            clone.Visible = true;
            finalIndex = i;
        else
            local targetRow = secretRows * 2 + math.floor((i-finalIndex-1)/maxColNormal);
            local targetColumn = math.floor((i-finalIndex-1)%maxColNormal);

            local clone: ImageButton = normalTemplate:Clone();
            clone.Name = petData.fullName;
            clone.Parent = holder;

            clone.Position = UDim2.new(
                clone.Size.X.Scale*targetColumn + clone.Size.X.Scale/2, 
                0, 
                secretTemplate.Size.Y.Scale*secretRows + (clone.Size.Y.Scale-yPaddingCorrection)*(targetRow-secretRows*2) + clone.Size.Y.Scale/2, 
                0
            );

            local rarity = petStats[petData.petName].Rarity;
            clone.Frame.BackgroundColor3 = globals.RarityColors[rarity];
            if rarity == 'Legendary' then
                clone.Glow.Visible = true;
                clone.Frame.Legendary.Enabled = true;
            end

            local clickCon: RBXScriptConnection
            clickCon = clone.MouseButton1Click:Connect(function()
                if not db then db = true task.delay(.15, function() db = false end)
                    if selectedPetID == petData.id then
                        selectedPetID = nil;
                        petInfoHolder.Visible = false;
                    else
                        LoadPetInfo(petData.id);
                    end
                end
            end)
            table.insert(clickConnections, clickCon);
            
            clone.Visible = true;
        end
    end
end

return InventoryHandler;