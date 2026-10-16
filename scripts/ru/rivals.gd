class_name RivalBanker
extends RefCounted
## An AI oligarch bidding for the same lots as the player. Bids are a share of the lot's book value, scaled by
## temperament and capped by the rival's cash (there is no credit yet). A rival that is `out` (arrested, dead,
## bankrupt) bids on nothing and its pending deals lapse. Duck-typed by AuctionHouse and Buyout:
## `id`, `out`, `bid(enterprise, session)` and `pending_on(enterprise_id)`.

## temperament -> [low, high] share of (book value x price level) offered
const SHARE := {"greedy": [0.20, 0.35], "violent": [0.10, 0.20], "cautious": [0.05, 0.12]}
## temperament -> [low, high] multiple of the auction's reserve offered
const MULTIPLE := {"greedy": [1.3, 2.0], "violent": [1.1, 1.5], "cautious": [1.0, 1.2]}
const TARGET_MONTHS := 3

var sess: RuSession
var registry: EnterpriseRegistry
var id: String = ""
var temperament: String = "cautious"
var cash_rub: int = 0
var out: bool = false
var target: String = ""  ## the firm it is working on now, if any

var _stream: int = 6
var _target_age: int = 0


func _init(sess_: RuSession, registry_: EnterpriseRegistry, id_: String, temperament_: String, cash: int,
		stream: int) -> void:
	sess = sess_
	registry = registry_
	id = id_
	temperament = temperament_
	cash_rub = cash
	_stream = stream


func pending_on(enterprise_id: String) -> bool:
	return not out and target != "" and target == enterprise_id


## With a reserve (what the auction asks at least), the rival offers a multiple of it; without one it offers a
## share of the firm's book value. Never more than its cash.
func bid(e: Enterprise, session: RuSession, reserve_value: int = 0) -> int:
	if out:
		return 0
	if reserve_value > 0:
		var mult: Array = MULTIPLE.get(temperament, MULTIPLE["cautious"])
		var offer: int = int(float(reserve_value) * sess.rng(_stream).uniform(float(mult[0]), float(mult[1])))
		return mini(cash_rub, offer)
	var span: Array = SHARE.get(temperament, SHARE["cautious"])
	var share: float = sess.rng(_stream).uniform(float(span[0]), float(span[1]))
	var level: float = 1.0 if session.ledger == null else session.ledger.price_level()
	return mini(cash_rub, int(float(e.book_value_rub) * level * share))


## One month of the rival's life: its money moves, and it may pick a firm to work on.
func monthly(_session: RuSession) -> void:
	if out:
		target = ""
		return
	var r: PyRandom = sess.rng(_stream)
	cash_rub = maxi(0, cash_rub + int(float(cash_rub) * r.uniform(-0.05, 0.25)))
	if target != "":
		_target_age += 1
		if _target_age >= TARGET_MONTHS:
			target = ""
			_target_age = 0
	elif r.random() < 0.3:
		var open: Array[Enterprise] = registry.available()
		if not open.is_empty():
			target = open[r.randint(0, open.size() - 1)].id
			_target_age = 0


func to_dict() -> Dictionary:
	return {"cash_rub": cash_rub, "out": out, "target": target, "target_age": _target_age}


func load_dict(d: Dictionary) -> void:
	cash_rub = int(d.get("cash_rub", 0))
	out = bool(d.get("out", false))
	target = str(d.get("target", ""))
	_target_age = int(d.get("target_age", 0))
