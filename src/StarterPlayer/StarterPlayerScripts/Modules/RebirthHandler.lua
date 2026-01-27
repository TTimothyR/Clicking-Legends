local RebirthHandler = {};
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
local autoRebirthStatus = false;
local autoRebirthSelect = false;
local selectedIndex = 0;

-- UI
local playerGui = player:WaitForChild('PlayerGui');
local frames: ScreenGui = playerGui:WaitForChild('Frames');
local rebirthFrame: Frame = frames:WaitForChild('Rebirths');
local main: Frame = rebirthFrame:WaitForChild('Main');
local templates: Folder = main:WaitForChild('Templates');
local rebirthTemplate: Frame = templates:WaitForChild('RebirthTemplate');
local list: Frame = main:WaitForChild('List');
local holder: ScrollingFrame = list:WaitForChild('ScrollingFrame');
local autoRebirthFrame: Frame = main:WaitForChild('AutoRebirth');
local autoRebirthToggle: ImageButton = autoRebirthFrame:WaitForChild('Toggle');
local autoRebirthSettings: ImageButton = rebirthFrame:WaitForChild('AutoSettings');

-- Modules
local rebirthStats = require(library.RebirthStats);
local globals = require(framework.Globals);
local infMath = require(framework.InfiniteMath);
local network = require(framework.Network);

local function UpdateButtonColor(inner: Frame, color: string)
    inner.Click.Frame.UIGradient.Color = globals.ButtonPresets[color].Gradient;
    inner.Click.Frame.UIStroke.Color = globals.ButtonPresets[color].StrokeColor;
    inner.Click.Title.UIStroke.Color = globals.ButtonPresets[color].StrokeColor;

    if color == 'Purple' then
        if tonumber(inner.Parent.Name) == selectedIndex then
            inner.Click.Title.Text = 'Selected'
        else
            inner.Click.Title.Text = 'Select'
        end
    else
        inner.Click.Title.Text = 'Rebirth'
    end
end

local function UpdateButton(inner: Frame, price)
    local playerClicks = infMath.new(http:JSONDecode(player:GetAttribute('Clicks')));
    local color = '';
    if playerClicks >= price then
        color = 'Green';
    else
        color = 'Red';
    end
    UpdateButtonColor(inner, color)
end

local function UpdateButtons(fromSignal: boolean)
    local playerRebirths = infMath.new(http:JSONDecode(player:GetAttribute('Rebirths')));
    local playerClicks = infMath.new(http:JSONDecode(player:GetAttribute('Clicks')));

    if (rebirthFrame.Visible or not fromSignal) and not autoRebirthSelect then
        for index, rebirths in ipairs(rebirthStats) do
            local clone: Frame = holder:FindFirstChild(index);
            
            local word = (rebirths == 1) and 'Rebirth' or 'Rebirths';
            
            local cost = infMath.new(globals.RebirthBasePrice * rebirths * playerRebirths);
            
            local inner: Frame = clone.Inner;
            inner.Amount.Text = '+'..tostring(rebirths)..' '..word..' ('..cost:GetSuffix(true)..' Clicks)';
            UpdateButton(inner, cost);
            
            inner.AutoStroke.Enabled = (selectedIndex == index);
            
            clone.Visible = true;
        end
        main.Rebirths.Amount.Text = 'Rebirths: '..playerRebirths:GetSuffix(true);
    end
    
    for index, rebirths in ipairs(rebirthStats) do
        local cost = infMath.new(globals.RebirthBasePrice * rebirths * playerRebirths);
        if autoRebirthStatus and selectedIndex == index and (playerClicks >= cost) then
            network:FireServer('AttemptRebirth', index);
        end
    end
end

local function UpdateAutoRebirthButton(status: boolean)
    local color = '';
    local text = '';
    if status then
        color = 'Green';
        text = 'On';
    else
        color = 'Red';
        text = 'Off';
    end
    autoRebirthToggle.Frame.UIGradient.Color = globals.ButtonPresets[color].Gradient;
    autoRebirthToggle.Frame.UIStroke.Color = globals.ButtonPresets[color].StrokeColor;
    autoRebirthToggle.Title.UIStroke.Color = globals.ButtonPresets[color].StrokeColor;
    autoRebirthToggle.Title.Text = text;
end

local function LoadAutoRebirth()
    local profile = network:InvokeServer('GetData');

    autoRebirthStatus = profile.AutoRebirthStatus;
    selectedIndex = profile.AutoRebirthIndex;
    UpdateAutoRebirthButton(autoRebirthStatus);
end

function RebirthHandler.LoadRebirthButtons()
    if #holder:GetChildren() - 1 == #rebirthStats then
        UpdateButtons(false);
        return;
    end
    for index, _ in ipairs(rebirthStats) do
        local clone: Frame = rebirthTemplate:Clone();
        local inner = clone.Inner;
        clone.Parent = holder;
        clone.LayoutOrder = index;
        clone.Name = index;

        inner.Click.MouseButton1Click:Connect(function()
            if not db then db = true task.delay(.15, function() db = false end)
                if autoRebirthSelect then
                    selectedIndex = network:InvokeServer('SetAutoRebirthIndex', index);
                    autoRebirthSelect = false;
                    UpdateButtons(false);
                else
                    network:FireServer('AttemptRebirth', index);
                end
            end
        end)
    end
    UpdateButtons(false);
end

function RebirthHandler.Initialize()
    if not game.Loaded then game.Loaded:Wait() end;

    task.spawn(LoadAutoRebirth)

    autoRebirthToggle.MouseButton1Click:Connect(function()
        if not db then db = true task.delay(.15, function() db = false end)
            autoRebirthStatus = network:InvokeServer('ToggleAutoRebirth');
            UpdateAutoRebirthButton(autoRebirthStatus);
        end
    end)

    autoRebirthSettings.MouseButton1Click:Connect(function()
        if not db then db = true task.delay(.15, function() db = false end)
            if not autoRebirthSelect then
                autoRebirthSelect = true;
                for _, child in ipairs(holder:GetChildren()) do
                    if child:IsA('Frame') then
                        UpdateButtonColor(child.Inner, 'Purple');
                    end
                end
            else
                autoRebirthSelect = false;
                UpdateButtons(false);
            end
        end
    end)

    player:GetAttributeChangedSignal('Clicks'):Connect(function()
        UpdateButtons(true);
    end)
    player:GetAttributeChangedSignal('Rebirths'):Connect(function()
        UpdateButtons(true);
    end)
end

return RebirthHandler;