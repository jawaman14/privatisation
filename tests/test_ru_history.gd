extends TestCase
## History (dated real events) and Chapters (the two chapters of the slice), wired together by RuGame.

var _game: RuGame = null


func after_each() -> void:
	if _game != null:
		_game.dispose()
		_game = null


func _new(seed_ := 61) -> RuGame:
	_game = RuGame.new_game(seed_)
	return _game


func test_skip_across_event_date_fires_once() -> void:
	var h := History.new()
	var first: Array = h.due(0, 12)  # December 1991 .. December 1992 covers Jan and Oct 1992
	var kinds := []
	for e in first:
		kinds.append(e["kind"])
	check(kinds.has("price_liberalisation"), "January 1992")
	check(kinds.has("vouchers_issued"), "October 1992")
	check_eq(kinds.count("vouchers_issued"), 1, "exactly once")
	check_eq(h.due(0, 12).size(), first.size(), "the query itself has no memory")
	check_eq(h.due(12, 13).size(), 0, "and nothing happens in January 1993 after the range")


func test_events_are_emitted_on_the_bus_as_the_months_pass() -> void:
	var g := _new()
	var seen := []
	g.sess.bus.subscribe("price_liberalisation", func(ev): seen.append(ev.kind))
	g.end_month()  # Jan 1992
	check_eq(seen.size(), 1, "liberalisation reaches the bus when its month begins")


func test_vouchers_issued_event_opens_the_voucher_market() -> void:
	var g := _new()
	for i in 9:
		g.end_month()  # to September 1992
	check(not g.vouchers.issued, "not yet in September")
	g.end_month()  # October 1992
	check(g.vouchers.issued, "issued in October 1992")
	check_eq(g.sess.year_month(), Vector2i(1992, 10), "and that is where we are")


func test_chapter_switches_after_september_1992() -> void:
	var g := _new()
	check_eq(g.chapters.current(), 1, "chapter 1 to start with")
	for i in 9:
		g.end_month()
	check_eq(g.chapters.current(), 1, "still September 1992")
	g.end_month()
	check_eq(g.chapters.current(), 2, "chapter 2 from October 1992")
	check(g.chapters.goals().size() > 0, "it has goals")


func test_the_game_ends_in_december_1993() -> void:
	var g := _new()
	for i in 24:
		g.end_month()
	check(g.is_over(), "24 months after December 1991")
	check(g.chapters.score() >= 0, "a score exists")


func test_auctions_are_scheduled_from_the_data_once_vouchers_exist() -> void:
	var g := _new()
	for i in 10:
		g.end_month()
	g.end_month()  # November 1992
	check(g.auctions.open_this_month().size() > 0, "the first lots are up in November 1992")


func test_a_month_with_a_raid_never_breaks_the_game() -> void:
	var g := _new()
	g.heat.add("prosecutor", 100.0)
	g.heat.add("tax", 100.0)
	for i in 24:
		g.end_month()
		g.heat.add("prosecutor", 100.0)
		check(g.ledger.rub >= 0, "cash never negative (month %d)" % i)


func test_save_and_load_reproduces_the_game() -> void:
	var g := _new(77)
	for i in 14:
		g.end_month()
	var d: Dictionary = g.to_dict()
	var h := RuGame.from_dict(d)
	check_eq(h.sess.month_index, g.sess.month_index, "same month")
	check_eq(h.ledger.rub, g.ledger.rub, "same cash")
	for i in 6:
		g.end_month()
		h.end_month()
	check_eq(h.ledger.rub, g.ledger.rub, "six months on they still agree on cash")
	check_eq(h.to_dict()["registry"], g.to_dict()["registry"], "and on who owns what")
	h.dispose()  # (g is disposed by after_each)


func test_owning_firms_draws_the_tax_police() -> void:
	var g := _new()
	g.registry.by_id("volzhsky_dairy").sell_shares("state", Ru.PLAYER, 10000)
	check_near(g.heat.tax, 0.0, 0.0001, "no heat before")
	for i in 3:
		g.end_month()
	check(g.heat.tax > 0.0, "a visible owner is a taxable one")
