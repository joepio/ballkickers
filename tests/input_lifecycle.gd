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
	check(game.humans == 2 and game.dual_stick, "standalone menu defaults to 1v1 dual-controller play")
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
	game.party.handle({"type": "controller_frame", "controllers": [{"controller": "opaque:B", "axes": [32767,0,0,-32767,0,32767], "buttons": 48}]})
	var left: Dictionary = game.read_dual_control(0, 0)
	var right: Dictionary = game.read_dual_control(0, 1)
	check(left.move.x > .9 and right.move.y < -.9 and left.shoot and right.shoot and left.tackle and right.tackle, "host dual sticks and shoulders route independently")
	check(not game.read_dual_control(0, 0).tackle and not game.read_dual_control(0, 1).tackle, "held shoulders only trigger a single dash edge per half")
	check(not left.sprint and not right.sprint and not left.get("pass"), "dual inputs ignore sprint and pass")
	check(game.sim.players[0].name == "Marsh" and game.sim.players[1].name == "Mallow", "profiles keyed by player ID")
	game.party.frame_time -= 300
	check(game.read_control(0).move == Vector2.ZERO and not game.read_control(0).shoot, "stale controller input becomes neutral")
	check(game.read_dual_control(0, 0).move == Vector2.ZERO and not game.read_dual_control(0, 1).shoot, "both dual halves neutralize on stale input")
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
	game.sim.phase = "play"
	game.impact_pause(.033)
	game.impact_pause(.05)
	check(game.hit_stop <= .05, "simultaneous impacts do not stack hit-stop durations")
	var match_time: float = game.sim.clock
	game._physics_process(.025)
	check(game.sim.clock == match_time and game.hit_stop > 0, "brief impact pause freezes simulation")
	game._physics_process(.025)
	game._physics_process(.025)
	check(game.sim.clock < match_time, "simulation resumes immediately after hit-stop expires")
	# Larger modes give each seat one unit, including six-seat hosts.
	game.team_size = 3
	seats.clear()
	var frames := []
	for seat in 6:
		seats.append({"index": seat, "controller": "six:%d" % seat, "occupant": {"kind": "local", "player_id": "seat%d" % seat}})
		frames.append({"controller": "six:%d" % seat, "axes": [32767,0,-32767,0,0,0], "buttons": 48})
	game.party.handle({"type": "prepare", "session": "six", "players": [], "seats": seats})
	game.party.handle({"type": "start", "session": "six"})
	game.party.handle({"type": "controller_frame", "controllers": frames})
	check(game.humans == 6 and game.sim.players.size() == 6, "six GameNight seats create six outfield units")
	for seat in 6:
		var control: Dictionary = game.read_single_control(seat)
		check(control.move.x > .9 and control.shoot, "seat %d uses left stick and shoulders for one unit" % seat)
	game.party.frame_time -= 300
	check(game.read_single_control(5).move == Vector2.ZERO, "sixth seat neutralizes stale input")
	seats.pop_back()
	game.party.handle({"type": "prepare", "session": "five", "players": [], "seats": seats})
	game.party.handle({"type": "start", "session": "five"})
	check(game.humans == 5 and game.sim.players.size() == 6 and game.sim.players[5].human == -1, "five-player GameNight party gets one bot")
	game.free()
	print("INPUT_LIFECYCLE_RESULT ", failures, " failures")
	quit(1 if failures else 0)
