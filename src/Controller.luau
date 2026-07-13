--!optimize 2
--!strict

local Promise = require(script.Parent.Parent.Promise)
local React = require(script.Parent.Parent.React)

local FastMerge = require(script.Parent.Utilities.FastMerge)
local Helpers = require(script.Parent.Helpers)
local SpringValue = require(script.Parent.SpringValue)
local Types = require(script.Parent.Types)

export type ControllerProperties<T = any> =
	Types.AnimationProperties
	& ({
		from: T?,
		to: T?,
	} | T)
export type ControllerApi = {
	start: (self: ControllerApi, startProperties: ControllerProperties<Types.AnimationStyle>) -> Promise.Promise,
	stop: (self: ControllerApi, keys: { string }?) -> Promise.Promise,
	pause: (self: ControllerApi, keys: { string }?) -> Promise.Promise,
}

export type Controller<T> = {
	bindings: { [string]: React.Binding<any> },
	controls: { [string]: SpringValue.SpringValue },

	start: (self: Controller<T>, startProperties: ControllerProperties<Types.AnimationStyle>) -> Promise.Promise,
	stop: (self: Controller<T>, keys: { string }?) -> (),
	pause: (self: Controller<T>, keys: { string }?) -> (),
}
type Static = {
	ClassName: "Controller",
	new: <T>(properties: ControllerProperties<T>) -> ({ [string]: React.Binding<any> }, Controller<T>),
}
type PrivateStatic = Static & { __tostring: (self: Controller<never>) -> string }

local Controller = {} :: Controller<never> & Static
local Private = Controller :: Controller<never> & PrivateStatic
Controller.ClassName = "Controller"
(Controller :: any).__index = Controller

function Controller.new<T>(properties): ({ [string]: React.Binding<any> }, Controller<T>)
	local self: Controller<T> = setmetatable({
		bindings = {} :: { [string]: React.Binding<any> },
		controls = {} :: { [string]: SpringValue.SpringValue },
	}, Controller) :: never
	self:start(FastMerge({ default = true }, properties))
	return self.bindings, self
end

local function CreateSpring(properties: ControllerProperties<Types.AnimationStyle>, key: string)
	local spring = SpringValue.new(properties :: any, key)
	local binding, setBinding = React.createBinding(nil :: any)

	spring.key = key
	spring.onChange = setBinding

	return spring, binding
end

local function PrepareKeys<T>(self: Controller<T>, properties: { [any]: any })
	local keys: { string } = properties.keys
	if keys then
		for _, key in keys do
			local spring = self.controls[key]
			if not spring then
				spring, self.bindings[key] = CreateSpring(properties, key)
				self.controls[key] = spring
			end

			(spring :: any):prepareNode(properties)
		end
	end
end

local function FlushUpdate<T>(self: Controller<T>, properties: { [any]: any })
	local loop = properties.loop
	properties.loop = false

	local promises: { Promise.Promise } = {}
	local length = 0

	for _, key in properties.keys or {} do
		local control = self.controls[key]
		length += 1
		promises[length] = control:start(properties)
	end

	return Promise.all(promises):andThen(function()
		if loop then
			local nextProperties = Helpers.CreateLoopUpdate(properties, loop)
			if nextProperties then
				PrepareKeys(self, nextProperties)
				return FlushUpdate(self, nextProperties)
			end
		end
	end)
end

function Controller:start(startProperties)
	if not startProperties then
		return Promise.new(function(resolve)
			resolve()
		end)
	end

	local properties = Helpers.CreateUpdate(startProperties)
	PrepareKeys(self, properties)
	return FlushUpdate(self, properties)
end

function Controller:stop(keys)
	if keys then
		for _, key in keys do
			local control = self.controls[key]
			if control then
				control:stop()
			else
				warn(`Tried to stop animation at key "{key}", but it doesn't exist.`)
			end
		end
	else
		for _, control in self.controls do
			control:stop()
		end
	end
end

function Controller:pause(keys: { string }?)
	if keys then
		for _, key in keys do
			local control = self.controls[key]
			if control then
				control:pause()
			else
				warn(`Tried to pause animation at key "{key}", but it doesn't exist.`)
			end
		end
	else
		for _, control in self.controls do
			control:pause()
		end
	end
end

function Private:__tostring()
	return "ReactSpring.Controller"
end

return table.freeze(Controller :: Static)
