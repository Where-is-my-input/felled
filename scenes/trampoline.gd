extends Area2D

enum BounceDirection { UP, DOWN, LEFT, RIGHT }

const DIRECTION_VECTORS := {
	BounceDirection.UP: Vector2.UP,
	BounceDirection.DOWN: Vector2.DOWN,
	BounceDirection.LEFT: Vector2.LEFT,
	BounceDirection.RIGHT: Vector2.RIGHT,
}

# Which way it launches players — set this per-instance to mount the same
# trampoline on a floor (UP), ceiling (DOWN), or either wall (LEFT/RIGHT).
@export var bounce_direction: BounceDirection = BounceDirection.UP
# Guaranteed minimum launch speed along bounce_direction — just enough that a
# slow or stationary touch still visibly pops off the surface, NOT a target
# bounce strength. The real bounce height comes from bounce_restitution below
# reflecting the player's own incoming speed.
@export var bounce_speed: float = 80.0
# How much of the player's own incoming speed (into the trampoline) carries
# over into the bounce. 1.0 would be perfectly elastic (same height as the
# fall they came from); slightly below 1.0 loses a bit of energy each bounce,
# like a real trampoline, instead of launching harder than the player fell.
@export var bounce_restitution: float = 0.85

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	# Placeholder visual (see PROJECT_RULES.md): Godot icon, randomly
	# modulated, rotated to visually hint at the direction it launches players.
	sprite.modulate = Color(randf(), randf(), randf())
	sprite.rotation = DIRECTION_VECTORS[bounce_direction].angle() + PI / 2.0
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not (body is CharacterBody2D) or not body.has_method("apply_external_launch"):
		return
	# Only the peer that actually owns this body may move it — every peer's
	# local copy of this trampoline independently detects the same overlap
	# (including for remote players' replicated collision shapes), so this
	# guard is what keeps the bounce from being a no-op fight against
	# whichever client is truly authoritative for that player.
	if not body.is_multiplayer_authority():
		return

	var direction: Vector2 = DIRECTION_VECTORS[bounce_direction]
	# Reflect only the velocity component ALONG the bounce axis (so hitting it
	# fast gives a bigger bounce) while leaving the perpendicular component
	# completely untouched — that's what keeps the resulting arc looking like
	# a normal charged jump under gravity, instead of the bounce overriding
	# the player's whole trajectory.
	var incoming_along_axis: float = body.velocity.dot(direction)
	var outgoing_speed: float = max(bounce_speed, -incoming_along_axis * bounce_restitution)
	var tangential: Vector2 = body.velocity - direction * incoming_along_axis
	body.apply_external_launch(tangential + direction * outgoing_speed)
