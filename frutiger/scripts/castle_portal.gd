extends Node3D

@export var interact_action: StringName = &"interact"
@export_file("*.tscn") var brains_scene_path: String = "res://bsrains/node_3d.tscn"

@onready var interaction_area: Area3D = $InteractionArea
@onready var prompt_label: Label3D = $PromptLabel3D

var _player_in_range: bool = false
var _transition_started: bool = false


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
	if _transition_started:
		return
	_transition_started = true
	if brains_scene_path.is_empty():
		push_error("Brains scene path is empty.")
		_transition_started = false
		return
	get_tree().change_scene_to_file(brains_scene_path)


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
