extends Camera2D

# A single shared camera (not per-player) that frames every connected player
# at once — centers on the midpoint of their bounding box and zooms out just
# enough to keep everyone on screen (with margin), zooming back in as they
# regroup. Runs identically and independently on every client's local view;
# it only reads player positions, never writes anything, so it has no effect
# on gameplay or networking.

@export var margin: float = 150.0
# Camera2D.zoom: LARGER values zoom IN (magnify), SMALLER values zoom OUT
# (show more of the world) — the opposite of what the name suggests.
@export var min_zoom: float = 0.5  # farthest out — used when players are spread apart
@export var max_zoom: float = 1.4  # closest in — used when players are bunched together
@export var follow_speed: float = 6.0
@export var zoom_speed: float = 4.0
# Fraction of the screen's height that should be above the players (vs.
# below). 2.0/3.0 means 2/3 of the view is above them, 1/3 below — useful
# for a platformer where seeing what's above/ahead of a jump matters more
# than what's below. 0.5 would be dead-center.
@export var above_fraction: float = 2.0 / 3.0

var _initialized: bool = false

func _ready() -> void:
	make_current()

func _physics_process(delta: float) -> void:
	var positions: Array[Vector2] = []
	for player in get_tree().get_nodes_in_group("players"):
		if is_instance_valid(player):
			positions.append(player.global_position)

	if positions.is_empty():
		return

	var min_pos: Vector2 = positions[0]
	var max_pos: Vector2 = positions[0]
	for pos in positions:
		min_pos.x = min(min_pos.x, pos.x)
		min_pos.y = min(min_pos.y, pos.y)
		max_pos.x = max(max_pos.x, pos.x)
		max_pos.y = max(max_pos.y, pos.y)

	var center: Vector2 = (min_pos + max_pos) * 0.5
	var box_size: Vector2 = (max_pos - min_pos) + Vector2.ONE * margin * 2.0

	var viewport_size: Vector2 = get_viewport_rect().size
	# A bigger bounding box needs a SMALLER zoom value to show more of the
	# world (see the zoom comment above) — hence the reciprocal here.
	var coverage_ratio: float = max(box_size.x / viewport_size.x, box_size.y / viewport_size.y)
	var target_zoom_scalar: float = clamp(1.0 / coverage_ratio, min_zoom, max_zoom)

	if not _initialized:
		# Snap on the very first frame instead of smoothly drifting in from
		# wherever the camera node happens to start in the scene.
		global_position = center
		zoom = Vector2(target_zoom_scalar, target_zoom_scalar)
		_initialized = true
	else:
		global_position = global_position.lerp(center, 1.0 - exp(-follow_speed * delta))
		var new_zoom_scalar: float = lerp(zoom.x, target_zoom_scalar, 1.0 - exp(-zoom_speed * delta))
		zoom = Vector2(new_zoom_scalar, new_zoom_scalar)

	# Recomputed every frame (not a fixed world-space value) so the 2/3-above,
	# 1/3-below split stays a constant SCREEN-space proportion as zoom changes
	# — offset is in world units and gets scaled by zoom just like position,
	# so the same raw offset would shift by a different amount on screen at a
	# different zoom level if we didn't divide it out here.
	var visible_world_height: float = viewport_size.y / zoom.y
	offset = Vector2(0.0, -(above_fraction - 0.5) * visible_world_height)
