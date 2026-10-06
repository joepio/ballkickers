extends SceneTree
## Renders one chaos event mid-play: godot --path . --script res://tools/capture_chaos.gd -- --chaos=dog --after=3 --out=/tmp/dog.png
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var kind := "streaker"
	var after := 3.0
	var out := "user://chaos.png"
	var teams := 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--chaos="): kind = arg.trim_prefix("--chaos=")
		elif arg.begins_with("--after="): after = float(arg.trim_prefix("--after="))
		elif arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		elif arg.begins_with("--teams="): teams = int(arg.trim_prefix("--teams="))
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.sound_enabled = false
	game.set_physics_process(false)
	game.team_size = teams
	game.menu = false
	game.sim.setup(0, false, 725, 120, true, teams)
	game.sync_arena()
	game.sim.phase = "play"
	game.sim.chaos.forced = kind
	game.camera.position = Vector3(0, 30 * game.sim.pitch_scale(teams), 31 * game.sim.pitch_scale(teams))
	await process_frame
	var t := 0.0
	while t < after:
		game.sim.step(1.0 / 60)
		for event in game.sim.events: game.handle_event(event)
		game.hit_stop = 0.0
		game.update_visuals(1.0 / 60)
		game.update_effects(1.0 / 60)
		t += 1.0 / 60
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("CAPTURE ", out)
	quit()
