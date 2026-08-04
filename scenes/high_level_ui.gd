extends Control

@export var player_scene: PackedScene

@onready var multiplayer_spawner: MultiplayerSpawner = $"../MultiplayerSpawner"
@onready var rope_manager: Node = $"../RopeManager"
@onready var btn_client: Button = $VBoxContainer/btnClient
@onready var ip: LineEdit = $VBoxContainer/ip
@onready var port: LineEdit = $VBoxContainer/port

func _ready() -> void:
	btn_client.grab_focus()
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.server_disconnected.connect(_on_disconnected)
	multiplayer_spawner.networkPlayer = player_scene
	multiplayer_spawner.add_spawnable_scene(player_scene.resource_path)

func _on_btn_client_pressed() -> void:
	HighLevelNetworkHandler.startClient(port.text, ip.text)

func _on_btn_server_pressed() -> void:
	Global.notify.emit("Starting server...")
	HighLevelNetworkHandler.startServer(port.text)

	if not multiplayer.is_server():
		push_error("Failed to start server")
		return

	Global.notify.emit("Server started, spawning player...")
	var player: Node = player_scene.instantiate()
	player.name = "1"  # Server has peer ID 1
	get_parent().add_child(player)
	rope_manager.register_initial_player(1)
	Global.notify.emit("Server player spawned with name: " + player.name)
	set_buttons_visibility(false)

func _on_connected_to_server() -> void:
	set_buttons_visibility(false)

func _on_disconnected() -> void:
	set_buttons_visibility(true)

func set_buttons_visibility(should_show: bool) -> void:
	visible = should_show
