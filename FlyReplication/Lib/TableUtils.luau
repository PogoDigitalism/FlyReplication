local TableUtils = {}

function TableUtils.DeepCopy<T>(e: T): T
    if type(e) ~= "table" then
        return e
    end
    
	local tCopy = table.clone(e)
	for k, v in tCopy do
		if type(v) == "table" then
            tCopy[k] = TableUtils.DeepCopy(v)
		end
	end
	return tCopy
end

local function compContents(a: {}, b: {}): boolean
	for k, vA in a do
		local vB = b[k]
		if typeof(vA) == "table" and typeof(vB) == "table" then
			if not TableUtils.IsSame(vA, vB) then
				return false
			end
		else
			if vA ~= vB then
				return false
			end
		end
	end
	return true
end

function TableUtils.IsSame(a: any, b: any): boolean
	if typeof(a) == "table" and typeof(b) == "table" then
		if a == b then return true end
		if next(a) == nil and next(b) == nil then return true end
		return compContents(a, b) and compContents(b, a)
	else
		return a == b
	end
end

return TableUtils
