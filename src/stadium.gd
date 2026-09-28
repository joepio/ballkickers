extends Node3D
const ORANGE = Color("ff7547")
const BLUE = Color("58caff")
const INK = Color("182d41")
const CREAM = Color("fff2d2")
var arena_nodes: Array = []
var pitch_size := 1
var mats: Dictionary = {}
var crowd_mesh: MultiMeshInstance3D

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
	label.position = pos
	parent.add_child(label)
	return label

func build() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("91b7c5")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b4dbef")
	env.ambient_light_energy = .24
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -34, 0)
	sun.light_color = Color("ffe4b5")
	sun.light_energy = .72
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 100
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(sun)
	box(self, Vector3(0, -1.6, 0), Vector3(200, .6, 200), Color("86a7b5"))
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
		box(self, Vector3(x, 5.25, -18), Vector3(11, .45, 4.8), ORANGE if x < 0 else BLUE)
		for xx in [-4.5, 4.5]: rod(self, Vector3(x + xx, 0, -19), Vector3(x + xx, 5.1, -19), .15, INK)
	box(self, Vector3(0, 5.2, -19), Vector3(14.2, 3.6, .55), INK)
	box(self, Vector3(0, 7.1, -19), Vector3(14.5, .16, .65), Color("ffc94d"))
	label3(self, "GOAL RUSH", Vector3(0, 5.8, -18.68), 112, CREAM)
	label3(self, "NO FOULS. ALL FOOTBALL.", Vector3(0, 4.6, -18.68), 30, Color("ffc94d"))
	for x in [-15, -5, 5, 15]:
		label3(self, "PLAY LOUD" if abs(x) == 15 else "RUSH!", Vector3(x, .5, -12.1), 35, ORANGE if x < 0 else BLUE)
	build_crowd()
	# Tag the goal/net before batching so it can move without stretching.
	for child in get_children():
		if child is MeshInstance3D and absf(child.position.x) >= 20.9 and absf(child.position.x) <= 23.3 and absf(child.position.z) < 3.9:
			child.set_meta("goal", true)
	batch_static_geometry()
	for child in get_children():
		if child is GeometryInstance3D:
			arena_nodes.append({"node": child, "transform": child.transform})

func resize_pitch(teams: int) -> void:
	pitch_size = teams
	var factor: float = preload("res://src/match.gd").pitch_scale(teams)
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
	# Merge immutable stadium pieces by material. The net and stands no longer
	# need hundreds of individual draw submissions, including their shadow pass.
	var groups: Dictionary = {}
	var sources: Array = []
	for child in get_children():
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
		add_child(merged)
	for source in sources:
		remove_child(source)
		source.queue_free()

func build_crowd() -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	var mesh := CapsuleMesh.new()
	mesh.radius = .25
	mesh.height = .9
	mesh.radial_segments = 8
	mesh.rings = 2
	multi.mesh = mesh
	multi.instance_count = 400
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1
	mesh.material = m
	var random := RandomNumberGenerator.new()
	random.seed = 18
	for i in 400:
		var tier: int = i / 134
		var pos: Vector3
		if i % 134 < 62: pos = Vector3(-23 + (i % 134) * .75, 1.0 + tier * .65, -14.8 - tier * 1.25)
		else:
			var j: int = i % 134 - 62
			pos = Vector3((-1 if j < 36 else 1) * (26 + tier * 1.3), 1 + tier * .65, -13 + (j % 36) * .75)
		pos.y += random.randf_range(-.12, .12)
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * random.randf_range(.8, 1.2)), pos))
		multi.set_instance_color(i, [ORANGE, BLUE, CREAM, Color("ffc94d"), Color("ad85cc")][random.randi_range(0, 4)])
	crowd_mesh = MultiMeshInstance3D.new()
	crowd_mesh.multimesh = multi
	add_child(crowd_mesh)

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
	var headband := ring(body, Vector3(0, 1.82, 0), .44, .055, color)
	headband.name = "Headband"
	for side in [-1, 1]:
		var eye := sphere(body, Vector3(side * .15, 1.76, .411), .056, INK)
		eye.scale = Vector3(.9, 1.5, .6)
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
	var badge := label3(body, "GK" if keeper else str(index / 2 + 1), Vector3(0, 1.04, -.435), 32, CREAM)
	badge.rotation.y = PI
	var marker := ring(root, Vector3(0, .11, 0), .83, .085, color)
	marker.name = "Marker"
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
