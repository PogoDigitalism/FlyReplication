--!strict

local Const = require(script.Parent.Parent.Const)
local Types = require(script.Parent.Parent.Types)

local dictionary: Types.TypeInterface = {}

-- dictionary doesnt append the elements
function dictionary.serialize(b: buffer, cursor: number, numKeys: number): number
    cursor = Const.WRITE_ENTRIES_LEN(b, cursor, numKeys)

    return cursor
end

function dictionary.deserialize(b: buffer, cursor: number): (number, number)
    local len: number
    len, cursor = Const.READ_ENTRIES_LEN(b, cursor)

    return len, cursor
end

function dictionary.size()
    return Const.ENTRIES_LEN_SIZE
end

return dictionary
