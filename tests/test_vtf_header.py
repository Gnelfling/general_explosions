"""Tests for the Blender-independent parts of the VDB converter.

Run with: python -m unittest discover -s tests -v
Requirements: numpy. Tests do not require Blender, GMod or OpenVDB.
"""
import importlib.util
import struct
import tempfile
import unittest
from pathlib import Path

import numpy as np

SPEC = importlib.util.spec_from_file_location(
    "vdb_to_vtf", Path(__file__).resolve().parents[1] / "tools" / "vdb_to_vtf.py")
converter = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(converter)


class TestVTFHeader(unittest.TestCase):
    def test_volume_vtf_header(self):
        h = converter.make_vtf_header(128, 128, 128)
        self.assertEqual(len(h), 80)
        self.assertEqual(h[:4], b"VTF\x00")
        self.assertEqual(struct.unpack_from("<II", h, 4), (7, 2))
        self.assertEqual(struct.unpack_from("<I", h, 12)[0], 80)
        self.assertEqual(struct.unpack_from("<HH", h, 16), (128, 128))
        self.assertEqual(struct.unpack_from("<I", h, 20)[0], 0x2300)
        self.assertEqual(struct.unpack_from("<I", h, 52)[0], 0)
        self.assertEqual(h[56], 1)
        self.assertEqual(struct.unpack_from("<I", h, 57)[0], 0xFFFFFFFF)
        self.assertEqual(struct.unpack_from("<H", h, 63)[0], 128)

    def test_invalid_sizes(self):
        with self.assertRaises(ValueError):
            converter.make_vtf_header(60, 64, 64)

    def test_write_volume(self):
        vol = np.zeros((4, 4, 4, 4), dtype=np.uint8)
        vol[1, 2, 3] = (201, 17, 0, 255)
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "smoke.vtf"
            converter.write_volume_vtf(path, vol)
            payload = path.read_bytes()
        self.assertEqual(len(payload), 80 + 4*4*4*4)
        self.assertEqual(payload[80:], vol.tobytes(order="C"))


class TestSampling(unittest.TestCase):
    def test_empty_frame_keeps_its_timing_without_fabricating_voxels(self):
        class EmptyVDB:
            def readAll(self, path):
                return [], {}
        with tempfile.TemporaryDirectory() as folder:
            target = Path(folder)
            result = converter.export_frame(EmptyVDB(), target/'frame.vdb', target, 199, 4)
            self.assertEqual(result, {'frame': 199, 'empty': True})
            self.assertEqual(list(target.iterdir()), [])
            manifest = converter.lua_manifest([result], 24, (0, 0, 0), 0, 199)
            self.assertIn('first_frame = 0', manifest)
            self.assertIn('last_frame = 199', manifest)
            self.assertIn('{frame=199, empty=true}', manifest)

    def test_trilinear_affine_field(self):
        original = sum(np.indices((4, 4, 4))).astype(np.float32)
        output = original
        for axis in range(3):
            output = converter.interp_axis(
                output, np.array([0, 1.5, 3], dtype=np.float32), 0, axis)
        self.assertEqual(output.shape, (3, 3, 3))
        self.assertAlmostEqual(float(output[1, 1, 1]), 4.5, places=5)
        self.assertAlmostEqual(float(output[-1, -1, -1]), 9.0, places=5)

    def test_quantize(self):
        field = np.array([0.0, 0.5, 1.0], dtype=np.float32)
        packed, peak = converter.quantize(field)
        self.assertAlmostEqual(peak, 1.0)
        self.assertEqual(packed.tolist(), [0, 128, 255])

    def test_sequence_filename(self):
        path = converter.series_path(Path("ground_explosion_0000.vdb"), 100)
        self.assertEqual(path.name, "ground_explosion_0100.vdb")


if __name__ == "__main__":
    unittest.main()
