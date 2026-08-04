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

# Hard ceiling: expressed as a multiple of rest_length (3x, for now) — NOT
# min_length, since min_length (16) is a proximity floor far smaller than
# the rope's normal idle length (rest_length, 64 by default); a 3x-min_length
# ceiling (48) was actually *tighter* than the default slack, so the rope
# could never relax out to its normal length and looked permanently reeled
# in. Basing it on rest_length instead keeps it a real ceiling ABOVE the
# rope's normal operating range. This is enforced as an actual positional
# clamp (see _physics_process) rather than just a stronger spring — a spring
# alone can still be out-stretched by enough thrust, which is exactly what
# happened before that was added. Each peer only ever corrects the end(s) it's
# actually authoritative for; the other end (if owned by a different client)
# gets caught up via that client's own copy of this same rope doing the same
# correction, then replicated position sync.
@export var max_length_multiplier: float = 3.0

# Lets the cap itself stretch a bit under a fast enough impact instead of
# always clamping at exactly max_length — full give (10% extra) only kicks
# in once the two are separating at overstretch_speed_threshold or faster;
# below that it scales down linearly to zero give, so a slow drift into the
# cap still stops right at max_length.
@export var max_length_overstretch_fraction: float = 0.1
@export var overstretch_speed_threshold: float = 400.0

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
	var max_length: float = rest_length * max_length_multiplier
	if distance > max_length:
		var direction_to_b: Vector2 = offset / distance
		var separating_speed_at_cap: float = (player_b.velocity - player_a.velocity).dot(direction_to_b)
		var give_fraction: float = clamp(separating_speed_at_cap / overstretch_speed_threshold, 0.0, 1.0)
		var effective_max_length: float = max_length * (1.0 + max_length_overstretch_fraction * give_fraction)
		if distance > effective_max_length:
			var excess: float = distance - effective_max_length
			var half_correction: Vector2 = direction_to_b * (excess * 0.5)
			if player_a.is_multiplayer_authority():
				player_a.global_position += half_correction
			if player_b.is_multiplayer_authority():
				player_b.global_position -= half_correction
			# Recompute so the spring math and line below use the corrected
			# (capped) distance instead of the stale, over-max one.
			offset = player_b.global_position - player_a.global_position
			distance = offset.length()

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
