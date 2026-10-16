class_name Brotherhood
extends RefCounted
## The krysha ("roof"): organised crime selling protection. Cheap and useful early; the more it protects you
## the more it owns you. Pay the tribute each month, and once its standing with you is high enough it demands a
## piece of the firm. Refuse, or miss a payment, and the firm is burned or its men beaten.

const DEMAND_STANDING := 60.0
const DEMAND_BP := 1500
const STANDING_GAIN := 4.0  ## per roofed firm per month
const OWNER_ID := "brotherhood"
const RESIST_CHANCE := 0.8
const TRIBUTE_RATE := 0.002  ## of the firm's real value, per month, before standing scales it

var sess: RuSession
var ledger: Ledger
var registry: EnterpriseRegistry
var heat: StateHeat
var standing: float = 5.0

var _roofed: Array[String] = []
var _demands: Dictionary = {}  ## enterprise id -> bp demanded


func _init(sess_: RuSession, ledger_: Ledger, registry_: EnterpriseRegistry, heat_: StateHeat) -> void:
	sess = sess_
	ledger = ledger_
	registry = registry_
	heat = heat_


func is_protected(enterprise_id: String) -> bool:
	return _roofed.has(enterprise_id)


func tribute_rub(enterprise_id: String) -> int:
	var e: Enterprise = registry.by_id(enterprise_id)
	if e == null:
		return 0
	return int(float(e.real_value_rub) * TRIBUTE_RATE * ledger.price_level() * (1.0 + standing / 50.0))


## Take a roof over a firm the player owns. Costs three months' tribute up front.
func buy_roof(enterprise_id: String) -> bool:
	var e: Enterprise = registry.by_id(enterprise_id)
	if e == null or e.holding(Ru.PLAYER) <= 0 or is_protected(enterprise_id):
		return false
	if not ledger.spend(3 * tribute_rub(enterprise_id)):
		return false
	_roofed.append(enterprise_id)
	standing = minf(100.0, standing + 5.0)
	return true


func defend_against_raid(enterprise_id: String) -> bool:
	if not is_protected(enterprise_id):
		return false
	return sess.rng(4).random() < RESIST_CHANCE


func demand_bp(enterprise_id: String) -> int:
	return int(_demands.get(enterprise_id, 0))


func monthly() -> void:
	var ids: Array[String] = _roofed.duplicate()
	ids.sort()
	for id in ids:
		if not ledger.spend(tribute_rub(id)):
			_retaliate(id)
		standing = minf(100.0, standing + STANDING_GAIN)
		var e: Enterprise = registry.by_id(id)
		if _demands.has(id):
			var take: int = mini(int(_demands[id]), e.holding(Ru.PLAYER))
			if take > 0:
				e.sell_shares(Ru.PLAYER, OWNER_ID, take)
				sess.bus.emit("brotherhood_took_stake", float(sess.month_index), "", ["runner"], {"id": id, "bp": take})
			_demands.erase(id)
		elif standing >= DEMAND_STANDING and e.holding(Ru.PLAYER) >= DEMAND_BP and e.holding(OWNER_ID) < 4500:
			_demands[id] = DEMAND_BP
			sess.bus.emit("brotherhood_demand", float(sess.month_index), "", ["runner"], {"id": id, "bp": DEMAND_BP})


func pay_off(enterprise_id: String) -> bool:
	if not _demands.has(enterprise_id):
		return false
	var e: Enterprise = registry.by_id(enterprise_id)
	var cost: int = int(float(e.real_value_rub) * float(_demands[enterprise_id]) / 10000.0 * 0.5 * ledger.price_level())
	if not ledger.spend(cost):
		return false
	_demands.erase(enterprise_id)
	standing = maxf(0.0, standing - 20.0)
	return true


## Refuse to pay or to be protected: they make an example of the firm.
func refuse(enterprise_id: String) -> Dictionary:
	var e: Enterprise = registry.by_id(enterprise_id)
	if e == null or e.holding(Ru.PLAYER) <= 0:
		return {}
	return _retaliate(enterprise_id)


func _retaliate(enterprise_id: String) -> Dictionary:
	var e: Enterprise = registry.by_id(enterprise_id)
	var r: PyRandom = sess.rng(4)
	var kind: String = "arson" if r.random() < 0.5 else "beating"
	var lost: int = maxi(1, int(float(e.workers) * r.uniform(0.03, 0.08)))
	e.workers = maxi(0, e.workers - lost)
	heat.add("rubop", 8.0)
	var data := {"id": enterprise_id, "event": kind, "workers_lost": lost}
	sess.bus.emit("brotherhood_retaliation", float(sess.month_index), "", ["runner"], data)
	return data


func to_dict() -> Dictionary:
	return {"standing": standing, "roofed": _roofed.duplicate(), "demands": _demands.duplicate()}


func load_dict(d: Dictionary) -> void:
	standing = float(d.get("standing", 5.0))
	_roofed.clear()
	for id in d.get("roofed", []):
		_roofed.append(str(id))
	_demands = (d.get("demands", {}) as Dictionary).duplicate()
