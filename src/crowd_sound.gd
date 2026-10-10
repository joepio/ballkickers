extends "res://addons/crowd_sound/crowd_sound.gd"
## Stadium crowd audio: the procedural crowd engine from joepio/godot-crowd-sound (from
## Growing Guns), voiced for football. Match events map onto its reactions;
## the beds play 2D because the stands surround the whole pitch.

func _init() -> void:
	# Football is quieter than a gunfight: the crowd sits under the kicks and the
	# goal cue (measured: idle bed about 20 dB, goal roar about 5 dB below them).
	murmur_db = -22.0
	cheer_db = -15.0
	claps_db = -17.0
	panic_db = -16.0
	reaction_db = -12.0
	chant_db = -16.0

func _ready() -> void:
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
