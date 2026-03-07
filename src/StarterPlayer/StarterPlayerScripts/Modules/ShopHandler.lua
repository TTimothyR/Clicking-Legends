local ShopHandler = {};
local db = false;

-- Services
local players = game:GetService('Players');
local rs = game:GetService('ReplicatedStorage');
local mps = game:GetService('MarketplaceService');
local ts = game:GetService('TweenService');

-- Variables
repeat task.wait() until players.LocalPlayer;
local player: Player = players.LocalPlayer;

local framework: Folder = rs:WaitForChild('Framework');
local library: Folder = framework:WaitForChild('Library');
local classes: Folder = rs:WaitForChild('Classes');

local gpConnections = {};

-- UI
local playerGui: PlayerGui = player:WaitForChild('PlayerGui');
local frames: ScreenGui = playerGui:WaitForChild('Frames');
local shopFrame: Frame = frames:WaitForChild('Shop');
local greyFrame: Frame = frames:WaitForChild('GreyFrame');
local infoFrame: Frame = frames:WaitForChild('Info');
local templates: Folder = shopFrame:WaitForChild('Templates');
local passTemplate: Frame = templates:WaitForChild('PassTemplate');
local gemsTemplate: Frame = templates:WaitForChild('GemsTemplate');
local main: Frame = shopFrame:WaitForChild('Main');
local holder: Frame = main:WaitForChild('Holder');
local scrollingHolder: ScrollingFrame = holder:WaitForChild('ScrollingHolder');

local exclusivePetFrame: Frame = scrollingHolder:WaitForChild('ExclusivePets');

-- Modules
local dataSync = require(script.Parent.DataSyncClient);
local menuHandler = require(script.Parent.MenuHandler);
local shopStats = require(library.ShopStats);
local infoPopup = require(classes.InfoPopup);

local function ShowGreyFrame()
    if greyFrame.Visible and greyFrame.BackgroundTransparency == 0.4 then return end;

    greyFrame.Visible = true;
    ts:Create(greyFrame, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {BackgroundTransparency = 0.4}):Play();
end

local function UpdateGamepasses(newData)
    for gpName, _ in pairs(newData) do
        local clone = scrollingHolder:FindFirstChild(gpName);
        for _, child in ipairs(clone.Inner.Buttons.Buy:GetChildren()) do
            child.Visible = (child.Name == 'Owns');
        end
        clone.Inner.Buttons.Buy:SetAttribute('Scale', nil);
        if gpConnections[gpName] then
            gpConnections[gpName]:Disconnect();
        end
        -- clone.Inner.Buttons.Buy.PriceHolder.Title.Text = 'Owned';
    end
end

local function LoadShop()
    for gamepassName, data in pairs(shopStats.Gamepasses) do
        if data.GamepassID == nil then continue end;
        local clone = passTemplate:Clone();
        clone.Name = gamepassName;
        clone.Parent = scrollingHolder;
        clone.LayoutOrder = data.LayoutOrder;

        local s, info = pcall(function()
            return mps:GetProductInfoAsync(data.GamepassID, Enum.InfoType.GamePass);
        end)
        if s then
            clone.Inner.Buttons.Buy.PriceHolder.Title.Text = info.PriceInRobux;
        end

        clone.Inner.PassName.Text = gamepassName;
        clone.Inner.PassDescription.Text = data.Description;
        -- clone.Icon.Image = to be done;

        gpConnections[gamepassName] = clone.Inner.Buttons.Buy.MouseButton1Click:Connect(function()
            if not db then db = true task.delay(.15, function() db = false end)
                mps:PromptGamePassPurchase(player, data.GamepassID);
                ShowGreyFrame();
            end
        end)
        clone.Inner.Buttons.Gift.MouseButton1Click:Connect(function()
            if not db then db = true task.delay(.15, function() db = false end)
                
            end
        end)

        clone.Visible = true;
    end

    for productName, data in pairs(shopStats.DeveloperProducts) do
        if data.ProductID == nil then continue end;

        local s, info = pcall(function()
            return mps:GetProductInfoAsync(data.ProductID, Enum.InfoType.Product);
        end)
        local clone
        if string.match(productName, 'Pet') then

            if string.match(productName, 'Combi') then
                clone = exclusivePetFrame.Inner.Bundle;
                -- Pet images to be done
                clone.Buy.Discounted.Text = ''..info.PriceInRobux;
            else
                clone = exclusivePetFrame.Inner.Pets[productName];
                clone.PetName.Text = data.PetName;
                -- clone.Icon.Image = to be done;
                clone.Buy.Price.Text = ''..info.PriceInRobux;
            end
        elseif string.match(productName, 'Gem') then
            clone = gemsTemplate:Clone();
            clone.Parent = scrollingHolder;
            clone.Name = productName;
            clone.LayoutOrder = data.LayoutOrder;
            clone.Frame.Buy.PriceHolder.Title.Text = info.PriceInRobux;
            clone.Visible = true;
        end

        local buyButton = clone:FindFirstChild('Buy', true);
        buyButton.MouseButton1Click:Connect(function()
            if not db then db = true task.delay(.15, function() db = false end)
                mps:PromptProductPurchase(player, data.ProductID);
                ShowGreyFrame();
            end
        end)
    end

    UpdateGamepasses(dataSync.Get('OwnedGamepasses'));
end

function ShopHandler.HideGreyFrame()
    if not greyFrame.Visible and greyFrame.BackgroundTransparency == 1 then return end;

    local tween = ts:Create(greyFrame, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {BackgroundTransparency = 1})
    tween:Play();
    tween.Completed:Wait();
    greyFrame.Visible = false;
end

function ShopHandler.PurchaseConfirmed(purchaseType: string, purchaseName: string, id: number)
    ShopHandler.HideGreyFrame();

    local popup = infoPopup.new(
        nil,
        'Thank you for your purchase!',
        function()
            menuHandler.handleOpenClose(shopFrame);
        end,
        infoFrame
    );

    menuHandler.handleOpenClose(infoFrame);
end

function ShopHandler.Initialize()
    if not game.Loaded then game.Loaded:Wait() end;

    dataSync.OnReady(function()
        LoadShop();
    end)

    dataSync.OnChanged('OwnedGamepasses', function(new, old)
        UpdateGamepasses(new);
    end)

    task.spawn(function()
        while true do
            local tween1 = ts:Create(shopFrame.Shine, TweenInfo.new(15, Enum.EasingStyle.Linear), {Rotation = 180});
            local tween2 = ts:Create(shopFrame.Shine, TweenInfo.new(15, Enum.EasingStyle.Linear), {Rotation = 360});
            
            tween1:Play();
            tween1.Completed:Wait();

            tween2:Play();
            tween2.Completed:Wait();
        end
    end)
end

return ShopHandler;