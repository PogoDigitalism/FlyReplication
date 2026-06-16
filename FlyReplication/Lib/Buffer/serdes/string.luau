--!strict
local Const = require(script.Parent.Parent.Const)
local Types = require(script.Parent.Parent.Types)

local str: Types.TypeInterface = {}

function str.serialize(b: buffer, cursor: number, data: any): number
    local len = #data

    cursor = Const.WRITE_FIELD_LEN(b, cursor, len)
    buffer.writestring(b, cursor, data)
    cursor += len

    return cursor
end

function str.deserialize(b: buffer, cursor: number): (string, number)
    local len: number
    len, cursor = Const.READ_FIELD_LEN(b, cursor)
    local data = buffer.readstring(b, cursor, len)
    cursor += len

    return data, cursor
end

function str.size(data: any)
    return Const.FIELD_LEN_SIZE + #data
end

return str
