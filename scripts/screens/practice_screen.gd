class_name PracticeScreen
extends Screen
## Choose a difficulty to practice alone, or type a player level's code.

var _code: LineEdit
var _status: Label


func build() -> void:
	label(L.t("practice"), 48)
	for diff: String in QuestionBank.DIFFICULTIES:
		var b := button("%s\n%s" % [L.t(diff), L.t(diff + "_desc")], main.show_practice.bind(diff))
		b.custom_minimum_size.y = 120
		b.add_theme_font_size_override("font_size", 28)
	spacer(10)
	label(L.t("play_level"), 30)
	_code = input(L.t("level_code_ph"))
	_code.max_length = 6
	_code.text_submitted.connect(func(_t: String) -> void: _play_level())
	button(L.t("play_level"), _play_level)
	_status = label("", 24)
	button(L.t("menu"), main.show_menu)


func _play_level() -> void:
	if not Net.is_configured():
		_status.text = L.t("online_only")
		return
	_status.text = L.t("connecting")
	var res := await Net.get_level(_code.text.strip_edges())
	if not is_inside_tree():
		return
	if res["ok"]:
		main.show_level_practice(res["data"])
	else:
		_status.text = L.t("level_not_found") if str(res["error"]).contains("not found") else L.t("net_error")
