
local HttpService = game:GetService("HttpService")

local Typecheck = {}

local bufferTag = HttpService:GenerateGUID(false)
local listTag = HttpService:GenerateGUID(false)
local dictionairyTag = HttpService:GenerateGUID(false)
local optionalTag = HttpService:GenerateGUID(false)
local orTag = HttpService:GenerateGUID(false)

local function clearOfBuffertag(annotation: any): any
	local annotationType = typeof(annotation)
    if (annotationType == "table") then
        if annotation[bufferTag] then
            return annotation.data
        end
	end
    return annotation
end

function Typecheck.hasTag(annotation: any): boolean
	return annotation[listTag] or 
		annotation[dictionairyTag] or
		annotation[optionalTag] or 
		annotation[orTag]
end

function Typecheck.isList(annotation: any): boolean
	if typeof(annotation) ~= "table" then
		return false
	end
	return (typeof(annotation) == "table") and annotation[listTag]
end

function Typecheck.isDictionary(annotation: any): boolean
	if typeof(annotation) ~= "table" then
		return false
	end
	return (typeof(annotation) == "table" and annotation[dictionairyTag])
end

function Typecheck.isOptional(annotation: any): boolean
	if typeof(annotation) ~= "table" then
		return false
	end
	return (typeof(annotation) == "table" and annotation[optionalTag])
end
function Typecheck.isOr(annotation: any): boolean
	if typeof(annotation) ~= "table" then
		return false
	end
	return (typeof(annotation) == "table" and annotation[orTag])
end

function Typecheck.getAnnotationAtPath(annotation: any, parsedPath: {}): any
    local current = annotation
	for _, key in parsedPath do
        if current == nil then return nil end
        local t = typeof(current)
        
        if t ~= "table" then
            return nil
        end
		
        if Typecheck.isDictionary(current) then
            current = current.value
        elseif Typecheck.isList(current) then
            current = current.value
        elseif Typecheck.isOptional(current) then
            current = current.data
            if typeof(current) == "table" then
                current = current[key]
            end
        else
            current = current[key]
        end
	end
    return current
end

function Typecheck.typeCheck(data: any, annotation: any)
	local dataType = typeof(data)

	annotation = clearOfBuffertag(annotation)

    if Typecheck.isDictionary(annotation) then
		if dataType ~= "table" then
			error("Invalid type passed: " .. data .. ", expected: a dictionairy with (key-value) pair " .. typeof(annotation.key) .. "-" .. typeof(annotation.value), 10)
		end
		
		if next(data) == nil then
			return -- is empty table OR list, passes!
		end
		
        for k, v in data do
            warn("CHECK KEY", k, annotation.key, annotation["key"], annotation)
            Typecheck.typeCheck(k, annotation.key)
            warn("CHECK VALUE", v, annotation.value)
			Typecheck.typeCheck(v, annotation.value)
		end
		return
	end
	
    if Typecheck.isList(annotation) then
		if dataType ~= "table" then
            error("Invalid type passed: " .. data .. ", expected: a list with value type '" .. typeof(annotation.value) .. "'", 10)
		end
		
		for _, v in data do
			Typecheck.typeCheck(v, annotation.value)
		end
		return
	end

    if Typecheck.isOptional(annotation) then
		if data == nil then
			return -- if optional and data is nil, then just skip :D
		else
			Typecheck.typeCheck(data, annotation.data)
			return
		end
	end
    if Typecheck.isOr(annotation) then
		local okA, errA = pcall(Typecheck.typeCheck, data, annotation.aA)
		if okA then return end

		local okB, errB = pcall(Typecheck.typeCheck, data, annotation.aB)
		if okB then return end

		error("Invalid type passed: " .. tostring(data) .. ", expected: " .. typeof(annotation.aA) .. " OR " .. typeof(annotation.aB), 10)
	end

	-- non generic type checks
	if typeof(annotation) ~= "table" then
		if dataType == "Instance" then
			if not data:IsA(annotation.ClassName) then
				error("Invalid instance passed: " .. data .. ", expected: " .. annotation, 10)
			end
			return
		end
		if dataType ~= typeof(annotation) then
			error("Invalid type passed: " .. dataType .. ", expected: " .. typeof(annotation), 10)
		end
		return
	end

	if dataType ~= "table" then
		error("Expected table, got " .. dataType, 10)
		return
	end

	for k, e in annotation do
		local v = data[k]
		if not v and not Typecheck.isOptional(e) then
			error("Missing key in data: " .. tostring(k), 10)
		end

		local success, result = pcall(Typecheck.typeCheck, v, e)
		if not success then
			error(`Problem for key '{k}': ` .. result)
		end
	end

	--local keyCache = {}
	-- for k, v in data do
	-- 	keyCache[k] = true

	-- 	local expected = annotation[k]
	-- 	if expected == nil then
	-- 		continue
	-- 	end

	-- 	local success, result = pcall(Typecheck.typeCheck, v, expected)
	-- 	if not success then
	-- 		error(`Problem for key '{k}': ` .. result)
	-- 	end
	-- 	-- if vType == "table" then
	-- 	-- 	if typeof(expected) ~= "table" then
	-- 	-- 		if dataType == "Instance" then
	-- 	-- 			if not data:IsA(annotation) then
	-- 	-- 				error("Invalid instance passed: " .. data .. ", expected: " .. annotation, 10)
	-- 	-- 			end
	-- 	-- 			return
	-- 	-- 		end
	-- 	-- 		error("Expected non-table type at key '" .. tostring(k) .. "', got table", 10)
	-- 	-- 	end

	-- 	-- 	Typecheck.typeCheck(v, expected)
	-- 	-- else
	-- 	-- 	if isOptional(expected) then
	-- 	-- 		expected = expected.data
	-- 	-- 	elseif isOr(expected) then
	-- 	-- 		local isAny = false
	-- 	-- 		if vType == typeof(expected.aA) then
	-- 	-- 			isAny = true
	-- 	-- 			local temp = expected.aA
	-- 	-- 			expected = temp
	-- 	-- 		elseif vType == typeof(expected.aB) then
	-- 	-- 			isAny = true
	-- 	-- 			local temp = expected.aB
	-- 	-- 			expected = temp
	-- 	-- 		end

	-- 	-- 		if not isAny then
	-- 	-- 			error("Invalid type passed: " .. v .. ", expected: " .. typeof(annotation.aA) .. " OR " .. typeof(annotation.aB), 10)
	-- 	-- 		end
	-- 	-- 	end

	-- 	-- 	if vType ~= typeof(expected) then
	-- 	-- 		error("Invalid type at key '" .. tostring(k) .. "': got " .. typeof(v) .. ", expected " .. typeof(expected), 10)
	-- 	-- 	end
	-- 	-- end
	-- end

	-- -- check for missing keys
	-- for k, v in annotation do
	-- 	if isOptional(v) then continue end -- optional, so dont matterrr

	-- 	if not keyCache[k] then
	-- 		error("Missing key in data: " .. tostring(k), 10)
	-- 	end
	-- end
end

local types = {}

local _any = Instance.new("Configuration")
types.any = _any :: any
types.string = ""
types.number = 0
types.bool = false
types.nothing = -1 :: nil

--[[
	The typechecker will not check instance types at runtime.
	For convenience a few common instances have been made as types

	If you want more intellisense just type assert: types.Instance :: YourInstanceHere
]]
local o = Instance.new("Configuration")
types.Player = o :: Player
types.Instance = o :: Instance
types.Attachment = o :: Attachment
types.Model = o :: Model
types.BasePart = o :: BasePart
types.Folder = o :: Folder

types.Color3 = Color3.new()
types.CFrame = CFrame.identity
types.Vector3 = Vector3.zero
types.Vector2 = Vector2.zero

types.custom = function<T, U>(name: "" | T, dataType: U | any): T | U
	return dataType -- purely for semantical purpose
end

types.buffer = function<T>(dataType: T): T
	return {
		[bufferTag] = true,
		data = dataType
	}
end
types.list = function<T>(valueType: T): {T}
	return {
		[listTag] = true,
		value = valueType
	}
end
types.dictionairy = function<T, U>(keyType: T, valueType: U): {[T]: U}
	return {
		[dictionairyTag] = true,
		key = keyType,
		value = valueType
	}
end
types.optional = function<T>(dataType: T): T?
	return {
		[optionalTag] = true,
		data = dataType
	} :: T?
end
types.OR = function<T, U>(a: T, b: U): T | U
	return {
		[orTag] = true,
		aA = a,
		aB = b
	}
end

local toType = {
	number = types.number,
	string = types.string,
	boolean = types.bool,
	["nil"] = types.nothing,
	Vector2 = types.Vector2,
	Vector3 = types.Vector3,
	Color3 = types.Color3,
	CFrame = types.CFrame,
	Instance = types.Instance
}

function Typecheck.inferSchema(data: any): any
	local t = typeof(data)
	return toType[t]
end

Typecheck.types = types
return Typecheck
