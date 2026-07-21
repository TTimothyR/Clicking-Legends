local interfaceUtility = {}

-- Services
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local runService = game:GetService("RunService")
local Globals = require(script.Parent.Globals)

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
	strength = math.rad(strength) -- add this line
	local StartCFrame = camera.CFrame
	local StartTime = tick()
	local SeedX, SeedY, SeedZ = 0, 100, 200

	local conn: RBXScriptConnection

	conn = runService.RenderStepped:Connect(function()
		local elapsed = tick() - StartTime
		if elapsed >= duration then
			conn:Disconnect()
			camera.CFrame = StartCFrame
			return
		end

		local t = elapsed * speed
		local fallOff = 1 - (elapsed / duration)
		local noiseX = math.noise(t + SeedX) * strength * fallOff
		local noiseY = math.noise(t + SeedY) * strength * fallOff
		local noiseZ = math.noise(t + SeedZ) * strength * fallOff

		camera.CFrame = StartCFrame * CFrame.Angles(noiseX, noiseY, noiseZ)
	end)

	--while tick() - startTime < duration do
	--	local elapsed = tick() - startTime
	--	if elapsed >= duration then
	--		conn:Disconnect()
	--		camera.CFrame = startCFrame
	--		return
	--	end
	--	local dt = runService.RenderStepped:Wait()

	--	timeOffset += dt * speed
	--	local t
	--	local fallOff = 1 - (elapsed / duration)
	--	local noiseX = math.noise(timeOffset, 0, 0)
	--	local noiseY = math.noise(0, timeOffset, 0)
	--	local noiseZ = math.noise(0, 0, timeOffset)
	--	camera.CFrame = camera.CFrame * CFrame.Angles(noiseX, noiseY, noiseZ)
	--end

	--camera.CFrame = start
end

function interfaceUtility.CreateShinyEffect(clone): RBXScriptConnection
	local startPosition = UDim2.fromScale(-0.5 * 1.5, 0.5)
	local endPosition = UDim2.fromScale(1.5 * 1.5, 0.5)

	local state = "moving"
	local duration = math.random(500, 900) / 1000
	local waitTime = math.random(1500, 1900) / 1000
	local elapsed = 0

	local shinyEffect = clone.Frame:FindFirstChildOfClass("ImageLabel").ShinyEffect :: ImageLabel
	shinyEffect.Position = startPosition

	local connection = RunService.Heartbeat:Connect(function(elapsedSec: number)
		elapsed += elapsedSec

		if state == "moving" then
			local alpha = math.clamp(elapsed / duration, 0, 1)

			shinyEffect.Position = startPosition:Lerp(endPosition, alpha)

			if alpha >= 1 then
				elapsed = 0
				waitTime = math.random(1500, 1900) / 1000
				shinyEffect.Position = startPosition
				state = "waiting"
			end
		elseif state == "waiting" then
			if elapsed >= waitTime then
				state = "moving"
				elapsed = 0
				duration = math.random(500, 900) / 1000
				shinyEffect.Position = startPosition
			end
		end
	end)
	return connection
end

function interfaceUtility.CreateGradientAnimation(
	gradientsToAnimate: { [number]: UIGradient },
	currentRotation: { value: number }
): RBXScriptConnection
	return runService.Heartbeat:Connect(function(elapsedSec: number)
		currentRotation.value += 360 / Globals.LegendaryGradientRotateSpeed * elapsedSec
		if currentRotation.value >= 360 then
			currentRotation.value -= 360
		end
		for i = #gradientsToAnimate, 1, -1 do
			local gradient = gradientsToAnimate[i] :: UIGradient

			if not gradient or not gradient.Parent then
				table.remove(gradientsToAnimate, i)
			else
				gradient.Rotation = currentRotation.value
			end
		end
	end) :: RBXScriptConnection
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
