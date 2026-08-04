extends MultiplayerSpawner

@export var networkPlayer: PackedScene

func _ready() -> void:
	multiplayer.peer_connected.connect(_spawn_player)
	spawn_function = Callable(self, "_create_player")

func _spawn_player(id: int) -> void:
	if not multiplayer.is_server(): return
	spawn({id = id})
	Global.notify.emit("Peer id " + str(id) + " spawned")

func _create_player(data: Variant) -> Node:
	var player: Node = networkPlayer.instantiate()
	player.name = str(data["id"])
	return player
