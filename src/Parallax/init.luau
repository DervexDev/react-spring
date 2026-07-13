--!optimize 2
--!strict

local RunService = game:GetService("RunService")

local LuauPolyfill = require(script.Parent.Parent.LuauPolyfill)
local React = require(script.Parent.Parent.React)

local Constants = require(script.Parent.Constants)
local Controller = require(script.Parent.Controller)
local ParallaxTypes = require(script.ParallaxTypes)
local ParentContext = require(script.ParentContext)

local Set = LuauPolyfill.Set

local function Parallax(properties: ParallaxTypes.ParallaxProperties, reference: any)
	local ready, setReady = React.useState(false)
	local containerCanvasSize, setContainerCanvasSize = React.useBinding(0)
	local scroll, setScroll = React.useBinding(0)

	local containerReference = React.useRef(nil :: ScrollingFrame?)
	local contentReference = React.useRef(nil :: GuiObject?)
	local syncScrollConnection = React.useRef(nil :: RBXScriptConnection?)

	local function disconnectEffect()
		local connection = syncScrollConnection.current
		if connection then
			connection:Disconnect()
			syncScrollConnection.current = nil
		end
	end
	React.useEffect(disconnectEffect, {})

	local pages = properties.pages
	local configuration = properties.config or Constants.Config.default
	local horizontal = properties.horizontal or false
	local children = properties.children

	local containerProperties: any = table.clone(properties)
	containerProperties.pages = nil
	containerProperties.config = nil
	containerProperties.horizontal = nil
	containerProperties.children = nil

	local function update() end
	local function scrollTo(_: number) end

	local state = React.useMemo(function(): ParallaxTypes.Parallax
		local styles, api = Controller.new({ Scroll = 0 })
		return {
			config = configuration,
			horizontal = horizontal,
			busy = false,
			space = 0,
			current = 0,
			offset = 0,
			layers = Set.new(),
			container = containerReference,
			content = contentReference,
			update = function()
				update()
			end,

			scrollTo = function(offset)
				scrollTo(offset)
			end,

			stop = function()
				api:stop()
			end,

			_Api = api,
			_Styles = styles,
		}
	end, {})

	React.useImperativeHandle(reference, function()
		return state
	end)

	update = function()
		local container = containerReference.current
		if not container then
			return
		end

		state.space = if horizontal then container.AbsoluteSize.X else container.AbsoluteSize.Y
		state.current = if horizontal then container.CanvasPosition.X else container.CanvasPosition.Y
		setContainerCanvasSize(pages * state.space)

		local content = contentReference.current
		if content then
			content.Size = if horizontal
				then UDim2.fromOffset(state.space * pages, content.AbsoluteSize.Y)
				else UDim2.fromOffset(content.AbsoluteSize.X, state.space * pages)
		end

		for _, layer in state.layers do
			layer.setHeight(state.space, true)
			layer.setPosition(state.space, state.current, true)
		end
	end

	scrollTo = function(offset: number)
		state.offset = offset

		state._Api
			:start({
				immediate = true,
				Scroll = state.current,
			})
			:andThen(function()
				-- DEVIATION: Chained to `andThen` because immediate currently only takes effect on the next frame
				if syncScrollConnection.current then
					syncScrollConnection.current:Disconnect()
				end

				local connection = RunService.PostSimulation:Connect(function()
					setScroll(state._Styles.Scroll:getValue())
				end)

				syncScrollConnection.current = connection

				state._Api
					:start({
						config = configuration,
						Scroll = offset * state.space,
					})
					:andThen(function()
						if syncScrollConnection.current and connection == syncScrollConnection.current then
							connection:Disconnect()
							syncScrollConnection.current = nil
						end
					end)
			end)
	end

	local function onScroll(frame: ScrollingFrame)
		local newScroll = if horizontal then frame.CanvasPosition.X else frame.CanvasPosition.Y
		-- DEVIATION: Track user manual scroll
		setScroll(newScroll)

		if not state.busy then
			state.busy = true
			state.current = newScroll
			for _, layer in state.layers do
				layer.setPosition(state.space, state.current)
			end

			state.busy = false
		end
	end

	local function updateEffect()
		state.update()
	end
	React.useEffect(updateEffect)

	local function readyEffect()
		setReady(true)
	end
	React.useEffect(readyEffect, {})

	containerProperties.AutomaticCanvasSize = Enum.AutomaticSize.None
	containerProperties.ScrollingDirection = if horizontal then Enum.ScrollingDirection.X else Enum.ScrollingDirection.Y
	containerProperties.ref = containerReference
	containerProperties[React.Change.CanvasPosition] = onScroll
	containerProperties[React.Change.AbsoluteSize] = update
	containerProperties.CanvasPosition = scroll:map(function(value)
		return if horizontal then Vector2.new(value, 0) else Vector2.new(0, value)
	end)
	containerProperties.CanvasSize = containerCanvasSize:map(function(value)
		return if horizontal then UDim2.fromOffset(value, 0) else UDim2.fromOffset(0, value)
	end)

	return React.createElement(
		"ScrollingFrame",
		containerProperties,
		ready
			and React.createElement(
				React.Fragment,
				{},
				React.createElement(ParentContext.Provider, {
					key = "ParentProvider",
					value = state,
				}, children)
			)
	)
end

local ParallaxNoMemo = React.forwardRef(Parallax)
ParallaxNoMemo.displayName = "ParallaxNoMemo"

local TrueParallax = React.memo(Parallax)
TrueParallax.displayName = "Parallax"
return (TrueParallax :: never) :: (properties: ParallaxTypes.ParallaxProperties) -> React.ReactNode
