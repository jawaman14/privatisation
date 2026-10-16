class_name VoucherMarket
extends RefCounted
## The privatisation vouchers: 10,000 roubles of face value, issued to every citizen from October 1992,
## traded on the street far below that. The player buys them cheap and spends them at auction at face value.

const NOMINAL_RUB := 10000

var sess: RuSession
var ledger: Ledger
var issued: bool = false
var player_vouchers: int = 0

var _fraction_by_year: Dictionary = {}
var _noise: float = 0.08
var _allotment: int = 3
var _drift: float = 1.0  ## this month's multiplier on the year's price


func _init(sess_: RuSession, ledger_: Ledger) -> void:
	sess = sess_
	ledger = ledger_
	var d: Dictionary = Ru.load_json("res://data/ru/vouchers.json")
	_fraction_by_year = d.get("price_fraction_by_year", {})
	_noise = float(d.get("monthly_noise", 0.08))
	_allotment = int(d.get("player_allotment", 3))
	sess.bus.subscribe("vouchers_issued", _on_issued)


func _on_issued(_ev) -> void:
	if issued:
		return
	issued = true
	player_vouchers += _allotment


func price_rub() -> int:
	var year: int = sess.year_month().x
	var f: float = _fraction_for(year)
	return maxi(1, int(float(NOMINAL_RUB) * f * _drift))


func _fraction_for(year: int) -> float:
	if _fraction_by_year.has(str(year)):
		return float(_fraction_by_year[str(year)])
	var best := 0
	for k in _fraction_by_year:
		best = maxi(best, int(k))
	return float(_fraction_by_year.get(str(best), 0.5)) if year > best else 0.35


func buy(count: int) -> bool:
	if not issued or count <= 0:
		return false
	if not ledger.spend(price_rub() * count):
		return false
	player_vouchers += count
	return true


func sell(count: int) -> bool:
	if not issued or count <= 0 or count > player_vouchers:
		return false
	player_vouchers -= count
	ledger.earn(price_rub() * count)
	return true


## Take `count` vouchers out of the player's hand for an auction bid; returns their face value, or 0 (and
## takes nothing) if the player does not hold that many.
func bundle_for_bid(count: int) -> int:
	if count <= 0 or count > player_vouchers:
		return 0
	player_vouchers -= count
	return count * NOMINAL_RUB


## Once a month: the street price wanders a little.
func apply_month() -> void:
	_drift = 1.0 + sess.rng(1).uniform(-_noise, _noise)


func to_dict() -> Dictionary:
	return {"issued": issued, "player_vouchers": player_vouchers, "drift": _drift}


func load_dict(d: Dictionary) -> void:
	issued = bool(d.get("issued", false))
	player_vouchers = int(d.get("player_vouchers", 0))
	_drift = float(d.get("drift", 1.0))
