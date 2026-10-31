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


class RuntimeTests(unittest.TestCase):
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


if __name__ == '__main__':
    unittest.main()
