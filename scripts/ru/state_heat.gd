class_name StateHeat
extends RefCounted
## How closely the state is watching: the tax police, RUBOP (the organised-crime unit), the prosecutors and the
## Service (ex-KGB). Each meter runs 0-100. The 1990s organs are weak and corruptible; `enforcement_by_year`
## in data/ru/heat.json says how strong they are, and the raid chance is the hottest meter scaled by it.

const KINDS := ["tax", "rubop", "prosecutor", "service"]

var sess: RuSession
var ledger: Ledger
var registry: EnterpriseRegistry
var tax: float = 0.0
var rubop: float = 0.0
var prosecutor: float = 0.0
var service: float = 0.0

var _enforcement: Dictionary = {}
var _decay: float = 0.05


func _init(sess_: RuSession, ledger_: Ledger, registry_: EnterpriseRegistry) -> void:
	sess = sess_
	ledger = ledger_
	registry = registry_
	var d: Dictionary = Ru.load_json("res://data/ru/heat.json")
	_enforcement = d.get("enforcement_by_year", {})
	_decay = float(d.get("monthly_decay", 0.05))


func get_level(kind: String) -> float:
	return float(get(kind)) if kind in KINDS else 0.0


## Raise (or, with a negative amount, lower) one meter. False for a kind that does not exist.
func add(kind: String, amount: float) -> bool:
	if not kind in KINDS:
		return false
	set(kind, clampf(float(get(kind)) + amount, 0.0, 100.0))
	return true


func apply_month() -> void:
	for k in KINDS:
		set(k, float(get(k)) * (1.0 - _decay))


func enforcement() -> float:
	var year: int = sess.year_month().x
	if _enforcement.has(str(year)):
		return float(_enforcement[str(year)])
	var best := 0
	for k in _enforcement:
		best = maxi(best, int(k))
	return float(_enforcement.get(str(best), 0.1)) if year > best else 0.1


## Chance, this month, that the state moves against the organisation.
func raid_chance() -> float:
	var hottest: float = maxf(maxf(tax, rubop), maxf(prosecutor, service))
	return clampf(hottest / 100.0 * enforcement(), 0.0, 1.0)


## A raid happens: cash is seized (never more than there is) and, if the prosecutors are hot, a firm may be
## taken back by the state. The heat cools afterwards. Returns {seized_rub, lost_enterprise}.
func resolve_raid() -> Dictionary:
	var r: PyRandom = sess.rng(5)
	var seized: int = mini(ledger.rub, int(float(ledger.rub) * r.uniform(0.05, 0.25)))
	ledger.spend(seized)
	var lost := ""
	if prosecutor > 60.0 and r.random() < prosecutor / 200.0:
		var best: Enterprise = null
		for e in registry.owned_by(Ru.PLAYER):
			if best == null or e.real_value_rub > best.real_value_rub:
				best = e
		if best != null:
			best.sell_shares(Ru.PLAYER, "state", best.holding(Ru.PLAYER))
			lost = best.id
	for k in KINDS:
		set(k, float(get(k)) * 0.7)
	sess.bus.emit("raid", 0.0, "", ["runner", "law"], {"seized_rub": seized, "lost_enterprise": lost})
	return {"seized_rub": seized, "lost_enterprise": lost}


func to_dict() -> Dictionary:
	return {"tax": tax, "rubop": rubop, "prosecutor": prosecutor, "service": service}


func load_dict(d: Dictionary) -> void:
	for k in KINDS:
		set(k, float(d.get(k, 0.0)))
