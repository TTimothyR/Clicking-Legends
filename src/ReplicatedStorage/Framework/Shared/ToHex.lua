local ToInteger = require("./ToInteger")

return function(color)
	local int = ToInteger(color)

	local current = int
	local final = ""

	local hexChar = {
		"A",
		"B",
		"C",
		"D",
		"E",
		"F",
	}

	repeat
		local remainder = current % 16
		local char = tostring(remainder)

		if remainder >= 10 then
			char = hexChar[1 + remainder - 10]
		end

		current = math.floor(current / 16)
		final = final .. char
	until current <= 0

	return "#" .. string.reverse(final)
end
