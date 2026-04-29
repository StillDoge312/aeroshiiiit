extends Node3D

const CLIPPY_BLESSING_GRANTED_META := "clippy_blessing_granted"
const LOCKED_LINES: Array[Dictionary] = [
	{"speaker": "Anton", "text": "тоо сначала нужно получить благсловлдение Clippy"}
]

@export var interact_action: StringName = &"interact"
@export_file("*.tscn") var brains_scene_path: String = "res://bsrains/node_3d.tscn"

@onready var interaction_area: Area3D = $InteractionArea
@onready var prompt_label: Label3D = $PromptLabel3D

var _player_in_range: bool = false
var _transition_started: bool = false
var _dialog_active: bool = false


func _ready() -> void:
	_ensure_interact_action()
	set_process(true)
	prompt_label.visible = false
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if not _player_in_range:
		return
	if not Input.is_action_just_pressed(interact_action):
		return
	_enter_brains()


func _enter_brains() -> void:
	if not bool(get_tree().root.get_meta(CLIPPY_BLESSING_GRANTED_META, false)):
		_show_locked_dialog()
		return
	if _transition_started:
		return
	_transition_started = true
	if brains_scene_path.is_empty():
		push_error("Brains scene path is empty.")
		_transition_started = false
		return
	get_tree().change_scene_to_file(brains_scene_path)


func _show_locked_dialog() -> void:
	if _dialog_active:
		return
	var anton_npc := get_tree().current_scene.get_node_or_null(^"AntonNPC")
	if anton_npc != null and anton_npc.has_method("play_locked_dialog"):
		anton_npc.call("play_locked_dialog")
		return
	var dialog_system := _get_dialog_system()
	if dialog_system == null:
		push_error("DialogSystem unavailable for castle locked dialog.")
		return
	_dialog_active = true
	dialog_system.dialog_finished.connect(_on_locked_dialog_finished, CONNECT_ONE_SHOT)
	dialog_system.show_dialog(LOCKED_LINES)


func _on_locked_dialog_finished() -> void:
	_dialog_active = false


func _get_dialog_system() -> DialogSystem:
	var existing := get_tree().root.get_node_or_null(^"DialogSystem") as DialogSystem
	if existing != null:
		return existing
	var created := DialogSystem.new()
	created.name = "DialogSystem"
	get_tree().root.add_child(created)
	return created


func _on_body_entered(body: Node3D) -> void:
	if not _is_player(body):
		return
	_player_in_range = true
	prompt_label.visible = true


func _on_body_exited(body: Node3D) -> void:
	if not _is_player(body):
		return
	_player_in_range = false
	prompt_label.visible = false


func _is_player(body: Node3D) -> bool:
	return body is CharacterBody3D and body.name == "Player"


func _ensure_interact_action() -> void:
	if InputMap.has_action(interact_action):
		return
	InputMap.add_action(interact_action)
	var interact_key := InputEventKey.new()
	interact_key.physical_keycode = KEY_E
	InputMap.action_add_event(interact_action, interact_key)
