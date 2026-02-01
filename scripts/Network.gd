# scripts/Network.gd
extends Node

@export var port: int = 7777
var peer : ENetMultiplayerPeer

func start_server(max_clients: int = 8):
	peer = ENetMultiplayerPeer.new()
	peer.create_server(port, max_clients)
	get_tree().multiplayer.multiplayer_peer = peer
	print("Server started on port %d" % port)

func connect_to_server(host: String):
	peer = ENetMultiplayerPeer.new()
	peer.create_client(host, port)
	get_tree().multiplayer.multiplayer_peer = peer
	print("Connecting to %s:%d" % [host, port])
