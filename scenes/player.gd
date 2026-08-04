extends CharacterBody2D


const SPEED = 300.0
const MIN_JUMP_VELOCITY = -220.0
const MAX_JUMP_VELOCITY = -650.0
const MAX_CHARGE_TIME = 1.0

var charging_jump: bool = false
var jump_charge_time: float = 0.0

func _ready() -> void:
	print("Multiplayer authority will be set to: ", name.to_int())
	set_multiplayer_authority(name.to_int())
	
	# setting this here because only the owner has authority to set it
	position = Vector2(455, 79)


func _physics_process(delta: float) -> void:
	if !is_multiplayer_authority(): return

	var direction: float = Input.get_axis("ui_left", "ui_right")

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		if charging_jump:
			if Input.is_action_just_released("ui_accept"):
				var charge_ratio: float = clamp(jump_charge_time / MAX_CHARGE_TIME, 0.0, 1.0)
				velocity.y = lerp(MIN_JUMP_VELOCITY, MAX_JUMP_VELOCITY, charge_ratio)
				charging_jump = false
				jump_charge_time = 0.0
			elif direction != 0.0:
				charging_jump = false
				jump_charge_time = 0.0
				charging_jump = true
			elif Input.is_action_pressed("ui_accept"):
				charging_jump = true
				jump_charge_time += delta
				jump_charge_time = min(jump_charge_time, MAX_CHARGE_TIME)
		elif Input.is_action_pressed("ui_accept"):
			charging_jump = true
			jump_charge_time = 0.0

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	if charging_jump and is_on_floor():
		velocity.x = 0.0
	elif direction != 0.0:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
