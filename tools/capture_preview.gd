extends SceneTree
## Staged situations, real simulation/keepers/AI/rendering; no fake gameplay.
var game: Node
var frame := 0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.sound_enabled = false
	game.demo = true
	game.menu = false
	game.set_physics_process(false)
	stage(0)
	process_frame.connect(advance)

func stage(shot: int) -> void:
	game.team_size = shot + 1
	game.sim.setup(0, false, 725 + shot, 120, true, game.team_size)
	game.sim.phase = "play"
	game.sim.clock = 97
	game.sim.power = [100.0, 80.0]
	game.sync_arena()
	game.clear_effects()
	game.hit_stop = 0
	game.notice_time = 0
	var factor: float = game.sim.pitch_scale(game.team_size)
	game.aim_camera(Vector3(0, 0, game.CAMERA_AIM_Z * factor), factor)
	if shot == 1:
		game.sim.players[0].pos = Vector2(-1,0)
		game.sim.players[0].face = Vector2.RIGHT
		game.sim.players[1].pos = Vector2(1,0)
		game.sim.players[1].face = Vector2.LEFT
		game.sim.owner = 1
		game.sim.ball = Vector3(.2,.45,0)
	else:
		game.sim.players[0].pos = Vector2(game.sim.half_x - 11,-2)
		game.sim.players[0].face = Vector2(1,.30).normalized()
		game.sim.players[0].charge = .98
		game.sim.owner = 0
		game.sim.ball = Vector3(game.sim.half_x - 10,.45,-2)
	for i in game.sim.players.size():
		game.athletes[i].position = Vector3(game.sim.players[i].pos.x,0,game.sim.players[i].pos.y)
	game.ball_node.position = game.sim.ball

func advance() -> void:
	frame += 1
	if frame == 90: stage(1)
	if frame == 180: stage(2)
	var local_frame := frame % 90
	var shot := mini(frame / 90,2)
	if local_frame == 8:
		if shot == 1: game.sim.move_player(0,{"move":Vector2.RIGHT,"tackle":true},1.0/30)
		else: game.sim.shoot_ball(0)
		for event in game.sim.events: game.handle_event(event)
		game.sim.events.clear()
	var controls := {}
	if local_frame < 8:
		game.sim.players[0].human = 0
		controls[0] = {"move":Vector2.ZERO,"shoot":true}
	else: game.sim.players[0].human = -1
	if game.hit_stop <= 0:
		for tick in 4:
			game.sim.step(1.0/120,controls)
			for event in game.sim.events: game.handle_event(event)
	else: game.hit_stop = maxf(0,game.hit_stop-1.0/30)
	if frame >= 270: quit()
