--!strict
local Const = require(script.Parent.Parent.Const)
local Types = require(script.Parent.Parent.Types)

local num: Types.TypeInterface = {}

local SIGNED_BIT = 0b1000_0000
local UNSIGNED_BIT = 0b0000_0000

local function uintSerialize(b: buffer, cursor: number, data: number): number
    if data <= 255 then
		cursor = Const.WRITE_NUM_TYPE(b, cursor, Const.uint8)
        buffer.writeu8(b, cursor, data)
        cursor += 1
    elseif data <= 65_535 then
		cursor = Const.WRITE_NUM_TYPE(b, cursor, Const.uint16)
        buffer.writeu16(b, cursor, data)
        cursor += 2
    elseif data <= 4_294_967_295 then
		cursor = Const.WRITE_NUM_TYPE(b, cursor, Const.uint32)
        buffer.writeu32(b, cursor, data)
        cursor += 4
    else
        -- f64 fallback for large floats or values beyond u32
		cursor = Const.WRITE_NUM_TYPE(b, cursor, Const.f64)
        buffer.writef64(b, cursor, data)
        cursor += 8
    end

    return cursor
end
local function intSerialize(b: buffer, cursor: number, data: number): number
    if -128 <= data and data <= 127 then
        cursor = Const.WRITE_NUM_TYPE(b, cursor, Const.uint8)
        buffer.writei8(b, cursor, data)
        cursor += 1
    elseif -32_768 <= data and data <= 32_767 then
		cursor = Const.WRITE_NUM_TYPE(b, cursor, Const.uint16)
        buffer.writei16(b, cursor, data)
        cursor += 2
    elseif -2_147_483_648 <= data and data <= 2_147_483_647 then
		cursor = Const.WRITE_NUM_TYPE(b, cursor, Const.uint32)
        buffer.writei32(b, cursor, data)
        cursor += 4
    else
        -- f64 fallback for large floats or values beyond u32
		cursor = Const.WRITE_NUM_TYPE(b, cursor, Const.int16)
        buffer.writef64(b, cursor, data)
        cursor += 8
    end

    return cursor
end
local function floatSerialize(b: buffer, cursor: number, data: number): number
	if Const.FORCE_F64_FLOATS then
		cursor = Const.WRITE_NUM_TYPE(b, cursor, Const.f64)
		buffer.writef64(b, cursor, data)
		cursor += 8
		
		return cursor
	end
	
    local signed = data < 0
    local absd = math.abs(data)
    if 0 < absd and absd < 1 then -- apply f8
        local decimalPart = math.round((absd % 1) * 10^2)
        local signBit = signed and SIGNED_BIT or UNSIGNED_BIT
        local final = bit32.bor(signBit, decimalPart)

		cursor = Const.WRITE_NUM_TYPE(b, cursor, Const.f8)
        buffer.writeu8(b, cursor, final)
		cursor += 1
    else -- go for f32
        cursor = Const.WRITE_NUM_TYPE(b, cursor, Const.f32)
		buffer.writef32(b, cursor, data)
		cursor += 4
    end

    return cursor
end

local function uintDeserialize(b: buffer, cursor: number, typeId: number): (number, number)
    local result: number
    if typeId == Const.uint8 then 
        result = buffer.readu8(b, cursor)
        cursor += 1
    elseif typeId == Const.uint16 then
        result = buffer.readu16(b, cursor)
        cursor += 2
    elseif typeId == Const.uint32 then
        result = buffer.readu32(b, cursor)
        cursor += 4
    end

    return result, cursor
end
local function intDeserialize(b: buffer, cursor: number, typeId: number): (number, number)
    local result: number
    if typeId == Const.int8 then 
        result = buffer.readi8(b, cursor)
        cursor += 1
    elseif typeId == Const.int16 then
        result = buffer.readi16(b, cursor)
        cursor += 2
    elseif typeId == Const.int32 then
        result = buffer.readi32(b, cursor)
        cursor += 4
    end

    return result, cursor
end
local SIGN_MASK = 0b1000_0000
local NO_SIGN_MASK = 0b0111_1111
local function floatDeserialize(b: buffer, cursor: number, typeId: number): (number, number)
    local result: number
    if typeId == Const.f8 then
        local raw = buffer.readu8(b, cursor)
        cursor += 1
    
        local sign = bit32.band(raw, SIGN_MASK) ~= 0 and -1 or 1
        local final = bit32.band(raw, NO_SIGN_MASK)
        result = (final / 10^2) * sign
    elseif typeId == Const.f64 then
        result = buffer.readf64(b, cursor)
        cursor += 8
    end

    return result, cursor
end

function num.serialize(b: buffer, cursor: number, data: number): number
    local isInteger = data % 1 == 0
    local signed = data < 0

    if isInteger then
        if not signed then
            cursor = uintSerialize(b, cursor, data)
        else
            cursor = intSerialize(b, cursor, data)
        end

        return cursor
    else -- is fraction
        return floatSerialize(b, cursor, data)
    end
end

function num.deserialize(b: buffer, cursor: number): (number, number)
    local typeId: number
    typeId, cursor = Const.READ_NUM_TYPE(b, cursor)

    local result: number
    if typeId == Const.uint8 or typeId == Const.uint16 or typeId == Const.uint32 then
        result, cursor = uintDeserialize(b, cursor, typeId)
    elseif typeId == Const.int8 or typeId == Const.int16 or typeId == Const.int32 then
        result, cursor = intDeserialize(b, cursor, typeId)
	elseif typeId == Const.f8 or typeId == Const.f64 then
        result, cursor = floatDeserialize(b, cursor, typeId)
    else
        error(`{typeId} is not supported by the number deserializer`)
    end

    return result, cursor
end

function num.size(data: any): number
    local isInteger = data % 1 == 0
    local signed = data < 0
    local size = 0

    if isInteger then
        if not signed then
            if data <= 255 then
                size = 1
            elseif data <= 65_535 then
                size = 2
            elseif data <= 4_294_967_295 then
                size = 4
            else
                size = 8
            end
        else
            if -128 <= data and data <= 127 then
                size = 1
            elseif -32_768 <= data and data <= 32_767 then
                size = 2
            elseif -2_147_483_648 <= data and data <= 2_147_483_647 then
                size = 4
            else
                size = 8
            end
        end
    else
        if 0 < data and data < 1 then 
            size = 1
        else
            size = 8
        end
    end

    return Const.TYPE_ID_SIZE + size
end

return num
