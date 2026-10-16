class_name AuctionHouse
extends RefCounted
## Stakes in state enterprises sold to the highest bid, in voucher face value plus cash. The player's bid is held
## in escrow until the lot resolves. A lot nobody bids on comes back the next month. Rivals are duck-typed:
## anything with `id: String`, `out: bool` and `bid(enterprise, session) -> int` (roubles; 0 or under the
## reserve means they abstain).

var sess: RuSession
var ledger: Ledger
var registry: EnterpriseRegistry
var vouchers: VoucherMarket
var heat: StateHeat
var rivals: Array

var _lots: Dictionary = {}  ## enterprise id -> lot dictionary


func _init(sess_: RuSession, ledger_: Ledger, registry_: EnterpriseRegistry, vouchers_: VoucherMarket,
		heat_: StateHeat, rivals_: Array) -> void:
	sess = sess_
	ledger = ledger_
	registry = registry_
	vouchers = vouchers_
	heat = heat_
	rivals = rivals_


func schedule(enterprise_id: String, month_index: int, bp_offered: int, reserve_vouchers: int) -> void:
	_lots[enterprise_id] = {"id": enterprise_id, "month_index": month_index, "bp": bp_offered,
		"reserve": reserve_vouchers, "resolved": false, "vouchers_in": 0, "cash_in": 0, "disq": []}


## True while the firm has a lot that is not yet settled (this month's or a relisted one).
func is_listed(enterprise_id: String) -> bool:
	return _lots.has(enterprise_id) and not bool(_lots[enterprise_id]["resolved"])


func open_this_month() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in _lots:
		if _is_open(_lots[id]):
			out.append(_lots[id])
	return out


func _is_open(lot: Dictionary) -> bool:
	return not bool(lot["resolved"]) and int(lot["month_index"]) == sess.month_index


func reserve_value(lot: Dictionary) -> int:
	return int(lot["reserve"]) * VoucherMarket.NOMINAL_RUB


## Bid `vouchers` and `cash_rub` on an open lot. The bid is escrowed; a new bid replaces the old one. It must
## reach the reserve, and the player must hold what they offer.
func place_player_bid(id: String, vouchers_n: int, cash_rub: int) -> bool:
	if not _lots.has(id):
		return false
	var lot: Dictionary = _lots[id]
	if not _is_open(lot) or vouchers_n < 0 or cash_rub < 0:
		return false
	if vouchers_n > vouchers.player_vouchers + int(lot["vouchers_in"]):
		return false
	if cash_rub > ledger.rub + int(lot["cash_in"]):
		return false
	if vouchers_n * VoucherMarket.NOMINAL_RUB + cash_rub < reserve_value(lot):
		return false
	_refund_all(lot)
	vouchers.player_vouchers -= vouchers_n
	ledger.spend(cash_rub)
	lot["vouchers_in"] = vouchers_n
	lot["cash_in"] = cash_rub
	return true


func _refund_all(lot: Dictionary) -> void:
	vouchers.player_vouchers += int(lot["vouchers_in"])
	ledger.earn(int(lot["cash_in"]))
	lot["vouchers_in"] = 0
	lot["cash_in"] = 0


## Pay an official to knock the strongest rival out of this lot. Success depends on the size of the bribe against
## the stake's worth; either way the prosecutors take notice.
func bribe(id: String, _official: String, rub: int) -> Dictionary:
	if not _lots.has(id) or not _is_open(_lots[id]) or rub <= 0 or not ledger.spend(rub):
		return {"ok": false, "risk": heat.prosecutor}
	var lot: Dictionary = _lots[id]
	var e: Enterprise = registry.by_id(id)
	var effective: float = float(rub) / ledger.price_level()
	var p: float = clampf(effective / (0.01 * float(e.real_value_rub)), 0.1, 0.95)
	var ok: bool = sess.rng(2).random() < p
	if ok:
		var strongest: Variant = null
		var top := -1
		for r in rivals:
			if r.out or (lot["disq"] as Array).has(r.id):
				continue
			var v: int = r.bid(e, sess, reserve_value(lot))
			if v > top:
				top = v
				strongest = r
		if strongest != null:
			(lot["disq"] as Array).append(strongest.id)
		heat.add("prosecutor", 12.0)
		heat.add("rubop", 6.0)
	else:
		heat.add("prosecutor", 20.0)
	return {"ok": ok, "risk": heat.prosecutor}


## Close the lot. Returns {winner, price, bp}; {} if it was already resolved (or never existed).
func resolve(id: String) -> Dictionary:
	if not _lots.has(id) or bool(_lots[id]["resolved"]):
		return {}
	var lot: Dictionary = _lots[id]
	var e: Enterprise = registry.by_id(id)
	var floor_value: int = reserve_value(lot)
	var bids: Array = []  # [owner, value]
	var player_value: int = int(lot["vouchers_in"]) * VoucherMarket.NOMINAL_RUB + int(lot["cash_in"])
	if player_value >= floor_value and player_value > 0:
		bids.append([Ru.PLAYER, player_value])
	for r in rivals:
		if r.out or (lot["disq"] as Array).has(r.id):
			continue
		var v: int = r.bid(e, sess, reserve_value(lot))
		if v >= floor_value and v > 0:
			bids.append([r.id, v])
	var bp: int = mini(int(lot["bp"]), e.state_bp())
	if bids.is_empty() or bp <= 0:
		_refund_all(lot)
		if bp <= 0:
			lot["resolved"] = true
		else:
			lot["month_index"] = sess.month_index + 1  # relist next month
		return {"winner": "", "price": 0, "bp": 0}
	var best: Array = bids[0]
	for b in bids:
		if int(b[1]) > int(best[1]) or (int(b[1]) == int(best[1]) and b[0] == Ru.PLAYER):
			best = b
	var winner: String = best[0]
	var price: int = floor_value if bids.size() == 1 else int(best[1])
	e.sell_shares("state", winner, bp)
	lot["resolved"] = true
	if winner == Ru.PLAYER:
		var excess: int = player_value - price
		var v_back: int = mini(int(lot["vouchers_in"]), excess / VoucherMarket.NOMINAL_RUB)
		vouchers.player_vouchers += v_back
		ledger.earn(mini(int(lot["cash_in"]), excess - v_back * VoucherMarket.NOMINAL_RUB))
		lot["vouchers_in"] = 0
		lot["cash_in"] = 0
		sess.bus.emit("auction_won", float(sess.month_index), "", ["runner"], {"id": id, "bp": bp, "price": price})
	else:
		_refund_all(lot)
		sess.bus.emit("auction_lost", float(sess.month_index), "", ["runner"], {"id": id, "winner": winner, "price": price})
	return {"winner": winner, "price": price, "bp": bp}


func to_dict() -> Dictionary:
	return {"lots": _lots.duplicate(true)}


func load_dict(d: Dictionary) -> void:
	_lots = (d.get("lots", {}) as Dictionary).duplicate(true)
