local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")

local Framework = ReplicatedStorage:WaitForChild("Framework")

local Library = Framework:WaitForChild("Library")

local Tooltip = {}

local Player = Players.LocalPlayer
local PlayerGui = Player.PlayerGui
local Frames = PlayerGui:WaitForChild("Frames")
local TooltipFrame = Frames:WaitForChild("Tooltip")
local Labels = TooltipFrame.Labels
local Camera = workspace.CurrentCamera

local Tooltips = require(Library:WaitForChild("Tooltips"))

local function GetMouseUIPos()
	local MousePos = UserInputService:GetMouseLocation()
	local GuiInset = GuiService:GetGuiInset()
	local ViewportSize = Camera.ViewportSize

	local VisibleMouseY = MousePos.Y - GuiInset.Y
	local VisibleScreenHeight = ViewportSize.Y - GuiInset.Y

	return UDim2.fromScale(MousePos.X / ViewportSize.X, VisibleMouseY / VisibleScreenHeight)
end

-- local function SetBackgroundSize()
-- 	local NewSize = UDim2.fromScale(1, 0.15)

-- 	for _, v in pairs(Labels:GetChildren()) do
-- 		if v:IsA("Frame") or v:IsA("TextLabel") or v:IsA("ImageLabel") then
-- 			if v.Visible == true then
-- 				NewSize += UDim2.fromScale(0, v.Size.Y.Scale * 1.275)
-- 			end
-- 		end
-- 	end

-- 	Background.Size = NewSize
-- end

local function SetDefaultVisiblity()
	for _, v in pairs(Labels:GetChildren()) do
		if v:IsA("Frame") or v:IsA("TextLabel") or v:IsA("ImageLabel") then
			v.Visible = false
		end
	end
end

function Tooltip.SetupTooltip(Button: GuiButton, TooltipType: string, Data: {})
	if not Tooltips[TooltipType] then
		return
	end

	Button.MouseMoved:Connect(function()
		SetDefaultVisiblity()
		local Pos = (GetMouseUIPos() + UDim2.fromScale(0.02, 0.02) + UDim2.new())
		TooltipFrame.Position = Pos
		TooltipFrame.Visible = true

		Tooltips[TooltipType](TooltipFrame, Data)
	end)

	Button.MouseLeave:Connect(function()
		TooltipFrame.Visible = false
		SetDefaultVisiblity()
	end)
end

return Tooltip
