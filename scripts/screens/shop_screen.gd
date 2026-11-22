class_name ShopScreen
extends Screen
## Buy and equip color themes with coins (earned by playing) or gems (wins / real money later).

var _status: Label


func build() -> void:
	label(L.t("shop"), 56)
	label(L.t("shop_note"), 22)
	label(L.t("wallet") % [Save.coins(), Save.gems()], 28)

	var list := scroll_list()
	for item: Dictionary in ThemeCatalog.all():
		list.add_child(_row(item))

	_status = label("", 22)
	button(L.t("get_gems"), _get_gems)
	button(L.t("menu"), main.show_menu)


func _row(item: Dictionary) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 16)

	# Little color preview: background, tile, used tile.
	for key in ["bg", "tile", "done"]:
		var swatch := ColorRect.new()
		swatch.color = item[key]
		swatch.custom_minimum_size = Vector2(34, 70)
		r.add_child(swatch)

	var name_label := label(item["name"], 30, r)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.size_flags_horizontal = SIZE_EXPAND_FILL

	var id: String = item["id"]
	var action: Button
	if Save.data["equipped"] == id:
		action = button(L.t("equipped"), func() -> void: pass, r)
		action.disabled = true
	elif Save.owns(id):
		action = button(L.t("equip"), _equip.bind(id), r)
	else:
		action = button(L.t("price") % [item["price"], _currency_word(item["currency"])], _buy.bind(item), r)
	action.custom_minimum_size = Vector2(230, 70)
	return r


func _currency_word(currency: String) -> String:
	return L.t("gems_word") if currency == "gems" else L.t("coins_word")


func _buy(item: Dictionary) -> void:
	if Save.buy(item):
		_equip(item["id"])
	else:
		_status.text = L.t("not_enough") % _currency_word(item["currency"])


func _equip(id: String) -> void:
	Save.equip(id)
	main.refresh_theme()
	main.show_shop()


func _get_gems() -> void:
	# TODO (later): real-money gem packs.
	# 1. Add the Google Play Billing plugin (and StoreKit for iPhone).
	# 2. When the store confirms a purchase, call Save.add_gems(amount).
	# Purchases must go through Google Play / Apple billing - no other payment methods.
	_status.text = L.t("gems_soon")
