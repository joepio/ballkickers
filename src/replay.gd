extends RefCounted
## Broadcast-style goal replays. Records the last seconds of live play as
## snapshots, then plays them back through the normal renderer: wipe in,
## real-time build-up, super slo-mo on the finish, a hold on the net, wipe out.
## Purely visual: the simulation is saved before playback and restored after.
const BUFFER := 300
const WINDOW := 230
const SLOW_FRAMES := 55
const WIPE := .42
const EVENT_TYPES := ["shot", "pass", "super", "save", "keeper_beaten", "hit", "keeper_dive", "goal", "dash", "receive"]
const LINES := {
	"own": ["OH NO. OWN GOAL!", "THEY'LL WANT TO FORGET THAT ONE", "WRONG END, WRONG END!"],
	"super": ["ABSOLUTE ROCKET!", "HIT IT LIKE IT OWED THEM MONEY", "THE NET IS STILL SHAKING"],
	"beaten": ["THE KEEPER WILL WANT THAT ONE BACK", "STRONG HAND... NOT STRONG ENOUGH"],
	"rebound": ["SCRAPPY! THEY ALL COUNT", "FIRST TO REACT. THAT'S INSTINCT"],
	"distance": ["FROM ALL THE WAY OUT THERE!", "SPECULATIVE... AND SPECTACULAR"],
	"tackle": ["WON IT BACK AND PUNISHED THEM", "PRESS, STEAL, FINISH. TEXTBOOK"],
	"bonus": ["THE BEACH BALL! DOES THAT COUNT? IT COUNTS!", "BRING YOUR OWN BALL, SCORE YOUR OWN GOAL"],
	"plain": ["WHAT A FINISH!", "TOP BINS!", "CLINICAL.", "PUT THAT ONE ON A T-SHIRT", "YOU CANNOT TEACH THAT", "AND THE CROWD GOES WILD"],
}
var frames: Array = []
var active := false
var stage := ""
var stage_time := 0.0
var cursor := 0.0
var clip: Array = []
var saved: Dictionary = {}
var scorer := ""
var team := 0
var caption := ""
var speed_kmh := 0
var skipped := false
## Reaction shots after the replay: the scorer, the coaches, the fans.
var reactions: Array = []
var scorer_index := -1
var own_goal := false

func clear() -> void:
	frames.clear()

func record(sim) -> void:
	var events: Array = []
	for e in sim.events:
		if e.type in EVENT_TYPES: events.append(e.duplicate())
	frames.append({
		"players": sim.players.map(func(p): return [p.pos, p.face, p.vel, p.stun, p.dash, p.kick, p.charge]),
		"keepers": sim.keepers.map(func(k): return [k.pos, k.dive, k.dive_dir, k.recovery, k.kick, k.vel]),
		"ball": sim.ball, "ball_velocity": sim.ball_velocity, "owner": sim.owner, "keeper_owner": sim.keeper_owner,
		"elapsed": sim.elapsed, "extra": sim.chaos.extra.get("pos", null), "events": events})
	if frames.size() > BUFFER: frames.pop_front()

func start(sim) -> bool:
	if frames.size() < 30: return false
	clip = frames.slice(maxi(0, frames.size() - WINDOW))
	saved = {"players": sim.players.duplicate(true), "keepers": sim.keepers.duplicate(true), "ball": sim.ball,
		"ball_velocity": sim.ball_velocity, "owner": sim.owner, "keeper_owner": sim.keeper_owner,
		"elapsed": sim.elapsed, "phase": sim.phase, "extra": sim.chaos.extra.duplicate(true)}
	team = sim.events_team
	describe(sim)
	plan_reactions()
	active = true
	skipped = false
	stage = "in"
	stage_time = 0.0
	cursor = 0.0
	return true

func describe(sim) -> void:
	# Lower-third facts and a commentary cliché chosen from what actually happened.
	var types: Array = []
	var top_speed := 0.0
	for f in clip:
		top_speed = maxf(top_speed, Vector2(f.ball_velocity.x, f.ball_velocity.z).length())
		for e in f.events: types.append(e.type)
	speed_kmh = int(top_speed * 2.6)
	var touch: int = sim.last_touch
	scorer_index = -1
	own_goal = false
	var kind := "plain"
	var bonus := false
	for e in clip[-1].events: if e.type == "goal" and e.get("bonus", false): bonus = true
	if bonus:
		scorer = "THE BEACH BALL"
		kind = "bonus"
	elif touch >= 0 and sim.players[touch].team != team:
		scorer = str(sim.players[touch].name)
		kind = "own"
		own_goal = true
	else:
		scorer = str(sim.players[touch].name) if touch >= 0 else "SOMEBODY"
		scorer_index = touch
		var shot_from := INF
		for f in clip:
			for e in f.events:
				if e.type in ["shot", "super"] and e.get("team", -1) == team: shot_from = absf(e.pos.x - (sim.half_x if team == 0 else -sim.half_x))
		if "super" in types: kind = "super"
		elif "keeper_beaten" in types: kind = "beaten"
		elif "save" in types: kind = "rebound"
		elif shot_from > sim.half_x * .8 and shot_from < INF: kind = "distance"
		elif "hit" in types: kind = "tackle"
	var options: Array = LINES[kind]
	caption = options[randi() % options.size()]

func plan_reactions() -> void:
	# Not every replay gets every cutaway, so they keep surprising.
	reactions.clear()
	if scorer_index >= 0: reactions.append({"kind": "scorer", "time": 1.9})
	if own_goal: reactions.append({"kind": "coach_sad", "time": 1.6})
	var extra: Array = ["coach", "fans"]
	extra.shuffle()
	if randf() < .75 or reactions.is_empty(): reactions.append({"kind": extra[0], "time": 1.6})
	if randf() < .3: reactions.append({"kind": extra[1], "time": 1.4})
	if not own_goal and randf() < .35: reactions.append({"kind": "coach_sad", "time": 1.3})

## The camera shot the broadcast is on right now.
func shot() -> String:
	match stage:
		"play": return "goalcam" if cursor >= clip.size() - SLOW_FRAMES else "wide"
		"hold": return "goalcam"
		"react": return reactions[reaction_index()].kind
		"out": return "react_end" if not reactions.is_empty() else "goalcam"
	return "wide"

func reaction_index() -> int:
	var t := stage_time
	for i in reactions.size():
		t -= reactions[i].time
		if t < 0: return i
	return reactions.size() - 1

func skip() -> void:
	if active and stage != "out":
		skipped = true
		stage = "out"
		stage_time = 0.0

## Advances playback; returns true while the replay owns the screen.
func advance(sim, dt: float, on_event: Callable) -> bool:
	if not active: return false
	stage_time += dt
	match stage:
		"in":
			if stage_time >= WIPE * .5 and cursor == 0.0:
				cursor = .001
				apply(sim, 0)
			if stage_time >= WIPE:
				stage = "play"
				stage_time = 0.0
		"play":
			var before := int(cursor)
			var slow := cursor >= clip.size() - SLOW_FRAMES
			cursor += dt * 60.0 * (.32 if slow else 1.25)
			var last := clip.size() - 1
			for index in range(before + 1, mini(int(cursor), last) + 1):
				for e in clip[index].events: on_event.call(e)
			apply(sim, mini(int(cursor), last))
			if cursor >= last:
				stage = "hold"
				stage_time = 0.0
		"hold":
			if stage_time >= .8:
				stage = "react" if not reactions.is_empty() else "out"
				stage_time = 0.0
				if stage == "react":
					apply(sim, clip.size() - 1)
					sim.phase = "goal"
		"react":
			# The goal frame stays frozen in place while everyone celebrates.
			sim.elapsed += dt
			var total := 0.0
			for r in reactions: total += r.time
			if stage_time >= total:
				stage = "out"
				stage_time = 0.0
		"out":
			if stage_time >= WIPE * .5 and not saved.is_empty(): restore(sim)
			if stage_time >= WIPE:
				active = false
				stage = ""
				return false
	return true

func slow_motion() -> bool:
	return stage == "play" and cursor >= clip.size() - SLOW_FRAMES or stage == "hold"

## 0..1 cover of the transition wipe, peaking when the picture swaps.
func wipe() -> float:
	if stage == "in" or stage == "out": return clampf(stage_time / WIPE, 0, 1)
	return -1.0

func ball_path(count: int) -> Array:
	var points: Array = []
	var end := mini(int(cursor), clip.size() - 1)
	for index in range(maxi(0, end - count), end + 1): points.append(clip[index].ball)
	return points

func apply(sim, index: int) -> void:
	var f: Dictionary = clip[index]
	sim.phase = "replay"
	for i in sim.players.size():
		var p: Dictionary = sim.players[i]
		var s: Array = f.players[i]
		p.pos = s[0]; p.face = s[1]; p.vel = s[2]; p.stun = s[3]; p.dash = s[4]; p.kick = s[5]; p.charge = s[6]
	for i in sim.keepers.size():
		var k: Dictionary = sim.keepers[i]
		var s: Array = f.keepers[i]
		k.pos = s[0]; k.dive = s[1]; k.dive_dir = s[2]; k.recovery = s[3]; k.kick = s[4]; k.vel = s[5]
	sim.ball = f.ball
	sim.ball_velocity = f.ball_velocity
	sim.owner = f.owner
	sim.keeper_owner = f.keeper_owner
	sim.elapsed = f.elapsed
	if f.extra != null and not sim.chaos.extra.is_empty(): sim.chaos.extra.pos = f.extra

func restore(sim) -> void:
	sim.players.assign(saved.players)
	sim.keepers.assign(saved.keepers)
	sim.ball = saved.ball
	sim.ball_velocity = saved.ball_velocity
	sim.owner = saved.owner
	sim.keeper_owner = saved.keeper_owner
	sim.elapsed = saved.elapsed
	sim.phase = saved.phase
	sim.chaos.extra = saved.extra
	saved = {}
