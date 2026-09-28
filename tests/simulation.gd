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
	check(s.players.size() == 4, "2v2 has four outfield athletes")
	check(s.keepers.size() == 2, "each team gets a dedicated keeper in addition to two outfield players")
	check(s.players.filter(func(p): return p.human >= 0).size() == 4, "four humans can control all outfield athletes")
	s.setup(3, true)
	check(s.players.filter(func(p): return p.human >= 0 and p.team == 0).size() == 2, "cooperative team caps at two humans")
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
	s.setup(1)
	s.owner = 0
	s.players[0].pos = Vector2.ZERO
	s.players[2].pos = Vector2(4, 0)
	s.pass_ball(0, Vector2.RIGHT)
	s.auto_control_receiver(2)
	check(s.players[2].human == 0 and s.players[0].human == -1, "passing human automatically follows the ball to AI teammate")
	s.setup(1)
	s.ball = Match.vec3(s.players[2].pos, .45)
	s.move_ball(1.0 / 120)
	check(s.owner == 2 and s.players[2].human == 0, "actual loose-ball reception automatically transfers control")
	s.setup(2)
	s.auto_control_receiver(3)
	check(s.players[3].human == 1 and s.players[1].human == -1 and s.players[0].human == 0, "opponent possession only switches the opponent's controller")
	s.setup(4)
	s.ball_controller = 0
	s.ball_controller_team = 0
	s.auto_control_receiver(2)
	check(s.players[2].human == 2 and s.players[0].human == 0, "auto-switch never steals another human's athlete")
	s.setup(1)
	s.owner = 0
	s.move_player(0, {"shoot": true, "tackle": true}, .05)
	check(s.players[0].dash == 0 and s.players[0].charge > 0, "shared action button charges instead of tackling while in possession")
	s.setup(0)
	s.phase = "play"
	s.clock = .001
	s.step(.01)
	check(s.overtime and s.phase == "play", "tie enters golden goal")
	s.goal_scored(1)
	s.step(3)
	check(s.phase == "result" and s.score[1] == 1, "golden goal ends match")
	s.setup(0)
	s.phase = "play"
	s.ball = Vector3(18.9, .6, 0)
	s.ball_velocity = Vector3(22, 0, 0)
	s.move_ball(.02)
	check(s.keeper_owner == 1 and s.stats.saves == 1 and s.score[0] == 0, "keeper catches a straight slower shot")
	for frame in 65: s.step(1.0 / 120)
	check(s.keeper_owner == -1 and s.ball_velocity.x < -1, "keeper distributes promptly back into play")
	s.setup(0)
	s.phase = "play"
	s.ball = Vector3(17, .5, 0)
	s.ball_velocity = Vector3(100, 0, 0)
	s.move_ball(.05)
	check(s.score[0] == 0 and s.ball_velocity.x < 0 and s.keepers[1].recovery > .5, "swept save stops tunnelling and parries powerful shots")
	s.ball = Vector3(18.7, .5, 0)
	s.ball_velocity = Vector3(50, 0, 0)
	s.move_ball(.06)
	check(s.score[0] == 1, "rebound shot can beat a recovering keeper")
	s.setup(0)
	s.phase = "play"
	s.ball = Vector3(19, .5, 3.0)
	s.ball_velocity = Vector3(50, 0, 0)
	s.move_ball(.05)
	check(s.score[0] == 1, "well-placed corner can beat a centered keeper")
	s.setup(0)
	s.phase = "play"
	s.ball = Vector3(8, .5, 2.6)
	s.ball_velocity = Vector3(30, 0, 0)
	var saw_dive := false
	for frame in 40:
		s.step(1.0 / 120)
		if s.keepers[1].dive > 0: saw_dive = true
	check(saw_dive, "keeper reacts then commits to a lateral dive")
	s.kickoff(-1)
	check(s.keeper_owner == -1 and s.keepers[1].dive == 0 and s.keepers[1].pos.y == 0, "kickoff resets keeper possession and recovery")
	var total_goals := 0
	var totals := {"shots": 0, "passes": 0, "tackles": 0, "supers": 0, "saves": 0}
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
	check(totals.saves > 10, "keepers make saves during real seeded matches")
	s.setup(1, false, 90, 120, true)
	check(s.players[0].human == 0 and s.players[2].human == 1 and s.players[1].human == -1, "one dual controller owns both teammates and leaves opponent bots")
	s.setup(2, false, 90, 120, true)
	check(s.players[1].human == 2 and s.players[3].human == 3, "second dual controller owns the opposing pair")
	for kickoff_team in [-1, 0, 1]:
		s.kickoff(kickoff_team)
		check(s.players[0].pos.x < s.players[2].pos.x and s.players[1].pos.x < s.players[3].pos.x, "L starts left of R for both teams at kickoff %d" % kickoff_team)
		check(s.players[0].human == 0 and s.players[2].human == 1 and s.players[1].human == 2 and s.players[3].human == 3, "kickoff preserves fixed stick ownership")
	s.phase = "play"
	s.players[0].pos = Vector2.ZERO
	s.players[2].pos = Vector2(0, 5)
	s.step(.05, {0: {"move": Vector2.RIGHT, "sprint": true}, 1: {"move": Vector2.LEFT}})
	check(s.players[0].vel.x > 0 and s.players[2].vel.x < 0, "both halves move their own unit simultaneously")
	check(s.players[0].stamina == 1, "sprint is disabled in the dual experiment")
	s.owner = 0
	s.step(.01, {0: {"pass": true}})
	check(s.owner == 0 and s.stats.passes == 0, "passing is disabled in the dual experiment")
	s.players[0].face = Vector2(1, .5).normalized()
	s.shoot_ball(0)
	check(Vector2(s.ball_velocity.x, s.ball_velocity.z).normalized().dot(s.players[0].face) > .999, "shot follows the displayed aim direction without hidden goal assist")
	s.setup(2, false, 90, 120, true)
	s.phase = "play"
	s.players[0].pos = Vector2.ZERO
	s.players[0].face = Vector2.RIGHT
	s.ball = Vector3(1.5, .45, 0)
	s.move_player(0, {"shoot": true, "tackle": true}, .016)
	s.move_ball(.016)
	check(s.owner == -1 and s.stats.shots == 1 and s.ball_velocity.x > 25, "dash into a loose ball automatically kicks it")
	check(s.players[0].human == 0 and s.players[2].human == 1, "dual ownership stays fixed after possession changes")
	for seed_value in [725, 18, 40]:
		s.setup(0, false, seed_value, 120, true)
		for frame in 24000:
			s.step(1.0 / 120)
			if s.phase == "result": break
		check(s.phase == "result" and s.stats.shots > 0 and s.stats.passes == 0, "dual-rules bot match %d finishes without passing (%s)" % [seed_value, str(s.score)])
	print("RESULT ", failures, " failures")
	quit(1 if failures > 0 else 0)
