from pathlib import Path
import struct
import unittest

from test_runtime import client_runtime


class NukeTests(unittest.TestCase):
    def test_shipped_frames_and_independent_playback(self):
        lua, include = client_runtime()
        manifest = include('general_explosions/data/nuke.lua')
        self.assertEqual(len(manifest.frames), 120)
        root = Path(__file__).resolve().parents[1]
        for frame in manifest.frames.values():
            texture = root / 'materials' / frame.texture
            self.assertTrue(texture.with_suffix('.vmt').is_file())
            vtf = texture.with_suffix('.vtf')
            with vtf.open('rb') as stream:
                header = stream.read(80)
            self.assertEqual(header[:4], b'VTF\0')
            self.assertEqual(struct.unpack_from('<H', header, 63)[0], 64)
            self.assertEqual(vtf.stat().st_size, 80 + 64**3 * 4)

        include('autorun/client/ge_volume.lua')
        lua.execute('''
            assert(GEVolume.Spawn(Vector(), 1, 99, "nuke"))
            assert(GEVolume.Spawn(Vector(80, 0, 0), 1, 99))
            assert(not GEVolume.Spawn(Vector(), 1, 99, "unknown"))
            local draw = hook.callbacks['PostDrawTranslucentRenderables:GE.Volume.Render']
            draw(false, false)
            assert(#GEVolume.instances == 2 and #GEVolume.manifest.frames == 188)
            NOW = 107
            draw(false, false)
            assert(#GEVolume.instances == 1 and GEVolume.instances[1].profile == 'nuke')
            NOW = 109
            draw(false, false)
            assert(#GEVolume.instances == 0)
        ''')
