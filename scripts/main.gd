class_name Main
extends Control
## Root of the game. Shows one screen at a time and switches between them.

var current: Screen
var help: HelpOverlay


func _ready() -> void:
	# Main keeps listening for F1 while the game is paused; screens pause normally.
	process_mode = Node.PROCESS_MODE_ALWAYS
	refresh_theme()
	show_menu()


## Opens (or closes) the rules & tutorial on top of the current screen. Bound to F1.
func show_help() -> void:
	if is_instance_valid(help) and not help.is_queued_for_deletion():
		help.close_help()
		return
	help = HelpOverlay.new()
	add_child(help)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		get_viewport().set_input_as_handled()
		show_help()


## Re-applies colors after the player equips a new theme.
func refresh_theme() -> void:
	theme = UI.build_theme()


func show_menu() -> void:
	_swap(MenuScreen.new())


## Challenge a friend. Pass a level to duel on a player-made level instead of built-in questions.
func show_challenge(level := {}) -> void:
	var screen := ChallengeScreen.new()
	screen.level = level
	_swap(screen)


func show_duels() -> void:
	_swap(DuelsScreen.new())


func show_shop() -> void:
	_swap(ShopScreen.new())


func show_avatar() -> void:
	_swap(AvatarScreen.new())


func show_leaderboard() -> void:
	_swap(LeaderboardScreen.new())


func show_levels() -> void:
	_swap(LevelsScreen.new())


func show_level_editor() -> void:
	_swap(LevelEditorScreen.new())


## Pick a difficulty (or a level code) for practice.
func show_practice_menu() -> void:
	_swap(PracticeScreen.new())


## Practice: 10 questions of a difficulty that this phone has seen least.
func show_practice(difficulty: String) -> void:
	var ids := QuestionBank.pick_practice(Save.data["practice_seen"], difficulty)
	var screen := QuizScreen.new()
	screen.round = QuestionBank.round_from_ids(ids, difficulty, str(randi()))
	screen.title = "%s · %s" % [L.t("practice_title"), L.t(difficulty)]
	screen.practice = {"question_ids": ids, "difficulty": difficulty}
	_swap(screen)


## Practice a player-made level alone.
func show_level_practice(level: Dictionary) -> void:
	var screen := QuizScreen.new()
	screen.round = QuestionBank.round_from_level(level, str(randi()))
	screen.title = L.t("level_label") % level["title"]
	screen.practice = {"level": level}
	_swap(screen)


## Play your turn of an online duel.
func show_duel_quiz(duel: Dictionary) -> void:
	var screen := QuizScreen.new()
	screen.duel = duel
	screen.round = QuestionBank.round_for_duel(duel)
	screen.title = L.t("duel_with") % duel["opponent_name"]
	_swap(screen)


## result = {"duel": {...}} for a duel, or {"round", "picks", "practice"} for practice. Optional "coins".
func show_result(result: Dictionary) -> void:
	var screen := ResultScreen.new()
	screen.result = result
	_swap(screen)


func _swap(screen: Screen) -> void:
	screen.main = self
	screen.process_mode = Node.PROCESS_MODE_PAUSABLE
	if current:
		current.queue_free()
	current = screen
	add_child(screen)


## Android back button returns to the menu.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if is_instance_valid(help) and not help.is_queued_for_deletion():
		help.close_help()
	elif not (current is MenuScreen):
		show_menu()
