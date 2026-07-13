--!optimize 2
--!strict

local AnimationConfiguration = require(script.Parent.AnimationConfiguration)
local Helpers = require(script.Parent.Helpers)
local Types = require(script.Parent.Types)

export type Animation = {
	values: { number },
	toValues: { number },
	fromValues: { number },
	type: string,

	config: AnimationConfiguration.SpringConfiguration,
	immediate: boolean?,

	velocity0: { number },
	lastPosition: { number },
	lastVelocity: { number },
	done: { boolean },
	elapsedTime: { number },
	durationProgress: { number },

	setValue: (self: Animation, index: number, value: number) -> boolean,
	mergeProperties: (self: Animation, properties: Types.Properties?) -> (),
	getValue: (self: Animation) -> Types.AnimatableType,
	stop: (self: Animation) -> (),
}
type Static = {
	ClassName: "Animation",
	new: (properties: Types.Properties, key: string?) -> Animation,
}
type PrivateStatic = Static & { __tostring: (self: Animation) -> string }

local Animation = {} :: Animation & Static
local Private = Animation :: Animation & PrivateStatic
Animation.ClassName = "Animation"
(Animation :: any).__index = Animation

function Animation.new(properties: Types.Properties, key: string?): Animation
	local self = setmetatable({}, Animation)

	local to = properties.to and properties.to[key :: string]
	local from = properties.from and properties.from[key :: string]
	local length = #Helpers.GetValuesFromType(from or to)

	self.values = Helpers.GetValuesFromType(from or to)
	self.toValues = Helpers.GetValuesFromType(to or from)
	self.fromValues = Helpers.GetValuesFromType(from or to)
	self.type = typeof(from or to)

	self.config = AnimationConfiguration.MergeConfiguration(properties.config or {})
	self.immediate = properties.immediate :: boolean

	self.velocity0 = table.create(length, nil) :: { number }
	self.lastPosition = Helpers.GetValuesFromType(from or to)
	self.lastVelocity = table.create(length, nil) :: { number }
	self.done = table.create(length, false)
	self.elapsedTime = table.create(length, 0)
	self.durationProgress = table.create(length, 0)

	return self :: never
end

function Animation:setValue(index: number, value: number)
	self.lastPosition[index] = value
	local values = self.values
	if values[index] == value then
		return false
	end

	values[index] = value
	return true
end

function Animation:mergeProperties(properties: Types.Properties?)
	if properties then
		self.config = AnimationConfiguration.MergeConfiguration(properties.config or {})
		self.immediate = if properties.immediate ~= nil then properties.immediate else self.immediate

		local length = #self.values
		self.done = table.create(length, false)
		self.elapsedTime = table.create(length, 0)
		self.durationProgress = table.create(length, 0)
	end
end

function Animation:getValue(): Types.AnimatableType
	return Helpers.GetTypeFromValues(self.type, self.values)
end

function Animation:stop()
	local lastPosition = self.lastPosition
	local lastVelocity = self.lastVelocity
	local values = self.values
	local velocity0 = self.velocity0

	local length = #values
	for index, value in values do
		lastPosition[index] = value
		lastVelocity[index] = nil
		velocity0[index] = nil

		self.durationProgress = table.create(length, 0)
		self.elapsedTime = table.create(length, 0)
	end
end

function Private:__tostring()
	return "ReactSpring.Animation"
end

return table.freeze(Animation :: Static)
