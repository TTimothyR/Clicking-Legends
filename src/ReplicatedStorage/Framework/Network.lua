local Network = {}

local rs = game:GetService("ReplicatedStorage")

do
	local event: RemoteEvent = rs:WaitForChild("NetworkEvent")
	local func: RemoteFunction = rs:WaitForChild("NetworkFunction")

	function Network:FireServer(job, ...)
		event:FireServer(job, ...)
	end

	function Network:InvokeServer(job, ...)
		return func:InvokeServer(job, ...)
	end

	function Network:FireClient(player, job, ...)
		event:FireClient(player, job, ...)
	end

	function Network:InvokeClient(player, job, ...)
		warn('YOU ARE USING A DANGEROUS REMOTE CALL. PLEASE DONT USE INVOKECLIENT');
		return func:InvokeClient(player, job, ...)
	end
end


return Network