export type function getReturnValue(key, template)
	key = tostring(key)
	
	if not key:is("singleton") then
		error("Not a keyPath ")
	end

	local currentRef = template

	local keyPath = key:value()
	local keys = string.split(keyPath, ".")

	if #keys <= 1 then
		error("Not a valid keypath")
	end
	
	if keys[2] ~= "path" then
		error("Invalid keypath; second index MUST be 'path'")
	end

	for i = 3, #keys - 1, 1 do
		local key = keys[i]
		key = tonumber(key) or key

		currentRef = currentRef:readproperty(types.singleton(key)) :: type
	end

	local finalKey = keys[#keys]
	finalKey = tonumber(finalKey) or finalKey

	return currentRef:readproperty(types.singleton(finalKey))
end

export type Path = "self.Path.key.path.here"?

export type StrPath = "key.path.here"
export type ParsedPath = {string}

export type ReplicationPacket = {[StrPath]: any}

return {}
