local DiscordManager = {
	WebhookCache = {},
}
local HttpService = game:GetService("HttpService")

function DiscordManager:GetWebhook(Type)
	local WebhookIDs = script:FindFirstChild("WebhookIDs")
	if self.WebhookCache[Type] then
		return self.WebhookCache[Type]
	end
	for _, Hook in pairs(WebhookIDs:GetChildren()) do
		if Hook.Name == string.format("%s/Webhook", Type) then
			self.WebhookCache[Type] = require(Hook)
			return self.WebhookCache[Type]
		end
	end
	return
end
local function GetProxyURL(ImageType, ImageID)
	local ProxyTemplates = {
		Asset = "https://thumbnails.roproxy.com/v1/assets?assetIds=%d&size=420x420&format=Png&isCircular=false",
		Player = "https://thumbnails.roproxy.com/v1/users/avatar-headshot?userIds=%d&size=420x420&format=Png&isCircular=false",
	}
	local Template = ProxyTemplates[ImageType]
	if Template then
		local URL = Template:format(ImageID)
		local Success, Response = pcall(function()
			return HttpService:GetAsync(URL)
		end)
		if Success then
			local Data = HttpService:JSONDecode(Response)
			return Data.data[1].imageUrl
		end
	end
	return nil
end
function DiscordManager:Send(...)
	local Webhook = unpack({ ... })
	local WebhookURL = self:GetWebhook(Webhook.Type)

	if not WebhookURL then
		warn(("Webhook does not exist: %s"):format(Webhook.Type))
		return
	end
	local ImageURL = GetProxyURL(Webhook.ImageType, Webhook.ImageID)
	if not ImageURL then
		warn("Failed to retrieve image for webhook.")
		return
	end
	local EmbedInfo = {
		["content"] = Webhook.Content,
		["embeds"] = {
			{
				["author"] = {
					["name"] = Webhook.Author,
				},
				["title"] = Webhook.Title,
				["color"] = Webhook.Color,
				["description"] = Webhook.Description,
				["thumbnail"] = {
					["url"] = ImageURL,
				},
				["fields"] = {
					{
						["name"] = Webhook.Field and Webhook.Field[1] or "",
						["value"] = Webhook.Field and Webhook.Field[2] or "",
						["inline"] = true,
					},
				},
				["timestamp"] = DateTime.now():ToIsoDate(),
			},
		},
	}
	local JsonData = HttpService:JSONEncode(EmbedInfo)
	local MaxRetries = 3
	local Attempt = 0
	local Success, ErrorMessage

	repeat
		Attempt = Attempt + 1
		Success, ErrorMessage = pcall(function()
			HttpService:PostAsync(WebhookURL, JsonData)
		end)
		if not Success then
			warn(("Failed to send webhook (Attempt %d/%d): %s"):format(Attempt, MaxRetries, ErrorMessage))
			if Attempt < MaxRetries then
				task.wait(2)
			end
		end
	until Success or Attempt >= MaxRetries

	if not Success then
		warn("Webhook sending ultimately failed after 3 attempts.")
	end
end
return DiscordManager
