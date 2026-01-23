local Utility = {};

function Utility.WaitForAttribute(object, name)
    repeat
        task.wait();
    until object:GetAttribute(name) ~= nil;

    return object:GetAttribute(name);
end

return Utility;