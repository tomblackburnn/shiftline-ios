# Architecture

Shiftline is split into a SpriteKit-free simulation core and a presentation layer. Everything that decides outcomes (physics, rules, AI, economy, saves) is plain Swift value types or small `nonisolated` classes that run headlessly in tests and in off-screen championship simulations.

```
            ┌──────────────┐     ┌────────────────┐
  Data/  ──▶│  RaceFactory │────▶│   RaceConfig   │
 (content)  └──────────────┘     └───────┬────────┘
                                         ▼
   ┌────────────┐   fixed 120 Hz   ┌─────────────┐   events   ┌──────────────────┐
   │ VehicleModel│◀────────────────│ RaceSession │───────────▶│ RaceViewModel     │──▶ HUD, audio, haptics
   └────────────┘                  │  + RaceMode │            │ (SwiftUI + scene) │
   ┌────────────┐                  │  + AIDriver │            └──────────────────┘
   │TrackGeometry│◀────────────────└──────┬──────┘
   └────────────┘                         ▼
                                   OutcomeBuilder ──▶ RaceOutcome ──▶ ProgressionRules ──▶ SaveData ──▶ SaveStore
```

## Simulation core

### Physics (`Physics/`)

- **`VehicleSpec`** — the complete physical definition of a car *as driven*: mass, torque curve (peak torque, peak power, redline), gear ratios, drivetrain and AWD split, weight distribution, CG height, tyre grip and compound, brakes, aero drag and downforce, steering, differential lock, suspension balance and stiffness, turbo, supercharger and nitrous.
- **`VehicleState`** — everything that changes while driving: pose, velocity, yaw rate, steering angle, gear, RPM, shift timer, turbo spool, nitrous, wheelspin, axle slide, weight transfer, tyre wear and a per-step `VehicleEvents` set (shifts, blow-off, backfire, limiter, lock-up).
- **`VehicleModel`** — pure functions over the two: `advancing(_:with:on:assists:by:)` integrates one fixed step; `shiftingUp`/`shiftingDown` implement the gearbox and shift-quality rating. It precomputes the ideal upshift RPM per gear (the crossover where the next gear pulls harder) and the traction-limited ideal launch RPM.

The dynamics are a bicycle model. Each axle gets a vertical load (static distribution plus longitudinal weight transfer plus downforce), a lateral force from a simplified Pacejka curve of its slip angle, and a longitudinal force from drive and brakes. Both are limited by a friction ellipse, so a driven axle that is spinning or saturated loses cornering grip — which is what makes RWD rotate under power, FWD push wide and AWD stay composed. Traction control limits drive to the *combined* grip left after cornering; ABS limits braking to the lock threshold; stability control damps excess yaw. At walking pace the model blends to kinematic steering so slip angles never explode.

### Tracks (`Tracks/`, `Data/Tracks.swift`)

Layouts are authored as either closed waypoint loops (centripetal Catmull-Rom, which never loops or cusps) or open road pieces (straights and constant-radius arcs, ideal for switchbacks). `TrackGeometry` resamples either into 2 m samples with tangents, normals, curvature, checkpoints, start/finish and grid slots, and exposes:

- `project(_:near:)` — nearest point on the centreline, searched around a hint index first so hairpins never snap to the wrong leg;
- a **racing line** — lateral offsets relaxed toward neighbour midpoints on a coarse grid (a minimum-curvature approximation) and clamped inside the track;
- `speedProfile(...)` — the fastest speed at each sample for a given grip, downforce and braking deceleration, with a backward braking pass. AI uses this for braking points; the racing-line assist colours it green/yellow/red against the player's speed.

### Race session (`Racing/`, `RaceModes/`)

`RaceSession` owns a race: cars, a fixed 120 Hz timestep with an accumulator (`advance(by:)` runs as many steps as fit, with a spiral-of-death cap, and exposes an interpolation alpha for rendering), countdown, surface contact (road, kerb, run-off, weather, gradient), slipstream, progress (continuous race distance, checkpoints, sectors, laps), wrong-way and stuck detection, track limits, wall and car collisions (impulse-based, restitution and friction, with yaw from off-centre hits), standings and presentation events.

Rules are layered on with the `RaceMode` protocol:

| Implementation | Responsibility |
|---|---|
| `CircuitRaceMode` | Laps, penalties; endurance enables tyre wear |
| `SprintRaceMode` | Point to point (sprint, street, touge, rival duels) |
| `EliminationMode` | Last place out whenever the leader completes a lap |
| `CheckpointMode` | Countdown clock with checkpoint bonuses |
| `SpeedTrapMode` | Trap speeds plus an average-speed zone |
| `TimeAttackMode` | Lap invalidation, sector bests, theoretical best |
| `DriftRaceMode` | Score attack, sections, chain and tandem via `DriftScorer` |
| `PracticeMode` | Free drive |
| `TutorialMode` | Scripted steps whose completion is checked against real driving |

Drag racing uses its own `DragRace` (christmas tree, staging, launch rating, splits, trap) because it is one-dimensional and heads-up, but it drives the same `VehicleModel`.

### AI (`AI/AIDriver.swift`)

Each AI driver steers by pure pursuit towards a lookahead point on the racing line plus a lane offset, and controls speed against its own speed profile (grip used and braking lateness scale with skill). Racecraft adjusts the lane offset: pull out to pass slower cars ahead within an aggression-dependent range, cover the inside when defending on straights, give room when side by side, and lift when boxed in. Inconsistent drivers occasionally misjudge a braking point. Stuck cars reverse out; hopelessly stuck cars are reset to the track. AI shifts manually at a skill-dependent fraction of the ideal RPM, so strong drivers earn perfect shifts too.

### Career and economy (`Career/`)

All rules are pure structs that take a `SaveData` and return an updated copy (or throw a typed error):

- `GarageRules` — starters, buying, selling, upgrades, compounds, induction kits, drivetrain conversions, tuning and customisation;
- `ProgressionRules` — XP curve, tier and event availability with human-readable requirement checks, personal bests, and applying a `RaceOutcome` (records, rivals, statistics, daily challenges, achievements, level-ups);
- `RewardCalculator` — itemised credits and XP;
- `ChampionshipRules` — entry, round scoring, count-back tie-breaks, final prizes;
- `DailyChallengeRules` — three challenges generated from the date;
- `AchievementRules` — data-driven achievements evaluated from the save;
- `RaceFactory` — builds `RaceConfig`s with matchmaking (AI cars chosen near the player's performance but within the event's class cap and restrictions), rivals and physics-derived medal targets (`EventTargets` runs an idealised `ReferenceRun` of a reference car).

`OutcomeBuilder` turns a finished `RaceSession` or `DragRace` into a `RaceOutcome`. Championship drag, time-attack and drift rounds are solo on track; `OffscreenField` (and `DragRace.simulatedPass`) runs every other competitor through the same event headlessly and ranks them by the same score the player gets.

### Persistence (`Persistence/`)

`SaveData` is a single `Codable` value per profile with a schema version, a tolerant decoder (missing keys fall back to defaults) and `migrated()` for upgrades. `SaveStore` writes atomically, keeps the previous good save as a backup, quarantines corrupt files and falls back to the backup and then to a fresh save — it never throws to the UI. Ghosts are stored beside the save. `LocalLeaderboard` ranks personal bests across every profile; `GameCenterService` mirrors them to Game Center when signed in.

## Presentation

- **`GameStore`** (`@Observable`) holds the active profile, applies rules, persists every change and queues races.
- **Scenes** (`Render/`): `RaceScene` builds the chunked track, scenery and cars, runs the chase camera (velocity look-ahead, speed zoom, heading smoothing, shake), lighting and weather overlays, skid marks from a recycled pool, smoke, sparks and speed streaks. `DragScene` is side-on with parallax layers. Both call back into their view model every frame; view models advance the simulation, turn events into banners, audio and haptics, and publish a HUD snapshot at 30 Hz.
- **Art** is procedural (`CarArtist`, `SceneryArtist`) and cached, so customisation and liveries are reflected everywhere without shipping image assets.
- **Audio** (`Audio/`) synthesises engines, tyres and music in `AVAudioSourceNode` render blocks reading lock-free parameter objects written by the game loop.
- **UI** (`UI/`) is SwiftUI with a shared theme, a `NavigationStack` for menus and a full-screen cover for races.

## Conventions

- Logic types are `nonisolated` (the app target uses main-actor default isolation).
- Content lives in `Data/` and is referenced by string IDs; views never hard-code content.
- Every rule change that affects the save goes through a rule struct so it can be tested without UI.
