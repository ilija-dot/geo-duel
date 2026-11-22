class_name MenuScreen
extends Screen
## Start screen: your ID, nickname, language, and the main buttons.

var _id_label: Label
var _status: Label
var _duels_button: Button


func build() -> void:
	label(L.t("title"), 72)
	label(L.t("tagline"), 26)
	label(L.t("wallet") % [Save.coins(), Save.gems()], 26)

	var id_row := row()
	id_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_id_label = label("", 32, id_row)
	var copy := button(L.t("copy"), _copy_id, id_row)
	copy.custom_minimum_size = Vector2(170, 70)

	var nick := input(L.t("nick_ph"))
	nick.text = str(Save.data["nickname"])
	nick.max_length = 16
	nick.text_changed.connect(func(t: String) -> void: Save.set_nickname(t))
	nick.text_submitted.connect(func(_t: String) -> void: _register())
	nick.focus_exited.connect(_register)

	_status = label("", 22)
	button(L.t("challenge"), main.show_challenge)
	_duels_button = button(L.t("matches"), main.show_duels)
	button(L.t("practice"), main.show_practice)
	var bottom := row()
	button(L.t("shop"), main.show_shop, bottom).size_flags_horizontal = SIZE_EXPAND_FILL
	button(L.t("other_lang"), _toggle_language, bottom).size_flags_horizontal = SIZE_EXPAND_FILL

	_show_id()
	if not Net.is_configured():
		_status.text = L.t("offline")
	else:
		_register()


func _show_id() -> void:
	var id := str(Save.data["player_id"])
	_id_label.text = L.t("your_id") % (id if id != "" else "------")


## Gets/updates your player ID online, and counts duels waiting for you.
func _register() -> void:
	if not Net.is_configured():
		return
	if str(Save.data["player_id"]) == "":
		_status.text = L.t("connecting")
	var res := await Net.register()
	if not is_inside_tree():
		return
	if not res["ok"]:
		_status.text = L.t("net_error")
		return
	_status.text = ""
	_show_id()
	var duels := await Net.my_duels()
	if is_inside_tree() and duels["ok"]:
		var waiting := 0
		for d: Dictionary in duels["data"]:
			if d["my_picks"] == null:
				waiting += 1
		if waiting > 0:
			_duels_button.text = L.t("matches_n") % waiting


func _copy_id() -> void:
	if str(Save.data["player_id"]) != "":
		DisplayServer.clipboard_set(str(Save.data["player_id"]))
		_status.text = L.t("copied")


func _toggle_language() -> void:
	L.toggle()
	main.show_menu()
