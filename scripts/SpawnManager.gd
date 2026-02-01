extends Node

signal murderer_changed(new_peer_id: int)

var murderer_peer_id: int = 0
var players: Dictionary = {} # peer_id -> NodePath

func _ready() -> void:
	get_tree().multiplayer.multiplayer_peer_connected.connect(_on_peer_connected)
	get_tree().multiplayer.multiplayer_peer_disconnected.connect(_on_peer_disconnected)

func register_player(peer_id: int, node_path: NodePath) -> void:
	players[peer_id] = node_path
	if get_tree().multiplayer.is_server() and murderer_peer_id == 0:
		set_murderer(peer_id)

func unregister_player(peer_id: int) -> void:
	players.erase(peer_id)
	if murderer_peer_id == peer_id:
		murderer_peer_id = 0
		for p in players.keys():
			set_murderer(p)
			break

@rpc("authority")
func set_murderer(peer_id: int) -> void:
	if not get_tree().multiplayer.is_server():
		return
	murderer_peer_id = peer_id
	rpc("notify_murderer_changed", murderer_peer_id)
	emit_signal("murderer_changed", murderer_peer_id)

@rpc("call_remote")
func notify_murderer_changed(peer_id: int) -> void:
	murderer_peer_id = peer_id
	emit_signal("murderer_changed", peer_id)

@rpc("authority")
func request_role_transfer(requester_id: int, previous_murderer_id: int, success: bool) -> void:
	if not get_tree().multiplayer.is_server():
		return
	if not success:
		return
	if requester_id == previous_murderer_id:
		return
	if not players.has(requester_id) or not players.has(previous_murderer_id):
		return
	murderer_peer_id = requester_id
	rpc("notify_murderer_changed", murderer_peer_id)
	emit_signal("murderer_changed", murderer_peer_id)

func _on_peer_connected(id: int) -> void:
	print("Peer connected: ", id)

func _on_peer_disconnected(id: int) -> void:
	print("Peer disconnected: ", id)
	unregister_player(id)
