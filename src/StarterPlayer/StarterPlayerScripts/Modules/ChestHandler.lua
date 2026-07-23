local DataSyncClient = require(script.Parent.DataSyncClient)
local ChestHandler = {}

function ChestHandler.Initialize()
	DataSyncClient.OnReady(function()
		--
	end)
end

return ChestHandler
