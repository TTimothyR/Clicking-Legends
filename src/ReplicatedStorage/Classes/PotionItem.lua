local PotionItem = {}
local db = false
PotionItem.__index = PotionItem

-- Services
local rs = game:GetService("ReplicatedStorage")

-- Variables
local framework = rs:WaitForChild("Framework")
local library = framework:WaitForChild("Library")

-- Modules
local potionsStats = require(library.PotionStats)
local imageService = require(library.ImageService)
local globals = require(framework.Globals)

function PotionItem.new(inventoryHandler, data, templateClone)
	local self = setmetatable({}, PotionItem)

	self.amount = data.amount
	self.potionName = data.name
	self.rarity = potionsStats[self.potionName].Rarity or "Common"
	self.clone = templateClone
	self.selectButton = templateClone.Click

	self.image = imageService[self.potionName] or imageService["Placeholder"]

	self.connections = {}

	self:setupUI()

	self.connections.click = self.selectButton.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)
			inventoryHandler.SelectPotion(self)
		end
	end)

	self.connections.parentChange = self.clone:GetPropertyChangedSignal("Parent"):Once(function()
		self:Destroy()
	end)

	return self
end

function PotionItem:setupUI()
	self.selectButton.ImageColor3 = globals.RarityColors[self.rarity]
	if self.rarity == "Legendary" then
		self.selectButton.Legendary.Enabled = true
	end

	self.selectButton.ItemName.Text = self.potionName:gsub("_", " ")
	self.selectButton.Amount.Text = "x" .. self.amount

	self.selectButton.ItemIcon.Image = self.image

	self.clone.Visible = true
end

function PotionItem:updateAmount(newAmount)
	if newAmount <= 0 then
		return true
	end

	self.selectButton.Amount.Text = "x" .. newAmount
	return false
end

function PotionItem:Destroy()
	for _, con: RBXScriptConnection in pairs(self.connections) do
		con:Disconnect()
	end
	self.connections = nil
	self.clone:Destroy()
	self.amount = nil
	self.potionName = nil
	self.rarity = nil
	self.selectButton = nil
	self.image = nil
end

return PotionItem
