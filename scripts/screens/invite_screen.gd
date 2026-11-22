class_name InviteScreen
extends Screen
## Opened from an invite link (…/geo-duel/?invite=K7M2QX&d=medium).
## The friend creates an account or logs in, and the duel starts right away.

var invite: Dictionary = {}  # {"id": "K7M2QX", "d": "medium"}

var _title: Label
var _status: Label
var _email: LineEdit
var _password: LineEdit
var _inviter := ""
var _buttons: Array[Button] = []


func build() -> void:
	var id := str(invite.get("id", "")).to_upper()
	var diff := str(invite.get("d", "medium"))
	if not diff in QuestionBank.DIFFICULTIES:
		diff = "medium"
	invite["id"] = id
	invite["d"] = diff

	label(L.t("title"), 56)
	if not Net.is_configured() or not RegEx.create_from_string("^[A-Z0-9]{6}$").search(id):
		label(L.t("invite_bad"), 28)
		button(L.t("menu"), main.show_menu)
		return
	if id == str(Save.data["player_id"]):
		label(L.t("invite_self"), 28)
		button(L.t("menu"), main.show_menu)
		return

	_title = label(L.t("connecting"), 34)
	label(L.t("invite_sub") % L.t(diff), 24)
	if Net.is_logged_in():
		_buttons.append(button(L.t("accept_duel"), _start_duel))
	else:
		var form := AccountScreen.add_login_form(self)
		_email = form[0]
		_password = form[1]
		_buttons.append(button(L.t("invite_play"), _create_and_play))
		label(L.t("privacy_agree"), 20)
		label(L.t("have_account"), 24)
		_buttons.append(button(L.t("invite_login"), _login_and_play))
	_status = label("", 24)
	var bottom := row()
	button(L.t("privacy"), main.show_privacy.bind(main.show_invite.bind(invite)), bottom).size_flags_horizontal = SIZE_EXPAND_FILL
	button(L.t("menu"), main.show_menu, bottom).size_flags_horizontal = SIZE_EXPAND_FILL
	_load_inviter()


func _load_inviter() -> void:
	var res := await Net.find_player(str(invite["id"]))
	if not is_inside_tree():
		return
	if res["ok"] and not (res["data"] as Dictionary).is_empty():
		_inviter = str(res["data"]["nickname"])
		_title.text = L.t("invite_title") % _inviter
	elif res["ok"]:
		_title.text = L.t("invite_bad")
		for b in _buttons:
			b.disabled = true
	else:
		_title.text = L.t("net_error")


func _create_and_play() -> void:
	var problem := AccountScreen.check_form(_email.text, _password.text)
	if problem != "":
		_status.text = problem
		return
	_set_busy(true)
	var res := await Net.create_account(_email.text, _password.text)
	if not is_inside_tree():
		return
	if res["ok"]:
		_start_duel()
	else:
		_set_busy(false)
		_status.text = AccountScreen.error_text(res)


func _login_and_play() -> void:
	var problem := AccountScreen.check_form(_email.text, _password.text)
	if problem != "":
		_status.text = problem
		return
	_set_busy(true)
	var res := await Net.log_in(_email.text, _password.text)
	if not is_inside_tree():
		return
	if res["ok"]:
		_start_duel()
	else:
		_set_busy(false)
		_status.text = AccountScreen.error_text(res)


func _start_duel() -> void:
	_set_busy(true)
	if str(invite["id"]) == str(Save.data["player_id"]):
		_status.text = L.t("invite_self")
		return
	var res := await Net.create_duel(str(invite["id"]), str(invite["d"]))
	if not is_inside_tree():
		return
	if res["ok"]:
		Save.add_friend(str(invite["id"]), _inviter if _inviter != "" else str(invite["id"]))
		main.show_duel_quiz(res["data"])
	else:
		_set_busy(false)
		_status.text = L.t("invite_bad") if str(res["error"]).contains("not found") else L.t("err_generic") % res["error"]


func _set_busy(busy: bool) -> void:
	for b in _buttons:
		b.disabled = busy
	if busy:
		_status.text = L.t("connecting")
