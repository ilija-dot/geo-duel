class_name QuestionBank
extends RefCounted
## Loads the questions from data/questions.json and scores answers.
##
## Each question has 8 answers. Correct answers have a "rarity" from 1 (obvious) to 4 (rare).
## The rarer the correct answer you pick, the more points you get. Wrong answers give 0.

static var path := "res://data/questions.json"  # tests can point this elsewhere
const POINTS := {1: 10, 2: 25, 3: 50, 4: 100}
const PER_GAME := 10

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


## Points for picking answer number `index` (-1 = ran out of time).
static func points(question_id: int, index: int) -> int:
	var q := get_question(question_id)
	if q.is_empty() or index < 0 or index >= (q["answers"] as Array).size():
		return 0
	var answer: Dictionary = q["answers"][index]
	if not answer.get("correct", false):
		return 0
	return POINTS.get(int(answer.get("rarity", 1)), 10)


static func total(question_ids: Array, picks: Array) -> int:
	var sum := 0
	for i in mini(question_ids.size(), picks.size()):
		sum += points(int(question_ids[i]), int(picks[i]))
	return sum


## The order the 8 tiles are shown in. Same seed = same order (both players see the same layout).
static func tile_order(question_id: int, seed_key: String) -> Array[int]:
	var n := (get_question(question_id)["answers"] as Array).size()
	var order: Array[int] = []
	for i in n:
		order.append(i)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s-%d" % [seed_key, question_id])
	for i in range(n - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := order[i]
		order[i] = order[j]
		order[j] = tmp
	return order


## For practice: questions this phone has seen the fewest times, in random order.
static func pick_practice(seen: Dictionary) -> Array[int]:
	var ids: Array[int] = []
	for i in range(1, count() + 1):
		ids.append(i)
	ids.shuffle()
	ids.sort_custom(func(a: int, b: int) -> bool: return int(seen.get(str(a), 0)) < int(seen.get(str(b), 0)))
	return ids.slice(0, PER_GAME)
