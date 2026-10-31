"""Execute actual addon Lua with a Lua 5.1 runtime and mocked GMod boundaries.

These are behavior/contract tests; no rendering, networking or audio is emulated.
"""
from pathlib import Path
import unittest

from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]


def runtime():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute((ROOT / 'tests/gmod_stub.lua').read_text())
    def include(path):
        if path == 'shared.lua':
            path = 'entities/ge_orbital_railgun/shared.lua'
        return lua.execute((ROOT / 'lua' / path).read_text())
    lua.globals().include = include
    include('general_explosions/runtime.lua')
    return lua, include


def client_runtime():
    lua, include = runtime()
    lua.execute((ROOT / 'tests/render_stub.lua').read_text())
    return lua, include


class RuntimeTests(unittest.TestCase):
    def test_spawn_permissions_limits_and_single_undo_registration(self):
        lua, include = runtime()
        include('entities/ge_orbital_railgun/init.lua')
        lua.execute('''
            ENT:SetupDataTables()
            for _,name in ipairs({'SetModel','SetMoveType','SetSolid','DrawShadow','SetCollisionGroup',
                'SetPos','SetAngles','Activate','SetCreator'}) do ENT[name]=function() end end
            ENT.Spawn=function(e) e:Initialize() end
            local creates,undos,cleanups=0,0,0
            ents.Create=function() creates=creates+1;return setmetatable({},{__index=ENT}) end
            undo={Create=function() undos=undos+1 end,AddEntity=function() end,SetPlayer=function() end,Finish=function() end}
            local tr={Hit=true,HitWorld=true,HitNormal=Vector(0,0,1),HitPos=Vector(0,0,0)}
            local admin=false
            local ply={IsAdmin=function() return admin end,ChatPrint=function() end,
                GetEyeTrace=function() return tr end,AddCleanup=function(_,kind) assert(kind=='sents');cleanups=cleanups+1 end}
            assert(ENT:SpawnFunction(ply,tr)==nil and creates==0)
            admin=true; tr.HitSky=true
            assert(ENT:SpawnFunction(ply,tr)==nil and creates==0)
            tr.HitSky=false
            assert(ENT:SpawnFunction(ply,tr)~=nil and undos==0 and cleanups==0)
            concommand.callbacks.ge_railgun_fire(ply); assert(undos==1 and cleanups==1)
            ents.FindByClass=function() return {{},{}} end
            assert(ENT:SpawnFunction(ply,tr)==nil and creates==2)
            ents.FindByClass=function() return {{},{},{}} end
            local e=setmetatable({},{__index=ENT});e:Initialize();assert(e.removed)
        ''')

    def test_cleanup_invalidates_pending_showcase_timers(self):
        lua, include = runtime()
        include('autorun/server/ge_fx_server.lua')
        lua.execute('''
            local callbacks={}
            timer.Simple=function(_,fn) callbacks[#callbacks+1]=fn end
            local ply={IsAdmin=function() return true end,GetEyeTrace=function()
                return {Hit=true,HitWorld=true,HitNormal=Vector(0,0,1),HitPos=Vector(0,0,0)} end}
            concommand.callbacks.ge_fx_showcase(ply,nil,{})
            assert(#callbacks==3)
            GEFXServer.Clear()
            for _,fn in ipairs(callbacks) do fn() end
            assert(#GEFXServer.craters==0)
        ''')

    def test_all_lua_parses_as_51(self):
        lua = LuaRuntime()
        compile_lua = lua.eval('function(s,n) local f,e=loadstring(s,n); assert(f,e) end')
        for path in ROOT.rglob('*.lua'):
            with self.subTest(path=path.relative_to(ROOT)):
                compile_lua(path.read_text(), str(path))

    def test_frame_boundaries_all_200_and_sparse_empty_frames(self):
        lua, _ = runtime()
        lua.execute('''
            local frames={}
            for i=0,199 do frames[#frames+1]={frame=i} end
            local m={frames=frames,fps=24}
            for i=0,199 do
                local f,alive=GERuntime.Frame(m,(i+0.01)/24,1,false)
                assert(alive and f.frame==i)
            end
            local f,alive=GERuntime.Frame(m,200/24,1,false)
            assert(f==nil and not alive)
            f,alive=GERuntime.Frame(m,-1,1,false); assert(f==nil and alive)
            f=GERuntime.Frame(m,200/24,1,true); assert(f.frame==0)
            f=GERuntime.Frame(m,1,0.5,false); assert(f.frame==12)
            m={fps=24,frames={{frame=0},{frame=2},{frame=4,empty=true},{frame=199,empty=true}}}
            f=GERuntime.Frame(m,3/24,1,false); assert(f.frame==2)
            f,alive=GERuntime.Frame(m,198/24,1,false); assert(f==nil and alive)
        ''')

    def test_seeded_stream_does_not_touch_global_rng(self):
        lua, _ = runtime()
        lua.execute('''
            local a,b=GERuntime.Random(55),GERuntime.Random(55)
            for i=1,200 do local x=a(-4,8); assert(x==b(-4,8) and x>=-4 and x<=8) end
            assert(GERuntime.Number(0/0,5,0,10)==5)
            assert(GERuntime.Number(math.huge,5,0,10)==5)
            assert(not GERuntime.Position(Vector(0/0,0,0)))
        ''')

    def test_server_cues_once_at_exact_offsets_and_single_impact(self):
        lua, include = runtime()
        include('autorun/server/ge_fx_server.lua')
        include('entities/ge_orbital_railgun/init.lua')
        lua.execute('''
            ENT:SetupDataTables()
            e=setmetatable({StartTime=100,ImpactRadius=320,VisualSeed=777,
                GroundNormal=Vector(0,0,1)}, {__index=ENT})
            for _,t in ipairs({99.9,100,100,102.999,103,103,103.2,103.2,104.3}) do NOW=t; e:Think() end
            assert(#sound.calls==3)
            assert(sound.calls[1].time==100 and sound.calls[2].time==103 and sound.calls[3].time==103.2)
            assert(#GEFXServer.craters==1)
            assert(GEFXServer.craters[1].time==103.2 and GEFXServer.craters[1].seed==777)
            NOW=105.3; e:Think(); assert(e.removed and #sound.calls==3)
            e=setmetatable({StartTime=90},{__index=ENT}); e:Think(); assert(e.removed and #sound.calls==3)
        ''')

    def test_snapshot_is_rate_limited_and_history_bounded(self):
        lua, include = runtime()
        include('autorun/server/ge_fx_server.lua')
        lua.execute('''
            assert(not GEFXServer.Impact(Vector(0/0,0,0),200,50))
            for i=1,40 do GEFXServer.Impact(Vector(i,0,0),200,50) end
            assert(#GEFXServer.craters==12 and GEFXServer.craters[1].id==29)
            local ply={}
            net.callbacks.ge_fx_ready_v2(0,ply)
            local n=#net.writes
            net.callbacks.ge_fx_ready_v2(0,ply); assert(#net.writes==n)
            NOW=111; net.callbacks.ge_fx_ready_v2(0,ply); assert(#net.writes>n)
            GEFXServer.Clear(); assert(#GEFXServer.craters==0)
        ''')


class ClientBehaviorTests(unittest.TestCase):
    def test_future_clock_record_waits_for_impact_time(self):
        lua, include = client_runtime()
        include('autorun/client/ge_fx_client.lua')
        lua.execute('''
            local volumes,craters=0,0
            GEVolume={Spawn=function(p,s,t) volumes=volumes+1;assert(t==100.1);return true end}
            GECraters={Add=function() craters=craters+1;return true end}
            local i,j=0,0
            net.ReadUInt=function() i=i+1;return i==1 and 1 or 55 end
            local floats={100.1,320,77}
            net.ReadFloat=function() j=j+1;return floats[j] end
            net.ReadVector=function() return Vector() end
            net.ReadNormal=function() return Vector(0,0,1) end
            net.ReadBool=function() return false end
            net.callbacks.ge_fx_visual_impact_v2()
            hook.callbacks['Think:GE.FX.BuildCraters']()
            assert(volumes==0 and craters==0)
            NOW=100.1;hook.callbacks['Think:GE.FX.BuildCraters']()
            assert(volumes==1 and craters==1)
        ''')

    def test_nearest_light_budget_occlusion_query_and_removal(self):
        lua, include = client_runtime()
        include('entities/ge_orbital_railgun/cl_init.lua')
        lua.execute('''
            ENT:SetupDataTables()
            local entities={}
            CVARS.ge_railgun_light_budget.value='2'
            NOW=103.25
            for i=1,4 do
                local e=setmetatable({StartTime=100,ImpactRadius=320,VisualSeed=i,
                    GroundNormal=Vector(0,0,1)},{__index=ENT})
                e.GetPos=function() return Vector(i*100,0,3) end
                e.EntIndex=function() return i end
                e:Initialize();entities[i]=e
            end
            for _,e in ipairs(entities) do e:Think() end
            assert(LIGHTS[1] and LIGHTS[2] and not LIGHTS[3] and not LIGHTS[4])
            local e=entities[1]
            e:DrawTranslucent();e:DrawTranslucent();assert(PIXEL_CALLS==1)
            assert(LIGHTS[1].brightness>1 and LIGHTS[1].dietime>NOW)
            e:OnRemove();assert(LIGHTS[1].size==0)
            hook.callbacks['PostCleanupMap:GE.Railgun.Cleanup']()
            assert(LIGHTS[2].size==0)
        ''')

    def test_every_cinematic_phase_palette_and_quality_executes(self):
        lua, include = client_runtime()
        include('entities/ge_orbital_railgun/cl_init.lua')
        lua.execute('''
            ENT:SetupDataTables()
            e=setmetatable({StartTime=100,ImpactRadius=320,VisualSeed=88,
                GroundNormal=Vector(0,0,1)},{__index=ENT})
            e:Initialize()
            for q=0,2 do
                CVARS.ge_railgun_quality.value=tostring(q)
                for _,color in ipairs({'blue','purple','red','unknown'}) do
                    CVARS.ge_railgun_color.value=color
                    for i=0,315 do
                        NOW=99.99+i/60
                        e:DrawTranslucent(); e:Think()
                        assert(render.beam==0)
                    end
                end
            end
            assert(render.calls>0 and LIGHTS[7].size==0)
            CVARS.ge_railgun_visuals.value='0'; e:Think()
            assert(LIGHTS[7].size==0)
            local count=render.calls; e:DrawTranslucent(); assert(count==render.calls)
            e:OnRemove(); assert(GERailgunVisuals.active[e]==nil)
        ''')

    def test_crater_trace_budget_failure_cleanup_and_render_state(self):
        lua, include = client_runtime()
        include('autorun/client/ge_crater.lua')
        lua.execute('''
            local ok,c=GECraters.Add(Vector(0,0,0),320,77,{seed=99})
            assert(ok and TRACES==49 and c.heatMesh)
            FAIL_DRAW=true
            hook.callbacks['PostDrawOpaqueRenderables:GE.Crater.Render'](false,false)
            assert(c.failed and #ERRORS==1)
            assert(render.state.SetStencilEnable==false)
            assert(render.state.OverrideDepthEnable==false and render.state.OverrideColorWriteEnable==false)
            assert(render.state.OverrideAlphaWriteEnable==false and render.state.SetBlend==1)
            hook.callbacks['PostDrawOpaqueRenderables:GE.Crater.Render'](false,false)
            assert(#ERRORS==1)
            GECraters.Clear()
            for _,m in ipairs(MESHES) do assert(m.destroyed) end
            FAIL_DRAW=false; FAIL_VERTEX=true
            ok=GECraters.Add(Vector(0,0,0),320,77,{seed=99}); assert(not ok)
            for _,m in ipairs(MESHES) do assert(m.destroyed) end
            FAIL_VERTEX=false
            ok,c=GECraters.Add(Vector(0,0,0),320,0,{seed=99})
            assert(ok and c.flatMesh and #c.meshes==1)
        ''')

    def test_particle_budget_determinism_and_cleanup(self):
        lua, include = client_runtime()
        include('autorun/client/ge_impact_fx.lua')
        lua.execute('''
            CVARS.ge_fx_particle_budget.value='64'
            local a=GEImpactFX.Burst(Vector(0,0,0),1,55)
            local v=EMITTERS[1].particles[1].Velocity
            local b=GEImpactFX.Burst(Vector(0,0,0),1,55)
            assert(a+b<=64 and GEImpactFX.Burst(Vector(0,0,0),1,55)==0)
            local w=EMITTERS[2].particles[1].Velocity
            assert(v:DistToSqr(w)==0)
            GEImpactFX.Clear()
            for _,e in ipairs(EMITTERS) do assert(e.finished and e.hidden) end
            FAIL_PARTICLE=true
            GEImpactFX.Burst(Vector(0,0,0),1,55)
            assert(EMITTERS[#EMITTERS].finished and #ERRORS==1)
        ''')

    def test_volume_hides_without_reset_and_culls_before_texture_lookup(self):
        lua, include = client_runtime()
        manifest = include('general_explosions/data/ground_explosion.lua')
        original_include = lua.globals().include
        lua.globals().include = lambda path: manifest if path.endswith('ground_explosion.lua') else original_include(path)
        include('autorun/client/ge_volume.lua')
        lua.execute('''
            local draw=hook.callbacks['PostDrawTranslucentRenderables:GE.Volume.Render']
            assert(GEVolume.Spawn(Vector(0,0,0),1,99))
            CVARS.ge_volume_enabled.value='0'; draw(false,false)
            assert(#GEVolume.instances==1 and GEVolume.instances[1].start==99)
            CVARS.ge_volume_enabled.value='1'
            local original=Material
            Material=function() error('offscreen texture lookup') end
            GEVolume.instances[1].origin=Vector(30000,0,0)
            draw(false,false); assert(#GEVolume.instances==1)
            Material=original
            NOW=110; draw(false,false); assert(#GEVolume.instances==0)
            NOW=100; assert(GEVolume.Spawn(Vector(0,0,0),1,99))
            draw(false,false)
            hook.callbacks['PostCleanupMap:GE.Volume.Cleanup'](); assert(#GEVolume.instances==0)
        ''')

    def test_invalid_manifest_fails_cleanly(self):
        for manifest in ('return 12', 'return {frames={1}}',
                         'return {fps=0/0,frames={{frame=0,empty=true}}}',
                         'return {fps=24,anchor=4,frames={{frame=0,empty=true}}}',
                         'return {fps=24,last_frame=0/0,frames={{frame=0,empty=true}}}'):
            with self.subTest(manifest=manifest):
                lua, include = client_runtime()
                include('autorun/client/ge_volume.lua')
                lua.globals().include = lambda _: lua.execute(manifest)
                lua.execute('local ok,err=GEVolume.Spawn(Vector(0,0,0),1); assert(not ok and type(err)=="string")')

    def test_network_duplicate_snapshot_and_late_packet_ages(self):
        lua, include = client_runtime()
        include('autorun/client/ge_fx_client.lua')
        lua.execute('''
            local volumes,craters,bursts=0,0,0
            GEVolume={Spawn=function(p,s,t) volumes=volumes+1; assert(t==99.8); return true end,
                ClearInstances=function() end}
            GECraters={Add=function() craters=craters+1; return true end,Clear=function() end}
            GEImpactFX={Burst=function() bursts=bursts+1 end}
            local uints={8,55}; local floats={99.8,320,77}
            local ui,fi=0,0
            net.ReadUInt=function(bits) if bits==6 then return 1 end; ui=ui+1; return uints[ui] end
            net.ReadFloat=function() fi=fi+1; return floats[fi] end
            net.ReadVector=function() return Vector(0,0,0) end
            net.ReadNormal=function() return Vector(0,0,1) end
            net.ReadBool=function() return false end
            local function impact() ui,fi=0,0; net.callbacks.ge_fx_visual_impact_v2() end
            impact(); impact()
            assert(volumes==1 and bursts==1)
            hook.callbacks['Think:GE.FX.BuildCraters'](); assert(craters==1)
            ui,fi=0,0; net.callbacks.ge_fx_crater_snapshot_v2()
            hook.callbacks['Think:GE.FX.BuildCraters']()
            assert(craters==2 and volumes==1 and bursts==1)
            NOW=101; uints[1]=9; impact(); assert(volumes==2 and bursts==1)
            GEVisuals.Clear()
            hook.callbacks['Think:GE.FX.BuildCraters'](); assert(craters==2)
        ''')


if __name__ == '__main__':
    unittest.main()
