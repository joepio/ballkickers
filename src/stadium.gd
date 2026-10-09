extends Node3D
const ORANGE = Color("ff7547")
const BLUE = Color("58caff")
const INK = Color("182d41")
const CREAM = Color("fff2d2")
var arena_nodes: Array = []
var pitch_size := 1
var mats: Dictionary = {}
var crowd: Node3D
var scenery: Node3D
var floodlights: Array = []
var board: Node3D
var board_scores: Array = []
var board_bars: Array = []
var board_clock: Label3D
var blimp: Node3D
var blimp_angle := 0.0
static var display_font: Font
static var round_font: Font

## Lilita One for headlines and numbers, Fredoka SemiBold for everything else.
static func fonts() -> void:
	if display_font: return
	var fallback: Array[Font] = [ThemeDB.fallback_font]
	var lilita: FontFile = load("res://assets/fonts/LilitaOne-Regular.ttf")
	lilita.fallbacks = fallback
	display_font = lilita
	var fredoka := FontVariation.new()
	fredoka.base_font = load("res://assets/fonts/Fredoka-var.ttf")
	fredoka.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	fredoka.fallbacks = fallback
	round_font = fredoka

func material(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var key := str(color) + str(emission)
	if mats.has(key): return mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = .78
	if emission > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	mats[key] = m
	return m

func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, glow: float = 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return shape(parent, mesh, pos, color, glow)

func sphere(parent: Node3D, pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = 16
	mesh.rings = 8
	return shape(parent, mesh, pos, color)

func capsule(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 4
	return shape(parent, mesh, pos, color)

func shape(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, glow: float = 0.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material(color, glow)
	instance.position = pos
	parent.add_child(instance)
	return instance

func rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 8
	var instance := shape(parent, mesh, (a + b) / 2, color)
	var dir := (b - a).normalized()
	var axis := Vector3.UP.cross(dir)
	if axis.length() > .001: instance.quaternion = Quaternion(axis.normalized(), Vector3.UP.angle_to(dir))
	return instance

func ring(parent: Node3D, pos: Vector3, radius: float, width: float, color: Color) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - width
	mesh.outer_radius = radius + width
	mesh.rings = 48
	mesh.ring_segments = 6
	return shape(parent, mesh, pos, color)

func label3(parent: Node3D, text: String, pos: Vector3, size: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = .015
	label.modulate = color
	label.outline_size = 0
	fonts()
	label.font = display_font
	label.position = pos
	parent.add_child(label)
	return label

func build() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	# A bright summer sky for the close-ups; the main camera never sees it.
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("3f8fd2")
	sky_material.sky_horizon_color = Color("d4ecf2")
	sky_material.sky_curve = .12
	sky_material.ground_horizon_color = Color("d4ecf2")
	sky_material.ground_bottom_color = Color("6f9c5c")
	sky_material.sun_angle_max = 8
	env.sky = Sky.new()
	env.sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b4dbef")
	env.ambient_light_energy = .24
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -34, 0)
	sun.light_color = Color("ffe4b5")
	sun.light_energy = .62
	sun.shadow_enabled = true
	# Two cascades suit the perspective camera: crisp shadows on the pitch and
	# no stretched, streaky shadow texels on the far stands.
	sun.directional_shadow_max_distance = 110
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.shadow_normal_bias = 1.6
	add_child(sun)
	box(self, Vector3(0, -1.6, 0), Vector3(200, .6, 200), Color("7fae63"))
	box(self, Vector3(0, -1.32, 0), Vector3(78, .2, 58), Color("aeb3a6"))
	box(self, Vector3(0, -.8, 0), Vector3(49, 1.4, 31), INK)
	box(self, Vector3(0, -.32, 0), Vector3(45, .5, 27), Color("104c4b"))
	for i in 14:
		box(self, Vector3(-19.5 + i * 3, .01, 0), Vector3(3, .08, 24), Color("368e72") if i % 2 == 0 else Color("32866a"))
	var white := Color("dcebc4")
	for z in [-11.7, 11.7]: box(self, Vector3(0, .066, z), Vector3(41.5, .02, .11), white)
	for x in [-20.7, 0, 20.7]: box(self, Vector3(x, .066, 0), Vector3(.11, .02, 23.5), white)
	ring(self, Vector3(0, .07, 0), 3.6, .055, white)
	var center := sphere(self, Vector3(0, .07, 0), .18, white)
	center.scale.y = .1
	for side in [-1, 1]:
		var color: Color = BLUE if side == 1 else ORANGE
		box(self, Vector3(side * 16, .07, 0), Vector3(.10, .02, 11.5), white)
		for z in [-5.75, 5.75]: box(self, Vector3(side * 18.4, .07, z), Vector3(4.9, .02, .11), white)
		for z in [-8.1, 8.1]:
			var board := box(self, Vector3(side * 21.4, .55, z), Vector3(.65, 1.1, 8.7), color)
			board.set_meta("end_board", true)
			var trim := box(self, Vector3(side * 21.4, 1.14, z), Vector3(.78, .16, 8.7), CREAM)
			trim.set_meta("end_board", true)
		# Real net silhouette, recessed beyond the goal line.
		for z in [-3.7, 3.7]:
			rod(self, Vector3(side * 21.0, .05, z), Vector3(side * 21.0, 3.15, z), .15, CREAM)
			rod(self, Vector3(side * 21.0, 3.15, z), Vector3(side * 23.2, 2.5, z), .11, color)
		rod(self, Vector3(side * 21, 3.15, -3.7), Vector3(side * 21, 3.15, 3.7), .15, CREAM)
		for n in 16:
			var z: float = -3.7 + n * .4933
			rod(self, Vector3(side * 23.2, .08, z), Vector3(side * 23.2, 2.5, z), .023, Color("b8d4d5"))
			rod(self, Vector3(side * 21, 3.15, z), Vector3(side * 23.2, 2.5, z), .023, Color("b8d4d5"))
		for n in 6:
			rod(self, Vector3(side * 23.2, n * .5, -3.7), Vector3(side * 23.2, n * .5, 3.7), .023, Color("b8d4d5"))
		for z in [-12.45, 12.45]:
			box(self, Vector3(side * 10.5, .46, z), Vector3(21, .95, .55), INK)
			box(self, Vector3(side * 10.5, .98, z), Vector3(21, .14, .72), color)
	# Rear stands, chunky canopies and luminous scoreboard.
	for tier in 3:
		box(self, Vector3(0, .2 + tier * .65, -15.1 - tier * 1.25), Vector3(49, 1 + tier * .6, 1.3), Color("344c68"))
		for side in [-1, 1]: box(self, Vector3(side * (26 + tier * 1.3), .2 + tier * .65, 0), Vector3(1.4, 1 + tier * .6, 29), Color("344c68"))
	for x in [-23, 23]:
		rod(self, Vector3(x, 0, -18), Vector3(x, 9, -18), .23, INK)
		box(self, Vector3(x, 9.1, -17.7), Vector3(3.5, .8, .65), CREAM)
		for i in 4: box(self, Vector3(x - 1.3 + i * .86, 9.15, -17.31), Vector3(.55, .4, .06), Color("fff3cb"), .8)
	for x in [-15, 15]:
		box(self, Vector3(x, 5.25, -18), Vector3(11, .45, 4.8), Color("2b4058"))
		box(self, Vector3(x, 5.25, -15.55), Vector3(11, .5, .12), Color("d9dde0"))
		for xx in [-4.5, 4.5]: rod(self, Vector3(x + xx, 0, -19), Vector3(x + xx, 5.1, -19), .15, INK)
	box(self, Vector3(0, 4.3, -19), Vector3(14.2, 3.6, .55), INK)
	box(self, Vector3(0, 6.2, -19), Vector3(14.5, .16, .65), Color("ffc94d"))
	for x in [-15, -5, 5, 15]:
		label3(self, "PLAY LOUD" if abs(x) == 15 else "RUSH!", Vector3(x, .5, -12.1), 35, ORANGE if x < 0 else BLUE)
	build_bowl()
	crowd = preload("res://src/crowd.gd").new()
	add_child(crowd)
	# Tag the goal/net before batching so it can move without stretching.
	for child in get_children():
		if child is MeshInstance3D and absf(child.position.x) >= 20.9 and absf(child.position.x) <= 23.3 and absf(child.position.z) < 3.9:
			child.set_meta("goal", true)
	batch_static_geometry()
	build_board()
	for child in get_children():
		if child is GeometryInstance3D:
			arena_nodes.append({"node": child, "transform": child.transform})

func build_board() -> void:
	# The stadium screen is the scoreboard: score, clock and power meters live
	# in the world, so the HUD can stay out of the way.
	board = Node3D.new()
	board.name = "Board"
	board.position = Vector3(0, 0, -18.68)
	add_child(board)
	for team in 2:
		var x := -4.6 if team == 0 else 4.6
		var color: Color = ORANGE if team == 0 else BLUE
		box(board, Vector3(x, 4.35, 0), Vector3(4.2, 2.5, .06), color)
		board_scores.append(label3(board, "0", Vector3(x, 4.3, .06), 170, INK))
		box(board, Vector3(x, 2.85, 0), Vector3(4.2, .26, .06), Color("0d1a26"))
		var bar := box(board, Vector3(x, 2.85, .05), Vector3(4.2, .26, .06), color, .4)
		board_bars.append(bar)
	label3(board, "BALLKICKERS", Vector3(0, 5.3, .04), 34, Color("ffc94d"))
	board_clock = label3(board, "2:00", Vector3(0, 4.15, .04), 110, CREAM)

func update_board(sim, time: float) -> void:
	for team in 2:
		board_scores[team].text = str(sim.score[team])
		var power: float = clampf(sim.power[team] / 100.0, 0, 1)
		var bar: MeshInstance3D = board_bars[team]
		var x := -4.6 if team == 0 else 4.6
		bar.scale.x = maxf(.001, power)
		# Both meters fill outwards from the clock.
		bar.position.x = x + 2.1 * (1 - power) * (1 if team == 0 else -1)
		var ready := power >= .99 and fmod(time, .5) < .3
		bar.material_override = material(Color("ffc94d") if ready else (ORANGE if team == 0 else BLUE), .9 if ready else .4)
	var seconds := int(ceil(sim.clock))
	board_clock.text = "GOLDEN\nGOAL" if sim.overtime else "%d:%02d" % [seconds / 60, seconds % 60]
	board_clock.font_size = 56 if sim.overtime else 110

func build_bowl() -> void:
	# Near stand, dugouts, corners and the outer wall that closes the stadium.
	var seat := Color("344c68")
	var shell := Color("2b4058")
	for tier in 2:
		box(self, Vector3(0, .2 + tier * .65, 16.4 + tier * 1.25), Vector3(49, 1 + tier * .6, 1.3), seat)
	for side in [-1, 1]:
		var color: Color = ORANGE if side == -1 else BLUE
		for z in [-17.6, 17.2]:
			box(self, Vector3(side * 27.6, .3, z), Vector3(5.2, 2.0, 5.0), shell)
		box(self, Vector3(side * 31.2, .9, 0), Vector3(1.4, 4.4, 41), shell)
		box(self, Vector3(side * 31.2, 3.16, 0), Vector3(1.5, .16, 41), Color("d9dde0"))
		# Dugouts: a bench, a backrest and a few spare balls.
		box(self, Vector3(side * 6.8, .25, 15.05), Vector3(4.2, .5, .62), color.darkened(.25))
		box(self, Vector3(side * 6.8, .62, 15.32), Vector3(4.2, .75, .12), color)
		for n in 3: sphere(self, Vector3(side * 6.8 + (n - 1) * .3 + .9, .14, 14.6), .14, CREAM)
	box(self, Vector3(0, .6, -20.4), Vector3(64, 3.8, 1.2), shell)
	box(self, Vector3(0, .5, 19.4), Vector3(64, 2.6, 1.2), shell)
	# Floodlight towers in the corners lean over the pitch.
	for x in [-1, 1]:
		for z in [-1, 1]:
			var base := Vector3(x * 33.5, -1.3, z * 22.5)
			var top := Vector3(x * 32.2, 17, z * 21.4)
			rod(self, base, top, .32, Color("d9dde0"))
			for n in 5: rod(self, base.lerp(top, n / 5.0) + Vector3(-x * .3, 0, 0), base.lerp(top, n / 5.0 + .2) + Vector3(x * .3, 0, 0), .06, Color("d9dde0"))
			var head := box(self, top + Vector3(-x * .6, .9, -z * .5), Vector3(4.2, 2.6, .35), INK)
			head.rotation = Vector3(.45, atan2(-x, -z), 0)
			for n in 6:
				var lamp := box(self, Vector3.ZERO, Vector3(1.0, .9, .08), Color("fff6d8"), .9)
				lamp.transform = head.transform * Transform3D(Basis.IDENTITY, Vector3((n % 3 - 1) * 1.25, (n / 3 - .5) * 1.15, .2))
			# Each tower throws a real light, so everyone on the pitch gets the
			# classic four-way floodlight shadow.
			var flood := SpotLight3D.new()
			flood.light_color = Color("fff1d6")
			flood.light_energy = .28
			flood.spot_range = 80
			flood.spot_angle = 30
			flood.spot_attenuation = .2
			flood.shadow_enabled = true
			flood.shadow_bias = .12
			flood.shadow_normal_bias = 2.5
			flood.shadow_opacity = 1.0
			flood.shadow_blur = 1.5
			add_child(flood)
			floodlights.append({"light": flood, "at": head.position})
	place_floodlights(1.0)
	build_scenery()

func place_floodlights(factor: float) -> void:
	for entry in floodlights:
		var light: SpotLight3D = entry.light
		var at: Vector3 = entry.at
		# Hang the light a few metres in front of its tower, so the lattice and the
		# lamp housing never sit between the light and the pitch. With the light
		# inside the tower they cast thin black streaks across the corners.
		var spot := Vector3(at.x * factor, at.y, at.z * factor)
		spot += (Vector3.ZERO - spot).normalized() * 3.0
		light.position = spot
		light.look_at(Vector3(0, 0, 0))

func build_scenery() -> void:
	# Far beyond the stands: a park ring of trees, rolling hills, a small skyline,
	# clouds and the Ballkickers blimp. Only the replay cameras ever see it.
	scenery = Node3D.new()
	scenery.name = "Scenery"
	add_child(scenery)
	var random := RandomNumberGenerator.new()
	random.seed = 61
	var leaves := [Color("4f9a4a"), Color("5fae52"), Color("3f8a4a"), Color("78b850")]
	for n in 150:
		var angle := random.randf() * TAU
		var reach := random.randf_range(1.0, 1.6)
		var at := Vector3(cos(angle) * 44 * reach, -1.3, sin(angle) * 34 * reach)
		# Keep the near side clear so no treetop pokes into the main camera.
		if at.z > 0: at.z += 16
		var size := random.randf_range(.8, 1.5)
		rod(scenery, at, at + Vector3(0, 2.2 * size, 0), .22 * size, Color("7a5236"))
		var crown := sphere(scenery, at + Vector3(0, 3.3 * size, 0), 1.7 * size, leaves[n % leaves.size()])
		crown.scale = Vector3(1, 1.15, 1)
		if n % 3 == 0: sphere(scenery, at + Vector3(.7, 4.4 * size, .3) * Vector3(size, 1, size), 1.1 * size, leaves[(n + 1) % leaves.size()])
	for n in 9:
		var angle := n / 9.0 * TAU + .3
		var hill := sphere(scenery, Vector3(cos(angle) * 190, -14, sin(angle) * 170), random.randf_range(45, 70), Color("8bb56a") if n % 2 else Color("7aa864"))
		hill.scale = Vector3(1.6, .55, 1)
	var walls := [Color("e6d5be"), Color("c8d6df"), Color("f0b49a"), Color("a9c4d3"), Color("f3e3a1")]
	for n in 46:
		var angle := random.randf_range(-2.6, -.55)
		var reach := random.randf_range(95, 125)
		var height := random.randf_range(10, 34)
		var width := random.randf_range(7, 14)
		var at := Vector3(cos(angle) * reach, height / 2 - 1.3, sin(angle) * reach)
		var block := box(scenery, at, Vector3(width, height, width * .8), walls[n % walls.size()])
		block.rotation.y = -angle
		var roof := box(scenery, at + Vector3(0, height / 2 + .3, 0), Vector3(width * .7, .6, width * .55), Color("5a6b7a"))
		roof.rotation.y = -angle
	for n in 14:
		var at := Vector3(random.randf_range(-160, 160), random.randf_range(38, 60), random.randf_range(-170, 120))
		if absf(at.x) < 60 and absf(at.z) < 60: at.z -= 90
		for puff in 4:
			var cloud := sphere(scenery, at + Vector3(puff * 5.0 - 7.5, sin(puff * 2.0) * 1.5, random.randf_range(-2, 2)), random.randf_range(4, 6.5), Color("ffffff"))
			cloud.scale = Vector3(1.3, .6, 1)
	build_outskirts(random)
	batch_children(scenery)
	blimp = Node3D.new()
	scenery.add_child(blimp)
	var hull := capsule(blimp, Vector3.ZERO, 3.2, 15, CREAM)
	hull.rotation.z = PI / 2
	box(blimp, Vector3(0, -3.3, 0), Vector3(3.2, 1, 1.5), INK)
	for fin in 2: box(blimp, Vector3(-6.6, 0, 0), Vector3(2.2, .2, 5.4) if fin == 0 else Vector3(2.2, 5.4, .2), ORANGE)
	for side in [-1, 1]:
		var name_tag := label3(blimp, "BALLKICKERS", Vector3(0, .4, side * 3.25), 130, BLUE)
		name_tag.rotation.y = 0.0 if side == 1 else PI
		name_tag.double_sided = false

func build_outskirts(random: RandomNumberGenerator) -> void:
	# Match-day life right outside the walls: food trucks behind the main stand,
	# car parks on both sides, the team buses, flags and lamp posts on the plaza.
	var paint := [Color("e84d6b"), Color("ffc94d"), Color("6ccf7a"), Color("ad85cc"), Color("f3f0e6"), Color("4f8fe0"), Color("2b2f3a"), Color("d96c3f")]
	var trucks := [["HOT DOGS", Color("ffc94d")], ["CHIPS", Color("e84d6b")], ["ICE CREAM", Color("f7b6d0")], ["COFFEE", Color("8a5a3c")], ["PIZZA", Color("6ccf7a")]]
	for n in trucks.size():
		var at := Vector3(-17 + n * 8.5, -1.22, -25.5)
		var color: Color = trucks[n][1]
		box(scenery, at + Vector3(0, 1.45, 0), Vector3(5.2, 2.6, 2.4), color)
		box(scenery, at + Vector3(2.9, 1.0, 0), Vector3(1.6, 1.7, 2.3), color.darkened(.15))
		box(scenery, at + Vector3(3.3, 1.45, 0), Vector3(.9, .7, 2.2), Color("bfe3ef"))
		box(scenery, at + Vector3(-.4, 1.65, 1.21), Vector3(3.2, 1.0, .05), INK)
		for stripe in 6:
			box(scenery, at + Vector3(-1.9 + stripe * .6, 2.55, 1.6), Vector3(.6, .1, .9), CREAM if stripe % 2 == 0 else color.darkened(.2))
		for wheel in [-1.6, 2.6]:
			for side in [-1, 1]: sphere(scenery, at + Vector3(wheel, .3, side * 1.1), .38, Color("1c1f26"))
		var sign := label3(scenery, trucks[n][0], at + Vector3(-.4, 3.25, .4), 60, color.darkened(.45) if n == 2 else CREAM)
		sign.outline_size = 10
		sign.outline_modulate = INK
		# A short queue of hungry fans.
		for q in random.randi_range(1, 3):
			var fan := at + Vector3(-.4 + random.randf_range(-.4, .4), 0, 2.4 + q * 1.1)
			capsule(scenery, fan + Vector3(0, .75, 0), .32, 1.1, paint[random.randi_range(0, paint.size() - 1)])
			sphere(scenery, fan + Vector3(0, 1.55, 0), .3, crowd_skin(random))
	for side in [-1, 1]:
		# Car parks: asphalt, white bays and rows of little cars.
		box(scenery, Vector3(side * 47, -1.2, 0), Vector3(14, .08, 40), Color("4d545c"))
		for row in 2:
			var x: float = side * (42.5 + row * 9)
			for bay in 12:
				var z := -16.5 + bay * 3.0
				box(scenery, Vector3(x, -1.14, z - 1.5), Vector3(4.6, .02, .12), Color("e8e8e0"))
				if random.randf() < .78:
					var car: Color = paint[random.randi_range(0, paint.size() - 1)]
					var nose: int = -side if row == 0 else side
					var at := Vector3(x + nose * .1, -1.16, z)
					box(scenery, at + Vector3(0, .55, 0), Vector3(3.6, .75, 1.7), car)
					box(scenery, at + Vector3(-nose * .3, 1.15, 0), Vector3(1.9, .6, 1.5), car.lightened(.15))
					box(scenery, at + Vector3(-nose * .3, 1.15, 0), Vector3(1.95, .4, 1.55), Color("2c3e50"))
					for wheel in [-1.1, 1.1]:
						for w in [-1, 1]: sphere(scenery, at + Vector3(wheel, .3, w * .82), .32, Color("1c1f26"))
		# Lamp posts along the car park.
		for z in [-18, -6, 6, 18]:
			rod(scenery, Vector3(side * 38.2, -1.3, z), Vector3(side * 38.2, 5, z), .12, Color("d9dde0"))
			box(scenery, Vector3(side * 38.2, 5.1, z), Vector3(1.2, .25, .5), Color("d9dde0"))
	# The team buses, parked by the players' entrance.
	for team in 2:
		var color: Color = ORANGE if team == 0 else BLUE
		var at := Vector3(-30 + team * 60, -1.22, -27.5)
		box(scenery, at + Vector3(0, 1.9, 0), Vector3(11, 3.2, 2.8), CREAM)
		box(scenery, at + Vector3(0, 1.3, 0), Vector3(11.05, 1.0, 2.85), color)
		box(scenery, at + Vector3(0, 2.6, 0), Vector3(10.2, .9, 2.9), Color("2c3e50"))
		for wheel in [-3.6, 3.4]:
			for side in [-1, 1]: sphere(scenery, at + Vector3(wheel, .45, side * 1.3), .5, Color("1c1f26"))
	# A row of flags along the plaza.
	for n in 10:
		var at := Vector3(-34 + n * 7.5, -1.3, -22.6)
		rod(scenery, at, at + Vector3(0, 7, 0), .08, Color("d9dde0"))
		box(scenery, at + Vector3(.75, 6.3, 0), Vector3(1.5, 1.0, .05), paint[n % 6])

func crowd_skin(random: RandomNumberGenerator) -> Color:
	var skins := [Color("ffe0bd"), Color("f2c29b"), Color("d9a074"), Color("b47a50"), Color("8a5634"), Color("5e3a22")]
	return skins[random.randi_range(0, skins.size() - 1)]

func make_cameraman(index: int) -> Node3D:
	# Camera operators in hi-vis bibs with a shoulder camera and a red tally
	# light; replays are filmed through their lenses.
	var root := Node3D.new()
	root.name = "Cameraman%d" % index
	add_child(root)
	root.scale = Vector3.ONE * 1.15
	if index < 2:
		# The goal-line operators film from a small riser.
		var riser := box(root, Vector3(0, -.52, 0), Vector3(1.3, 1.04, 1.3), Color("5c666c"))
		riser.name = "Riser"
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var skin: Color = [Color("d9a074"), Color("ffe0bd"), Color("8a5634")][index % 3]
	capsule(body, Vector3(0, .95, 0), .4, 1.05, Color("2b2f3a"))
	var bib := capsule(body, Vector3(0, 1.05, 0), .42, .7, Color("d7f24a"))
	bib.scale = Vector3(1, 1, 1.02)
	box(body, Vector3(0, 1.05, .41), Vector3(.5, .06, .04), Color("eef3f5"))
	box(body, Vector3(0, .9, .41), Vector3(.5, .06, .04), Color("eef3f5"))
	sphere(body, Vector3(0, 1.7, 0), .42, skin)
	var cap := sphere(body, Vector3(0, 1.93, -.02), .4, Color("1c1f26"))
	cap.scale = Vector3(1.05, .45, 1.05)
	box(body, Vector3(0, 1.88, -.42), Vector3(.46, .05, .24), Color("1c1f26"))
	ring(body, Vector3(0, 1.74, 0), .44, .05, Color("1c1f26")).rotation.z = PI / 2
	for side in [-1, 1]:
		sphere(body, Vector3(side * .44, 1.72, 0), .12, Color("1c1f26"))
		var eye := sphere(body, Vector3(side * .14, 1.74, .38), .05, INK)
		eye.scale = Vector3(.9, 1.4, .6)
		var leg := Node3D.new()
		leg.name = "LegL" if side == -1 else "LegR"
		leg.position = Vector3(side * .2, .48, 0)
		body.add_child(leg)
		capsule(leg, Vector3(0, -.2, 0), .15, .5, Color("3a4250"))
		capsule(leg, Vector3(0, -.42, .1), .17, .45, INK).rotation.x = PI / 2
	# The camera rides on the right shoulder and points where the body faces.
	var cam := Node3D.new()
	cam.name = "Camera"
	cam.position = Vector3(.42, 1.62, .15)
	body.add_child(cam)
	box(cam, Vector3(0, 0, 0), Vector3(.32, .4, .85), Color("1c1f26"))
	box(cam, Vector3(0, .25, -.05), Vector3(.06, .12, .5), Color("1c1f26"))
	var lens := rod(cam, Vector3(0, 0, .4), Vector3(0, 0, .75), .14, Color("2f3642"))
	lens.name = "Lens"
	sphere(cam, Vector3(0, 0, .76), .1, Color("7fc6e8"))
	box(cam, Vector3(0, .24, .25), Vector3(.08, .06, .08), Color("ff3b3b"), 2.0)
	var arm := capsule(body, Vector3(.42, 1.35, .1), .13, .5, Color("2b2f3a"))
	arm.rotation.x = -1.2
	return root

func _process(dt: float) -> void:
	if blimp == null: return
	blimp_angle += dt * .025
	blimp.position = Vector3(cos(blimp_angle) * 70, 30, sin(blimp_angle) * 55 - 10)
	blimp.rotation.y = -blimp_angle - PI / 2

func resize_pitch(teams: int) -> void:
	pitch_size = teams
	var factor: float = preload("res://src/match.gd").pitch_scale(teams)
	crowd.layout(factor)
	scenery.scale = Vector3.ONE * factor
	place_floodlights(factor)
	board.position.z = -18.68 * factor
	for entry in arena_nodes:
		var node: GeometryInstance3D = entry.node
		node.transform = entry.transform
		if node.get_meta("end_board", false):
			node.position.x = signf(node.position.x) * (21.0 * factor + .4)
			var outer := 12.45 * factor
			node.position.z = signf(node.position.z) * (3.75 + outer) * .5
			node.scale.z = (outer - 3.75) / 8.7
		elif node.has_meta("goal_side"):
			node.position.x += float(node.get_meta("goal_side")) * 21.0 * (factor - 1)
		else:
			node.position.x *= factor
			node.position.z *= factor
			node.scale.x *= factor
			node.scale.z *= factor

func batch_static_geometry() -> void:
	batch_children(self)

func batch_children(parent: Node3D) -> void:
	# Merge immutable stadium pieces by material. The net and stands no longer
	# need hundreds of individual draw submissions, including their shadow pass.
	var groups: Dictionary = {}
	var sources: Array = []
	for child in parent.get_children():
		if child is MeshInstance3D and not child.get_meta("end_board", false):
			var mat: Material = child.material_override
			var key := str(mat.get_instance_id()) + ("goal_left" if child.position.x < 0 else "goal_right") if child.get_meta("goal", false) else str(mat.get_instance_id())
			if not groups.has(key): groups[key] = []
			groups[key].append(child)
			sources.append(child)
	for mat in groups:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for source in groups[mat]: surface.append_from(source.mesh, 0, source.transform)
		var merged := MeshInstance3D.new()
		merged.mesh = surface.commit()
		merged.material_override = groups[mat][0].material_override
		if "goal_" in mat: merged.set_meta("goal_side", -1 if "left" in mat else 1)
		parent.add_child(merged)
	for source in sources:
		parent.remove_child(source)
		source.queue_free()

func make_player(index: int, keeper: bool = false) -> Node3D:
	var root := Node3D.new()
	root.name = "Athlete%d" % index
	add_child(root)
	var color: Color = ORANGE if index % 2 == 0 else BLUE
	if keeper: color = Color("ffcf4d") if index % 2 == 0 else Color("c38aff")
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	capsule(body, Vector3(0, .92, 0), .43, 1.03, color)
	capsule(body, Vector3(0, .49, 0), .37, .55, INK)
	var head := sphere(body, Vector3(0, 1.72, 0), .46, CREAM)
	head.name = "Head"
	# Sweatband follows the face, with no floating panel geometry.
	for side in [-1, 1]:
		var eye := sphere(body, Vector3(side * .15, 1.76, .411), .056, INK)
		eye.scale = Vector3(.9, 1.5, .6)
		eye.name = "EyeL" if side == -1 else "EyeR"
		var brow := box(body, Vector3(side * .15, 1.86, .44), Vector3(.15, .035, .04), INK)
		brow.name = "BrowL" if side == -1 else "BrowR"
		var leg := Node3D.new()
		leg.name = "LegL" if side == -1 else "LegR"
		leg.position = Vector3(side * .24, .48, 0)
		body.add_child(leg)
		capsule(leg, Vector3(0, -.16, 0), .16, .42, INK if keeper else CREAM)
		var boot := capsule(leg, Vector3(0, -.36, .10), .21, .55, color.darkened(.25))
		boot.rotation.x = PI / 2
		var arm := Node3D.new()
		arm.name = "ArmL" if side == -1 else "ArmR"
		arm.position = Vector3(side * .47, 1.22, 0)
		body.add_child(arm)
		capsule(arm, Vector3(side * .04, -.17, 0), .16, .46, color)
		sphere(arm, Vector3(side * .09, -.37, 0), .30 if keeper else .21, CREAM)
	var mouth := box(body, Vector3(0, 1.58, .43), Vector3(.15, .045, .04), INK)
	mouth.name = "Mouth"
	var hair := Node3D.new()
	hair.name = "Hair"
	hair.set_meta("color", HAIR[index % HAIR.size()])
	body.add_child(hair)
	add_hairstyle(hair, (index / 2 + (index % 2) * 4) % 8, HAIR[index % HAIR.size()])
	var stars := Node3D.new()
	stars.name = "Stars"
	stars.position = Vector3(0, 2.45, 0)
	stars.visible = false
	body.add_child(stars)
	for n in 3:
		var star := sphere(stars, Vector3(cos(n * TAU / 3), 0, sin(n * TAU / 3)) * .42, .09, Color("ffd84d"))
		star.material_override = material(Color("ffd84d"), 1.5)
	var badge := label3(body, "GK" if keeper else str(index / 2 + 1), Vector3(0, 1.04, -.435), 32, CREAM)
	badge.rotation.y = PI
	var marker := ring(root, Vector3(0, .11, 0), .83, .085, color)
	marker.name = "Marker"
	return root

const HAIR = [Color("2b1d14"), Color("e8c35a"), Color("c9503a"), Color("5a3a1e"), Color("1b1b2a"), Color("f0eadc"), Color("7a4a2a")]

func add_hairstyle(body: Node3D, style: int, hair: Color) -> void:
	# Parts are children of the Hair node, so a GameNight profile colour can dye them.
	# Every athlete gets a silhouette of their own, readable from the broadcast camera.
	match style:
		0: # Mohawk
			for n in 4: box(body, Vector3(0, 2.13 - absf(n - 1.5) * .05, .22 - n * .16), Vector3(.1, .26, .14), hair)
		1: # Afro
			var afro := sphere(body, Vector3(0, 1.98, -.08), .44, hair)
			afro.scale = Vector3(1.12, .9, 1.0)
		2: # Ponytail
			sphere(body, Vector3(0, 1.9, -.18), .4, hair).scale = Vector3(1.05, .75, 1.0)
			sphere(body, Vector3(0, 1.75, -.55), .15, hair)
			sphere(body, Vector3(0, 1.52, -.6), .12, hair)
		3: # Backwards cap
			sphere(body, Vector3(0, 1.98, -.02), .43, hair).scale = Vector3(1.04, .55, 1.04)
			box(body, Vector3(0, 1.95, -.5), Vector3(.5, .05, .3), hair.darkened(.2))
		4: # Spikes
			for n in 5:
				var spike := box(body, Vector3((n - 2) * .14, 2.12, -.05), Vector3(.1, .3, .1), hair)
				spike.rotation.z = (n - 2) * -.32
		5: # Moustache and a shiny head
			box(body, Vector3(0, 1.645, .44), Vector3(.3, .07, .06), hair.darkened(.1))
			sphere(body, Vector3(.12, 2.08, .1), .07, Color("fffbe8")).set_meta("dye", false)
		6: # Top bun
			sphere(body, Vector3(0, 1.94, -.08), .41, hair).scale = Vector3(1.03, .6, 1.0)
			sphere(body, Vector3(0, 2.22, -.1), .17, hair)
		7: # Round glasses and curls
			for side in [-1, 1]:
				var lens := ring(body, Vector3(side * .15, 1.76, .43), .085, .018, INK)
				lens.rotation.x = PI / 2
				lens.set_meta("dye", false)
				for n in 3: sphere(body, Vector3(side * (.12 + n * .1), 2.02 - n * .07, -.1 - n * .05), .14, hair)
			box(body, Vector3(0, 1.77, .45), Vector3(.1, .02, .02), INK).set_meta("dye", false)

func make_coach(team: int) -> Node3D:
	# Touchline managers: suit, team tie and cap, one moustache, one pair of glasses.
	var color: Color = ORANGE if team == 0 else BLUE
	var root := Node3D.new()
	root.name = "Coach%d" % team
	add_child(root)
	root.scale = Vector3.ONE * 1.2
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var suit := Color("2a3a4f") if team == 0 else Color("3b2f4a")
	capsule(body, Vector3(0, .95, 0), .42, 1.1, suit)
	box(body, Vector3(0, 1.12, .36), Vector3(.22, .5, .06), CREAM)
	box(body, Vector3(0, 1.08, .4), Vector3(.08, .42, .04), color)
	capsule(body, Vector3(0, .5, 0), .36, .5, suit.darkened(.2))
	sphere(body, Vector3(0, 1.72, 0), .44, Color("f2c29b"))
	var cap := sphere(body, Vector3(0, 1.98, .02), .42, color)
	cap.scale = Vector3(1.05, .45, 1.08)
	box(body, Vector3(0, 1.93, .42), Vector3(.5, .05, .26), color.darkened(.25))
	for side in [-1, 1]:
		var eye := sphere(body, Vector3(side * .15, 1.76, .4), .055, INK)
		eye.scale = Vector3(.9, 1.4, .6)
		var leg := Node3D.new()
		leg.name = "LegL" if side == -1 else "LegR"
		leg.position = Vector3(side * .22, .48, 0)
		body.add_child(leg)
		capsule(leg, Vector3(0, -.2, 0), .15, .5, suit.darkened(.2))
		capsule(leg, Vector3(0, -.42, .1), .17, .45, INK).rotation.x = PI / 2
		var arm := Node3D.new()
		arm.name = "ArmL" if side == -1 else "ArmR"
		arm.position = Vector3(side * .46, 1.25, 0)
		body.add_child(arm)
		capsule(arm, Vector3(side * .04, -.18, 0), .14, .48, suit)
		sphere(arm, Vector3(side * .08, -.4, 0), .16, Color("f2c29b"))
		if team == 1:
			var lens := ring(body, Vector3(side * .15, 1.76, .43), .09, .02, INK)
			lens.rotation.x = PI / 2
	if team == 0: box(body, Vector3(0, 1.62, .43), Vector3(.36, .09, .07), Color("5a3a1e"))
	var board := box(body.get_node("ArmL"), Vector3(-.05, -.45, .2), Vector3(.36, .48, .04), CREAM)
	board.rotation.x = -.5
	return root

func make_ball() -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var ball_mesh := sphere(root, Vector3.ZERO, .48, CREAM)
	var shader := Shader.new()
	shader.code = """shader_type spatial;
varying vec3 local_normal;
void vertex() { local_normal = NORMAL; }
void fragment() {
 vec3 n = normalize(local_normal);
 float p = 0.0;
 float a = 0.525731;
 float b = 0.850651;
 for (int x = -1; x <= 1; x += 2) {
  for (int y = -1; y <= 1; y += 2) {
   p = max(p, dot(n, vec3(0.0, float(x)*a, float(y)*b)));
   p = max(p, dot(n, vec3(float(x)*a, float(y)*b, 0.0)));
   p = max(p, dot(n, vec3(float(x)*b, 0.0, float(y)*a)));
  }
 }
 ALBEDO = mix(vec3(0.95,0.91,0.78), vec3(0.055,0.1,0.14), smoothstep(0.94,0.95,p));
 ROUGHNESS = 0.75;
} """
	var mat := ShaderMaterial.new()
	mat.shader = shader
	ball_mesh.material_override = mat
	return root
