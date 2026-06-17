extends RefCounted
class_name Renderer
## STEP 5: the rendering layer. Pure drawing helpers — they READ the
## GameState/Spy data and paint it, but never change any game state.
## Everything is drawn with primitives (no image assets) for a clean,
## self-contained C64-inspired look.

const PAD := 6

# Draw one player's split-screen panel: their room view + a small HUD.
static func draw_panel(ci: CanvasItem, font: Font, gs: GameState, viewer: Spy, rect: Rect2) -> void:
	# TV-screen frame
	ci.draw_rect(rect, Palette.BLACK, true)
	ci.draw_rect(rect, Palette.GREY, false, 1.0)

	var hud_w := 80.0
	var room_rect := Rect2(rect.position.x + 3, rect.position.y + 3,
		rect.size.x - hud_w - 6, rect.size.y - 6)
	var hud_rect := Rect2(rect.position.x + rect.size.x - hud_w, rect.position.y + 2,
		hud_w - 3, rect.size.y - 4)

	var room: Room = gs.rooms[viewer.room_id]
	_draw_room(ci, font, gs, room, viewer, room_rect)
	_draw_hud(ci, font, gs, viewer, hud_rect)

static func _draw_room(ci: CanvasItem, font: Font, gs: GameState, room: Room, viewer: Spy, r: Rect2) -> void:
	var wall := Palette.wall_for(room.id)
	var inset := 12.0
	var back := Rect2(r.position.x + inset, r.position.y + inset * 0.5,
		r.size.x - inset * 2.0, r.size.y - inset * 1.4)

	# ceiling, side walls, floor (perspective quads)
	_quad(ci, r.position, Vector2(r.end.x, r.position.y), back.position,
		Vector2(back.end.x, back.position.y), Palette.darken(wall, 0.15))            # ceiling
	_quad(ci, r.position, Vector2(r.position.x, r.end.y),
		Vector2(back.position.x, back.end.y), back.position, Palette.darken(wall, 0.30)) # left wall
	_quad(ci, Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y),
		Vector2(back.end.x, back.end.y), Vector2(back.end.x, back.position.y),
		Palette.darken(wall, 0.42))                                                  # right wall
	_quad(ci, Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y),
		Vector2(back.end.x, back.end.y), Vector2(back.position.x, back.end.y),
		Palette.darken(wall, 0.55))                                                  # floor
	ci.draw_rect(back, wall, true)                                                   # back wall

	# Where objects/spies stand:
	var walk_y: float = back.end.y + (r.end.y - back.end.y) * 0.42
	var lane_to_x := func(lane: float) -> float:
		return back.position.x + lane * back.size.x

	# Doors
	for dir in room.doors.keys():
		var info: Dictionary = room.doors[dir]
		var dx: float = lane_to_x.call(float(info["lane"]))
		var is_exit := dir == Room.EXIT_DIR
		_draw_door(ci, dx, walk_y, is_exit)
		var trap := room.door_trap(dir)
		if trap != null and trap.armed and trap.is_known_to(viewer.id):
			_draw_trap_marker(ci, font, trap, dx, walk_y - 18.0)

	# Furniture
	for f in room.furniture:
		var fx: float = lane_to_x.call(f.lane_x)
		_draw_furniture(ci, font, f, fx, walk_y)
		if f.has_trap() and f.trap.is_known_to(viewer.id):
			_draw_trap_marker(ci, font, f.trap, fx, walk_y - 16.0)

	# Spies that are in this room (other spy first, viewer on top)
	for spy in gs.spies:
		if spy.room_id != room.id or spy.id == viewer.id:
			continue
		_draw_spy(ci, font, spy, lane_to_x.call(spy.lane_x), walk_y)
	_draw_spy(ci, font, viewer, lane_to_x.call(viewer.lane_x), walk_y)

	# Floating message
	if viewer.msg != "":
		ci.draw_string(font, Vector2(r.position.x + 4, r.position.y + 10),
			viewer.msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.WHITE)

static func _draw_door(ci: CanvasItem, x: float, base_y: float, is_exit: bool) -> void:
	var w := 9.0
	var h := 18.0
	var col := Palette.YELLOW if is_exit else Palette.BROWN
	ci.draw_rect(Rect2(x - w * 0.5, base_y - h, w, h), col, true)
	ci.draw_rect(Rect2(x - w * 0.5, base_y - h, w, h), Palette.BLACK, false, 1.0)
	ci.draw_circle(Vector2(x + w * 0.25, base_y - h * 0.5), 1.0, Palette.BLACK)
	if is_exit:
		ci.draw_circle(Vector2(x, base_y - h - 2.0), 1.5, Palette.LIGHT_RED)

static func _draw_furniture(ci: CanvasItem, font: Font, f: Furniture, x: float, base_y: float) -> void:
	var col := Palette.BROWN if not f.searched else Palette.darken(Palette.BROWN, 0.3)
	var w := 12.0
	var h := 9.0
	match f.type:
		"Painting":
			ci.draw_rect(Rect2(x - 6, base_y - 22, 12, 9), Palette.RED, true)
			ci.draw_rect(Rect2(x - 6, base_y - 22, 12, 9), Palette.YELLOW, false, 1.0)
			return
		"Plant":
			ci.draw_rect(Rect2(x - 2, base_y - 6, 4, 6), Palette.ORANGE, true)
			ci.draw_circle(Vector2(x, base_y - 9), 4.0, Palette.GREEN)
			return
		"Safe":
			ci.draw_rect(Rect2(x - 6, base_y - 11, 12, 11), Palette.GREY, true)
			ci.draw_circle(Vector2(x, base_y - 5), 2.0, Palette.BLACK)
			return
		"Clock":
			ci.draw_rect(Rect2(x - 3, base_y - 16, 6, 16), Palette.BROWN, true)
			ci.draw_circle(Vector2(x, base_y - 13), 2.0, Palette.WHITE)
			return
	# default box-like furniture
	ci.draw_rect(Rect2(x - w * 0.5, base_y - h, w, h), col, true)
	ci.draw_rect(Rect2(x - w * 0.5, base_y - h, w, h), Palette.BLACK, false, 1.0)
	ci.draw_line(Vector2(x - w * 0.5, base_y - h * 0.5), Vector2(x + w * 0.5, base_y - h * 0.5),
		Palette.BLACK, 1.0)

static func _draw_trap_marker(ci: CanvasItem, font: Font, trap: TrapData, x: float, y: float) -> void:
	# Warning triangle, coloured per trap type, with a one-letter tag.
	var col := trap.marker_color()
	var p0 := Vector2(x, y - 4)
	var p1 := Vector2(x - 4, y + 3)
	var p2 := Vector2(x + 4, y + 3)
	ci.draw_colored_polygon(PackedVector2Array([p0, p1, p2]), col)
	ci.draw_polyline(PackedVector2Array([p0, p1, p2, p0]), Palette.BLACK, 1.0)
	ci.draw_string(font, Vector2(x - 2.0, y - 5.0), trap.tag(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 7, col)

static func _draw_spy(ci: CanvasItem, font: Font, spy: Spy, x: float, base_y: float) -> void:
	var body := Palette.WHITE if spy.is_white else Palette.DARK_GREY
	var outline := Palette.BLACK if spy.is_white else Palette.WHITE

	if spy.state == Spy.State.DYING:
		_draw_death(ci, font, spy, x, base_y, body)
		return

	# coat (trapezoid)
	var coat := PackedVector2Array([
		Vector2(x - 5, base_y), Vector2(x + 5, base_y),
		Vector2(x + 3, base_y - 9), Vector2(x - 3, base_y - 9),
	])
	ci.draw_colored_polygon(coat, body)
	var coat_closed := PackedVector2Array([coat[0], coat[1], coat[2], coat[3], coat[0]])
	ci.draw_polyline(coat_closed, outline, 1.0)
	# head
	ci.draw_circle(Vector2(x, base_y - 12), 2.6, body)
	# hat brim + crown
	ci.draw_rect(Rect2(x - 4, base_y - 14, 8, 1.5), body, true)
	ci.draw_rect(Rect2(x - 2.5, base_y - 17, 5, 3), body, true)
	# little eye showing facing
	ci.draw_circle(Vector2(x + spy.facing * 1.0, base_y - 12), 0.6, outline)

static func _draw_death(ci: CanvasItem, font: Font, spy: Spy, x: float, base_y: float, body: Color) -> void:
	# starburst
	for i in 8:
		var a := TAU * i / 8.0
		ci.draw_line(Vector2(x, base_y - 6),
			Vector2(x + cos(a) * 9.0, base_y - 6 + sin(a) * 9.0), Palette.YELLOW, 1.0)
	# crumpled spy
	ci.draw_rect(Rect2(x - 5, base_y - 3, 10, 3), body, true)
	ci.draw_string(font, Vector2(x - 12, base_y - 12), spy.death_line,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Palette.LIGHT_RED)

static func _draw_hud(ci: CanvasItem, font: Font, gs: GameState, spy: Spy, r: Rect2) -> void:
	ci.draw_rect(r, Palette.darken(Palette.BLUE, 0.4), true)
	ci.draw_rect(r, Palette.GREY, false, 1.0)
	var x := r.position.x + 4
	var y := r.position.y + 9

	var name_col := Palette.WHITE if spy.is_white else Palette.LIGHT_BLUE
	ci.draw_string(font, Vector2(x, y), spy.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, name_col)
	y += 11
	ci.draw_string(font, Vector2(x, y), _time_str(gs.time_left),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.YELLOW)
	y += 12

	# Inventory slots for the 4 required items.
	var letters := {"Briefcase": "B", "Passport": "P", "Key": "K", "Documents": "D"}
	var sx := x
	for item in gs.required_items:
		var have := spy.has_item(item)
		var box := Rect2(sx, y, 11, 11)
		ci.draw_rect(box, Palette.GREEN if have else Palette.DARK_GREY, true)
		ci.draw_rect(box, Palette.BLACK, false, 1.0)
		ci.draw_string(font, Vector2(sx + 2.5, y + 9), letters.get(item, "?"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.BLACK if have else Palette.GREY)
		sx += 13
		if sx > r.end.x - 12:
			sx = x
			y += 13
	y += 15
	ci.draw_string(font, Vector2(x, y), "Traps:" + str(spy.traps_left),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.LIGHT_RED)
	y += 11
	ci.draw_string(font, Vector2(x, y), "Trap>" + TrapData.TYPES[spy.selected_trap],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.WHITE)

static func _time_str(t: float) -> String:
	var s := int(maxf(t, 0.0))
	return "%d:%02d" % [s / 60, s % 60]

# --- small geometry helper: draw a filled quad from 4 points ---
static func _quad(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([a, b, c, d]), col)
