"""Geometry execution/budgets, not Source visual acceptance."""
import unittest
from test_runtime import client_runtime


class ChoreographyTests(unittest.TestCase):
    def test_geometry_stays_bounded_at_extreme_radii_and_slopes(self):
        lua, include = client_runtime()
        include('entities/ge_orbital_railgun/cl_init.lua')
        lua.execute('''
            ENT:SetupDataTables()
            local e=setmetatable({StartTime=100,ImpactRadius=900,VisualSeed=19,
                GroundNormal=Vector(0.759934,0,0.65)},{__index=ENT})
            e:Initialize()
            CVARS.ge_railgun_beam_height.value='10000'
            local add=render.AddBeam
            local vertices=0
            render.AddBeam=function(p,w,t,c)
                vertices=vertices+1
                assert(math.abs(p.x)<=5200 and math.abs(p.y)<=5200 and p.z>=-5200 and p.z<=10400)
                assert(w>=0 and c.a>=0 and c.a<=255)
                add(p,w,t,c)
            end
            for _,radius in ipairs({80,320,900}) do
                e.ImpactRadius=radius
                for quality=0,2 do
                    CVARS.ge_railgun_quality.value=tostring(quality)
                    for i=0,315 do
                        NOW=99.99+i/60; vertices=0
                        e:DrawTranslucent()
                        assert(vertices<=(quality==0 and 350 or 900))
                        assert(render.beam==0)
                    end
                end
            end
        ''')

    def test_visual_geometry_is_time_based_and_has_no_emitter_side_effects(self):
        lua, include = client_runtime()
        include('entities/ge_orbital_railgun/cl_init.lua')
        lua.execute('''
            ENT:SetupDataTables()
            local e=setmetatable({StartTime=100,ImpactRadius=320,VisualSeed=42,
                GroundNormal=Vector(0,0,1)},{__index=ENT})
            e:Initialize()
            local points={}
            local add=render.AddBeam
            render.AddBeam=function(p,w,t,c)
                points[#points+1]=string.format('%.4f,%.4f,%.4f,%.4f,%.4f',p.x,p.y,p.z,w,c.a)
                add(p,w,t,c)
            end
            local function capture(t)
                points={};NOW=t;e:DrawTranslucent();return table.concat(points,';')
            end
            for _,t in ipairs({100.8,102.8,103.1,103.35,104.2}) do
                local expected=capture(t)
                capture(t-0.017);capture(t-0.005)
                assert(expected==capture(t))
            end
            assert(#EMITTERS==0 and #sound.calls==0)
        ''')
