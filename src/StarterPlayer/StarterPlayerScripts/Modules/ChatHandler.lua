local ChatHandler = {}

local tcs = game:GetService("TextChatService")
local DataSyncClient = require(script.Parent.DataSyncClient)

local channels = tcs:WaitForChild("TextChannels")
local hatchesChannel = channels:WaitForChild("Hatches") :: TextChannel

function ChatHandler.ShowMessage(message, color, canSkip)
	local skipEasyLegendaries = DataSyncClient.Get("Settings").SkipEasyLegendaries
	if skipEasyLegendaries and canSkip then
		return
	end
	hatchesChannel:DisplaySystemMessage(`<font color='{color}'>[Server]: {message}</font>`)
end

return ChatHandler
