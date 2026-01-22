local ClickHandler = {};

-- Services
local players = game:GetService('Players');
local ts = game:GetService('TweenService');

-- Variables
repeat task.wait() until players.LocalPlayer;
local plr: Player = players.LocalPlayer;

-- UI
local playerGui: PlayerGui = plr:WaitForChild('PlayerGui');
local hud: ScreenGui = playerGui:WaitForChild('HUD');
local clickButton: ImageButton = hud:WaitForChild('Click');
local shine: ImageLabel = clickButton:WaitForChild('Shine');

-- Constants
local rotationTime = 10;

local function AnimateShine()
    while true do
        local tween1 = ts:Create(shine, TweenInfo.new(rotationTime/2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {Rotation = 360});
        tween1:Play();
        tween1.Completed:Wait();    
        shine.Rotation = 0;
    end
end

function ClickHandler.Initialize()
    if not game.Loaded then game.Loaded:Wait() end;

    task.spawn(AnimateShine);
end

return ClickHandler;