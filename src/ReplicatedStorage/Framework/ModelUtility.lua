local ModelUtil = {}

-- Services
local rs = game:GetService("RunService")
local ts = game:GetService("TweenService")

function ModelUtil.NewClickDetector(instance: any)
	local clickDetector: ClickDetector = Instance.new("ClickDetector")
	clickDetector.Parent = instance
	clickDetector.Name = "Click"

	return clickDetector
end

function ModelUtil.Rainbowify(i: Part | ParticleEmitter, v: number)
	local colorConnection: RBXScriptConnection

	if i:IsA("BasePart") then
		colorConnection = rs.Heartbeat:Connect(function()
			local t = tick() * 0.4 % 1
			local color = Color3.fromHSV(t, 0.7, v)
			i.Color = color
		end)
		i:GetPropertyChangedSignal("Parent"):Once(function()
			colorConnection:Disconnect()
		end)
	elseif i:IsA("ParticleEmitter") then
		colorConnection = rs.Heartbeat:Connect(function()
			local t = tick() * 0.4 % 1
			i.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHSV(t, 0.7, v)),
				ColorSequenceKeypoint.new(1, Color3.fromHSV(t, 0.7, v)),
			})
		end)
		i:GetPropertyChangedSignal("Parent"):Once(function()
			colorConnection:Disconnect()
		end)
	end
end

function ModelUtil.Mythicify(i: Part | ParticleEmitter, v: number)
	local colorConnection: RBXScriptConnection

	if i:IsA("BasePart") then
		colorConnection = rs.Heartbeat:Connect(function()
			local hueSpeed = 0.4
			local minHue = 0.6 -- Blue (approx)
			local maxHue = 0.8 -- Purple (approx)
			local hueRange = maxHue - minHue

			local timeInCycle = tick() * hueSpeed % (2 * hueRange)
			local hueOffset = math.abs(timeInCycle - hueRange)

			local t = minHue + hueOffset
			local color = Color3.fromHSV(t, 0.7, v)
			i.Color = color
		end)

		i:GetPropertyChangedSignal("Parent"):Once(function()
			colorConnection:Disconnect()
		end)
	elseif i:IsA("ParticleEmitter") then
		colorConnection = rs.Heartbeat:Connect(function()
			local hueSpeed = 0.4
			local minHue = 0.6 -- Blue (approx)
			local maxHue = 0.8 -- Purple (approx)
			local hueRange = maxHue - minHue

			local timeInCycle = tick() * hueSpeed % (2 * hueRange)
			local hueOffset = math.abs(timeInCycle - hueRange)

			local t = minHue + hueOffset
			i.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHSV(t, 0.7, v)),
				ColorSequenceKeypoint.new(1, Color3.fromHSV(t, 0.7, v)),
			})
		end)
		i:GetPropertyChangedSignal("Parent"):Once(function()
			colorConnection:Disconnect()
		end)
	end
end

function ModelUtil.ScalePart(part: BasePart, factor: number)
	local originalCframe = part.CFrame
	part.Size = part.Size * factor
	part.CFrame = CFrame.new(originalCframe.Position) * originalCframe.Rotation
end

function ModelUtil.AnimateScale(startScale: number, endScale: number, ti: TweenInfo, model: Model)
	local elapsed: number = 0
	local scale: number = 0
	local connection: RBXScriptConnection

	local style = ti.EasingStyle or Enum.EasingStyle.Quint
	local dir = ti.EasingDirection or Enum.EasingDirection.Out

	connection = rs.Heartbeat:Connect(function(deltaTime)
		elapsed = math.min(elapsed + deltaTime, ti.Time)

		local alpha = ts:GetValue(elapsed / ti.Time, style, dir)

		scale = startScale + alpha * (endScale - startScale)
		model:ScaleTo(scale)

		if elapsed >= ti.Time then
			connection:Disconnect()
		end
	end)
end

function ModelUtil.SquishModel(
	model: Model,
	scaleFactor: number,
	duration: number,
	ogPosition,
	jumpHeight: number,
	Repeat: boolean
)
	local completed: number = 0
	local toComplete: number = #model:GetChildren()

	local originalSizes = {}
	local primaryPart = model.PrimaryPart :: BasePart?
	local originalHeights = primaryPart and primaryPart.Size or 0
	for _, part: Instance in pairs(model:GetChildren()) do
		if part:IsA("BasePart") then
			originalSizes[part] = part.Size
		end
	end

	for _, part: Instance in pairs(model:GetChildren()) do
		if part:IsA("BasePart") then
			task.spawn(function()
				local newModelPos

				local originalSize = originalSizes[part]
				local newSize = Vector3.new(originalSize.X, originalSize.Y * scaleFactor, originalSize.Z)

				local yOffset = part.Position.Y - primaryPart.Position.Y
				local newOffset = yOffset * scaleFactor
				local newPos = part.Position + Vector3.new(0, newOffset - yOffset, 0)

				local pos = Instance.new("CFrameValue")
				pos.Value = ogPosition

				local con: RBXScriptConnection
				con = rs.Heartbeat:Connect(function()
					model:PivotTo(pos.Value)
				end)

				local heightDiff = (originalHeights.Y - originalHeights.Y * scaleFactor) / 2
				newModelPos = ogPosition * CFrame.new(0, -heightDiff, 0)
				local t1 = ts:Create(
					part,
					TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, Repeat),
					{ Size = newSize, Position = newPos + Vector3.new(0, jumpHeight, 0) }
				)
				local t2 = ts:Create(
					pos,
					TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, Repeat),
					{ Value = newModelPos + Vector3.new(0, jumpHeight, 0) }
				)
				t1:Play()
				t2:Play()
				t2.Completed:Wait()

				completed += 1
				con:Disconnect()
			end)
		end
	end
	repeat
		task.wait()
	until completed == toComplete
	return true
end

function ModelUtil.SetupPetModel(model: Model, variant: boolean)
	if not variant then
		return
	end
	if variant then
		for _, part in ipairs(model:GetChildren()) do
			local color = part.Color
			local h, s, v = Color3.toHSV(color)

			local newH, newS, newV

			local NEAR_BLACK_V = 0.05
			local NEAR_WHITE_V = 0.95
			local NEAR_ACHROMATIC_S = 0.05

			if v < NEAR_BLACK_V or (v > NEAR_WHITE_V and s < NEAR_ACHROMATIC_S) then
				newH = h
				newS = s
				newV = v
			else
				newH = (h + 0.5) % 1
				newS = math.max(s, 0.1)
				newV = 1 - v

				local MIN_TARGET_V = 0.15
				local MAX_TARGET_V = 0.85
				newV = math.max(MIN_TARGET_V, math.min(MAX_TARGET_V, newV))
			end

			part.Color = Color3.fromHSV(newH, newS, newV)
		end
		return
	end
	--if variant == "Rainbow" then
	--	for _, instance in pairs(model:GetDescendants()) do
	--		if instance:IsA("BasePart") then
	--			if instance.Transparency ~= 1 then
	--				local clone = instance:Clone()
	--				clone.Parent = instance.Parent
	--				clone.Transparency = 0.65
	--				clone.Size += Vector3.new(0.1,0.1,0.1)
	--				ModelUtil.Rainbowify(instance, 1)
	--			end
	--		end
	--	end
	--	return
	--end
end

return ModelUtil
