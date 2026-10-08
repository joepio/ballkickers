extends Node
## Ballkickers' view of the GameNight SDK (the `GameNight` autoload): local
## seats in party order, profiles by player id, and one `command` per host
## event so main.gd handles the lifecycle in one place. The SDK owns the
## connection, sessions, settings replay and window manners (GameNightScreen).
signal command(message: Dictionary)
var managed: bool:
	get: return GameNight.launched_by_daemon
	set(value): GameNight.launched_by_daemon = value
var session: String:
	get: return GameNight.session
var profiles: Dictionary = {}
var frames: Dictionary = {}

func _ready() -> void:
	GameNight.declare_settings(preload("res://src/settings.gd").SPECS)
	GameNight.prepared.connect(func(id: String, seats: Array, players: Array) -> void:
		update_profiles(players)
		frames.clear()
		command.emit({"type": "prepare", "session": id, "seats": seats, "players": players}))
	GameNight.started.connect(func(id: String) -> void: command.emit({"type": "start", "session": id}))
	GameNight.paused.connect(func(id: String) -> void: command.emit({"type": "pause", "session": id}))
	GameNight.resumed.connect(func(id: String) -> void: command.emit({"type": "resume", "session": id}))
	GameNight.disposed.connect(func(id: String) -> void: command.emit({"type": "dispose", "session": id}))
	GameNight.roster_changed.connect(func(_seats: Array, players: Array, _presence: Array) -> void:
		update_profiles(players)
		command.emit({"type": "party_updated"}))
	GameNight.controllers_changed.connect(func(controllers: Array) -> void:
		frames.clear()
		for record in controllers: frames[str(record.get("controller", ""))] = record
		command.emit({"type": "controller_frame"}))
	GameNight.setting_changed.connect(func(key: String, value: Variant) -> void:
		command.emit({"type": "setting_changed", "key": key, "value": value}))

## Feed one host message through the SDK, as if it came over the socket.
func handle(message: Dictionary) -> void:
	GameNight._handle(message)

## Protocol messages the SDK has no helper for (participation, activity).
func send(message: Dictionary) -> void:
	if managed: GameNight._send(message)

func update_profiles(players: Array) -> void:
	for p in players: profiles[str(p.get("id", ""))] = p

func human_seats() -> Array:
	var result: Array = []
	for seat in GameNight.party.get("seats", []):
		if seat.get("occupant", {}).get("kind", "") == "local": result.append(seat)
	return result.slice(0, 6)

func read_seat(index: int) -> Dictionary:
	var humans := human_seats()
	if index >= humans.size(): return {}
	return GameNight.frame_for_seat(int(humans[index].get("index", -1)))
