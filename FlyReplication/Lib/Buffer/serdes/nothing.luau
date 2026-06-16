--!strict
local Const = require(script.Parent.Parent.Const)
local Types = require(script.Parent.Parent.Types)

local nothing_SIZE = 1
local nothing: Types.TypeInterface = {}

function nothing.serialize(b: buffer, cursor: number, data: nil): number
    return cursor
end

function nothing.deserialize(b: buffer, cursor: number): (nil, number)
    return nil, cursor
end

function nothing.size(data: nil)
    return 0
end

return nothing
