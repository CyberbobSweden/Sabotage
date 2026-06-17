extends RefCounted
class_name Palette
## Commodore 64 inspired 16-colour palette.
## Used everywhere so the whole game shares one cohesive retro look.

const BLACK      := Color(0.000, 0.000, 0.000)
const WHITE      := Color(1.000, 1.000, 1.000)
const RED        := Color(0.533, 0.000, 0.000)
const CYAN       := Color(0.667, 1.000, 0.933)
const PURPLE     := Color(0.800, 0.267, 0.800)
const GREEN      := Color(0.000, 0.800, 0.333)
const BLUE       := Color(0.000, 0.000, 0.667)
const YELLOW     := Color(0.933, 0.933, 0.467)
const ORANGE     := Color(0.867, 0.533, 0.333)
const BROWN      := Color(0.400, 0.267, 0.000)
const LIGHT_RED  := Color(1.000, 0.467, 0.467)
const DARK_GREY  := Color(0.200, 0.200, 0.200)
const GREY       := Color(0.467, 0.467, 0.467)
const LIGHT_GREEN:= Color(0.667, 1.000, 0.400)
const LIGHT_BLUE := Color(0.000, 0.533, 1.000)
const LIGHT_GREY := Color(0.733, 0.733, 0.733)

## A set of wall colours rooms cycle through, so each room feels distinct
## (varied room colours for a retro mansion feel).
const WALL_COLORS: Array[Color] = [
	Color(0.800, 0.267, 0.800), # purple
	Color(0.000, 0.800, 0.333), # green
	Color(0.000, 0.533, 1.000), # light blue
	Color(0.867, 0.533, 0.333), # orange
	Color(0.667, 1.000, 0.933), # cyan
	Color(0.933, 0.933, 0.467), # yellow
]

static func wall_for(room_id: int) -> Color:
	return WALL_COLORS[room_id % WALL_COLORS.size()]

## Returns a darker shade of any colour, used for floors / shadows.
static func darken(c: Color, amount: float = 0.45) -> Color:
	return Color(c.r * (1.0 - amount), c.g * (1.0 - amount), c.b * (1.0 - amount), c.a)
