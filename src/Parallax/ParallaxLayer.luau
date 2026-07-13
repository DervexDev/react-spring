--!optimize 2
--!strict

local React = require(script.Parent.Parent.Parent.React)

local Controller = require(script.Parent.Parent.Controller)
local ParallaxTypes = require(script.Parent.ParallaxTypes)
local ParentContext = require(script.Parent.ParentContext)

local function ParallaxLayer(properties: ParallaxTypes.ParallaxLayerProperties, reference: any)
	local layerProperties: any = table.clone(properties)

	local horizontal = layerProperties.horizontal
	layerProperties.horizontal = nil

	local factor = layerProperties.factor or 1
	layerProperties.factor = nil

	local offset = layerProperties.offset or 0
	layerProperties.offset = nil

	local speed = layerProperties.speed or 0
	layerProperties.speed = nil

	local sticky = layerProperties.sticky
	layerProperties.sticky = nil

	local children = layerProperties.children
	layerProperties.children = nil

	local parent = React.useContext(ParentContext)
	local stickyTranslate, setStickyTranslate = React.useBinding(0)

	local styles, api = React.useMemo(function()
		local translate: number
		if sticky then
			local start = sticky.start or 0
			translate = start * parent.space
		else
			local targetScroll = math.floor(offset) * parent.space
			local distance = parent.space * offset + targetScroll * speed
			translate = -(parent.current * speed) + distance
		end

		return Controller.new({
			space = if sticky then parent.space else parent.space * factor,
			Translate = translate,
		})
	end, {})

	local function setSticky(_: number, _: number) end

	local layer = React.useMemo(function(): ParallaxTypes.ParallaxLayer
		return {
			horizontal = if horizontal == nil or sticky then parent.horizontal else horizontal,
			sticky = nil,
			isSticky = false,

			setPosition = function(height, scrollTop, immediate)
				if sticky then
					setSticky(height, scrollTop)
				else
					local targetScroll = math.floor(offset) * height
					local distance = height * offset + targetScroll * speed
					api:start({
						config = parent.config,
						immediate = immediate,
						Translate = -(scrollTop * speed) + distance,
					} :: any)
				end
			end,

			setHeight = function(height, immediate)
				api:start({
					config = parent.config,
					immediate = immediate,
					space = if sticky then height else height * factor,
				})
			end,
		}
	end, {})

	-- TODO: useOnce
	local function updateStickyEffect()
		if sticky then
			local start = sticky.start or 0
			local finish = sticky.finish or start + 1
			layer.sticky = {
				finish = finish,
				start = start,
			}
		end
	end
	React.useEffect(updateStickyEffect, {})

	React.useImperativeHandle(reference, function()
		return layer
	end)

	setSticky = function(height: number, scrollTop: number)
		local start = layer.sticky and layer.sticky.start and layer.sticky.start * height
		local finish = layer.sticky and layer.sticky.finish and layer.sticky.finish * height
		if start and finish then
			layer.isSticky = scrollTop >= start and scrollTop <= finish

			-- DEVIATION: Since `sticky` is not natively supported, we must manually set the position of the sticky layer every time
			-- the scroll position changes
			if scrollTop > start and scrollTop < finish then
				setStickyTranslate(scrollTop)
			else
				setStickyTranslate(if scrollTop <= start then start else finish)
			end
		end
	end

	local function updateParentEffect()
		if not parent then
			return
		end

		parent.layers:add(layer)
		parent.update()
		return function()
			parent.layers:delete(layer)
			parent.update()
		end
	end
	React.useEffect(updateParentEffect, {})

	api:start({ Translate = 0 })

	layerProperties.BackgroundTransparency = 1
	layerProperties.Position = (if sticky then stickyTranslate else styles.Translate):map(function(value)
		return if layer.horizontal then UDim2.fromOffset(value, 0) else UDim2.fromOffset(0, value)
	end)
	layerProperties.Size = styles.space:map(function(value)
		return if layer.horizontal then UDim2.new(0, value, 1, 0) else UDim2.new(1, 0, 0, value)
	end)
	layerProperties.ref = reference
	return React.createElement("Frame", layerProperties, children)
end

local ParallaxLayerNoMemo = React.forwardRef(ParallaxLayer)
ParallaxLayerNoMemo.displayName = "ParallaxLayerNoMemo"

local TrueParallaxLayer = React.memo(ParallaxLayerNoMemo)
TrueParallaxLayer.displayName = "ParallaxLayer"
return (TrueParallaxLayer :: never) :: (properties: ParallaxTypes.ParallaxLayerProperties) -> React.ReactNode
