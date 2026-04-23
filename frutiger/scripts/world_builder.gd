extends Node3D

@export var field_size: Vector2 = Vector2(4000.0, 4000.0)
@export var field_height: float = 1.2


func _ready() -> void:
	_build_field()


func _build_field() -> void:
	var field_body := StaticBody3D.new()
	field_body.name = "Field"
	add_child(field_body)

	var field_shape := BoxShape3D.new()
	field_shape.size = Vector3(field_size.x, field_height, field_size.y)
	var collider := CollisionShape3D.new()
	collider.shape = field_shape
	collider.position.y = field_height * 0.5
	field_body.add_child(collider)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = field_shape.size
	mesh_instance.mesh = mesh
	mesh_instance.position.y = field_height * 0.5
	mesh_instance.material_override = _make_grass_material()
	field_body.add_child(mesh_instance)

func _make_grass_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.14, 0.64, 0.18, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.05, 0.22, 0.06, 1.0)
	material.emission_energy_multiplier = 0.3
	material.roughness = 0.95
	material.metallic = 0.0
	return material
