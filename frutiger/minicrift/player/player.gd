extends CharacterBody3D

const SPEED := 5.0
const JUMP_VELOCITY := 4.5
const MOUSE_SENSITIVITY := 0.0025
const REACH_DISTANCE := 5.0
const HIT_EPSILON := 0.01

@export var world_grid_path: NodePath
@export var highlight_path: NodePath
@export var debug_label_path: NodePath

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var raycast: RayCast3D = $Head/BlockRayCast

var world_grid: Node
var highlight: MeshInstance3D
var debug_label: Label
var target_break_cell := Vector3i.ZERO
var target_place_cell := Vector3i.ZERO
var has_target := false

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	ray_cast_setup()
	world_grid = get_node_or_null(world_grid_path)
	highlight = get_node_or_null(highlight_path) as MeshInstance3D
	debug_label = get_node_or_null(debug_label_path) as Label
	_resolve_scene_references()
	if highlight != null:
		highlight.visible = false

func _resolve_scene_references() -> void:
	var parent_scene := get_parent()
	if parent_scene != null:
		if world_grid == null:
			world_grid = parent_scene.get_node_or_null("World/WorldGrid")
		if highlight == null:
			highlight = parent_scene.get_node_or_null("World/BlockHighlight") as MeshInstance3D
		if debug_label == null:
			debug_label = parent_scene.get_node_or_null("UI/DebugLabel") as Label
	var scene := get_tree().current_scene
	if scene == null:
		return
	if world_grid == null:
		world_grid = scene.get_node_or_null("World/WorldGrid")
	if highlight == null:
		highlight = scene.get_node_or_null("World/BlockHighlight") as MeshInstance3D
	if debug_label == null:
		debug_label = scene.get_node_or_null("UI/DebugLabel") as Label

func ray_cast_setup() -> void:
	raycast.enabled = true
	raycast.target_position = Vector3(0, 0, -REACH_DISTANCE)
	raycast.collide_with_areas = false
	raycast.collide_with_bodies = true

func _input(event: InputEvent) -> void:
	_handle_game_input(event)

func _handle_game_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED)
	if event.is_action_pressed("break_block"):
		try_break_block()
	if event.is_action_pressed("place_block"):
		try_place_block()
	for i in Inventory.HOTBAR_SIZE:
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			Inventory.set_active(i)
	if event.is_action_pressed("hotbar_prev"):
		Inventory.cycle(-1)
	if event.is_action_pressed("hotbar_next"):
		Inventory.cycle(1)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	move_and_slide()
	update_target()

func update_target() -> void:
	raycast.force_raycast_update()
	has_target = false
	if world_grid == null or not raycast.is_colliding():
		_set_highlight_visible(false)
		_update_debug_label()
		return
	var hit_pos: Vector3 = raycast.get_collision_point()
	var hit_normal: Vector3 = raycast.get_collision_normal()
	target_break_cell = world_grid.world_to_grid(hit_pos - hit_normal * HIT_EPSILON)
	target_place_cell = world_grid.world_to_grid(hit_pos + hit_normal * HIT_EPSILON)
	has_target = world_grid.get_block_at(target_break_cell) != null
	_set_highlight_visible(has_target)
	if has_target and highlight != null:
		highlight.global_position = world_grid.grid_to_world(target_break_cell)
	_update_debug_label()

func try_break_block() -> void:
	update_target()
	if not has_target or world_grid == null:
		return
	var block: Resource = world_grid.get_block_at(target_break_cell)
	if block == null or not block.is_breakable or not Inventory.can_add(block.id, 1):
		return
	var removed: Resource = world_grid.break_block(target_break_cell)
	if removed != null:
		Inventory.add(removed.id, 1)

func try_place_block() -> void:
	update_target()
	if not raycast.is_colliding() or world_grid == null:
		return
	var block: Resource = Inventory.get_active_block()
	if block == null:
		return
	if world_grid.place_block(target_place_cell, block):
		Inventory.remove_from_active(1)

func _set_highlight_visible(value: bool) -> void:
	if highlight != null:
		highlight.visible = value

func _update_debug_label() -> void:
	if debug_label == null:
		return
	debug_label.text = "Break: %s\nPlace: %s\nTarget: %s" % [target_break_cell, target_place_cell, has_target]
