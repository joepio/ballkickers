extends RefCounted
## Deterministic simulation, independent of rendering and physical devices.
const HALF_X = 21.0
const HALF_Z = 12.0
const GOAL_Z = 3.7
const GOAL_HEIGHT = 3.1
const RADIUS = 0.65
const SLIDE_RECOVERY = .5
const Chaos = preload("res://src/chaos.gd")
var run_speed := 1.0
var shot_power := 1.0
var ball_friction := 1.0
var keeper_speed := 1.0
var power_charge := 1.0
var super_shots := true
var replays := true
var team_size := 1
## Three-way mode: three teams on a six-sided arena (a triangle with its
## corners cut off), one goal in the middle of each long side. Every team is
## one controller steering two players, one per stick.
var three_way := false
var teams := 2
var arena_factor := 1.0
## Per team: the centre of its goal line "c", the inward normal "n" (into the
## pitch) and the direction along the goal line "t".
var goals: Array = []
## Three-way boundaries: a point "p", an inward normal "n", and the team whose
## goal is in this wall (-1 for a corner wall).
var walls: Array = []
var assist_team := -1
var conceded_team := 1
const TRI_R := 30.0
const TRI_CUT := .7
const TRI_FACTOR := 1.5
## The middle of the pitch: the centre spot. Three-way slides the arena back
## so it sits centred in the stadium.
var arena_center := Vector2.ZERO
var half_x := HALF_X
var half_z := HALF_Z
var rng := RandomNumberGenerator.new()
var players: Array = []
var keepers: Array = []
var keeper_owner := -1
var dual_control := false
var arcade_control := false
var ball := Vector3(0, 0.45, 0)
var ball_velocity := Vector3.ZERO
var owner := -1
var last_touch := -1
var ball_controller := -1
var ball_controller_team := -1
var pickup_lock := 0.0
var score := [0, 0]
var power := [20.0, 20.0]
var clock := 120.0
var duration := 120.0
var phase := "kickoff"
var phase_time := 2.0
var elapsed := 0.0
var overtime := false
var events: Array = []
var stats := {"shots": 0, "passes": 0, "tackles": 0, "goals": 0, "supers": 0}
var chaos = Chaos.new()

static func pitch_scale(team_count: int, three: bool = false) -> float:
	if three: return TRI_FACTOR
	return sqrt(3.0) if team_count >= 3 else 1.0

func setup(humans: int = 1, coop: bool = false, seed_value: int = 42, seconds: float = 120, dual: bool = false, controllers_per_team: int = 1, three: bool = false) -> void:
	three_way = three
	team_size = 1 if three else clampi(controllers_per_team, 1, 3)
	teams = 3 if three else 2
	arena_factor = pitch_scale(team_size, three)
	half_x = HALF_X * arena_factor
	half_z = HALF_Z * arena_factor
	build_arena()
	rng.seed = seed_value
	dual_control = (dual and team_size == 1) or three
	arcade_control = dual or team_size > 1 or three
	players.clear()
	keepers.clear()
	for team in teams:
		keepers.append({"team": team, "pos": keeper_home(team),
			"vel": 0.0, "dive": 0.0, "dive_dir": 1.0, "recovery": 0.0, "reaction": 0.0, "hold": 0.0, "kick": 0.0, "push": 0.0, "slap": 0.0})
	score = []
	power = []
	for team in teams:
		score.append(0)
		power.append(20.0)
	duration = seconds
	clock = seconds
	elapsed = 0.0
	overtime = false
	stats = {"shots": 0, "passes": 0, "tackles": 0, "goals": 0, "supers": 0}
	stats["saves"] = 0
	chaos.setup(seed_value)
	for i in (6 if three_way else (4 if team_size == 1 else team_size * 2)):
		var team: int = i % teams
		var role: int = i / teams
		var human := -1
		if three_way:
			if team < humans: human = team * 2 + role
		elif dual_control:
			var controller: int = (role / 2) * 2 + team
			if controller < humans: human = controller * 2 + role % 2
		elif coop:
			if team == 0 and role < mini(humans, 2): human = role
		else:
			if i < humans: human = i
		players.append({"team": team, "role": role, "human": human, "pos": Vector2.ZERO,
			"vel": Vector2.ZERO, "face": Vector2(1 if team == 0 else -1, 0), "stamina": 1.0,
			"charge": 0.0, "cooldown": 0.0, "stun": 0.0, "dash": 0.0, "kick": 0.0,
			"dash_shot": false, "slide": 0.0,
			"think": rng.randf_range(0, 0.3), "intent": Vector2.ZERO, "shoot_at": rng.randf_range(.3, .9),
			"nerve": rng.randf_range(.7, 1.2), "drift": rng.randf_range(-2.5, 2.5), "held": false,
			"name": "P%d" % (human + 1) if human >= 0 else ["BOLT", "MISO", "ZIG", "POPPY", "BUBS", "NOVA"][i % 6]})
	kickoff(-1)
	events.clear()

func build_arena() -> void:
	goals.clear()
	walls.clear()
	arena_center = Vector2.ZERO
	if not three_way:
		goals.append({"c": Vector2(-half_x, 0), "n": Vector2(1, 0), "t": Vector2(0, 1)})
		goals.append({"c": Vector2(half_x, 0), "n": Vector2(-1, 0), "t": Vector2(0, 1)})
		return
	# Orange defends the lower-left side, blue the lower-right and lime the far
	# side, so the triangle points at the camera.
	var r := TRI_R * .5
	arena_center = Vector2(0, -(TRI_R * TRI_CUT - r) * .5)
	for angle in [-30.0, 210.0, 90.0]:
		var n := Vector2(cos(deg_to_rad(angle)), sin(deg_to_rad(angle)))
		goals.append({"c": arena_center - n * r, "n": n, "t": Vector2(-n.y, n.x)})
	for team in 3:
		walls.append({"p": goals[team].c, "n": goals[team].n, "goal": team})
	for team in 3:
		# The corner opposite each goal is cut off by a short rebound wall.
		walls.append({"p": arena_center + goals[team].n * TRI_R * TRI_CUT, "n": -goals[team].n, "goal": -1})
	half_x = 0.0
	half_z = 0.0
	for corner in arena_corners():
		half_x = maxf(half_x, absf(corner.x))
		half_z = maxf(half_z, absf(corner.y))

## The six corners of the three-way arena, in order around it.
func arena_corners() -> Array:
	var result: Array = []
	for team in 3:
		var n: Vector2 = goals[team].n
		var line := -TRI_R * .5
		# Each goal side runs between the two corner walls next to it.
		for other in [(team + 1) % 3, (team + 2) % 3]:
			var m: Vector2 = -goals[other].n
			var cut := -TRI_R * TRI_CUT
			var det := n.x * m.y - n.y * m.x
			result.append(arena_center + Vector2((line * m.y - n.y * cut) / det, (n.x * cut - m.x * line) / det))
	return result

func keeper_home(team: int) -> Vector2:
	return goals[team].c + goals[team].n * 1.6

## Keeps a point inside the three-way arena, `margin` from every wall.
func confine(pos: Vector2, margin: float) -> Vector2:
	for pass_index in 2:
		for w in walls:
			var depth: float = (pos - w.p).dot(w.n)
			if depth < margin: pos += w.n * (margin - depth)
	return pos

func touch(i: int) -> void:
	# Remember the last other team on the ball, to credit own goals in three-way.
	if i >= 0 and last_touch >= 0 and players[last_touch].team != players[i].team:
		assist_team = players[last_touch].team
	last_touch = i

func kickoff(team: int) -> void:
	keeper_owner = -1
	for k in keepers:
		k.pos = keeper_home(k.team)
		for field in ["vel", "dive", "recovery", "reaction", "hold", "kick", "push", "slap"]: k[field] = 0.0
	for i in players.size():
		var p: Dictionary = players[i]
		if three_way:
			# Side by side in front of their own goal, the left stick's player on
			# the left of the screen, like the two-team kickoff.
			var g: Dictionary = goals[p.team]
			var left: Vector2 = -g.t if g.t.x > 0 else g.t
			p.pos = g.c + g.n * 8.0 + left * (4.0 if p.role == 0 else -4.0)
			p.face = g.n
		var direction: float = 1 if p.team == 0 else -1
		# Screen X increases to the right for both teams. Mirror the formation,
		# not the controller halves: L starts left and R starts right each kickoff.
		var spawn_role: int = 1 - (p.role % 2) if dual_control and p.team == 0 else p.role % 2
		if not three_way:
			p.pos = Vector2(-direction * (5.5 if spawn_role == 0 else 12.0), 0 if spawn_role == 0 else 4.5)
			p.pos.x *= pitch_scale(team_size)
			if team_size > 1: p.pos.y = (float(p.role) - (team_size - 1) * .5) * (half_z * 1.35 / team_size)
			p.face = Vector2(direction, 0)
		p.vel = Vector2.ZERO
		p.stun = 0.0
		p.charge = 0.0
		p.held = false
		p.cooldown = 0.0
		p.dash = 0.0
		p.dash_shot = false
		p.slide = 0.0
	ball = vec3(arena_center, .45)
	ball_velocity = Vector3.ZERO
	owner = -1
	last_touch = -1
	assist_team = -1
	ball_controller = -1
	ball_controller_team = -1
	pickup_lock = 0.0
	if team >= 0 and three_way:
		players[team].pos = arena_center - goals[team].n * 1.0
	elif team >= 0:
		var taker: int = 2 if dual_control and team == 0 else team
		players[taker].pos = Vector2(-1.0 if team == 0 else 1.0, 0)
	phase = "kickoff"
	phase_time = 2.2
	chaos.clear()

func step(dt: float, inputs: Dictionary = {}) -> void:
	events.clear()
	elapsed += dt
	if phase == "result": return
	if phase == "goal":
		phase_time -= dt
		if phase_time <= 0:
			if overtime or clock <= 0: finish()
			else: kickoff(conceded_team)
		return
	if phase == "kickoff":
		phase_time -= dt
		if phase_time <= 0:
			phase = "play"
			events.append({"type": "whistle", "pos": ball})
		return
	if not overtime: clock = maxf(0, clock - dt)
	pickup_lock = maxf(0, pickup_lock - dt)
	for team in teams: power[team] = minf(100, power[team] + dt * 1.9 * power_charge)
	for i in players.size():
		var p: Dictionary = players[i]
		var control: Dictionary = inputs.get(p.human, {}) if p.human >= 0 else ai_input(i, dt)
		if arcade_control:
			control = control.duplicate()
			control["pass"] = false
			control["sprint"] = false
		move_player(i, control, dt)
	resolve_bodies()
	update_keepers(dt)
	move_ball(dt)
	if phase == "play": chaos.step(self, dt)
	if clock <= 0 and phase == "play":
		if score.count(score.max()) > 1:
			if not overtime: events.append({"type": "overtime", "pos": ball})
			overtime = true
		else: finish()

func move_player(i: int, input: Dictionary, dt: float) -> void:
	var p: Dictionary = players[i]
	p.cooldown = maxf(0, p.cooldown - dt)
	p.stun = maxf(0, p.stun - dt)
	p.dash = maxf(0, p.dash - dt)
	p.slide = maxf(0, p.slide - dt)
	if p.dash <= 0 or p.stun > 0: p.dash_shot = false
	p.kick = maxf(0, p.kick - dt)
	var move: Vector2 = input.get("move", Vector2.ZERO)
	move = move.limit_length()
	var shoot: bool = input.get("shoot", false)
	if p.stun > 0:
		p.vel = p.vel.move_toward(Vector2.ZERO, dt * 16)
		p.charge = 0.0
	else:
		if move.length() > .15: p.face = p.face.slerp(move.normalized(), minf(1, dt * 22))
		var sprint: bool = input.get("sprint", false) and p.stamina > .05 and move.length() > .1
		p.stamina = clampf(p.stamina + dt * (-.32 if sprint else .24), 0, 1)
		var speed := (12.8 if sprint else 9.0) * run_speed
		if owner == i: speed *= .91
		if p.charge > 0: speed *= .66
		# Getting up from a missed slide tackle: a dash that hits nobody and no ball slows you down.
		var sliding: bool = p.dash <= 0 and p.slide > 0
		if sliding: speed *= .25
		if p.dash > 0:
			p.vel = p.face * 22.0
		else: p.vel = p.vel.move_toward(move * speed, dt * (140.0 if sliding else (64.0 if move.length() > .1 else 48.0)) * chaos.grip)
		if input.get("tackle", false) and owner != i and p.cooldown <= 0 and p.stamina > .2:
			p.dash = .21
			p.slide = .21 + SLIDE_RECOVERY
			p.dash_shot = true
			p.vel = p.face * 22.0
			p.cooldown = .9
			p.stamina -= .2
			events.append({"type": "dash", "pos": vec3(p.pos), "team": p.team})
		if owner == i:
			if input.get("pass", false):
				pass_ball(i, move)
			elif shoot:
				p.charge = minf(1.15, p.charge + dt)
			elif p.held:
				shoot_ball(i)
		else: p.charge = 0.0
	p.held = shoot
	p.pos += p.vel * dt
	keep_on_pitch(p)
	if p.dash > 0:
		for j in players.size():
			var q: Dictionary = players[j]
			if q.team == p.team or q.stun > .1: continue
			if p.pos.distance_to(q.pos) < 1.65:
				q.stun = .75
				q.vel = p.face * 17
				p.dash = 0.0
				p.slide = 0.0
				stats.tackles += 1
				power[p.team] = minf(100, power[p.team] + 9)
				if owner == j:
					owner = -1
					ball = vec3(q.pos, .5)
					ball_velocity = vec3(p.face * 12, 3.5)
					pickup_lock = .14
				events.append({"type": "hit", "pos": vec3(q.pos, 1), "team": p.team})

func resolve_bodies() -> void:
	for i in players.size():
		for j in range(i + 1, players.size()):
			var a: Dictionary = players[i]
			var b: Dictionary = players[j]
			var offset: Vector2 = b.pos - a.pos
			var distance := offset.length()
			if distance < RADIUS * 2:
				var normal := offset / distance if distance > .001 else Vector2.RIGHT
				var correction := normal * (RADIUS * 2 - distance) * .5
				a.pos -= correction
				b.pos += correction
	for p in players: keep_on_pitch(p)

func keep_on_pitch(p: Dictionary) -> void:
	if three_way:
		p.pos = confine(p.pos, RADIUS)
		return
	p.pos.x = clampf(p.pos.x, -half_x + RADIUS, half_x - RADIUS)
	p.pos.y = clampf(p.pos.y, -half_z + RADIUS, half_z - RADIUS)

func shoot_ball(i: int) -> void:
	var p: Dictionary = players[i]
	ball_controller = p.human
	ball_controller_team = p.team
	var charge: float = p.charge
	var direction := Vector2(1 if p.team == 0 else -1, 0)
	# Face-to-goal assistance only in the forward cone. Aim still selects a corner.
	var goal := Vector2(direction.x * (half_x + 1), clampf(p.face.y * 4.8, -3.0, 3.0))
	var toward: Vector2 = (goal - p.pos).normalized()
	if arcade_control: direction = p.face
	elif p.face.dot(direction) > .1: direction = toward
	else: direction = p.face
	var super_shot: bool = super_shots and charge >= .85 and power[p.team] >= 99
	if super_shot:
		power[p.team] = 0.0
		stats.supers += 1
	else: power[p.team] = minf(100, power[p.team] + 6)
	owner = -1
	touch(i)
	ball = vec3(confine(p.pos + direction * 1.2, .43) if three_way else p.pos + direction * 1.2, .55)
	ball_velocity = vec3(direction * (55.0 if super_shot else 24.0 + charge * 17.0) * shot_power, 2.6 + charge * 1.2)
	pickup_lock = .22
	p.kick = .25
	p.charge = 0.0
	stats.shots += 1
	events.append({"type": "super" if super_shot else "shot", "pos": ball, "team": p.team})

func pass_ball(i: int, aim: Vector2) -> void:
	var p: Dictionary = players[i]
	ball_controller = p.human
	ball_controller_team = p.team
	var target := -1
	var best := -INF
	if aim.length() < .2: aim = p.face
	for j in players.size():
		var q: Dictionary = players[j]
		if j == i or q.team != p.team: continue
		var delta: Vector2 = q.pos - p.pos
		var rating := delta.normalized().dot(aim.normalized()) * 16.0 - delta.length() * .15
		if rating > best: best = rating; target = j
	if target < 0: return
	var delta: Vector2 = players[target].pos + players[target].vel * .15 - p.pos
	var direction := delta.normalized()
	owner = -1
	touch(i)
	ball = vec3(p.pos + direction * 1.2, .45)
	ball_velocity = vec3(direction * clampf(delta.length() * 2, 18, 29), 1.0)
	pickup_lock = .14
	p.charge = 0.0
	p.kick = .22
	power[p.team] = minf(100, power[p.team] + 6)
	stats.passes += 1
	events.append({"type": "pass", "pos": ball, "team": p.team})

func move_ball(dt: float) -> void:
	if keeper_owner >= 0:
		var k: Dictionary = keepers[keeper_owner]
		ball = vec3(k.pos + goals[k.team].n * .65, 1.15)
		ball_velocity = Vector3.ZERO
		return
	if owner >= 0:
		var p: Dictionary = players[owner]
		var at: Vector2 = p.pos + p.face * 1.0
		if three_way: at = confine(at, .43)
		ball = vec3(at, .45 + absf(sin(elapsed * 16)) * minf(.15, p.vel.length() * .01))
		ball_velocity = vec3(p.vel)
		keeper_save(ball, ball)
		return
	var before := ball
	ball_velocity.y -= 20 * dt
	ball += ball_velocity * dt
	if ball.y < .43:
		ball.y = .43
		ball_velocity.y = absf(ball_velocity.y) * .48 if absf(ball_velocity.y) > 1 else 0.0
		var ground_velocity := Vector2(ball_velocity.x, ball_velocity.z).move_toward(Vector2.ZERO, dt * 3.6 * ball_friction * chaos.slide)
		ball_velocity.x = ground_velocity.x
		ball_velocity.z = ground_velocity.y
	if three_way:
		tri_walls(before)
		return
	if absf(ball.z) > half_z - .43:
		ball.z = signf(ball.z) * (half_z - .43)
		ball_velocity.z *= -.82
		events.append({"type": "bounce", "pos": ball})
	if keeper_save(before, ball): return
	if absf(ball.x) > half_x:
		# Interpolate the line crossing, so fast shots cannot skip the goal mouth.
		var crossing := before.lerp(ball, clampf((signf(ball.x) * half_x - before.x) / (ball.x - before.x) if absf(ball.x - before.x) > .001 else 1.0, 0, 1))
		if absf(crossing.z) < GOAL_Z - .3 and crossing.y < GOAL_HEIGHT - .25:
			goal_scored(0 if ball.x > 0 else 1)
			return
		ball.x = signf(ball.x) * half_x
		ball_velocity.x *= -.8
		events.append({"type": "bounce", "pos": ball})
	pick_up()

func tri_walls(before: Vector3) -> void:
	# Corner walls first, then the keepers, then the goal sides with their mouths.
	for w in walls:
		if w.goal < 0: bounce_wall(w, .43, .82)
	if keeper_save(before, ball): return
	for w in walls:
		if w.goal < 0: continue
		var depth: float = (Vector2(ball.x, ball.z) - w.p).dot(w.n)
		if depth >= 0: continue
		var was: float = (Vector2(before.x, before.z) - w.p).dot(w.n)
		var crossing := before.lerp(ball, clampf(was / (was - depth), 0, 1) if was - depth > .001 else 1.0)
		var lateral: float = (Vector2(crossing.x, crossing.z) - w.p).dot(goals[w.goal].t)
		if was >= 0 and absf(lateral) < GOAL_Z - .3 and crossing.y < GOAL_HEIGHT - .25:
			tri_goal(w.goal)
			return
		bounce_wall(w, 0.0, .8)
	# A push off a goal side can land past a corner wall where the two meet.
	for w in walls:
		if w.goal < 0: bounce_wall(w, .43, .82)
	pick_up()

func bounce_wall(w: Dictionary, margin: float, keep: float) -> void:
	var flat := Vector2(ball.x, ball.z)
	var depth: float = (flat - w.p).dot(w.n)
	if depth >= margin: return
	flat += w.n * (margin - depth)
	var velocity := Vector2(ball_velocity.x, ball_velocity.z)
	var into: float = velocity.dot(w.n)
	if into < 0: velocity -= w.n * into * (1.0 + keep)
	ball = Vector3(flat.x, ball.y, flat.y)
	ball_velocity = Vector3(velocity.x, ball_velocity.y, velocity.y)
	events.append({"type": "bounce", "pos": ball})

func tri_goal(conceding: int) -> void:
	# The last other team to touch it scores. An own goal goes to whoever had
	# it before, or else to the next team round.
	var scorer := -1
	if last_touch >= 0 and players[last_touch].team != conceding: scorer = players[last_touch].team
	elif assist_team >= 0 and assist_team != conceding: scorer = assist_team
	else: scorer = (conceding + 1) % 3
	goal_scored(scorer, null, conceding)

func pick_up() -> void:
	if pickup_lock > 0 or ball.y > 1.55: return
	for i in players.size():
		var p: Dictionary = players[i]
		if p.stun > 0: continue
		if p.pos.distance_to(Vector2(ball.x, ball.z)) < 1.35:
			var speed := Vector2(ball_velocity.x, ball_velocity.z).length()
			if speed > 32 and i != last_touch and last_touch >= 0 and p.team != players[last_touch].team:
				p.stun = .55
				p.vel = Vector2(ball_velocity.x, ball_velocity.z).normalized() * 12
				ball_velocity *= .72
				pickup_lock = .10
				events.append({"type": "hit", "pos": ball, "team": players[last_touch].team})
				return
			owner = i
			touch(i)
			p.charge = 0.0
			auto_control_receiver(i)
			if p.dash > 0 and p.dash_shot:
				p.charge = .35
				p.dash = 0.0
				p.slide = 0.0
				p.dash_shot = false
				shoot_ball(i)
				return
			events.append({"type": "receive", "pos": ball, "team": p.team})
			return

var events_team := 0
func goal_scored(team: int, at = null, conceding: int = -1) -> void:
	keeper_owner = -1
	conceded_team = conceding if conceding >= 0 else 1 - team
	score[team] += 1
	stats.goals += 1
	phase = "goal"
	phase_time = 2.5
	events_team = team
	owner = -1
	ball_velocity = Vector3.ZERO
	power[conceded_team] = minf(100, power[conceded_team] + 18)
	events.append({"type": "goal", "pos": ball if at == null else at, "team": team, "bonus": at != null})

func finish() -> void:
	phase = "result"
	events.append({"type": "finish", "pos": ball, "team": score.find(score.max())})

func switch_player(human: int) -> void:
	var current := -1
	for i in players.size():
		if players[i].human == human: current = i; break
	if current < 0: return
	var nearest := -1
	var best := INF
	for i in players.size():
		var p: Dictionary = players[i]
		if p.team != players[current].team or p.human >= 0: continue
		var d: float = p.pos.distance_to(Vector2(ball.x, ball.z))
		if owner == i: d = -10.0
		if d < best: nearest = i; best = d
	if nearest >= 0:
		players[nearest].human = human
		players[current].human = -1
		players[current].held = false
		players[current].charge = 0.0

func auto_control_receiver(receiver: int) -> void:
	if arcade_control: return
	var receiving: Dictionary = players[receiver]
	if receiving.human >= 0: return
	var source := -1
	var best := INF
	for i in players.size():
		var p: Dictionary = players[i]
		if p.human < 0 or p.team != receiving.team: continue
		var distance: float = p.pos.distance_to(receiving.pos)
		if p.human == ball_controller and p.team == ball_controller_team: distance = -1
		if distance < best: best = distance; source = i
	if source < 0: return
	receiving.human = players[source].human
	receiving.held = false
	players[source].human = -1
	players[source].held = false
	players[source].charge = 0.0
	events.append({"type": "control_changed", "pos": ball, "team": receiving.team})

func ai_input(i: int, dt: float) -> Dictionary:
	if three_way: return ai_three_way(i, dt)
	var p: Dictionary = players[i]
	var target: Vector2 = p.intent
	p.think -= dt
	var direction := 1.0 if p.team == 0 else -1.0
	var ball_pos := Vector2(ball.x, ball.z)
	var has_ball := owner == i
	var ally_ball: bool = owner >= 0 and players[owner].team == p.team
	if p.think <= 0:
		p.think = rng.randf_range(.12, .28)
		if rng.randf() < .12: p.drift = rng.randf_range(-3, 3)
		if has_ball:
			target = Vector2(half_x * direction, p.drift)
		else:
			var nearest := i
			var distance: float = p.pos.distance_to(ball_pos)
			for j in players.size():
				if players[j].team != p.team or players[j].stun > 0: continue
				var d: float = players[j].pos.distance_to(ball_pos)
				if d < distance: nearest = j; distance = d
			if nearest == i and not ally_ball:
				target = ball_pos + Vector2(ball_velocity.x, ball_velocity.z).limit_length(16) * .10
			elif ally_ball:
				target = Vector2(clampf(ball_pos.x + direction * 5.5, -half_x + 4, half_x - 4), lerpf(-half_z * .7, half_z * .7, float(p.role) / maxf(1, team_size * 2 - 1)) + p.drift * .5)
			else:
				target = Vector2(clampf(ball_pos.x - direction * (7 + (p.role % 2) * 2), -half_x + 3, half_x - 3), clampf(ball_pos.y * .4 + (p.role - (team_size * 2 - 1) * .5) * 4, -half_z + 2, half_z - 2))
		p.intent = target
	var move: Vector2 = (target - p.pos).limit_length()
	var shoot := false
	var do_pass := false
	if has_ball:
		var goal_distance: float = absf(direction * half_x - p.pos.x)
		var pressure := 100.0
		for q in players:
			if q.team != p.team: pressure = minf(pressure, q.pos.distance_to(p.pos))
		if goal_distance < 14 or p.charge > 0:
			shoot = p.charge < p.shoot_at
			if not shoot: p.shoot_at = rng.randf_range(.12, 1.05)
		elif pressure < 2.7 and rng.randf() < dt * 3: do_pass = true
	return {"move": move, "shoot": shoot, "pass": do_pass,
		"tackle": not ally_ball and p.pos.distance_to(ball_pos) < 2.8 and rng.randf() < dt * 4 * p.nerve,
		"sprint": p.stamina > .32 and (has_ball or p.pos.distance_to(ball_pos) < 8)}

## Three-way bots: chase the ball, carry it at whichever other goal is
## closest, and shoot once in range.
func ai_three_way(i: int, dt: float) -> Dictionary:
	var p: Dictionary = players[i]
	var ball_pos := Vector2(ball.x, ball.z)
	var has_ball := owner == i
	var own_keeper: bool = keeper_owner == p.team
	p.think -= dt
	if p.think <= 0:
		p.think = rng.randf_range(.12, .28)
		if rng.randf() < .12: p.drift = rng.randf_range(-3, 3)
		var best := INF
		for team in teams:
			if team == p.team: continue
			var d: float = p.pos.distance_to(goals[team].c) + rng.randf_range(0, 4)
			if d < best:
				best = d
				p["aim_goal"] = team
		var g: Dictionary = goals[p.get("aim_goal", (p.team + 1) % teams)]
		if has_ball: p.intent = g.c + g.n * 2.0 + g.t * p.drift * .5
		elif own_keeper: p.intent = goals[p.team].c + goals[p.team].n * 9.0
		else:
			p.intent = ball_pos + Vector2(ball_velocity.x, ball_velocity.z).limit_length(16) * .10
			# Two players a side: whoever is further from the ball covers instead
			# of crowding in, up front when the mate has it, else in front of goal.
			var mate: int = i + 3 if i < 3 else i - 3
			if mate < players.size() and (owner == mate or players[mate].pos.distance_to(ball_pos) + 1.5 < p.pos.distance_to(ball_pos)):
				var home: Dictionary = goals[p.team]
				if owner == mate: p.intent = g.c + g.n * 7.0 + g.t * p.drift * 1.5
				else: p.intent = home.c + home.n * 9.0 + (ball_pos - home.c).limit_length(6.0) * .6
	var move: Vector2 = (p.intent - p.pos).limit_length()
	var shoot := false
	if has_ball:
		var target: Dictionary = goals[p.get("aim_goal", (p.team + 1) % teams)]
		if p.pos.distance_to(target.c) < 13 or p.charge > 0:
			shoot = p.charge < p.shoot_at
			if not shoot: p.shoot_at = rng.randf_range(.12, 1.05)
	return {"move": move, "shoot": shoot, "pass": false,
		"tackle": not has_ball and not own_keeper and p.pos.distance_to(ball_pos) < 2.8 and rng.randf() < dt * 4 * p.nerve,
		"sprint": false}

static func vec3(v: Vector2, height: float = 0) -> Vector3:
	return Vector3(v.x, height, v.y)

## Walk up to the keeper and you get a clip round the ear: knocked down and
## pushed back, losing the ball if you had it.
const SLAP_REACH := 1.55

func keeper_slap(k: Dictionary) -> void:
	if k.slap > 0 or k.dive > 0 or keeper_owner == k.team: return
	for i in players.size():
		var p: Dictionary = players[i]
		if p.team == k.team or p.stun > 0: continue
		var away: Vector2 = p.pos - k.pos
		if away.length() > SLAP_REACH: continue
		var dir: Vector2 = away.normalized() if away.length() > .01 else goals[k.team].n
		p.stun = .7
		p.dash = 0.0
		p.charge = 0.0
		p.vel = dir * 14
		k.kick = .2
		k.slap = .8
		if owner == i:
			owner = -1
			ball = vec3(p.pos, .5)
			ball_velocity = vec3(dir * 9, 2.5)
			pickup_lock = .2
		events.append({"type": "hit", "pos": vec3(p.pos, 1), "team": k.team})
		return

func update_keepers(dt: float) -> void:
	# Each keeper works in its own goal's frame: depth out from the goal line
	# along "n", and lateral along the line ("t").
	for k in keepers:
		var g: Dictionary = goals[k.team]
		k.recovery = maxf(0, k.recovery - dt)
		k.kick = maxf(0, k.kick - dt)
		k.slap = maxf(0, k.slap - dt)
		keeper_slap(k)
		var depth: float = (k.pos - g.c).dot(g.n)
		var lateral: float = (k.pos - g.c).dot(g.t)
		depth += k.push * dt
		k.push = move_toward(k.push, 0.0, dt * 22)
		if absf(k.push) < .1: depth = move_toward(depth, 1.6, dt * 3)
		depth = maxf(depth, -1.7)
		k.pos = g.c + g.n * depth + g.t * lateral
		if keeper_owner == k.team:
			k.hold -= dt
			if k.hold <= 0: distribute(k)
			continue
		var from_goal: Vector2 = Vector2(ball.x, ball.z) - g.c
		var ball_depth: float = from_goal.dot(g.n)
		var ball_lateral: float = from_goal.dot(g.t)
		var flat := Vector2(ball_velocity.x, ball_velocity.z)
		var inward_speed: float = flat.dot(g.n)
		var target := clampf(ball_lateral * .55, -2.65, 2.65)
		var approaching: bool = owner < 0 and keeper_owner < 0 and inward_speed < -8
		var eta: float = (depth - ball_depth) / inward_speed if approaching else 10.0
		var threat: bool = approaching and eta > 0 and eta < .65
		if threat:
			k.reaction += dt
			target = clampf(ball_lateral + flat.dot(g.t) * eta, -3.25, 3.25)
		else: k.reaction = 0.0
		if k.dive > 0:
			k.dive = maxf(0, k.dive - dt)
			lateral += k.vel * dt
		elif k.recovery <= 0:
			if threat and k.reaction > .14 and eta < .36 and absf(target - lateral) > .65:
				k.dive = .28
				k.recovery = .85
				k.dive_dir = signf(target - lateral)
				k.vel = k.dive_dir * 12.0 * keeper_speed
				events.append({"type": "keeper_dive", "pos": vec3(k.pos, .7), "team": k.team})
			else:
				k.vel = clampf((target - lateral) * 6, -4.5, 4.5) * keeper_speed
				lateral += k.vel * dt
		else: k.vel = 0.0
		lateral = clampf(lateral, -3.25, 3.25)
		k.pos = g.c + g.n * depth + g.t * lateral

func keeper_save(before: Vector3, after: Vector3) -> bool:
	# Swept test, before scoring: fast balls cannot tunnel through the gloves.
	var segment := after - before
	for k in keepers:
		if k.recovery > 0 and k.dive <= 0: continue
		var center := vec3(k.pos, 1.0)
		var t := clampf((center - before).dot(segment) / segment.length_squared(), 0, 1) if segment.length_squared() > .00001 else 0.0
		var contact := before + segment * t
		var reach := 1.45 if k.dive > 0 else 1.03
		if Vector2(contact.x - center.x, contact.z - center.z).length() > reach or contact.y > 2.15: continue
		# Do not recatch our own distribution or touch a ball moving out of goal.
		var g: Dictionary = goals[k.team]
		if owner < 0 and Vector2(ball_velocity.x, ball_velocity.z).dot(g.n) > 2: continue
		var speed := ball_velocity.length()
		var difficulty := clampf((speed - 18.0) / 42.0, 0.0, 1.0)
		var edge := clampf(Vector2(contact.x - center.x, contact.z - center.z).length() / reach, 0, 1)
		var save_chance := clampf(.98 - difficulty * .64 - edge * .10, .22, .98)
		# One seeded roll per contact, with recovery preventing repeated rerolls.
		if rng.randf() > save_chance:
			k.recovery = .8
			k.dive = 0.0
			k.push = -lerpf(1.0, 12.0, difficulty)
			ball_velocity *= .84
			events.append({"type": "keeper_beaten", "pos": contact, "team": k.team})
			return false
		if owner >= 0:
			players[owner].charge = 0.0
			players[owner].held = false
		owner = -1
		stats.saves += 1
		power[k.team] = minf(100, power[k.team] + 5)
		ball = contact
		k.push = -maxf(0, speed - 25) * .18
		if speed < 29 and k.dive <= 0:
			keeper_owner = k.team
			k.hold = .5
			ball_velocity = Vector3.ZERO
		else:
			# Successful powerful saves still spill dangerous rebounds and push the keeper back.
			var side := signf((Vector2(contact.x, contact.z) - k.pos).dot(g.t))
			if side == 0: side = k.dive_dir
			var out: Vector2 = g.n * maxf(9, speed * .42) + g.t * side * 10
			ball_velocity = Vector3(out.x, 4.5, out.y)
			var flat := Vector2(ball.x, ball.z)
			flat += g.n * ((k.pos - flat).dot(g.n) + 1.5)
			ball.x = flat.x
			ball.z = flat.y
			k.recovery = .9 if speed > 44 else .65
			k.dive = minf(k.dive, .12)
		pickup_lock = .16
		events.append({"type": "save", "pos": ball, "team": k.team})
		return true
	return false

func distribute(k: Dictionary) -> void:
	var g: Dictionary = goals[k.team]
	var target := -1
	var best := -INF
	for i in players.size():
		var p: Dictionary = players[i]
		if p.team != k.team or p.stun > 0: continue
		var space := 12.0
		for q in players:
			if q.team != k.team: space = minf(space, q.pos.distance_to(p.pos))
		var rating: float = space - p.pos.distance_to(k.pos) * .15
		if rating > best: best = rating; target = i
	var destination: Vector2 = players[target].pos + players[target].vel * .2 if target >= 0 else Vector2.ZERO
	var direction: Vector2 = (destination - k.pos).normalized()
	if direction.dot(g.n) < .2: direction = (g.n + g.t * direction.dot(g.t)).normalized()
	keeper_owner = -1
	touch(target)
	ball = vec3(k.pos + direction * 1.6, .6)
	ball_velocity = vec3(direction * 25, 1.6)
	pickup_lock = .18
	k.recovery = .35
	k.kick = .3
	events.append({"type": "pass", "pos": ball, "team": k.team})
