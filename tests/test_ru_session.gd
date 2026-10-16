extends TestCase
## RuSession: the clock, the seeded streams and the save format of the Privatisation sim.


func test_starts_in_december_1991() -> void:
	var s := RuSession.new({"seed": 5})
	check_eq(s.year_month(), Vector2i(1991, 12), "the USSR ends in December 1991")
	check_eq(s.month_index, 0, "month zero")


func test_advance_wraps_year() -> void:
	var s := RuSession.new({"seed": 5})
	s.advance_month()
	check_eq(s.year_month(), Vector2i(1992, 1), "December rolls into January")
	for i in 11:
		s.advance_month()
	check_eq(s.year_month(), Vector2i(1992, 12), "twelve months on")


func test_streams_are_independent_and_stable() -> void:
	var a := RuSession.new({"seed": 7})
	var b := RuSession.new({"seed": 7})
	check_eq(a.rng(0).random(), b.rng(0).random(), "same seed, same stream, same draw")
	check(a.rng(1).random() != b.rng(0).random(), "stream 1 is not stream 0")
	var c := RuSession.new({"seed": 8})
	check(c.rng(0).random() != RuSession.new({"seed": 7}).rng(0).random(), "another seed differs")


func test_the_same_stream_is_one_generator() -> void:
	var s := RuSession.new({"seed": 7})
	var first: float = s.rng(2).random()
	var second: float = s.rng(2).random()
	check(first != second, "asking twice continues the stream, it does not restart it")


func test_round_trip_keeps_month_and_rng_state() -> void:
	var s := RuSession.new({"seed": 11})
	s.advance_month()
	s.advance_month()
	s.rng(3).random()
	var d := s.to_dict()
	var t := RuSession.from_dict(d)
	check_eq(t.month_index, 2, "month survives")
	check_eq(t.seed, 11, "seed survives")
	check_eq(t.rng(3).random(), s.rng(3).random(), "the stream carries on from the same point")


func test_it_is_switched_off_by_ru_enabled() -> void:
	Ru.ENABLED = false
	check(not RuSession.available(), "off")
	Ru.ENABLED = true
	check(RuSession.available(), "on")
