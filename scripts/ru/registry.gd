class_name EnterpriseRegistry
extends RefCounted
## Every enterprise in the game and who owns it.

var _by_id: Dictionary = {}
var _order: Array[String] = []


func load_from(path: String) -> void:
	var data: Variant = Ru.load_json(path)
	var rows: Array = data.get("enterprises", []) if data is Dictionary else []
	for row in rows:
		add(Enterprise.from_dict(row))


func add(e: Enterprise) -> void:
	if not _by_id.has(e.id):
		_order.append(e.id)
	_by_id[e.id] = e


## (Not `get`: Object already has one.)
func by_id(id: String) -> Enterprise:
	return _by_id.get(id, null)


func all() -> Array[Enterprise]:
	var out: Array[Enterprise] = []
	for id in _order:
		out.append(_by_id[id])
	return out


func owned_by(owner: String) -> Array[Enterprise]:
	var out: Array[Enterprise] = []
	for e in all():
		if e.holding(owner) > 0:
			out.append(e)
	return out


## Firms in which the state still holds a stake.
func available() -> Array[Enterprise]:
	var out: Array[Enterprise] = []
	for e in all():
		if e.state_bp() > 0:
			out.append(e)
	return out


## Replace every enterprise with the saved ones (the inverse of to_dict).
func load_dict(d: Dictionary) -> void:
	_by_id.clear()
	_order.clear()
	for row in d.get("enterprises", []):
		add(Enterprise.from_dict(row))


func to_dict() -> Dictionary:
	var rows := []
	for e in all():
		rows.append(e.to_dict())
	return {"enterprises": rows}
