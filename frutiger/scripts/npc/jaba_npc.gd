extends Node3D

const DIALOG_SOUND_PATH := "res://sounds/dzaba_dialog.mp3"
const DIALOG_INTRO: Array[Dictionary] = [
	{"speaker": "Jaba", "text": "Построй мне дом, а я тебя выпущу"},
]
const DIALOG_PRAISE: Array[Dictionary] = [
	{"speaker": "Jaba", "text": "Ого, ну ты красавчик!"},
	{"speaker": "Jaba", "text": "Ладно, свободен"},
]

enum State { INTRO, BUILDING, PRAISE, DONE }

@export_node_path("CharacterBody3D") var player_path: NodePath = ^"../Player"
@export var interact_action: StringName = &"interact"
@export var interaction_enabled: bool = true

@onready var interaction_area: Area3D = $InteractionArea
@onready var prompt: Label3D = $Prompt

var _player: CharacterBody3D
var _player_inside: bool = false
var _dialog_active: bool = false
var _state: int = State.INTRO
var _build_zone: Node3D


func _ready() -> void:
	_ensure_interact_action()
	_player = get_node_or_null(player_path) as CharacterBody3D
	set_interaction_enabled(interaction_enabled)
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	# find BuildZone sibling
	await get_tree().process_frame
	_build_zone = get_parent().get_node_or_null("BuildZone")
	if _build_zone == null:
		_build_zone = get_parent().get_node_or_null("BuildScene")
	if _build_zone != null and _build_zone.has_signal("build_mode_exited"):
		_build_zone.build_mode_exited.connect(_on_build_done)


func _process(_delta: float) -> void:
	if _player == null:
		_player = get_node_or_null(player_path) as CharacterBody3D
	if _player == null:
		return
	var target := _player.global_position
	target.y = global_position.y
	look_at(target, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if _state == State.BUILDING or _state == State.DONE:
		return
	if not _player_inside or _dialog_active:
		return
	if not event.is_action_pressed(interact_action):
		return
	get_viewport().set_input_as_handled()
	_start_dialog()


func _start_dialog() -> void:
	var ds := _get_dialog_system()
	if ds == null:
		return
	_dialog_active = true
	prompt.visible = false
	_play_dialog_sound()
	var lines: Array[Dictionary]
	if _state == State.INTRO:
		lines = DIALOG_INTRO
	else:
		lines = DIALOG_PRAISE
	ds.dialog_finished.connect(_on_dialog_finished, CONNECT_ONE_SHOT)
	ds.show_dialog(lines)


func _on_dialog_finished() -> void:
	_dialog_active = false
	if _state == State.INTRO:
		_state = State.BUILDING
		prompt.visible = false
		# enter build mode
		if _build_zone != null and _build_zone.has_method("enter_build_mode"):
			_build_zone.call("enter_build_mode")
	elif _state == State.PRAISE:
		_state = State.DONE
		prompt.visible = false
		_reveal_exit_door()


func _on_build_done() -> void:
	_state = State.PRAISE
	if _player_inside:
		prompt.visible = true


func _reveal_exit_door() -> void:
	var door := get_tree().current_scene.find_child("ExitDoor", true, false)
	if door != null and door.has_method("reveal"):
		door.call("reveal")


func _play_dialog_sound() -> void:
	var stream := load(DIALOG_SOUND_PATH) as AudioStream
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = "SFX"
	p.volume_db = -2.0
	get_tree().root.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func _on_body_entered(body: Node3D) -> void:
	if not _is_player(body):
		return
	_player_inside = true
	if not _dialog_active and _state != State.BUILDING and _state != State.DONE:
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


func _get_dialog_system() -> DialogSystem:
	var ds := get_tree().root.get_node_or_null(^"DialogSystem") as DialogSystem
	if ds != null:
		return ds
	var created := DialogSystem.new()
	created.name = "DialogSystem"
	get_tree().root.add_child(created)
	return created


func _ensure_interact_action() -> void:
	if InputMap.has_action(interact_action):
		return
	InputMap.add_action(interact_action)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	InputMap.action_add_event(interact_action, key)


func set_interaction_enabled(enabled: bool) -> void:
	interaction_enabled = enabled
	_player_inside = false
	prompt.visible = false
	if interaction_area != null:
		interaction_area.monitoring = enabled
		interaction_area.monitorable = enabled
