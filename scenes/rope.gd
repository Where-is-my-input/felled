extends Node2D

@export var stiffness: float = 30.0
@export var damping: float = 11.0
@export var rest_length: float = 64.0
@export var max_pull_accel: float = 4000.0

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

	var offset: Vector2 = player_b.global_position - player_a.global_position
	var distance: float = offset.length()
	if distance > rest_length:
		var direction: Vector2 = offset / distance
		var stretch: float = distance - rest_length
		# Damp based on how fast the two are separating along the rope, so the pull
		# gets stronger the faster they're flying apart instead of settling for a
		# weaker (or even reversed) pull — that sign is what makes it converge.
		var separating_speed: float = (player_b.velocity - player_a.velocity).dot(direction)
		var pull_accel: float = clamp(stretch * stiffness + separating_speed * damping, -max_pull_accel, max_pull_accel)
		var pull: Vector2 = direction * pull_accel
		player_a.rope_pull += pull
		player_b.rope_pull -= pull

	line.points = PackedVector2Array([to_local(player_a.global_position), to_local(player_b.global_position)])
