extends Node3D

const ANTON_V2_DIALOG_DONE_META := "anton_v2_dialog_done"
const CASTLE_EXPLODED_META := "castle_exploded"
const DIALOG_LINES: Array[Dictionary] = [
	{"speaker": "antonV2", "text": "о"},
	{"speaker": "antonV2", "text": "а чё, так можно было?"},
	{"speaker": "antonV2", "text": "Там просто капец как страшно было"},
	{"speaker": "antonV2", "text": "Ну короче спасибо"},
	{"speaker": "antonV2", "text": "Спроси Джаббу"},
	{"speaker": "antonV2", "text": "Он тебе ключ даст чтбы ты ушёл"},
	{"speaker": "antonV2", "text": "Ибо делать нечего тут больше"}
]

@export_node_path("CharacterBody3D") var player_path: NodePath = ^"../Player"
@export var interact_action: StringName = &"interact"
@export var interaction_enabled: bool = true

@onready var interaction_area: Area3D = $InteractionArea
@onready var prompt: Label3D = $Prompt

var _player: CharacterBody3D
var _player_inside: bool = false
var _dialog_active: bool = false
var _dialog_done: bool = false
var _unlocked: bool = false


func _enter_tree() -> void:
	visible = false


func _ready() -> void:
	add_to_group(&"anton_v2_npc")
	_unlocked = bool(get_tree().root.get_meta(CASTLE_EXPLODED_META, false))
	_dialog_done = bool(get_tree().root.get_meta(ANTON_V2_DIALOG_DONE_META, false))
	_ensure_interact_action()
	_player = get_node_or_null(player_path) as CharacterBody3D
	if _unlocked:
		visible = true
		set_interaction_enabled(interaction_enabled)
	else:
		visible = false
		set_interaction_enabled(false)
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if not _unlocked:
		return
	if _player == null:
		_player = get_node_or_null(player_path) as CharacterBody3D
	if _player == null:
		return
	var target_position := _player.global_position
	target_position.y = global_position.y
	look_at(target_position, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if not _unlocked:
		return
	if _dialog_done or not _player_inside or _dialog_active:
		return
	if not event.is_action_pressed(interact_action):
		return
	get_viewport().set_input_as_handled()
	_start_dialog()


func _start_dialog() -> void:
	var dialog_system := _get_dialog_system()
	if dialog_system == null:
		push_error("DialogSystem unavailable for AntonV2 dialog.")
		return
	_dialog_active = true
	prompt.visible = false
	dialog_system.dialog_finished.connect(_on_dialog_finished, CONNECT_ONE_SHOT)
	dialog_system.show_dialog(DIALOG_LINES)


func _on_dialog_finished() -> void:
	_dialog_active = false
	_dialog_done = true
	get_tree().root.set_meta(ANTON_V2_DIALOG_DONE_META, true)
	prompt.visible = false


func _on_body_entered(body: Node3D) -> void:
	if not _is_player(body):
		return
	_player_inside = true
	if not _dialog_active and not _dialog_done:
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


func set_interaction_enabled(enabled: bool) -> void:
	interaction_enabled = enabled
	_player_inside = false
	prompt.visible = false
	if interaction_area != null:
		interaction_area.monitoring = enabled
		interaction_area.monitorable = enabled


func unlock_after_explosion() -> void:
	_unlocked = true
	visible = true
	set_interaction_enabled(true)
