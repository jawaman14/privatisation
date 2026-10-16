class_name RuSession
extends RefCounted
## The Privatisation sim: a monthly clock from December 1991, one seeded stream per system, and a save format.
## Headless and deterministic: no clock reads, no global random draws.

var seed: int = 1
var bus: EventBus
var month_index: int = 0  ## 0 = December 1991
var ledger: Ledger = null  ## set when the game is wired up (see Task 10); systems that need prices read it

var _streams: Dictionary = {}  ## stream number -> PyRandom


func _init(opts := {}) -> void:
	seed = int(opts.get("seed", 1))
	month_index = int(opts.get("month_index", 0))
	bus = EventBus.new()


static func available() -> bool:
	return Ru.ENABLED


## The generator for one system, created on first use and kept: asking again continues it.
func rng(stream: int) -> PyRandom:
	if not _streams.has(stream):
		var r := PyRandom.new()
		r.seed(seed + Ru.STREAM_BASE + stream)
		_streams[stream] = r
	return _streams[stream]


## x = year, y = month (1-12).
func year_month() -> Vector2i:
	var m: int = Ru.START_MONTH - 1 + month_index
	@warning_ignore("integer_division")
	return Vector2i(Ru.START_YEAR + m / 12, m % 12 + 1)


func advance_month() -> void:
	month_index += 1


func to_dict() -> Dictionary:
	var streams := {}
	for k in _streams:
		streams[str(k)] = (_streams[k] as PyRandom).get_state()
	return {"seed": seed, "month_index": month_index, "streams": streams}


static func from_dict(d: Dictionary) -> RuSession:
	var s := RuSession.new({"seed": int(d.get("seed", 1)), "month_index": int(d.get("month_index", 0))})
	var streams: Dictionary = d.get("streams", {})
	for k in streams:
		s.rng(int(k)).set_state(streams[k])
	return s
