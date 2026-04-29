extends Node3D
## Дверь выхода. Изначально скрыта.
## Вызвать reveal() чтобы она появилась из-под земли.
## Игрок подходит, жмёт E → THE END.

@export_node_path("CharacterBody3D") var player_path: NodePath = ^"../Player"
@export var interact_action: StringName = &"interact"

@onready var interaction_area: Area3D = $InteractionArea
@onready var prompt: Label3D = $Prompt

var _player: CharacterBody3D
var _player_inside: bool = false
var _revealed: bool = false
var _ended: bool = false


func _ready() -> void:
	visible = false
	_ensure_interact_action()
	_player = get_node_or_null(player_path) as CharacterBody3D
	interaction_area.monitoring = false
	interaction_area.monitorable = false
	prompt.visible = false
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if not _revealed or _ended or not _player_inside:
		return
	if not event.is_action_pressed(interact_action):
		return
	get_viewport().set_input_as_handled()
	_ended = true
	prompt.visible = false
	_show_the_end()


func reveal() -> void:
	if _revealed:
		return
	_revealed = true
	visible = true
	interaction_area.monitoring = true
	interaction_area.monitorable = true
	# animate rising from ground
	var target_pos := position
	position = target_pos - Vector3(0, 6, 0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", target_pos, 1.5)


func _show_the_end() -> void:
	if _player != null and _player.has_method("set_controls_enabled"):
		_player.call("set_controls_enabled", false)

	var ui := CanvasLayer.new()
	ui.layer = 100

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(bg)

	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = "THE END"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 120)
	label.modulate = Color(1, 1, 1, 0)
	ui.add_child(label)

	get_tree().root.add_child(ui)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(bg, "color", Color(0, 0, 0, 0.85), 2.0)
	tween.tween_property(label, "modulate", Color(1, 1, 1, 1), 3.0)

	# dubstep
	var stream := load("res://sounds/dubstep_final.mp3") as AudioStream
	if stream != null:
		var music := AudioStreamPlayer.new()
		music.stream = stream
		music.volume_db = 0.0
		get_tree().root.add_child(music)
		music.play()


func _on_body_entered(body: Node3D) -> void:
	if not _is_player(body) or not _revealed or _ended:
		return
	_player_inside = true
	prompt.visible = true


func _on_body_exited(body: Node3D) -> void:
	if not _is_player(body):
		return
	_player_inside = false
	prompt.visible = false


func _is_player(body: Node3D) -> bool:
	if _player != null:
		return body == _player
	return body is CharacterBody3D and body.name == "Player"


func _ensure_interact_action() -> void:
	if InputMap.has_action(interact_action):
		return
	InputMap.add_action(interact_action)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	InputMap.action_add_event(interact_action, key)
