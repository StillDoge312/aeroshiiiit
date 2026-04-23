extends CharacterBody3D

@export var move_speed: float = 8.0
@export var ground_acceleration: float = 28.0
@export var air_acceleration: float = 8.0
@export var jump_velocity: float = 6.0
@export var look_sensitivity: float = 0.0045
@export var min_pitch: float = deg_to_rad(-70.0)
@export var max_pitch: float = deg_to_rad(55.0)

@onready var visual: Node3D = $Visual
@onready var camera_rig: Node3D = $CameraRig
@onready var pitch_pivot: Node3D = $CameraRig/PitchPivot

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _yaw: float = 0.0
var _pitch: float = deg_to_rad(-14.0)
var _camera_rotate_active: bool = false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	camera_rig.rotation.y = _yaw
	pitch_pivot.rotation.x = _pitch


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_rotate"):
		_camera_rotate_active = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_released("camera_rotate"):
		_camera_rotate_active = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if _camera_rotate_active and event is InputEventMouseMotion:
		_yaw -= event.relative.x * look_sensitivity
		_pitch = clamp(_pitch - event.relative.y * look_sensitivity, min_pitch, max_pitch)
		camera_rig.rotation.y = _yaw
		pitch_pivot.rotation.x = _pitch


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	var input_axis := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	var cam_basis := camera_rig.global_transform.basis
	var cam_forward := -cam_basis.z
	cam_forward.y = 0.0
	cam_forward = cam_forward.normalized()
	var cam_right := cam_basis.x
	cam_right.y = 0.0
	cam_right = cam_right.normalized()

	var move_dir := (cam_right * input_axis.x + cam_forward * input_axis.y).normalized()
	var target_velocity := move_dir * move_speed
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var accel := ground_acceleration if is_on_floor() else air_acceleration
	horizontal_velocity = horizontal_velocity.move_toward(target_velocity, accel * delta)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	if move_dir.length() > 0.01:
		var target_yaw := atan2(-move_dir.x, -move_dir.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, min(1.0, delta * 10.0))

	move_and_slide()
