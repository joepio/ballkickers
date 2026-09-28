extends RefCounted
## Deterministic simulation, independent of rendering and physical devices.
const HALF_X = 21.0
const HALF_Z = 12.0
const GOAL_Z = 3.7
const GOAL_HEIGHT = 3.1
const RADIUS = 0.65
var rng := RandomNumberGenerator.new()
var players: Array = []
var ball := Vector3(0, 0.45, 0)
var ball_velocity := Vector3.ZERO
var owner := -1
var last_touch := -1
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

func setup(humans: int = 1, coop: bool = false, seed_value: int = 42, seconds: float = 120) -> void:
	rng.seed = seed_value
	players.clear()
	score = [0, 0]
	power = [20.0, 20.0]
	duration = seconds
	clock = seconds
	elapsed = 0.0
	overtime = false
	stats = {"shots": 0, "passes": 0, "tackles": 0, "goals": 0, "supers": 0}
	for i in 6:
		var team: int = i % 2
		var role: int = i / 2
		var human := -1
		if coop:
			if team == 0 and role < mini(humans, 3): human = role
		else:
			if i < humans: human = i
		players.append({"team": team, "role": role, "human": human, "pos": Vector2.ZERO,
			"vel": Vector2.ZERO, "face": Vector2(1 if team == 0 else -1, 0), "stamina": 1.0,
			"charge": 0.0, "cooldown": 0.0, "stun": 0.0, "dash": 0.0, "kick": 0.0,
			"think": rng.randf_range(0, 0.3), "intent": Vector2.ZERO, "shoot_at": rng.randf_range(.3, .9),
			"nerve": rng.randf_range(.7, 1.2), "drift": rng.randf_range(-2.5, 2.5), "held": false,
			"name": "P%d" % (human + 1) if human >= 0 else ["BOLT", "MISO", "ZIG", "POPPY", "BUBS", "NOVA"][i]})
	kickoff(-1)
	events.clear()

func kickoff(team: int) -> void:
	for i in players.size():
		var p: Dictionary = players[i]
		var direction: float = 1 if p.team == 0 else -1
		p.pos = Vector2(-direction * (5.5 if p.role == 0 else 12.0), 0 if p.role == 0 else (-6.0 if p.role == 1 else 6.0))
		p.vel = Vector2.ZERO
		p.face = Vector2(direction, 0)
		p.stun = 0.0
		p.charge = 0.0
		p.held = false
		p.cooldown = 0.0
		p.dash = 0.0
	ball = Vector3(0, .45, 0)
	ball_velocity = Vector3.ZERO
	owner = -1
	last_touch = -1
	pickup_lock = 0.0
	if team >= 0:
		players[team].pos = Vector2(-1.0 if team == 0 else 1.0, 0)
	phase = "kickoff"
	phase_time = 2.2

func step(dt: float, inputs: Dictionary = {}) -> void:
	events.clear()
	elapsed += dt
	if phase == "result": return
	if phase == "goal":
		phase_time -= dt
		if phase_time <= 0:
			if overtime or clock <= 0: finish()
			else: kickoff(1 - int(events_team))
		return
	if phase == "kickoff":
		phase_time -= dt
		if phase_time <= 0:
			phase = "play"
			events.append({"type": "whistle", "pos": ball})
		return
	if not overtime: clock = maxf(0, clock - dt)
	pickup_lock = maxf(0, pickup_lock - dt)
	for team in 2: power[team] = minf(100, power[team] + dt * 1.9)
	for i in players.size():
		var p: Dictionary = players[i]
		var control: Dictionary = inputs.get(p.human, {}) if p.human >= 0 else ai_input(i, dt)
		move_player(i, control, dt)
	resolve_bodies()
	move_ball(dt)
	if clock <= 0 and phase == "play":
		if score[0] == score[1]:
			if not overtime: events.append({"type": "overtime", "pos": ball})
			overtime = true
		else: finish()

func move_player(i: int, input: Dictionary, dt: float) -> void:
	var p: Dictionary = players[i]
	p.cooldown = maxf(0, p.cooldown - dt)
	p.stun = maxf(0, p.stun - dt)
	p.dash = maxf(0, p.dash - dt)
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
		var speed := 12.8 if sprint else 9.0
		if owner == i: speed *= .91
		if p.charge > 0: speed *= .66
		if p.dash > 0:
			p.vel = p.face * 22.0
		else: p.vel = p.vel.move_toward(move * speed, dt * (64.0 if move.length() > .1 else 48.0))
		if input.get("tackle", false) and p.cooldown <= 0 and p.stamina > .2:
			p.dash = .21
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
	p.pos.x = clampf(p.pos.x, -HALF_X + RADIUS, HALF_X - RADIUS)
	p.pos.y = clampf(p.pos.y, -HALF_Z + RADIUS, HALF_Z - RADIUS)
	if p.dash > 0:
		for j in players.size():
			var q: Dictionary = players[j]
			if q.team == p.team or q.stun > .1: continue
			if p.pos.distance_to(q.pos) < 1.65:
				q.stun = .75
				q.vel = p.face * 17
				p.dash = 0.0
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
	for p in players:
		p.pos.x = clampf(p.pos.x, -HALF_X + RADIUS, HALF_X - RADIUS)
		p.pos.y = clampf(p.pos.y, -HALF_Z + RADIUS, HALF_Z - RADIUS)

func shoot_ball(i: int) -> void:
	var p: Dictionary = players[i]
	var charge: float = p.charge
	var direction := Vector2(1 if p.team == 0 else -1, 0)
	# Face-to-goal assistance only in the forward cone. Aim still selects a corner.
	var goal := Vector2(direction.x * (HALF_X + 1), clampf(p.face.y * 4.8, -3.0, 3.0))
	var toward: Vector2 = (goal - p.pos).normalized()
	if p.face.dot(direction) > .1: direction = toward
	else: direction = p.face
	var super_shot: bool = charge >= .85 and power[p.team] >= 99
	if super_shot:
		power[p.team] = 0.0
		stats.supers += 1
	else: power[p.team] = minf(100, power[p.team] + 6)
	owner = -1
	last_touch = i
	ball = vec3(p.pos + direction * 1.2, .55)
	ball_velocity = vec3(direction * (55.0 if super_shot else 24.0 + charge * 17.0), 2.6 + charge * 1.2)
	pickup_lock = .22
	p.kick = .25
	p.charge = 0.0
	stats.shots += 1
	events.append({"type": "super" if super_shot else "shot", "pos": ball, "team": p.team})

func pass_ball(i: int, aim: Vector2) -> void:
	var p: Dictionary = players[i]
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
	last_touch = i
	ball = vec3(p.pos + direction * 1.2, .45)
	ball_velocity = vec3(direction * clampf(delta.length() * 2, 18, 29), 1.0)
	pickup_lock = .14
	p.charge = 0.0
	p.kick = .22
	power[p.team] = minf(100, power[p.team] + 6)
	stats.passes += 1
	events.append({"type": "pass", "pos": ball, "team": p.team})

func move_ball(dt: float) -> void:
	if owner >= 0:
		var p: Dictionary = players[owner]
		ball = vec3(p.pos + p.face * 1.0, .45 + absf(sin(elapsed * 16)) * minf(.15, p.vel.length() * .01))
		ball_velocity = vec3(p.vel)
		return
	var before := ball
	ball_velocity.y -= 20 * dt
	ball += ball_velocity * dt
	if ball.y < .43:
		ball.y = .43
		ball_velocity.y = absf(ball_velocity.y) * .48 if absf(ball_velocity.y) > 1 else 0.0
		var ground_velocity := Vector2(ball_velocity.x, ball_velocity.z).move_toward(Vector2.ZERO, dt * 3.6)
		ball_velocity.x = ground_velocity.x
		ball_velocity.z = ground_velocity.y
	if absf(ball.z) > HALF_Z - .43:
		ball.z = signf(ball.z) * (HALF_Z - .43)
		ball_velocity.z *= -.82
		events.append({"type": "bounce", "pos": ball})
	if absf(ball.x) > HALF_X:
		# Interpolate the line crossing, so fast shots cannot skip the goal mouth.
		var crossing := before.lerp(ball, clampf((signf(ball.x) * HALF_X - before.x) / (ball.x - before.x) if absf(ball.x - before.x) > .001 else 1.0, 0, 1))
		if absf(crossing.z) < GOAL_Z - .3 and crossing.y < GOAL_HEIGHT - .25:
			goal_scored(0 if ball.x > 0 else 1)
			return
		ball.x = signf(ball.x) * HALF_X
		ball_velocity.x *= -.8
		events.append({"type": "bounce", "pos": ball})
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
			last_touch = i
			p.charge = 0.0
			events.append({"type": "receive", "pos": ball, "team": p.team})
			return

var events_team := 0
func goal_scored(team: int) -> void:
	score[team] += 1
	stats.goals += 1
	phase = "goal"
	phase_time = 2.5
	events_team = team
	owner = -1
	ball_velocity = Vector3.ZERO
	power[1 - team] = minf(100, power[1 - team] + 18)
	events.append({"type": "goal", "pos": ball, "team": team})

func finish() -> void:
	phase = "result"
	events.append({"type": "finish", "pos": ball, "team": 0 if score[0] > score[1] else 1})

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

func ai_input(i: int, dt: float) -> Dictionary:
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
			target = Vector2(HALF_X * direction, p.drift)
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
				target = Vector2(clampf(ball_pos.x + direction * 5.5, -17, 17), (-6 if p.role % 2 == 0 else 6) + p.drift * .5)
			else:
				target = Vector2(clampf(ball_pos.x - direction * (7 + p.role * 2), -18, 18), ball_pos.y * .4 + (p.role - 1) * 4)
		p.intent = target
	var move: Vector2 = (target - p.pos).limit_length()
	var shoot := false
	var do_pass := false
	if has_ball:
		var goal_distance: float = absf(direction * HALF_X - p.pos.x)
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

static func vec3(v: Vector2, height: float = 0) -> Vector3:
	return Vector3(v.x, height, v.y)
