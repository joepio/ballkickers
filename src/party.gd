extends Node
## Small Godot adapter for the authoritative GameNight controller stream.
signal command(message: Dictionary)
var managed := false
var session := ""
var seats: Array = []
var profiles: Dictionary = {}
var frames: Dictionary = {}
var frame_time := 0
var socket := WebSocketPeer.new()
var hello_sent := false
var connected_at := 0

func _ready() -> void:
	managed = OS.get_environment("GAMENIGHT") == "1"
	if not managed: return
	print("GameNight: managed launch")
	DisplayServer.window_set_position(Vector2i(-30000, -30000))
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	Engine.max_fps = 30
	var address := OS.get_environment("GAMENIGHT_ADDR")
	if address.is_empty(): address = "127.0.0.1:7912"
	if not address.begins_with("ws"): address = "ws://" + address
	connected_at = Time.get_ticks_msec()
	var error := socket.connect_to_url(address)
	if error != OK: push_error("GameNight: connection initialization failed (%s)" % error)

func _process(_dt: float) -> void:
	if not managed: return
	socket.poll()
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		if not hello_sent:
			hello_sent = true
			var game := OS.get_environment("GAMENIGHT_GAME_ID")
			send({"type": "hello", "role": "game", "game": game if game != "" else "goal-rush", "token": OS.get_environment("GAMENIGHT_TOKEN")})
		while socket.get_available_packet_count() > 0:
			var message = JSON.parse_string(socket.get_packet().get_string_from_utf8())
			if message is Dictionary: handle(message)
	elif hello_sent or Time.get_ticks_msec() - connected_at > 10000:
		get_tree().quit()

func send(message: Dictionary) -> void:
	if managed and socket.get_ready_state() == WebSocketPeer.STATE_OPEN: socket.send_text(JSON.stringify(message))

func handle(message: Dictionary) -> void:
	if message.get("type", "") in ["start", "pause", "resume", "dispose", "party_updated"] and message.get("session", "") != session: return
	match message.get("type", ""):
		"prepare":
			session = message.get("session", "")
			seats = message.get("seats", [])
			update_profiles(message.get("players", []))
			frames.clear()
		"party_updated":
			update_profiles(message.get("players", []))
		"controller_frame":
			frames.clear()
			frame_time = Time.get_ticks_msec()
			for record in message.get("controllers", []): frames[str(record.get("controller", ""))] = record
		"welcome":
			send({"type": "declare_settings", "settings": [{"key": "seconds", "label": "Match length", "kind": "number", "default": 120, "min": 60, "max": 300}]})
	command.emit(message)

func update_profiles(players: Array) -> void:
	for p in players: profiles[str(p.get("id", ""))] = p

func human_seats() -> Array:
	var result: Array = []
	for seat in seats:
		if seat.get("occupant", {}).get("kind", "") == "local": result.append(seat)
	return result.slice(0, 4)

func read_seat(index: int) -> Dictionary:
	var humans := human_seats()
	if index >= humans.size() or Time.get_ticks_msec() - frame_time > 250: return {}
	return frames.get(str(humans[index].get("controller", "")), {})

func show_game() -> void:
	Engine.max_fps = 120
	if DisplayServer.get_name() == "headless": return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	var screen := DisplayServer.window_get_current_screen()
	DisplayServer.window_set_size(DisplayServer.screen_get_size(screen) + Vector2i(0, 1))
	DisplayServer.window_set_position(DisplayServer.screen_get_position(screen))
	DisplayServer.window_move_to_foreground()

func hide_game() -> void:
	Engine.max_fps = 20
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_position(Vector2i(-30000, -30000))
