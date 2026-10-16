extends TestCase
## Enterprise and EnterpriseRegistry: who owns what, in basis points (10000 = the whole firm).


func _reg() -> EnterpriseRegistry:
	var r := EnterpriseRegistry.new()
	r.load_from("res://data/ru/enterprises.json")
	return r


func test_json_loads_15_enterprises_with_valid_shares() -> void:
	var r := _reg()
	check_eq(r.all().size(), 15, "fifteen firms in the slice")
	for e in r.all():
		var total := 0
		for owner in e.owner_shares:
			total += int(e.owner_shares[owner])
		check_eq(total, 10000, "%s shares sum to 10000" % e.id)
		check(e.workers > 0 and e.book_value_rub > 0, "%s has workers and a book value" % e.id)


func test_ids_are_unique() -> void:
	var r := _reg()
	var seen := {}
	for e in r.all():
		check(not seen.has(e.id), "duplicate id %s" % e.id)
		seen[e.id] = true


func test_sell_shares_moves_basis_points_and_rejects_oversell() -> void:
	var e := Enterprise.new()
	e.id = "x"
	e.owner_shares = {"state": 10000}
	check(e.sell_shares("state", "me", 2500), "a sale of a quarter")
	check_eq(int(e.owner_shares["state"]), 7500, "state keeps three quarters")
	check_eq(int(e.owner_shares["me"]), 2500, "buyer holds a quarter")
	check(not e.sell_shares("state", "me", 8000), "cannot sell more than held")
	check(not e.sell_shares("me", "you", 0), "a zero sale is refused")
	check(e.sell_shares("me", "you", 2500), "buyer can resell")
	check(not e.owner_shares.has("me"), "an empty holding is removed")
	check_eq(e.state_bp(), 7500, "state_bp reads the state's holding")


func test_real_value_exceeds_book_for_at_least_half() -> void:
	var r := _reg()
	var under := 0
	for e in r.all():
		if e.real_value_rub > e.book_value_rub:
			under += 1
	check(under * 2 >= r.all().size(), "the undervaluation that drives the game is in the data (%d of %d)" % [under, r.all().size()])


func test_owned_by_and_available() -> void:
	var r := _reg()
	check_eq(r.available().size(), 15, "the state still holds everything")
	var e: Enterprise = r.by_id(r.all()[0].id)
	check(e.sell_shares("state", "me", 10000), "buy a whole firm")
	check_eq(r.owned_by("me").size(), 1, "I own one")
	check_eq(r.available().size(), 14, "and the state has one fewer")
	check(r.by_id("nope") == null, "unknown id gives null")
