extends Node

const IP_ADDRESS: String = "localhost"
const PORT: int = 42069
const MAIN_MENU_SCENE: String = "res://scenes/main_menu.tscn"

var peer: ENetMultiplayerPeer

func _ready() -> void:
	# Centralized here (rather than on the menu's own script) because the menu
	# scene is gone by the time these fire — hosting/joining transitions to
	# debug_level.tscn, which destroys whatever was listening in the menu.
	# This autoload survives every scene change, so it's the one place that
	# can reliably send everyone back to the menu regardless of which scene
	# happens to be active when the connection drops.
	multiplayer.server_disconnected.connect(_return_to_menu)
	multiplayer.connection_failed.connect(_return_to_menu)

func startServer(port:String):
	peer = ENetMultiplayerPeer.new()
	peer.create_server(port.to_int())
	multiplayer.multiplayer_peer = peer

func startClient(port:String, ip:String):
	peer = ENetMultiplayerPeer.new()
	peer.create_client(ip, port.to_int())
	multiplayer.multiplayer_peer = peer

func _return_to_menu() -> void:
	multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
