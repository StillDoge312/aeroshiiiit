extends Node3D

const BUBBLE_POP_SOUND_PATH := "res://sounds/bubble pop.mp3.mp3"

const DIALOG_LINES: Array[Dictionary] = [
	{"speaker": "Clippy", "text": "Помоги спасти моего ребёнка"},
	{"speaker": "Clippy", "text": "она скоро утоонет"},
	{"speaker": "Clippy", "text": "быстрее"}
]
const REUNION_DIALOG_LINES: Array[Dictionary] = [
	{"speaker": "Clippy", "text": "Спасибо большое странник"},
	{"speaker": "Clippy", "text": "Очень тебе благодарен"},
	{"speaker": "Clippy", "text": "Ты очень добрая душа, такие как ты нужны людям"},
	{"speaker": "Clippy", "text": "Найди моего друга бабайку, он возле замка"},
	{"speaker": "Clippy", "text": "ОСТЕРЕГАЙСЯ ГЛАЗ"},
	{"speaker": "Clippy", "text": "..."},
	{"speaker": "Clippy", "text": "Ну всё, я пошёл за хлебом"},
	{"speaker": "Clippy", "text": "*исчезаю*"}
]
const CLIPPY_BLESSING_GRANTED_META := "clippy_blessing_granted"

@export_node_path("CharacterBody3D") var player_path: NodePath = ^"../Player"
@export var interact_action: StringName = &"interact"

@onready var interaction_area: Area3D = $InteractionArea
@onready var prompt: Label3D = $Prompt

var _player: CharacterBody3D
var _player_inside: bool = false
var _dialog_active: bool = false
var _reunion_finished: bool = false


func _ready() -> void:
	_ensure_interact_action()
	_player = get_node_or_null(player_path) as CharacterBody3D
	prompt.visible = false
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	interaction_area.area_entered.connect(_on_area_entered)


func _process(_delta: float) -> void:
	if _reunion_finished:
		return
	if _player == null:
		_player = get_node_or_null(player_path) as CharacterBody3D
	if _player == null:
		return

	var target_position := _player.global_position
	target_position.y = global_position.y
	look_at(target_position, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if _reunion_finished or not _player_inside or _dialog_active:
		return
	if not event.is_action_pressed(interact_action):
		return

	get_viewport().set_input_as_handled()
	_start_dialog()


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


func _start_dialog() -> void:
	var dialog_system := _get_dialog_system()
	if dialog_system == null:
		push_error("DialogSystem is unavailable for Clippy NPC.")
		return

	_dialog_active = true
	prompt.visible = false
	dialog_system.dialog_finished.connect(_on_dialog_finished, CONNECT_ONE_SHOT)
	dialog_system.show_dialog(DIALOG_LINES)


func _on_dialog_finished() -> void:
	_dialog_active = false
	prompt.visible = _player_inside


func _on_reunion_dialog_finished() -> void:
	_reunion_finished = true
	_dialog_active = false
	prompt.visible = false
	get_tree().root.set_meta("clippy_dead", true)
	get_tree().root.set_meta(CLIPPY_BLESSING_GRANTED_META, true)
	_play_one_shot_sound(BUBBLE_POP_SOUND_PATH, "SFX", -2.0)
	queue_free()


func _on_area_entered(area: Area3D) -> void:
	if _reunion_finished or _dialog_active:
		return

	var clippy_fem := _resolve_clippy_fem(area)
	if clippy_fem == null:
		return
	if not clippy_fem.has_method("is_following_player"):
		return
	if not clippy_fem.call("is_following_player"):
		return

	if clippy_fem.has_method("move_near_clippy"):
		clippy_fem.call("move_near_clippy", self)
	_start_reunion_dialog()


func _start_reunion_dialog() -> void:
	var dialog_system := _get_dialog_system()
	if dialog_system == null:
		push_error("DialogSystem is unavailable for Clippy NPC reunion dialog.")
		return

	_dialog_active = true
	_player_inside = false
	prompt.visible = false
	dialog_system.dialog_finished.connect(_on_reunion_dialog_finished, CONNECT_ONE_SHOT)
	dialog_system.show_dialog(REUNION_DIALOG_LINES)


func _resolve_clippy_fem(area: Area3D) -> Node3D:
	var root := area.get_parent() as Node3D
	if root == null:
		return null
	if root.is_in_group("clippy_fem_npc"):
		return root
	return null


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


func _play_one_shot_sound(stream_path: String, bus_name: String, volume_db: float) -> void:
	var stream := load(stream_path) as AudioStream
	if stream == null:
		push_warning("Sound not found: " + stream_path)
		return

	var player_node := AudioStreamPlayer.new()
	player_node.stream = stream
	player_node.bus = bus_name
	player_node.volume_db = volume_db
	get_tree().root.add_child(player_node)
	player_node.finished.connect(player_node.queue_free)
	player_node.play()
