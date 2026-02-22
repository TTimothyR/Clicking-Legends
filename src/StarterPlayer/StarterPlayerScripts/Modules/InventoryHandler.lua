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
-- local clickConnections = {};
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
local equippedHolder: Folder = holder:WaitForChild('Equipped');
local notEquippedHolder: Folder = holder:WaitForChild('NotEquipped');

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
        return;
    end
    for _, con: RBXScriptConnection in ipairs(petInfoConnections) do
        if con.Connected then
            con:Disconnect();
        end
    end

    local date = os.date('*t', petData.date);

    local xpNeeded = globals.XPForNextLevel(petData.level, petData.shiny);

    petInfoHolder.PetName.Text = petData.fullName;
    petInfoHolder.FoundDate.Text = 'Found on '..date.day..'/'..date.month..'/'..(date.year-2000);
    petInfoHolder.Level.Text = 'Level '..petData.level;
    petInfoHolder.XP.Progress.Text = petData.xp..' / '..infMath.new(xpNeeded):GetSuffix(true)..' XP'

    local clicks = globals.GetPetClicks(petData);
    local gems = globals.GetPetGems(petData);

    petInfoHolder.Stats.Clicks.Amount.Text = infMath.new(clicks):GetSuffix(true);
    petInfoHolder.Stats.Gems.Amount.Text = infMath.new(gems):GetSuffix(true);

    SetEquipButtonColor(petData.equipped);

    local equipCon: RBXScriptConnection
    local deleteCon: RBXScriptConnection
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
    deleteCon = petInfoButtons.Delete.MouseButton1Click:Connect(function()
        if not db then db = true task.delay(.15, function() db = false end)
            local success = network:InvokeServer('DeletePet', id);
            if not success then return end;
            selectedPetID = nil;
            petInfoHolder.Visible = false;

            InventoryHandler.LoadInventory();
            holder:FindFirstChild(id, true):Destroy();
        end
    end)
    table.insert(petInfoConnections, equipCon);
    table.insert(petInfoConnections, deleteCon)

    selectedPetID = id;
    petInfoHolder.Visible = true;
end

local function CreateClickConnection(clone: ImageButton, petData)
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
    clone:GetPropertyChangedSignal('Parent'):Once(function()
        print('Button destroyed, disconnecting click conneciton')
        clickCon:Disconnect();
    end)
    -- table.insert(clickConnections, clickCon);
end

local function CreateEquippedPet(petData, template)
    local clone: ImageButton = template:Clone();
    clone.Parent = equippedHolder;
    clone.Name = petData.id;
    if clone.Frame:FindFirstChild('PetName') then
        local egg = tblUtil.FindEgg(eggStats, petData.petName);
        local chance = eggStats[egg].Pets[petData.petName][1]
        if chance == 0 then
            clone.Frame.Chance.Text = 'Unknown'
        else
            local simplifiedChance = infMath.new((1/chance)*100);
            clone.Frame.Chance.Text = '1 in '..simplifiedChance:GetSuffix(true);
        end
        clone.Frame.PetName.Text = petData.petName;
    else
        local rarity = petStats[petData.petName].Rarity;
        clone.Frame.BackgroundColor3 = globals.RarityColors[rarity];
        if rarity == 'Legendary' then
            clone.Glow.Visible = true;
            clone.Frame.Legendary.Enabled = true;
        end
    end
    CreateClickConnection(clone, petData);
end

local function CreateNormalPet(petData)
    local clone: ImageButton = normalTemplate:Clone();
    clone.Parent = notEquippedHolder;
    clone.Name = petData.id;
    
    local rarity = petStats[petData.petName].Rarity;
    clone.Frame.BackgroundColor3 = globals.RarityColors[rarity];
    if rarity == 'Legendary' then
        clone.Glow.Visible = true;
        clone.Frame.Legendary.Enabled = true;
    end
    
    CreateClickConnection(clone, petData);
end

local function CreateSecretPet(petData)
    local clone: ImageButton = secretTemplate:Clone();
    clone.Name = petData.id;
    clone.Parent = notEquippedHolder;
    clone.Frame.PetName.Text = petData.petName;
    
    local egg = tblUtil.FindEgg(eggStats, petData.petName);
    local chance = eggStats[egg].Pets[petData.petName][1]
    if chance == 0 then
        clone.Frame.Chance.Text = 'Unknown'
    else
        local simplifiedChance = infMath.new((1/chance)*100);
        clone.Frame.Chance.Text = '1 in '..simplifiedChance:GetSuffix(true);
    end

    CreateClickConnection(clone, petData);
end

function InventoryHandler.LoadInventory()
    local profile = network:InvokeServer('GetData');
    if not profile then
        warn('Failed to load player profile');
        return;
    end

    local pets = profile.Pets;
    local normalTbl, secretTbl = SeperatePets(pets, false);
    local equippedNormalTbl, equippedSecretTbl = SeperatePets(pets, true);
    local totalEquipped = #equippedNormalTbl + #equippedSecretTbl;
    table.sort(normalTbl, SortPets);
    table.sort(equippedNormalTbl, SortPets);

    for i, petData in ipairs(equippedSecretTbl) do
        if notEquippedHolder:FindFirstChild(petData.id) then
            notEquippedHolder:FindFirstChild(petData.id):Destroy();
        end
        if not equippedHolder:FindFirstChild(petData.id) then
            CreateEquippedPet(petData, equippedSecretTemplate);
        end
    end
    for i, petData in ipairs(equippedNormalTbl) do
        if notEquippedHolder:FindFirstChild(petData.id) then
            notEquippedHolder:FindFirstChild(petData.id):Destroy();
        end
        if not equippedHolder:FindFirstChild(petData.id) then
            CreateEquippedPet(petData, normalTemplate)
        end
    end

    for i, petData in ipairs(secretTbl) do
        if equippedHolder:FindFirstChild(petData.id) then
            equippedHolder:FindFirstChild(petData.id):Destroy();
        end
        if not notEquippedHolder:FindFirstChild(petData.id) then
            CreateSecretPet(petData);
        end
    end
    for i, petData in ipairs(normalTbl) do
        if equippedHolder:FindFirstChild(petData.id) then
            equippedHolder:FindFirstChild(petData.id):Destroy();
        end
        if not notEquippedHolder:FindFirstChild(petData.id) then
            CreateNormalPet(petData);
        end
    end

    local lastEquippedRow = -1

    for i, petData in ipairs(equippedSecretTbl) do
        local row = math.floor((i-1)/maxColNormal);
        local col = math.floor((i-1)%maxColNormal);

        local clone: ImageButton = equippedHolder:FindFirstChild(petData.id);
        clone.Position = UDim2.new(
            clone.Size.X.Scale*col + clone.Size.X.Scale/2,
            0,
            clone.Size.Y.Scale*row + clone.Size.Y.Scale/2,
            0
        );

        lastEquippedRow = row;
        clone.Visible = true;
    end
    for i, petData in ipairs(equippedNormalTbl) do
        local row = math.floor((i+#equippedSecretTbl-1)/maxColNormal);
        local col = math.floor((i+#equippedSecretTbl-1)%maxColNormal);

        local clone: ImageButton = equippedHolder:FindFirstChild(petData.id);
        clone.Position = UDim2.new(
            clone.Size.X.Scale*col + clone.Size.X.Scale/2,
            0,
            clone.Size.Y.Scale*row + clone.Size.Y.Scale/2,
            0
        );

        lastEquippedRow = row;
        clone.Visible = true;
    end

    lastEquippedRow += 1;

    local lastRow = 0;
    local lastColumn = 0;

    for i, petData in ipairs(secretTbl) do
        local row = math.floor((i-1)/maxColSecret);
        lastRow = (row+1)*2;
        local column = math.floor((i-1)%maxColSecret);
        lastColumn = ((column+1)%maxColSecret)*2;

        local clone: ImageButton = notEquippedHolder:FindFirstChild(petData.id);
        
        clone.Position = UDim2.new(
            clone.Size.X.Scale*column + clone.Size.X.Scale/2,
            0,
            clone.Size.Y.Scale*row + clone.Size.Y.Scale/2 + normalTemplate.Size.Y.Scale * lastEquippedRow,
            0
        );

        clone.Visible = true;
    end

    local savedColumn = lastColumn;
    local rowsFilled = 0;
    local finalIndex = 0;
    local secretRows = math.ceil(#secretTbl/maxColSecret);
    local yPaddingCorrection = 0.043;
    local equipCorrection = (totalEquipped == 0) and 0 or yPaddingCorrection*3;
    local finalCorrection = lastEquippedRow == 0 and normalTemplate.Size.Y.Scale/2 or 0;

    for i, petData in ipairs(normalTbl) do
        local clone: ImageButton = notEquippedHolder:FindFirstChild(petData.id);

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
            clone.Position = UDim2.new(xPos, 0, yPos, 0)
            finalIndex = i;
        else
            local targetRow = secretRows * 2 + math.floor((i-finalIndex-1)/maxColNormal);
            local targetColumn = math.floor((i-finalIndex-1)%maxColNormal);

            local xPos = normalTemplate.Size.X.Scale*targetColumn + normalTemplate.Size.X.Scale/2;
            local yPos = secretTemplate.Size.Y.Scale*secretRows + (normalTemplate.Size.Y.Scale-yPaddingCorrection)*(targetRow-secretRows*2) + (normalTemplate.Size.Y.Scale * lastEquippedRow) + equipCorrection + finalCorrection;
            clone.Position = UDim2.new(xPos, 0, yPos, 0)
        end

        clone.Visible = true;
    end
end



function InventoryHandler.Initialize()
    if not game.Loaded then game.Loaded:Wait() end;

    task.spawn(function()
        while task.wait(1) do
            if not selectedPetID then continue end;
            if not inventoryFrame.Visible then continue end;
            LoadPetInfo(selectedPetID);
        end
    end)
end

return InventoryHandler;