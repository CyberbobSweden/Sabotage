extends Node2D
## Main controller. Owns the GameState, feeds it input (human + AI + remote),
## and asks the Renderer to paint two split-screen panels (WHITE on top, BLACK
## below), mirroring the classic split-screen spy-duel layout.
##
## Phases:  MENU -> LOBBY -> PLAYING -> GAMEOVER -> MENU ...
## Modes:   "2P"  = two humans, one keyboard (hotseat)
##          "AI"  = human (player 1) vs computer spy   [phone friendly]
##          "NET" = two humans on two devices over LAN (host-authoritative)

enum Phase { MENU, LOBBY, PLAYING, GAMEOVER }

const SNAPSHOT_INTERVAL := 0.05   ## host broadcasts ~20x/sec

var phase: int = Phase.MENU
var mode: String = "AI"
var gs: GameState
var ais: Array[AIController] = []
var font: Font

var sound: SoundBank
var net: NetworkManager
var lobby_status: String = ""
var _snap_accum: float = 0.0

# Client-side sound diffing (snapshots carry no events).
var _cli_prev_finished := false
var _cli_prev_dying := {}      ## spy id -> was DYING last snapshot

# Touch-control state (drives the local player).
var touch_layer: CanvasLayer
var touch_left := false
var touch_right := false
var touch_act := false
var touch_trap := false
var touch_det := false

# Join screen (IP entry).
var net_ui_layer: CanvasLayer
var ip_edit: LineEdit

func _ready() -> void:
	randomize()
	font = ThemeDB.fallback_font

	sound = SoundBank.new()
	sound.name = "Sound"
	add_child(sound)

	net = NetworkManager.new()
	net.name = "Net"   # stable node path so RPCs line up on both peers
	add_child(net)
	net.client_joined.connect(_on_client_joined)
	net.connected_ok.connect(_on_connected_ok)
	net.conn_failed.connect(_on_conn_failed)
	net.peer_left.connect(_on_peer_left)

	_setup_input()
	_build_touch_ui()
	_build_net_ui()
	_goto_menu()

func _process(delta: float) -> void:
	match phase:
		Phase.PLAYING:
			_update_playing(delta)
		Phase.MENU:
			if Input.is_action_just_pressed("start_2p"):
				_start_local("2P")
			elif Input.is_action_just_pressed("start_ai"):
				_start_local("AI")
			elif Input.is_action_just_pressed("start_host"):
				_start_host()
			elif Input.is_action_just_pressed("start_join"):
				_open_join_screen()
		Phase.GAMEOVER:
			if Input.is_action_just_pressed("restart"):
				_goto_menu()
		Phase.LOBBY:
			# Client begins play as soon as the host's first snapshot lands.
			if net.is_client() and net.has_new_state():
				phase = Phase.PLAYING
	# Esc: from the menu it quits the app, elsewhere it backs out to the menu.
	if Input.is_action_just_pressed("quit"):
		if phase == Phase.MENU:
			get_tree().quit()
		else:
			_goto_menu()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	var tapped := (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if not tapped:
		return
	if phase == Phase.MENU:
		_start_local("AI")
	elif phase == Phase.GAMEOVER:
		_goto_menu()

# ---------------------------------------------------------------------------
# GAME FLOW
# ---------------------------------------------------------------------------
func _goto_menu() -> void:
	phase = Phase.MENU
	mode = "AI"
	ais.clear()
	gs = null
	net.shutdown()
	touch_layer.visible = false
	net_ui_layer.visible = false
	lobby_status = ""

func _make_gs(black_is_ai: bool) -> GameState:
	var g := Mansion.generate(5, 4)   # 20 rooms
	var white := Spy.new()
	white.id = 0; white.name = "WHITE"; white.is_white = true
	var black := Spy.new()
	black.id = 1; black.name = "BLACK"; black.is_white = false
	black.is_ai = black_is_ai
	g.add_spy(white)
	g.add_spy(black)
	g.sfx.connect(sound.play)
	return g

func _start_local(p_mode: String) -> void:
	mode = p_mode
	gs = _make_gs(mode == "AI")
	ais.clear()
	if mode == "AI":
		ais.append(AIController.new(gs, gs.get_spy(1)))
	phase = Phase.PLAYING
	touch_layer.visible = (mode == "AI")
	sound.play("select")

# --- networking entry points ---
func _start_host() -> void:
	if not net.host_game():
		lobby_status = "Could not start host"
		return
	mode = "NET"
	phase = Phase.LOBBY
	lobby_status = "Waiting for player...\nYour IP: %s\nPort: %d" % [net.local_ip(), NetworkManager.DEFAULT_PORT]
	touch_layer.visible = false
	sound.play("select")

func _on_client_joined() -> void:
	# Host is authoritative: build the world, then start and push first state.
	if not net.is_host():
		return
	gs = _make_gs(false)            # BLACK is the remote human, not AI
	ais.clear()
	_snap_accum = 0.0
	phase = Phase.PLAYING
	touch_layer.visible = true      # host controls WHITE; touch helps on phones
	net.push_state(gs.serialize())

func _open_join_screen() -> void:
	mode = "NET"
	phase = Phase.LOBBY
	lobby_status = "Enter host IP, then Connect"
	net_ui_layer.visible = true
	ip_edit.grab_focus()

func _do_join() -> void:
	var ip := ip_edit.text.strip_edges()
	if ip == "":
		lobby_status = "Type the host's IP first"
		return
	net_ui_layer.visible = false
	if not net.join_game(ip):
		lobby_status = "Could not connect to " + ip
		return
	lobby_status = "Connecting to %s ..." % ip

func _on_connected_ok() -> void:
	lobby_status = "Connected — waiting for game..."

func _on_conn_failed() -> void:
	lobby_status = "Connection failed"
	phase = Phase.LOBBY

func _on_peer_left() -> void:
	if phase == Phase.PLAYING or phase == Phase.LOBBY:
		lobby_status = "Other player disconnected"
		_goto_menu()

# ---------------------------------------------------------------------------
# PER-FRAME UPDATE
# ---------------------------------------------------------------------------
func _update_playing(delta: float) -> void:
	if mode == "NET":
		if net.is_host():
			_update_net_host(delta)
		else:
			_update_net_client(delta)
		return

	# Local single-device play.
	_update_human(gs.get_spy(0), "p1", true, delta)
	if mode == "2P":
		_update_human(gs.get_spy(1), "p2", false, delta)
	else:
		for ai in ais:
			ai.update(delta)
	gs.update(delta)
	if gs.finished:
		phase = Phase.GAMEOVER

func _update_net_host(delta: float) -> void:
	# Local human drives WHITE (spy 0).
	_update_human(gs.get_spy(0), "p1", true, delta)
	# Remote human drives BLACK (spy 1) from received intents.
	gs.move(1, net.remote_dir, delta)
	for a in net.take_remote_actions():
		match a:
			"act":  gs.interact(1)
			"trap": gs.place_trap(1)
			"det":  gs.detect(1)
	gs.update(delta)

	_snap_accum += delta
	if _snap_accum >= SNAPSHOT_INTERVAL:
		_snap_accum = 0.0
		net.push_state(gs.serialize())

	if gs.finished:
		net.push_state(gs.serialize())   # make sure the client sees the result
		phase = Phase.GAMEOVER

func _update_net_client(delta: float) -> void:
	# Send local intent (same controls as player 1) to the host for BLACK.
	var dir := 0.0
	if Input.is_action_pressed("p1_left") or touch_left:
		dir -= 1.0
	if Input.is_action_pressed("p1_right") or touch_right:
		dir += 1.0
	var act := Input.is_action_just_pressed("p1_action") or _consume_act()
	var trap := Input.is_action_just_pressed("p1_trap") or _consume_trap()
	var det := Input.is_action_just_pressed("p1_detect") or _consume_det()
	net.send_local_input(dir, act, trap, det)

	# Mirror the host's latest snapshot for rendering.
	if net.has_new_state():
		var snap := net.consume_state()
		if gs == null:
			gs = GameState.deserialize(snap)
			touch_layer.visible = true
		else:
			gs.apply_snapshot(snap)
		_client_snapshot_sounds()
	if gs != null and gs.finished:
		phase = Phase.GAMEOVER

## The client renders from snapshots (which carry no events), so we infer a few
## key sounds by watching what changed since the previous snapshot.
func _client_snapshot_sounds() -> void:
	if gs == null:
		return
	for spy in gs.spies:
		var dying := spy.state == Spy.State.DYING
		if dying and not bool(_cli_prev_dying.get(spy.id, false)):
			sound.play("death")
		_cli_prev_dying[spy.id] = dying
	if gs.finished and not _cli_prev_finished:
		sound.play("win")
	_cli_prev_finished = gs.finished

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
		Phase.LOBBY:    _draw_lobby()
		Phase.PLAYING:  _draw_playing()
		Phase.GAMEOVER: _draw_playing(); _draw_gameover()

func _draw_playing() -> void:
	if gs == null:
		return
	Renderer.draw_panel(self, font, gs, gs.get_spy(0), Rect2(2, 2, 316, 86))
	Renderer.draw_panel(self, font, gs, gs.get_spy(1), Rect2(2, 91, 316, 86))

func _draw_menu() -> void:
	_text(104, 26, "SABOTAGE!", 16, Palette.WHITE)
	_text(96, 41, "A RETRO SPY DUEL", 8, Palette.YELLOW)
	_text(64, 66, "[1]  TWO PLAYERS  (one keyboard)", 8, Palette.WHITE)
	_text(64, 79, "[2]  PLAYER vs A.I.   (or tap)", 8, Palette.LIGHT_GREEN)
	_text(64, 92, "[3]  HOST  LAN GAME", 8, Palette.CYAN)
	_text(64, 105, "[4]  JOIN  LAN GAME", 8, Palette.CYAN)
	_text(36, 128, "P1: A/D move  W act  S trap  Q detect", 8, Palette.LIGHT_GREY)
	_text(36, 140, "P2: <- -> move  Up act  Dn trap  / detect", 8, Palette.LIGHT_GREY)
	_text(60, 162, "Grab Briefcase, Passport, Key, Docs -> EXIT", 8, Palette.CYAN)

func _draw_lobby() -> void:
	draw_rect(Rect2(24, 50, 272, 80), Palette.BLACK, true)
	draw_rect(Rect2(24, 50, 272, 80), Palette.WHITE, false, 1.0)
	var role_txt := "HOST" if net.is_host() else "JOIN"
	_text(40, 68, "LAN GAME — " + role_txt, 10, Palette.YELLOW)
	var y := 84
	for line in lobby_status.split("\n"):
		_text(40, y, line, 8, Palette.WHITE)
		y += 11
	_text(40, 124, "Esc: back to menu", 8, Palette.LIGHT_GREY)

func _draw_gameover() -> void:
	draw_rect(Rect2(30, 60, 260, 60), Palette.BLACK, true)
	draw_rect(Rect2(30, 60, 260, 60), Palette.WHITE, false, 1.0)
	var title := "DRAW!"
	var col := Palette.YELLOW
	if gs != null and gs.winner != -1:
		var w := gs.get_spy(gs.winner)
		title = w.name + " WINS!"
		col = Palette.WHITE if w.is_white else Palette.LIGHT_BLUE
	_text(120, 82, title, 16, col)
	if gs != null:
		_text(60, 100, gs.finish_reason, 8, Palette.LIGHT_GREY)
	_text(96, 114, "Press R  /  tap to play again", 8, Palette.CYAN)

func _text(x: float, y: float, s: String, size: int, col: Color) -> void:
	draw_string(font, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

# ---------------------------------------------------------------------------
# INPUT MAP (built at runtime so project.godot stays simple & portable)
# ---------------------------------------------------------------------------
func _setup_input() -> void:
	_bind("p1_left",    [KEY_A])
	_bind("p1_right",   [KEY_D])
	_bind("p1_action",  [KEY_W])
	_bind("p1_trap",    [KEY_S])
	_bind("p1_detect",  [KEY_Q])
	_bind("p2_left",    [KEY_LEFT])
	_bind("p2_right",   [KEY_RIGHT])
	_bind("p2_action",  [KEY_UP])
	_bind("p2_trap",    [KEY_DOWN])
	_bind("p2_detect",  [KEY_SLASH])
	_bind("start_2p",   [KEY_1, KEY_KP_1])
	_bind("start_ai",   [KEY_2, KEY_KP_2])
	_bind("start_host", [KEY_3, KEY_KP_3])
	_bind("start_join", [KEY_4, KEY_KP_4])
	_bind("restart",    [KEY_R, KEY_ENTER, KEY_SPACE])
	_bind("quit",       [KEY_ESCAPE])

func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)

# ---------------------------------------------------------------------------
# TOUCH UI (local player, for phones)
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

# ---------------------------------------------------------------------------
# JOIN UI (IP entry for connecting to a host)
# ---------------------------------------------------------------------------
func _build_net_ui() -> void:
	net_ui_layer = CanvasLayer.new()
	add_child(net_ui_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	net_ui_layer.add_child(root)

	ip_edit = LineEdit.new()
	ip_edit.placeholder_text = "192.168.x.x"
	ip_edit.text = "192.168.1."
	ip_edit.set_anchors_preset(Control.PRESET_CENTER)
	ip_edit.offset_left = -120
	ip_edit.offset_right = 120
	ip_edit.offset_top = -4
	ip_edit.offset_bottom = 30
	root.add_child(ip_edit)
	ip_edit.text_submitted.connect(func(_t: String) -> void: _do_join())

	var connect_btn := Button.new()
	connect_btn.text = "CONNECT"
	connect_btn.focus_mode = Control.FOCUS_NONE
	connect_btn.set_anchors_preset(Control.PRESET_CENTER)
	connect_btn.offset_left = -50
	connect_btn.offset_right = 50
	connect_btn.offset_top = 40
	connect_btn.offset_bottom = 74
	root.add_child(connect_btn)
	connect_btn.pressed.connect(_do_join)

	net_ui_layer.visible = false
