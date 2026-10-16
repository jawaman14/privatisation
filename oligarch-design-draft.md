# Working title: **Privatisation** (alt: *Vouchers*, *The Roof*, *Ten Thousand Roubles*)

**Russia 1991-2003. Own what the state used to own.**

*Draft v0.1. Built on the Skyrunner engine (Godot 4.7, GDScript, seeded headless sim). Not approved; nothing is built.*

---

## 1. Pitch

December 1991: the USSR dissolves. Every factory, mine, refinery, shipyard, port and TV station in the country belongs
to a state that no longer exists. Over the next decade it is sold, given away, stolen and fought over. You start as a
mid-level insider (a Komsomol business-club graduate, a factory deputy director, a foreign-trade clerk, or an
ex-KGB officer) with a flat, a telephone and a handful of vouchers. You can end as the man the Kremlin has to call,
or as a corpse in a lift, or in a cell in 2003.

It is the Skyrunner loop (build an organisation, move product and cash, buy protection, outlast the law) moved from a
Caribbean smuggling coast to the largest asset sale in history.

**Tone:** grim, darkly funny, period-accurate. Not a power fantasy: every fortune is built on people who lose their jobs,
their savings or their lives, and the game keeps score of that.

**Fictional content rule (inherited from Skyrunner):** real *institutions* and *events* (KGB, FSB, RUBOP, GKI, the voucher
scheme, loans-for-shares, the 1998 default) appear as the historical backdrop. Named *people* (oligarchs, ministers,
gangsters) are fictional composites. Companies are fictional stand-ins with real-sector flavour (a "Northern Nickel
Combine", not Norilsk Nickel).

## 2. Player fantasy and goals

- **Goal:** by Jan 2004 hold the largest empire you can *and still be free and alive*. Score = net worth + political
  cover + what you still hold, minus bodies and unpaid wages.
- **Anti-goal:** a game that is just "number go up". Every acquisition has a victim, a rival and a clock.
- **Non-goal:** a Russian-history lecture. History is the board, not the lesson. A codex explains each real event.
- **Non-goal (v1):** flight sim. The flight model is dormant (see section 9).

## 3. Timeline (the story mode's chapters)

Each chapter unlocks a system, as Skyrunner does. Historically anchored events are fixed; how they hit you is not.

| # | Years | Chapter | Real backdrop | New system unlocked |
|---|---|---|---|---|
| 1 | 1991-92 | **The Cooperative** | Late-USSR cooperatives, Komsomol "youth centres", state-to-private commodity arbitrage, Gaidar price liberalisation (Jan 1992) | Trading, cash, kiosks, first crew |
| 2 | 1992-93 | **Vouchers** | Voucher privatisation: 10,000-rouble vouchers to every citizen, voucher auctions, "Option 2" managers' buyouts (51% to insiders) | Voucher buying, auctions, factory takeover |
| 3 | 1993 | **The Roof** | Racketeering ("krysha"), Solntsevo/Izmailovo-style brigades, RUBOP formed, Oct 1993 parliament crisis | Protection, gang war, the Brotherhood |
| 4 | 1993-94 | **The Ministry** | KGB broken up into SVR / FSK (later FSB) / FSO; ex-officers go private (security firms) | The Service, kompromat, security staff |
| 5 | 1994-95 | **Banks** | MMM-style pyramids, the interbank crisis (Black Tuesday, Oct 1994), the first Chechen war | Own bank, deposits, state accounts |
| 6 | 1995 | **Loans for Shares** | Rigged auctions of the best state oil/metal stakes to insider banks | The big auction (set-piece) |
| 7 | 1996 | **The Election** | Yeltsin's re-election, media-for-support pact among bankers | Media, campaign financing |
| 8 | 1996-97 | **Bankers' War** | Svyazinvest-type fight among former allies | Oligarch-vs-oligarch war |
| 9 | 1997-98 | **Shares and Shadows** | Asian crisis, GKO bubble, asset stripping, transfer pricing, tax offshore | Offshore, stripping, minority-shareholder fights |
| 10 | Aug 1998 | **Default** | 17 Aug default and rouble collapse, banks fail | Crisis set-piece (survive or buy cheap) |
| 11 | 1999-2000 | **The Successor** | Yeltsin's resignation, new security-service-friendly regime, "equidistance" ends | Loyalty tests, the Deal |
| 12 | 2000-03 | **Equidistance** | Oligarchs told to stay out of politics; tax raids; first arrests | Endgame: exile, deal, fight or fold |

*(Chapter list is my draft, to be argued over. 12 matches Skyrunner's structure.)*

## 4. Core loop

A **turn-based-ish real-time strategy at the desk** (Skyrunner's "boss's desk" and task-force desk, not the 3D flight view), plus **on-foot/in-car set pieces** for the moments that matter (auctions, meetings, hits, raids).

1. **Find an asset.** Map of Russia's industrial regions and a city district view. Each asset has book value, real
   value, workforce, debts, current owners, "who must be paid" (director, governor, regional property fund, the local gang).
2. **Choose a means.** Legal, grey, or illegal (section 5).
3. **Pay the price in money, people, favours and exposure.**
4. **Hold it.** Rivals, raiders, tax police, wage arrears, strikes, the roof's price rise.
5. **Make it pay.** Run it straight, strip it (sell inventory, export raw material through your own trader at below-market price), or flip it.
6. **Convert profit into cover.** Banks, media, officials, security. Cover buys the next asset.

## 5. Means of acquisition

**Legal / semi-legal**
- Buy workers' vouchers cheaply (they sold them for bottles and rent money; accurate and ugly).
- Voucher auctions; managers' buyout (Option 2) by bribing or co-opting the director.
- Cash auctions and investment tenders (promise an investment; ignore it).
- Buy debt: acquire a company's arrears and call them in.
- Shareholder meetings: proxy fights, share dilution, additional share issues.

**Illegal / grey**
- **Bribes** (officials, regional property funds, auction organisers).
- **Rigged auctions:** disqualify rivals on a technicality; a "competitor" is blocked at the door.
- **Raiding** ("reiderstvo"): forged documents, a friendly court, a masked "security" team arrives to take the
  office, the seal and the register of shareholders.
- **Intimidation and violence:** threats, arson, beating, contract killing. Each leaves heat and a witness.
- **Kompromat:** collect and trade compromising material (a Skyrunner "informant/wiretap" mirror).
- **Asset stripping / tunnelling** and **transfer pricing** to bleed a company into a shell.
- **Tax evasion, offshore schemes** (Cyprus, Channel Islands, Switzerland).

## 6. The factions (map to Skyrunner "powers")

| Skyrunner system | Becomes | Role |
|---|---|---|
| The Family (a Cosa Nostra family, offers may be traps) | **The Brotherhood**: organised-crime groups (Solntsevo/Izmailovo/Uralmash-style, fictional names) | Sells *krysha* (protection). Cheap early, expensive and possessive later. Will happily "protect" you out of your own factory. |
| The Company (covert pipeline that protects you until it does not) | **The Service**: ex-KGB / FSB networks, security firms | Sells information, access to the state, kompromat, legal cover. Loyalty tested in ch. 11-12. |
| Isla Soberana + the General (passage, cheap product) | **Regional barons / governors** | Controls local property funds, courts, police, airports. Cheap local pass; demands tribute and votes. |
| Task force (hunts you) | **Prosecutor General's office, Tax Police, MVD/RUBOP, FSB** (and later the Kremlin itself) | The pursuers. Rules shift per chapter: the 90s pursuers are weak and corruptible; after ch. 11 they become the dominant threat. |
| Federal court | **Arbitration court / criminal court** | Bail, lawyers, "friendly judges", sentence. Reuse the court system. |
| Rival cartel Los Cuervos | **Rival oligarchs and raiders** | AI banker-barons who compete for the same assets. |
| Renown | **Political capital + street reputation** (two bars) | The first buys cover, the second buys fear. Both attract attention. |
| Hired hands (soldiers, drivers, lookouts, accountants, pilots) | **Staff**: bodyguards, lawyers, accountants, lobbyists, enforcers, directors-in-name | Loyalty, wages, can defect or talk. |
| Stash works / hidden vault | **Offshore accounts, cash dens, hidden shell companies** | Where the money hides; exposure raids. |
| Logistics (product, cash, fuel) | **Commodities and cash logistics**: oil, metals, grain, timber, cash in suitcases across the border | Routes, checkpoints, customs, export quotas, port control. |
| Markets that move with raids/storms | **Rouble, GKO yields, commodity prices, inflation** | Hyperinflation 1992-94, Black Tuesday 1994, the 1998 collapse. |
| The arena (street race/air circuit) | Optional: **auctions as a minigame** (bidding with an audience of thugs) | |

## 7. Structure and systems

- **Macro layer (sim):** a seeded, deterministic simulation (Skyrunner already guarantees replayability). Monthly turns
  with a real-time "week" tick for events; daily for crises.
- **Assets:** ~120 fictional enterprises across oil/gas, metals, aluminium, banking, media, ports, fisheries, timber,
  retail, vodka, airlines, defence plants.
- **Money:** multi-currency (roubles, dollars, offshore balances), inflation curve per year, the voucher market.
- **Heat/exposure meters:** public, press, tax police, prosecutors, the Service, rivals. Each reacts to different actions.
- **People:** named characters with loyalty, price, secrets, and family (use the dialogue system).
- **Violence:** the ground war (squads, car chases) is the Skyrunner engine's existing tactical layer, re-skinned.
- **Time pressure:** auctions have fixed dates; historical events happen on schedule regardless of your actions.
- **Replay variation:** the seed changes which firms exist, who your rivals are, and which scandals break; the macro
  history stays fixed.

**Multiplayer (inherited):** seats are *Oligarch*, *Fixer* (lieutenant), *Enforcer*, *Prosecutor*, *Tax Inspector*,
*Governor*, *Rival Banker*. The AI plays unclaimed seats. Versus mode = oligarchs against each other and against the state.

## 8. Win/lose

- **Ending types:** *Exile* (abroad, rich, can't return), *The Deal* (you hold on by serving the new Kremlin), *Prison*,
  *Dead*, *Underground* (small but free), *Titan* (rare: you are too big and too useful).
- The end screen lists what you took, who lost, and what happened to each.

## 9. What carries over from Skyrunner and what changes

**Keep as-is (configure only):**
- Seeded sim + test harness, determinism rules, switches, parity fixtures style, balance simulators.
- Session layer chain, command handlers, save/load, networking, seats, lobby, dedicated server, voice-as-radio (phone/walkie).
- Hired-hands, loyalty, renown, powers/offers/traps, court, task-force desk, HQ seasons, ground war, wiretaps, informants.
- The phone/dialogue UI (Dialogue Manager scripts), the station desks, the HUD, on-foot walker, car.

**Rework:**
- Map: replace Costa Brava with (a) a **Moscow district map** and (b) a **Russia region map** (Moscow, St Petersburg, Urals,
  Siberian oil/nickel, Volga, Far East port). Needs a new map data format or an abstract node graph.
- Economy: product/cash/fuel become many commodities and a financial system (banks, shares, auctions).
- Assets: new "enterprise" entity with ownership shares, debt, workforce, stripping state.
- Period setting: Soviet/90s Russian visuals, sound and radio.
- Fiction content: all dialogue, names, news, UI strings in Russian-flavoured English (optionally Russian localisation later).

**Dormant / optional (not needed):**
- The 6-DOF flight model and aircraft data. Keep in the repo behind a switch; maybe re-use for Siberian oil-field
  helicopters, a Yak-40 shuttle between regions, or a chapter-10 escape flight.

**New:**
- Auction engine (bidders, bribes, disqualification, shill bids).
- Shareholding / voting / dilution.
- Banking and credit (loans, deposits, interbank, bank runs).
- Currency and inflation.
- Kompromat as a first-class item (collect, hold, trade, leak).
- Raiding mini-system (documents + court + masked security team + register of shareholders).
- Media (own a TV channel; spin; blackout).
- Regional politics (governor elections, Duma votes).
- A historical-event scheduler with player-influenced outcomes.

## 10. What needs to be done (work breakdown)

**Phase 0: Decide (1-2 sessions, with you)**
1. Confirm the scope: single-player story first, multiplayer later? (My default: yes.)
2. Confirm the view: desk-strategy first, 3D set-pieces later? (My default: yes.)
3. Confirm tone and the fictional-people rule.
4. Pick the repo plan: fork Skyrunner into a new repo (my recommendation) or add a mode inside it.

**Phase 1: Fork and strip (engine)**
5. Fork the repo; rename; keep tests green; disable flight, aircraft and Caribbean content behind switches.
6. Register new switches; add new RNG streams (per `docs/DESIGN.md`).
7. Make the sim data-driven for a new theatre: "assets", "regions", "commodities" instead of strips and cays.

**Phase 2: Vertical slice (Chapters 1-2, "Cooperative" + "Vouchers")**
8. Enterprise entity (ownership, workforce, debts, book vs real value).
9. Voucher market and a basic auction engine.
10. Trading/arbitrage loop (state price vs market price, inflation).
11. One district map (Moscow-like city) re-using the city renderer with Soviet-era assets (khrushchyovka blocks,
    Ladas, kiosks). Kenney/KayKit/Quaternius CC0 packs may not fit; budget for new low-poly art.
12. The phone/dialogue UI for your first contacts: a director, a bank clerk, a brigade boss, a KGB major.
13. A balance harness for the slice (Skyrunner's `scripts/balance`).

**Phase 3: The pursuers and protectors (Chapters 3-4)**
14. Re-skin Family -> Brotherhood and Company -> Service (data + dialogue, minimal code).
15. Re-skin task force -> Prosecutor/Tax Police/RUBOP/FSB with era-changing rules.
16. Kompromat and heat meters.

**Phase 4: Finance (Chapters 5-6, 9-10)**
17. Banks, deposits, credit, GKO yields, bank runs.
18. Shareholding, voting, dilution, proxy fights.
19. Loans-for-shares set-piece (a scripted multi-bidder auction with insider rules).
20. Offshore and transfer pricing; stripping.
21. The 1998 crisis scenario.

**Phase 5: Politics and endgame (Chapters 7-8, 11-12)**
22. Media ownership; the 1996 election mini-game.
23. Oligarch AI (rivals with personalities).
24. Endgame logic and endings.

**Phase 6: Polish and content**
25. Period audio (synthesize; do not ship real broadcasts without clearing rights).
26. Art pass; localisation hooks; tutorial; accessibility.
27. Historical codex (short entries on each real event, with sources).
28. Multiplayer seats (Prosecutor, Governor, Rival Banker) and balance.
29. Beta, CI, exports (already exist in the Skyrunner repo).

## 11. Risks and open questions

- **Scope.** The financial layer (shares, banks, auctions) is the biggest new build. Slice first.
- **Historical accuracy vs fun.** Where history is bleak and passive (voucher holders were mostly robbed), the game
  needs agency without whitewashing. Proposal: the cost ledger.
- **Real people.** Using real oligarchs/politicians invites legal and taste problems. Draft uses fictional composites.
- **Sensitivity.** Crime, violence and corruption are central. Treat victims as people; do not glamorise.
- **Art.** The existing art is tropical; the setting needs Soviet-era city, industrial and winter looks.
- **Language.** English only at first; Russian names and some phrases for flavour.
- **Is the map Moscow-only or all of Russia?** Recommendation: Moscow + a handful of regional "scenes", not a full map.
- **Do you want flight at all?** Recommendation: no, in v1.

## 12. Suggested first step

Build the **Chapter 1-2 vertical slice** (about 4 weeks of focused work): one city district, 15 enterprises, vouchers,
auctions, a protection racket, a rival, one pursuer, and the phone UI. If that feels like Skyrunner's boss desk with a
different heart, expand.
