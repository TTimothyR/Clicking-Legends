local ChatHandler = {}

local tcs = game:GetService("TextChatService")

local channel: TextChannel = tcs:WaitForChild("TextChannels").RBXGeneral

function ChatHandler.ShowMessage(message: string)
	channel:DisplaySystemMessage(message)
end

return ChatHandler
