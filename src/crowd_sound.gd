extends "res://addons/crowd_sound/crowd_sound.gd"
## Stadium crowd audio: the procedural crowd engine from joepio/godot-crowd-sound (from
## Growing Guns), voiced for football. Match events map onto its reactions;
## the beds play 2D because the stands surround the whole pitch.

const CHATTER_DB := -33.0
var _chatter_rng := RandomNumberGenerator.new()
var _chatter_wait := 6.0
var _chatter_age := -1.0
var _chatter_length := 0.0

func _init() -> void:
	# Football is quieter than a gunfight: the crowd sits under the kicks and the
	# goal cue (measured: idle bed about 20 dB, goal roar about 5 dB below them).
	murmur_db = -80.0
	cheer_db = -15.0
	claps_db = -17.0
	panic_db = -16.0
	reaction_db = -12.0
	chant_db = -16.0

func _ready() -> void:
	_chatter_rng.randomize()
	super()
	set_bus(&"Match SFX")

func react(event: Dictionary) -> void:
	match String(event.type):
		"shot": excite(.08)
		"save": hit(.3, .9)
		"keeper_beaten", "hit": hit(.12, .3)
		"super": roar(.35)
		"goal": celebrate(3.5)
		"chaos": hit(.4, 1.0)
		"chaos_boom": excite(.25)
		"finish": celebrate(5.0)

# Gate only the synthetic conversational murmur. Cheers, chants and match
# reactions keep the shared engine's dynamics and ducking.
func _process(delta: float) -> void:
	if is_ready(): advance_chatter(delta)
	super(delta)

func advance_chatter(delta: float) -> void:
	if not active:
		_chatter_age = -1.0
		_chatter_wait = 6.0
		murmur_db = -80.0
		return
	if enthusiasm > 0.7 or fear > 0.4:
		_chatter_age = -1.0
		_chatter_wait = maxf(_chatter_wait, 12.0)
		murmur_db = -80.0
		return
	if _chatter_age < 0.0:
		_chatter_wait -= delta
		murmur_db = -80.0
		if _chatter_wait > 0.0: return
		_chatter_age = 0.0
		_chatter_length = _chatter_rng.randf_range(1.2, 2.4)
	_chatter_age += delta
	if _chatter_age >= _chatter_length:
		_chatter_age = -1.0
		_chatter_wait = _chatter_rng.randf_range(18.0, 32.0)
		murmur_db = -80.0
		return
	var envelope := minf(clampf(_chatter_age / 0.35, 0.0, 1.0),
		clampf((_chatter_length - _chatter_age) / 0.65, 0.0, 1.0))
	murmur_db = CHATTER_DB + linear_to_db(maxf(envelope, 0.001))
