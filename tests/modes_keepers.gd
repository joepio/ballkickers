extends SceneTree
const Match = preload("res://src/match.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok: failures += 1

func _initialize() -> void:
	var s = Match.new()
	for teams in [1, 2, 3]:
		s.setup(teams * 2, false, 42, 120, true, teams)
		var count: int = 4 if teams == 1 else teams * 2
		check(s.players.size() == count, "%dv%d roster" % [teams, teams])
		check(is_equal_approx(s.half_x * s.half_z / (21 * 12), 3.0 if teams == 3 else 1.0), "1v1 and 2v2 share the original pitch; 3v3 retains its larger pitch")
		for kickoff_team in [-1, 0, 1]:
			s.kickoff(kickoff_team)
			for controller in teams * 2:
				var pair := []
				for p in s.players:
					if (p.human / 2 if teams == 1 else p.human) == controller: pair.append(p)
				if teams == 1:
					check(pair.size() == 2 and pair[0].team == controller % 2 and pair[0].pos.x < pair[1].pos.x, "seat %d keeps its team and L/R order at kickoff %d" % [controller, kickoff_team])
				else:
					check(pair.size() == 1 and pair[0].team == controller % 2, "seat %d owns exactly one unit on its team" % controller)
		var controls := {}
		for slot in count: controls[slot] = {"move": Vector2.RIGHT if slot % 2 == 0 else Vector2.LEFT}
		s.phase = "play"
		s.step(.016, controls)
		for p in s.players:
			check(p.vel.x > 0 if p.human % 2 == 0 else p.vel.x < 0, "unit %d responds independently" % p.human)
		var human_count: int = 2 if teams == 1 else teams * 2 - 1
		s.setup(human_count, false, 42, 120, true, teams)
		var human_units := 0
		for p in s.players:
			if p.human >= 0: human_units += 1
		check(human_units == (4 if teams == 1 else human_count), "odd-sized party fills only the missing place with a bot")
		if teams > 1:
			check(s.players[-1].human == -1 and not s.dual_control, "3/5 humans leave a single bot with single-unit controls")
		s.setup(0, false, 42, 120, true, teams)
		s.keepers[1].recovery = 1.0
		s.ball = Vector3(s.half_x - .5, .5, 0)
		s.ball_velocity = Vector3(50, 0, 0)
		s.move_ball(.02)
		check(s.score[0] == 1, "goal line follows enlarged pitch")
	var saves := []
	for speed in [20.0, 38.0, 55.0]:
		var saved := 0
		var pushed := 0
		for seed_value in 300:
			s.setup(0, false, seed_value)
			s.ball_velocity = Vector3(speed, 0, 0)
			if s.keeper_save(Vector3(18, .8, 0), Vector3(20, .8, 0)): saved += 1
			s.update_keepers(.1)
			if s.keepers[1].pos.x > 19.5: pushed += 1
		check(saved > 0 and saved < 300, "speed %d can be saved or missed" % speed)
		if speed == 55: check(pushed > 250, "hard shots visibly knock keepers toward their goal")
		saves.append(saved)
	print("SAVES_PER_300 ", saves)
	check(saves[0] > saves[1] + 40 and saves[1] > saves[2] + 40, "charged shots are substantially harder to keep")
	s.setup(0, false, 12, 120, true)
	s.phase = "play"
	var attacker: int = s.players.find(s.players.filter(func(p): return p.team == 0)[0])
	s.owner = attacker
	s.players[attacker].pos = s.keepers[1].pos + Vector2(-1.2, .3)
	s.update_keepers(1.0 / 60)
	check(s.players[attacker].stun > 0 and s.owner == -1 and s.players[attacker].vel.x < 0, "walking into the keeper gets you knocked down and loses the ball")
	s.players[attacker].stun = 0.0
	s.players[attacker].pos = s.keepers[1].pos + Vector2(-1.0, 0)
	s.update_keepers(1.0 / 60)
	check(s.players[attacker].stun == 0, "the keeper needs a moment before the next slap")
	s.players[attacker].pos = s.keepers[1].pos + Vector2(-4, 0)
	s.update_keepers(1.0)
	check(s.players[attacker].stun == 0, "players at a distance are left alone")
	three_way_checks()
	print("MODES_KEEPERS_RESULT ", failures, " failures")
	quit(1 if failures else 0)


func inside(s, at: Vector2) -> bool:
	return s.confine(at, 0.0).distance_to(at) < .01

func three_way_checks() -> void:
	var s = Match.new()
	s.setup(3, false, 21, 120, true, 1, true)
	s.chaos.level = 0
	check(s.teams == 3 and s.players.size() == 3 and s.keepers.size() == 3 and s.score.size() == 3, "three-way has three teams of one, three keepers and three scores")
	check(s.players.all(func(p): return p.human == p.team), "each of three people gets their own team")
	var placed := true
	for i in 3:
		var p: Dictionary = s.players[i]
		var g: Dictionary = s.goals[p.team]
		placed = placed and inside(s, p.pos) and inside(s, s.keepers[i].pos) and p.face.dot(g.n) > .99
	check(placed, "kickoff places everyone inside the arena, facing out of their own goal")
	# A shot into blue's goal, last touched by orange, is orange's goal.
	s.phase = "play"
	var g: Dictionary = s.goals[1]
	s.last_touch = 0
	s.keepers[1].pos = g.c + g.n * 1.6 + g.t * 3.2
	s.keepers[1].recovery = 3.0
	s.ball = Vector3(g.c.x + g.n.x * 2, .5, g.c.y + g.n.y * 2)
	s.ball_velocity = Vector3(-g.n.x * 30, 0, -g.n.y * 30)
	for frame in 20: s.move_ball(1.0 / 60)
	check(s.phase == "goal" and s.score == [1, 0, 0] and s.conceded_team == 1, "orange scores in blue's goal (%s)" % [s.score])
	for frame in 200: s.step(1.0 / 60)
	check(s.phase == "kickoff" and s.players[1].pos.distance_to(s.arena_center) < 1.5, "the team that conceded kicks off")
	# An own goal goes to the last other team on the ball.
	s.phase = "play"
	g = s.goals[2]
	s.last_touch = 1
	s.touch(2)
	s.keepers[2].pos = g.c + g.n * 1.6 + g.t * 3.2
	s.keepers[2].recovery = 3.0
	s.ball = Vector3(g.c.x + g.n.x * 2, .5, g.c.y + g.n.y * 2)
	s.ball_velocity = Vector3(-g.n.x * 30, 0, -g.n.y * 30)
	for frame in 20: s.move_ball(1.0 / 60)
	check(s.phase == "goal" and s.score == [1, 1, 0], "a lime own goal counts for blue, who touched it before (%s)" % [s.score])
	# Corner walls send the ball back in.
	s.setup(0, false, 22, 120, true, 1, true)
	s.phase = "play"
	var corner: Vector2 = s.walls[3].p
	s.ball = Vector3(s.arena_center.x, .5, s.arena_center.y)
	var toward: Vector2 = (corner - s.arena_center).normalized() * 40
	s.ball_velocity = Vector3(toward.x, 0, toward.y)
	for frame in 60: s.move_ball(1.0 / 60)
	check(inside(s, Vector2(s.ball.x, s.ball.z)) and s.phase == "play", "the cut-off corners bounce the ball back into play")
	# A full bot match stays inside the arena and every team can score.
	s.setup(0, false, 23, 240, true, 1, true)
	var escaped := 0
	for frame in 60 * 900:
		if s.phase == "result": break
		s.step(1.0 / 60)
		if s.phase == "play" and not inside(s, Vector2(s.ball.x, s.ball.z)) and s.keeper_owner < 0: escaped += 1
		for p in s.players: if not inside(s, p.pos): escaped += 1
	print("THREE_WAY_SCORE ", s.score)
	check(escaped == 0, "players and ball stay inside the arena for a whole match (%d escapes)" % escaped)
	check(s.score.filter(func(n): return n > 0).size() >= 2, "goals are spread over the teams in a bot match (%s)" % [s.score])
	check(s.phase == "result" and s.events.size() >= 0, "a three-way match ends")
