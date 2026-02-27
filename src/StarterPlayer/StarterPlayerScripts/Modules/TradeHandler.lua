local TradeHandler = {};
local db = false;

-- Services
local players = game:GetService('Players');
local rs = game:GetService('ReplicatedStorage');
local runService = game:GetService('RunService');

-- Variables
repeat task.wait() until players.LocalPlayer;
local player: Player = players.LocalPlayer;

local framework: Folder = rs:WaitForChild('Framework');
local library: Folder = framework:WaitForChild('Library');
local classes: Folder = rs:WaitForChild('Classes');

local playerConnections = {};
local tradeConnections = {};
local timerConnection: RBXScriptConnection = nil;
local tradeRequestEndPos = UDim2.new(0.5,0,0.1,0);
local tradeRequestStartPos = UDim2.new(0.5,0,-0.1,0);
local requestWaitTime = 6;

-- UI
local playerGui: PlayerGui = player:WaitForChild('PlayerGui');
local frames: ScreenGui = playerGui:WaitForChild('Frames');
local infoFrame: Frame = frames:WaitForChild('Info');
local playerListFrame: Frame = frames:WaitForChild('PlayerList');
local templates: Folder = playerListFrame:WaitForChild('Templates');
local playerTemplate: Frame = templates:WaitForChild('PlayerTemplate');
local main: Frame = playerListFrame:WaitForChild('Main');
local toggleTrading: ImageButton = main:WaitForChild('Toggle');
local listFrame: Frame = main:WaitForChild('List');
local playerHolder: ScrollingFrame = listFrame:WaitForChild('ScrollingFrame');

local tradeRequestFrame: Frame = frames:WaitForChild('TradeRequest');
local requestMain: Frame = tradeRequestFrame:WaitForChild('Main');
local tradeFrame: Frame = frames:WaitForChild('Trade');
local tradeTemplates: Folder = tradeFrame:WaitForChild('Templates');
local petTemplate: ImageButton = tradeTemplates:WaitForChild('PetTemplate');
local offerTemplate: ImageButton = tradeTemplates:WaitForChild('OfferTemplate');
local tradeMain: Frame = tradeFrame:WaitForChild('Main');
local timerLabel: TextLabel = tradeMain:WaitForChild('Timer');
local tradeButtons: Frame = tradeMain:WaitForChild('Buttons');
local youOffer: Frame = tradeMain:WaitForChild('YouOffer');
local youPets: Frame = tradeMain:WaitForChild('YouPets');
local meOffer: Frame = tradeMain:WaitForChild('MeOffer');
local mePets: Frame = tradeMain:WaitForChild('MePets');

-- Modules
local network = require(framework.Network);
local globals = require(framework.Globals);
local petStats = require(library.PetStats);
local menuHandler = require(script.Parent.MenuHandler);
local infoPopup = require(classes.InfoPopup);
local dataSync = require(script.Parent.DataSyncClient);

local function UpdateTradeButton(color: string, text: string, button: ImageButton)
    button.Frame.UIGradient.Color = globals.ButtonPresets[color].Gradient;
    button.Frame.UIStroke.Color = globals.ButtonPresets[color].StrokeColor;
    button.Title.UIStroke.Color = globals.ButtonPresets[color].StrokeColor;
    button.Title.Text = text;
end

local function CreatePlayerFrame(plr: Player)
    local clone: Frame = playerTemplate:Clone();
    clone.Parent = playerHolder;
    clone.Name = plr.Name;

    local inner: Frame = clone.Inner;
    inner.PlayerName.Text = plr.Name;
    clone.Visible = true;

    local clickCon: RBXScriptConnection
    clickCon = inner.Trade.MouseButton1Click:Connect(function()
        if not db then db = true task.delay(.15, function() db = false end)
            network:FireServer('SendTradeRequest', plr);
        end
    end)
    playerConnections[plr.Name] = clickCon;
end

local function CreatePetButton(clone: ImageButton, holder, petData)
    clone.Parent = holder;
    clone.Name = petData.id;

    local rarity = petStats[petData.petName].Rarity;
    clone.Frame.BackgroundColor3 = globals.RarityColors[rarity];
    if rarity == 'Legendary' then
        clone.Glow.Visible = true;
        clone.Frame.Legendary.Enabled = true;
    end

    clone.Visible = true;
    return clone;
end

local function CleanUp()
    for _, child: Instance in ipairs(mePets.ScrollingFrame:GetChildren()) do
        if child:IsA('ImageButton') then
            child:Destroy();
        end
    end    
    for _, child: Instance in ipairs(youPets.ScrollingFrame:GetChildren()) do
        if child:IsA('ImageButton') then
            child:Destroy();
        end
    end
    for _, child: Instance in ipairs(meOffer.Pets:GetChildren()) do
        if child:IsA('ImageButton') then
            child:Destroy();
        end
    end    
    for _, child: Instance in ipairs(youOffer.Pets:GetChildren()) do
        if child:IsA('ImageButton') then
            child:Destroy();
        end
    end

    for _, con: RBXScriptConnection in ipairs(tradeConnections) do
        if con.Connected then
            con:Disconnect();
        end
    end
    tradeConnections = {};
end

function TradeHandler.DeclineTrade(me: Player)
    if player == me then
        local popup = infoPopup.new(
            nil,
            'You have declined the trade. Trade them again if this was a mistake!',
            function()
                menuHandler.handleOpenClose(infoFrame)
            end,
            infoFrame
        )
    else
        local popup = infoPopup.new(
            nil,
            'The other player has declined the trade. Trade them again if this was a mistake!',
            function()
                menuHandler.handleOpenClose(infoFrame)
            end,
            infoFrame
        )
    end

    menuHandler.handleOpenClose(infoFrame);
    CleanUp();
end

function TradeHandler.Ready(me: Player)
    if player == me then
        meOffer.Ready.Visible = true;
        tradeButtons.Ready.Visible = false;
        tradeButtons.Unready.Visible = true;
    else
        youOffer.Ready.Visible = true;
    end
end

function TradeHandler.Unready(me: Player)
    if player == me then
        meOffer.Ready.Visible = false;
        tradeButtons.Ready.Visible = true;
        tradeButtons.Unready.Visible = false;
    else
        youOffer.Ready.Visible = false;
    end
end

function TradeHandler.LockTrade()
    tradeButtons.Ready.Visible = false;
    tradeButtons.Unready.Visible = false;
    tradeButtons.Decline.Visible = false;
end

function TradeHandler.TradeFinished()
    local popup = infoPopup.new(
        nil,
        'The trade has been completed.',
        function()
            menuHandler.handleOpenClose(infoFrame)
        end,
        infoFrame
    )

    menuHandler.handleOpenClose(infoFrame);
    CleanUp();
end

function TradeHandler.StartTimer(totalTime: number)
    timerLabel.Visible = true;

    timerConnection = runService.RenderStepped:Connect(function(deltaTime)
        totalTime -= deltaTime;

        if totalTime <= 0 then
            TradeHandler.StopTimer()
        end

        timerLabel.Text = totalTime..'s';
    end)
end

function TradeHandler.StopTimer()
    timerLabel.Visible = false;

    if timerConnection.Connected then
        timerConnection:Disconnect();
    end
end

function TradeHandler.TogglePet(me: Player, data, state)
    if state == 'Removed' then
        if player == me then
            meOffer.Pets:FindFirstChild(data.id):Destroy();
        else
            youOffer.Pets:FindFirstChild(data.id):Destroy();
        end
    elseif state == 'Added' then
        local clone: ImageButton = offerTemplate:Clone();
        
        if player == me then
            clone = CreatePetButton(clone, meOffer.Pets, data);
            local clickCon: RBXScriptConnection
            clickCon = clone.MouseButton1Click:Connect(function()
                if not db then db = true task.delay(.15, function() db = false end)
                    network:FireServer('TogglePet', data.id);
                    -- network:FireServer('Unready');
                end
            end)
            clone:GetPropertyChangedSignal('Parent'):Once(function()
                clickCon:Disconnect();
            end)
        else
            clone = CreatePetButton(clone, youOffer.Pets, data);
        end
    end
end

function TradeHandler.EnterTrade(me: Player, you: Player)
    -- local myProfile = network:InvokeServer('GetData');
    local yourProfile = dataSync.GetOtherData(you.UserId);
    local myPets = dataSync.Get('Pets');
    local yourPets = yourProfile.Pets;

    meOffer.Ready.Visible = false;
    youOffer.Ready.Visible = false;
    tradeButtons.Ready.Visible = true;
    tradeButtons.Decline.Visible = true;
    tradeButtons.Unready.Visible = false;

    CleanUp();

    youPets.PlayerName.Text = you.Name..'\'s Inventory';
    youOffer.PlayerName.Text = you.Name..'\'s Offer';

    local function CreatePetButtons(inventory, holder)
        for _, petData in ipairs(inventory) do
            local clone: ImageButton = petTemplate:Clone();
            clone = CreatePetButton(clone, holder, petData);

            local clickCon: RBXScriptConnection;
            clickCon = clone.MouseButton1Click:Connect(function()
                if not db then db = true task.delay(.15, function() db = false end)
                    if clone.Parent == mePets.ScrollingFrame then
                        network:FireServer('TogglePet', petData.id)
                        -- network:FireServer('Unready');
                    end
                end
            end)
            table.insert(tradeConnections, clickCon);
        end
    end

    local readyCon: RBXScriptConnection;
    local unreadyCon: RBXScriptConnection
    local declineCon: RBXScriptConnection;

    readyCon = tradeButtons.Ready.MouseButton1Click:Connect(function()
        if not db then db = true task.delay(.15, function() db = false end)
            network:FireServer('Ready');
        end
    end)
    unreadyCon = tradeButtons.Unready.MouseButton1Click:Connect(function()
        if not db then db = true task.delay(.15, function() db = false end)
            network:FireServer('Unready')
        end
    end)
    declineCon = tradeButtons.Decline.MouseButton1Click:Connect(function()
        if not db then db = true task.delay(.15, function() db = false end)
            network:FireServer('DeclineTrade');
        end
    end)
    table.insert(tradeConnections, readyCon);
    table.insert(tradeConnections, unreadyCon);
    table.insert(tradeConnections, declineCon);

    CreatePetButtons(myPets, mePets.ScrollingFrame);
    CreatePetButtons(yourPets, youPets.ScrollingFrame);

    menuHandler.handleOpenClose(tradeFrame);
end

function TradeHandler.UpdateTradeButtons()
    for _, child in ipairs(playerHolder:GetChildren()) do
        if child:IsA('Frame') then
            local playerName: string = child.Name
            -- local profile = network:InvokeServer('GetOtherData', playerName);
            local profile = dataSync.GetOtherData(players:FindFirstChild(playerName).UserId);
            if profile.IsInTrade then
                UpdateTradeButton('Red', 'Busy', child.Inner.Trade);
            elseif profile.HasTradingDisabled then
                UpdateTradeButton('Purple', 'Disabled', child.Inner.Trade);
            elseif profile.TradeRequestFrom == player.Name then
                UpdateTradeButton('Orange', 'Pending', child.Inner.Trade);
            else
                UpdateTradeButton('Green', 'Send', child.Inner.Trade);
            end
        end
    end
end

function TradeHandler.HideTradeRequest()
    local frameTime = 0.2;
    local function HideUI()
        tradeRequestFrame:TweenPosition(tradeRequestStartPos, Enum.EasingDirection.In, Enum.EasingStyle.Back, frameTime);
    end

    if tradeRequestFrame.Position == tradeRequestEndPos then
        HideUI();
    end
end

function TradeHandler.TradeRequest(me: Player)
    local frameTime = 0.2;
    local function ShowUI()
        tradeRequestFrame:TweenPosition(tradeRequestEndPos, Enum.EasingDirection.Out, Enum.EasingStyle.Back, frameTime);
    end
    local function HideUI()
        tradeRequestFrame:TweenPosition(tradeRequestStartPos, Enum.EasingDirection.In, Enum.EasingStyle.Back, frameTime);
    end
    local image, ready = players:GetUserThumbnailAsync(me.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420);

    requestMain.Title.Text = me.Name..' sent you a trade request!';
    requestMain.PlayerImg.Image = ready and image or '';
    ShowUI();

    local buttons = requestMain.Buttons;

    local acceptCon: RBXScriptConnection;
    local declineCon: RBXScriptConnection;

    local choice = nil;
    local elapsed = 0;

    acceptCon = buttons.Accept.MouseButton1Click:Connect(function()
        if not db then db = true task.delay(.15, function() db = false end)
            if choice == nil then
                choice = true;
            end
        end
    end)
    declineCon = buttons.Decline.MouseButton1Click:Connect(function()
        if not db then db = true task.delay(.15, function() db = false end)
            if choice == nil then
                choice = false;
            end
        end
    end)

    while choice == nil and elapsed < requestWaitTime do
        elapsed += 0.1;
        task.wait(0.1);
    end

    HideUI();

    if acceptCon.Connected then acceptCon:Disconnect() end;
    if declineCon.Connected then declineCon:Disconnect() end;

    network:FireServer('RequestAnswer', me, (choice or false));
end

function TradeHandler.LoadPlayerList()
    for _, plr: Player in ipairs(players:GetPlayers()) do
        if playerHolder:FindFirstChild(plr.Name) then continue end
        if plr ~= player then
            CreatePlayerFrame(plr)
        end
    end
    for _, child: Instance in ipairs(playerHolder:GetChildren()) do
        if child:IsA('Frame') then
            if not players:FindFirstChild(child.Name) then
                child:Destroy();
                
                playerConnections[child.Name]:Disconnect();
                playerConnections[child.Name] = nil;
            end
        end
    end
end

function TradeHandler.Initialize()
    if not game.Loaded then game.Loaded:Wait() end;

    task.spawn(TradeHandler.LoadPlayerList)

    players.PlayerAdded:Connect(function(player)
        task.spawn(TradeHandler.LoadPlayerList)
    end)
    players.PlayerRemoving:Connect(function(player, reason)
        task.spawn(TradeHandler.LoadPlayerList)
    end)
end

return TradeHandler;