extends Node3D

@export_node_path("Node3D") var teleport_target_path: NodePath = ^"../TeleportTarget"
@export var teleport_only_character_bodies: bool = true
@export var required_group: StringName = &""

@onready var water_area: Area3D = $WaterArea
@onready var water_visual: MeshInstance3D = $WaterArea/WaterVisual


func _ready() -> void:
	_apply_water_material()
	water_area.body_entered.connect(_on_water_body_entered)


func _on_water_body_entered(body: Node3D) -> void:
	if teleport_only_character_bodies and not (body is CharacterBody3D):
		return
	if required_group != StringName() and not body.is_in_group(required_group):
		return

	var teleport_target := get_node_or_null(teleport_target_path) as Node3D
	if teleport_target == null:
		push_error("Teleport target not found: %s" % teleport_target_path)
		return

	body.global_position = teleport_target.global_position
	if body is CharacterBody3D:
		(body as CharacterBody3D).velocity = Vector3.ZERO


func _apply_water_material() -> void:
	var water_material := StandardMaterial3D.new()
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	water_material.albedo_color = Color(0.2, 0.58, 0.95, 0.35)
	water_material.roughness = 0.07
	water_material.metallic = 0.0
	water_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	water_visual.material_override = water_material
