# Prototype validation — 2026-09-28

Godot 4.5.2, Windows, NVIDIA RTX 5070 Ti.

- Simulation regression suite: 22 assertions passed. Includes team composition,
  co-op, power-shot consumption, fast goal crossing, post-goal freeze, rebounds,
  tackle dislodging, controller switching, overtime and golden-goal finish.
- Five seeded full bot matches completed inside 200 simulated seconds each.
  Final scores: 5–4, 4–7, 5–7, 6–7, 2–6. Aggregate: 53 goals, 48 deliberate
  shots, 321 passes, 501 tackles and 6 power shots. Passes can also score.
- Input/lifecycle suite: 13 assertions passed. Reversed opaque host controller
  ordering, missing/stale devices, profile identity, Start pause/resume, host
  pause freezing time, dispose/reprepare and ignoring stale-session commands.
- Real loopback WebSocket test: authentication, settings declaration,
  participation/ready, Back overlay, repeated sessions and clean disconnect exit.
- Rendered 32-second bot match at 1440×810: mean frame time 8.61 ms (~116 FPS),
  95th percentile 10.93 ms. Final frame: 264 draw calls. This includes the
  120 FPS cap and background system load; it is not an uncapped GPU benchmark.
- Visually inspected the menu, play and goal celebration screenshots.

Static stadium geometry is merged by material, reducing initial scene draw
submissions from about 555 to about 250–280. Spectators share one MultiMesh.

Physical controllers were not connected during this run. Their actual button
feel, multi-device focus switching and audible output still need a playtest.
The system audio backend reported an unavailable output format; automated
renders used Godot's Dummy audio driver. Original WAV effects are included.
No Android build, online play, remote publication or GameNight certification
was performed. This is a locally registered, playable prototype.
