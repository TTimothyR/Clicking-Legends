local u2 = { "K", "M", "B", "T", "Qd", "Qn", "Sx", "Sp", "O", "N", "De", "Ud", "Dd" }

local function FormatNumber(p1)
	if p1 < 50 then
		if p1 % 1 == 0 then
			return ("%i"):format(p1)
		else
			return ("%.1f"):format(p1)
		end
	end
	if p1 < 1000 then
		return ("%i"):format(p1)
	end

	local v1 = math.floor(math.log10(p1))
	local v2 = v1 % 3
	local v3
	if v2 == 0 then
		v3 = "%.2f"
	elseif v2 == 1 then
		v3 = "%.1f"
	else
		v3 = "%i"
	end

	return (v3 .. u2[math.floor(v1 / 3)]):format(p1 / 10 ^ (math.floor(v1 / 3) * 3))
end

return FormatNumber
