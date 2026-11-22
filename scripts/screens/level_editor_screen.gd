class_name LevelEditorScreen
extends Screen
## Write your own quiz: 3-20 questions, each with 4-8 answers.
## Tap the button next to an answer to set it Wrong, or Right for 10 / 25 / 50 / 100 points.

const STATES := [0, 10, 25, 50, 100]
const SLOTS := 8

var questions: Array = []  # [{"q": "", "answers": [{"t": "", "p": 0}, ...8]}]
var _index := 0

var _title: LineEdit
var _header: Label
var _question: LineEdit
var _answer_edits: Array[LineEdit] = []
var _state_buttons: Array[Button] = []
var _status: Label
var _save: Button


func build() -> void:
	for i in 3:
		questions.append(_empty_question())
	_title = input(L.t("level_title_ph"))
	_title.max_length = 40
	_header = label("", 26)
	_question = input(L.t("question_ph"))
	_question.max_length = 120
	_question.text_changed.connect(func(t: String) -> void: questions[_index]["q"] = t)

	var list := scroll_list()
	for i in SLOTS:
		var r := row(list)
		var e := input(L.t("answer_ph") % (i + 1), r)
		e.max_length = 40
		e.alignment = HORIZONTAL_ALIGNMENT_LEFT
		e.custom_minimum_size.y = 64
		e.size_flags_horizontal = SIZE_EXPAND_FILL
		e.text_changed.connect(func(t: String) -> void: questions[_index]["answers"][i]["t"] = t)
		_answer_edits.append(e)
		var s := button("", _cycle.bind(i), r)
		s.custom_minimum_size = Vector2(200, 64)
		s.add_theme_font_size_override("font_size", 24)
		_state_buttons.append(s)

	var nav := row()
	for pair in [["<", _go.bind(-1)], [L.t("add_q"), _add_question], [L.t("del_q"), _delete_question], [">", _go.bind(1)]]:
		var b := button(pair[0], pair[1], nav)
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 70
		b.add_theme_font_size_override("font_size", 24)
	_status = label("", 22)
	var bottom := row()
	button(L.t("back"), main.show_levels, bottom).size_flags_horizontal = SIZE_EXPAND_FILL
	_save = button(L.t("save_level"), _on_save, bottom)
	_save.size_flags_horizontal = SIZE_EXPAND_FILL
	_show()


func _empty_question() -> Dictionary:
	var answers := []
	for i in SLOTS:
		answers.append({"t": "", "p": 10 if i == 0 else 0})
	return {"q": "", "answers": answers}


func _show() -> void:
	var q: Dictionary = questions[_index]
	_header.text = L.t("editor_q") % [_index + 1, questions.size()]
	_question.text = q["q"]
	for i in SLOTS:
		_answer_edits[i].text = q["answers"][i]["t"]
		_paint_state(i)


func _paint_state(i: int) -> void:
	var p := int(questions[_index]["answers"][i]["p"])
	var b := _state_buttons[i]
	b.text = L.t("state_wrong") if p == 0 else L.t("state_points") % p
	var color: Color = UI.RATING_COLORS["R"] if p == 0 else UI.RATING_COLORS["G"]
	for state in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(state, UI.box(color))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)


func _cycle(i: int) -> void:
	var a: Dictionary = questions[_index]["answers"][i]
	a["p"] = STATES[(STATES.find(int(a["p"])) + 1) % STATES.size()]
	_paint_state(i)


func _go(step: int) -> void:
	_index = clampi(_index + step, 0, questions.size() - 1)
	_show()


func _add_question() -> void:
	if questions.size() < 20:
		questions.insert(_index + 1, _empty_question())
		_index += 1
		_show()


func _delete_question() -> void:
	if questions.size() > 1:
		questions.remove_at(_index)
		_index = mini(_index, questions.size() - 1)
		_show()


## The level as the server wants it (empty answer boxes dropped), or an error message.
func build_level() -> Dictionary:
	var title := _title.text.strip_edges()
	if title == "":
		return {"error": L.t("err_title")}
	if questions.size() < 3 or questions.size() > 20:
		return {"error": L.t("err_count")}
	var out := []
	for qi in questions.size():
		var q: Dictionary = questions[qi]
		if str(q["q"]).strip_edges() == "":
			return {"error": L.t("err_q") % (qi + 1)}
		var answers := []
		var right := 0
		for a: Dictionary in q["answers"]:
			if str(a["t"]).strip_edges() != "":
				answers.append({"t": str(a["t"]).strip_edges(), "p": int(a["p"])})
				if int(a["p"]) > 0:
					right += 1
		if answers.size() < 4:
			return {"error": L.t("err_answers") % (qi + 1)}
		if right == 0 or right == answers.size():
			return {"error": L.t("err_mix") % (qi + 1)}
		out.append({"q": str(q["q"]).strip_edges(), "answers": answers})
	return {"title": title, "questions": out}


func _on_save() -> void:
	var lvl := build_level()
	if lvl.has("error"):
		_status.text = lvl["error"]
		return
	_save.disabled = true
	_status.text = L.t("sending")
	var res := await Net.create_level(lvl["title"], lvl["questions"])
	if not is_inside_tree():
		return
	_save.disabled = false
	if res["ok"]:
		DisplayServer.clipboard_set(str(res["data"]))
		_status.text = L.t("level_saved") % res["data"]
		_save.disabled = true
	elif str(res["error"]).contains("bad words"):
		_status.text = L.t("err_bad_words")
	else:
		_status.text = L.t("err_generic") % res["error"]
