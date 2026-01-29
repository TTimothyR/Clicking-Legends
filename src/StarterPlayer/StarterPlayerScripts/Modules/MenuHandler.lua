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
local indexFrame: Frame = frames:WaitForChild('Index');
local inventoryFrame: Frame = frames:WaitForChild('Inventory');
local prizesFrame: Frame = frames:WaitForChild('Prizes');
local rebirthsFrame: Frame = frames:WaitForChild('Rebirths');
local shopFrame: Frame = frames:WaitForChild('Shop');
local playerListFrame: Frame = frames:WaitForChild('PlayerList');

local hud: ScreenGui = playerGui:WaitForChild('HUD');
local left: Frame = hud:WaitForChild('Left');
local buttons: Frame = left:WaitForChild('Buttons');
local indexButton: ImageButton = buttons:WaitForChild('Index');
local inventoryButton: ImageButton = buttons:WaitForChild('Pets');
local prizesButton: ImageButton = buttons:WaitForChild('Prizes');
local rebirthButton: ImageButton = buttons:WaitForChild('Rebirth');
local shopButton: ImageButton = buttons:WaitForChild('Shop');
local tradeButton: ImageButton = buttons:WaitForChild('Trading');

-- Modules
local inventoryHandler = require(script.Parent.InventoryHandler);
local rebirthHandler = require(script.Parent.RebirthHandler);
local indexHandler = require(script.Parent.IndexHandler);

-- Constants
local sizePos = {
    ["Index"] = {UDim2.new(0.497,0,0.6,0), UDim2.new(0.5,0,0.5,0)},
    ["Inventory"] = {UDim2.new(0.588,0,0.658,0), UDim2.new(0.5,0,0.5,0)},
    ["Prizes"] = {UDim2.new(0.5,0,0.5,0), UDim2.new(0.5,0,0.5,0)},
    ["Rebirths"] = {UDim2.new(0.6,0,0.6,0), UDim2.new(0.5,0,0.5,0)},
    ["Shop"] = {UDim2.new(0.588,0,0.658,0), UDim2.new(0.5,0,0.5,0)},
    ["PlayerList"] = {UDim2.new(0.6,0,0.6,0), UDim2.new(0.5,0,0.5,0)},
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
    
    indexButton.MouseButton1Click:Connect(function()
        ButtonHandler.handleOpenClose(indexFrame, indexHandler.LoadIndex);
    end)
	inventoryButton.MouseButton1Click:Connect(function()
        ButtonHandler.handleOpenClose(inventoryFrame, inventoryHandler.LoadInventory);
    end)
	prizesButton.MouseButton1Click:Connect(function()
        ButtonHandler.handleOpenClose(prizesFrame);
    end)
	rebirthButton.MouseButton1Click:Connect(function()
        ButtonHandler.handleOpenClose(rebirthsFrame, rebirthHandler.LoadRebirthButtons);
    end)
	shopButton.MouseButton1Click:Connect(function()
        ButtonHandler.handleOpenClose(shopFrame);
    end)
	tradeButton.MouseButton1Click:Connect(function()
        ButtonHandler.handleOpenClose(playerListFrame);
    end)

	for _, frame: Frame in ipairs(frames:GetChildren()) do
		if frame:FindFirstChild('Close') then
			frame:FindFirstChild('Close').MouseButton1Click:Connect(function()
				if not db then db = true task.delay(.15, function() db = false end)
					ButtonHandler.closeFrame(frame);
				end
			end)
		end
	end
end

return ButtonHandler;