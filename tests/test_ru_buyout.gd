extends TestCase
## Buyout: turn the director, let the insiders take 51% ("Option 2"), keep a side-deal option for yourself.


class BusyRival extends RefCounted:
	var id: String = "rival"
	var out: bool = false
	var target: String = ""

	func bid(_e, _s, _reserve := 0) -> int:
		return 0

	func pending_on(enterprise_id: String) -> bool:
		return enterprise_id == target


const FIRM := "volzhsky_dairy"


func _make(rivals := [], cash := 5_000_000_000) -> Dictionary:
	var s := RuSession.new({"seed": 21})
	var l := Ledger.new(s, cash)
	var r := EnterpriseRegistry.new()
	r.load_from("res://data/ru/enterprises.json")
	var v := VoucherMarket.new(s, l)
	var h := StateHeat.new(s, l, r)
	var a := AuctionHouse.new(s, l, r, v, h, rivals)
	var b := Buyout.new(s, l, r, h, a, rivals)
	return {"s": s, "l": l, "r": r, "h": h, "a": a, "b": b}


func _turn(m: Dictionary, id: String) -> bool:
	var e: Enterprise = m.r.by_id(id)
	for i in 30:
		var res: Dictionary = m.b.offer(e.director, id, e.director_price_rub * 100)
		if res.get("accepted"):
			return true
	return false


func test_accepted_buyout_moves_5100bp_to_insiders_and_player_gets_option() -> void:
	var m := _make()
	check(_turn(m, FIRM), "a generous bribe turns the director")
	check_eq(m.b.pending().size(), 1, "one deal waiting to be funded")
	check(m.b.fund_insider_purchase(FIRM), "the player funds the insiders' purchase")
	var e: Enterprise = m.r.by_id(FIRM)
	check_eq(e.holding("insiders"), 5100, "insiders hold 51%")
	check_eq(e.state_bp(), 4900, "state keeps 49%")
	check_eq(m.b.option_bp(FIRM), 3000, "the player holds an option on 30%")
	check_eq(m.b.pending().size(), 0, "nothing left pending")
	check(not m.b.fund_insider_purchase(FIRM), "cannot fund it twice")


func test_exercising_the_option_moves_shares_to_the_player() -> void:
	var m := _make()
	_turn(m, FIRM)
	m.b.fund_insider_purchase(FIRM)
	var cash: int = m.l.rub
	check(m.b.exercise_option(FIRM), "exercise")
	check_eq(m.r.by_id(FIRM).holding(Ru.PLAYER), 3000, "30% is the player's")
	check_eq(m.r.by_id(FIRM).holding("insiders"), 2100, "from the insiders' 51%")
	check(m.l.rub < cash, "and it cost something")
	check(not m.b.exercise_option(FIRM), "an option is used once")


func test_low_bribe_is_refused_and_costs_nothing() -> void:
	var m := _make()
	var e: Enterprise = m.r.by_id(FIRM)
	var cash: int = m.l.rub
	var res: Dictionary = m.b.offer(e.director, FIRM, 1)
	check(not res.get("accepted"), "a token bribe insults him")
	check_eq(m.l.rub, cash, "and costs nothing")
	check_eq(m.b.pending().size(), 0, "no deal")


func test_wrong_director_is_refused() -> void:
	var m := _make()
	check(not m.b.offer("Somebody Else", FIRM, 1_000_000_000).get("accepted"), "that is not his firm")


func test_cannot_buyout_with_a_pending_auction_or_rival_deal() -> void:
	var m := _make()
	m.a.schedule(FIRM, 0, 2500, 10)
	var e: Enterprise = m.r.by_id(FIRM)
	check(not m.b.offer(e.director, FIRM, e.director_price_rub * 100).get("accepted"), "a listed firm cannot be bought out")
	var rv := BusyRival.new()
	rv.target = "tula_samovar"
	var m2 := _make([rv])
	var e2: Enterprise = m2.r.by_id("tula_samovar")
	check(not m2.b.offer(e2.director, "tula_samovar", e2.director_price_rub * 100).get("accepted"), "a rival's deal blocks it")


func test_second_offer_while_one_is_pending_is_refused() -> void:
	var m := _make()
	check(_turn(m, FIRM), "first deal agreed")
	var e: Enterprise = m.r.by_id(FIRM)
	check(not m.b.offer(e.director, FIRM, e.director_price_rub * 100).get("accepted"), "already agreed")


func test_unfunded_or_unknown_deal_cannot_be_funded() -> void:
	var m := _make()
	check(not m.b.fund_insider_purchase(FIRM), "no deal yet")
	check(not m.b.fund_insider_purchase("nope"), "no such firm")
