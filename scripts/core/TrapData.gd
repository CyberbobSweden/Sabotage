extends RefCounted
class_name TrapData
## A single trap. Pure data — knows nothing about how it is drawn.

const TYPES: Array[String] = ["Bomb", "Spring", "Drawer"]

var type: String = "Bomb"     ## one of TYPES (Drawer = "exploding drawer")
var owner_id: int = -1         ## which spy planted it
var armed: bool = true
var known_by: Array[int] = []  ## spy ids that have detected this trap

func _init(p_type: String = "Bomb", p_owner: int = -1) -> void:
	type = p_type
	owner_id = p_owner

func is_known_to(spy_id: int) -> bool:
	return spy_id in known_by

func reveal_to(spy_id: int) -> void:
	if spy_id not in known_by:
		known_by.append(spy_id)

## A short cartoon death line for when this trap goes off.
func death_line() -> String:
	match type:
		"Bomb":   return "BOOM!"
		"Spring": return "SPROING!"
		"Drawer": return "KABLAM!"
	return "SPLAT!"
