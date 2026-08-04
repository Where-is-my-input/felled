extends Node

const ROPE_SCENE = preload("res://scenes/rope.tscn")
const WAIT_FRAMES_TIMEOUT = 300  # ~5s at 60fps before giving up on a missing player

@onready var scene_root: Node = get_parent()

var connection_order: Array[int] = []

func _ready() -> void:
	if multiplayer.is_server():
		multiplayer.peer_connected.connect(_on_peer_connected)

# Called once by the server right after it spawns its own local player,
# since the server never receives a peer_connected signal for itself.
func register_initial_player(id: int) -> void:
	connection_order.append(id)

func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
	var previous_id: int = connection_order[-1] if connection_order.size() > 0 else -1
	connection_order.append(id)
	if previous_id != -1:
		_spawn_rope.rpc(previous_id, id)

@rpc("authority", "call_local", "reliable")
func _spawn_rope(id_a: int, id_b: int) -> void:
	var player_a: Node = await _wait_for_player(id_a)
	var player_b: Node = await _wait_for_player(id_b)
	if player_a == null or player_b == null:
		push_warning("Rope target missing, could not attach rope between %d and %d" % [id_a, id_b])
		return

	var rope: Node2D = ROPE_SCENE.instantiate()
	rope.name = "rope_%d_%d" % [id_a, id_b]
	scene_root.add_child(rope)
	rope.setup(player_a, player_b)

func _wait_for_player(id: int) -> Node:
	var player: Node = scene_root.get_node_or_null(str(id))
	var attempts := 0
	while player == null and attempts < WAIT_FRAMES_TIMEOUT:
		await get_tree().process_frame
		player = scene_root.get_node_or_null(str(id))
		attempts += 1
	return player
