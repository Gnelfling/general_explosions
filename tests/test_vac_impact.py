import importlib.util
from pathlib import Path
import tempfile
import unittest
from test_runtime import client_runtime

ROOT = Path(__file__).resolve().parents[1]


class VACImpactTests(unittest.TestCase):
    def test_optional_layer_seek_cull_expiry_and_error_cleanup(self):
        lua, include = client_runtime()
        include('autorun/client/ge_vac_impact.lua')
        lua.execute('''
            GEVACImpact.data={COLS=16,ROWS=8,F={
                {t=0,wA=0,rA=0,rB=0,Rb=20,Zb=30},
                {t=40,wA=1,rA=1,rB=1,Rb=100,Zb=70}}}
            NOW=104
            assert(GEVACImpact.Spawn(Vector(),320,100))
            assert(GEVACImpact.list[1].start==100)
            local idx,k=GEVACImpact.Frame(20);assert(idx==0 and k==0.5)
            local draw=hook.callbacks['PostDrawTranslucentRenderables:GE.VACImpact.Render']
            draw(false,false);assert(render.state.OverrideDepthEnable==false)
            GEVACImpact.list[1].pos=Vector(30000,0,0)
            FAIL_VERTEX=true;draw(false,false);assert(#ERRORS==0)
            GEVACImpact.list[1].pos=Vector();draw(false,false)
            assert(#ERRORS==1 and #GEVACImpact.list==0 and render.state.OverrideDepthEnable==false)
            FAIL_VERTEX=false;assert(GEVACImpact.Spawn(Vector(),320,100))
            CVARS.ge_railgun_vac_impact.value='0';NOW=109;draw(false,false)
            assert(#GEVACImpact.list==0)
            CVARS.ge_railgun_vac_impact.value='1'
            file.Exists=function() return false end
            local ok,reason=GEVACImpact.Spawn(Vector(),320,109)
            assert(not ok and string.find(reason,'Missing optional asset'))
        ''')

    def test_entity_optional_layer_once_even_when_lighting_disabled(self):
        lua, include = client_runtime()
        include('entities/ge_orbital_railgun/cl_init.lua')
        lua.execute('''
            ENT:SetupDataTables()
            local count=0
            GEVACImpact={Spawn=function(pos,r,t) count=count+1;assert(r==320 and t==103.2) end}
            local e=setmetatable({StartTime=100,ImpactRadius=320,GroundNormal=Vector(0,0,1)},{__index=ENT})
            CVARS.ge_railgun_light.value='0';NOW=103.19;e:Think();assert(count==0)
            NOW=103.4;e:Think();e:Think();assert(count==1)
        ''')

    def test_import_is_nondestructive_and_extracts_only_dependencies(self):
        spec=importlib.util.spec_from_file_location('import_vac',ROOT/'tools/import_vac_impact.py')
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as folder:
            source,target=Path(folder)/'source',Path(folder)/'target'
            for name in module.FILES:
                p=source/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b'fixture')
            data=source/'lua/vac/fx/cl_impact_vol_data.lua';data.parent.mkdir(parents=True)
            data.write_text('VAC.FX.ImpactVolData = { COLS=16, ROWS=8, F={} }')
            names=module.extract(source,target)
            self.assertEqual(len(names),7)
            self.assertTrue((target/module.DATA).read_text().splitlines()[1].startswith('return {'))
            self.assertEqual(data.read_text(),'VAC.FX.ImpactVolData = { COLS=16, ROWS=8, F={} }')
            with self.assertRaises(FileExistsError): module.extract(source,target)
