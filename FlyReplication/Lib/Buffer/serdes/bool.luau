--!strict
local Const = require(script.Parent.Parent.Const)
local Types = require(script.Parent.Parent.Types)

local BOOL_SIZE = 1
local bool: Types.TypeInterface = {}

function bool.serialize(b: buffer, cursor: number, data: boolean): number
    buffer.writeu8(b, cursor, data and 1 or 0)
    cursor += 1

    return cursor
end

function bool.deserialize(b: buffer, cursor: number): (boolean, number)
    local data = buffer.readu8(b, cursor)
    cursor += 1

    local result = data == 1
    return result, cursor
end

function bool.size(data: boolean)
    return BOOL_SIZE
end

return bool
