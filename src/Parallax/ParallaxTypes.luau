--!optimize 2
--!strict

local LuauPolyfill = require(script.Parent.Parent.Parent.LuauPolyfill)
local React = require(script.Parent.Parent.Parent.React)

export type Parallax = {
	config: any,
	horizontal: boolean,
	busy: boolean,
	space: number,
	offset: number,

	current: number,
	layers: LuauPolyfill.Set<ParallaxLayer>,
	container: any,
	content: any,

	scrollTo: (offset: number) -> (),
	update: () -> (),
	stop: () -> (),

	_Api: any,
	_Styles: any,
}

export type ParallaxProperties = {
	config: any?,
	pages: number,
	horizontal: boolean?,
	children: React.ReactNode?,
	[string]: any,
}

export type StickyConfiguration = {
	finish: number?,
	start: number?,
}

export type ParallaxLayer = {
	horizontal: boolean,
	sticky: StickyConfiguration?,
	isSticky: boolean,

	setHeight: (height: number, immediate: boolean?) -> (),
	setPosition: (height: number, scrollTop: number, immediate: boolean?) -> (),
}

export type ParallaxLayerProperties = {
	horizontal: boolean?,
	-- Size of a page, (1 = 100%, 1.5 = 3/2, ...)
	factor: number?,
	-- Determines where the layer will be at when scrolled to (0=start, 1=1st page, ...)
	offset: number?,
	-- Shifts the layer in accordance to its offset, values can be positive or negative
	speed: number?,
	-- Layer will be sticky between these two offsets, all other props are ignored
	sticky: StickyConfiguration?,

	children: React.ReactNode?,
	[string]: any,
}

return false
