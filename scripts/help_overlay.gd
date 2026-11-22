class_name HelpOverlay
extends Control
## Rules and a short tutorial, shown on top of whatever screen is open.
## Opened with F1 (or the Help button). The game pauses while it's open,
## so the quiz timer stops. Close with the button, F1 or Escape.

const SECTIONS := [
	["help_how_t", "help_how"],
	["help_score_t", "help_score"],
	["help_diff_t", "help_diff"],
	["help_duel_t", "help_duel"],
	["help_board_t", "help_board"],
	["help_levels_t", "help_levels"],
	["help_shop_t", "help_shop"],
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	panel.offset_left = 24
	panel.offset_right = -24
	panel.offset_top = 60
	panel.offset_bottom = -40
	var sb := UI.box(UI.colors()["bg"])
	sb.set_border_width_all(3)
	sb.border_color = UI.colors()["tile"]
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	_label(L.t("help_title"), 44, col).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(L.t("help_key"), 20, col).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 8)
	scroll.add_child(text)
	for pair in SECTIONS:
		var heading := _label(L.t(pair[0]), 30, text)
		heading.add_theme_color_override("font_color", UI.colors()["tile"].lightened(0.2))
		_label(L.t(pair[1]), 24, text)

	var close := Button.new()
	close.text = L.t("help_close")
	close.custom_minimum_size.y = 84
	close.pressed.connect(close_help)
	col.add_child(close)
	get_tree().paused = true


func _label(t: String, font_size: int, parent: Node) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	parent.add_child(l)
	return l


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close_help()


func close_help() -> void:
	get_tree().paused = false
	queue_free()
