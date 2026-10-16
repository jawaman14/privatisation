extends TestCase
## The Privatisation desk: builds around a RuGame, shows the month, and every action it offers runs.

var _desk: Desk = null
var _game: RuGame = null


func after_each() -> void:
	if _desk != null:
		_desk.free()
		_desk = null
	if _game != null:
		_game.dispose()
		_game = null


func _make(seed_ := 71, opts := {}) -> Desk:
	_game = RuGame.new_game(seed_, opts)
	_desk = Desk.new()
	_desk.bind(_game)
	return _desk


func test_desk_builds_and_end_month_advances() -> void:
	var d := _make()
	check(d.header_text().contains("December 1991"), "starts in December 1991: %s" % d.header_text())
	d.end_month_pressed()
	check_eq(_game.sess.month_index, 1, "one month on")
	check(d.header_text().contains("January 1992"), "and the header says so: %s" % d.header_text())
	check(d.header_text().contains("The Cooperative"), "chapter title shown")


func test_the_log_reports_what_happened() -> void:
	var d := _make()
	d.end_month_pressed()
	var joined := "\n".join(d.log_lines())
	check(joined.contains("Prices are freed"), "the January 1992 event is in the log")


func test_enterprise_list_shows_the_firms() -> void:
	var d := _make()
	check_eq(d.enterprise_ids().size(), 15, "all fifteen firms listed")
	d.select(d.enterprise_ids()[0])
	check_eq(d.selected(), d.enterprise_ids()[0], "selection sticks")
	d.select("nope")
	check_eq(d.selected(), d.enterprise_ids()[0], "an unknown id does not change it")


func test_every_action_runs_without_crashing() -> void:
	var d := _make(72, {"cash_rub": 50_000_000_000})
	d.do_trade_buy("vodka_cases", 10)
	d.end_month_pressed()
	d.do_trade_sell_all("vodka_cases")
	for i in 9:
		d.end_month_pressed()  # to October 1992
	d.do_buy_vouchers(1000)
	d.do_sell_vouchers(10)
	d.end_month_pressed()  # November: lots are open
	var lots: Array = _game.auctions.open_this_month()
	check(lots.size() > 0, "a lot is open")
	d.select(str(lots[0]["id"]))
	d.do_bid()
	d.do_bribe_official()
	d.select("tula_samovar")
	d.do_buyout()
	d.do_fund()
	d.do_exercise()
	_game.registry.by_id("kuban_sugar").sell_shares("state", Ru.PLAYER, 10000)
	d.select("kuban_sugar")
	d.do_roof()
	d.do_payoff()
	d.do_refuse()
	for c in ["director", "banker", "brigade", "major"]:
		d.do_call(c)
	d.end_month_pressed()
	check(_game.ledger.rub >= 0, "still solvent and standing")
	check(d.log_lines().size() > 0, "something was said")


func test_calling_the_major_buys_relief() -> void:
	var d := _make(73, {"cash_rub": 1_000_000_000})
	_game.heat.add("prosecutor", 50.0)
	var before: float = _game.heat.prosecutor
	d.do_call("major")
	check(_game.heat.prosecutor < before, "the major makes a file disappear")


func test_the_major_does_nothing_for_free() -> void:
	var d := _make(74, {"cash_rub": 1})
	_game.heat.add("prosecutor", 50.0)
	d.do_call("major")
	check_near(_game.heat.prosecutor, 50.0, 0.001, "no money, no favour")


func test_game_over_is_announced() -> void:
	var d := _make()
	for i in 24:
		d.end_month_pressed()
	check(d.header_text().contains("Final score"), "the end of 1993 shows the score: %s" % d.header_text())
	d.end_month_pressed()
	check_eq(_game.sess.month_index, 24, "and the clock stops")


func test_rival_names_are_capitalised_in_the_log() -> void:
	var d := _make()
	_game.sess.bus.emit("auction_lost", 0.0, "", ["runner"], {"id": "volzhsky_dairy", "winner": "dyachenko", "price": 5})
	check("\n".join(d.log_lines()).contains("Dyachenko"), "the winner is a person, not an id")


func test_binding_twice_does_not_duplicate_the_screen() -> void:
	var d := _make()
	var kids: int = d.get_child_count()
	d.bind(_game)
	check_eq(d.get_child_count(), kids, "one screen, however often it is bound")
	_game.sess.bus.emit("raid", 0.0, "", ["runner"], {"seized_rub": 1, "lost_enterprise": ""})
	var raids := 0
	for line in d.log_lines():
		if str(line).begins_with("Raid!"):
			raids += 1
	check_eq(raids, 1, "and an event is logged once, not once per bind")
