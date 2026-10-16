class_name Chapters
extends RefCounted
## The two chapters of the slice, their goals and the score. Net worth is measured in December 1991 roubles
## (deflated by the price level) so that inflation does not make everyone rich.

var game: RuGame
var _spans: Array = []  ## [{number, title, from_index, to_index}]
var _end_index: int = 24


func _init(game_: RuGame) -> void:
	game = game_
	var d: Dictionary = Ru.load_json("res://data/ru/history.json")
	for c in d.get("chapters", []):
		_spans.append({"number": int(c["number"]), "title": str(c["title"]),
			"from_index": History.month_index_of(str(c["from"])), "to_index": History.month_index_of(str(c["to"]))})
	_end_index = History.month_index_of(str(d.get("end_month", "1993-12")))


func current() -> int:
	var m: int = game.sess.month_index
	for s in _spans:
		if m >= int(s["from_index"]) and m <= int(s["to_index"]):
			return int(s["number"])
	return int((_spans.back() as Dictionary)["number"]) if m > _end_index else 1


func title() -> String:
	for s in _spans:
		if int(s["number"]) == current():
			return str(s["title"])
	return ""


func end_index() -> int:
	return _end_index


## Everything the player has, in December 1991 roubles.
func net_worth() -> int:
	var level: float = game.ledger.price_level()
	var total: float = float(game.ledger.rub) / level
	total += float(game.vouchers.player_vouchers * game.vouchers.price_rub()) / level
	for g in game.trading.goods():
		total += float(game.trading.stock(g) * game.trading.market_price(g)) / level
	for e in game.registry.owned_by(Ru.PLAYER):
		total += float(e.real_value_rub) * float(e.holding(Ru.PLAYER)) / 10000.0
	return int(total)


func goals() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var worth: int = net_worth()
	var owned: Array[Enterprise] = game.registry.owned_by(Ru.PLAYER)
	if current() == 1:
		out.append({"text": "Build a stake of 200,000 roubles (1991 money)", "done": worth >= 200_000})
		var contacts := 0
		for g in game.trading.goods():
			if game.trading.has_contact(g):
				contacts += 1
		out.append({"text": "Open a second line of trade", "done": contacts >= 2})
	else:
		out.append({"text": "Own a share of an enterprise", "done": not owned.is_empty()})
		var held := 0
		for e in owned:
			held += int(float(e.real_value_rub) * float(e.holding(Ru.PLAYER)) / 10000.0)
		out.append({"text": "Hold enterprises worth 20,000,000 (1991 money)", "done": held >= 20_000_000})
		out.append({"text": "Keep the prosecutors off your back", "done": game.heat.prosecutor < 80.0})
	return out


func score() -> int:
	var done := 0
	for g in goals():
		if g["done"]:
			done += 1
	return maxi(0, net_worth() / 10000) + 100 * done
