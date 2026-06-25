local Popup = {}
Popup.__index = Popup

function Popup.new(title, message, confirmCallback, cancelCallback, frame)
	local self = setmetatable({}, Popup)

	self.title = title or "Hey!"
	self.message = message
		or "The owner forgot to add a message lol. Because you don't know what this warning does, I advice clicking CANCEL."
	self.confirmCallback = confirmCallback
	self.cancelCallback = cancelCallback

	self.connections = {}

	self.frame = frame
	self.frame.Title.Text = self.title
	self.frame.Message.Text = self.message
	self.confirmButton = self.frame.Main.Buttons.Yes
	self.cancelButton = self.frame.Main.Buttons.No

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
		self.cancelButton.MouseButton1Click:Connect(function()
			if type(self.cancelCallback) == "function" then
				self.cancelCallback()
			end
			self:Cleanup()
		end)
	)
	table.insert(
		self.connections,
		self.frame.Close.MouseButton1Click:Connect(function()
			if type(self.cancelCallback) == "function" then
				self.cancelCallback()
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
	self.cancelCallback = nil
end

return Popup
