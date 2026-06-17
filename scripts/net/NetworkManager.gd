extends Node
class_name NetworkManager
## LAN multiplayer (same Wi-Fi), host-authoritative.
##
## MODEL
##   * HOST owns the real GameState and runs every rule (Mansion + GameState +
##     AI if any). It controls WHITE (spy 0).
##   * CLIENT controls BLACK (spy 1). It does NOT run game rules. Each frame it
##     sends its intent to the host and renders from the host's snapshots.
##   * The host serialises a full snapshot ~20x/sec and broadcasts it. Because
##     the Renderer only ever READS the GameState, the client mirrors and draws
##     it with no extra work.
##
## HONEST STATUS: written carefully but NOT tested on real devices in this
## environment. LAN netcode usually needs a tweak or two on first contact —
## if something misbehaves, this is the place to look. Single-device modes
## (2P hotseat / vs-AI) are unaffected by any of this.

signal client_joined          ## host: a client connected
signal connected_ok           ## client: reached the host
signal conn_failed            ## client: could not reach the host
signal peer_left              ## either side: the other dropped

const DEFAULT_PORT := 9559
const MAX_CLIENTS := 1         ## 1 host + 1 client = 2 spies

var role: String = "none"      ## "host" | "client" | "none"

# Host-side: latest intent received from the client.
var remote_dir: float = 0.0
var _remote_actions: Array[String] = []

# Client-side: latest world snapshot received from the host.
var _latest_state: Dictionary = {}
var _has_new_state := false

func _ready() -> void:
	# Connect the MultiplayerAPI signals once; they cover both host and client.
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(func() -> void: connected_ok.emit())
	multiplayer.connection_failed.connect(func() -> void: conn_failed.emit())
	multiplayer.server_disconnected.connect(func() -> void: peer_left.emit())

# ---------------------------------------------------------------------------
# CONNECTION SETUP
# ---------------------------------------------------------------------------
func host_game(port: int = DEFAULT_PORT) -> bool:
	_reset_peer()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		push_error("Sabotage: could not host on port %d (err %d)" % [port, err])
		return false
	multiplayer.multiplayer_peer = peer
	role = "host"
	return true

func join_game(host_ip: String, port: int = DEFAULT_PORT) -> bool:
	_reset_peer()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(host_ip, port)
	if err != OK:
		push_error("Sabotage: could not connect to %s:%d (err %d)" % [host_ip, port, err])
		return false
	multiplayer.multiplayer_peer = peer
	role = "client"
	return true

func shutdown() -> void:
	_reset_peer()
	role = "none"
	remote_dir = 0.0
	_remote_actions.clear()
	_latest_state = {}
	_has_new_state = false

func _reset_peer() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

func is_host() -> bool:
	return role == "host"

func is_client() -> bool:
	return role == "client"

func _on_peer_connected(_id: int) -> void:
	client_joined.emit()

func _on_peer_disconnected(_id: int) -> void:
	peer_left.emit()

## First non-loopback IPv4 address, shown to the host so the client knows where
## to connect.
func local_ip() -> String:
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254"):
			return a
	return "127.0.0.1"

# ---------------------------------------------------------------------------
# CLIENT -> HOST : input intent
# Movement is continuous (sent unreliably every frame); actions are one-shots
# (sent reliably so a trap-plant is never lost).
# ---------------------------------------------------------------------------
func send_local_input(dir: float, act: bool, trap: bool, det: bool) -> void:
	if not is_client():
		return
	rpc_id(1, "_recv_move", dir)
	if act:
		rpc_id(1, "_recv_action", "act")
	if trap:
		rpc_id(1, "_recv_action", "trap")
	if det:
		rpc_id(1, "_recv_action", "det")

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _recv_move(dir: float) -> void:
	remote_dir = dir

@rpc("any_peer", "call_remote", "reliable", 2)
func _recv_action(kind: String) -> void:
	_remote_actions.append(kind)

## Host reads-and-clears the queued client actions for this frame.
func take_remote_actions() -> Array[String]:
	var a: Array[String] = []
	for s in _remote_actions:
		a.append(s)
	_remote_actions.clear()
	return a

# ---------------------------------------------------------------------------
# HOST -> CLIENT : world snapshot
# ---------------------------------------------------------------------------
func push_state(state: Dictionary) -> void:
	if not is_host():
		return
	rpc("_recv_state", state)

@rpc("authority", "call_remote", "reliable", 3)
func _recv_state(state: Dictionary) -> void:
	_latest_state = state
	_has_new_state = true

func has_new_state() -> bool:
	return _has_new_state

func consume_state() -> Dictionary:
	_has_new_state = false
	return _latest_state

# ---------------------------------------------------------------------------
# INTERNET PLAY (beyond LAN)
# Same-Wi-Fi needs no extra setup. To play across the internet you additionally
# need either port-forwarding of DEFAULT_PORT on the host's router, or a relay
# (e.g. Godot WebRTC + a small signalling server, or a hosting service). The
# host-authoritative design above is unchanged either way.
# ---------------------------------------------------------------------------
