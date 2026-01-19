local PetItem = {}
local db = false
PetItem.__index = PetItem

-- Services
local rs = game:GetService("ReplicatedStorage")

-- Variables
local framework = rs:WaitForChild("Framework")
local library = framework:WaitForChild("Library")

-- Modules
local imageService = require(library.ImageService)
local globals = require(framework.Globals)

function PetItem.new(inventoryHandler, petData, templateClone)
	local self = setmetatable({}, PetItem)
	
	self.data = petData
	self.clone = templateClone
	self.selectButton = templateClone.Click
	
	self.evoPrefix = self.data.evo and "Evolved " or ""
	self.variantPrefix = (self.data.variant == "Shiny") and "Shiny " or ""
	self.image = 		
		imageService[self.variantPrefix..self.evoPrefix..self.data.petName]
		or imageService[self.evoPrefix..self.data.petName]
		or imageService["Placeholder"]
	
	self.connections = {}
	
	self:setupUI()
	
	self.connections.click = self.selectButton.MouseButton1Click:Connect(function()
		if not db then db = true task.delay(.15, function() db = false end)
			inventoryHandler.SelectPet(self)
		end
	end)
	
	self.connections.parentChange = self.clone:GetPropertyChangedSignal("Parent"):Once(function()
		self:Destroy()
	end)
	
	return self
end

function PetItem:setupUI()
	self.selectButton.ImageColor3 = globals.RarityColors[self.data.rarity]
	self.selectButton.Legendary.Enabled = (self.data.rarity == "Legendary") or (self.data.rarity == "Secret")
	
	self.selectButton.ItemName.Text = self.data.petName
	self.selectButton.ItemIcon.Image = self.image
	self.selectButton.EvoTag.Visible = self.data.evo
	self.selectButton.SecretTag.Visible = (self.data.rarity == "Secret")
	
	self.selectButton.Locked.Visible = self.data.locked
	
	if self.data.variant == "Shiny" then
		if self.data.evo then
			self.selectButton.ItemName.ShinyEvoGradient.Enabled = true
		else
			self.selectButton.ItemName.ShinyGradient.Enabled = true
		end
	else
		if self.data.evo then
			self.selectButton.ItemName.EvoGradient.Enabled = true
		end
	end
	
	if self.data.equipped then
		self.selectButton.ImageColor3 = Color3.fromRGB(97, 239, 53)
		self.selectButton.Legendary.Enabled = false
	end
	
	self.clone.Visible = true
end

function PetItem:updateEquippedStatus(isEquipped)
	if isEquipped then
		self.selectButton.ImageColor3 = Color3.fromRGB(97, 239, 53)
		self.selectButton.Legendary.Enabled = false
	else
		self.selectButton.ImageColor3 = globals.RarityColors[self.data.rarity]
		self.selectButton.Legendary.Enabled = (self.data.rarity == "Legendary") or (self.data.rarity == "Secret")
	end
end

function PetItem:Destroy()
	for _, con in pairs(self.connections) do
		con:Disconnect()
	end
	self.connections = nil
	self.clone:Destroy()
	self.data = nil
	self.clone = nil
	self.selectButton = nil
	self.evoPrefix = nil
	self.variantPrefix = nil
	self.image = nil
end

return PetItem