extends SceneTree
const Match = preload("res://src/match.gd")
var failures := 0

func check(condition: bool, label: String) -> void:
	if not condition:
		push_error("FAIL: " + label)
		failures += 1
	else: print("PASS: ", label)

func _initialize() -> void:
	var s = Match.new()
	s.setup(4)
	check(s.players.size() == 6, "3v3 always has six athletes")
	check(s.players.filter(func(p): return p.human >= 0).size() == 4, "four humans plus two bots")
	s.setup(3, true)
	check(s.players.filter(func(p): return p.human >= 0 and p.team == 0).size() == 3, "three-player cooperative team")
	s.setup(1)
	s.phase = "play"
	s.owner = 0
	s.players[0].pos = Vector2.ZERO
	s.players[0].charge = 1.0
	s.power[0] = 100.0
	s.shoot_ball(0)
	check(s.ball_velocity.x > 50 and s.power[0] == 0, "charged super spends meter and accelerates ball")
	s.ball = Vector3(20.8, .5, 0)
	s.ball_velocity = Vector3(80, 0, 0)
	s.move_ball(1.0 / 120)
	check(s.score[0] == 1 and s.phase == "goal", "fast goal crossing scores exactly once")
	s.step(.1)
	check(s.score[0] == 1, "goal freeze prevents repeat scoring")
	s.setup(1)
	s.phase = "play"
	s.ball = Vector3(20.8, .5, 6)
	s.ball_velocity = Vector3(50, 0, 0)
	s.move_ball(.02)
	check(s.score[0] == 0 and s.ball_velocity.x < 0, "wall shot rebounds outside goal")
	s.owner = 1
	s.players[0].pos = Vector2(0, 0)
	s.players[0].face = Vector2.RIGHT
	s.players[1].pos = Vector2(1.3, 0)
	s.move_player(0, {"tackle": true}, .016)
	check(s.players[1].stun > 0 and s.owner == -1, "tackle dislodges possession and stuns opponent")
	s.setup(1)
	s.players[2].pos = Vector2.ZERO
	s.switch_player(0)
	check(s.players[0].human == -1 and s.players[2].human == 0, "switch transfers one controller to nearest teammate")
	s.setup(0)
	s.phase = "play"
	s.clock = .001
	s.step(.01)
	check(s.overtime and s.phase == "play", "tie enters golden goal")
	s.goal_scored(1)
	s.step(3)
	check(s.phase == "result" and s.score[1] == 1, "golden goal ends match")
	var total_goals := 0
	var totals := {"shots": 0, "passes": 0, "tackles": 0, "supers": 0}
	for seed_value in [725, 18, 80385, 1337, 40]:
		s.setup(0, false, seed_value, 120)
		for frame in 24000:
			s.step(1.0 / 120)
			if s.phase == "result": break
			if not s.ball.is_finite(): check(false, "finite ball"); break
		for key in totals: totals[key] += s.stats[key]
		total_goals += s.stats.goals
		check(s.stats.goals >= 2, "seed %d produces goals, not a possession stalemate (%s)" % [seed_value, str(s.score)])
		check(s.phase == "result", "seed %d finishes within 200 seconds" % seed_value)
	print("MATCH_TOTALS ", total_goals, " goals ", totals)
	check(totals.passes > 5 and totals.tackles > 10 and totals.shots > 20, "bots pass, tackle and shoot across matches")
	print("RESULT ", failures, " failures")
	quit(1 if failures > 0 else 0)
