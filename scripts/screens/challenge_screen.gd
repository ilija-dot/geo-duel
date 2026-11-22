class_name ChallengeScreen
extends Screen
## Type (or paste) a friend's ID to start a duel. Friends you played are saved for one-tap rematches.

var _input: LineEdit
var _status: Label
var _start: Button
var _found: Dictionary = {}


func build() -> void:
	label(L.t("challenge"), 48)
	if not Net.is_configured():
		label(L.t("offline"), 26)
		button(L.t("menu"), main.show_menu)
		return

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
	_status = label("", 26)
	_start = button("", _start_duel)
	_start.visible = false

	label(L.t("friends"), 34)
	var list := scroll_list()
	if (Save.data["friends"] as Array).is_empty():
		label(L.t("no_friends"), 24, list)
	for f: Dictionary in Save.data["friends"]:
		var b := button("%s  (%s)" % [f["name"], f["id"]], _rematch.bind(f), list)
		b.custom_minimum_size.y = 76

	button(L.t("menu"), main.show_menu)


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
	var res := await Net.create_duel(str(_found["id"]))
	if not is_inside_tree():
		return
	_start.disabled = false
	if not res["ok"]:
		var err := str(res["error"])
		_status.text = L.t("not_found") if err.contains("not found") else (L.t("own_id") if err.contains("own id") else L.t("err_generic") % err)
		return
	Save.add_friend(str(_found["id"]), str(_found["nickname"]))
	main.show_duel_quiz(res["data"])
