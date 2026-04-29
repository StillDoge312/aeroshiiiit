extends Node3D
## Строительная площадка — работает с существующим Player.
## ЛКМ — поставить блок, ПКМ — сломать.
## Колесо мыши — выбор блока.
## Рейкаст идёт из камеры Player'а по центру экрана.

const REACH := 10.0
const EPS := 0.01

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
var active_block: int = 0
var _camera: Camera3D


func _ready() -> void:
	_build_grid()
	_build_highlight()
	_build_ui()
	_seed_ground()
	# Find camera from Player node (sibling)
	await get_tree().process_frame
	var player := get_parent().get_node_or_null("Player") as CharacterBody3D
	if player != null:
		var cams: Array[Node] = player.find_children("*", "Camera3D", true, false)
		if not cams.is_empty():
			_camera = cams[0] as Camera3D


func _input(event: InputEvent) -> void:
	if _camera == null:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_place()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_break()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			active_block = (active_block - 1 + BLOCK_DEFS.size()) % BLOCK_DEFS.size()
			_update_label()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			active_block = (active_block + 1) % BLOCK_DEFS.size()
			_update_label()


func _process(_delta: float) -> void:
	_update_highlight()


func _raycast() -> Dictionary:
	if _camera == null:
		return {}
	var viewport := get_viewport()
	var center := viewport.get_visible_rect().size * 0.5
	var from := _camera.project_ray_origin(center)
	var dir := _camera.project_ray_normal(center)
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * REACH)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return space.intersect_ray(query)


func _update_highlight() -> void:
	var result := _raycast()
	if result.is_empty():
		highlight.visible = false
		return
	var hit: Vector3 = result.position
	var norm: Vector3 = result.normal
	var cell := grid_map.local_to_map(grid_map.to_local(hit - norm * EPS))
	var item := grid_map.get_cell_item(cell)
	highlight.visible = item != GridMap.INVALID_CELL_ITEM
	if highlight.visible:
		highlight.global_position = grid_map.to_global(grid_map.map_to_local(cell))


func _place() -> void:
	var result := _raycast()
	if result.is_empty():
		return
	var hit: Vector3 = result.position
	var norm: Vector3 = result.normal
	var cell := grid_map.local_to_map(grid_map.to_local(hit + norm * EPS))
	if grid_map.get_cell_item(cell) != GridMap.INVALID_CELL_ITEM:
		return
	# check player overlap
	var player := get_parent().get_node_or_null("Player") as CharacterBody3D
	if player != null:
		var center := grid_map.to_global(grid_map.map_to_local(cell))
		var ca := AABB(center - Vector3.ONE * 0.5, Vector3.ONE)
		var pa := AABB(player.global_position + Vector3(-0.4, 0, -0.4), Vector3(0.8, 2.0, 0.8))
		if ca.intersects(pa):
			return
	grid_map.set_cell_item(cell, active_block)


func _break() -> void:
	var result := _raycast()
	if result.is_empty():
		return
	var hit: Vector3 = result.position
	var norm: Vector3 = result.normal
	var cell := grid_map.local_to_map(grid_map.to_local(hit - norm * EPS))
	if grid_map.get_cell_item(cell) == GridMap.INVALID_CELL_ITEM:
		return
	grid_map.set_cell_item(cell, GridMap.INVALID_CELL_ITEM)


func _update_label() -> void:
	block_label.text = "[%s]   ЛКМ ставить  |  СКМ ломать  |  Колесо — выбор блока" % BLOCK_DEFS[active_block].name


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
	var ui := CanvasLayer.new()
	ui.layer = 10

	# block label
	block_label = Label.new()
	block_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block_label.anchor_left = 0.0; block_label.anchor_right = 1.0
	block_label.anchor_top = 1.0;  block_label.anchor_bottom = 1.0
	block_label.offset_top = -40;  block_label.offset_bottom = -10
	block_label.offset_left = 10;  block_label.offset_right = -10
	block_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	block_label.add_theme_font_size_override("font_size", 18)
	ui.add_child(block_label)
	_update_label()

	# crosshair
	var cross := Label.new()
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross.text = "+"
	cross.anchor_left = 0.5; cross.anchor_right = 0.5
	cross.anchor_top = 0.5;  cross.anchor_bottom = 0.5
	cross.offset_left = -10; cross.offset_right = 10
	cross.offset_top = -12;  cross.offset_bottom = 12
	cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cross.add_theme_font_size_override("font_size", 24)
	ui.add_child(cross)

	add_child(ui)


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
