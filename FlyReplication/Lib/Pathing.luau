local Pathing = {}

function Pathing.getPath(object, key)
	local path = {
		__depth = table.clone(object.__depth),
        __index = function(self, key)
			return Pathing.getPath(self, key)
		end,
		__call = function(self)
			return self.__depth
		end,
		__tostring = function(self)
			return table.concat(self.__depth, ".")
		end
	}

	table.insert(path.__depth, key)
	return setmetatable(path, path)
end
function Pathing.initPathRoot()
	local root = {
		__depth = {},

        __index = function(self, key)
			return Pathing.getPath(self, key)
		end,

		__call = function(self)
			return {}
		end,

		__tostring = function()
			return ""
		end
	}
	return setmetatable(root, root)
end

function Pathing.isRootPath(path: any?): boolean
	return path == nil or #path() == 0
end

export type Path = typeof(Pathing.initPathRoot())

return Pathing
