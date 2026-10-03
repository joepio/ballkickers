"""Checks for measurement and playback errors that could invalidate the experiment."""
import math
import tempfile
import unittest
from pathlib import Path
from analyze import SR, db, fade, metrics, mix, read, write, match_rms

class AnalysisTest(unittest.TestCase):
    def test_known_level_and_silence(self):
        self.assertAlmostEqual(db(.5), -6.02, places=2)
        self.assertIsNone(metrics([0.0]*SR)["rms_dbfs"])
        self.assertEqual(metrics([.5]*SR)["peak_dbfs"], -6.02)

    def test_pcm_roundtrip(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)/"test.wav"
            x = [-.9, -.25, 0, .5, .9]
            write(path, x)
            self.assertTrue(all(abs(a-b) <= 1/32768 for a,b in zip(x, read(path))))

    def test_fade_preserves_middle_and_duration(self):
        x = [.5]*1000
        result = fade(x)
        self.assertEqual(len(result), len(x))
        self.assertEqual(result[0], 0)
        self.assertEqual(result[-1], 0)
        self.assertEqual(result[500], .5)

    def test_equal_energy(self):
        x = [.2, -.2]*100
        y = match_rms([.05, -.05]*100, x)
        self.assertAlmostEqual(sum(v*v for v in x), sum(v*v for v in y))

    def test_voice_limit_and_release(self):
        event = {"time": 0, "type": "whistle", "sound": "whistle"}
        events = [event.copy() for _ in range(11)]
        events.append({**event, "time": .2})
        _, result = mix(events, {"whistle": [.1]*2400}, 42, 1)
        self.assertEqual(result["dropped_events"], 1)
        self.assertEqual(result["max_voices"], 10)

    def test_analysis_detects_overload_before_wav_clamping(self):
        events = [{"time": 0, "type": "whistle", "sound": "whistle"}]*10
        audio, _ = mix(events, {"whistle": [.9]*2400}, 42, 1)
        self.assertGreater(metrics(audio)["peak_dbfs"], 0)

if __name__ == "__main__":
    unittest.main()
