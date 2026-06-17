extends RefCounted
class_name GameState
## The single source of truth for a match. ALL game rules live here so that
## both the human input handler (Main) and the AIController call the exact
## same functions. The renderer only ever *reads* from this object.

signal event(text: String)   ## fired for notable moments (death, win, found item)

const MOVE_SPEED := 0.55      ## lane units per second
const REACH := 0.09           ## how close you must be to interact
const RESPAWN_TIME := 1.6
const START_TIME := 300.0     ## seconds on the clock

var rooms: Dictionary = {}            ## id -> Room
var spies: Array[Spy] = []
var required_items: Array[String] = []
var cols: int = 5
var rows: int = 4
var start_room_id: int = 0
var exit_room_id: int = 0

var time_left: float = START_TIME
var winner: int = -1                  ## spy id, or -1 = no winner yet
var finished: bool = false
var finish_reason: String = ""

func add_spy(spy: Spy) -> void:
	spy.room_id = start_room_id
	spy.lane_x = 0.4 + 0.2 * spy.id    ## offset so they don't overlap
	spies.append(spy)

func get_spy(id: int) -> Spy:
	for s in spies:
		if s.id == id:
			return s
	return null

func room_of(spy: Spy) -> Room:
	return rooms[spy.room_id]

# ---------------------------------------------------------------------------
# MOVEMENT
# ---------------------------------------------------------------------------
func move(spy_id: int, dir: float, delta: float) -> void:
	var spy := get_spy(spy_id)
	if spy == null or not spy.is_alive() or finished:
		return
	if dir == 0.0:
		return
	spy.facing = 1 if dir > 0.0 else -1
	spy.lane_x = clampf(spy.lane_x + dir * MOVE_SPEED * delta, 0.0, 1.0)

# ---------------------------------------------------------------------------
# INTERACT  (context action: search furniture / use door / leave)
# ---------------------------------------------------------------------------
func interact(spy_id: int) -> void:
	var spy := get_spy(spy_id)
	if spy == null or not spy.is_alive() or finished:
		return
	var room := room_of(spy)
	var f := room.nearest_furniture(spy.lane_x, REACH)
	var dir := room.nearest_door(spy.lane_x, REACH)

	# Prefer whichever is closest.
	var f_d := 99.0
	var d_d := 99.0
	if f != null:
		f_d = absf(f.lane_x - spy.lane_x)
	if dir != 999:
		d_d = absf(float(room.doors[dir]["lane"]) - spy.lane_x)

	if f != null and f_d <= d_d:
		_search_furniture(spy, f)
	elif dir != 999:
		_use_door(spy, room, dir)

func _search_furniture(spy: Spy, f: Furniture) -> void:
	if f.has_trap():
		if f.trap.is_known_to(spy.id):
			spy.set_msg("Disarm it first!")
			return
		_kill(spy, f.trap)
		f.trap = null
		return
	if not f.searched:
		f.searched = true
		if f.item != "":
			spy.inventory.append(f.item)
			spy.set_msg("Found " + f.item + "!")
			event.emit(spy.name + " found the " + f.item)
		else:
			spy.set_msg("Nothing here...")
	else:
		spy.set_msg("Already searched")

func _use_door(spy: Spy, room: Room, dir: int) -> void:
	if dir == Room.EXIT_DIR:
		_try_exit(spy)
		return
	var trap := room.door_trap(dir)
	if trap != null and trap.armed:
		if trap.is_known_to(spy.id):
			spy.set_msg("Disarm it first!")
			return
		_kill(spy, trap)
		room.door_traps.erase(dir)
		return
	# Travel to the neighbour room.
	var info: Dictionary = room.doors[dir]
	spy.room_id = int(info["target"])
	spy.lane_x = float(info["back_lane"])

func _try_exit(spy: Spy) -> void:
	if spy.has_all(required_items):
		winner = spy.id
		finished = true
		finish_reason = spy.name + " escaped with everything!"
		event.emit(finish_reason)
	else:
		var missing := required_items.size() - spy.inventory.size()
		spy.set_msg("Need " + str(missing) + " more item(s)!")

# ---------------------------------------------------------------------------
# TRAPS  (Step 3)
# ---------------------------------------------------------------------------
func place_trap(spy_id: int) -> void:
	var spy := get_spy(spy_id)
	if spy == null or not spy.is_alive() or finished or spy.traps_left <= 0:
		if spy != null and spy.traps_left <= 0:
			spy.set_msg("Out of traps")
		return
	var room := room_of(spy)
	var f := room.nearest_furniture(spy.lane_x, REACH)
	var dir := room.nearest_door(spy.lane_x, REACH)
	var ttype: String = TrapData.TYPES[spy.selected_trap]

	if f != null:
		if f.has_trap():
			spy.set_msg("Already trapped")
			return
		f.trap = TrapData.new(ttype, spy.id)
		spy.traps_left -= 1
		spy.selected_trap = (spy.selected_trap + 1) % TrapData.TYPES.size()
		spy.set_msg("Planted " + ttype)
	elif dir != 999 and dir != Room.EXIT_DIR:
		if room.door_trap(dir) != null:
			spy.set_msg("Already trapped")
			return
		room.door_traps[dir] = TrapData.new(ttype, spy.id)
		spy.traps_left -= 1
		spy.selected_trap = (spy.selected_trap + 1) % TrapData.TYPES.size()
		spy.set_msg("Trapped door")
	else:
		spy.set_msg("Stand by furniture/door")

## DETECT / DISARM. First press on a hidden trap reveals it; a second press
## on a revealed trap disarms it (and returns a trap to your pocket).
func detect(spy_id: int) -> void:
	var spy := get_spy(spy_id)
	if spy == null or not spy.is_alive() or finished:
		return
	var room := room_of(spy)
	var f := room.nearest_furniture(spy.lane_x, REACH)
	var dir := room.nearest_door(spy.lane_x, REACH)

	var trap: TrapData = null
	var on_furniture := false
	if f != null and f.has_trap():
		trap = f.trap
		on_furniture = true
	elif dir != 999 and room.door_trap(dir) != null:
		trap = room.door_trap(dir)

	if trap == null:
		spy.set_msg("All clear")
		return
	if not trap.is_known_to(spy.id):
		trap.reveal_to(spy.id)
		spy.set_msg("Trap detected!")
	else:
		# Disarm it.
		if on_furniture:
			f.trap = null
		else:
			room.door_traps.erase(dir)
		spy.traps_left += 1
		spy.set_msg("Trap disarmed")

# ---------------------------------------------------------------------------
# DEATH & RESPAWN  (cartoon deaths)
# ---------------------------------------------------------------------------
func _kill(spy: Spy, trap: TrapData) -> void:
	spy.state = Spy.State.DYING
	spy.death_timer = RESPAWN_TIME
	spy.death_line = trap.death_line()
	event.emit(spy.name + " got " + trap.type.to_lower() + "ed! " + trap.death_line())
	# Drop everything you were carrying — items get re-hidden so they can be
	# found again, which keeps long matches interesting.
	_drop_inventory(spy)

func _drop_inventory(spy: Spy) -> void:
	if spy.inventory.is_empty():
		return
	var all_furniture: Array[Furniture] = []
	for id in rooms.keys():
		for f in rooms[id].furniture:
			all_furniture.append(f)
	for item in spy.inventory:
		var f: Furniture = all_furniture[randi() % all_furniture.size()]
		f.item = item
		f.searched = false
	spy.inventory.clear()

# ---------------------------------------------------------------------------
# PER-FRAME UPDATE: timers, respawns, clock, win-by-time
# ---------------------------------------------------------------------------
func update(delta: float) -> void:
	if finished:
		return
	time_left -= delta
	if time_left <= 0.0:
		_finish_by_time()
		return
	for spy in spies:
		if spy.msg_timer > 0.0:
			spy.msg_timer -= delta
			if spy.msg_timer <= 0.0:
				spy.msg = ""
		if spy.state == Spy.State.DYING:
			spy.death_timer -= delta
			if spy.death_timer <= 0.0:
				_respawn(spy)

func _respawn(spy: Spy) -> void:
	spy.state = Spy.State.ALIVE
	spy.room_id = start_room_id
	spy.lane_x = 0.5
	spy.death_line = ""
	spy.set_msg("Respawned", 1.0)

func _finish_by_time() -> void:
	finished = true
	# Most items collected wins; tie = draw.
	var best := -1
	var best_count := -1
	var tie := false
	for spy in spies:
		var c := spy.inventory.size()
		if c > best_count:
			best_count = c
			best = spy.id
			tie = false
		elif c == best_count:
			tie = true
	if tie:
		winner = -1
		finish_reason = "Time up — it's a draw!"
	else:
		winner = best
		finish_reason = "Time up — most loot wins!"
	event.emit(finish_reason)

# ---------------------------------------------------------------------------
# PATHFINDING helper (used by the AI). BFS over the door graph.
# Returns the door direction to take from `from_id` to step toward `to_id`,
# or 999 if unreachable / already there.
# ---------------------------------------------------------------------------
func next_dir_towards(from_id: int, to_id: int) -> int:
	if from_id == to_id:
		return 999
	var came_from := {from_id: -1}
	var came_dir := {}
	var queue: Array[int] = [from_id]
	while not queue.is_empty():
		var cur: int = queue.pop_front()
		if cur == to_id:
			break
		for dir in rooms[cur].doors.keys():
			if dir == Room.EXIT_DIR:
				continue
			var nxt: int = int(rooms[cur].doors[dir]["target"])
			if not came_from.has(nxt):
				came_from[nxt] = cur
				came_dir[nxt] = dir
				queue.append(nxt)
	if not came_from.has(to_id):
		return 999
	# Walk back from target to the room right after `from_id`.
	var node := to_id
	while came_from[node] != from_id:
		node = came_from[node]
		if node == -1:
			return 999
	return came_dir[node]
