extends VBoxContainer

# Lets whoever is about to host edit RopeManager's rope-constraint defaults
# before starting the server. This panel (and the whole main menu it's part
# of) is hidden the moment hosting/joining starts — see
# HighLevelUI.set_buttons_visibility — so there is no mid-game editing to
# worry about: whatever is set here becomes the host's authoritative values
# for the entire session, and RopeManager sends them to every client as it
# connects (see rope_manager.gd's _on_peer_connected/_sync_rope_settings).
# Editing here while you're actually a client does nothing useful — your own
# RopeManager's values get overwritten by the real host's the moment you join.

# name, display label, min, max, step — kept in the same order as
# RopeManager.ROPE_PROPERTY_NAMES for easy comparison, not required to match.
const FIELDS: Array[Dictionary] = [
	{"name": "stiffness", "label": "Stiffness", "min": 0.1, "max": 50.0, "step": 0.1},
	{"name": "damping", "label": "Damping", "min": 0.0, "max": 50.0, "step": 0.1},
	{"name": "rest_length", "label": "Rest Length", "min": 8.0, "max": 300.0, "step": 1.0},
	{"name": "max_pull_accel", "label": "Max Pull Accel", "min": 100.0, "max": 20000.0, "step": 100.0},
	{"name": "min_length", "label": "Min Length", "min": 1.0, "max": 100.0, "step": 1.0},
	{"name": "max_length_multiplier", "label": "Max Length (x Rest Length)", "min": 1.0, "max": 10.0, "step": 0.1},
	{"name": "max_length_overstretch_fraction", "label": "Overstretch Fraction", "min": 0.0, "max": 1.0, "step": 0.01},
	{"name": "overstretch_speed_threshold", "label": "Overstretch Speed Threshold", "min": 0.0, "max": 2000.0, "step": 10.0},
	{"name": "pull_rest_length", "label": "Pull (Reel-In) Rest Length", "min": 1.0, "max": 150.0, "step": 1.0},
	{"name": "pull_stiffness_multiplier", "label": "Pull Stiffness Multiplier", "min": 1.0, "max": 10.0, "step": 0.1},
	{"name": "puller_drag_multiplier", "label": "Puller Drag Multiplier", "min": 1.0, "max": 5.0, "step": 0.1},
]

@onready var rope_manager: Node = $"../../../RopeManager"
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
	spin.value = rope_manager.get(field["name"])
	spin.value_changed.connect(_on_field_changed.bind(field["name"]))
	row.add_child(spin)

func _on_field_changed(new_value: float, property_name: String) -> void:
	rope_manager.set(property_name, new_value)
