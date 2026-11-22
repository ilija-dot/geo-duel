extends Node
## Saves PNGs of the main screens to the folder in the SHOT_DIR environment variable.
## Run (not headless): godot --path . --resolution 720x1280 res://tests/screenshots.tscn


func _ready() -> void:
	Net.enabled = false
	var out := OS.get_environment("SHOT_DIR")
	Save.path = "user://shot_save.json"
	Save.data = Save._defaults()
	Save.data["nickname"] = "Mila"
	Save.data["player_id"] = "K7M2QX"
	Save.data["coins"] = 320
	Save.data["avatar"] = {"skin": 1, "hair": 2, "hair_color": 4, "eyes": 1, "mouth": 0, "acc": 1, "bg": 3}
	var main: Main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _shot(out, "1_menu")

	main.show_avatar()
	await _shot(out, "2_avatar")

	main.show_leaderboard()
	var board := main.current as LeaderboardScreen
	var names := ["Ana", "Leo", "Mila", "Ivo", "Sara", "Marko", "Elena"]
	var rows := []
	for i in names.size():
		rows.append({"rank": i + 1, "id": "K7M2QX" if names[i] == "Mila" else "P%05d" % i, "nickname": names[i],
			"avatar": {"skin": i % 6, "hair": (i * 3) % 7, "hair_color": i % 8, "eyes": i % 5, "mouth": (i + 2) % 5, "acc": i % 7, "bg": i % 8},
			"wins": 14 - i * 2, "played": 18 - i, "points": 2000 - i * 150})
	await get_tree().process_frame
	board.show_board({"rows": rows, "me": {"rank": 3, "wins": 10, "played": 16, "points": 1700}})
	await _shot(out, "3_leaderboard")

	main.show_practice_menu()
	await _shot(out, "4_practice")

	main.show_practice("hard")
	(main.current as QuizScreen).reveal_seconds = 100.0
	await _shot(out, "5_quiz_hard")

	main.show_level_editor()
	var ed := main.current as LevelEditorScreen
	await get_tree().process_frame
	ed._title.text = "Macedonia quiz"
	ed.questions[0] = {"q": "Name a river in Macedonia", "answers": [{"t": "Vardar", "p": 10}, {"t": "Treska", "p": 50}, {"t": "Crna Reka", "p": 25}, {"t": "Nile", "p": 0}, {"t": "Danube", "p": 0}, {"t": "", "p": 0}, {"t": "", "p": 0}, {"t": "", "p": 0}]}
	ed._show()
	await _shot(out, "6_level_editor")

	main.show_menu()
	await get_tree().process_frame
	main.show_help()
	await _shot(out, "7_help")
	main.help.close_help()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path))
	get_tree().quit()


func _shot(out: String, file_name: String) -> void:
	for i in 4:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(file_name + ".png"))
