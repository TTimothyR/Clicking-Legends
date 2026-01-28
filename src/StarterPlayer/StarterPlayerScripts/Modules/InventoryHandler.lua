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
local petInfoConnections = {};

-- UI
local playerGui = player:WaitForChild('PlayerGui');
local frames: ScreenGui = playerGui:WaitForChild('Frames');
local inventoryFrame: Frame = frames:WaitForChild('Inventory');
local templates: Folder = inventoryFrame:WaitForChild('Templates');
local normalTemplate: ImageButton = templates:WaitForChild('Normal');
local secretTemplate: ImageButton = templates:WaitForChild('Secret');
local equippedSecretTemplate: ImageButton = templates:WaitForChild('EquippedSecret');
local main: Frame = inventoryFrame:WaitForChild('Main');
local inventory: Frame = main:WaitForChild('Inventory');
local holder: ScrollingFrame = inventory:WaitForChild('ScrollingFrame');

local petInfo: Frame = main:WaitForChild('PetInfo');
local petInfoHolder: Frame = petInfo:WaitForChild('Holder');
local petInfoButtons: Frame = petInfoHolder:WaitForChild('Buttons');

-- Modules
local network = require(framework.Network);
local infMath = require(framework.InfiniteMath);
local petStats = require(library.PetStats);
local eggStats = require(library.EggStats);
local globals = require(framework.Globals);
local tblUtil = require(framework.TableUtility)

-- Constants
local maxColSecret = 3;
local maxColNormal = 6;

local function SeperatePets(petsTbl, equipped)
    local normalTbl = {};
    local secretTbl = {};
    
    for i, petData in ipairs(petsTbl) do
        if petData.equipped == equipped then
            if petStats[petData.petName].Secret then
                table.insert(secretTbl, petData);
            else
                table.insert(normalTbl, petData);
            end
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

local function SetEquipButtonColor(newStatus: boolean)
    local equipButton: ImageButton = petInfoButtons.Equip;
    local color = '';
    local text = '';
    if newStatus then
        color = 'Red';
        text = 'Unequip';
    else
        color = 'Green';
        text = 'Equip';
    end
    equipButton.Frame.UIGradient.Color = globals.ButtonPresets[color].Gradient;
    equipButton.Frame.UIStroke.Color = globals.ButtonPresets[color].StrokeColor;
    equipButton.Title.UIStroke.Color = globals.ButtonPresets[color].StrokeColor;
    equipButton.Title.Text = text;
end

local function LoadPetInfo(id: string)
    local petData = GetPetData(id);
    if not petData then
        warn('Player does not own pet with ID:', id);
    end
    for _, con: RBXScriptConnection in ipairs(petInfoConnections) do
        if con.Connected then
            con:Disconnect();
        end
    end

    local date = os.date('*t', petData.date);

    petInfoHolder.PetName.Text = petData.fullName;
    petInfoHolder.FoundDate.Text = 'Found on '..date.day..'/'..date.month..'/'..(date.year-2000);
    petInfoHolder.Level.Text = 'Level '..petData.level;

    local petStat = petStats[petData.petName];

    petInfoHolder.Stats.Clicks.Amount.Text = infMath.new(petStat.Clicks):GetSuffix(true);
    petInfoHolder.Stats.Gems.Amount.Text = petStat.GemMulti;

    SetEquipButtonColor(petData.equipped);

    local equipCon: RBXScriptConnection
    local currentlyEquipped = petData.equipped
    equipCon = petInfoButtons.Equip.MouseButton1Click:Connect(function()
        if not db then db = true task.delay(.15, function() db = false end)
            if not currentlyEquipped then
                local success = network:InvokeServer('EquipPet', id);
                if not success then return end;
                currentlyEquipped = true;
                SetEquipButtonColor(currentlyEquipped);
                InventoryHandler.LoadInventory();
            else
                local success = network:InvokeServer('UnequipPet', id);
                if not success then return end;
                currentlyEquipped = false;
                SetEquipButtonColor(currentlyEquipped);
                InventoryHandler.LoadInventory();
            end
        end
    end)
    table.insert(petInfoConnections, equipCon);

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
    local normalTbl, secretTbl = SeperatePets(pets, false);
    local equippedNormalTbl, equippedSecretTbl = SeperatePets(pets, true);
    local totalEquipped = #equippedNormalTbl + #equippedSecretTbl;
    table.sort(normalTbl, SortPets);
    table.sort(equippedNormalTbl, SortPets);

    local function createClickConnection(clone, petData)
        local clickCon: RBXScriptConnection = clone.MouseButton1Click:Connect(function()
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
    end

    local function createEquippedPet(petData, template, row, col)
        local clone: ImageButton = template:Clone();
        clone.Parent = holder;
        clone.Name = petData.fullName;
        if clone.Frame:FindFirstChild('PetName') then
            local egg = tblUtil.FindEgg(eggStats, petData.petName);
            local chance = eggStats[egg].Pets[petData.petName][1]
            local simplifiedChance = infMath.new((1/chance)*100);
            clone.Frame.PetName.Text = petData.petName;
            clone.Frame.Chance.Text = '1 in '..simplifiedChance:GetSuffix(true);
        else
            local rarity = petStats[petData.petName].Rarity;
            clone.Frame.BackgroundColor3 = globals.RarityColors[rarity];
            if rarity == 'Legendary' then
                clone.Glow.Visible = true;
                clone.Frame.Legendary.Enabled = true;
            end
        end
        clone.Position = UDim2.new(
            clone.Size.X.Scale*col + clone.Size.X.Scale/2,
            0,
            clone.Size.Y.Scale*row + clone.Size.Y.Scale/2,
            0
        );
        createClickConnection(clone, petData);
        clone.Visible = true;
    end

    local lastEquippedRow = -1;

    for i, petData in ipairs(equippedSecretTbl) do
        local row = math.floor((i-1)/maxColNormal);
        local col = math.floor((i-1)%maxColNormal);
        createEquippedPet(petData, equippedSecretTemplate, row, col);
        lastEquippedRow = row;
    end

    for i, petData in ipairs(equippedNormalTbl) do
        local row = math.floor((i+#equippedSecretTbl-1)/maxColNormal);
        local col = math.floor((i+#equippedSecretTbl-1)%maxColNormal);
        createEquippedPet(petData, normalTemplate, row, col);
        lastEquippedRow = row;
    end

    lastEquippedRow += 1;

    local lastRow = 0;
    local lastColumn = 0;

    for i, petData in ipairs(secretTbl) do
        local row = math.floor((i-1)/maxColSecret);
        lastRow = (row+1)*2;
        local column = math.floor((i-1)%maxColSecret);
        lastColumn = ((column+1)%maxColSecret)*2;

        local clone: ImageButton = secretTemplate:Clone();
        clone.Name = petData.fullName;
        clone.Parent = holder;
        clone.Frame.PetName.Text = petData.petName;
        
        local egg = tblUtil.FindEgg(eggStats, petData.petName);
        local chance = eggStats[egg].Pets[petData.petName][1]
        local simplifiedChance = infMath.new((1/chance)*100);
        clone.Frame.Chance.Text = '1 in '..simplifiedChance:GetSuffix(true);
        
        clone.Position = UDim2.new(
            clone.Size.X.Scale*column + clone.Size.X.Scale/2,
            0,
            clone.Size.Y.Scale*row + clone.Size.Y.Scale/2 + normalTemplate.Size.Y.Scale * lastEquippedRow,
            0
        );
        createClickConnection(clone, petData);
        clone.Visible = true;
    end

    local savedColumn = lastColumn;
    local rowsFilled = 0;
    local finalIndex = 0;
    local secretRows = math.ceil(#secretTbl/maxColSecret);
    local yPaddingCorrection = 0.043;
    local equipCorrection = (totalEquipped == 0) and 0 or yPaddingCorrection*3;
    local finalCorrection = lastEquippedRow == 0 and normalTemplate.Size.Y.Scale/2 or 0;

    local function createNormalPet(petData, xPos, yPos)
        local clone: ImageButton = normalTemplate:Clone();
        clone.Name = petData.fullName;
        clone.Parent = holder;
        clone.Position = UDim2.new(xPos, 0, yPos, 0);
        
        local rarity = petStats[petData.petName].Rarity;
        clone.Frame.BackgroundColor3 = globals.RarityColors[rarity];
        if rarity == 'Legendary' then
            clone.Glow.Visible = true;
            clone.Frame.Legendary.Enabled = true;
        end
        
        createClickConnection(clone, petData);
        clone.Visible = true;
    end

    for i, petData in ipairs(normalTbl) do
        if lastColumn > 0 and rowsFilled < 2 then
            local targetColumn = lastColumn + 1;
            local row = math.floor((i-1)/(maxColNormal-savedColumn));
            
            lastColumn += 1;
            if lastColumn == 6 then
                rowsFilled += 1;
                lastColumn = savedColumn;
                lastRow += 1;
            end

            local xPos = normalTemplate.Size.X.Scale*(targetColumn-1) + normalTemplate.Size.X.Scale/2;
            local yPos = secretTemplate.Size.Y.Scale*(secretRows-1) + (normalTemplate.Size.Y.Scale-yPaddingCorrection)*row + (normalTemplate.Size.Y.Scale * lastEquippedRow) + equipCorrection + finalCorrection;
            createNormalPet(petData, xPos, yPos);
            finalIndex = i;
        else
            local targetRow = secretRows * 2 + math.floor((i-finalIndex-1)/maxColNormal);
            local targetColumn = math.floor((i-finalIndex-1)%maxColNormal);

            local xPos = normalTemplate.Size.X.Scale*targetColumn + normalTemplate.Size.X.Scale/2;
            local yPos = secretTemplate.Size.Y.Scale*secretRows + (normalTemplate.Size.Y.Scale-yPaddingCorrection)*(targetRow-secretRows*2) + (normalTemplate.Size.Y.Scale * lastEquippedRow) + equipCorrection + finalCorrection;
            createNormalPet(petData, xPos, yPos);
        end
    end
end


return InventoryHandler;