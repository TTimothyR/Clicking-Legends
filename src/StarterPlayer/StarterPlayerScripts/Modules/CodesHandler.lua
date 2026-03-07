local CodesHandler = {};
local db = false;

-- Services
local players = game:GetService('Players');
local rs = game:GetService('ReplicatedStorage');

-- Variables
repeat task.wait() until players.LocalPlayer;
local player: Player = players.LocalPlayer;

local framework: Folder = rs:WaitForChild('Framework');

local currentInput = '';

-- UI
local playerGui = player:WaitForChild('PlayerGui');
local frames: ScreenGui = playerGui:WaitForChild('Frames');
local shopFrame: Frame = frames:WaitForChild('Shop');
local main: Frame = shopFrame:WaitForChild('Main');
local everythingHolder: Frame = main:WaitForChild('Holder');
local holder: ScrollingFrame = everythingHolder:WaitForChild('ScrollingHolder');
local codesFrame: Frame = holder:WaitForChild('Codes');
local innerCodes: Frame = codesFrame:WaitForChild('Inner');
local redeemButton: ImageButton = innerCodes:WaitForChild('Redeem');
local inputFrame: Frame = innerCodes:WaitForChild('Input');
local textBox: TextBox = inputFrame:WaitForChild('TextBox');

-- Modules
local dataSync = require(script.Parent.DataSyncClient);
local network = require(framework.Network);

local function ConnectInput()
    textBox.Focused:Connect(function()
        textBox.Text = '';
        currentInput = textBox.Text;
    end)
    textBox:GetPropertyChangedSignal('Text'):Connect(function()
        currentInput = textBox.Text;
    end)
    redeemButton.MouseButton1Click:Connect(function()
        if not db then db = true task.delay(.15, function() db = false end)
            network:FireServer('RedeemCode', currentInput);
            currentInput = '';
        end
    end)
end

function CodesHandler.CodeInfo(text)
    textBox.Text = text;
    task.delay(3, function()
        textBox.Text = '';
    end)
end

function CodesHandler.Initialize()
    dataSync.OnReady(ConnectInput);
end
return CodesHandler