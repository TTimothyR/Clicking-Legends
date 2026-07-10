local jobs = {}

local rs = game:GetService("ReplicatedStorage")
local sss = game:GetService("ServerScriptService")
local runService = game:GetService("RunService")

local event: RemoteEvent = rs:WaitForChild("NetworkEvent")
local funct: RemoteFunction = rs:WaitForChild("NetworkFunction")

local isStudio = runService:IsStudio()

local function getTotal(parent)
	local total = 0

	for _, descendant in pairs(parent:GetDescendants()) do
		if descendant:IsA("ModuleScript") and descendant:GetAttribute("LoadServer") == true then
			total += 1
		end
	end

	return total
end

local function loadJobModules()
	local loaded, total = 0, getTotal(sss)
	for _, descendant in pairs(sss:GetDescendants()) do
		if descendant:IsA("ModuleScript") and descendant:GetAttribute("LoadServer") == true then
			local jobModule = require(descendant)

			for functionName, func in pairs(jobModule) do
				if type(func) ~= "function" then
					continue
				end
				if functionName ~= "Profiles" then
					if functionName == "Initialize" then
						func()
						--if isStudio then warn("- SERVER - "..descendant.Name.." initialized!") end
					else
						if jobs[functionName] == nil then
							jobs[functionName] = func
							--if isStudio then print("- SERVER - Registered job: ", functionName) end
						end
					end
				end
			end
			loaded += 1
			if isStudio then
				warn(`- SERVER - {descendant.Name} ({loaded}/{total}) finished loading!`)
			end
		end
	end
end

loadJobModules()

event.OnServerEvent:Connect(function(player, job, ...)
	if jobs[job] then
		jobs[job](player, ...)
	else
		error("No handler for job: " .. job)
	end
end)

funct.OnServerInvoke = function(player, job, ...)
	if jobs[job] then
		return jobs[job](player, ...)
	else
		error("No handler for job: " .. job)
		return nil
	end
end
