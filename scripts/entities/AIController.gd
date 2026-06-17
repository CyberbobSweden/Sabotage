extends RefCounted
class_name AIController
## STEP 4: the AI spy. A small state machine that drives a Spy by calling the
## very same GameState methods a human would. It never reaches into rendering.
##
## Intents: "explore" -> "search" -> "collect" -> "escape", with opportunistic
## trap-planting and trap-avoidance mixed in.

const DECISION_INTERVAL := 0.35   ## how often it re-evaluates
const DETECT_CHANCE := 0.7        ## chance to scan a station before using it
const TRAP_CHANCE := 0.25         ## chance to plant a trap after searching

var gs: GameState
var spy: Spy

func _init(p_gs: GameState, p_spy: Spy) -> void:
	gs = p_gs
	spy = p_spy

func update(delta: float) -> void:
	if not spy.is_alive() or gs.finished:
		return

	spy.ai_decision_cd -= delta
	var room: Room = gs.room_of(spy)

	# Always drift toward a chosen lane target; act when we arrive.
	if spy.ai_decision_cd <= 0.0:
		spy.ai_decision_cd = DECISION_INTERVAL
		_choose_target(room)

	_move_toward(spy.ai_target_lane, delta)
	_act_if_arrived(room)

func _choose_target(room: Room) -> void:
	spy.ai_visited[spy.room_id] = int(spy.ai_visited.get(spy.room_id, 0)) + 1

	# 1) If we have everything, head for the exit.
	if spy.has_all(gs.required_items):
		spy.ai_intent = "escape"
		_target_exit(room)
		return

	# 2) If there is unsearched furniture here, go search it.
	var target := _nearest_unsearched(room)
	if target != null:
		spy.ai_intent = "search"
		spy.ai_target_lane = target.lane_x
		return

	# 3) Otherwise move to a less-explored neighbouring room.
	spy.ai_intent = "explore"
	_target_explore_door(room)

func _target_exit(room: Room) -> void:
	if room.is_exit:
		spy.ai_target_lane = Room.lane_for_dir(Room.EXIT_DIR)
		return
	var dir := gs.next_dir_towards(spy.room_id, gs.exit_room_id)
	if dir != 999 and room.doors.has(dir):
		spy.ai_target_lane = float(room.doors[dir]["lane"])
	else:
		spy.ai_intent = "explore"
		_target_explore_door(room)

func _target_explore_door(room: Room) -> void:
	var best_dir := 999
	var best_visits := 1 << 30
	for dir in room.doors.keys():
		if dir == Room.EXIT_DIR:
			continue
		var tgt: int = int(room.doors[dir]["target"])
		var v: int = int(spy.ai_visited.get(tgt, 0))
		# Skip doors with traps we already know about.
		var t := room.door_trap(dir)
		if t != null and t.armed and t.is_known_to(spy.id):
			continue
		if v < best_visits:
			best_visits = v
			best_dir = dir
	if best_dir != 999:
		spy.ai_target_lane = float(room.doors[best_dir]["lane"])
	else:
		spy.ai_target_lane = randf()   # wander if boxed in

func _nearest_unsearched(room: Room) -> Furniture:
	var best: Furniture = null
	var best_d := 2.0
	for f in room.furniture:
		if f.searched and not f.has_trap():
			continue
		var d: float = absf(f.lane_x - spy.lane_x)
		if d < best_d:
			best_d = d
			best = f
	return best

func _move_toward(target: float, delta: float) -> void:
	var diff := target - spy.lane_x
	if absf(diff) < 0.01:
		return
	gs.move(spy.id, signf(diff), delta)

func _act_if_arrived(room: Room) -> void:
	# Are we standing on the station we were heading for?
	var f := room.nearest_furniture(spy.lane_x, GameState.REACH)
	var dir := room.nearest_door(spy.lane_x, GameState.REACH)

	# Be cautious: sometimes scan for a trap before touching anything.
	if randf() < DETECT_CHANCE * 0.15:
		gs.detect(spy.id)

	if spy.ai_intent == "search" and f != null:
		# Don't blunder into a trap we know about.
		if f.has_trap() and f.trap.is_known_to(spy.id):
			gs.detect(spy.id)  # disarm it
			return
		if f.has_trap() and randf() < (DETECT_CHANCE - f.trap.detect_difficulty()):
			gs.detect(spy.id)  # may reveal then avoid next tick
			return
		gs.interact(spy.id)
		# Occasionally booby-trap what we just left behind.
		if randf() < TRAP_CHANCE and spy.traps_left > 0:
			gs.place_trap(spy.id)
		return

	if (spy.ai_intent == "explore" or spy.ai_intent == "escape") and dir != 999:
		var trap: TrapData = null
		if dir != Room.EXIT_DIR:
			trap = room.door_trap(dir)
		if trap != null and trap.armed:
			if trap.is_known_to(spy.id):
				gs.detect(spy.id)  # disarm
				return
			if randf() < (DETECT_CHANCE - trap.detect_difficulty()):
				gs.detect(spy.id)
				return
		gs.interact(spy.id)
