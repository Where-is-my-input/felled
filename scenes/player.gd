extends CharacterBody2D


const SPEED = 300.0
const MIN_JUMP_VELOCITY = -220.0
const MAX_JUMP_VELOCITY = -650.0
const MAX_CHARGE_TIME = 1.0
const MAX_JUMP_ANGLE_DEG = 75.0
const JUMP_ANGLE_STEP_DEG = 5.0
const JUMP_ANGLE_STEP_INTERVAL = 0.025
const MIN_HORIZONTAL_LAUNCH_SPEED = 200.0
const MAX_HORIZONTAL_LAUNCH_SPEED = 900.0
const ROPE_PULL_SCALE_WHILE_JUMPING = 0.35
const MIN_JUMP_INDICATOR_LENGTH = 16.0
const MAX_JUMP_INDICATOR_LENGTH = 48.0
const DANGLE_STEER_ACCEL = 2400.0
const DANGLE_STEER_MAX_SPEED = 220.0
# Walk speed multiplier applied while a taut rope is at its max stretch and
# the player is walking further away (see _rope_drag_multiplier) — simulates
# the drag of hauling the rope-mate's weight along. Lerped between 1.0 (slack
# rope) and this at max stretch, not an instant cutoff.
const ROPE_DRAG_MIN_MULTIPLIER = 0.5
# Fraction of horizontal speed kept (reversed, i.e. a small bounce-back)
# after move_and_slide blocks it against something roughly vertical-faced —
# a wall or another player hit from the side — instead of losing it all
# outright the way a plain slide response would.
const WALL_BOUNCE_RETENTION = 0.3
# Super Mario Bros-style corner correction: while airborne, if horizontal
# movement is only blocked because the player's hitbox barely clips a wall's
# top/bottom edge by this many pixels or less, nudge the player around the
# corner (see _apply_corner_correction) instead of stopping/bouncing them.
const CORNER_CORRECTION_MAX_OFFSET = 8.0
# Used only if the level has no checkpoint in the "checkpoints" group with
# is_first_checkpoint = true — see _find_spawn_position().
const DEFAULT_SPAWN_POSITION = Vector2(455, 79)

@onready var jump_indicator: Line2D = $JumpIndicator
@onready var name_label: Label = $NameLabel

var charging_jump: bool = false
var jump_charge_time: float = 0.0
var jump_direction: float = 0.0
var angle_step_timer: float = 0.0

# True only from the moment a self-initiated jump launches until landing —
# NOT true just because the player is airborne (e.g. yanked off the ground by
# the rope, or walked off a ledge). Gates horizontal air control: while
# is_jumping, velocity.x is left alone so an aimed jump's trajectory can't be
# steered after the fact; whenever airborne without it, the player is just
# dangling/falling and can freely steer left/right.
var is_jumping: bool = false

# Accumulated by any Rope this frame (see rope.gd, which runs at a lower
# process_physics_priority so its pull lands before it's consumed below),
# then folded into velocity and reset every physics frame.
var rope_pull: Vector2 = Vector2.ZERO

# Like rope_pull, but added directly to velocity with no *delta — a one-time
# instant kick (see rope.gd) rather than a continuous acceleration, applied
# the instant a pull key is first pressed for a punchy "tug" instead of a
# slow ramp-up.
var rope_kick: Vector2 = Vector2.ZERO

# Set by RopeManager when a rope attaches to this player (see rope_manager.gd).
# "previous"/"next" refer to connection order — rope_to_previous is the rope
# where this player is the later-joined end, rope_to_next the earlier end.
var rope_to_previous: Node = null
var rope_to_next: Node = null

# Replicated (see player.tscn's MultiplayerSynchronizer) so every peer's local
# Rope instance can see who's pulling, not just the pulling player's own client.
var is_pulling_previous: bool = false
var is_pulling_next: bool = false

# Replicated (see player.tscn's MultiplayerSynchronizer) so every peer sees the
# nickname above this player's head, not just the owning client. Only the
# owning peer ever writes this (from Global.username, set via the profile menu
# in main_menu.tscn) — everyone else just displays whatever comes in over sync.
var display_name: String = ""

func _ready() -> void:
	print("Multiplayer authority will be set to: ", name.to_int())
	set_multiplayer_authority(name.to_int())
	add_to_group("players")  # so the shared dynamic camera (dynamic_camera.gd) can find every player

	if is_multiplayer_authority():
		display_name = Global.username

	# setting this here because only the owner has authority to set it
	position = _find_spawn_position()

# Looks for a level checkpoint marked as the first one and spawns there
# instead; falls back to the hardcoded default if the level has none placed
# yet (e.g. debug_level.tscn before any checkpoint is authored in it).
func _find_spawn_position() -> Vector2:
	for checkpoint in get_tree().get_nodes_in_group("checkpoints"):
		if checkpoint.is_first_checkpoint:
			return checkpoint.global_position
	return DEFAULT_SPAWN_POSITION

# Called by external mechanics (currently just trampoline.gd) that want to
# launch the player with a specific velocity the same way a self-initiated
# jump works: cancel any in-progress charge, and set is_jumping so the
# resulting trajectory is locked (can't be immediately steered away) just
# like an aimed jump's arc already is.
func apply_external_launch(new_velocity: Vector2) -> void:
	charging_jump = false
	jump_charge_time = 0.0
	jump_direction = 0.0
	angle_step_timer = 0.0
	is_jumping = true
	velocity = new_velocity

# Ungated by multiplayer authority (unlike _physics_process) so the label
# stays in sync with display_name on every peer, including remote players
# whose name only ever arrives via replication.
func _process(_delta: float) -> void:
	name_label.text = display_name

	# Name tags live in world space (children of this Node2D), so the shared
	# dynamic camera's zoom would otherwise magnify/shrink them along with
	# everything else. Counter-scale by 1/zoom each frame so the tag stays a
	# constant size on screen no matter how far GameCamera has zoomed.
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera != null and camera.zoom.x > 0.0 and camera.zoom.y > 0.0:
		name_label.scale = Vector2.ONE / camera.zoom


func _physics_process(delta: float) -> void:
	if !is_multiplayer_authority(): return

	var horizontal_input: float = Input.get_axis("ui_left", "ui_right")

	is_pulling_previous = rope_to_previous != null and Input.is_action_pressed("pull_previous")
	is_pulling_next = rope_to_next != null and Input.is_action_pressed("pull_next")

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		is_jumping = false
		if charging_jump:
			if Input.is_action_pressed("ui_down"):
				# Cancel the charge outright — no jump, and ground movement
				# resumes immediately since charging_jump is now false.
				charging_jump = false
				jump_charge_time = 0.0
				jump_direction = 0.0
				angle_step_timer = 0.0
			elif Input.is_action_just_released("ui_accept"):
				var charge_ratio: float = clamp(jump_charge_time / MAX_CHARGE_TIME, 0.0, 1.0)
				var launch_velocity_y: float = lerp(MIN_JUMP_VELOCITY, MAX_JUMP_VELOCITY, charge_ratio)
				var launch_horizontal_speed: float = lerp(MIN_HORIZONTAL_LAUNCH_SPEED, MAX_HORIZONTAL_LAUNCH_SPEED, charge_ratio)
				velocity = Vector2(jump_direction * launch_horizontal_speed, launch_velocity_y)
				is_jumping = true
				charging_jump = false
				jump_charge_time = 0.0
				jump_direction = 0.0
			elif Input.is_action_pressed("ui_accept"):
				jump_charge_time += delta
				jump_charge_time = min(jump_charge_time, MAX_CHARGE_TIME)
				if horizontal_input != 0.0:
					var input_sign: float = sign(horizontal_input)
					# Compare directly against the target (not sign() vs sign()) so a ramp
					# that's crossing through neutral keeps stepping smoothly instead of
					# hitting a "starting from zero" special case and snapping the rest of
					# the way to max.
					if jump_direction != input_sign:
						angle_step_timer += delta
						var step_fraction: float = JUMP_ANGLE_STEP_DEG / MAX_JUMP_ANGLE_DEG
						while angle_step_timer >= JUMP_ANGLE_STEP_INTERVAL:
							angle_step_timer -= JUMP_ANGLE_STEP_INTERVAL
							jump_direction = move_toward(jump_direction, input_sign, step_fraction)
					jump_direction = clamp(jump_direction, -1.0, 1.0)
		elif Input.is_action_pressed("ui_accept"):
			charging_jump = true
			jump_charge_time = 0.0
			angle_step_timer = 0.0
			jump_direction = clamp(sign(horizontal_input), -1.0, 1.0)

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	if is_on_floor():
		# Belt's target speed if standing on a conveyor_belt.gd floor this
		# frame, else zero — see _get_conveyor_push_velocity().
		var conveyor_push_x: float = _get_conveyor_push_velocity().x
		if charging_jump:
			velocity.x = 0.0
		elif horizontal_input != 0.0:
			# Walking adds on top of the belt instead of being capped by it,
			# so fighting the belt is possible but riding it is faster.
			var walk_speed: float = SPEED * _rope_drag_multiplier(horizontal_input)
			velocity.x = horizontal_input * walk_speed + conveyor_push_x
		else:
			velocity.x = move_toward(velocity.x, conveyor_push_x, SPEED)
	elif not is_jumping:
		# Airborne but not from a self-initiated jump — dangling off the rope
		# (or just falling) rather than mid-trajectory, so steering is fine.
		if horizontal_input != 0.0:
			velocity.x = move_toward(velocity.x, horizontal_input * DANGLE_STEER_MAX_SPEED, DANGLE_STEER_ACCEL * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, DANGLE_STEER_ACCEL * delta)
	# Airborne from a jump: no horizontal control — velocity.x keeps whatever the jump launched it with.

	# Charging or mid-air, the rope should be easier to fight against so a jump
	# can actually pull you away from your rope-mate instead of being reeled in.
	var rope_pull_scale: float = ROPE_PULL_SCALE_WHILE_JUMPING if (charging_jump or not is_on_floor()) else 1.0
	velocity += (rope_pull * delta + rope_kick) * rope_pull_scale
	rope_pull = Vector2.ZERO
	rope_kick = Vector2.ZERO

	if charging_jump and is_on_floor():
		# Bracing for a jump plants you — the rope can still slide you side to
		# side, but it can never yank you up off the ground while you're
		# anchored like this. Your rope-mate gets flung around instead.
		velocity.y = max(velocity.y, 0.0)

	_update_jump_indicator()

	if not is_on_floor():
		_apply_corner_correction(delta)

	var pre_slide_velocity_x: float = velocity.x
	move_and_slide()
	_apply_wall_bounce(pre_slide_velocity_x)

# Slows walking down while it's stretching an attached rope taut by walking
# further away from the other end — NOT while walking toward them (which only
# slackens the rope) or while the rope is already slack. Mirrors dragging the
# rope-mate's actual weight: barely noticeable near rest length, strongest
# once the rope is stretched near its hard max.
func _rope_drag_multiplier(horizontal_input: float) -> float:
	var multiplier: float = 1.0
	for rope in [rope_to_previous, rope_to_next]:
		if rope == null:
			continue
		var partner: CharacterBody2D = rope.get_partner(self)
		if partner == null:
			continue
		var away_from_partner: float = sign(global_position.x - partner.global_position.x)
		if away_from_partner == 0.0 or sign(horizontal_input) != away_from_partner:
			continue
		var stretch_fraction: float = rope.get_stretch_fraction()
		multiplier = min(multiplier, lerp(1.0, ROPE_DRAG_MIN_MULTIPLIER, stretch_fraction))
	return multiplier

# Checks whether the floor collision that made is_on_floor() true this frame
# came from a conveyor_belt.gd — if so, returns the speed it wants to carry
# a standing player at, otherwise Vector2.ZERO. Queried instead of pushed
# onto the player (unlike rope_pull/rope_kick) because a belt has no
# per-player state to track between frames.
func _get_conveyor_push_velocity() -> Vector2:
	for i in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(i)
		if collision.get_normal().dot(Vector2.UP) < 0.5:
			continue
		var collider: Object = collision.get_collider()
		if collider is Node and collider.is_in_group("conveyor_belts"):
			return collider.get_push_velocity()
	return Vector2.ZERO

# Tries to slip the player past a wall corner it's only barely clipping,
# instead of letting move_and_slide block/bounce it off the wall face. Tests
# this frame's horizontal motion from progressively larger vertical offsets
# (both up and down, smallest first) and snaps to the first one that clears
# both the nudge itself and the horizontal move — i.e. only kicks in for a
# shallow edge-graze, not a real head-on wall hit.
func _apply_corner_correction(delta: float) -> void:
	if is_zero_approx(velocity.x):
		return
	var horizontal_motion: Vector2 = Vector2(velocity.x * delta, 0.0)
	if not test_move(global_transform, horizontal_motion):
		return
	for offset in range(1, int(CORNER_CORRECTION_MAX_OFFSET) + 1):
		for direction in [-1.0, 1.0]:
			var nudge: Vector2 = Vector2(0.0, offset * direction)
			if test_move(global_transform, nudge):
				continue
			var nudged_transform: Transform2D = global_transform
			nudged_transform.origin += nudge
			if not test_move(nudged_transform, horizontal_motion):
				global_position += nudge
				return

# move_and_slide's default response to hitting something solid is to just
# zero out whatever velocity component was blocked — fine for landing on a
# floor, but it means bumping a wall or another player sideways (mid-jump,
# dangling, being flung by the rope, etc.) killed all horizontal momentum
# outright. This restores a fraction of it as a small bounce-back whenever a
# collision this frame had a roughly-vertical surface (a wall-like normal,
# not a floor/ceiling one).
func _apply_wall_bounce(pre_slide_velocity_x: float) -> void:
	if abs(pre_slide_velocity_x) < 0.01:
		return
	for i in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(i)
		var normal: Vector2 = collision.get_normal()
		if abs(normal.x) > 0.5:
			velocity.x = normal.x * abs(pre_slide_velocity_x) * WALL_BOUNCE_RETENTION
			break

# Shows where the jump will actually launch, using the same charge_ratio math
# as the release branch above, so it stays accurate throughout the charge.
func _update_jump_indicator() -> void:
	if not charging_jump:
		jump_indicator.visible = false
		return

	var charge_ratio: float = clamp(jump_charge_time / MAX_CHARGE_TIME, 0.0, 1.0)
	var launch_velocity_y: float = lerp(MIN_JUMP_VELOCITY, MAX_JUMP_VELOCITY, charge_ratio)
	var launch_horizontal_speed: float = lerp(MIN_HORIZONTAL_LAUNCH_SPEED, MAX_HORIZONTAL_LAUNCH_SPEED, charge_ratio)
	var launch_direction: Vector2 = Vector2(jump_direction * launch_horizontal_speed, launch_velocity_y).normalized()
	var indicator_length: float = lerp(MIN_JUMP_INDICATOR_LENGTH, MAX_JUMP_INDICATOR_LENGTH, charge_ratio)

	jump_indicator.visible = true
	jump_indicator.points = PackedVector2Array([Vector2.ZERO, launch_direction * indicator_length])
