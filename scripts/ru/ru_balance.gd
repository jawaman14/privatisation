class_name RuBalance
extends RefCounted
## Plays N seeded games with RuBot and reports how they go. A change to the economy's numbers should come with
## a run of at least 200 seeds (see docs/RU_BALANCE.md).


## Returns {seeds, stake_rate, median_firms, median_score, median_worth, median_prosecutor_heat, raids_per_game}.
static func run(seeds: int, first_seed := 1000) -> Dictionary:
	var firms: Array = []
	var scores: Array = []
	var worths: Array = []
	var stakes := 0
	var raids := 0
	for i in seeds:
		var g := RuGame.new_game(first_seed + i)
		var raid_count: Array = [0]
		g.sess.bus.subscribe("raid", func(_ev): raid_count[0] += 1)
		RuBot.play(g)
		var owned: int = g.registry.owned_by(Ru.PLAYER).size()
		if owned > 0:
			stakes += 1
		firms.append(owned)
		scores.append(g.chapters.score())
		worths.append(g.chapters.net_worth())
		raids += int(raid_count[0])
		g.dispose()
	return {"seeds": seeds, "stake_rate": float(stakes) / float(maxi(1, seeds)), "median_firms": _median(firms),
		"median_score": _median(scores), "median_worth": _median(worths), "raids_per_game": float(raids) / float(maxi(1, seeds))}


static func _median(values: Array) -> int:
	if values.is_empty():
		return 0
	var v: Array = values.duplicate()
	v.sort()
	return int(v[v.size() / 2])


static func report(r: Dictionary) -> String:
	return "seeds=%d stake_rate=%.0f%% median_firms=%d median_score=%d median_worth=%d raids/game=%.2f" % [
		int(r["seeds"]), float(r["stake_rate"]) * 100.0, int(r["median_firms"]), int(r["median_score"]),
		int(r["median_worth"]), float(r["raids_per_game"])]
