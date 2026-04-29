extends Control

var slot_panels: Array[PanelContainer] = []
var slot_labels: Array[Label] = []

func _ready() -> void:
	_build_ui()
	Inventory.slot_changed.connect(_on_slot_changed)
	Inventory.active_slot_changed.connect(_on_active_slot_changed)
	for i in Inventory.HOTBAR_SIZE:
		_on_slot_changed(i)
	_on_active_slot_changed(Inventory.active_index)

func _build_ui() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.name = "HotbarRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.anchor_left = 0.5
	row.anchor_right = 0.5
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.offset_left = -234
	row.offset_right = 234
	row.offset_top = -72
	row.offset_bottom = -16
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	for i in Inventory.HOTBAR_SIZE:
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.custom_minimum_size = Vector2(48, 48)
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 10)
		panel.add_child(label)
		row.add_child(panel)
		slot_panels.append(panel)
		slot_labels.append(label)
	var crosshair := Label.new()
	crosshair.name = "Crosshair"
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.text = "+"
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.anchor_left = 0.5
	crosshair.anchor_right = 0.5
	crosshair.anchor_top = 0.5
	crosshair.anchor_bottom = 0.5
	crosshair.offset_left = -10
	crosshair.offset_right = 10
	crosshair.offset_top = -10
	crosshair.offset_bottom = 10
	crosshair.add_theme_font_size_override("font_size", 22)
	add_child(crosshair)

func _on_slot_changed(slot_index: int) -> void:
	var slot = Inventory.slots[slot_index]
	if slot == null:
		slot_labels[slot_index].text = "%d" % (slot_index + 1)
	else:
		slot_labels[slot_index].text = "%d\n%s\nx%d" % [slot_index + 1, String(slot.block_id), slot.count]

func _on_active_slot_changed(slot_index: int) -> void:
	for i in slot_panels.size():
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.12, 0.12, 0.78)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = Color(1.0, 0.9, 0.25, 1.0) if i == slot_index else Color(0.35, 0.35, 0.35, 1.0)
		slot_panels[i].add_theme_stylebox_override("panel", style)
