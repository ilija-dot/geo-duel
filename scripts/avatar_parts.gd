class_name AvatarParts
extends RefCounted
## Every option for building an avatar. An avatar is just a few numbers, e.g.
## {"skin": 2, "hair": 3, "hair_color": 1, "eyes": 0, "mouth": 2, "acc": 4, "bg": 5}
## so it is tiny to store online and can't contain anything inappropriate.

static var SKIN := [Color("ffe0c4"), Color("f5c9a5"), Color("e0a97e"), Color("c08455"), Color("8d5a36"), Color("5e3a22")]
static var HAIR_COLOR := [Color("2b1d14"), Color("5a3825"), Color("a0612b"), Color("e8c060"), Color("d9534f"), Color("8e5cff"), Color("2ec4a6"), Color("f0f0f0")]
static var BG := [Color("3a7bd5"), Color("2ec4a6"), Color("ff7a59"), Color("ff6fb5"), Color("6ab04c"), Color("8e5cff"), Color("f5c542"), Color("44495e")]
const HAIR := ["none", "short", "long", "spiky", "bun", "curly", "mohawk"]
const EYES := ["dots", "big", "happy", "sleepy", "wink"]
const MOUTH := ["smile", "open", "flat", "o", "tongue"]

## Accessories. Free ones for everyone; the rest are bought with coins or gems (looks only).
const ACCESSORIES := [
	{"id": "none", "mk": "Ништо", "en": "None", "price": 0, "currency": "coins"},
	{"id": "glasses", "mk": "Очила", "en": "Glasses", "price": 0, "currency": "coins"},
	{"id": "flower", "mk": "Цвет", "en": "Flower", "price": 0, "currency": "coins"},
	{"id": "sunglasses", "mk": "Сончеви очила", "en": "Sunglasses", "price": 100, "currency": "coins"},
	{"id": "cap", "mk": "Капа", "en": "Cap", "price": 150, "currency": "coins"},
	{"id": "headphones", "mk": "Слушалки", "en": "Headphones", "price": 250, "currency": "coins"},
	{"id": "crown", "mk": "Круна", "en": "Crown", "price": 60, "currency": "gems"},
]

## The parts shown in the editor, in order.
const KEYS := ["skin", "hair", "hair_color", "eyes", "mouth", "acc", "bg"]


static func count(key: String) -> int:
	match key:
		"skin": return SKIN.size()
		"hair": return HAIR.size()
		"hair_color": return HAIR_COLOR.size()
		"eyes": return EYES.size()
		"mouth": return MOUTH.size()
		"acc": return ACCESSORIES.size()
		"bg": return BG.size()
	return 1


static func defaults() -> Dictionary:
	return {"skin": 1, "hair": 1, "hair_color": 1, "eyes": 0, "mouth": 0, "acc": 0, "bg": 0}


## Fills in missing parts and fixes out-of-range numbers (e.g. from an older app version).
static func normalize(av: Variant) -> Dictionary:
	var out := defaults()
	if av is Dictionary:
		for key: String in KEYS:
			if (av as Dictionary).has(key):
				out[key] = clampi(int(av[key]), 0, count(key) - 1)
	return out


static func random_avatar() -> Dictionary:
	var av := {}
	for key: String in KEYS:
		av[key] = randi() % count(key)
	av["acc"] = randi() % 3  # only free accessories
	return av


static func accessory(index: int) -> Dictionary:
	return ACCESSORIES[clampi(index, 0, ACCESSORIES.size() - 1)]


## Shop item id for an accessory, e.g. "acc_crown" (stored in Save "owned").
static func item_id(index: int) -> String:
	return "acc_" + str(accessory(index)["id"])


static func is_free(index: int) -> bool:
	return int(accessory(index)["price"]) == 0
