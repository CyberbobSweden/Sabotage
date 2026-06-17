extends RefCounted
class_name Room
## One room of the mansion. Pure data + a few query helpers.
## Doors are stored by direction: 0=North, 1=East, 2=South, 3=West.

const N := 0
const E := 1
const S := 2
const W := 3
const EXIT_DIR := -1   ## the special "leave the mansion" door

var id: int = 0
var gx: int = 0
var gy: int = 0
var is_exit: bool = false
var furniture: Array[Furniture] = []
## doors[dir] = { "target": int, "lane": float, "back_lane": float }
var doors: Dictionary = {}
## door_traps[dir] = TrapData
var door_traps: Dictionary = {}

func _init(p_id: int, p_gx: int, p_gy: int) -> void:
	id = p_id
	gx = p_gx
	gy = p_gy

static func opposite(dir: int) -> int:
	match dir:
		N: return S
		S: return N
		E: return W
		W: return E
	return dir

static func lane_for_dir(dir: int) -> float:
	match dir:
		W: return 0.08
		E: return 0.92
		N: return 0.40
		S: return 0.62
		EXIT_DIR: return 0.50
	return 0.5

func add_door(dir: int, target_id: int) -> void:
	doors[dir] = {
		"target": target_id,
		"lane": lane_for_dir(dir),
		"back_lane": lane_for_dir(opposite(dir)),
	}

func add_exit_door() -> void:
	is_exit = true
	doors[EXIT_DIR] = { "target": -1, "lane": lane_for_dir(EXIT_DIR), "back_lane": 0.5 }

## Nearest furniture to a lane position, within threshold. null if none.
func nearest_furniture(lane: float, threshold: float = 0.09) -> Furniture:
	var best: Furniture = null
	var best_d := threshold
	for f in furniture:
		var d: float = absf(f.lane_x - lane)
		if d <= best_d:
			best_d = d
			best = f
	return best

## Nearest door direction to a lane position, within threshold. EXIT_DIR
## counts as a door. Returns a very large int (999) if nothing is close.
func nearest_door(lane: float, threshold: float = 0.09) -> int:
	var best := 999
	var best_d := threshold
	for dir in doors.keys():
		var info: Dictionary = doors[dir]
		var d: float = absf(float(info["lane"]) - lane)
		if d <= best_d:
			best_d = d
			best = dir
	return best

func door_trap(dir: int) -> TrapData:
	return door_traps.get(dir, null)
