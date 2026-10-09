extends SceneTree
## Chaos events: each one starts, interacts with play and ends; frequency is opt-out.
const Match = preload("res://src/match.gd")
var failures := 0

func check(condition: bool, label: String) -> void:
	if not condition:
		push_error("FAIL: " + label)
		failures += 1
	else: print("PASS: ", label)

func live(seed_value: int = 7, teams: int = 1) -> RefCounted:
	var s = Match.new()
	s.setup(0, false, seed_value, 900, true, teams)
	s.phase = "play"
	return s

func run_until_over(s, limit: float = 40.0) -> float:
	var t := 0.0
	while s.chaos.active() and t < limit:
		if s.phase == "play": t += 1.0 / 60
		s.step(1.0 / 60)
	return t

func _initialize() -> void:
	for teams in [1, 3]:
		for kind in Match.Chaos.KINDS:
			var s = live(11, teams)
			s.chaos.forced = kind
			s.step(1.0 / 60)
			check(s.chaos.kind == kind, "%s starts on demand (%dv%d)" % [kind, teams, teams])
			var t := run_until_over(s)
			check(not s.chaos.active() and t < 40, "%s ends by itself after %.1fs (%dv%d)" % [kind, t, teams, teams])
			for p in s.players:
				check(absf(p.pos.x) <= s.half_x and absf(p.pos.y) <= s.half_z, "%s keeps athletes on the pitch" % kind)
	# Occasional by default, frequent on Lots, never when Off.
	for level in 3:
		var s = live(5)
		s.chaos.level = level
		s.chaos.setup(5)
		var started := 0
		var played := 0.0
		while played < 120:
			if s.phase == "play": played += 1.0 / 60
			s.step(1.0 / 60)
			for e in s.events: if e.type == "chaos": started += 1
		print("CHAOS_EVENTS_LEVEL_%d %d" % [level, started])
		if level == 0: check(started == 0, "Off never starts chaos")
		elif level == 1: check(started >= 1 and started <= 2, "Some keeps chaos rare: one or two events per two minutes")
		else: check(started >= 4, "Lots gives frequent events")
	# Fireworks stun athletes inside the telegraphed radius.
	var s = live()
	s.chaos.start(s, "fireworks")
	var f: Dictionary = s.chaos.fireworks[0]
	s.players[0].pos = f.to + Vector2(1, 0)
	s.players[1].pos = f.to + Vector2(8, 0)
	f.state = "fizz"
	f.t = f.fuse
	s.chaos.step(s, 1.0 / 60)
	check(s.players[0].stun > 0 and s.players[1].stun == 0, "firework blast stuns only nearby athletes")
	# A protest banner is a wall for the ball.
	s = live()
	s.chaos.start(s, "protest")
	for a in s.chaos.actors: a.pos.y = 0.0
	var mid: float = s.chaos.actors[2].pos.x
	s.chaos.last_ball = Vector3(mid, .45, -1)
	s.ball = Vector3(mid, .45, .3)
	s.ball_velocity = Vector3(0, 0, 20)
	s.chaos.update_protest(s, 1.0 / 60)
	check(s.ball_velocity.z < 0 and s.ball.z < s.chaos.actors[0].pos.y, "protest banner bounces the ball back")
	# The bonus ball can score and is credited to the right team.
	s = live()
	s.chaos.start(s, "second_ball")
	s.chaos.extra.pos = Vector3(s.half_x - .2, .45, 0)
	s.chaos.extra.vel = Vector3(30, 0, 0)
	s.keepers[1].pos.y = 3.2
	s.chaos.step(s, 1.0 / 60)
	check(s.score[0] == 1 and s.phase == "goal", "second ball scores a real goal")
	s.step(3.0)
	s.step(1.0 / 60)
	check(not s.chaos.active(), "kickoff clears the bonus ball")
	# The dog steals the ball; a dash gets it back.
	s = live()
	s.chaos.start(s, "dog")
	var dog: Dictionary = s.chaos.actors[0]
	dog.pos = Vector2(0, 0)
	s.ball = Vector3(.3, .45, 0)
	s.chaos.update_dog(s, 1.0 / 60)
	check(s.chaos.dog_ball, "dog grabs a loose ball")
	s.players[0].pos = dog.pos + Vector2(-1, 0)
	s.players[0].dash = .2
	s.players[0].face = Vector2.RIGHT
	s.chaos.update_dog(s, 1.0 / 60)
	check(not s.chaos.dog_ball and dog.stun > 0, "a dash makes the dog drop the ball")
	# Sprinklers make the pitch slippery; wind moves a resting ball.
	s = live()
	s = live()
	s.chaos.start(s, "brawl")
	s.chaos.age = 4.0
	var scrum: Vector2 = s.chaos.extra.at
	s.owner = 0
	s.players[0].pos = scrum + Vector2(1.5, 0)
	s.players[1].pos = scrum + Vector2(9, 0)
	s.chaos.update_brawl(s, 1.0 / 60)
	check(s.players[0].stun > 0 and s.owner == -1 and s.players[1].stun == 0, "walking into the hooligan brawl knocks you down and loses the ball")
	s = live()
	s.chaos.start(s, "sprinklers")
	for i in 120: s.chaos.step(s, 1.0 / 60)
	check(s.chaos.grip < .5 and s.chaos.slide < .5, "sprinklers reduce grip and ball friction")
	s = live()
	s.chaos.start(s, "wind")
	s.ball = Vector3(0, .43, 0)
	s.ball_velocity = Vector3.ZERO
	for i in 120: s.step(1.0 / 60, {0: {}, 1: {}, 2: {}, 3: {}})
	check(Vector2(s.ball.x, s.ball.z).length() > .5, "wind pushes a resting ball")
	# Same seed, same chaos.
	var a = live(99)
	var b = live(99)
	a.chaos.level = 2
	b.chaos.level = 2
	a.chaos.setup(99)
	b.chaos.setup(99)
	var log_a: Array = []
	var log_b: Array = []
	for i in 60 * 60:
		a.step(1.0 / 60)
		b.step(1.0 / 60)
		for e in a.events: if e.type == "chaos": log_a.append(e.kind)
		for e in b.events: if e.type == "chaos": log_b.append(e.kind)
	check(log_a == log_b and log_a.size() > 0, "chaos is deterministic per seed")
	# Full bot matches with frequent chaos still finish.
	for seed_value in [3, 21]:
		var m = Match.new()
		m.chaos.level = 2
		m.setup(0, false, seed_value, 60, true)
		var t := 0.0
		while m.phase != "result" and t < 300:
			m.step(1.0 / 60)
			t += 1.0 / 60
		check(m.phase == "result", "bot match with lots of chaos finishes (%s)" % [m.score])
	print("CHAOS_RESULT %d failures" % failures)
	quit(1 if failures else 0)
