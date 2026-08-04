extends Node

# Persists rope-constraint edits made via the host-lobby cog button
# (rope_settings_panel.gd, in main_menu.tscn) across the menu -> debug_level
# scene transition. RopeManager doesn't exist while the menu is showing — it
# lives in debug_level.tscn, only instantiated once hosting/joining starts —
# so edits can't be written directly onto a RopeManager instance the way they
# used to when everything was one scene. This autoload is the one place that
# survives the scene change; debug_level.gd applies it to the real
# RopeManager as soon as that node exists.

var overrides: Dictionary = {}

func set_value(property_name: String, value: float) -> void:
	overrides[property_name] = value

func get_value(property_name: String, default_value: float) -> float:
	return overrides.get(property_name, default_value)

func apply_to(rope_manager: Node) -> void:
	for property_name in overrides:
		rope_manager.set(property_name, overrides[property_name])
