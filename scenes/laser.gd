extends Area2D

enum Direction { UP, DOWN, LEFT, RIGHT }

const DIRECTION_VECTORS := {
	Direction.UP: Vector2.UP,
	Direction.DOWN: Vector2.DOWN,
	Direction.LEFT: Vector2.LEFT,
	Direction.RIGHT: Vector2.RIGHT,
}

# Which way the beam fires — set this per-instance in the Inspector.
@export var direction: Direction = Direction.RIGHT
# How far the beam reaches from this node's position.
@export var beam_length: float = 200.0
# How thick the beam (and its hitbox) is.
@export var beam_width: float = 8.0
# Full cycle length in seconds: time from the start of one firing to the
# start of the next — includes both the active and idle portions below.
@export var interval: float = 3.0
# How long, within each interval, the beam is actually on (visible + deadly)
# — the rest of the interval it's off. Clamped to interval in _physics_process,
# so a value >= interval just means "always on."
@export var active_duration: float = 1.0

@onready var beam: Sprite2D = $Beam
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _cycle_timer: float = 0.0

func _ready() -> void:
	rotation = DIRECTION_VECTORS[direction].angle()

	# Sized here (rather than authored on the CollisionShape2D/Sprite2D
	# directly) so every instance can set its own beam_length/beam_width in
	# the Inspector without fighting over a shared sub-resource.
	var shape := RectangleShape2D.new()
	shape.size = Vector2(beam_length, beam_width)
	collision_shape.shape = shape
	collision_shape.position.x = beam_length / 2.0

	# Placeholder visual (see PROJECT_RULES.md): Godot icon, randomly
	# modulated, stretched into a beam-shaped rectangle matching the hitbox.
	beam.modulate = Color(randf(), randf(), randf())
	var texture_size: Vector2 = beam.texture.get_size()
	beam.scale = Vector2(beam_length / texture_size.x, beam_width / texture_size.y)
	beam.position.x = beam_length / 2.0

	_set_active(false)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	_cycle_timer += delta
	if _cycle_timer >= interval:
		_cycle_timer -= interval
	_set_active(_cycle_timer < min(active_duration, interval))

# Toggles both monitoring (so the beam is only actually deadly while "on")
# and the visual together, so they never fall out of sync with each other.
func _set_active(active: bool) -> void:
	if active == monitoring:
		return
	monitoring = active
	beam.visible = active

func _on_body_entered(body: Node) -> void:
	if not (body is CharacterBody2D) or not body.has_method("die"):
		return
	# Every peer's local copy of this laser independently detects the same
	# touch (including replicated remote players) — only the peer that
	# actually owns the touching body should act on it, same guard as
	# spike.gd/trampoline.gd.
	if not body.is_multiplayer_authority():
		return
	body.die()
