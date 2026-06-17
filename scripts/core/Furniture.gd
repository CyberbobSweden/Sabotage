extends RefCounted
class_name Furniture
## A searchable piece of furniture inside a room. Pure data.

const TYPES: Array[String] = [
	"Cabinet", "Drawer", "Painting", "Safe", "Couch", "Plant", "Desk", "Clock",
]

var type: String = "Cabinet"
var lane_x: float = 0.5          ## horizontal position in the room, 0..1
var searched: bool = false
var item: String = ""            ## hidden mission item, "" if none
var trap: TrapData = null        ## a planted trap, or null

func _init(p_type: String = "Cabinet", p_lane: float = 0.5) -> void:
	type = p_type
	lane_x = p_lane

func has_trap() -> bool:
	return trap != null and trap.armed

# --- networking ---
func to_dict() -> Dictionary:
	return {
		"type": type, "lane_x": lane_x, "searched": searched, "item": item,
		"trap": trap.to_dict() if trap != null else null,
	}

static func from_dict(d: Dictionary) -> Furniture:
	var f := Furniture.new(String(d.get("type", "Cabinet")), float(d.get("lane_x", 0.5)))
	f.searched = bool(d.get("searched", false))
	f.item = String(d.get("item", ""))
	var td = d.get("trap", null)
	f.trap = TrapData.from_dict(td) if td != null else null
	return f
