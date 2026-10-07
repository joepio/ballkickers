extends Control
const INK = Color("172b3c")
const CREAM = Color("fff2d2")
const GOLD = Color("ffce56")
const ORANGE = Color("ff7547")
const BLUE = Color("58caff")
var game: Node
var font: Font
var bold: Font
var scale_factor := 1.0
var hit_rects: Array = []
var control_icons: Array[Texture2D] = []
var fade := 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	preload("res://src/stadium.gd").fonts()
	font = preload("res://src/stadium.gd").round_font
	bold = preload("res://src/stadium.gd").display_font
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Analytic coverage at 4x display resolution: transparent background and
	# smooth inner/outer edges, including the straight edge of the half disc.
	for variant in 4:
		var pixels := Image.create(96, 96, false, Image.FORMAT_RGBA8)
		for y in 96:
			for x in 96:
				var point := Vector2(x + .5, y + .5) - Vector2(48, 48)
				var distance := point.length()
				var outer := 1.0 - smoothstep(41.0, 43.0, distance)
				var inner := 1.0 - smoothstep(35.0, 37.0, distance)
				var fill := 0.0
				if variant == 0: fill = inner * (1.0 - smoothstep(-1, 1, point.x))
				elif variant == 1: fill = inner * smoothstep(-1, 1, point.x)
				elif variant == 3: fill = 1.0 - smoothstep(22.0, 24.0, distance)
				var alpha := fill if variant == 3 else maxf(outer - inner, fill * .78)
				pixels.set_pixel(x, y, Color(1, 1, 1, alpha))
		control_icons.append(ImageTexture.create_from_image(pixels))

func identity_color(p: Dictionary) -> Color:
	return [CREAM, GOLD, Color("d6b5ff")][int(p.human / 2) % 3]

func text(value: String, pos: Vector2, size: int, color: Color = CREAM, heavy: bool = false) -> void:
	draw_string(bold if heavy else font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color, color.a * fade))

func centered(value: String, y: float, size: int, color: Color = CREAM, heavy: bool = true) -> void:
	var f: Font = bold if heavy else font
	text(value, Vector2(800 - f.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2, y), size, color, heavy)

## Big centred text with a dark rim, readable on the pitch without a panel.
func loud(value: String, y: float, size: int, color: Color) -> void:
	var pos := Vector2(800 - bold.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2, y)
	draw_string_outline(bold, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(6, size / 7), Color(INK, .92))
	draw_string(bold, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func panel(rect: Rect2, color: Color, radius: float = 14) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color, color.a * fade)
	style.corner_radius_top_left = int(radius)
	style.corner_radius_top_right = int(radius)
	style.corner_radius_bottom_left = int(radius)
	style.corner_radius_bottom_right = int(radius)
	draw_style_box(style, rect)

func button_icon(letter: String, pos: Vector2, color: Color, radius: float = 16) -> void:
	draw_circle(pos, radius, Color(color, color.a * fade))
	var width := bold.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, int(radius * 1.15)).x
	text(letter, pos + Vector2(-width / 2, radius * .42), int(radius * 1.15), INK, true)

func _draw() -> void:
	if game == null or game.sim == null: return
	scale_factor = size.x / 1600.0
	draw_set_transform(Vector2.ZERO, 0, Vector2(scale_factor, size.y / 900))
	hit_rects.clear()
	if game.menu:
		draw_menu()
		return
	var s = game.sim
	# Score, clock and power meters are on the stadium screen; the HUD stays clear.
	# World-anchored player indicators and stamina.
	for i in s.players.size():
		var p: Dictionary = s.players[i]
		if p.human < 0 or game.replay_showing(): continue
		var position: Vector2 = game.camera.unproject_position(Vector3(p.pos.x, 2.85, p.pos.y))
		position /= Vector2(size.x / 1600.0, size.y / 900.0)
		var color: Color = ORANGE if p.team == 0 else BLUE
		var icon := position + Vector2(0, -12)
		var icon_rect := Rect2(icon - Vector2(13, 13), Vector2(26, 26))
		draw_texture_rect(control_icons[p.human % 2 if s.dual_control else 2], icon_rect, false, color)
		if not s.dual_control: draw_texture_rect(control_icons[3], icon_rect, false, identity_color(p))
		if s.arcade_control:
			var facing: Vector2 = p.face
			var length: float = 1.35 + p.charge * 3.5
			var unit_pos := Vector3(p.pos.x, .12, p.pos.y)
			var arrow_start: Vector2 = game.camera.unproject_position(unit_pos + Vector3(facing.x, 0, facing.y) * .85)
			var arrow_end: Vector2 = game.camera.unproject_position(unit_pos + Vector3(facing.x, 0, facing.y) * length)
			var viewport_scale := Vector2(size.x / 1600.0, size.y / 900.0)
			arrow_start /= viewport_scale
			arrow_end /= viewport_scale
			var arrow_dir := (arrow_end - arrow_start).normalized()
			var normal := Vector2(-arrow_dir.y, arrow_dir.x)
			var arrow_color: Color = color
			if p.charge > .08:
				draw_line(arrow_start, arrow_end - arrow_dir * 8, INK, 5, true)
				draw_line(arrow_start, arrow_end - arrow_dir * 8, arrow_color, 3, true)
			draw_colored_polygon(PackedVector2Array([arrow_end, arrow_end - arrow_dir * 13 + normal * 7, arrow_end - arrow_dir * 13 - normal * 7]), arrow_color)
		if p.stamina < .98:
			draw_rect(Rect2(position + Vector2(-24, -32), Vector2(48, 4)), INK)
			draw_rect(Rect2(position + Vector2(-24, -32), Vector2(48 * p.stamina, 4)), color)
		if game.party.managed and (not s.dual_control or p.human % 2 == 0):
			var profile: Dictionary = p.get("profile", {})
			var center := Vector2(52 if p.team == 0 else 1360, 650 + (p.human / 4 if s.dual_control else p.human / 2) * 57)
			panel(Rect2(center - Vector2(28, 25), Vector2(220, 51)), INK, 12)
			draw_circle(center, 18, Color.from_string(str(profile.get("skin_color", "#fff2d2")), CREAM))
			var avatar: String = str(profile.get("avatar", ""))
			if game.profile_textures.has(avatar):
				var texture: Texture2D = game.profile_textures[avatar]
				var factor := 18.0 / (12.0 if texture.get_width() == 48 else texture.get_width() * .35)
				var origin := Vector2(24, 28) if texture.get_width() == 48 else texture.get_size() / 2
				draw_texture_rect(texture, Rect2(center - origin * factor, texture.get_size() * factor), false)
			else:
				draw_circle(center + Vector2(-5, -1), 2, INK)
				draw_circle(center + Vector2(5, -1), 2, INK)
			text(str(p.name).left(16), center + Vector2(31, 7), 17, color, true)
			if not s.dual_control: draw_texture_rect(control_icons[3], Rect2(center + Vector2(162, -12), Vector2(24, 24)), false, identity_color(p))
	# Controls are a reminder for the opening seconds, then they get out of the way.
	var hint := clampf((9.0 - s.elapsed) / 1.5, 0, 1)
	if hint > 0 and not game.replay_showing():
		draw_hints(hint)
	if game.replay_showing(): pass
	elif s.phase == "kickoff":
		loud("GET READY", 380, 22, GOLD)
		loud(str(maxi(1, int(ceil(s.phase_time)))), 470, 84, CREAM)
	elif s.phase == "goal":
		var color: Color = ORANGE if s.events_team == 0 else BLUE
		loud("GOOOAL!", 430, 96, color)
		loud("TANGERINES" if s.events_team == 0 else "BLUEBERRIES", 474, 24, CREAM)
	elif s.phase == "result":
		panel(Rect2(460, 274, 680, 328), INK, 24)
		centered("FULL TIME", 330, 20, GOLD)
		centered("TANGERINES WIN!" if s.score[0] > s.score[1] else "BLUEBERRIES WIN!", 401, 55, ORANGE if s.score[0] > s.score[1] else BLUE)
		centered("%d  :  %d" % [s.score[0], s.score[1]], 474, 52)
		centered("START / ENTER  ·  REMATCH", 560, 21)
	if game.notice_time > 0:
		var notice_width: float = bold.get_string_size(game.notice, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x + 48
		panel(Rect2(800 - notice_width / 2, 148, notice_width, 40), Color(.06, .12, .17, .87), 20)
		centered(game.notice, 177, 26, GOLD)
	if s.chaos.active() and s.phase == "play":
		var label: String = s.chaos.title().trim_suffix("!")
		var width: float = bold.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 44
		panel(Rect2(800 - width / 2, 794, width, 34), Color("c0263f"), 17)
		draw_circle(Vector2(800 - width / 2 + 18, 811), 5, GOLD if fmod(game.run_time, .8) < .4 else CREAM)
		text(label, Vector2(800 - width / 2 + 32, 817), 15, CREAM, true)
	if game.paused:
		draw_rect(Rect2(0, 0, 1600, 900), Color(.04, .09, .13, .64))
		panel(Rect2(530, 315, 540, 250), INK, 24)
		centered("TIME OUT", 408, 62)
		centered("START / ESC   RESUME", 475, 23, GOLD)
		centered("Y / TAB   BACK TO MENU", 521, 17)
	draw_replay(s)
	if game.show_stats:
		text("%d FPS  ·  %d DRAWS" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)], Vector2(25, 38), 17, INK)

func draw_hints(alpha: float) -> void:
	fade = alpha
	panel(Rect2(440, 846, 720, 36), Color(.06, .12, .17, .55), 18)
	if game.team_size > 1:
		text("L STICK  MOVE / AIM", Vector2(467, 867), 16, CREAM, true)
		text("LB / RB  SHOOT / TACKLE", Vector2(808, 867), 16, CREAM, true)
	elif game.dual_stick:
		text("L STICK + LB", Vector2(467, 867), 16, CREAM, true)
		text("MOVE · SHOOT / TACKLE", Vector2(632, 867), 14)
		text("R STICK + RB", Vector2(975, 867), 16, GOLD, true)
	else:
		button_icon("X", Vector2(467, 861), BLUE, 12)
		text("SHOOT / TACKLE", Vector2(486, 867), 15)
		button_icon("A", Vector2(660, 861), Color("b9e76a"), 12)
		text("PASS", Vector2(679, 867), 15)
		text("HOLD X: CHARGE", Vector2(755, 867), 14)
		text("RT  SPRINT     LB  SWITCH", Vector2(895, 867), 15)
	fade = 1.0

func draw_menu() -> void:
	draw_rect(Rect2(0, 0, 615, 900), Color(.06, .12, .18, .96))
	draw_colored_polygon(PackedVector2Array([Vector2(615, 0), Vector2(715, 0), Vector2(615, 900)]), Color(.06, .12, .18, .96))
	text("PARTY FOOTBALL", Vector2(64, 82), 19, GOLD, true)
	text("BALL", Vector2(55, 221), 112, CREAM, true)
	text("KICKERS", Vector2(55, 326), 79, ORANGE, true)
	text("More friends. Bigger trouble.", Vector2(66, 375), 25, CREAM)
	var matchup: String = "MATCHUP     %s" % ("%dv%d" % [game.team_size, game.team_size] if game.humans > 1 else "SOLO vs AI") if game.dual_stick else "PLAYERS     %d" % game.humans
	var options: Array = ["KICK OFF", matchup, "CONTROLS    %s" % ("SINGLE" if game.team_size > 1 else ("DUAL" if game.dual_stick else "CLASSIC")), "MATCH       %d MIN" % (game.match_seconds / 60), "SOUND       %s" % ("ON" if game.sound_enabled else "OFF"), "CHAOS       %s" % ["OFF", "SOME", "LOTS"][game.chaos_level]]
	for i in options.size():
		var rect := Rect2(61, 412 + i * 57, 475, 50)
		hit_rects.append(rect)
		var active: bool = i == game.menu_selection
		if active: panel(rect, GOLD if i == 0 else Color("294457"), 12)
		var parts: PackedStringArray = options[i].split("  ", false)
		text(parts[0].strip_edges(), rect.position + Vector2(20, 33), 23 if i == 0 else 19, INK if active and i == 0 else CREAM, true)
		if parts.size() > 1: text(parts[-1].strip_edges(), rect.position + Vector2(190, 33), 19, GOLD if active else CREAM, true)
		if active and i > 0: text("‹   ›", rect.position + Vector2(388, 33), 25, GOLD, true)
	if game.team_size > 1:
		text("One controller. One unit. Bots fill empty places.", Vector2(65, 775), 18, Color("a8c1c7"))
		text("Left stick move / aim     LB or RB shoot / tackle", Vector2(65, 811), 17, CREAM)
		text("Keyboard: WASD + Q", Vector2(65, 838), 16, CREAM)
	elif game.dual_stick:
		text("Two units per controller. Bots fill empty places.", Vector2(65, 775), 18, Color("a8c1c7"))
		text("Left stick + LB     /     Right stick + RB", Vector2(65, 811), 18, CREAM)
		text("Keyboard: WASD + Q    /    Arrows + CTRL", Vector2(65, 838), 16, CREAM)
	else:
		text("Controllers + keyboard  ·  Bots fill the teams", Vector2(65, 775), 18, Color("a8c1c7"))
		text("WASD move    J shoot / tackle    K pass", Vector2(65, 811), 16, CREAM)
		text("SHIFT sprint    SPACE switch    F11 fullscreen", Vector2(65, 838), 16, CREAM)
	text("A / ENTER  START     ↑ ↓  SELECT     ← →  CHANGE", Vector2(65, 880), 14, GOLD)

func draw_replay(s) -> void:
	var r = game.replay
	if not r.active: return
	var color: Color = ORANGE if r.team == 0 else BLUE
	if game.replay_showing():
		var scale := Vector2(size.x / 1600.0, size.y / 900.0)
		# Telestrator: the ball's recent path, chalked over the pitch.
		var path := PackedVector2Array()
		var view: Camera3D = get_viewport().get_camera_3d()
		if r.stage in ["play", "hold"]:
			for point in r.ball_path(50):
				var world := Vector3(point.x, .15, point.z)
				if not view.is_position_behind(world): path.append(view.unproject_position(world) / scale)
		if path.size() > 1:
			draw_polyline(path, Color(INK, .5), 11, true)
			draw_polyline(path, GOLD, 6, true)
		draw_rect(Rect2(0, 0, 1600, 900), Color(1, .93, .78, .05))
		# Broadcast bug.
		var tilt := Transform2D(-.06, Vector2(46, 46))
		draw_set_transform_matrix(Transform2D.IDENTITY.scaled(Vector2(scale_factor, size.y / 900)) * tilt)
		panel(Rect2(0, 0, 228, 58), INK, 14)
		draw_circle(Vector2(30, 29), 9, Color("ff4a5c") if fmod(game.run_time, 1.0) < .6 else Color("7a2a33"))
		text("REPLAY", Vector2(50, 43), 34, CREAM, true)
		if r.slow_motion():
			panel(Rect2(14, 62, 200, 32), GOLD, 10)
			text("SUPER SLO-MO", Vector2(30, 86), 20, INK, true)
		draw_set_transform(Vector2.ZERO, 0, Vector2(scale_factor, size.y / 900))
		# Lower third: who, what the commentator thinks, and the speed gun.
		if r.cursor > 25:
			var slide := clampf((r.cursor - 25) / 18.0, 0, 1)
			var x := lerpf(-760, 40, ease(slide, .3))
			panel(Rect2(x, 690, 720, 104), INK, 18)
			panel(Rect2(x, 690, 18, 104), color, 9)
			text("GOAL  ·  " + r.scorer, Vector2(x + 38, 732), 32, color, true)
			text(r.caption, Vector2(x + 38, 772), 21, CREAM)
			panel(Rect2(x + 760, 690, 190, 104), color, 18)
			text("SHOT SPEED", Vector2(x + 782, 724), 15, INK, true)
			text("%d KM/H" % r.speed_kmh, Vector2(x + 782, 770), 36, INK, true)
		panel(Rect2(1340, 30, 230, 44), Color(INK, .85), 22)
		text("A / START  SKIP  ▸", Vector2(1364, 59), 18, GOLD, true)
	var w: float = r.wipe()
	if w >= 0:
		# Classic replay sting: team stripes sweep across and swap the picture.
		var offset := lerpf(-2400, 2200, w)
		var stripes := [[ORANGE, -260], [CREAM, -120], [BLUE, 0], [INK, 120]]
		for stripe in stripes:
			var o: float = offset + stripe[1]
			var c: Color = stripe[0]
			if stripe[0] == ORANGE and r.team == 1: c = BLUE
			elif stripe[0] == BLUE and r.team == 1: c = ORANGE
			var width := 2000.0 if stripe[0] == INK else 140.0
			draw_colored_polygon(PackedVector2Array([Vector2(o, 0), Vector2(o + width, 0), Vector2(o + width - 300, 900), Vector2(o - 300, 900)]), c)
		var cx := offset + 760
		text("BALL", Vector2(cx - 210, 470), 110, CREAM, true)
		text("KICKERS", Vector2(cx + 30, 470), 110, color, true)
		text("ACTION REPLAY", Vector2(cx - 120, 540), 34, GOLD, true)
