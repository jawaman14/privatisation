class_name RuBot
extends RefCounted
## A simple policy that plays a whole game: trade early, hoard vouchers once they exist, bid for the cheapest
## lots, buy a roof for what it owns, and turn a director when it is rich enough. It exists to prove the game can
## be played and to drive the balance harness; it is deliberately not clever.

const SECOND_CONTACT_MONTH := 3
const VOUCHER_SHARE := 0.5  ## of cash spent on vouchers each month once they exist
const MAX_BID_MULTIPLE := 3  ## bid up to this many times the reserve


## `bold` bots also bribe the property fund whenever they can afford a quarter of the sure price, whether or not
## they could bid: they exist to put pressure on the state in tests and balance runs.
static func play(g: RuGame, bold := false) -> void:
	while not g.is_over():
		act(g, bold)
		g.end_month()


static func act(g: RuGame, bold := false) -> void:
	_trade(g)
	if g.vouchers.issued:
		_vouchers_and_auctions(g, bold)
	_protect(g)
	_buyout(g)


static func _trade(g: RuGame) -> void:
	if g.sess.month_index == SECOND_CONTACT_MONTH:
		g.trading.add_contact("grain_tonnes")
	for good in g.trading.goods():
		var n: int = g.trading.sellable(good)
		if n > 0:
			g.trading.sell_market(good, n)
	# put most of the cash to work in the best margin we can reach
	var best := ""
	var best_margin := 0.0
	for good in g.trading.goods():
		if g.trading.has_contact(good) and g.trading.profit_margin(good) > best_margin:
			best = good
			best_margin = g.trading.profit_margin(good)
	if best == "":
		return
	var budget: int = int(float(g.ledger.rub) * (0.5 if g.vouchers.issued else 0.9))
	var qty: int = mini(g.trading.quota(best), budget / maxi(1, g.trading.state_price(best)))
	if qty > 0:
		g.trading.buy_state(best, qty)


static func _vouchers_and_auctions(g: RuGame, bold: bool) -> void:
	var price: int = g.vouchers.price_rub()
	var spend: int = int(float(g.ledger.rub) * VOUCHER_SHARE)
	var n: int = spend / maxi(1, price)
	if n > 0:
		g.vouchers.buy(n)
	var lots: Array = g.auctions.open_this_month()
	lots.sort_custom(func(a, b): return int(a["reserve"]) < int(b["reserve"]))
	_rig_one(g, lots, bold)
	for lot in lots:
		var reserve: int = int(lot["reserve"])
		var have: int = g.vouchers.player_vouchers
		if have >= reserve:
			g.auctions.place_player_bid(str(lot["id"]), mini(have, reserve * MAX_BID_MULTIPLE), 0)
			return  # one lot at a time: the vouchers are committed


## When it holds enough vouchers to bid for the cheapest lot and still has the cash, pay the property fund a quarter
## of the sure price (about a one in four chance) to strike a rival off it. A failed bribe draws the prosecutors.
static func _rig_one(g: RuGame, lots: Array, bold: bool) -> void:
	if lots.is_empty():
		return
	var lot: Dictionary = lots[0]
	var id: String = str(lot["id"])
	var cost: int = g.auctions.bribe_cost(id) / 4
	if (bold or g.vouchers.player_vouchers >= int(lot["reserve"])) and cost > 0 and g.ledger.rub > 12 * cost / 10:
		g.auctions.bribe(id, "property_fund", cost)


static func _protect(g: RuGame) -> void:
	for e in g.registry.owned_by(Ru.PLAYER):
		if not g.brotherhood.is_protected(e.id) and g.ledger.rub > 10 * g.brotherhood.tribute_rub(e.id):
			g.brotherhood.buy_roof(e.id)
		if g.brotherhood.demand_bp(e.id) > 0:
			g.brotherhood.pay_off(e.id)


static func _buyout(g: RuGame) -> void:
	for p in g.buyout.pending():
		g.buyout.fund_insider_purchase(str(p["id"]))
	for e in g.registry.available():
		if g.buyout.option_bp(e.id) > 0:
			g.buyout.exercise_option(e.id)
	var level: float = g.ledger.price_level()
	for e in g.registry.available():
		var bribe: int = int(float(e.director_price_rub) * level * 1.5)
		if bribe > 0 and g.ledger.rub > 6 * bribe and e.book_value_rub < 100_000_000:
			if g.buyout.offer(e.director, e.id, bribe).get("accepted", false):
				return
