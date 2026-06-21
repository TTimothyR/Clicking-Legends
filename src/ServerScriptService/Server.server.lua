local players = game:GetService("Players")

for _, plr: Player in pairs(players:GetPlayers()) do
	local equip: Folder = Instance.new("Folder")
	equip.Parent = workspace.EquippedPets
	equip.Name = plr.Name
end

players.PlayerAdded:Connect(function(plr: Player)
	local equip: Folder = Instance.new("Folder")
	equip.Parent = workspace.EquippedPets
	equip.Name = plr.Name
end)

players.PlayerRemoving:Connect(function(plr: Player)
	if workspace.EquippedPets:FindFirstChild(plr.Name) then
		workspace.EquippedPets:FindFirstChild(plr.Name):Destroy()
	end
end)
