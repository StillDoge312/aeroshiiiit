extends Node3D

@export_node_path("CharacterBody3D") var player_path: NodePath = ^"../Player"
@export var interact_action: StringName = &"interact"
@export var follow_offset: Vector3 = Vector3(0.9, 0.0, 0.9)
@export var reunion_offset: Vector3 = Vector3(1.2, 0.0, 0.6)

@onready var interaction_area: Area3D = $InteractionArea
@onready var prompt: Label3D = $Prompt

var _player: CharacterBody3D
var _player_inside: bool = false
var _following_player: bool = false
var _spawn_transform: Transform3D


func _ready() -> void:
	add_to_group("escort_resettable")
	add_to_group("clippy_fem_npc")
	_ensure_interact_action()
	_spawn_transform = global_transform
	_player = get_node_or_null(player_path) as CharacterBody3D
	prompt.visible = false
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if _player == null:
		_player = get_node_or_null(player_path) as CharacterBody3D
	if _player == null:
		return

	if _following_player:
		global_position = _player.global_position + follow_offset
		return

	var target_position := _player.global_position
	target_position.y = global_position.y
	look_at(target_position, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if _following_player or not _player_inside:
		return
	if not event.is_action_pressed(interact_action):
		return

	get_viewport().set_input_as_handled()
	_follow_player()


func reset_to_spawn() -> void:
	_following_player = false
	_player_inside = false
	prompt.visible = false
	global_transform = _spawn_transform


func is_following_player() -> bool:
	return _following_player


func die_in_water() -> void:
	_following_player = false
	_player_inside = false
	prompt.visible = false
	queue_free()


func move_near_clippy(clippy_node: Node3D) -> void:
	_following_player = false
	_player_inside = false
	prompt.visible = false
	global_position = clippy_node.global_position + reunion_offset
	var target_position := clippy_node.global_position
	target_position.y = global_position.y
	look_at(target_position, Vector3.UP)


func _on_body_entered(body: Node3D) -> void:
	if not _is_player(body):
		return
	_player_inside = true
	prompt.visible = not _following_player


func _on_body_exited(body: Node3D) -> void:
	if not _is_player(body):
		return
	_player_inside = false
	prompt.visible = false


func _follow_player() -> void:
	_following_player = true
	prompt.visible = false


func _is_player(body: Node3D) -> bool:
	if _player != null:
		return body == _player
	return body is CharacterBody3D and body.name == "Player"


func _ensure_interact_action() -> void:
	if InputMap.has_action(interact_action):
		return

	InputMap.add_action(interact_action)
	var interact_key := InputEventKey.new()
	interact_key.physical_keycode = KEY_E
	InputMap.action_add_event(interact_action, interact_key)
