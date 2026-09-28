# Goal Rush

A playful, fast 3v3 party football prototype for Godot 4.5.2. Original procedural
stadium, marshmallow athletes, synthesised Foley and arcade ball physics.

## Play

Open `build/GoalRush.exe`. It is a standalone Windows build; no Godot install is
needed. Keep `GoalRush.pck` beside it. Alternatively open `project.godot` in Godot.

Pick 1–4 local players (subject to available devices). Bots fill both teams to
three. Versus alternates humans between teams; Co-op puts up to three humans on
Ember. Two players can share a keyboard. Controllers are assigned first, then
keyboard layouts, and never silently reassigned when disconnected.

| Action | Controller | Keyboard 1 | Keyboard 2 |
|---|---|---|---|
| Move / aim | Left stick / D-pad | WASD | Arrows |
| Shoot; hold to charge, release to kick | X | J | Numpad 1 |
| Pass toward a teammate | A | K | Numpad 2 |
| Tackle / dash | B | L | Numpad 3 |
| Sprint | RT / RB | Shift | Ctrl |
| Switch to teammate near ball | LB | Space | Numpad 0 |
| Pause / resume | Start | Escape / Enter | Escape |
| Menu during pause | Y | Tab | Tab |
| Fullscreen | — | F11 | F11 |

Menu: stick or D-pad up/down selects a row, left/right changes it; A or Start
starts. Clicks also work. F3 shows performance. F12 saves a screenshot to the
source `captures` folder when running from source.

Receiving the ball gives close dribbling control; tap passes and shots keep play moving.
There are no fouls or throw-ins. Rebound walls keep the ball live. Sprint and
tackles spend stamina. Passing, tackling and time fill a team power meter;
holding a shot for at least 0.85 seconds with a full meter releases a powerful
shot that knocks opponents aside. Matches last 1–5 minutes; ties enter golden
goal. Start/Enter instantly rematches after the result.

## GameNight

`tools/register_gamenight.ps1` adds this local build without replacing other
local games. Restart GameNight to refresh the local shelf.

The game implements authenticated WebSocket lifecycle messages and authoritative
host controller frames. Opaque device tokens retain ownership; stale input is
neutral after 250 ms. Managed sessions skip the menu, prepare off-screen, freeze
and hide on host pause, resume the same state, and support repeated sessions.
Back/Select returns to GameNight. Standalone Start is an in-game pause menu.
Party profile names, colours, skin and pixel portraits appear in the HUD.
New players join at the next session (`instant_join: false`). Local multiplayer
only; no online netcode. A managed match automatically rematches after nine seconds.

## Develop

```powershell
./tools/build.ps1
./build/GoalRush.exe -- --demo --stats
```

Simulation and input/lifecycle regression scripts run during the build.
`tools/generate_audio.py` regenerates the six original sound effects.
`-- --demo --capture=E:/path/frame.png --capture-at=12 --exit-at=30` produces
repeatable visual captures and frame statistics. Tests use fixed seeds.

Static stadium geometry is combined by material; 400 spectators use one
MultiMesh. A single orthographic camera keeps all six athletes visible. No
downloaded art, third-party character assets, or heavyweight postprocessing.

This is a first playable prototype, not a certified GameNight release.
Physical multi-controller testing and match balance still benefit from playtests.
