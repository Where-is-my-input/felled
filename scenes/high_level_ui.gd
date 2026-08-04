extends Control

const DEBUG_LEVEL_SCENE: String = "res://scenes/debug_level.tscn"

@onready var menu_panel: VBoxContainer = $MenuCenter/MenuPanel
@onready var btn_host: Button = $MenuCenter/MenuPanel/HostRow/btnHost
@onready var btn_rope_settings: Button = $MenuCenter/MenuPanel/HostRow/btnRopeSettings
@onready var btn_join: Button = $MenuCenter/MenuPanel/btnJoin
@onready var btn_settings: Button = $MenuCenter/MenuPanel/btnSettings
@onready var btn_quit: Button = $MenuCenter/MenuPanel/btnQuit

@onready var join_panel: VBoxContainer = $MenuCenter/JoinPanel
@onready var ip: LineEdit = $MenuCenter/JoinPanel/ip
@onready var port: LineEdit = $MenuCenter/JoinPanel/port
@onready var btn_connect: Button = $MenuCenter/JoinPanel/btnConnect
@onready var btn_join_back: Button = $MenuCenter/JoinPanel/btnJoinBack

@onready var settings_panel: VBoxContainer = $MenuCenter/SettingsPanel
@onready var btn_settings_back: Button = $MenuCenter/SettingsPanel/btnSettingsBack

@onready var rope_settings_panel: VBoxContainer = $MenuCenter/RopeSettingsPanel
@onready var btn_rope_settings_back: Button = $MenuCenter/RopeSettingsPanel/btnRopeSettingsBack

func _ready() -> void:
	btn_host.grab_focus()

	btn_host.pressed.connect(_on_btn_host_pressed)
	btn_rope_settings.pressed.connect(_on_btn_rope_settings_pressed)
	btn_join.pressed.connect(_on_btn_join_pressed)
	btn_settings.pressed.connect(_on_btn_settings_pressed)
	btn_quit.pressed.connect(_on_btn_quit_pressed)
	btn_connect.pressed.connect(_on_btn_connect_pressed)
	btn_join_back.pressed.connect(_show_menu)
	btn_settings_back.pressed.connect(_show_menu)
	btn_rope_settings_back.pressed.connect(_show_menu)

func _on_btn_join_pressed() -> void:
	menu_panel.visible = false
	join_panel.visible = true

func _on_btn_settings_pressed() -> void:
	menu_panel.visible = false
	settings_panel.visible = true

func _on_btn_rope_settings_pressed() -> void:
	menu_panel.visible = false
	rope_settings_panel.visible = true

func _show_menu() -> void:
	join_panel.visible = false
	settings_panel.visible = false
	rope_settings_panel.visible = false
	menu_panel.visible = true

func _on_btn_quit_pressed() -> void:
	get_tree().quit()

func _on_btn_connect_pressed() -> void:
	HighLevelNetworkHandler.startClient(port.text, ip.text)
	get_tree().change_scene_to_file(DEBUG_LEVEL_SCENE)

func _on_btn_host_pressed() -> void:
	Global.notify.emit("Starting server...")
	# Hosting doesn't show a port field (that's only needed to join someone else's
	# lobby) — always host on the well-known default port.
	HighLevelNetworkHandler.startServer(str(HighLevelNetworkHandler.PORT))

	if not multiplayer.is_server():
		push_error("Failed to start server")
		return

	get_tree().change_scene_to_file(DEBUG_LEVEL_SCENE)
