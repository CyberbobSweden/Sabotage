extends RefCounted
class_name TrapData
## A single trap. Pure data — knows nothing about how it is drawn.
##
## Six trap flavours. They all kill on contact unless disarmed, but they differ
## in their cartoon death line, their warning-marker colour, and how hard they
## are to spot (detect_difficulty influences the AI's scan behaviour).

const TYPES: Array[String] = ["Bomb", "Spring", "Drawer", "Gun", "Bucket", "Anvil"]

var type: String = "Bomb"      ## one of TYPES
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
		"Gun":    return "BANG!"
		"Bucket": return "SPLOOSH!"
		"Anvil":  return "CLONK!"
	return "SPLAT!"

## Colour of the warning marker once a trap is revealed (see Renderer).
func marker_color() -> Color:
	match type:
		"Bomb":   return Palette.LIGHT_RED
		"Spring": return Palette.CYAN
		"Drawer": return Palette.ORANGE
		"Gun":    return Palette.YELLOW
		"Bucket": return Palette.LIGHT_BLUE
		"Anvil":  return Palette.LIGHT_GREY
	return Palette.LIGHT_RED

## Single-letter tag drawn next to a revealed trap.
func tag() -> String:
	return type.substr(0, 1)

## How tricky the trap is to notice. Higher = the AI is more likely to walk
## into it. Humans always reveal on a successful scan regardless.
func detect_difficulty() -> float:
	match type:
		"Bomb":   return 0.0
		"Spring": return 0.1
		"Drawer": return 0.15
		"Gun":    return 0.25
		"Bucket": return 0.2
		"Anvil":  return 0.35
	return 0.0

# --- networking (host-authoritative LAN play) ---
func to_dict() -> Dictionary:
	return {"type": type, "owner_id": owner_id, "armed": armed, "known_by": known_by.duplicate()}

static func from_dict(d: Dictionary) -> TrapData:
	var t := TrapData.new(String(d.get("type", "Bomb")), int(d.get("owner_id", -1)))
	t.armed = bool(d.get("armed", true))
	var kb: Array[int] = []
	for v in d.get("known_by", []):
		kb.append(int(v))
	t.known_by = kb
	return t
