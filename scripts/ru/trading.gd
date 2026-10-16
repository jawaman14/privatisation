class_name Trading
extends RefCounted
## Arbitrage, the first money of the new Russia: buy goods at the state's price (through a contact, up to a
## monthly quota) and sell them on the street for several times as much. The gap closes as prices liberalise.

var sess: RuSession
var ledger: Ledger

var _goods: Dictionary = {}
var _anchors: Array = []
var _contacts: Dictionary = {}  ## good -> true
var _stock: Dictionary = {}  ## good -> units held
var _bought: Dictionary = {}  ## good -> units bought this month


func _init(sess_: RuSession, ledger_: Ledger) -> void:
	sess = sess_
	ledger = ledger_
	var d: Dictionary = Ru.load_json("res://data/ru/goods.json")
	_goods = d.get("goods", {})
	_anchors = d.get("gap_anchors", [[0, 1.0]])
	for g in d.get("start_contacts", []):
		_contacts[str(g)] = true


func goods() -> Array:
	return _goods.keys()


func good_name(good: String) -> String:
	return str((_goods.get(good, {}) as Dictionary).get("name", good))


func add_contact(good: String) -> void:
	if _goods.has(good):
		_contacts[good] = true


func has_contact(good: String) -> bool:
	return _contacts.has(good)


## How much wider the street price is than the state's, now (linear between the anchors).
func gap() -> float:
	var m: float = float(sess.month_index)
	var prev: Array = _anchors[0]
	for a in _anchors:
		if m <= float(a[0]):
			var span: float = float(a[0]) - float(prev[0])
			if span <= 0.0:
				return float(a[1])
			return lerpf(float(prev[1]), float(a[1]), (m - float(prev[0])) / span)
		prev = a
	return float(prev[1])


func state_price(good: String) -> int:
	if not _goods.has(good):
		return 0
	return maxi(1, int(float((_goods[good] as Dictionary)["base_price"]) * ledger.price_level()))


func market_price(good: String) -> int:
	return int(float(state_price(good)) * gap())


func profit_margin(good: String) -> float:
	var s: int = state_price(good)
	return 0.0 if s == 0 else float(market_price(good)) / float(s) - 1.0


## Units still buyable at the state price this month.
func quota(good: String) -> int:
	if not _goods.has(good):
		return 0
	return maxi(0, int((_goods[good] as Dictionary)["quota"]) - int(_bought.get(good, 0)))


func stock(good: String) -> int:
	return int(_stock.get(good, 0))


func buy_state(good: String, qty: int) -> bool:
	if qty <= 0 or not has_contact(good) or qty > quota(good):
		return false
	if not ledger.spend(state_price(good) * qty):
		return false
	_stock[good] = stock(good) + qty
	_bought[good] = int(_bought.get(good, 0)) + qty
	return true


## Units that can be sold now: what was bought this month is still on the road.
func sellable(good: String) -> int:
	return maxi(0, stock(good) - int(_bought.get(good, 0)))


func sell_market(good: String, qty: int) -> bool:
	if qty <= 0 or qty > sellable(good):
		return false
	_stock[good] = stock(good) - qty
	ledger.earn(market_price(good) * qty)
	return true


## A new month: the quotas reset.
func apply_month() -> void:
	_bought.clear()


func to_dict() -> Dictionary:
	return {"contacts": _contacts.duplicate(), "stock": _stock.duplicate(), "bought": _bought.duplicate()}


func load_dict(d: Dictionary) -> void:
	_contacts = (d.get("contacts", {}) as Dictionary).duplicate()
	_stock = (d.get("stock", {}) as Dictionary).duplicate()
	_bought = (d.get("bought", {}) as Dictionary).duplicate()
