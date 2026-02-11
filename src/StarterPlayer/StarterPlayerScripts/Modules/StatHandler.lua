local ClickHandler = {};
local db: boolean = false;

-- Services
local players = game:GetService('Players');
local ts = game:GetService('TweenService');
local rs = game:GetService('ReplicatedStorage');
local http = game:GetService('HttpService');
local uis = game:GetService('UserInputService');
local guiService = game:GetService('GuiService');
local debris = game:GetService('Debris');

-- Variables
repeat task.wait() until players.LocalPlayer;
local plr: Player = players.LocalPlayer;

local framework: Folder = rs:WaitForChild('Framework');
local assets: Folder = rs:WaitForChild('Assets');
local clickModels: Folder = assets:WaitForChild('ClickModels');
local criticalModel: Model = clickModels:WaitForChild('CriticalClick');
local library: Folder = framework:WaitForChild('Library');
local cpsNumber: NumberValue = script:WaitForChild('CPSNumber');
local criticalEffects: Folder = script:WaitForChild('Critical');

local rng = Random.new();
local statsLoaded = false;

-- UI
local playerGui: PlayerGui = plr:WaitForChild('PlayerGui');
local hud: ScreenGui = playerGui:WaitForChild('HUD');
local clickButton: ImageButton = hud:WaitForChild('Click');

local autoClickerFrame: Frame = hud:WaitForChild('AutoClicker');
local toggleButton: ImageButton = autoClickerFrame:WaitForChild('Toggle');

local left: Frame = hud:WaitForChild('Left');
local statsFrame: Frame = left:WaitForChild('Stats');

local popUpArea: Frame = hud:WaitForChild('PopUpArea');
local popUps: Frame = hud:WaitForChild('PopUps');
local popUpTemplate: Frame = hud:WaitForChild('PopUpTemplate');

local shine: ImageLabel = clickButton:WaitForChild('Shine');
local template: Frame = clickButton:WaitForChild('Template');
local animationFrames: Folder = clickButton:WaitForChild('AnimationFrames');

-- Modules
local network = require(framework.Network);
local infMath = require(framework.InfiniteMath);
local util = require(framework.Utility);
local globals = require(framework.Globals);
local imageService = require(library.ImageService);

-- Constants
local rotationTime: number = 15;
local animationTime: number = 0.5;
local debounceTime: number = 0.15;
local textEndSize: UDim2 = UDim2.new(1,0,0.5,0);
local currencies = {'Clicks', 'Gems'};
local characterGroup = "CHAR";
local debrisGroup = 'DEBRIS';

-- Globals
local animationData = {};
local autoClickStatus = false;



local function SetupCharacter(character)
    for _, effect: ParticleEmitter in ipairs(criticalEffects:GetChildren()) do
        local clone: ParticleEmitter = effect:Clone();
        clone.Parent = character.HumanoidRootPart;
    end
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA('BasePart') then
            part.CollisionGroup = characterGroup;
        end
    end

    character.DescendantAdded:Connect(function(part)
        if part:IsA('BasePart') then
            part.CollisionGroup = characterGroup;
        end
    end)
end

local function AnimateShine()
    while true do
        local tween1: Tween = ts:Create(shine, TweenInfo.new(rotationTime/2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {Rotation = 360});
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

local function PopUp(increment, currencyStr: string, critical: boolean, position: UDim2)
    if not increment then
        return
    end

    if not position then
        local randomX = rng:NextNumber(popUpArea.Position.X.Scale, popUpArea.Position.X.Scale + popUpArea.Size.Width.Scale);
        local randomY = rng:NextNumber(popUpArea.Position.Y.Scale, popUpArea.Position.Y.Scale + popUpArea.Size.Width.Scale);

        position = UDim2.new(randomX, 0, randomY, 0);
    end

    local clone: Frame = popUpTemplate:Clone();
    local extraImgFrames: Folder = clone.ExtraImgFrames;
    clone.Parent = popUps;
    clone.Icon.Image = imageService[currencyStr];

    if critical then
        clone.Icon.ImageColor3 = Color3.fromRGB(237,98,255);
    end

    clone.Position = position;
    clone.Size = UDim2.new(0,0,0,0);
    clone.Visible = true;

    local animTime: number = 0.3;
    local style = Enum.EasingStyle.Back;
    local style2 = Enum.EasingStyle.Linear;
    local direction = Enum.EasingDirection.Out;
    local direction2 = Enum.EasingDirection.In;

    local popUpEndSize: UDim2 = critical and UDim2.new(2*0.042, 0, 2*0.065, 0) or UDim2.new(0.042, 0, 0.065, 0);

    clone:TweenSize(popUpEndSize, direction, style, animTime);
    local tween: Tween = ts:Create(clone, TweenInfo.new(animTime, style, direction), {Rotation = 0});
    tween:Play();
    tween.Completed:Wait();

    local incrementText: TextLabel = clone.Increment;
    incrementText.Text = '+'..infMath.new(increment):GetSuffix(true);
    local textTween: Tween = ts:Create(incrementText, TweenInfo.new(animTime/2, style2, direction), {TextTransparency = 0})
    textTween:Play();
    ts:Create(incrementText.UIStroke, TweenInfo.new(animTime/2, style2, direction), {Transparency = 0}):Play();
    incrementText:TweenSize(textEndSize, direction2, style, animTime);
    textTween.Completed:Wait();

    local amount: number = critical and 20 or 10;
    
    for i = 0, amount do
        task.spawn(function()
            local imgClone: ImageLabel = clone.Icon:Clone();
            imgClone.Parent = extraImgFrames;

            imgClone:TweenSize(UDim2.new(1.75,0,1.75,0), Enum.EasingDirection.Out, Enum.EasingStyle.Linear, animTime);
            local transparencyTween: Tween = ts:Create(imgClone, TweenInfo.new(animTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {ImageTransparency = 1})
            transparencyTween:Play();
            transparencyTween.Completed:Wait();

            imgClone:Destroy();
        end)
        task.wait(0.1);
    end

    repeat task.wait() until #extraImgFrames:GetChildren() == 0;
    
    clone:TweenSize(UDim2.new(0,0,0,0), direction2, style, animTime);
    local tween: Tween = ts:Create(clone, TweenInfo.new(animTime, style, direction2), {Rotation = 180});
    tween:Play();
    tween.Completed:Wait();

    clone:Destroy();
end

local function CriticalHitEffect()
    local character = plr.Character;
    local root = character.HumanoidRootPart;

    if not root then return end;
    for _, child: Instance in ipairs(root:GetChildren()) do
        if child:IsA('ParticleEmitter') then
            child:Emit(50);
        end
    end

    for i = 1, 10 do
        task.spawn(function()
            local clone: Model = criticalModel:Clone();

            if not clone.PrimaryPart then
                clone:Destroy();
            end

            for _, part in ipairs(clone:GetDescendants()) do
                if part:IsA('BasePart') then
                    part.CollisionGroup = debrisGroup;
                end
            end

            clone:PivotTo(root.CFrame * CFrame.new(0,2,0));
            clone.Parent = workspace;
            local force = 15
            local xForce = rng:NextNumber(-force, force);
            local zForce = rng:NextNumber(-force, force);
            local yForce = rng:NextNumber(30, 60);

            local jumpVector = Vector3.new(xForce,yForce,zForce);

            clone.PrimaryPart:ApplyImpulse(jumpVector * clone.PrimaryPart.AssemblyMass);
            
            local randomRot = Vector3.new(rng:NextNumber(-10, 10),rng:NextNumber(-10, 10),rng:NextNumber(-10, 10));
            
            clone.PrimaryPart:ApplyAngularImpulse(randomRot * clone.PrimaryPart.AssemblyMass);

            debris:AddItem(clone, 5);
        end)
    end
end

local function UpdateStatDisplay(currencyStr: string)
    if not statsLoaded then return end;
    local currencyFrame: Frame = statsFrame[currencyStr]
    local goalValue: number = 1;

    local targetValue = infMath.new(http:JSONDecode(plr:GetAttribute(currencyStr)));

    local data = animationData[currencyStr];

    if data.activeTween then
        data.activeTween:Cancel();
    end

    if data.activeConnection then
        data.activeConnection:Disconnect();
    end
    data.currentAnimValue = infMath.new(data.currentValue);

    local startValue = data.currentValue;
    local delta = infMath.new(targetValue - startValue);

    if currencyStr == 'Gems' then
        task.spawn(PopUp, delta, currencyStr)
    end

    data.tweenNumber.Value = 0;
    data.activeTween = ts:Create(data.tweenNumber, TweenInfo.new(0.3), {Value = goalValue});
    data.activeConnection = data.tweenNumber.Changed:Connect(function(value)
        data.currentAnimValue = infMath.new(startValue + (delta * value));
        currencyFrame.Background.Amount.Text = data.currentAnimValue:GetSuffix(true);
    end)
    data.activeTween:Play();
    data.currentValue = targetValue;
end

local function ClickByButton()
    local increment, critical = network:InvokeServer('Click');

    if critical then
        task.spawn(CriticalHitEffect);
    end
    
    task.spawn(ClickAnimation);
    task.spawn(PopUp, increment, 'Clicks', critical);
end

local function ClickByScreen(inputPosition)
    local increment, critical = network:InvokeServer('Click');
    local guiInset = guiService:GetGuiInset();

    if critical then
        task.spawn(CriticalHitEffect);
    end
    
    task.spawn(PopUp, increment, 'Clicks', critical, UDim2.fromOffset(
        inputPosition.X,
        inputPosition.Y + guiInset.Y
    ));
end

local function StartCPSTrack()
    local currencyFrame: Frame = statsFrame.Clicks;
    local cpsText: TextLabel = currencyFrame.Background.CPS;
    cpsText.Text = "0/s";

    local lastClickTable;
    local startJSON = util.WaitForAttribute(plr, 'Clicks');
    if startJSON then
        local tbl = http:JSONDecode(startJSON);
        lastClickTable = tbl;
    else
        lastClickTable = infMath.new(0);
    end
    local updateTime: number = 1;

    local currentTween: Tween = nil;
    local currentConnection: RBXScriptConnection = nil;
    local currentCPS = infMath.new(0);
    local goalValue: number = 1;

    while true do
        task.wait(updateTime);

        local jsonString = plr:GetAttribute('Clicks');
        if currentTween then
            currentTween:Cancel();
        end
        if currentConnection then
            currentConnection:Disconnect();
        end

        if jsonString then
            local currentRaw = http:JSONDecode(jsonString);
            local currentTbl = infMath.new(currentRaw);

            local cps = infMath.new(currentTbl - lastClickTable);

            local startValue = currentCPS;
            local delta = infMath.new(cps - startValue);

            cpsNumber.Value = 0
            currentTween = ts:Create(cpsNumber, TweenInfo.new(0.3), {Value = goalValue});

            currentConnection = cpsNumber.Changed:Connect(function(value)
                currentCPS = infMath.new(startValue + (delta * value));
                cpsText.Text = currentCPS:GetSuffix(true)..'/s';
            end)
            currentTween:Play();
            lastClickTable = currentTbl;
        end
    end
end

local function AutoClick()
    while task.wait(debounceTime) do
        if not autoClickStatus then continue end
        
        local increment, critical = network:InvokeServer('Click');
        if critical then
            task.spawn(CriticalHitEffect);
        end
        task.spawn(PopUp, increment, 'Clicks', critical);
    end
end

local function UpdateAutoClickButton(status: boolean)
    local color = '';
    local text = '';
    if status then
        color = 'Green';
        text = 'On';
    else
        color = 'Red';
        text = 'Off';
    end
    toggleButton.Frame.UIGradient.Color = globals.ButtonPresets[color].Gradient;
    toggleButton.Frame.UIStroke.Color = globals.ButtonPresets[color].StrokeColor;
    toggleButton.Title.UIStroke.Color = globals.ButtonPresets[color].StrokeColor;
    toggleButton.Title.Text = text;
end

function ClickHandler.LoadStatDisplay(profile)
    for _, currency: string in ipairs(currencies) do
        statsFrame[currency].Background.Amount.Text = infMath.new(profile[currency]):GetSuffix(true);

        local numValue = Instance.new('NumberValue', script);
        numValue.Name = currency;
        numValue.Value = 0;

        animationData[currency] = {
            currentValue = infMath.new(profile[currency]),
            currentAnimValue = infMath.new(0),
            activeTween = ts:Create(numValue, TweenInfo.new(0),{Value = 0}),
            activeConnection = nil,
            tweenNumber = numValue
        };
    end
    autoClickStatus = profile.AutoClickerStatus;
    UpdateAutoClickButton(autoClickStatus);
    statsLoaded = true;
end

function ClickHandler.Initialize()
    if not game.Loaded then game.Loaded:Wait() end;

    task.spawn(AnimateShine);
    task.spawn(StartCPSTrack);
    task.spawn(AutoClick);

    SetupCharacter(plr.Character);

    uis.InputBegan:Connect(function(input, gameProcessedEvent)
        if gameProcessedEvent then return end;
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            ClickByScreen(input.Position);
        end
    end)
    
    clickButton.MouseButton1Click:Connect(function()
        if not db then db = true task.delay(debounceTime, function() db = false end)
            ClickByButton();
        end
    end)

    toggleButton.MouseButton1Click:Connect(function()
        if not db then db = true task.delay(debounceTime, function() db = false end)
            autoClickStatus = network:InvokeServer('ToggleAutoClicker');
            UpdateAutoClickButton(autoClickStatus);
        end
    end)

    plr:GetAttributeChangedSignal('Clicks'):Connect(function()
        task.spawn(UpdateStatDisplay, 'Clicks');
    end)

    plr:GetAttributeChangedSignal('Gems'):Connect(function()
        task.spawn(UpdateStatDisplay, 'Gems');
    end)
end


return ClickHandler;