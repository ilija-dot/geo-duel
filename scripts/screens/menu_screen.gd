class_name MenuScreen
extends Screen
## Start screen: your avatar and ID, nickname, and the main buttons.

var _id_label: Label
var _status: Label
var _duels_button: Button


func build() -> void:
	label(L.t("title"), 64)
	var me := row()
	me.alignment = BoxContainer.ALIGNMENT_CENTER
	var avatar_button := Button.new()
	avatar_button.flat = true
	avatar_button.custom_minimum_size = Vector2(120, 120)
	avatar_button.pressed.connect(main.show_avatar)
	var face := AvatarView.make(Save.avatar(), 120)
	face.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	avatar_button.add_child(face)
	me.add_child(avatar_button)
	var info := VBoxContainer.new()
	me.add_child(info)
	_id_label = label("", 30, info)
	_id_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label(L.t("logged_in_as") % Save.data["email"] if Net.is_logged_in() else L.t("guest"), 20, info)
	label(L.t("wallet") % [Save.coins(), Save.gems()], 22, info)
	var copy := button(L.t("copy"), _copy_id, info)
	copy.custom_minimum_size = Vector2(170, 56)

	var nick := input(L.t("nick_ph"))
	nick.text = str(Save.data["nickname"])
	nick.max_length = 16
	nick.text_changed.connect(func(t: String) -> void: Save.set_nickname(t))
	nick.text_submitted.connect(func(_t: String) -> void: _register())
	nick.focus_exited.connect(_register)

	_status = label("", 22)
	button(L.t("challenge"), main.show_challenge.bind({}))
	_duels_button = button(L.t("matches"), main.show_duels)
	var r1 := row()
	button(L.t("practice"), main.show_practice_menu, r1).size_flags_horizontal = SIZE_EXPAND_FILL
	button(L.t("leaderboard"), main.show_leaderboard, r1).size_flags_horizontal = SIZE_EXPAND_FILL
	var r2 := row()
	button(L.t("levels"), main.show_levels, r2).size_flags_horizontal = SIZE_EXPAND_FILL
	button(L.t("avatar"), main.show_avatar, r2).size_flags_horizontal = SIZE_EXPAND_FILL
	button(L.t("account"), main.show_account, r2).size_flags_horizontal = SIZE_EXPAND_FILL
	var r3 := row()
	button(L.t("shop"), main.show_shop, r3).size_flags_horizontal = SIZE_EXPAND_FILL
	button(L.t("other_lang"), _toggle_language, r3).size_flags_horizontal = SIZE_EXPAND_FILL
	button(L.t("help") + " (F1)", main.show_help, r3).size_flags_horizontal = SIZE_EXPAND_FILL

	_show_id()
	if not Net.is_configured():
		_status.text = L.t("offline")
	else:
		_register()


func _show_id() -> void:
	var id := str(Save.data["player_id"])
	_id_label.text = L.t("your_id") % (id if id != "" else "------")


## Gets/updates your player ID online, uploads a changed avatar, and counts duels waiting for you.
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
	if not Save.data["avatar_synced"]:
		var av := await Net.set_avatar(Save.avatar())
		if av["ok"]:
			Save.data["avatar_synced"] = true
			Save.save_game()
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
