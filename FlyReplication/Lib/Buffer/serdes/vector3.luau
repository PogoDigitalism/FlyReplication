--!strict
local Const = require(script.Parent.Parent.Const)
local Types = require(script.Parent.Parent.Types)
local num = require(script.Parent.number)

local vector3: Types.TypeInterface = {}

-- we let num decide what the smallest possible number can be
-- for any coords i suspect it will be f64 as i dont have f16,f32 added yet

function vector3.serialize(b: buffer, cursor: number, data: Vector3): number
    cursor = num.serialize(b, cursor, data.X)
    cursor = num.serialize(b, cursor, data.Y)
    cursor = num.serialize(b, cursor, data.Z)

    return cursor
end

function vector3.deserialize(b: buffer, cursor: number): (Vector3, number)
    local x: number, y: number, z: number
    x, cursor = num.deserialize(b, cursor)
    y, cursor = num.deserialize(b, cursor)
    z, cursor = num.deserialize(b, cursor)

    return Vector3.new(x, y, z), cursor
end

function vector3.size(data: Vector3): number
    return num.size(data.X) + num.size(data.Y) + num.size(data.Z)
end

return vector3
