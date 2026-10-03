extends SceneTree
const Sound = preload("res://src/sound.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok: failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var audio = Sound.new()
	root.add_child(audio)
	check(audio.players.size() == 10, "eight contact voices plus dedicated goal and whistle voices")
	for name in Sound.CUES:
		check(audio.banks[name].size() == Sound.CUES[name].count, name + " variants loaded")
		for stream in audio.banks[name]:
			check(stream.get_length() > .05 and stream.get_length() < 2.0, name + " is a short playable clip")
		var previous := -1
		var repeats := false
		for i in 30:
			var index: int = audio.choose_variant(name)
			if int(Sound.CUES[name].count) > 1 and index == previous: repeats = true
			previous = index
		check(not repeats, name + " avoids adjacent repeats")
	check(audio.play_cue("hit"), "first contact plays")
	check(not audio.play_cue("hit"), "duplicate contact in same frame is suppressed")
	audio.clock += .13
	check(audio.play_cue("hit"), "later independent contact plays")
	await process_frame
	audio.reset()
	for i in 8:
		audio.players[i].stream = audio.banks.kick[0]
		audio.players[i].play()
	check(audio.play_cue("goal"), "goal remains audible when all contact voices are occupied")
	check(audio.play_cue("whistle"), "whistle remains audible when all other voices are occupied")
	check(audio.players[8].get_meta("cue") == "goal", "goal uses reserved voice")
	check(audio.players[9].get_meta("cue") == "whistle", "whistle uses reserved voice")
	await process_frame
	audio.reset()
	check(audio.last_time.is_empty() and audio.last_variant.is_empty(), "rematch clears cue history")
	check(audio.players.all(func(p): return not p.playing), "reset stops every sound")
	var bus := AudioServer.get_bus_index("Match SFX")
	check(bus >= 0 and AudioServer.get_bus_effect(bus,0) is AudioEffectHardLimiter, "SFX peak limiter is installed")
	audio.free()
	await create_timer(0.1).timeout
	print("AUDIO_RESULT ", failures, " failures")
	quit(1 if failures else 0)
