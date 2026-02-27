local module = {}

-- Services
local rs = game:GetService("ReplicatedStorage")
local http = game:GetService('HttpService');

-- Variables
local framework = rs:WaitForChild("Framework")

-- Modules
local infMath = require(framework.InfiniteMath)

function module:CreateLeaderstats(player: Player, profile)
	local leaderstats = Instance.new("Folder", player)
	leaderstats.Name = "leaderstats"
	
	local clicks = Instance.new("StringValue", leaderstats)
	clicks.Name = "Clicks"
	clicks.Value = infMath.new(profile.Data.Clicks):GetSuffix(true)
	
	local rebirths = Instance.new("StringValue", leaderstats)
	rebirths.Name = "Rebirths"
	rebirths.Value = infMath.new(profile.Data.Rebirths):GetSuffix(true)
	
	local gems = Instance.new("StringValue", leaderstats)
	gems.Name = "Gems"
	gems.Value = infMath.new(profile.Data.Gems):GetSuffix(true)
	
	local eggs = Instance.new("StringValue", leaderstats)
	eggs.Name = "Eggs"
	eggs.Value = infMath.new(profile.Data.Eggs):GetSuffix(true)

	local uiLock = Instance.new("BoolValue", player)
	uiLock.Name = "UILock"
	uiLock.Value = false

	-- player:SetAttribute('Clicks', http:JSONEncode(profile.Data.Clicks));
	-- player:SetAttribute('Gems', http:JSONEncode(profile.Data.Gems));
	-- player:SetAttribute('Rebirths', http:JSONEncode(profile.Data.Rebirths));
	-- player:SetAttribute('Eggs', http:JSONEncode(profile.Data.Eggs));
	-- player:SetAttribute('ActualClicks', http:JSONEncode(profile.Data.ActualClicks));
end

return module
