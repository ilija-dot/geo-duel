class_name SelfTest
extends Node
## Plays a whole duel between two new test players through the real screens, against the
## live server, and prints "SELFTEST ..." lines (browser console / terminal).
## Web: open the game with ?selftest=1   Desktop: godot --path . -- --selftest

var main: Main
var failures := 0


func check(cond: bool, what: String) -> void:
	print("SELFTEST %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		failures += 1


func _wait_for(cond: Callable, seconds := 15.0) -> bool:
	var t := 0.0
	while t < seconds:
		if cond.call():
			return true
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	return false


func run() -> void:
	print("SELFTEST start (web=%s)" % OS.has_feature("web"))
	Save.path = "user://selftest_save.json"
	Save.data = Save._defaults()

	# Player 2 (Leo) registers first, so Ana can challenge him.
	Save.data["nickname"] = "TestLeo"
	var r := await Net.register()
	check(r["ok"], "Leo registers (%s)" % r.get("error", "ok"))
	var leo := {"auth": Save.data["auth"].duplicate(), "id": Save.data["player_id"]}

	Save.data = Save._defaults()
	Save.data["nickname"] = "TestAna"
	r = await Net.register()
	check(r["ok"], "Ana registers (%s)" % r.get("error", "ok"))
	var ana := {"id": Save.data["player_id"]}

	# Ana: Challenge screen -> find Leo -> start duel
	main.show_challenge({})
	await get_tree().process_frame
	var ch := main.current as ChallengeScreen
	ch._input.text = str(leo["id"])
	ch._find()
	check(await _wait_for(func() -> bool: return ch._start.visible), "Ana finds Leo by ID (%s)" % ch._status.text)
	ch._start.pressed.emit()
	var started := await _wait_for(func() -> bool: return main.current is QuizScreen)
	check(started, "duel starts and the quiz opens (status: %s)" % (ch._status.text if is_instance_valid(ch) else "-"))
	if not started:
		return _finish()

	# Ana plays 10 questions by tapping the first tile each time.
	var played := await _play_quiz("Ana")
	check(played, "Ana answers all 10 questions")
	check(await _wait_for(func() -> bool: return main.current is ResultScreen, 20.0), "Ana sees her result screen")

	# Leo opens My duels and plays his turn.
	Save.data = Save._defaults()
	Save.data["auth"] = leo["auth"]
	Save.data["player_id"] = leo["id"]
	Save.data["nickname"] = "TestLeo"
	main.show_duels()
	var ds := main.current as DuelsScreen
	check(await _wait_for(func() -> bool: return ds._list.get_child_count() > 0 and ds._status.text == ""), "Leo's duel list loads (%s)" % ds._status.text)
	var play_button: Button = null
	for child in ds._list.get_children():
		if child is HBoxContainer:
			for b in child.get_children():
				if b is Button and b.text == L.t("play"):
					play_button = b
	check(play_button != null, "Leo sees 'Play' (his turn)")
	if play_button == null:
		return _finish()
	play_button.pressed.emit()
	check(await _wait_for(func() -> bool: return main.current is QuizScreen), "Leo's quiz opens")
	check(await _play_quiz("Leo"), "Leo answers all 10 questions")
	check(await _wait_for(func() -> bool: return main.current is ResultScreen, 20.0), "Leo sees the final result")
	if main.current is ResultScreen:
		var res: Dictionary = (main.current as ResultScreen).result
		var duel: Dictionary = res.get("duel", {})
		check(duel.get("finished", false) and duel.get("their_done", false), "duel is finished with both scores (Leo %s : Ana %s)" % [duel.get("my_score"), duel.get("their_score")])
	print("SELFTEST players %s %s" % [ana["id"], leo["id"]])
	_finish()


func _play_quiz(who: String) -> bool:
	for i in 10:
		if not await _wait_for(func() -> bool: return main.current is QuizScreen and (main.current as QuizScreen)._answering):
			print("SELFTEST %s stuck before question %d" % [who, i + 1])
			return false
		var quiz := main.current as QuizScreen
		quiz.reveal_seconds = 0.2
		quiz._tiles[i % quiz._tiles.size()].pressed.emit()
		await get_tree().process_frame
	return true


func _finish() -> void:
	print("SELFTEST %s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path))
