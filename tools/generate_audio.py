"""Build the football sound bank from CC0 recordings and original tonal accents.
Requires Python + NumPy + ffmpeg. Source files and licenses: tools/audio_sources.
Run from any working directory. Output is deterministic mono PCM16, 48 kHz.
"""
import hashlib
import json
import math
import subprocess
import wave
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "tools/audio_sources"
SR = 48000

def decode(name):
    raw = subprocess.check_output(["ffmpeg", "-v", "error", "-i", str(SOURCES/name),
                                   "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"])
    return np.frombuffer(raw, dtype="<f4").astype(np.float64)

def lowpass(x, hz):
    # One-pole, twice cascaded for a gentle top-end roll-off.
    a = 1-math.exp(-2*math.pi*hz/SR)
    y = x.copy()
    for _ in range(2):
        previous = 0.
        for i in range(len(y)):
            previous += a*(y[i]-previous)
            y[i] = previous
    return y

def highpass(x, hz=55):
    a = math.exp(-2*math.pi*hz/SR)
    y = np.zeros_like(x)
    previous = 0.
    previous_input = 0.
    for i, value in enumerate(x):
        previous = a*(previous + value-previous_input)
        y[i] = previous
        previous_input = value
    return y

def edges(x, attack=.0015, release=.025):
    y = x.copy()
    for count, ending in ((min(int(attack*SR), len(y)//2), False),
                          (min(int(release*SR), len(y)//2), True)):
        if count > 1:
            shape = .5-.5*np.cos(np.linspace(0, math.pi, count))
            if ending:
                y[-count:] *= shape[::-1]
            else:
                y[:count] *= shape
    return y

def crop(x, start, seconds):
    return x[round(start*SR):round((start+seconds)*SR)].copy()

def trim(x, threshold=.025):
    indices = np.flatnonzero(np.abs(x) > max(abs(x)) * threshold)
    return x[max(0,indices[0]-96):min(len(x),indices[-1]+int(.025*SR))] if len(indices) else x

def peak(x, target=.72):
    maximum = float(max(abs(x)))
    return x*(target/maximum) if maximum else x

def pad(x, count):
    return np.pad(x, (0,max(0,count-len(x))))[:count]

def resonant_thump(seconds=.24, f=105):
    t = np.arange(round(seconds*SR))/SR
    # Integrated downward frequency envelope, no phase discontinuities.
    phase = 2*math.pi*(f*t + 30*.017*(1-np.exp(-t/.017)))
    return edges(np.sin(phase)*np.exp(-t/.045), .002, .03)

def mallet(f, seconds=.8):
    t = np.arange(round(seconds*SR))/SR
    return edges((np.sin(2*math.pi*f*t)*np.exp(-t/.22)
                  + .22*np.sin(2*math.pi*f*2*t)*np.exp(-t/.09)
                  + .05*np.sin(2*math.pi*f*3*t)*np.exp(-t/.045)), .008, .1)

def celebration():
    # Overlapping separately enveloped notes resolve to a warm major chord.
    result = np.zeros(round(1.5*SR))
    for start, f, gain in [(0,523.25,.28),(.115,659.25,.25),(.23,783.99,.25),
                           (.38,1046.5,.21),(.38,523.25,.10),(.38,659.25,.07)]:
        note = mallet(f)
        index = round(start*SR)
        result[index:index+len(note)] += note*gain
    # Small diffuse tail. No white-noise "crowd".
    dry = result.copy()
    for delay, gain in ((.061,.11),(.103,.07),(.167,.045)):
        offset=round(delay*SR)
        result[offset:] += dry[:-offset]*gain
    return edges(result, .006, .22)

def build():
    balls = decode("ball-kicks-1044.mp3")
    whistle = decode("whistle-1017.mp3")
    kicks = []
    for start in (.283,2.393,5.193,7.933,10.673):
        real = edges(highpass(lowpass(trim(crop(balls,start,.31)),6500)))
        count=max(len(real),round(.24*SR))
        kick=pad(peak(real,.65),count)+pad(resonant_thump(),count)*.11
        kicks.append(edges(kick))
    bank = {"kick":kicks[:4],
            "pass":[edges(lowpass(k,3500)) for k in kicks[1:4]],
            "hit":[], "save":[]}
    for i in range(4):
        body=highpass(lowpass(trim(decode(f"impactSoft_medium_{i:03}.ogg")),2400),65)
        turf=highpass(lowpass(trim(decode(f"footstep_grass_{i:03}.ogg")),4200),250)
        count=round(.27*SR)
        # Soft contact with a small turf layer; no sharp broadband noise burst.
        impact=pad(peak(body,.6),count)+pad(peak(turf,.6),count)*.13
        bank["hit"].append(edges(impact,.003,.07))
    for i in range(3):
        real=lowpass(kicks[i],4700)
        glove=lowpass(trim(decode(f"impactSoft_medium_{i+1:03}.ogg")),1700)
        count=round(.3*SR)
        bank["save"].append(edges(pad(peak(real,.6),count)*.65+pad(peak(glove,.6),count)*.55,.002,.07))
    bank["whistle"]=[edges(lowpass(highpass(crop(whistle,2.255,.325),450),6000),.01,.055)]
    bank["super"]=[]
    for i in range(2):
        count=round(.62*SR); t=np.arange(count)/SR
        pulse=resonant_thump(.4,72+i*4)
        airy=highpass(lowpass(np.random.default_rng(810+i).normal(0,1,count),1400),250)
        airy*=np.exp(-t/.095)*(1-np.exp(-t/.005))
        shimmer=mallet(523.25 if i==0 else 659.25,.5)*.04
        bank["super"].append(edges(pad(kicks[i],count)*.8+pad(pulse,count)*.28+airy*.10+pad(shimmer,count),.002,.08))
    bank["goal"]=[celebration()]
    manifest={}
    for name, variants in bank.items():
        for i, x in enumerate(variants):
            filename=f"{name}{'_'+str(i+1) if i else ''}.wav"
            x=peak(edges(highpass(x,35),.001,.02),.5 if name=="whistle" else .72)
            # No clipping; reserve headroom before playback gain and limiting.
            assert np.isfinite(x).all() and max(abs(x)) < 1
            raw=np.rint(x*32767).astype("<i2")
            with wave.open(str(ROOT/"assets"/filename),"wb") as f:
                f.setparams((1,2,SR,0,"NONE","not compressed")); f.writeframes(raw.tobytes())
            manifest[filename]={"seconds":round(len(x)/SR,4),
                "peak_dbfs":round(20*math.log10(max(abs(x))),2),
                "rms_dbfs":round(20*math.log10(np.sqrt(np.mean(x*x))),2),
                "sha256":hashlib.sha256((ROOT/"assets"/filename).read_bytes()).hexdigest()}
    (SOURCES/"render-manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
    print(f"Rendered {len(manifest)} effects at {SR} Hz; zero endpoints, no clipping.")
    return manifest

if __name__=="__main__":
    build()
