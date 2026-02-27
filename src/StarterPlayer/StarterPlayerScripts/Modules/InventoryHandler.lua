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
local classes: Folder = rs:WaitForChild('Classes');

local selectedPetID: string = nil;
-- local clickConnections = {};
local petInfoConnections = {};
local petConnections = {};
local bulkButtonsConnected = false;
local mutliDeleteActive = false;
local selectedPets = {};
local selectedPetAmount = 0;

local CreateClickConnection

-- UI
local playerGui = player:WaitForChild('PlayerGui');
local frames: ScreenGui = playerGui:WaitForChild('Frames');
local inventoryFrame: Frame = frames:WaitForChild('Inventory');
local warningFrame: Frame = frames:WaitForChild('Warning');
local templates: Folder = inventoryFrame:WaitForChild('Templates');
local normalTemplate: ImageButton = templates:WaitForChild('Normal');
local secretTemplate: ImageButton = templates:WaitForChild('Secret');
local equippedSecretTemplate: ImageButton = templates:WaitForChild('EquippedSecret');
local main: Frame = inventoryFrame:WaitForChild('Main');
local statsFrame: Frame = main:WaitForChild('Stats');
local equippedStat: Frame = statsFrame:WaitForChild('Equipped');
local storageStat: Frame = statsFrame:WaitForChild('Storage');
local bulkButtons: Frame = main:WaitForChild('BulkButtons');
local equipBest: ImageButton = bulkButtons:WaitForChild('EquipBest');
local unequipAll: ImageButton = bulkButtons:WaitForChild('UnequipAll');
local deleteAll: ImageButton = bulkButtons:WaitForChild('DeleteAll');
local utilityButtons: Frame = main:WaitForChild('UtilityButtons');
local utilButtonsHolder: Frame = utilityButtons:WaitForChild('Holder');
local multiDeleteButton: ImageButton = utilButtonsHolder:WaitForChild('MultiDelete');
local shrinkButton: ImageButton = utilButtonsHolder:WaitForChild('Shrink');
local inventory: Frame = main:WaitForChild('Inventory');
local holder: ScrollingFrame = inventory:WaitForChild('ScrollingFrame');
local equippedHolder: Folder = holder:WaitForChild('Equipped');
local notEquippedHolder: Folder = holder:WaitForChild('NotEquipped');

local petInfo: Frame = main:WaitForChild('PetInfo');
local multiDeleteInfo: Frame = petInfo:WaitForChild('MultiDeleteInfo');
local mutliDeleteButtons: Frame = multiDeleteInfo:WaitForChild('Buttons');
local confirmMultiDelete: ImageButton = mutliDeleteButtons:WaitForChild('Confirm');
local cancelMultiDelete: ImageButton = mutliDeleteButtons:WaitForChild('Cancel');
local petInfoHolder: Frame = petInfo:WaitForChild('Holder');
local petInfoButtons: Frame = petInfoHolder:WaitForChild('Buttons');

-- Modules
local network = require(framework.Network);
local infMath = require(framework.InfiniteMath);
local petStats = require(library.PetStats);
local eggStats = require(library.EggStats);
local globals = require(framework.Globals);
local tblUtil = require(framework.TableUtility);
local warning = require(classes.WarningPopup);
local dataSync = require(script.Parent.DataSyncClient);
local menuHandler = nil;

-- Constants
local maxColSecret = 3;
local maxColNormal = 6;

local function RemovePetConnection(id: string)
    if petConnections[id] then
        petConnections[id]:Disconnect();
        petConnections[id] = nil;
    end
end

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
    local pets = dataSync.Get('Pets');

    for i, data in ipairs(pets) do
        if data.id == id then
            return data;
        end
    end
    return nil;
end

local function GetPetAmount(pets, petName: string)
    local count = 0;
    for i, petData in ipairs(pets) do
        if petData.petName == petName and not petData.shiny and not petData.locked then
            count += 1
        end
    end
    return count;
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
        -- DEBUG TO BE REMOVED
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

    if petData.shiny then
        petInfoButtons.Shiny.Title.Text = 'Already Shiny';
    elseif petData.locked then
        petInfoButtons.Shiny.Title.Text = 'Locked';
    else
        petInfoButtons.Shiny.Title.Text = 'Make Shiny ('..GetPetAmount(dataSync.Get('Pets'), petData.petName)..'/8)';
    end

    SetEquipButtonColor(petData.equipped);

    local equipCon: RBXScriptConnection
    local deleteCon: RBXScriptConnection
    local shinyCon: RBXScriptConnection
    local lockCon: RBXScriptConnection
    local currentlyEquipped = petData.equipped
    equipCon = petInfoButtons.Equip.MouseButton1Click:Connect(function()
        if not db then db = true task.delay(.15, function() db = false end)
            if not currentlyEquipped then
                local success = network:InvokeServer('EquipPet', id);
                if not success then return end;
                currentlyEquipped = true;
                SetEquipButtonColor(currentlyEquipped);
                -- InventoryHandler.LoadInventory();
            else
                local success = network:InvokeServer('UnequipPet', id);
                if not success then return end;
                currentlyEquipped = false;
                SetEquipButtonColor(currentlyEquipped);
                -- InventoryHandler.LoadInventory();
            end
        end
    end)
    deleteCon = petInfoButtons.Delete.MouseButton1Click:Connect(function()
        if not db then db = true task.delay(.15, function() db = false end)
            local success = network:InvokeServer('DeletePet', id);
            if not success then return end;
            selectedPetID = nil;
            petInfoHolder.Visible = false;

            -- InventoryHandler.LoadInventory();
            holder:FindFirstChild(id, true):Destroy();
            RemovePetConnection(id);
        end
    end)
    shinyCon = petInfoButtons.Shiny.MouseButton1Click:Connect(function()
        if not db then db = true task.delay(.15, function() db = false end)
            local success, usedIds = network:InvokeServer('MakeShiny', petData.petName);
            if not success then return end;
            selectedPetID = nil;
            petInfoHolder.Visible = false;

            -- InventoryHandler.LoadInventory();
            for _, id in ipairs(usedIds) do
                holder:FindFirstChild(id, true):Destroy();
                RemovePetConnection(id);
            end
        end
    end)
    lockCon = petInfoHolder.Lock.MouseButton1Click:Connect(function()
        if not db then db = true task.delay(.15, function() db = false end)
            local success, newState = network:InvokeServer('ToggleLock', petData.id);
            if not success then return end;
            -- TODO: Make sure the lock button gets updated after the toggle
            petData.locked = newState;
            -- LoadPetInfo(id);
            local petClone = holder:FindFirstChild(id, true)
            CreateClickConnection(petClone, petData)
            petClone.Frame.Locked.Visible = newState;
        end
    end)
    table.insert(petInfoConnections, equipCon);
    table.insert(petInfoConnections, deleteCon);
    table.insert(petInfoConnections, shinyCon);
    table.insert(petInfoConnections, lockCon);

    selectedPetID = id;
    petInfoHolder.Visible = true;
end

CreateClickConnection = function(clone: ImageButton, petData)
    RemovePetConnection(petData.id);
    local clickCon: RBXScriptConnection = clone.MouseButton1Click:Connect(function()
        if not db then db = true task.delay(.15, function() db = false end)
            if mutliDeleteActive then
                if petData.locked then return end;
                if selectedPets[petData.id] then
                    selectedPets[petData.id] = nil;
                    selectedPetAmount -= 1;
                    clone.Frame.ImageLabel.ImageColor3 = Color3.fromRGB(255, 255, 255);
                else
                    selectedPets[petData.id] = true;
                    selectedPetAmount += 1;
                    clone.Frame.ImageLabel.ImageColor3 = Color3.fromRGB(255,0,0);
                end
                multiDeleteInfo.Info.Text = selectedPetAmount.." Pets selected";
            else
                if selectedPetID == petData.id then
                    selectedPetID = nil;
                    petInfoHolder.Visible = false;
                else
                    selectedPetID = petData.id;
                    LoadPetInfo(petData.id);
                end
            end
        end
    end)
    petConnections[petData.id] = clickCon;
end

local function CreateEquippedPet(petData, template)
    local clone: ImageButton = template:Clone();
    clone.Parent = equippedHolder;
    clone.Name = petData.id;
    clone.Frame.Locked.Visible = petData.locked;
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
    -- clone:GetPropertyChangedSignal('Parent'):Once(function()
    --     if petConnections[petData.id] then
    --         if petConnections[petData.id].Connected then
    --             petConnections[petData.id]:Disconnect();
    --         end
    --         petConnections[petData.id] = nil;
    --     end
    -- end)
    CreateClickConnection(clone, petData);
end

local function CreateNormalPet(petData)
    local clone: ImageButton = normalTemplate:Clone();
    clone.Parent = notEquippedHolder;
    clone.Name = petData.id;
    clone.Frame.Locked.Visible = petData.locked;

    local rarity = petStats[petData.petName].Rarity;
    clone.Frame.BackgroundColor3 = globals.RarityColors[rarity];
    if rarity == 'Legendary' then
        clone.Glow.Visible = true;
        clone.Frame.Legendary.Enabled = true;
    end
    -- clone:GetPropertyChangedSignal('Parent'):Once(function()
    --     if petConnections[petData.id] then
    --         if petConnections[petData.id].Connected then
    --             petConnections[petData.id]:Disconnect();
    --         end
    --         petConnections[petData.id] = nil;
    --     end
    -- end)
    CreateClickConnection(clone, petData);
end

local function CreateSecretPet(petData)
    local clone: ImageButton = secretTemplate:Clone();
    clone.Name = petData.id;
    clone.Parent = notEquippedHolder;
    clone.Frame.PetName.Text = petData.petName;
    clone.Frame.Locked.Visible = petData.locked;
    
    local egg = tblUtil.FindEgg(eggStats, petData.petName);
    local chance = eggStats[egg].Pets[petData.petName][1]
    if chance == 0 then
        clone.Frame.Chance.Text = 'Unknown'
    else
        local simplifiedChance = infMath.new((1/chance)*100);
        clone.Frame.Chance.Text = '1 in '..simplifiedChance:GetSuffix(true);
    end
    -- clone:GetPropertyChangedSignal('Parent'):Once(function()
    --     if petConnections[petData.id] then
    --         if petConnections[petData.id].Connected then
    --             petConnections[petData.id]:Disconnect();
    --         end
    --         petConnections[petData.id] = nil;
    --     end
    -- end)
    CreateClickConnection(clone, petData);
end

local function ReloadPetInfo()
    if not selectedPetID then return end;
    if not inventoryFrame.Visible then return end;
    if mutliDeleteActive then return end;
    LoadPetInfo(selectedPetID);
end

function InventoryHandler.LoadInventory()
    local function ClearMultiDelete()
        mutliDeleteActive = false;
        multiDeleteInfo.Visible = false;
        if selectedPetID then
            petInfoHolder.Visible = true;
        end
        for id, _ in pairs(selectedPets) do
            holder:FindFirstChild(id, true).Frame.ImageLabel.ImageColor3 = Color3.fromRGB(255,255,255);
        end
        table.clear(selectedPets);
        selectedPetAmount = 0;
    end

    if not bulkButtonsConnected then
        confirmMultiDelete.MouseButton1Click:Connect(function()
            if not db then db = true task.delay(.15, function() db = false end)
                if not mutliDeleteActive then return end;
                if selectedPetAmount == 0 then
                    ClearMultiDelete();
                    return;
                end;
    
                local success, deletedIds = network:InvokeServer('DeleteSelection', selectedPets);
                if success then
                    -- InventoryHandler.LoadInventory();
                    for _, id in ipairs(deletedIds) do
                        holder:FindFirstChild(id, true):Destroy();
                        if selectedPetID == id then
                            selectedPetID = nil;
                            petInfoHolder.Visible = false;
                        end
                    end
                    table.clear(selectedPets);
                    ClearMultiDelete();
                end
            end
        end)
        cancelMultiDelete.MouseButton1Click:Connect(function()
            if not db then db = true task.delay(.15, function() db = false end)
                ClearMultiDelete();
            end
        end)
        multiDeleteButton.MouseButton1Click:Connect(function()
            if not db then db = true task.delay(.15, function() db = false end)
                if mutliDeleteActive then
                    ClearMultiDelete();
                else
                    table.clear(selectedPets);
                    selectedPetAmount = 0;
                    
                    mutliDeleteActive = true;
                    petInfoHolder.Visible = false;
                    multiDeleteInfo.Visible = true;
    
                    multiDeleteInfo.Info.Text = "0 Pets selected";
                end
            end
        end)
        equipBest.MouseButton1Click:Connect(function()
            if not db then db = true task.delay(.15, function() db = false end)
                network:FireServer('EquipBest');
                -- if not success then return end;
                -- InventoryHandler.LoadInventory();
                -- if selectedPetID ~= nil then
                --     LoadPetInfo(selectedPetID);
                -- end
            end
        end)
        unequipAll.MouseButton1Click:Connect(function()
            if not db then db = true task.delay(.15, function() db = false end)
                network:FireServer('UnequipAll');
                -- if not success then return end;
                -- InventoryHandler.LoadInventory();
                -- if selectedPetID ~= nil then
                --     LoadPetInfo(selectedPetID);
                -- end
            end
        end)
        deleteAll.MouseButton1Click:Connect(function()
            if not db then db = true task.delay(.15, function() db = false end)
                local warningPopup = warning.new(
                    nil,
                    "Are you sure you want to delete all unlocked pets below the Legendary rarity?",
                    function()
                        menuHandler.handleOpenClose(inventoryFrame)
                        local success, deletedIds = network:InvokeServer('DeleteAllUnlocked');
                        if success then
                            -- InventoryHandler.LoadInventory();
                            for _, id in ipairs(deletedIds) do
                                holder:FindFirstChild(id, true):Destroy();
                                if selectedPetID == id then
                                    selectedPetID = nil;
                                    petInfoHolder.Visible = false;
                                end
                            end
                        end
                    end,
                    function()
                        menuHandler.handleOpenClose(inventoryFrame)
                    end,
                    warningFrame
                )
                menuHandler.handleOpenClose(warningFrame)
            end
        end)
        bulkButtonsConnected = true;
    end


    local pets = dataSync.Get('Pets');
    local normalTbl, secretTbl = SeperatePets(pets, false);
    local equippedNormalTbl, equippedSecretTbl = SeperatePets(pets, true);
    local totalEquipped = #equippedNormalTbl + #equippedSecretTbl;
    table.sort(normalTbl, SortPets);
    table.sort(equippedNormalTbl, SortPets);

    equipBest.Visible = (totalEquipped == 0);
    unequipAll.Visible = not (totalEquipped == 0);

    storageStat.TextLabel.Text = #pets..'/'..dataSync.Get('PetStorage');
    equippedStat.TextLabel.Text = totalEquipped..'/'..dataSync.Get('PetEquips');

    for i, petData in ipairs(equippedSecretTbl) do
        if notEquippedHolder:FindFirstChild(petData.id) then
            notEquippedHolder:FindFirstChild(petData.id):Destroy();
            RemovePetConnection(petData.id);
        end
        if not equippedHolder:FindFirstChild(petData.id) then
            CreateEquippedPet(petData, equippedSecretTemplate);
        end
    end
    for i, petData in ipairs(equippedNormalTbl) do
        if notEquippedHolder:FindFirstChild(petData.id) then
            notEquippedHolder:FindFirstChild(petData.id):Destroy();
            RemovePetConnection(petData.id);
        end
        if not equippedHolder:FindFirstChild(petData.id) then
            CreateEquippedPet(petData, normalTemplate)
        end
    end

    for i, petData in ipairs(secretTbl) do
        if equippedHolder:FindFirstChild(petData.id) then
            equippedHolder:FindFirstChild(petData.id):Destroy();
            RemovePetConnection(petData.id);
        end
        if not notEquippedHolder:FindFirstChild(petData.id) then
            CreateSecretPet(petData);
        end
    end
    for i, petData in ipairs(normalTbl) do
        if equippedHolder:FindFirstChild(petData.id) then
            equippedHolder:FindFirstChild(petData.id):Destroy();
            RemovePetConnection(petData.id);
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

function InventoryHandler.ParseMenuHandler(handler)
    menuHandler = handler;
end

function InventoryHandler.Initialize()
    if not game.Loaded then game.Loaded:Wait() end;

    dataSync.OnChanged('Pets', function()
        InventoryHandler.LoadInventory();
        ReloadPetInfo();
    end)

    dataSync.OnChanged('PetEquips', function()
        InventoryHandler.LoadInventory();
    end)    
    dataSync.OnChanged('CurrentEquips', function()
        InventoryHandler.LoadInventory();
    end)

    dataSync.OnChanged('PetStorage', function()
        InventoryHandler.LoadInventory();
    end)

    -- task.spawn(function()
    --     while task.wait(1) do
    --         if not selectedPetID then continue end;
    --         if not inventoryFrame.Visible then continue end;
    --         if mutliDeleteActive then continue end;
    --         LoadPetInfo(selectedPetID);
    --     end
    -- end)
end

return InventoryHandler;