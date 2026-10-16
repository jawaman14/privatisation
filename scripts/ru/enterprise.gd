class_name Enterprise
extends RefCounted
## One state enterprise on the block. Ownership is in basis points (10000 = the whole firm).
## Values are in roubles at December 1991 prices; multiply by Ledger.price_level() for today's.

var id: String = ""
var name: String = ""
var sector: String = ""  ## metals, oil, food, retail, vodka, port, timber, machinery
var region: String = ""
var book_value_rub: int = 0  ## what the paperwork says
var real_value_rub: int = 0  ## what it is worth to a buyer who knows
var workers: int = 0
var debt_rub: int = 0
var director: String = ""
var director_price_rub: int = 0  ## what it takes to turn the director
var owner_shares: Dictionary = {"state": 10000}  ## owner id -> basis points


static func from_dict(d: Dictionary) -> Enterprise:
	var e := Enterprise.new()
	e.id = str(d.get("id", ""))
	e.name = str(d.get("name", ""))
	e.sector = str(d.get("sector", ""))
	e.region = str(d.get("region", ""))
	e.book_value_rub = int(d.get("book_value_rub", 0))
	e.real_value_rub = int(d.get("real_value_rub", 0))
	e.workers = int(d.get("workers", 0))
	e.debt_rub = int(d.get("debt_rub", 0))
	e.director = str(d.get("director", ""))
	e.director_price_rub = int(d.get("director_price_rub", 0))
	if d.has("owner_shares"):
		e.owner_shares = {}
		for k in d["owner_shares"]:
			e.owner_shares[str(k)] = int(d["owner_shares"][k])
	return e


func state_bp() -> int:
	return int(owner_shares.get("state", 0))


func holding(owner: String) -> int:
	return int(owner_shares.get(owner, 0))


## Move `bp` basis points from one owner to another. False, and nothing changes, if the seller lacks them.
func sell_shares(from: String, to: String, bp: int) -> bool:
	if bp <= 0 or from == to or holding(from) < bp:
		return false
	owner_shares[from] = holding(from) - bp
	if int(owner_shares[from]) == 0:
		owner_shares.erase(from)
	owner_shares[to] = holding(to) + bp
	return true


func to_dict() -> Dictionary:
	return {"id": id, "name": name, "sector": sector, "region": region, "book_value_rub": book_value_rub,
		"real_value_rub": real_value_rub, "workers": workers, "debt_rub": debt_rub, "director": director,
		"director_price_rub": director_price_rub, "owner_shares": owner_shares.duplicate()}
