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
	var expected := QuestionBank.total(duel["question_ids"], leo_picks)
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

	DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path))
	print("TEST_PLAYERS %s %s" % [ana["player_id"], leo["player_id"]])
	print("\n%s (%d failures)" % ["ALL PASSED" if failures == 0 else "FAILED", failures])
	get_tree().quit(1 if failures else 0)
