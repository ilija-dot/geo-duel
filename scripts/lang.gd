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
	# Avatar
	"avatar": ["Аватар", "Avatar"],
	"part_skin": ["Кожа", "Skin"],
	"part_hair": ["Фризура", "Hair"],
	"part_hair_color": ["Боја на коса", "Hair color"],
	"part_eyes": ["Очи", "Eyes"],
	"part_mouth": ["Уста", "Mouth"],
	"part_acc": ["Додаток", "Extra"],
	"part_bg": ["Позадина", "Background"],
	"random": ["Случајно", "Random"],
	"save": ["Зачувај", "Save"],
	"saved": ["Зачувано!", "Saved!"],
	"buy_for": ["Купи за %d %s", "Buy for %d %s"],
	"locked_acc": ["Прво купи го овој додаток.", "Buy this extra first."],
	# Leaderboard
	"leaderboard": ["Ранг листа", "Leaderboard"],
	"this_week": ["Оваа недела", "This week"],
	"last_week": ["Минатата недела", "Last week"],
	"all_time": ["Сите времиња", "All time"],
	"champions": ["Шампиони на минатата недела", "Last week's champions"],
	"wins_n": ["%d победи", "%d wins"],
	"row_stats": ["%d победи · %d дуели", "%d wins · %d duels"],
	"your_rank": ["Твое место: #%d · %d победи", "Your rank: #%d · %d wins"],
	"not_ranked": ["Уште не си на листата. Победи во дуел!", "You're not on the board yet. Win a duel!"],
	"board_empty": ["Уште нема победници. Биди прв!", "No winners yet. Be the first!"],
	"board_note": ["Се рестартира секој понеделник. Против ист играч се бројат најмногу 3 победи неделно. Дуелите на нивоа од играчи не се бројат.", "Resets every Monday. At most 3 wins against the same player count per week. Duels on player levels don't count."],
	# Difficulty
	"difficulty": ["Тежина", "Difficulty"],
	"easy": ["Лесно", "Easy"],
	"medium": ["Средно", "Medium"],
	"hard": ["Тешко", "Hard"],
	"easy_desc": ["Полесни прашања, повеќе точни одговори", "Easier questions, more right answers"],
	"medium_desc": ["Полесни прашања, помалку точни одговори", "Easier questions, fewer right answers"],
	"hard_desc": ["Тешки прашања, само 2 точни одговори", "Hard questions, only 2 right answers"],
	# Player levels
	"levels": ["Нивоа од играчи", "Player levels"],
	"levels_note": ["Направи свој квиз и сподели го кодот со другарите.", "Make your own quiz and share its code with friends."],
	"create_level": ["Направи ниво", "Create a level"],
	"level_code_ph": ["Код на ниво (на пр. NVDNW8)", "Level code (e.g. NVDNW8)"],
	"play_level": ["Играј ниво", "Play level"],
	"my_levels": ["Мои нивоа", "My levels"],
	"no_levels": ["Уште немаш нивоа.", "You have no levels yet."],
	"level_info": ["%s\nКод: %s · %d играња", "%s\nCode: %s · %d plays"],
	"duel_btn": ["Дуел", "Duel"],
	"level_not_found": ["Нема ниво со тој код.", "No level with that code."],
	"level_label": ["Ниво: %s", "Level: %s"],
	"report": ["Пријави несоодветно ниво", "Report this level"],
	"reported": ["Ти благодариме. Нивото е пријавено.", "Thanks. The level has been reported."],
	"level_title_ph": ["Име на нивото", "Level name"],
	"question_ph": ["Прашање", "Question"],
	"answer_ph": ["Одговор %d", "Answer %d"],
	"state_wrong": ["Грешно", "Wrong"],
	"state_points": ["Точно %d", "Right %d"],
	"editor_q": ["Прашање %d / %d", "Question %d / %d"],
	"add_q": ["+ Прашање", "+ Question"],
	"del_q": ["Избриши", "Delete"],
	"save_level": ["Зачувај ниво", "Save level"],
	"level_saved": ["Зачувано! Код: %s (копиран)", "Saved! Code: %s (copied)"],
	"err_title": ["Дај му име на нивото.", "Give the level a name."],
	"err_count": ["Нивото треба 3 до 20 прашања.", "A level needs 3 to 20 questions."],
	"err_q": ["Прашање %d: напиши го прашањето.", "Question %d: write the question."],
	"err_answers": ["Прашање %d: треба 4 до 8 одговори.", "Question %d: needs 4 to 8 answers."],
	"err_mix": ["Прашање %d: треба барем еден точен и еден грешен одговор.", "Question %d: needs at least one right and one wrong answer."],
	"err_bad_words": ["Нивото има несоодветни зборови.", "The level contains words that aren't allowed."],
	"back": ["Назад", "Back"],
	"online_only": ["Ова бара интернет и онлајн игра.", "This needs the internet and online play."],
	# Help (F1)
	"help": ["Помош", "Help"],
	"help_title": ["Правила и упатство", "Rules & tutorial"],
	"help_key": ["Притисни F1 за да ја отвориш или затвориш помошта.", "Press F1 to open or close help."],
	"help_close": ["Затвори", "Close"],
	"help_how_t": ["Како се игра", "How to play"],
	"help_how": [
		"1. Секое прашање има неколку точни одговори, на пр. „Наведи река во Африка“.\n2. Се прикажуваат плочки. Некои се точни, некои се стапици.\n3. Избери ЕДНА плочка пред да истечат 20 секунди.\n4. Потоа се гледа колку поени носел секој точен одговор.\n5. Игра има 10 прашања.",
		"1. Each question has several right answers, e.g. \"Name a river in Africa\".\n2. You see a set of tiles. Some are right, some are traps.\n3. Pick ONE tile before the 20 seconds run out.\n4. Then you see how many points each right answer was worth.\n5. A game has 10 questions."],
	"help_score_t": ["Поени", "Scoring"],
	"help_score": [
		"Поретко точен одговор носи повеќе поени:\n• очигледен одговор = 10\n• познат = 25\n• од лекцијата = 50\n• редок = 100\nГрешен одговор или истечено време = 0. Сигурен одговор или ризик за 100?",
		"The rarer the right answer, the more points:\n• obvious answer = 10\n• well known = 25\n• from the lesson = 50\n• rare = 100\nA wrong answer or running out of time = 0. Play it safe, or gamble for 100?"],
	"help_diff_t": ["Тежина", "Difficulty"],
	"help_diff": [
		"• Лесно: полесни прашања, повеќе точни плочки (4-5 точни, 2 стапици).\n• Средно: полесни прашања, помалку точни (3 точни, 3 стапици).\n• Тешко: тешки прашања, само 2 точни плочки.",
		"• Easy: easier questions, more right tiles (4-5 right, 2 traps).\n• Medium: easier questions, fewer right tiles (3 right, 3 traps).\n• Hard: hard questions, only 2 right tiles."],
	"help_duel_t": ["Дуел со другар", "Duel a friend"],
	"help_duel": [
		"1. На менито е твојот ID (на пр. K7M2QX). Испрати му го на другар.\n2. Притисни „Предизвикај другар“, избери тежина и внеси го неговиот ID.\n3. Одиграј ги своите 10 прашања.\n4. Другарот ги игра истите прашања кога ќе има време.\n5. Победува тој со повеќе поени. Во „Мои дуели“ гледаш чиј е редот.\nНикогаш не добиваш прашање што веќе си го имал против истиот другар.",
		"1. Your ID is on the menu (e.g. K7M2QX). Send it to a friend.\n2. Tap \"Challenge a friend\", choose a difficulty and type their ID.\n3. Play your 10 questions.\n4. Your friend plays the same questions when they have time.\n5. Most points wins. \"My duels\" shows whose turn it is.\nYou never get a question you've already had against the same friend."],
	"help_board_t": ["Ранг листа", "Leaderboard"],
	"help_board": [
		"Секоја победа во дуел те качува на светската ранг листа. Неделната листа се рестартира секој понеделник, а шампионите од минатата недела остануваат на подиумот. Против ист играч се бројат најмногу 3 победи неделно.",
		"Every duel you win moves you up the global leaderboard. The weekly board resets every Monday, and last week's champions stay on the podium. At most 3 wins against the same player count each week."],
	"help_levels_t": ["Нивоа од играчи", "Player levels"],
	"help_levels": [
		"Направи свој квиз: 3 до 20 прашања, секое со 4 до 8 одговори. Кај секој одговор избери „Грешно“ или колку поени носи. Ќе добиеш код за споделување. Играј го сам или предизвикај другар. Ако видиш несоодветно ниво, пријави го.",
		"Make your own quiz: 3 to 20 questions, each with 4 to 8 answers. For each answer choose \"Wrong\" or how many points it's worth. You get a code to share. Play it alone or challenge a friend. If you see an inappropriate level, report it."],
	"help_shop_t": ["Аватар и продавница", "Avatar & shop"],
	"help_shop": [
		"Направи свој аватар во „Аватар“. Монетите ги добиваш со играње, а дијаманти за секоја победа. Со нив купуваш теми и додатоци за аватарот. Тие само го менуваат изгледот и не даваат предност.",
		"Build your avatar under \"Avatar\". You earn coins by playing and gems for every win. Use them for color themes and avatar extras. They only change how things look and never give an advantage."],
}

var lang := "en"


func _ready() -> void:
	lang = str(Save.data.get("lang", "en"))


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
