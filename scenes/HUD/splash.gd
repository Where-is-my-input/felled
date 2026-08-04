extends Control
@onready var texture: TextureRect = $tr

func _ready() -> void:
	if !OS.is_debug_build():
		var t = create_tween()
		t.tween_property(texture, "modulate", Color(1.0, 1.0, 1.0, 1.0), 2.5)
		await t.finished
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
