extends TestCase
## Determinism and playability: the same seed replays identically, the bot can play a whole game, and a save
## taken in the middle of an auction resolves the same way.

var _games: Array[RuGame] = []


func after_each() -> void:
	for g in _games:
		g.dispose()
	_games.clear()


func _play(seed_: int) -> RuGame:
	var g := RuGame.new_game(seed_)
	_games.append(g)
	RuBot.play(g)
	return g


func test_same_seed_replays_to_identical_final_state() -> void:
	var a := _play(101)
	var b := _play(101)
	check_eq(a.to_dict(), b.to_dict(), "two runs of the same seed end in the same state")


func test_different_seeds_end_differently() -> void:
	var a := _play(101)
	var b := _play(102)
	check(a.to_dict() != b.to_dict(), "another seed is another game")


func test_bot_reaches_the_end_with_a_sane_state() -> void:
	var g := _play(103)
	check(g.is_over(), "24 months played")
	check(g.ledger.rub >= 0, "no negative cash")
	check(g.ledger.price_level() > 100.0, "hyperinflation happened")
	check(g.chapters.score() >= 0, "scored")


func test_the_lazy_bot_wins_a_stake_in_a_minority_of_games() -> void:
	# Balance target (docs/RU_BALANCE.md): a policy that never bribes and never plans lands a firm in 20-60% of games.
	var wins := 0
	var seeds := 40
	for s in seeds:
		var g := _play(200 + s)
		if not g.registry.owned_by(Ru.PLAYER).is_empty():
			wins += 1
	check(wins * 100 >= 15 * seeds and wins * 100 <= 70 * seeds, "stake rate %d of %d is inside the 15-70%% band" % [wins, seeds])


func test_save_load_mid_auction_gives_the_same_result() -> void:
	var g := RuGame.new_game(301, {"cash_rub": 50_000_000_000})
	_games.append(g)
	for i in 10:
		g.end_month()  # to October 1992: vouchers are issued
	g.vouchers.buy(5000)
	g.end_month()  # November 1992: lots open
	var lots: Array = g.auctions.open_this_month()
	check(lots.size() > 0, "lots are open")
	var id: String = str(lots[0]["id"])
	var reserve: int = int(lots[0]["reserve"])
	check(g.auctions.place_player_bid(id, mini(g.vouchers.player_vouchers, reserve * 2), 0), "bid placed")
	var h := RuGame.from_dict(g.to_dict())
	_games.append(h)
	g.end_month()
	h.end_month()
	check_eq(h.to_dict()["registry"], g.to_dict()["registry"], "same owners after the lot resolves")
	check_eq(h.ledger.rub, g.ledger.rub, "same cash")
	check_eq(h.vouchers.player_vouchers, g.vouchers.player_vouchers, "same vouchers")


func test_the_bot_draws_some_state_attention() -> void:
	# A bold bot bribes the property fund at every auction it can afford, so the prosecutors notice it.
	var noticed := 0
	for s in 20:
		var g := RuGame.new_game(500 + s)
		_games.append(g)
		var peak := 0.0
		while not g.is_over():
			RuBot.act(g, true)
			peak = maxf(peak, g.heat.prosecutor)
			g.end_month()
		if peak > 5.0:
			noticed += 1
	check(noticed >= 5, "the state looked at the bot in %d of 20 games" % noticed)
