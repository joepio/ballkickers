# Ballkickers audio baseline — 2 October 2026

Source commit: 521fb1b7c650103804c40af439200eb3ddddefa0. Production sounds and playback code are unchanged.

## AI judge result

Audiobox Aesthetics 0.0.4 ran locally on cpu. It preferred the original over deliberately damaged repeated clips on production quality for **4/6** effects. The predefined gate requires at least 5/6. **Do not use this judge alone to choose replacement sounds.**

| Effect | Original PQ | Damaged PQ | Original enjoyment |
|---|---:|---:|---:|
| kick | 7.16 | 6.98 | 3.91 |
| pass | 6.99 | 7.00 | 3.62 |
| hit | 7.12 | 6.43 | 3.15 |
| super | 7.02 | 6.86 | 3.16 |
| goal | 7.88 | 7.71 | 3.89 |
| whistle | 7.68 | 7.83 | 2.98 |

These are model predictions, not listener ratings. Pass is effectively tied; the damaged whistle receives higher PQ. The damaged single hit also scores above the original on PQ. The judge is sensitive to presentation. Higher PQ does not establish pleasantness or gameplay fit.

## Measurements

- Hit plays 24–44 times per minute across these twelve seeded bot traces. Saves, tackles and beaten keepers share this source clip.
- Kick, pass, hit and super have boundary discontinuities above the exploratory -50 dBFS threshold. The blind fade condition tests whether these are audible at listening level.
- The goal jingle has a 0.465 full-scale sample jump at 170 ms, exactly at a generated note change. The boundary fade condition does not repair this internal transition.
- Hit contains 2 samples at the generator's internal clamp ceiling (26000/32768), even though the WAV does not reach 0 dBFS.
- No reconstructed mix reached full scale or exhausted ten voices; maximum concurrency was four. This does not rule out device-specific playback faults.

## Next decision

Complete the blind listening sheet before replacing assets. Prioritize hit repetition, the whistle's character, and goal-note transitions. If redesigned or generated candidates are added, compare them at matched listening level and then in actual gameplay with visuals.

## Evidence and limits

The listening page includes six native-gain effects, eighteen blind repeated A/B pairs (including six identical controls), and twelve reconstructed bot mixes. There are 36 AI-scored single/repeated clips. The bot mixes approximate current playback gain, pitch range and voice count; they exclude presentation hit-stop and the actual Godot/device audio path. RMS matching is not perceptual loudness matching. No human preference results have been collected.

Checks: six analysis tests passed; all 54 browser audio links returned WAVs; browser playback succeeded; desktop and 390px mobile layouts were captured.
