extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)

func run() -> void:
	var viewport := SubViewport.new()
	root.add_child(viewport)
	var game = load("res://main.tscn").instantiate()
	viewport.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.menu = false
	game.team_size = 3
	game.sim.setup(6, false, 725, 120, true, 3)
	game.sync_arena()
	game.aim_camera(Vector3(0, 0, game.CAMERA_AIM_Z * game.sim.arena_factor), game.sim.arena_factor)
	for shape in [Vector2i(1600, 900), Vector2i(1024, 768), Vector2i(2100, 900), Vector2i(390, 844)]:
		viewport.size = shape
		await process_frame
		game.update_camera_framing()
		var bounds := Rect2(Vector2.ZERO, Vector2(shape))
		for side in [-1, 1]:
			for edge in [-1, 1]:
				check(bounds.has_point(game.camera.unproject_position(Vector3(side * game.sim.half_x, 1.0, edge * game.sim.half_z))), "Pitch corner clipped at %s" % shape)
				check(bounds.has_point(game.camera.unproject_position(Vector3(side * (game.sim.half_x + 2), game.sim.GOAL_HEIGHT, edge * game.sim.GOAL_Z))), "Goal clipped at %s" % shape)
		for menu in [false, true]:
			game.menu = menu
			var transform: Transform2D = game.hud.layout_transform(menu)
			check(is_equal_approx(transform.x.length(), transform.y.length()), "Distorted HUD at %s" % shape)
			var row := Rect2(61, 412, 475, 50) if menu else Rect2(570, 335, 460, 50)
			game.hud.hit_rects.assign([row])
			var visual_point: Vector2 = transform * row.get_center()
			check(bounds.has_point(visual_point) and game.hud.row_at(visual_point) == 0, "Menu row/hit mismatch at %s" % shape)
			check(game.hud.row_at(transform * (row.position - Vector2.ONE)) == -1, "Click outside row at %s" % shape)
		game.menu = false
	print("Ballkickers viewport checks: %d failures" % failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
