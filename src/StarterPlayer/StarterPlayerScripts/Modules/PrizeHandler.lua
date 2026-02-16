local PrizeHandler = {};
local db = false;

-- Services
local players = game:GetService('Players');
local rs = game:GetService('ReplicatedStorage');
local http = game:GetService('HttpService');

-- Variables
repeat task.wait() until players.LocalPlayer;
local player: Player = players.LocalPlayer;

local framework: Folder = rs:WaitForChild('Framework');
local library: Folder = framework:WaitForChild('Library');

local selectedType: string = 'Eggs';
local UpdatePrizes
local clickConnections = {};

-- UI
local playerGui: PlayerGui = player:WaitForChild('PlayerGui');
local frames: ScreenGui = playerGui:WaitForChild('Frames');
local prizeFrame: Frame = frames:WaitForChild('Prizes');
local templates: Folder = prizeFrame:WaitForChild('Templates');
local prizeTemplate: Frame = templates:WaitForChild('PrizeTemplate');
local buttonsFrame: Frame = prizeFrame:WaitForChild('Buttons');
local eggsButton: ImageButton = buttonsFrame:WaitForChild('Eggs');
local clicksButton: ImageButton = buttonsFrame:WaitForChild('Clicks');
local main: Frame = prizeFrame:WaitForChild('Main');
local holderFrame: Frame = main:WaitForChild('Holder');
local scrollingHolder: ScrollingFrame = holderFrame:WaitForChild('ScrollingFrame');

-- Modules
local prizes = require(library.Prizes);
local infMath = require(framework.InfiniteMath);
local network = require(framework.Network);

local function IsPrizeClaimed(prizeData, prizeIndex)
    for i, idx in ipairs(prizeData) do
        if idx == prizeIndex then
            return true;
        end
    end
    return false;
end

local function UpdatePrizeProgress(clone: Frame, targetType: string, data, claimedPrizes)
    local claimed: boolean = IsPrizeClaimed(claimedPrizes[targetType], clone.Name);
    
    local target = infMath.new(data.Target);
    local goal: string = (targetType == 'Eggs') and 'Hatch '..target:GetSuffix(true)..' Eggs' or 'Click '..target:GetSuffix(true)..' Times';
    clone.Task.Text = goal;

    local currentProgress = infMath.new(http:JSONDecode(player:GetAttribute(targetType)));
    local procentualProgress = infMath.new(currentProgress/target):GetSuffix(true);

    clone.Progress.Level.Text = (currentProgress < target) and currentProgress:GetSuffix(true)..' / '..target:GetSuffix(true) or 'Completed';
    clone.Progress.Frame.Size = UDim2.new(math.min(tonumber(procentualProgress), 1), 0, 1, 0);

    clone.Accept.CantClaim.Visible = (currentProgress < target);
    if claimed then
        clone.Accept.Title.Text = 'Claimed';
    end
end

local function UpdatePrizes()
    local profile = network:InvokeServer('GetData');
    for i, data in ipairs(prizes[selectedType]) do
        local clone: Frame = scrollingHolder:FindFirstChild(i);

        UpdatePrizeProgress(clone, selectedType, data, profile.ClaimedPrizes);
    end
end

function PrizeHandler.LoadPrizes(targetType: string)
    local profile = network:InvokeServer('GetData');
    targetType = targetType or selectedType;

    for _, instance in ipairs(scrollingHolder:GetChildren()) do
        if instance:IsA('Frame') then
            instance:Destroy();
        end
    end

    for i, data in ipairs(prizes[targetType]) do
        local clone: Frame = prizeTemplate:Clone();
        clone.Parent = scrollingHolder;
        clone.LayoutOrder = i;
        clone.Name = i;

        UpdatePrizeProgress(clone, targetType, data, profile.ClaimedPrizes);

        local clickConnection: RBXScriptConnection
        clickConnection = clone.Accept.MouseButton1Click:Connect(function()
            if not db then db = true task.delay(.15, function() db = false end)
                local success = network:InvokeServer('ClaimPrize', targetType, clone.Name);
                if not success then return end;
                UpdatePrizes();
            end
        end)
        clone:GetPropertyChangedSignal('Parent'):Once(function()
            clickConnection:Disconnect();
        end)

        clone.Visible = true;
    end
end

function PrizeHandler.Initialize()
    if not game.Loaded then game.Loaded:Wait() end;

    eggsButton.MouseButton1Click:Connect(function()
        if not db then db = true task.delay(.15, function() db = false end);
            if selectedType ~= 'Eggs' then
                selectedType = 'Eggs';
                PrizeHandler.LoadPrizes(selectedType);
            end
        end
    end)    
    clicksButton.MouseButton1Click:Connect(function()
        if not db then db = true task.delay(.15, function() db = false end);
            if selectedType ~= 'ActualClicks' then
                selectedType = 'ActualClicks';
                PrizeHandler.LoadPrizes(selectedType);
            end
        end
    end)

    player:GetAttributeChangedSignal('ActualClicks'):Connect(function()
        if selectedType == 'ActualClicks' and prizeFrame.Visible then
            UpdatePrizes();
        end
    end)

    player:GetAttributeChangedSignal('Eggs'):Connect(function()
        if selectedType == 'Eggs' and prizeFrame.Visible then
            UpdatePrizes()
        end
    end)
end

return PrizeHandler;