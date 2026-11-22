extends Node
## Autoload "Net": talks to Supabase (the online database) for player IDs and duels.
##
## Each phone gets an anonymous account automatically: no email, no password.
## Every function returns {"ok": true, "data": ...} or {"ok": false, "error": "..."}.
## Use them with await, e.g.:  var res := await Net.create_duel("K7M2QX")


## Where the web version of the game lives (used for invite links).
const GAME_URL := "https://ilija-dot.github.io/geo-duel/"

## Offline tests set this to false so they never touch the live server.
var enabled := true


func is_configured() -> bool:
	return enabled and SupabaseConfig.URL != "" and SupabaseConfig.ANON_KEY != ""


# --- Player -------------------------------------------------------------------

## Makes sure this phone has an account and a player ID. Also updates the nickname.
func register() -> Dictionary:
	var res := await _rpc("register_player", {"nick": Save.nickname()})
	if res["ok"]:
		Save.data["player_id"] = str(res["data"])
		Save.save_game()
	return res


## Looks up a friend's nickname by their ID. data = {"id", "nickname"} or {} if not found.
func find_player(player_id: String) -> Dictionary:
	var res := await _call(HTTPClient.METHOD_GET,
		"/rest/v1/players?select=id,nickname&id=eq.%s" % player_id.uri_encode())
	if res["ok"]:
		var rows: Array = res["data"] if res["data"] is Array else []
		res["data"] = rows[0] if rows.size() > 0 else {}
	return res


# --- Duels --------------------------------------------------------------------
# A duel (as returned by the server) looks like:
# {"id", "opponent_id", "opponent_name", "question_ids": [10 ids], "my_picks", "my_score",
#  "their_picks", "their_score", "their_done", "finished", "created_at"}
# their_picks/their_score stay hidden until you've played.

## Starts a duel. Built-in questions: the server picks 10 from the difficulty's pool that
## neither player has seen before. With level_code: the duel uses that player-made level.
func create_duel(opponent_id: String, difficulty := "medium", level_code := "") -> Dictionary:
	var params := {"opponent": opponent_id, "difficulty": difficulty}
	if level_code != "":
		params["level"] = level_code
	return await _rpc("create_match", params)


func my_duels() -> Dictionary:
	var res := await _rpc("my_matches", {})
	if res["ok"] and not (res["data"] is Array):
		res["data"] = []
	return res


## Sends your answers (answer index per question, -1 = no answer). The server works out the score.
func submit_picks(duel_id: String, picks: Array) -> Dictionary:
	return await _rpc("submit_picks", {"match_id": duel_id, "picks": picks})


# --- Avatar & leaderboard -----------------------------------------------------------

func set_avatar(avatar: Dictionary) -> Dictionary:
	return await _rpc("set_avatar", {"av": avatar})


## period: "week", "last_week" or "all". data = {"rows": [...top 50...], "me": {...} or null}
func leaderboard(period: String) -> Dictionary:
	return await _rpc("leaderboard", {"period": period})


# --- Player-made levels ---------------------------------------------------------------
# A level: {"id": "NVDNW8", "title", "questions": [{"q": "...", "answers": [{"t": "...", "p": 0|10|25|50|100}]}]}

## Saves a new level. data = its share code.
func create_level(title: String, questions: Array) -> Dictionary:
	return await _rpc("create_level", {"title": title, "questions": questions})


func get_level(code: String) -> Dictionary:
	return await _rpc("get_level", {"code": code})


func my_levels() -> Dictionary:
	var res := await _rpc("my_levels", {})
	if res["ok"] and not (res["data"] is Array):
		res["data"] = []
	return res


func report_level(code: String) -> Dictionary:
	return await _rpc("report_level", {"code": code})


# --- Wallet (coins, gems, purchases, equipped theme) -------------------------------------
# The server owns the wallet; Save keeps a copy so screens can show it instantly.
# Every wallet call returns {"ok", "data": wallet} and updates that copy.

## Copies a wallet from the server into Save. Returns true if the equipped theme changed.
func apply_wallet(w: Variant) -> bool:
	if not (w is Dictionary):
		return false
	var old_theme := str(Save.data["equipped"])
	Save.data["coins"] = int(w.get("coins", 0))
	Save.data["gems"] = int(w.get("gems", 0))
	Save.data["owned"] = Array(w.get("owned", Save.STARTER_THEMES))
	Save.data["equipped"] = str(w.get("equipped", "classic"))
	Save.save_game()
	return old_theme != str(Save.data["equipped"])


## Gets the account's wallet. The first time, coins saved on this device are moved onto the account.
func sync_wallet() -> Dictionary:
	var res := await _rpc("my_wallet", {})
	if res["ok"] and res["data"] is Dictionary and not res["data"].get("imported", true):
		res = await _rpc("import_wallet", {"c": Save.coins(), "g": Save.gems(), "own": Save.data["owned"]})
	if res["ok"]:
		res["theme_changed"] = apply_wallet(res["data"])
	return res


func buy_item(item_id: String) -> Dictionary:
	var res := await _rpc("buy_item", {"item": item_id})
	if res["ok"]:
		apply_wallet(res["data"])
	return res


func equip_theme(theme_id: String) -> Dictionary:
	var res := await _rpc("equip_theme", {"theme": theme_id})
	if res["ok"]:
		apply_wallet(res["data"])
	return res


## Asks the server to pay practice coins (score / 20, max 100 a day). data = coins paid.
func practice_reward(question_ids: Array, picks: Array) -> Dictionary:
	var res := await _rpc("practice_reward", {"question_ids": question_ids, "picks": picks})
	if res["ok"]:
		apply_wallet(res["data"]["wallet"])
		res["data"] = int(res["data"]["coins"])
	return res


## After logging out or deleting, this device starts again with an empty guest wallet.
func _reset_local_wallet() -> void:
	Save.data["coins"] = 0
	Save.data["gems"] = 0
	Save.data["owned"] = Save.STARTER_THEMES.duplicate()
	Save.data["equipped"] = "classic"
	Save.data["claimed_wins"] = []


# --- Email accounts -------------------------------------------------------------------
# Every device starts as a guest (anonymous account). create_account() upgrades that same
# account with an email + password, so the player ID and duels stay. log_in() signs in to an
# existing account on any device.

## Turns the current guest into an email account (keeps the player ID).
func create_account(email: String, password: String) -> Dictionary:
	var reg := await register()  # make sure there is a guest account + player first
	if not reg["ok"]:
		return reg
	var res := await _call(HTTPClient.METHOD_PUT, "/auth/v1/user", {"email": email.strip_edges(), "password": password})
	if not res["ok"]:
		return res
	var user: Dictionary = res["data"] if res["data"] is Dictionary else {}
	if str(user.get("email", "")) != email.strip_edges().to_lower():
		# Supabase is set to send a confirmation email first.
		return {"ok": false, "error": "confirm_email", "error_code": "confirm_email"}
	Save.data["email"] = email.strip_edges().to_lower()
	Save.save_game()
	return {"ok": true}


## Signs in to an existing account on this device and loads that player.
func log_in(email: String, password: String) -> Dictionary:
	var res := await _call(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=password",
		{"email": email.strip_edges(), "password": password}, false)
	if not res["ok"]:
		return res
	_store_session(res["data"])
	Save.data["email"] = email.strip_edges().to_lower()
	Save.data["player_id"] = ""
	var profile := await _rpc("my_profile", {})
	if profile["ok"] and profile["data"] is Dictionary:
		var p: Dictionary = profile["data"]
		Save.data["player_id"] = str(p["id"])
		Save.data["nickname"] = str(p["nickname"])
		Save.data["avatar"] = AvatarParts.normalize(p.get("avatar", {}))
		Save.data["avatar_synced"] = true
		_reset_local_wallet()  # this device's guest coins don't merge into the account
		apply_wallet(p.get("wallet"))
	Save.save_game()
	if str(Save.data["player_id"]) == "":
		return await register()  # account without a player yet (shouldn't happen)
	return {"ok": true}


## Logs out on this device. Next time the game starts as a new guest.
func log_out() -> void:
	if is_configured() and str(Save.data["auth"].get("access_token", "")) != "":
		await _call(HTTPClient.METHOD_POST, "/auth/v1/logout", {})
	Save.data["auth"] = {}
	Save.data["player_id"] = ""
	Save.data["email"] = ""
	Save.data["nickname"] = ""
	Save.data["avatar"] = {}
	Save.data["friends"] = []
	_reset_local_wallet()
	Save.save_game()


## Deletes this account and everything on the server (player, duels, levels).
func delete_account() -> Dictionary:
	var res := await _rpc("delete_my_account", {})
	if res["ok"]:
		Save.data["auth"] = {}
		Save.data["player_id"] = ""
		Save.data["email"] = ""
		Save.data["nickname"] = ""
		Save.data["avatar"] = {}
		Save.data["friends"] = []
		_reset_local_wallet()
		Save.save_game()
	return res


func is_logged_in() -> bool:
	return str(Save.data.get("email", "")) != ""


## Invite link for a duel with you, e.g. https://ilija-dot.github.io/geo-duel/?invite=K7M2QX&d=medium
func invite_link(difficulty: String) -> String:
	return "%s?invite=%s&d=%s" % [GAME_URL, Save.data["player_id"], difficulty]


# --- Login (anonymous) ----------------------------------------------------------

func _ensure_session() -> Dictionary:
	var auth: Dictionary = Save.data["auth"]
	var now := int(Time.get_unix_time_from_system())
	if auth.get("access_token", "") != "" and int(auth.get("expires_at", 0)) > now + 60:
		return {"ok": true}
	var res: Dictionary
	if auth.get("refresh_token", "") != "":
		res = await _call(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=refresh_token",
			{"refresh_token": auth["refresh_token"]}, false)
		if not res["ok"] and int(res.get("code", 0)) in [400, 401, 403]:
			# The saved login is no longer valid (e.g. logged out elsewhere).
			Save.data["auth"] = {}
			if is_logged_in():
				Save.data["email"] = ""
				Save.data["player_id"] = ""
				Save.save_game()
				return {"ok": false, "error": "session_expired", "error_code": "session_expired"}
			Save.data["player_id"] = ""
			res = await _call(HTTPClient.METHOD_POST, "/auth/v1/signup", {"data": {}}, false)
	else:
		res = await _call(HTTPClient.METHOD_POST, "/auth/v1/signup", {"data": {}}, false)
	if not res["ok"]:
		return res
	_store_session(res["data"])
	return {"ok": true}


func _store_session(d: Dictionary) -> void:
	var now := int(Time.get_unix_time_from_system())
	Save.data["auth"] = {
		"access_token": d.get("access_token", ""),
		"refresh_token": d.get("refresh_token", ""),
		"expires_at": int(d.get("expires_at", now + int(d.get("expires_in", 3600)))),
	}
	Save.save_game()


# --- HTTP helpers ------------------------------------------------------------------

func _rpc(function_name: String, params: Dictionary) -> Dictionary:
	return await _call(HTTPClient.METHOD_POST, "/rest/v1/rpc/" + function_name, params)


func _call(method: int, path: String, body: Variant = null, needs_login := true) -> Dictionary:
	if not is_configured():
		return {"ok": false, "error": "offline"}
	if needs_login:
		var session := await _ensure_session()
		if not session["ok"]:
			return session

	var headers := PackedStringArray([
		"apikey: " + SupabaseConfig.ANON_KEY,
		"Content-Type: application/json",
	])
	if needs_login:
		headers.append("Authorization: Bearer " + str(Save.data["auth"]["access_token"]))

	var http := HTTPRequest.new()
	http.timeout = 15.0
	# Browsers already unpack gzip replies; letting Godot unpack them again fails on the web
	# ("network" error after a duel was in fact created). So don't ask Godot to do it.
	http.accept_gzip = false
	add_child(http)
	var err := http.request(SupabaseConfig.URL + path, headers, method,
		"" if body == null else JSON.stringify(body))
	if err != OK:
		http.queue_free()
		return {"ok": false, "error": "network"}
	var result: Array = await http.request_completed
	http.queue_free()

	if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": "network"}
	var code: int = result[1]
	var text := (result[3] as PackedByteArray).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text) if text.strip_edges() != "" else null
	if code >= 200 and code < 300:
		return {"ok": true, "data": parsed}
	var message := "HTTP %d" % code
	var error_code := ""
	if parsed is Dictionary:
		message = str(parsed.get("message", parsed.get("error_description", parsed.get("msg", message))))
		error_code = str(parsed.get("error_code", parsed.get("error", "")))
	return {"ok": false, "error": message, "error_code": error_code, "code": code}
