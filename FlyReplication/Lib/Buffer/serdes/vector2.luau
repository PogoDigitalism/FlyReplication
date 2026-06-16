--!strict
local Const = require(script.Parent.Parent.Const)
local Types = require(script.Parent.Parent.Types)
local num = require(script.Parent.number)

local vector2: Types.TypeInterface = {}

function vector2.serialize(b: buffer, cursor: number, data: Vector2): number
    cursor = num.serialize(b, cursor, data.X)
    cursor = num.serialize(b, cursor, data.Y)

    return cursor
end

function vector2.deserialize(b: buffer, cursor: number): (Vector2, number)
    local x: number, y: number
    x, cursor = num.deserialize(b, cursor)
    y, cursor = num.deserialize(b, cursor)

    return Vector2.new(x, y), cursor
end

function vector2.size(data: Vector2): number
    return num.size(data.X) + num.size(data.Y)
end

return vector2
