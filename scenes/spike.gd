extends Area2D

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	# Placeholder visual (see PROJECT_RULES.md): Godot icon, randomly modulated.
	sprite.modulate = Color(randf(), randf(), randf())
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not (body is CharacterBody2D) or not body.has_method("die"):
		return
	# Every peer's local copy of this spike independently detects the same
	# touch (including replicated remote players) — only the peer that
	# actually owns the touching body should act on it, same guard as
	# trampoline.gd's bounce.
	if not body.is_multiplayer_authority():
		return
	body.die()
