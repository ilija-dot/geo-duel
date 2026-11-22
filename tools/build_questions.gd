extends SceneTree
## Checks question files, merges them into data/questions.json, and writes the
## server answer key supabase/seed_questions.sql.
##
## Run:  godot --headless --path . -s tools/build_questions.gd -- <folder with part*.json>
## Without a folder it just re-checks data/questions.json and regenerates the SQL.

const OUT_JSON := "res://data/questions.json"
const OUT_SQL := "res://supabase/seed_questions.sql"
const POINTS := {1: 10, 2: 25, 3: 50, 4: 100}

var errors: Array[String] = []
var warnings: Array[String] = []


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var questions: Array = []
	if args.size() > 0:
		var dir := args[0]
		var files := Array(DirAccess.get_files_at(dir)).filter(func(f: String) -> bool: return f.begins_with("part") and f.ends_with(".json"))
		files.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
		for f: String in files:
			var part := _load(dir.path_join(f))
			print("%s: %d questions" % [f, part.size()])
			for q in part:
				q["_source"] = f
				questions.append(q)
	else:
		questions = _load(OUT_JSON)
		for q: Dictionary in questions:  # merged file stores topic as {"mk", "en"}
			if q.has("topic"):
				q["topic_mk"] = q["topic"]["mk"]
				q["topic_en"] = q["topic"]["en"]

	var seen_q := {}
	var rarity_count := {1: 0, 2: 0, 3: 0, 4: 0}
	for i in questions.size():
		var q: Dictionary = questions[i]
		q["id"] = i + 1
		_check(q, seen_q, rarity_count)

	for w in warnings:
		print("  warning: ", w)
	for e in errors:
		print("  ERROR: ", e)
	print("\n%d questions, %d errors, %d warnings. Correct answers by rarity: %s" % [questions.size(), errors.size(), warnings.size(), rarity_count])
	if errors.size() > 0:
		print("Nothing written - fix the errors first.")
		quit(1)
		return

	# Difficulty: questions whose correct answers are mostly well known are "easy",
	# the half with rarer correct answers is "hard".
	var by_rarity := questions.duplicate()
	by_rarity.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ra := _avg_rarity(a)
		var rb := _avg_rarity(b)
		return ra < rb if ra != rb else int(a["id"]) < int(b["id"]))
	for i in by_rarity.size():
		(by_rarity[i] as Dictionary)["difficulty"] = "easy" if i < by_rarity.size() / 2 else "hard"

	var clean := []
	for q: Dictionary in questions:
		q.erase("_source")
		clean.append({"id": q["id"], "difficulty": q["difficulty"], "topic": {"mk": q["topic_mk"], "en": q["topic_en"]}, "page": int(q["page"]), "q": q["q"], "answers": q["answers"]})
	var out := FileAccess.open(OUT_JSON, FileAccess.WRITE)
	out.store_string(JSON.stringify(clean, "\t"))
	out.close()
	_write_sql(clean)
	print("Wrote %s and %s" % [OUT_JSON, OUT_SQL])
	quit(0)


func _load(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("can't open " + path)
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Array):
		errors.append(path + " is not a JSON array")
		return []
	return parsed


func _check(q: Dictionary, seen_q: Dictionary, rarity_count: Dictionary) -> void:
	var where := "#%d (%s p.%s)" % [q["id"], q.get("_source", ""), q.get("page", "?")]
	for key in ["topic_mk", "topic_en", "page", "q", "answers"]:
		if not q.has(key):
			errors.append("%s missing '%s'" % [where, key])
			return
	var text: Dictionary = q["q"]
	if str(text.get("mk", "")) == "" or str(text.get("en", "")) == "":
		errors.append("%s question text missing mk or en" % where)
		return
	where += " \"%s\"" % text["en"]
	var key := str(text["mk"]).to_lower().strip_edges()
	if seen_q.has(key):
		errors.append("%s duplicate of #%d" % [where, seen_q[key]])
	seen_q[key] = q["id"]
	if str(text["mk"]).length() > 100 or str(text["en"]).length() > 100:
		warnings.append("%s question is long" % where)

	var answers: Array = q["answers"]
	if answers.size() != 8:
		errors.append("%s has %d answers (needs 8)" % [where, answers.size()])
		return
	var correct := 0
	var has_common := false
	var has_rare := false
	var texts := {}
	for a: Dictionary in answers:
		if str(a.get("mk", "")) == "" or str(a.get("en", "")) == "":
			errors.append("%s answer missing mk or en" % where)
			continue
		for lang in ["mk", "en"]:
			var t := "%s:%s" % [lang, str(a[lang]).to_lower()]
			if texts.has(t):
				errors.append("%s repeated answer '%s'" % [where, a[lang]])
			texts[t] = true
			if str(a[lang]).length() > 28:
				warnings.append("%s long answer '%s'" % [where, a[lang]])
		if a.get("correct", false):
			correct += 1
			var r := int(a.get("rarity", 0))
			if r < 1 or r > 4:
				errors.append("%s bad rarity on '%s'" % [where, a["en"]])
				continue
			rarity_count[r] += 1
			has_common = has_common or r == 1
			has_rare = has_rare or r >= 3
	if correct < 4 or correct > 5:
		errors.append("%s has %d correct answers (needs 4-5)" % [where, correct])
	if not has_common or not has_rare:
		warnings.append("%s rarity spread (needs a 1 and a 3/4)" % where)


static func _avg_rarity(q: Dictionary) -> float:
	var total := 0.0
	var n := 0
	for a: Dictionary in q["answers"]:
		if a.get("correct", false):
			total += float(a.get("rarity", 1))
			n += 1
	return total / maxi(n, 1)


func _write_sql(questions: Array) -> void:
	var meta := PackedStringArray()
	for q: Dictionary in questions:
		meta.append("(%d,'%s')" % [q["id"], q["difficulty"]])
	var rows := PackedStringArray()
	for q: Dictionary in questions:
		var answers: Array = q["answers"]
		for i in answers.size():
			var a: Dictionary = answers[i]
			var pts: int = POINTS.get(int(a.get("rarity", 1)), 10) if a.get("correct", false) else 0
			rows.append("(%d,%d,%d)" % [q["id"], i, pts])
	var sql := "-- Generated by tools/build_questions.gd from data/questions.json. Do not edit by hand.\n"
	sql += "-- Run in Supabase SQL Editor after schema.sql (safe to re-run after changing questions).\n"
	sql += "begin;\ndelete from public.question_answers;\n"
	sql += "insert into public.question_answers (question_id, answer_index, points) values\n"
	sql += ",\n".join(rows) + ";\n"
	sql += "delete from public.question_meta;\n"
	sql += "insert into public.question_meta (question_id, difficulty) values\n"
	sql += ",\n".join(meta) + ";\ncommit;\n"
	var f := FileAccess.open(OUT_SQL, FileAccess.WRITE)
	f.store_string(sql)
	f.close()
