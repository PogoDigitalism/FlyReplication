--!strict

local Const = require(script.Parent.Parent.Const)
local Types = require(script.Parent.Parent.Types)

local list: Types.TypeInterface = {}

-- list doesnt append the elements
function list.serialize(b: buffer, cursor: number, len: number): number
    cursor = Const.WRITE_ENTRIES_LEN(b, cursor, len)
    
    return cursor
end

function list.deserialize(b: buffer, cursor: number): (number, number)
    local len: number
    len, cursor = Const.READ_ENTRIES_LEN(b, cursor)

    return len, cursor
end

function list.size()
    return Const.ENTRIES_LEN_SIZE
end

return list
