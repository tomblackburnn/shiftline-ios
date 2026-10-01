# Progress

_Last updated: 1 October 2026_

## Build status

- `main` builds for iOS 17+ with Xcode 26 (Debug and Release).
- Unit tests: **131 passing** (Swift Testing, 14 suites).
- UI tests: **4 passing** (XCUITest).
- Verified in the iPhone 17 Pro simulator at 60 fps with six cars, night, rain and full scenery.

## Content

| Item | Count | Target |
|---|---|---|
| Cars | 27 | 20–30 |
| Manufacturers | 7 | 5+ |
| Environments | 10 | 8–12 |
| Track layouts (incl. variants and drag strips) | 34 | multiple per environment |
| Race modes / event types | 14 | 10+ |
| Career tiers | 7 | 5+ |
| Career events | 92 | large pool |
| Rival duels | 18 (6 rivals × 3) | named rivals |
| Championships | 9 | several |
| Achievements | 45 | 30+ |
| Upgrade categories | 15 × 4 levels | multiple |
| Tyre compounds | 5 | 5 |
| Liveries / wheel styles | 9 / 6 | meaningful |
| Tutorials | 7 | 7 |

## Completed systems

- Vehicle physics: bicycle model, friction ellipse, load transfer, ABS with brake-force distribution, open/locked differential coupling, understeer-biased road tyres and loose drift tyres, FWD/RWD/AWD, torque curves, turbo, supercharger, nitrous, gradients, surfaces, weather grip, tyre wear, slipstream, ABS/TC/stability/steering/braking assists, auto-reverse.
- Manual and automatic gearbox with shift-quality rating and precomputed ideal shift points.
- Drag racing: tree, launch window, ratings, foul starts, splits, trap speed, heads-up result, simulated passes.
- Track system: splines and road pieces, projection, checkpoints, sectors, racing line, speed profiles, grid.
- Race session: fixed timestep, laps, sectors, wrong way, track limits, collisions, standings, overtakes, ghosts, timed start boosts (hit the gas on "2") and slipstream slingshots.
- Race modes: circuit, sprint, street, touge, elimination, checkpoint, speed trap, time attack, drift (four formats), endurance, rival duel, championship, free drive, tutorials.
- AI: racing line, braking points, overtaking, defending, avoidance, recovery, personalities, skill-based shifting, drifting (handbrake entries, throttle-held angle, transitions) and tandem lead pacing.
- Garage, dealership (filters, favourites, comparison), upgrades and downgrades, compounds, induction kits, drivetrain conversions, tuning with presets, customisation.
- Career tiers, event requirements, rivals, championships, XP and levels, rewards and bonuses, daily challenges, achievements, statistics, personal bests, device leaderboards, Game Center submission.
- Profiles, versioned saves, backup and corruption recovery.
- Procedural art, chase camera, lighting, weather, particles, skid marks, parallax drag scene.
- Engine, tyre, wind, effects and music synthesis; Core Haptics.
- SwiftUI menus and HUDs for every mode; four steering schemes; pause, restart, results.
- Accessibility: VoiceOver labels and values on race pedals (double-tap latches a held control), pedal buttons, stat bars, upgrade levels and paint swatches (spoken colour names); camera shake follows Reduce Motion.
- Debug menu and launch arguments (credits, levels, unlocks, overlays, telemetry, forced conditions, autopilot, FPS).

## Current work

- Touch controls, haptics and audio are confirmed on device. Tilt steering did not respond on device; it now uses one shared motion manager started on demand and reads the live setting, and needs re-checking.
- Drift medal targets were recalibrated from device play (60 s score attack: 1,020 / 2,100 / 3,600); more scores from better drifters would refine gold.

## Known issues

- The tilt steering fix cannot be exercised in the simulator (no motion sensor); direction may still need inverting on device.
- AI drift scores vary a lot from run to run (a dropped chain costs a whole corner); skill raises the average but a low-skill rival can post a big score.
- Global leaderboards need the 37 boards in `docs/LEADERBOARDS.md` created in App Store Connect; until then results are submitted to boards that do not exist and only the device leaderboards show anything.
- Menus use fixed type sizes: Dynamic Type would need the landscape layouts reworked (a scaling font loses the condensed display face and overflows 402 pt-tall screens).
- Engine audio is synthesised; bundled recordings (`music_<style>.m4a` for music) can replace the procedural soundtrack, but engine samples are not yet supported.

## Next priorities

1. Re-check tilt steering on device.
2. Engine sample playback option.
3. Dynamic Type: scrollable menu layouts that can take larger text.
