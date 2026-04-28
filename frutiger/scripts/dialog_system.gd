class_name DialogSystem
extends CanvasLayer

signal dialog_finished
signal choice_selected(index: int)

const TYPEWRITER_SPD := 0.026

var _queue: Array[Dictionary] = []
var _current: Dictionary = {}
var _typing := false
var _choices_shown := false

var _root: Control
var _panel: PanelContainer
var _speaker_bg: PanelContainer
var _speaker_label: Label
var _text_label: RichTextLabel
var _continue_hint: Label
var _choices_box: HBoxContainer
var _slide_tween: Tween
var _type_tween: Tween


func _ready() -> void:
	layer = 10
	_build_ui()
	_panel.visible = false


# lines: Array of String or Dictionary {speaker, text, choices?}
func show_dialog(lines: Array) -> void:
	_queue.clear()
	for entry in lines:
		if entry is String:
			_queue.append({"speaker": "", "text": entry})
		elif entry is Dictionary:
			_queue.append(entry)
	_panel.visible = true
	_advance()
	_do_open()


func _do_open() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var vp := get_viewport().get_visible_rect().size
	_panel.position.x = (vp.x - _panel.size.x) * 0.5
	var target_y := vp.y - _panel.size.y - 28.0
	_panel.position.y = vp.y + 20.0
	if _slide_tween:
		_slide_tween.kill()
	_slide_tween = create_tween()
	_slide_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_slide_tween.tween_property(_panel, "position:y", target_y, 0.42)


func _do_close() -> void:
	var vp := get_viewport().get_visible_rect().size
	if _slide_tween:
		_slide_tween.kill()
	_slide_tween = create_tween()
	_slide_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_slide_tween.tween_property(_panel, "position:y", vp.y + 20.0, 0.32)
	_slide_tween.tween_callback(func():
		_panel.visible = false
		dialog_finished.emit()
	)


func _advance() -> void:
	if _queue.is_empty():
		_do_close()
		return
	_current = _queue.pop_front()
	var speaker: String = _current.get("speaker", "")
	_speaker_label.text = speaker
	_speaker_bg.visible = speaker.length() > 0
	_text_label.text = ""
	_continue_hint.visible = false
	_choices_shown = false
	_clear_choices()
	_run_typewriter(_current.get("text", ""))


func _run_typewriter(full: String) -> void:
	_typing = true
	if _type_tween:
		_type_tween.kill()
	_type_tween = create_tween()
	_type_tween.tween_method(
		func(n: int): _text_label.text = full.left(n),
		0, full.length(),
		maxf(full.length() * TYPEWRITER_SPD, 0.01)
	)
	_type_tween.tween_callback(_on_type_done)


func _on_type_done() -> void:
	_typing = false
	var choices: Array = _current.get("choices", [])
	if choices.is_empty():
		_continue_hint.visible = true
	else:
		_show_choices(choices)


func _show_choices(choices: Array) -> void:
	_choices_shown = true
	for i in choices.size():
		_choices_box.add_child(_make_choice_btn(choices[i], i))


func _on_choice(idx: int) -> void:
	_clear_choices()
	_choices_shown = false
	choice_selected.emit(idx)
	_advance()


func _clear_choices() -> void:
	for c in _choices_box.get_children():
		c.queue_free()


func _input(event: InputEvent) -> void:
	if not _panel.visible or _choices_shown:
		return
	var fired := false
	if event.is_action_pressed("ui_accept"):
		fired = true
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			fired = true
	if not fired:
		return
	get_viewport().set_input_as_handled()
	if _typing:
		if _type_tween:
			_type_tween.kill()
		_text_label.text = _current.get("text", "")
		_on_type_done()
	else:
		_advance()


# ─── Build ───────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_root)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _panel_style())
	_panel.clip_contents = true
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_root.add_child(_panel)

	# Content fills panel; gloss overlays on top (added after = drawn on top)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 18)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	_speaker_bg = _make_speaker_panel()
	vbox.add_child(_speaker_bg)
	_speaker_label = Label.new()
	_speaker_label.add_theme_font_size_override("font_size", 17)
	_speaker_label.add_theme_color_override("font_color", Color(0.88, 0.97, 1.0))
	_speaker_bg.add_child(_speaker_label)

	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = false
	_text_label.scroll_active = false
	_text_label.fit_content = true
	_text_label.custom_minimum_size = Vector2(0, 72)
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.add_theme_font_size_override("normal_font_size", 20)
	_text_label.add_theme_color_override("default_color", Color(0.95, 0.98, 1.0))
	vbox.add_child(_text_label)

	_continue_hint = Label.new()
	_continue_hint.text = "▶  продолжить"
	_continue_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_continue_hint.add_theme_font_size_override("font_size", 13)
	_continue_hint.add_theme_color_override("font_color", Color(0.68, 0.90, 1.0, 0.80))
	_continue_hint.visible = false
	vbox.add_child(_continue_hint)
	_pulse_hint()

	_choices_box = HBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 10)
	_choices_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_choices_box)

	# Gloss strip — second child renders on top of margin content
	var gloss := TextureRect.new()
	gloss.texture = _gloss_texture()
	gloss.stretch_mode = TextureRect.STRETCH_SCALE
	gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gloss.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gloss.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	gloss.custom_minimum_size = Vector2(0, 46)
	_panel.add_child(gloss)

	get_viewport().size_changed.connect(_on_viewport_resized)
	call_deferred("_init_width")


func _init_width() -> void:
	if not is_inside_tree():
		return
	var vp := get_viewport().get_visible_rect().size
	_panel.custom_minimum_size.x = clampf(vp.x * 0.72, 520.0, 940.0)


func _on_viewport_resized() -> void:
	if not is_inside_tree():
		return
	var vp := get_viewport().get_visible_rect().size
	_panel.custom_minimum_size.x = clampf(vp.x * 0.72, 520.0, 940.0)
	call_deferred("_reposition")


func _reposition() -> void:
	if not is_inside_tree() or not _panel.visible:
		return
	var vp := get_viewport().get_visible_rect().size
	_panel.position = Vector2(
		(vp.x - _panel.size.x) * 0.5,
		vp.y - _panel.size.y - 28.0
	)


# ─── Styles ──────────────────────────────────────────────────────────────────

func _panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.35, 0.60, 0.88, 0.76)
	s.corner_radius_top_left = 16
	s.corner_radius_top_right = 16
	s.corner_radius_bottom_left = 16
	s.corner_radius_bottom_right = 16
	s.border_width_left = 1
	s.border_width_top = 1
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.border_color = Color(0.74, 0.92, 1.0, 0.88)
	s.shadow_color = Color(0.0, 0.10, 0.35, 0.55)
	s.shadow_size = 14
	s.shadow_offset = Vector2(0, 5)
	s.set_content_margin_all(0)
	return s


func _make_speaker_panel() -> PanelContainer:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.18, 0.44, 0.78, 0.72)
	s.corner_radius_top_left = 8
	s.corner_radius_top_right = 8
	s.corner_radius_bottom_left = 8
	s.corner_radius_bottom_right = 8
	s.border_width_left = 1
	s.border_width_top = 1
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.border_color = Color(0.58, 0.84, 1.0, 0.74)
	s.set_content_margin_all(6)
	s.set_content_margin(SIDE_LEFT, 12)
	s.set_content_margin(SIDE_RIGHT, 12)
	pc.add_theme_stylebox_override("panel", s)
	return pc


func _make_choice_btn(text: String, idx: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 44)

	var sn := StyleBoxFlat.new()
	sn.bg_color = Color(0.28, 0.58, 0.90, 0.52)
	sn.corner_radius_top_left = 10
	sn.corner_radius_top_right = 10
	sn.corner_radius_bottom_left = 10
	sn.corner_radius_bottom_right = 10
	sn.border_width_left = 1
	sn.border_width_top = 1
	sn.border_width_right = 1
	sn.border_width_bottom = 1
	sn.border_color = Color(0.68, 0.90, 1.0, 0.80)
	sn.set_content_margin_all(8)

	var sh := sn.duplicate() as StyleBoxFlat
	sh.bg_color = Color(0.42, 0.72, 1.0, 0.70)
	var sp := sn.duplicate() as StyleBoxFlat
	sp.bg_color = Color(0.22, 0.50, 0.82, 0.65)

	btn.add_theme_stylebox_override("normal", sn)
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_stylebox_override("pressed", sp)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 17)
	btn.pressed.connect(func(): _on_choice(idx))
	return btn


func _gloss_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 1.0, 1.0, 0.22))
	g.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_LINEAR
	t.fill_from = Vector2(0.5, 0.0)
	t.fill_to = Vector2(0.5, 1.0)
	t.width = 4
	t.height = 4
	return t


func _pulse_hint() -> void:
	var t := create_tween().set_loops()
	t.tween_property(_continue_hint, "modulate:a", 0.28, 0.7).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_continue_hint, "modulate:a", 1.0, 0.7).set_ease(Tween.EASE_IN_OUT)
