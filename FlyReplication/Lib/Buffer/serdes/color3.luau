--!strict
local Types = require(script.Parent.Parent.Types)
local num = require(script.Parent.number)

local color3: Types.TypeInterface = {}

function color3.serialize(b: buffer, cursor: number, color: Color3): number
    cursor = num.serialize(b, cursor, color.R)
    cursor = num.serialize(b, cursor, color.G)
    cursor = num.serialize(b, cursor, color.B)

    return cursor
end

function color3.deserialize(b: buffer, cursor: number): (Color3, number)
    local r: number, g: number, b_: number
    r, cursor = num.deserialize(b, cursor)
    g, cursor = num.deserialize(b, cursor)
    b_, cursor = num.deserialize(b, cursor)

    return Color3.new(r, g, b_), cursor
end

function color3.size(data: Color3): number
    return num.size(data.R) + num.size(data.G) + num.size(data.B)
end

return color3
