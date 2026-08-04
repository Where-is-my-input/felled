extends Area2D

# The doors this switch controls. Wire this up in the Inspector (drag each
# target Door node onto a slot) — a single button can list any number of
# doors, and the same door can just as easily be listed by several different
# buttons (see door.gd's _active_buttons), so this is a true many-to-many
# relationship: N buttons per door, N doors per button.
@export var doors: Array[NodePath] = []

@onready var sprite: Sprite2D = $Sprite2D

var is_on: bool = false
var _base_color: Color

func _ready() -> void:
	# Placeholder visual (see PROJECT_RULES.md): Godot icon, random modulate.
	# Dimmed while off, full brightness while on, as simple visual feedback
	# for a switch with no dedicated art yet.
	_base_color = Color(randf(), randf(), randf())
	_update_visual()
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not (body is CharacterBody2D) or not body.is_multiplayer_authority():
		return
	# Every peer's local copy of this button independently detects the same
	# touch (including replicated remote players), so only the peer that
	# actually owns the touching body gets past the check above — but unlike
	# a personal effect (e.g. trampoline.gd), a door's open/closed state has
	# to be agreed on by everyone, so the resulting toggle is broadcast
	# rather than just applied locally.
	_toggle.rpc()

@rpc("any_peer", "call_local", "reliable")
func _toggle() -> void:
	is_on = not is_on
	_update_visual()
	for door_path in doors:
		var door: Node = get_node_or_null(door_path)
		if door != null:
			door.set_button_state(self, is_on)

func _update_visual() -> void:
	# Color * float also scales alpha, which would make "off" semi-transparent
	# instead of just dim — scale rgb only, keep it fully opaque either way.
	sprite.modulate = _base_color if is_on else Color(_base_color.r * 0.5, _base_color.g * 0.5, _base_color.b * 0.5, 1.0)
