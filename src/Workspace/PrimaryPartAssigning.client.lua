local folder: Folder = workspace:WaitForChild('AssignPrimaryParts');


for _, model: Model in ipairs(folder:GetChildren()) do
    if model.PrimaryPart then
        model.PrimaryPart:Destroy();
    end

    local center, size = model:GetBoundingBox();

    local new: Part = Instance.new('Part', model);
    new.Name = 'Primary';
    new.Size = Vector3.new(size.X, 0.05, size.Z);
    new.CFrame = center;
    new.Transparency = 1;
    new.CanCollide = false;
    new.Anchored = true;

    model.PrimaryPart = new;

    for _, child in ipairs(model:GetDescendants()) do
        if child:IsA('BasePart') then
            child.CanCollide = false;
            child.Anchored = true;
        end
    end

    print('Successfully configured', model.Name);
end