extends RefCounted
class_name Mansion
## STEP 1 + STEP 2: procedural mansion generator.
## Builds a connected grid of rooms, scatters furniture, and hides the
## required mission items. Returns a fully populated GameState.
## This is *pure logic*: it never touches the renderer.

const REQUIRED_ITEMS: Array[String] = ["Briefcase", "Passport", "Key", "Documents"]

static func generate(cols: int = 5, rows: int = 4) -> GameState:
	var gs := GameState.new()
	gs.cols = cols
	gs.rows = rows
	gs.required_items = REQUIRED_ITEMS.duplicate()

	# --- create rooms ---
	for gy in rows:
		for gx in cols:
			var id := gy * cols + gx
			gs.rooms[id] = Room.new(id, gx, gy)

	_carve_doors(gs, cols, rows)
	_place_furniture(gs)

	# Start room top-left, exit room bottom-right.
	gs.start_room_id = 0
	gs.exit_room_id = cols * rows - 1
	gs.rooms[gs.exit_room_id].add_exit_door()

	_hide_items(gs)
	return gs

## Build a connected layout: a random spanning tree (guarantees you can
## reach every room) plus a few extra loops so it isn't a boring maze.
static func _carve_doors(gs: GameState, cols: int, rows: int) -> void:
	var total := cols * rows
	var visited := {}
	var stack: Array[int] = [0]
	visited[0] = true

	while not stack.is_empty():
		var current: int = stack[-1]
		var neighbours := _unvisited_neighbours(current, cols, rows, visited)
		if neighbours.is_empty():
			stack.pop_back()
		else:
			var pick: Array = neighbours[randi() % neighbours.size()]
			var nid: int = pick[0]
			var dir: int = pick[1]
			_link(gs, current, nid, dir)
			visited[nid] = true
			stack.append(nid)

	# Extra random connections (~18% of rooms) for loops.
	var extra := int(total * 0.18)
	for _i in extra:
		var a := randi() % total
		var dir := randi() % 4
		var b := _neighbour_in_dir(a, dir, cols, rows)
		if b != -1 and not gs.rooms[a].doors.has(dir):
			_link(gs, a, b, dir)

static func _link(gs: GameState, a: int, b: int, dir: int) -> void:
	gs.rooms[a].add_door(dir, b)
	gs.rooms[b].add_door(Room.opposite(dir), a)

static func _unvisited_neighbours(id: int, cols: int, rows: int, visited: Dictionary) -> Array:
	var out: Array = []
	for dir in 4:
		var nid := _neighbour_in_dir(id, dir, cols, rows)
		if nid != -1 and not visited.has(nid):
			out.append([nid, dir])
	return out

static func _neighbour_in_dir(id: int, dir: int, cols: int, rows: int) -> int:
	var gx := id % cols
	var gy := id / cols
	match dir:
		Room.N: gy -= 1
		Room.S: gy += 1
		Room.E: gx += 1
		Room.W: gx -= 1
	if gx < 0 or gx >= cols or gy < 0 or gy >= rows:
		return -1
	return gy * cols + gx

static func _place_furniture(gs: GameState) -> void:
	for id in gs.rooms.keys():
		var room: Room = gs.rooms[id]
		var count := randi_range(1, 3)
		# spread furniture evenly between lane 0.22 and 0.78
		var lanes := _spread(count, 0.22, 0.78)
		for i in count:
			var ftype: String = Furniture.TYPES[randi() % Furniture.TYPES.size()]
			room.furniture.append(Furniture.new(ftype, lanes[i]))

static func _spread(count: int, lo: float, hi: float) -> Array[float]:
	var out: Array[float] = []
	if count <= 1:
		out.append((lo + hi) * 0.5)
		return out
	var step := (hi - lo) / float(count - 1)
	for i in count:
		out.append(lo + step * i)
	return out

## Hide the four required items in random furniture, avoiding the start room
## so the player always has to explore.
static func _hide_items(gs: GameState) -> void:
	var candidates: Array[Furniture] = []
	for id in gs.rooms.keys():
		if id == gs.start_room_id:
			continue
		for f in gs.rooms[id].furniture:
			candidates.append(f)
	# Fallback: if somehow too few, allow start room too.
	if candidates.size() < gs.required_items.size():
		for f in gs.rooms[gs.start_room_id].furniture:
			candidates.append(f)
	candidates.shuffle()
	for i in gs.required_items.size():
		candidates[i].item = gs.required_items[i]
