extends Node3D

const SETTINGS_PATH := "user://settings.json"
const MENU_BACKGROUND_PATH := "res://assets/menu/settings_background.jpg"
const SETTINGS_BACKGROUND_PATH := "res://assets/menu/settings_background.jpg"
const BUTTON_TEXTURE_PATH := "res://assets/menu/bubblefull_button.png"
const RESOLUTION_LIST: Array[String] = ["1280x720", "1600x900", "1920x1080", "2560x1440"]

@export_file("*.png", "*.jpg", "*.jpeg", "*.hdr", "*.exr") var skybox_path: String = "res://assets/skyboxes_49.png"

@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var player: CharacterBody3D = $Player

var _settings: Dictionary = {}
var _menu_background_texture: Texture2D
var _settings_background_texture: Texture2D
var _button_texture: Texture2D

var _ui_layer: CanvasLayer
var _ui_root: Control
var _menu_background: TextureRect
var _menu_buttons: VBoxContainer
var _play_button: TextureButton
var _settings_button: TextureButton
var _quit_button: TextureButton

var _settings_window: TextureRect
var _settings_scroll: ScrollContainer
var _master_slider: HSlider
var _music_slider: HSlider
var _sfx_slider: HSlider
var _environment_option: OptionButton
var _quality_option: OptionButton
var _resolution_option: OptionButton
var _settings_tween: Tween
var _settings_opened: bool = false


func _ready() -> void:
	_apply_skybox()
	_load_menu_assets()
	_build_menu_ui()
	_load_settings()
	_apply_all_settings()
	_sync_controls_from_settings()
	_update_ui_layout()
	_set_player_controls(false)
	get_viewport().size_changed.connect(_update_ui_layout)


func _apply_skybox() -> void:
	var image := Image.new()
	var error := image.load(skybox_path)
	if error != OK:
		push_error("Skybox load failed: %s (%d)" % [skybox_path, error])
		return

	var texture := ImageTexture.create_from_image(image)
	var panorama := PanoramaSkyMaterial.new()
	panorama.panorama = texture

	var sky := Sky.new()
	sky.sky_material = panorama

	if world_environment.environment == null:
		world_environment.environment = Environment.new()

	world_environment.environment.background_mode = Environment.BG_SKY
	world_environment.environment.sky = sky


func _load_menu_assets() -> void:
	var settings_back := _find_settings_back_texture()
	_menu_background_texture = settings_back if settings_back != null else _load_first_texture([MENU_BACKGROUND_PATH])
	_settings_background_texture = settings_back if settings_back != null else _load_first_texture([SETTINGS_BACKGROUND_PATH])
	_button_texture = _crop_texture_alpha_bounds(load(BUTTON_TEXTURE_PATH) as Texture2D)


func _load_first_texture(paths: Array[String]) -> Texture2D:
	for path in paths:
		var texture: Texture2D = load(path) as Texture2D
		if texture != null:
			return texture
	return null


func _find_settings_back_texture() -> Texture2D:
	var dir := DirAccess.open("res://assets/menu")
	if dir == null:
		return null

	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if dir.current_is_dir():
			continue
		if name.to_lower().contains("settings_back"):
			var texture := load("res://assets/menu/" + name) as Texture2D
			if texture != null:
				dir.list_dir_end()
				return texture
	dir.list_dir_end()
	return null


func _crop_texture_alpha_bounds(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null:
		return texture

	var used_rect := image.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		return texture

	if used_rect.position == Vector2i.ZERO and used_rect.size == image.get_size():
		return texture

	var cropped := Image.create(used_rect.size.x, used_rect.size.y, false, image.get_format())
	cropped.blit_rect(image, used_rect, Vector2i.ZERO)
	return ImageTexture.create_from_image(cropped)


func _build_menu_ui() -> void:
	_ui_layer = CanvasLayer.new()
	add_child(_ui_layer)

	_ui_root = Control.new()
	_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_PASS
	_ui_layer.add_child(_ui_root)

	_menu_background = TextureRect.new()
	_menu_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_background.texture = _menu_background_texture
	_menu_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_menu_background.modulate = Color(1.0, 1.0, 1.0, 0.95)
	_ui_root.add_child(_menu_background)

	_menu_buttons = VBoxContainer.new()
	_menu_buttons.add_theme_constant_override("separation", 14)
	_ui_root.add_child(_menu_buttons)

	_play_button = _create_menu_button("Играть")
	_settings_button = _create_menu_button("Настройки")
	_quit_button = _create_menu_button("Выйти")
	_menu_buttons.add_child(_play_button)
	_menu_buttons.add_child(_settings_button)
	_menu_buttons.add_child(_quit_button)

	_play_button.pressed.connect(_on_play_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

	_settings_window = TextureRect.new()
	_settings_window.texture = _settings_background_texture
	_settings_window.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_settings_window.visible = false
	_settings_window.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui_root.add_child(_settings_window)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.05, 0.08, 0.12, 0.45)
	_settings_window.add_child(shade)

	var outer_margin := MarginContainer.new()
	outer_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer_margin.add_theme_constant_override("margin_left", 24)
	outer_margin.add_theme_constant_override("margin_top", 22)
	outer_margin.add_theme_constant_override("margin_right", 24)
	outer_margin.add_theme_constant_override("margin_bottom", 22)
	_settings_window.add_child(outer_margin)

	_settings_scroll = ScrollContainer.new()
	_settings_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_margin.add_child(_settings_scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	_settings_scroll.add_child(content)

	var title := Label.new()
	title.text = "Настройки"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	content.add_child(title)

	_master_slider = _add_slider_row(content, "Мастер", 1.0)
	_music_slider = _add_slider_row(content, "Музыка", 1.0)
	_sfx_slider = _add_slider_row(content, "Звуки", 1.0)
	_environment_option = _add_option_row(content, "Инвайромент", ["Default", "Clear", "Moody"])
	_quality_option = _add_option_row(content, "Качество", ["Low", "Medium", "High"])
	_resolution_option = _add_option_row(content, "Разрешение", RESOLUTION_LIST)

	var close_button := _create_menu_button("Закрыть")
	close_button.custom_minimum_size = Vector2(220, 58)
	close_button.pressed.connect(_close_settings_window)
	content.add_child(close_button)

	_master_slider.value_changed.connect(_on_master_volume_changed)
	_music_slider.value_changed.connect(_on_music_volume_changed)
	_sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	_environment_option.item_selected.connect(_on_environment_selected)
	_quality_option.item_selected.connect(_on_quality_selected)
	_resolution_option.item_selected.connect(_on_resolution_selected)


func _create_menu_button(caption: String) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = _button_texture
	button.texture_hover = _button_texture
	button.texture_pressed = _button_texture
	button.texture_disabled = _button_texture
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.custom_minimum_size = Vector2(460, 98)
	button.ignore_texture_size = true

	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 30)
	button.add_child(label)

	button.mouse_entered.connect(_on_button_hovered.bind(button, true))
	button.mouse_exited.connect(_on_button_hovered.bind(button, false))
	button.button_down.connect(_on_button_pressed_state.bind(button, true))
	button.button_up.connect(_on_button_pressed_state.bind(button, false))
	return button


func _on_button_hovered(button: TextureButton, hovered: bool) -> void:
	button.modulate = Color(1.18, 1.18, 1.18, 1.0) if hovered else Color(1.0, 1.0, 1.0, 1.0)


func _on_button_pressed_state(button: TextureButton, pressed: bool) -> void:
	if pressed:
		button.scale = Vector2(0.98, 0.98)
	else:
		button.scale = Vector2.ONE


func _add_slider_row(parent: VBoxContainer, title: String, default_value: float) -> HSlider:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(130, 0)
	row.add_child(label)

	var slider := HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = default_value
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(44, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text = str(int(round(default_value * 100.0))) + "%"
	row.add_child(value_label)

	slider.value_changed.connect(_on_slider_visual_changed.bind(value_label))
	return slider


func _on_slider_visual_changed(value: float, value_label: Label) -> void:
	value_label.text = str(int(round(value * 100.0))) + "%"


func _add_option_row(parent: VBoxContainer, title: String, items: Array[String]) -> OptionButton:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(130, 0)
	row.add_child(label)

	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item in items:
		option.add_item(item)
	row.add_child(option)
	return option


func _make_default_settings() -> Dictionary:
	var window_size := DisplayServer.window_get_size()
	var resolution_text := "%dx%d" % [window_size.x, window_size.y]
	return {
		"master_volume": 1.0,
		"music_volume": 0.8,
		"sfx_volume": 0.9,
		"environment": "Default",
		"quality": "High",
		"resolution": resolution_text
	}


func _load_settings() -> void:
	_settings = _make_default_settings()
	if not FileAccess.file_exists(SETTINGS_PATH):
		return

	var raw := FileAccess.get_file_as_string(SETTINGS_PATH)
	var parsed_data: Variant = JSON.parse_string(raw)
	if parsed_data is Dictionary:
		var parsed: Dictionary = parsed_data
		for key in _settings.keys():
			if parsed.has(key):
				_settings[key] = parsed[key]


func _save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write settings file: " + SETTINGS_PATH)
		return
	file.store_string(JSON.stringify(_settings, "\t"))


func _sync_controls_from_settings() -> void:
	_master_slider.value = float(_settings["master_volume"])
	_music_slider.value = float(_settings["music_volume"])
	_sfx_slider.value = float(_settings["sfx_volume"])
	_select_option_by_text(_environment_option, String(_settings["environment"]))
	_select_option_by_text(_quality_option, String(_settings["quality"]))
	_ensure_resolution_item(String(_settings["resolution"]))
	_select_option_by_text(_resolution_option, String(_settings["resolution"]))


func _select_option_by_text(option: OptionButton, value: String) -> void:
	for i in range(option.item_count):
		if option.get_item_text(i) == value:
			option.select(i)
			return
	option.select(0)


func _ensure_resolution_item(value: String) -> void:
	for i in range(_resolution_option.item_count):
		if _resolution_option.get_item_text(i) == value:
			return
	_resolution_option.add_item(value)


func _apply_all_settings() -> void:
	_apply_audio("Master", float(_settings["master_volume"]))
	_apply_audio("Music", float(_settings["music_volume"]))
	_apply_audio("SFX", float(_settings["sfx_volume"]))
	_apply_environment(String(_settings["environment"]))
	_apply_quality(String(_settings["quality"]))
	_apply_resolution(String(_settings["resolution"]))


func _apply_audio(bus_name: String, linear_value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	var clamped := clampf(linear_value, 0.0, 1.0)
	AudioServer.set_bus_mute(index, clamped <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(max(clamped, 0.0001)))


func _apply_environment(mode_name: String) -> void:
	if world_environment.environment == null:
		world_environment.environment = Environment.new()
	var env := world_environment.environment

	match mode_name:
		"Clear":
			env.fog_enabled = false
			env.glow_enabled = false
			env.tonemap_exposure = 1.2
			env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			env.ambient_light_sky_contribution = 0.7
		"Moody":
			env.fog_enabled = true
			env.fog_density = 0.009
			env.glow_enabled = true
			env.glow_intensity = 0.95
			env.tonemap_exposure = 0.95
			env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			env.ambient_light_sky_contribution = 0.4
		_:
			env.fog_enabled = true
			env.fog_density = 0.004
			env.glow_enabled = true
			env.glow_intensity = 0.75
			env.tonemap_exposure = 1.15
			env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			env.ambient_light_sky_contribution = 0.55


func _apply_quality(quality_name: String) -> void:
	var viewport := get_viewport()
	match quality_name:
		"Low":
			viewport.scaling_3d_scale = 0.65
			viewport.msaa_3d = Viewport.MSAA_DISABLED
		"Medium":
			viewport.scaling_3d_scale = 0.8
			viewport.msaa_3d = Viewport.MSAA_2X
		_:
			viewport.scaling_3d_scale = 1.0
			viewport.msaa_3d = Viewport.MSAA_4X


func _apply_resolution(resolution_text: String) -> void:
	var size := _parse_resolution(resolution_text)
	if size == Vector2i.ZERO:
		return
	DisplayServer.window_set_size(size)
	var screen := DisplayServer.window_get_current_screen()
	var screen_size := DisplayServer.screen_get_size(screen)
	var center := (screen_size - size) / 2
	DisplayServer.window_set_position(center)


func _parse_resolution(text: String) -> Vector2i:
	var parts := text.split("x")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))


func _on_play_pressed() -> void:
	_menu_background.visible = false
	_menu_buttons.visible = false
	_close_settings_window(true)
	_set_player_controls(true)


func _on_settings_pressed() -> void:
	if _settings_opened:
		_close_settings_window()
	else:
		_open_settings_window()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _open_settings_window() -> void:
	_settings_opened = true
	_settings_window.visible = true
	if _settings_tween != null:
		_settings_tween.kill()
	_settings_tween = create_tween()
	_settings_tween.set_trans(Tween.TRANS_CUBIC)
	_settings_tween.set_ease(Tween.EASE_OUT)
	_settings_tween.tween_property(_settings_window, "position:y", _get_settings_visible_position().y, 0.65)


func _close_settings_window(force_hide: bool = false) -> void:
	_settings_opened = false
	if force_hide:
		_settings_window.visible = false
		return
	_settings_window.visible = true
	if _settings_tween != null:
		_settings_tween.kill()
	_settings_tween = create_tween()
	_settings_tween.set_trans(Tween.TRANS_CUBIC)
	_settings_tween.set_ease(Tween.EASE_IN)
	_settings_tween.tween_property(_settings_window, "position:y", _get_settings_hidden_position().y, 0.5)
	_settings_tween.finished.connect(_on_settings_hidden)


func _on_settings_hidden() -> void:
	if not _settings_opened:
		_settings_window.visible = false


func _get_settings_size() -> Vector2:
	var vp := _get_ui_size()
	return Vector2(clampf(vp.x * 0.43, 430.0, 680.0), clampf(vp.y * 0.72, 360.0, 700.0))


func _get_settings_visible_position() -> Vector2:
	var vp := _get_ui_size()
	var panel_size := _get_settings_size()
	return Vector2(24.0, vp.y - panel_size.y - 24.0)


func _get_settings_hidden_position() -> Vector2:
	var visible := _get_settings_visible_position()
	var vp := _get_ui_size()
	return Vector2(visible.x, vp.y + 20.0)


func _update_ui_layout() -> void:
	if _ui_root == null:
		return

	_ui_root.size = _get_ui_size()

	var button_width := clampf(_ui_root.size.x * 0.38, 400.0, 760.0)
	var button_height := clampf(_ui_root.size.y * 0.1, 68.0, 108.0)
	for button in [_play_button, _settings_button, _quit_button]:
		button.custom_minimum_size = Vector2(button_width, button_height)

	var menu_height := button_height * 3.0 + 28.0
	_menu_buttons.position = Vector2(24.0, _ui_root.size.y - menu_height - 24.0)
	_menu_buttons.size = Vector2(button_width, menu_height)

	var panel_size := _get_settings_size()
	_settings_window.size = panel_size
	_settings_window.position = _get_settings_visible_position() if _settings_opened else _get_settings_hidden_position()


func _get_ui_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _set_player_controls(enabled: bool) -> void:
	if player != null and player.has_method("set_controls_enabled"):
		player.call("set_controls_enabled", enabled)


func _on_master_volume_changed(value: float) -> void:
	_settings["master_volume"] = value
	_apply_audio("Master", value)
	_save_settings()


func _on_music_volume_changed(value: float) -> void:
	_settings["music_volume"] = value
	_apply_audio("Music", value)
	_save_settings()


func _on_sfx_volume_changed(value: float) -> void:
	_settings["sfx_volume"] = value
	_apply_audio("SFX", value)
	_save_settings()


func _on_environment_selected(index: int) -> void:
	var value := _environment_option.get_item_text(index)
	_settings["environment"] = value
	_apply_environment(value)
	_save_settings()


func _on_quality_selected(index: int) -> void:
	var value := _quality_option.get_item_text(index)
	_settings["quality"] = value
	_apply_quality(value)
	_save_settings()


func _on_resolution_selected(index: int) -> void:
	var value := _resolution_option.get_item_text(index)
	_settings["resolution"] = value
	_apply_resolution(value)
	_save_settings()
	_update_ui_layout()
