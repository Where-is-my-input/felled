extends Node2D

# KNOWN GAP: the pull below is a straight line between the two players and
# does not check the tilemap for terrain in between — a rope can currently
# pull straight through a wall instead of wrapping around it.
# Not fixed yet — flagged for later.

@export var stiffness: float = 4.0
@export var damping: float = 4.0
@export var rest_length: float = 64.0
@export var max_pull_accel: float = 4000.0

# Hard floor: no matter what rest_length shrinks to (including while being
# reeled in below), the rope never pulls the two players closer than this —
# it just goes fully slack once they're within it.
@export var min_length: float = 16.0

# Applied while either end is holding their pull key (Q for the earlier-joined
# end, E for the later-joined end — see player.gd's rope_to_previous/next).
@export var pull_rest_length: float = 24.0
@export var pull_stiffness_multiplier: float = 3.0
@export var puller_drag_multiplier: float = 1.8

var player_a: CharacterBody2D
var player_b: CharacterBody2D

@onready var line: Line2D = $Line

func _ready() -> void:
	# Must run before the players' own _physics_process (priority 0) so the pull
	# it computes this frame is consumed by move_and_slide the same frame.
	process_physics_priority = -1

func setup(a: CharacterBody2D, b: CharacterBody2D) -> void:
	player_a = a
	player_b = b

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player_a) or not is_instance_valid(player_b):
		queue_free()
		return

	# player_a is the earlier-joined end of this rope (its "next" neighbor is
	# player_b), player_b is the later-joined end (its "previous" neighbor is
	# player_a) — see the rope_to_previous/rope_to_next convention in player.gd.
	# These are replicated player properties, not local rope state, so every
	# peer's copy of this rope agrees on who's pulling regardless of which
	# client actually owns either player.
	var pulling_a: bool = player_a.is_pulling_next
	var pulling_b: bool = player_b.is_pulling_previous
	var is_being_pulled: bool = pulling_a or pulling_b

	var effective_rest_length: float = max(min_length, pull_rest_length if is_being_pulled else rest_length)
	var effective_stiffness: float = stiffness
	var effective_damping: float = damping
	if is_being_pulled:
		effective_stiffness *= pull_stiffness_multiplier
		# Scale damping by sqrt(stiffness multiplier) to stay near-critically
		# damped at the new, stiffer setting instead of starting to oscillate.
		effective_damping *= sqrt(pull_stiffness_multiplier)

	var offset: Vector2 = player_b.global_position - player_a.global_position
	var distance: float = offset.length()
	if distance > effective_rest_length:
		var direction: Vector2 = offset / distance
		var stretch: float = distance - effective_rest_length
		# Damp based on how fast the two are separating along the rope, so the pull
		# gets stronger the faster they're flying apart instead of settling for a
		# weaker (or even reversed) pull — that sign is what makes it converge.
		var separating_speed: float = (player_b.velocity - player_a.velocity).dot(direction)
		var pull_accel: float = clamp(stretch * effective_stiffness + separating_speed * effective_damping, -max_pull_accel, max_pull_accel)
		var pull: Vector2 = direction * pull_accel
		# Whoever is actively pulling gets dragged toward the other end harder
		# than the passive end does.
		player_a.rope_pull += pull * (puller_drag_multiplier if pulling_a else 1.0)
		player_b.rope_pull -= pull * (puller_drag_multiplier if pulling_b else 1.0)

	line.points = PackedVector2Array([to_local(player_a.global_position), to_local(player_b.global_position)])
