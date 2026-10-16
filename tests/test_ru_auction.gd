extends TestCase
## AuctionHouse: stakes in state enterprises sold for vouchers and cash, to the highest bid.


class StubRival extends RefCounted:
	var id: String = "rival"
	var out: bool = false
	var amount: int = 0

	func _init(id_ := "rival", amount_ := 0) -> void:
		id = id_
		amount = amount_

	func bid(_e, _sess, _reserve := 0) -> int:
		return amount


const LOT := "volzhsky_dairy"
const RESERVE_VOUCHERS := 10  ## 100,000 roubles of face value
const BP := 2500


func _make(rivals := [], cash := 50_000_000) -> Dictionary:
	var s := RuSession.new({"seed": 12})
	var l := Ledger.new(s, cash)
	var r := EnterpriseRegistry.new()
	r.load_from("res://data/ru/enterprises.json")
	var v := VoucherMarket.new(s, l)
	s.bus.emit("vouchers_issued", 0.0)
	var h := StateHeat.new(s, l, r)
	var a := AuctionHouse.new(s, l, r, v, h, rivals)
	a.schedule(LOT, s.month_index, BP, RESERVE_VOUCHERS)
	return {"s": s, "l": l, "r": r, "v": v, "h": h, "a": a}


func test_highest_bid_wins_and_shares_transfer() -> void:
	var m := _make([StubRival.new("rival", 5_000_000)])
	m.v.buy(20)
	check(m.a.place_player_bid(LOT, 20, 0), "player bids 20 vouchers (200,000 face value)")
	var out: Dictionary = m.a.resolve(LOT)
	check_eq(out.get("winner"), "rival", "the rival's 5m beats the player's 200k")
	check_eq(m.r.by_id(LOT).holding("rival"), BP, "rival now holds the stake")
	check_eq(m.r.by_id(LOT).state_bp(), 10000 - BP, "state sold it")
	check_eq(m.v.player_vouchers, 3 + 20, "the player's escrowed vouchers come back (3 were the allotment)")


func test_player_wins_with_the_highest_bid() -> void:
	var m := _make([StubRival.new("rival", 150_000)])
	m.v.buy(30)
	check(m.a.place_player_bid(LOT, 30, 0), "300,000 face value")
	var out: Dictionary = m.a.resolve(LOT)
	check_eq(out.get("winner"), Ru.PLAYER, "player wins")
	check_eq(m.r.by_id(LOT).holding(Ru.PLAYER), BP, "and holds the stake")


func test_zero_bidders_relists_next_month() -> void:
	var m := _make([StubRival.new("rival", 0)])
	var out: Dictionary = m.a.resolve(LOT)
	check_eq(out.get("winner"), "", "nobody bid")
	check_eq(m.a.open_this_month().size(), 0, "not open this month any more")
	m.s.advance_month()
	check_eq(m.a.open_this_month().size(), 1, "it is back next month")
	check_eq(m.r.by_id(LOT).state_bp(), 10000, "the state still holds everything")


func test_player_sole_bidder_pays_reserve_only() -> void:
	var m := _make([])
	m.v.buy(40)
	var have: int = m.v.player_vouchers
	check(m.a.place_player_bid(LOT, 40, 0), "400,000 against a 100,000 reserve")
	var out: Dictionary = m.a.resolve(LOT)
	check_eq(out.get("winner"), Ru.PLAYER, "sole bidder wins")
	check_eq(int(out.get("price")), RESERVE_VOUCHERS * VoucherMarket.NOMINAL_RUB, "and pays the reserve")
	check_eq(m.v.player_vouchers, have - RESERVE_VOUCHERS, "the unspent vouchers come back")


func test_bid_below_reserve_is_refused() -> void:
	var m := _make([])
	check(not m.a.place_player_bid(LOT, 2, 0), "two vouchers is under the reserve")
	check(not m.a.place_player_bid(LOT, 500, 0), "and you cannot bid vouchers you do not hold")
	check_eq(m.v.player_vouchers, 3, "nothing was taken")


func test_a_cash_top_up_counts_and_is_escrowed() -> void:
	var m := _make([])
	var cash: int = m.l.rub
	check(m.a.place_player_bid(LOT, 3, 80_000), "3 vouchers + 80,000 roubles = 110,000")
	check_eq(m.l.rub, cash - 80_000, "cash is held while the bid stands")
	var out: Dictionary = m.a.resolve(LOT)
	check_eq(int(out.get("price")), 100_000, "the sole bidder pays the 100,000 reserve")
	check_eq(m.v.player_vouchers, 1, "the 10,000 excess comes back as a voucher, vouchers first")
	check_eq(m.l.rub, cash - 80_000, "and the cash stays spent")


func test_bribe_can_disqualify_a_rival_and_adds_heat() -> void:
	var m := _make([StubRival.new("rival", 9_000_000)], 5_000_000_000)
	var heat0: float = m.h.prosecutor
	var won := false
	for i in 30:
		var res: Dictionary = m.a.bribe(LOT, "property_fund", 200_000_000)
		if res.get("ok"):
			won = true
			break
	check(won, "a big enough bribe works within a few tries")
	check(m.h.prosecutor > heat0, "and the prosecutors noticed")
	m.v.buy(30)
	m.a.place_player_bid(LOT, 30, 0)
	check_eq(m.a.resolve(LOT).get("winner"), Ru.PLAYER, "with the rival disqualified the player takes it")


func test_resolve_twice_is_a_noop_second_time() -> void:
	var m := _make([])
	m.v.buy(20)
	m.a.place_player_bid(LOT, 20, 0)
	m.a.resolve(LOT)
	var holding: int = m.r.by_id(LOT).holding(Ru.PLAYER)
	var second: Dictionary = m.a.resolve(LOT)
	check(second.is_empty(), "nothing to resolve")
	check_eq(m.r.by_id(LOT).holding(Ru.PLAYER), holding, "no second transfer")


func test_an_out_rival_never_bids() -> void:
	var rv := StubRival.new("rival", 99_000_000)
	rv.out = true
	var m := _make([rv])
	m.v.buy(20)
	m.a.place_player_bid(LOT, 20, 0)
	check_eq(m.a.resolve(LOT).get("winner"), Ru.PLAYER, "the arrested rival is skipped")
