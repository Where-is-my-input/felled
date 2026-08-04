extends VBoxContainer

# Lets whoever is about to host edit the rope-constraint defaults before
# starting the server. RopeManager doesn't exist yet at this point (it lives
# in debug_level.tscn, only instantiated after hosting/joining starts), so
# edits go into RopeSettingsStore (an autoload that survives the scene
# transition) instead of a live RopeManager node. debug_level.gd applies the
# store's overrides to the real RopeManager as soon as it's created, and
# RopeManager itself sends the resulting values to every client as it
# connects (see rope_manager.gd's _on_peer_connected/_sync_rope_settings).
# Editing here while you're actually a client does nothing useful — your own
# RopeManager's values get overwritten by the real host's the moment you join.

# name, label, min, max, step, default — "default" mirrors RopeManager's own
# @export default for that property, used only for the field's initial value
# when there's no override yet (kept in the same order as
# RopeManager.ROPE_PROPERTY_NAMES for easy comparison, not required to match).
const FIELDS: Array[Dictionary] = [
	{"name": "stiffness", "label": "Stiffness", "min": 0.1, "max": 50.0, "step": 0.1, "default": 4.0},
	{"name": "damping", "label": "Damping", "min": 0.0, "max": 50.0, "step": 0.1, "default": 4.0},
	{"name": "rest_length", "label": "Rest Length", "min": 8.0, "max": 300.0, "step": 1.0, "default": 64.0},
	{"name": "max_pull_accel", "label": "Max Pull Accel", "min": 100.0, "max": 20000.0, "step": 100.0, "default": 4000.0},
	{"name": "min_length", "label": "Min Length", "min": 1.0, "max": 100.0, "step": 1.0, "default": 16.0},
	{"name": "max_length_multiplier", "label": "Max Length (x Rest Length)", "min": 1.0, "max": 10.0, "step": 0.1, "default": 3.0},
	{"name": "max_length_overstretch_fraction", "label": "Overstretch Fraction", "min": 0.0, "max": 1.0, "step": 0.01, "default": 0.1},
	{"name": "overstretch_speed_threshold", "label": "Overstretch Speed Threshold", "min": 0.0, "max": 2000.0, "step": 10.0, "default": 400.0},
	{"name": "pull_rest_length", "label": "Pull (Reel-In) Rest Length", "min": 1.0, "max": 150.0, "step": 1.0, "default": 24.0},
	{"name": "pull_stiffness_multiplier", "label": "Pull Stiffness Multiplier", "min": 1.0, "max": 10.0, "step": 0.1, "default": 3.0},
	{"name": "puller_drag_multiplier", "label": "Puller Drag Multiplier", "min": 1.0, "max": 5.0, "step": 0.1, "default": 1.8},
	{"name": "pull_kick_speed", "label": "Pull Kick Speed", "min": 0.0, "max": 1000.0, "step": 10.0, "default": 150.0},
]

@onready var fields_container: VBoxContainer = $ScrollContainer/FieldsContainer

func _ready() -> void:
	for field in FIELDS:
		_add_field(field)

func _add_field(field: Dictionary) -> void:
	var row := HBoxContainer.new()
	fields_container.add_child(row)

	var label := Label.new()
	label.text = field["label"]
	label.custom_minimum_size = Vector2(190, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	row.add_child(label)

	var spin := SpinBox.new()
	spin.min_value = field["min"]
	spin.max_value = field["max"]
	spin.step = field["step"]
	spin.custom_minimum_size = Vector2(100, 0)
	spin.value = RopeSettingsStore.get_value(field["name"], field["default"])
	spin.value_changed.connect(_on_field_changed.bind(field["name"]))
	row.add_child(spin)

func _on_field_changed(new_value: float, property_name: String) -> void:
	RopeSettingsStore.set_value(property_name, new_value)
