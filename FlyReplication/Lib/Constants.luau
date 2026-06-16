local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = {}

if RunService:IsServer() then
    local FOLDER = Instance.new("Folder")
    FOLDER.Name = "_FlyReplication"
    FOLDER.Parent = ReplicatedStorage

    Constants.FOLDER = FOLDER
elseif RunService:IsClient() then
    local FOLDER = ReplicatedStorage:WaitForChild("_FlyReplication")
    Constants.FOLDER = FOLDER
end

Constants.ROOT_KEY = ""
Constants.ROOT_PATH = {}

return Constants
