extends Node
## Automated checks. Run with:
##   godot --headless --path . res://tests/test_runner.tscn
## Uses a small made-up question set, so it works whatever is in data/questions.json.
## Never contacts the live server (online features use fake server data here;
## tests/online_test.tscn tests the real server).

var failures := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		print("  FAIL ", what)


func _sample_questions() -> Array:
	var list := []
	for i in 24:
		list.append({
			"id": i + 1, "difficulty": "easy" if i < 12 else "hard", "topic": {"mk": "Тема", "en": "Topic"}, "page": 10,
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


func _count_right(q: Dictionary) -> int:
	var n := 0
	for t: int in q["tiles"]:
		if int(q["answers"][t]["points"]) > 0:
			n += 1
	return n


func _ready() -> void:
	Net.enabled = false  # never contact the live server from these tests
	Save.path = "user://test_save.json"
	Save.data = Save._defaults()
	check(L.lang == "en" and Save.data["lang"] == "en", "game starts in English")
	var qpath := "user://test_questions.json"
	var f := FileAccess.open(qpath, FileAccess.WRITE)
	f.store_string(JSON.stringify(_sample_questions()))
	f.close()
	QuestionBank.path = qpath
	QuestionBank._all = []

	print("Question bank & difficulty")
	check(QuestionBank.count() == 24, "loads questions")
	check(QuestionBank.points(1, 0) == 10 and QuestionBank.points(1, 3) == 100, "rarity 1 = 10 pts, rarity 4 = 100 pts")
	check(QuestionBank.points(1, 4) == 0 and QuestionBank.points(1, -1) == 0, "wrong answer and no answer = 0")
	var easy: Dictionary = QuestionBank.round_from_ids([1], "easy", "s")[0]
	var medium: Dictionary = QuestionBank.round_from_ids([1], "medium", "s")[0]
	var hard: Dictionary = QuestionBank.round_from_ids([13], "hard", "s")[0]
	check(_count_right(easy) == 4 and easy["tiles"].size() == 6, "easy: all 4 right + 2 traps")
	check(_count_right(medium) == 3 and medium["tiles"].size() == 6, "medium: 3 right + 3 traps")
	check(_count_right(hard) == 2 and hard["tiles"].size() == 6, "hard: 2 right + all 4 traps")
	check(QuestionBank.tiles_for(3, "medium", "duel-abc") == QuestionBank.tiles_for(3, "medium", "duel-abc"), "same duel = same tiles for both players")
	var practice_easy := QuestionBank.pick_practice({}, "medium")
	var practice_hard := QuestionBank.pick_practice({}, "hard")
	check(practice_easy.all(func(id: int) -> bool: return id <= 12), "easy/medium practice uses the easy pool")
	check(practice_hard.all(func(id: int) -> bool: return id > 12), "hard practice uses the hard pool")
	var seen := {}
	for i in range(1, 11):
		seen[str(i)] = 1
	var unseen := QuestionBank.pick_practice(seen, "easy")
	check(11 in unseen and 12 in unseen, "practice prefers questions not seen yet")
	var level := {"id": "LVL123", "title": "My quiz", "questions": [
		{"q": "River in Macedonia?", "answers": [{"t": "Vardar", "p": 10}, {"t": "Treska", "p": 50}, {"t": "Nile", "p": 0}, {"t": "Rhine", "p": 0}]},
		{"q": "Lake?", "answers": [{"t": "Ohrid", "p": 10}, {"t": "Prespa", "p": 25}, {"t": "Dojran", "p": 50}, {"t": "Erie", "p": 0}]},
		{"q": "Mountain?", "answers": [{"t": "Korab", "p": 25}, {"t": "Shar", "p": 10}, {"t": "Alps", "p": 0}, {"t": "Andes", "p": 0}]}]}
	var lround := QuestionBank.round_from_level(level, "x")
	check(lround.size() == 3 and lround[0]["tiles"].size() == 4, "player level becomes a round with all its answers")
	check(QuestionBank.round_total(lround, [1, 2, 3]) == 100, "level points add up (50 + 50 + 0)")

	print("Language")
	var both_ok := true
	for key: String in L.STRINGS:
		var pair: Array = L.STRINGS[key]
		both_ok = both_ok and pair.size() == 2 and pair[0] != "" and pair[1] != ""
	check(both_ok, "every text has Macedonian and English")
	L.toggle()
	check(L.lang == "mk" and L.t("practice") == "Вежбај сам" and Save.data["lang"] == "mk", "switch to Macedonian and remember it")
	L.toggle()
	check(L.t("practice") == "Practice alone", "back to English")

	print("Save, avatar")
	check(Save.clean_name("Ана Б!<script>") == "АнаБscript", "nicknames keep Cyrillic, drop symbols")
	Save.add_friend("AAAAAA", "Ana")
	Save.add_friend("BBBBBB", "Leo")
	Save.add_friend("AAAAAA", "Ana2")
	check((Save.data["friends"] as Array).size() == 2 and Save.data["friends"][0]["name"] == "Ana2", "friends list: no duplicates, latest first")
	check(Save.claim_win("duel-1") == 5 and Save.claim_win("duel-1") == 0, "win gems paid once per duel")
	var odd := AvatarParts.normalize({"skin": 99, "hair": -3, "evil": "x"})
	check(odd["skin"] == AvatarParts.count("skin") - 1 and odd["hair"] == 0 and not odd.has("evil"), "avatar data is cleaned up")
	Save.set_avatar({"skin": 2, "hair": 3, "acc": 1})
	check(Save.avatar()["hair"] == 3 and not Save.data["avatar_synced"], "avatar saved locally, waiting to upload")
	var crown := AvatarParts.ACCESSORIES.size() - 1
	check(not AvatarParts.is_free(crown) and AvatarParts.is_free(1), "crown costs gems, glasses are free")

	print("Play a practice game (medium)")
	var main: Main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.show_practice("medium")
	var quiz := main.current as QuizScreen
	quiz.reveal_seconds = 0.05
	await get_tree().process_frame
	check(quiz._tiles.size() == 6, "medium shows 6 tiles")
	var coins_before := Save.coins()
	var expected := 0
	for i in 10:
		var q: Dictionary = quiz.round[i]
		if i == 9:
			quiz._time_left = 0.0  # let the last one time out
			await get_tree().process_frame
		else:
			var pick: int = q["tiles"][0]
			expected += QuestionBank.round_points(q, pick)
			quiz._choose(pick)
		for wait in 50:
			await get_tree().create_timer(0.02).timeout
			if not (main.current is QuizScreen) or quiz._answering:
				break
	check(main.current is ResultScreen, "result screen after 10 questions")
	var result: Dictionary = (main.current as ResultScreen).result
	check(QuestionBank.round_total(result["round"], result["picks"]) == expected, "score adds up (%d)" % expected)
	check(result["picks"][9] == -1, "timeout recorded as no answer")
	check(Save.coins() == coins_before + expected / 20, "practice pays score / 20 coins")

	print("Help (F1)")
	main.show_menu()
	await get_tree().process_frame
	var f1 := InputEventKey.new()
	f1.keycode = KEY_F1
	f1.pressed = true
	main._unhandled_input(f1)
	await get_tree().process_frame
	check(is_instance_valid(main.help) and get_tree().paused, "F1 opens help and pauses the game")
	main._unhandled_input(f1)
	await get_tree().process_frame
	check(not get_tree().paused and main.current is MenuScreen, "F1 again closes help and resumes")

	print("Duels (fake server data)")
	var ids := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
	var waiting := {"id": "d1", "opponent_id": "BBBBBB", "opponent_name": "Leo", "opponent_avatar": {"hair": 4}, "difficulty": "easy",
		"level": null, "question_ids": ids, "my_picks": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "my_score": 100,
		"their_done": false, "their_picks": null, "their_score": null, "finished": false}
	var my_turn := waiting.duplicate()
	my_turn.merge({"id": "d2", "my_picks": null, "my_score": null}, true)
	var won := waiting.duplicate()
	won.merge({"id": "d3", "their_done": true, "their_picks": [4, 4, 4, 4, 4, 4, 4, 4, 4, 0], "their_score": 10, "finished": true}, true)
	var level_duel := won.duplicate()
	level_duel.merge({"id": "d4", "level": level, "question_ids": [1, 2, 3], "my_picks": [1, 2, 0], "their_picks": [0, 0, 2]}, true)
	check(DuelsScreen.status_text(my_turn) == "Your turn", "status: your turn")
	check(DuelsScreen.status_text(waiting) == "Waiting for Leo", "status: waiting for friend")
	check(DuelsScreen.status_text(won) == "You won 100:10", "status: won with score")
	check(DuelsScreen.status_text(level_duel) == "You won 125:20", "level duel scored from the level")
	main.show_duels()
	await get_tree().process_frame
	(main.current as DuelsScreen).show_duels([my_turn, waiting, won, level_duel])
	await get_tree().process_frame
	check((main.current as DuelsScreen)._list.get_child_count() == 4, "duel list shows all duels")
	var gems_before := Save.gems()
	main.show_result({"duel": won, "coins": 10})
	await get_tree().process_frame
	check(Save.gems() == gems_before + 5, "won duel pays 5 gems")
	main.show_result({"duel": level_duel})
	await get_tree().process_frame
	check(Save.gems() == gems_before + 5, "level duels pay no gems")
	main.show_duel_quiz(my_turn)
	await get_tree().process_frame
	check((main.current as QuizScreen)._tiles.size() == 6, "easy duel shows 6 tiles")

	print("Leaderboard & levels (fake server data)")
	main.show_leaderboard()
	await get_tree().process_frame
	var board := main.current as LeaderboardScreen
	var rows := []
	for i in 6:
		rows.append({"rank": i + 1, "id": "P%05d" % i, "nickname": "Player%d" % i, "avatar": AvatarParts.random_avatar(), "wins": 10 - i, "played": 12, "points": 900})
	board.show_board({"rows": rows, "me": {"rank": 4, "wins": 7, "played": 12, "points": 800}})
	await get_tree().process_frame
	check(board._podium.get_child_count() == 3 and board._list.get_child_count() == 3, "top 3 on the podium, rest in the list")
	check(board._status.text == "Your rank: #4 · 7 wins", "shows your rank")
	main.show_level_editor()
	await get_tree().process_frame
	var editor := main.current as LevelEditorScreen
	check(editor.build_level().get("error") == L.t("err_title"), "editor: level needs a name")
	editor._title.text = "My quiz"
	for qi in 3:
		editor.questions[qi]["q"] = "Q%d" % qi
		for ai in 4:
			editor.questions[qi]["answers"][ai]["t"] = "A%d" % ai
	var built := editor.build_level()
	check(not built.has("error") and built["questions"].size() == 3 and built["questions"][0]["answers"].size() == 4, "editor: valid level drops empty answer boxes")
	editor.questions[1]["answers"][0]["p"] = 0
	check(editor.build_level().get("error") == L.t("err_mix") % 2, "editor: each question needs a right answer")

	print("Accounts & invite links")
	var q := Main.parse_query("?invite=K7M2QX&d=hard&x=a%20b")
	check(q.get("invite") == "K7M2QX" and q.get("d") == "hard" and q.get("x") == "a b", "invite link is read from the address")
	check(Main.parse_query("").is_empty(), "no invite in a normal address")
	Save.data["player_id"] = "K7M2QX"
	check(Net.invite_link("hard") == "https://ilija-dot.github.io/geo-duel/?invite=K7M2QX&d=hard", "invite link format")
	check(AccountScreen.check_form("ana@mail.com", "secret1") == "", "valid email + password accepted")
	check(AccountScreen.check_form("ana-at-mail", "secret1") == L.t("err_email"), "bad email rejected")
	check(AccountScreen.check_form("ana@mail.com", "123") == L.t("err_password"), "short password rejected")
	check(AccountScreen.error_text({"error_code": "invalid_credentials"}) == L.t("err_wrong_login"), "wrong login message")
	check(AccountScreen.error_text({"error_code": "email_exists"}) == L.t("err_email_taken"), "email taken message")
	check(not Net.is_logged_in(), "starts as a guest")

	print("Open every screen")
	for show in [main.show_menu, main.show_challenge.bind({}), main.show_challenge.bind(level), main.show_shop, main.show_avatar, main.show_practice_menu, main.show_levels, main.show_account, main.show_invite.bind({"id": "ABCDEF", "d": "easy"}), main.show_privacy]:
		show.call()
		await get_tree().process_frame
		check(main.current.box.get_child_count() > 0, "%s builds" % main.current.get_script().get_global_name())

	for p in [Save.path, qpath]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	print("\n%s (%d failures)" % ["ALL PASSED" if failures == 0 else "FAILED", failures])
	get_tree().quit(1 if failures else 0)
