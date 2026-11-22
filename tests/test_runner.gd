extends Node
## Automated checks. Run with:
##   godot --headless --path . res://tests/test_runner.tscn
## Uses a small made-up question set, so it works whatever is in data/questions.json.
## (Online features are tested with fake server data; the real server isn't contacted.)

var failures := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		print("  FAIL ", what)


func _sample_questions() -> Array:
	var list := []
	for i in 12:
		list.append({
			"id": i + 1, "topic": {"mk": "Тема", "en": "Topic"}, "page": 10,
			"q": {"mk": "Прашање %d" % (i + 1), "en": "Question %d" % (i + 1)},
			"answers": [
				{"mk": "Нил", "en": "Nile", "correct": true, "rarity": 1},
				{"mk": "Конго", "en": "Congo", "correct": true, "rarity": 2},
				{"mk": "Замбези", "en": "Zambezi", "correct": true, "rarity": 3},
				{"mk": "Оранж", "en": "Orange", "correct": true, "rarity": 4},
				{"mk": "Амазон", "en": "Amazon", "correct": false},
				{"mk": "Дунав", "en": "Danube", "correct": false},
				{"mk": "Мисисипи", "en": "Mississippi", "correct": false},
				{"mk": "Волга", "en": "Volga", "correct": false},
			],
		})
	return list


func _ready() -> void:
	Save.path = "user://test_save.json"
	Save.data = Save._defaults()
	var qpath := "user://test_questions.json"
	var f := FileAccess.open(qpath, FileAccess.WRITE)
	f.store_string(JSON.stringify(_sample_questions()))
	f.close()
	QuestionBank.path = qpath
	QuestionBank._all = []

	print("Question bank")
	check(QuestionBank.count() == 12, "loads questions")
	check(QuestionBank.points(1, 0) == 10 and QuestionBank.points(1, 3) == 100, "rarity 1 = 10 pts, rarity 4 = 100 pts")
	check(QuestionBank.points(1, 4) == 0 and QuestionBank.points(1, -1) == 0, "wrong answer and no answer = 0")
	check(QuestionBank.total([1, 2, 3], [1, 2, 5]) == 75, "total adds up (25 + 50 + 0)")
	var order := QuestionBank.tile_order(3, "duel-abc")
	var sorted := order.duplicate()
	sorted.sort()
	check(order == QuestionBank.tile_order(3, "duel-abc"), "same duel = same tile order for both players")
	check(sorted == [0, 1, 2, 3, 4, 5, 6, 7], "tile order shows all 8 answers once")
	var seen := {}
	for i in range(1, 11):
		seen[str(i)] = 1
	var practice := QuestionBank.pick_practice(seen)
	check(practice.size() == 10 and 11 in practice and 12 in practice, "practice prefers questions not seen yet")

	print("Language")
	var both_ok := true
	for key: String in L.STRINGS:
		var pair: Array = L.STRINGS[key]
		both_ok = both_ok and pair.size() == 2 and pair[0] != "" and pair[1] != ""
	check(both_ok, "every text has Macedonian and English")
	L.lang = "mk"
	check(L.t("practice") == "Вежбај сам" and L.pick({"mk": "Нил", "en": "Nile"}) == "Нил", "Macedonian text")
	L.toggle()
	check(L.lang == "en" and L.t("practice") == "Practice alone" and Save.data["lang"] == "en", "switch to English and remember it")
	L.toggle()

	print("Save")
	check(Save.clean_name("Ана Б!<script>") == "АнаБscript", "nicknames keep Cyrillic, drop symbols")
	Save.add_friend("AAAAAA", "Ana")
	Save.add_friend("BBBBBB", "Leo")
	Save.add_friend("AAAAAA", "Ana2")
	check((Save.data["friends"] as Array).size() == 2 and Save.data["friends"][0]["name"] == "Ana2", "friends list: no duplicates, latest first")
	check(Save.claim_win("duel-1") == 5 and Save.claim_win("duel-1") == 0 and Save.gems() == 5, "win gems paid once per duel")
	Save.data["coins"] = 50
	check(not Save.buy(ThemeCatalog.get_item("ocean")), "can't buy without enough coins")
	Save.data["coins"] = 150
	check(Save.buy(ThemeCatalog.get_item("ocean")) and Save.coins() == 50, "buying spends coins")
	Save.load_game()
	check(Save.owns("ocean"), "purchase survives save + load")

	print("Online (not configured)")
	var res: Dictionary = await Net.create_duel("AAAAAA")
	check(not Net.is_configured() and not res["ok"] and res["error"] == "offline", "without Supabase settings, online calls fail safely")

	print("Play a practice game")
	var main: Main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.show_practice()
	var quiz := main.current as QuizScreen
	quiz.reveal_seconds = 0.05
	await get_tree().process_frame
	check(quiz._tiles.size() == 8, "8 answer tiles shown")
	var coins_before := Save.coins()
	for i in 10:
		if i == 9:
			quiz._time_left = 0.0  # let the last one time out
			await get_tree().process_frame
		else:
			quiz._choose(3 if i < 5 else 4)  # 5x rare correct (100), 4x wrong
		await get_tree().create_timer(0.15).timeout
	check(main.current is ResultScreen, "result screen after 10 questions")
	var result: Dictionary = (main.current as ResultScreen).result
	check(QuestionBank.total(result["question_ids"], result["picks"]) == 500, "score = 5 x 100 (wrong and timeout = 0)")
	check(result["picks"][9] == -1, "timeout recorded as no answer")
	check(Save.coins() == coins_before + 25, "practice pays score / 20 coins")
	check((Save.data["practice_seen"] as Dictionary).size() == 10, "practice remembers questions seen")

	print("Duels (fake server data)")
	var waiting := {"id": "d1", "opponent_id": "BBBBBB", "opponent_name": "Leo", "question_ids": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
		"my_picks": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "my_score": 100, "their_done": false, "their_picks": null, "their_score": null, "finished": false}
	var my_turn := waiting.duplicate()
	my_turn.merge({"id": "d2", "my_picks": null, "my_score": null}, true)
	var won := waiting.duplicate()
	won.merge({"id": "d3", "their_done": true, "their_picks": [4, 4, 4, 4, 4, 4, 4, 4, 4, 0], "their_score": 10, "finished": true}, true)
	L.lang = "en"
	check(DuelsScreen.status_text(my_turn) == "Your turn", "status: your turn")
	check(DuelsScreen.status_text(waiting) == "Waiting for Leo", "status: waiting for friend")
	check(DuelsScreen.status_text(won) == "You won 100:10", "status: won with score")
	main.show_duels()
	await get_tree().process_frame
	(main.current as DuelsScreen).show_duels([my_turn, waiting, won])
	await get_tree().process_frame
	check((main.current as DuelsScreen)._list.get_child_count() == 3, "duel list shows all duels")
	var gems_before := Save.gems()
	main.show_result({"duel": won, "coins": 10})
	await get_tree().process_frame
	check(Save.gems() == gems_before + 5, "viewing a won duel pays 5 gems")
	main.show_result({"duel": won})
	await get_tree().process_frame
	check(Save.gems() == gems_before + 5, "...only once")
	main.show_result({"duel": waiting})
	await get_tree().process_frame
	check(main.current is ResultScreen, "result while friend hasn't played")
	main.show_duel_quiz(my_turn)
	await get_tree().process_frame
	check((main.current as QuizScreen).question_ids == my_turn["question_ids"], "duel uses the server's questions")

	print("Open every screen")
	for show in [main.show_menu, main.show_challenge, main.show_shop]:
		show.call()
		await get_tree().process_frame
		check(main.current.box.get_child_count() > 0, "%s builds" % main.current.get_script().get_global_name())

	for p in [Save.path, qpath]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	print("\n%s (%d failures)" % ["ALL PASSED" if failures == 0 else "FAILED", failures])
	get_tree().quit(1 if failures else 0)
