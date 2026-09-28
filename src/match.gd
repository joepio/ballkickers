extends RefCounted
## Deterministic simulation, independent of rendering and physical devices.
const HALF_X = 21.0
const HALF_Z = 12.0
const GOAL_Z = 3.7
const GOAL_HEIGHT = 3.1
const RADIUS = 0.65
var team_size := 1
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

static func pitch_scale(teams: int) -> float:
	return sqrt(3.0) if teams >= 3 else 1.0

func setup(humans: int = 1, coop: bool = false, seed_value: int = 42, seconds: float = 120, dual: bool = false, controllers_per_team: int = 1) -> void:
	team_size = clampi(controllers_per_team, 1, 3)
	half_x = HALF_X * pitch_scale(team_size)
	half_z = HALF_Z * pitch_scale(team_size)
	rng.seed = seed_value
	dual_control = dual and team_size == 1
	arcade_control = dual or team_size > 1
	players.clear()
	keepers.clear()
	for team in 2:
		keepers.append({"team": team, "pos": Vector2(-(half_x - 1.6) if team == 0 else half_x - 1.6, 0),
			"vel": 0.0, "dive": 0.0, "dive_dir": 1.0, "recovery": 0.0, "reaction": 0.0, "hold": 0.0, "kick": 0.0, "push": 0.0})
	score = [0, 0]
	power = [20.0, 20.0]
	duration = seconds
	clock = seconds
	elapsed = 0.0
	overtime = false
	stats = {"shots": 0, "passes": 0, "tackles": 0, "goals": 0, "supers": 0}
	stats["saves"] = 0
	for i in (4 if team_size == 1 else team_size * 2):
		var team: int = i % 2
		var role: int = i / 2
		var human := -1
		if dual_control:
			var controller: int = (role / 2) * 2 + team
			if controller < humans: human = controller * 2 + role % 2
		elif coop:
			if team == 0 and role < mini(humans, 2): human = role
		else:
			if i < humans: human = i
		players.append({"team": team, "role": role, "human": human, "pos": Vector2.ZERO,
			"vel": Vector2.ZERO, "face": Vector2(1 if team == 0 else -1, 0), "stamina": 1.0,
			"charge": 0.0, "cooldown": 0.0, "stun": 0.0, "dash": 0.0, "kick": 0.0,
			"dash_shot": false,
			"think": rng.randf_range(0, 0.3), "intent": Vector2.ZERO, "shoot_at": rng.randf_range(.3, .9),
			"nerve": rng.randf_range(.7, 1.2), "drift": rng.randf_range(-2.5, 2.5), "held": false,
			"name": "P%d" % (human + 1) if human >= 0 else ["BOLT", "MISO", "ZIG", "POPPY", "BUBS", "NOVA"][i % 6]})
	kickoff(-1)
	events.clear()

func kickoff(team: int) -> void:
	keeper_owner = -1
	for k in keepers:
		k.pos = Vector2(-(half_x - 1.6) if k.team == 0 else half_x - 1.6, 0)
		for field in ["vel", "dive", "recovery", "reaction", "hold", "kick", "push"]: k[field] = 0.0
	for i in players.size():
		var p: Dictionary = players[i]
		var direction: float = 1 if p.team == 0 else -1
		# Screen X increases to the right for both teams. Mirror the formation,
		# not the controller halves: L starts left and R starts right each kickoff.
		var spawn_role: int = 1 - (p.role % 2) if dual_control and p.team == 0 else p.role % 2
		p.pos = Vector2(-direction * (5.5 if spawn_role == 0 else 12.0), 0 if spawn_role == 0 else 4.5)
		p.pos.x *= pitch_scale(team_size)
		if team_size > 1: p.pos.y = (float(p.role) - (team_size - 1) * .5) * (half_z * 1.35 / team_size)
		p.vel = Vector2.ZERO
		p.face = Vector2(direction, 0)
		p.stun = 0.0
		p.charge = 0.0
		p.held = false
		p.cooldown = 0.0
		p.dash = 0.0
		p.dash_shot = false
	ball = Vector3(0, .45, 0)
	ball_velocity = Vector3.ZERO
	owner = -1
	last_touch = -1
	ball_controller = -1
	ball_controller_team = -1
	pickup_lock = 0.0
	if team >= 0:
		var taker: int = 2 if dual_control and team == 0 else team
		players[taker].pos = Vector2(-1.0 if team == 0 else 1.0, 0)
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
		if arcade_control:
			control = control.duplicate()
			control["pass"] = false
			control["sprint"] = false
		move_player(i, control, dt)
	resolve_bodies()
	update_keepers(dt)
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
		var speed := 12.8 if sprint else 9.0
		if owner == i: speed *= .91
		if p.charge > 0: speed *= .66
		if p.dash > 0:
			p.vel = p.face * 22.0
		else: p.vel = p.vel.move_toward(move * speed, dt * (64.0 if move.length() > .1 else 48.0))
		if input.get("tackle", false) and owner != i and p.cooldown <= 0 and p.stamina > .2:
			p.dash = .21
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
	p.pos.x = clampf(p.pos.x, -half_x + RADIUS, half_x - RADIUS)
	p.pos.y = clampf(p.pos.y, -half_z + RADIUS, half_z - RADIUS)
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
	if keeper_owner >= 0:
		var k: Dictionary = keepers[keeper_owner]
		ball = vec3(k.pos + Vector2(1 if k.team == 0 else -1, 0) * .65, 1.15)
		ball_velocity = Vector3.ZERO
		return
	if owner >= 0:
		var p: Dictionary = players[owner]
		ball = vec3(p.pos + p.face * 1.0, .45 + absf(sin(elapsed * 16)) * minf(.15, p.vel.length() * .01))
		ball_velocity = vec3(p.vel)
		keeper_save(ball, ball)
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
			auto_control_receiver(i)
			if p.dash > 0 and p.dash_shot:
				p.charge = .35
				p.dash = 0.0
				p.dash_shot = false
				shoot_ball(i)
				return
			events.append({"type": "receive", "pos": ball, "team": p.team})
			return

var events_team := 0
func goal_scored(team: int) -> void:
	keeper_owner = -1
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

static func vec3(v: Vector2, height: float = 0) -> Vector3:
	return Vector3(v.x, height, v.y)

func update_keepers(dt: float) -> void:
	for k in keepers:
		k.recovery = maxf(0, k.recovery - dt)
		k.kick = maxf(0, k.kick - dt)
		k.pos.x += k.push * dt
		k.push = move_toward(k.push, 0.0, dt * 22)
		if absf(k.push) < .1:
			k.pos.x = move_toward(k.pos.x, -(half_x - 1.6) if k.team == 0 else half_x - 1.6, dt * 3)
		k.pos.x = clampf(k.pos.x, -half_x - 1.7, half_x + 1.7)
		if keeper_owner == k.team:
			k.hold -= dt
			if k.hold <= 0: distribute(k)
			continue
		var inward := 1.0 if k.team == 0 else -1.0
		var target := clampf(ball.z * .55, -2.65, 2.65)
		var approaching: bool = owner < 0 and keeper_owner < 0 and ball_velocity.x * inward < -8
		var eta: float = (k.pos.x - ball.x) / ball_velocity.x if approaching else 10.0
		var threat: bool = approaching and eta > 0 and eta < .65
		if threat:
			k.reaction += dt
			target = clampf(ball.z + ball_velocity.z * eta, -3.25, 3.25)
		else: k.reaction = 0.0
		if k.dive > 0:
			k.dive = maxf(0, k.dive - dt)
			k.pos.y += k.vel * dt
		elif k.recovery <= 0:
			if threat and k.reaction > .14 and eta < .36 and absf(target - k.pos.y) > .65:
				k.dive = .28
				k.recovery = .85
				k.dive_dir = signf(target - k.pos.y)
				k.vel = k.dive_dir * 12.0
				events.append({"type": "keeper_dive", "pos": vec3(k.pos, .7), "team": k.team})
			else:
				k.vel = clampf((target - k.pos.y) * 6, -4.5, 4.5)
				k.pos.y += k.vel * dt
		else: k.vel = 0.0
		k.pos.y = clampf(k.pos.y, -3.25, 3.25)

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
		var inward := 1.0 if k.team == 0 else -1.0
		if owner < 0 and ball_velocity.x * inward > 2: continue
		var speed := ball_velocity.length()
		var difficulty := clampf((speed - 18.0) / 42.0, 0.0, 1.0)
		var edge := clampf(Vector2(contact.x - center.x, contact.z - center.z).length() / reach, 0, 1)
		var save_chance := clampf(.98 - difficulty * .64 - edge * .10, .22, .98)
		# One seeded roll per contact, with recovery preventing repeated rerolls.
		if rng.randf() > save_chance:
			k.recovery = .8
			k.dive = 0.0
			k.push = -inward * lerpf(1.0, 12.0, difficulty)
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
		k.push = -inward * maxf(0, speed - 25) * .18
		if speed < 29 and k.dive <= 0:
			keeper_owner = k.team
			k.hold = .5
			ball_velocity = Vector3.ZERO
		else:
			# Successful powerful saves still spill dangerous rebounds and push the keeper back.
			var side := signf(contact.z - k.pos.y)
			if side == 0: side = k.dive_dir
			ball_velocity = Vector3(inward * maxf(9, speed * .42), 4.5, side * 10)
			ball.x = k.pos.x + inward * 1.5
			k.recovery = .9 if speed > 44 else .65
			k.dive = minf(k.dive, .12)
		pickup_lock = .16
		events.append({"type": "save", "pos": ball, "team": k.team})
		return true
	return false

func distribute(k: Dictionary) -> void:
	var inward := 1.0 if k.team == 0 else -1.0
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
	if direction.x * inward < .2: direction = Vector2(inward, direction.y).normalized()
	keeper_owner = -1
	last_touch = target
	ball = vec3(k.pos + direction * 1.6, .6)
	ball_velocity = vec3(direction * 25, 1.6)
	pickup_lock = .18
	k.recovery = .35
	k.kick = .3
	events.append({"type": "pass", "pos": ball, "team": k.team})
