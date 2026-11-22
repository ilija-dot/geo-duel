extends Node
## Autoload "L": all game text in Macedonian and English.
## Use L.t("key") for UI text, and L.pick({"mk": ..., "en": ...}) for question data.

const STRINGS := {
	"title": ["ГЕО ДУЕЛ", "GEO DUEL"],
	"tagline": ["Избери ретко точен одговор и победи ги другарите!", "Pick rare correct answers and beat your friends!"],
	"your_id": ["Твој ID: %s", "Your ID: %s"],
	"copy": ["Копирај", "Copy"],
	"copied": ["Копирано!", "Copied!"],
	"nick_ph": ["Прекар (не вистинско име)", "Nickname (not your real name)"],
	"challenge": ["Предизвикај другар", "Challenge a friend"],
	"matches": ["Мои дуели", "My duels"],
	"matches_n": ["Мои дуели (%d на ред)", "My duels (%d your turn)"],
	"practice": ["Вежбај сам", "Practice alone"],
	"shop": ["Продавница", "Shop"],
	"menu": ["Мени", "Menu"],
	"other_lang": ["English", "Македонски"],
	"offline": ["Онлајн играта уште не е поставена. Засега можеш да вежбаш.", "Online play isn't set up yet. You can practice for now."],
	"connecting": ["Се поврзувам...", "Connecting..."],
	"net_error": ["Нема врска. Обиди се повторно.", "No connection. Try again."],
	"wallet": ["Монети %d     Дијаманти %d", "Coins %d     Gems %d"],
	"friend_id_ph": ["ID на другар (на пр. K7M2QX)", "Friend's ID (e.g. K7M2QX)"],
	"paste": ["Залепи", "Paste"],
	"find": ["Најди", "Find"],
	"start_duel": ["Започни дуел со %s", "Start a duel with %s"],
	"not_found": ["Нема играч со тој ID.", "No player with that ID."],
	"own_id": ["Тоа е твојот ID :)", "That's your own ID :)"],
	"friends": ["Другари", "Friends"],
	"no_friends": ["Додај другар со неговиот ID.", "Add a friend with their ID."],
	"no_matches": ["Уште немаш дуели. Предизвикај другар!", "No duels yet. Challenge a friend!"],
	"your_turn": ["Твој ред", "Your turn"],
	"waiting_for": ["Чекаме %s", "Waiting for %s"],
	"won_score": ["Победи %d:%d", "You won %d:%d"],
	"lost_score": ["Загуби %d:%d", "You lost %d:%d"],
	"draw_score": ["Нерешено %d:%d", "Draw %d:%d"],
	"play": ["Играј", "Play"],
	"view": ["Види", "View"],
	"refresh": ["Освежи", "Refresh"],
	"question_n": ["Прашање %d / %d", "Question %d / %d"],
	"score": ["%d поени", "%d points"],
	"time_up": ["Времето истече! 0 поени", "Time's up! 0 points"],
	"wrong": ["Погрешно! 0 поени", "Wrong! 0 points"],
	"right": ["Точно! +%d", "Correct! +%d"],
	"rarity_hint": ["Поретко точен одговор = повеќе поени", "Rarer correct answer = more points"],
	"sending": ["Се испраќа...", "Sending..."],
	"retry": ["Обиди се повторно", "Try again"],
	"quit": ["Излези", "Quit"],
	"you": ["Ти", "You"],
	"practice_title": ["Вежба", "Practice"],
	"duel_with": ["Дуел со %s", "Duel with %s"],
	"you_won": ["Победи!", "You won!"],
	"you_lost": ["Загуби!", "You lost!"],
	"draw": ["Нерешено!", "It's a draw!"],
	"waiting_long": ["%s уште не играл. Резултатот ќе го видиш кога ќе заврши.", "%s hasn't played yet. You'll see the result when they finish."],
	"plus_coins": ["+%d монети", "+%d coins"],
	"plus_gems": ["+%d дијаманти за победата!", "+%d gems for the win!"],
	"practice_again": ["Вежбај пак", "Practice again"],
	"shop_note": ["Темите ги менуваат само боите. Не даваат предност.", "Themes only change colors. They give no advantage."],
	"not_enough": ["Немаш доволно %s. Играј дуели за да заработиш!", "Not enough %s yet. Play duels to earn more!"],
	"equipped": ["Ставено", "Equipped"],
	"equip": ["Стави", "Equip"],
	"price": ["%d %s", "%d %s"],
	"get_gems": ["Купи дијаманти", "Get gems"],
	"gems_soon": ["Пакетите дијаманти доаѓаат наскоро. Засега добиваш 5 за секоја победа!", "Gem packs are coming soon. For now you get 5 for every win!"],
	"coins_word": ["монети", "coins"],
	"gems_word": ["дијаманти", "gems"],
	"err_generic": ["Нешто тргна наопаку: %s", "Something went wrong: %s"],
}

var lang := "mk"


func _ready() -> void:
	lang = str(Save.data.get("lang", "mk"))


func t(key: String) -> String:
	var pair: Array = STRINGS.get(key, [key, key])
	return pair[0] if lang == "mk" else pair[1]


## Picks the right language from question data like {"mk": "Нил", "en": "Nile"}.
func pick(texts: Dictionary) -> String:
	return str(texts.get(lang, texts.get("mk", "")))


func toggle() -> void:
	lang = "en" if lang == "mk" else "mk"
	Save.data["lang"] = lang
	Save.save_game()
