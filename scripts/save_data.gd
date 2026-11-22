extends Node
## Autoload "Save": everything the game remembers on this phone, in a JSON file.
## Online data (your ID, duels) lives in Supabase; see scripts/net.gd.

var path := "user://save.json"  # tests point this somewhere else
const STARTER_THEMES := ["classic", "mint", "sunset"]
const WIN_GEMS := 5

var data: Dictionary = {}


func _ready() -> void:
	data = _defaults()
	load_game()


func _defaults() -> Dictionary:
	return {
		"nickname": "",
		"lang": "en",  # the game starts in English
		"player_id": "",  # your unique ID, given by the server
		"auth": {},  # login tokens for the server (anonymous account, no email)
		"coins": 0,
		"gems": 0,
		"owned": STARTER_THEMES.duplicate(),
		"equipped": "classic",
		"friends": [],  # [{"id": "K7M2QX", "name": "Ana"}]
		"practice_seen": {},  # "question id" -> times seen in practice
		"claimed_wins": [],  # duel ids we already paid win gems for
		"avatar": {},  # part numbers, see AvatarParts
		"avatar_synced": true,  # false = not yet saved on the server
		"difficulty": "medium",  # last chosen difficulty
		"email": "",  # set when logged in with an email account (stays on this device only)
	}


func load_game() -> void:
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		for key: String in parsed:
			if data.has(key):
				data[key] = parsed[key]


func save_game() -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))


# --- Currency & shop ---------------------------------------------------------

func coins() -> int:
	return int(data["coins"])


func gems() -> int:
	return int(data["gems"])


func add_coins(amount: int) -> void:
	data["coins"] = coins() + amount
	save_game()


## Adds gems from a win or a real-money purchase (only after the store confirms payment).
func add_gems(amount: int) -> void:
	data["gems"] = gems() + amount
	save_game()


func owns(theme_id: String) -> bool:
	return theme_id in data["owned"]


## Spends coins or gems on a theme. Returns false if the player can't afford it.
func buy(item: Dictionary) -> bool:
	var currency: String = item["currency"]
	var price: int = item["price"]
	if owns(item["id"]) or int(data[currency]) < price:
		return false
	data[currency] = int(data[currency]) - price
	data["owned"].append(item["id"])
	save_game()
	return true


func equip(theme_id: String) -> void:
	if owns(theme_id):
		data["equipped"] = theme_id
		save_game()


# --- Player, friends, practice ------------------------------------------------

## Nicknames: letters (Latin or Cyrillic), numbers and _ only, max 16 characters.
static func clean_name(text: String) -> String:
	var regex := RegEx.create_from_string("[^\\p{L}\\p{N}_]")
	return regex.sub(text, "", true).left(16)


func nickname() -> String:
	var n := str(data["nickname"])
	return n if n != "" else "Player"


func set_nickname(text: String) -> void:
	data["nickname"] = clean_name(text)
	save_game()


func avatar() -> Dictionary:
	return AvatarParts.normalize(data["avatar"])


func set_avatar(av: Dictionary) -> void:
	data["avatar"] = AvatarParts.normalize(av)
	data["avatar_synced"] = false
	save_game()


func add_friend(id: String, friend_name: String) -> void:
	var kept := []
	for f: Dictionary in data["friends"]:
		if f["id"] != id:
			kept.append(f)
	kept.push_front({"id": id, "name": friend_name})
	data["friends"] = kept.slice(0, 30)
	save_game()


func mark_practice_seen(question_ids: Array) -> void:
	var seen: Dictionary = data["practice_seen"]
	for id in question_ids:
		seen[str(id)] = int(seen.get(str(id), 0)) + 1
	save_game()


## Gives win gems once per won duel. Returns how many gems were given (0 if already claimed).
func claim_win(duel_id: String) -> int:
	if duel_id in data["claimed_wins"]:
		return 0
	data["claimed_wins"].append(duel_id)
	data["gems"] = gems() + WIN_GEMS
	save_game()
	return WIN_GEMS
