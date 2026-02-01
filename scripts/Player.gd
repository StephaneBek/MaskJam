extends CharacterBody2D

@export var speed: float = 160.0
@export var dodge_duration: float = 0.35
@export var dodge_window: float = 0.25
@export var charge_time: float = 0.45
@export var proximity_radius: float = 64.0

var is_murderer: bool = false
var is_dodging: bool = false
var last_attack_time: float = -100.0
var peer_id: int = 0

@onready var mask_sprite: Sprite2D = $MaskSprite
@onready var proximity_area: Area2D = $ProximityArea
@onready var anim: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	peer_id = get_tree().multiplayer.get_unique_id()
	var shape = proximity_area.get_node("CollisionShape2D").shape
	if shape and shape is CircleShape2D:
		shape.radius = proximity_radius
	proximity_area.body_entered.connect(_on_proximity_body_entered)
	proximity_area.body_exited.connect(_on_proximity_body_exited)
	if get_tree().multiplayer.is_server():
		get_tree().gameManager.register_player(peer_id, get_path())
	get_tree().gameManager.connect("murderer_changed", Callable(self, "_on_murderer_changed"))

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		_process_input(delta)

func _process_input(delta: float) -> void:
	var dir = Vector2.ZERO
	if Input.is_action_pressed("move_up"):
		dir.y -= 1
	if Input.is_action_pressed("move_down"):
		dir.y += 1
	if Input.is_action_pressed("move_left"):
		dir.x -= 1
	if Input.is_action_pressed("move_right"):
		dir.x += 1
	if dir != Vector2.ZERO:
		velocity = dir.normalized() * speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	if Input.is_action_just_pressed("dodge"):
		_start_dodge()

	if is_murderer and Input.is_action_just_pressed("attack"):
		if get_tree().multiplayer.is_server():
			var target_peer = _find_nearest_player_peer()
			if target_peer != 0 and target_peer != peer_id:
				perform_attack(peer_id, target_peer)
		else:
			rpc_id(1, "perform_attack", peer_id, _find_nearest_player_peer())

func _start_dodge() -> void:
	if is_dodging:
		return
	is_dodging = true
	if anim.has_animation("dodge"):
		anim.play("dodge")
	last_attack_time = Time.get_ticks_msec()
	var t = Timer.new()
	t.one_shot = true
	t.wait_time = dodge_duration
	add_child(t)
	t.timeout.connect(Callable(self, "_on_dodge_timeout"))
	t.start()
	rpc("notify_dodge_started", peer_id, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE)

@rpc("call_remote")
func notify_dodge_started(peer: int) -> void:
	pass

func _on_dodge_timeout() -> void:
	is_dodging = false
	if anim.has_animation("idle"):
		anim.play("idle")

func _on_proximity_body_entered(body: Node) -> void:
	if not get_tree().multiplayer.is_server():
		return
	if body.has_method("is_murderer") and body.is_murderer:
		var murderer_node = body
		rpc_id(murderer_node.get_multiplayer_authority(), "force_wear_mask")

func _on_proximity_body_exited(body: Node) -> void:
	pass

@rpc("call_remote")
func force_wear_mask() -> void:
	mask_sprite.visible = true
	if anim.has_animation("wear_mask"):
		anim.play("wear_mask")

@rpc("authority")
func perform_attack(attacker_id: int, target_peer_id: int) -> void:
	if not get_tree().multiplayer.is_server():
		return
	if get_tree().gameManager.murderer_peer_id != attacker_id:
		return
	last_attack_time = Time.get_ticks_msec()
	rpc("notify_attack_started", attacker_id, target_peer_id)
	await get_tree().create_timer(charge_time).timeout
	_resolve_attack(attacker_id, target_peer_id)

func _resolve_attack(attacker_id: int, target_peer_id: int) -> void:
	if not get_tree().gameManager.players.has(target_peer_id):
		rpc("notify_attack_result", attacker_id, target_peer_id, false)
		return
	var target_path = get_tree().gameManager.players[target_peer_id]
	var target_node = get_node_or_null(target_path)
	if target_node == null:
		rpc("notify_attack_result", attacker_id, target_peer_id, false)
		return
	var time_since_attack = Time.get_ticks_msec() - last_attack_time
	var dodge_success = target_node.is_dodging and time_since_attack <= dodge_window
	if dodge_success:
		get_tree().gameManager.request_role_transfer(target_peer_id, attacker_id, true)
		rpc("notify_attack_result", attacker_id, target_peer_id, true)
	else:
		rpc("notify_attack_result", attacker_id, target_peer_id, false)

@rpc("call_remote")
func notify_attack_started(attacker_id: int, target_peer_id: int) -> void:
	pass

@rpc("call_remote")
func notify_attack_result(attacker_id: int, target_peer_id: int, dodge_success: bool) -> void:
	if dodge_success:
		if get_tree().multiplayer.get_unique_id() == target_peer_id:
			is_murderer = true
			mask_sprite.visible = true
			if anim.has_animation("become_murderer"):
				anim.play("become_murderer")
		elif get_tree().multiplayer.get_unique_id() == attacker_id:
			is_murderer = false
			mask_sprite.visible = false
			if anim.has_animation("lost_murderer"):
				anim.play("lost_murderer")
	else:
		if get_tree().multiplayer.get_unique_id() == target_peer_id:
			if anim.has_animation("hit"):
				anim.play("hit")

@rpc("call_remote")
func client_setup_after_spawn(player_path: NodePath) -> void:
	var node = get_node_or_null(player_path)
	if node:
		var cam = get_tree().get_root().get_node_or_null("Main/MainCamera")
		if cam:
			cam.current = true
			cam.position = node.position

func _on_murderer_changed(new_peer_id: int) -> void:
	is_murderer = (new_peer_id == get_tree().multiplayer.get_unique_id())
	mask_sprite.visible = is_murderer
	var info = get_tree().get_root().get_node_or_null("Main/CanvasLayer/InfoLabel")
	if info:
		if info.text == is_murderer: "You are the Murderer" 
		else: "You are Innocent"

func _find_nearest_player_peer() -> int:
	var best_peer: int = 0
	var best_dist = 1e9
	for p in get_tree().gameManager.players.keys():
		if p == peer_id:
			continue
		var path = get_tree().gameManager.players[p]
		var node = get_node_or_null(path)
		if node == null:
			continue
		var d = global_position.distance_to(node.global_position)
		if d < best_dist:
			best_dist = d
			best_peer = p
	if best_dist <= 64.0:
		return best_peer
	return 0
