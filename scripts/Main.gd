extends Node2D

@onready var network = preload("res://scripts/Network.gd").new()
@onready var spawn_manager_scene: PackedScene = preload("res://scripts/SpawnManager.gd")

func _ready() -> void:
	$CanvasLayer/VBoxContainer/StartServerBtn.pressed.connect(Callable(self, "on_start_server_pressed"))
	$CanvasLayer/VBoxContainer/ConnectBtn.pressed.connect(Callable(self, "on_connect_pressed"))
	$CanvasLayer/VBoxContainer/HostEdit.text = "127.0.0.1"
	$CanvasLayer/InfoLabel.text = "Ready"

func on_start_server_pressed() -> void:
	network.start_server()
	if not has_node("SpawnManager"):
		var sm = spawn_manager_scene.instantiate()
		sm.name = "SpawnManager"
		add_child(sm)
	$CanvasLayer/InfoLabel.text = "Server started"

func on_connect_pressed() -> void:
	var host = $CanvasLayer/VBoxContainer/HostEdit.text.strip_edges()
	network.connect_to_server(host)
	$CanvasLayer/InfoLabel.text = "Connecting to %s" % host
