extends Node2D

# Loaded (via change_scene_to_file) after hosting or joining succeeds — see
# high_level_ui.gd. Runs identically on host and client; only the host
# actually spawns anything here; a client's own player arrives later via
# MultiplayerSpawner, replicated from the server.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")

@onready var multiplayer_spawner: MultiplayerSpawner = $MultiplayerSpawner
@onready var rope_manager: Node = $RopeManager

func _ready() -> void:
	multiplayer_spawner.networkPlayer = PLAYER_SCENE
	multiplayer_spawner.add_spawnable_scene(PLAYER_SCENE.resource_path)

	# Host-lobby cog button (rope_settings_panel.gd, in main_menu.tscn) writes
	# any edits into this store before RopeManager exists — apply them now,
	# before any rope gets created.
	RopeSettingsStore.apply_to(rope_manager)

	if multiplayer.is_server():
		Global.notify.emit("Server started, spawning player...")
		var player: Node = PLAYER_SCENE.instantiate()
		player.name = "1"  # Server has peer ID 1
		add_child(player)
		rope_manager.register_initial_player(1)
		Global.notify.emit("Server player spawned with name: " + player.name)
