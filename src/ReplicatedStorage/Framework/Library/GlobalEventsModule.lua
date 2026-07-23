local GlobalEvents = {
	Events = {
		["LuckEvent"] = {
			Multi = 1.5,
			LookupID = 3608446486,
		},
		["ClicksEvent"] = {
			Multi = 2,
			LookupID = 3608446486,
		},
	},
}

function GlobalEvents.IsActive(EventName)
	local Attribute = workspace:GetAttribute(EventName)
	if Attribute and Attribute >= os.time() then
		return true
	end
	return false
end

function GlobalEvents.GetMulti(EventName)
	local Attribute = workspace:GetAttribute(EventName)
	if Attribute and Attribute >= os.time() then
		return GlobalEvents.Events[EventName].Multi
	end
	return 1
end

return GlobalEvents
