class_name LeaderboardScreen
extends Screen
## Global ranking by wins: this week, last week's champions, and all time.

const MEDALS := [Color("f5c542"), Color("c0c7d1"), Color("cd7f32")]

var period := "week"
var _tabs := {}
var _status: Label
var _podium: HBoxContainer
var _list: VBoxContainer


func build() -> void:
	label(L.t("leaderboard"), 46)
	var tabs := row()
	for p: String in ["week", "last_week", "all"]:
		var b := button(L.t({"week": "this_week", "last_week": "last_week", "all": "all_time"}[p]), _select.bind(p), tabs)
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.toggle_mode = true
		b.custom_minimum_size.y = 72
		b.add_theme_font_size_override("font_size", 24)
		_tabs[p] = b
	_status = label("", 26)
	_podium = row()
	_podium.alignment = BoxContainer.ALIGNMENT_CENTER
	_podium.add_theme_constant_override("separation", 18)
	_list = scroll_list()
	label(L.t("board_note"), 18)
	button(L.t("menu"), main.show_menu)
	_select("week")


func _select(p: String) -> void:
	period = p
	for key: String in _tabs:
		(_tabs[key] as Button).set_pressed_no_signal(key == p)
	if not Net.is_configured():
		_status.text = L.t("online_only")
		return
	_status.text = L.t("connecting")
	var res := await Net.leaderboard(p)
	if not is_inside_tree() or period != p:
		return
	if not res["ok"]:
		_status.text = L.t("net_error")
		return
	show_board(res["data"])


## Fills the podium and list. Separate from _select() so tests can pass fake data.
func show_board(data: Dictionary) -> void:
	for child in _podium.get_children() + _list.get_children():
		child.queue_free()
	var rows: Array = data.get("rows", [])
	var me: Variant = data.get("me")
	if me is Dictionary:
		_status.text = L.t("your_rank") % [int(me["rank"]), int(me["wins"])]
	else:
		_status.text = L.t("not_ranked")
	if period == "last_week" and not rows.is_empty():
		_status.text = L.t("champions") + "\n" + _status.text
	if rows.is_empty():
		label(L.t("board_empty"), 26, _list)
		return

	# Podium: 2nd, 1st, 3rd
	for place in [1, 0, 2]:
		if place < rows.size():
			_podium.add_child(_podium_column(rows[place], place))
	for i in range(3, rows.size()):
		_list.add_child(_list_row(rows[i]))


func _podium_column(r: Dictionary, place: int) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_END
	col.add_theme_constant_override("separation", 6)
	col.add_child(AvatarView.make(r.get("avatar", {}), 130 if place == 0 else 100))
	var name_label := label(str(r["nickname"]), 24, col)
	name_label.custom_minimum_size.x = 170
	label(L.t("wins_n") % int(r["wins"]), 22, col)
	var block := Label.new()
	block.text = "#%d" % int(r["rank"])
	block.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	block.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	block.custom_minimum_size = Vector2(170, [130, 95, 70][place])
	block.add_theme_font_size_override("font_size", 34)
	block.add_theme_color_override("font_color", Color("2b2230"))
	block.add_theme_stylebox_override("normal", UI.box(MEDALS[place]))
	col.add_child(block)
	if str(r["id"]) == str(Save.data["player_id"]):
		name_label.text += " ★"
	return col


func _list_row(r: Dictionary) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	var rank := label("#%d" % int(r["rank"]), 26, line)
	rank.custom_minimum_size.x = 70
	line.add_child(AvatarView.make(r.get("avatar", {}), 60))
	var you := str(r["id"]) == str(Save.data["player_id"])
	var info := label("%s%s\n%s" % [r["nickname"], "  ★" if you else "", L.t("row_stats") % [int(r["wins"]), int(r["played"])]], 24, line)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info.size_flags_horizontal = SIZE_EXPAND_FILL
	return line
