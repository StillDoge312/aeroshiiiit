@tool
extends Node3D

@export_node_path("Node3D") var target_path: NodePath = ^"../Player"
@export var texture: Texture2D:
	set(value):
		_texture = value
		_refresh_visual()
	get:
		return _texture
@export var quad_size: Vector2 = Vector2(4.0, 6.0):
	set(value):
		_quad_size = value
		_refresh_visual()
	get:
		return _quad_size
@export var orient_to_player: bool = true
@export var preview_in_editor: bool = true

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
var _texture: Texture2D
var _quad_size: Vector2 = Vector2(4.0, 6.0)


func _ready() -> void:
	_refresh_visual()
	set_process(orient_to_player and (not Engine.is_editor_hint() or preview_in_editor))


func _process(_delta: float) -> void:
	if not orient_to_player:
		return
	var target := _get_target_node()
	if target == null:
		return

	var target_position := target.global_position
	target_position.y = global_position.y
	look_at(target_position, Vector3.UP)


func _refresh_visual() -> void:
	if mesh_instance == null:
		return
	_setup_mesh()
	_setup_material()


func _get_target_node() -> Node3D:
	var target := get_node_or_null(target_path) as Node3D
	if target != null:
		return target

	target = get_node_or_null(^"../Player") as Node3D
	if target != null:
		return target

	return get_node_or_null(^"../../Player") as Node3D


func _setup_mesh() -> void:
	var quad := QuadMesh.new()
	quad.size = quad_size
	mesh_instance.mesh = quad
	mesh_instance.position = Vector3(0.0, quad_size.y * 0.5, 0.0)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _setup_material() -> void:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	material.albedo_texture = texture
	material.roughness = 1.0
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.material_override = material
