extends TestCase
## RivalBanker: the AI oligarchs who bid against the player for the same lots.

const FIRM := "volzhsky_dairy"


func _make(seed_ := 41) -> Dictionary:
	var s := RuSession.new({"seed": seed_})
	var r := EnterpriseRegistry.new()
	r.load_from("res://data/ru/enterprises.json")
	return {"s": s, "r": r}


func _rival(m: Dictionary, id: String, temperament: String, cash := 2_000_000_000) -> RivalBanker:
	return RivalBanker.new(m.s, m.r, id, temperament, cash, 6)


func test_same_seed_gives_same_bids() -> void:
	var a := _make(5)
	var b := _make(5)
	var ra := _rival(a, "r", "greedy")
	var rb := _rival(b, "r", "greedy")
	var e: Enterprise = a.r.by_id(FIRM)
	check_eq(ra.bid(e, a.s), rb.bid(e, b.s), "deterministic")


func test_greedy_outbids_cautious_on_the_same_lot() -> void:
	var m := _make()
	var e: Enterprise = m.r.by_id("kamsky_oil")
	var greedy := 0
	var cautious := 0
	for i in 20:
		greedy += _rival(m, "g%d" % i, "greedy").bid(e, m.s)
		cautious += _rival(m, "c%d" % i, "cautious").bid(e, m.s)
	check(greedy > cautious, "greedy bids more over twenty lots")


func test_bids_against_a_reserve_are_a_multiple_of_it() -> void:
	var m := _make()
	var e: Enterprise = m.r.by_id(FIRM)
	var reserve := 10_000_000
	for i in 30:
		var g: int = _rival(m, "g%d" % i, "greedy", 1_000_000_000).bid(e, m.s, reserve)
		var c: int = _rival(m, "c%d" % i, "cautious", 1_000_000_000).bid(e, m.s, reserve)
		check(g >= int(1.3 * reserve) and g <= 2 * reserve, "greedy offers 1.3-2x the reserve (%d)" % g)
		check(c >= reserve and c <= int(1.2 * reserve), "cautious barely clears it (%d)" % c)


func test_a_rival_never_bids_more_than_it_has() -> void:
	var m := _make()
	var poor := _rival(m, "poor", "greedy", 50_000)
	check(poor.bid(m.r.by_id("kamsky_oil"), m.s) <= 50_000, "no credit in 1992")


func test_out_rival_never_bids_and_pending_deals_void_cleanly() -> void:
	var m := _make()
	var rv := _rival(m, "r", "violent")
	rv.target = FIRM
	check(rv.pending_on(FIRM), "it has a deal pending")
	rv.out = true
	check_eq(rv.bid(m.r.by_id(FIRM), m.s), 0, "arrested men do not bid")
	check(not rv.pending_on(FIRM), "and their deals lapse")
	rv.monthly(m.s)
	check(true, "a month passes without a crash")


func test_monthly_grows_cash_and_may_choose_a_target() -> void:
	var m := _make()
	var rv := _rival(m, "r", "greedy", 100_000_000)
	var start: int = rv.cash_rub
	for i in 12:
		m.s.advance_month()
		rv.monthly(m.s)
	check(rv.cash_rub != start, "the rival trades")
	check(rv.cash_rub >= 0, "never negative")


func test_round_trip() -> void:
	var m := _make()
	var rv := _rival(m, "r", "cautious")
	rv.target = FIRM
	rv.cash_rub = 77
	var rv2 := _rival(m, "r", "cautious")
	rv2.load_dict(rv.to_dict())
	check_eq(rv2.cash_rub, 77, "cash survives")
	check_eq(rv2.target, FIRM, "target survives")
