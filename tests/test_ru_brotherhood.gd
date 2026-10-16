extends TestCase
## Brotherhood: the krysha. Protection that is cheap early and possessive later.

const FIRM := "volzhsky_dairy"


func _make(cash := 5_000_000_000) -> Dictionary:
	var s := RuSession.new({"seed": 31})
	var l := Ledger.new(s, cash)
	var r := EnterpriseRegistry.new()
	r.load_from("res://data/ru/enterprises.json")
	var h := StateHeat.new(s, l, r)
	var b := Brotherhood.new(s, l, r, h)
	r.by_id(FIRM).sell_shares("state", Ru.PLAYER, 10000)
	return {"s": s, "l": l, "r": r, "h": h, "b": b}


func test_buying_a_roof_needs_a_firm_you_own_and_the_cash() -> void:
	var m := _make()
	check(not m.b.buy_roof("tula_samovar"), "not yours to protect")
	check(m.b.buy_roof(FIRM), "yours")
	check(m.b.is_protected(FIRM), "protected")
	check(not m.b.buy_roof(FIRM), "already under a roof")
	var poor := _make(10)
	check(not poor.b.buy_roof(FIRM), "cannot afford the first payment")
	check(not poor.b.is_protected(FIRM), "still bare")


func test_protected_enterprise_resists_a_rival_raid() -> void:
	var m := _make()
	m.b.buy_roof(FIRM)
	var repelled := 0
	var bare := 0
	for i in 60:
		if m.b.defend_against_raid(FIRM):
			repelled += 1
		if m.b.defend_against_raid("tula_samovar"):
			bare += 1
	check(repelled >= 35, "the roof usually holds (%d of 60)" % repelled)
	check_eq(bare, 0, "an unprotected firm has no one to call")


func test_tribute_rises_and_a_stake_demand_appears_after_the_standing_threshold() -> void:
	var m := _make()
	m.b.buy_roof(FIRM)
	var early: int = m.b.tribute_rub(FIRM)
	check_eq(m.b.demand_bp(FIRM), 0, "no demand at first")
	for i in 20:
		m.s.advance_month()
		m.l.earn(500_000_000)
		m.b.monthly()
	check(m.b.standing >= Brotherhood.DEMAND_STANDING, "they own you a little more each month")
	check(m.b.tribute_rub(FIRM) > early, "and the price rose with it")
	check(m.b.demand_bp(FIRM) > 0 or m.r.by_id(FIRM).holding("brotherhood") > 0, "they asked for a piece of the firm")


func test_an_unanswered_demand_is_taken_by_force() -> void:
	var m := _make()
	m.b.buy_roof(FIRM)
	m.b.standing = 80.0
	m.l.earn(1_000_000_000)
	m.b.monthly()
	check(m.b.demand_bp(FIRM) > 0, "the demand is made")
	var ask: int = m.b.demand_bp(FIRM)
	m.l.earn(1_000_000_000)
	m.b.monthly()
	check_eq(m.r.by_id(FIRM).holding("brotherhood"), ask, "ignored, they take it")
	check_eq(m.b.demand_bp(FIRM), 0, "nothing left to demand")


func test_paying_off_a_demand_clears_it_and_lowers_standing() -> void:
	var m := _make()
	m.b.buy_roof(FIRM)
	m.b.standing = 80.0
	m.l.earn(1_000_000_000)
	m.b.monthly()
	var before: float = m.b.standing
	check(m.b.pay_off(FIRM), "paid")
	check_eq(m.b.demand_bp(FIRM), 0, "demand cleared")
	check(m.b.standing < before, "and they think a little less of themselves")
	check(not m.b.pay_off(FIRM), "nothing to pay")


func test_refusal_has_a_consequence_event() -> void:
	var m := _make()
	var seen := []
	m.s.bus.subscribe("brotherhood_retaliation", func(ev): seen.append(ev))
	var workers: int = m.r.by_id(FIRM).workers
	var res: Dictionary = m.b.refuse(FIRM)
	check(res.has("event"), "something happens")
	check(m.r.by_id(FIRM).workers < workers, "men are hurt or sacked")
	check_eq(seen.size(), 1, "the bus hears of it")
	check(m.h.rubop > 0.0, "violence draws RUBOP")


func test_missing_the_tribute_is_a_refusal() -> void:
	var m := _make()
	m.b.buy_roof(FIRM)
	m.l.spend(m.l.rub)
	var workers: int = m.r.by_id(FIRM).workers
	m.b.monthly()
	check(m.r.by_id(FIRM).workers < workers, "no money, no peace")


func test_unprotected_firms_get_visits_and_roofed_ones_do_not() -> void:
	var bare := _make(50_000_000_000)
	var visits := []
	bare.s.bus.subscribe("brotherhood_retaliation", func(ev): visits.append(ev.kind))
	for i in 60:
		bare.b.monthly()
	check(visits.size() > 0, "a firm with no roof gets a visit from the local brigade sooner or later")
	var roofed := _make(50_000_000_000)
	var calm := []
	roofed.s.bus.subscribe("brotherhood_retaliation", func(ev): calm.append(ev.kind))
	roofed.b.buy_roof(FIRM)
	for i in 8:
		roofed.s.advance_month()
		roofed.l.earn(1_000_000_000)
		roofed.b.monthly()
	check_eq(calm.size(), 0, "tribute paid, peace kept")
