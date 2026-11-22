class_name Screen
extends Control
## Base class for every screen: background, margins, a vertical list,
## and small helpers to add labels and buttons. Screens put their content in build().

var main: Main
var box: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = UI.colors()["bg"]
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 80)  # room for the phone's notch
	margin.add_theme_constant_override("margin_bottom", 44)
	add_child(margin)

	box = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	margin.add_child(box)

	build()


## Override this in each screen.
func build() -> void:
	pass


func label(text: String, font_size := 30, parent: Node = null) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	(parent if parent else box).add_child(l)
	return l


func button(text: String, on_press: Callable, parent: Node = null) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 86
	b.pressed.connect(on_press)
	(parent if parent else box).add_child(b)
	return b


func spacer(height: int) -> void:
	var c := Control.new()
	c.custom_minimum_size.y = height
	box.add_child(c)


## A scrollable list that fills the free space. Add rows to the returned box.
func scroll_list() -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 14)
	scroll.add_child(list)
	box.add_child(scroll)
	return list


## A one-line input box.
func input(placeholder: String, parent: Node = null) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.custom_minimum_size.y = 80
	(parent if parent else box).add_child(e)
	return e


func row(parent: Node = null) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 14)
	(parent if parent else box).add_child(r)
	return r
