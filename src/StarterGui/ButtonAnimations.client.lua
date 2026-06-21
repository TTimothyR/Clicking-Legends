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
		local attributeChange: RBXScriptConnection

		local originalSize: UDim2 = button.Size
		local originalRotation: UDim2 = button.Rotation

		local hoverScale: number = button:GetAttribute("Scale") or 1;
		local clickScale: number = 1 - (hoverScale - 1) or 1;
		local rotation: number = button:GetAttribute("Rotation") or 0;

		local hoverSize: UDim2 = UDim2.new(originalSize.X.Scale * hoverScale, originalSize.X.Offset, originalSize.Y.Scale * hoverScale, originalSize.Y.Offset)
		local clickSize = UDim2.new(originalSize.X.Scale * clickScale, originalSize.X.Offset, originalSize.Y.Scale * clickScale, originalSize.Y.Offset)

		local isHovering: boolean = false
		local rotateTween: Tween = ts:Create(button, tweenInfo, {Rotation = rotation})
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
		button:GetPropertyChangedSignal("Parent"):Once(function()
			if button.Parent == nil then
				mouseEnter:Disconnect()
				mouseLeave:Disconnect()
				mouseDown:Disconnect()
				mouseUp:Disconnect()
			end
		end)
		attributeChange = button:GetAttributeChangedSignal('Scale'):Connect(function()
			if button:GetAttribute('Scale') == nil then
				mouseEnter:Disconnect()
				mouseLeave:Disconnect()
				mouseDown:Disconnect()
				mouseUp:Disconnect()
				attributeChange:Disconnect()
			end
		end)
	end)
end

local function InitializeAnimation(descendant)
	if descendant:IsA("ImageButton") and next(descendant:GetAttributes()) then
		animateButton(descendant)
	end
end

for _, descendant in playerGui:GetDescendants() do
	InitializeAnimation(descendant)
end

playerGui.DescendantAdded:Connect(function(descendant)
	InitializeAnimation(descendant)
end)