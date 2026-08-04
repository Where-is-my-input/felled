extends StaticBody2D

# Tracks which buttons currently want this door open (button instance -> true)
# instead of a single bool, so any number of independent buttons can each
# hold it open — the door stays open as long as AT LEAST ONE connected
# button is toggled on, and only closes once every single one of them is
# off, like real parallel switches wired to the same door. A button adds/
# removes its own entry via set_button_state(); this dictionary is never
# touched directly by anything else.
var _active_buttons: Dictionary = {}

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	# Placeholder visual (see PROJECT_RULES.md): Godot icon, random modulate.
	sprite.modulate = Color(randf(), randf(), randf())
	_apply_state()

# Called locally by any connected button.gd whenever ITS toggle state
# changes. Each peer's button already replicates its own toggle via RPC (see
# button.gd), so by the time this runs it's happening identically on every
# peer — the door itself needs no networking of its own.
func set_button_state(button: Node, is_on: bool) -> void:
	if is_on:
		_active_buttons[button] = true
	else:
		_active_buttons.erase(button)
	_apply_state()

func _apply_state() -> void:
	var is_open: bool = not _active_buttons.is_empty()
	# This is reached via button.gd's body_entered handler, which fires while
	# the physics server is still mid-query-flush — changing collision state
	# directly at that point doesn't reliably apply. set_deferred() is the
	# standard Godot fix: it waits until the physics step is safely done.
	collision_shape.set_deferred("disabled", is_open)
	sprite.visible = not is_open
