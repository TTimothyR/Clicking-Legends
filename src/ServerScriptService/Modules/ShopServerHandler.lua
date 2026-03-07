local ShopHandler = {};

-- Services
local players = game:GetService('Players');
local mps = game:GetService('MarketplaceService');
local rs = game:GetService('ReplicatedStorage');

-- Variables
local framework: Folder = rs:WaitForChild('Framework');
local library: Folder = framework:WaitForChild('Library');

-- Modules
local shopStats = require(library.ShopStats);
local network = require(framework.Network);

-- Constants
local gpIDToName = {};
local productIDToname = {};
local callbacks = {
    ['Double Luck'] = function(player: Player)
        print(player.Name..' bought double luck')
    end,
    
    
    ['Pet'] = function(player: Player, petNames: {number : string})
        print(player.Name..' bought a pet');
    end,
    ['Gem'] = function(player: Player, packNr: number)
        
    end
}


local function GamepassPurchaseHandler()
    for gpName, data in pairs(shopStats.Gamepasses) do
        if data.GamepassID then
            gpIDToName[data.GamepassID] = gpName;
        end
    end

    mps.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
        if not wasPurchased then
            network:FireClient(player, 'HideGreyFrame');
            return
        end;

        local gpName = gpIDToName[gamePassId];
        if not gpName then
            network:FireClient(player, 'HideGreyFrame');
            return
        end;

        callbacks[gpName](player);
        network:FireClient(player, 'PurchaseConfirmed', 'gamepass', gpName, gamePassId);
    end)
end

local function ProductPurchaseHandler()
    for productName, data in pairs(shopStats.DeveloperProducts) do
        if data.ProductID then
            productIDToname[data.ProductID] = productName;
        end
    end

    mps.PromptProductPurchaseFinished:Connect(function(userId, productId, isPurchased)
        if not isPurchased then
            network:FireClient(players:GetPlayerByUserId(userId), 'HideGreyFrame');
        end
    end)

    mps.ProcessReceipt = function(receiptInfo)
        local player = players:GetPlayerByUserId(receiptInfo.PlayerId);
        if not player then
            -- network:FireClient(player, 'HideGreyFrame');
            return Enum.ProductPurchaseDecision.NotProcessedYet;
        end

        local productName = productIDToname[receiptInfo.ProductId];
        if not productName then
            network:FireClient(player, 'HideGreyFrame');
            return Enum.ProductPurchaseDecision.PurchaseGranted;
        end

        if string.match(productName, 'Pet') then
            callbacks['Pet'](player, nil);
        elseif string.match(productName, 'Gem') then
            callbacks['Gem'](player, nil);
        end

        network:FireClient(player, 'PurchaseConfirmed', 'product', productName, receiptInfo.ProductId);

        return Enum.ProductPurchaseDecision.PurchaseGranted;
    end
end

function ShopHandler.Initialize()
    GamepassPurchaseHandler();
    ProductPurchaseHandler();
end

return ShopHandler;