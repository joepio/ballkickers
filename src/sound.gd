extends Node
## Short natural effects, non-repeating variants and reserved match cues.
const CUES := {
	"kick": {"count": 4, "db": -12.0, "gap": 0.045, "pitch": 0.025},
	"pass": {"count": 3, "db": -16.0, "gap": 0.06, "pitch": 0.025},
	"hit": {"count": 4, "db": -19.0, "gap": 0.12, "pitch": 0.035},
	"save": {"count": 3, "db": -14.0, "gap": 0.09, "pitch": 0.02},
	"super": {"count": 2, "db": -12.0, "gap": 0.18, "pitch": 0.01},
	"goal": {"count": 1, "db": -9.0, "gap": 0.8, "pitch": 0.0},
	"whistle": {"count": 1, "db": -20.0, "gap": 0.6, "pitch": 0.0},
}
var players: Array[AudioStreamPlayer] = []
var banks: Dictionary = {}
var last_variant: Dictionary = {}
var last_time: Dictionary = {}
var rng := RandomNumberGenerator.new()
var clock := 0.0
var duck_until := 0.0

func _ready() -> void:
	rng.randomize()
	var bus := AudioServer.get_bus_index("Match SFX")
	if bus < 0:
		bus = AudioServer.bus_count
		AudioServer.add_bus()
		AudioServer.set_bus_name(bus, "Match SFX")
		AudioServer.set_bus_send(bus, "Master")
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -1.0
		AudioServer.add_bus_effect(bus, limiter)
	for name in CUES:
		banks[name] = []
		for index in int(CUES[name].count):
			var suffix := "" if index == 0 else "_%d" % (index + 1)
			var stream = load("res://assets/%s%s.wav" % [name, suffix])
			assert(stream != null, "Missing sound: " + name + suffix)
			banks[name].append(stream)
	for index in 10:
		var player := AudioStreamPlayer.new()
		player.bus = "Match SFX"
		add_child(player)
		players.append(player)

func _process(dt: float) -> void:
	clock += dt

func reset() -> void:
	for player in players: player.stop()
	last_time.clear()
	last_variant.clear()
	duck_until = 0.0

func choose_variant(name: String) -> int:
	var count: int = CUES[name].count
	var index := 0
	if count > 1:
		if last_variant.has(name):
			index = rng.randi_range(0, count - 2)
			if index >= int(last_variant[name]): index += 1
		else:
			index = rng.randi_range(0, count - 1)
	last_variant[name] = index
	return index

func play_cue(name: String) -> bool:
	if not banks.has(name): return false
	var cue: Dictionary = CUES[name]
	if clock - float(last_time.get(name, -100.0)) < float(cue.gap): return false
	# Goals and whistles each own a voice and cannot be lost behind contact noise.
	var player: AudioStreamPlayer
	if name == "goal": player = players[8]
	elif name == "whistle": player = players[9]
	else:
		for index in 8:
			if not players[index].playing:
				player = players[index]
				break
		# A power shot can replace a quiet impact when the contact pool is full.
		if player == null and name == "super":
			for index in 8:
				if str(players[index].get_meta("cue", "")) == "hit":
					player = players[index]
					break
	if player == null: return false
	last_time[name] = clock
	var variant := choose_variant(name)
	player.stream = banks[name][variant]
	player.set_meta("cue", name)
	var variation := rng.randf_range(-0.6, 0.6) if float(cue.pitch) > 0 else 0.0
	player.volume_db = float(cue.db) + variation
	player.set_meta("base_db", player.volume_db)
	player.pitch_scale = 1.0 + rng.randf_range(-float(cue.pitch), float(cue.pitch))
	if name in ["goal", "super"]:
		duck_until = maxf(duck_until, clock + (0.65 if name == "goal" else 0.18))
		for index in 8:
			if players[index].playing and str(players[index].get_meta("cue", "")) in ["hit", "pass"]:
				players[index].volume_db = float(players[index].get_meta("base_db", players[index].volume_db)) - 4.0
	elif clock < duck_until and name in ["hit", "pass"]:
		player.volume_db -= 4.0
	player.play()
	return true
