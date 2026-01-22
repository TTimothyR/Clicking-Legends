local ClickHandler = {};
local db = false;

-- Services
local players = game:GetService('Players');
local ts = game:GetService('TweenService');
local rs = game:GetService('ReplicatedStorage');

-- Variables
repeat task.wait() until players.LocalPlayer;
local plr: Player = players.LocalPlayer;

local framework: Folder = rs:WaitForChild('Framework');

-- UI
local playerGui: PlayerGui = plr:WaitForChild('PlayerGui');
local hud: ScreenGui = playerGui:WaitForChild('HUD');
local clickButton: ImageButton = hud:WaitForChild('Click');

local left: Frame = hud:WaitForChild('Left');
local statsFrame: Frame = left:WaitForChild('Stats');

local shine: ImageLabel = clickButton:WaitForChild('Shine');
local template: Frame = clickButton:WaitForChild('Template');
local animationFrames: Folder = clickButton:WaitForChild('AnimationFrames');

-- Modules
local network = require(framework.Network);
local infMath = require(framework.InfiniteMath);

-- Constants
local rotationTime = 15;
local animationTime = 0.5;
local debounceTime = 0.05;

local function AnimateShine()
    while true do
        local tween1 = ts:Create(shine, TweenInfo.new(rotationTime/2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {Rotation = 360});
        tween1:Play();
        tween1.Completed:Wait();
        shine.Rotation = 0;
    end
end

local function ClickAnimation()
    local clone: Frame = template:Clone();
    clone.Parent = animationFrames;

    clone:TweenSize(UDim2.new(1.25,0,1.25,0), Enum.EasingDirection.Out, Enum.EasingStyle.Sine, animationTime);
    local tween: Tween = ts:Create(clone, TweenInfo.new(animationTime, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {BackgroundTransparency = 1});
    tween:Play();
    tween.Completed:Wait();

    clone:Destroy();
end

local function PopUp()
    -- TODO
end

local function UpdateStatDisplay(currencyStr: string, newValue)
    local currencyFrame: Frame = statsFrame[currencyStr]
    currencyFrame.Background.Amount.Text = infMath.new(newValue):GetSuffix(true);
end

local function Click()
    task.spawn(ClickAnimation);
    task.spawn(PopUp);
    
    network:FireServer('Click');
end

function ClickHandler.LoadStatDisplay(profile)
    local currencies = {'Clicks', 'Gems'};

    for _, currency: string in ipairs(currencies) do
        statsFrame[currency].Background.Amount.Text = infMath.new(profile[currency]):GetSuffix(true);
    end
end

function ClickHandler.Initialize()
    if not game.Loaded then game.Loaded:Wait() end;

    task.spawn(AnimateShine);

    clickButton.MouseButton1Click:Connect(function()
        if not db then db = true task.delay(debounceTime, function() db = false end)
            Click();
        end
    end)

    plr:WaitForChild('leaderstats').Clicks.Changed:Connect(function(newValue)
        UpdateStatDisplay('Clicks', newValue);
    end)
    plr:WaitForChild('leaderstats').Gems.Changed:Connect(function(newValue)
        UpdateStatDisplay('Gems', newValue);
    end)
end

return ClickHandler;