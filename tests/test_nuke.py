from pathlib import Path
import struct
import unittest

from test_runtime import client_runtime


class NukeTests(unittest.TestCase):
    def test_strike_impact_runs_once_and_sends_nuke_profile(self):
        from test_runtime import runtime

        lua, include = runtime()
        lua.globals().include = lambda name: include('entities/ge_nuke_strike/shared.lua' if name == 'shared.lua' else name)
        include('autorun/server/ge_fx_server.lua')
        include('entities/ge_nuke_strike/init.lua')
        lua.execute('''
            ENT:SetupDataTables()
            local strike = setmetatable({StrikeStart=100, DropHeight=6400,
                GroundNormal=Vector(0,0,1)}, {__index=ENT})
            NOW=105; strike:Think(); assert(#GEFXServer.craters==0)
            NOW=105.2; strike:Think(); strike:Think()
            local crater = GEFXServer.craters[1]
            assert(#GEFXServer.craters==1 and crater.nuke and crater.radius==650)
            assert(net.last=='ge_fx_nuke_impact_v1' and #sound.calls==1)
            assert(sound.calls[1].path=='general_explosions/nuke/atomic_strike.wav')
            file.Exists=function() return false end
            local fallback = setmetatable({StrikeStart=100, DropHeight=12000,
                GroundNormal=Vector(0,0,1)}, {__index=ENT})
            fallback:Think(); fallback:Think()
            assert(#sound.calls==3 and sound.calls[2].path=='ambient/explosions/explode_9.wav')
            NOW=109; strike:Think(); assert(strike.removed)
        ''')

    def test_shipped_frames_and_independent_playback(self):
        lua, include = client_runtime()
        manifest = include('general_explosions/data/nuke.lua')
        self.assertEqual(len(manifest.frames), 120)
        root = Path(__file__).resolve().parents[1]
        dome = root / 'materials/general_explosions/nuke/condensation.vtf'
        self.assertEqual(dome.stat().st_size, 80 + 64**3 * 4)
        self.assertTrue(dome.with_suffix('.vmt').is_file())
        for frame in manifest.frames.values():
            texture = root / 'materials' / frame.texture
            self.assertTrue(texture.with_suffix('.vmt').is_file())
            vtf = texture.with_suffix('.vtf')
            with vtf.open('rb') as stream:
                header = stream.read(80)
            self.assertEqual(header[:4], b'VTF\0')
            self.assertEqual(struct.unpack_from('<HH', header, 16), (128, 128))
            self.assertEqual(struct.unpack_from('<H', header, 63)[0], 64)
            self.assertEqual(frame.min[3], 0)
            self.assertEqual(vtf.stat().st_size, 80 + 128**2 * 64 * 4)

        include('autorun/client/ge_volume.lua')
        lua.execute('''
            concommand.callbacks.ge_nuke_preview(nil, nil, {})
            assert(GEVolume.preview.profile == 'nuke' and GEVolume.preview.origin.z == 2)
            GEVolume.preview = nil
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
