class_name ResultScreen
extends Screen
## After a game: your score, the friend's score, and points per question.

## {"duel": {...server duel...}, "coins": n}
## or for practice {"round", "picks", "practice": {...}, "title", "coins"}
var result: Dictionary
var _status: Label


func build() -> void:
	var is_duel := result.has("duel")
	var duel: Dictionary = result.get("duel", {})
	var round: Array = QuestionBank.round_for_duel(duel) if is_duel else result["round"]
	var my_picks: Array = (duel["my_picks"] if duel["my_picks"] != null else []) if is_duel else result["picks"]
	var their_picks: Array = duel["their_picks"] if is_duel and duel["their_picks"] != null else []
	var mine := QuestionBank.round_total(round, my_picks)
	var level: Variant = duel.get("level") if is_duel else result.get("practice", {}).get("level")

	if not is_duel:
		label(str(result.get("title", L.t("practice_title"))), 34)
		label(L.t("score") % mine, 84)
	else:
		var heads := row()
		heads.alignment = BoxContainer.ALIGNMENT_CENTER
		heads.add_child(AvatarView.make(Save.avatar(), 110))
		label("vs", 30, heads)
		heads.add_child(AvatarView.make(duel.get("opponent_avatar", {}), 110))
		var mode: String = L.t("level_label") % level["title"] if level is Dictionary else L.t(str(duel.get("difficulty", "medium")))
		label("%s · %s" % [L.t("duel_with") % duel["opponent_name"], mode], 28)
		if duel["their_done"]:
			var theirs := QuestionBank.round_total(round, their_picks)
			label("%d : %d" % [mine, theirs], 80)
			label("%s  -  %s" % [L.t("you"), duel["opponent_name"]], 24)
			var verdict := "you_won" if mine > theirs else ("you_lost" if mine < theirs else "draw")
			label(L.t(verdict), 38)
			if mine > theirs and not (level is Dictionary):  # no gems for level duels
				var gems := Save.claim_win(str(duel["id"]))
				if gems > 0:
					label(L.t("plus_gems") % gems, 26)
		else:
			label(L.t("score") % mine, 80)
			label(L.t("waiting_long") % duel["opponent_name"], 24)

	if int(result.get("coins", 0)) > 0:
		label(L.t("plus_coins") % int(result["coins"]), 26)

	# Points per question: you (and your friend once they've played).
	var list := scroll_list()
	for i in round.size():
		var q: Dictionary = round[i]
		var r := row(list)
		var text := label("%d. %s" % [i + 1, q["text"]], 22, r)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		text.size_flags_horizontal = SIZE_EXPAND_FILL
		_points_cell(QuestionBank.round_points(q, int(my_picks[i])) if i < my_picks.size() else -1, r)
		if is_duel:
			_points_cell(QuestionBank.round_points(q, int(their_picks[i])) if i < their_picks.size() else -1, r)

	_status = label("", 22)
	if level is Dictionary:
		button(L.t("report"), _report.bind(str(level["id"])))
	var buttons := row()
	if is_duel:
		button(L.t("matches"), main.show_duels, buttons).size_flags_horizontal = SIZE_EXPAND_FILL
	elif level is Dictionary:
		button(L.t("levels"), main.show_levels, buttons).size_flags_horizontal = SIZE_EXPAND_FILL
	else:
		var diff := str(result.get("practice", {}).get("difficulty", "medium"))
		button(L.t("practice_again"), main.show_practice.bind(diff), buttons).size_flags_horizontal = SIZE_EXPAND_FILL
	button(L.t("menu"), main.show_menu, buttons).size_flags_horizontal = SIZE_EXPAND_FILL


func _report(code: String) -> void:
	var res := await Net.report_level(code)
	if is_inside_tree():
		_status.text = L.t("reported") if res["ok"] else L.t("net_error")


## A small colored box with the points (green = scored, red = 0, grey "?" = not played yet).
func _points_cell(points: int, parent: Node) -> void:
	var cell := Label.new()
	cell.text = "?" if points < 0 else str(points)
	cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cell.custom_minimum_size = Vector2(76, 50)
	cell.size_flags_vertical = SIZE_SHRINK_CENTER
	cell.add_theme_font_size_override("font_size", 24)
	cell.add_theme_color_override("font_color", Color.WHITE)
	var color: Color = Color(0.5, 0.5, 0.5) if points < 0 else (UI.RATING_COLORS["G"] if points > 0 else UI.RATING_COLORS["R"])
	cell.add_theme_stylebox_override("normal", UI.box(color))
	parent.add_child(cell)
