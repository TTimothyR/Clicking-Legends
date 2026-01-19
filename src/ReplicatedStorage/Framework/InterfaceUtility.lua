local interfaceUtility = {}

-- Services
local rs = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")

function interfaceUtility.ShakeUI(object, duration, strength, speed)
	local originalPos = object.Position

	local originalXScale = originalPos.X.Scale
	local originalYScale = originalPos.Y.Scale

	local startTime = tick()
	local timeOffset = 0
	local previousFrameTime = startTime

	while tick() - startTime < duration do
		local currentTime = tick()
		local deltaTime = currentTime - previousFrameTime
		previousFrameTime = currentTime

		timeOffset += deltaTime * speed

		local offsetX = math.noise(timeOffset, 0, 0) * strength
		local offsetY = math.noise(0, timeOffset, 0) * strength

		object.Position = UDim2.new(originalXScale + offsetX, 0, originalYScale + offsetY, 0)
		task.wait()
	end
	
	object.Position = originalPos
end

function interfaceUtility.RotateGradient(gradient: UIGradient)
	local connection: RBXScriptConnection
	
	local startTime = os.clock()
	local speed = 5
	local min, max = -180, 180
	
	gradient.Rotation = min
	
	connection = runService.Heartbeat:Connect(function()
		local currentTime = os.clock()
		local timeInCycle = (currentTime - startTime) % speed
		
		local progress = timeInCycle/speed
		
		local sineValue = math.sin(progress * 2 * math.pi)
		
		gradient.Rotation = min + ((sineValue + 1)/2) * (max - min)
	end)
	
	return connection
end

return interfaceUtility