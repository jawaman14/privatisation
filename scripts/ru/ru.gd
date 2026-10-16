class_name Ru
extends RefCounted
## Privatisation (Russia 1991-2003): constants and the one switch for the whole game.
##
## RNG streams (each system draws on its own PyRandom, seed + STREAM_BASE + n; never share one):
##   0 ledger   1 vouchers   2 auctions   3 buyout   4 brotherhood   5 state heat   6 rival 1   7 rival 2
##   8 history  9 trading   10 contacts

static var ENABLED := true

const START_YEAR := 1991
const START_MONTH := 12
const STREAM_BASE := 1001
