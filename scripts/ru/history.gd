class_name History
extends RefCounted
## The dated events of the real 1992-93 (price liberalisation, the voucher issue, the parliament crisis), read
## from data/ru/history.json. They happen on schedule whatever the player does. History has no memory: the
## caller asks which events fall in a range of months and emits them once.

var _events: Array = []  ## [{month_index, kind, text}]


func _init() -> void:
	var d: Dictionary = Ru.load_json("res://data/ru/history.json")
	for e in d.get("events", []):
		var row: Dictionary = (e as Dictionary).duplicate()
		row["month_index"] = month_index_of(str(row.get("month", "")))
		_events.append(row)


## "1992-10" -> 10 (months since December 1991). -1 if malformed.
static func month_index_of(ym: String) -> int:
	var parts: PackedStringArray = ym.split("-")
	if parts.size() != 2:
		return -1
	return (int(parts[0]) - Ru.START_YEAR) * 12 + (int(parts[1]) - Ru.START_MONTH)


## Events with prev < month_index <= now, oldest first.
func due(prev_index: int, now_index: int) -> Array:
	var out: Array = []
	for e in _events:
		var m: int = int(e["month_index"])
		if m > prev_index and m <= now_index:
			out.append(e)
	out.sort_custom(func(a, b): return int(a["month_index"]) < int(b["month_index"]))
	return out
