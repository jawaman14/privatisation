extends TestCase
## StateHeat: how closely the tax police, RUBOP, the prosecutors and the Service are watching.


func _make(cash := 10_000_000) -> Dictionary:
	var s := RuSession.new({"seed": 4})
	var l := Ledger.new(s, cash)
	var r := EnterpriseRegistry.new()
	r.load_from("res://data/ru/enterprises.json")
	var h := StateHeat.new(s, l, r)
	return {"s": s, "l": l, "r": r, "h": h}


func test_add_clamps_and_rejects_unknown_kind() -> void:
	var m := _make()
	check(m.h.add("tax", 30.0), "tax heat added")
	check_near(m.h.tax, 30.0, 0.001, "30")
	m.h.add("tax", 500.0)
	check_near(m.h.tax, 100.0, 0.001, "clamped at 100")
	m.h.add("tax", -500.0)
	check_near(m.h.tax, 0.0, 0.001, "and at 0")
	check(not m.h.add("weather", 5.0), "an unknown kind is refused")


func test_heat_decays_monthly() -> void:
	var m := _make()
	m.h.add("rubop", 50.0)
	m.h.apply_month()
	check(m.h.rubop < 50.0 and m.h.rubop > 40.0, "a few percent cooler each month")


func test_enforcement_is_weak_in_1992_and_stronger_in_1993() -> void:
	var m := _make()
	for k in ["tax", "rubop", "prosecutor", "service"]:
		m.h.add(k, 50.0)
	m.s.advance_month()  # Jan 1992
	var early: float = m.h.raid_chance()
	for i in 12:
		m.s.advance_month()  # Jan 1993
	var later: float = m.h.raid_chance()
	check(early > 0.0, "some risk even in 1992")
	check(later > early, "the state is stronger a year on")
	check(later <= 1.0, "a probability")


func test_no_heat_no_raid() -> void:
	var m := _make()
	m.s.advance_month()
	check_near(m.h.raid_chance(), 0.0, 0.0001, "a clean organisation is not raided")


func test_raid_can_seize_but_never_drives_cash_negative() -> void:
	var m := _make(100)
	for i in 50:
		var out: Dictionary = m.h.resolve_raid()
		check(m.l.rub >= 0, "cash never negative (raid %d)" % i)
		check(int(out.get("seized_rub", 0)) >= 0, "seizure is a non-negative amount")


func test_a_prosecutor_raid_can_return_a_firm_to_the_state() -> void:
	var m := _make()
	m.r.by_id("volzhsky_dairy").sell_shares("state", Ru.PLAYER, 10000)
	m.h.add("prosecutor", 95.0)
	var lost := ""
	for i in 300:
		lost = str(m.h.resolve_raid().get("lost_enterprise", ""))
		if lost != "":
			break
		m.h.add("prosecutor", 95.0)
	check_eq(lost, "volzhsky_dairy", "the player's only firm is taken back eventually")
	check_eq(m.r.by_id("volzhsky_dairy").state_bp(), 10000, "and the state holds it again")
