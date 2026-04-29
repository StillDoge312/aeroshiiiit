extends CSGBox3D
class_name Interactable

const RETURN_SCENE_PATH := "res://scenes/main.tscn"
const RETURN_DELAY_SECONDS := 3.0
const RETURN_TO_TERRAIN_META := "return_to_terrain"

@onready var eyes: Node = $"../eyes"
@onready var directional_light_3d: DirectionalLight3D = $"../DirectionalLight3D"

@onready var _397365_klankbeeld_horror_insects_1706011190: AudioStreamPlayer3D = $"../397365KlankbeeldHorrorInsects1706011190"
@onready var _531447_zhr_horror_sound_4: AudioStreamPlayer3D = $"../531447ZhrHorrorSound4"
@onready var _561194_zhr_horror_piano_2: AudioStreamPlayer3D = $"../561194ZhrHorrorPiano2"
@onready var _584602_rodrigocswm_horror_voices_screaming_and_whispering: AudioStreamPlayer3D = $"../584602RodrigocswmHorrorVoicesScreamingAndWhispering"

var _return_started: bool = false


func action() -> void:
	if _return_started:
		return
	_return_started = true

	for eye in eyes.eyes:
		eye.queue_free()
	eyes.eyes.clear()
	
	_397365_klankbeeld_horror_insects_1706011190.queue_free()
	_531447_zhr_horror_sound_4.queue_free()
	_561194_zhr_horror_piano_2.queue_free()
	_584602_rodrigocswm_horror_voices_screaming_and_whispering.queue_free()
	
	directional_light_3d.show()
	await get_tree().create_timer(RETURN_DELAY_SECONDS).timeout
	get_tree().root.set_meta(RETURN_TO_TERRAIN_META, true)
	get_tree().change_scene_to_file(RETURN_SCENE_PATH)
