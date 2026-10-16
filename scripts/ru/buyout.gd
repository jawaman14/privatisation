class_name Buyout
extends RefCounted
## "Option 2" managers' buyouts: bribe the director, the insiders take 51% at 1.7x book value (the player puts up
## the money), and the player keeps an option on 30% at book value. The director must be turned first; a token
## bribe insults him at no cost, a failed real one is lost.

const INSIDER_BP := 5100
const OPTION_BP := 3000
const INSIDER_PRICE_X_BOOK := 1.7
const INSIDER_ID := "insiders"
const MIN_RATIO := 0.6  ## a bribe under this share of the director's price is refused outright

var sess: RuSession
var ledger: Ledger
var registry: EnterpriseRegistry
var heat: StateHeat
var auctions: AuctionHouse
var rivals: Array

var _deals: Dictionary = {}  ## enterprise id -> {"funded": bool}
var _options: Dictionary = {}  ## enterprise id -> bp the player may still buy


func _init(sess_: RuSession, ledger_: Ledger, registry_: EnterpriseRegistry, heat_: StateHeat,
		auctions_: AuctionHouse, rivals_: Array) -> void:
	sess = sess_
	ledger = ledger_
	registry = registry_
	heat = heat_
	auctions = auctions_
	rivals = rivals_


## Offer `bribe_rub` to a firm's director. Returns {accepted, bp, reason}.
func offer(director: String, enterprise_id: String, bribe_rub: int) -> Dictionary:
	var e: Enterprise = registry.by_id(enterprise_id)
	if e == null or e.director != director:
		return _no("not his firm")
	if _deals.has(enterprise_id) or auctions.is_listed(enterprise_id) or _rival_busy(enterprise_id):
		return _no("spoken for")
	if e.state_bp() < INSIDER_BP:
		return _no("the state no longer holds enough")
	var price: float = float(e.director_price_rub) * ledger.price_level()
	var ratio: float = float(bribe_rub) / price
	if ratio < MIN_RATIO or not ledger.can_afford(bribe_rub):
		return _no("insulted")
	ledger.spend(bribe_rub)
	var p: float = clampf(ratio / 1.5, 0.0, 0.95) * (1.0 - heat.prosecutor / 200.0)
	if sess.rng(3).random() >= p:
		heat.add("prosecutor", 10.0)
		return _no("took the money and talked")
	heat.add("prosecutor", 5.0)
	_deals[enterprise_id] = {"funded": false}
	return {"accepted": true, "bp": INSIDER_BP, "reason": ""}


func _no(reason: String) -> Dictionary:
	return {"accepted": false, "bp": 0, "reason": reason}


func _rival_busy(enterprise_id: String) -> bool:
	for r in rivals:
		if r.has_method("pending_on") and r.pending_on(enterprise_id):
			return true
	return false


func pending() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in _deals:
		if not bool(_deals[id]["funded"]):
			out.append({"id": id, "bp": INSIDER_BP, "cost": insider_cost(id)})
	return out


func insider_cost(enterprise_id: String) -> int:
	var e: Enterprise = registry.by_id(enterprise_id)
	if e == null:
		return 0
	return int(float(e.book_value_rub) * INSIDER_PRICE_X_BOOK * float(INSIDER_BP) / 10000.0 * ledger.price_level())


## The player finances the insiders' purchase of 51%; in return they hold an option on 30%.
func fund_insider_purchase(enterprise_id: String) -> bool:
	if not _deals.has(enterprise_id) or bool(_deals[enterprise_id]["funded"]):
		return false
	var e: Enterprise = registry.by_id(enterprise_id)
	if e.state_bp() < INSIDER_BP or not ledger.spend(insider_cost(enterprise_id)):
		return false
	e.sell_shares("state", INSIDER_ID, INSIDER_BP)
	_deals[enterprise_id]["funded"] = true
	_options[enterprise_id] = OPTION_BP
	sess.bus.emit("buyout_done", float(sess.month_index), "", ["runner"], {"id": enterprise_id})
	return true


func option_bp(enterprise_id: String) -> int:
	return int(_options.get(enterprise_id, 0))


## Buy the option's shares from the insiders at book value.
func exercise_option(enterprise_id: String) -> bool:
	var bp: int = option_bp(enterprise_id)
	if bp <= 0:
		return false
	var e: Enterprise = registry.by_id(enterprise_id)
	var cost: int = int(float(e.book_value_rub) * float(bp) / 10000.0 * ledger.price_level())
	if e.holding(INSIDER_ID) < bp or not ledger.spend(cost):
		return false
	e.sell_shares(INSIDER_ID, Ru.PLAYER, bp)
	_options.erase(enterprise_id)
	return true


func to_dict() -> Dictionary:
	return {"deals": _deals.duplicate(true), "options": _options.duplicate()}


func load_dict(d: Dictionary) -> void:
	_deals = (d.get("deals", {}) as Dictionary).duplicate(true)
	_options = (d.get("options", {}) as Dictionary).duplicate()
