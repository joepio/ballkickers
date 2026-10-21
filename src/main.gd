extends Node3D
const Match = preload("res://src/match.gd")
const Stadium = preload("res://src/stadium.gd")
const Hud = preload("res://src/hud.gd")
const Party = preload("res://src/party.gd")
var settings = preload("res://src/settings.gd").new()
var sim = Match.new()
var stadium = Stadium.new()
var hud = Hud.new()
var chaos_view = preload("res://src/chaos_view.gd").new()
var replay = preload("res://src/replay.gd").new()
var replay_pending := false
var party = Party.new()
var camera := Camera3D.new()
## Perspective broadcast camera for replay close-ups and reaction shots.
var cine := Camera3D.new()
var cine_shot := ""
var coaches: Array = []
var cameramen: Array = []
const CAMERA_PITCH := deg_to_rad(47.0)
const CAMERA_FOV := 30.0
const RISER := 1.2
const SHOT_FOV := {"wide": 34.0, "goalcam": 30.0, "scorer": 36.0, "coach": 40.0, "coach_sad": 40.0, "fans": 11.0}
const CAMERA_DISTANCE := 61.0
const CAMERA_AIM_Z := -.3
## How far the rig slides compared to where it aims; the rest is a slight turn.
const CAMERA_TRUCK := .6
var athletes: Array = []
var keeper_nodes: Array = []
var ball_node: Node3D
var ball_shadow: MeshInstance3D
var effects: Array = []
var menu := true
var menu_selection := 0
## Time-out menu: Resume, New match, then the match settings. The matchup is
## picked here and takes effect with New match.
var pause_selection := 0
var pause_matchup := "Auto"
const MATCHUPS = ["Auto", "1v1", "2v2", "3v3", "3-way"]
var paused := false
var humans := 2
var team_size := 1
## Three players, three teams, three goals on a six-sided arena.
var three_way := false
var team_override := false
var managed_matchup := "Auto"
var coop := false
var dual_stick := true
var match_seconds := 120
var chaos_level := 1
var chaos_force := ""
var sound_enabled := true
var devices: Array = []
var previous: Dictionary = {}
var notice := ""
var notice_time := 0.0
var shake := 0.0
var show_stats := false
var run_time := 0.0
var super_time := 0.0
# Phase and replay state from the last frame: a kickoff or a replay cut puts
# everyone in place at once instead of sliding them back.
var seen_phase := ""
var seen_replay := false
var result_time := 0.0
var hit_stop := 0.0
var demo := false
var capture_path := ""
var capture_at := 4.0
var capture_done := false
var exit_at := 0.0
var sound_players: Array = []
var audio = preload("res://src/sound.gd").new()
var crowd_audio = preload("res://src/crowd_sound.gd").new()
var profile_textures: Dictionary = {}
var host_active := false
var last_activity := 0
var overlay_ready := true
var managed_buttons: Dictionary = {}
var overlay_after := 0
var frame_samples: Array = []

func _ready() -> void:
	print("Ballkickers: loading stadium")
	Engine.max_fps = 120
	for arg in OS.get_cmdline_user_args():
		if arg == "--demo": demo = true
		elif arg.begins_with("--capture="): capture_path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--capture-at="): capture_at = float(arg.trim_prefix("--capture-at="))
		elif arg.begins_with("--exit-at="): exit_at = float(arg.trim_prefix("--exit-at="))
		elif arg.begins_with("--teams="):
			team_size = clampi(int(arg.trim_prefix("--teams=")), 1, 3)
			humans = team_size * 2
			team_override = true
		elif arg == "--three":
			three_way = true
			team_size = 1
			humans = 3
			team_override = true
		elif arg == "--stats": show_stats = true
		elif arg.begins_with("--chaos="): chaos_force = arg.trim_prefix("--chaos=")
		elif arg.begins_with("--chaos-level="): chaos_level = clampi(int(arg.trim_prefix("--chaos-level=")), 0, 2)
		elif arg == "--mute": sound_enabled = false
		elif arg == "--fullscreen": DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	add_child(stadium)
	stadium.build()
	for i in 12:
		var athlete = stadium.make_player(i)
		athlete.scale = Vector3.ONE * 1.16
		athletes.append(athlete)
	for team in 3:
		var keeper = stadium.make_player(6 + team, true)
		stadium.paint_kit(keeper, Stadium.KEEPER_COLORS[team])
		keeper.scale = Vector3.ONE * 1.23
		keeper.get_node("Marker").visible = false
		keeper_nodes.append(keeper)
	for team in 3: coaches.append(stadium.make_coach(team))
	for index in 3: cameramen.append(stadium.make_cameraman(index))
	ball_node = stadium.make_ball()
	chaos_view.stadium = stadium
	chaos_view.game = self
	add_child(chaos_view)
	ball_shadow = stadium.sphere(stadium, Vector3.ZERO, .46, Color("285e50"))
	ball_shadow.scale.y = .015
	add_child(camera)
	add_child(cine)
	cine.fov = 34
	cine.far = 220
	camera.fov = CAMERA_FOV
	camera.far = 260
	camera.current = true
	aim_camera(Vector3(-9, 0, -1), 1.0)
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.game = self
	party.command.connect(on_party_command)
	add_child(party)
	print("Ballkickers: ready; %d local controllers" % Input.get_connected_joypads().size())
	add_child(audio)
	add_child(crowd_audio)
	sound_players = audio.players
	sim.chaos.level = chaos_level
	sim.setup(0, false, 725, 120, dual_stick, team_size, three_way)
	sync_arena()
	if demo:
		menu = false
		sim.setup(0, false, 725, 120, dual_stick, team_size, three_way)
		sim.chaos.forced = chaos_force
		sim.power = [100.0, 100.0]
		aim_camera(Vector3(0, 0, CAMERA_AIM_Z), 1.0)
	if party.managed:
		menu = false
		paused = true

func sync_arena() -> void:
	stadium.resize_pitch(team_size, three_way)
	for i in athletes.size():
		athletes[i].visible = i < sim.players.size()
		if i < sim.players.size():
			athletes[i].position = Match.vec3(sim.players[i].pos)
			stadium.paint_kit(athletes[i], Stadium.TEAM_COLORS[sim.players[i].team])
	for team in keeper_nodes.size():
		keeper_nodes[team].visible = team < sim.teams
		if team < sim.teams: keeper_nodes[team].position = Match.vec3(sim.keepers[team].pos)
	for team in coaches.size(): coaches[team].visible = team < sim.teams

func configure_managed_matchup() -> void:
	if managed_matchup != "Auto":
		three_way = managed_matchup == "3-way"
		team_size = 1 if three_way else int(managed_matchup.left(1))
	elif not team_override:
		var count: int = party.human_seats().size()
		three_way = count == 3
		team_size = 1 if count <= 3 else (2 if count <= 4 else 3)

func reset_replay() -> void:
	if replay.active and not replay.saved.is_empty(): replay.restore(sim)
	replay.active = false
	replay.clear()
	replay_pending = false

func start_match() -> void:
	reset_replay()
	if party.managed:
		configure_managed_matchup()
		humans = party.human_seats().size()
	else:
		devices.clear()
		for id in Input.get_connected_joypads(): devices.append(id)
		devices.append(-1)
		if not dual_stick and not three_way: devices.append(-2)
		humans = mini(humans, devices.size())
	if dual_stick: humans = mini(humans, team_size * 2)
	if coop: humans = mini(humans, team_size * 2)
	if three_way: humans = mini(humans, 3)
	if not party.managed: sim.chaos.level = chaos_level
	sim.setup(0 if demo else humans, coop, int(Time.get_ticks_usec()) % 1000000, match_seconds, dual_stick, team_size, three_way)
	sync_arena()
	apply_profiles()
	menu = false
	paused = false
	previous.clear()
	result_time = 0
	hit_stop = 0.0
	clear_effects()
	audio.reset()
	play_sound("whistle")
	crowd_audio.kickoff()

func _physics_process(dt: float) -> void:
	if party.managed and not host_active: return
	if paused: return
	if replay.active:
		# Replayed impacts freeze the picture too, but only briefly.
		hit_stop = maxf(0, hit_stop - dt)
		replay.advance(sim, dt, replay_event)
		if not replay.active: hit_stop = 0.0
		return
	if hit_stop > 0:
		hit_stop = maxf(0, hit_stop - dt)
		return
	var controls: Dictionary = {}
	if not menu and not demo:
		for h in humans:
			if team_size > 1 and not three_way:
				controls[h] = read_single_control(h)
			elif dual_stick or three_way:
				for half in 2: controls[h * 2 + half] = read_dual_control(h, half)
			else:
				controls[h] = read_control(h)
				if controls[h].get("switch", false):
					sim.switch_player(h)
					apply_profiles()
	var live: bool = sim.phase == "play"
	sim.step(dt, controls)
	if sim.phase == "kickoff": replay.clear()
	elif live and not menu: replay.record(sim)
	if not menu:
		for event in sim.events: handle_event(event)
	if sim.phase == "result":
		result_time += dt
		if menu: sim.setup(0, false, randi(), 120, dual_stick, team_size, three_way)
		elif party.managed and result_time > 9: start_match()
	# Roll the replay once the celebration has had its moment.
	if replay_pending and sim.phase == "goal" and sim.phase_time < 1.0:
		replay_pending = false
		if sim.replays and not menu and replay.worth_showing(sim) and replay.start(sim): play_sound("whistle")

func read_control(h: int) -> Dictionary:
	var move := Vector2.ZERO
	var buttons := 0
	var sprint := false
	if party.managed:
		var record: Dictionary = party.read_seat(h)
		var axes: Array = record.get("axes", [])
		if axes.size() >= 2: move = Vector2(float(axes[0]), float(axes[1])) / 32767.0
		buttons = int(record.get("buttons", 0))
		if axes.size() >= 6: sprint = float(axes[5]) > 8000
		if buttons & (1 << 12): move.x = -1
		if buttons & (1 << 13): move.x = 1
		if buttons & (1 << 10): move.y = -1
		if buttons & (1 << 11): move.y = 1
	else:
		var device: int = devices[h] if h < devices.size() else -99
		if device >= 0 and Input.get_connected_joypads().has(device):
			move = Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
			var mapping := [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]
			for b in mapping.size():
				if Input.is_joy_button_pressed(device, mapping[b]): buttons |= 1 << b
			sprint = Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT) > .2
			if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT): move.x = -1
			if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT): move.x = 1
			if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP): move.y = -1
			if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN): move.y = 1
		elif device == -1:
			move = Vector2(int(Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_A)), int(Input.is_physical_key_pressed(KEY_S)) - int(Input.is_physical_key_pressed(KEY_W)))
			if Input.is_physical_key_pressed(KEY_K): buttons |= 1
			if Input.is_physical_key_pressed(KEY_L): buttons |= 2
			if Input.is_physical_key_pressed(KEY_J): buttons |= 4
			if Input.is_physical_key_pressed(KEY_SPACE): buttons |= 16
			sprint = Input.is_physical_key_pressed(KEY_SHIFT)
		elif device == -2:
			move = Vector2(int(Input.is_physical_key_pressed(KEY_RIGHT)) - int(Input.is_physical_key_pressed(KEY_LEFT)), int(Input.is_physical_key_pressed(KEY_DOWN)) - int(Input.is_physical_key_pressed(KEY_UP)))
			if Input.is_physical_key_pressed(KEY_KP_2): buttons |= 1
			if Input.is_physical_key_pressed(KEY_KP_3): buttons |= 2
			if Input.is_physical_key_pressed(KEY_KP_1): buttons |= 4
			if Input.is_physical_key_pressed(KEY_KP_0): buttons |= 16
			sprint = Input.is_physical_key_pressed(KEY_CTRL)
	if move.length() < .18: move = Vector2.ZERO
	else: move = move.normalized() * minf(1, (move.length() - .18) / .82)
	var before: int = previous.get(h, 0)
	var pressed: int = buttons & ~before
	previous[h] = buttons
	if party.managed:
		if (buttons != 0 or move.length() > .1) and Time.get_ticks_msec() - last_activity > 500:
			last_activity = Time.get_ticks_msec()
			var seat: Dictionary = party.human_seats()[h]
			GameNight.report_activity(int(seat.get("index", -1)))
		if pressed & (1 << 6) and overlay_ready:
			overlay_ready = false
			GameNight.request_overlay()
	return {"move": move.limit_length(), "shoot": bool(buttons & 6), "pass": bool(pressed & 1), "tackle": bool(pressed & 6), "switch": bool(pressed & 16), "sprint": sprint or bool(buttons & 32)}

func read_single_control(h: int) -> Dictionary:
	# A single unit uses left-stick movement; either shoulder shoots/tackles.
	var left := read_dual_control(h, 0)
	var right := read_dual_control(h, 1)
	var action: bool = left.shoot or right.shoot
	var key := "single_%d" % h
	left.tackle = action and not previous.get(key, false)
	left.shoot = action
	previous[key] = action
	return left

func read_dual_control(h: int, half: int) -> Dictionary:
	var move := Vector2.ZERO
	var action := false
	if party.managed:
		var record: Dictionary = party.read_seat(h)
		var axes: Array = record.get("axes", [])
		var axis: int = half * 2
		if axes.size() > axis + 1: move = Vector2(float(axes[axis]), float(axes[axis + 1])) / 32767.0
		action = bool(int(record.get("buttons", 0)) & (1 << (4 + half)))
	else:
		var device: int = devices[h] if h < devices.size() else -99
		if device >= 0 and Input.get_connected_joypads().has(device):
			move = Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X if half == 0 else JOY_AXIS_RIGHT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y if half == 0 else JOY_AXIS_RIGHT_Y))
			action = Input.is_joy_button_pressed(device, JOY_BUTTON_LEFT_SHOULDER if half == 0 else JOY_BUTTON_RIGHT_SHOULDER)
		elif device == -1:
			if half == 0:
				move = Vector2(int(Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_A)), int(Input.is_physical_key_pressed(KEY_S)) - int(Input.is_physical_key_pressed(KEY_W)))
				action = Input.is_physical_key_pressed(KEY_Q)
			else:
				move = Vector2(int(Input.is_physical_key_pressed(KEY_RIGHT)) - int(Input.is_physical_key_pressed(KEY_LEFT)), int(Input.is_physical_key_pressed(KEY_DOWN)) - int(Input.is_physical_key_pressed(KEY_UP)))
				action = Input.is_physical_key_pressed(KEY_CTRL)
	if move.length() < .18: move = Vector2.ZERO
	else: move = move.normalized() * minf(1, (move.length() - .18) / .82)
	var key := "dual_%d_%d" % [h, half]
	var pressed: bool = action and not previous.get(key, false)
	previous[key] = action
	if party.managed and (action or move.length() > .1) and Time.get_ticks_msec() - last_activity > 500:
		last_activity = Time.get_ticks_msec()
		GameNight.report_activity(int(party.human_seats()[h].get("index", -1)))
	return {"move": move.limit_length(), "shoot": action, "tackle": pressed, "pass": false, "sprint": false, "switch": false}

func _process(dt: float) -> void:
	crowd_audio.active = sound_enabled and not paused and not (party.managed and not host_active)
	run_time += dt
	if exit_at > 0 and run_time > 3 and not paused: frame_samples.append(dt * 1000.0)
	if not paused and (not party.managed or host_active):
		notice_time = maxf(0, notice_time - dt)
		super_time = maxf(0, super_time - dt)
		shake = move_toward(shake, 0, dt * 2)
		if hit_stop <= 0:
			update_visuals(dt)
			update_effects(dt)
		stadium.update_board(sim, run_time)
		stadium.crowd.update(dt, menu or (sim.phase == "play" and not sim.chaos.active() and hype_free()))
	var factor: float = sim.arena_factor
	# A fixed broadcast camera high on the near stand that keeps the whole pitch
	# in shot; only the menu frames the stadium off to one side.
	var focus := Vector3(-9.0 * factor if menu else 0.0, 0, CAMERA_AIM_Z * factor)
	var rate := 5.0
	if replay_showing(): direct_replay(dt)
	elif not camera.current:
		camera.current = true
		cine_shot = ""
	var offset := Vector3(sin(run_time * 67) * shake * .12, 0, cos(run_time * 79) * shake * .1)
	var view := camera_offset(factor)
	var rig := Vector3(focus.x * CAMERA_TRUCK, 0, focus.z)
	camera.position = camera.position.lerp(rig + view + offset, 1 - exp(-dt * rate))
	camera.look_at(focus + offset)
	hud.queue_redraw()
	if not capture_done and not capture_path.is_empty() and run_time >= capture_at:
		capture_done = true
		capture.call_deferred()
	if exit_at > 0 and run_time > exit_at:
		frame_samples.sort()
		var mean := 0.0
		for sample in frame_samples: mean += sample
		mean /= maxf(1, frame_samples.size())
		print("BALLKICKERS_METRICS ", JSON.stringify({"fps": Engine.get_frames_per_second(), "mean_frame_ms": mean, "p95_frame_ms": frame_samples[int(frame_samples.size() * .95)] if not frame_samples.is_empty() else 0, "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "objects": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "stats": sim.stats, "score": sim.score}))
		get_tree().quit()

func hype_free() -> bool:
	# The wave only starts while the ball is calmly in midfield.
	return absf(sim.ball.x) < sim.half_x * .55

func update_visuals(dt: float) -> void:
	var snap: bool = (sim.phase == "kickoff" and seen_phase != "kickoff") or replay.active != seen_replay
	seen_phase = sim.phase
	seen_replay = replay.active
	var follow: float = 1.0 if snap else 1 - exp(-dt * 34)
	for team in sim.teams:
		var node: Node3D = keeper_nodes[team]
		var k: Dictionary = sim.keepers[team]
		node.position = node.position.lerp(Vector3(k.pos.x, 0, k.pos.y), follow)
		var body: Node3D = node.get_node("Body")
		# Face out of the goal; "inward" is which way a dive along the line rolls.
		var g: Dictionary = sim.goals[team]
		body.rotation.y = atan2(g.n.x, g.n.y)
		var inward: float = -Vector2(cos(body.rotation.y), -sin(body.rotation.y)).dot(g.t)
		pose_keeper(node, body, k, team, inward, snap, dt)
		body.get_node("Stars").visible = false
	for i in athletes.size():
		var node: Node3D = athletes[i]
		node.visible = i < sim.players.size()
		if not node.visible: continue
		var p: Dictionary = sim.players[i]
		node.position = node.position.lerp(Vector3(p.pos.x, 0, p.pos.y), 1.0 if snap else 1 - exp(-dt * 30))
		var body: Node3D = node.get_node("Body")
		var speed: float = p.vel.length()
		body.rotation.y = lerp_angle(body.rotation.y, atan2(p.face.x, p.face.y), 1.0 if snap else 1 - exp(-dt * 22))
		var stride := sin(sim.elapsed * 19 + i) * minf(.8, speed * .06)
		body.position.y = absf(sin(sim.elapsed * 19 + i)) * minf(.16, speed * .014)
		body.rotation.x = lerpf(body.rotation.x, .85 if p.stun > 0 else (-.35 if p.dash > 0 else (-.2 if p.slide > 0 else .08 * speed / 12)), 1 - exp(-dt * 20))
		body.rotation.z = lerpf(body.rotation.z, 1.25 if p.stun > 0 else 0, 1 - exp(-dt * 15))
		body.get_node("LegL").rotation.x = stride - p.kick * 5
		body.get_node("LegR").rotation.x = -stride
		body.get_node("ArmL").rotation.x = -stride
		body.get_node("ArmR").rotation.x = stride
		node.get_node("Marker").visible = p.human >= 0 and not menu
		body.get_node("ArmL").rotation.z = .1
		body.get_node("ArmR").rotation.z = -.1
		var mood := "focus" if p.dash > 0 or p.charge > .05 else ("hurt" if p.stun > 0 else ("grin" if sim.owner == i else ""))
		if sim.phase == "goal" or sim.phase == "result":
			if p.team == sim.events_team:
				celebrate(body, i, sim.elapsed)
				mood = "cheer"
				if i == replay.scorer_index and replay.stage == "react":
					# The close-up: big jumps, fists up, straight into the lens.
					var to_lens := cine.global_position - node.global_position
					body.rotation = Vector3(0, atan2(to_lens.x, to_lens.z), 0)
					body.position.y = absf(sin(sim.elapsed * 7)) * .9
					body.get_node("ArmL").rotation = Vector3(0, 0, -2.7 + sin(sim.elapsed * 14) * .25)
					body.get_node("ArmR").rotation = Vector3(0, 0, 2.7 - sin(sim.elapsed * 14) * .25)
			else:
				# Heads down for the team that conceded.
				body.rotation.x = lerpf(body.rotation.x, .5, 1 - exp(-dt * 6))
				body.position.y = 0.0
				mood = "sad"
		express(body, mood, sim.elapsed + i * 1.37, p.kick > 0)
		var stars: Node3D = body.get_node("Stars")
		stars.visible = p.stun > .12
		stars.rotation.y = run_time * 7
	chaos_view.update(sim, dt)
	update_coaches(dt)
	update_cameramen(dt)
	ball_node.position = ball_node.position.lerp(sim.ball, 1.0 if snap else 1 - exp(-dt * 36))
	ball_node.rotate_x(sim.ball_velocity.z * dt * 1.6)
	ball_node.rotate_z(-sim.ball_velocity.x * dt * 1.6)
	ball_shadow.position = Vector3(sim.ball.x, .12, sim.ball.z)
	var shadow_scale := clampf(1 - sim.ball.y * .09, .3, 1)
	ball_shadow.scale = Vector3(shadow_scale, .015, shadow_scale)

## Keeper body language: a bouncy ready stance with a side-step shuffle,
## a stretched full-length dive, a staged get-up (lie, knee, stand), a slap,
## and a reaction to every goal.
func pose_keeper(node: Node3D, body: Node3D, k: Dictionary, team: int, inward: float, snap: bool, dt: float) -> void:
	var t: float = sim.elapsed + team * 1.7
	var side: float = k.dive_dir * inward
	if k.dive > 0: node.set_meta("dived", true)
	elif k.recovery <= 0: node.set_meta("dived", false)
	var dived: bool = node.get_meta("dived", false)
	var holding: bool = sim.keeper_owner == team
	var shuffle: float = clampf(absf(k.vel) / 4.0, 0, 1) if k.dive <= 0 else 0.0
	var sway: float = signf(k.vel) * -inward
	# Pose targets: body tilt (x forward, z sideways), height, then limbs.
	var tilt := Vector3(.16, 0, 0)
	var lift := absf(sin(t * 9)) * .05
	var arm_l := Vector3(-.45, 0, -.75)
	var arm_r := Vector3(-.45, 0, .75)
	var leg_l := Vector3(0, 0, -.18)
	var leg_r := Vector3(0, 0, .18)
	var mood := ""
	if sim.phase in ["goal", "result"] and sim.conceded_team == team:
		# Beaten: down on both knees, head hanging, fists thumping the grass.
		var thump := absf(sin(t * 5)) * .5
		tilt = Vector3(.55, 0, 0)
		lift = -.3
		arm_l = Vector3(-.3 - thump, 0, .1)
		arm_r = Vector3(-.3 - absf(sin(t * 5 + 1.6)) * .5, 0, -.1)
		leg_l = Vector3(1.45, 0, -.1)
		leg_r = Vector3(1.45, 0, .1)
		mood = "sad"
	elif sim.phase in ["goal", "result"] and sim.events_team == team:
		# Our team scored: star jumps in the box.
		var jump := absf(sin(t * 7))
		tilt = Vector3.ZERO
		lift = jump * .6
		arm_l = Vector3(0, 0, -2.7 + jump * .4)
		arm_r = Vector3(0, 0, 2.7 - jump * .4)
		leg_l = Vector3(0, 0, -.35 * jump)
		leg_r = Vector3(0, 0, .35 * jump)
		mood = "cheer"
	elif k.dive > 0:
		# Full stretch: flat out, arms reaching past the head, legs together.
		tilt = Vector3(-.15, 0, side * 1.38)
		lift = .62
		arm_l = Vector3(0, 0, -2.85)
		arm_r = Vector3(0, 0, 2.85)
		leg_l = Vector3(.2, 0, -.05)
		leg_r = Vector3(.05, 0, .05)
		mood = "focus"
	elif dived and k.recovery > .4:
		# Down on the grass, arms still out where the ball went.
		tilt = Vector3(0, 0, side * 1.5)
		lift = .38
		arm_l = Vector3(0, 0, -2.3 + sin(t * 3) * .1)
		arm_r = Vector3(0, 0, 2.3)
		leg_l = Vector3(.3, 0, -.2)
		leg_r = Vector3(-.2, 0, .2)
		mood = "hurt"
	elif dived and k.recovery > .16:
		# Up onto one knee, the low hand pushing off the ground.
		tilt = Vector3(.35, 0, side * .3)
		lift = -.18
		arm_l = Vector3(-.2, 0, .4 if side < 0 else -1.0)
		arm_r = Vector3(-.2, 0, -.4 if side > 0 else 1.0)
		leg_l = Vector3(-1.35, 0, -.1)
		leg_r = Vector3(1.3, 0, .1)
		mood = "focus"
	elif dived:
		# Springing back up, shaking it off.
		tilt = Vector3(.05, 0, sin(t * 22) * .08)
		lift = .12
		arm_l = Vector3(-.2, 0, -1.1)
		arm_r = Vector3(-.2, 0, 1.1)
	elif k.recovery > .4 and not holding:
		# Knocked back by a shot through the gloves: arms windmilling.
		tilt = Vector3(-.3, 0, sin(t * 14) * .1)
		arm_l = Vector3(sin(t * 20) * 1.2 - 1.2, 0, -1.2)
		arm_r = Vector3(-sin(t * 20) * 1.2 - 1.2, 0, 1.2)
		leg_l = Vector3(-.4, 0, -.15)
		mood = "hurt"
	elif holding:
		# Ball tucked into the chest, scanning for a runner.
		tilt = Vector3(-.05, 0, 0)
		lift = absf(sin(t * 6)) * .04
		arm_l = Vector3(-1.35, 0, .55)
		arm_r = Vector3(-1.35, 0, -.55)
		mood = "grin"
	elif k.slap > 0:
		# A big round-arm swat at whoever wandered too close.
		var swing := clampf((.8 - k.slap) / .22, 0, 1)
		tilt = Vector3(.2, 0, -.15)
		arm_r = Vector3(lerpf(-2.6, .9, swing), 0, .5)
		arm_l = Vector3(.3, 0, -.6)
		mood = "focus"
	else:
		# Ready stance: on the toes, knees bent, gloves wide; shuffling sideways
		# with a lean and legs scissoring rather than running.
		var step := sin(t * 17) * shuffle
		tilt = Vector3(.2, 0, sway * shuffle * .14)
		arm_l = Vector3(-.5 + sin(t * 4) * .06, 0, -.85 - shuffle * .2)
		arm_r = Vector3(-.5 + sin(t * 4 + 1) * .06, 0, .85 + shuffle * .2)
		leg_l = Vector3(0, 0, -.2 - absf(step) * .3)
		leg_r = Vector3(0, 0, .2 + absf(step) * .3)
		lift += absf(step) * .06
	var rate: float = 1.0 if snap else 1 - exp(-dt * (26.0 if k.dive > 0 else 14.0))
	body.rotation.x = lerp_angle(body.rotation.x, tilt.x, rate)
	body.rotation.z = lerp_angle(body.rotation.z, tilt.z, rate)
	body.position.y = lerpf(body.position.y, lift, rate)
	for pair in [["ArmL", arm_l], ["ArmR", arm_r], ["LegL", leg_l], ["LegR", leg_r]]:
		var limb: Node3D = body.get_node(pair[0])
		var goal: Vector3 = pair[1]
		limb.rotation = Vector3(lerp_angle(limb.rotation.x, goal.x, rate), 0, lerp_angle(limb.rotation.z, goal.z, rate))
	# Kicks and throws snap through on top of the pose.
	if k.kick > 0: body.get_node("LegL").rotation.x = -k.kick * 4
	express(body, mood, t, k.kick > 0)

func celebrate(body: Node3D, i: int, t: float) -> void:
	# Each athlete has a signature celebration.
	match (i / 2 + (i % 2) * 4) % 4:
		0:
			body.position.y += absf(sin(t * 8 + i)) * .65
			body.get_node("ArmL").rotation.z = -2.4
			body.get_node("ArmR").rotation.z = 2.4
		1:
			body.rotation.y = t * 11.0
			body.position.y += absf(sin(t * 6)) * .25
			body.get_node("ArmL").rotation.z = -1.4
			body.get_node("ArmR").rotation.z = 1.4
		2:
			# Aeroplane: arms out, banking from side to side.
			body.rotation.z = sin(t * 4 + i) * .4
			body.get_node("ArmL").rotation.z = -1.55
			body.get_node("ArmR").rotation.z = 1.55
			body.get_node("ArmL").rotation.x = 0.0
			body.get_node("ArmR").rotation.x = 0.0
		3:
			# Backflips.
			var cycle := fmod(t * 1.3 + i * .3, 1.0)
			body.position.y += sin(cycle * PI) * 1.3
			body.rotation.x = -cycle * TAU
			body.get_node("ArmL").rotation.z = -2.8
			body.get_node("ArmR").rotation.z = 2.8

func express(body: Node3D, mood: String, t: float, kicking: bool) -> void:
	var blink := fmod(t, 3.7) < .12 and mood != "hurt"
	for eye in ["EyeL", "EyeR"]:
		var node: Node3D = body.get_node(eye)
		node.scale = Vector3(.9, .25 if blink or mood == "cheer" else (.7 if mood == "hurt" else 1.5), .6)
	var mouth: Node3D = body.get_node("Mouth")
	if kicking or mood in ["cheer", "hurt"]: mouth.scale = Vector3(.8, 3.2, 1)
	elif mood == "grin": mouth.scale = Vector3(1.45, 1.2, 1)
	elif mood == "sad": mouth.scale = Vector3(.7, .8, 1)
	else: mouth.scale = Vector3.ONE
	var tilt := {"focus": .4, "hurt": -.35, "sad": -.45, "cheer": -.2}.get(mood, 0.0) as float
	body.get_node("BrowL").rotation.z = -tilt
	body.get_node("BrowR").rotation.z = tilt
	body.get_node("BrowL").position.y = 1.86 + (.04 if mood in ["cheer", "hurt"] else 0.0)
	body.get_node("BrowR").position.y = body.get_node("BrowL").position.y

## Where the main camera sits relative to the point it looks at: a little lower
## than straight-down isometric, so the players and stands read as 3D.
func camera_offset(factor: float) -> Vector3:
	return Vector3(0, sin(CAMERA_PITCH), cos(CAMERA_PITCH)) * CAMERA_DISTANCE * factor

func aim_camera(focus: Vector3, factor: float) -> void:
	camera.position = Vector3(focus.x * CAMERA_TRUCK, 0, focus.z) + camera_offset(factor)
	camera.look_at(focus)

func direct_replay(dt: float) -> void:
	# Pick a camera position per shot; cut on a new shot, glide within one.
	var shot: String = replay.shot()
	if shot == "react_end": return
	var side := 1.0 if replay.team == 0 else -1.0
	var ball: Vector3 = sim.ball
	var eye := Vector3.ZERO
	var target := Vector3.ZERO
	match shot:
		"wide":
			eye = Vector3(ball.x * .85, 8.5, sim.half_z + 13)
			target = Vector3(ball.x, .8, ball.z)
		_:
			# Every other shot is filmed by one of the camera operators.
			var man := replay_operator(shot)
			eye = lens_point(man)
			target = man.get_meta("look", ball)
			if shot == "scorer": target.y = 1.9
	if shot != cine_shot or not cine.current:
		cine_shot = shot
		cine.current = true
		cine.fov = SHOT_FOV.get(shot, 34.0)
		cine.position = eye
		cine.look_at(target)
	else:
		cine.position = cine.position.lerp(eye, 1 - exp(-dt * 4))
		var look := cine.global_transform.looking_at(target)
		cine.global_transform = cine.global_transform.interpolate_with(look, 1 - exp(-dt * 6))

func clear_view(index: int, at: Vector2, side: float) -> Vector3:
	# Walk around the scorer and take the angle with the least of anyone between
	# the lens and them, staying on the pitch so the net never sits in front.
	var best := Vector3.ZERO
	var best_score := INF
	# Prefer looking back at the scorer from the pitch side of the beaten goal.
	var ahead: Vector2 = sim.goals[sim.conceded_team].n
	for step in 12:
		var dir := ahead.rotated(step * TAU / 12.0)
		var from := at + dir * 6.5
		if sim.three_way:
			if sim.confine(from, .6).distance_to(from) > .01: continue
		elif absf(from.x) > sim.half_x - .6 or absf(from.y) > sim.half_z + .4: continue
		var score := absf(dir.angle_to(ahead)) * .15
		var near := at + dir * .7
		var bodies: Array = []
		for i in sim.players.size(): if i != index: bodies.append(sim.players[i].pos)
		for k in sim.keepers: bodies.append(k.pos)
		for b in bodies:
			var d: float = Geometry2D.get_closest_point_to_segment(b, near, from).distance_to(b)
			score += maxf(0.0, 1.8 - d)
		if score < best_score:
			best_score = score
			best = Vector3(from.x, 3.3, from.y)
	if best_score == INF: best = Vector3(at.x + ahead.x * 6.5, 3.3, at.y + ahead.y * 6.5)
	return best

func update_cameramen(dt: float) -> void:
	# The replay cameras are real people. One stands on a riser beside each goal
	# (the goal-line and crowd shots come from them) and a steadicam operator
	# walks behind the coaches on the near side, then runs in for the scorer and coach close-ups.
	var f: float = sim.arena_factor
	var shot: String = replay.shot() if replay_showing() else ""
	var scoring_side := 1.0 if replay.team == 0 else -1.0
	for index in cameramen.size():
		var man: Node3D = cameramen[index]
		var body: Node3D = man.get_node("Body")
		var look: Vector3 = sim.ball
		var target: Vector3
		var snap := false
		if index < 2:
			var side := -1.0 if index == 0 else 1.0
			# On the goal line by the far corner: the classic goal-line angle,
			# with nothing of the net between the lens and the goal mouth.
			target = Vector3(side * (sim.half_x - 1.0), RISER, -(sim.half_z + 1.5))
			# The crowd shot is a long-lens look from the scoring end, over the
			# heads on the pitch, at the scorers' own stand at the other end.
			if shot == "fans" and side == scoring_side:
				look = Vector3(-side * (sim.half_x + 7.5), 2.8, -2.0 * f)
		else:
			target = Vector3(clampf(sim.ball.x, -sim.half_x + 2, sim.half_x - 2), 0, sim.half_z + 2.0)
			if shot == "scorer" and replay.scorer_index >= 0:
				var p: Dictionary = sim.players[replay.scorer_index]
				var spot := clear_view(replay.scorer_index, p.pos, scoring_side)
				target = Vector3(spot.x, 0, spot.z)
				look = Vector3(p.pos.x, 1.5, p.pos.y)
				snap = true
			elif shot in ["coach", "coach_sad"]:
				var coach_team: int = replay.team if shot == "coach" else sim.conceded_team
				var coach: Node3D = coaches[coach_team]
				target = coach.position + Vector3(-.9, 0, -4.6)
				if sim.three_way:
					# Three-way coaches stand beside their own goal, facing the pitch.
					var g: Dictionary = sim.goals[coach_team]
					var spot: Vector2 = g.n * 6.2 - g.t * .9
					target = coach.position + Vector3(spot.x, 0, spot.y)
				look = coach.position + Vector3(0, 1.75 if shot == "coach" else 1.45, 0)
				snap = true
		man.set_meta("look", look)
		var to_look := Vector2(look.x - man.position.x, look.z - man.position.z)
		if snap and man.position.distance_to(target) > .5:
			man.position = target
			to_look = Vector2(look.x - target.x, look.z - target.z)
			body.rotation.y = atan2(to_look.x, to_look.y)
		if man.position.distance_to(target) > 14: man.position = target
		var step := Vector2(target.x - man.position.x, target.z - man.position.z).length()
		man.position = man.position.move_toward(target, dt * 4.5)
		body.rotation.y = lerp_angle(body.rotation.y, atan2(to_look.x, to_look.y), 1 - exp(-dt * 7))
		var swing := sin(run_time * 10 + index) * (.55 if step > .2 else 0.0)
		body.get_node("LegL").rotation.x = swing
		body.get_node("LegR").rotation.x = -swing
		body.position.y = absf(swing) * .06
		# Tilt the camera onto what it is filming.
		var camera_node: Node3D = body.get_node("Camera")
		var lens_height: float = man.position.y + 1.9
		camera_node.rotation.x = clampf(atan2(lens_height - look.y, maxf(.5, to_look.length())), -.3, .6)
		# Never show the operator whose lens the replay is looking through.
		man.visible = man != replay_operator(shot)

## The camera operator a replay shot is filmed by, or null for the gantry.
func replay_operator(shot: String) -> Node3D:
	var scoring_side := 1.0 if replay.team == 0 else -1.0
	var beaten_right: bool = sim.goals[sim.conceded_team].c.x > 0
	match shot:
		"goalcam": return cameramen[1 if beaten_right else 0]
		"fans": return cameramen[1 if scoring_side > 0 else 0]
		"scorer", "coach", "coach_sad": return cameramen[2]
	return null

## A point just in front of an operator's lens, where the replay eye sits.
func lens_point(man: Node3D) -> Vector3:
	var lens: Node3D = man.get_node("Body/Camera")
	return lens.global_transform * Vector3(0, 0, 1.0)

func update_coaches(dt: float) -> void:
	for team in sim.teams:
		var coach: Node3D = coaches[team]
		var home: float = [-6.5, 6.5, 0.0][team] * sim.arena_factor
		var pace := home + sin(run_time * .45 + team * 2.0) * 2.2 + clampf(sim.ball.x * .12, -2, 2)
		var target := Vector3(pace, 0, sim.half_z + .6)
		var facing := PI
		if sim.three_way:
			# Beside their own goal, just behind the boards.
			var g: Dictionary = sim.goals[team]
			var spot: Vector2 = g.c - g.n * 1.9 + g.t * (6.8 + sin(run_time * .45 + team * 2.0) * 1.4)
			target = Vector3(spot.x, 0, spot.y)
			facing = atan2(g.n.x, g.n.y)
		if coach.position.distance_to(target) > 12: coach.position = target
		var step := target - coach.position
		coach.position = coach.position.lerp(target, 1 - exp(-dt * 2))
		var body: Node3D = coach.get_node("Body")
		var t: float = run_time * 9 + team
		# Hold still for the cameras while a replay runs.
		var walking: bool = Vector2(step.x, step.z).length() > .15 and not replay.active
		body.rotation.y = lerp_angle(body.rotation.y, atan2(step.x, step.z) if walking else facing, 1 - exp(-dt * 6))
		body.position.y = 0.0
		body.rotation.x = 0.0
		var swing := sin(t) * (.5 if walking else 0.0)
		body.get_node("LegL").rotation.x = swing
		body.get_node("LegR").rotation.x = -swing
		var arm_l := Vector3(-swing, 0, .1)
		var arm_r := Vector3(swing, 0, -.1)
		if sim.phase in ["goal", "result"]:
			body.rotation.y = lerp_angle(body.rotation.y, facing, 1 - exp(-dt * 8))
			if team == sim.events_team:
				body.position.y = absf(sin(run_time * 9 + team)) * .7
				arm_l = Vector3(0, 0, -2.6 + sin(run_time * 14) * .3)
				arm_r = Vector3(0, 0, 2.6 - sin(run_time * 14) * .3)
			else:
				# Hands on head, looking at the floor.
				body.rotation.x = .35
				arm_l = Vector3(-2.3, 0, -.9)
				arm_r = Vector3(-2.3, 0, .9)
		elif Vector2(sim.ball.x - coach.position.x, sim.ball.z - coach.position.z).length() < (8 if sim.three_way else 99) and absf(sim.ball.x - coach.position.x) < 8 and sim.phase == "play":
			arm_r = Vector3(-1.4 + sin(run_time * 6) * .25, 0, -.3)
		body.get_node("ArmL").rotation = arm_l
		body.get_node("ArmR").rotation = arm_r

func replay_showing() -> bool:
	return replay.active and replay.cursor > 0 and not replay.saved.is_empty()

func replay_event(event: Dictionary) -> void:
	# Re-fire the moment's effects; the goal brings the crowd up a second time.
	handle_event(event)

func handle_event(event: Dictionary) -> void:
	var type: String = event.type
	if not menu: crowd_audio.react(event)
	var team: int = event.get("team", 0)
	var color: Color = Stadium.TEAM_COLORS[team] if team >= 0 and team < 3 else Stadium.CREAM
	match type:
		"control_changed": apply_profiles()
		"save":
			stadium.crowd.event("save")
			shake = .3
			play_sound("save")
			notice = "SAVED!"
			notice_time = .65
		"keeper_beaten":
			shake = .35
			play_sound("hit")
			impact_pause(.035)
		"keeper_dive": burst(event.pos, color, 5, 3)
		"shot", "pass":
			if type == "shot": stadium.crowd.event("shot")
			play_sound("kick" if type == "shot" else "pass")
			shake = .25 if type == "shot" else .08
			if type == "shot": impact_pause(.033)
		"super":
			stadium.crowd.event("super")
			super_time = 1.4
			shake = .85
			notice = "POWER SHOT!"
			notice_time = 1.2
			play_sound("super")
			impact_pause(.050)
		"hit":
			burst(event.pos, color, 12, 7)
			shake = .48
			play_sound("hit")
			impact_pause(.050)
		"goal":
			if sim.phase == "goal": replay_pending = true
			stadium.crowd.event("goal", event.team)
			burst(event.pos + Vector3.UP * 2, color, 65, 18)
			shake = 1.0
			play_sound("goal")
		"dash": burst(event.pos, color, 5, 3)
		"receive": burst(event.pos, color, 4, 2)
		"whistle": play_sound("whistle")
		"overtime":
			notice = "NEXT GOAL WINS"
			notice_time = 3.0
			play_sound("whistle")
		"chaos":
			stadium.crowd.event("chaos")
			notice = event.text
			notice_time = 2.6
			shake = maxf(shake, .2)
			play_sound("whistle")
		"chaos_text":
			notice = event.text
			notice_time = 1.6
		"chaos_kick":
			play_sound("pass")
		"chaos_boom":
			burst(event.pos, Color("ffb347"), 30, 13)
			burst(event.pos, Color("ff4a3d"), 18, 9)
			burst(event.pos + Vector3.UP, Color("dfe6e8"), 14, 4)
			shake = .75
			play_sound("super")
			impact_pause(.04)
		"chaos_pop":
			burst(event.pos, Color("ff5c6b"), 16, 6)
			play_sound("hit")
		"finish":
			stadium.crowd.event("finish", event.team)
			sim.events_team = event.team
			play_sound("goal")
			GameNight.notify_finished(party.session)

func burst(pos: Vector3, color: Color, count: int, speed: float) -> void:
	for i in count:
		if effects.size() >= 180: break
		var particle = stadium.sphere(stadium, pos, randf_range(.065, .17), color)
		var velocity := Vector3(randf_range(-1, 1), randf_range(.3, 1.5), randf_range(-1, 1)).normalized() * randf_range(speed * .3, speed)
		effects.append({"node": particle, "vel": velocity, "life": randf_range(.35, .85), "max": .85})

func impact_pause(duration: float) -> void:
	# Present the contact pose first, then briefly freeze the whole shared pitch.
	# Capped and non-additive: simultaneous hits never stack into a long stall.
	update_visuals(1.0 / 60)
	hit_stop = maxf(hit_stop, duration)

func update_effects(dt: float) -> void:
	for i in range(effects.size() - 1, -1, -1):
		var e: Dictionary = effects[i]
		e.life -= dt
		if e.life <= 0:
			e.node.queue_free()
			effects.remove_at(i)
			continue
		e.vel.y -= dt * 15
		e.node.position += e.vel * dt
		if e.node.position.y < .2:
			e.node.position.y = .2
			e.vel.y = absf(e.vel.y) * .3
		e.node.scale = Vector3.ONE * minf(1, e.life * 4)

func clear_effects() -> void:
	for e in effects: e.node.queue_free()
	effects.clear()
	chaos_view.reset()

func play_sound(name: String) -> void:
	if not sound_enabled or menu or paused or (party.managed and not host_active): return
	audio.play_cue(name)

func _input(event: InputEvent) -> void:
	var key := 0
	var button := -1
	if event is InputEventKey and event.pressed and not event.echo: key = event.physical_keycode
	if event is InputEventJoypadButton and event.pressed and not party.managed: button = event.button_index
	if key == KEY_F11:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if key == KEY_F3: show_stats = not show_stats
	if key == KEY_F12:
		get_viewport().set_input_as_handled() # F12 captures; the SDK would read it as "back to party".
		capture_path = "res://captures/gameplay.png"
		capture.call_deferred()
	if party.managed and not host_active: return
	if replay.active and not menu:
		if key in [KEY_ENTER, KEY_SPACE, KEY_ESCAPE, KEY_Q, KEY_J, KEY_CTRL] or button in [JOY_BUTTON_A, JOY_BUTTON_START, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
			replay.skip()
		return
	if menu:
		if key in [KEY_UP, KEY_W] or button == JOY_BUTTON_DPAD_UP: menu_selection = posmod(menu_selection - 1, 6)
		if key in [KEY_DOWN, KEY_S] or button == JOY_BUTTON_DPAD_DOWN: menu_selection = (menu_selection + 1) % 6
		if key in [KEY_LEFT, KEY_A] or button == JOY_BUTTON_DPAD_LEFT: adjust_menu(-1)
		if key in [KEY_RIGHT, KEY_D] or button == JOY_BUTTON_DPAD_RIGHT: adjust_menu(1)
		if key in [KEY_ENTER, KEY_SPACE] or button in [JOY_BUTTON_A, JOY_BUTTON_START]:
			if menu_selection == 0 or button == JOY_BUTTON_START: start_match()
			else: adjust_menu(1)
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var pos: Vector2 = event.position / (get_viewport().get_visible_rect().size / Vector2(1600, 900))
			for i in hud.hit_rects.size():
				if hud.hit_rects[i].has_point(pos):
					menu_selection = i
					if i == 0: start_match()
					else: adjust_menu(1)
		if event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y:
			var gate: int = previous.get("menu_axis", 0)
			if absf(event.axis_value) > .65 and gate == 0:
				menu_selection = posmod(menu_selection + (1 if event.axis_value > 0 else -1), 6)
				previous["menu_axis"] = 1
			elif absf(event.axis_value) < .3: previous["menu_axis"] = 0
		if event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_X:
			var gate: int = previous.get("menu_x", 0)
			if absf(event.axis_value) > .65 and gate == 0:
				adjust_menu(1 if event.axis_value > 0 else -1)
				previous["menu_x"] = 1
			elif absf(event.axis_value) < .3: previous["menu_x"] = 0
		return
	if sim.phase == "result" and not paused and (key == KEY_ENTER or button in [JOY_BUTTON_START, JOY_BUTTON_A]): start_match(); return
	if paused:
		var step := Vector2i.ZERO
		if key in [KEY_UP, KEY_W] or button == JOY_BUTTON_DPAD_UP: step.y = -1
		if key in [KEY_DOWN, KEY_S] or button == JOY_BUTTON_DPAD_DOWN: step.y = 1
		if key in [KEY_LEFT, KEY_A] or button == JOY_BUTTON_DPAD_LEFT: step.x = -1
		if key in [KEY_RIGHT, KEY_D] or button == JOY_BUTTON_DPAD_RIGHT: step.x = 1
		if event is InputEventJoypadMotion and not party.managed and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
			var gate := "pause_axis_%d" % event.axis
			if absf(event.axis_value) > .65 and previous.get(gate, 0) == 0:
				step[0 if event.axis == JOY_AXIS_LEFT_X else 1] = 1 if event.axis_value > 0 else -1
				previous[gate] = 1
			elif absf(event.axis_value) < .3: previous[gate] = 0
		pause_input(step, key in [KEY_ENTER, KEY_SPACE] or button == JOY_BUTTON_A, key == KEY_ESCAPE or button in [JOY_BUTTON_START, JOY_BUTTON_B])
		if not party.managed and (key == KEY_TAB or button == JOY_BUTTON_Y):
			pause_selection = 5
			activate_pause()
		return
	if key in [KEY_ESCAPE, KEY_ENTER] or button == JOY_BUTTON_START: set_paused(true)

func adjust_menu(delta: int) -> void:
	match menu_selection:
		1:
			# Solo, 1v1, 2v2, 3v3, then three-way.
			set_matchup_choice(posmod(local_matchup_choice() + delta, 5))
			sim.setup(0, false, 725, 120, dual_stick, team_size, three_way)
			sync_arena()
		2:
			if team_size > 1 or three_way: return
			dual_stick = not dual_stick
			coop = false
			if dual_stick: humans = mini(humans, team_size * 2)
			sim.setup(0, false, 725, 120, dual_stick, team_size, three_way)
		3: match_seconds = clampi(match_seconds + delta * 60, 60, 300)
		4:
			sound_enabled = not sound_enabled
			if not sound_enabled: audio.reset()
		5:
			chaos_level = posmod(chaos_level + delta, 3)
			sim.chaos.level = chaos_level

## Standalone matchups: 0 solo, 1-3 for 1v1-3v3, 4 three-way.
func local_matchup_choice() -> int:
	return 0 if humans == 1 else (4 if three_way else team_size)

func set_matchup_choice(choice: int) -> void:
	three_way = choice == 4
	team_size = 1 if three_way else maxi(1, choice)
	humans = 1 if choice == 0 else (3 if three_way else team_size * 2)

func set_paused(value: bool) -> void:
	paused = value
	for player in sound_players: player.stream_paused = paused
	if paused:
		pause_selection = 0
		pause_matchup = current_matchup()

func current_matchup() -> String:
	return managed_matchup if party.managed else ["Solo", "1v1", "2v2", "3v3", "3-way"][local_matchup_choice()]

func pause_rows() -> Array:
	var rows := ["RESUME", "NEW MATCH", "MATCHUP     %s" % pause_matchup.to_upper(), "MATCH       %d MIN" % (match_seconds / 60), "CHAOS       %s" % ["OFF", "SOME", "LOTS"][sim.chaos.level]]
	if not party.managed: rows.append("MAIN MENU")
	return rows

func store_setting(key: String, value: Variant) -> void:
	if not party.managed or not settings.change(key, value): return
	GameNight.set_setting(key, value)

func adjust_pause(delta: int) -> void:
	match pause_selection:
		2:
			var options: Array = MATCHUPS if party.managed else ["Solo", "1v1", "2v2", "3v3", "3-way"]
			pause_matchup = options[posmod(options.find(pause_matchup) + delta, options.size())]
		3:
			match_seconds = clampi(match_seconds + delta * 60, 60, 300)
			store_setting("seconds", match_seconds)
		4:
			chaos_level = posmod(sim.chaos.level + delta, 3)
			sim.chaos.level = chaos_level
			store_setting("chaos", settings.CHAOS_LEVELS[chaos_level])

func activate_pause() -> void:
	match pause_selection:
		0: set_paused(false)
		1:
			if party.managed:
				managed_matchup = pause_matchup
				store_setting("matchup", pause_matchup)
			else: set_matchup_choice(["Solo", "1v1", "2v2", "3v3", "3-way"].find(pause_matchup))
			set_paused(false)
			start_match()
		5:
			reset_replay()
			set_paused(false)
			menu = true
			sim.setup(0, false, randi(), 120, dual_stick, team_size, three_way)
			sync_arena()
		_: adjust_pause(1)

func pause_input(step: Vector2i, accept: bool, back: bool) -> void:
	if step.y != 0: pause_selection = posmod(pause_selection + step.y, pause_rows().size())
	if step.x != 0: adjust_pause(step.x)
	if accept: activate_pause()
	elif back: set_paused(false)

func on_party_command(message: Dictionary) -> void:
	match message.get("type", ""):
		"prepare":
			reset_replay()
			host_active = false
			menu = false
			paused = true
			configure_managed_matchup()
			humans = mini(party.human_seats().size(), 3 if three_way else (team_size * 2 if dual_stick else team_size * 4))
			coop = false
			managed_buttons.clear()
			sim.setup(humans, false, 725, match_seconds, dual_stick, team_size, three_way)
			sync_arena()
			apply_profiles()
			GameNight.notify_participation(party.session, false)
			# Wait until the renderer has prepared the arena before Ready. A
			# warming game is minimized, and a minimized window never draws, so
			# only wait while the window is actually on screen.
			if DisplayServer.get_name() != "headless" and DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_MINIMIZED:
				await RenderingServer.frame_post_draw
			GameNight.notify_ready(party.session)
		"start":
			host_active = true
			start_match()
		"controller_frame":
			# Host Start must work even while locally paused; polling inside the
			# simulation alone would leave a paused game unable to resume.
			if not host_active: return
			for seat in party.human_seats():
				var token: String = str(seat.get("controller", ""))
				var record: Dictionary = party.frames.get(token, {})
				var buttons: int = int(record.get("buttons", 0))
				var old: int = managed_buttons.get(token, 0)
				managed_buttons[token] = buttons
				if replay.active and buttons & ~old & ((1 << 0) | (1 << 4) | (1 << 5) | (1 << 7)):
					replay.skip()
					continue
				if not buttons & (1 << 6) and Time.get_ticks_msec() > overlay_after: overlay_ready = true
				var pressed: int = buttons & ~old
				if paused:
					var step := Vector2i(int(pressed & (1 << 13) != 0) - int(pressed & (1 << 12) != 0), int(pressed & (1 << 11) != 0) - int(pressed & (1 << 10) != 0))
					var axes: Array = record.get("axes", [])
					if axes.size() >= 2:
						var stick := Vector2(float(axes[0]), float(axes[1])) / 32767.0
						var gate: bool = managed_buttons.get(token + "_stick", false)
						if stick.length() > .65 and not gate:
							if absf(stick.x) > absf(stick.y): step.x = int(signf(stick.x))
							else: step.y = int(signf(stick.y))
							managed_buttons[token + "_stick"] = true
						elif stick.length() < .3: managed_buttons[token + "_stick"] = false
					pause_input(step, pressed & 1 != 0, pressed & ((1 << 1) | (1 << 7)) != 0)
				elif pressed & (1 << 7):
					if sim.phase == "result": start_match()
					else: set_paused(true)
				if buttons & (1 << 6) and not old & (1 << 6) and overlay_ready:
					overlay_ready = false
					GameNight.request_overlay()
		"pause":
			host_active = false
			paused = true
			for player in sound_players: player.stream_paused = true
		"resume":
			host_active = true
			paused = false
			previous.clear()
			for player in sound_players: player.stream_paused = false
			overlay_after = Time.get_ticks_msec() + 1000
		"dispose":
			host_active = false
			paused = true
			for player in sound_players: player.stop()
			clear_effects()
		"party_updated": apply_profiles()
		"setting_changed":
			var key: String = str(message.get("key", ""))
			if not settings.change(key, message.get("value")): return
			settings.apply_live(sim)
			if key == "seconds": match_seconds = settings.values.seconds
			elif key == "matchup": managed_matchup = settings.values.matchup

func dye_hair(athlete: Node3D, color: Color) -> void:
	for part in athlete.get_node("Body/Hair").get_children():
		if part is MeshInstance3D and part.get_meta("dye", true): part.material_override = stadium.material(color)

func apply_profiles() -> void:
	if not party.managed: return
	var seats: Array = party.human_seats()
	for i in sim.players.size():
		var p: Dictionary = sim.players[i]
		p.erase("profile")
		athletes[i].get_node("Body/Head").material_override = stadium.material(Stadium.CREAM)
		dye_hair(athletes[i], athletes[i].get_node("Body/Hair").get_meta("color"))
		var person: int = p.human / 2 if sim.dual_control else p.human
		if p.human < 0 or person >= seats.size(): continue
		var id: String = str(seats[person].get("occupant", {}).get("player_id", ""))
		var profile: Dictionary = party.profiles.get(id, {})
		p.name = str(profile.get("name", "P%d" % (p.human + 1)))
		p.profile = profile
		athletes[i].get_node("Body/Head").material_override = stadium.material(Color.from_string(str(profile.get("skin_color", "#fff2d2")), Stadium.CREAM))
		# The party profile colour shows as dyed hair.
		dye_hair(athletes[i], Color.from_string(str(profile.get("color", "#fff2d2")), Stadium.CREAM))
		var avatar: String = str(profile.get("avatar", ""))
		if avatar != "" and not profile_textures.has(avatar):
			var data = JSON.parse_string(avatar)
			if data is Dictionary:
				var w := clampi(int(data.get("w", 48)), 1, 128)
				var h := clampi(int(data.get("h", 48)), 1, 128)
				var pixels: Array = data.get("px", [])
				if pixels.size() != w * h: continue
				var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
				image.fill(Color.TRANSPARENT)
				for pixel in pixels.size():
					if pixels[pixel] != null: image.set_pixel(pixel % w, pixel / w, Color.from_string(str(pixels[pixel]), Color.TRANSPARENT))
				profile_textures[avatar] = ImageTexture.create_from_image(image)

func capture() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(capture_path)
	print("CAPTURE ", capture_path, " status=", err)
