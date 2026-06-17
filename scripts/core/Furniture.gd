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
