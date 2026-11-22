class_name ThemeCatalog
extends RefCounted
## Every cosmetic theme in the shop. Themes only change colors - they never
## make anyone faster, so paying players don't get an advantage.
##
## To add a theme, add one line to all(). Colors are hex codes:
##   bg   = screen background      fg   = text on the background
##   tile = tile / button color    text = number on the tile
##   done = tile after you tap it


static func all() -> Array:
	return [
		# Free for everyone (so nobody looks "poor" for not paying)
		_t("classic", "Classic", "1d1f2b", "ffffff", "3a7bd5", "ffffff", "2b2e3d", 0, "coins"),
		_t("mint", "Mint", "12302b", "ffffff", "2ec4a6", "ffffff", "1c4640", 0, "coins"),
		_t("sunset", "Sunset", "2d1b2e", "ffffff", "ff7a59", "ffffff", "45293f", 0, "coins"),
		# Earned with coins from playing
		_t("ocean", "Ocean", "0b2545", "ffffff", "13a8d6", "ffffff", "13315c", 100, "coins"),
		_t("candy", "Candy", "3b1d3a", "ffffff", "ff6fb5", "ffffff", "54294f", 150, "coins"),
		_t("forest", "Forest", "1b2a1b", "ffffff", "6ab04c", "ffffff", "2a3d2a", 200, "coins"),
		_t("paper", "Paper", "f4efe6", "2d2d2d", "2d2d2d", "ffffff", "d9d2c5", 250, "coins"),
		_t("neon", "Neon", "0d0d0d", "39ff14", "39ff14", "0d0d0d", "1f1f1f", 400, "coins"),
		# Gems: from duel wins, or (later) bought with real money
		_t("galaxy", "Galaxy", "140c2e", "ffffff", "8e5cff", "ffffff", "2a1d52", 50, "gems"),
		_t("gold", "Gold", "1a1408", "f5c542", "f5c542", "1a1408", "3a2f12", 80, "gems"),
	]


static func get_item(id: String) -> Dictionary:
	for item: Dictionary in all():
		if item["id"] == id:
			return item
	return all()[0]


static func _t(id: String, title: String, bg: String, fg: String, tile: String, text: String,
		done: String, price: int, currency: String) -> Dictionary:
	return {
		"id": id, "name": title,
		"bg": Color(bg), "fg": Color(fg), "tile": Color(tile), "text": Color(text), "done": Color(done),
		"price": price, "currency": currency,
	}
