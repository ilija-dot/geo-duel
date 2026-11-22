class_name Main
extends Control
## Root of the game. Shows one screen at a time and switches between them.

var current: Screen


func _ready() -> void:
	refresh_theme()
	show_menu()


## Re-applies colors after the player equips a new theme.
func refresh_theme() -> void:
	theme = UI.build_theme()


func show_menu() -> void:
	_swap(MenuScreen.new())


func show_challenge() -> void:
	_swap(ChallengeScreen.new())


func show_duels() -> void:
	_swap(DuelsScreen.new())


func show_shop() -> void:
	_swap(ShopScreen.new())


## Practice: 10 questions this phone has seen least.
func show_practice() -> void:
	var screen := QuizScreen.new()
	screen.question_ids = QuestionBank.pick_practice(Save.data["practice_seen"])
	screen.seed_key = str(randi())
	_swap(screen)


## Play your turn of an online duel.
func show_duel_quiz(duel: Dictionary) -> void:
	var screen := QuizScreen.new()
	screen.duel = duel
	screen.question_ids = duel["question_ids"]
	screen.seed_key = str(duel["id"])
	_swap(screen)


## result = {"duel": {...}} for a duel, or {"question_ids", "picks"} for practice. Optional "coins".
func show_result(result: Dictionary) -> void:
	var screen := ResultScreen.new()
	screen.result = result
	_swap(screen)


func _swap(screen: Screen) -> void:
	screen.main = self
	if current:
		current.queue_free()
	current = screen
	add_child(screen)


## Android back button returns to the menu.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not (current is MenuScreen):
		show_menu()
