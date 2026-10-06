extends RefCounted
## Occasional football chaos: pitch invaders, fireworks, protests and an extra ball.
## Deterministic like the match: its own seeded RNG, stepped only during live play,
## so the match RNG stream (AI, keeper rolls) is unchanged by these events.
const KINDS := ["streaker", "fireworks", "protest", "second_ball", "dog", "sprinklers", "wind"]
const TITLES := {
	"streaker": "STREAKER ON THE PITCH!",
	"fireworks": "FIREWORKS FROM THE STANDS!",
	"protest": "PITCH PROTEST!",
	"second_ball": "A SECOND BALL!",
	"dog": "DOG ON THE PITCH!",
	"sprinklers": "SPRINKLERS ON!",
	"wind": "GALE FORCE WIND!",
}
const SLOGANS := ["MORE GOALS!", "BAN OFFSIDE", "FREE THE KEEPERS", "BALLS FOR ALL", "KEEP FOOTBALL WEIRD",
	"JUSTICE FOR BUBS", "NO FOULS NO PEACE", "LONGER HALF TIME", "ROUND IS GOOD"]
const BODY = 0.65
const GOAL_Z = 3.7
const GOAL_HEIGHT = 3.1
var rng := RandomNumberGenerator.new()
## 0 = off, 1 = occasional, 2 = frequent.
var level := 1
var forced := ""
var kind := ""
var serial := 0
var age := 0.0
var cooldown := 12.0
var recent: Array = []
var actors: Array = []
var fireworks: Array = []
var extra: Dictionary = {}
var wind := Vector2.ZERO
var grip := 1.0
var slide := 1.0
var slogan := ""
var dog_ball := false
var last_ball := Vector3.ZERO

func setup(seed_value: int) -> void:
	rng.seed = seed_value * 7919 + 13
	recent.clear()
	clear()
	cooldown = rng.randf_range(10, 18) if level < 2 else rng.randf_range(3, 6)

func clear() -> void:
	kind = ""
	age = 0.0
	actors.clear()
	fireworks.clear()
	extra = {}
	wind = Vector2.ZERO
	grip = 1.0
	slide = 1.0
	dog_ball = false
	cooldown = maxf(cooldown, 4.0)

func active() -> bool:
	return kind != ""

func title() -> String:
	return TITLES.get(kind, "")

func step(m, dt: float) -> void:
	if kind == "":
		if forced != "":
			start(m, forced)
			forced = ""
		elif level > 0:
			cooldown -= dt
			if cooldown <= 0: start(m, pick())
		last_ball = m.ball
		return
	age += dt
	var done := false
	match kind:
		"streaker": done = update_streaker(m, dt)
		"fireworks": done = update_fireworks(m, dt)
		"protest": done = update_protest(m, dt)
		"second_ball": done = update_second_ball(m, dt)
		"dog": done = update_dog(m, dt)
		"sprinklers": done = update_sprinklers(m, dt)
		"wind": done = update_wind(m, dt)
	if m.phase != "play": return
	if level <= 0 and kind != "fireworks": done = true
	last_ball = m.ball
	if done:
		if dog_ball: drop_dog_ball(m, Vector2.ZERO)
		m.events.append({"type": "chaos_end", "kind": kind, "pos": m.ball})
		clear()

func pick() -> String:
	var options: Array = []
	for k in KINDS:
		if k not in recent: options.append(k)
	return options[rng.randi_range(0, options.size() - 1)]

func start(m, which: String) -> void:
	clear()
	kind = which
	serial += 1
	# The quiet gap counts only while no event runs, so goals cannot shorten it.
	cooldown = rng.randf_range(20, 34) if level < 2 else rng.randf_range(3, 7)
	recent.append(which)
	if recent.size() > 3: recent.pop_front()
	var hx: float = m.half_x
	var hz: float = m.half_z
	match which:
		"streaker":
			var x0 := rng.randf_range(-hx * .55, hx * .55)
			var x1 := rng.randf_range(-hx * .55, hx * .55)
			actors.append(actor("streaker", Vector2(x0, -hz - 1.5), .55))
			actors[0]["goal"] = Vector2(x1, hz + 2.0)
			var steward := actor("steward", Vector2(x0 + rng.randf_range(-2, 2), -hz - 1.5), .6)
			steward["delay"] = 1.6
			actors.append(steward)
		"fireworks":
			var count := 3 if level < 2 else 5
			for i in count:
				var target := Vector2(m.ball.x, m.ball.z) + Vector2(rng.randf_range(-7, 7), rng.randf_range(-5, 5))
				target.x = clampf(target.x, -hx + 4, hx - 4)
				target.y = clampf(target.y, -hz + 1.5, hz - 1.5)
				var from := Vector3(clampf(target.x + rng.randf_range(-6, 6), -hx, hx), 3.0, -hz - 3.5)
				fireworks.append({"from": from, "to": target, "t": -i * .55, "flight": .95, "fuse": 1.7, "state": "wait"})
		"protest":
			slogan = SLOGANS[rng.randi_range(0, SLOGANS.size() - 1)]
			var count := 5 if level < 2 else 7
			var cx := rng.randf_range(-hx * .35, hx * .35)
			for i in count:
				var a := actor("protester", Vector2(cx + (i - (count - 1) * .5) * 1.3, -hz - 1.4), .55)
				a["shirt"] = rng.randi_range(0, 4)
				actors.append(a)
		"second_ball":
			var from := Vector3(rng.randf_range(-hx * .5, hx * .5), 3.2, -hz - 2.5)
			var target := Vector3(rng.randf_range(-6, 6), .45, rng.randf_range(-4, 4))
			var flight := 1.1
			var vel := (target - from) / flight
			vel.y = (target.y - from.y) / flight + .5 * 20 * flight
			extra = {"pos": from, "vel": vel, "lock": 0.0, "life": 16.0 if level < 2 else 22.0}
		"dog":
			var side := -1.0 if rng.randf() < .5 else 1.0
			var dog := actor("dog", Vector2(side * (hx + 1), hz - 1), .5)
			dog["state"] = "chase"
			actors.append(dog)
		"sprinklers": pass
		"wind":
			var angle := rng.randf_range(0, TAU)
			wind = Vector2(cos(angle), sin(angle)) * 7.5
	m.events.append({"type": "chaos", "kind": which, "text": title(), "pos": m.ball})

func actor(type: String, pos: Vector2, radius: float) -> Dictionary:
	return {"kind": type, "pos": pos, "vel": Vector2.ZERO, "face": Vector2(0, 1), "radius": radius,
		"stun": 0.0, "gone": false, "delay": 0.0}

func move_actor(a: Dictionary, target: Vector2, speed: float, dt: float, accel: float = 30.0) -> void:
	var offset: Vector2 = target - a.pos
	var desired: Vector2 = offset.normalized() * speed if offset.length() > .05 else Vector2.ZERO
	a.vel = a.vel.move_toward(desired, dt * accel)
	a.pos += a.vel * dt
	if a.vel.length() > .3: a.face = a.vel.normalized()

func shove_players(m, a: Dictionary, strength: float = 1.0) -> void:
	for p in m.players:
		var offset: Vector2 = p.pos - a.pos
		var reach: float = a.radius + BODY
		if offset.length() < reach:
			var normal := offset.normalized() if offset.length() > .001 else Vector2.RIGHT
			p.pos += normal * (reach - offset.length()) * strength

func ball_loose(m) -> bool:
	return m.owner < 0 and m.keeper_owner < 0 and m.ball.y < 1.4

func touch_ball(m, a: Dictionary, power: float) -> bool:
	if not ball_loose(m) or m.pickup_lock > 0: return false
	var offset: Vector2 = Vector2(m.ball.x, m.ball.z) - a.pos
	if offset.length() > a.radius + .55: return false
	var dir: Vector2 = offset.normalized() if offset.length() > .01 else a.face
	m.ball_velocity = Vector3(dir.x * power, 3.0, dir.y * power)
	m.last_touch = -1
	m.pickup_lock = .12
	m.events.append({"type": "chaos_kick", "pos": m.ball})
	return true

func inside(m, pos: Vector2, margin: float = 0.0) -> bool:
	return absf(pos.x) < m.half_x + margin and absf(pos.y) < m.half_z + margin

func update_streaker(m, dt: float) -> bool:
	var streaker: Dictionary = actors[0]
	var steward: Dictionary = actors[1]
	if not streaker.gone:
		# Weave across the pitch, front to back, dodging the steward.
		var goal: Vector2 = streaker.goal
		var target := Vector2(goal.x + sin(age * 2.3) * 7.0, goal.y)
		move_actor(streaker, target, 8.4, dt, 40)
		shove_players(m, streaker)
		touch_ball(m, streaker, 15.0)
		if streaker.pos.y > m.half_z + 1.8: streaker.gone = true
	steward.delay = maxf(0, steward.delay - dt)
	if steward.delay <= 0 and not steward.gone:
		var chase: Vector2 = streaker.pos if not streaker.gone else Vector2(steward.pos.x, m.half_z + 3)
		move_actor(steward, chase, 8.0, dt)
		shove_players(m, steward)
		touch_ball(m, steward, 10.0)
		if steward.pos.y > m.half_z + 2.5: steward.gone = true
	return (streaker.gone and steward.gone) or age > 16

func update_fireworks(m, dt: float) -> bool:
	var pending := false
	for f in fireworks:
		f.t += dt
		match f.state:
			"wait":
				if f.t >= 0: f.state = "air"
			"air":
				if f.t >= f.flight:
					f.state = "fizz"
					f.t = 0.0
					m.events.append({"type": "chaos_land", "pos": Vector3(f.to.x, .3, f.to.y)})
			"fizz":
				if f.t >= f.fuse:
					f.state = "done"
					explode(m, f.to)
		if f.state != "done": pending = true
	return not pending

func firework_position(f: Dictionary) -> Vector3:
	if f.state == "wait": return f.from
	if f.state != "air": return Vector3(f.to.x, .25, f.to.y)
	var t := clampf(f.t / f.flight, 0, 1)
	var flat: Vector3 = f.from.lerp(Vector3(f.to.x, .25, f.to.y), t)
	flat.y += 7.0 * 4.0 * t * (1.0 - t)
	return flat

func explode(m, at: Vector2) -> void:
	m.events.append({"type": "chaos_boom", "pos": Vector3(at.x, .6, at.y)})
	for i in m.players.size():
		var p: Dictionary = m.players[i]
		var offset: Vector2 = p.pos - at
		if offset.length() < 2.8:
			p.stun = .8
			p.vel = (offset.normalized() if offset.length() > .01 else Vector2.RIGHT) * 15
			p.charge = 0.0
			if m.owner == i: m.owner = -1
	var ball_offset := Vector2(m.ball.x, m.ball.z) - at
	if m.keeper_owner < 0 and m.owner < 0 and ball_offset.length() < 3.2 and m.ball.y < 2:
		var dir := ball_offset.normalized() if ball_offset.length() > .05 else Vector2.UP
		m.ball_velocity = Vector3(dir.x * 22, 9, dir.y * 22)
		m.last_touch = -1
		m.pickup_lock = .2

func update_protest(m, dt: float) -> bool:
	var speed: float = 2.7 * m.half_z / 12.0
	var z: float = actors[0].pos.y + speed * dt
	var left: float = actors[0].pos.x - .7
	var right: float = actors[-1].pos.x + .7
	for a in actors:
		a.vel = Vector2(0, speed)
		a.pos.y = z
		shove_players(m, a)
	# The banner between the outer protesters is a moving wall for players and the ball.
	if absf(z) < m.half_z + .5:
		for p in m.players:
			if p.pos.x > left and p.pos.x < right and absf(p.pos.y - z) < BODY + .15:
				p.pos.y = z + signf(p.pos.y - z + .001) * (BODY + .15)
		if m.ball.x > left and m.ball.x < right and m.ball.y < 2.4 and m.keeper_owner < 0:
			var before := signf(last_ball.z - z)
			var after := signf(m.ball.z - z)
			if absf(m.ball.z - z) < .45 or (before != after and before != 0):
				var side := before if before != 0 else -1.0
				if m.owner >= 0:
					m.players[m.owner].pos.y = z + side * (BODY + .2)
				else:
					m.ball.z = z + side * .5
					m.ball_velocity.z = side * maxf(absf(m.ball_velocity.z) * .7, speed + 3)
					m.events.append({"type": "chaos_kick", "pos": m.ball})
	return z > m.half_z + 1.6 or age > 30

func update_second_ball(m, dt: float) -> bool:
	var b: Dictionary = extra
	b.life -= dt
	b.lock = maxf(0, b.lock - dt)
	var before: Vector3 = b.pos
	b.vel.y -= 20 * dt
	b.pos += b.vel * dt
	if b.pos.y < .43:
		b.pos.y = .43
		b.vel.y = absf(b.vel.y) * .5 if absf(b.vel.y) > 1 else 0.0
		var ground := Vector2(b.vel.x, b.vel.z).move_toward(Vector2.ZERO, dt * 3.0 * m.ball_friction * slide)
		b.vel.x = ground.x
		b.vel.z = ground.y
	if b.pos.z > m.half_z - .43 or (b.pos.z < -m.half_z + .43 and b.vel.z < 0):
		b.pos.z = clampf(b.pos.z, -m.half_z + .43, m.half_z - .43)
		b.vel.z *= -.8
	if absf(b.pos.x) > m.half_x:
		var t := clampf((signf(b.pos.x) * m.half_x - before.x) / (b.pos.x - before.x), 0, 1) if absf(b.pos.x - before.x) > .001 else 1.0
		var crossing := before.lerp(b.pos, t)
		if absf(crossing.z) < GOAL_Z - .3 and crossing.y < GOAL_HEIGHT - .25:
			m.events.append({"type": "chaos_text", "text": "BONUS BALL GOAL!", "pos": crossing})
			m.goal_scored(0 if b.pos.x > 0 else 1, crossing)
			return false
		b.pos.x = signf(b.pos.x) * m.half_x
		b.vel.x *= -.8
	for k in m.keepers:
		var inward := 1.0 if k.team == 0 else -1.0
		if Vector2(b.pos.x - k.pos.x, b.pos.z - k.pos.y).length() < 1.25 and b.pos.y < 2.2 and b.vel.x * inward < 0:
			b.vel.x = inward * maxf(8, absf(b.vel.x) * .55)
			b.vel.y = 4.0
			m.events.append({"type": "chaos_kick", "pos": b.pos})
	if b.lock <= 0 and b.pos.y < 1.5:
		for p in m.players:
			if p.stun > 0: continue
			var offset: Vector2 = Vector2(b.pos.x, b.pos.z) - p.pos
			if offset.length() > 1.25: continue
			var dir: Vector2 = offset.normalized() if offset.length() > .05 else p.face
			var power: float = maxf(p.vel.length() * 1.6, 9.0)
			if p.dash > 0:
				dir = p.face
				power = 30.0
				p.dash = 0.0
			b.vel = Vector3(dir.x * power, 2.5, dir.y * power)
			b.lock = .15
			m.events.append({"type": "chaos_kick", "pos": b.pos})
			break
	if b.life <= 0:
		m.events.append({"type": "chaos_pop", "pos": b.pos})
		return true
	return false

func update_dog(m, dt: float) -> bool:
	var dog: Dictionary = actors[0]
	dog.stun = maxf(0, dog.stun - dt)
	var hx: float = m.half_x
	var hz: float = m.half_z
	if age > 10 and dog.state != "leave":
		dog.state = "leave"
		if dog_ball: drop_dog_ball(m, dog.face * 6)
	if dog.stun > 0:
		dog.vel = dog.vel.move_toward(Vector2.ZERO, dt * 20)
		dog.pos += dog.vel * dt
	elif dog.state == "leave":
		move_actor(dog, Vector2(dog.pos.x, hz + 3), 11.0, dt)
		if dog.pos.y > hz + 2.5: dog.gone = true
	elif dog_ball and m.keeper_owner >= 0:
		dog_ball = false
	elif dog_ball:
		# Run away from the nearest chaser, zigzagging, away from the goal mouths.
		var threat := Vector2.ZERO
		var nearest := INF
		for p in m.players:
			var d: float = p.pos.distance_to(dog.pos)
			if d < nearest: nearest = d; threat = p.pos
		var away: Vector2 = (dog.pos - threat).normalized() if nearest < INF else dog.face
		away = away.rotated(sin(age * 5.0) * .7)
		var target: Vector2 = dog.pos + away * 4
		target.x = clampf(target.x, -hx + 5, hx - 5)
		target.y = clampf(target.y, -hz + 1.5, hz - 1.5)
		move_actor(dog, target, 9.6, dt, 45)
		dog.pos.x = clampf(dog.pos.x, -hx + 5, hx - 5)
		dog.pos.y = clampf(dog.pos.y, -hz + 1, hz - 1)
		m.ball = Vector3(dog.pos.x + dog.face.x * .75, .5, dog.pos.y + dog.face.y * .75)
		m.ball_velocity = Vector3.ZERO
		m.pickup_lock = .1
		for p in m.players:
			if p.dash > 0 and p.pos.distance_to(dog.pos) < 1.5:
				p.dash = 0.0
				dog.stun = 1.1
				dog.vel = p.face * 9
				drop_dog_ball(m, p.face * 7)
				m.events.append({"type": "chaos_text", "text": "GOOD BOY. DROP IT!", "pos": m.ball})
				break
	else:
		var ball2 := Vector2(m.ball.x, m.ball.z)
		move_actor(dog, ball2, 10.5, dt, 45)
		if m.keeper_owner < 0 and m.ball.y < 1.0 and dog.pos.distance_to(ball2) < .95 and absf(dog.pos.x) < hx - 5:
			if m.owner >= 0:
				m.players[m.owner].charge = 0.0
				m.players[m.owner].held = false
			m.owner = -1
			dog_ball = true
			m.events.append({"type": "chaos_text", "text": "THE DOG HAS IT!", "pos": m.ball})
	return dog.gone or age > 18

func drop_dog_ball(m, push: Vector2) -> void:
	dog_ball = false
	m.ball_velocity = Vector3(push.x, 3.0, push.y)
	m.last_touch = -1
	m.pickup_lock = .25

func update_sprinklers(m, dt: float) -> bool:
	var length := 10.0
	var ramp := clampf(minf(age, length - age) / 1.2, 0, 1)
	grip = lerpf(1.0, .22, ramp)
	slide = lerpf(1.0, .25, ramp)
	return age >= length

func update_wind(m, dt: float) -> bool:
	var length := 9.0
	var gust := clampf(minf(age, length - age) / 1.0, 0, 1) * (.75 + .25 * sin(age * 3.1))
	var force := wind * gust
	if m.owner < 0 and m.keeper_owner < 0 and m.phase == "play":
		var lift := 1.7 if m.ball.y > .6 else 1.0
		m.ball_velocity.x += force.x * lift * dt
		m.ball_velocity.z += force.y * lift * dt
	for p in m.players:
		p.pos += force * .14 * dt
		p.pos.x = clampf(p.pos.x, -m.half_x + BODY, m.half_x - BODY)
		p.pos.y = clampf(p.pos.y, -m.half_z + BODY, m.half_z - BODY)
	return age >= length
