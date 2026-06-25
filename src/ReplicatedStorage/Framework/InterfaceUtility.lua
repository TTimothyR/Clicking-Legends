local interfaceUtility = {}

-- Services
local TweenService = game:GetService("TweenService")
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

function interfaceUtility.PlayScreenGlow(Glow, color, duration, onScreenDuration)
	task.spawn(function()
		for _, v in pairs(Glow:GetChildren()) do
			v.Visible = true
			v.ImageColor3 = color

			TweenService:Create(v, TweenInfo.new(duration), { ImageTransparency = 0 }):Play()

			task.delay(onScreenDuration, function()
				local twn = TweenService:Create(v, TweenInfo.new(duration), { ImageTransparency = 1 })
				twn:Play()
				twn.Completed:Wait()
				v.Visible = false

				--twn.Completed:Connect(function()
				--	v.Visible = false
				--end)
			end)
		end
	end)
end

function interfaceUtility.PlayWhiteOutAnim(template, parent, animationTime, size)
	task.spawn(function()
		if not size then
			size = 1.25
		end
		local clone: Frame = template:Clone()
		clone.Parent = parent

		clone:TweenSize(UDim2.fromScale(size, size), Enum.EasingDirection.Out, Enum.EasingStyle.Sine, animationTime)
		local tween: Tween = TweenService:Create(
			clone,
			TweenInfo.new(animationTime, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 1 }
		)
		tween:Play()
		tween.Completed:Wait()

		clone:Destroy()
	end)
end

function interfaceUtility.PlayFOV(goal, reset, resetTo)
	task.spawn(function()
		local camera = workspace.CurrentCamera
		local tween = TweenService:Create(
			camera,
			TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{ FieldOfView = goal }
		)
		tween:Play()
		tween.Completed:Wait()

		if reset then
			tween = TweenService:Create(
				camera,
				TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
				{ FieldOfView = resetTo }
			)
			tween:Play()
		end
	end)
end

return interfaceUtility
