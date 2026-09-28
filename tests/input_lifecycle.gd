extends SceneTree
var failures := 0

func check(condition: bool, label: String) -> void:
	if condition: print("PASS: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.sound_enabled = false
	game.party.set_process(false)
	game.party.managed = true
	var profiles := [{"id": "one", "name": "Marsh", "color": "#ffcc33", "skin_color": "#a97052"}, {"id": "two", "name": "Mallow"}]
	var seats := [{"index": 0, "controller": "opaque:B", "occupant": {"kind": "local", "player_id": "one"}}, {"index": 1, "controller": "opaque:A", "occupant": {"kind": "local", "player_id": "two"}}]
	game.party.handle({"type": "prepare", "session": "test", "players": profiles, "seats": seats})
	check(game.paused and not game.menu and not game.host_active, "prepare skips menu and keeps simulation quiet")
	game.party.handle({"type": "start", "session": "test"})
	check(not game.paused and game.humans == 2 and game.host_active, "host start binds two party seats")
	game.party.handle({"type": "controller_frame", "controllers": [{"controller": "opaque:A", "axes": [-32767,0,0,0,0,0], "buttons": 0}, {"controller": "opaque:B", "axes": [32767,0,0,0,0,32767], "buttons": 4}]})
	var p0: Dictionary = game.read_control(0)
	var p1: Dictionary = game.read_control(1)
	check(p0.move.x > .9 and p1.move.x < -.9 and p0.shoot and p0.sprint, "reversed host controller order preserves ownership")
	check(game.sim.players[0].name == "Marsh" and game.sim.players[1].name == "Mallow", "profiles keyed by player ID")
	game.party.frame_time -= 300
	check(game.read_control(0).move == Vector2.ZERO and not game.read_control(0).shoot, "stale controller input becomes neutral")
	game.party.handle({"type": "controller_frame", "controllers": [{"controller": "opaque:A", "axes": [32767,0,0,0,0,0], "buttons": 0}]})
	check(game.read_control(0).move == Vector2.ZERO and game.read_control(1).move.x > .9, "missing device does not borrow another controller")
	game.party.handle({"type": "controller_frame", "controllers": [{"controller": "opaque:B", "axes": [0,0], "buttons": 128}]})
	check(game.paused, "host Start pauses")
	game.party.handle({"type": "controller_frame", "controllers": [{"controller": "opaque:B", "axes": [0,0], "buttons": 0}]})
	game.party.handle({"type": "controller_frame", "controllers": [{"controller": "opaque:B", "axes": [0,0], "buttons": 128}]})
	check(not game.paused, "host Start can resume while simulation is paused")
	game.party.handle({"type": "pause", "session": "test"})
	var clock: float = game.sim.clock
	game._physics_process(1.0)
	check(game.paused and game.sim.clock == clock and not game.host_active, "host pause freezes match")
	game.party.handle({"type": "resume", "session": "test"})
	check(not game.paused and game.host_active, "host resume restores match")
	game.party.handle({"type": "dispose", "session": "test"})
	check(game.paused and not game.host_active and game.effects.is_empty(), "dispose stops simulation and effects")
	game.party.handle({"type": "prepare", "session": "next", "players": profiles, "seats": seats})
	game.party.handle({"type": "start", "session": "next"})
	check(game.party.session == "next" and not game.paused, "same process handles another session")
	game.party.handle({"type": "pause", "session": "test"})
	check(not game.paused, "stale-session commands cannot pause a new match")
	game.free()
	print("INPUT_LIFECYCLE_RESULT ", failures, " failures")
	quit(1 if failures else 0)
