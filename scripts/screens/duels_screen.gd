class_name DuelsScreen
extends Screen
## All your duels: whose turn it is, and results.

var _list: VBoxContainer
var _status: Label


func build() -> void:
	label(L.t("matches"), 48)
	_status = label("", 24)
	_list = scroll_list()
	var buttons := row()
	button(L.t("refresh"), _load, buttons).size_flags_horizontal = SIZE_EXPAND_FILL
	button(L.t("menu"), main.show_menu, buttons).size_flags_horizontal = SIZE_EXPAND_FILL
	if not Net.is_configured():
		_status.text = L.t("offline")
		return
	_load()


func _load() -> void:
	_status.text = L.t("connecting")
	var res := await Net.my_duels()
	if not is_inside_tree():
		return
	if not res["ok"]:
		_status.text = L.t("net_error")
		return
	_status.text = ""
	show_duels(res["data"])


## Fills the list. Separate from _load() so tests can call it with fake data.
func show_duels(duels: Array) -> void:
	for child in _list.get_children():
		child.queue_free()
	if duels.is_empty():
		label(L.t("no_matches"), 26, _list)
		return
	for d: Dictionary in duels:
		var r := row(_list)
		var info := label("%s\n%s" % [d["opponent_name"], status_text(d)], 28, r)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		info.size_flags_horizontal = SIZE_EXPAND_FILL
		var my_turn: bool = d["my_picks"] == null
		var action := button(L.t("play") if my_turn else L.t("view"),
			main.show_duel_quiz.bind(d) if my_turn else main.show_result.bind({"duel": d}), r)
		action.custom_minimum_size = Vector2(170, 76)


static func status_text(d: Dictionary) -> String:
	if d["my_picks"] == null:
		return L.t("your_turn")
	if not d["their_done"]:
		return L.t("waiting_for") % d["opponent_name"]
	var mine := int(d["my_score"])
	var theirs := int(d["their_score"])
	var key := "won_score" if mine > theirs else ("lost_score" if mine < theirs else "draw_score")
	return L.t(key) % [mine, theirs]
