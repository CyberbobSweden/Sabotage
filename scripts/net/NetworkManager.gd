extends Node
class_name NetworkManager
## EXPERIMENTAL LAN multiplayer scaffolding (same Wi-Fi).
##
## This is a clean starting point for phone-to-phone play over a local network
## using Godot's high-level multiplayer (ENet). It is intentionally NOT wired
## into Main.gd yet, so the single-device game always runs. Integrate it when
## you are ready (see README "Multiplayer").
##
## Honest status: I could not run/test this in the build environment, so treat
## it as a documented foundation rather than finished netcode.

signal connected
signal hosted
signal peer_joined(id: int)
signal connection_failed

const DEFAULT_PORT := 9559
const MAX_CLIENTS := 1   ## 1 host + 1 client = 2 spies

func host_game(port: int = DEFAULT_PORT) -> bool:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		push_error("Could not host on port %d (err %d)" % [port, err])
		return false
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	hosted.emit()
	return true

func join_game(host_ip: String, port: int = DEFAULT_PORT) -> bool:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(host_ip, port)
	if err != OK:
		push_error("Could not connect to %s:%d (err %d)" % [host_ip, port, err])
		return false
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(func() -> void: connected.emit())
	multiplayer.connection_failed.connect(func() -> void: connection_failed.emit())
	return true

func _on_peer_connected(id: int) -> void:
	peer_joined.emit(id)

func is_host() -> bool:
	return multiplayer.is_server()

func disconnect_all() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

# ---------------------------------------------------------------------------
# INTEGRATION SKETCH
# ---------------------------------------------------------------------------
# The simplest reliable model for this game is HOST-AUTHORITATIVE:
#   * The host owns the GameState and runs all rules (Mansion + GameState).
#   * Each client only sends its intent each frame:
#         @rpc("any_peer", "unreliable_ordered")
#         func send_input(dir: float, act: bool, trap: bool, det: bool): ...
#     On the host, apply those to that peer's Spy via gs.move / gs.interact / ...
#   * The host broadcasts a small world snapshot ~20x/sec:
#         @rpc("authority", "unreliable_ordered")
#         func sync_state(packed: Dictionary): ...
#     Clients render from the latest snapshot (Renderer only reads state, so
#     this fits the existing architecture cleanly).
#
# For play over the INTERNET (not just same Wi-Fi) you additionally need NAT
# traversal or a relay: host port-forward DEFAULT_PORT, or use a relay such as
# Godot's WebRTC + a small signalling server, or a hosting service. Pure LAN
# (this file) needs no extra infrastructure.
