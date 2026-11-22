class_name QuizScreen
extends Screen
## The quiz: one tile per shown answer, 20 seconds per question.
## Pick ONE tile. Wrong = 0 points. Correct = 10 / 25 / 50 / 100 points, the rarer the answer the more.

const SECONDS_PER_QUESTION := 20.0

var round: Array = []  # see QuestionBank: [{"text", "answers": [{"text", "points"}], "tiles": [...]}]
var title := ""
var duel: Dictionary = {}  # online duel; empty = practice
var practice: Dictionary = {}  # {"question_ids", "difficulty"} or {"level"}
var reveal_seconds := 2.0  # how long the answers stay revealed

var _index := 0
var _picks: Array[int] = []
var _time_left := 0.0
var _answering := false
var _tiles: Array[Button] = []

var _header: Label
var _timer_bar: ProgressBar
var _question: Label
var _grid: GridContainer
var _feedback: Label
var _quit: Button


func build() -> void:
	label(title, 22)
	_header = label("", 26)
	_timer_bar = ProgressBar.new()
	_timer_bar.max_value = SECONDS_PER_QUESTION
	_timer_bar.show_percentage = false
	_timer_bar.custom_minimum_size.y = 16
	box.add_child(_timer_bar)
	_question = label("", 36)
	_question.custom_minimum_size.y = 120
	_question.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label(L.t("rarity_hint"), 20)

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	_grid.size_flags_vertical = SIZE_EXPAND_FILL
	box.add_child(_grid)

	_feedback = label("", 30)
	_quit = button(L.t("quit"), main.show_menu)
	_show_question()


func _process(delta: float) -> void:
	if not _answering:
		return
	_time_left -= delta
	_timer_bar.value = maxf(_time_left, 0.0)
	if _time_left <= 0.0:
		_choose(-1)


func _update_header() -> void:
	_header.text = "%s     %s" % [L.t("question_n") % [_index + 1, round.size()],
		L.t("score") % QuestionBank.round_total(round, _picks)]


func _show_question() -> void:
	var q: Dictionary = round[_index]
	_update_header()
	_question.text = q["text"]
	_feedback.text = ""

	for child in _grid.get_children():
		child.queue_free()
	_tiles.clear()
	for answer_index: int in q["tiles"]:
		var b := Button.new()
		b.text = q["answers"][answer_index]["text"]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(0, 100)
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.size_flags_vertical = SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 27)
		b.pressed.connect(_choose.bind(answer_index))
		_grid.add_child(b)
		_tiles.append(b)

	_time_left = SECONDS_PER_QUESTION
	_timer_bar.value = SECONDS_PER_QUESTION
	_answering = true


## answer_index = which answer was picked (-1 = time ran out).
func _choose(answer_index: int) -> void:
	if not _answering:
		return
	_answering = false
	var q: Dictionary = round[_index]
	_picks.append(answer_index)
	var won := QuestionBank.round_points(q, answer_index)

	# Reveal: every correct tile shows its points, wrong tiles turn red when picked.
	var tiles: Array = q["tiles"]
	for i in _tiles.size():
		var idx: int = tiles[i]
		var tile := _tiles[i]
		var pts := QuestionBank.round_points(q, idx)
		var picked := idx == answer_index
		if pts > 0:
			tile.text = "%s\n+%d" % [q["answers"][idx]["text"], pts]
			_style_tile(tile, UI.RATING_COLORS["G"], picked)
		else:
			_style_tile(tile, UI.RATING_COLORS["R"] if picked else UI.colors()["done"], picked)
		tile.disabled = true

	if answer_index < 0:
		_feedback.text = L.t("time_up")
	elif won == 0:
		_feedback.text = L.t("wrong")
	else:
		_feedback.text = L.t("right") % won
	_update_header()
	create_tween().tween_callback(_next).set_delay(reveal_seconds)


func _style_tile(tile: Button, color: Color, picked: bool) -> void:
	var sb := UI.box(color)
	if picked:
		sb.set_border_width_all(6)
		sb.border_color = Color.WHITE
	tile.add_theme_stylebox_override("disabled", sb)
	tile.add_theme_color_override("font_disabled_color", Color.WHITE)


func _next() -> void:
	_index += 1
	if _index < round.size():
		_show_question()
	else:
		_finish()


func _finish() -> void:
	var total := QuestionBank.round_total(round, _picks)
	if duel.is_empty():
		var coins := 0
		if practice.has("question_ids"):  # no coins for player levels (they could be made too easy)
			Save.mark_practice_seen(practice["question_ids"])
			if Net.is_configured():  # the server pays (max 100 coins a day from practice)
				_question.text = L.t("sending")
				var res := await Net.practice_reward(practice["question_ids"], _picks)
				if not is_inside_tree():
					return
				coins = int(res["data"]) if res["ok"] else 0
			else:
				coins = total / 20
				Save.add_coins(coins)
		main.show_result({"round": round, "picks": _picks, "practice": practice, "title": title, "coins": coins})
		return
	_submit()


## Sends the duel answers. If the internet is down, shows a retry button (answers aren't lost).
func _submit() -> void:
	for child in _grid.get_children():
		child.queue_free()
	_question.text = L.t("sending")
	_feedback.text = ""
	_quit.visible = false
	var res := await Net.submit_picks(str(duel["id"]), _picks)
	if not is_inside_tree():
		return
	if res["ok"]:
		var coins := 0
		if not (res["data"].get("level") is Dictionary):  # level duels pay nothing
			coins = int(res["data"]["my_score"]) / 10  # already paid by the server
		await Net.sync_wallet()
		if not is_inside_tree():
			return
		main.show_result({"duel": res["data"], "coins": coins})
	elif str(res["error"]).contains("already played"):
		main.show_duels()
	else:
		_question.text = L.t("net_error")
		button(L.t("retry"), _submit, _grid)
