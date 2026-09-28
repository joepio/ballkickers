extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.sound_enabled = false
	game.set_physics_process(false)
	game.sim.setup(2, false, 725, 120, true)
	game.sim.phase = "play"
	game.menu = false
	game.humans = 2
	game.sim.players[0].face = Vector2(1, -.5).normalized()
	game.sim.players[2].face = Vector2(1, .5).normalized()
	game.sim.players[0].charge = .55
	game.sim.owner = 0
	game.sim.ball = Vector3(-4.5, .45, 0)
	await create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("E:/dev/goal-rush/captures/dual-controls.png")
	quit()
