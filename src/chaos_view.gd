extends Node3D
## Visuals for the match's chaos events. Reads the simulation, never changes it.
const INK = Color("182d41")
const CREAM = Color("fff2d2")
const SKIN = Color("f2b48f")
const SHIRTS = [Color("e84d6b"), Color("6ccf7a"), Color("ad85cc"), Color("ffc94d"), Color("4f8fe0")]
var stadium: Node3D
var game: Node
var built_serial := -1
var nodes: Array = []
var banner: Node3D
var flares: Array = []
var bonus_ball: Node3D
var bonus_shadow: MeshInstance3D
var drops: Array = []
var streaks: Array = []
var heads: Array = []
var spark_clock := 0.0
var time := 0.0

func _ready() -> void:
	for i in 150:
		var drop: MeshInstance3D = stadium.sphere(self, Vector3.ZERO, .13, Color("bdeeff"))
		drop.visible = false
		drops.append({"node": drop, "vel": Vector3.ZERO, "life": 0.0})
	for i in 28:
		var streak: MeshInstance3D = stadium.box(self, Vector3.ZERO, Vector3(.05, .05, 1.8), Color("e6f4f1"), .25)
		streak.visible = false
		streaks.append(streak)
	var wet := StandardMaterial3D.new()
	wet.albedo_color = Color(.62, .86, 1.0, .32)
	wet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wet.roughness = .1
	for i in 6:
		var head: MeshInstance3D = stadium.box(self, Vector3.ZERO, Vector3(.35, .3, .35), INK)
		head.visible = false
		var puddle: MeshInstance3D = stadium.sphere(head, Vector3(0, -.1, 0), 4.0, CREAM)
		puddle.material_override = wet
		puddle.name = "Puddle"
		heads.append(head)

func reset() -> void:
	for n in nodes: n.queue_free()
	nodes.clear()
	for f in flares: f.queue_free()
	flares.clear()
	if banner: banner.queue_free()
	banner = null
	if bonus_ball:
		bonus_ball.queue_free()
		bonus_shadow.queue_free()
	bonus_ball = null
	for d in drops:
		d.life = 0.0
		d.node.visible = false
	for s in streaks: s.visible = false
	for h in heads: h.visible = false
	built_serial = -1

func update(sim, dt: float) -> void:
	time += dt
	var chaos = sim.chaos
	if chaos.kind == "":
		if built_serial != -1: reset()
		return
	if built_serial != chaos.serial:
		reset()
		build(sim, chaos)
		built_serial = chaos.serial
	match chaos.kind:
		"streaker", "dog", "protest": update_actors(sim, chaos, dt)
		"fireworks": update_fireworks(chaos, dt)
		"second_ball": update_bonus_ball(chaos, dt)
		"sprinklers": update_sprinklers(sim, chaos, dt)
		"wind": update_wind(sim, chaos, dt)

func build(sim, chaos) -> void:
	match chaos.kind:
		"streaker":
			nodes.append(make_streaker())
			nodes.append(make_person(Color("ffd83a"), INK, SKIN, "steward"))
		"protest":
			for a in chaos.actors: nodes.append(make_person(SHIRTS[a.shirt], Color("3d5a80"), SKIN.darkened(float(a.shirt % 3) * .18), "protester"))
			make_banner(chaos)
		"dog": nodes.append(make_dog())
		"fireworks":
			for f in chaos.fireworks: flares.append(make_flare())
		"second_ball":
			bonus_ball = make_beach_ball()
			bonus_shadow = stadium.sphere(self, Vector3.ZERO, .46, Color("285e50"))
		"sprinklers":
			var spots := [Vector2(-.55, -.55), Vector2(0, -.6), Vector2(.55, -.55), Vector2(-.55, .55), Vector2(0, .6), Vector2(.55, .55)]
			for i in heads.size():
				heads[i].position = Vector3(spots[i].x * sim.half_x, .15, spots[i].y * sim.half_z)
				heads[i].visible = true
	for i in nodes.size():
		if i < chaos.actors.size():
			var a: Dictionary = chaos.actors[i]
			nodes[i].position = Vector3(a.pos.x, 0, a.pos.y)

func limb(body: Node3D, name: String, pos: Vector3) -> Node3D:
	var joint := Node3D.new()
	joint.name = name
	joint.position = pos
	body.add_child(joint)
	return joint

func make_person(shirt: Color, pants: Color, skin: Color, role: String) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.scale = Vector3.ONE * 1.12
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	stadium.capsule(body, Vector3(0, .92, 0), .41, 1.0, shirt)
	stadium.capsule(body, Vector3(0, .5, 0), .36, .5, pants)
	stadium.sphere(body, Vector3(0, 1.7, 0), .42, skin)
	for side in [-1, 1]:
		var eye: MeshInstance3D = stadium.sphere(body, Vector3(side * .14, 1.74, .37), .05, INK)
		eye.scale = Vector3(.9, 1.5, .6)
		var leg := limb(body, "LegL" if side < 0 else "LegR", Vector3(side * .22, .48, 0))
		stadium.capsule(leg, Vector3(0, -.2, 0), .15, .5, pants)
		var arm := limb(body, "ArmL" if side < 0 else "ArmR", Vector3(side * .45, 1.2, 0))
		stadium.capsule(arm, Vector3(side * .04, -.17, 0), .14, .44, shirt if role != "streaker" else skin)
		stadium.sphere(arm, Vector3(side * .08, -.36, 0), .17, skin)
	if role == "steward":
		stadium.ring(body, Vector3(0, 1.0, 0), .42, .05, CREAM)
		var cap: MeshInstance3D = stadium.sphere(body, Vector3(0, 1.98, .05), .36, INK)
		cap.scale = Vector3(1, .35, 1.15)
	root.set_meta("role", role)
	return root

func make_streaker() -> Node3D:
	var root := make_person(SKIN, SKIN, SKIN, "streaker")
	var body: Node3D = root.get_node("Body")
	# Broadcast-safe: a censor bar and a team scarf, nothing else.
	stadium.box(body, Vector3(0, .5, .38), Vector3(.75, .26, .08), Color("111111"))
	stadium.ring(body, Vector3(0, 1.32, 0), .3, .09, Color("ff7547"))
	var hair: MeshInstance3D = stadium.sphere(body, Vector3(0, 1.98, -.04), .3, Color("c9503a"))
	hair.scale = Vector3(1, .5, 1)
	return root

func make_dog() -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.set_meta("role", "dog")
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var fur := Color("c58a4a")
	var torso: MeshInstance3D = stadium.capsule(body, Vector3(0, .62, 0), .3, 1.25, fur)
	torso.rotation.x = PI / 2
	stadium.sphere(body, Vector3(0, .95, .62), .3, fur)
	stadium.sphere(body, Vector3(0, .88, .9), .15, fur.lightened(.25))
	stadium.sphere(body, Vector3(0, .93, 1.04), .07, INK)
	for side in [-1, 1]:
		stadium.sphere(body, Vector3(side * .12, 1.04, .84), .045, INK)
		var ear: MeshInstance3D = stadium.box(body, Vector3(side * .22, 1.12, .55), Vector3(.1, .26, .16), fur.darkened(.4))
		ear.rotation.z = side * .4
		for end in [-1, 1]:
			var leg := limb(body, "Leg%d%d" % [side + 1, end + 1], Vector3(side * .17, .48, end * .38))
			stadium.capsule(leg, Vector3(0, -.2, 0), .09, .45, fur.darkened(.15))
	stadium.ring(body, Vector3(0, .9, .48), .2, .04, Color("e84d6b"))
	var tail := limb(body, "Tail", Vector3(0, .8, -.62))
	stadium.rod(tail, Vector3.ZERO, Vector3(0, .35, -.25), .05, fur)
	root.scale = Vector3.ONE * 1.45
	return root

func make_banner(chaos) -> void:
	banner = Node3D.new()
	add_child(banner)
	var first: Dictionary = chaos.actors[0]
	var last: Dictionary = chaos.actors[-1]
	var width: float = last.pos.x - first.pos.x + 1.2
	for x in [-width * .5, width * .5]:
		stadium.rod(banner, Vector3(x, 0, 0), Vector3(x, 3.2, 0), .05, Color("8a5a3a"))
	stadium.box(banner, Vector3(0, 2.6, 0), Vector3(width, 1.0, .06), CREAM)
	stadium.box(banner, Vector3(0, 3.1, .01), Vector3(width, .1, .07), Color("e84d6b"))
	var label: Label3D = stadium.label3(banner, chaos.slogan, Vector3(0, 2.58, .05), 56, Color("c0263f"))
	label.font = game.hud.bold
	# Shrink long slogans so they always fit on the cloth.
	var text_width: float = label.font.get_string_size(chaos.slogan, HORIZONTAL_ALIGNMENT_LEFT, -1, 56).x
	label.pixel_size = minf(.015, (width - .5) / maxf(1.0, text_width))
	banner.set_meta("center", (first.pos.x + last.pos.x) * .5)

func update_actors(sim, chaos, dt: float) -> void:
	for i in nodes.size():
		var node: Node3D = nodes[i]
		var a: Dictionary = chaos.actors[i]
		node.visible = not a.gone and (a.delay <= 0 or a.kind != "steward")
		var target := Vector3(a.pos.x, 0, a.pos.y)
		node.position = node.position.lerp(target, 1 - exp(-dt * 30))
		var body: Node3D = node.get_node("Body")
		var speed: float = a.vel.length()
		if speed > .3: body.rotation.y = lerp_angle(body.rotation.y, atan2(a.face.x, a.face.y), 1 - exp(-dt * 16))
		var phase := time * (22.0 if a.kind == "dog" else 17.0) + i
		if a.kind == "dog":
			body.position.y = absf(sin(phase)) * .12 * minf(1, speed / 6)
			body.rotation.z = lerpf(body.rotation.z, 1.2 if a.stun > 0 else 0.0, 1 - exp(-dt * 12))
			for leg in ["Leg00", "Leg02", "Leg20", "Leg22"]:
				var swing := 1.0 if leg in ["Leg00", "Leg22"] else -1.0
				body.get_node(leg).rotation.x = sin(phase) * .8 * swing * minf(1, speed / 5)
			body.get_node("Tail").rotation.y = sin(time * 18) * .7
			continue
		var stride := sin(phase) * minf(.8, speed * .08)
		body.position.y = absf(sin(phase)) * minf(.14, speed * .016)
		body.get_node("LegL").rotation.x = stride
		body.get_node("LegR").rotation.x = -stride
		match a.kind:
			"streaker":
				# Arms up in triumph, waving to the crowd.
				body.get_node("ArmL").rotation = Vector3(0, 0, -2.7 + sin(time * 9) * .35)
				body.get_node("ArmR").rotation = Vector3(0, 0, 2.7 + sin(time * 9 + 1) * .35)
			"protester":
				body.position.y = absf(sin(time * 6 + i * .7)) * .1
				body.get_node("ArmL").rotation = Vector3(-2.5, 0, -.2)
				body.get_node("ArmR").rotation = Vector3(-2.5, 0, .2)
			_:
				body.get_node("ArmL").rotation = Vector3(-stride, 0, 0)
				body.get_node("ArmR").rotation = Vector3(stride, 0, 0)
	if banner:
		var a: Dictionary = chaos.actors[0]
		banner.position = banner.position.lerp(Vector3(banner.get_meta("center"), absf(sin(time * 6)) * .1, a.pos.y + .35), 1 - exp(-dt * 30))

func make_flare() -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var stick := Node3D.new()
	stick.name = "Stick"
	stick.scale = Vector3.ONE * 1.6
	root.add_child(stick)
	stadium.capsule(stick, Vector3(0, .25, 0), .13, .55, Color("d9343d"))
	stadium.ring(stick, Vector3(0, .3, 0), .13, .03, CREAM)
	var tip: MeshInstance3D = stadium.sphere(stick, Vector3(0, .58, 0), .14, Color("ffde59"))
	tip.material_override = stadium.material(Color("ffde59"), 2.5)
	# Ground ring telegraphs the blast radius so players can dodge.
	var warn: MeshInstance3D = stadium.ring(root, Vector3(0, .09, 0), 2.8, .07, Color("ff4a3d"))
	warn.material_override = stadium.material(Color("ff4a3d"), 1.2)
	warn.name = "Warn"
	return root

func update_fireworks(chaos, dt: float) -> void:
	spark_clock -= dt
	var spark := spark_clock <= 0
	if spark: spark_clock = .05
	for i in flares.size():
		var node: Node3D = flares[i]
		var f: Dictionary = chaos.fireworks[i]
		node.visible = f.state in ["air", "fizz"]
		if not node.visible: continue
		node.position = chaos.firework_position(f)
		var warn: Node3D = node.get_node("Warn")
		warn.visible = f.state == "fizz" and fmod(time * (4.0 + f.t * 6.0), 1.0) < .6
		warn.scale = Vector3.ONE * (1.0 if f.state == "fizz" else .01)
		var stick: Node3D = node.get_node("Stick")
		if f.state == "air":
			stick.rotation = Vector3(f.t * 11, 0, f.t * 7)
		else:
			stick.rotation = Vector3(.5, 0, .2)
		if spark: game.burst(node.position + Vector3(0, .9, 0), Color("ffde59") if randf() < .6 else Color("ff7547"), 2, 5)

func make_beach_ball() -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var mesh: MeshInstance3D = stadium.sphere(root, Vector3.ZERO, .55, CREAM)
	var shader := Shader.new()
	shader.code = """shader_type spatial;
varying vec3 local_normal;
void vertex() { local_normal = NORMAL; }
void fragment() {
 vec3 n = normalize(local_normal);
 float slice = floor((atan(n.z, n.x) / 6.28318 + 0.5) * 6.0);
 vec3 c = vec3(1.0, 0.36, 0.42);
 if (slice == 1.0) c = vec3(1.0, 0.82, 0.25);
 else if (slice == 2.0) c = vec3(0.35, 0.72, 1.0);
 else if (slice == 3.0) c = vec3(1.0, 0.96, 0.88);
 else if (slice == 4.0) c = vec3(0.45, 0.85, 0.5);
 else if (slice == 5.0) c = vec3(0.75, 0.55, 0.95);
 if (abs(n.y) > 0.9) c = vec3(1.0, 0.96, 0.88);
 ALBEDO = c;
 ROUGHNESS = 0.45;
}"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mesh.material_override = mat
	return root

func update_bonus_ball(chaos, dt: float) -> void:
	if chaos.extra.is_empty(): return
	var pos: Vector3 = chaos.extra.pos
	var vel: Vector3 = chaos.extra.vel
	bonus_ball.position = bonus_ball.position.lerp(pos, 1 - exp(-dt * 36))
	bonus_ball.rotate_x(vel.z * dt * 1.4)
	bonus_ball.rotate_z(-vel.x * dt * 1.4)
	bonus_shadow.position = Vector3(pos.x, .12, pos.z)
	var s := clampf(1 - pos.y * .09, .3, 1)
	bonus_shadow.scale = Vector3(s, .015, s)
	# Blink during the last seconds before stewards confiscate it.
	bonus_ball.visible = chaos.extra.life > 2.5 or fmod(time * 6, 1.0) < .6

func update_sprinklers(sim, chaos, dt: float) -> void:
	var strength: float = clampf((1.0 - chaos.grip) / .78, 0, 1)
	for i in drops.size():
		var d: Dictionary = drops[i]
		d.life -= dt
		if d.life <= 0 and strength > .05:
			var head: Node3D = heads[i % heads.size()]
			var angle := time * 2.2 + i * 1.7
			d.node.position = head.position + Vector3(0, .3, 0)
			d.vel = Vector3(cos(angle) * 5.0, 6.5 + randf() * 2.5, sin(angle) * 5.0) * (0.6 + .4 * strength)
			d.life = 1.0
		d.vel.y -= 16 * dt
		d.node.position += d.vel * dt
		d.node.visible = d.life > 0 and d.node.position.y > .05
	for h in heads:
		h.position.y = lerpf(-.2, .15, strength)
		h.get_node("Puddle").scale = Vector3(strength, .004, strength) / maxf(.01, h.scale.x)

func update_wind(sim, chaos, dt: float) -> void:
	var dir: Vector2 = chaos.wind.normalized()
	var gust := clampf(minf(chaos.age, 9.0 - chaos.age), 0, 1)
	for i in streaks.size():
		var s: MeshInstance3D = streaks[i]
		if not s.visible or absf(s.position.x) > sim.half_x + 6 or absf(s.position.z) > sim.half_z + 6:
			# Respawn upwind, across the full width of the pitch.
			var across := Vector2(-dir.y, dir.x) * randf_range(-sim.half_x, sim.half_x)
			var start: Vector2 = -dir * (sim.half_x + 4) * randf_range(.6, 1.0) + across
			s.position = Vector3(start.x, randf_range(.6, 4.0), start.y)
			s.look_at_from_position(s.position, s.position + Vector3(dir.x, 0, dir.y))
			s.visible = gust > .1
		s.position += Vector3(dir.x, 0, dir.y) * 26 * dt
		s.scale = Vector3(1, 1, maxf(.05, gust))
