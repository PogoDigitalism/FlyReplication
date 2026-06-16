--!strict
local Const = require(script.Parent.Parent.Const)
local Types = require(script.Parent.Parent.Types)

local instance: Types.TypeInterface = {}

function instance.serialize(b: buffer, cursor: number, index: number): number
    buffer.writeu16(b, cursor, index)
    cursor += Const.INSTANCE_INDEX_SIZE

    return cursor
end

function instance.deserialize(b: buffer, cursor: number): (number, number)
    local index = buffer.readu16(b, cursor)
    cursor += Const.INSTANCE_INDEX_SIZE
    
    return index, cursor
end

function instance.size(data: boolean)
    return Const.INSTANCE_INDEX_SIZE
end

return instance
