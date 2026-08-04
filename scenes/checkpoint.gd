extends Area2D

## The first checkpoint of a map is where players spawn instead of the
## hardcoded fallback position in player.gd — see _find_spawn_position()
## there. Only one checkpoint per map should have this set.
@export var is_first_checkpoint: bool = false

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("checkpoints")
	# Placeholder visual (see PROJECT_RULES.md): Godot icon, randomly
	# modulated so multiple checkpoints in the same level are visually
	# distinguishable until real art exists.
	sprite.modulate = Color(randf(), randf(), randf())
