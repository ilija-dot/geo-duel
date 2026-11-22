class_name AvatarScreen
extends Screen
## Build your avatar from parts. Some extras cost coins or gems (looks only).

var _avatar := {}
var _preview: AvatarView
var _labels := {}
var _status: Label
var _save: Button


func build() -> void:
	_avatar = Save.avatar()
	label(L.t("avatar"), 46)
	_preview = AvatarView.make(_avatar, 240)
	box.add_child(_preview)

	for key: String in AvatarParts.KEYS:
		var r := row()
		var prev := button("<", _change.bind(key, -1), r)
		prev.custom_minimum_size = Vector2(90, 70)
		var l := label("", 26, r)
		l.size_flags_horizontal = SIZE_EXPAND_FILL
		_labels[key] = l
		var nxt := button(">", _change.bind(key, 1), r)
		nxt.custom_minimum_size = Vector2(90, 70)

	_status = label("", 22)
	var buttons := row()
	button(L.t("random"), _randomize, buttons).size_flags_horizontal = SIZE_EXPAND_FILL
	_save = button(L.t("save"), _on_save, buttons)
	_save.size_flags_horizontal = SIZE_EXPAND_FILL
	button(L.t("menu"), main.show_menu)
	_refresh()


func _change(key: String, step: int) -> void:
	var n := AvatarParts.count(key)
	_avatar[key] = (int(_avatar[key]) + step + n) % n
	_refresh()


func _randomize() -> void:
	_avatar = AvatarParts.normalize(AvatarParts.random_avatar())
	_refresh()


func _acc_owned() -> bool:
	var i := int(_avatar["acc"])
	return AvatarParts.is_free(i) or Save.owns(AvatarParts.item_id(i))


func _refresh() -> void:
	_preview.avatar = _avatar
	for key: String in AvatarParts.KEYS:
		var text := "%s  %d/%d" % [L.t("part_" + key), int(_avatar[key]) + 1, AvatarParts.count(key)]
		if key == "acc":
			var acc := AvatarParts.accessory(int(_avatar["acc"]))
			text = "%s: %s" % [L.t("part_acc"), L.pick(acc)]
			if not _acc_owned():
				text += "  (%d %s)" % [acc["price"], L.t("gems_word") if acc["currency"] == "gems" else L.t("coins_word")]
		(_labels[key] as Label).text = text
	if _acc_owned():
		_save.text = L.t("save")
	else:
		var acc := AvatarParts.accessory(int(_avatar["acc"]))
		_save.text = L.t("buy_for") % [acc["price"], L.t("gems_word") if acc["currency"] == "gems" else L.t("coins_word")]


func _on_save() -> void:
	if not _acc_owned():
		var acc := AvatarParts.accessory(int(_avatar["acc"]))
		var item := {"id": AvatarParts.item_id(int(_avatar["acc"])), "price": acc["price"], "currency": acc["currency"]}
		if not Save.buy(item):
			_status.text = L.t("not_enough") % (L.t("gems_word") if acc["currency"] == "gems" else L.t("coins_word"))
			return
		_refresh()
	Save.set_avatar(_avatar)
	_status.text = L.t("saved")
	if Net.is_configured():
		var res := await Net.set_avatar(Save.avatar())
		if res["ok"]:
			Save.data["avatar_synced"] = true
			Save.save_game()
