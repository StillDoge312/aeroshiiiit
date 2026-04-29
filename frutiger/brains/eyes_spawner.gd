extends Node

@export var count : int = 64
@export var area_size : Vector2 = Vector2(128, 128) 
@onready var animation_player: AnimationPlayer = $"../Area3D/AnimationPlayer"

const EYES_SCENES = preload("res://brains/eyes.tscn")
var eyes : Array = []

func _ready() -> void:
	for i in count:
		var scene := EYES_SCENES.instantiate()
		add_child(scene)
		
		
		var pos_x = randf_range(-area_size.x / 2, area_size.x / 2)
		var pos_z = randf_range(-area_size.y / 2, area_size.y / 2)
		var pos_y = randf_range(0, 10) 
		
		eyes.append(scene)
		scene.position = Vector3(pos_x, pos_y, pos_z)

func body_entered() -> void:
	for eye in eyes:
		eye.other_logic = true
		eye.SPEED = 25.0
		$"../DirectionalLight3D".hide()
		$"../397365KlankbeeldHorrorInsects1706011190".play()
		$"../531447ZhrHorrorSound4".play()
		$"../561194ZhrHorrorPiano2".play()
		$"../584602RodrigocswmHorrorVoicesScreamingAndWhispering".play()
		
	animation_player.play("close")

func body_exited() -> void:
	for eye in eyes:
		eye.other_logic = false
		
	animation_player.play_backwards("close")


func _on_area_3d_body_entered(body: Node3D) -> void:
	if _is_player(body):
		body_entered()


func _on_area_3d_body_exited(body: Node3D) -> void:
	if _is_player(body):
		body_exited()


func _is_player(body: Node3D) -> bool:
	return body != null and body.is_in_group("brains_player")
