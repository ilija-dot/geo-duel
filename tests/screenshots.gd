extends Node
## Saves PNGs of the main screens to the folder in the SHOT_DIR environment variable.
## Run (not headless): godot --path . --resolution 720x1280 res://tests/screenshots.tscn


func _ready() -> void:
	var out := OS.get_environment("SHOT_DIR")
	Save.path = "user://shot_save.json"
	Save.data = Save._defaults()
	Save.data["nickname"] = "Мила"
	Save.data["player_id"] = "K7M2QX"
	Save.data["coins"] = 120
	var main: Main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _shot(out, "1_menu_mk")

	main.show_practice()
	var quiz := main.current as QuizScreen
	quiz.reveal_seconds = 100.0
	await _shot(out, "2_quiz_mk")
	quiz._choose(quiz._order[0])
	await _shot(out, "3_reveal_mk")

	L.lang = "en"
	main.show_practice()
	await _shot(out, "4_quiz_en")

	var duel := {"id": "d3", "opponent_id": "BBBBBB", "opponent_name": "Ana", "question_ids": [1, 50, 120, 200, 260, 310, 333, 401, 450, 499],
		"my_picks": [0, 1, 2, 3, 4, 0, 1, 2, 3, 0], "my_score": 0, "their_done": true, "their_picks": [1, 1, 1, 5, 1, 1, 6, 1, 1, 1], "their_score": 0, "finished": true}
	main.show_result({"duel": duel, "coins": 18})
	await _shot(out, "5_result_en")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path))
	get_tree().quit()


func _shot(out: String, file_name: String) -> void:
	for i in 4:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(file_name + ".png"))
