local interfaceUtility = {}

-- Services
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

		object.Position = UDim2.fromScale(originalXScale + offsetX, originalYScale + offsetY)
		task.wait()
	end

	object.Position = originalPos
end

function interfaceUtility.ShakeCamera(camera, duration, strength, speed)
	local start = camera.CFrame

	local startTime = tick()
	local timeOffset = 0

	while tick() - startTime < duration do
		local dt = runService.RenderStepped:Wait()

		timeOffset += dt * speed
		local noiseX = math.noise(timeOffset, 0, 0)
		local noiseY = math.noise(0, timeOffset, 0)
		local noiseZ = math.noise(0, 0, timeOffset)
		camera.CFrame = camera.CFrame * CFrame.Angles(noiseX * strength, noiseY * strength, noiseZ * strength)
	end

	camera.CFrame = start
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

		local progress = timeInCycle / speed

		local sineValue = math.sin(progress * 2 * math.pi)

		gradient.Rotation = min + ((sineValue + 1) / 2) * (max - min)
	end)

	return connection
end

return interfaceUtility
