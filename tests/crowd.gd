extends SceneTree
const Sound = preload("res://src/sound.gd")
const Crowd = preload("res://src/crowd_sound.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok: failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.add_child(Sound.new())
	var crowd = Crowd.new()
	root.add_child(crowd)
	var start := Time.get_ticks_msec()
	while not crowd.is_ready() and Time.get_ticks_msec() - start < 60000:
		await process_frame
	check(crowd.is_ready(), "crowd sound synthesizes at boot")
	check(crowd._murmur_player.stream.get_length() > 5.0, "murmur bed is a long seamless loop")
	check(crowd._chant_wavs.size() == Crowd.CHANT_COUNT, "chants are composed")
	check(crowd._murmur_player.bus == &"Match SFX", "crowd plays through the match limiter")
	crowd.react({"type": "goal", "team": 0})
	check(crowd.enthusiasm == 0.0, "an empty stadium does not react")
	crowd.active = true
	crowd.kickoff()
	check(crowd.enthusiasm >= .85, "kick-off lifts the crowd")
	crowd.react({"type": "goal", "team": 1})
	await process_frame
	check(crowd.enthusiasm == 1.0 and crowd._celebrate_hold > 0.0, "a goal makes the crowd erupt")
	for i in 30: await process_frame
	check(crowd._cheer_player.volume_db > -40.0, "the cheer bed is audible after a goal")
	crowd.react({"type": "unknown"})
	crowd.active = false
	check(crowd.enthusiasm == 0.0 and crowd.fear == 0.0, "muting resets the mood")
	print("CROWD_RESULT ", failures, " failures")
	quit(1 if failures else 0)
