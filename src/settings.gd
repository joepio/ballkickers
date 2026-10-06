extends RefCounted
## One declaration is shared by the host, assistant and gameplay validation.
const SPECS = [
  {
    "key": "seconds",
    "label": "Match length, s (next match)",
    "kind": "number",
    "default": 120,
    "min": 60,
    "max": 300
  },
  {
    "key": "matchup",
    "label": "Matchup (next match)",
    "kind": "choice",
    "default": "Auto",
    "options": [
      "Auto",
      "1v1",
      "2v2",
      "3v3"
    ]
  },
  {
    "key": "run_speed",
    "label": "Running speed % (live)",
    "kind": "number",
    "default": 100,
    "min": 50,
    "max": 150
  },
  {
    "key": "shot_power",
    "label": "Shot speed % (next shot)",
    "kind": "number",
    "default": 100,
    "min": 50,
    "max": 150
  },
  {
    "key": "ball_friction",
    "label": "Ball ground friction % (live)",
    "kind": "number",
    "default": 100,
    "min": 25,
    "max": 200
  },
  {
    "key": "keeper_speed",
    "label": "Goalkeeper movement % (live)",
    "kind": "number",
    "default": 100,
    "min": 50,
    "max": 150
  },
  {
    "key": "power_charge",
    "label": "Passive super charge % (live)",
    "kind": "number",
    "default": 100,
    "min": 0,
    "max": 300
  },
  {
    "key": "super_shots",
    "label": "Super shots (next shot)",
    "kind": "toggle",
    "default": true
  },
  {
    "key": "replays",
    "label": "Goal replays (next goal)",
    "kind": "toggle",
    "default": true
  },
  {
    "key": "chaos",
    "label": "Football chaos events (live)",
    "kind": "choice",
    "default": "Some",
    "options": [
      "Off",
      "Some",
      "Lots"
    ]
  }
]
const CHAOS_LEVELS = ["Off", "Some", "Lots"]
var values: Dictionary = {}

func _init() -> void:
	for spec in SPECS: values[spec.key] = spec.default

func change(key: String, value: Variant) -> bool:
	for spec in SPECS:
		if spec.key != key: continue
		match spec.kind:
			"number":
				if typeof(value) not in [TYPE_INT, TYPE_FLOAT]: return false
				if not is_finite(float(value)) or float(value) != floor(float(value)): return false
				if value < spec.min or value > spec.max: return false
				value = int(value)
			"choice":
				if not value is String or value not in spec.options: return false
			"toggle":
				if not value is bool: return false
		values[key] = value
		write_probe()
		return true
	return false

func apply_live(sim: RefCounted) -> void:
	for key in ["run_speed", "shot_power", "ball_friction", "keeper_speed", "power_charge"]:
		sim.set(key, values[key] / 100.0)
	sim.super_shots = values.super_shots
	sim.replays = values.replays
	sim.chaos.level = CHAOS_LEVELS.find(values.chaos)


func write_probe() -> void:
	# Opt-in observation for real-host integration tests. No player data.
	var path := OS.get_environment("GAMENIGHT_SETTINGS_PROBE")
	if path.is_empty(): return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"settings": values}))
