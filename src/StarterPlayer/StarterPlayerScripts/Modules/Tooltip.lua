local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")

local Framework = ReplicatedStorage:WaitForChild("Framework")

local Library = Framework:WaitForChild("Library")

local Tooltip = {}

local Player = Players.LocalPlayer
local PlayerGui = Player.PlayerGui
local Frames = PlayerGui:WaitForChild("Frames")
local TooltipFrame = Frames:WaitForChild("Tooltip")
local Background = TooltipFrame.Background
local Labels = TooltipFrame.Labels
local Camera = workspace.CurrentCamera

local Globals = require(ReplicatedStorage.Framework.Globals)
local Tooltips = require(Library:WaitForChild("Tooltips"))

local function DisconnectAll(connections)
	for _, connection in ipairs(connections or {}) do
		if connection and connection.Connected then
			connection:Disconnect()
		end
	end
	table.clear(connections or {})
end

local function GetMouseUIPos()
	local MousePos = UserInputService:GetMouseLocation()
	local GuiInset = GuiService:GetGuiInset()
	local ViewportSize = Camera.ViewportSize

	local VisibleMouseY = MousePos.Y - GuiInset.Y
	local VisibleScreenHeight = ViewportSize.Y - GuiInset.Y

	return UDim2.fromScale(MousePos.X / ViewportSize.X, VisibleMouseY / VisibleScreenHeight)
end

local function SetBackgroundSize()
	local NewSize = UDim2.fromScale(1, 0.15)

	for _, v in pairs(Labels:GetChildren()) do
		if v:IsA("Frame") or v:IsA("TextLabel") or v:IsA("ImageLabel") then
			if v.Visible == true then
				NewSize += UDim2.fromScale(0, v.Size.Y.Scale * 1.275)
			end
		end
	end

	Background.Size = NewSize
end

local function SetDefaultVisibility()
	for _, v in pairs(Labels:GetChildren()) do
		if v:IsA("Frame") or v:IsA("TextLabel") or v:IsA("ImageLabel") then
			v.Visible = false
		end
	end
end

function Tooltip.SetupTooltip(Button: GuiButton, TooltipType: string, Data): { [number]: RBXScriptConnection }
	if not Tooltips[TooltipType] then
		return {}
	end

	local connections = {}
	local isHovering = false

	if not Data.reference then
		warn("Data does not contain a reference string, cannot continue.")
		return {}
	end

	local enterConnection = Button.MouseEnter:Connect(function()
		if not isHovering then
			isHovering = true
		end
		TooltipFrame.Name = Data.reference

		SetDefaultVisibility()
		local Pos = (GetMouseUIPos() + UDim2.fromScale(0.02, 0.02) + UDim2.new())
		TooltipFrame.Position = Pos
		TooltipFrame.Visible = true

		Tooltips[TooltipType](TooltipFrame, Data)
		SetBackgroundSize()
	end) :: RBXScriptConnection

	local cleanedUp = false

	local function LeaveCallback()
		if isHovering then
			isHovering = false
		end
		if TooltipFrame.Name == Data.reference then
			TooltipFrame.Visible = false
			SetDefaultVisibility()
		end
	end
	local function Cleanup()
		if cleanedUp then
			return
		end
		cleanedUp = true

		LeaveCallback()

		DisconnectAll(connections)
	end

	local hoverConnection = RunService.Heartbeat:Connect(function(elapsedSec: number)
		if isHovering then
			local Pos = (GetMouseUIPos() + UDim2.fromScale(0.02, 0.02) + UDim2.new())
			TooltipFrame.Position = Pos
			Tooltips[TooltipType](TooltipFrame, Data)

			local legendaryGradient = TooltipFrame.Top.Info.Rarity.Legendary :: UIGradient

			if legendaryGradient.Enabled then
				legendaryGradient.Rotation += 360 / Globals.LegendaryGradientRotateSpeed * elapsedSec % 360
			end
		end
	end)

	local leaveConnection = Button.MouseLeave:Connect(LeaveCallback) :: RBXScriptConnection
	local destroyConnection = Button.Destroying:Connect(Cleanup) :: RBXScriptConnection

	table.insert(connections, enterConnection)
	table.insert(connections, leaveConnection)
	table.insert(connections, destroyConnection)
	table.insert(connections, hoverConnection)

	return connections
end

return Tooltip
