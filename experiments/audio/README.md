# Ballkickers sound experiment

## Question

Which problems come from the six source effects, and which come from repetition,
event meaning, or relative levels? Can Audiobox Aesthetics rank these effects
well enough to help shortlist future replacements?

This checkout now includes the sound redesign. The original measurements and AI scores in output/ describe the original six procedural effects, not the replacement bank.

## Hear the redesign

Run `python tools/review_audio.py` with NumPy installed, then serve output/ as below and open http://localhost:8765/redesign.html. This preserves the baseline and adds the new effects at their game playback levels. The replacement bank contains 18 effects; source licenses are in third_party/AUDIO-CREDITS.txt.

The playable Windows build is build/Ballkickers.exe. Rebuild with tools/build.ps1. The build runs the existing gameplay checks and tests/audio.gd, including duplicate suppression, non-repeating variants, reserved goal/whistle voices and reset behavior.

## Reproduce the baseline

Use the original assets and src/main.gd from commit 521fb1b7c650103804c40af439200eb3ddddefa0 in a separate checkout before rerunning the baseline. The baseline analyzer intentionally rejects changed playback rules. Preserve the current output/ before regenerating it.

From that baseline repository root, with Python 3.9+ and Godot 4.5.2:

```sh
godot --headless --path . --script res://experiments/audio/capture_events.gd
python3 experiments/audio/analyze.py
python3 -m unittest discover -s experiments/audio -p 'test_*.py'
python3 -m http.server 8765 --bind 127.0.0.1 --directory experiments/audio/output
```

Open http://localhost:8765. The page has native-volume effects, 18 blind A/B
trials, and 12 reconstructed bot-match mixes. Download or open ratings.csv to
record ratings. A rerun preserves ratings.csv and refreshes ratings-template.csv.

The baseline works without third-party Python packages. Output is ignored by Git.
report.json includes source SHA-256 hashes, the repository commit, measurements
and limitations. events.json contains timestamped events from the real Match
simulation: 60 seconds for seeds 725, 18 and 40 in Dual, 2v2, 3v3 and Classic.

## Conditions and controls

Each effect is presented alone and eight times with 250 ms gaps:

- Original.
- A 3 ms cosine fade at each file boundary. This tests edge clicks only; it is
  not a proposed final redesign and does not repair internal note transitions.
- A deliberately damaged control: clipping, coarse quantization, sample hold.

A/B order is seeded and recorded separately in blind-key.json. There are six
identical-pair controls. Keep that key closed until ratings are complete.
RMS matching reduces energy differences, but does not guarantee equal perceived
loudness. Within each sound, all variants share one peak-safe gain. Native
playback-gain clips are provided separately to inspect the actual level balance.

## Listening procedure

Use a comfortable fixed volume. First rate blind comparisons for preference
(A/B/tie), confidence, pleasantness, and fatigue after repetition. Then hear the
native clips and bot mixes. Record whether kick/pass/hit are distinct and
whether saves, tackles and beaten keepers should share the same cue.

Use at least two listeners if practical. Repeat uncertain pairs later with
reversed order. Treat repeated strong preferences on identical pairs as a reason
to revisit the listening protocol. Do not choose a replacement from AI scores alone.

## Optional local AI judge

Use a separate Python environment. Tested package pins are in requirements-ai.txt;
install a matching torch/torchaudio pair appropriate for your system first.
For CPU-only Windows/Linux:

```sh
python -m venv experiments/audio/.venv
# Activate the environment using your shell's standard activation command.
python -m pip install torch==2.6.0 torchaudio==2.6.0 --index-url https://download.pytorch.org/whl/cpu
python -m pip install -r experiments/audio/requirements-ai.txt
python experiments/audio/score_audiobox.py
```

First use downloads model weights. Audio stays local. The scorer evaluates all
36 single/repeated clips and writes audiobox-scores.json plus a negative-control
check in audiobox-controls.json. It records package version, device, and clip hashes.
Keep production quality (PQ), enjoyment (CE), usefulness (CU), and complexity
(PC) separate. Complexity is not a quality target.

Predefined checks: original repeated clips should beat damaged controls on PQ
for at least five of six effects before trying the judge for shortlisting.
Check whether the direction of original-versus-fade preference changes between
single and repeated presentation. Disagreement is evidence of sensitivity to
presentation, not evidence that either score is the truth. Compare with blind
human ratings before selecting assets. Six effects are too few to establish
general judge reliability.

Reference implementation:
https://github.com/facebookresearch/audiobox-aesthetics

## Limits

- The bot mix is reconstructed offline, not captured game output. It includes
  current gains, ten voices and pitch variation, but excludes presentation
  hit-stop, Godot resampling, device processing and spatial/visual context.
- Simulations are bots, not a measurement of human match event rates.
- Simulation randomness is from Godot; offline pitch randomness is Python.
- Boundary thresholds are diagnostic prompts for listening, not pass/fail quality.
- Full-scale detection cannot identify every kind of distortion. The generator
  clamps before scaling to 26000; generator_clamp_samples reports exact samples
  at that known internal ceiling separately.
- No game changes or new generated sound replacements are included.

## Completed first run

See [RESULTS.md](RESULTS.md) for the initial measurements and model outcome.
Audiobox was run locally on all 36 clips; it met the negative-control expectation
for 4/6 effects, below the 5/6 gate. Human listening ratings remain empty.
`summarize.py` validates clip hashes before producing the results page.
After rerunning analysis with existing AI outputs, run it again to validate and
refresh the summary. Changed files require new AI scoring.

On this machine the separate AI environment is at
`C:/Users/joepm/AppData/Local/Temp/ballkickers-audio-ai`.
Its full installed versions are recorded in `environment-ai.txt`.
