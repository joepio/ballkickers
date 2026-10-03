extends SceneTree
## Uses the real simulation. Times exclude presentation hit-stop and device latency.
const Match = preload("res://src/match.gd")

func _initialize() -> void:
	var out_dir := "res://experiments/audio/output"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var runs := []
	for mode in ["dual", "2v2", "3v3", "classic"]:
		for seed_value in [725, 18, 40]:
			var sim = Match.new()
			var teams := 2 if mode == "2v2" else (3 if mode == "3v3" else 1)
			sim.setup(0, false, seed_value, 120, mode != "classic", teams)
			var events := [{"time": 0.0, "type": "start", "sound": "whistle"}]
			var mapping := {"shot": "kick", "pass": "pass", "super": "super",
				"hit": "hit", "save": "hit", "keeper_beaten": "hit",
				"goal": "goal", "finish": "goal", "whistle": "whistle", "overtime": "whistle"}
			for frame in 7200:
				sim.step(1.0 / 120)
				for event in sim.events:
					if mapping.has(event.type):
						events.append({"time": float(frame + 1) / 120.0, "type": event.type, "sound": mapping[event.type]})
			runs.append({"id": "%s-%d" % [mode, seed_value], "mode": mode, "seed": seed_value,
				"seconds": 60, "events": events, "stats": sim.stats})
	var file := FileAccess.open(out_dir + "/events.json", FileAccess.WRITE)
	if file == null:
		push_error("Cannot write events.json")
		quit(1)
		return
	file.store_string(JSON.stringify(runs, "\t"))
	print("AUDIO_EXPERIMENT: captured 12 deterministic 60-second simulation traces")
	quit(0)
