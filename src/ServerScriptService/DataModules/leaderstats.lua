local module = {}

-- Services
local rs = game:GetService("ReplicatedStorage")

-- Variables
local framework = rs:WaitForChild("Framework")

-- Modules
local infMath = require(framework.InfiniteMath)

function module:CreateLeaderstats(player: Player, profile)
	local leaderstats = Instance.new("Folder")
	leaderstats.Parent = player
	leaderstats.Name = "leaderstats"

	local clicks = Instance.new("StringValue")
	clicks.Parent = leaderstats
	clicks.Name = "Clicks"
	clicks.Value = infMath.new(profile.Data.Clicks):GetSuffix(true)

	local rebirths = Instance.new("StringValue")
	rebirths.Parent = leaderstats
	rebirths.Name = "Rebirths"
	rebirths.Value = infMath.new(profile.Data.Rebirths):GetSuffix(true)

	local gems = Instance.new("StringValue")
	gems.Parent = leaderstats
	gems.Name = "Gems"
	gems.Value = infMath.new(profile.Data.Gems):GetSuffix(true)

	local eggs = Instance.new("IntValue")
	eggs.Parent = leaderstats
	eggs.Name = "Eggs"
	eggs.Value = profile.Data.Eggs

	local uiLock = Instance.new("BoolValue")
	uiLock.Parent = player
	uiLock.Name = "UILock"
	uiLock.Value = false

	-- player:SetAttribute('Clicks', http:JSONEncode(profile.Data.Clicks));
	-- player:SetAttribute('Gems', http:JSONEncode(profile.Data.Gems));
	-- player:SetAttribute('Rebirths', http:JSONEncode(profile.Data.Rebirths));
	-- player:SetAttribute('Eggs', http:JSONEncode(profile.Data.Eggs));
	-- player:SetAttribute('ActualClicks', http:JSONEncode(profile.Data.ActualClicks));
end

return module
