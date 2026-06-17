extends Node2D
## Main controller. Owns the GameState, feeds it input (human + AI), and asks
## the Renderer to paint two split-screen panels (WHITE on top, BLACK below),
## mirroring the classic split-screen spy-duel layout.
##
## Phases:  MENU -> PLAYING -> GAMEOVER -> MENU ...
## Modes:   "2P"  = two humans, one keyboard (hotseat)
##          "AI"  = human (player 1) vs computer spy  [phone friendly]

enum Phase { MENU, PLAYING, GAMEOVER }

var phase: int = Phase.MENU
var mode: String = "AI"
var gs: GameState
var ais: Array[AIController] = []
var font: Font

# Touch-control state (drives player 1 only).
var touch_layer: CanvasLayer
var touch_left := false
var touch_right := false
var touch_act := false
var touch_trap := false
var touch_det := false

func _ready() -> void:
	randomize()
	font = ThemeDB.fallback_font
	_setup_input()
	_build_touch_ui()
	_goto_menu()

func _process(delta: float) -> void:
	match phase:
		Phase.PLAYING:
			_update_playing(delta)
		Phase.MENU:
			if Input.is_action_just_pressed("start_2p"):
				_start_game("2P")
			elif Input.is_action_just_pressed("start_ai"):
				_start_game("AI")
		Phase.GAMEOVER:
			if Input.is_action_just_pressed("restart"):
				_goto_menu()
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	# Tap support for phones (no keyboard).
	var tapped := (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if not tapped:
		return
	if phase == Phase.MENU:
		_start_game("AI")
	elif phase == Phase.GAMEOVER:
		_goto_menu()

# ---------------------------------------------------------------------------
# GAME FLOW
# ---------------------------------------------------------------------------
func _goto_menu() -> void:
	phase = Phase.MENU
	touch_layer.visible = false

func _start_game(p_mode: String) -> void:
	mode = p_mode
	gs = Mansion.generate(5, 4)   # 20 rooms

	var white := Spy.new()
	white.id = 0; white.name = "WHITE"; white.is_white = true
	var black := Spy.new()
	black.id = 1; black.name = "BLACK"; black.is_white = false
	black.is_ai = (mode == "AI")
	gs.add_spy(white)
	gs.add_spy(black)

	ais.clear()
	if black.is_ai:
		ais.append(AIController.new(gs, black))

	phase = Phase.PLAYING
	touch_layer.visible = (mode == "AI")

func _update_playing(delta: float) -> void:
	# Human player 1 (always WHITE), with touch enabled.
	_update_human(gs.get_spy(0), "p1", true, delta)
	# Player 2 is either a second human or AI.
	if mode == "2P":
		_update_human(gs.get_spy(1), "p2", false, delta)
	else:
		for ai in ais:
			ai.update(delta)

	gs.update(delta)
	if gs.finished:
		phase = Phase.GAMEOVER

func _update_human(spy: Spy, prefix: String, allow_touch: bool, delta: float) -> void:
	if spy == null:
		return
	var dir := 0.0
	if Input.is_action_pressed(prefix + "_left") or (allow_touch and touch_left):
		dir -= 1.0
	if Input.is_action_pressed(prefix + "_right") or (allow_touch and touch_right):
		dir += 1.0
	gs.move(spy.id, dir, delta)

	if Input.is_action_just_pressed(prefix + "_action") or (allow_touch and _consume_act()):
		gs.interact(spy.id)
	if Input.is_action_just_pressed(prefix + "_trap") or (allow_touch and _consume_trap()):
		gs.place_trap(spy.id)
	if Input.is_action_just_pressed(prefix + "_detect") or (allow_touch and _consume_det()):
		gs.detect(spy.id)

func _consume_act() -> bool:
	var v := touch_act; touch_act = false; return v
func _consume_trap() -> bool:
	var v := touch_trap; touch_trap = false; return v
func _consume_det() -> bool:
	var v := touch_det; touch_det = false; return v

# ---------------------------------------------------------------------------
# DRAWING
# ---------------------------------------------------------------------------
func _draw() -> void:
	draw_rect(Rect2(0, 0, 320, 180), Palette.BLUE, true)
	match phase:
		Phase.MENU:     _draw_menu()
		Phase.PLAYING:  _draw_playing()
		Phase.GAMEOVER: _draw_playing(); _draw_gameover()

func _draw_playing() -> void:
	if gs == null:
		return
	Renderer.draw_panel(self, font, gs, gs.get_spy(0), Rect2(2, 2, 316, 86))
	Renderer.draw_panel(self, font, gs, gs.get_spy(1), Rect2(2, 91, 316, 86))

func _draw_menu() -> void:
	_text(104, 34, "SABOTAGE!", 16, Palette.WHITE)
	_text(96, 50, "A RETRO SPY DUEL", 8, Palette.YELLOW)
	_text(70, 84, "[1]  TWO PLAYERS  (one keyboard)", 8, Palette.WHITE)
	_text(70, 98, "[2]  PLAYER vs A.I.   (or tap)", 8, Palette.LIGHT_GREEN)
	_text(40, 124, "P1: A/D move  W act  S trap  Q detect", 8, Palette.LIGHT_GREY)
	_text(40, 136, "P2: <- -> move  Up act  Dn trap  / detect", 8, Palette.LIGHT_GREY)
	_text(70, 158, "Grab Briefcase, Passport, Key, Docs -> EXIT", 8, Palette.CYAN)

func _draw_gameover() -> void:
	draw_rect(Rect2(30, 60, 260, 60), Palette.BLACK, true)
	draw_rect(Rect2(30, 60, 260, 60), Palette.WHITE, false, 1.0)
	var title := "DRAW!"
	var col := Palette.YELLOW
	if gs.winner != -1:
		var w := gs.get_spy(gs.winner)
		title = w.name + " WINS!"
		col = Palette.WHITE if w.is_white else Palette.LIGHT_BLUE
	_text(120, 82, title, 16, col)
	_text(60, 100, gs.finish_reason, 8, Palette.LIGHT_GREY)
	_text(96, 114, "Press R  /  tap to play again", 8, Palette.CYAN)

func _text(x: float, y: float, s: String, size: int, col: Color) -> void:
	draw_string(font, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

# ---------------------------------------------------------------------------
# INPUT MAP (built at runtime so project.godot stays simple & portable)
# ---------------------------------------------------------------------------
func _setup_input() -> void:
	_bind("p1_left",   [KEY_A])
	_bind("p1_right",  [KEY_D])
	_bind("p1_action", [KEY_W])
	_bind("p1_trap",   [KEY_S])
	_bind("p1_detect", [KEY_Q])
	_bind("p2_left",   [KEY_LEFT])
	_bind("p2_right",  [KEY_RIGHT])
	_bind("p2_action", [KEY_UP])
	_bind("p2_trap",   [KEY_DOWN])
	_bind("p2_detect", [KEY_SLASH])
	_bind("start_2p",  [KEY_1, KEY_KP_1])
	_bind("start_ai",  [KEY_2, KEY_KP_2])
	_bind("restart",   [KEY_R, KEY_ENTER, KEY_SPACE])
	_bind("quit",      [KEY_ESCAPE])

func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)

# ---------------------------------------------------------------------------
# TOUCH UI (player 1, for phones in vs-AI mode)
# ---------------------------------------------------------------------------
func _build_touch_ui() -> void:
	touch_layer = CanvasLayer.new()
	add_child(touch_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	touch_layer.add_child(root)

	var hold_l := _corner_btn("<", Control.PRESET_BOTTOM_LEFT, 16, 64)
	var hold_r := _corner_btn(">", Control.PRESET_BOTTOM_LEFT, 78, 64)
	var b_act := _corner_btn("ACT", Control.PRESET_BOTTOM_RIGHT, -78, 64)
	var b_trap := _corner_btn("TRAP", Control.PRESET_BOTTOM_RIGHT, -150, 64)
	var b_det := _corner_btn("SCAN", Control.PRESET_BOTTOM_RIGHT, -222, 64)
	for b in [hold_l, hold_r, b_act, b_trap, b_det]:
		root.add_child(b)

	hold_l.button_down.connect(func() -> void: touch_left = true)
	hold_l.button_up.connect(func() -> void: touch_left = false)
	hold_r.button_down.connect(func() -> void: touch_right = true)
	hold_r.button_up.connect(func() -> void: touch_right = false)
	b_act.pressed.connect(func() -> void: touch_act = true)
	b_trap.pressed.connect(func() -> void: touch_trap = true)
	b_det.pressed.connect(func() -> void: touch_det = true)

	touch_layer.visible = false

func _corner_btn(text: String, preset: int, ox: float, w: float) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.modulate = Color(1, 1, 1, 0.82)
	b.set_anchors_preset(preset)
	b.offset_left = ox
	b.offset_right = ox + w
	b.offset_top = -76
	b.offset_bottom = -16
	return b
