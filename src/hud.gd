extends Control
const INK = Color("172b3c")
const CREAM = Color("fff2d2")
const GOLD = Color("ffce56")
const ORANGE = Color("ff7547")
const BLUE = Color("58caff")
var game: Node
var font: Font = ThemeDB.fallback_font
var bold: Font = SystemFont.new()
var scale_factor := 1.0
var hit_rects: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	bold.font_names = PackedStringArray(["Arial Black", "DejaVu Sans", "Arial"])
	bold.font_weight = 900

func text(value: String, pos: Vector2, size: int, color: Color = CREAM, heavy: bool = false) -> void:
	draw_string(bold if heavy else font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func centered(value: String, y: float, size: int, color: Color = CREAM, heavy: bool = true) -> void:
	var f: Font = bold if heavy else font
	text(value, Vector2(800 - f.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2, y), size, color, heavy)

func panel(rect: Rect2, color: Color, radius: float = 14) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = int(radius)
	style.corner_radius_top_right = int(radius)
	style.corner_radius_bottom_left = int(radius)
	style.corner_radius_bottom_right = int(radius)
	draw_style_box(style, rect)

func button_icon(letter: String, pos: Vector2, color: Color, radius: float = 16) -> void:
	draw_circle(pos, radius, color)
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
	# One compact broadcast scoreboard; the pitch remains the hero.
	panel(Rect2(548, 28, 504, 82), INK)
	panel(Rect2(548, 28, 155, 82), ORANGE)
	panel(Rect2(897, 28, 155, 82), BLUE)
	text("EMBER", Vector2(564, 57), 17, INK, true)
	text(str(s.score[0]), Vector2(606, 94), 34, INK, true)
	text("TIDAL", Vector2(928, 57), 17, INK, true)
	text(str(s.score[1]), Vector2(953, 94), 34, INK, true)
	var seconds := int(ceil(s.clock))
	centered("GOLDEN GOAL" if s.overtime else "%d:%02d" % [seconds / 60, seconds % 60], 80, 24 if s.overtime else 34)
	for team in 2:
		var x: float = 551 if team == 0 else 899
		draw_rect(Rect2(x, 115, 151, 5), Color(0, 0, 0, .35))
		draw_rect(Rect2(x, 115, 151 * s.power[team] / 100, 5), ORANGE if team == 0 else BLUE)
		if s.power[team] >= 99: text("POWER SHOT READY", Vector2(x, 138), 12, GOLD, true)
	# World-anchored player indicators and stamina.
	for i in s.players.size():
		var p: Dictionary = s.players[i]
		if p.human < 0: continue
		var position: Vector2 = game.camera.unproject_position(Vector3(p.pos.x, 2.85, p.pos.y))
		position /= Vector2(size.x / 1600.0, size.y / 900.0)
		var color: Color = ORANGE if p.team == 0 else BLUE
		var width := 88.0 if game.dual_stick else 64.0
		panel(Rect2(position - Vector2(width / 2, 25), Vector2(width, 25)), INK, 8)
		var identity := "P%d %s" % [p.human / 2 + 1, "L" if p.human % 2 == 0 else "R"] if game.dual_stick else "P%d" % (p.human + 1)
		text(identity, position + Vector2(-31 if game.dual_stick else -13, -7), 17, color, true)
		draw_colored_polygon(PackedVector2Array([position + Vector2(-5, 1), position + Vector2(5, 1), position + Vector2(0, 7)]), color)
		if game.dual_stick:
			var facing: Vector2 = p.face
			var length: float = 2.2 + p.charge * 2.6
			var unit_pos := Vector3(p.pos.x, .12, p.pos.y)
			var arrow_start: Vector2 = game.camera.unproject_position(unit_pos + Vector3(facing.x, 0, facing.y) * .85)
			var arrow_end: Vector2 = game.camera.unproject_position(unit_pos + Vector3(facing.x, 0, facing.y) * length)
			var viewport_scale := Vector2(size.x / 1600.0, size.y / 900.0)
			arrow_start /= viewport_scale
			arrow_end /= viewport_scale
			var arrow_dir := (arrow_end - arrow_start).normalized()
			var normal := Vector2(-arrow_dir.y, arrow_dir.x)
			var arrow_color: Color = CREAM if p.human % 2 == 0 else GOLD
			draw_line(arrow_start, arrow_end - arrow_dir * 8, INK, 7, true)
			draw_line(arrow_start, arrow_end - arrow_dir * 8, arrow_color, 3, true)
			draw_colored_polygon(PackedVector2Array([arrow_end, arrow_end - arrow_dir * 13 + normal * 7, arrow_end - arrow_dir * 13 - normal * 7]), arrow_color)
		if p.stamina < .98:
			draw_rect(Rect2(position + Vector2(-24, -32), Vector2(48, 4)), INK)
			draw_rect(Rect2(position + Vector2(-24, -32), Vector2(48 * p.stamina, 4)), color)
		if p.charge > .05:
			draw_arc(position + Vector2(0, 44), 25, -PI / 2, -PI / 2 + TAU * minf(1, p.charge), 32, GOLD, 5, true)
		if game.party.managed and (not game.dual_stick or p.role == 0):
			var profile: Dictionary = p.get("profile", {})
			var center := Vector2(52 if p.team == 0 else 1360, 698 if game.dual_stick else 698 + (p.human / 2) * 65)
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
	# Readable short controls, no permanent instruction panel covering the arena.
	panel(Rect2(440, 841, 720, 40), Color(.06, .12, .17, .87), 20)
	if game.dual_stick:
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
	text("GOAL RUSH", Vector2(30, 870), 18, CREAM, true)
	if s.phase == "kickoff":
		centered("GET READY", 369, 21, GOLD)
		centered(str(maxi(1, int(ceil(s.phase_time)))), 479, 100)
	elif s.phase == "goal":
		var color: Color = ORANGE if s.events_team == 0 else BLUE
		panel(Rect2(507, 335, 586, 172), INK, 24)
		centered("GOOOAL!", 429, 73, color)
		centered("EMBER SCORES" if s.events_team == 0 else "TIDAL SCORES", 475, 22)
	elif s.phase == "result":
		panel(Rect2(460, 274, 680, 328), INK, 24)
		centered("FULL TIME", 330, 20, GOLD)
		centered("EMBER WINS!" if s.score[0] > s.score[1] else "TIDAL WINS!", 401, 55, ORANGE if s.score[0] > s.score[1] else BLUE)
		centered("%d  :  %d" % [s.score[0], s.score[1]], 474, 52)
		centered("START / ENTER  ·  REMATCH", 560, 21)
	if game.notice_time > 0:
		centered(game.notice, 177, 26, GOLD)
	if game.paused:
		draw_rect(Rect2(0, 0, 1600, 900), Color(.04, .09, .13, .64))
		panel(Rect2(530, 315, 540, 250), INK, 24)
		centered("TIME OUT", 408, 62)
		centered("START / ESC   RESUME", 475, 23, GOLD)
		centered("Y / TAB   BACK TO MENU", 521, 17)
	if game.show_stats:
		text("%d FPS  ·  %d DRAWS" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)], Vector2(25, 38), 17, INK)

func draw_menu() -> void:
	draw_rect(Rect2(0, 0, 615, 900), Color(.06, .12, .18, .96))
	draw_colored_polygon(PackedVector2Array([Vector2(615, 0), Vector2(715, 0), Vector2(615, 900)]), Color(.06, .12, .18, .96))
	text("2 v 2   /   PARTY FOOTBALL", Vector2(64, 82), 19, GOLD, true)
	text("GOAL", Vector2(55, 221), 112, CREAM, true)
	text("RUSH", Vector2(55, 326), 112, ORANGE, true)
	text("Small pitch. Big trouble.", Vector2(66, 375), 25, CREAM)
	var matchup: String = "MATCHUP     %s" % ("1v1" if game.humans == 2 else "SOLO vs AI") if game.dual_stick else "PLAYERS     %d" % game.humans
	var options: Array = ["KICK OFF", matchup, "CONTROLS    %s" % ("DUAL" if game.dual_stick else "CLASSIC"), "MATCH       %d MIN" % (game.match_seconds / 60), "SOUND       %s" % ("ON" if game.sound_enabled else "OFF")]
	for i in options.size():
		var rect := Rect2(61, 421 + i * 64, 475, 53)
		hit_rects.append(rect)
		var active: bool = i == game.menu_selection
		if active: panel(rect, GOLD if i == 0 else Color("294457"), 12)
		text(options[i], rect.position + Vector2(20, 35), 23 if i == 0 else 19, INK if active and i == 0 else CREAM, true)
		if active and i > 0: text("‹   ›", rect.position + Vector2(388, 35), 25, GOLD, true)
	if game.dual_stick:
		text("One controller. Two players. Your whole team.", Vector2(65, 775), 18, Color("a8c1c7"))
		text("Left stick + LB     /     Right stick + RB", Vector2(65, 811), 18, CREAM)
		text("Keyboard: WASD + Q    /    Arrows + CTRL", Vector2(65, 838), 16, CREAM)
	else:
		text("Controllers + keyboard  ·  Bots fill the teams", Vector2(65, 775), 18, Color("a8c1c7"))
		text("WASD move    J shoot / tackle    K pass", Vector2(65, 811), 16, CREAM)
		text("SHIFT sprint    SPACE switch    F11 fullscreen", Vector2(65, 838), 16, CREAM)
	text("A / ENTER  START     ↑ ↓  SELECT     ← →  CHANGE", Vector2(65, 880), 14, GOLD)
	panel(Rect2(1235, 33, 323, 40), INK, 20)
	text("SUNSET SOCIAL CLUB", Vector2(1262, 60), 18, CREAM, true)
