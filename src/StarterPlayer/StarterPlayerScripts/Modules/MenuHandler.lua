local ButtonHandler = {};
local db = false;

-- Services
local players = game:GetService("Players");
local ts = game:GetService('TweenService');
local rs = game:GetService('ReplicatedStorage');

-- Variables
repeat task.wait() until players.LocalPlayer;
local plr: Player = players.LocalPlayer;

ButtonHandler.activeFrame = nil;

local camera = workspace.CurrentCamera;

local playerScripts = plr:WaitForChild('PlayerScripts');
local modules = playerScripts:WaitForChild('Modules');

local framework = rs:WaitForChild('Framework');

-- UI
local playerGui = plr:WaitForChild('PlayerGui');

local frames: ScreenGui = playerGui:WaitForChild('Frames');
local inventoryFrame: Frame = frames:WaitForChild('Inventory');

local hud: ScreenGui = playerGui:WaitForChild('HUD');
local left: Frame = hud:WaitForChild('Left');
local buttons: Frame = left:WaitForChild('Buttons');
local inventoryButton: ImageButton = buttons:WaitForChild('Pets');

-- Modules
local inventoryHandler = require(script.Parent.InventoryHandler);

-- Constants
local sizePos = {
    ["Inventory"] = {UDim2.new(0.588,0,0.658,0), UDim2.new(0.5,0,0.5,0)}
};
local animationTime = .15;
local fov = camera.FieldOfView;

function ButtonHandler.openFrame(frame: Frame)
	ButtonHandler.activeFrame = frame
	frame.Size = UDim2.new(0,0,0,0)
	frame.Position = UDim2.new(0.5,0,0.85,0)
	frame.Visible = true
	
	frame:TweenSizeAndPosition(sizePos[frame.Name][1], sizePos[frame.Name][2], Enum.EasingDirection.Out, Enum.EasingStyle.Sine, animationTime)
	ts:Create(camera, TweenInfo.new(animationTime, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {FieldOfView = 90}):Play()
end

function ButtonHandler.closeFrame(frame: Frame)
	frame:TweenSizeAndPosition(UDim2.new(0,0,0,0), UDim2.new(0.5,0,0.85,0), Enum.EasingDirection.Out, Enum.EasingStyle.Sine, animationTime)
	ts:Create(camera, TweenInfo.new(animationTime, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {FieldOfView = fov}):Play()
	ButtonHandler.activeFrame = nil
	task.wait(animationTime)
	frame.Visible = false
end

function ButtonHandler.handleOpenClose(frame, func)
	if not db then db = true task.delay(.15, function() db = false end)
		if func then func() end
		if frame == ButtonHandler.activeFrame then 
			ButtonHandler.closeFrame(frame) 
			return 
		end
		if ButtonHandler.activeFrame then 
			ButtonHandler.closeFrame(ButtonHandler.activeFrame) 
		end
		ButtonHandler.openFrame(frame)
	end
end

function ButtonHandler.Initialize()
    if not game.Loaded then game.Loaded:Wait() end;
    
    inventoryButton.MouseButton1Click:Connect(function()
        ButtonHandler.handleOpenClose(inventoryFrame, inventoryHandler.LoadInventory);
    end)
end

return ButtonHandler;