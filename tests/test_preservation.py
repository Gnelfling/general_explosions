import importlib.util
from pathlib import Path
import tempfile
import unittest
import zipfile
import hashlib
import json
import shutil
import subprocess
from test_runtime import client_runtime, runtime

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('package_update', ROOT/'tools/package_update.py')
pack = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pack)


class PreservationTests(unittest.TestCase):
    def test_original_audio_and_compiled_shaders_are_preserved(self):
        for name, digest in json.loads((ROOT/'audio_sources/sha256.json').read_text()).items():
            self.assertEqual(hashlib.sha256((ROOT/'audio_sources'/name).read_bytes()).hexdigest(), digest)
        for name, digest in {'ge_volume_ps30.vcs':'559baf360474f359b36e6a57edf3d606c9bdf50b',
                             'ge_volume_vs30.vcs':'f347532e5679c84c7e50b1539853076d5a6f212d'}.items():
            data=(ROOT/'shaders/fxc'/name).read_bytes()
            self.assertEqual(hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest(),digest)

    def test_read_only_install_verifier(self):
        shell=shutil.which('pwsh') or shutil.which('powershell')
        if not shell: self.skipTest('PowerShell unavailable')
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder)/'general_explosions-main'; root.mkdir()
            names=['shaders/fxc/ge_volume_ps30.vcs','shaders/fxc/ge_volume_vs30.vcs',
                   'lua/general_explosions/runtime.lua','lua/general_explosions/load_runtime.lua',
                   'materials/example.vtf','materials/example.vmt']
            names += ['sound/general_explosions/railgun/'+n for n in ('railgun_charge.wav','railgun_fire.wav','railgun_explosion.wav')]
            for name in names:
                p=root/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b'fixture')
            m=root/'lua/general_explosions/data/ground_explosion.lua';m.parent.mkdir();m.write_text('return {first_frame=0,last_frame=199,frames={{frame=0,texture="example"}}}')
            def snapshot(): return {str(p.relative_to(root)):p.read_bytes() for p in root.rglob('*') if p.is_file()}
            before=snapshot()
            command=[shell,'-NoProfile','-File',str(ROOT/'tools/verify_install.ps1'),'-AddonPath',str(root)]
            result=subprocess.run(command,capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stderr)
            report=json.loads(result.stdout);self.assertEqual(report['FrameRecords'],1)
            self.assertTrue(report['Warnings']);self.assertEqual(before,snapshot())
            (root/'materials/example.vtf').unlink()
            result=subprocess.run(command,capture_output=True,text=True)
            self.assertEqual(result.returncode,1)
            self.assertIn('materials/example.vtf',json.loads(result.stdout)['Missing'])

    def test_overlay_preserves_local_assets_and_custom_audio(self):
        with tempfile.TemporaryDirectory() as folder:
            target = Path(folder)/'update.zip'
            for audio in (False, True):
                pack.package(target, audio)
                with zipfile.ZipFile(target) as z:
                    names = z.namelist()
                    self.assertFalse(any('/data/' in p or p.endswith(('.vtf','.vmt','.vcs')) for p in names))
                    self.assertEqual(len([p for p in names if p.endswith('.wav')]), 3 if audio else 0)
                    self.assertIn('lua/general_explosions/load_runtime.lua', names)
                    self.assertIn('tools/verify_install.ps1', names)

    def test_consumers_load_without_bootstrap_and_survive_reload(self):
        for path in ('autorun/client/ge_volume.lua', 'autorun/client/ge_crater.lua',
                     'autorun/client/ge_fx_client.lua', 'autorun/client/ge_impact_fx.lua',
                     'autorun/server/ge_fx_server.lua', 'entities/ge_orbital_railgun/init.lua',
                     'entities/ge_orbital_railgun/cl_init.lua'):
            with self.subTest(path=path):
                lua, include = runtime() if '/server/' in path or path.endswith('/init.lua') else client_runtime()
                lua.execute('GERuntime=nil')
                include(path)
                self.assertTrue(lua.eval('GERuntime.Frame ~= nil'))
                include(path)
                self.assertEqual(len(lua.globals().ERRORS), 0)

    def test_missing_runtime_reports_actionable_diagnostic(self):
        lua, include = runtime()
        lua.execute('GERuntime=nil')
        lua.globals().include = lambda _: (_ for _ in ()).throw(RuntimeError('missing file'))
        self.assertFalse(include('general_explosions/load_runtime.lua'))
        self.assertIn('install lua/general_explosions/runtime.lua', lua.globals().ERRORS[1])
