extends RefCounted
class_name Spy
## A spy: the white one or the black one. Pure data.
## Movement/rules live in GameState; AI decisions in AIController.

enum State { ALIVE, DYING, READY }

var id: int = 0
var name: String = "WHITE"
var is_white: bool = true
var is_ai: bool = false

var room_id: int = 0
var lane_x: float = 0.5
var facing: int = 1               ## 1 = right, -1 = left
var inventory: Array[String] = []
var traps_left: int = 4
var selected_trap: int = 0        ## index into TrapData.TYPES

var state: int = State.ALIVE
var death_timer: float = 0.0
var death_line: String = ""

# Short on-screen message ("Found Key!", "Trap detected!", ...)
var msg: String = ""
var msg_timer: float = 0.0

# --- AI scratch data (ignored for human players) ---
var ai_decision_cd: float = 0.0
var ai_visited: Dictionary = {}   ## room_id -> times visited
var ai_target_lane: float = 0.5
var ai_intent: String = "explore"

func set_msg(text: String, t: float = 2.0) -> void:
	msg = text
	msg_timer = t

func is_alive() -> bool:
	return state == State.ALIVE

func has_item(item: String) -> bool:
	return item in inventory

func has_all(required: Array[String]) -> bool:
	for r in required:
		if r not in inventory:
			return false
	return true

# --- networking (dynamic per-spy state) ---
func to_dict() -> Dictionary:
	return {
		"id": id, "name": name, "is_white": is_white, "is_ai": is_ai,
		"room_id": room_id, "lane_x": lane_x, "facing": facing,
		"inventory": inventory.duplicate(), "traps_left": traps_left,
		"selected_trap": selected_trap, "state": state,
		"death_timer": death_timer, "death_line": death_line,
		"msg": msg, "msg_timer": msg_timer,
	}

func apply_dict(d: Dictionary) -> void:
	room_id = int(d.get("room_id", room_id))
	lane_x = float(d.get("lane_x", lane_x))
	facing = int(d.get("facing", facing))
	var inv: Array[String] = []
	for v in d.get("inventory", []):
		inv.append(String(v))
	inventory = inv
	traps_left = int(d.get("traps_left", traps_left))
	selected_trap = int(d.get("selected_trap", selected_trap))
	state = int(d.get("state", state))
	death_timer = float(d.get("death_timer", death_timer))
	death_line = String(d.get("death_line", death_line))
	msg = String(d.get("msg", msg))
	msg_timer = float(d.get("msg_timer", msg_timer))

static func from_dict(d: Dictionary) -> Spy:
	var s := Spy.new()
	s.id = int(d.get("id", 0))
	s.name = String(d.get("name", "WHITE"))
	s.is_white = bool(d.get("is_white", true))
	s.is_ai = bool(d.get("is_ai", false))
	s.apply_dict(d)
	return s
