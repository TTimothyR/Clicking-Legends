local HttpService = game:GetService("HttpService")
local LogHandler = {}

local WEBHOOK_URLS: { [string]: string } = {
	Trade = "https://discord.com/api/webhooks/1529800840733524018/bbReFQZdJu0pSEJtFQngMR5ppqpyWEhvIcdKw2q-XhDTUF6-kc_OjRCIHHBmarTFWtCf", -- e.g. "https://discord.com/api/webhooks/XXXX/XXXX"
	Purchase = "https://discord.com/api/webhooks/1529802053835292684/NmfQcMX73tqNTBMr_O6ZY-5_HKTWEV9ldUQLmWhZX0as_anctXCjQVdnVmOMZFYpcdhT",
	Dupe = "https://discord.com/api/webhooks/1529802678459433030/s2uaA02MK_TXIz4SFwXLrpFTu6qt7MRD3woQn8MU4z5YetOYD5XCe1WOqXkwDNkzdu-1",
}

local EMBED_COLORS: { [string]: number } = {
	Trade = 0x2ECC71, -- green
	Purchase = 0x3498DB, -- blue
	Dupe = 0xE74C3C, -- red
	Default = 0x7F8C8D, -- grey
}
local MAX_FIELD_LENGTH = 1024

local function PostToDiscord(webhookUrl: string, payload: { [string]: any }): boolean
	if not webhookUrl or webhookUrl == "" then
		warn("[WebhookLogger] No webhook URL configured for this log type.")
		return false
	end

	local encodeSuccess, jsonOrErr = pcall(HttpService.JSONEncode, HttpService, payload)
	if not encodeSuccess then
		warn("[WebhookLogger] Failed to encode payload:", jsonOrErr)
		return false
	end

	local success, err = pcall(function()
		HttpService:PostAsync(webhookUrl, jsonOrErr, Enum.HttpContentType.ApplicationJson)
	end)

	if not success then
		warn("[WebhookLogger] Failed to send webhook:", err)
	end

	return success
end

local function BuildOfferText(pets: { [string]: any }, gifts: { [string]: any }): string
	local lines = {}

	for _, petData in pairs(pets) do
		local petName = (petData and petData.fullName) or "Unknown Pet"
		table.insert(lines, string.format("• 🐾 %s", petName))
	end

	for _, gamepassName in pairs(gifts) do
		table.insert(lines, string.format("• 🎁 %s", tostring(gamepassName)))
	end

	if #lines == 0 then
		return "Nothing"
	end

	local text = table.concat(lines, "\n")
	if #text > MAX_FIELD_LENGTH then
		text = text:sub(1, MAX_FIELD_LENGTH - 3) .. "..."
	end

	return text
end

export type EmbedField = {
	name: string,
	value: string,
	inline: boolean?,
}

export type EmbedOptions = {
	description: string?,
	color: number?,
	footer: string?,
	thumbnail: string?,
	author: { name: string, icon_url: string? }?,
}

function LogHandler.SendEmbed(logType: string, title: string, fields: { EmbedField }?, options: EmbedOptions): boolean
	options = options or {}

	local webhookUrl = WEBHOOK_URLS[logType]
	local color = options.color or EMBED_COLORS[logType] or EMBED_COLORS.Default

	local embed: { [string]: any } = {
		title = title,
		color = color,
		fields = fields or {},
		timestamp = DateTime.now():ToIsoDate(),
	}

	if options.description then
		embed.description = options.description
	end
	if options.footer then
		embed.footer = { text = options.footer }
	end
	if options.thumbnail then
		embed.thumbnail = { url = options.thumbnail }
	end
	if options.author then
		embed.author = options.author
	end

	return PostToDiscord(webhookUrl, { embeds = { embed } })
end

export type TradeOffer = {
	Pets: { [string]: any },
	Gifts: { [string]: any },
}

function LogHandler.LogTrade(player1: Player, player2: Player, offerFrom1: TradeOffer, offerFrom2: TradeOffer)
	local fields = {
		{
			name = string.format("%s gave", player1.Name),
			value = BuildOfferText(offerFrom1.Pets, offerFrom1.Gifts),
			inline = true,
		},
		{
			name = string.format("%s gave", player2.Name),
			value = BuildOfferText(offerFrom2.Pets, offerFrom2.Gifts),
			inline = true,
		},
	}
	return LogHandler.SendEmbed("Trade", "Trade Completed", fields, {
		description = string.format("**%s** ↔ **%s**", player1.Name, player2.Name),
		footer = string.format("UserIds: %d / %d", player1.UserId, player2.UserId),
	})
end

function LogHandler.LogPurchase(player: Player, itemName: string, purchaseType: string, robuxPrice: number?)
	local fields = {
		{ name = "Player", value = string.format("%s (%d)", player.Name, player.UserId), inline = true },
		{ name = "Item", value = itemName, inline = true },
		{ name = "Type", value = purchaseType, inline = true },
	}

	if robuxPrice then
		table.insert(fields, { name = "Price", value = string.format("R$ %d", robuxPrice), inline = true })
	end

	return LogHandler.SendEmbed("Purchase", "Purchase Completed", fields, {
		footer = string.format("UserId: %d", player.UserId),
	})
end

function LogHandler.LogDupe(involvedPlayers: { Player }, duplicateIds: { string }, scanType: string): boolean
	local playerLines = {}
	for _, plr in ipairs(involvedPlayers) do
		table.insert(playerLines, string.format("• %s (%d)", plr.Name, plr.UserId))
	end

	local playerText = #playerLines > 0 and table.concat(playerLines, "\n") or "Unknown"
	local idText = #duplicateIds > 0 and table.concat(duplicateIds, ", ") or "Unknown"

	if #idText > MAX_FIELD_LENGTH then
		idText = idText:sub(1, MAX_FIELD_LENGTH - 3) .. "..."
	end

	local fields = {
		{ name = "Scan Type", value = scanType, inline = true },
		{ name = "Players Involved", value = playerText, inline = false },
		{ name = "Duplicated Pet Id(s)", value = idText, inline = false },
	}

	return LogHandler.SendEmbed("Dupe", "Dupe Detected", fields, {
		description = "One or more players were flagged/banned for duplicate pets.",
	})
end

return LogHandler
