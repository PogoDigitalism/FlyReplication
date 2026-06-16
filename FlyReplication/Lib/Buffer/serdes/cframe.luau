--!strict
local Const = require(script.Parent.Parent.Const)
local Types = require(script.Parent.Parent.Types)
local num = require(script.Parent.number)

local CFRAME_TYPE_SIZE = 1

local cframe: Types.TypeInterface = {}

function cframe.serialize(b: buffer, cursor: number, data: CFrame): number
    local axis, angle = data:ToAxisAngle()
    local isSimple = angle == 0

    local cframeType: number
    if isSimple then
        cframeType = Const.cframeSimple
    else
        cframeType = Const.cframe
    end
    buffer.writeu8(b, cursor, cframeType)
    cursor += CFRAME_TYPE_SIZE

    -- position
    cursor = num.serialize(b, cursor, data.X)
    cursor = num.serialize(b, cursor, data.Y)
    cursor = num.serialize(b, cursor, data.Z)

    -- rotation
    if not isSimple then
        cursor = num.serialize(b, cursor, axis.X)
        cursor = num.serialize(b, cursor, axis.Y)
        cursor = num.serialize(b, cursor, axis.Z)
        cursor = num.serialize(b, cursor, angle)
    end

    return cursor
end

function cframe.deserialize(b: buffer, cursor: number): (CFrame, number)
    local cframeType = buffer.readu8(b, cursor)
    cursor += CFRAME_TYPE_SIZE

    local x, y, z
    x, cursor = num.deserialize(b, cursor)
    y, cursor = num.deserialize(b, cursor)
    z, cursor = num.deserialize(b, cursor)

    local base = CFrame.new(x, y, z)
    if cframeType == Const.cframeSimple then
        return base, cursor
    else
        local ax, ay, az, angle
        ax, cursor = num.deserialize(b, cursor)
        ay, cursor = num.deserialize(b, cursor)
        az, cursor = num.deserialize(b, cursor)
        angle, cursor = num.deserialize(b, cursor)

        local axis = Vector3.new(ax, ay, az)
        return base * CFrame.fromAxisAngle(axis, angle), cursor
    end
end

function cframe.size(data: CFrame): number
    local axis, angle = data:ToAxisAngle()

    local posSize = num.size(data.X) + num.size(data.Y) + num.size(data.Z)
    if angle == 0 then
        return CFRAME_TYPE_SIZE + posSize
    else
        local rotSize = num.size(axis.X) + num.size(axis.Y) + num.size(axis.Z) + num.size(angle)
        return CFRAME_TYPE_SIZE + posSize + rotSize + num.size(angle)
    end
end

return cframe
