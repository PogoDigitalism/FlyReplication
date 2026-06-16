--!strict

local Const = require(script.Const)
local Typecheck = require(script.Parent.Typecheck)
local bool = require(script.serdes.bool)
local cframe = require(script.serdes.cframe)
local types = Typecheck.types
local list = require(script.serdes.list)
local numberBuf = require(script.serdes.number)
local color3 = require(script.serdes.color3)
local dictionary = require(script.serdes.dictionary)
local instance = require(script.serdes.instance)
local nothing = require(script.serdes.nothing)
local vector2 = require(script.serdes.vector2)
local vector3 = require(script.serdes.vector3)
local stringBuf = require(script.serdes.string)
local unbufferable = require(script.serdes.unbufferable)

local Buffer = {}

function Buffer.measureSize(typeSchema: any, data: any): number
	local size = 0

    if typeof(typeSchema) == "table" and not Typecheck.hasTag(typeSchema) then
		for k, valueSchema in typeSchema do
			if data[k] == nil and not Typecheck.isOptional(valueSchema) then
				error(`Key '{k}', does not have a value, but '{k}'' is required!`)
			end
            size += Buffer.measureSize(valueSchema, data[k], false)
        end
        return size
    end

    local isOr = Typecheck.isOr(typeSchema)
    if isOr then
        size = Const.TYPE_ID_SIZE
        typeSchema = Typecheck.inferSchema(data)
    end
	
    if typeSchema == types.Instance then
        size += instance.size(data)
    elseif typeSchema == types.number then
        size += numberBuf.size(data)
    elseif typeSchema == types.string then
        size += stringBuf.size(data)
    elseif typeSchema == types.bool then
        size += bool.size(data)
    elseif typeSchema == types.Vector2 then
        size += vector2.size(data)
    elseif typeSchema == types.Vector3 then
        size += vector3.size(data)
    elseif typeSchema == types.Color3 then
        size += color3.size(data)
    elseif typeSchema == types.CFrame then
        size += cframe.size(data)
    elseif Typecheck.isDictionary(typeSchema) then
        size += Const.ENTRIES_LEN_SIZE
        for k, v in data do
			--size += Const.FIELD_LEN_SIZE
			warn("MEASURE KEY SIZE")
            size += Buffer.measureSize(typeSchema.key, k)
			--size += Const.FIELD_LEN_SIZE
			warn("MEASURE NUM SIZE")
            size += Buffer.measureSize(typeSchema.value, v)
        end
    elseif Typecheck.isList(typeSchema) then
        local isOrV = Typecheck.isOr(typeSchema.value)
        size += list.size(data)
        if not isOrV then
            if #data > 0 then
                size += Buffer.measureSize(typeSchema.value, data[1]) * #data
            end
        else
            for _, element in data do
                size += Buffer.measureSize(typeSchema.value, element)
            end
        end
    else
        size += unbufferable.size(data)
    end

    return size
end

function Buffer.createBuffer(typeSchema: any, data: any): buffer
    local bufferSize = Buffer.measureSize(typeSchema, data)
    local b = buffer.create(bufferSize)

    return b
end

function Buffer.dumpData(typeSchema: any, data: any): (buffer, {Instance}?, {any}?)
    warn(typeSchema, data, 'DUMP')
    local b = Buffer.createBuffer(typeSchema, data)
    local instanceTable = {}
    local unbufferableTable = {}

    Buffer.fillBuffer(
        typeSchema,
        b,
        0,
        data,
        instanceTable, unbufferableTable,
        false
    )

    return b, if #instanceTable > 0 then instanceTable else nil, if #unbufferableTable > 0 then unbufferableTable else nil
end

local function writeTypeId(b, cursor, typeId: boolean | number)
    if not typeId then return cursor end

    return Const.WRITE_TYPE_ID(b, cursor, typeId :: number)
end

local schemaToId = {
    [types.number] = Const.number,
    [types.string] = Const.string,
	[types.nothing] = Const.nothing,
    [types.bool] = Const.bool,
    [types.Vector2] = Const.vector2,
    [types.Vector3] = Const.vector3,
    [types.Color3] = Const.color3,
    [types.CFrame] = Const.cframe,
    [types.Instance] = Const.instance,

	[types.any] = Const.unbufferable
}

function Buffer.fillBuffer(
    typeSchema: any, 
    b: buffer, 
    cursor: number, 
    data: any, 
    instanceTable: {Instance},
    unbufferableTable: {any}
): number
    -- parse structured tables
    print(typeSchema, data, cursor)
    if typeof(typeSchema) == "table" and not Typecheck.hasTag(typeSchema) then
        local keys = {}
        for k in typeSchema do
            if Typecheck.hasTag(k) then
                error("Mixing FlyReplication types with keys is not allowed!", 10)
            end
            table.insert(keys, k)
        end
        table.sort(keys)

        for _, key in keys do
            local valueSchema = typeSchema[key]
            cursor = Buffer.fillBuffer(valueSchema, b, cursor, data[key], instanceTable, unbufferableTable)
        end

        return cursor
    end

	local isOr = Typecheck.isOr(typeSchema)
	if isOr then
		typeSchema = Typecheck.inferSchema(data)
        print(typeSchema)
		local typeId = typeSchema and schemaToId[typeSchema] or Const.unbufferable
		cursor = Const.WRITE_TYPE_ID(b, cursor, typeId)
	end
	
    if typeSchema == types.Instance then
        table.insert(instanceTable, data)
        cursor = instance.serialize(b, cursor, #instanceTable)
    elseif typeSchema == types.number then
        cursor = numberBuf.serialize(b, cursor, data)
    elseif typeSchema == types.nothing then
        cursor = nothing.serialize(b, cursor, data)
    elseif typeSchema == types.string then
        cursor = stringBuf.serialize(b, cursor, data)
    elseif typeSchema == types.bool then
        cursor = bool.serialize(b, cursor, data)
    elseif typeSchema == types.Vector2 then
        cursor = vector2.serialize(b, cursor, data)
    elseif typeSchema == types.Vector3 then
        cursor = vector3.serialize(b, cursor, data)
    elseif typeSchema == types.Color3 then
        cursor = color3.serialize(b, cursor, data)
    elseif typeSchema == types.CFrame then
        cursor = cframe.serialize(b, cursor, data)
    elseif Typecheck.isDictionary(typeSchema) then
        local entriesLenCursor = cursor
        local numKeys = 0

        cursor = dictionary.serialize(b, cursor, 0) --overwrite later
        for k, v in data do
            numKeys += 1
            -- i later realised that we dont even need keylen + valuelen since the typeschema already + deserialize cursoring + num keys already does it
            -- take f.e. string as a key, typeschema already knows its a string and the string buffer entry contains len by itself, moves the cursor accordingly 
            cursor = Buffer.fillBuffer(typeSchema.key, b, cursor, k, instanceTable, unbufferableTable)
            cursor = Buffer.fillBuffer(typeSchema.value, b, cursor, v, instanceTable, unbufferableTable)

            -- local keyStart = cursor
            -- -- thus a key can be max 2^16 bytes
            -- cursor += Const.FIELD_LEN_SIZE

            -- -- isOr optimisation to not add type id per entry if the key type is one type
            -- local keyEnd = Buffer.fillBuffer(typeSchema.key, b, cursor, k, instanceTable, unbufferableTable, isOrK)
            -- Const.WRITE_FIELD_LEN(b, keyStart, keyEnd - cursor)
            -- cursor = keyEnd

            -- -- write value
            -- local valueStart = cursor
            -- -- thus a value can be max 2^16 bytes
            -- cursor += Const.FIELD_LEN_SIZE

            -- local valueEnd = Buffer.fillBuffer(typeSchema.value, b, cursor, v, instanceTable, unbufferableTable, isOrV)
            -- Const.WRITE_FIELD_LEN(b, valueStart, valueEnd - cursor)
            -- cursor = valueEnd
        end
        dictionary.serialize(b, entriesLenCursor, numKeys) --overwrite now
    elseif Typecheck.isList(typeSchema) then
        cursor = list.serialize(b, cursor, #data)
        
        for _, element in data do
            cursor = Buffer.fillBuffer(
                typeSchema.value, 
                b, 
                cursor, 
                element, 
                instanceTable,
                unbufferableTable
            )
        end
    else -- unbuferrable
        table.insert(unbufferableTable, data)
        cursor = unbufferable.serialize(b, cursor, #unbufferableTable)
    end

    return cursor
end

local idToSchema = {
    [Const.number] = types.number,
    [Const.string] = types.string,
    [Const.bool] = types.bool,
    [Const.nothing] = types.nothing,
    [Const.vector2] = types.Vector2,
    [Const.vector3] = types.Vector3,
    [Const.color3] = types.Color3,
	[Const.cframe] = types.CFrame,
	[Const.instance] = types.Instance
}

--TODO include isOr optimisation in dictionary deserialising
function Buffer.deconstructBuffer<T>(typeSchema: T, b: buffer, cursor: number, unbufferableTable: {any}?, instanceTable: {Instance}?): (T, number)
    -- parse structured tables
    if typeof(typeSchema) == "table" and not Typecheck.hasTag(typeSchema) then
        local keys = {}
        for k in typeSchema :: {[any]: any} do
            table.insert(keys, k)
        end
        table.sort(keys)

        local result = {}
        for _, key in keys do
            local valueSchema = typeSchema[key]
            result[key], cursor = Buffer.deconstructBuffer(valueSchema, b, cursor, unbufferableTable, instanceTable)
        end

        return result, cursor
    end

    local isOr = Typecheck.isOr(typeSchema)
    if isOr then
        -- if we entered an OR, we gotta resolve which type it actually is through type id
        -- this type id is at the cursor. We turn this into a type schema to parse it
        local typeId
        typeId, cursor = Const.READ_TYPE_ID(b, cursor)
        typeSchema = idToSchema[typeId] or types.any
        -- typeSchema OR gets replaced with the actual typeid
        -- TODO Instance keeps working, same with table and list, cant be an OR but i gotta rethink that
    end

    local result
    if typeSchema == types.number then
        result, cursor = numberBuf.deserialize(b, cursor)
    elseif typeSchema == types.string then
        result, cursor = stringBuf.deserialize(b, cursor)
    elseif typeSchema == types.nothing then
        result, cursor = nothing.deserialize(b, cursor)
    elseif typeSchema == types.bool then
        result, cursor = bool.deserialize(b, cursor)
    elseif typeSchema == types.Vector2 then
        result, cursor = vector2.deserialize(b, cursor)
    elseif typeSchema == types.Vector3 then
        result, cursor = vector3.deserialize(b, cursor)
    elseif typeSchema == types.Color3 then
        result, cursor = color3.deserialize(b, cursor)
    elseif typeSchema == types.CFrame then
        result, cursor = cframe.deserialize(b, cursor)
    elseif Typecheck.isDictionary(typeSchema) then
        local numKeys
        numKeys, cursor = Const.READ_ENTRIES_LEN(b, cursor)

        result = {}
        for i = 1, numKeys do
            -- local keyLen
            -- keyLen, cursor = Const.READ_FIELD_LEN(b, cursor)
            local k
            k, cursor = Buffer.deconstructBuffer(typeSchema.key, b, cursor, unbufferableTable, instanceTable)

            -- local valueLen
            -- valueLen, cursor = Const.READ_FIELD_LEN(b, cursor)
            local v
            v, cursor = Buffer.deconstructBuffer(typeSchema.value, b, cursor, unbufferableTable, instanceTable)

            result[k] = v
        end
    elseif Typecheck.isList(typeSchema) then
        local numElements
        numElements, cursor = list.deserialize(b, cursor)

        result = {}
        for i = 1, numElements do
            result[i], cursor = Buffer.deconstructBuffer(typeSchema.value, b, cursor, unbufferableTable, instanceTable)
        end
    elseif typeSchema == types.Instance then
        local index
        index, cursor = instance.deserialize(b, cursor)
        result = instanceTable and instanceTable[index]
    else -- unbufferable
        local index
        index, cursor = unbufferable.deserialize(b, cursor)
        result = unbufferableTable and unbufferableTable[index]
    end

    return result, cursor
end

return Buffer
