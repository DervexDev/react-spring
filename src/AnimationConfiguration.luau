--!optimize 2
--!strict

local Constants = require(script.Parent.Constants)
local FastMerge = require(script.Parent.Utilities.FastMerge)
local Types = require(script.Parent.Types)

local AnimationConfiguration = {}

local TAU = math.pi * 2
local DOUBLE_TAU = TAU * 2

export type SpringConfiguration = Types.SpringConfiguration
export type PartialSpringConfiguration = Types.PartialSpringConfiguration

local DEFAULTS: SpringConfiguration = table.freeze(FastMerge(Constants.Config.default, {
	mass = 1,
	damping = 1,
	clamp = false,
	velocity = 0,
	easing = Constants.EasingFunctions.Smoother,
}))

function AnimationConfiguration.MergeConfiguration(configuration: any, newConfiguration: any?)
	local trueConfiguration: SpringConfiguration = if newConfiguration
		then FastMerge(configuration, newConfiguration)
		else table.clone(configuration)
	for key, value in DEFAULTS :: { [string]: any } do
		if trueConfiguration[key] == nil then
			trueConfiguration[key] = value
		end
	end

	local frequency = trueConfiguration.frequency
	if frequency then
		local mass = trueConfiguration.mass
		if frequency < 0.01 then
			frequency = 0.01
			trueConfiguration.frequency = frequency
		end

		local dampingRatio = trueConfiguration.damping
		if dampingRatio < 0 then
			dampingRatio = 0
			trueConfiguration.damping = dampingRatio
		end

		trueConfiguration.tension = (TAU / frequency) ^ 2 * mass
		trueConfiguration.friction = DOUBLE_TAU * dampingRatio * mass / frequency
	end

	return trueConfiguration
end

return table.freeze(AnimationConfiguration)
