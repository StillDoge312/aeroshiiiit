@tool
extends SceneTree

const BlockResourceScript := preload("res://resources/block_resource.gd")

const BLOCKS := [
	{"id": &"stone", "name": "Stone", "item": 0, "color": Color(0.46, 0.47, 0.50, 1.0), "accent": Color(0.25, 0.26, 0.29, 1.0), "pattern": "chips"},
	{"id": &"dirt", "name": "Dirt", "item": 1, "color": Color(0.42, 0.25, 0.13, 1.0), "accent": Color(0.22, 0.12, 0.06, 1.0), "pattern": "speckles"},
	{"id": &"grass", "name": "Grass", "item": 2, "color": Color(0.22, 0.60, 0.18, 1.0), "accent": Color(0.10, 0.34, 0.10, 1.0), "pattern": "blades"},
	{"id": &"wood", "name": "Wood", "item": 3, "color": Color(0.56, 0.32, 0.14, 1.0), "accent": Color(0.30, 0.16, 0.07, 1.0), "pattern": "rings"},
	{"id": &"glass", "name": "Glass", "item": 4, "color": Color(0.58, 0.88, 1.0, 0.62), "accent": Color(0.90, 1.0, 1.0, 0.85), "pattern": "shine"},
]

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/blocks"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://meshlib"))
	_build_block_resources()
	_build_mesh_library()
	print("Generated block resources and MeshLibrary")
	quit()

func _build_block_resources() -> void:
	for data in BLOCKS:
		var block: Resource = BlockResourceScript.new()
		block.id = data.id
		block.display_name = data.name
		block.grid_item_id = data.item
		block.icon_color = data.color
		block.break_particle_color = data.color
		block.max_stack = 64
		block.is_breakable = true
		ResourceSaver.save(block, "res://data/blocks/%s.tres" % String(data.id))

func _build_mesh_library() -> void:
	var library := MeshLibrary.new()
	for data in BLOCKS:
		var item_id: int = data.item
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		var material := StandardMaterial3D.new()
		material.albedo_color = data.color
		material.albedo_texture = _make_texture(data.color, data.accent, data.pattern)
		material.roughness = 0.82
		if data.id == &"glass":
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.roughness = 0.08
			material.metallic = 0.0
		mesh.material = material
		library.create_item(item_id)
		library.set_item_name(item_id, String(data.id))
		library.set_item_mesh(item_id, mesh)
		var shape := BoxShape3D.new()
		shape.size = Vector3.ONE
		library.set_item_shapes(item_id, [shape, Transform3D.IDENTITY])
	ResourceSaver.save(library, "res://meshlib/blocks_meshlib.tres")

func _make_texture(base: Color, accent: Color, pattern: String) -> ImageTexture:
	var size := 32
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var value := _pattern_value(x, y, pattern)
			var color := base.lerp(accent, value)
			if pattern == "shine" and (x == y or x == y + 1 or x + y == size - 2):
				color = base.lerp(accent, 0.88)
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

func _pattern_value(x: int, y: int, pattern: String) -> float:
	var n := float((x * 17 + y * 31 + x * y * 7) % 23) / 22.0
	match pattern:
		"chips":
			return 0.18 + (0.34 if ((x / 4 + y / 3) % 3 == 0) else 0.0) + n * 0.12
		"speckles":
			return 0.12 + (0.45 if int(n * 10.0) % 5 == 0 else 0.0)
		"blades":
			return 0.10 + (0.36 if (x + y * 2) % 7 < 2 else 0.0) + n * 0.08
		"rings":
			return 0.16 + (0.42 if abs(sin(float(x) * 0.7 + float(y) * 0.18)) > 0.78 else 0.0)
		"shine":
			return 0.08 + n * 0.10
		_:
			return n * 0.25
