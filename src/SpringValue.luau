--!optimize 2
--!strict

local RunService = game:GetService("RunService")
local Promise = require(script.Parent.Parent.Promise)
local Signal = require(script.Parent.Parent.Signal)

local Animation = require(script.Parent.Animation)
local AnimationConfiguration = require(script.Parent.AnimationConfiguration)
local FastMerge = require(script.Parent.Utilities.FastMerge)
local Helpers = require(script.Parent.Helpers)
local Types = require(script.Parent.Types)

export type SpringValueProperties = {
	from: number,
	to: number,
	delay: number?,
	immediate: boolean?,
	config: AnimationConfiguration.SpringConfiguration?,
	onChange: nil | (position: Types.AnimatableType) -> (),
}

export type SpringValue = {
	animation: Animation.Animation,
	defaultProperties: { config: AnimationConfiguration.SpringConfiguration?, immediate: boolean },
	onChange: (position: Types.AnimatableType) -> (),
	onComplete: Signal.VoidSignal,
	hasAnimated: boolean,
	key: string?,
	updateEvent: typeof(RunService.PostSimulation),

	start: (self: SpringValue, properties: Types.Properties) -> Promise.Promise,
	stop: (self: SpringValue) -> (),
	pause: (self: SpringValue) -> (),
	advance: (self: SpringValue, deltaTime: number) -> (),
}
type Private = {
	animation: Animation.Animation,
	connection: RBXScriptConnection?,
	defaultProperties: { config: AnimationConfiguration.SpringConfiguration?, immediate: boolean },
	hasAnimated: boolean,
	key: string?,
	memoizedDuration: number,
	onChange: (position: Types.AnimatableType) -> (),
	onComplete: Signal.VoidSignal,
	updateEvent: typeof(RunService.PostSimulation),

	start: (self: Private, properties: Types.Properties) -> Promise.Promise,
	stop: (self: Private) -> (),
	pause: (self: Private) -> (),
	advance: (self: Private, deltaTime: number) -> (),

	prepareNode: (self: Private, properties: Types.Properties) -> {
		from: unknown,
		to: unknown,
	},
}
type Static = {
	ClassName: "SpringValue",
	new: (properties: SpringValueProperties, key: string, updateEvent: Types.PostSimulationLike?) -> SpringValue,
}
type PrivateStatic = Static & { __tostring: (self: SpringValue) -> string }

local SpringValue = {} :: SpringValue & Static
local Private = SpringValue :: Private & PrivateStatic
SpringValue.ClassName = "SpringValue"
(SpringValue :: any).__index = SpringValue

function SpringValue.new(properties, key, updateEvent)
	assert(properties.from or properties.to, "`to` or `from` expected, none passed.")

	return setmetatable({
		animation = Animation.new(properties, key),
		defaultProperties = {
			config = properties.config,
			immediate = if properties.immediate ~= nil then properties.immediate else false,
		},

		onChange = (properties.onChange or function() end) :: (position: Types.AnimatableType) -> (),
		onComplete = Signal.new() :: Signal.VoidSignal,
		hasAnimated = false,
		key = nil :: string?,
		updateEvent = (updateEvent or RunService.PostSimulation) :: typeof(RunService.PostSimulation),

		connection = nil :: RBXScriptConnection?,
		memoizedDuration = 0,
	}, SpringValue) :: never
end

local function PrepareNode(self: Private, properties: Types.Properties)
	local key = self.key or ""
	local to = properties.to :: any
	local from = properties.from :: any

	if type(to) == "table" then
		to = to[key]
	end

	if type(from) == "table" then
		from = from[key]
	end

	local range = { from = from, to = to }
	if not self.hasAnimated then
		if properties.reverse then
			to, from = from, to
		end

		local values = Helpers.GetValuesFromType(from or to)
		self.animation.values = table.clone(values)
		self.animation.lastPosition = table.clone(values)
		self.onChange(from or to)
	end

	return range
end
Private.prepareNode = PrepareNode

local function Update(self: Private, properties: Types.Properties)
	if properties.default then
		self.defaultProperties = FastMerge(self.defaultProperties, Helpers.GetDefaultProperties(properties))
	end

	return Promise.new(function(resolve, _, onCancel)
		if properties.delay then
			task.wait(properties.delay)
		end

		if onCancel() then
			return
		end

		local range = PrepareNode(self, properties)
		local from = range.from
		local to = range.to

		if from and not to then
			to = from
		end

		local classAnimation = self.animation
		classAnimation:mergeProperties(FastMerge(self.defaultProperties, properties))

		if properties.reverse then
			classAnimation.toValues, classAnimation.fromValues = classAnimation.fromValues, classAnimation.toValues
		end

		self.onChange = properties.onChange or self.onChange

		local reset = if properties.reset == nil
			then from ~= nil
			else classAnimation.fromValues ~= nil and properties.reset
		if reset then
			classAnimation.values = table.clone(classAnimation.fromValues)
			classAnimation.lastPosition = if from then Helpers.GetValuesFromType(from) else classAnimation.lastPosition

			local length = #classAnimation.velocity0
			classAnimation.velocity0 = table.create(length, nil)
			classAnimation.lastVelocity = table.create(length, nil)
		end

		classAnimation.toValues = Helpers.GetValuesFromType(to)
		classAnimation.fromValues = table.clone(classAnimation.lastPosition)

		if not self.connection then
			self.connection = self.updateEvent:Connect(function(deltaTime: number)
				self:advance(deltaTime)
			end)
		end

		self.onComplete:Wait()
		resolve()
	end)
end

function Private:start(properties)
	self.hasAnimated = true
	return Update(self, properties)
end

function Private:stop()
	local connection = self.connection
	if connection then
		connection:Disconnect()
		self.connection = nil
	end

	self.animation:stop()
end

function Private:pause()
	local connection = self.connection
	if connection then
		connection:Disconnect()
		self.connection = nil
	end
end

-- TODO: REDUCE INDEXING PLEASEEEEEEEEEEEEE
function Private:advance(deltaTime: number)
	local changed = false
	local idle = true

	local classAnimation = self.animation
	local configuration = classAnimation.config
	local toValues = classAnimation.toValues

	for index = 1, #classAnimation.values do
		if classAnimation.done[index] then
			continue
		end

		local finished = classAnimation.immediate
		local position = toValues[index]
		local from = classAnimation.fromValues[index]
		local to = classAnimation.toValues[index]

		if not finished then
			position = classAnimation.lastPosition[index]
			if configuration.tension <= 0 then
				classAnimation.done[index] = true
				continue
			end

			local currentElapsedTime = classAnimation.elapsedTime[index] + deltaTime
			classAnimation.elapsedTime[index] = currentElapsedTime

			local currentVelocity0 = classAnimation.velocity0[index]
			if currentVelocity0 == nil then
				local velocity = configuration.velocity
				if type(velocity) == "table" then
					currentVelocity0 = velocity[index]
					classAnimation.velocity0[index] = currentVelocity0
				else
					currentVelocity0 = if to - from > 0 then velocity elseif to - from < 0 then -velocity else 0
					classAnimation.velocity0[index] = currentVelocity0
				end
			end

			local velocity: number
			local duration = configuration.duration
			if duration then
				local alpha = 1
				if duration > 0 then
					if self.memoizedDuration ~= duration then
						self.memoizedDuration = duration

						local durationProgress = classAnimation.durationProgress[index]
						if durationProgress > 0 then
							currentElapsedTime = duration * durationProgress + deltaTime
							classAnimation.elapsedTime[index] = currentElapsedTime
						end
					end

					alpha = math.clamp((configuration.progress or 0) + currentElapsedTime / self.memoizedDuration, 0, 1)
					classAnimation.durationProgress[index] = alpha
				end

				position = from + configuration.easing(alpha) * (to - from)
				velocity = (position - classAnimation.lastPosition[index]) / deltaTime
				finished = alpha == 1
			else
				velocity = classAnimation.lastVelocity[index] or currentVelocity0

				local precision = math.max(
					configuration.precision or (if from == to then 0.005 else math.min(1, math.abs(to - from) / 1000)),
					0.0001
				)
				local restVelocity = configuration.restVelocity or precision / 10

				local bounceFactor = if configuration.clamp then 0 else configuration.bounce
				local canBounce = bounceFactor ~= nil

				local isGrowing = if from == to then currentVelocity0 > 0 else from < to
				local totalSteps = deltaTime * 1000 // 2 + 1
				for _ = 0, totalSteps do
					local isMoving = math.abs(velocity) > restVelocity
					if not isMoving then
						finished = math.abs(to - position) <= precision
						if finished then
							break
						end
					end

					if canBounce then
						local isBouncing = position == to or (position > to) == isGrowing
						if isBouncing then
							velocity = -velocity * bounceFactor :: number
							position = to
						end
					end

					local springForce = -configuration.tension * 0.000001 * (position - to)
					local dampingForce = -configuration.friction * 0.001 * velocity
					local acceleration = (springForce + dampingForce) / configuration.mass

					velocity += acceleration
					position += velocity
				end
			end

			classAnimation.lastVelocity[index] = velocity
		end

		if finished then
			position = to
			classAnimation.done[index] = true
		else
			idle = false
		end

		if classAnimation:setValue(index, position) then
			changed = true
		end
	end

	if idle then
		self.onChange(classAnimation:getValue())
		local connection = self.connection
		if connection then
			connection:Disconnect()
			self.connection = nil
		end

		self.animation:stop()
		self.onComplete:Fire()
	elseif changed then
		self.onChange(classAnimation:getValue())
	end
end

function Private:__tostring()
	return "ReactSpring.SpringValue"
end

return table.freeze(SpringValue :: Static)
