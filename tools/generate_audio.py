"""Original, deterministic synth Foley. No external audio assets."""
import math
import random
import struct
import wave
from pathlib import Path

DEST = Path(__file__).resolve().parents[1] / "assets"
SR = 24000

def write(name, duration, sample):
    rng = random.Random(48)
    with wave.open(str(DEST / f"{name}.wav"), "wb") as output:
        output.setparams((1, 2, SR, 0, "NONE", "not compressed"))
        output.writeframes(b"".join(struct.pack("<h", round(max(-1, min(1, sample(n/SR, rng))) * 26000)) for n in range(int(duration*SR))))

write("kick", .22, lambda t,r: (math.sin(2*math.pi*(145*t-190*t*t))*.8 + r.uniform(-1,1)*.25)*math.exp(-t*23))
write("pass", .12, lambda t,r: (math.sin(2*math.pi*220*t)*.65 + r.uniform(-1,1)*.12)*math.exp(-t*35))
write("hit", .27, lambda t,r: (r.uniform(-1,1)*.65 + math.sin(2*math.pi*70*t)*.45)*math.exp(-t*18))
write("whistle", .36, lambda t,r: math.sin(2*math.pi*1800*t + .3*math.sin(2*math.pi*50*t))*.35*min(1,t*50)*min(1,(.36-t)*15))
write("super", .65, lambda t,r: (math.sin(2*math.pi*(90*t+500*t*t))*.5 + r.uniform(-1,1)*.35)*math.exp(-t*5))

def goal(t, rng):
    notes = [523.25, 659.25, 783.99, 1046.5]
    beat = min(3, int(t/.17))
    local = t-beat*.17
    melody = sum(math.sin(2*math.pi*notes[beat]*harmonic*t)/harmonic for harmonic in [1,2,3])*.27*math.exp(-local*3)
    crowd = rng.uniform(-1,1)*.15*math.exp(-t*2)
    return (melody+crowd)*min(1,t*80)*min(1,(1.2-t)*8)
write("goal", 1.2, goal)
print("Generated six original Foley clips")
