extends SceneTree
## Renders the game mid-moment for documentation, stepping it at a fixed 60 Hz:
##   -- --chaos=dog --after=3 --out=/tmp/dog.png      a chaos event in progress
##   -- --goal=1.2 --out=/tmp/goal.png                 the celebration after a goal
##   -- --replay=4 --out=/tmp/replay.png               4 s into the goal replay
##   -- --keeper=.5 --out=/tmp/keeper.png              .5 s after a forced keeper dive
##   -- --pause --out=/tmp/pause.png                   the time-out menu on the matchup row
## Set SEED=n to pick which reaction shots (scorer, coaches, fans) a replay gets.
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	seed(int(OS.get_environment("SEED")) if OS.has_environment("SEED") else 7)
	var kind := ""
	var after := 3.0
	var out := "user://capture.png"
	var teams := 1
	var goal := -1.0
	var replay := -1.0
	var three := false
	var keeper := -1.0
	var pause := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--chaos="): kind = arg.trim_prefix("--chaos=")
		elif arg.begins_with("--after="): after = float(arg.trim_prefix("--after="))
		elif arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		elif arg.begins_with("--teams="): teams = int(arg.trim_prefix("--teams="))
		elif arg.begins_with("--goal="): goal = float(arg.trim_prefix("--goal="))
		elif arg.begins_with("--replay="): replay = float(arg.trim_prefix("--replay="))
		elif arg == "--three": three = true
		elif arg.begins_with("--keeper="): keeper = float(arg.trim_prefix("--keeper="))
		elif arg == "--pause": pause = true
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.sound_enabled = false
	game.set_physics_process(false)
	game.set_process(false)
	game.demo = true
	game.team_size = teams
	game.three_way = three
	game.menu = false
	game.sim.chaos.level = 1 if kind != "" else 0
	game.sim.setup(0, false, 725, 120, true, teams, three)
	game.sync_arena()
	game.sim.phase = "play"
	game.sim.chaos.forced = kind
	var factor: float = game.sim.arena_factor
	game.aim_camera(Vector3(0, 0, game.CAMERA_AIM_Z * factor), factor)
	await process_frame
	var dt := 1.0 / 60
	var t := 0.0
	while t < after:
		tick(game, dt)
		t += dt
	if goal >= 0 or replay >= 0:
		# Line up a strike from the edge of the box so the goal has a build-up.
		var s = game.sim
		# Replays only follow late goals, so stage this one in the closing seconds.
		if replay >= 0: s.clock = 12.0
		var shooter: int = 0
		# Blue's goal, in its own frame: c on the line, n into the pitch, t along it.
		var g: Dictionary = s.goals[1]
		var start: Vector2 = g.c + g.n * 11 + g.t * 2.5
		s.owner = shooter
		s.players[shooter].pos = start
		s.players[shooter].human = -1
		s.players[shooter].face = (-g.n - g.t * .12).normalized()
		s.players[shooter].charge = 1.0
		s.power[0] = 100.0
		s.ball = Vector3(start.x - g.n.x, .45, start.y - g.n.y)
		s.pickup_lock = 0.0
		game.replay.clear()
		for i in 50:
			s.owner = shooter
			s.players[shooter].vel = -g.n * 9
			s.players[shooter].pos += -g.n * 9.0 / 60
			tick(game, dt)
		s.owner = shooter
		s.players[shooter].charge = 1.0
		s.shoot_ball(shooter)
		var aim: Vector2 = (g.c - g.n - g.t * 2.2 - Vector2(s.ball.x, s.ball.z)).normalized() * 46
		s.ball_velocity = Vector3(aim.x, 2.5, aim.y)
		s.keepers[1].pos = g.c + g.n * 1.6 + g.t * 2.6
		s.keepers[1].recovery = 3.0
		var guard := 0
		while s.phase == "play" and guard < 240:
			tick(game, dt)
			guard += 1
		var hold := goal if goal >= 0 else 0.0
		t = 0.0
		while t < hold:
			tick(game, dt)
			t += dt
		if replay >= 0:
			while not game.replay.active and s.phase == "goal": tick(game, dt)
			t = 0.0
			while t < replay and game.replay.active:
				tick(game, dt)
				t += dt
	if keeper >= 0:
		var k: Dictionary = game.sim.keepers[0]
		k.dive = .28
		k.recovery = .85
		k.dive_dir = 1.0
		k.vel = 12.0
		t = 0.0
		while t < keeper:
			tick(game, dt)
			t += dt
	if pause:
		game.set_paused(true)
		game.pause_selection = 2
		game.pause_matchup = "3-way"
		game.hud.queue_redraw()
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("CAPTURE ", out)
	quit()

func tick(game, dt: float) -> void:
	game._physics_process(dt)
	game._process(dt)
