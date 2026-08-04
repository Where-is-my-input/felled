extends CharacterBody2D


const SPEED = 300.0
const MIN_JUMP_VELOCITY = -220.0
const MAX_JUMP_VELOCITY = -650.0
const MAX_CHARGE_TIME = 1.0
const MAX_JUMP_ANGLE_DEG = 75.0
const JUMP_ANGLE_STEP_DEG = 5.0
const JUMP_ANGLE_STEP_INTERVAL = 0.1
const MIN_HORIZONTAL_LAUNCH_SPEED = 200.0
const MAX_HORIZONTAL_LAUNCH_SPEED = 600.0

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
					if jump_direction == 0.0:
						jump_direction = input_sign
						angle_step_timer = 0.0
					elif input_sign != sign(jump_direction):
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

	velocity += rope_pull * delta
	rope_pull = Vector2.ZERO

	move_and_slide()
