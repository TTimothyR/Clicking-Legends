-- Services
local players = game:GetService("Players")
local workspace = game:GetService("Workspace")

-- Variables
repeat task.wait() until players.LocalPlayer
local plr: Player = players.LocalPlayer

local camera = workspace.CurrentCamera

-- Constants
local base = 1633

-- UI
local playerGui = plr:WaitForChild("PlayerGui")

local function ScaleStroke(stroke)
	local baseThickness = stroke:GetAttribute("BaseThickness")
	if not baseThickness then
		baseThickness = stroke.Thickness
		stroke:SetAttribute("BaseThickness", baseThickness)
	end
	local scaleFactor = workspace.CurrentCamera.ViewportSize.X / base
	stroke.Thickness = baseThickness * scaleFactor
end

local function autoScale()
	for _, gui in ipairs(playerGui:GetDescendants()) do
		if gui:IsA("UIStroke") then
			task.spawn(ScaleStroke, gui)
		end
	end
end

playerGui.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("UIStroke") then
		ScaleStroke(descendant)
	end
end)

camera:GetPropertyChangedSignal("ViewportSize"):Connect(autoScale)
autoScale()