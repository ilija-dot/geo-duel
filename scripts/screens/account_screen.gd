class_name AccountScreen
extends Screen
## Create an email account (keeps your guest ID and duels), log in on another device, or log out.

var _email: LineEdit
var _password: LineEdit
var _status: Label


func build() -> void:
	label(L.t("account"), 46)
	if not Net.is_configured():
		label(L.t("online_only"), 26)
		button(L.t("menu"), main.show_menu)
		return

	if Net.is_logged_in():
		label(L.t("logged_in_as") % Save.data["email"], 28)
		label(L.t("your_id") % Save.data["player_id"], 28)
		spacer(20)
		button(L.t("log_out"), _log_out)
		label(L.t("logout_note"), 22)
	else:
		label(L.t("account_note"), 24)
		var form := add_login_form(self)
		_email = form[0]
		_password = form[1]
		button(L.t("create_account"), _create)
		label(L.t("privacy_agree"), 20)
		label(L.t("have_account"), 26)
		button(L.t("log_in"), _log_in)
	_status = label("", 24)
	var bottom := row()
	button(L.t("privacy"), main.show_privacy.bind(main.show_account), bottom).size_flags_horizontal = SIZE_EXPAND_FILL
	button(L.t("menu"), main.show_menu, bottom).size_flags_horizontal = SIZE_EXPAND_FILL
	if str(Save.data["player_id"]) != "":
		_delete = button(L.t("delete_account"), _delete_account)
		_delete.add_theme_stylebox_override("normal", UI.box(UI.RATING_COLORS["R"].darkened(0.2)))
		_delete.add_theme_stylebox_override("hover", UI.box(UI.RATING_COLORS["R"]))


var _delete: Button
var _delete_armed := false


## First tap asks for confirmation, second tap deletes everything on the server.
func _delete_account() -> void:
	if not _delete_armed:
		_delete_armed = true
		_status.text = L.t("delete_confirm")
		return
	_delete.disabled = true
	_status.text = L.t("connecting")
	var res := await Net.delete_account()
	if not is_inside_tree():
		return
	if res["ok"]:
		_status.text = L.t("deleted")
		main.show_menu()
	else:
		_delete.disabled = false
		_status.text = error_text(res)


## Email + password boxes, shared with the invite screen. Returns [email, password].
static func add_login_form(screen: Screen) -> Array:
	var email := screen.input(L.t("email_ph"))
	email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	email.max_length = 120
	var password := screen.input(L.t("password_ph"))
	password.secret = true
	password.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD
	password.max_length = 72
	return [email, password]


## Checks the boxes before sending. Returns an error text, or "" if fine.
static func check_form(email: String, password: String) -> String:
	var e := email.strip_edges()
	if not RegEx.create_from_string("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$").search(e):
		return L.t("err_email")
	if password.length() < 6:
		return L.t("err_password")
	return ""


## Turns a server error into a friendly message.
static func error_text(res: Dictionary) -> String:
	var code := str(res.get("error_code", ""))
	var msg := str(res.get("error", "")).to_lower()
	if code in ["email_exists", "user_already_exists"] or msg.contains("already"):
		return L.t("err_email_taken")
	if code == "invalid_credentials" or msg.contains("invalid login"):
		return L.t("err_wrong_login")
	if code == "weak_password":
		return L.t("err_password")
	if code in ["email_address_invalid", "validation_failed"]:
		return L.t("err_email")
	if code in ["confirm_email", "email_not_confirmed"]:
		return L.t("err_confirm")
	if code == "session_expired":
		return L.t("err_session")
	if code.contains("rate_limit") or int(res.get("code", 0)) == 429:
		return L.t("err_rate")
	if msg == "network":
		return L.t("net_error")
	return L.t("err_generic") % res.get("error", "?")


func _create() -> void:
	var problem := check_form(_email.text, _password.text)
	if problem != "":
		_status.text = problem
		return
	_status.text = L.t("connecting")
	var res := await Net.create_account(_email.text, _password.text)
	if not is_inside_tree():
		return
	if res["ok"]:
		_status.text = L.t("account_created") % Save.data["email"]
		main.show_menu()
	else:
		_status.text = error_text(res)


func _log_in() -> void:
	var problem := check_form(_email.text, _password.text)
	if problem != "":
		_status.text = problem
		return
	_status.text = L.t("connecting")
	var res := await Net.log_in(_email.text, _password.text)
	if not is_inside_tree():
		return
	if res["ok"]:
		main.refresh_theme()
		main.show_menu()
	else:
		_status.text = error_text(res)


func _log_out() -> void:
	await Net.log_out()
	if is_inside_tree():
		main.show_menu()
