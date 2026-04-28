extends CharacterBody3D

const WALK_SOUND_PATH := "res://sounds/walk.mp3"

@export var move_speed: float = 8.0
@export var ground_acceleration: float = 28.0
@export var air_acceleration: float = 8.0
@export var jump_velocity: float = 6.0
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.15
@export var look_sensitivity: float = 0.0045
@export var min_pitch: float = deg_to_rad(-70.0)
@export var max_pitch: float = deg_to_rad(55.0)
@export var model_yaw_offset: float = deg_to_rad(90.0)
@export var glass_color: Color = Color(0.16, 0.52, 1.0, 0.28)
@export var glass_roughness: float = 0.06
@export var glass_metallic: float = 0.02
@export var outline_color: Color = Color(0.0, 0.0, 0.0, 1.0)
@export var outline_thickness: float = 0.03
@export_range(0.01, 0.95, 0.01) var outline_edge_threshold: float = 0.35
@export var idle_animation_name: StringName = &"Idle"
@export var walk_animation_name: StringName = &"Walk"
@export var jump_animation_name: StringName = &"Jump"
@export var animation_blend_time: float = 0.2

@onready var visual: Node3D = $Visual
@onready var camera_rig: Node3D = $CameraRig
@onready var pitch_pivot: Node3D = $CameraRig/PitchPivot
@onready var spring_arm: SpringArm3D = $CameraRig/PitchPivot/SpringArm3D
@onready var animation_player: AnimationPlayer = _find_animation_player()

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _yaw: float = 0.0
var _pitch: float = deg_to_rad(-14.0)
var _camera_rotate_active: bool = false
var _controls_enabled: bool = true
var _jump_buffer_left: float = 0.0
var _coyote_left: float = 0.0
var _idle_animation: StringName = StringName()
var _walk_animation: StringName = StringName()
var _jump_animation: StringName = StringName()
var _current_animation: StringName = StringName()
var _walk_sound: AudioStreamPlayer


func _ready() -> void:
	_ensure_jump_action()
	_setup_walk_sound()
	_configure_camera_collision()
	_apply_glass_material()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	camera_rig.rotation.y = _yaw
	pitch_pivot.rotation.x = _pitch
	_resolve_animation_names()


func _unhandled_input(event: InputEvent) -> void:
	if not _controls_enabled:
		return
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
	if not _controls_enabled:
		velocity = Vector3.ZERO
		_set_walk_sound_playing(false)
		_update_animation_state(0.0)
		move_and_slide()
		return

	var jump_pressed: bool = Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("ui_accept")
	if jump_pressed:
		_jump_buffer_left = jump_buffer_time
	else:
		_jump_buffer_left = max(0.0, _jump_buffer_left - delta)

	if is_on_floor():
		_coyote_left = coyote_time
	else:
		_coyote_left = max(0.0, _coyote_left - delta)

	if _jump_buffer_left > 0.0 and _coyote_left > 0.0:
		velocity.y = jump_velocity
		_jump_buffer_left = 0.0
		_coyote_left = 0.0

	if not is_on_floor():
		velocity.y -= _gravity * delta

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
		visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw + model_yaw_offset, min(1.0, delta * 10.0))

	var should_play_walk := is_on_floor() and horizontal_velocity.length() > 0.15
	_set_walk_sound_playing(should_play_walk)
	_update_animation_state(horizontal_velocity.length())
	move_and_slide()


func _ensure_jump_action() -> void:
	if InputMap.has_action("jump"):
		return
	InputMap.add_action("jump")
	var jump_key := InputEventKey.new()
	jump_key.physical_keycode = KEY_SPACE
	InputMap.action_add_event("jump", jump_key)


func set_controls_enabled(enabled: bool) -> void:
	_controls_enabled = enabled
	_camera_rotate_active = false
	if not enabled:
		_set_walk_sound_playing(false)
	if not enabled:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _setup_walk_sound() -> void:
	_ensure_audio_bus("SFX")
	var stream := load(WALK_SOUND_PATH) as AudioStream
	if stream == null:
		return
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true

	_walk_sound = AudioStreamPlayer.new()
	_walk_sound.stream = stream
	_walk_sound.bus = "SFX"
	_walk_sound.volume_db = -8.0
	add_child(_walk_sound)


func _ensure_audio_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	var insert_index := AudioServer.get_bus_count()
	AudioServer.add_bus(insert_index)
	AudioServer.set_bus_name(insert_index, bus_name)
	AudioServer.set_bus_send(insert_index, "Master")


func _set_walk_sound_playing(playing: bool) -> void:
	if _walk_sound == null:
		return
	if playing:
		if not _walk_sound.playing:
			_walk_sound.play()
		return
	if _walk_sound.playing:
		_walk_sound.stop()


func _configure_camera_collision() -> void:
	if spring_arm == null:
		return
	spring_arm.add_excluded_object(get_rid())
	var collision_nodes: Array[Node] = find_children("*", "CollisionObject3D", true, false)
	for node in collision_nodes:
		var collision_object := node as CollisionObject3D
		if collision_object == null:
			continue
		spring_arm.add_excluded_object(collision_object.get_rid())


func _apply_glass_material() -> void:
	var glass_material := _make_glass_material()
	var meshes: Array[Node] = visual.find_children("*", "MeshInstance3D", true, false)
	for mesh_node in meshes:
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance == null:
			continue
		mesh_instance.material_override = glass_material


func _make_glass_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	material.albedo_color = glass_color
	material.roughness = glass_roughness
	material.metallic = glass_metallic
	material.clearcoat = 1.0
	material.clearcoat_roughness = 0.03
	material.emission_enabled = true
	material.emission = Color(0.04, 0.1, 0.24, 1.0)
	material.emission_energy_multiplier = 0.4
	material.next_pass = _make_outline_material()
	return material


func _make_outline_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_thickness = 0.03;
uniform float edge_threshold = 0.35;

void vertex() {
	VERTEX += NORMAL * outline_thickness;
}

void fragment() {
	float ndv = abs(dot(normalize(NORMAL), normalize(VIEW)));
	if (ndv > edge_threshold) {
		discard;
	}
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}
"""

	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("outline_color", outline_color)
	material.set_shader_parameter("outline_thickness", outline_thickness)
	material.set_shader_parameter("edge_threshold", outline_edge_threshold)
	return material


func _find_animation_player() -> AnimationPlayer:
	var players: Array[Node] = visual.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return null
	return players[0] as AnimationPlayer


func _resolve_animation_names() -> void:
	if animation_player == null:
		return
	_idle_animation = _resolve_animation_name(idle_animation_name, PackedStringArray(["idle"]))
	_walk_animation = _resolve_animation_name(walk_animation_name, PackedStringArray(["walk", "step", "run"]))
	_jump_animation = _resolve_animation_name(jump_animation_name, PackedStringArray(["jump", "fall"]))
	_play_animation(_idle_animation)


func _resolve_animation_name(preferred: StringName, fallback_tokens: PackedStringArray) -> StringName:
	if animation_player.has_animation(preferred):
		return preferred

	var animation_list: PackedStringArray = animation_player.get_animation_list()
	for animation_name in animation_list:
		var lowered_name := animation_name.to_lower()
		for token in fallback_tokens:
			if lowered_name.contains(token):
				return StringName(animation_name)

	return StringName()


func _update_animation_state(horizontal_speed: float) -> void:
	if animation_player == null:
		return

	if not is_on_floor():
		_play_animation(_jump_animation)
		return

	if horizontal_speed > 0.15:
		_play_animation(_walk_animation)
		return

	_play_animation(_idle_animation)


func _play_animation(animation_name: StringName) -> void:
	if animation_name == StringName():
		return
	if _current_animation == animation_name:
		return
	_current_animation = animation_name
	animation_player.play(String(animation_name), animation_blend_time)
