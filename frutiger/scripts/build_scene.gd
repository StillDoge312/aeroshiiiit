extends Node3D
## Строительная площадка — режим от первого лица.
## Вызвать enter_build_mode() чтобы войти.
## ESC — выйти. Постройка сохраняется.

signal build_mode_exited

const REACH := 8.0
const EPS := 0.01
const SPEED := 5.0
const JUMP_VEL := 4.5
const MSENS := 0.0025

const BLOCK_DEFS := [
	{"name": "Stone", "color": Color(0.46, 0.47, 0.50), "accent": Color(0.25, 0.26, 0.29)},
	{"name": "Dirt",  "color": Color(0.42, 0.25, 0.13), "accent": Color(0.22, 0.12, 0.06)},
	{"name": "Grass", "color": Color(0.22, 0.60, 0.18), "accent": Color(0.10, 0.34, 0.10)},
	{"name": "Wood",  "color": Color(0.56, 0.32, 0.14), "accent": Color(0.30, 0.16, 0.07)},
	{"name": "Glass", "color": Color(0.58, 0.88, 1.0, 0.62), "accent": Color(0.90, 1.0, 1.0, 0.85), "transparent": true},
]

var grid_map: GridMap
var highlight: MeshInstance3D
var block_label: Label
var crosshair: Label
var active_block: int = 0
var _building: bool = false
var _fps_player: CharacterBody3D
var _fps_head: Node3D
var _fps_camera: Camera3D
var _fps_raycast: RayCast3D
var _main_player: CharacterBody3D
var _ui: CanvasLayer


func _ready() -> void:
	_build_grid()
	_build_highlight()
	_build_ui()
	_seed_ground()
	_ui.visible = false
	highlight.visible = false


func enter_build_mode() -> void:
	if _building:
		return
	_building = true

	# find and disable main player
	_main_player = get_parent().get_node_or_null("Player") as CharacterBody3D
	if _main_player != null and _main_player.has_method("set_controls_enabled"):
		_main_player.call("set_controls_enabled", false)
		_main_player.visible = false

	# create FPS player at build zone
	_fps_player = CharacterBody3D.new()
	_fps_player.name = "FPSBuilder"
	_fps_player.position = global_position + Vector3(0, 2, 6)

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	col.shape = cap
	col.position.y = 0.9
	_fps_player.add_child(col)

	_fps_head = Node3D.new()
	_fps_head.position.y = 1.55
	_fps_player.add_child(_fps_head)

	_fps_camera = Camera3D.new()
	_fps_camera.current = true
	_fps_head.add_child(_fps_camera)

	_fps_raycast = RayCast3D.new()
	_fps_raycast.enabled = true
	_fps_raycast.target_position = Vector3(0, 0, -REACH)
	_fps_raycast.collide_with_bodies = true
	_fps_raycast.collide_with_areas = false
	_fps_head.add_child(_fps_raycast)

	get_parent().add_child(_fps_player)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_ui.visible = true
	_update_label()


func _exit_build_mode() -> void:
	if not _building:
		return
	_building = false
	_ui.visible = false
	highlight.visible = false

	# restore main player
	if _main_player != null:
		if _main_player.has_method("set_controls_enabled"):
			_main_player.call("set_controls_enabled", true)
		_main_player.visible = true

	# remove FPS player, restore main camera
	if _fps_player != null:
		_fps_player.queue_free()
		_fps_player = null

	# re-enable main camera
	if _main_player != null:
		var cams: Array[Node] = _main_player.find_children("*", "Camera3D", true, false)
		if not cams.is_empty():
			(cams[0] as Camera3D).current = true

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	build_mode_exited.emit()


func _input(event: InputEvent) -> void:
	if not _building:
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_fps_player.rotate_y(-event.relative.x * MSENS)
		_fps_head.rotate_x(-event.relative.y * MSENS)
		_fps_head.rotation.x = clampf(_fps_head.rotation.x, deg_to_rad(-89), deg_to_rad(89))
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_place()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_break()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			active_block = (active_block - 1 + BLOCK_DEFS.size()) % BLOCK_DEFS.size()
			_update_label()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			active_block = (active_block + 1) % BLOCK_DEFS.size()
			_update_label()
	if event.is_action_pressed("ui_cancel"):
		_exit_build_mode()
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if not _building or _fps_player == null:
		return
	if not _fps_player.is_on_floor():
		_fps_player.velocity += _fps_player.get_gravity() * delta
	if Input.is_action_just_pressed("jump") and _fps_player.is_on_floor():
		_fps_player.velocity.y = JUMP_VEL
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (_fps_player.global_transform.basis * Vector3(input.x, 0, input.y)).normalized()
	_fps_player.velocity.x = dir.x * SPEED if dir else move_toward(_fps_player.velocity.x, 0, SPEED)
	_fps_player.velocity.z = dir.z * SPEED if dir else move_toward(_fps_player.velocity.z, 0, SPEED)
	_fps_player.move_and_slide()
	_update_highlight()


func _update_highlight() -> void:
	_fps_raycast.force_raycast_update()
	if not _fps_raycast.is_colliding():
		highlight.visible = false
		return
	var hit := _fps_raycast.get_collision_point()
	var norm := _fps_raycast.get_collision_normal()
	var cell := grid_map.local_to_map(grid_map.to_local(hit - norm * EPS))
	var item := grid_map.get_cell_item(cell)
	highlight.visible = item != GridMap.INVALID_CELL_ITEM
	if highlight.visible:
		highlight.global_position = grid_map.to_global(grid_map.map_to_local(cell))


func _place() -> void:
	_fps_raycast.force_raycast_update()
	if not _fps_raycast.is_colliding():
		return
	var hit := _fps_raycast.get_collision_point()
	var norm := _fps_raycast.get_collision_normal()
	var cell := grid_map.local_to_map(grid_map.to_local(hit + norm * EPS))
	if grid_map.get_cell_item(cell) != GridMap.INVALID_CELL_ITEM:
		return
	var center := grid_map.to_global(grid_map.map_to_local(cell))
	var ca := AABB(center - Vector3.ONE * 0.5, Vector3.ONE)
	var pa := AABB(_fps_player.global_position + Vector3(-0.35, 0, -0.35), Vector3(0.7, 1.8, 0.7))
	if ca.intersects(pa):
		return
	grid_map.set_cell_item(cell, active_block)


func _break() -> void:
	_fps_raycast.force_raycast_update()
	if not _fps_raycast.is_colliding():
		return
	var hit := _fps_raycast.get_collision_point()
	var norm := _fps_raycast.get_collision_normal()
	var cell := grid_map.local_to_map(grid_map.to_local(hit - norm * EPS))
	if grid_map.get_cell_item(cell) == GridMap.INVALID_CELL_ITEM:
		return
	grid_map.set_cell_item(cell, GridMap.INVALID_CELL_ITEM)


func _update_label() -> void:
	block_label.text = "[%s]   ЛКМ ставить  |  ПКМ ломать  |  Колесо выбор  |  ESC выход" % BLOCK_DEFS[active_block].name


# ======================== BUILD ========================

func _build_grid() -> void:
	grid_map = GridMap.new()
	grid_map.name = "BuildGrid"
	grid_map.mesh_library = _build_meshlib()
	grid_map.cell_size = Vector3.ONE
	add_child(grid_map)


func _build_highlight() -> void:
	highlight = MeshInstance3D.new()
	var hmesh := BoxMesh.new()
	hmesh.size = Vector3(1.03, 1.03, 1.03)
	var hmat := StandardMaterial3D.new()
	hmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hmat.albedo_color = Color(1, 0.92, 0.05, 0.42)
	hmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hmat.no_depth_test = true
	hmesh.material = hmat
	highlight.mesh = hmesh
	highlight.visible = false
	add_child(highlight)


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 10

	block_label = Label.new()
	block_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block_label.anchor_left = 0.0; block_label.anchor_right = 1.0
	block_label.anchor_top = 1.0;  block_label.anchor_bottom = 1.0
	block_label.offset_top = -40;  block_label.offset_bottom = -10
	block_label.offset_left = 10;  block_label.offset_right = -10
	block_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	block_label.add_theme_font_size_override("font_size", 18)
	_ui.add_child(block_label)

	crosshair = Label.new()
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.text = "+"
	crosshair.anchor_left = 0.5; crosshair.anchor_right = 0.5
	crosshair.anchor_top = 0.5;  crosshair.anchor_bottom = 0.5
	crosshair.offset_left = -10; crosshair.offset_right = 10
	crosshair.offset_top = -12;  crosshair.offset_bottom = 12
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.add_theme_font_size_override("font_size", 24)
	_ui.add_child(crosshair)

	add_child(_ui)


func _seed_ground() -> void:
	for x in range(-5, 6):
		for z in range(-5, 6):
			grid_map.set_cell_item(Vector3i(x, 0, z), 2 if abs(x) <= 2 and abs(z) <= 2 else 1)


func _build_meshlib() -> MeshLibrary:
	var lib := MeshLibrary.new()
	for i in BLOCK_DEFS.size():
		var b: Dictionary = BLOCK_DEFS[i]
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		var mat := StandardMaterial3D.new()
		mat.albedo_color = b.color
		mat.albedo_texture = _tex(b.color, b.accent)
		mat.roughness = 0.82
		if b.get("transparent", false):
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.roughness = 0.08
		mesh.material = mat
		lib.create_item(i)
		lib.set_item_name(i, b.name)
		lib.set_item_mesh(i, mesh)
		var shape := BoxShape3D.new()
		shape.size = Vector3.ONE
		lib.set_item_shapes(i, [shape, Transform3D.IDENTITY])
	return lib


func _tex(base: Color, accent: Color) -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var n := float((x * 17 + y * 31 + x * y * 7) % 23) / 22.0
			img.set_pixel(x, y, base.lerp(accent, n * 0.5))
	return ImageTexture.create_from_image(img)
