--!strict
export type Provider = {
	init: (self: Provider) -> (),
	start: (self: Provider) -> ()
} & any

export type Hook = {
	init: (self: Provider) -> (),
	start: (self: Provider) -> (),
	curate: (self: Provider, target: Provider) -> ()
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = {}
Core.pipeline = {} :: {Provider}

local function _package(self: typeof(Core), container: Instance, deep: boolean?)
	for _, module: Instance in container:GetDescendants() do
		if module:IsA("Folder") then
			_package(self, module, deep)
		end
		if not module:IsA('ModuleScript') then
			if deep then
				_package(self, module, deep)
			end
			continue
		end

		local source = require(module) :: Provider
		if table.find(self.pipeline, source) then
			continue
		else
			self:pipe(source)
		end
	end
end

local function init(provider: Provider, ...: any)
	if not provider.init then return end
	provider:init(...)
end

local function start(provider: Provider, ...: any)
	if not provider.start then return end
	task.spawn(provider.start, provider, ...)
end

function Core:curate(container: Instance)
	_package(self, container)
	return Core
end

function Core:deepCurate(container: Instance)
	_package(self, container, true)
	return Core
end

function Core:pipe(provider: Provider | ModuleScript)
	if typeof(provider) == 'Instance' then
		provider = require(provider) :: Provider
	end
	table.insert(self.pipeline, provider :: Provider)
	return Core
end

function Core:addMethod<method>(methodName: string, hook: Hook)
	self = self :: typeof(Core) & any
	
	if typeof(hook) == 'Instance' then
		hook = require(hook) :: Hook
	end
	self:pipe(hook)

	for _, provider: Provider in self.pipeline do
		if not provider[methodName] or provider == hook then
			continue
		end
		hook:curate(provider)
	end
	return Core
end

function Core:run(...: any): {Provider}
	for _, provider: Provider in self.pipeline do
		init(provider, ...)
	end
	for _, provider: Provider in self.pipeline do
		start(provider, ...)
	end
	return self.pipeline
end

return Core