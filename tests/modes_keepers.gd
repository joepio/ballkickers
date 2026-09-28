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
	print("MODES_KEEPERS_RESULT ", failures, " failures")
	quit(1 if failures else 0)
