--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Buffer = require(ReplicatedStorage.Shared.Lib.FlyReplication.Lib.Buffer)
local Pathing = require(script.Parent.Lib.Pathing)
local Constants = require(script.Parent.Lib.Constants)
local Types = require(script.Parent.Types)
local Keypath = require(script.Parent.Lib.Keypath)
local TableUtils = require(script.Parent.Lib.TableUtils)
local Debug = require(script.Parent.Debug)

local Client = {}
type changeFunc<T> = (new: T, old: T?) -> ()
export type Subscriber<T> = {
    OnChange: <U>(self: Subscriber<T>, path: U | Types.Path?, func: changeFunc<U>, unsafe: boolean?) -> RBXScriptConnection,
    Get: <U>(self: Subscriber<T>, path: U | Types.Path?, unsafe: boolean?) -> U,
	GetAsync: <U>(self: Subscriber<T>, path: U | Types.Path?, unsafe: boolean?) -> U,
}

local Subscriber = {}
Subscriber.__index = Subscriber

function Subscriber.new<T>(annotation: T)
	local self = setmetatable({}, Subscriber)
    
	self._annotation = annotation
	self._data = nil :: any
    self._initiated = false
    self._yieldedThreads = {} :: {[string]: {thread}}
    
	self._optimise = false
    self._name = nil :: string?
	self._remote = nil :: BaseRemoteEvent?
    
    self._listeners = {} :: {[() -> ()]: boolean}
    
	return self
end
type _Subscriber = typeof(Subscriber.new(...))

function Subscriber.OnChange(self: _Subscriber, path: Pathing.Path, func: any, unsafe: boolean?)
	local keyPath = Pathing.isRootPath(path) and Constants.ROOT_KEY or tostring(path)
	local parsed = Keypath.parsePath(keyPath)
	
	local oldValue = nil
	
	local callback = function()
		Debug:PROCESS_DEBUG(Debug.CLIENT_CLONE_PROFILE)
		
        local value = Keypath.getValue(self._data, parsed)
		if TableUtils.IsSame(value, oldValue) then Debug:END_DEBUG(); return end

		local copy = TableUtils.DeepCopy(value)
        if self._yieldedThreads[keyPath] then
			oldValue = copy
			
			Debug:END_DEBUG()
            return
        end
        
		task.defer(func, unsafe and copy or TableUtils.DeepCopy(value), oldValue)
		oldValue = copy
		
		Debug:END_DEBUG()
	end
	self._listeners[callback] = true

	return {
		Disconnect = function()
			self._listeners[callback] = nil
		end,
	}
end

function Subscriber.Get<T>(self: _Subscriber, path: Pathing.Path, unsafe)
    if Pathing.isRootPath(path) then
        return unsafe and self._data or TableUtils.DeepCopy(self._data)
    end
    
    local parsed = path()
    local value = Keypath.getValue(self._data, parsed)
    return unsafe and value or TableUtils.DeepCopy(value)
end

function Subscriber.GetAsync(self: _Subscriber, path, unsafe)
	if self._initiated then
        local value = self:Get(path, unsafe)
        if value ~= nil then
			return value
		end
	else
		self._remote:FireServer() -- init and get value
	end
	
	local keyPath = Pathing.isRootPath(path) and Constants.ROOT_KEY or tostring(path)
	self:_SubmitThread(keyPath)
	
	print(self._remote,  "YIELDEDDD", path)
    coroutine.yield()
    
    local value = self:Get(path, unsafe)
    if value == nil then
        return self:GetAsync(path, unsafe)
    end
    return value
end

function Subscriber._TriggerListeners(self: _Subscriber)
	for func, _ in self._listeners do
		task.spawn(func)
	end
end

function Subscriber._SetOptimisation(self: _Subscriber)
    self._optimise = true
end

function Subscriber._SubmitThread(self: _Subscriber, keyPath: string)
	local thread = coroutine.running()
    
	self._yieldedThreads[keyPath] = self._yieldedThreads[keyPath] or {}
	table.insert(self._yieldedThreads[keyPath], thread)
end

function Subscriber._HasThreads(self: _Subscriber, keyPath: string)
	local threads = self._yieldedThreads[keyPath] or {}
	return #threads > 0 
end

function Subscriber._ResumeThreads(self: _Subscriber)
    for keyPath, threads in self._yieldedThreads do
        for _, t in threads do
            coroutine.resume(t)
        end
    end
    
	self._yieldedThreads = {}
end

function Subscriber._Init<T>(self: _Subscriber, name: string)
    self._name = name
    self._remote = Constants.FOLDER:WaitForChild(name) :: BaseRemoteEvent
	
	self._remote.OnClientEvent:Connect(function(packet: Types.ReplicationPacket)
		for keyPath, value in packet do
			print(value, self._data, self._remote)
			if self._data == nil and value == nil then continue end
			
			if self._optimise then
				local b = value[1]
				local it = value[2]
				local ut = value[3]
                
                print(b, it, ut)
				local cursor
                value, cursor = Buffer.deconstructBuffer(self._annotation, b, 0, false, ut, it)
                
                print(value, cursor)
			end

			local parsed = Keypath.parsePath(keyPath)
			
			if self._data ~= nil then
				local oldValue = Keypath.getValue(self._data, parsed)
				if TableUtils.IsSame(value, oldValue) then continue end
			end

            if keyPath == Constants.ROOT_KEY then
                print(value)
				self._data = value
				self:_TriggerListeners()
				self:_ResumeThreads()
				
				continue
			end

			if self._data == nil then self._data = {} end

            Keypath.setNestedValue(self._data, parsed, value)
            self:_TriggerListeners()
            self:_ResumeThreads()
            
		end

		self._initiated = true
	end)
end

function Client.createSubscriber<T>(annotation: T): Subscriber<T>
    return Subscriber.new(annotation) :: Subscriber<T>
end

return Client
