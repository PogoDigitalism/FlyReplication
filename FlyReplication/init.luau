--!strict
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = require(script.Server)
local Client = require(script.Client)
local Typecheck = require(script.Lib.Typecheck)
local Constants = require(script.Lib.Constants)
local Pathing = require(script.Lib.Pathing)

local IS_SERVER = RunService:IsServer()
local IS_CLIENT = RunService:IsClient()

type Mode<TServer, TClient, TType> = {
    Server: TServer,
    Client: TClient,
    
    EnableBuffers: (self: Mode<TServer, TClient, TType>) -> Mode<TServer, TClient, TType>,
    SetUnreliable: (self: Mode<TServer, TClient, TType>) -> Mode<TServer, TClient, TType>,
    DisableTypechecking: (self: Mode<TServer, TClient, TType>) -> Mode<TServer, TClient, TType>,
    SetDefaultData: (self: Mode<TServer, TClient, TType>, default: TType) -> Mode<TServer, TClient, TType>,
} & {Path: TType}

type PublisherAll<T> = Server.PublisherAll<T>
type Publisher<T> = Server.Publisher<T>
type Subscriber<T> = Client.Subscriber<T>
type Modes<T> = {
    All: Mode<PublisherAll<T>, Subscriber<T>, T>,
    Player: Mode<Publisher<T>, Subscriber<T>, T>,
}

local ReplicationInstance = {}
ReplicationInstance.__index = ReplicationInstance

local replicationInstances: {[string]: _ReplicationInstance} = {}

function ReplicationInstance.new(mode, annotation)
    local self = setmetatable({}, ReplicationInstance)
    
	if mode == "All" then
		if IS_SERVER then
            self.Server = Server.createPublisherAll(annotation)
		elseif IS_CLIENT then
            self.Client = Client.createSubscriber(annotation)
		end
	elseif mode == "Player" then
		if IS_SERVER then
            self.Server = Server.createPublisher(annotation)
		elseif IS_CLIENT then
            self.Client = Client.createSubscriber(annotation)
		end
	end

    self.Path = Pathing.initPathRoot()
    
	self._namespace = ""
	self._initialised = false
    self._isUnreliable = false
    self._optimise = false

	return self
end
type _ReplicationInstance = typeof(ReplicationInstance.new(...))

function ReplicationInstance._Init(self: _ReplicationInstance, name: string, namespace: string)
	if typeof(name) ~= "string" then
		error("FlyReplication instance : ".. tostring(name) .. " must be  string type.")
	end
	
    self._namespace = namespace
    
    local remote: RemoteEvent = nil
    if RunService:IsServer() then
        if self._isUnreliable then
            remote = Instance.new("UnreliableRemoteEvent")
        else
            remote = Instance.new("RemoteEvent")
        end
        remote.Name = name
        --replicationInstances[self._namespace]
        remote.Parent = Constants.FOLDER
    end
    
    if self.Server then
        self.Server:_Init(remote, name)
    end
    if self.Client then
        self.Client:_Init(name)
    end
    
	self._initialised = true
end

function ReplicationInstance.EnableBuffers(self: _ReplicationInstance): _ReplicationInstance
    self._optimise = true

    if self.Server then
        self.Server:_SetOptimisation()
    end
    if self.Client then
        self.Client:_SetOptimisation()
    end

    return self
end

function ReplicationInstance.SetUnreliable(self: _ReplicationInstance): _ReplicationInstance
	if not self.Server then return self end
    self._isUnreliable = false
    
    return self
end

function ReplicationInstance.DisableTypechecking(self: _ReplicationInstance): _ReplicationInstance
	if not self.Server then return self end
    self.Server:_DisableTypechecking()

    return self
end

function ReplicationInstance.SetDefaultData(self: _ReplicationInstance, default: any?): _ReplicationInstance
	if not self.Server then return self end
    self.Server:_SetDefault(default)
    
    return self
end

local FlyReplication = {}

function FlyReplication.new<T, U>(
	mode: U | keyof<Modes<T>> | "",
	data: T
): index<Modes<T>, U>
    return ReplicationInstance.new(mode, data) :: index<Modes<T>, U> -- silence warning
end

function FlyReplication.namespace<T>(name: string, packets: T): T
	if typeof(packets) ~= "table" then
		error("'t' must be of type table")
	end
	
	for packetName, replicationInstance in packets do
		replicationInstance:_Init(packetName, name)
	end
	
	return packets
end

FlyReplication.types = Typecheck.types
return FlyReplication
