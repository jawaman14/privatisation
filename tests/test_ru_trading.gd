extends TestCase
## Trading: buying at the state's price and selling on the street, while the gap closes through 1992-93.

const GOOD := "vodka_cases"

var _last: RuSession = null


func after_each() -> void:
	if _last != null:
		_last.dispose()  # breaks the session <-> ledger reference cycle so nothing leaks at exit


func _make(cash := 100_000_000) -> Dictionary:
	var s := RuSession.new({"seed": 51})
	_last = s
	var l := Ledger.new(s, cash)
	s.ledger = l
	var t := Trading.new(s, l)
	return {"s": s, "l": l, "t": t}


func _month(m: Dictionary) -> void:
	m.s.advance_month()
	m.l.apply_month()
	m.t.apply_month()


func test_buying_needs_a_contact() -> void:
	var m := _make()
	check(not m.t.buy_state("metal_ingots", 1), "no one sells you ingots yet")
	m.t.add_contact("metal_ingots")
	check(m.t.buy_state("metal_ingots", 1), "after the introduction you can")


func test_you_start_with_one_contact() -> void:
	var m := _make()
	check(m.t.has_contact(GOOD), "the kiosk man sells vodka from day one")
	check(not m.t.has_contact("fuel_oil_tonnes"), "nothing else")


func test_arbitrage_profit_is_positive_early_in_1992_and_shrinks_by_1993() -> void:
	var m := _make()
	_month(m)  # Jan 1992
	var early: float = m.t.profit_margin(GOOD)
	for i in 12:
		_month(m)  # Jan 1993
	var later: float = m.t.profit_margin(GOOD)
	check(early > 1.0, "better than doubling your money in January 1992 (%.2f)" % early)
	check(later > 0.0 and later < early, "still a living in 1993, but a thinner one (%.2f)" % later)


func test_quota_blocks_unlimited_buying() -> void:
	var m := _make(10_000_000_000)
	var q: int = m.t.quota(GOOD)
	check(m.t.buy_state(GOOD, q), "the whole quota")
	check(not m.t.buy_state(GOOD, 1), "not one more this month")
	_month(m)
	check(m.t.buy_state(GOOD, 1), "the quota resets with the month")


func test_round_trip_makes_money_in_1992() -> void:
	var m := _make()
	_month(m)
	var cash: int = m.l.rub
	check(m.t.buy_state(GOOD, 20), "bought")
	check_eq(m.t.stock(GOOD), 20, "in the warehouse")
	check(not m.t.sell_market(GOOD, 20), "but the lorry has not arrived: nothing to sell this month")
	_month(m)
	check_eq(m.t.sellable(GOOD), 20, "next month it is on the street")
	cash = m.l.rub
	check(m.t.sell_market(GOOD, 20), "sold")
	check_eq(m.t.stock(GOOD), 0, "empty")
	check(m.l.rub > cash, "and richer for it")


func test_cannot_sell_what_you_do_not_have_or_buy_what_you_cannot_afford() -> void:
	var m := _make(1)
	check(not m.t.sell_market(GOOD, 1), "nothing to sell")
	check(not m.t.buy_state(GOOD, 1), "one rouble buys nothing")
	check_eq(m.l.rub, 1, "money untouched")
	check(not m.t.buy_state(GOOD, 0) and not m.t.sell_market(GOOD, -2), "non-positive quantities are refused")


func test_unknown_good_is_refused() -> void:
	var m := _make()
	check(not m.t.buy_state("plutonium", 1), "no such good")
	check_eq(m.t.state_price("plutonium"), 0, "and no price")


func test_round_trip_of_state() -> void:
	var m := _make()
	m.t.add_contact("grain_tonnes")
	m.t.buy_state(GOOD, 5)
	var t2 := Trading.new(m.s, m.l)
	t2.load_dict(m.t.to_dict())
	check_eq(t2.stock(GOOD), 5, "stock survives")
	check(t2.has_contact("grain_tonnes"), "contacts survive")
	check_eq(t2.quota(GOOD), m.t.quota(GOOD), "so does the month's remaining quota")
