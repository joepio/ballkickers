# GameNight settings

These options are declared over GameNight's typed settings protocol. The phone and lobby assistant discover the same keys, labels, ranges and current values. No game-specific model prompt is required.

| Key | Control and timing | Values | Default |
| --- | --- | --- | --- |
| `seconds` | Match length, s (next match) | 60 to 300 | `120` |
| `matchup` | Matchup (next match) | Auto, 1v1, 2v2, 3v3 | `"Auto"` |
| `run_speed` | Running speed % (live) | 50 to 150 | `100` |
| `shot_power` | Shot speed % (next shot) | 50 to 150 | `100` |
| `ball_friction` | Ball ground friction % (live) | 25 to 200 | `100` |
| `keeper_speed` | Goalkeeper movement % (live) | 50 to 150 | `100` |
| `power_charge` | Passive super charge % (live) | 0 to 300 | `100` |
| `super_shots` | Super shots (next shot) | On / Off | `true` |
| `replays` | Goal replays (next goal) | On / Off | `true` |
| `chaos` | Football chaos events (live) | Off, Some, Lots | `"Some"` |

Running speed affects walking and sprinting, not tackle dash speed. Shot speed affects the next shot, not a ball already in flight. Ground friction changes rolling deceleration. Goalkeeper movement changes lateral movement and diving speed. Passive charge changes the meter's automatic refill; rewards for passes, saves and shots remain. Disabling super shots prevents powered shots without deleting earned charge. Chaos events are described in the README; Off ends a running event (except fireworks already in the air) and stops new ones.

All numeric inputs are integers. Invalid types, unknown keys and values outside the declared range leave the previous value intact. Live options update without restarting; structural options wait for the boundary named in the label. Party choices use GameNight's existing saved configurations and Undo/Keep flow.

The lobby owns seats and controller bindings. These options cannot add human players, remap controllers or write arbitrary engine variables. Renderer/debug internals are not exposed as gameplay controls.

## Verification

The headless settings tests exercise validation and gameplay effects. The public `scripts/test-godot-settings.py` in the GameNight repo also runs the actual game against a real daemon and checks typed updates and Undo. These source checks do not certify older downloaded binaries.

Run `godot --headless --path . --script res://tests/settings.gd`.
