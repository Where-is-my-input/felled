extends Node

const ROPE_SCENE = preload("res://scenes/rope.tscn")
const WAIT_FRAMES_TIMEOUT = 300  # ~5s at 60fps before giving up on a missing player

# Mirrors every tunable on rope.gd, applied to every rope this manager
# creates — one place to configure rope feel instead of editing rope.tscn
# directly. Also what rope_settings_panel.gd edits via the host-lobby cog
# button, and what gets synced to clients on connect (see
# RopeSettingsPanel.PROPERTY_NAMES / _sync_rope_settings below) so every
# peer's local ropes behave identically to the host's.
@export var stiffness: float = 4.0
@export var damping: float = 4.0
@export var rest_length: float = 64.0
@export var max_pull_accel: float = 4000.0
@export var min_length: float = 16.0
@export var max_length_multiplier: float = 3.0
@export var max_length_overstretch_fraction: float = 0.1
@export var overstretch_speed_threshold: float = 400.0
@export var pull_rest_length: float = 24.0
@export var pull_stiffness_multiplier: float = 3.0
@export var puller_drag_multiplier: float = 1.8
@export var pull_kick_speed: float = 150.0

# Keep in sync with the @export list above — this is what gets sent to
# newly-connected peers (see _on_peer_connected) and iterated by
# rope_settings_panel.gd to build the editable field list.
const ROPE_PROPERTY_NAMES: Array[String] = [
	"stiffness", "damping", "rest_length", "max_pull_accel", "min_length",
	"max_length_multiplier", "max_length_overstretch_fraction",
	"overstretch_speed_threshold", "pull_rest_length",
	"pull_stiffness_multiplier", "puller_drag_multiplier", "pull_kick_speed",
]

@onready var scene_root: Node = get_parent()

var connection_order: Array[int] = []

func _ready() -> void:
	add_to_group("rope_manager")  # so a dying player (see player.gd's die()) can find this without a NodePath
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

	# Must land before any rope-spawning RPC below, since the very first rope
	# this new peer builds locally (whether an existing one it's catching up
	# on, or the brand-new one to previous_id) needs these values already in
	# place. Reliable RPCs from this node are delivered in the order sent.
	var settings: Dictionary = {}
	for property_name in ROPE_PROPERTY_NAMES:
		settings[property_name] = get(property_name)
	_sync_rope_settings.rpc_id(id, settings)

	# The new peer missed every _spawn_rope RPC sent before it connected, so it
	# never built those rope nodes locally — catch it up on the whole chain so far.
	if connection_order.size() > 1:
		var existing_pairs: Array = []
		for i in range(connection_order.size() - 1):
			existing_pairs.append([connection_order[i], connection_order[i + 1]])
		_spawn_ropes.rpc_id(id, existing_pairs)

	connection_order.append(id)
	if previous_id != -1:
		_spawn_rope.rpc(previous_id, id)

@rpc("authority", "reliable")
func _sync_rope_settings(settings: Dictionary) -> void:
	for property_name in settings:
		set(property_name, settings[property_name])

@rpc("authority", "reliable")
func _spawn_ropes(pairs: Array) -> void:
	for pair in pairs:
		await _create_rope(pair[0], pair[1])

@rpc("authority", "call_local", "reliable")
func _spawn_rope(id_a: int, id_b: int) -> void:
	await _create_rope(id_a, id_b)

func _create_rope(id_a: int, id_b: int) -> void:
	var rope_name: String = "rope_%d_%d" % [id_a, id_b]
	if scene_root.has_node(rope_name):
		return

	var player_a: Node = await _wait_for_player(id_a)
	var player_b: Node = await _wait_for_player(id_b)
	if player_a == null or player_b == null:
		push_warning("Rope target missing, could not attach rope between %d and %d" % [id_a, id_b])
		return

	var rope: Node2D = ROPE_SCENE.instantiate()
	rope.name = rope_name
	for property_name in ROPE_PROPERTY_NAMES:
		rope.set(property_name, get(property_name))
	scene_root.add_child(rope)
	rope.setup(player_a, player_b)

	# player_a is the earlier-joined end (id_a), player_b the later-joined end
	# (id_b) — see the rope_to_previous/rope_to_next convention in player.gd.
	player_a.rope_to_next = rope
	player_b.rope_to_previous = rope

func _wait_for_player(id: int) -> Node:
	var player: Node = scene_root.get_node_or_null(str(id))
	var attempts := 0
	while player == null and attempts < WAIT_FRAMES_TIMEOUT:
		await get_tree().process_frame
		player = scene_root.get_node_or_null(str(id))
		attempts += 1
	return player

# Called locally by whichever peer's own player just died (see player.gd's
# die()) — any_peer since it's just a request, but only the server actually
# acts on it: connection_order (and therefore the chain's shape) only ever
# lives on the server, same as the initial join-order chain built in
# _on_peer_connected above. Needs call_local: a peer's rpc_id(1, ...) to
# itself does NOT run locally unless call_local is set (Godot doesn't loop
# a "network" packet back to its own sender) — without it, the host's own
# player calling this never did anything. For a non-host caller, call_local
# means this also runs harmlessly on the caller's own machine, where the
# is_server() guard below immediately no-ops it — the real, authoritative
# run still only ever happens once, on the server.
@rpc("any_peer", "call_local", "reliable")
func request_death(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var index: int = connection_order.find(peer_id)
	if index == -1:
		return  # unrecognized id, or already handled by an earlier call — ignore

	var previous_id: int = connection_order[index - 1] if index > 0 else -1
	var next_id: int = connection_order[index + 1] if index < connection_order.size() - 1 else -1
	connection_order.remove_at(index)
	# Whoever's currently last becomes the dying player's new rope-mate; the
	# dying player is then appended back on, becoming the new last link.
	var new_previous_id: int = connection_order[-1] if connection_order.size() > 0 else -1
	connection_order.append(peer_id)

	_apply_death_relink.rpc(peer_id, previous_id, next_id, new_previous_id)

# Broadcast by the server (see request_death above) once it's decided the new
# chain shape, so every peer applies the identical relink instead of each
# guessing independently. Removes the dying player's old one or two rope
# connections, bridges its old neighbors directly together so the rest of the
# chain stays continuous without it, then respawns the dying player close to
# the (pre-death) last player in the chain and attaches a fresh rope to them.
@rpc("authority", "call_local", "reliable")
func _apply_death_relink(dying_id: int, previous_id: int, next_id: int, new_previous_id: int) -> void:
	if previous_id != -1:
		_remove_rope(previous_id, dying_id)
	if next_id != -1:
		_remove_rope(dying_id, next_id)
	if previous_id != -1 and next_id != -1:
		await _create_rope(previous_id, next_id)

	var dying_player: Node = await _wait_for_player(dying_id)
	if dying_player == null:
		return

	if dying_player.is_multiplayer_authority():
		var tail_player: Node = scene_root.get_node_or_null(str(new_previous_id)) if new_previous_id != -1 else null
		# Spawn just short of rest_length away so the fresh rope below starts
		# out slack instead of instantly snapping/yanking the respawned player.
		var target_position: Vector2 = tail_player.global_position + Vector2(-rest_length * 0.5, 0.0) if tail_player != null else dying_player.find_spawn_position()
		dying_player.respawn_to(target_position)

	if new_previous_id != -1:
		await _create_rope(new_previous_id, dying_id)

# Undoes exactly what _create_rope did for this pair: clears both players'
# rope_to_previous/rope_to_next reference to it (see the same convention
# noted in _create_rope) and frees the rope node itself.
func _remove_rope(id_a: int, id_b: int) -> void:
	var rope: Node = scene_root.get_node_or_null("rope_%d_%d" % [id_a, id_b])
	if rope == null:
		return
	if is_instance_valid(rope.player_a):
		rope.player_a.rope_to_next = null
	if is_instance_valid(rope.player_b):
		rope.player_b.rope_to_previous = null
	# remove_child (not just queue_free, which leaves it in the tree — and
	# still passing has_node()'s check in _create_rope — until end of frame)
	# so a same-frame _create_rope() for this exact id_a/id_b pair, like the
	# reattach in _apply_death_relink when the dying player was already last
	# in the chain, doesn't mistake the about-to-be-freed old rope for a
	# still-live one and skip creating its replacement.
	scene_root.remove_child(rope)
	rope.queue_free()
