class_name LevelsScreen
extends Screen
## Player-made levels: create one, play one by its code, or duel a friend on yours.
## Levels are shared by code only (no public list), and can be reported.

var _code: LineEdit
var _status: Label
var _list: VBoxContainer


func build() -> void:
	label(L.t("levels"), 46)
	if not Net.is_configured():
		label(L.t("online_only"), 26)
		button(L.t("menu"), main.show_menu)
		return
	label(L.t("levels_note"), 24)
	button(L.t("create_level"), main.show_level_editor)
	var r := row()
	_code = input(L.t("level_code_ph"), r)
	_code.size_flags_horizontal = SIZE_EXPAND_FILL
	_code.max_length = 6
	_code.text_submitted.connect(func(_t: String) -> void: _play_code())
	button(L.t("play"), _play_code, r).custom_minimum_size.x = 170
	_status = label("", 24)
	label(L.t("my_levels"), 30)
	_list = scroll_list()
	button(L.t("menu"), main.show_menu)
	_load()


func _load() -> void:
	var res := await Net.my_levels()
	if not is_inside_tree():
		return
	if not res["ok"]:
		_status.text = L.t("net_error")
		return
	show_levels(res["data"])


func show_levels(levels: Array) -> void:
	for child in _list.get_children():
		child.queue_free()
	if levels.is_empty():
		label(L.t("no_levels"), 24, _list)
	for lvl: Dictionary in levels:
		var info := label(L.t("level_info") % [lvl["title"], lvl["id"], int(lvl.get("plays", 0))], 24, _list)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var r := row(_list)
		for pair in [[L.t("play"), main.show_level_practice.bind(lvl)], [L.t("duel_btn"), main.show_challenge.bind(lvl)], [L.t("copy"), _copy.bind(str(lvl["id"]))]]:
			var b := button(pair[0], pair[1], r)
			b.size_flags_horizontal = SIZE_EXPAND_FILL
			b.custom_minimum_size.y = 66


func _copy(code: String) -> void:
	DisplayServer.clipboard_set(code)
	_status.text = L.t("copied")


func _play_code() -> void:
	_status.text = L.t("connecting")
	var res := await Net.get_level(_code.text.strip_edges())
	if not is_inside_tree():
		return
	if res["ok"]:
		main.show_level_practice(res["data"])
	else:
		_status.text = L.t("level_not_found") if str(res["error"]).contains("not found") else L.t("net_error")
