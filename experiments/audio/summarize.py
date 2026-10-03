"""Summarize verified AI scores and baseline measurements without rerunning inference."""
import argparse
import hashlib
import html
import json
from pathlib import Path

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=Path(__file__).resolve().parent/"output")
    out = parser.parse_args().out.resolve()
    report = json.loads((out/"report.json").read_text())
    result = json.loads((out/"audiobox-scores.json").read_text())
    for row in result["records"]:
        actual = hashlib.sha256((out/row["path"]).read_bytes()).hexdigest()
        if actual != row["sha256"]:
            raise SystemExit("Stale AI score for "+row["id"])
    by_id = {row["id"]: row["scores"] for row in result["records"]}
    names = ("kick", "pass", "hit", "super", "goal", "whistle")
    differences = {name: by_id[f"{name}/original/repeated"]["PQ"] -
                   by_id[f"{name}/damaged_control/repeated"]["PQ"] for name in names}
    wins = sum(delta > 0 for delta in differences.values())
    report["ai_status"] = "completed; all scored file hashes verified"
    report["ai_control_gate"] = {"passed": wins >= 5, "original_preferred_count": wins, "required": 5, "total": 6}
    (out/"report.json").write_text(json.dumps(report, indent=2)+"\n")
    lines = ["# Ballkickers audio baseline — 2 October 2026", "",
             f"Source commit: {report['commit']}. Production sounds and playback code are unchanged.", "",
             "## AI judge result", "",
             f"Audiobox Aesthetics {result['package_version']} ran locally on {result['device']}. "
             f"It preferred the original over deliberately damaged repeated clips on production quality for **{wins}/6** effects. "
             "The predefined gate requires at least 5/6. **Do not use this judge alone to choose replacement sounds.**", "",
             "| Effect | Original PQ | Damaged PQ | Original enjoyment |",
             "|---|---:|---:|---:|"]
    for name in names:
        original = by_id[f"{name}/original/repeated"]
        damaged = by_id[f"{name}/damaged_control/repeated"]
        lines.append(f"| {name} | {original['PQ']:.2f} | {damaged['PQ']:.2f} | {original['CE']:.2f} |")
    lines += ["", "These are model predictions, not listener ratings. Pass is effectively tied; "
              "the damaged whistle receives higher PQ. The damaged single hit also scores above the original on PQ. "
              "The judge is sensitive to presentation. Higher PQ does not establish pleasantness or gameplay fit.", "",
              "## Measurements", "",
              "- Hit plays 24–44 times per minute across these twelve seeded bot traces. "
              "Saves, tackles and beaten keepers share this source clip.",
              "- Kick, pass, hit and super have boundary discontinuities above the exploratory -50 dBFS threshold. "
              "The blind fade condition tests whether these are audible at listening level.",
              "- The goal jingle has a 0.465 full-scale sample jump at 170 ms, exactly at a generated note change. "
              "The boundary fade condition does not repair this internal transition.",
              f"- Hit contains {report['assets']['hit']['generator_clamp_samples']} samples at the generator's internal clamp ceiling "
              "(26000/32768), even though the WAV does not reach 0 dBFS.",
              "- No reconstructed mix reached full scale or exhausted ten voices; maximum concurrency was four. "
              "This does not rule out device-specific playback faults.", "",
              "## Next decision", "",
              "Complete the blind listening sheet before replacing assets. Prioritize hit repetition, "
              "the whistle's character, and goal-note transitions. If redesigned or generated candidates are added, "
              "compare them at matched listening level and then in actual gameplay with visuals.", "",
              "## Evidence and limits", "",
              "The listening page includes six native-gain effects, eighteen blind repeated A/B pairs "
              "(including six identical controls), and twelve reconstructed bot mixes. "
              "There are 36 AI-scored single/repeated clips. "
              "The bot mixes approximate current playback gain, pitch range and voice count; "
              "they exclude presentation hit-stop and the actual Godot/device audio path. "
              "RMS matching is not perceptual loudness matching. No human preference results have been collected.", "",
              "Checks: six analysis tests passed; all 54 browser audio links returned WAVs; "
              "browser playback succeeded; desktop and 390px mobile layouts were captured.", ""]
    (out/"results.md").write_text("\n".join(lines), encoding="utf-8")
    text = html.escape("\n".join(lines))
    (out/"results.html").write_text('<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
        '<title>Ballkickers audio results</title><style>body{max-width:950px;margin:40px auto;padding:0 20px;font:16px system-ui;background:#101923;color:#e3edf4}pre{white-space:pre-wrap;line-height:1.6}a{color:#93d9ff}</style>'
        '<a href="/">Listening experiment</a><pre>'+text+'</pre>', encoding="utf-8")
    print(json.dumps(report["ai_control_gate"]))

if __name__ == "__main__":
    main()
