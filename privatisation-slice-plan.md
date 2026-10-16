# Privatisation: Chapters 1-2 Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A playable, deterministic, desk-strategy slice of *Privatisation* (Dec 1991 - Dec 1993): trade, buy vouchers, win enterprises at auction or by buyout, buy protection, and dodge a weak-but-growing state.

**Architecture:** Fork Skyrunner into a new repo to inherit its test runner, deterministic RNG (`PyRandom`), `EventBus`, switch registry, dialogue add-on, networking and CI. Build the new game as a NEW headless sim core, `RuSession` in `scripts/ru/`, **not** by editing `Session` (it is welded to flight, aircraft and the Caribbean map). The old sim stays in the repo, untouched, until the slice works; deletion is a later task. UI is a 2D desk (like `scripts/station/`).

**Tech Stack:** Godot 4.7.2, GDScript (warnings are errors), Dialogue Manager add-on, the Skyrunner `tests/` harness (`TestCase`, `check*`).

**Spec:** `oligarch-design-draft.md` (sections 3-7, 9, 10 phases 1-3). Approved defaults from the user: new repo, desk-strategy slice of chapters 1-2 first, fictional people, no flight.

## Global Constraints

- Godot **4.7.2**, GDScript only. **Warnings are errors**: give every local an explicit type when the right side is a Variant.
- **Deterministic:** every random draw is on its own `PyRandom` stream seeded `seed + N`; no global `randi()/randf()`, no clock reads in `scripts/ru/`. `tests/test_switches.gd` scans for this.
- Every new static switch (`static var NAME := true`) is registered in `scripts/sim/switches.gd` (`OPT_IN`).
- **Fictional content only:** no real people or companies. Real *institutions* and *events* (KGB/FSB, RUBOP, voucher scheme, Gaidar price liberalisation) are allowed as backdrop. Enterprise and people names are invented.
- Money is stored as integer **kopecks-equivalent units** (`int`, never float) to keep hyperinflation arithmetic exact; display converts.
- RNG streams for this game start at `seed + 1001` and increase by 1 per system; the table lives in `docs/RU_DESIGN.md`.
- Feature branch + PR into `main`; CI runs the suite.
- Historical numbers are approximate and live in data files (`data/ru/*.json`), never hard-coded in logic.

## Review Focus

- Hyperinflation: 1992 prices rise ~25x in a year. Integer money must not overflow or round to zero; a 12-month compound at the 1992 curve is tested.
- Save then load mid-auction must resume to the identical outcome (RNG state saved).
- An auction with zero bidders, or where the player is the only bidder, must end cleanly (asset to the player at reserve / unsold), not hang.
- The same enterprise cannot be bought twice in one turn, nor bought while a rival's deal on it is pending.
- A rival or contact removed (arrested, dead) while holding a pending offer must not crash the turn.
- The player can reach zero cash with debts; the game must continue (forced sales), not soft-lock.
- Time skip across an event date (e.g. jumping from Sep 1992 to Dec 1992) must still fire the Oct 1992 voucher event exactly once.

---

## File Structure

| Path | Responsibility |
|---|---|
| `scripts/ru/ru.gd` | `class_name Ru`: switches, constants, stream table |
| `scripts/ru/ru_session.gd` | `RuSession`: clock, RNG streams, bus, owns subsystems, `to_dict/from_dict` |
| `scripts/ru/ledger.gd` | `Ledger`: integer money, currencies, inflation |
| `scripts/ru/enterprise.gd` | `Enterprise`: one asset (shares, debt, workforce) |
| `scripts/ru/registry.gd` | `EnterpriseRegistry`: loads `data/ru/enterprises.json`, ownership queries |
| `scripts/ru/vouchers.gd` | `VoucherMarket` |
| `scripts/ru/auction.gd` | `AuctionHouse` |
| `scripts/ru/buyout.gd` | `Buyout` (director deals, "Option 2") |
| `scripts/ru/brotherhood.gd` | `Brotherhood`: protection, tribute, escalation |
| `scripts/ru/state_heat.gd` | `StateHeat`: tax police / RUBOP / prosecutor / Service attention |
| `scripts/ru/rivals.gd` | `RivalBanker` AI |
| `scripts/ru/history.gd` | `History`: dated event scheduler |
| `scripts/ru/chapters.gd` | `Chapters`: goals and scoring for ch. 1-2 |
| `scripts/ru/ui/desk.gd` (+ menus) | 2D desk UI |
| `data/ru/*.json`, `dialogue/ru_*.dialogue` | content |
| `tests/test_ru_*.gd` | one file per system |

---

### Task 1: Fork the repo and keep the baseline green

**Files:**
- Create: new repo directory `C:\Users\BarryBee\privatisation` (copy of tracked Skyrunner files, fresh git history)
- Modify: `project.godot` (`config/name="Privatisation"`), `README.md` (replace with a one-paragraph stub pointing to `docs/RU_DESIGN.md`)
- Create: `docs/RU_DESIGN.md` (copy of the approved design draft, plus the RNG stream table)

**Interfaces:**
- Produces: a repo where `./tools/test.sh` passes unchanged, branch `main` + feature branch `feature/ru-slice`.

- [ ] **Step 1:** `git -C skyrunner archive HEAD | tar -x -C privatisation` (tracked files only; excludes `.git`, `.godot`, `.tools`). `git init`, first commit "import skyrunner engine at <sha>".
- [ ] **Step 2:** Locate a Godot 4.7.2 binary (Windows: set `GODOT` to its path; `tools/get_godot.sh` is Linux-only). Run `$GODOT --headless --import`, then `./tools/test.sh`. Expected: same pass count as the Skyrunner `main` baseline (record it in the commit message). If the baseline is red, stop and report; do not proceed.
- [ ] **Step 3:** Rename project, replace README, add `docs/RU_DESIGN.md`. Delete `skyrunner/` and `skyrunner-godot/` leftover dirs only if the tests do not reference them (check with a grep first).
- [ ] **Step 4:** Re-run the suite; Expected: still green. Commit.

### Task 2: `RuSession` skeleton, clock and save format

**Files:**
- Create: `scripts/ru/ru.gd`, `scripts/ru/ru_session.gd`, `tests/test_ru_session.gd`
- Modify: `scripts/sim/switches.gd` (add `"Ru.ENABLED"` to `OPT_IN`)

**Interfaces:**
- Produces: `class_name Ru` with `static var ENABLED := true`, `const START_YEAR := 1991`, `const START_MONTH := 12`, `const STREAM_BASE := 1001`.
- Produces: `class_name RuSession extends RefCounted` with `var seed: int`, `var bus: EventBus`, `var month_index: int` (0 = Dec 1991), `func _init(opts := {})`, `func year_month() -> Vector2i` (x year, y month), `func advance_month() -> void`, `func rng(stream: int) -> PyRandom` (returns `PyRandom` seeded `seed + Ru.STREAM_BASE + stream`), `func to_dict() -> Dictionary`, `static func from_dict(d: Dictionary) -> RuSession`.

- [ ] **Step 1:** Write failing tests in `tests/test_ru_session.gd`: `test_starts_in_december_1991` (`year_month() == Vector2i(1991,12)`), `test_advance_wraps_year` (after 1 advance == `Vector2i(1992,1)`), `test_streams_are_independent_and_stable` (same seed gives same first draw per stream; two streams differ), `test_round_trip_keeps_month_and_rng_state`.
- [ ] **Step 2:** Run `./tools/test.sh ru_session`. Expected: FAIL (class not found).
- [ ] **Step 3:** Implement per the Interfaces block. `to_dict` stores `seed`, `month_index` and each created stream's `get_state()`.
- [ ] **Step 4:** Run; Expected: PASS; also run `./tools/test.sh switches` (the new switch is registered).
- [ ] **Step 5:** Commit.

### Task 3: Ledger and inflation

**Files:** Create `scripts/ru/ledger.gd`, `data/ru/inflation.json`, `tests/test_ru_ledger.gd`

**Interfaces:**
- Consumes: `RuSession.year_month()`.
- Produces: `class_name Ledger` with `func _init(sess: RuSession)`, `var rub: int`, `var usd: int` (whole units), `func price_level() -> float` (CPI relative to Dec 1991 = 1.0), `func apply_month() -> void` (compounds the month's inflation from `inflation.json`), `func rub_to_usd(amount: int) -> int`, `func can_afford(rub_amount: int) -> bool`, `func spend(rub_amount: int) -> bool` (false, no change, if short), `func earn(rub_amount: int) -> void`.
- `inflation.json`: `{"annual_percent": {"1992": 2500, "1993": 840, "1994": 220}}` (approximate; monthly = annual compounded to 12th root).

- [ ] **Step 1:** Tests: `test_spend_refuses_when_short_and_leaves_balance`, `test_1992_prices_rise_about_26x` (12 `apply_month` from Jan 1992: `price_level()` within 5% of 26.0), `test_no_overflow_across_three_years` (36 months at start cash 10^9: balance is a non-negative int, no NaN).
- [ ] **Step 2-4:** Run to fail; implement with integers for balances and float only for the price index; run to pass.
- [ ] **Step 5:** Commit.

### Task 4: Enterprise entity and registry (15 fictional firms)

**Files:** Create `scripts/ru/enterprise.gd`, `scripts/ru/registry.gd`, `data/ru/enterprises.json`, `tests/test_ru_registry.gd`

**Interfaces:**
- Produces: `class_name Enterprise` fields: `id: String`, `name: String`, `sector: String` (`"metals","oil","food","retail","vodka","port","timber","machinery"`), `region: String`, `book_value_rub: int`, `real_value_rub: int`, `workers: int`, `debt_rub: int`, `director: String`, `owner_shares: Dictionary` (owner id -> basis points, sums to 10000), `state_bp() -> int`, `func sell_shares(from: String, to: String, bp: int) -> bool`.
- Produces: `class_name EnterpriseRegistry` with `func load_from(path: String) -> void`, `func get(id: String) -> Enterprise`, `func owned_by(owner: String) -> Array[Enterprise]`, `func available() -> Array[Enterprise]` (state still holds >0).

- [ ] **Step 1:** Tests: `test_json_loads_15_enterprises_with_valid_shares` (each sums to 10000), `test_sell_shares_moves_basis_points_and_rejects_oversell`, `test_real_value_exceeds_book_for_at_least_half` (the data encodes the undervaluation that drives the game).
- [ ] **Step 2-4:** Run to fail; implement; author the 15 firms (invented names, e.g. "Severny Combine", "Volzhsky Dairy Works"); run to pass.
- [ ] **Step 5:** Commit.

### Task 5: Voucher market

**Files:** Create `scripts/ru/vouchers.gd`, `data/ru/vouchers.json`, `tests/test_ru_vouchers.gd`

**Interfaces:**
- Consumes: `Ledger`, `RuSession.rng()`, `History` event `"vouchers_issued"` (Task 11 emits it; in this task tests emit it directly via `sess.bus.emit`).
- Produces: `class_name VoucherMarket` with `var issued: bool`, `var player_vouchers: int`, `func price_rub() -> int` (market price per voucher; nominal 10,000, market trades below it and drifts per `vouchers.json`), `func buy(count: int) -> bool` (spends rub at `price_rub()`, fails if not issued or short of cash), `func sell(count: int) -> bool`, `func bundle_for_bid(count: int) -> int` (removes vouchers, returns their nominal total), `func apply_month() -> void`.

- [ ] **Step 1:** Tests: `test_cannot_buy_before_issue`, `test_buy_deducts_price_times_count_and_adds_vouchers`, `test_market_price_stays_below_nominal_in_1992`, `test_sell_returns_cash_and_removes_vouchers`.
- [ ] **Step 2-4:** Fail, implement, pass.
- [ ] **Step 5:** Commit.

### Task 6: Auction house

**Files:** Create `scripts/ru/auction.gd`, `tests/test_ru_auction.gd`

**Interfaces:**
- Consumes: `EnterpriseRegistry`, `VoucherMarket`, `Ledger`, `RivalBanker.bid(enterprise, sess) -> int` (Task 9; stub in tests).
- Produces: `class_name AuctionHouse` with `func schedule(enterprise_id: String, month_index: int, bp_offered: int, reserve_vouchers: int) -> void`, `func open_this_month() -> Array[Dictionary]` (`{id, bp, reserve}`), `func place_player_bid(id: String, vouchers: int, cash_rub: int) -> bool`, `func bribe(id: String, official: String, rub: int) -> Dictionary` (`{ok, risk}`; may disqualify a named rival), `func resolve(id: String) -> Dictionary` (`{winner, price, bp}`; emits bus `"auction_won"` / `"auction_lost"`; on zero bids the lot is re-listed next month).

- [ ] **Step 1:** Tests: `test_highest_bid_wins_and_shares_transfer`, `test_zero_bidders_relists_next_month`, `test_player_sole_bidder_pays_reserve_only`, `test_bribe_can_disqualify_a_rival_and_adds_heat`, `test_resolve_twice_is_a_noop_second_time`.
- [ ] **Step 2-4:** Fail, implement, pass.
- [ ] **Step 5:** Commit.

### Task 7: Director buyout ("Option 2")

**Files:** Create `scripts/ru/buyout.gd`, `tests/test_ru_buyout.gd`

**Interfaces:**
- Produces: `class_name Buyout` with `func offer(director_id: String, enterprise_id: String, bribe_rub: int) -> Dictionary` (`{accepted, bp}`; acceptance probability depends on bribe vs the director's `price`, loyalty and `StateHeat`), `func fund_insider_purchase(enterprise_id: String) -> bool` (insiders take 51% = 5100 bp with the player financing; player gets a side-deal option on the shares), `func pending() -> Array[Dictionary]`.
- Consumes: `EnterpriseRegistry`, `Ledger`, `StateHeat.add(kind, amount)`.

- [ ] **Step 1:** Tests: `test_accepted_buyout_moves_5100bp_to_insiders_and_player_gets_option`, `test_low_bribe_is_refused_and_costs_nothing`, `test_cannot_buyout_an_enterprise_with_a_pending_auction_or_rival_deal`.
- [ ] **Step 2-4:** Fail, implement, pass.
- [ ] **Step 5:** Commit.

### Task 8: Brotherhood (protection) and StateHeat

**Files:** Create `scripts/ru/brotherhood.gd`, `scripts/ru/state_heat.gd`, `data/ru/brotherhood.json`, `tests/test_ru_brotherhood.gd`, `tests/test_ru_state_heat.gd`

**Interfaces:**
- `class_name StateHeat`: `var tax: float`, `var rubop: float`, `var prosecutor: float`, `var service: float` (0-100), `func add(kind: String, amount: float) -> void`, `func apply_month() -> void` (decay + chapter-based enforcement strength from `data`), `func raid_chance() -> float`, `func resolve_raid() -> Dictionary` (`{seized_rub, lost_enterprise: String or ""}`).
- `class_name Brotherhood`: `var standing: float`, `var tribute_bp_per_month: int`, `func buy_roof(enterprise_id: String) -> bool`, `func monthly() -> void` (collects tribute; if standing is high enough it demands a stake in a protected enterprise), `func pay_off(enterprise_id: String) -> bool`, `func refuse(enterprise_id: String) -> Dictionary` (consequence event: arson/beating that hurts `workers` or output).
- Fiction: gang names invented (e.g. "the Tulskaya brigade").

- [ ] **Step 1:** Tests: `test_protected_enterprise_resists_a_rival_raid`, `test_tribute_rises_and_stake_demand_appears_after_standing_threshold`, `test_refusal_has_a_consequence_event`, `test_enforcement_is_weak_in_1992_and_stronger_in_1993` (raid chance monotonic), `test_raid_can_seize_but_never_drives_cash_negative`.
- [ ] **Step 2-4:** Fail, implement, pass.
- [ ] **Step 5:** Commit.

### Task 9: Rival bankers (AI)

**Files:** Create `scripts/ru/rivals.gd`, `data/ru/rivals.json`, `tests/test_ru_rivals.gd`

**Interfaces:**
- `class_name RivalBanker`: `var id: String`, `var cash_rub: int`, `var temperament: String` (`"cautious"|"greedy"|"violent"`), `func bid(e: Enterprise, sess: RuSession) -> int` (vouchers-equivalent in rub; 0 = abstain), `func monthly(sess: RuSession) -> void` (buys vouchers, may bribe/raid by temperament), `var out: bool` (arrested/dead/bankrupt; skipped everywhere).
- Two rivals in the slice.

- [ ] **Step 1:** Tests: `test_same_seed_gives_same_bids`, `test_out_rival_never_bids_and_pending_deals_void_cleanly`, `test_greedy_outbids_cautious_on_same_lot`.
- [ ] **Step 2-4:** Fail, implement, pass.
- [ ] **Step 5:** Commit.

### Task 10: History scheduler and chapters 1-2

**Files:** Create `scripts/ru/history.gd`, `scripts/ru/chapters.gd`, `data/ru/history.json`, `data/ru/chapters.json`, `tests/test_ru_history.gd`

**Interfaces:**
- `class_name History`: `func due(prev_index: int, now_index: int) -> Array[Dictionary]` (all events with `month_index` in `(prev, now]`, each exactly once), events in `history.json`: `{"1992-01":"price_liberalisation","1992-10":"vouchers_issued","1993-10":"parliament_crisis"}`; emits each on the bus as its kind.
- `class_name Chapters`: `func current() -> int` (1 or 2), `func goals() -> Array[Dictionary]` (`{text, done}`), `func score() -> int`; chapter 1 ends Sep 1992 (goal: reach X rub equivalent, hire a first crew), chapter 2 ends Dec 1993 (goal: control N enterprises, survive).

- [ ] **Step 1:** Tests: `test_skip_across_event_date_fires_once`, `test_vouchers_issued_event_sets_market_issued`, `test_chapter_switches_after_sep_1992`.
- [ ] **Step 2-4:** Fail, implement, pass. Wire `RuSession.advance_month()` to call `Ledger.apply_month`, `VoucherMarket.apply_month`, `StateHeat.apply_month`, `Brotherhood.monthly`, each `RivalBanker.monthly`, then `History.due`.
- [ ] **Step 5:** Commit.

### Task 11: Trading and starting loop (chapter 1)

**Files:** Create `scripts/ru/trading.gd`, `data/ru/goods.json`, `tests/test_ru_trading.gd`

**Interfaces:**
- `class_name Trading`: `func state_price(good: String) -> int`, `func market_price(good: String) -> int` (arbitrage gap narrows over 1992), `func buy_state(good: String, qty: int) -> bool` (needs a contact; limited by a quota), `func sell_market(good: String, qty: int) -> bool`, `func profit_margin(good: String) -> float`.
- Gives the player first cash and a reason to meet the director/brigade/major contacts.

- [ ] **Step 1:** Tests: `test_arbitrage_profit_positive_in_early_1992_and_shrinks_by_1993`, `test_quota_blocks_unlimited_buying`, `test_buy_requires_a_contact`.
- [ ] **Step 2-4:** Fail, implement, pass.
- [ ] **Step 5:** Commit.

### Task 12: Desk UI and the four contacts

**Files:** Create `scripts/ru/ui/desk.gd`, `scripts/ru/ui/enterprise_list.gd`, `scripts/ru/ui/auction_panel.gd`, `scenes/ru_desk.tscn`, `dialogue/ru_director.dialogue`, `dialogue/ru_banker.dialogue`, `dialogue/ru_brigade.dialogue`, `dialogue/ru_major.dialogue`, `scripts/main.gd` (add `--game ru` branch that loads `ru_desk.tscn`), `tests/test_ru_ui.gd`

**Interfaces:**
- `Desk` binds a `RuSession` and exposes: month header, cash (rub/usd), voucher count, heat bars, enterprise list (available + owned), open auctions, chapter goals, "End month" button. Buttons call the Task 5-11 commands. Each contact's dialogue file offers the matching action (director: buyout; banker: vouchers/credit; brigade: roof; major: info/heat relief).

- [ ] **Step 1:** UI smoke test: `test_desk_builds_and_end_month_advances` (instantiate scene headless, press end-month, `month_index == 1`); `test_every_dialogue_file_parses` (Dialogue Manager parses all four).
- [ ] **Step 2-4:** Fail, implement, pass; run `$GODOT --path . -- --game ru --smoke 600` and expect `SMOKE OK`.
- [ ] **Step 5:** Commit.

### Task 13: Autoplay bot, balance harness, determinism and CI

**Files:** Create `scripts/ru/ru_bot.gd`, `scripts/ru/ru_balance.gd`, `tests/test_ru_replay.gd`; modify `.github/workflows/*.yml` (add the `--game ru --smoke` step)

**Interfaces:**
- `class_name RuBot`: `func act(sess: RuSession) -> void` (a simple policy: trade early, buy vouchers, bid on top-value lots, buy a roof when heat > threshold).
- `func RuBalance.run(seeds: int) -> Dictionary` (`{win_rate, median_enterprises, bankrupt_rate, died_rate}`), CLI: `$GODOT --headless --script res://scripts/ru/ru_balance.gd -- --seeds 200`.

- [ ] **Step 1:** Tests: `test_same_seed_replays_to_identical_final_state` (two runs of RuBot over 24 months give equal `to_dict()`), `test_bot_survives_most_seeds` (>= 60% reach Dec 1993 alive over 50 seeds), `test_save_load_mid_auction_gives_same_result`.
- [ ] **Step 2-4:** Fail, implement, pass; tune data until the balance run shows win rate 20-60% over 200 seeds. Record results in `docs/RU_BALANCE.md`.
- [ ] **Step 5:** Commit, open PR into `main`.

## Out of scope for this plan (later plans)

Chapters 3-12, banks and shareholding, media, kompromat, 3D scenes, multiplayer seats, art/audio pass, deletion of the Skyrunner flight and Caribbean code, localisation.
