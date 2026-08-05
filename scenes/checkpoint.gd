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
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not (body is CharacterBody2D) or not body.is_multiplayer_authority():
		return
	# The whole (roped-together) team shares one respawn point rather than a
	# per-player one — whichever checkpoint ANY player most recently reached
	# is where a respawn vote sends everyone. Every peer's local copy of this
	# checkpoint independently detects the same touch, so the authority guard
	# above is what keeps this to a single real update instead of a fight.
	var respawn_manager: Node = get_tree().get_first_node_in_group("respawn_manager")
	if respawn_manager != null:
		respawn_manager.record_checkpoint.rpc(global_position)
