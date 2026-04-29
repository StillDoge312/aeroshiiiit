extends Node3D

const CLIPPY_BLESSING_GRANTED_META := "clippy_blessing_granted"
const CASTLE_CLEARED_META := "castle_cleared"
const CASTLE_EXPLODED_META := "castle_exploded"
const EXPLOSION_TEXTURE_PATH := "res://assets/explosion.png"
const EXPLOSION_SOUND_PATH := "res://sounds/explosion.mp3"
const LOCKED_LINES: Array[Dictionary] = [
	{"speaker": "Anton", "text": "тоо сначала нужно получить благсловлдение Clippy"}
]

@export var interact_action: StringName = &"interact"
@export_file("*.tscn") var brains_scene_path: String = "res://bsrains/node_3d.tscn"

@onready var interaction_area: Area3D = $InteractionArea
@onready var prompt_label: Label3D = $PromptLabel3D
@onready var castle_sprite: Sprite3D = $CastleSprite

var _player_in_range: bool = false
var _transition_started: bool = false
var _dialog_active: bool = false
var _explosion_started: bool = false
var _explosion_texture: Texture2D


func _ready() -> void:
	_ensure_interact_action()
	set_process(true)
	_explosion_texture = load(EXPLOSION_TEXTURE_PATH) as Texture2D
	prompt_label.visible = false
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

	if bool(get_tree().root.get_meta(CASTLE_EXPLODED_META, false)):
		castle_sprite.visible = false
		_disable_portal()
		_enable_anton_v2()
		return
	if bool(get_tree().root.get_meta(CASTLE_CLEARED_META, false)):
		_start_explosion_sequence()


func _process(_delta: float) -> void:
	if _explosion_started:
		return
	if not _player_in_range:
		return
	if not Input.is_action_just_pressed(interact_action):
		return
	_enter_brains()


func _enter_brains() -> void:
	if bool(get_tree().root.get_meta(CASTLE_CLEARED_META, false)):
		return
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


func _start_explosion_sequence() -> void:
	if _explosion_started:
		return
	_explosion_started = true
	_disable_portal()
	_apply_exploded_visual()
	_play_explosion_sound()
	await get_tree().create_timer(0.8).timeout
	castle_sprite.visible = false
	get_tree().root.set_meta(CASTLE_EXPLODED_META, true)
	_enable_anton_v2()


func _disable_portal() -> void:
	_player_in_range = false
	prompt_label.visible = false
	interaction_area.monitoring = false
	interaction_area.monitorable = false


func _apply_exploded_visual() -> void:
	if _explosion_texture == null:
		push_error("Explosion texture not found: " + EXPLOSION_TEXTURE_PATH)
		return
	castle_sprite.texture = _explosion_texture
	castle_sprite.scale = Vector3(5.0, 5.0, 5.0)
	castle_sprite.visible = true


func _play_explosion_sound() -> void:
	var stream := load(EXPLOSION_SOUND_PATH) as AudioStream
	if stream == null:
		push_error("Explosion sound not found: " + EXPLOSION_SOUND_PATH)
		return
	_ensure_audio_bus("SFX")
	var player_node := AudioStreamPlayer.new()
	player_node.stream = stream
	player_node.bus = "SFX"
	player_node.volume_db = -2.0
	get_tree().root.add_child(player_node)
	player_node.finished.connect(player_node.queue_free)
	player_node.play()


func _enable_anton_v2() -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var anton_v1 := scene_root.get_node_or_null(^"AntonNPC")
	if anton_v1 != null:
		anton_v1.queue_free()
	var found := false
	for npc in get_tree().get_nodes_in_group(&"anton_v2_npc"):
		if npc == null:
			continue
		if npc.has_method("unlock_after_explosion"):
			npc.call("unlock_after_explosion")
			found = true
	if not found:
		push_error("No AntonV2 NPC nodes found in group 'anton_v2_npc'.")


func _ensure_audio_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	var insert_index := AudioServer.get_bus_count()
	AudioServer.add_bus(insert_index)
	AudioServer.set_bus_name(insert_index, bus_name)
	AudioServer.set_bus_send(insert_index, "Master")
