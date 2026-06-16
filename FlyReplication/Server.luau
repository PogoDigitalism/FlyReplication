--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Buffer = require(ReplicatedStorage.Shared.Lib.FlyReplication.Lib.Buffer)
local Types = require(script.Parent.Types)
local Pathing = require(script.Parent.Lib.Pathing)
local Keypath = require(script.Parent.Lib.Keypath)
local Typecheck = require(script.Parent.Lib.Typecheck)
local TableUtils = require(script.Parent.Lib.TableUtils)
local Constants = require(script.Parent.Lib.Constants)

local Server = {}

local PUB_ALL_KEY = {} :: Player

type updateFunc<T> = (current: T?) -> T
export type Publisher<T> = {
	Update: <U>(self: Publisher<T>, player: Player, path: U | Pathing.Path?, updateFunc: updateFunc<U>) -> (),
    Scope: <U>(self: Publisher<T>, path: U | Types.Path?) -> <K>(player: Player, key: keyof<U> | K, value: index<U, K>) -> (),
	Set: <U>(self: Publisher<T>, player: Player, path: U | Pathing.Path?, value: U) -> (),
	Increment: <U>(self: Publisher<T>, player: Player, path: U | Pathing.Path?, value: number?) -> number,
	Get: <U>(self: Publisher<T>, player: Player, path: U | Pathing.Path?) -> U,
    Reset: (self: Publisher<T>, player: Player) -> (),
}
export type PublisherAll<T> = {
	Update: <U>(self: PublisherAll<T>, path: U | Pathing.Path?, updateFunc: updateFunc<U>) -> (),
	Scope: <U>(self: PublisherAll<T>, path: U | Pathing.Path?) -> <K>(key: keyof<U> | K, value: index<U, K>) -> (),
	Set: <U>(self: PublisherAll<T>, path: U | Pathing.Path?, value: U) -> (),
	Increment: <U>(self: PublisherAll<T>, path: U | Pathing.Path?, value: number?) -> number,
	Get: <U>(self: PublisherAll<T>, path: U | Pathing.Path?) -> U,
    Reset: (self: PublisherAll<T>) -> (),
}

local Publisher = {}
Publisher.__index = Publisher

local totalBatch: {
    [RemoteEvent]: {
        [Player | string]: {[string]: any}
    }
} = {}
if RunService:IsServer() then
	--RunService:BindToSimulation(function(dt)
	--	for remote, batches in totalBatch do
	--		for player, batch in batches do
	--			if player == PUB_ALL_KEY then
	--				remote:FireAllClients(batch)
	--			else
	--				remote:FireClient(player :: Player, batch) 
	--			end
	--		end
	--	end
	--	totalBatch = {}
	--end, Enum.StepFrequency.Hz5)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed > .25 then
			elapsed = 0
		else
			return
		end
		
        for remote, batches in totalBatch do
            for player, batch in batches do
                if player == PUB_ALL_KEY then
                    remote:FireAllClients(batch)
                else
                    remote:FireClient(player :: Player, batch) 
                end
            end
        end
        totalBatch = {}
    end)
end

local function addToPlayerBatch(remote: RemoteEvent, player: Player, keyPath: string, value: any)
    warn(remote, ":",value)
    totalBatch[remote] = totalBatch[remote] or {}
    totalBatch[remote][player] = totalBatch[remote][player] or {}
    totalBatch[remote][player][keyPath] = value
end

function Publisher.new<T>(annotation: T)
    local self = setmetatable({}, Publisher)

    self._annotation = annotation :: any?
    self._playerData = {} :: {[Player]: any?}
    self._defaultData = nil :: any?
    self._typechecksEnabled = true

    self._optimise = false
    self._name = "Unknown"
    self._remote = nil :: any

    return self
end
type _Publisher = typeof(Publisher.new(...))

function Publisher.Update<T>(self: _Publisher, player: Player, path: T | Pathing.Path, updateFunc: updateFunc<T>)
    local value = self:Get(player, path, false)
    
    local new = updateFunc(value)
    self:Set(player, path, new)
end

function Publisher.Scope(self: _Publisher, path: Pathing.Path)
    return function(player: Player, key, value)
        self:Set(player, path[key], value)
    end
end

function Publisher.Set(self: _Publisher, player: Player, path: Pathing.Path, value: any)
    value = TableUtils.DeepCopy(value)

    local data = self:_GetPlayerData(player)

    print(Pathing.isRootPath(path), self._remote)
	if Pathing.isRootPath(path) then
        local parsedPath = Constants.ROOT_PATH
        local prev = Keypath.getValue(data, parsedPath)
		if TableUtils.IsSame(prev, value) then
			return
		end
		
		Typecheck.typeCheck(value, self._annotation)
		
        self._playerData[player] = value
        
        if self._optimise then
		    value = self:_DumpData(parsedPath, value)
        end
        addToPlayerBatch(
            self._remote,
            player,
            Constants.ROOT_KEY,
            value
        )
        return
    end
    
    if self._playerData[player] == nil then
        self._playerData[player] = {}
    end

	local parsedPath = path()
	local wasOverwritten = Keypath.setNestedValue(self._playerData[player], parsedPath, value)
	if not wasOverwritten then
        return
    end

	if self._typechecksEnabled then
		local annotation = Typecheck.getAnnotationAtPath(self._annotation, parsedPath)
        if annotation ~= nil then
            Typecheck.typeCheck(value, annotation)
        end
    end

    if self._optimise then
		value = self:_DumpData(parsedPath, value)
    end
    addToPlayerBatch(
        self._remote,
        player,
        tostring(path),
        value
    )
end

function Publisher.Increment(self: _Publisher, player: Player, path: Pathing.Path, amount: number?): number?
    local data = self:_GetPlayerData(player)
    if data == nil then return nil end
    
    local value = self:Get(player, path, true) :: number
    local valueType = typeof(value)
    if valueType ~= "number" then
        error("path: "..tostring(path).. " does not represent a 'number' type. Instead is a: "..valueType)
    end

    local result = value + (amount or 1)
    self:Set(player, path, result)
    return result
end

function Publisher.Get(self: _Publisher, player: Player, path: Pathing.Path, unsafe: boolean?): any? 
    local data = self:_GetPlayerData(player)
    if data == nil then return nil end
    
	if Pathing.isRootPath(path) then return unsafe and data or TableUtils.DeepCopy(data) end
    
    local parsedPath = path()
    local value = Keypath.getValue(data, parsedPath)
    return unsafe and value or TableUtils.DeepCopy(value)
end

function Publisher.Reset(self: _Publisher, player: Player)
    self:Set(player, nil, TableUtils.DeepCopy(self._defaultData))
end

function Publisher._DisableTypechecking(self: _Publisher)
    self._typechecksEnabled = false
end

function Publisher._SetDefault(self: _Publisher, default: any?)
    self._defaultData = default
end

function Publisher._InitPlayer(self: _Publisher, player: Player): any?
    local data = TableUtils.DeepCopy(self._defaultData)
    self._playerData[player] = data
    
    return data
end

function Publisher._SetOptimisation(self: _Publisher)
    self._optimise = true
end

function Publisher._GetPlayerData(self: _Publisher, player: Player): any?
    local data = self._playerData[player]
    if data == nil then
        if self._defaultData ~= nil then
            return self:_InitPlayer(player)
        else
            return nil
        end
    else
        return data
    end
end

function Publisher._DumpData(self: _Publisher, parsedPath: {string}, data: any)--: (buffer, {Instance}?, {any}?)
	local annotation = Typecheck.getAnnotationAtPath(self._annotation, parsedPath)

	local b, instanceTable, unbufferableTable = Buffer.dumpData(annotation, data)
	return {b, instanceTable, unbufferableTable}
	--local result, success = pcall(function()
	--	print("DUMPS")
	--end)
	--print(success, result)
	--if not success then
	--	error(`Exception for {self._remote} | Exception when dumping data into buffer:\n{result}`)
	--end
	
	--return result
end

function Publisher._Init(self: _Publisher, remote: RemoteEvent, name: string)
    self._name = name
    self._remote = remote

	self._remote.OnServerEvent:Connect(function(player)
		warn("RECEIVED INIT")
        local data = self:_GetPlayerData(player)
        if data then
			if self._optimise then
                data = self:_DumpData(Constants.ROOT_PATH, data)
            end

            addToPlayerBatch(
                self._remote,
                player,
                Constants.ROOT_KEY,
                data
            )
        end
    end)
end


-- publisher all is essentially just an emulator of a non-existant player
local PublisherAll = {}
PublisherAll.__index = PublisherAll

function PublisherAll.new<T>(annotation: T)
    local self = setmetatable({}, PublisherAll)
    
    self.Path = Pathing.initPathRoot()
    self._inner = Publisher.new(annotation)
    
    return self
end
type _PublisherAll = typeof(PublisherAll.new(...))

function PublisherAll.Update(self: _PublisherAll, path: Pathing.Path, updateFunc: any)
    self._inner:Update(PUB_ALL_KEY, path, updateFunc)
end

function PublisherAll.Scope(self: _PublisherAll, path: Pathing.Path): any
    local func = self._inner:Scope(path)
    return function(key, value)
        func(PUB_ALL_KEY, key, value)
    end
end

function PublisherAll.Set(self: _PublisherAll, path: Pathing.Path, value: any)
    self._inner:Set(PUB_ALL_KEY, path, value)
end

function PublisherAll.Increment(self: _PublisherAll, path: Pathing.Path, value: any): number?
    return self._inner:Increment(PUB_ALL_KEY, path, value)
end

function PublisherAll.Get(self: _PublisherAll, path: Pathing.Path, unsafe: boolean?): any?
    return self._inner:Get(PUB_ALL_KEY, path, unsafe)
end

function PublisherAll.Reset(self: _PublisherAll)
    self._inner:Reset(PUB_ALL_KEY)
end

function PublisherAll._DisableTypechecking(self: _PublisherAll)
    self._inner._typechecksEnabled = false
end

function PublisherAll._SetOptimisation(self: _PublisherAll)
    self._inner._optimise = true
end

function PublisherAll._SetDefault(self: _PublisherAll, default: any?)
    self._inner._defaultData = default
end

function PublisherAll._Init(self: _PublisherAll, remote: RemoteEvent, name: string)
    self._inner._remote = remote
    self._inner._name = name

    remote.OnServerEvent:Connect(function(player)
        local data = self._inner:_GetPlayerData(PUB_ALL_KEY)
		if data ~= nil then
            if self._inner._optimise then
                data = self._inner:_DumpData(Constants.ROOT_PATH, data)
                -- local b, instanceTable, unbufferableTable = Buffer.dumpData(self._inner._annotation, data)
                -- data = {b, instanceTable, unbufferableTable}
            end

            addToPlayerBatch(remote, player, Constants.ROOT_KEY, data)
        end
    end)
end


function Server.createPublisher<T>(annotation: T): Publisher<T>
	return Publisher.new(annotation) :: Publisher<T>
end

function Server.createPublisherAll<T>(annotation: T): PublisherAll<T>
	return PublisherAll.new(annotation) :: PublisherAll<T>
end

return Server
