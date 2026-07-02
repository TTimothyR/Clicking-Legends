local tbl = {
	I = 1,
	II = 2,
	III = 3,
	IV = 4,
	V = 5,
	VI = 6,
	VII = 7,
	VIII = 8,
	IX = 9,
	X = 10,
	XI = 11,
	XII = 12,
	XIII = 13,
	XIV = 14,
	XV = 15,
	XVI = 16,
	XVII = 17,
	XVIII = 18,
}

return function(romanNumber)
	if tbl[romanNumber] then
		return tbl[romanNumber]
	end
	return 1
end
