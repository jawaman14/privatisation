class_name Desk
extends Control
## The Privatisation desk: one screen, built in code around a RuGame. Left, the enterprises; middle, what you can
## do; right, how you stand and what has happened. Every button calls a public `do_*` method, so the tests (and a
## future gamepad or network seat) drive the same paths a click does.

const MONTHS := ["", "January", "February", "March", "April", "May", "June", "July", "August", "September",
	"October", "November", "December"]
const LOG_KEEP := 80
const ALL_EVENTS := "*"

var game: RuGame = null

var _selected: String = ""
var _log: Array[String] = []
var _contacts: Dictionary = {}

var _header: Label
var _status: Label
var _goals: Label
var _log_view: RichTextLabel
var _list: ItemList
var _end_button: Button
var _good_picker: OptionButton
var _ids: Array[String] = []


func _ready() -> void:
	if game == null:
		var seed_: int = 1
		var args: PackedStringArray = OS.get_cmdline_user_args()
		var i: int = args.find("--seed")
		if i >= 0 and i + 1 < args.size():
			seed_ = int(args[i + 1])
		bind(RuGame.new_game(seed_))


func bind(g: RuGame) -> void:
	game = g
	_contacts = (Ru.load_json("res://data/ru/contacts.json") as Dictionary).get("contacts", {})
	game.sess.bus.subscribe(ALL_EVENTS, _on_event)
	_build()
	refresh()


# ------------------------------------------------------------------ reading state
func header_text() -> String:
	var ym: Vector2i = game.sess.year_month()
	var text: String = "%s %d - Chapter %d: %s" % [MONTHS[ym.y], ym.x, game.chapters.current(), game.chapters.title()]
	if game.is_over():
		text += " - Final score: %d" % game.chapters.score()
	return text


func log_lines() -> Array[String]:
	return _log


func enterprise_ids() -> Array[String]:
	return _ids


func selected() -> String:
	return _selected


func select(id: String) -> void:
	if game.registry.by_id(id) == null:
		return
	_selected = id
	refresh()


# ------------------------------------------------------------------ the month
func end_month_pressed() -> void:
	if game.is_over():
		return
	game.end_month()
	if game.is_over():
		say("The year is 1993's end. The score is %d." % game.chapters.score())
	refresh()


# ------------------------------------------------------------------ trade and vouchers
func do_trade_buy(good: String, qty: int) -> void:
	if game.trading.buy_state(good, qty):
		say("Bought %d x %s." % [qty, game.trading.good_name(good)])
	else:
		say("Cannot buy %d x %s: no contact, no quota left, or no cash." % [qty, game.trading.good_name(good)])
	refresh()


func do_trade_sell_all(good: String) -> void:
	var n: int = game.trading.sellable(good)
	if n > 0 and game.trading.sell_market(good, n):
		say("Sold %d x %s on the street." % [n, game.trading.good_name(good)])
	else:
		say("Nothing of %s has arrived to sell." % game.trading.good_name(good))
	refresh()


func do_buy_vouchers(n: int) -> void:
	if game.vouchers.buy(n):
		say("Bought %d vouchers at %d roubles." % [n, game.vouchers.price_rub()])
	else:
		say("No vouchers to be had: not issued yet, or you cannot pay.")
	refresh()


func do_sell_vouchers(n: int) -> void:
	if game.vouchers.sell(n):
		say("Sold %d vouchers." % n)
	else:
		say("You do not hold %d vouchers." % n)
	refresh()


# ------------------------------------------------------------------ the selected enterprise
func do_bid() -> void:
	var lot: Dictionary = _open_lot(_selected)
	if lot.is_empty():
		say("No auction for that firm this month.")
	else:
		var reserve: int = int(lot["reserve"])
		var have: int = game.vouchers.player_vouchers
		if have < reserve or not game.auctions.place_player_bid(_selected, mini(have, reserve * 3), 0):
			say("You need at least %d vouchers to bid; you hold %d." % [reserve, have])
		else:
			say("Bid placed on %s." % _name(_selected))
	refresh()


func do_bribe_official() -> void:
	var e: Enterprise = game.registry.by_id(_selected)
	if e == null or _open_lot(_selected).is_empty():
		say("There is no auction to rig.")
	else:
		var rub: int = int(float(e.real_value_rub) * 0.01 * game.ledger.price_level())
		var res: Dictionary = game.auctions.bribe(_selected, "property_fund", rub)
		say("The property fund official takes the envelope. %s" % ("A rival is quietly struck off." if res["ok"] else "It goes nowhere, and people noticed."))
	refresh()


func do_buyout() -> void:
	var e: Enterprise = game.registry.by_id(_selected)
	if e == null:
		say("Pick a firm first.")
	else:
		var bribe: int = int(float(e.director_price_rub) * game.ledger.price_level() * 1.5)
		var res: Dictionary = game.buyout.offer(e.director, e.id, bribe)
		say("%s: %s" % [e.director, "agreed. The insiders will take 51%% if you fund it." if res["accepted"] else str(res["reason"])])
	refresh()


func do_fund() -> void:
	say("The insiders' purchase is funded." if game.buyout.fund_insider_purchase(_selected) else "There is no deal to fund there, or no cash for it.")
	refresh()


func do_exercise() -> void:
	say("You take your option." if game.buyout.exercise_option(_selected) else "You hold no option on that firm.")
	refresh()


func do_roof() -> void:
	say("Sasha's people will look after %s." % _name(_selected) if game.brotherhood.buy_roof(_selected) else "You cannot put a roof over that.")
	refresh()


func do_payoff() -> void:
	say("You pay them off." if game.brotherhood.pay_off(_selected) else "They are not asking, or you cannot pay.")
	refresh()


func do_refuse() -> void:
	var res: Dictionary = game.brotherhood.refuse(_selected)
	say("You send them away." if res.is_empty() else "You refuse. There is a fire at %s." % _name(_selected))
	refresh()


# ------------------------------------------------------------------ the phone
func do_call(contact: String) -> void:
	var c: Dictionary = _contacts.get(contact, {})
	if c.is_empty():
		return
	match contact:
		"director":
			if _selected == "":
				_voice(c, "declines")
			else:
				_voice(c, "opens")
				do_buyout()
		"banker":
			if game.vouchers.issued:
				_voice(c, "opens")
				do_buy_vouchers(100)
			else:
				_voice(c, "declines")
		"brigade":
			var e: Enterprise = game.registry.by_id(_selected)
			if e != null and e.holding(Ru.PLAYER) > 0:
				_voice(c, "opens")
				do_roof()
			else:
				_voice(c, "declines")
		"major":
			if game.pay_major(int(float(c["cost_factor"]) * game.ledger.price_level())):
				_voice(c, "opens")
			else:
				_voice(c, "declines")
	refresh()


# ------------------------------------------------------------------ log and refresh
func say(text: String) -> void:
	_log.append(text)
	while _log.size() > LOG_KEEP:
		_log.pop_front()


func _voice(contact: Dictionary, which: String) -> void:
	say("%s: %s" % [str(contact["name"]), str(contact[which])])


func _on_event(ev) -> void:
	var line: String = _describe(ev)
	if line != "":
		say(line)


func _describe(ev) -> String:
	if ev.text != "":
		return ev.text
	var d: Dictionary = ev.data
	match ev.kind:
		"auction_won":
			return "You won %s (%d%% of the shares) for %s roubles." % [_name(str(d["id"])), int(d["bp"]) / 100, _money(int(d["price"]))]
		"auction_lost":
			return "%s went to %s." % [_name(str(d["id"])), str(d["winner"])]
		"buyout_done":
			return "The insiders of %s have bought their 51%%." % _name(str(d["id"]))
		"brotherhood_demand":
			return "The Brotherhood wants %d%% of %s." % [int(d["bp"]) / 100, _name(str(d["id"]))]
		"brotherhood_took_stake":
			return "The Brotherhood took %d%% of %s." % [int(d["bp"]) / 100, _name(str(d["id"]))]
		"brotherhood_retaliation":
			return "%s at %s: %d men lost." % [str(d["event"]).capitalize(), _name(str(d["id"])), int(d["workers_lost"])]
		"raid":
			var lost: String = str(d.get("lost_enterprise", ""))
			return "Raid! %s roubles seized%s." % [_money(int(d["seized_rub"])), "" if lost == "" else ", and %s taken back by the state" % _name(lost)]
		"raid_repelled":
			return "Your roof turned a raid away from %s." % _name(str(d["id"]))
	return ""


func refresh() -> void:
	_header.text = header_text()
	var ledger: Ledger = game.ledger
	var lines: Array[String] = []
	lines.append("Cash: %s roubles  (~%s dollars)" % [_money(ledger.rub), _money(ledger.rub_to_usd(ledger.rub))])
	lines.append("Prices are x%.1f what they were in December 1991" % ledger.price_level())
	lines.append("Vouchers: %d  (street price %d)%s" % [game.vouchers.player_vouchers, game.vouchers.price_rub(), "" if game.vouchers.issued else "  [not issued]"])
	lines.append("Watching you: tax %d  RUBOP %d  prosecutor %d  Service %d" % [game.heat.tax, game.heat.rubop, game.heat.prosecutor, game.heat.service])
	lines.append("Brotherhood standing: %d" % game.brotherhood.standing)
	for g in game.trading.goods():
		if game.trading.has_contact(g) or game.trading.stock(g) > 0:
			lines.append("%s: state %d, street %d, stock %d, quota %d" % [game.trading.good_name(g), game.trading.state_price(g), game.trading.market_price(g), game.trading.stock(g), game.trading.quota(g)])
	_status.text = "\n".join(lines)
	var gl: Array[String] = ["Goals:"]
	for goal in game.chapters.goals():
		gl.append("[%s] %s" % ["x" if goal["done"] else " ", goal["text"]])
	_goals.text = "\n".join(gl)
	_log_view.text = "\n".join(_log.slice(maxi(0, _log.size() - 14)))
	_refresh_list()
	_end_button.disabled = game.is_over()


func _refresh_list() -> void:
	_list.clear()
	_ids.clear()
	for e in game.registry.all():
		_ids.append(e.id)
		var lot: Dictionary = _open_lot(e.id)
		var mine: int = e.holding(Ru.PLAYER)
		var tag: String = ""
		if not lot.is_empty():
			tag += "  [AUCTION: %d%% for %d vouchers]" % [int(lot["bp"]) / 100, int(lot["reserve"])]
		if mine > 0:
			tag += "  [you: %d%%]" % [mine / 100]
		_list.add_item("%s%s" % [e.name, tag])
		if e.id == _selected:
			_list.select(_ids.size() - 1)


# ------------------------------------------------------------------ helpers
func _open_lot(id: String) -> Dictionary:
	for lot in game.auctions.open_this_month():
		if str(lot["id"]) == id:
			return lot
	return {}


func _name(id: String) -> String:
	var e: Enterprise = game.registry.by_id(id)
	return id if e == null else e.name


static func _money(n: int) -> String:
	var s: String = str(absi(n))
	var out: String = ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


# ------------------------------------------------------------------ building the screen
func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	_header = Label.new()
	_header.add_theme_font_size_override("font_size", 22)
	root.add_child(_header)
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)
	# left: the enterprises
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.3
	cols.add_child(left)
	left.add_child(_label("Enterprises"))
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(func(idx: int): select(_ids[idx]))
	left.add_child(_list)
	# middle: actions
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(mid)
	mid.add_child(_label("Trade"))
	_good_picker = OptionButton.new()
	for g in game.trading.goods():
		_good_picker.add_item(game.trading.good_name(g))
		_good_picker.set_item_metadata(_good_picker.item_count - 1, g)
	mid.add_child(_good_picker)
	mid.add_child(_button("Buy 10 at the state price", func(): do_trade_buy(_picked_good(), 10)))
	mid.add_child(_button("Sell everything that has arrived", func(): do_trade_sell_all(_picked_good())))
	mid.add_child(_label("Vouchers"))
	mid.add_child(_button("Buy 100 vouchers", func(): do_buy_vouchers(100)))
	mid.add_child(_button("Sell 100 vouchers", func(): do_sell_vouchers(100)))
	mid.add_child(_label("The selected firm"))
	mid.add_child(_button("Bid at auction", do_bid))
	mid.add_child(_button("Bribe the property fund", do_bribe_official))
	mid.add_child(_button("Bribe the director (buyout)", do_buyout))
	mid.add_child(_button("Fund the insiders", do_fund))
	mid.add_child(_button("Exercise your option", do_exercise))
	mid.add_child(_button("Buy a roof", do_roof))
	mid.add_child(_button("Pay off a demand", do_payoff))
	mid.add_child(_button("Refuse the Brotherhood", do_refuse))
	mid.add_child(_label("Phone"))
	var phone := HBoxContainer.new()
	mid.add_child(phone)
	for c in ["director", "banker", "brigade", "major"]:
		phone.add_child(_button(c.capitalize(), func(): do_call(c)))
	# right: standing and the log
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	_status = Label.new()
	right.add_child(_status)
	_goals = Label.new()
	right.add_child(_goals)
	_log_view = RichTextLabel.new()
	_log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_log_view)
	_end_button = _button("End the month", end_month_pressed)
	root.add_child(_end_button)


func _picked_good() -> String:
	return str(_good_picker.get_item_metadata(maxi(0, _good_picker.selected)))


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	return l


func _button(text: String, fn: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(fn)
	return b
