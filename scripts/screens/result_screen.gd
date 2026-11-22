class_name ResultScreen
extends Screen
## After a game: your score, the friend's score, and points per question.

## {"duel": {...server duel...}, "coins": n}  or  {"question_ids", "picks", "coins"} for practice
var result: Dictionary


func build() -> void:
	var is_duel := result.has("duel")
	var duel: Dictionary = result.get("duel", {})
	var ids: Array = duel["question_ids"] if is_duel else result["question_ids"]
	var my_picks: Array = (duel["my_picks"] if duel["my_picks"] != null else []) if is_duel else result["picks"]
	var their_picks: Array = duel["their_picks"] if is_duel and duel["their_picks"] != null else []
	var mine := QuestionBank.total(ids, my_picks)

	if not is_duel:
		label(L.t("practice_title"), 40)
		label(L.t("score") % mine, 84)
	else:
		label(L.t("duel_with") % duel["opponent_name"], 38)
		if duel["their_done"]:
			var theirs := int(duel["their_score"])
			label("%d : %d" % [mine, theirs], 84)
			label("%s  -  %s" % [L.t("you"), duel["opponent_name"]], 26)
			var verdict := "you_won" if mine > theirs else ("you_lost" if mine < theirs else "draw")
			label(L.t(verdict), 40)
			if mine > theirs:
				var gems := Save.claim_win(str(duel["id"]))
				if gems > 0:
					label(L.t("plus_gems") % gems, 28)
		else:
			label(L.t("score") % mine, 84)
			label(L.t("waiting_long") % duel["opponent_name"], 26)

	if int(result.get("coins", 0)) > 0:
		label(L.t("plus_coins") % int(result["coins"]), 28)

	# Points per question: you (and your friend once they've played).
	var list := scroll_list()
	for i in ids.size():
		var q := QuestionBank.get_question(int(ids[i]))
		var r := row(list)
		var text := label("%d. %s" % [i + 1, L.pick(q["q"])], 22, r)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		text.size_flags_horizontal = SIZE_EXPAND_FILL
		_points_cell(QuestionBank.points(int(ids[i]), int(my_picks[i])) if i < my_picks.size() else -1, r)
		if is_duel:
			_points_cell(QuestionBank.points(int(ids[i]), int(their_picks[i])) if i < their_picks.size() else -1, r)

	var buttons := row()
	if is_duel:
		button(L.t("matches"), main.show_duels, buttons).size_flags_horizontal = SIZE_EXPAND_FILL
	else:
		button(L.t("practice_again"), main.show_practice, buttons).size_flags_horizontal = SIZE_EXPAND_FILL
	button(L.t("menu"), main.show_menu, buttons).size_flags_horizontal = SIZE_EXPAND_FILL


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
