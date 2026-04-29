extends CharacterBody3D

var SPEED = 1.0

var target : Node3D 
var update_counter : int = 0
var update_once : int = 15

var other_logic : bool = false

@onready var sprite_3d: Sprite3D = $Sprite3D


func _ready() -> void:
	target = _get_player()
	sprite_3d.modulate = Color(randf_range(0.0, 1.0), randf_range(0.0, 1.0), randf_range(0.0, 1.0))
	sprite_3d.pixel_size = randf_range(0.0015, 0.0015)


func _physics_process(_delta: float) -> void:
	if target == null:
		target = _get_player()

	update_counter += 1
	if update_once <= update_counter:
		update_counter = 0
		if target:
			var random_point = Vector3(randf_range(-50, 50), randf_range(0, 10), randf_range(-50, 50))
			
			if other_logic:
				velocity = self.global_position.direction_to(target.global_position) * SPEED
			else:
				velocity = self.global_position.direction_to(random_point) * SPEED
				velocity += Vector3(sin(Time.get_ticks_msec()),sin(Time.get_ticks_msec()),sin(Time.get_ticks_msec()))
	move_and_slide()


func _get_player() -> Node3D:
	var nodes := get_tree().get_nodes_in_group("brains_player")
	if nodes.is_empty():
		return null
	return nodes[0] as Node3D
