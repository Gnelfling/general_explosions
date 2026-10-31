import unittest
from test_runtime import runtime


class DamageTests(unittest.TestCase):
    def test_impact_damage_shake_once_at_impact_and_creator_fallback(self):
        lua, include = runtime()
        include('entities/ge_orbital_railgun/init.lua')
        lua.execute('''
            ENT:SetupDataTables()
            local blasts,shakes=0,0
            local owner={}
            local e=setmetatable({StartTime=100,ImpactRadius=320,VisualSeed=1,
                GroundNormal=Vector(0,0,1),creator=owner},{__index=ENT})
            util.BlastDamage=function(inflictor,attacker,pos,radius,damage)
                blasts=blasts+1
                assert(inflictor==e and attacker==owner and radius==320 and damage==150)
                assert(pos.z==8 and NOW==103.2)
            end
            util.ScreenShake=function(pos,amplitude,freq,duration,radius,air)
                shakes=shakes+1;assert(amplitude==8 and freq==8 and duration==1.2 and radius==2560 and air)
            end
            NOW=103.19;e:Think();assert(blasts==0 and shakes==0)
            NOW=103.2;e:Think();e:Think();assert(blasts==1 and shakes==1)
            CVARS.ge_railgun_damage.value='0';CVARS.ge_railgun_shake.value='0'
            e._geDidImpact=false;e:Think();assert(blasts==1 and shakes==1)
            CVARS.ge_railgun_damage.value='250'
            e._geDidImpact=false;owner.removed=true
            util.BlastDamage=function(inflictor,attacker,pos,radius,damage)
                blasts=blasts+1;assert(attacker==e and damage==250)
            end
            e:Think();assert(blasts==2)
            e._geDidImpact=false;NOW=106;e:Think();assert(e.removed and blasts==2)
        ''')
