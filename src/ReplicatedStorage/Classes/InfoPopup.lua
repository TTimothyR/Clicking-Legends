local Popup = {}
Popup.__index = Popup

function Popup.new(title, message, confirmCallback, frame)
	local self = setmetatable({}, Popup)

	self.title = title or "Hey!"
	self.message = message or "The owner forgot to add a message lol. You can ignore this one :)"
	self.confirmCallback = confirmCallback

	self.connections = {}

	self.frame = frame
	self.frame.Title.Text = self.title
	self.frame.Message.Text = self.message
	self.confirmButton = self.frame.Main.Buttons.Yes

	table.insert(
		self.connections,
		self.confirmButton.MouseButton1Click:Connect(function()
			if type(self.confirmCallback) == "function" then
				self.confirmCallback()
			end
			self:Cleanup()
		end)
	)

	table.insert(
		self.connections,
		self.frame.Close.MouseButton1Click:Connect(function()
			if type(self.confirmCallback) == "function" then
				self.confirmCallback()
			end
			self:Cleanup()
		end)
	)

	return self
end

function Popup:Cleanup()
	for _, connection in pairs(self.connections) do
		connection:Disconnect()
	end
	self.connections = {}
	self.confirmCallback = nil
end

return Popup
