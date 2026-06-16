local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(script.Parent.Parent.Types)

local SEPERATOR = "."

local Keypath = {}

function Keypath.parsePath(key: Types.StrPath?): Types.ParsedPath
	if key == "" then
		return {}
	end
	
    local t = {}
	
	for _, subKey in tostring(key):split(SEPERATOR) do
		subKey = tonumber(subKey) or subKey
        table.insert(t, subKey)
    end
    
	return t
end

function Keypath.getValue(data: any, parsedPath: Types.ParsedPath): any?
    local current = data
	for i = 1, #parsedPath, 1 do
		local key = parsedPath[i]
		if typeof(current) ~= "table" then
			error("Trying to index a non-table type with key: "..key)
            -- throw error
            return nil
		end
		
		current = current[key]
		--[[
		this clause is here to make sure people dont index like self.Path["6"].foo when trying to get the 6'th index of a list. Serializing back to a number is not done by Roblox, hence why this has been added to support indexes for replication.
		
		This allows for conistent cross-context Set and Get behavior of lists (f.e. self.Path[6].foo)
		--]]
		if i < #parsedPath and not current and tonumber(key) and typeof(key) == "string" then
			error("Indexing with key: \""..key.."\" returned a nil value, did you mean "..key.." index as a number?")
		end
    end
    return current
end

function Keypath.setNestedValue(data: any, parsedPath: Types.ParsedPath, value: any): boolean
    for i = 1, #parsedPath - 1, 1 do
		local key = parsedPath[i]
		key = tonumber(key) or key

		if typeof(data) ~= "table" then
			error("Trying to access non-table type with key '" .. key .. "' (full path: '" .. table.concat(parsedPath, ".") .. "')")
		end
		
		if data[key] == nil then
			data[key] = {}
		end
		data = data[key]
    end

	local finalKey = parsedPath[#parsedPath]
	local oldValue = data[finalKey]
    if oldValue == value then
        return false
    end
	
	data[finalKey] = value
	
    return true
end

return Keypath
