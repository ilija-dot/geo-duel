class_name PrivacyScreen
extends Screen
## The privacy note: what the game stores, who sees it, and how to delete it.

const SECTIONS := [
	["privacy_what_t", "privacy_what"],
	["privacy_who_t", "privacy_who"],
	["privacy_not_t", "privacy_not"],
	["privacy_where_t", "privacy_where"],
	["privacy_delete_t", "privacy_delete"],
	["privacy_age_t", "privacy_age"],
]

## Which screen the Back button returns to.
var back: Callable


func build() -> void:
	label(L.t("privacy_title"), 42)
	var list := scroll_list()
	var intro := label(L.t("privacy_intro"), 24, list)
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	for pair in SECTIONS:
		var heading := label(L.t(pair[0]), 30, list)
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		heading.add_theme_color_override("font_color", UI.colors()["tile"].lightened(0.2))
		var body := label(L.t(pair[1]), 23, list)
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button(L.t("back"), back if back.is_valid() else main.show_menu)
