extends Node
## Plays a real duel between two new test players on the live Supabase server,
## using the game's own Net code. Run:
##   godot --headless --path . res://tests/online_test.tscn
## Prints the two test player IDs at the end so they can be deleted afterwards.

var failures := 0


func check(cond: bool, what: String) -> void:
	print("  ok   " if cond else "  FAIL ", what)
	if not cond:
		failures += 1


## Each "phone" is its own login + player ID. We swap them in and out of Save.
func as_player(state: Dictionary) -> void:
	Save.data["auth"] = state.get("auth", {})
	Save.data["player_id"] = state.get("player_id", "")
	Save.data["nickname"] = state.get("nickname", "")


func remember(state: Dictionary) -> void:
	state["auth"] = Save.data["auth"]
	state["player_id"] = Save.data["player_id"]


func _ready() -> void:
	Save.path = "user://online_test_save.json"
	Save.data = Save._defaults()
	var ana := {"nickname": "TestAna"}
	var leo := {"nickname": "TestLeo"}

	print("Sign up + register two players")
	as_player(ana)
	var r: Dictionary = await Net.register()
	check(r["ok"] and str(Save.data["player_id"]).length() == 6, "Ana gets a 6-character ID (%s)" % Save.data["player_id"])
	remember(ana)
	as_player(leo)
	r = await Net.register()
	check(r["ok"] and str(Save.data["player_id"]) != ana["player_id"], "Leo gets a different ID (%s)" % Save.data["player_id"])
	remember(leo)

	print("Find a friend by ID")
	r = await Net.find_player(ana["player_id"])
	check(r["ok"] and r["data"].get("nickname") == "TestAna", "Leo finds Ana by her ID")
	r = await Net.find_player("ZZZZZZ")
	check(r["ok"] and (r["data"] as Dictionary).is_empty(), "unknown ID -> not found")

	print("Leo challenges Ana and plays his turn")
	r = await Net.create_duel(ana["player_id"])
	check(r["ok"] and (r["data"]["question_ids"] as Array).size() == 10, "duel created with 10 questions")
	var duel: Dictionary = r["data"]
	var leo_picks := [0, 1, 2, 3, 4, 5, 6, 7, 0, 1]
	r = await Net.submit_picks(str(duel["id"]), leo_picks)
	var expected := QuestionBank.round_total(QuestionBank.round_for_duel(duel), leo_picks)
	check(r["ok"] and int(r["data"]["my_score"]) == expected, "server score matches the app's answer key (%d)" % expected)
	r = await Net.submit_picks(str(duel["id"]), leo_picks)
	check(not r["ok"] and str(r["error"]).contains("already played"), "can't submit twice")

	print("Ana sees the duel and plays")
	as_player(ana)
	r = await Net.my_duels()
	check(r["ok"] and (r["data"] as Array).size() == 1 and r["data"][0]["my_picks"] == null, "Ana sees 'your turn'")
	check(r["data"][0]["their_picks"] == null, "Leo's answers are hidden from Ana before she plays")
	var ana_picks := [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
	r = await Net.submit_picks(str(duel["id"]), ana_picks)
	check(r["ok"] and r["data"]["finished"] and int(r["data"]["their_score"]) == expected and int(r["data"]["my_score"]) == 0, "duel finished: Ana 0, Leo %d" % expected)

	print("Token refresh")
	Save.data["auth"]["expires_at"] = 0  # pretend the login expired
	r = await Net.my_duels()
	check(r["ok"], "expired login refreshes automatically")

	print("Avatar")
	r = await Net.set_avatar({"skin": 2, "hair": 4, "acc": 6})
	check(r["ok"], "Ana saves her avatar")
	r = await Net.set_avatar({"evil": "<script>"})
	check(not r["ok"], "bad avatar data is rejected")

	print("Leaderboard")
	r = await Net.leaderboard("week")
	var top: Array = r["data"]["rows"] if r["ok"] else []
	check(r["ok"] and top.size() >= 1 and top[0]["nickname"] == "TestLeo" and int(top[0]["wins"]) == 1, "Leo is #1 this week with 1 win")
	check(r["data"]["me"] is Dictionary and int(r["data"]["me"]["wins"]) == 0, "Ana sees her own rank")
	var ana_row: Array = top.filter(func(x: Dictionary) -> bool: return x["id"] == ana["player_id"])
	check(ana_row.size() == 1 and int(ana_row[0]["avatar"].get("hair", -1)) == 4, "leaderboard shows Ana's avatar")

	print("Player levels")
	var questions := [
		{"q": "River in Macedonia?", "answers": [{"t": "Vardar", "p": 10}, {"t": "Treska", "p": 50}, {"t": "Nile", "p": 0}, {"t": "Rhine", "p": 0}]},
		{"q": "Lake in Macedonia?", "answers": [{"t": "Ohrid", "p": 10}, {"t": "Prespa", "p": 25}, {"t": "Dojran", "p": 50}, {"t": "Erie", "p": 0}]},
		{"q": "Mountain in Macedonia?", "answers": [{"t": "Korab", "p": 25}, {"t": "Shar", "p": 10}, {"t": "Alps", "p": 0}, {"t": "Andes", "p": 0}]}]
	r = await Net.create_level("Test level", questions)
	check(r["ok"] and str(r["data"]).length() == 6, "Ana creates a level and gets a code")
	var code := str(r.get("data", ""))
	r = await Net.create_level("Rude level", [{"q": "shit", "answers": questions[0]["answers"]}, questions[1], questions[2]])
	check(not r["ok"] and str(r["error"]).contains("bad words"), "bad words are blocked")
	r = await Net.create_duel(leo["player_id"], "medium", code)
	check(r["ok"] and r["data"]["level"] is Dictionary and r["data"]["level"]["title"] == "Test level", "Ana challenges Leo on her level")
	r = await Net.submit_picks(str(r["data"]["id"]), [1, 2, 0])
	check(r["ok"] and int(r["data"]["my_score"]) == 125, "level duel scored by the server (125)")
	as_player(leo)
	r = await Net.get_level(code.to_lower())
	check(r["ok"] and r["data"]["creator_name"] == "TestAna", "Leo opens the level by code")
	r = await Net.report_level(code)
	check(r["ok"], "Leo can report the level")

	print("Hard duel")
	r = await Net.create_duel(ana["player_id"], "hard")
	check(r["ok"] and r["data"]["difficulty"] == "hard", "hard duel created")
	var hard_round := QuestionBank.round_for_duel(r["data"]) if r["ok"] else []
	var all_two := hard_round.size() == 10
	for q: Dictionary in hard_round:
		var right := 0
		for t: int in q["tiles"]:
			if int(q["answers"][t]["points"]) > 0:
				right += 1
		all_two = all_two and right == 2
	check(all_two, "every hard question shows exactly 2 right tiles")

	print("Wallet on the account")
	as_player(leo)
	Save.data["coins"] = 999999  # pretend someone edited their save file
	Save.data["gems"] = 0
	r = await Net.sync_wallet()
	check(r["ok"] and Save.coins() <= 2000 + 30, "old device coins imported once, capped (%d)" % Save.coins())
	var before := Save.coins()
	Save.data["coins"] = 5
	r = await Net.sync_wallet()
	check(r["ok"] and Save.coins() == before, "the server's balance wins over the device")
	r = await Net.buy_item("ocean")
	check(r["ok"] and "ocean" in Save.data["owned"] and Save.coins() == before - 100, "buying a theme is charged on the server")
	r = await Net.equip_theme("ocean")
	check(r["ok"] and Save.data["equipped"] == "ocean", "equipped theme saved on the account")
	r = await Net.buy_item("acc_crown")
	check(not r["ok"] and str(r["error"]).contains("not enough"), "can't buy the crown without gems")
	r = await Net.practice_reward([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	check(r["ok"] and int(r["data"]) >= 0 and int(r["data"]) <= 100, "practice coins paid by the server (%d)" % int(r.get("data", -1)))
	as_player(ana)
	Save.data["coins"] = 0
	r = await Net.sync_wallet()
	check(r["ok"] and Save.gems() >= 0, "Ana's wallet loads")

	print("Email accounts")
	var email := "geoduel.test.%d@gmail.com" % (randi() % 1000000000)
	as_player(ana)
	r = await Net.create_account(email, "secret-123")
	check(r["ok"] and Net.is_logged_in(), "Ana turns her guest into an email account (%s)" % r.get("error_code", "ok"))
	check(str(Save.data["player_id"]) == ana["player_id"], "...and keeps her player ID")
	as_player(leo)
	Save.data["email"] = ""
	r = await Net.create_account(email, "other-pass")
	check(not r["ok"] and AccountScreen.error_text(r) == L.t("err_email_taken"), "the same email can't be used twice")
	as_player({})  # a new device
	Save.data["email"] = ""
	r = await Net.log_in(email, "wrong-pass")
	check(not r["ok"] and AccountScreen.error_text(r) == L.t("err_wrong_login"), "wrong password is refused")
	r = await Net.log_in(email.to_upper(), "secret-123")
	check(r["ok"] and str(Save.data["player_id"]) == ana["player_id"] and Save.data["nickname"] == "TestAna", "logging in on a new device brings back Ana's player")
	check(int(Save.avatar()["hair"]) == 4, "...with her avatar")
	r = await Net.my_duels()
	check(r["ok"] and (r["data"] as Array).size() >= 2, "...and her duels")
	await Net.log_out()
	check(not Net.is_logged_in() and str(Save.data["player_id"]) == "", "log out clears this device")
	r = await Net.log_in(email, "secret-123")
	r = await Net.delete_account()
	check(r["ok"] and str(Save.data["player_id"]) == "", "Ana deletes her account")
	Save.data["auth"] = {}
	r = await Net.log_in(email, "secret-123")
	check(not r["ok"], "a deleted account can't log in any more")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path))
	print("TEST_PLAYERS %s %s" % [ana["player_id"], leo["player_id"]])
	print("\n%s (%d failures)" % ["ALL PASSED" if failures == 0 else "FAILED", failures])
	get_tree().quit(1 if failures else 0)
