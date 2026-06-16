--!strict

local Const = require(script.Parent.Parent.Const)
local Types = require(script.Parent.Parent.Types)

local unbufferable: Types.TypeInterface = {}

function unbufferable.serialize(b: buffer, cursor: number, index: number): number
	buffer.writeu16(b, cursor, index)
	cursor += Const.UNBUFFERABLE_INDEX_SIZE

	return cursor
end

function unbufferable.deserialize(b: buffer, cursor: number): (number, number)
	local index = buffer.readu16(b, cursor)
	cursor += Const.UNBUFFERABLE_INDEX_SIZE

	return index, cursor
end

function unbufferable.size(data: any)
	return Const.UNBUFFERABLE_INDEX_SIZE
end


return unbufferable
