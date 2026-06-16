local Const = {}

-- in case f<32 is causing floating point precision errors, enable this
-- applies to ALL non-integer numbers
Const.FORCE_F64_FLOATS = false

-- collection of macros for convenience
Const.FIELD_LEN_SIZE = 2 -- capped at u16, no field should have more than 32k entries (except list/dict)
Const.ENTRIES_LEN_SIZE = 4 -- capped at u32, 4+ mil entries
Const.INSTANCE_INDEX_SIZE = 2
Const.UNBUFFERABLE_INDEX_SIZE = 2
Const.TYPE_ID_SIZE = 1
Const.WRITE_FIELD_LEN = function(b: buffer, cursor: number, len: number): number
	buffer.writeu16(b, cursor, len)
	return cursor+Const.FIELD_LEN_SIZE
end
Const.WRITE_ENTRIES_LEN = function(b: buffer, cursor: number, len: number): number
	buffer.writeu32(b, cursor, len)
	return cursor+Const.ENTRIES_LEN_SIZE
end
Const.WRITE_TYPE_ID = function(b: buffer, cursor: number, id: number): number
	buffer.writeu8(b, cursor, id)
	return cursor+Const.TYPE_ID_SIZE
end
Const.WRITE_NUM_TYPE = Const.WRITE_TYPE_ID
Const.READ_FIELD_LEN = function(b: buffer, cursor: number): (number, number)
	local len = buffer.readu16(b, cursor)
	return len, cursor+Const.FIELD_LEN_SIZE
end
Const.READ_ENTRIES_LEN = function(b: buffer, cursor: number): (number, number)
	local len = buffer.readu32(b, cursor)
	return len, cursor+Const.ENTRIES_LEN_SIZE
end
Const.READ_TYPE_ID = function(b: buffer, cursor: number): (number, number)
	local typeId = buffer.readu8(b, cursor)
	return typeId, cursor+Const.TYPE_ID_SIZE
end
Const.READ_NUM_TYPE = Const.READ_TYPE_ID

-- type id consts
Const.instance = 0
Const.string = 1

Const.number = 2
-- number subtypes
Const.int8 = 20
Const.int16 = 21
Const.int32 = 22
Const.uint8 = 23
Const.uint16 = 24
Const.uint32 = 25
Const.f8 = 26 --[[ only applies to -1 < x < 1 at 2 decimal precision, 
-- first bit is sign bit, the other 7 bits are for precision 0<f<1 ()
]]
Const.f16 = 27
Const.f32 = 28
Const.f64 = 29

Const.bool = 3
Const.nothing = 4

Const.table = 5
Const.list = 6

Const.cframe = 70
Const.cframeSimple = 71
Const.vector3 = 8
Const.vector2 = 9
Const.color3 = 10
Const.udim2 = 11

-- for things like ColorSequence
Const.unbufferable = 255

return Const

--[[
	type structs: {[offset, semantic_name, size]}

	instance: {[0, instance_index, 2]},
	string: {[0, len, 2], [2, content, x]}
	number: {[0, num_type, 1], [1, number_content, 1-8]}
	bool: {[0, bool_value, 1]}
	nothing: {}
	table: {[0, entries_len, 4], 
			[4, key_len, 6],
			[6, key_content, x],
			[6+x, value_len, 2],
			[6+x+2, value_content, y]}
	list: {[0, entries_len, 4],
			[4, entries, x*entries_len]}
	cframe: {
			[0, cframe_type, 1],
			[1, x, q],
			[q, y, w],
			[w, z, e],

			[e, xa, r],
			[r, ya, t],
			[t, za, y]
	}
	cframeSimple: {
			[0, cframe_type, 1],
			[1, x, q],
			[q, y, w],
			[w, z, e],
	}
	vector3: {
			[0, x, q],
			[q, y, w],
			[w, z, e],
	}
	vector2: {
			[0, x, q],
			[q, y, w],
	}
	color3: {
			[0, r, 1],
			[1, g, 1],
			[2, z, 1],
	}

	unbufferable: {[0, unbuferrable_index, 2]}
]]