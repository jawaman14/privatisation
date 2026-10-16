extends TestCase
## VoucherMarket: the 10,000-rouble privatisation vouchers, from the October 1992 issue.


func _make(cash := 100_000_000) -> Dictionary:
	var s := RuSession.new({"seed": 9})
	var l := Ledger.new(s, cash)
	var v := VoucherMarket.new(s, l)
	return {"s": s, "l": l, "v": v}


func _issue(s: RuSession) -> void:
	s.bus.emit("vouchers_issued", 0.0)


func test_cannot_buy_before_issue() -> void:
	var m := _make()
	check(not m.v.buy(5), "no vouchers exist yet")
	check_eq(m.l.rub, 100_000_000, "no money moved")


func test_issue_event_opens_the_market_and_gives_the_player_a_share() -> void:
	var m := _make()
	_issue(m.s)
	check(m.v.issued, "issued")
	check(m.v.player_vouchers > 0, "every citizen gets one; the player's household too")


func test_buy_deducts_price_times_count_and_adds_vouchers() -> void:
	var m := _make()
	_issue(m.s)
	var price: int = m.v.price_rub()
	var have: int = m.v.player_vouchers
	check(m.v.buy(10), "bought ten")
	check_eq(m.l.rub, 100_000_000 - price * 10, "paid the market price for each")
	check_eq(m.v.player_vouchers, have + 10, "ten more vouchers")
	check(not m.v.buy(0) and not m.v.buy(-3), "a non-positive count is refused")


func test_cannot_buy_what_cash_cannot_cover() -> void:
	var m := _make(1000)
	_issue(m.s)
	check(not m.v.buy(1), "a voucher costs more than 1000 roubles")
	check_eq(m.l.rub, 1000, "untouched")


func test_market_price_stays_below_nominal_in_1992() -> void:
	var m := _make()
	_issue(m.s)
	for i in 10:
		m.s.advance_month()
		m.l.apply_month()
		m.v.apply_month()
		check(m.v.price_rub() < VoucherMarket.NOMINAL_RUB, "month %d: below the 10,000 face value" % i)
		check(m.v.price_rub() > 0, "and positive")


func test_sell_returns_cash_and_removes_vouchers() -> void:
	var m := _make()
	_issue(m.s)
	m.v.buy(4)
	var cash: int = m.l.rub
	var have: int = m.v.player_vouchers
	check(m.v.sell(3), "sold three")
	check_eq(m.v.player_vouchers, have - 3, "three fewer")
	check_eq(m.l.rub, cash + 3 * m.v.price_rub(), "paid at market")
	check(not m.v.sell(have), "cannot sell more than held")


func test_bundle_for_bid_removes_vouchers_and_returns_their_face_value() -> void:
	var m := _make()
	_issue(m.s)
	var have: int = m.v.player_vouchers
	check_eq(m.v.bundle_for_bid(2), 2 * VoucherMarket.NOMINAL_RUB, "face value, not market price")
	check_eq(m.v.player_vouchers, have - 2, "spent")
	check_eq(m.v.bundle_for_bid(have + 50), 0, "not enough: nothing returned")
	check_eq(m.v.player_vouchers, have - 2, "and nothing removed")


func test_round_trip() -> void:
	var m := _make()
	_issue(m.s)
	m.v.buy(7)
	m.s.advance_month()
	m.v.apply_month()
	var d: Dictionary = m.v.to_dict()
	var v2 := VoucherMarket.new(m.s, m.l)
	v2.load_dict(d)
	check_eq(v2.player_vouchers, m.v.player_vouchers, "vouchers survive")
	check_eq(v2.price_rub(), m.v.price_rub(), "price survives")
	check(v2.issued, "issued survives")
