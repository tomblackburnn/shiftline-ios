# Global leaderboards

Shiftline sends results to Game Center and opens Game Center's leaderboard screen from **Records → Leaderboards → Global Leaderboards**. The code and the Game Center entitlement are in place; the boards themselves have to be created once in App Store Connect.

Each track has one board per headline measure:

- **Best lap** on circuits, from any lap-based mode (race, time attack, endurance, elimination, free drive).
- **Sprint time** on point-to-point routes.
- **Elapsed time** on drag strips.
- **60-second score attack** on the drift venues.

Speed trap, checkpoint and the other drift formats stay on the device leaderboards.

## Setup

1. In App Store Connect, create the app record for bundle ID `com.tomblackburn.shiftline` if it does not exist yet.
2. Open the app's Game Center section and turn Game Center on.
3. Add a **classic** leaderboard for every row in the table below, with:
   - **Leaderboard ID**: exactly as listed (the game submits to these identifiers).
   - **Reference name** and the localised display name: the Name column.
   - **Score format** and **sort order**: as listed.
   - **Score submission type**: Best Score.
4. Build and run on a device signed in to Game Center. Settings → Online shows `Signed in as …` when it is working.

Boards can be tested before release: scores from development builds go to Game Center's sandbox for the signed-in tester.

Times are submitted as whole hundredths of a second (a 1:23.456 lap is sent as `8346`), which is what the elapsed-time format expects. Check the first time that appears on a board: if it reads 100× too long or too short, the format chosen for that board does not match.

## Boards

| Leaderboard ID | Name | Score format | Sort order |
|---|---|---|---|
| `shiftline.velocity_gp.lap` | Velocity Park — Grand Prix · Best Lap | Elapsed Time – To the Hundredth of a Second | Low to High |
| `shiftline.velocity_national.lap` | Velocity Park — National · Best Lap | Elapsed Time – To the Hundredth of a Second | Low to High |
| `shiftline.velocity_gp_rev.lap` | Velocity Park — Grand Prix Reverse · Best Lap | Elapsed Time – To the Hundredth of a Second | Low to High |
| `shiftline.harbour_loop.lap` | Solano Harbour — Dockside Loop · Best Lap | Elapsed Time – To the Hundredth of a Second | Low to High |
| `shiftline.harbour_loop_rev.lap` | Solano Harbour — Dockside Reverse · Best Lap | Elapsed Time – To the Hundredth of a Second | Low to High |
| `shiftline.harbour_yard.lap` | Solano Harbour — Container Yard · Best Lap | Elapsed Time – To the Hundredth of a Second | Low to High |
| `shiftline.harbour_yard.drift` | Solano Harbour — Container Yard · Drift Score (60 s) | Integer | High to Low |
| `shiftline.harbour_sprint.sprint` | Solano Harbour — Quayside Sprint · Sprint Time | Elapsed Time – To the Hundredth of a Second | Low to High |
| `shiftline.neon_expressway.lap` | Neon Meridian — Expressway Loop · Best Lap | Elapsed Time – To the Hundredth of a Second | Low to High |
| `shiftline.neon_expressway_rev.lap` | Neon Meridian — Expressway Outer · Best Lap | Elapsed Time – To the Hundredth of a Second | Low to High |
| `shiftline.neon_downtown.sprint` | Neon Meridian — Downtown Run · Sprint Time | Elapsed Time – To the Hundredth of a Second | Low to High |
| `shiftline.neon_quarter.drag` | Neon Meridian — Harbour Bridge 1/4 · Elapsed Time | Elapsed Time – To the Hundredth of a Second | Low to High |
| `shiftline.ashgrove_foundry.lap` | Ashgrove Works — Foundry Circuit · Best Lap | Elapsed Time – To the Hundredth of a Second | Low to High |
| `shiftline.ashgrove_foundry_rev.lap` | Ashgrove Works — Foundry Reverse · Best Lap | Elapsed Time – To the Hundredth of a Second | Low to High |
| `shiftline.ashgrove_smelter.lap` | Ashgrove Works — Smelter Drift · Best Lap | Elapsed Time – To the Hundredth of a Second | Low to High |
| `shiftline.ashgrove_smelter.drift` | Ashgrove Works — Smelter Drift · Drift Score (60 s) | Integer | High to Low |
| `shiftline.ashgrove_run.sprint` | Ashgrove Works — Rail Yard Run · Sprint Time | Elapsed Time – To the Hundredth of a Second | Low to High |
| `shiftline.mesa_highway.sprint` | Red Mesa — Highway 9 · Sprint Time | Elapsed Time – To the Hundredth of a Second | Low to High |
| `shiftline.mesa_speedrun.sprint` | Red Mesa — Salt Flat Run · Sprint Time | Elapsed Time – To the Hundredth of a Second | Low to High |
| `shiftline.mesa_half.drag` | Red Mesa — Salt Flat 1/2 Mile · Elapsed Time | Elapsed Time – To the Hundredth of a Second | Low to High |
| `shiftline.pines_stage.sprint` | Hollow Pines — Forest Stage · Sprint Time | Elapsed Time – To the Hundredth of a Second | Low to High |
| `shiftline.pines_stage_rev.sprint` | Hollow Pines — Forest Stage Reverse · Sprint Time | Elapsed Time – To the Hundredth of a Second | Low to High |
| `shiftline.ridge_uphill.sprint` | Serpent Ridge — Uphill · Sprint Time | Elapsed Time – To the Hundredth of a Second | Low to High |
| `shiftline.ridge_downhill.sprint` | Serpent Ridge — Downhill · Sprint Time | Elapsed Time – To the Hundredth of a Second | Low to High |
| `shiftline.ridge_summit.sprint` | Serpent Ridge — Summit Run · Sprint Time | Elapsed Time – To the Hundredth of a Second | Low to High |
| `shiftline.coast_road.sprint` | Brightwater Coast — Cliff Road · Sprint Time | Elapsed Time – To the Hundredth of a Second | Low to High |
| `shiftline.coast_road_rev.sprint` | Brightwater Coast — Cliff Road Northbound · Sprint Time | Elapsed Time – To the Hundredth of a Second | Low to High |
| `shiftline.coast_lighthouse.lap` | Brightwater Coast — Lighthouse Loop · Best Lap | Elapsed Time – To the Hundredth of a Second | Low to High |
| `shiftline.kestrel_circuit.lap` | Kestrel Airfield — Taxiway Circuit · Best Lap | Elapsed Time – To the Hundredth of a Second | Low to High |
| `shiftline.kestrel_pad.lap` | Kestrel Airfield — Drift Pad · Best Lap | Elapsed Time – To the Hundredth of a Second | Low to High |
| `shiftline.kestrel_pad.drift` | Kestrel Airfield — Drift Pad · Drift Score (60 s) | Integer | High to Low |
| `shiftline.kestrel_eighth.drag` | Kestrel Airfield — 1/8 Mile · Elapsed Time | Elapsed Time – To the Hundredth of a Second | Low to High |
| `shiftline.kestrel_quarter.drag` | Kestrel Airfield — 1/4 Mile · Elapsed Time | Elapsed Time – To the Hundredth of a Second | Low to High |
| `shiftline.kestrel_half.drag` | Kestrel Airfield — 1/2 Mile · Elapsed Time | Elapsed Time – To the Hundredth of a Second | Low to High |
| `shiftline.kestrel_kilometre.drag` | Kestrel Airfield — Standing Kilometre · Elapsed Time | Elapsed Time – To the Hundredth of a Second | Low to High |
| `shiftline.oldtown_circuit.lap` | Castellane Old Town — Citadel Circuit · Best Lap | Elapsed Time – To the Hundredth of a Second | Low to High |
| `shiftline.oldtown_sprint.sprint` | Castellane Old Town — Market Dash · Sprint Time | Elapsed Time – To the Hundredth of a Second | Low to High |

The list comes from `GlobalLeaderboards.all` in `Shiftline/Career/GlobalLeaderboards.swift`; adding a track adds its board there automatically, and the board then needs creating here too.
