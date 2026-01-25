local InventoryHandler = {};

-- Services
local players = game:GetService('Players');
local rs = game:GetService('ReplicatedStorage');

-- Variables
repeat task.wait() until players.LocalPlayer;
local player: Player = players.LocalPlayer;

local framework = rs:WaitForChild('Framework');
local library = framework:WaitForChild('Library');

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

-- Modules
local network = require(framework.Network);
local petStats = require(library.PetStats);

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

function InventoryHandler.LoadInventory()
    local profile = network:InvokeServer('GetData');
    if not profile then
        warn('Failed to load player profile');
        return;
    end

    holder:ClearAllChildren();

    local pets = profile.Pets;
    local normalTbl, secretTbl = SeperatePets(pets);

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
            local targetRow = lastRow - 1;
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
            
            clone.Visible = true;
        end
    end
end

return InventoryHandler;