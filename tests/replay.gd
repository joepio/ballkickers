extends SceneTree
## Goal replays: record live play, play back without touching the outcome, skippable.
const Match = preload("res://src/match.gd")
const Replay = preload("res://src/replay.gd")
var failures := 0

func check(condition: bool, label: String) -> void:
	if not condition:
		push_error("FAIL: " + label)
		failures += 1
	else: print("PASS: ", label)

func until_goal(s, r) -> bool:
	for frame in 60 * 120:
		var live: bool = s.phase == "play"
		s.step(1.0 / 60)
		if s.phase == "kickoff": r.clear()
		elif live: r.record(s)
		if s.phase == "goal": return true
	return false

func _initialize() -> void:
	var s = Match.new()
	s.setup(0, false, 31, 600, true)
	s.chaos.level = 0
	var r = Replay.new()
	check(until_goal(s, r), "bot match produces a goal to replay")
	check(r.frames.size() >= 30 and r.frames[-1].events.any(func(e): return e.type == "goal"), "buffer ends on the goal frame")
	var before := [s.ball, s.players[0].pos, s.keepers[1].pos, s.phase, s.phase_time, s.score.duplicate()]
	s.clock = 60.0
	s.overtime = false
	var rally := [r.rally_time, r.swaps, r.chances]
	r.rally_time = 5.0
	r.swaps = 2
	r.chances = 1
	check(not r.worth_showing(s), "an ordinary mid-match goal gets no replay")
	r.rally_time = 40.0
	r.swaps = 14
	check(r.worth_showing(s), "a goal after a long back-and-forth point gets a replay")
	r.rally_time = 40.0
	r.swaps = 1
	r.chances = 1
	check(not r.worth_showing(s), "a long but quiet point does not")
	r.rally_time = rally[0]
	r.swaps = rally[1]
	r.chances = rally[2]
	s.clock = 9.0
	check(r.worth_showing(s), "a goal in the closing seconds gets a replay")
	s.clock = 0.0
	s.overtime = true
	check(r.worth_showing(s), "a golden goal gets a replay")
	check(r.start(s), "replay starts")
	check(r.scorer != "" and r.caption != "" and r.speed_kmh > 0, "lower third has scorer, caption and shot speed (%s, %s)" % [r.scorer, r.caption])
	var seen: Array = []
	var moved := false
	var t := 0.0
	while r.advance(s, 1.0 / 60, func(e): seen.append(e.type)) and t < 20:
		if s.phase == "replay" and s.ball != before[0]: moved = true
		t += 1.0 / 60
	check(moved and "goal" in seen, "playback moves the ball and re-fires the goal")
	check(t > 3 and t < 15, "replay runs a few seconds (%.1fs)" % t)
	check([s.ball, s.players[0].pos, s.keepers[1].pos, s.phase, s.phase_time, s.score] == before, "match state is restored exactly")
	check(until_goal(s, r), "match continues to another goal after the replay")
	check(r.start(s), "second replay starts")
	r.advance(s, .5, func(e): pass)
	r.skip()
	t = 0.0
	while r.advance(s, 1.0 / 60, func(e): pass): t += 1.0 / 60
	check(t < .5 and s.phase == "goal", "skipping ends the replay at once and restores play")
	r.clear()
	check(not r.start(s), "no replay without recorded play")
	print("REPLAY_RESULT %d failures" % failures)
	quit(1 if failures else 0)
