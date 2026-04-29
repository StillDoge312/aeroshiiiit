extends Node3D

const ANTON_INTRO_DONE_META := "anton_intro_done"
const ANTON_INTRO_LINES: Array[Dictionary] = [
	{"speaker": "Anton", "text": "О, дарова"},
	{"speaker": "Anton", "text": "Ты откуда вообще?"},
	{"speaker": "Anton", "text": "АААААА, сверху пришёл?"},
	{"speaker": "Anton", "text": "Это круто"},
	{"speaker": "Anton", "text": "Говорят там небо серым бывает и дождик идёт"},
	{"speaker": "Anton", "text": "У нас такого нет"},
	{"speaker": "Anton", "text": "Кста, ты же не занят?"},
	{"speaker": "Anton", "text": "Можешь пожалуйста моему другу помочь?"},
	{"speaker": "Anton", "text": "Он возле озера, с дочкой в лодочки играет"},
	{"speaker": "Anton", "text": "а я пойду пока с замком что нибудь решу"}
]
const LOCKED_LINES: Array[Dictionary] = [
	{"speaker": "Anton", "text": "тоо сначала нужно получить благсловлдение Clippy"}
]

@export_node_path("CharacterBody3D") var player_path: NodePath = ^"../Player"
@export var interact_action: StringName = &"interact"

@onready var interaction_area: Area3D = $InteractionArea
@onready var prompt: Label3D = $Prompt

var _player: CharacterBody3D
var _player_inside: bool = false
var _dialog_active: bool = false


func _ready() -> void:
	if bool(get_tree().root.get_meta(ANTON_INTRO_DONE_META, false)):
		queue_free()
		return

	_ensure_interact_action()
	_player = get_node_or_null(player_path) as CharacterBody3D
	prompt.visible = false
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if _player == null:
		_player = get_node_or_null(player_path) as CharacterBody3D
	if _player == null:
		return
	var target_position := _player.global_position
	target_position.y = global_position.y
	look_at(target_position, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside or _dialog_active:
		return
	if not event.is_action_pressed(interact_action):
		return
	get_viewport().set_input_as_handled()
	_start_intro_dialog()


func play_locked_dialog() -> void:
	if _dialog_active:
		return
	var dialog_system := _get_dialog_system()
	if dialog_system == null:
		push_error("DialogSystem unavailable for Anton locked dialog.")
		return
	_dialog_active = true
	prompt.visible = false
	dialog_system.dialog_finished.connect(_on_dialog_finished, CONNECT_ONE_SHOT)
	dialog_system.show_dialog(LOCKED_LINES)


func _start_intro_dialog() -> void:
	var dialog_system := _get_dialog_system()
	if dialog_system == null:
		push_error("DialogSystem unavailable for Anton intro dialog.")
		return
	_dialog_active = true
	prompt.visible = false
	dialog_system.dialog_finished.connect(_on_intro_dialog_finished, CONNECT_ONE_SHOT)
	dialog_system.show_dialog(ANTON_INTRO_LINES)


func _on_intro_dialog_finished() -> void:
	get_tree().root.set_meta(ANTON_INTRO_DONE_META, true)
	queue_free()


func _on_dialog_finished() -> void:
	_dialog_active = false
	prompt.visible = _player_inside


func _on_body_entered(body: Node3D) -> void:
	if not _is_player(body):
		return
	_player_inside = true
	if not _dialog_active:
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
	var existing := get_tree().root.get_node_or_null(^"DialogSystem") as DialogSystem
	if existing != null:
		return existing
	var created := DialogSystem.new()
	created.name = "DialogSystem"
	get_tree().root.add_child(created)
	return created


func _ensure_interact_action() -> void:
	if InputMap.has_action(interact_action):
		return
	InputMap.add_action(interact_action)
	var interact_key := InputEventKey.new()
	interact_key.physical_keycode = KEY_E
	InputMap.action_add_event(interact_action, interact_key)
