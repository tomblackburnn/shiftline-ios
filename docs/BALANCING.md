# Balancing

All numbers below come from the game data and physics (regenerate them from `Data/` and `PerformanceProfile` if values change).

## Performance index and classes

The performance index (PI, 100–999) is measured, not authored: each spec is driven through a short straight-line simulation (0–100 km/h and top speed) and combined with lateral grip at 150 km/h and braking distance from 100 km/h. It is used only for classes, UI and matchmaking — never for physics.

| Class | PI range |
|---|---|
| D | ≤ 329 |
| C | 330–449 |
| B | 450–569 |
| A | 570–689 |
| S | 690–819 |
| X | ≥ 820 |

## Car roster

| Car | Class | PI | Price | Unlock level | hp | 0-100 km/h | Top speed |
|---|---|---|---|---|---|---|---|
| Hayase Pip 1.4 | D | 228 | 9,000 | 1 | 101 | 8.7 s | 179 km/h |
| Hayase Kite S | D | 298 | 11,000 | 1 | 128 | 7.3 s | 196 km/h |
| Norrvik Fjell 2.0T | D | 309 | 12,000 | 1 | 168 | 7.7 s | 203 km/h |
| Brannock Saddleback 350 | D | 240 | 15,000 | 2 | 204 | 7.8 s | 200 km/h |
| Wrenfield Linnet 1.6 | C | 367 | 16,500 | 2 | 121 | 6.5 s | 192 km/h |
| Hayase Tempo Type-Z | C | 446 | 28,000 | 4 | 228 | 6.1 s | 239 km/h |
| Hayase Arc S | C | 434 | 32,000 | 5 | 245 | 5.7 s | 244 km/h |
| Brannock Tempest SS | C | 407 | 34,000 | 5 | 355 | 6.0 s | 258 km/h |
| Veltra Aria 3.0 | C | 443 | 36,000 | 5 | 254 | 5.8 s | 243 km/h |
| Norrvik Saga TR | B | 510 | 40,000 | 6 | 289 | 4.8 s | 253 km/h |
| Wrenfield Merlin | A | 645 | 58,000 | 8 | 240 | 4.3 s | 238 km/h |
| Hayase Zenith R | B | 565 | 60,000 | 9 | 329 | 4.3 s | 267 km/h |
| Brannock Outlaw GT | B | 477 | 64,000 | 9 | 470 | 5.6 s | 291 km/h |
| Kazeru Hikari RS | B | 548 | 66,000 | 10 | 340 | 5.1 s | 275 km/h |
| Veltra Corsa GT | B | 548 | 72,000 | 10 | 399 | 5.0 s | 288 km/h |
| Aurex Brezza Spider | A | 607 | 98,000 | 12 | 420 | 4.3 s | 291 km/h |
| Brannock Goliath X | B | 478 | 108,000 | 14 | 723 | 5.9 s | 322 km/h |
| Veltra Spectre RS | A | 658 | 118,000 | 14 | 579 | 3.3 s | 308 km/h |
| Wrenfield Hawk R | S | 803 | 122,000 | 16 | 360 | 3.7 s | 272 km/h |
| Kazeru Shiden R | A | 669 | 126,000 | 15 | 559 | 3.8 s | 318 km/h |
| Aurex Nova S | S | 695 | 142,000 | 16 | 540 | 3.9 s | 320 km/h |
| Kazeru Tsurugi R | S | 758 | 235,000 | 20 | 689 | 3.0 s | 338 km/h |
| Veltra Vortex | S | 784 | 245,000 | 20 | 659 | 2.8 s | 340 km/h |
| Wrenfield Peregrine | X | 844 | 255,000 | 22 | 520 | 3.5 s | 300 km/h |
| Aurex Serpa V12 | S | 760 | 285,000 | 22 | 740 | 3.8 s | 352 km/h |
| Brannock Leviathan | S | 705 | 620,000 | 28 | 1,020 | 4.6 s | 385 km/h |
| Aurex Fulmine | X | 929 | 850,000 | 30 | 1,110 | 2.4 s | 405 km/h |

Deliberate outliers: the Goliath X and Leviathan are traction-limited drag specialists whose PI understates their quarter-mile pace; the Merlin, Hawk R and Peregrine are light track cars whose grip lifts their class above their power.

## Career tiers

| Tier | Driver level | Previous-tier wins | Class cap | AI base skill | 1st-place prize | Base XP | AI upgrade level |
|---|---|---|---|---|---|---|---|
| Rookie Cup | 1 | – | D | 0.36 | 2,600 | 140 | Stock |
| Street Scene | 3 | 4 | C | 0.46 | 4,200 | 190 | Stock |
| Club Series | 6 | 4 | B | 0.55 | 6,800 | 250 | Street |
| Regional Tour | 10 | 4 | A | 0.63 | 10,500 | 320 | Street |
| Pro Circuit | 15 | 4 | S | 0.71 | 16,500 | 400 | Sport |
| Elite Masters | 21 | 4 | S | 0.79 | 26,000 | 480 | Sport |
| Legend Series | 27 | 4 | X | 0.87 | 42,000 | 580 | Race |

Prize modifiers: ×1.3 for 4+ lap races, ×1.8 for endurance, ×1.6 for rival duels, ×1.2 for special events. Replays pay 75%.

## Rewards

| Result | Credit share | XP share |
|---|---|---|
| 1st / Gold | 100% | 100% |
| 2nd / Silver | 62% | 75% |
| 3rd / Bronze | 45% / 40% | 60% |
| 4th | 32% / 15% (finished, no medal) | 45% |
| 5th–8th | 22%, 15%, 10%, 8% | 35–20% |

Bonuses (scaled by the event's prize): clean race +300, clean overtake +90 each (max 10), perfect shift +50 each (max 15), fastest lap +350, perfect launch +250, new personal best +400, drift combo (chain / 8 when over 2,000), rival defeated +50% of the prize. Difficulty multiplies credits: Rookie 0.8, Amateur 0.9, Pro 1.0, Elite 1.15, Legend 1.3.

Level-ups pay `400 × new level` credits. XP to the next level is `350 + 150 × level`. Tutorials pay 1,000 credits and 120 XP once. Daily challenges pay 2,500–4,500. Championships pay a round prize of 80% of the tier payout per round and a final prize of 100% / 50% / 30% of the championship purse for the top three.

Pacing check: a new player earns roughly 2,000–3,500 per Rookie race, so the first non-starter car (16,500) takes about six races and the Street tier opens after 4–6 Rookie wins.

## Handling and assists

Cars are set up to push wide at the limit rather than spin, so they stay driveable with on/off buttons even with traction and stability control switched off:

- Rear tyres carry 16% more cornering grip than the fronts (tuning balance moves this ±7%).
- Drive torque through an open differential costs only 40% of the cornering grip a locked one does, scaling up with differential lock. A fully spinning driven tyre loses 35% of its cornering grip.
- ABS distributes braking: a cornering tyre gives up braking to keep grip for the turn, the rear first (down to 25%) and the front least (never below 85%). Straight-line stops are unaffected.
- Drift tyres switch all of that off: neutral balance, drive torque couples fully and a spinning tyre loses 50%. Drift events and the drift tutorial put every car on drift tyres.

Rain multiplies grip by 0.78 for every car.

## Boosts

Start boost: the throttle must go down while "2" is showing and stay down to the green. Within 0.5 s of the "2" is a rocket start (+4 m/s² for 1.5 s), later in that beat is a good start (+2.5 m/s² for 1 s), after "1" is a normal start, and holding from before "2" spins the wheels for 0.9 s. Three seconds after the green a rocket start is about 12 m ahead of a normal one and an early start about 10 m behind. AI drivers roll for the same outcomes: a rocket start with probability 10% + 40% × skill, a good start 30% of the time, never an early one.

Slipstream: within 30 m behind another car (and 2.2 m of its line, above 72 km/h) drag falls by up to 35%. Holding the tow fills a charge in 2.5 s (it drains in 1.5 s out of the tow); a full charge fires a slingshot of +3 m/s² for 1.5 s. The rule is the same for every car.

## Upgrade costs

Cost = car price × category weight × level factor (5%, 10%, 18%, 30%), minimum 350 × level, rounded to 50. Race (level 3) needs driver level 6 and Pro (level 4) needs level 12. Example on a 30,000-credit car:

| Category | Street | Sport | Race | Pro |
|---|---|---|---|---|
| Engine | 1,800 | 3,600 | 6,500 | 10,800 |
| Turbo / Supercharger | 1,950 | 3,900 | 7,000 | 11,700 |
| ECU | 750 | 1,500 | 2,700 | 4,500 |
| Exhaust | 600 | 1,200 | 2,150 | 3,600 |
| Intake | 550 | 1,050 | 1,900 | 3,150 |
| Transmission | 1,050 | 2,100 | 3,800 | 6,300 |
| Clutch | 600 | 1,200 | 2,150 | 3,600 |
| Differential | 750 | 1,500 | 2,700 | 4,500 |
| Tyres | 750 | 1,500 | 2,700 | 4,500 |
| Brakes | 750 | 1,500 | 2,700 | 4,500 |
| Suspension | 1,050 | 2,100 | 3,800 | 6,300 |
| Weight Reduction | 1,350 | 2,700 | 4,850 | 8,100 |
| Aero | 1,200 | 2,400 | 4,300 | 7,200 |
| Nitrous | 900 | 1,800 | 3,250 | 5,400 |
| Drivetrain | 900 | 1,800 | 3,250 | 5,400 |

Effects per level: engine +4.5% power, ECU +2% and +120 rpm, exhaust and intake +1.5%, turbo/supercharger kits +8%/+7% boost (stock turbo cars +6%), transmission −12% shift time, clutch −5%, tyres +2.5% grip, suspension +1.2% grip and response, brakes +8%, weight −3%, aero +downforce, nitrous 3–8 s. A fully upgraded car typically rises two or three classes. Removing a level refunds 55% of its price (the same share a sale pays), so a car can be stepped back under a class cap.

Conversions: AWD→RWD at drivetrain level 2; RWD/FWD→AWD at level 3; 6,000 credits.

## AI

| Difficulty | Skill offset | Reward multiplier |
|---|---|---|
| Rookie | −0.30 | 0.80 |
| Amateur | −0.14 | 0.90 |
| Pro | 0 | 1.00 |
| Elite | +0.08 | 1.15 |
| Legend | +0.15 | 1.30 |

Effective skill = tier base + driver offset (−0.05…+0.06, rivals +0.12…+0.15) + difficulty, clamped to 0…1. Skill sets the fraction of the grip limit used in corners (76–92%), braking lateness and shift precision (90–99% of the ideal RPM).

## Expected times

Idealised reference laps (expert pace, dry) for each tier's reference car:

| Tier | Reference car | Velocity Park National (flying lap) | Solano Quayside Sprint | Serpent Ridge Uphill |
|---|---|---|---|---|
| Rookie Cup | Hayase Kite S | 56.8 s | 70.2 s | 92.5 s |
| Street Scene | Brannock Tempest SS | 52.4 s | 65.0 s | 88.5 s |
| Club Series | Norrvik Saga TR | 51.8 s | 63.8 s | 85.9 s |
| Regional Tour | Wrenfield Merlin | 47.5 s | 59.5 s | 81.3 s |
| Pro Circuit / Elite | Aurex Serpa V12 | 44.4 s | 56.8 s | 79.9 s |
| Legend Series | Aurex Fulmine | 41.5 s | 52.4 s | 74.9 s |

Medal targets are derived from these: time attack gold/silver/bronze at 102/107/114% of the reference lap; checkpoint clocks start at 45% of the reference route time with 80% more spread over the checkpoints; speed trap targets at 96/90/83% of the reference speeds; drift targets at 60/35/17 points per second of expected drifting (scaled for sections, chains and tandem), calibrated from play: a 60-second score attack needs 1,020 / 2,100 / 3,600.

Quarter-mile benchmarks from the drag model: Hayase Pip ≈ 17.0 s, Veltra Aria ≈ 14.1 s (manual), Veltra Vortex ≈ 10.5 s, Aurex Fulmine ≈ 9.6 s.
