extends Node3D
## 520 supporters built like small athletes: shirts, heads, eyes, arms and hats,
## drawn as a handful of MultiMeshes. One shader animates them all on the GPU:
## idle fidgeting, jumping and arm waving for their team, slumping after a goal
## against, a Mexican wave, and a few fans with signs and flags.
const ORANGE = Color("ff7547")
const BLUE = Color("58caff")
const CREAM = Color("fff2d2")
const INK = Color("182d41")
const NEUTRAL = [Color("ffc94d"), Color("ad85cc"), Color("6ccf7a"), Color("e84d6b"), CREAM, Color("4f8fe0")]
const SKINS = [Color("ffe0bd"), Color("f2c29b"), Color("d9a074"), Color("b47a50"), Color("8a5634"), Color("5e3a22")]
const HAIR = [Color("2b1d14"), Color("5a3a1e"), Color("c9503a"), Color("e8c35a"), Color("9a9a9a"), Color("1b1b2a")]
const SIZE := 1.35
const SIGNS = ["HI MUM!", "TANGERINES 4 LIFE", "BLUEBERRY TILL I DIE", "MARRY ME BUBS", "I SKIPPED WORK", "MORE GOALS PLS", "ZIG IS MY HERO", "WHO IS THE REF?"]
const SHADER = """shader_type spatial;
uniform float cheer_0 = 0.0;
uniform float cheer_1 = 0.0;
uniform float gloom_0 = 0.0;
uniform float gloom_1 = 0.0;
uniform float hype = 0.0;
uniform float wave_u = -1.0;
void vertex() {
	float u = INSTANCE_CUSTOM.r;
	float team = INSTANCE_CUSTOM.g;
	float energy = INSTANCE_CUSTOM.b;
	float side = INSTANCE_CUSTOM.a * 2.0 - 1.0;
	float phase = fract(u * 91.7) * 6.2831;
	float mine = team < 0.25 ? cheer_0 : (team > 0.75 ? cheer_1 : max(cheer_0, cheer_1) * 0.6);
	float gloom = team < 0.25 ? gloom_0 : (team > 0.75 ? gloom_1 : 0.0);
	float wave = wave_u < -0.5 ? 0.0 : exp(-pow((u - wave_u) * 16.0, 2.0));
	float up = clamp(max(mine, hype * (0.35 + energy * 0.65)), 0.0, 1.0);
	float lift = 0.035 * sin(TIME * (1.3 + energy * 2.2) + phase)
		+ up * abs(sin(TIME * (6.0 + energy * 4.0) + phase)) * 0.62
		+ wave * 0.4 - gloom * 0.14;
	if (abs(side) > 0.5) {
		float raise = max(max(up, wave), gloom * 0.95);
		float a = side * (mix(0.2, 2.7, raise) + up * 0.35 * sin(TIME * 13.0 + phase));
		VERTEX.xy = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * VERTEX.xy;
	}
	VERTEX.y += lift / max(0.01, length(MODEL_MATRIX[1].xyz));
}
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.9;
}"""
var material := ShaderMaterial.new()
var seats: Array = []
var layers: Dictionary = {}
var props: Array = []
var flag_shader := Shader.new()
var cheer := [0.0, 0.0]
var gloom := [0.0, 0.0]
var hype := 0.0
var wave_u := -1.0
var wave_clock := 14.0
var time := 0.0

func _ready() -> void:
	var shader := Shader.new()
	shader.code = SHADER
	material.shader = shader
	var random := RandomNumberGenerator.new()
	random.seed = 18
	for i in 400:
		var tier: int = i / 134
		var j: int = i % 134
		var pos: Vector3
		var facing := 0.0
		var ring := 0.0
		if j < 62:
			pos = Vector3(-23 + j * .75, 1.0 + tier * .65, -14.8 - tier * 1.25)
			ring = .3 + j / 61.0 * .4
		else:
			var k: int = j - 62
			var side := -1 if k < 36 else 1
			pos = Vector3(side * (26 + tier * 1.3), 1 + tier * .65, -13 + (k % 36) * .75)
			facing = side * -PI / 2
			# The ring runs from the front-left corner, along the back, to the front-right.
			ring = (.3 - (k % 36) / 35.0 * .3) if side < 0 else (.7 + (k % 36) / 35.0 * .3)
		add_seat(random, pos, facing, ring)
	# The near stand, seen from behind on the main camera and face-on in close-ups.
	# The wave carries on along it, from the right corner back to the left.
	for tier in 2:
		for j in 60:
			var pos := Vector3(22.1 - j * .75, 1.0 + tier * .65, 16.1 + tier * 1.25)
			add_seat(random, pos, PI, 1.0 + j / 59.0 * .3)
	var body := capsule(.27, .78, Vector3.ZERO)
	var head := combine(sphere(.25, Vector3(0, .56, 0)))
	var eyes := combine([sphere(.05, Vector3(-.09, .6, .24)), sphere(.05, Vector3(.09, .6, .24))])
	var arm := capsule(.085, .46, Vector3(0, -.17, 0))
	var beanie := combine(sphere(.24, Vector3(0, .7, 0), Vector3(1.05, .7, 1.05)))
	var cap := combine([sphere(.25, Vector3(0, .7, 0), Vector3(1.04, .5, 1.04)), box(Vector3(.36, .04, .26), Vector3(0, .67, .25))])
	var hair := combine(sphere(.27, Vector3(0, .64, -.05), Vector3(1.05, .78, 1.0)))
	layers["body"] = layer(body, seats.size())
	layers["head"] = layer(head, seats.size())
	layers["eyes"] = layer(eyes, seats.size())
	layers["arms"] = layer(arm, seats.size() * 2)
	var hats := [0, 0, 0]
	for s in seats: if s.hat >= 0: hats[s.hat] += 1
	layers["beanie"] = layer(beanie, hats[0])
	layers["cap"] = layer(cap, hats[1])
	layers["hair"] = layer(hair, hats[2])
	build_props(random)
	layout(1.0)

func add_seat(random: RandomNumberGenerator, pos: Vector3, facing: float, ring: float) -> void:
	pos.y += random.randf_range(-.08, .08)
	var team := 0.5
	var lean: float = pos.x / 23.0
	if random.randf() < clampf(.5 + absf(lean) * .45, .5, .92): team = 0.0 if lean < 0 else 1.0
	var shirt: Color
	if team == 0.0: shirt = ORANGE.lerp([CREAM, Color("ffc94d"), INK][random.randi_range(0, 2)], random.randf_range(0, .3))
	elif team == 1.0: shirt = BLUE.lerp([CREAM, Color("4f8fe0"), INK][random.randi_range(0, 2)], random.randf_range(0, .3))
	else: shirt = NEUTRAL[random.randi_range(0, NEUTRAL.size() - 1)]
	var hat := -1
	var roll := random.randf()
	if roll < .28: hat = 0
	elif roll < .42: hat = 1
	elif roll < .62: hat = 2
	seats.append({"pos": pos, "facing": facing, "ring": ring, "team": team, "energy": random.randf(),
		"scale": random.randf_range(.86, 1.1), "shirt": shirt, "skin": SKINS[random.randi_range(0, SKINS.size() - 1)],
		"hat": hat, "hat_color": shirt.darkened(.3) if random.randf() < .6 else HAIR[random.randi_range(0, HAIR.size() - 1)]})

func capsule(radius: float, height: float, offset: Vector3) -> Mesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 2
	return combine([[mesh, Transform3D(Basis.IDENTITY, offset)]])

func sphere(radius: float, offset: Vector3, stretch: Vector3 = Vector3.ONE) -> Array:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = 10
	mesh.rings = 5
	return [mesh, Transform3D(Basis.IDENTITY.scaled(stretch), offset)]

func box(size: Vector3, offset: Vector3) -> Array:
	var mesh := BoxMesh.new()
	mesh.size = size
	return [mesh, Transform3D(Basis.IDENTITY, offset)]

func combine(parts) -> Mesh:
	if parts is Array and parts.size() == 2 and parts[0] is Mesh: parts = [parts]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in parts: surface.append_from(part[0], 0, part[1])
	return surface.commit()

func layer(mesh: Mesh, count: int) -> MultiMesh:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.use_custom_data = true
	multi.mesh = mesh
	multi.instance_count = count
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.material_override = material
	add_child(node)
	return multi

func layout(factor: float) -> void:
	# Seats spread with the stands when the pitch grows; people keep their size.
	var counts := {"beanie": 0, "cap": 0, "hair": 0}
	for i in seats.size():
		var s: Dictionary = seats[i]
		var pos: Vector3 = s.pos
		pos.x *= factor
		pos.z *= factor
		# Fans are drawn a size up from the athletes so the stands read from the
		# broadcast camera; they stand a little taller to keep their feet on the tier.
		var size: float = s.scale * SIZE
		pos.y += .39 * (size - 1.0)
		var basis := Basis(Vector3.UP, s.facing).scaled(Vector3.ONE * size)
		var person := Transform3D(basis, pos)
		var data := Color(s.ring, s.team, s.energy, .5)
		for key in ["body", "head", "eyes"]:
			var multi: MultiMesh = layers[key]
			multi.set_instance_transform(i, person)
			multi.set_instance_custom_data(i, data)
		layers.body.set_instance_color(i, s.shirt)
		layers.head.set_instance_color(i, s.skin)
		layers.eyes.set_instance_color(i, INK)
		for side in 2:
			var shoulder := person * Transform3D(Basis.IDENTITY, Vector3(-.3 if side == 0 else .3, .26, 0))
			layers.arms.set_instance_transform(i * 2 + side, shoulder)
			layers.arms.set_instance_custom_data(i * 2 + side, Color(s.ring, s.team, s.energy, float(side)))
			layers.arms.set_instance_color(i * 2 + side, s.shirt)
		if s.hat >= 0:
			var key: String = ["beanie", "cap", "hair"][s.hat]
			var multi: MultiMesh = layers[key]
			multi.set_instance_transform(counts[key], person)
			multi.set_instance_custom_data(counts[key], data)
			multi.set_instance_color(counts[key], s.hat_color)
			counts[key] += 1
	for prop in props:
		var node: Node3D = prop.node
		var seat: Dictionary = seats[prop.seat]
		node.position = Vector3(seat.pos.x * factor, seat.pos.y + .39 * (SIZE - 1.0), seat.pos.z * factor)
		node.scale = Vector3.ONE * SIZE

const FLAG_CODE = """shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color;
uniform float wave = 0.0;
uniform float strength = 1.0;
varying float shade;
void vertex() {
	// d: 0 at the pole, 1 at the free end. The pole edge stays put.
	float d = clamp(abs(VERTEX.z) / 1.7, 0.0, 1.0);
	float ripple = sin(wave - d * 7.0) * 0.16 + sin(wave * 1.7 - d * 11.0 + VERTEX.y * 2.0) * 0.05;
	VERTEX.x += ripple * d * strength;
	VERTEX.y -= d * d * 0.12 * (1.6 - strength);
	shade = cos(wave - d * 7.0) * d;
}
void fragment() {
	ALBEDO = tint.rgb * (0.86 + 0.14 * shade);
	ROUGHNESS = 0.85;
}"""

func build_props(random: RandomNumberGenerator) -> void:
	flag_shader.code = FLAG_CODE
	# A few superfans: hand-written signs on the back stand and big flags on the sides.
	preload("res://src/stadium.gd").fonts()
	var label_font: Font = preload("res://src/stadium.gd").display_font
	var picks := [8, 21, 35, 49, 75, 112, 150, 189]
	for n in picks.size():
		var seat: int = picks[n] if n < 4 else 134 + picks[n] % 62
		var node := Node3D.new()
		add_child(node)
		var board := Node3D.new()
		board.name = "Board"
		node.add_child(board)
		var mesh := MeshInstance3D.new()
		var quad := BoxMesh.new()
		quad.size = Vector3(2.6, .95, .05)
		mesh.mesh = quad
		var mat := StandardMaterial3D.new()
		mat.albedo_color = [CREAM, Color("ffc94d"), CREAM, Color("ffd6e0")][n % 4]
		mesh.material_override = mat
		mesh.position = Vector3(0, 1.35, .15)
		board.add_child(mesh)
		var label := Label3D.new()
		label.text = SIGNS[n]
		label.font = label_font
		label.font_size = 40
		label.pixel_size = minf(.016, 2.4 / maxf(1.0, label_font.get_string_size(SIGNS[n], HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x))
		label.modulate = [INK, Color("c0263f"), ORANGE.darkened(.2), BLUE.darkened(.35)][n % 4]
		label.outline_size = 0
		label.position = Vector3(0, 1.35, .18)
		board.add_child(label)
		props.append({"node": node, "seat": seat, "kind": "sign", "phase": random.randf() * TAU})
	for n in 4:
		var side := -1 if n < 2 else 1
		var seat: int = 62 + (0 if side < 0 else 36) + 8 + (n % 2) * 18 + 134
		var node := Node3D.new()
		add_child(node)
		var pole := Node3D.new()
		pole.name = "Pole"
		node.add_child(pole)
		var stick := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = .04
		cylinder.bottom_radius = .04
		cylinder.height = 3.2
		stick.mesh = cylinder
		stick.position = Vector3(0, 1.6, 0)
		var dark := StandardMaterial3D.new()
		dark.albedo_color = INK
		stick.material_override = dark
		pole.add_child(stick)
		# The cloth hangs from the pole along its edge and ripples in a shader:
		# a wave runs from the pole to the free end, growing as it goes.
		var cloth := MeshInstance3D.new()
		var grid := SurfaceTool.new()
		grid.begin(Mesh.PRIMITIVE_TRIANGLES)
		var columns := 14
		for c in columns:
			for r in 2:
				var z0 := -side * 1.7 * c / columns
				var z1 := -side * 1.7 * (c + 1) / columns
				var y0 := 2.05 + r * .55
				var y1 := y0 + .55
				for v in [Vector3(0, y0, z0), Vector3(0, y1, z0), Vector3(0, y1, z1), Vector3(0, y0, z0), Vector3(0, y1, z1), Vector3(0, y0, z1)]:
					grid.set_normal(Vector3.RIGHT)
					grid.add_vertex(v)
		cloth.mesh = grid.commit()
		var color := ShaderMaterial.new()
		color.shader = flag_shader
		color.set_shader_parameter("tint", ORANGE if side < 0 else BLUE)
		cloth.material_override = color
		cloth.name = "Cloth"
		pole.add_child(cloth)
		props.append({"node": node, "seat": seat, "kind": "flag", "phase": random.randf() * TAU, "team": 0 if side < 0 else 1})

func event(type: String, team: int = -1) -> void:
	match type:
		"goal":
			cheer[team] = 1.0
			gloom[1 - team] = 1.0
			wave_u = -1.0
		"shot", "save", "near": hype = maxf(hype, .45)
		"super": hype = maxf(hype, .8)
		"chaos": hype = maxf(hype, .9)
		"finish":
			cheer[team] = 1.0
			gloom[1 - team] = 1.0

func update(dt: float, quiet: bool) -> void:
	time += dt
	for team in 2:
		cheer[team] = move_toward(cheer[team], 0.0, dt / 5.0)
		gloom[team] = move_toward(gloom[team], 0.0, dt / 4.0)
	hype = move_toward(hype, 0.0, dt / 1.6)
	# Mexican wave when the game is calm: it rolls around the ring every so often.
	if wave_u >= 0:
		wave_u += dt / 4.5
		if wave_u > 1.45: wave_u = -1.0
	elif quiet:
		wave_clock -= dt
		if wave_clock <= 0:
			wave_clock = randf_range(18, 32)
			wave_u = -.15
	material.set_shader_parameter("cheer_0", smoothstep(0.0, .25, cheer[0]))
	material.set_shader_parameter("cheer_1", smoothstep(0.0, .25, cheer[1]))
	material.set_shader_parameter("gloom_0", smoothstep(0.0, .3, gloom[0]))
	material.set_shader_parameter("gloom_1", smoothstep(0.0, .3, gloom[1]))
	material.set_shader_parameter("hype", hype)
	material.set_shader_parameter("wave_u", wave_u if wave_u >= -.5 else -1.0)
	for prop in props:
		var seat: Dictionary = seats[prop.seat]
		var excite: float = maxf(hype, maxf(cheer[0], cheer[1]) if seat.team == .5 else cheer[int(seat.team)])
		if prop.kind == "sign":
			var board: Node3D = prop.node.get_node("Board")
			board.position.y = .15 * sin(time * 2 + prop.phase) + excite * absf(sin(time * 8 + prop.phase)) * .45
			board.rotation.z = .08 * sin(time * 1.3 + prop.phase) + excite * .15 * sin(time * 9 + prop.phase)
		else:
			var pole: Node3D = prop.node.get_node("Pole")
			# Advance the swing angle instead of multiplying the clock by a changing
			# speed: that made flags shudder wildly while a cheer faded.
			var speed: float = 1.6 + cheer[prop.team] * 2.4
			prop.phase += dt * speed
			pole.rotation.x = sin(prop.phase) * (.25 + cheer[prop.team] * .3)
			var cloth_material: ShaderMaterial = prop.node.get_node("Pole/Cloth").material_override
			cloth_material.set_shader_parameter("wave", prop.phase * 2.6)
			cloth_material.set_shader_parameter("strength", .7 + cheer[prop.team] * .6)
