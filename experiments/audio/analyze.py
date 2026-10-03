"""Ballkickers audio experiment. Standard library only; never changes game assets."""
import argparse
import array
import csv
import hashlib
import html
import json
import math
import random
import struct
import subprocess
import sys
import wave
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
NAMES = ("kick", "pass", "hit", "super", "goal", "whistle")
SR = 24000
GAIN = {n: -16 if n == "goal" else -13 for n in NAMES}
MAPPING = {"shot": "kick", "pass": "pass", "super": "super", "hit": "hit",
           "save": "hit", "keeper_beaten": "hit", "goal": "goal", "finish": "goal",
           "whistle": "whistle", "overtime": "whistle", "start": "whistle"}

def db(value):
    return round(20 * math.log10(value), 2) if value > 0 else None

def read(path):
    with wave.open(str(path), "rb") as w:
        if (w.getnchannels(), w.getsampwidth(), w.getframerate()) != (1, 2, SR):
            raise ValueError(f"{path}: expected mono 16-bit PCM at {SR} Hz")
        raw = array.array("h", w.readframes(w.getnframes()))
    if sys.byteorder != "little":
        raw.byteswap()
    if not raw:
        raise ValueError(f"{path}: empty audio")
    return [v / 32768 for v in raw]

def write(path, samples):
    path.parent.mkdir(parents=True, exist_ok=True)
    raw = array.array("h", (round(max(-1, min(32767/32768, x)) * 32768) for x in samples))
    if sys.byteorder != "little":
        raw.byteswap()
    with wave.open(str(path), "wb") as w:
        w.setparams((1, 2, SR, 0, "NONE", "not compressed"))
        w.writeframes(raw.tobytes())

def metrics(x):
    peak = max(map(abs, x))
    rms = math.sqrt(sum(v*v for v in x) / len(x))
    active = [i for i, v in enumerate(x) if abs(v) >= 0.001]  # -60 dBFS
    jumps = [abs(b-a) for a, b in zip(x, x[1:])]
    max_i = max(range(len(jumps)), key=jumps.__getitem__) if jumps else 0
    # Full-clip RMS is an energy measure, not perceived loudness / LUFS.
    return {"duration_ms": round(len(x)/SR*1000, 2), "peak_dbfs": db(peak),
            "rms_dbfs": db(rms), "crest_db": db(peak/rms) if rms else None,
            "dc_offset": round(sum(x)/len(x), 6),
            "samples_at_full_scale": sum(abs(v) >= 32767/32768 for v in x),
            "start_step_dbfs": db(abs(x[0])), "end_step_dbfs": db(abs(x[-1])),
            "largest_sample_step": round(max(jumps, default=0), 6),
            "largest_step_time_ms": round((max_i+1)/SR*1000, 3),
            "leading_below_minus60_ms": round(active[0]/SR*1000, 3) if active else len(x)/SR*1000,
            "trailing_below_minus60_ms": round((len(x)-1-active[-1])/SR*1000, 3) if active else len(x)/SR*1000}

def fade(x):
    result = x.copy()
    count = min(round(0.003 * SR), len(x)//2)
    for i in range(count):
        gain = .5 - .5 * math.cos(math.pi * i / (count-1))
        result[i] *= gain
        result[-1-i] *= gain
    return result

def degrade(x):
    # Deliberately damaged control: hard clipping, coarse quantization and sample hold.
    held = [round(max(-1, min(1, v*6))*15)/15 for v in x[::6]]
    return [held[i//6] for i in range(len(x))]

def scale(x, gain):
    return [v*gain for v in x]

def match_rms(x, reference):
    a = math.sqrt(sum(v*v for v in x)/len(x))
    b = math.sqrt(sum(v*v for v in reference)/len(reference))
    return scale(x, b/a) if a else x.copy()

def montage(x, repeats=8):
    return (x + [0.0]*round(.25*SR))*repeats

def pitched(x, factor):
    result = []
    for i in range(math.ceil(len(x)/factor)):
        position = i*factor
        index = int(position)
        if index >= len(x):
            break
        other = x[index+1] if index+1 < len(x) else 0
        result.append(x[index] + (other-x[index])*(position-index))
    return result

def mix(events, assets, seed_value, seconds):
    rng = random.Random(seed_value)
    mixed = [0.0]*round((seconds+2)*SR)
    busy = []
    dropped = 0
    voices = 0
    for event in events:
        name = event["sound"]
        if MAPPING.get(event["type"]) != name:
            raise ValueError("Event/sound mapping changed")
        start = event["time"]
        busy = [end for end in busy if end > start]
        if len(busy) >= 10:
            dropped += 1
            continue
        factor = rng.uniform(.94, 1.06) if name in ("kick", "hit", "pass") else 1
        clip = pitched(assets[name], factor)
        busy.append(start + len(clip)/SR)
        voices = max(voices, len(busy))
        offset = round(start*SR)
        gain = 10**(GAIN[name]/20)
        for i, value in enumerate(clip):
            if offset+i < len(mixed):
                mixed[offset+i] += value*gain
    return mixed, {"dropped_events": dropped, "max_voices": voices}

def save_json(path, value):
    path.write_text(json.dumps(value, indent=2, allow_nan=False) + "\n", encoding="utf-8")

def build(out):
    out.mkdir(parents=True, exist_ok=True)
    source = (ROOT/"src/main.gd").read_text()
    for expected in ('for i in 10:', 'player.volume_db = -13 if name != "goal" else -16',
                     'randf_range(.94, 1.06)'):
        if expected not in source:
            raise RuntimeError("Playback implementation changed; update the experiment before interpreting results")
    assets = {name: read(ROOT/"assets"/f"{name}.wav") for name in NAMES}
    try:
        commit = subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "HEAD"], text=True).strip()
    except (OSError, subprocess.CalledProcessError):
        commit = "unavailable"
    report = {"commit": commit, "sample_rate": SR, "assets": {}, "runs": [],
              "ai_status": "not run; use score_audiobox.py",
              "limits": ["RMS is not perceived loudness.", "Threshold flags are diagnostic, not a taste score.",
                         "Reconstructed bot mixes exclude visual context, hit-stop and Godot/device processing.",
                         "Python pitch RNG/interpolation differs from Godot; these are repeatable approximations."]}
    scored = []
    pairs = []
    rng = random.Random(20261002)
    for name, x in assets.items():
        stats = metrics(x)
        flags = []
        for edge in ("start", "end"):
            level = stats[f"{edge}_step_dbfs"]
            if level is not None and level > -50:
                flags.append(f"{edge} boundary exceeds -50 dBFS: audition for clicks")
        if stats["samples_at_full_scale"]:
            flags.append("full-scale samples")
        stats.update({"sha256": hashlib.sha256((ROOT/"assets"/f"{name}.wav").read_bytes()).hexdigest(),
                      "playback_gain_db": GAIN[name], "generator_clamp_samples": sum(abs(v) == 26000/32768 for v in x), "flags": flags})
        report["assets"][name] = stats
        native = scale(x, 10**(GAIN[name]/20))
        write(out/"native"/f"{name}.wav", native)
        conditions = {"original": x, "edge_fade": fade(x), "damaged_control": degrade(x)}
        # Match RMS, then apply a common peak-safe gain to all three conditions.
        conditions = {key: match_rms(value, x) for key, value in conditions.items()}
        common_gain = min(1, .8 / max(abs(v) for values in conditions.values() for v in values))
        for condition, values in conditions.items():
            clip = scale(values, common_gain)
            for presentation, audio in (("single", clip), ("repeated", montage(clip))):
                rel = f"comparison/{name}-{condition}-{presentation}.wav"
                write(out/rel, audio)
                scored.append({"id": f"{name}/{condition}/{presentation}", "path": rel,
                               "sound": name, "condition": condition, "presentation": presentation})
        for condition in ("edge_fade", "damaged_control", "original"):
            order = ["original", condition]
            rng.shuffle(order)
            pair_id = f"trial-{len(pairs)+1:02d}"
            for label, variant in zip(("A", "B"), order):
                write(out/"blind"/f"{pair_id}-{label}.wav",
                      read(out/"comparison"/f"{name}-{variant}-repeated.wav"))
            pairs.append({"trial": pair_id, "sound": name, "A": order[0], "B": order[1]})
    trace = out/"events.json"
    if trace.exists():
        for run in json.loads(trace.read_text()):
            mixed, info = mix(run["events"], assets, run["seed"], run["seconds"])
            write(out/"mixes"/f"{run['id']}.wav", mixed)
            report["runs"].append({"id": run["id"], **info, **metrics(mixed),
                                   "events": dict(Counter(e["type"] for e in run["events"])),
                                   "sound_counts": dict(Counter(e["sound"] for e in run["events"]))})
    save_json(out/"report.json", report)
    save_json(out/"score-manifest.json", scored)
    save_json(out/"blind-key.json", pairs)
    with (out/("ratings-template.csv" if (out/"ratings.csv").exists() else "ratings.csv")).open("w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["trial", "sound", "preference_A_B_tie", "confidence_1_5",
                         "A_pleasant_1_5", "B_pleasant_1_5", "A_fatigue_1_5", "B_fatigue_1_5", "notes"])
        writer.writerows([[p["trial"], p["sound"], "", "", "", "", "", "", ""] for p in pairs])
    # A static review document; native browser controls, no app dependencies.
    sections = ['<h1>Ballkickers audio experiment</h1><p>Start at low listening volume. '
                'Baseline measurements are technical diagnostics; AI scores and listening judgments are separate.</p>',
                '<h2>Native playback gain</h2><p>Unmodified WAVs with the current game gain. '
                'Compare event clarity and relative level here.</p>']
    for name in NAMES:
        m = report["assets"][name]
        sections.append(f'<h3>{name}</h3><audio controls preload="none" src="native/{name}.wav"></audio>'
                        f'<p>{m["duration_ms"]} ms · peak {m["peak_dbfs"]} dBFS · RMS {m["rms_dbfs"]} dBFS</p>'
                        f'<p>{html.escape("; ".join(m["flags"]) or "No boundary/full-scale flags")}</p>')
    sections.append('<h2>Blind repeated listening</h2><p>A/B clips have matched full-clip RMS '
                    '(not perceptually matched loudness). Use ratings.csv; keep blind-key.json closed until rating. '
                    'Some pairs are identical controls. Judge fatigue, character and clarity; ties are valid.</p>')
    for pair in pairs:
        ident = pair["trial"]
        sections.append(f'<h3>{ident}: {pair["sound"]}</h3>')
        for label in ("A", "B"):
            sections.append(f'<p>{label} <audio controls preload="none" src="blind/{ident}-{label}.wav"></audio></p>')
    sections.append('<h2>Reconstructed bot-match audio</h2><p>60-second simulation traces plus tails. '
                    'Approximate offline mix, not a recording of game playback. No visual synchronization judgment.</p>')
    for run in report["runs"]:
        sections.append(f'<h3>{run["id"]}</h3><audio controls preload="none" src="mixes/{run["id"]}.wav"></audio>'
                        f'<p>{run["max_voices"]} maximum voices; {run["dropped_events"]} dropped events. '
                        f'{html.escape(str(run["sound_counts"]))}</p>')
    document = '<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
    document += '<title>Ballkickers audio experiment</title><style>body{font:17px system-ui;max-width:850px;margin:40px auto;padding:0 20px;background:#101923;color:#e3edf4}h2{margin-top:50px}audio{width:min(100%,540px)}p{line-height:1.5;color:#bfd0de}</style>'
    (out/"index.html").write_text(document+"".join(sections), encoding="utf-8")
    print(json.dumps(report, indent=2))

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=HERE/"output")
    args = parser.parse_args()
    build(args.out.resolve())
