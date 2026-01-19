local jobs = {}
local inits = {}

local rs = game:GetService("ReplicatedStorage")
local starterPlayer = game:GetService("StarterPlayer")
local runService = game:GetService("RunService")

local event: RemoteEvent = rs:WaitForChild("NetworkEvent")
local funct: RemoteFunction = rs:WaitForChild("NetworkFunction")

local isStudio = runService:IsStudio()

local function getTotal(parent)
	local total = 0

	for _, descendant in pairs(parent:GetDescendants()) do
		if descendant:IsA("ModuleScript") and descendant:GetAttribute("LoadClient") == true then
			total += 1
		end
	end

	return total
end

local function loadJobModules()
	local loaded, total = 0, getTotal(starterPlayer)
	for _, descendant in pairs(starterPlayer:GetDescendants()) do
		if descendant:IsA("ModuleScript") and descendant:GetAttribute("LoadClient") == true then
			local jobModule = require(descendant)
			for functionName, func in pairs(jobModule) do
				if functionName == "Initialize" then
					if inits[descendant.Name] == nil then
						func()
						inits[descendant.Name] = true
						--if isStudio then warn("- CLIENT - "..descendant.Name.." initialized!") end
					end
				else
					if jobs[functionName] == nil then
						jobs[functionName] = func
						--if isStudio then print("- CLIENT - Registered job: ", functionName) end
					end
				end
			end
			loaded += 1
			if isStudio then warn(`- CLIENT - {descendant.Name} ({loaded}/{total}) finished loading!`) end
		end
	end
end

loadJobModules()

event.OnClientEvent:Connect(function(job, ...)
	if jobs[job] then
		jobs[job](...)
	else
		error("No handler for job: "..job)
	end
end)

funct.OnClientInvoke = function(job, ...)
	if jobs[job] then
		return jobs[job](...)
	else
		error("No handler for job: "..job)
		return nil
	end
end