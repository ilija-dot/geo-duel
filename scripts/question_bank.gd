class_name QuestionBank
extends RefCounted
## Loads the questions from data/questions.json, builds the tiles for each
## difficulty, and scores answers.
##
## A "round" is what the quiz screen plays: an array of questions like
##   {"text": "Name a river in Africa", "answers": [{"text": "Nile", "points": 10}, ...],
##    "tiles": [3, 0, 6, 1, 5, 2]}   <- which answers are shown, in order
## Built-in questions and player-made levels both become rounds, so the quiz works the same.

static var path := "res://data/questions.json"  # tests can point this elsewhere
const POINTS := {1: 10, 2: 25, 3: 50, 4: 100}
const PER_GAME := 10
const DIFFICULTIES := ["easy", "medium", "hard"]

static var _all: Array = []


static func all() -> Array:
	if _all.is_empty():
		var file := FileAccess.open(path, FileAccess.READ)
		if file:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Array:
				_all = parsed
	return _all


static func count() -> int:
	return all().size()


## Question ids start at 1.
static func get_question(id: int) -> Dictionary:
	var list := all()
	if id < 1 or id > list.size():
		return {}
	return list[id - 1]


static func _answer_points(answer: Dictionary) -> int:
	return POINTS.get(int(answer.get("rarity", 1)), 10) if answer.get("correct", false) else 0


## Points for picking answer number `index` of a built-in question (-1 = ran out of time).
static func points(question_id: int, index: int) -> int:
	var q := get_question(question_id)
	if q.is_empty() or index < 0 or index >= (q["answers"] as Array).size():
		return 0
	return _answer_points(q["answers"][index])


## Easy and medium use the "easy" question pool, hard uses the "hard" pool.
static func pool_for(difficulty: String) -> String:
	return "hard" if difficulty == "hard" else "easy"


## Which answers are shown for a difficulty (same seed = same tiles for both players):
##   easy   = all right answers (4-5) + 2 wrong
##   medium = 3 right + 3 wrong
##   hard   = 2 right + all wrong (3-4)
static func tiles_for(question_id: int, difficulty: String, seed_key: String) -> Array[int]:
	var q := get_question(question_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s-%d" % [seed_key, question_id])
	var right: Array[int] = []
	var wrong: Array[int] = []
	var answers: Array = q["answers"]
	for i in answers.size():
		if answers[i].get("correct", false):
			right.append(i)
		else:
			wrong.append(i)
	_shuffle(right, rng)
	_shuffle(wrong, rng)
	match difficulty:
		"easy":
			wrong = wrong.slice(0, 2)
		"medium":
			right = right.slice(0, 3)
			wrong = wrong.slice(0, 3)
		"hard":
			right = right.slice(0, 2)
	var tiles: Array[int] = right + wrong
	_shuffle(tiles, rng)
	return tiles


## A round of built-in questions, in the current language.
static func round_from_ids(ids: Array, difficulty: String, seed_key: String) -> Array:
	var out := []
	for id in ids:
		var q := get_question(int(id))
		var answers := []
		for a: Dictionary in q["answers"]:
			answers.append({"text": L.pick(a), "points": _answer_points(a)})
		out.append({"text": L.pick(q["q"]), "answers": answers, "tiles": tiles_for(int(id), difficulty, seed_key)})
	return out


## A round from a player-made level: all its answers, shuffled.
static func round_from_level(level: Dictionary, seed_key: String) -> Array:
	var out := []
	var questions: Array = level["questions"]
	for qi in questions.size():
		var q: Dictionary = questions[qi]
		var answers := []
		var tiles: Array[int] = []
		for a: Dictionary in q["answers"]:
			tiles.append(answers.size())
			answers.append({"text": str(a["t"]), "points": int(a["p"])})
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%s-%d" % [seed_key, qi])
		_shuffle(tiles, rng)
		out.append({"text": str(q["q"]), "answers": answers, "tiles": tiles})
	return out


## The round for an online duel (built-in questions or a level).
static func round_for_duel(duel: Dictionary) -> Array:
	if duel.get("level") is Dictionary:
		return round_from_level(duel["level"], str(duel["id"]))
	return round_from_ids(duel["question_ids"], str(duel.get("difficulty", "medium")), str(duel["id"]))


## Points for picking answer `pick` in one round question (-1 = no answer).
static func round_points(question: Dictionary, pick: int) -> int:
	var answers: Array = question["answers"]
	if pick < 0 or pick >= answers.size():
		return 0
	return int(answers[pick]["points"])


static func round_total(round: Array, picks: Array) -> int:
	var sum := 0
	for i in mini(round.size(), picks.size()):
		sum += round_points(round[i], int(picks[i]))
	return sum


## For practice: questions from the difficulty's pool this phone has seen least, in random order.
static func pick_practice(seen: Dictionary, difficulty := "medium") -> Array[int]:
	var pool := pool_for(difficulty)
	var ids: Array[int] = []
	for q: Dictionary in all():
		if str(q.get("difficulty", "easy")) == pool:
			ids.append(int(q["id"]))
	ids.shuffle()
	ids.sort_custom(func(a: int, b: int) -> bool: return int(seen.get(str(a), 0)) < int(seen.get(str(b), 0)))
	return ids.slice(0, PER_GAME)


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
