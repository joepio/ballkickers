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
	check(crowd.is_ready(), "crowd sound is ready at boot")
	check(not crowd._goal_samples.is_empty() and crowd._cheer_player.stream is AudioStreamOggVorbis,
		"the stadium recordings are loaded")
	check(crowd._murmur_player.stream.get_length() > 5.0, "murmur bed is a long seamless loop")
	check(crowd._chant_wavs.size() >= 3, "there are several chants")
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
	crowd.set_process(false)
	crowd.active = true
	crowd.enthusiasm = 0.2
	crowd.advance_chatter(0.1)
	check(crowd.murmur_db <= -80.0, "conversation starts with silence")
	crowd._chatter_wait = 0.0
	crowd.advance_chatter(0.35)
	check(crowd.murmur_db <= -33.0 and crowd.murmur_db > -60.0, "short chatter is quiet and fades in")
	crowd.advance_chatter(2.5)
	check(crowd.murmur_db <= -80.0 and crowd._chatter_wait >= 18.0, "chatter ends and leaves a long silent gap")
	crowd._chatter_wait = 0.0
	crowd.advance_chatter(0.4)
	crowd.enthusiasm = 1.0
	crowd.advance_chatter(0.1)
	check(crowd.murmur_db <= -80.0, "celebration interrupts chatter without muting cheers")
	check(crowd.cheer_db == -15.0 and crowd.reaction_db == -12.0, "other crowd layers retain their mix")
	crowd.active = false
	crowd.advance_chatter(0.1)
	check(crowd._chatter_age < 0.0 and crowd._chatter_wait >= 5.0, "pause and leaving reset chatter")
	print("CROWD_RESULT ", failures, " failures")
	quit(1 if failures else 0)
