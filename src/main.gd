extends Node3D
const Match = preload("res://src/match.gd")
const Stadium = preload("res://src/stadium.gd")
const Hud = preload("res://src/hud.gd")
const Party = preload("res://src/party.gd")
var sim = Match.new()
var stadium = Stadium.new()
var hud = Hud.new()
var party = Party.new()
var camera := Camera3D.new()
var athletes: Array = []
var keeper_nodes: Array = []
var ball_node: Node3D
var ball_shadow: MeshInstance3D
var effects: Array = []
var trail: Array = []
var trail_index := 0
var menu := true
var menu_selection := 0
var paused := false
var humans := 2
var team_size := 1
var team_override := false
var managed_matchup := "Auto"
var coop := false
var dual_stick := true
var match_seconds := 120
var sound_enabled := true
var devices: Array = []
var previous: Dictionary = {}
var notice := ""
var notice_time := 0.0
var shake := 0.0
var show_stats := false
var run_time := 0.0
var trail_clock := 0.0
var super_time := 0.0
var result_time := 0.0
var hit_stop := 0.0
var demo := false
var capture_path := ""
var capture_at := 4.0
var capture_done := false
var exit_at := 0.0
var sound_players: Array = []
var sounds: Dictionary = {}
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
		elif arg == "--stats": show_stats = true
		elif arg == "--mute": sound_enabled = false
		elif arg == "--fullscreen": DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	add_child(stadium)
	stadium.build()
	for i in 12:
		var athlete = stadium.make_player(i)
		athlete.scale = Vector3.ONE * 1.16
		athletes.append(athlete)
	for team in 2:
		var keeper = stadium.make_player(6 + team, true)
		keeper.scale = Vector3.ONE * 1.23
		keeper.get_node("Marker").visible = false
		keeper_nodes.append(keeper)
	ball_node = stadium.make_ball()
	ball_shadow = stadium.sphere(stadium, Vector3.ZERO, .46, Color("285e50"))
	ball_shadow.scale.y = .015
	for i in 20:
		var mote = stadium.sphere(stadium, Vector3.ZERO, .19, Stadium.CREAM)
		mote.visible = false
		trail.append({"node": mote, "life": 0.0})
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 33
	camera.far = 160
	camera.current = true
	camera.position = Vector3(-9, 30, 31)
	camera.look_at(Vector3(-9, 0, -1))
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.game = self
	party.command.connect(on_party_command)
	add_child(party)
	print("Ballkickers: ready; %d local controllers" % Input.get_connected_joypads().size())
	for name in ["kick", "pass", "hit", "goal", "whistle", "super"]:
		var path := "res://assets/%s.wav" % name
		if ResourceLoader.exists(path): sounds[name] = load(path)
	for i in 10:
		var player := AudioStreamPlayer.new()
		add_child(player)
		sound_players.append(player)
	sim.setup(0, false, 725, 120, dual_stick, team_size)
	sync_arena()
	if demo:
		menu = false
		sim.setup(0, false, 725, 120, dual_stick, team_size)
		sim.power = [100.0, 100.0]
		camera.position = Vector3(0, 30, 31)
		camera.look_at(Vector3(0, 0, -1))
	if party.managed:
		menu = false
		paused = true

func sync_arena() -> void:
	stadium.resize_pitch(team_size)
	for i in athletes.size():
		athletes[i].visible = i < sim.players.size()
		if i < sim.players.size(): athletes[i].position = Match.vec3(sim.players[i].pos)

func configure_managed_matchup() -> void:
	if managed_matchup != "Auto":
		team_size = int(managed_matchup.left(1))
	elif not team_override:
		var count: int = party.human_seats().size()
		team_size = 1 if count <= 2 else (2 if count <= 4 else 3)

func start_match() -> void:
	if party.managed:
		configure_managed_matchup()
		humans = party.human_seats().size()
	else:
		devices.clear()
		for id in Input.get_connected_joypads(): devices.append(id)
		devices.append(-1)
		if not dual_stick: devices.append(-2)
		humans = mini(humans, devices.size())
	if dual_stick: humans = mini(humans, team_size * 2)
	if coop: humans = mini(humans, team_size * 2)
	sim.setup(0 if demo else humans, coop, int(Time.get_ticks_usec()) % 1000000, match_seconds, dual_stick, team_size)
	sync_arena()
	apply_profiles()
	menu = false
	paused = false
	previous.clear()
	result_time = 0
	hit_stop = 0.0
	clear_effects()
	play_sound("whistle")

func _physics_process(dt: float) -> void:
	if party.managed and not host_active: return
	if paused: return
	if hit_stop > 0:
		hit_stop = maxf(0, hit_stop - dt)
		return
	var controls: Dictionary = {}
	if not menu and not demo:
		for h in humans:
			if team_size > 1:
				controls[h] = read_single_control(h)
			elif dual_stick:
				for half in 2: controls[h * 2 + half] = read_dual_control(h, half)
			else:
				controls[h] = read_control(h)
				if controls[h].get("switch", false):
					sim.switch_player(h)
					apply_profiles()
	sim.step(dt, controls)
	if not menu:
		for event in sim.events: handle_event(event)
	if sim.phase == "result":
		result_time += dt
		if menu: sim.setup(0, false, randi(), 120, dual_stick, team_size)
		elif party.managed and result_time > 9: start_match()

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
			party.send({"type": "controller_input", "session": party.session, "controller": seat.get("controller", "")})
		if pressed & (1 << 6) and overlay_ready:
			overlay_ready = false
			party.send({"type": "request_overlay"})
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
		party.send({"type": "controller_input", "session": party.session, "controller": party.human_seats()[h].get("controller", "")})
	return {"move": move.limit_length(), "shoot": action, "tackle": pressed, "pass": false, "sprint": false, "switch": false}

func _process(dt: float) -> void:
	run_time += dt
	if exit_at > 0 and run_time > 3 and not paused: frame_samples.append(dt * 1000.0)
	if not paused and (not party.managed or host_active):
		notice_time = maxf(0, notice_time - dt)
		super_time = maxf(0, super_time - dt)
		shake = move_toward(shake, 0, dt * 2)
		if hit_stop <= 0:
			update_visuals(dt)
			update_effects(dt)
	var factor := Match.pitch_scale(team_size)
	camera.size = 33 * factor
	var target_x := -9.0 * factor if menu else 0.0
	var offset := Vector3(sin(run_time * 67) * shake * .12, 0, cos(run_time * 79) * shake * .1)
	camera.position = camera.position.lerp(Vector3(target_x, 30 * factor, 31 * factor) + offset, 1 - exp(-dt * 5))
	camera.look_at(Vector3(camera.position.x, 0, -1) + offset)
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

func update_visuals(dt: float) -> void:
	for team in keeper_nodes.size():
		var node: Node3D = keeper_nodes[team]
		var k: Dictionary = sim.keepers[team]
		node.position = node.position.lerp(Vector3(k.pos.x, 0, k.pos.y), 1 - exp(-dt * 34))
		var body: Node3D = node.get_node("Body")
		var inward := 1.0 if team == 0 else -1.0
		body.rotation.y = inward * PI / 2
		var down: bool = k.dive > 0 or k.recovery > .45
		body.rotation.z = lerp_angle(body.rotation.z, k.dive_dir * inward * 1.2 if down else 0.0, 1 - exp(-dt * 18))
		body.position.y = lerpf(body.position.y, .45 if down else 0.0, 1 - exp(-dt * 18))
		var holding: bool = sim.keeper_owner == team
		body.get_node("ArmL").rotation.x = -1.3 if holding or down else -.5
		body.get_node("ArmR").rotation.x = -1.3 if holding or down else -.5
		body.get_node("ArmL").rotation.z = -.55 if down else .35
		body.get_node("ArmR").rotation.z = .55 if down else -.35
		body.get_node("LegL").rotation.x = sin(sim.elapsed * 18) * minf(.35, absf(k.vel) * .04) - k.kick * 4
		body.get_node("LegR").rotation.x = -body.get_node("LegL").rotation.x
	for i in athletes.size():
		var node: Node3D = athletes[i]
		node.visible = i < sim.players.size()
		if not node.visible: continue
		var p: Dictionary = sim.players[i]
		node.position = node.position.lerp(Vector3(p.pos.x, 0, p.pos.y), 1 - exp(-dt * 30))
		var body: Node3D = node.get_node("Body")
		var speed: float = p.vel.length()
		body.rotation.y = lerp_angle(body.rotation.y, atan2(p.face.x, p.face.y), 1 - exp(-dt * 22))
		var stride := sin(sim.elapsed * 19 + i) * minf(.8, speed * .06)
		body.position.y = absf(sin(sim.elapsed * 19 + i)) * minf(.16, speed * .014)
		body.rotation.x = lerpf(body.rotation.x, .85 if p.stun > 0 else (-.35 if p.dash > 0 else .08 * speed / 12), 1 - exp(-dt * 20))
		body.rotation.z = lerpf(body.rotation.z, 1.25 if p.stun > 0 else 0, 1 - exp(-dt * 15))
		body.get_node("LegL").rotation.x = stride - p.kick * 5
		body.get_node("LegR").rotation.x = -stride
		body.get_node("ArmL").rotation.x = -stride
		body.get_node("ArmR").rotation.x = stride
		node.get_node("Marker").visible = p.human >= 0 and not menu
		if sim.phase == "goal" or sim.phase == "result":
			if p.team == sim.events_team:
				body.position.y += absf(sin(sim.elapsed * 8 + i)) * .65
				body.get_node("ArmL").rotation.z = -2.4
				body.get_node("ArmR").rotation.z = 2.4
		else:
			body.get_node("ArmL").rotation.z = .1
			body.get_node("ArmR").rotation.z = -.1
	ball_node.position = ball_node.position.lerp(sim.ball, 1 - exp(-dt * 36))
	ball_node.rotate_x(sim.ball_velocity.z * dt * 1.6)
	ball_node.rotate_z(-sim.ball_velocity.x * dt * 1.6)
	ball_shadow.position = Vector3(sim.ball.x, .12, sim.ball.z)
	var shadow_scale := clampf(1 - sim.ball.y * .09, .3, 1)
	ball_shadow.scale = Vector3(shadow_scale, .015, shadow_scale)
	trail_clock -= dt
	if sim.owner < 0 and sim.ball_velocity.length() > 12 and trail_clock <= 0 and sim.phase == "play":
		trail_clock = .024
		var entry: Dictionary = trail[trail_index]
		trail_index = (trail_index + 1) % trail.size()
		entry.node.position = ball_node.position
		entry.node.visible = true
		entry.node.material_override = stadium.material(Color("ffcf57") if super_time > 0 else Stadium.CREAM, .3)
		entry.life = .24 if super_time <= 0 else .42
	for entry in trail:
		entry.life -= dt
		entry.node.visible = entry.life > 0
		entry.node.scale = Vector3.ONE * maxf(.01, entry.life * 2.8)

func handle_event(event: Dictionary) -> void:
	var type: String = event.type
	var color: Color = Stadium.ORANGE if event.get("team", 0) == 0 else Stadium.BLUE
	match type:
		"control_changed": apply_profiles()
		"save":
			burst(event.pos, Stadium.CREAM, 10, 5)
			shake = .3
			play_sound("hit")
			notice = "SAVED!"
			notice_time = .65
		"keeper_beaten":
			burst(event.pos, Stadium.CREAM, 7, 4)
			shake = .35
			play_sound("hit")
			impact_pause(.035)
		"keeper_dive": burst(event.pos, color, 5, 3)
		"shot", "pass":
			burst(event.pos, Stadium.CREAM, 6, 4)
			play_sound("kick" if type == "shot" else "pass")
			shake = .25 if type == "shot" else .08
			if type == "shot": impact_pause(.033)
		"super":
			burst(event.pos, Color("ffce56"), 28, 12)
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
			burst(event.pos + Vector3.UP * 2, color, 65, 18)
			burst(Vector3(0, 3, -4), Color("ffce56"), 45, 13)
			shake = 1.0
			play_sound("goal")
		"dash": burst(event.pos, color, 5, 3)
		"receive": burst(event.pos, color, 4, 2)
		"whistle": play_sound("whistle")
		"overtime":
			notice = "NEXT GOAL WINS"
			notice_time = 3.0
			play_sound("whistle")
		"finish":
			sim.events_team = event.team
			play_sound("goal")
			party.send({"type": "finished", "session": party.session})

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
	for entry in trail: entry.life = 0.0

func play_sound(name: String) -> void:
	if not sound_enabled or not sounds.has(name) or menu or (party.managed and not host_active): return
	for player in sound_players:
		if not player.playing:
			player.stream = sounds[name]
			player.volume_db = -13 if name != "goal" else -16
			player.pitch_scale = randf_range(.94, 1.06) if name in ["kick", "hit", "pass"] else 1.0
			player.play()
			break

func _input(event: InputEvent) -> void:
	var key := 0
	var button := -1
	if event is InputEventKey and event.pressed and not event.echo: key = event.physical_keycode
	if event is InputEventJoypadButton and event.pressed and not party.managed: button = event.button_index
	if key == KEY_F11:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if key == KEY_F3: show_stats = not show_stats
	if key == KEY_F12:
		capture_path = "res://captures/gameplay.png"
		capture.call_deferred()
	if party.managed and not host_active: return
	if menu:
		if key in [KEY_UP, KEY_W] or button == JOY_BUTTON_DPAD_UP: menu_selection = posmod(menu_selection - 1, 5)
		if key in [KEY_DOWN, KEY_S] or button == JOY_BUTTON_DPAD_DOWN: menu_selection = (menu_selection + 1) % 5
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
				menu_selection = posmod(menu_selection + (1 if event.axis_value > 0 else -1), 5)
				previous["menu_axis"] = 1
			elif absf(event.axis_value) < .3: previous["menu_axis"] = 0
		if event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_X:
			var gate: int = previous.get("menu_x", 0)
			if absf(event.axis_value) > .65 and gate == 0:
				adjust_menu(1 if event.axis_value > 0 else -1)
				previous["menu_x"] = 1
			elif absf(event.axis_value) < .3: previous["menu_x"] = 0
		return
	if sim.phase == "result" and (key == KEY_ENTER or button in [JOY_BUTTON_START, JOY_BUTTON_A]): start_match(); return
	if key in [KEY_ESCAPE, KEY_ENTER] or button == JOY_BUTTON_START:
		paused = not paused
		for player in sound_players: player.stream_paused = paused
	if paused and not party.managed and (key == KEY_TAB or button == JOY_BUTTON_Y):
		menu = true
		paused = false
		sim.setup(0, false, randi(), 120, dual_stick, team_size)
	if party.managed and key == KEY_F1: party.send({"type": "request_overlay"})

func adjust_menu(delta: int) -> void:
	match menu_selection:
		1:
			var choice := 0 if humans == 1 else team_size
			choice = posmod(choice + delta, 4)
			team_size = maxi(1, choice)
			humans = 1 if choice == 0 else team_size * 2
			sim.setup(0, false, 725, 120, dual_stick, team_size)
			sync_arena()
		2:
			if team_size > 1: return
			dual_stick = not dual_stick
			coop = false
			if dual_stick: humans = mini(humans, team_size * 2)
			sim.setup(0, false, 725, 120, dual_stick, team_size)
		3: match_seconds = clampi(match_seconds + delta * 60, 60, 300)
		4: sound_enabled = not sound_enabled

func on_party_command(message: Dictionary) -> void:
	match message.get("type", ""):
		"prepare":
			host_active = false
			menu = false
			paused = true
			configure_managed_matchup()
			humans = mini(party.human_seats().size(), team_size * 2 if dual_stick else team_size * 4)
			coop = false
			managed_buttons.clear()
			sim.setup(humans, false, 725, match_seconds, dual_stick, team_size)
			sync_arena()
			apply_profiles()
			party.send({"type": "participation", "session": party.session, "instant_join": false})
			# Wait until the renderer has prepared the arena before Ready.
			if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
			party.send({"type": "ready", "session": party.session})
		"start":
			party.show_game()
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
				if not buttons & (1 << 6) and Time.get_ticks_msec() > overlay_after: overlay_ready = true
				if buttons & (1 << 7) and not old & (1 << 7):
					if sim.phase == "result": start_match()
					else:
						paused = not paused
						for player in sound_players: player.stream_paused = paused
				if buttons & (1 << 6) and not old & (1 << 6) and overlay_ready:
					overlay_ready = false
					party.send({"type": "request_overlay"})
		"pause":
			host_active = false
			paused = true
			for player in sound_players: player.stream_paused = true
			party.hide_game()
		"resume":
			host_active = true
			paused = false
			previous.clear()
			for player in sound_players: player.stream_paused = false
			party.show_game()
			overlay_after = Time.get_ticks_msec() + 1000
		"dispose":
			host_active = false
			paused = true
			for player in sound_players: player.stop()
			clear_effects()
			party.hide_game()
		"party_updated": apply_profiles()
		"setting_changed":
			if message.get("key", "") == "seconds": match_seconds = clampi(int(message.get("value", 120)), 60, 300)
			elif message.get("key", "") == "matchup" and message.get("value", "") in ["Auto", "1v1", "2v2", "3v3"]:
				managed_matchup = message.value

func apply_profiles() -> void:
	if not party.managed: return
	var seats: Array = party.human_seats()
	for i in sim.players.size():
		var p: Dictionary = sim.players[i]
		p.erase("profile")
		athletes[i].get_node("Body/Head").material_override = stadium.material(Stadium.CREAM)
		athletes[i].get_node("Body/Headband").material_override = stadium.material(Stadium.ORANGE if p.team == 0 else Stadium.BLUE)
		var person: int = p.human / 2 if sim.dual_control else p.human
		if p.human < 0 or person >= seats.size(): continue
		var id: String = str(seats[person].get("occupant", {}).get("player_id", ""))
		var profile: Dictionary = party.profiles.get(id, {})
		p.name = str(profile.get("name", "P%d" % (p.human + 1)))
		p.profile = profile
		athletes[i].get_node("Body/Head").material_override = stadium.material(Color.from_string(str(profile.get("skin_color", "#fff2d2")), Stadium.CREAM))
		athletes[i].get_node("Body/Headband").material_override = stadium.material(Color.from_string(str(profile.get("color", "#fff2d2")), Stadium.CREAM))
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
