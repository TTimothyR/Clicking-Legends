local EggHandler = {};
local db = false

-- Services
local players = game:GetService('Players');
local workspace = game:GetService('Workspace');
local rs = game:GetService('ReplicatedStorage');
local runService = game:GetService('RunService');
local ts = game:GetService('TweenService');

-- Variables
repeat task.wait() until players.LocalPlayer;
local player: Player = players.LocalPlayer;

local eggOpens: Folder = workspace:WaitForChild('EggOpens');
local camera: Camera = workspace.CurrentCamera;
local cameraOffset = CFrame.new(0, 0, -4.5) * CFrame.Angles(0, math.rad(180), 0);

local assets: Folder = rs:WaitForChild('Assets');
local petModels: Folder = assets:WaitForChild('PetModels');
local eggModels: Folder = assets:WaitForChild('EggModels');
local sounds: Folder = assets:WaitForChild('Sounds');

local framework: Folder = rs:WaitForChild('Framework');

-- UI
local playerGui: PlayerGui = player:WaitForChild('PlayerGui');
local hud: ScreenGui = playerGui:WaitForChild('HUD');
local hatchOverlay: ScreenGui = playerGui:WaitForChild('HatchOverlay');
local left: Frame = hud:WaitForChild('Left');
local boost: Frame = hud:WaitForChild('Boost');
local autoClicker: Frame = hud:WaitForChild('AutoClicker');
local clickButton: ImageButton = hud:WaitForChild('Click');
local popUps: Frame = hud:WaitForChild('PopUps');

-- Modules
local modelUtil = require(framework.ModelUtility);
local menuHandler = require(script.Parent.MenuHandler);
local soundHandler = require(script.Parent.SoundHandler);

-- Constants
local dir, style, animTime = Enum.EasingDirection.Out, Enum.EasingStyle.Sine, 0.3;
local closedFrame = nil;

local function CalculatePositions(amount: number)
	local eggDataList = {}
	local eggSpacing = 3.5

	local maxCols
	if amount == 1 then
		maxCols = 1
	elseif amount == 2 then
		maxCols = 2
	elseif amount == 3 then
		maxCols = 3
	elseif amount == 4 then
		maxCols = 2 
	elseif amount == 5 or amount == 6 then
		maxCols = 3 
	elseif amount == 7 or amount == 8 then
		maxCols = 4 
	elseif amount == 9 or amount == 10 then
		maxCols = 5
	elseif amount == 100 then
		maxCols = 10
	end

	local numRows = math.ceil(amount / maxCols)

	local zBase = 0
	local zDepthPerDimensionUnit = 0.7 
	local maxVisibleDimension = math.max(maxCols, numRows)
	local dynamicFinalZ = zBase + (maxVisibleDimension - 1) * zDepthPerDimensionUnit

	for i = 1, amount do
		local idx = i - 1
		local col = idx % maxCols
		local row = math.floor(idx / maxCols)

		local currentEggsInThisRow = maxCols
		if row == numRows - 1 then
			local remainingEggs = amount % maxCols
			if remainingEggs ~= 0 then
				currentEggsInThisRow = remainingEggs
			end
		end

		local xOffset = (col - (currentEggsInThisRow - 1) / 2) * eggSpacing
		local yOffset = (row - (numRows - 1) / 2) * eggSpacing

		local initialPosValue = CFrame.new(xOffset, yOffset - 7, dynamicFinalZ)
		local finalPosValue = CFrame.new(xOffset, yOffset, dynamicFinalZ)

		table.insert(eggDataList, {
			pos0 = initialPosValue,
			pos1 = finalPosValue
		})
	end

	return eggDataList
end

local function HideUI()
    left:TweenPosition(UDim2.new(-0.25,0,0.162,0), dir, style, animTime);
    autoClicker:TweenPosition(UDim2.new(0.218,0,1,0), dir, style, animTime);
    clickButton:TweenPosition(UDim2.new(0.517,0,1.2,0), dir, style, animTime);
    boost:TweenPosition(UDim2.new(0.292,0,-0.3,0), dir, style, animTime);
    popUps.Visible = false;

    if closedFrame then
        menuHandler.openFrame(closedFrame);
        closedFrame = nil;
    end
end

local function UnHideUI()
    left:TweenPosition(UDim2.new(0.006,0,0.162,0), dir, style, animTime);
    autoClicker:TweenPosition(UDim2.new(0.218,0,0.891,0), dir, style, animTime);
    clickButton:TweenPosition(UDim2.new(0.517,0,0.91,0), dir, style, animTime);
    boost:TweenPosition(UDim2.new(0.292,0,0.013,0), dir, style, animTime);
    popUps.Visible = true;

    if menuHandler.activeFrame then
        closedFrame = menuHandler.activeFrame;
        menuHandler.closeFrame(closedFrame);
    end
end

function EggHandler.EggAnimation(eggName: string, amount: number, petsData)
    local speed = 1

    local eggData = {};
    local eggAnimationConnections = {};
    local eggDestroyConnections = {};

    HideUI();

    for i = 1, amount do
        local egg: Model = eggModels:FindFirstChild(eggName):Clone();
        local attach = Instance.new('Attachment', egg.PrimaryPart);
        attach.Name = 'Particle';

        local smoke: ParticleEmitter = script.Smoke:Clone();
        smoke.Parent = attach;
        smoke.Name = 'Smoke';

        smoke.Lifetime = NumberRange.new(smoke.Lifetime.Min/speed, smoke.Lifetime.Max/speed);
        
        local originalScale = egg:GetScale();
        egg.Parent = eggOpens;
        egg:ScaleTo(0.00001);


        local pos = Instance.new('CFrameValue');
        local rot = Instance.new('CFrameValue');
        rot.Value = CFrame.Angles(0,0,0);

        local positions = CalculatePositions(amount);
        pos.Value = positions[i].pos1;

        table.insert(eggData, {
            egg = egg,
            pos = pos,
            rot = rot,
            endScale = originalScale,
            endPos = positions[i].pos1
        })

        local eggConnection: RBXScriptConnection = runService.RenderStepped:Connect(function(deltaTime)
            egg:PivotTo(camera.CFrame * cameraOffset * pos.Value * rot.Value);
        end)
        table.insert(eggAnimationConnections, eggConnection);

        local destroyConnection: RBXScriptConnection = egg:GetPropertyChangedSignal('Parent'):Once(function()
            eggConnection:Disconnect();
        end)
        table.insert(eggDestroyConnections, destroyConnection);
    end

    for _, data in ipairs(eggData) do
        task.spawn(function()
            modelUtil.AnimateScale(data.egg:GetScale(), data.endScale, TweenInfo.new(0.35/speed, Enum.EasingStyle.Back, Enum.EasingDirection.Out), data.egg);
        end)
    end
    task.wait(0.65/speed);

    local startWait, endWait, direction, alpha = 0.5/speed, 0.01/speed, 1, 30;
    local rotationCount, trigger = 0, 2
    local currentWait = startWait
    local originalFOV = camera.FieldOfView;

    local zoomIn = function()
        ts:Create(camera, TweenInfo.new((currentWait/2), Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {FieldOfView = camera.FieldOfView-3}):Play();
    end
    local zoomOut = function(waitTime)
        ts:Create(camera, TweenInfo.new(waitTime, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {FieldOfView = camera.FieldOfView+1}):Play();
    end
    local zoomPop = function()
        local popFactor = 1.3;
        local speed = startWait/2;
        
        local tween1: Tween = ts:Create(camera, TweenInfo.new(speed*0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = originalFOV / popFactor});
        tween1:Play();
        tween1.Completed:Wait();
        
        local tween2: Tween = ts:Create(camera, TweenInfo.new(speed*0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = originalFOV});
        tween2:Play();
    end
    repeat
        local hatchTweens = {};
        for _, data in ipairs(eggData) do
            table.insert(hatchTweens, function()
                ts:Create(data.rot, TweenInfo.new(currentWait, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {Value = CFrame.Angles(0,0,direction*math.rad(alpha))}):Play();
            end)
        end
        
        -- if rotationCount <= 1 then
        --     zoomIn();
        -- else
        --     zoomOut(currentWait);
        -- end
        
        for _, func in ipairs(hatchTweens) do
            func();
            soundHandler.PlaySound(sounds.Turn);
        end
        task.wait(currentWait)
        currentWait /= 1.25;
        direction *= -1;
        rotationCount += 1;
    until currentWait <= endWait
    
    -- task.spawn(zoomPop);
    
    for _, data in ipairs(eggData) do
        for _, descendant in ipairs(data.egg:GetDescendants()) do
            if descendant:IsA('BasePart') then
                descendant.Transparency = 1;
            end
        end
    end
    
    for _, data in ipairs(eggData) do
        runService.Heartbeat:Wait();
        data.egg.PrimaryPart.Particle.Smoke:Emit(17);
    end

    local petData = {};
    local petAnimationConnections = {};
    local petUIConnections = {};
    local petDestroyConnections = {};

    for i, data in ipairs(eggData) do
        local petName: string = petsData[i].fullName;

        if petsData[i].shiny and not petModels:FindFirstChild(petName) then
            warn('Shiny model for pet', petName,'not found, falling back to regular model.');
            petName = petsData[i].petName;
        end
        if not petModels:FindFirstChild(petName) then
            warn('Model for pet', petName, 'not found, falling back to Doggy.');
            petName = 'Doggy';
        end
        
        local pet: Model = petModels:FindFirstChild(petName):Clone();
        pet.Parent = eggOpens

        local petPos = Instance.new('CFrameValue');
        local petRot = Instance.new('CFrameValue');

        petPos.Value = data.endPos * CFrame.new(0,0,2);
        petRot.Value = CFrame.Angles(0,0,0);

        local nameLabel: TextLabel = script.PetName:Clone();
        nameLabel.Name = petName;
        nameLabel.Text = petName;
        nameLabel.Parent = hatchOverlay;
        nameLabel.Visible = true        
        
        local rarityLabel: TextLabel = script.Rarity:Clone();
        rarityLabel.Name = petsData[i].rarity;
        rarityLabel.Text = petsData[i].rarity;
        rarityLabel.Parent = hatchOverlay;
        rarityLabel.Visible = true

        local miscLabel: TextLabel = script.Misc:Clone();
        miscLabel.Text = "";
        miscLabel.Parent = hatchOverlay;
        miscLabel.Visible = true

        if petsData[i].autoDeleted then
            miscLabel.Text = 'Auto Deleted';
        elseif petsData[i].new then
            miscLabel.Text = 'New Pet Discovered!'
        end

        table.insert(petData, {
            pet = pet,
            pos = petPos,
            rot = petRot,
            endPos = data.endPos,
            nameLabel = nameLabel,
            rarityLabel = rarityLabel,
            miscLabel = miscLabel
        })

        local petConnection: RBXScriptConnection = runService.RenderStepped:Connect(function(deltaTime)
            pet:PivotTo(CFrame.new((camera.CFrame * cameraOffset * petPos.Value).Position, camera.CFrame.Position) * petRot.Value);
        end)
        table.insert(petAnimationConnections, petConnection);

        local uiConnection: RBXScriptConnection = runService.Heartbeat:Connect(function(deltaTime)
			local screenPoint, onScreen = camera:WorldToScreenPoint(pet.PrimaryPart.Position - pet.PrimaryPart.CFrame.UpVector * pet.PrimaryPart.Size.Y/2)
            nameLabel.Visible = onScreen;
            rarityLabel.Visible = onScreen;
            miscLabel.Visible = onScreen;
            
            if onScreen then
                nameLabel.Position = UDim2.new(screenPoint.X/camera.ViewportSize.X, 0, (screenPoint.Y+100)/camera.ViewportSize.Y, 0)
				rarityLabel.Position = UDim2.new(screenPoint.X/camera.ViewportSize.X, 0, (screenPoint.Y + 150)/camera.ViewportSize.Y, 0)
				miscLabel.Position = UDim2.new(screenPoint.X/camera.ViewportSize.X, 0, (screenPoint.Y - 100)/camera.ViewportSize.Y, 0)
            end
        end)
        table.insert(petUIConnections, uiConnection);

        local petDestroyConnection: RBXScriptConnection = pet:GetPropertyChangedSignal('Parent'):Once(function()
            petConnection:Disconnect();
        end)
        table.insert(petDestroyConnections, petDestroyConnection);

        soundHandler.PlaySound(sounds.Normal);
    end
    for _, data in ipairs(eggData) do
        task.delay(data.egg.PrimaryPart.Particle.Smoke.Lifetime.Max, function()
            data.egg:Destroy();
        end);
    end

    task.wait(1.85/speed);
    for _, data in ipairs(petData) do
        data.nameLabel:Destroy();
        data.rarityLabel:Destroy();
        data.miscLabel:Destroy();
    end

    local removeTweens = {};
    local removeTime = 0.75/speed;

    for _, data in ipairs(petData) do
        table.insert(removeTweens, function()
            modelUtil.AnimateScale(data.pet:GetScale(), 0.00001, TweenInfo.new(removeTime, Enum.EasingStyle.Back, Enum.EasingDirection.In), data.pet);
            for _, descendant in ipairs(data.pet:GetDescendants()) do
                if descendant.Transparency then
                    ts:Create(descendant, TweenInfo.new(removeTime*1.15, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {Transparency = 1}):Play();
                end
            end
        end)
    end
    for _, func in ipairs(removeTweens) do
        task.spawn(func);
    end
    task.wait(removeTime);
    UnHideUI();

    for _, data in ipairs(petData) do
        data.pet:Destroy();
    end

    for _, con: RBXScriptConnection in ipairs(eggAnimationConnections) do
        if con.Connected then
            con:Disconnect();
        end
    end
    for _, con: RBXScriptConnection in ipairs(eggDestroyConnections) do
        if con.Connected then
            con:Disconnect();
        end
    end
    for _, con: RBXScriptConnection in ipairs(petAnimationConnections) do
        if con.Connected then
            con:Disconnect();
        end
    end
    for _, con: RBXScriptConnection in ipairs(petUIConnections) do
        if con.Connected then
            con:Disconnect();
        end
    end
    for _, con: RBXScriptConnection in ipairs(petDestroyConnections) do
        if con.Connected then
            con:Disconnect();
        end
    end

    return true;
end

return EggHandler;