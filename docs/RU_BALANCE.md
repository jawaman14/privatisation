# Privatisation: balance notes

Run: `$GODOT --headless --path . --script res://tools/ru_balance.gd -- --seeds 200`
The player is `RuBot`, a lazy policy (trades, hoards vouchers, bids on the cheapest lot, never bribes or plans).
It is a floor, not a target: a human who bribes, buys out directors and plays the rivals should beat it.

## 1. Auction reserve factor (2026-10-16)

Target: the lazy bot lands a stake in 20-60% of games.

| `reserve_factor` | stake rate (100 seeds) |
|---|---|
| 1.0 - 1.6 | 100% |
| 2.0 | 88% |
| 2.5 | 38% |
| 3.0+ | 0% |

Chosen: **2.4**, 200 seeds: stake_rate 36%, median firms 0, raids/game 0.02.

Other levers set by hand, not yet swept: rival bid multiples of the reserve (greedy 1.3-2.0, violent 1.1-1.5,
cautious 1.0-1.2), voucher price fraction by year (0.35 / 0.55 / 0.9 of face), trading gap anchors (8x to 1.3x over 36 months),
tax heat 0.5 per owned firm per month, brigade visit chance 12% per unroofed firm per month.

Known gaps: no death or prison outcome yet, so "survival" is not measured; the bot never raises heat, so raids are rare
(0.02 a game) and the state is under-tested by this policy.
