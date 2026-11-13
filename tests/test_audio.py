"""Asset compatibility and sample-time preservation checks."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('prepare_audio', ROOT / 'tools/prepare_audio.py')
prepare_audio = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(prepare_audio)


class AudioTests(unittest.TestCase):
    def test_existing_cues_keep_sample_count_and_rate(self):
        expected = {'railgun_charge.wav': 138240, 'railgun_fire.wav': 224256,
                    'railgun_explosion.wav': 589875}
        folder = ROOT / 'sound/general_explosions/railgun'
        names = {p.name for p in folder.iterdir()}
        for name, frames in expected.items():
            self.assertIn(name, names)  # Also checks actual filename case on Windows.
            with wave.open(str(folder / name), 'rb') as audio:
                self.assertEqual(audio.getparams()[:4], (1, 2, 44100, frames))

    def test_24bit_signed_mixdown_and_no_trimming(self):
        with tempfile.TemporaryDirectory() as folder:
            source, target = Path(folder)/'source.wav', Path(folder)/'target.wav'
            samples = np.array([-8388608, -8388608, 8388607, 8388607, 256, 768], dtype=np.int32)
            raw = np.column_stack([samples & 255, (samples >> 8) & 255, (samples >> 16) & 255])
            with wave.open(str(source), 'wb') as audio:
                audio.setparams((2, 3, 44100, 3, 'NONE', 'not compressed'))
                audio.writeframes(raw.astype(np.uint8).tobytes())
            prepare_audio.prepare(source, target)
            with wave.open(str(target), 'rb') as audio:
                self.assertEqual(audio.getnframes(), 3)
                self.assertEqual(np.frombuffer(audio.readframes(3), dtype='<i2').tolist(), [-32768, 32767, 2])
