class_name Ledger
extends RefCounted
## Money in whole roubles (an int, never a float) and the price level under the 1992-95 inflation.
## Balances are not inflated; prices are: other systems multiply their base prices by `price_level()`.

var sess: RuSession
var rub: int = 0
var usd: int = 0

var _index: float = 1.0  ## consumer prices relative to December 1991
var _annual: Dictionary = {}
var _usd_start: float = 125.0
var _pass_through: float = 0.5


func _init(sess_: RuSession, start_rub := 0) -> void:
	sess = sess_
	rub = start_rub
	var d: Dictionary = Ru.load_json("res://data/ru/inflation.json")
	_annual = d.get("annual_percent", {})
	_usd_start = float(d.get("usd_start_rub", 125))
	_pass_through = float(d.get("usd_pass_through", 0.5))


func price_level() -> float:
	return _index


## Compound the month the session has just entered (call after RuSession.advance_month).
func apply_month() -> void:
	var year: int = sess.year_month().x
	var pct: float = _annual_for(year)
	_index *= pow(1.0 + pct / 100.0, 1.0 / 12.0)


func _annual_for(year: int) -> float:
	if _annual.has(str(year)):
		return float(_annual[str(year)])
	var last_year := 0
	for k in _annual:
		last_year = maxi(last_year, int(k))
	if year < last_year or last_year == 0:
		return 0.0
	return float(_annual[str(last_year)])


## Roubles per dollar now: the rouble loses value more slowly than domestic prices rise (pass-through < 1).
func rub_per_usd() -> float:
	return _usd_start * pow(_index, _pass_through)


func rub_to_usd(amount: int) -> int:
	return int(float(amount) / rub_per_usd())


func can_afford(rub_amount: int) -> bool:
	return rub_amount >= 0 and rub >= rub_amount


func spend(rub_amount: int) -> bool:
	if not can_afford(rub_amount):
		return false
	rub -= rub_amount
	return true


func earn(rub_amount: int) -> void:
	rub += maxi(0, rub_amount)
