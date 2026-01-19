-- Services
local players = game:GetService("Players")
local ts = game:GetService("TweenService")

-- Variables
repeat task.wait() until players.LocalPlayer
local player: Player = players.LocalPlayer
local tweenInfo = TweenInfo.new(.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

-- UI
local playerGui = player:WaitForChild("PlayerGui")

local function animateButton(button: ImageButton)
	task.spawn(function()
		local mouseEnter: RBXScriptConnection
		local mouseLeave: RBXScriptConnection
		local mouseDown: RBXScriptConnection
		local mouseUp: RBXScriptConnection
		local removeConnection: RBXScriptConnection

		local originalSize: UDim2 = button.Size
		local originalPosition: UDim2 = button.Position
		local originalRotation: UDim2 = button.Rotation

		local hoverSize: UDim2 = UDim2.new(originalSize.X.Scale * 1.15, originalSize.X.Offset, originalSize.Y.Scale * 1.15, originalSize.Y.Offset)
		local clickSize = UDim2.new(originalSize.X.Scale * .85, originalSize.X.Offset, originalSize.Y.Scale * .85, originalSize.Y.Offset)

		local isHovering: boolean = false
		local rotateTween: Tween = ts:Create(button, tweenInfo, {Rotation = button:GetAttribute("AnimateAngle")})
		local rotateTween2: Tween = ts:Create(button, tweenInfo, {Rotation = originalRotation})


		mouseEnter = button.MouseEnter:Connect(function()
			isHovering = true
			button:TweenSize(hoverSize, Enum.EasingDirection.Out, Enum.EasingStyle.Quint, .2, true)
			rotateTween:Play()
		end)
		mouseLeave = button.MouseLeave:Connect(function()
			isHovering = false
			button:TweenSize(originalSize, Enum.EasingDirection.Out, Enum.EasingStyle.Quint, .2, true)
			rotateTween2:Play()
		end)
		mouseDown = button.MouseButton1Down:Connect(function()
			button:TweenSize(clickSize, Enum.EasingDirection.Out, Enum.EasingStyle.Quint, .2, true)
		end)
		mouseUp = button.MouseButton1Up:Connect(function()
			if isHovering == true then
				button:TweenSize(hoverSize, Enum.EasingDirection.Out, Enum.EasingStyle.Quint, .2, true)
			elseif isHovering == false then
				button:TweenSize(originalSize, Enum.EasingDirection.Out, Enum.EasingStyle.Quint, .2, true)
			end
		end)
		removeConnection = button:GetPropertyChangedSignal("Parent"):Once(function()
			if button.Parent == nil then
				mouseEnter:Disconnect()
				mouseLeave:Disconnect()
				mouseDown:Disconnect()
				mouseUp:Disconnect()
			end
		end)
	end)
end

for _, descendant in playerGui:GetDescendants() do
	if descendant:IsA("ImageButton") and descendant:GetAttribute("AnimateAngle") then
		animateButton(descendant)
	end
end

playerGui.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("ImageButton") and descendant:GetAttribute("AnimateAngle") then
		animateButton(descendant)
	end
end)