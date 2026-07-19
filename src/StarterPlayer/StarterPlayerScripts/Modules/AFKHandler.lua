local AFKHandler = {}

local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local framework = ReplicatedStorage:WaitForChild("Framework")
local library = framework:WaitForChild("Library")

local player = Players.LocalPlayer

local playerGui = player.PlayerGui
local frames = playerGui:WaitForChild("Frames")
local afkReportFrame = frames.AFKReport :: CanvasGroup
local holderFrame = afkReportFrame.Holder :: Frame
local eggsHatchedFrame = holderFrame.EggsHatched :: Frame
local timeFrame = holderFrame.Time :: Frame
local rebirthsFrame = holderFrame.Rebirths :: Frame
local petsFrame = holderFrame.Pets :: Frame
local petList = petsFrame.List :: ScrollingFrame
local petTemplate = petsFrame.Template :: ImageButton

local dataSync = require(script.Parent.DataSyncClient)
local network = require(framework.Network)
local infMath = require(framework.InfiniteMath)
local globals = require(framework.Globals)
local imageService = require(library.ImageService)

local afk = false
local timeSinceLastAction = 0
local AFKThreshold = 1 -- second
local rejoinThreshold = 18 -- minutes
local showReportThreshold = 30 -- seconds
local eggsHatchedFormat = "Eggs Hatched: %s"
local rebirthsFormat = "Rebirths: %s"
local dismissConnection

local targetEndScale = UDim2.fromScale(1, 1)
local targetStartScale = UDim2.fromScale(2.5, 2.5)
local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

local function ShowAFKReport()
	afkReportFrame.Visible = true

	local scaleTween = TweenService:Create(afkReportFrame, tweenInfo, { Size = targetEndScale })
	local transparencyTween = TweenService:Create(afkReportFrame, tweenInfo, { GroupTransparency = 0 })

	scaleTween:Play()
	transparencyTween:Play()

	transparencyTween.Completed:Wait()
end

local function HideAFKReport()
	local scaleTween = TweenService:Create(afkReportFrame, tweenInfo, { Size = targetStartScale })
	local transparencyTween = TweenService:Create(afkReportFrame, tweenInfo, { GroupTransparency = 1 })

	scaleTween:Play()
	transparencyTween:Play()

	transparencyTween.Completed:Wait()

	afkReportFrame.Visible = false
end

local function ShowPets(pets)
	for fullName, amount in pairs(pets) do
		for _ = 1, amount, 1 do
			local clone = petTemplate:Clone()
			clone.Frame.Icon.Image = imageService[fullName] or imageService["Placeholder"]

			clone.Parent = petList
			clone.Visible = true
		end
	end
end

local function AFKEnded()
	timeSinceLastAction = tick()

	if afk then
		afk = false

		local afkInfo = network:InvokeServer("StopAFK")

		if not afkInfo then
			return
		end

		if afkInfo.deltaTime < showReportThreshold then
			return
		end

		for _, instance in ipairs(petList:GetChildren()) do
			if instance:IsA("ImageButton") then
				instance:Destroy()
			end
		end

		eggsHatchedFrame.Title.Text = eggsHatchedFormat:format(globals.FormatNumber(afkInfo.deltaEggs))
		if afkInfo.deltaRebirths then
			rebirthsFrame.Title.Text = rebirthsFormat:format(infMath.new(afkInfo.deltaRebirths):GetSuffix(true))
		else
			rebirthsFrame.Title.Text = rebirthsFormat:format("N/A")
		end
		timeFrame.Title.Text = globals.FormatTime(afkInfo.deltaTime, true)

		ShowPets(afkInfo.petsHatched)

		ShowAFKReport()

		dismissConnection = UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
			if not gameProcessedEvent then
				return
			end

			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dismissConnection:Disconnect()
				HideAFKReport()
			end
		end)
	end
end

local function OnRejoin()
	local joinInfo = TeleportService:GetLocalPlayerTeleportData()

	if joinInfo and joinInfo.isAFK then
		afk = true
	else
		network:FireServer("ResetAFKReport")
	end
end

local function SetupCharacter(character)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid?

	humanoid.Running:Connect(function(speed: number)
		if speed >= 0.01 then
			AFKEnded()
		end
	end)
	humanoid.Jumping:Connect(function(active: boolean)
		if active then
			AFKEnded()
		end
	end)
end

function AFKHandler.Initialize()
	dataSync.OnReady(function()
		OnRejoin()
		timeSinceLastAction = tick()

		if player.Character then
			SetupCharacter(player.Character)
		end
		player.CharacterAdded:Connect(SetupCharacter)

		UserInputService.InputBegan:Connect(function(_: InputObject, _: boolean)
			AFKEnded()
		end)

		task.spawn(function()
			while player.Character.Parent do
				local currentTime = tick()

				local isAutoHatching = dataSync.Get("IsAutoHatching")
				local isAutoClicking = dataSync.Get("AutoClickerStatus")

				if not isAutoClicking and not isAutoHatching then
					task.wait(1)
					continue
				end

				if (currentTime - timeSinceLastAction) >= rejoinThreshold * 60 then
					network:FireServer("TPPlayer")
				end
				if (currentTime - timeSinceLastAction) >= AFKThreshold and not afk then
					afk = true
					network:FireServer("StartAFK")
				end
				task.wait(1)
			end
		end)
	end)
end

return AFKHandler
