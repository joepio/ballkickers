"""Optional local AI scoring. Downloads Audiobox weights on first run; uploads no audio."""
import argparse
import hashlib
import importlib.metadata
import json
import wave
import math
import subprocess
import sys
from pathlib import Path

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=Path(__file__).resolve().parent/"output")
    args = parser.parse_args()
    out = args.out.resolve()
    manifest = json.loads((out/"score-manifest.json").read_text())
    try:
        import torch
        from audiobox_aesthetics.infer import initialize_predictor
    except ImportError as exc:
        raise SystemExit("Install requirements-ai.txt in a separate Python environment first: " + str(exc))
    predictor = initialize_predictor()
    records = []
    for item in manifest:
        path = out/item["path"]
        # Read PCM directly; avoids backend/FFmpeg differences in torchaudio.load.
        import array
        import sys
        with wave.open(str(path), "rb") as stream:
            sample_rate = stream.getframerate()
            if stream.getnchannels() != 1 or stream.getsampwidth() != 2:
                raise ValueError("Expected mono PCM16")
            samples = array.array("h", stream.readframes(stream.getnframes()))
        if sys.byteorder != "little":
            samples.byteswap()
        tensor = torch.tensor(samples, dtype=torch.float32).unsqueeze(0)/32768
        scores = predictor.forward([{"path": tensor, "sample_rate": sample_rate}])[0]
        if set(scores) != {"CE", "CU", "PC", "PQ"} or not all(math.isfinite(v) for v in scores.values()):
            raise ValueError("Unexpected model output")
        records.append({**item, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "scores": scores})
        print(item["id"], scores, flush=True)
    payload = {"model": "facebook/audiobox-aesthetics", "package_version": importlib.metadata.version("audiobox-aesthetics"),
               "torch": torch.__version__, "device": str(predictor.device), "records": records,
               "limits": "Exploratory scores. Very short effects and repeated montages differ from training examples. Do not maximize PC or combine all axes."}
    (out/"audiobox-scores.json").write_text(json.dumps(payload, indent=2)+"\n")
    scores_by_id = {r["id"]: r["scores"] for r in records}
    checks = []
    for sound in ("kick", "pass", "hit", "super", "goal", "whistle"):
        original = scores_by_id[f"{sound}/original/repeated"]["PQ"]
        damaged = scores_by_id[f"{sound}/damaged_control/repeated"]["PQ"]
        checks.append({"sound": sound, "original_PQ_minus_damaged_PQ": original-damaged})
    (out/"audiobox-controls.json").write_text(json.dumps(checks, indent=2)+"\n")
    subprocess.run([sys.executable, str(Path(__file__).with_name("summarize.py")), "--out", str(out)], check=True)
    print("Control checks:", checks)
    print("If damaged controls are not consistently rated worse, do not use this judge to select these SFX.")

if __name__ == "__main__":
    main()
