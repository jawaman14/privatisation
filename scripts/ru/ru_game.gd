class_name RuGame
extends RefCounted
## One game of Privatisation: builds every system around a RuSession and runs the month. The desk UI, the bot and
## the balance harness all drive a RuGame; nothing in here draws or reads the clock.

const START_CASH_RUB := 300_000  ## December 1991 roubles
const OWNER_TAX_HEAT := 0.5  ## per firm owned, per month
const RIVAL_CASH := {"dyachenko": 20_000_000, "zhuravlev": 8_000_000}

var sess: RuSession
var ledger: Ledger
var registry: EnterpriseRegistry
var vouchers: VoucherMarket
var heat: StateHeat
var auctions: AuctionHouse
var buyout: Buyout
var brotherhood: Brotherhood
var trading: Trading
var history: History
var chapters: Chapters
var rivals: Array = []  ## of RivalBanker

var _schedule: Array = []  ## from data/ru/auctions.json
var _reserve_factor: float = 1.0


static func new_game(seed_: int, opts := {}) -> RuGame:
	var g := RuGame.new()
	g._build(RuSession.new({"seed": seed_}), int(opts.get("cash_rub", START_CASH_RUB)))
	return g


func _build(sess_: RuSession, cash: int) -> void:
	sess = sess_
	ledger = Ledger.new(sess, cash)
	sess.ledger = ledger
	registry = EnterpriseRegistry.new()
	registry.load_from("res://data/ru/enterprises.json")
	vouchers = VoucherMarket.new(sess, ledger)
	heat = StateHeat.new(sess, ledger, registry)
	rivals = [RivalBanker.new(sess, registry, "dyachenko", "greedy", int(RIVAL_CASH["dyachenko"]), 6),
		RivalBanker.new(sess, registry, "zhuravlev", "violent", int(RIVAL_CASH["zhuravlev"]), 7)]
	auctions = AuctionHouse.new(sess, ledger, registry, vouchers, heat, rivals)
	buyout = Buyout.new(sess, ledger, registry, heat, auctions, rivals)
	brotherhood = Brotherhood.new(sess, ledger, registry, heat)
	trading = Trading.new(sess, ledger)
	history = History.new()
	chapters = Chapters.new(self)
	var a: Dictionary = Ru.load_json("res://data/ru/auctions.json")
	_schedule = a.get("lots", [])
	_reserve_factor = float(a.get("reserve_factor", 1.0))


## Pay Major Belov: a file on the prosecutors' desk goes missing. False, and nothing happens, if you cannot pay.
func pay_major(rub: int) -> bool:
	if rub <= 0 or not ledger.spend(rub):
		return false
	heat.add("prosecutor", -15.0)
	heat.add("rubop", -10.0)
	return true


## Break the reference cycles so the game can be freed.
func dispose() -> void:
	chapters.game = null
	sess.dispose()


func is_over() -> bool:
	return sess.month_index >= chapters.end_index()


## Close the month: resolve this month's auctions, then let the world move on one month.
func end_month() -> void:
	for lot in auctions.open_this_month().duplicate():
		auctions.resolve(str(lot["id"]))
	var prev: int = sess.month_index
	sess.advance_month()
	var now: int = sess.month_index
	ledger.apply_month()
	vouchers.apply_month()
	trading.apply_month()
	heat.apply_month()
	for e in registry.owned_by(Ru.PLAYER):
		heat.add("tax", OWNER_TAX_HEAT)  # a visible owner is a taxable one
	brotherhood.monthly()
	for r in rivals:
		r.monthly(sess)
	for ev in history.due(prev, now):
		sess.bus.emit(str(ev["kind"]), float(now), str(ev.get("text", "")), ["runner", "law"], ev)
	_schedule_auctions()
	_maybe_raid()


func _schedule_auctions() -> void:
	var ym: Vector2i = sess.year_month()
	var key: String = "%04d-%02d" % [ym.x, ym.y]
	for lot in _schedule:
		if str(lot["on"]) != key:
			continue
		var e: Enterprise = registry.by_id(str(lot["id"]))
		if e == null or e.state_bp() <= 0:
			continue
		var bp: int = int(lot["bp"])
		var reserve: int = maxi(1, int(float(e.book_value_rub) * float(bp) / 10000.0 * _reserve_factor / float(VoucherMarket.NOMINAL_RUB)))
		auctions.schedule(e.id, sess.month_index, bp, reserve)


func _maybe_raid() -> void:
	if sess.rng(5).random() >= heat.raid_chance():
		return
	var target: Enterprise = null
	for e in registry.owned_by(Ru.PLAYER):
		if target == null or e.real_value_rub > target.real_value_rub:
			target = e
	if target != null and brotherhood.defend_against_raid(target.id):
		sess.bus.emit("raid_repelled", float(sess.month_index), "", ["runner"], {"id": target.id})
		return
	heat.resolve_raid()


func to_dict() -> Dictionary:
	var rs := []
	for r in rivals:
		rs.append(r.to_dict())
	return {"sess": sess.to_dict(), "ledger": ledger.to_dict(), "registry": registry.to_dict(),
		"vouchers": vouchers.to_dict(), "heat": heat.to_dict(), "auctions": auctions.to_dict(),
		"buyout": buyout.to_dict(), "brotherhood": brotherhood.to_dict(), "trading": trading.to_dict(),
		"rivals": rs}


static func from_dict(d: Dictionary) -> RuGame:
	var g := RuGame.new()
	g._build(RuSession.from_dict(d["sess"]), 0)
	g.ledger.load_dict(d["ledger"])
	g.registry.load_dict(d["registry"])
	g.vouchers.load_dict(d["vouchers"])
	g.heat.load_dict(d["heat"])
	g.auctions.load_dict(d["auctions"])
	g.buyout.load_dict(d["buyout"])
	g.brotherhood.load_dict(d["brotherhood"])
	g.trading.load_dict(d["trading"])
	var rs: Array = d["rivals"]
	for i in g.rivals.size():
		g.rivals[i].load_dict(rs[i])
	return g
