local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Framework = ReplicatedStorage:WaitForChild("Framework")

local InterfaceUtility = require(Framework:WaitForChild("InterfaceUtility"))
local Eggs = workspace:WaitForChild("Eggs")

local EggUnlockCutscene = {
	IsPlaying = false,
}

function EggUnlockCutscene.UnlockEggCutscene(eggName: string)
	EggUnlockCutscene.IsPlaying = true
	local Egg = Eggs:WaitForChild(eggName)
	if not Egg then
		return
	end
	local eggModel = Egg:WaitForChild(eggName)
	local OGPivot = eggModel:GetPivot()
	local HeightValue = Instance.new("NumberValue")
	HeightValue.Value = 0
	local SpinAngle = Instance.new("NumberValue")
	SpinAngle.Value = 0

	local IsSpinning = true

	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt)
		if not IsSpinning then
			return
		end
		SpinAngle.Value += math.rad(360) * dt
		eggModel:PivotTo(OGPivot * CFrame.new(0, HeightValue.Value, 0) * CFrame.Angles(0, SpinAngle.Value, 0))
	end)

	local _Tween =
		TweenService:Create(HeightValue, TweenInfo.new(1.75, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 5 })
	_Tween:Play()
	_Tween.Completed:Wait()

	-- Snaps after this point

	--local nextFullTurn = math.ceil(SpinAngle.Value / math.rad(360)) * math.rad(360)
	--TweenService:Create(SpinAngle, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Value = nextFullTurn}):Play()

	_Tween =
		TweenService:Create(HeightValue, TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Value = 0 })
	_Tween:Play()
	_Tween.Completed:Wait()

	InterfaceUtility.ShakeCamera(workspace.Camera, 0.8, 8, 4)

	IsSpinning = false
	HeightValue:Destroy()
	SpinAngle:Destroy()
	conn:Disconnect()
	EggUnlockCutscene.IsPlaying = false
	eggModel:PivotTo(OGPivot)
end

return EggUnlockCutscene
