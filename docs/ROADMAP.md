# Roadmap

Shiftline's single-player game is feature-complete; the roadmap is about depth, feel and going online.

## Near term

- **Device feel pass** — control latency, haptic intensities, tilt calibration, camera zoom per device size.
- **Accessibility** — Dynamic Type in menus (needs scrollable layouts), colour-blind-safe racing line palette, one-handed control layout.
- **Engine samples** — optional recorded engine loops with RPM crossfading, alongside the synthesised voices.

## Content

- Two more environments (a snowbound pass with a low-grip surface and a floodlit stadium drift arena).
- Wet/dry transitions within an event (event-scripted rain onset).
- Additional liveries and wheel designs; livery colour layers.
- A "Legend" post-game season that re-mixes events with harder rivals, without resetting progress.

## Online

The single-player systems were built so online play can reuse them:

- **Leaderboards** — device boards rank every local profile; 37 global Game Center boards (one headline measure per track) are submitted to and opened from Records. They need creating in App Store Connect once (`docs/LEADERBOARDS.md`).
- **Asynchronous competition** — time attack ghosts are compact (`GhostRecording`, ~10 samples/s). Sharing a ghost through Game Center challenges or CloudKit would let players race each other's best laps.
- **Real-time multiplayer** — the simulation is deterministic per step and SpriteKit-free, so a host-authoritative model fits: the host runs `RaceSession`, clients send `PlayerControls` each step and receive `VehicleState` snapshots at 20–30 Hz with interpolation. Heads-up drag racing is the natural first mode (two cars, one straight, results already modelled). Game Center's `GKMatch` is the planned transport. No multiplayer UI is shown until this exists.

## Technical

- Render static track chunks into cached textures to cut draw calls further on older devices.
- Save migration test fixtures for every schema version.
- Performance tests for the physics step and AI in CI.
