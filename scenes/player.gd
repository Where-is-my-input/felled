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

@onready var jump_indicator: Line2D = $JumpIndicator

var charging_jump: bool = false
var jump_charge_time: float = 0.0
var jump_direction: float = 0.0
var angle_step_timer: float = 0.0

# Accumulated by any Rope this frame (see rope.gd, which runs at a lower
# process_physics_priority so its pull lands before it's consumed below),
# then folded into velocity and reset every physics frame.
var rope_pull: Vector2 = Vector2.ZERO

func _ready() -> void:
	print("Multiplayer authority will be set to: ", name.to_int())
	set_multiplayer_authority(name.to_int())
	
	# setting this here because only the owner has authority to set it
	position = Vector2(455, 79)


func _physics_process(delta: float) -> void:
	if !is_multiplayer_authority(): return

	var horizontal_input: float = Input.get_axis("ui_left", "ui_right")

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		if charging_jump:
			if Input.is_action_just_released("ui_accept"):
				var charge_ratio: float = clamp(jump_charge_time / MAX_CHARGE_TIME, 0.0, 1.0)
				var launch_velocity_y: float = lerp(MIN_JUMP_VELOCITY, MAX_JUMP_VELOCITY, charge_ratio)
				var launch_horizontal_speed: float = lerp(MIN_HORIZONTAL_LAUNCH_SPEED, MAX_HORIZONTAL_LAUNCH_SPEED, charge_ratio)
				velocity = Vector2(jump_direction * launch_horizontal_speed, launch_velocity_y)
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
		if charging_jump:
			velocity.x = 0.0
		elif horizontal_input != 0.0:
			velocity.x = horizontal_input * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
	# Airborne: no horizontal control — velocity.x keeps whatever the jump launched it with.

	# Charging or mid-air, the rope should be easier to fight against so a jump
	# can actually pull you away from your rope-mate instead of being reeled in.
	var rope_pull_scale: float = ROPE_PULL_SCALE_WHILE_JUMPING if (charging_jump or not is_on_floor()) else 1.0
	velocity += rope_pull * rope_pull_scale * delta
	rope_pull = Vector2.ZERO

	_update_jump_indicator()

	move_and_slide()

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
