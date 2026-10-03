extends SceneTree
const Settings = preload("res://src/settings.gd")
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func validate(settings: RefCounted) -> void:
	for spec in settings.SPECS:
		var invalid: Array = [null, {}, []]
		if spec.kind == "number":
			check(settings.change(spec.key, float(spec.min)), "JSON integral numbers accepted")
			check(settings.change(spec.key, spec.max), "Upper boundary accepted")
			invalid += [true, "10", 1.5, INF, NAN, spec.min-1, spec.max+1]
		elif spec.kind == "choice":
			for option in spec.options: check(settings.change(spec.key,option),"Choice accepted")
			invalid += ["unknown", 1, false]
		else:
			check(settings.change(spec.key, not spec.default), "Toggle accepted")
			invalid += ["false", 0, 1]
		check(settings.change(spec.key, spec.default), "Reset accepted")
		for value in invalid:
			check(not settings.change(spec.key,value), "Invalid value rejected: "+spec.key)
			check(settings.values[spec.key] == spec.default, "Invalid update preserves value")
	check(not settings.change("controller_id", 1), "Roster cannot be changed via settings")
func finish(settings: RefCounted) -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--settings-output="):
			var file = FileAccess.open(arg.trim_prefix("--settings-output="), FileAccess.WRITE)
			file.store_string(JSON.stringify(settings.SPECS))
	print("SETTINGS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

const Match = preload("res://src/match.gd")
func run() -> void:
	var settings = Settings.new()
	validate(settings)
	var slow = Match.new();slow.setup(2)
	var fast = Match.new();fast.setup(2)
	settings.change("run_speed",150);settings.apply_live(fast)
	for i in 30:
		slow.move_player(0,{"move":Vector2.RIGHT},.01)
		fast.move_player(0,{"move":Vector2.RIGHT},.01)
	check(fast.players[0].pos.x>slow.players[0].pos.x, "Movement changes in simulation")
	slow.setup(2);fast.setup(2)
	settings.change("shot_power",150);settings.apply_live(fast)
	slow.players[0].charge=.5;fast.players[0].charge=.5
	slow.shoot_ball(0);fast.shoot_ball(0)
	check(is_equal_approx(fast.ball_velocity.x,slow.ball_velocity.x*1.5),"Shot speed changes")
	fast.power[0]=100
	settings.change("super_shots",false);settings.apply_live(fast)
	fast.players[0].charge=1.
	fast.shoot_ball(0)
	check(fast.stats.supers==0,"Super shots disabled in actual shot path")
	fast.phase="play";fast.power=[20.,20.]
	settings.change("power_charge",0);settings.apply_live(fast)
	fast.step(.01,{})
	check(fast.power[0]==20., "No passive charge when disabled")
	finish(settings)
