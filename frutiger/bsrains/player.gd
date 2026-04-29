extends CharacterBody3D

@export var mouse_sens : float = 0.0005


@onready var neck: Node3D = %neck
@onready var ray_cast_3d: RayCast3D = $neck/Camera3D/RayCast3D

var double_jump_available : bool = true

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

func _ready() -> void:
	add_to_group("brains_player")
	_ensure_interact_action()
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var vector : Vector2 = (event.relative * -1) * mouse_sens
		
		rotate_y(vector.x)
		neck.rotate_x(vector.y)
		
		neck.rotation.x = clamp(neck.rotation.x, -PI/2, PI/2)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		double_jump_available = true
	
	if (Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("ui_accept")) and (is_on_floor() or double_jump_available):
		if not is_on_floor():
			double_jump_available = false
		
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	
	if Input.is_action_just_pressed("interact"):
		if ray_cast_3d.is_colliding():
			if ray_cast_3d.get_collider().has_method(&"action"):
				ray_cast_3d.get_collider().call(&"action")
	
	move_and_slide()


func _ensure_interact_action() -> void:
	if InputMap.has_action("interact"):
		return
	InputMap.add_action("interact")
	var interact_key := InputEventKey.new()
	interact_key.physical_keycode = KEY_E
	InputMap.action_add_event("interact", interact_key)
