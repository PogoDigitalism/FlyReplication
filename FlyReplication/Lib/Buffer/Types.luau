export type TypeInterface = {
	-- cursor ALWAYS assumes that cursor+0 is an empty spot to-be filled
	serialize: (b: buffer, cursor: number, arg: any) -> number,
	-- will assume cursor is compensated for type id offset
	deserialize: (b: buffer, cursor: number) -> (any, number),
	size: (data: any) -> number
}
return {}
