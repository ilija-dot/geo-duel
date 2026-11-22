class_name ChallengeScreen
extends Screen
## Pick a difficulty (or a player level), then type or paste a friend's ID to start a duel.
## Friends you played are saved for one-tap rematches.

var level: Dictionary = {}  # set to duel on a player-made level

var _input: LineEdit
var _status: Label
var _start: Button
var _found: Dictionary = {}
var _diff_buttons := {}


func build() -> void:
	label(L.t("challenge"), 46)
	if not Net.is_configured():
		label(L.t("offline"), 26)
		button(L.t("menu"), main.show_menu)
		return

	if level.is_empty():
		var diffs := row()
		for diff: String in QuestionBank.DIFFICULTIES:
			var b := button(L.t(diff), _set_difficulty.bind(diff), diffs)
			b.size_flags_horizontal = SIZE_EXPAND_FILL
			b.toggle_mode = true
			_diff_buttons[diff] = b
		_set_difficulty(str(Save.data["difficulty"]))
	else:
		label(L.t("level_label") % level["title"], 30)

	_input = input(L.t("friend_id_ph"))
	_input.max_length = 6
	_input.text_changed.connect(func(t: String) -> void:
		var caret := _input.caret_column
		_input.text = t.to_upper()
		_input.caret_column = caret
		_start.visible = false)
	_input.text_submitted.connect(func(_t: String) -> void: _find())

	var buttons := row()
	button(L.t("paste"), _paste, buttons).size_flags_horizontal = SIZE_EXPAND_FILL
	button(L.t("find"), _find, buttons).size_flags_horizontal = SIZE_EXPAND_FILL
	_status = label("", 24)
	_start = button("", _start_duel)
	_start.visible = false
	if level.is_empty():
		button(L.t("invite_link"), _invite)

	label(L.t("friends"), 32)
	var list := scroll_list()
	if (Save.data["friends"] as Array).is_empty():
		label(L.t("no_friends"), 24, list)
	for f: Dictionary in Save.data["friends"]:
		var b := button("%s  (%s)" % [f["name"], f["id"]], _rematch.bind(f), list)
		b.custom_minimum_size.y = 72

	button(L.t("menu"), main.show_menu)


func _set_difficulty(diff: String) -> void:
	if not diff in QuestionBank.DIFFICULTIES:
		diff = "medium"
	Save.data["difficulty"] = diff
	Save.save_game()
	for key: String in _diff_buttons:
		(_diff_buttons[key] as Button).set_pressed_no_signal(key == diff)


## Copies a link that opens the game straight into a duel with you.
func _invite() -> void:
	if str(Save.data["player_id"]) == "":
		_status.text = L.t("connecting")
		var res := await Net.register()
		if not is_inside_tree():
			return
		if not res["ok"]:
			_status.text = L.t("net_error")
			return
	var link := Net.invite_link(str(Save.data["difficulty"]))
	DisplayServer.clipboard_set(link)
	_status.text = L.t("invite_copied") % link


func _paste() -> void:
	_input.text = DisplayServer.clipboard_get().strip_edges().to_upper().left(6)
	_find()


func _find() -> void:
	var id := _input.text.strip_edges().to_upper()
	if id.length() != 6:
		_status.text = L.t("not_found")
		return
	if id == str(Save.data["player_id"]):
		_status.text = L.t("own_id")
		return
	_status.text = L.t("connecting")
	var res := await Net.find_player(id)
	if not is_inside_tree():
		return
	if not res["ok"]:
		_status.text = L.t("net_error")
	elif (res["data"] as Dictionary).is_empty():
		_status.text = L.t("not_found")
	else:
		_found = res["data"]
		_status.text = ""
		_start.text = L.t("start_duel") % _found["nickname"]
		_start.visible = true


func _rematch(f: Dictionary) -> void:
	_found = {"id": f["id"], "nickname": f["name"]}
	_start_duel()


func _start_duel() -> void:
	_start.disabled = true
	_status.text = L.t("connecting")
	var res := await Net.create_duel(str(_found["id"]), str(Save.data["difficulty"]), str(level.get("id", "")))
	if not is_inside_tree():
		return
	_start.disabled = false
	if not res["ok"]:
		var err := str(res["error"])
		if err.contains("player not found"):
			_status.text = L.t("not_found")
		elif err.contains("level not found"):
			_status.text = L.t("level_not_found")
		elif err.contains("own id"):
			_status.text = L.t("own_id")
		else:
			_status.text = L.t("err_generic") % err
		return
	Save.add_friend(str(_found["id"]), str(_found["nickname"]))
	main.show_duel_quiz(res["data"])
