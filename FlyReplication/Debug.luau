return {
	DEBUG = true,
	CLIENT_CLONE_PROFILE = "FLY_REPLICATION_CLIENT_CLONE",
	
	PROCESS_DEBUG = function(self, debugProfile: string)
		if self.DEBUG then
			debug.profilebegin(debugProfile)
		end
	end,
	END_DEBUG = function(self)
		if self.DEBUG then
			debug.profileend()
		end
	end,
}