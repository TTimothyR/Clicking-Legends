local ChatHandler = {}

local tcs = game:GetService("TextChatService")

local channels = tcs:WaitForChild("TextChannels")
local hatchesChannel = channels:WaitForChild("Hatches") :: TextChannel

function ChatHandler.ShowMessage(message, color)
	hatchesChannel:DisplaySystemMessage(`<font color='{color}'>[Server]: {message}</font>`)
end

return ChatHandler
