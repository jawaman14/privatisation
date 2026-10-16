extends TestCase
## Ledger: integer roubles and dollars, and the price level under 1992's hyperinflation.


func _ledger(cash := 1000) -> Ledger:
	var s := RuSession.new({"seed": 3})
	return Ledger.new(s, cash)


func test_spend_refuses_when_short_and_leaves_balance() -> void:
	var l := _ledger(500)
	check(not l.spend(501), "cannot spend more than the balance")
	check_eq(l.rub, 500, "balance untouched")
	check(l.spend(500), "can spend all of it")
	check_eq(l.rub, 0, "nothing left")


func test_earn_adds() -> void:
	var l := _ledger(10)
	l.earn(90)
	check_eq(l.rub, 100, "earned")
	check(l.can_afford(100) and not l.can_afford(101), "can_afford is exact")


func test_1992_prices_rise_about_26x() -> void:
	var s := RuSession.new({"seed": 3})
	var l := Ledger.new(s, 0)
	check_near(l.price_level(), 1.0, 0.0001, "December 1991 is the base")
	for i in 12:
		s.advance_month()
		l.apply_month()
	check_near(l.price_level(), 26.0, 26.0 * 0.05, "2500% in 1992 is 26x")


func test_no_overflow_across_three_years() -> void:
	var s := RuSession.new({"seed": 3})
	var l := Ledger.new(s, 1_000_000_000)
	for i in 36:
		s.advance_month()
		l.apply_month()
	check(l.rub >= 0, "balance stays a non-negative integer")
	check(l.price_level() > 100.0 and l.price_level() < 2000.0, "three years of inflation is large but finite")
	check(l.rub_to_usd(l.rub) >= 0, "conversion is sane")


func test_the_rouble_buys_fewer_dollars_as_prices_rise() -> void:
	var s := RuSession.new({"seed": 3})
	var l := Ledger.new(s, 0)
	var before: int = l.rub_to_usd(1_000_000)
	for i in 12:
		s.advance_month()
		l.apply_month()
	check(l.rub_to_usd(1_000_000) < before, "a million roubles is worth fewer dollars a year on")
