extends StaticBody2D

enum Direction { LEFT, RIGHT }

const DIRECTION_VECTORS := {
	Direction.LEFT: Vector2.LEFT,
	Direction.RIGHT: Vector2.RIGHT,
}

# Which way the belt carries standing players — set this per-instance in the
# Inspector to mount copies of the same belt facing either way.
@export var direction: Direction = Direction.RIGHT
# Horizontal speed a stationary player gets carried at while standing on this
# belt. A player walking with/against it adds their own input speed on top
# instead of being capped at this — see player.gd's on-floor movement, which
# reads this via get_push_velocity().
@export var belt_speed: float = 150.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	# Placeholder visual (see PROJECT_RULES.md): Godot icon, randomly
	# modulated, flipped to visually hint at the direction it carries players.
	sprite.modulate = Color(randf(), randf(), randf())
	sprite.flip_h = direction == Direction.LEFT
	add_to_group("conveyor_belts")

# Queried by player.gd every physics frame it's standing on this belt (found
# via its floor collision, same as any other ground) rather than pushed onto
# the player — a belt has no per-player state to track, so there's nothing to
# gain from the trampoline/button style of reacting to body_entered.
func get_push_velocity() -> Vector2:
	return DIRECTION_VECTORS[direction] * belt_speed
